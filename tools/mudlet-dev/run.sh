#!/usr/bin/env bash
# Run a headless Mudlet under Xvfb, install the freshly-built package,
# and take a screenshot.
#
# Usage:
#   tools/mudlet-dev/run.sh dev          # one-shot: launch, screenshot, exit
#   tools/mudlet-dev/run.sh interactive  # leave Mudlet running for manual driving
#   tools/mudlet-dev/run.sh stop         # kill any leftover Mudlet/Xvfb
#
# Env overrides:
#   ICESUS_HOST       (default: icesus.org)
#   ICESUS_PORT       (default: 4000)
#   XVFB_DISPLAY      (default: :99)
#   XVFB_GEOMETRY     (default: 1600x1000x24)
#   WAIT_SECONDS      (default: 8)
#   PROFILE_NAME      (default: icesus-dev)

set -euo pipefail

cd "$(dirname "$0")/../.."

REPO_ROOT="$PWD"
MODE="${1:-dev}"

ICESUS_HOST="${ICESUS_HOST:-icesus.org}"
ICESUS_PORT="${ICESUS_PORT:-4000}"
XVFB_DISPLAY="${XVFB_DISPLAY:-:99}"
XVFB_GEOMETRY="${XVFB_GEOMETRY:-1600x1000x24}"
WAIT_SECONDS="${WAIT_SECONDS:-8}"
PROFILE_NAME="${PROFILE_NAME:-icesus-dev}"

MUDLET_BIN="$HOME/mudlet-bin/Mudlet.AppImage"
PROFILE_DIR="$HOME/.config/mudlet/profiles/$PROFILE_NAME"
WORKDIR=/tmp/icesus-mudlet-dev
SHOTS_DIR="$REPO_ROOT/tools/mudlet-dev/screenshots"
PKG="$REPO_ROOT/dist/Icesus.mpackage"

mkdir -p "$WORKDIR" "$SHOTS_DIR"

# -----------------------------------------------------------------
# stop: kill anything we left running
# -----------------------------------------------------------------
if [[ "$MODE" == "stop" ]]; then
  pkill -9 -f Mudlet.AppImage 2>/dev/null || true
  pkill -9 -f "Xvfb $XVFB_DISPLAY" 2>/dev/null || true
  echo "Stopped Mudlet + Xvfb on $XVFB_DISPLAY."
  exit 0
fi

# -----------------------------------------------------------------
# precondition: package must be built
# -----------------------------------------------------------------
if [[ ! -f "$PKG" ]]; then
  echo "Package missing at $PKG — running build first."
  "$REPO_ROOT/build/build.sh"
fi

if [[ ! -x "$MUDLET_BIN" ]]; then
  echo "Mudlet AppImage missing at $MUDLET_BIN. Run tools/mudlet-dev/install.sh first." >&2
  exit 1
fi

# -----------------------------------------------------------------
# fresh Xvfb
# -----------------------------------------------------------------
pkill -9 -f Mudlet.AppImage 2>/dev/null || true
if ! DISPLAY="$XVFB_DISPLAY" xdpyinfo >/dev/null 2>&1; then
  Xvfb "$XVFB_DISPLAY" -screen 0 "$XVFB_GEOMETRY" -nolisten tcp \
    >"$WORKDIR/xvfb.log" 2>&1 &
  XVFB_PID=$!
  echo "Started Xvfb on $XVFB_DISPLAY (pid $XVFB_PID, $XVFB_GEOMETRY)."
  sleep 1
fi

# -----------------------------------------------------------------
# fresh profile pre-pointed at the right host
# -----------------------------------------------------------------
rm -rf "$PROFILE_DIR"
mkdir -p "$PROFILE_DIR"
echo "$ICESUS_HOST" >"$PROFILE_DIR/url"
echo "$ICESUS_PORT" >"$PROFILE_DIR/port"
echo "true" >"$PROFILE_DIR/GMCP"
# AutoLogin off so we don't accidentally connect with cached creds
echo "false" >"$PROFILE_DIR/AutoLogin"

# -----------------------------------------------------------------
# launch Mudlet with the package as install argument
# -----------------------------------------------------------------
LOG="$WORKDIR/mudlet.log"
echo "Launching Mudlet (profile=$PROFILE_NAME, host=$ICESUS_HOST:$ICESUS_PORT)..."
DISPLAY="$XVFB_DISPLAY" "$MUDLET_BIN" --fullscreen --profile="$PROFILE_NAME" "$PKG" \
  >"$LOG" 2>&1 &
MUDLET_PID=$!
echo "Mudlet pid: $MUDLET_PID. Log: $LOG"

# -----------------------------------------------------------------
# branch on mode
# -----------------------------------------------------------------
case "$MODE" in
  dev)
    sleep "$WAIT_SECONDS"
    stamp=$(date +%Y%m%d-%H%M%S)
    out="$SHOTS_DIR/$stamp.png"
    import -display "$XVFB_DISPLAY" -window root "$out"
    ln -sfn "$stamp.png" "$SHOTS_DIR/latest.png"
    echo "Screenshot: $out"
    echo "Symlink:    $SHOTS_DIR/latest.png"
    kill "$MUDLET_PID" 2>/dev/null || true
    sleep 1
    pkill -9 -f Mudlet.AppImage 2>/dev/null || true
    ;;
  interactive)
    echo "Mudlet is running on $XVFB_DISPLAY. To shoot:"
    echo "  import -display $XVFB_DISPLAY -window root /tmp/shot.png"
    echo "To stop:"
    echo "  $0 stop"
    ;;
  *)
    echo "Unknown mode: $MODE (expected: dev | interactive | stop)" >&2
    exit 2
    ;;
esac
