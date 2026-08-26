# Headless Mudlet for development

Tools for running Mudlet under Xvfb (X virtual framebuffer) on a Linux
server, installing the locally-built `.mpackage`, and screenshotting the
result. Lets us iterate on layout and rendering without a round-trip
through a real client.

What you get out of this:

- A headless Mudlet that runs as the current user.
- A `tools/mudlet-dev/run.sh dev` one-liner that builds the package,
  drops it into a clean profile, launches Mudlet, takes a screenshot,
  and shuts Mudlet down.
- A screenshot at `tools/mudlet-dev/screenshots/latest.png` that the
  current sessions's tools can read inline.

What this is **not**:

- A replacement for testing on a real Mudlet on a real desktop. Fonts,
  Qt rendering details, and OS-specific quirks differ between Linux
  Xvfb and macOS / Windows / X11-with-real-GPU. Final QA still happens
  on the maintainer's actual machine.

## One-time install

On a fresh Linux server (Ubuntu 24.04 confirmed; should work on any
modern Debian-derived system):

```sh
./tools/mudlet-dev/install.sh
```

This:

1. Installs `xvfb`, `imagemagick`, and the Qt/X11/font runtime libraries
   Mudlet needs (via `sudo apt`).
2. Downloads the latest Mudlet AppImage from GitHub Releases into
   `~/mudlet-bin/Mudlet.AppImage`.

Re-running the script is safe — it skips packages and downloads that
are already present. That also means it never *updates* Mudlet: to
pull a newer release over the top of the one you have, run it as
`MUDLET_UPDATE=1 ./tools/mudlet-dev/install.sh`. Worth doing whenever
Mudlet ships a release, since a screenshot only proves the package
works on the build sitting in `~/mudlet-bin`. Currently on **4.22.0**
(2026-07-06).

`run.sh` writes three keys into `~/.config/mudlet/Mudlet.ini` before
launching, to settle first-run dialogs that would otherwise cover the
HUD: Mudlet 4.22.0 asks whether it should own `telnet://` links (it
checks with `xdg-mime`, which a server does not have, so it asks every
time), and the updater pops an error box when its self-download
fails. Both are answered the way a throwaway headless run wants.

## Per-iteration workflow

```sh
./build/build.sh                   # build dist/Icesus.mpackage
./tools/mudlet-dev/run.sh dev      # launch headless, screenshot, exit
```

Then look at `tools/mudlet-dev/screenshots/latest.png`.

The default `run.sh dev` mode:

- Wipes any previous `icesus-dev` Mudlet profile so each run starts
  clean.
- Pre-points the profile at `icesus.org:4000` (override with
  `ICESUS_HOST` / `ICESUS_PORT`).
- Installs `dist/Icesus.mpackage` via Mudlet's CLI install path.
- Runs Mudlet under Xvfb at the resolution given by `XVFB_GEOMETRY`
  (default `1600x1000x24`).
- Takes a screenshot after `WAIT_SECONDS` (default `8`).
- Saves to `tools/mudlet-dev/screenshots/<timestamp>.png` and updates
  the `latest.png` symlink.
- Kills Mudlet.

`run.sh interactive` skips the screenshot and leaves Mudlet running so
you can drive it yourself via VNC or `xdotool`.

## Fake data for layout shots

`run.sh dev` ships an empty HUD because Mudlet doesn't auto-connect
on a fresh profile. To exercise every panel (vitals filled, enemies
populated, casting in progress, effects badges, channel feed)
without needing a live Icesus connection:

```sh
./build/build.sh
./tools/mudlet-dev/run.sh fake
```

What `fake` mode does:

1. Spawns `tools/mudlet-dev/fake_server.py` on `127.0.0.1:7878` (port
   overridable with `FAKE_PORT`). The server speaks just enough telnet
   to negotiate GMCP, then replays a JSON fixture of events as
   `IAC SB GMCP <package> <json> IAC SE` frames.
