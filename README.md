# Icesus Mudlet package

Official Mudlet package for [Icesus MUD](https://icesus.org). A
GMCP-driven HUD that gives you vitals, identity, casting, cooldowns,
status effects, an enemy panel, a channel feed, and a location/exits
row — without writing your own triggers.

## Install

**Easy path — Mudlet GUI:**

1. Download
   [`Icesus.mpackage`](https://github.com/Icesus-mud/mudlet-package/releases/latest)
   from the latest release.
2. In Mudlet: `Toolbox → Package Manager → Install`, point at the file.
3. Connect to `icesus.org` (port `4443` TLS, or `4000` plain).

**Direct from this repo:** clone and import `package/Icesus.xml` via
Mudlet's Package Manager → Install. That imports the script directly
without going through `.mpackage`.

The package emits a green `Icesus package v1.0.0 ready.` line on load.
If you don't see vitals updating, the most likely cause is GMCP not
being negotiated — make sure GMCP is enabled in your profile settings.

## What's in the HUD

**Top banner** (above the main console)
- **Identity row** — name, level, race, guild from `Char.Base`.
- **Carry summary** — money, divine favor, carry weight % from
  `Char.Status`.
- **EXP gauge** — full-width forest-green bar with current EXP and
  percent-to-next.

**Bottom strip** (below the main console, above the command line)
- **Vitals** — HP / SP / EP gauges, plus PSP if your character has any.
  Slim glass pills with vertical gradient. HP pulses red when below 25 %.
- **Location & exits** — current room, area, a `SAFE` chip when
  applicable, and the open exits as short cyan letters (`n e s w u`).

**Right column** (combat & comms)
- **Momentum buttons** — clickable `BERSERK` / `EXECUTE`-style labels
  that light up when `Char.Status.momentum` /
  `Char.Status.special_momentum` are set; click sends `use <name>`.
- **Casting / busy bar** — fills over `Char.Casting.progress / cps`
  while a spell or skill runs. Repaints amber for non-spell `busy`
  activities (camping, smelting, fishing, …) so every wait gets a
  visual signal.
- **Status effects strip** — colour-coded badges per effect
  (bleeding red, stunned amber, poisoned green, burning orange,
  frozen ice, blessed gold, cursed violet, death-sickness purple,
  …) from `Char.Status.effects`.
- **Cooldowns row** — pills with name + seconds, gradient red → cyan →
  green as the cooldown ticks down. Truncates names and drops the
  seconds suffix when many are active so the row never clips.
- **Enemy panel** — one bar per opponent from `Char.Status.enemies`,
  using the server's 12-tier shape buckets so the bar can't pretend
  to know more than `consider` would tell you. Cleared by
  `Char.EnemyDeath`.
- **Channel feed** — every channel + tell + whisper from
  `Comm.Channel` echoed into a side miniconsole, with timestamps.

The HUD reserves 360 px on the right, 92 px on top (banner), and 64 px
on the bottom (vitals + exits). The main console fills everything else
and renders untouched, so existing prompts and scripts still work.

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
./build/build.sh && ./tools/mudlet-dev/run.sh fake
# → tools/mudlet-dev/screenshots/latest.png
```

The `fake` mode runs against a small Python GMCP replayer
(`tools/mudlet-dev/fake_server.py`) that streams a fixture of every
package. This is for layout iteration and regression checks — final
QA still happens on real Mudlet on a real desktop.

## How it works

There's one Lua script (`package/Icesus.xml` → `icesus.core`) under a
single `icesus` global table. It registers anonymous event handlers
for the GMCP packages it cares about, builds a Geyser-based HUD on
load, and tears it all down on uninstall. Hot-reload is supported:
editing the script in Mudlet's IDE replaces the running HUD cleanly.

GMCP packages subscribed via `Core.Supports.Set`:

```
["Char 1", "Char.Base 1", "Char.Vitals 1", "Char.Status 1",
 "Char.Cooldowns 1", "Comm 1", "Room 1"]
```

`Char 1` covers `Char.Vitals`, `Char.Maxstats`, `Char.Casting`,
`Char.ExpGain`, `Char.EnemyDeath`. `Char.Base`, `Char.Status` and
`Char.Cooldowns` are listed explicitly even though the server's
`send_all` sends them regardless — keeps client intent visible on
the wire and survives any future server-side gating. `Comm 1`
covers `Comm.Channel`. `Room 1` feeds the location/exits row.

The full GMCP spec lives in the mudlib at `doc/help/gmcp.doc`; a
public mirror is in `docs/gmcp-reference.md` here.

## Visual language

The palette and gauge gradients are ported from the
[play.icesus.org web client](https://play.icesus.org) so the two
clients feel like siblings: cool-toned panels, ice-blue accents,
forest-green EXP, glacier-cyan cast, blood-red HP. The vitals row
uses a slim glass treatment (vertical gradient, 5 px corner radius)
that stays out of the way of the game text.

## Roadmap

The next features in priority order, all of them welcome PRs:

1. **Channel gagging from the main window** — currently channels are
   mirrored, not routed. A trigger group that gags `Comm.Channel`-paired
   text lines would let players use the side console exclusively.
2. **Outworld minimap** — Geyser miniconsole rendering the LOS-visible
   grid. Render-only first, fog-of-war later.
3. **Party panel** — `Party.Info` with HP bars per member.
4. **Sound pack** — level-up, channel mention, death, combat-enter cues.
5. **Theme switcher** — light / dark / high-contrast.
6. **`Client.Triggers` / `Client.Hotkeys` GMCP sync** — triggers and
   hotkeys roam between the web client and Mudlet.
7. **Inventory panel** — `Char.Items`, slot-equipped + carried.

See `docs/design.md` for the longer-term plan.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Short version: open an issue
with what you want to add, then PR. Style for Lua is "match what's
already there"; XML is hand-edited, so keep it minimal and readable.

## License

MIT — see [LICENSE](LICENSE).
