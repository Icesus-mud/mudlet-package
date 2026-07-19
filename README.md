# Icesus Mudlet package

Official Mudlet package for [Icesus MUD](https://icesus.org). A
GMCP-driven HUD that gives you vitals, identity, casting, cooldowns,
status effects, an enemy panel, a channel feed, and a location/exits
row — without writing your own triggers.

## Install

**One-liner — paste into Mudlet's command line:**

```
lua installPackage("https://github.com/Icesus-mud/mudlet-package/releases/latest/download/Icesus.mpackage")
```

Mudlet downloads the latest release and installs it in place. Connect
to `icesus.org` (port `4443` TLS, or `4000` plain) and you're done.

**GUI path** (same result, more clicks):

1. Download
   [`Icesus.mpackage`](https://github.com/Icesus-mud/mudlet-package/releases/latest)
   from the latest release.
2. In Mudlet: `Toolbox → Package Manager → Install`, point at the file.

**Conflicts handled automatically.** On first install, the package
removes Mudlet's bundled `generic_mapper` if present — that script
maps via title/exits heuristics and would fight the Icesus mapper
for the same Mudlet room IDs.

**Auto-updates.** Once installed, the package checks GitHub on each
profile load and re-installs itself if a newer version is published.
You'll see `Icesus update available: vX.Y.Z (you have vA.B.C).
Installing…` in the main console — no action required, the new build
slots in without a restart. To opt out, set
`icesus.config.autoUpdate = false` in your own scripts before the
package loads.

The package emits a green `Icesus v1.0.x ready.` line on load.
If you don't see vitals updating, the most likely cause is GMCP not
being negotiated — make sure GMCP is enabled in your profile settings.

## What's in the HUD

**Top banner** (above the main console)
- **Identity row** — name, level, race, guild from `Char.Base`.
- **Carry summary** — money, divine favor, carry weight % from
  `Char.Status`.
- **EXP gauge** — full-width forest-green bar with current EXP and
  percent-to-next. At level 100 (cap), it switches to tracking
  progress toward your next advancement point.

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

## Mapper

Press **F11** to open Mudlet's standalone mapper window. The package
drives it from `Room.Info`: as you walk, rooms are added, exits are
linked, and overworld grid rooms land at their server-provided
coordinates. No trigger-writing required.

What's plumbed in:

- **Rooms.** Each server room ships a stable 8-char hex `id`; the
  package keeps a hex → Mudlet-int mapping in
  `<profile>/Icesus.idmap.lua` so room numbering survives reconnects.
- **Exits.** Cardinal exits (`n/ne/e/se/s/sw/w/nw/up/down/in/out`) use
  Mudlet's normal exit lines; non-cardinal commands like
  `enter shop` become special exits. Shrouded or dynamic
  destinations render as direction stubs — you see the option without
  learning the target.
- **Outworld.** Server ships absolute `(x, y)` for grid tiles; placed
  with Mudlet's geographic convention (north is up). The first
  coord-bearing tile in an area auto-flips it to `setGridMode` so the
  overworld renders as a pixel map.
- **Terrain palette.** Outworld tiles paint with the pinkfish
  classic 16-color palette from `Room.Info.terrain`: road (`#`,
  brown), path (`.`, light gray), water (`~`, blue), swamp (`s`,
  red), mountain (`^`, dark gray); forest is plain green,
  plains is yellow, ice is cyan. The grid view ends up reading
  like a tiny ASCII overworld.
- **Indoor layout.** Server doesn't ship coords for indoor rooms.
  The package anchors each unplaced room near the last room you
  visited and scans outward for a free slot per-area, so buildings
  entered via `enter shop` / `enter house` scatter near their
  entrances instead of all piling up at `(0,0,0)`. Walking inside a
  building expands cardinally as normal.
- **Mapper-hostile rooms** (the `/void/` rifts, pre-nether) are
  silently skipped — those rooms don't pollute the map.
- **Persistence.** The map saves to `<profile>/Icesus.map.dat`; see
  [Save modes](#save-modes) below for exactly when. Reconnect and
  your map is right back.
- **Deleted a room by accident?** Just walk back into it. The mapper
  re-adds it and rewires the exits of the surrounding rooms as you
  pass back through — no `mapper reset` needed.

### Save modes

By default (`auto`) the mapper saves itself: changes flush to disk
the next time you go quiet — never mid-walk or mid-fight, so a big
map never stutters the client — with a hard 300-second ceiling so a
long unbroken session still gets flushed eventually. Switch to
`manual` and the timer goes away entirely: you decide when to save,
and a console reminder (at most once every 15 minutes, and only
while you're idle and out of combat) nags you if changes have been
sitting unsaved for a while. Either way the map is always saved when
you close the profile, disconnect, or the package updates — the only
real risk in manual mode is losing unsaved rooms to a Mudlet crash.

Switch modes with:

```
mapper autosave     (show the current mode)
mapper autosave on  (switch to auto, the default)
mapper autosave off (switch to manual)
```

`mapper save` flushes immediately in either mode. The location row
also grows two small controls at its right edge: a badge reading
`map saved` or `map: N unsaved` (click to save now), and a `save:
auto|manual` pill (click to toggle the mode). The chosen mode is
remembered across sessions in `Icesus.settings.lua`, a file separate
from the map/idmap, so `mapper reset` never resets it.

### Map integrity, backups, and restore

Both map files are written atomically: each save goes to a sidecar
file first, is validated, and only then renamed over the live copy —
a crash mid-save can never corrupt the map on disk. On top of that,
the mapper keeps rolling **backups of the map and room-ID table as a
pair** (Mudlet's own map backups don't cover the idmap, and one file
is useless without the other) in `<profile>/Icesus.backup/`. A pair
is snapshotted on the first save of each session, then at most once
an hour, and every time you run `mapper save` explicitly — so an
explicit save doubles as a manual restore point. Retention is
tiered: the five most recent pairs are kept, plus the first pair of
each of the last seven days — so however many backups a hectic
session burns through, yesterday's opening state always survives.

```
mapper restore      (list available backup pairs)
mapper restore N    (roll back to pair N; 1 = most recent)
```

A restore is never destructive: the pair it replaces is set aside as
`.bad-<timestamp>` files in the profile directory.

The map load itself is guarded twice. First, the package no longer
reloads its map file when Mudlet has already auto-loaded the profile
map at startup (the normal case): reloading a `.dat` over thousands
of live rooms makes the engine tear them down one at a time, which
freezes Mudlet for minutes at login and looks exactly like a crash —
this was the "Mudlet crashes when I connect and only deleting the
map files fixes it" bug. Second, a crash-loop sentinel detects that
the previous session died while the map was loading; when that
happens the map file is skipped for one session so you can get back
into the game, your files stay untouched on disk, and the console
tells you — walk on to rebuild as you go, or `mapper restore` if the
file itself is at fault. No more deleting map files by hand.

### Outworld mapping modes

The outworld grid is where a map gets big: on a mature map it holds
95%+ of the rooms, all in one giant gridmode area — which is also
what makes engine-side map operations slow. If you don't need the
full pixel map, thin it out:

```
mapper outworld          (show the current mode)
mapper outworld full     (map every tile — the default)
mapper outworld roads    (only road/path tiles: a lean ridable atlas)
mapper outworld off      (add no outworld tiles at all)
```

Indoor zones always map normally. The modes only gate *new* tiles:
anything already mapped stays on the map and the view still recenters
on it as you ride. In `roads` mode neighbouring tiles are no longer
pre-created (that 8-per-tile fan-out is most of the map's bulk), and
adjacent road tiles link both ways as you ride them. To shrink an
already-large map, pick a mode and then `mapper reset` to rebuild
lean from scratch — on a big map the reset itself can freeze Mudlet
for a minute or two; let it finish. The setting persists across
sessions and survives `mapper reset`.

### Pausing the mapper

If the mapper starts misbehaving mid-session — recentering wrong,
wiring bad exits — you don't have to nuke the map to make it stop.
`mapper off` pauses tracking: incoming `Room.Info` packets are
ignored entirely, so no rooms are created, no exits rewired, and no
recentering happens, while the map and any saved files stay exactly
as they are. `mapper on` resumes tracking (take a step afterward to
resync). Unlike `mapper reset` below, this is fully non-destructive —
use it first, and reach for `reset` only if the map itself is
actually broken. The state persists across sessions in
`Icesus.settings.lua`, same as the save mode, and shows on the HUD
badge as `map: off` in red.

If the map gets visually corrupted — most often after upgrading from
a pre-v1.0.5 build where rooms were placed upside-down — type:

```
mapper reset
```

That wipes the saved map and ID table; the next room you enter starts
a fresh graph. The reset is per-profile, so different characters keep
their own maps. Backup pairs in `Icesus.backup/` survive a reset, so
`mapper restore` can undo one that turns out to be a mistake.

## Resetting and reinstalling

If the HUD looks frozen after a link-death or a long stretch of bad
connection — gauges blank, channels silent, momentum buttons stuck —
you can reinitialize the package without restarting Mudlet. Paste
into the command line:

```
lua icesus.install()
```

`install()` is idempotent: it tears down every event handler, mapper
hook, and HUD widget the package owns, then builds them fresh and
re-subscribes to GMCP. The next packet from the server repopulates
the displays. Safe to run any time; the map and saved settings are
left alone.

For map-specific corruption (rooms upside-down, exits pointing
nowhere), use [`mapper reset`](#mapper) instead — it wipes only the
map state.

### Manual uninstall and reinstall

If a reinit doesn't clear it, or you want a completely clean slate:

1. Open `Toolbox → Package Manager` in Mudlet.
2. Select `Icesus` in the list and click `Uninstall`.
3. Reinstall with the one-liner from the top of this README:
   ```
   lua installPackage("https://github.com/Icesus-mud/mudlet-package/releases/latest/download/Icesus.mpackage")
   ```

Uninstall removes the package's scripts, triggers, and aliases but
leaves your saved map (`<profile>/Icesus.map.dat`) and room-ID table
(`<profile>/Icesus.idmap.lua`) in place, so reinstall picks up where
you left off. To start the mapper from zero too, delete those two
files from your Mudlet profile directory before reinstalling.

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
covers `Comm.Channel.Tell` and `Comm.Channel.Text`. `Room 1` feeds
both the location/exits row and the F11 mapper (`Room.Info` carries
the `id`, `exits`, and `coords` that the mapper reads).

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
2. **HUD minimap panel** — the F11 mapper already works; an embedded
   Geyser miniconsole tied to the same map (or rendering the
   LOS-visible grid alongside it) would keep cartography visible
   without juggling windows.
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
