# Linux release artifacts

The manually dispatched `.github/workflows/build-linux.yml` workflow builds the selected tag from `AyuGram/AyuGramDesktop`; the current branch is used only for the workflow helpers. Dispatch it from the Actions tab with the exact upstream `vX.Y.Z` tag.

The build follows [upstream's Linux Docker procedure](https://github.com/AyuGram/AyuGramDesktop/blob/dev/docs/building-linux.md): initialize the upstream tag's recursive submodules, run `Telegram/build/prepare/linux.sh`, then execute `Telegram/build/docker/centos_env/build.sh` in its generated `tdesktop:centos_env` image with the official API credentials documented by upstream (`2040` and the public API hash in `docs/api_credentials.md`). The expected binary is `out/Release/AyuGram`.

Artifacts are named `AyuGram-<version>-linux-x86_64.tar.gz`, `ayugram_<version>_amd64.deb`, and `SHA256SUMS`. The archive retains the upstream output tree and launches with `./AyuGram` after extraction. It uses host-provided shared libraries; it is not claimed to be fully portable without testing on a clean target system.

The Debian package installs the binary/runtime tree under `/usr/lib/ayugram-<version>`, provides `/usr/bin/ayugram`, and installs upstream's AyuGram desktop entry, D-Bus service, metainfo, icons, `tg` and `tonsite` URL handlers. Runtime dependency names are inferred from the built ELF's `ldd` paths and Ubuntu package ownership; validate them on supported Debian-family systems before declaring broad compatibility. This workflow does not claim other distributions are supported.

The release tag matches upstream (`vX.Y.Z`), and the release title is `AyuGram vX.Y.Z — Linux x86_64`. The workflow refuses to publish if that tag or release already exists in this destination repository. Its release is a normal, mutable GitHub Release: the release API available to this repository reports `immutable: false` and exposes no native immutability setting. It does not use an emulated immutability mechanism.

Release notes include **Triggered by**, **Upstream repository**, **Upstream tag**, **Upstream commit**, **Upstream commit date** (committer timestamp in UTC), **Build date** (UTC), **Artifacts**, **Checksums**, and **Build source** (the exact commit URL).

## Validation scope

The workflow packages assets only after the executable exists and checks its ELF x86_64 architecture. It validates Debian control/content metadata, archive contents, and checksums before release publication. Locally, scripts can be syntax-checked, but this repository's instructions prohibit a project build; end-to-end build, install/remove on a clean Debian environment, and real GitHub Actions dispatch require external runtime verification.
