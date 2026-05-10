# Icesus Mudlet package

Official Mudlet package for [Icesus MUD](https://icesus.org). A GMCP-driven
HUD that gives you vitals gauges, an enemy panel, and a channel feed
without writing your own triggers.

This is **v0.1** — the first feedback release. It ships a small core
that's strictly better than vanilla Mudlet; everything else (cooldowns,
casting, party, outworld minimap, sound, themes) is open for contribution.

## What's in v0.2

- **Vitals gauges** — HP / SP / EP, fed by `Char.Vitals` + `Char.Maxstats`.
- **Monster health bars** — one bar per opponent from
  `Char.Status.enemies`, using the server's 12-tier shape buckets so the
  bar can't pretend to know more than `consider` would tell you. Cleared
  by `Char.EnemyDeath`.
- **Momentum buttons** — clickable "use momentum" / "use special
  momentum" labels that light up when `Char.Status.momentum` /
  `special_momentum` are set, and send `use <name>` on click.
- **Casting / busy bar** — fills over `Char.Casting.progress / cps` while
  a spell or skill is in progress; goes empty on completion or
  interruption.
- **Status effects strip** — badges for every entry in
  `Char.Status.effects` (bleeding, stunned, etc.).
- **Channel feed** — every channel + say + tell + whisper from
  `Comm.Channel` echoed into a side miniconsole, with timestamps.

The HUD reserves 320 px on the right and 36 px on the bottom; the main
game window keeps everything else and renders untouched, so existing
prompts and scripts still work.

## Install

**Easy path — Mudlet GUI:**

1. Download
   [`Icesus.mpackage`](https://github.com/Icesus-mud/mudlet-package/releases/latest)
   from the latest release.
2. In Mudlet: `Toolbox → Package Manager → Install`, point at the file.
3. Connect to `icesus.org` (port `4443` TLS, or `4000` plain).

**Direct from this repo (no release yet):** clone and import
`package/Icesus.xml` via Mudlet's Package Manager → Install. That
imports the script directly without going through `.mpackage`.

The package emits a green `Icesus package v0.1.0 ready.` line on load.
If you don't see vitals updating, the most likely cause is GMCP not
being negotiated — make sure GMCP is enabled in your profile settings.

## Building

```sh
./build/build.sh
```

Produces `dist/Icesus.mpackage`. Requires Python 3 only.

## Headless Mudlet for development

A maintainer or contributor on a Linux box can run Mudlet under Xvfb,
install the just-built package, and screenshot the result without
touching a real desktop. See [`tools/mudlet-dev/README.md`](tools/mudlet-dev/README.md).

```sh
./tools/mudlet-dev/install.sh      # one-time: deps + Mudlet AppImage
./build/build.sh && ./tools/mudlet-dev/run.sh dev
# → tools/mudlet-dev/screenshots/latest.png
```

This is for layout iteration and regression checks. Final QA still
happens on real Mudlet on a real desktop.

## How it works

There's one Lua script (`package/Icesus.xml` → `icesus.core`) under a
single `icesus` global table. It registers anonymous event handlers for
the GMCP packages it cares about, builds a Geyser-based HUD on load,
and tears it all down on uninstall. Hot-reload is supported: editing
the script in Mudlet's IDE replaces the running HUD cleanly.

GMCP packages subscribed via `Core.Supports.Set`:

```
["Char 1", "Char.Vitals 1", "Comm 1", "Room 1"]
```

`Char 1` covers `Char.Vitals`, `Char.Maxstats`, `Char.Status` (enemies,
position, conditions, money, EXP, …), `Char.Casting`, `Char.Cooldowns`,
`Char.ExpGain`, `Char.EnemyDeath`. `Comm 1` covers `Comm.Channel`.
`Room 1` is reserved for the upcoming room/exit panel and minimap.

The full GMCP spec lives in the mudlib at `doc/help/gmcp.doc`; a
public mirror is in `docs/gmcp-reference.md` here.

## Roadmap

The next features in priority order, all of them welcome PRs:

1. **Channel gagging from the main window** — currently channels are
   mirrored, not routed. A trigger group that gags `Comm.Channel`-paired
   text lines would let players use the side console exclusively.
2. **Cooldown panel** — `Char.Cooldowns`, mm:ss tickers, client-side.
3. **Identity row** — name / title / level / money / carry / conditions
   from `Char.Base` + `Char.Status`.
4. **Room panel** — name + exits as clickable buttons, from `Room.Info`.
5. **Outworld minimap** — Geyser miniconsole rendering the LOS-visible
   grid. Render-only first, fog-of-war later.
6. **Party panel** — `Party.Info` with HP bars per member.
7. **Sound pack** — level-up, channel mention, death, combat-enter cues.
8. **Theme switcher** — light / dark / high-contrast.
9. **`Client.Triggers` / `Client.Hotkeys` GMCP sync** — triggers and
   hotkeys roam between the web client and Mudlet.

See `docs/design.md` for the longer-term plan.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Short version: open an issue
with what you want to add, then PR. Style for Lua is "match what's
already there"; XML is hand-edited, so keep it minimal and readable.

## License

MIT — see [LICENSE](LICENSE).
