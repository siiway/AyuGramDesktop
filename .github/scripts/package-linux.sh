#!/usr/bin/env bash
set -euo pipefail

: "${VERSION:?VERSION is required}"
: "${UPSTREAM_TAG:?UPSTREAM_TAG is required}"
: "${UPSTREAM_COMMIT:?UPSTREAM_COMMIT is required}"

root="$PWD"
binary="$root/out/Release/AyuGram"
[[ -x "$binary" ]] || { echo "::error::Expected executable not found: $binary"; exit 1; }
file "$binary" | grep -Eq 'ELF 64-bit LSB (pie )?executable, x86-64' || {
  echo "::error::AyuGram is not an x86_64 ELF executable."; exit 1;
}

if [[ "$(find "$root/out/Release" -mindepth 1 -maxdepth 1 ! -name AyuGram | wc -l)" -eq 0 ]]; then
  echo "::error::The build output has no supporting runtime files beside AyuGram."
  exit 1
fi

dist="$root/dist"
rm -rf "$dist"
mkdir -p "$dist"
archive_root="$dist/AyuGram-$VERSION-linux-x86_64"
mkdir -p "$archive_root"
cp -a "$root/out/Release/." "$archive_root/"
cat > "$archive_root/README.txt" <<EOF
AyuGram Desktop $VERSION for Linux x86_64

Extract this directory and launch with:
  ./AyuGram

Runtime system libraries are provided by the target Linux distribution and
are not bundled. This archive has not been tested as a portable bundle on a
clean target environment.

Upstream tag: $UPSTREAM_TAG
Upstream commit: $UPSTREAM_COMMIT
EOF
tar -C "$dist" -czf "$dist/AyuGram-$VERSION-linux-x86_64.tar.gz" "$(basename "$archive_root")"

control_root="$root/package-root"
rm -rf "$control_root"
mkdir -p "$control_root/DEBIAN" \
  "$control_root/usr/bin" \
  "$control_root/usr/lib/ayugram-$VERSION" \
  "$control_root/usr/share/applications" \
  "$control_root/usr/share/dbus-1/services" \
  "$control_root/usr/share/metainfo" \
  "$control_root/usr/share/icons/hicolor"
cp -a "$root/out/Release/." "$control_root/usr/lib/ayugram-$VERSION/"
ln -s "/usr/lib/ayugram-$VERSION/AyuGram" "$control_root/usr/bin/ayugram"
sed 's/^TryExec=AyuGram$/TryExec=ayugram/; s/^Exec=env DESKTOPINTEGRATION=1 AyuGram -- %U$/Exec=env DESKTOPINTEGRATION=1 ayugram -- %U/; s/^Exec=AyuGram -quit$/Exec=ayugram -quit/' \
  "$root/lib/xdg/com.ayugram.desktop.desktop" > "$control_root/usr/share/applications/com.ayugram.desktop.desktop"
sed "s|@CMAKE_INSTALL_FULL_BINDIR@/AyuGram|/usr/bin/ayugram|" \
  "$root/lib/xdg/com.ayugram.desktop.service" > "$control_root/usr/share/dbus-1/services/com.ayugram.desktop.service"
cp "$root/lib/xdg/com.ayugram.desktop.metainfo.xml" "$control_root/usr/share/metainfo/"
for size in 16 32 48 64 128 256 512; do
  mkdir -p "$control_root/usr/share/icons/hicolor/${size}x${size}/apps"
  cp "$root/Telegram/Resources/art/icon${size}.png" \
    "$control_root/usr/share/icons/hicolor/${size}x${size}/apps/com.ayugram.desktop.png"
done
mkdir -p "$control_root/usr/share/icons/hicolor/symbolic/apps"
cp "$root/Telegram/Resources/icons/tray_monochrome.svg" "$control_root/usr/share/icons/hicolor/symbolic/apps/com.ayugram.desktop-symbolic.svg"
cp "$root/Telegram/Resources/icons/tray_monochrome_attention.svg" "$control_root/usr/share/icons/hicolor/symbolic/apps/com.ayugram.desktop-attention-symbolic.svg"
cp "$root/Telegram/Resources/icons/tray_monochrome_mute.svg" "$control_root/usr/share/icons/hicolor/symbolic/apps/com.ayugram.desktop-mute-symbolic.svg"

mapfile -t libraries < <(ldd "$binary" | awk '/=> \/|^[[:space:]]*\// { path = ($2 == "=>" ? $3 : $1); if (path ~ /^\//) print path }' | sort -u)
packages=()
ignored_libraries=()
for library in "${libraries[@]}"; do
  package="$(dpkg-query -S "$library" 2>/dev/null | awk -F ': ' 'NR == 1 { print $1 }' || true)"
  if [[ -n "$package" ]]; then
    packages+=("$package")
  else
    ignored_libraries+=("$library")
  fi
done
if ((${#ignored_libraries[@]})); then
  printf 'Ignoring libraries not owned by installed Debian packages:\n' >&2
  printf '  %s\n' "${ignored_libraries[@]}" >&2
fi
if ((${#packages[@]} == 0)); then
  echo "::error::Could not determine Debian runtime dependencies from the built executable."
  exit 1
fi
depends="$(printf '%s\n' "${packages[@]}" | sort -u | paste -sd ',' - | sed 's/,/, /g')"
cat > "$control_root/DEBIAN/control" <<EOF
Package: ayugram
Version: $VERSION
Section: net
Priority: optional
Architecture: amd64
Maintainer: AyuGram build automation <noreply@github.com>
Depends: $depends
Description: Telegram Desktop client with AyuGram features
 Built from upstream tag $UPSTREAM_TAG ($UPSTREAM_COMMIT).
EOF
dpkg-deb --root-owner-group --build "$control_root" "$dist/ayugram_${VERSION}_amd64.deb"
dpkg-deb --info "$dist/ayugram_${VERSION}_amd64.deb"
dpkg-deb --contents "$dist/ayugram_${VERSION}_amd64.deb" >/dev/null
sha256sum "$dist/AyuGram-$VERSION-linux-x86_64.tar.gz" "$dist/ayugram_${VERSION}_amd64.deb" > "$dist/SHA256SUMS"
sha256sum --check "$dist/SHA256SUMS"
