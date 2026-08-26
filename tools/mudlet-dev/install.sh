#!/usr/bin/env bash
# Install dependencies for headless Mudlet development.
#
# Idempotent — re-running skips work that's already done.

set -euo pipefail

DEPS=(
  xvfb
  imagemagick
  x11-utils
  libegl1
  libgl1
  libxcb-cursor0
  libdbus-1-3
  libfuse2
  libxkbcommon0
  libfontconfig1
  fonts-dejavu
  fonts-noto
)

missing=()
for p in "${DEPS[@]}"; do
  if ! dpkg -s "$p" >/dev/null 2>&1; then
    missing+=("$p")
  fi
done

if (( ${#missing[@]} )); then
  echo "Installing: ${missing[*]}"
  sudo apt-get update -qq
  sudo apt-get install -y "${missing[@]}"
else
  echo "All apt dependencies already installed."
fi

# Mudlet AppImage. Only fetched when missing — set MUDLET_UPDATE=1 to
# pull the current release over the top of an older one. Worth doing
# when a new Mudlet ships: run.sh only proves the package works on the
# build sitting here, and 4.22.0 arrived with a first-run dialog that
# broke the harness until run.sh learned to answer it.
MUDLET_BIN="$HOME/mudlet-bin/Mudlet.AppImage"
if [[ ! -x "$MUDLET_BIN" || -n "${MUDLET_UPDATE:-}" ]]; then
  echo "Downloading Mudlet AppImage..."
  mkdir -p "$(dirname "$MUDLET_BIN")"
  url=$(curl -sL https://api.github.com/repos/Mudlet/Mudlet/releases/latest \
    | python3 -c '
import json, sys
r = json.load(sys.stdin)
for a in r.get("assets", []):
    if "AppImage.tar" in a["name"] and "linux-x64" in a["name"]:
        print(a["browser_download_url"]); break
')
  if [[ -z "$url" ]]; then
    echo "Could not find an AppImage in the latest Mudlet release." >&2
    exit 1
  fi
  tmp=$(mktemp -d)
  curl -sL -o "$tmp/mudlet.tar" "$url"
  tar -xf "$tmp/mudlet.tar" -C "$(dirname "$MUDLET_BIN")"
  rm -rf "$tmp"
  chmod +x "$MUDLET_BIN"
  echo "Installed Mudlet to $MUDLET_BIN"
else
  echo "Mudlet AppImage already at $MUDLET_BIN (MUDLET_UPDATE=1 to refresh it)"
fi

"$MUDLET_BIN" --version 2>&1 | head -1 || true
echo "Done. Next: ./tools/mudlet-dev/run.sh dev"
