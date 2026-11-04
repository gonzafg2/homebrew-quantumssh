# QuantumSSH's Homebrew formula (ADR-0056 in gonzafg2/quantumssh).
#
# It installs the attested release tarball for the platform; there is no
# source build. Each `sha256` is copied from the release's PGP-verified
# SHA256SUMS, never computed from a download, and the tap's CI checks
# them against it before it installs anything (ADR-0056 §3, §4).

# RFC-0017's support tiers: binaries for macOS on Apple silicon and for
# Linux on x86_64 and arm64. Intel macOS fails here, before any download.
class QuantumsshSupportTier < Requirement
  fatal true

  satisfy(build_env: false) { Hardware::CPU.arm? }

  def message
    <<~EOS
      QuantumSSH publishes binaries for macOS on Apple silicon and for Linux
      on x86_64 and arm64 (RFC-0017's support tiers). Intel macOS has no
      binary and no runner to test one, and this formula does not build
      from source. To build it yourself, see:
        https://github.com/gonzafg2/quantumssh/blob/main/docs/deployment.md#1-install-the-binary
    EOS
  end

  def display_s = "macOS on Apple silicon"
end

class Quantumssh < Formula
  desc "Memory-safe, post-quantum-first SSH server"
  homepage "https://github.com/gonzafg2/quantumssh"
  license "Apache-2.0"

  on_macos do
    depends_on QuantumsshSupportTier

    on_arm do
      url "https://github.com/gonzafg2/quantumssh/releases/download/v0.2.0/quantumssh-0.2.0-aarch64-apple-darwin.tar.gz"
      sha256 "db875f6a190bf9e7b485caba2fbcad8b00c84259f96e7687192d1882e4582d30"
    end
    # The formula must load on every platform (`brew readall`), so Intel
    # macOS names the arm64 tarball; QuantumsshSupportTier stops the
    # install before it is downloaded.
    on_intel do
      url "https://github.com/gonzafg2/quantumssh/releases/download/v0.2.0/quantumssh-0.2.0-aarch64-apple-darwin.tar.gz"
      sha256 "db875f6a190bf9e7b485caba2fbcad8b00c84259f96e7687192d1882e4582d30"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/gonzafg2/quantumssh/releases/download/v0.2.0/quantumssh-0.2.0-x86_64-unknown-linux-musl.tar.gz"
      sha256 "b9729c9dfdab41aee9056e6953c82ff6677882e33f9c998622fea4e11b39d5e4"
    end
    on_arm do
      url "https://github.com/gonzafg2/quantumssh/releases/download/v0.2.0/quantumssh-0.2.0-aarch64-unknown-linux-musl.tar.gz"
      sha256 "bc8e41ad44cef85d22c56d396161d93571073fa45f91659d0edee5d725ffc076"
    end
  end

  def install
    bin.install "quantumssh"
  end

  # The configuration is written once: an upgrade keeps the operator's
  # edits (overwrite: false). write_file creates it under the umask, and a
  # umask of 002 leaves it group-writable, which the server refuses
  # (ADR-0029): hence its mode.
  post_install_steps do
    mkdir_p "quantumssh", base: :etc
    set_permissions "quantumssh", "0700", base: :etc, recursive: false
    write_file "quantumssh/config.toml", <<~TOML, base: :etc, overwrite: false
      # QuantumSSH under brew services: a single-user evaluation path
      # (ADR-0056). Every path stays inside this directory.
      schema_version = 1

      [server]
      listen   = "127.0.0.1:2222"
      host_key = "{{etc}}/quantumssh/ssh_host_mldsa44_ed25519_key"

      [auth]
      authorized_keys = "{{etc}}/quantumssh/authorized_keys"
    TOML
    set_permissions "quantumssh/config.toml", "0600", base: :etc, recursive: false
  end

  service do
    run [opt_bin/"quantumssh", "--config", etc/"quantumssh/config.toml"]
    keep_alive true
    log_path var/"log/quantumssh.log"
    error_log_path var/"log/quantumssh.log"
  end

  def caveats
    <<~EOS
      This is a single-user evaluation path, not the supported deployment.
      Under `brew services` the server runs as your account, unlike the
      dedicated service account of the Linux guide (ADR-0016): your account
      owns the host key and authorized_keys, and every session carries its
      authority. For a server, follow:
        https://github.com/gonzafg2/quantumssh/blob/main/docs/deployment.md

      Before the first start:
        chmod g-w "$(brew --prefix)/etc"
        quantumssh keygen "$(brew --prefix)/etc/quantumssh/ssh_host_mldsa44_ed25519_key"
        install -m 0644 ~/.ssh/id_ed25519.pub "$(brew --prefix)/etc/quantumssh/authorized_keys"
        brew services start quantumssh

      The server refuses its configuration and keys under a group-writable
      directory, and Homebrew leaves its etc group-writable for an admin
      account: hence the chmod.

      Clients need OpenSSH 10.6 or newer. On macOS, install Homebrew's and
      unlink it, so the system ssh stays in place, then run it by full path:
        brew install openssh && brew unlink openssh
        "$(brew --prefix openssh)/bin/ssh" -p 2222 localhost
      If ~/.ssh/config sets UseKeychain, put `IgnoreUnknown UseKeychain` on
      its first line: only Apple's ssh knows that option.
    EOS
  end

  test do
    assert_match "quantumssh #{version}", shell_output("#{bin}/quantumssh --version")
  end
end
