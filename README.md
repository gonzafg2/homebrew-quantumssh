# homebrew-quantumssh

The Homebrew tap for [QuantumSSH](https://github.com/gonzafg2/quantumssh),
a memory-safe, post-quantum-first SSH server in alpha.

```sh
brew install gonzafg2/quantumssh/quantumssh
```

Installing by the full name trusts this formula (Homebrew's tap trust).
To install it by its short name, run `brew trust gonzafg2/quantumssh`
first.

## Scope: a single-user evaluation path

Under `brew services` the server runs as your own account, unlike the
supported deployment, which uses a dedicated service account. Your account
therefore owns the host key and `authorized_keys`, and every session
carries its authority. This tap is for trying QuantumSSH out; for a server,
follow the
[Linux deployment guide](https://github.com/gonzafg2/quantumssh/blob/main/docs/deployment.md).
The decision and its limits are
[ADR-0056](https://github.com/gonzafg2/quantumssh/blob/main/docs/adr/0056-homebrew-tap.md).

| Platform | Formula |
|---|---|
| macOS on Apple silicon | The release's `aarch64-apple-darwin` tarball |
| Linux on x86_64 and arm64 | The release's static musl tarballs |
| Intel macOS | Refused at install: no binary, and no source build |

`brew info quantumssh` prints the steps before the first start: remove
group write from Homebrew's `etc`, create the host key with
`quantumssh keygen`, and install your `authorized_keys`. Clients need
OpenSSH 10.6 or newer.

## What `brew install` checks

The formula installs the attested release tarball, with the `sha256`
recorded in the formula. Each `sha256` is copied by hand from the
release's `SHA256SUMS`, which the maintainer signs with the project PGP key,
never from a fresh download. On every pull request, this repository's CI:

1. fetches the project's pin set and `scripts/verify-download.sh` from
   QuantumSSH's `main`, and checks the current key against the
   fingerprint pinned in the workflow;
2. verifies the release's `SHA256SUMS` signature with that script, and
   fails unless every `sha256` in the formula equals its signed line;
3. runs `brew install` and `brew test`;
4. starts the service and logs in to it with OpenSSH 10.6.

It runs on macOS arm64 and on `ubuntu-24.04`.

## License

[Apache-2.0](LICENSE), like QuantumSSH.