2. Builds a fake-flavoured `dist/Icesus-fake.mpackage` — same package
   plus a tiny inlined script that calls `connectToServer("127.0.0.1",
   7878)` half a second after profile load. The real package on disk
   is untouched. The fake artefact lives in `dist/` and is gitignored.
3. Launches Mudlet against that package. Mudlet dials the fake server,
   receives the fixture, the HUD renders.
4. Screenshots, then tears down Mudlet, Xvfb, and the fake server.

The default fixture is `tools/mudlet-dev/fixtures/default.json`:
populated vitals, three enemies of varying shapes, momentum +
special_momentum, mid-cast spell, two effects, three channel lines.
Override with `FAKE_FIXTURE=path/to/scenario.json`.

Add scenarios by dropping new `.json` files into `fixtures/`. Each is
an array of:

```json
{ "delay_ms": 100, "package": "Char.Vitals", "payload": { … } }
```

`delay_ms` is relative to the previous event. `package` is any GMCP
module path the package handles (`Char.Vitals`, `Char.Maxstats`,
`Char.Status`, `Char.Casting`, `Char.EnemyDeath`, `Comm.Channel`).
`payload` becomes the JSON body of the frame; field names must match
what the package reads — see `docs/gmcp-reference.md` and the actual
handlers in `package/Icesus.xml`. Mismatched field names fail
silently (gauges sit at zero, panels stay empty), so cross-check
the screenshot against expectations before declaring the fixture
correct.

## Testing player customisation

The profile directory is what `getMudletHomeDir()` returns, so the two
override files a player writes by hand can be seeded into a run:

```sh
ICESUS_USER_FILE=/tmp/Icesus.user.lua ./tools/mudlet-dev/run.sh fake
ICESUS_CUSTOM_FILE=/tmp/Icesus.custom.lua ./tools/mudlet-dev/run.sh fake
```

Each is copied into the fresh profile before Mudlet launches. Handy for
checking a layout override renders, or that a `Icesus.custom.lua`
example in the README actually works — the customisation surface is the
one part of the package where the failure mode is "silently keeps the
default", which a screenshot catches and a unit test can't.

To drive the `hud` command in a headless run, put the calls in a
`Icesus.custom.lua` behind `icesus.onHudReady` with a one-shot guard
(the command rebuilds the HUD, which fires the hook again).

## Unit tests

Two suites, both loading the real `icesus.core` chunk out of
`package/Icesus.xml` under a mocked Mudlet API. No Mudlet, no X, no
network — run them on every change:

```sh
lua5.4 tools/mudlet-dev/test_mapper.lua    # mapper, persistence, save modes
lua5.4 tools/mudlet-dev/test_user.lua      # customisation layer, hud command
```

`test_mapper.lua` mocks the map database and skips the HUD build;
`test_user.lua` mocks the widgets instead and lets `icesus.install()`
run for real. Each exits non-zero on failure.

## Connecting to live or dev

```sh
ICESUS_HOST=icesus.org ICESUS_PORT=4000 ./tools/mudlet-dev/run.sh dev
```

Live connections create a real session — be careful with which
character you log in as. For full GMCP testing without polluting the
live game, use a dedicated test character or a dev-server slot.

## Troubleshooting

- **"could not connect to display"** — Xvfb didn't come up. Look at
  `/tmp/icesus-mudlet-dev/xvfb.log`.
- **Mudlet starts but the screenshot is blank** — bump `WAIT_SECONDS`
  to 12+. Mudlet's first launch on a fresh profile auto-installs `mpkg`
  which can take a few seconds.
- **Screenshot has only the menu bar** — Mudlet didn't honour
  `--fullscreen`. The window is at its default size in the top-left.
  Workable but ugly. We can either `xdotool` to maximise, or save a
  `geometry` setting in the profile XML on first launch.
- **`mInstalledPackages` is empty after launch** — Mudlet sometimes
  loses package state on ungraceful shutdown. The harness installs
  fresh on every run for exactly this reason.
