#!/usr/bin/env bash
# Run a headless Mudlet under Xvfb, install the freshly-built package,
# and take a screenshot.
#
# Usage:
#   tools/mudlet-dev/run.sh dev          # one-shot: launch, screenshot, exit
#   tools/mudlet-dev/run.sh fake         # like dev, but the "server" is a local
#                                        # fixture replayer — populates every panel
#   tools/mudlet-dev/run.sh interactive  # leave Mudlet running for manual driving
#   tools/mudlet-dev/run.sh stop         # kill any leftover Mudlet/Xvfb/fake_server
#
# Env overrides:
#   ICESUS_HOST       (default: icesus.org;       fake mode forces 127.0.0.1)
#   ICESUS_PORT       (default: 4000;             fake mode uses FAKE_PORT)
#   FAKE_PORT         (default: 7878)
#   FAKE_FIXTURE      (default: tools/mudlet-dev/fixtures/default.json)
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
FAKE_PORT="${FAKE_PORT:-7878}"
FAKE_FIXTURE="${FAKE_FIXTURE:-$REPO_ROOT/tools/mudlet-dev/fixtures/default.json}"
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
  pkill -9 -f "fake_server.py" 2>/dev/null || true
  echo "Stopped Mudlet + Xvfb + fake_server on $XVFB_DISPLAY."
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
# fake mode: spin up the local GMCP fixture replayer and aim Mudlet at it
# -----------------------------------------------------------------
FAKE_PID=""
if [[ "$MODE" == "fake" ]]; then
  if [[ ! -f "$FAKE_FIXTURE" ]]; then
    echo "Fixture missing: $FAKE_FIXTURE" >&2
    exit 1
  fi
  pkill -9 -f "fake_server.py" 2>/dev/null || true
  ICESUS_HOST="127.0.0.1"
  ICESUS_PORT="$FAKE_PORT"
  FAKE_LOG="$WORKDIR/fake_server.log"
  python3 "$REPO_ROOT/tools/mudlet-dev/fake_server.py" "$FAKE_PORT" "$FAKE_FIXTURE" \
    >"$FAKE_LOG" 2>&1 &
  FAKE_PID=$!
  echo "Started fake_server on 127.0.0.1:$FAKE_PORT (pid $FAKE_PID, log $FAKE_LOG)."
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if grep -q "listening on" "$FAKE_LOG" 2>/dev/null; then
      break
    fi
    sleep 0.2
  done

  # Mudlet's CLI only accepts one positional .mpackage. Inline a tiny
  # auto-connect script into a fake-flavoured copy so the HUD dials the
  # fake_server on profile load. Real package on disk is untouched.
  PKG="$REPO_ROOT/dist/Icesus-fake.mpackage"
  python3 - "$REPO_ROOT/package" "$PKG" "$FAKE_PORT" <<'PY'
import os, re, sys, zipfile
src, out, port = sys.argv[1], sys.argv[2], sys.argv[3]
xml_path = os.path.join(src, "Icesus.xml")
with open(xml_path) as fh:
    xml = fh.read()

inject = f"""
   <Script isActive="yes" isFolder="no">
    <name>icesus.fakeconnect</name>
    <packageName>Icesus</packageName>
    <script><![CDATA[
-- tools/mudlet-dev fake mode: dial the local fixture replayer once the
-- profile finishes loading. Stripped from real builds.
tempTimer(0.5, function()
  cecho("\\n<grey>[fakeconnect] dialing 127.0.0.1:{port}<reset>\\n")
  connectToServer("127.0.0.1", {port})
end)
    ]]></script>
    <eventHandlerList>
     <string>sysLoadEvent</string>
    </eventHandlerList>
   </Script>

  </ScriptGroup>"""
xml = xml.replace("\n  </ScriptGroup>", inject, 1)

os.makedirs(os.path.dirname(out), exist_ok=True)
if os.path.exists(out):
    os.remove(out)
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("Icesus.xml", xml)
    z.write(os.path.join(src, "config.lua"), "config.lua")
PY
  echo "Built fake-flavoured package: $PKG"
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
# fake mode wants Mudlet to dial localhost on its own; dev mode stays
# manual to avoid accidentally connecting with cached creds.
if [[ "$MODE" == "fake" ]]; then
  echo "true"  >"$PROFILE_DIR/AutoLogin"
else
  echo "false" >"$PROFILE_DIR/AutoLogin"
fi

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
  dev|fake)
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
    if [[ -n "$FAKE_PID" ]]; then
      kill "$FAKE_PID" 2>/dev/null || true
      pkill -9 -f "fake_server.py" 2>/dev/null || true
    fi
    ;;
  interactive)
    echo "Mudlet is running on $XVFB_DISPLAY. To shoot:"
    echo "  import -display $XVFB_DISPLAY -window root /tmp/shot.png"
    echo "To stop:"
    echo "  $0 stop"
    ;;
  *)
    echo "Unknown mode: $MODE (expected: dev | fake | interactive | stop)" >&2
    exit 2
    ;;
esac
