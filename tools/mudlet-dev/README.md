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
are already present.

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

The `--no-connect` mode is useful for layout-only screenshots: the HUD
renders in its empty state. To exercise every panel (vitals filled,
enemies populated, casting in progress, effects badges showing), pass
`--fake-gmcp` and the harness will inject synthetic GMCP events into
Mudlet via `runLuaCode` after the package loads.

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
