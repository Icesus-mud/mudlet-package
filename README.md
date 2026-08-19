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
slots in without a restart. Your own settings and customisations
survive it; see [Customising](#customising). To opt out, put
`config = { autoUpdate = false }` in `Icesus.user.lua`.

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
reloads its map file when Mudlet has already auto-loaded the same map
at startup (the normal case): reloading a `.dat` over thousands of
live rooms makes the engine tear them down one at a time, which
freezes Mudlet for minutes at login and looks exactly like a crash —
this was the "Mudlet crashes when I connect and only deleting the
map files fixes it" bug. Mudlet keeps its own copy of the map and
writes it on its own schedule, so after a hard crash that copy can be
older than `Icesus.map.dat`; the package counts how much of the map
is actually there before accepting it, and reloads from its own file
if rooms are missing rather than quietly dropping them.

Second, a crash-loop sentinel detects that the previous session died
while the map was loading; when that happens the map file is skipped
for one session so you can get back into the game, and the console
tells you. If Mudlet's own map came up fine you simply carry on. If
it didn't, the map and ID table are set aside as `.bad-*` files and
you start with a clean slate — walk on to rebuild as you go, or
`mapper restore` to roll back to a backup. Nothing is deleted either
way, and no more deleting map files by hand.

### Outworld mapping modes

The outworld grid is where a map gets big: on a mature map it holds
95%+ of the rooms, all in one giant gridmode area — which is also
what makes engine-side map operations slow. If you don't need the
full pixel map, thin it out:

```
mapper outworld          (show the current mode)
mapper outworld full     (map every tile — the default)
mapper outworld roads    (roads, gates and landmarks: a lean atlas)
mapper outworld off      (add no outworld tiles at all)
```

Indoor zones always map normally. On tiles the mode skips, an
invisible cursor cell anchors the view to your grid position —
Mudlet's own player marker shows where you are, nothing extra is
drawn, and the cursor disappears when you switch back to `full`.

The two lean modes treat existing tiles differently. Tiles properly
mapped back in `full` mode always keep their room — the modes only
stop the map from growing. `roads` additionally prunes *Default
Area strays* (ghost rooms pre-created by older versions, never
assigned an area) as you ride over them, so the leftover outline
cleans itself up along your routes. `off` is a strict freeze:
nothing is added and nothing is removed. In `roads` mode neighbouring
tiles are no longer pre-created — that 8-per-tile fan-out is most of
the map's bulk. Exits are only ever drawn from the room whose data
the server just sent, so a road links up fully once you have ridden
it in both directions.

What `roads` keeps is defined by exclusion, on purpose: only the
recognised bulk-fill terrains (forest, plains, water, swamp,
mountain, ice, badlands, ashlands) with nothing but plain cardinal
exits are skipped. Roads and paths, mine entrances (`?`), province
and city buildings (`c`, `O`), tiles with unknown terrain codes, and
any tile with a
special exit (it leads somewhere) are all kept — so landmark tiles
survive even when the server labels them with codes this package has
never seen. Unknown short codes are also drawn as the room glyph,
mirroring the game's own overhead map. To shrink an already-large
map, pick a mode and then `mapper reset` to rebuild lean from
scratch — on a big map the reset itself can freeze Mudlet for a
minute or two; let it finish. The setting persists across sessions
and survives `mapper reset`.

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

## Customising

A new release reinstalls the package, so anything you change inside its
own script is gone with the next update. Two files in your Mudlet
profile directory are yours instead — install, update, uninstall and
`mapper reset` all leave them alone:

- **`Icesus.user.lua`** — data. Colours, fonts, text sizes, which side
  the column sits on, how much scrollback the chat panel keeps.
- **`Icesus.custom.lua`** — script. Everything else, including
  replacing what the package does with your own code.

Both sit next to your map, in Mudlet's profile directory
(`lua getMudletHomeDir()` prints the path). Neither one can hurt your
map or your map settings: if a file has a mistake in it the package says
so and carries on with its own defaults.

### The short version

```
hud                    what is set right now, and where it came from
hud side left|right    move the combat and comms column
hud font <name>        set the HUD font (hud font default to undo)
hud chatsize <n>       channel feed text size
hud example            write a starter Icesus.user.lua
hud reload             re-read both files after an edit, no relog
hud reset              forget what `hud` set; your files stay
```

Start with `hud example`. It writes an `Icesus.user.lua` with every
setting present and commented out, so customising is a matter of
deleting `--` and running `hud reload`. It never overwrites a file you
already have.

### Icesus.user.lua

Return one table. Anything you leave out keeps the package default, and
deleting a line later really does go back to that default.

```lua
return {
  hudSide   = "left",
  fontStack = '"Fira Code", "DejaVu Sans Mono", monospace',

  fontSizes = { channels = 11, location = 12 },

  config = {
    borderRight  = 420,
    channelTimes = false,
    autoUpdate   = true,
  },

  chatStyle = {
    channel    = "SpringGreen",
    talker     = "khaki",
    text       = "wheat",
    perChannel = { newbie = "SpringGreen", sales = "grey" },
  },

  palette = {
    ice    = "#a5f3fc",
    hpGrad = { "#7f1d1d", "#ef4444" },
  },

  effectStyles = {
    poisoned = { fg = "#4ade80", bg = "rgba(74,222,128,0.18)",
                 bd = "rgba(74,222,128,0.40)" },
  },
}
```

| Section | Keys |
| --- | --- |
| top level | `hudSide` (`"left"` / `"right"`), `fontStack` |
| `config` | `hudSide`, `autoUpdate`, `borderTop`, `borderRight`, `borderBottom`, `channelLines`, `channelTimes`, `expMaxW` |
| `fontSizes` | `identity`, `carry`, `exp`, `location`, `mapSave`, `vitals`, `momentum`, `cast`, `badges`, `enemy`, `channels` |
| `chatStyle` | `time`, `channel`, `tell`, `speech`, `emote`, `talker`, `selfTalker`, `text`, `perChannel` |
| `palette` | surfaces: `bgDeep`, `bgMain`, `bgPanel`, `bgInput`, `border`, `borderBright` · text: `text`, `textDim`, `textBright` · accents: `ice`, `iceBright`, `iceGlow`, `green`, `red`, `amber`, `cyan` · gauge gradients, each a `{ from, to }` pair: `hpGrad`, `hpGradC` (critical), `spGrad`, `epGrad`, `pspGrad`, `expGrad`, `castGrad` |
| `effectStyles` | one entry per effect name, each `{ fg = .., bg = .., bd = .. }`; new names are allowed, not just the ones shipped |

Colours are Mudlet colour names in `chatStyle` (`lua showColors()`
prints every name you can use) and CSS colours in `palette` and
`effectStyles` — `#7dd3fc`, or `rgba(125,211,252,0.25)` when you want
transparency. `chatStyle.text = ""` leaves the server's own colours
alone, which is the default.

Fonts are whatever your system has installed, in preference order;
Mudlet falls through the list until one exists. `lua getAvailableFonts()`
prints what you can choose from.

Get a key wrong and the package tells you which line it ignored, after
the ready banner and again under `hud`. It never silently drops a typo.

Data only in this file: no Mudlet function calls, no `if` on game
state. That's what the other file is for.

**If you make the HUD unreadable**, in rising order of bluntness:
`hud reset` forgets anything the `hud` command set; commenting the line
out and running `hud reload` undoes one setting from the file; and
deleting `Icesus.user.lua` (then `hud reload`) puts everything back to
the shipped look. None of it touches your map.

### Icesus.custom.lua

A plain Lua script, run before the HUD is built, with the whole Mudlet
API and the `icesus` table in scope. Three things it can do that the
data file can't:

**Replace what the package does.** Every GMCP handler is looked up by
name when its event fires, so assigning over one takes effect
immediately and survives updates — `icesus.onCommText`,
`onCommTell`, `onRoomSpeech`, `onBase`, `onVitals`, `onMaxstats`,
`onStatus`, `onCasting`, `onCooldowns`, `onEnemyDeath`, `onRoomInfo`.

**Reshape the HUD.** Define `icesus.onHudReady()` and it runs at the
end of every HUD build, when the widgets exist and are styled. This is
where you move things, hide things, or add your own. Every widget is a
Geyser object under `icesus.hud`: `banner`, `identityLabel`,
`carryLabel`, `expGauge`, `bottom`, `hp`, `sp`, `ep`, `psp`,
`locationLabel`, `mapSaveBadge`, `mapModeBtn`, `right`, `momentumBtn`,
`specialMomentumBtn`, `castGauge`, `effectsRow`, `cooldownsRow`,
`enemyLabel`, `channels`.

**Change the defaults in code**, the same keys as the data file, for
anything you want computed rather than written out.

Worked example — the chat feed on the left of the main window, in your
own colours, with the rest of the HUD where it was:

```lua
local CHAT_W = 320

icesus.onHudReady = function()
  setBorderLeft(CHAT_W)
  if not icesus.myChat then
    icesus.myChat = Geyser.MiniConsole:new({
      name = "myChat",
      x = 8, y = icesus.config.borderTop + 8,
      width = CHAT_W - 16,
      height = "100%-" .. (icesus.config.borderTop + 80),
      autoWrap = true, fontSize = 11, color = "#0c0e1a",
    })
  end
  icesus.myChat:show()
  icesus.hud.channels:hide()      -- the package's own panel
end

local function mine(line)
  if icesus.myChat then icesus.myChat:cecho(line .. "\n") end
end

icesus.onCommText = function()
  local p = gmcp.Comm and gmcp.Comm.Channel and gmcp.Comm.Channel.Text
  if not p then return end
  mine(string.format("<SpringGreen>[%s]<reset> <khaki>%s<reset>: %s",
    tostring(p.channel or "?"), tostring(p.talker or ""),
    tostring(p.text or "")))
end
```

If the file has an error the package says so and carries on with its
own defaults — a broken customisation never costs you the HUD.

### From a package of your own

Prefer to keep your work in a Mudlet package rather than a loose file?
The package raises `icesus.hudReady` at the end of every HUD build:

```lua
registerAnonymousEventHandler("icesus.hudReady", function()
  setFont("icesus.channels", "Fira Code")
  setFontSize("icesus.channels", 11)
end)
```

That fires on the first build, on every rebuild, and after an update
reinstalls the package, so there is nothing to re-apply by hand.

### What wins

Weakest to strongest:

1. the package defaults
2. what the `hud` command has saved (in `Icesus.settings.lua`)
3. `Icesus.user.lua`
4. `Icesus.custom.lua`

So a setting written in a file beats the same setting typed as a
command — and `hud side left` will tell you outright when
`Icesus.user.lua` is pinning the side, rather than appearing to do
nothing.

Two honest limits. The combat and comms panels move as one column, not
individually: `hud side` moves all of them, and pulling a single panel
out means building your own, as in the example above. And panel order
within the column is fixed — reordering means `move()`ing the widgets
in `onHudReady`.

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
5. **Theme switcher** — light / dark / high-contrast. Every colour is
   already overridable per player (see [Customising](#customising));
   what's missing is a set of named themes and a command to switch
   between them.
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
