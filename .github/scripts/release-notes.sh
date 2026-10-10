#!/usr/bin/env bash
set -euo pipefail

directory="${1:?Artifact directory is required}"
: "${VERSION:?VERSION is required}"
: "${UPSTREAM_TAG:?UPSTREAM_TAG is required}"
: "${UPSTREAM_COMMIT:?UPSTREAM_COMMIT is required}"
: "${UPSTREAM_DATE:?UPSTREAM_DATE is required}"
: "${BUILD_DATE:?BUILD_DATE is required}"
: "${TRIGGERED_BY:?TRIGGERED_BY is required}"

[[ "$UPSTREAM_COMMIT" =~ ^[0-9a-f]{40}$ ]]
[[ "$UPSTREAM_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T.*Z$ ]]
[[ "$BUILD_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T.*Z$ ]]
for name in "AyuGram-$VERSION-linux-x86_64.tar.gz" "ayugram_${VERSION}_amd64.deb" SHA256SUMS; do
  [[ -s "$directory/$name" ]] || { echo "::error::Missing release asset: $name"; exit 1; }
done
(cd "$directory" && sha256sum --check SHA256SUMS)
grep -Fq "AyuGram-$VERSION-linux-x86_64.tar.gz" "$directory/SHA256SUMS"
grep -Fq "ayugram_${VERSION}_amd64.deb" "$directory/SHA256SUMS"

cat > "$directory/RELEASE_NOTES.md" <<EOF
Linux x86_64 build of AyuGram from the exact upstream source tag.

## Build provenance

- **Triggered by:** @$TRIGGERED_BY
- **Upstream repository:** [AyuGram/AyuGramDesktop](https://github.com/AyuGram/AyuGramDesktop)
- **Upstream tag:** \`$UPSTREAM_TAG\`
- **Upstream commit:** \`$UPSTREAM_COMMIT\`
- **Upstream commit date:** $UPSTREAM_DATE (UTC; committer date)
- **Build date:** $BUILD_DATE (UTC)
- **Build source:** https://github.com/AyuGram/AyuGramDesktop/commit/$UPSTREAM_COMMIT

## Artifacts

- \`AyuGram-$VERSION-linux-x86_64.tar.gz\` — extracted runtime tree; run \`./AyuGram\` after unpacking. Uses system runtime libraries and is not represented as a fully portable bundle.
- \`ayugram_${VERSION}_amd64.deb\` — Debian package with XDG desktop integration and detected runtime library dependencies.
- **Checksums:** SHA-256 values are listed in the attached \`SHA256SUMS\` file.
- \`SHA256SUMS\` — SHA-256 checksums for both binary artifacts.

Immutable release status: GitHub's native immutable-release option is not enabled by this repository's currently available release API/account configuration. This release is published as a normal GitHub Release.
EOF

for field in 'Triggered by' 'Upstream repository' 'Upstream tag' 'Upstream commit' 'Upstream commit date' 'Build date' 'Artifacts' 'Checksums' 'Build source'; do
  grep -Fq "**$field:**" "$directory/RELEASE_NOTES.md" || {
    echo "::error::Release notes are missing provenance field '$field'."
    exit 1
  }
done
