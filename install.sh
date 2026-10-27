#!/usr/bin/env bash
# Installs the newest MP3 Direct Cut release from GitHub for the current user:
#
#   curl -fsSL https://raw.githubusercontent.com/NuclleaR/mp3directcutlinux/main/install.sh | bash
#
# and removes it again with:
#
#   curl -fsSL https://raw.githubusercontent.com/NuclleaR/mp3directcutlinux/main/install.sh | bash -s -- --uninstall
#
#   app           $XDG_DATA_HOME/mp3-direct-cut (default ~/.local/share)
#   command       $XDG_BIN_HOME/mp3-direct-cut (default ~/.local/bin), a symlink
#   menu entry    $XDG_DATA_HOME/applications/com.example.mp3_direct_cut.desktop
#
# The menu entry is named after the app id: on Wayland the dock ignores the window icon
# and finds the app's name and icon through it. MP3DC_ARCHIVE_URL installs the given
# archive instead of the newest release.
set -euo pipefail

repo=NuclleaR/mp3directcutlinux
asset=mp3-direct-cut-linux-x64.tar.gz
app_id=com.example.mp3_direct_cut
data="${XDG_DATA_HOME:-$HOME/.local/share}"
dest="$data/mp3-direct-cut"
link="${XDG_BIN_HOME:-$HOME/.local/bin}/mp3-direct-cut"
entry="$data/applications/$app_id.desktop"

uninstall() {
  rm -rf "$dest"
  if [[ -L "$link" ]]; then rm "$link"; fi
  rm -f "$entry"
}

if [[ "${1:-}" == "--uninstall" ]]; then
  uninstall
  echo "Removed MP3 Direct Cut."
  exit 0
fi

url="${MP3DC_ARCHIVE_URL:-}"
if [[ -z "$url" ]]; then
  # The newest release, pre-releases included (the "latest" endpoint skips them).
  url="$(curl -fsSL "https://api.github.com/repos/$repo/releases?per_page=1" |
    grep -o "\"browser_download_url\": *\"[^\"]*/$asset\"" | head -n 1 | grep -o 'https://[^"]*' || true)"
  if [[ -z "$url" ]]; then
    echo "No release of $repo has $asset yet." >&2
    exit 1
  fi
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
echo "Downloading $url"
curl -fL --progress-bar -o "$tmp/$asset" "$url"
tar -xzf "$tmp/$asset" -C "$tmp"

uninstall
mkdir -p "$data" "$(dirname "$link")" "$(dirname "$entry")"
mv "$tmp/mp3-direct-cut" "$dest"
ln -s "$dest/mp3_direct_cut" "$link"
cat > "$entry" <<EOF
[Desktop Entry]
Type=Application
Name=MP3 Direct Cut
Comment=Cut and split MP3 files without re-encoding
Exec=$dest/mp3_direct_cut
Icon=$dest/data/app_icon.png
Terminal=false
Categories=AudioVideo;Audio;AudioVideoEditing;
StartupWMClass=$app_id
EOF

echo "Installed MP3 Direct Cut to $dest"
case ":$PATH:" in
  *":$(dirname "$link"):"*) echo "Start it from the app menu or with: mp3-direct-cut" ;;
  *) echo "Start it from the app menu; $(dirname "$link") is not on PATH, so the mp3-direct-cut command needs it added." ;;
esac
