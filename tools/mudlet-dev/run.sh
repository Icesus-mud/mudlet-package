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
#   ICESUS_USER_FILE    path copied into the profile as Icesus.user.lua
#   ICESUS_CUSTOM_FILE  path copied into the profile as Icesus.custom.lua

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
  python3 - "$REPO_ROOT/package" "$PKG" "$FAKE_PORT" "$XVFB_GEOMETRY" <<'PY'
import os, re, sys, zipfile
src, out, port = sys.argv[1], sys.argv[2], sys.argv[3]
# --fullscreen leaves the window at 750x498 whatever Xvfb's screen is,
# which squeezes the HUD into a shape no player sees. Ask Mudlet for
# the screen size from inside instead.
geom_w, geom_h = sys.argv[4].split("x")[:2]
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
--
-- The profile is pointed at the replayer already, so normally it is
-- connected before this runs and dialling again would only drop the
-- session and reconnect. This stays as the fallback for when the
-- replayer was not up yet at profile load.
local connected = false
registerAnonymousEventHandler("sysConnectionEvent", function() connected = true end)
tempTimer(0.5, function()
  pcall(setMainWindowSize, {geom_w}, {geom_h})
  if connected then return end
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

# Host::readProfileData() reads these through a QDataStream, not as text:
# a big-endian quint32 byte count followed by UTF-16BE. Plain `echo` was
# read back as an empty string, so the profile has in fact always started
# on no host at all - which is why fake mode logged "Unable to connect"
# before the injected script dialled, and why `dev` mode never really
# pointed at icesus.org the way this script claimed.
write_profile_datum() {
  python3 -c '
import struct, sys
data = sys.argv[2].encode("utf-16-be")
open(sys.argv[1], "wb").write(struct.pack(">I", len(data)) + data)
' "$1" "$2"
}
write_profile_datum "$PROFILE_DIR/url"  "$ICESUS_HOST"
write_profile_datum "$PROFILE_DIR/port" "$ICESUS_PORT"
echo "true" >"$PROFILE_DIR/GMCP"
# fake mode wants Mudlet to dial localhost on its own; dev mode stays
# manual to avoid accidentally connecting with cached creds.
if [[ "$MODE" == "fake" ]]; then
  echo "true"  >"$PROFILE_DIR/AutoLogin"
else
  echo "false" >"$PROFILE_DIR/AutoLogin"
fi

# A profile with no *.xml save is "new", and Mudlet 5.0 fills a new one
# with its default packages - generic_mapper and, since 5.0, the
# mudlet-base-ui starter interface. The starter UI docks its own map,
# chat and vitals panels over the right-hand third of the screen, which
# is exactly where our HUD draws: the screenshot then shows two
# interfaces fighting, and neither reads.
#
# A real Icesus player never sees that. Mudlet picks the preinstall set
# from the profile NAME, via TGameDetails::findGame() - a profile named
# "Icesus" resolves to icesus.org, whose entry carries providesOwnUi, so
# the starter UI is skipped and icesus-loader is installed instead. This
# profile is named icesus-dev and aimed at a fixture replayer, so it
# matches no game and gets the generic treatment.
#
# Naming it "Icesus" is not the fix: the loader would then download the
# RELEASED package from GitHub on connect and install it over the local
# build under test. Seeding an empty save is - Mudlet then treats the
# profile as one that already exists and preinstalls nothing, which is
# the state a real Icesus profile reaches anyway once our install()
# has dropped generic_mapper.
mkdir -p "$PROFILE_DIR/current"
cat >"$PROFILE_DIR/current/seed.xml" <<'SEED'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE MudletPackage>
<MudletPackage version="1.001">
 <TriggerPackage />
 <TimerPackage />
 <AliasPackage />
 <ActionPackage />
 <ScriptPackage />
 <KeyPackage />
 <VariablePackage><HiddenVariables /></VariablePackage>
</MudletPackage>
SEED

# Optional player-customisation files. The profile directory is what
# getMudletHomeDir() returns, so dropping them here is exactly what a
# player does by hand.
if [[ -n "${ICESUS_USER_FILE:-}" ]]; then
  cp "$ICESUS_USER_FILE" "$PROFILE_DIR/Icesus.user.lua"
  echo "Seeded Icesus.user.lua from $ICESUS_USER_FILE"
fi
if [[ -n "${ICESUS_CUSTOM_FILE:-}" ]]; then
  cp "$ICESUS_CUSTOM_FILE" "$PROFILE_DIR/Icesus.custom.lua"
  echo "Seeded Icesus.custom.lua from $ICESUS_CUSTOM_FILE"
fi

# -----------------------------------------------------------------
# Mudlet's own settings live outside the profile, so the wipe above
# does not reach them. Two first-run dialogs otherwise sit on top of
# the HUD and make the screenshot worthless:
#
#   * 4.22.0 asks whether Mudlet should take over telnet:// links. It
#     decides by shelling out to xdg-mime, and a headless server has
#     none — which counts as "somebody else owns them", so the prompt
#     comes up on every run.
#   * the updater downloads new releases by itself and puts an error
#     box on screen when that download fails.
#
# Answer both the way a throwaway headless run would.
# -----------------------------------------------------------------
MUDLET_INI="${MUDLET_CONFIG_DIR:-$HOME/.config/mudlet}/Mudlet.ini"
mkdir -p "$(dirname "$MUDLET_INI")"
python3 - "$MUDLET_INI" <<'INI_PY'
import configparser, sys

path = sys.argv[1]
# Raw: QSettings values are full of % and @ that interpolation chokes on.
cp = configparser.RawConfigParser()
cp.optionxform = str          # QSettings keys are case-sensitive
cp.read(path)
for section, keys in (
    ("General", { "telnetHandlerAsked":   "true",
                  "telnetHandlerEnabled": "false",
                  "telnetHandlerDontAsk": "true" }),
    ("DBLSQD",  { "autoDownload": "false" }),
):
    if not cp.has_section(section):
        cp.add_section(section)
    for key, value in keys.items():
        cp.set(section, key, value)
with open(path, "w") as fh:
    cp.write(fh, space_around_delimiters=False)
INI_PY
echo "Settled Mudlet's first-run prompts in $MUDLET_INI"

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
