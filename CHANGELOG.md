# Changelog

## Unreleased

- **Guild resources reach the HUD.** The server now sends the scalar a
  guild runs on — fury for firepriests, vitae for scions and water
  priests — in `Char.Vitals`, and the structured ones — templar bonds,
  scion souls, charms, piety — in a new `Char.Resources` packet. The
  package draws what a player watches mid-fight beside the vitals
  gauges: the scalar, the four bond strengths with an arrow for filling
  or draining, and the active charm. Numbers, never gauges, since none
  of these has a maximum to fill against. The strip sizes itself to its
  content, hands the gauges the rest of the row, and is absent for a
  character with nothing to show. The rest — bond load and drain, the
  soul list largest first, charm abilities, devotion to the nine —
  prints to the console on `hud guild`, or a click on the strip or the
  carry summary, after one fresh request to the server. A scalar the
  server grows later shows up with no package change. Colours live in
  `icesus.guildStyles` for `Icesus.user.lua`. Mirrors what the web
  client shipped on 2026-08-29.
- **Karma badges.** `Char.Status.karmas` has been on the wire for
  months and was dropped on the floor. The karma you spent on yourself
  — exp, luck, learning, mastery, momentum, impulse — now sits in the
  effects row after concealment, in gold and with the web client's ☯
  mark, so a `MOMENTUM` karma is not read as the momentum button.
  Restyle them all under `karma` in `effectStyles`, or one under
  `["karma exp"]`.
- **Momentum buttons say where the momentum came from.** Hover the
  button for `Momentum from mining — use chase the rich vein`. The
  source (`combat`, `mining`, `bellows`, `polish`) is
  `Char.Status.momentum_source`, another field that was already being
  sent.
- **Special exits are drawn at last.** The mapper asked Mudlet for
  `setSpecialExit`, a function Mudlet has never had — the special-exit
  family is `addSpecialExit`. Both call sites were wrapped in `pcall`,
  so the missing function raised nothing and the mapper carried on:
  every `enter shop`, `climb ladder` and `enter cave` has been silently
  dropped for as long as the mapper has existed. Reported by Direkein.
- **Rooms with special exits stop being rebuilt on every pass.** The
  prune step read the room's current special exits with
  `getSpecialExits`, which is keyed by destination room id and puts the
  commands in a table underneath. Comparing those keys against command
  names never matched, so a rebuild always concluded that everything
  had vanished and cleared and re-added the lot. It now reads
  `getSpecialExitsSwap`, which is the command-keyed one. This never
  bit anyone before, because there were no special exits to rebuild.

## v1.0.18 — 2026-08-26

- **Concealment badges.** The server now reports what you are hiding
  behind — moving silently, hiding in shadows, invisible — in
  `Char.Status.stealth`, the same three states, read from the same
  queries and in the same order as the `[ shh ]` line of
  `show effects`. They appear at the head of the effects row as
  `SILENT` / `HIDDEN` / `INVIS`, in cool colours and without the
  affliction badges' alarm palette: this is a state you switched on,
  not something happening to you. It can also lapse on its own, which
  is the point of showing it — the badge disappearing is the warning.
  Restyle them from `Icesus.user.lua` like any other badge, under
  their full names (`["hiding in shadows"] = { fg = ... }`). The web
  client shows the same three; the short labels are a concession to
  the narrower combat column. Names this build has never heard of are
  drawn as the server spells them, so a fourth state needs no update.

- **The effects row stops losing badges off its right edge.** It is a
  fixed-width label that does not wrap, so anything past the edge was
  simply not drawn — three badges was already enough to lose one, and
  concealment made three a normal number. The row now works out how
  many characters it can show, tightens its spacing, and then shortens
  the longest names (`BLEED…`) until everything fits. A wider column
  or a smaller badge font buys back the full names; both are
  `Icesus.user.lua` settings.

## v1.0.17 — 2026-08-19

- **Issue #12: rooms piling into "Default Area", and the overlaps that
  came with it.** Mudlet's `addAreaName` refuses a name that already
  exists and returns -1, and areas outlive the rooms in them —
  `deleteRoom` leaves the area behind. So any state where Mudlet still
  held the area names while the package's id table did not (a
  `mapper reset`, v1.0.16's idmap quarantine, a deleted
  `Icesus.idmap.lua`) made every `ensureArea` call fail: rooms went to
  Default Area, and because the gridmode flip is gated on a real area
  id, the outworld lost its pixel-map rendering and drew as a
  node-and-line graph with exit arrows. `ensureArea` now adopts the
  existing area via `getAreaTable` instead. That also accounts for most
  of what the report described as pre-placed neighbours: with the area
  and gridmode restored, unvisited outworld tiles render as blank grid
  cells rather than arrowed circles, and indoor neighbours go back to
  being invisible in the area view. (Reported by chosig.)

- **A reset no longer leaves the area list behind.** `mapper reset`
  deletes the areas it created once they are empty, so an empty map
  stops showing a full phone book of area names. Areas that still hold
  rooms, and any the player made themselves, are left alone.

- **Pre-placed neighbours stop landing on top of each other.** Guessing
  a room's position by offsetting from the room you are standing in is
  fine for a grid and wrong for a building: two rooms could guess the
  same cell and stack. The guess is now taken only while the cell is
  free, and a room that turns out to be in a different area than the
  neighbour who placed it claims its cell in that area on arrival —
  otherwise the next building in that area was handed the same slot.

- **Customisation that survives an update.** Every release reinstalls
  the package, which took any edit made inside its script with it —
  players who had recoloured the channel feed were re-patching after
  each update. Two files in the Mudlet profile directory are now the
  supported place for that, and install, update, uninstall and
  `mapper reset` all leave them alone. `Icesus.user.lua` returns a
  table of data overrides: `hudSide`, `fontStack`, and sections for
  `config`, `fontSizes`, `chatStyle`, `palette` and `effectStyles`.
  `Icesus.custom.lua` is a script, run before the HUD is built, for
  anything data can't express. A bad key in either file is reported by
  name after the ready banner instead of silently doing nothing, and a
  broken file never costs you the HUD. See the README's "Customising".

- **One line, once per profile, so players know any of this exists.**
  After the first ready banner: colours, fonts and which side the panels
  sit on are yours to change, type `hud`. It is a one-shot, recorded in
  `Icesus.settings.lua`, and `hud reset` does not bring it back. `hud`
  and the starter file both link the README's reference by URL rather
  than naming a file nobody can click, and point at `showColors()` and
  `getAvailableFonts()` for the values they accept.

- **`hud` command.** `hud` on its own reports what is set and which
  file it came from; `hud side left|right` moves the combat and comms
  column to either side of the main window; `hud font <name>` and
  `hud chatsize <n>` cover the two most-asked tweaks without writing
  Lua; `hud example` writes a fully commented starter
  `Icesus.user.lua`; `hud reload` re-reads both files with no relog;
  `hud reset` forgets what the command set and leaves the files. What
  `hud` saves lives in `Icesus.settings.lua` alongside the map
  settings, and loses to `Icesus.user.lua` — deliberately, and it
  says so when that happens rather than appearing to ignore you.

- **The channel feed's colours are data now.** They used to be literals
  inside the GMCP handlers, which is why recolouring meant editing the
  package. `chatStyle` covers the time stamp, channel tags, tells,
  speech, emotes, talker names, your own lines, the message body, and a
  `perChannel` map so `chat` and `sales` can differ. Per-widget font
  sizes moved out to `fontSizes` for the same reason.

- **Handlers are late-bound.** Event registration now looks each
  handler up on the `icesus` table when the event fires instead of
  capturing the function at install time, so assigning over
  `icesus.onCommText` (or any other) from your own script takes effect
  immediately, with no reinstall.

- **`icesus.hudReady`.** Raised at the end of every HUD build, with an
  `icesus.onHudReady()` callback alongside it, so tweaks that need real
  widgets have a defined moment to run — including after an update
  reinstalls the package. `icesus.rebuildHUD()` forces a rebuild after
  changing anything the HUD reads.

- **The HUD-rebuild guard no longer needs a sentinel bump.** It
  compares a signature of the script version and the layout inputs, so
  a hot upgrade, a side change or a font change all rebuild correctly
  and a new widget can't be skipped by a forgotten constant. Rebuilt
  HUDs also repaint immediately from cached state instead of showing
  placeholders until the next packet.

- **Auto-update opt-out works as documented.** `autoUpdate` is a real
  config default, so `config = { autoUpdate = false }` in
  `Icesus.user.lua` takes. The old README said to set
  `icesus.config.autoUpdate = false` "before the package loads", which
  could never work: the script reassigns `icesus.config` on load.

## v1.0.16 — 2026-08-11

- **The "Mudlet crashes when I connect" bug, and the map loss behind
  it.** Closing Mudlet cleanly and reconnecting could end with the
  client apparently hung at login, and the only way back in was
  deleting `Icesus.map.dat` and `Icesus.idmap.lua` — losing the whole
  map. Neither file was ever corrupt. Mudlet auto-loads the profile's
  own map before any script runs, and the package then called
  `loadMap()` on top of it; on a 12.7k-room map that reload froze the
  UI for minutes. Players force-quit the unresponsive window, and the
  broken empty map got saved over the good one. The package now checks
  whether the engine already holds its rooms and skips the redundant
  reload, which removes the freeze entirely. (Diagnosis and fix by
  Steve De Jongh / sdejongh / Arthr, PR #10.)

- **`mapper outworld full|roads|off`.** The outworld grid is where a
  map gets big: on a mature map it is 95%+ of the rooms, all in one
  gridmode area, which is also what makes engine-side map operations
  slow. `roads` keeps the road and path network plus landmarks and
  stops pre-creating the 8-neighbour fan-out around every tile;
  `off` adds no outworld tiles at all. Indoor zones always map
  normally. On a skipped tile an invisible cursor cell keeps the view
  tracking your position, so riding across unmapped terrain still
  follows you. The setting persists and survives `mapper reset`.
  (Arthr, PR #10.)

- **Both map files are now written atomically, backed up as a pair,
  and restorable.** Each save goes to a sidecar, is validated, and is
  renamed over the live file, so a crash mid-save cannot truncate
  anything. Map and ID table are snapshotted together in
  `Icesus.backup/` — Mudlet's own map backups cannot recover a thing
  without the ID table that names those rooms — on the first save of a
  session, hourly after that, and on every explicit `mapper save`.
  Retention keeps the five most recent pairs plus the first pair of
  each of the last seven days, so a hectic session cannot rotate away
  the last known-good state. `mapper restore` lists them and rolls
  back. A save is also refused outright if the in-memory map looks
  wiped, which is the exact write that used to destroy maps, and the
  stale-map auto-reset now sets the old pair aside as `.bad-*` instead
  of deleting it. Only an explicit `mapper reset` still deletes.
  (Arthr, PR #10.)

- **The map Mudlet already has is now checked, not assumed.** Mudlet
  writes its own copy of the map when the profile closes, while the
  package writes on its own cadence, so a hard crash leaves the
  auto-loaded map behind `Icesus.map.dat`. Sampling a few rooms only
  proves that map is *ours*, not that it is current. The package now
  counts how much of the ID table is actually live and reloads from
  its own file when the engine is short, instead of silently running a
  session on an older map and then writing that shortfall back over
  the good file. A single room deleted in Mudlet's map editor is
  normal wear and does not trigger a reload.

- **A recovery boot leaves the map writable.** When the crash sentinel
  fires, the map file is skipped for one session and the console tells
  you to walk on and rebuild. If the engine also came up empty, the
  orphaned ID table used to make every save refuse for the rest of the
  session, so that whole session of mapping went nowhere. The pair is
  now snapshotted and set aside, and you get a clean slate that
  actually saves. `mapper restore` still has the old map.

- **`roads` mode no longer invents exits.** Linking a neighbour's
  return exit because this room has a forward one assumes the outworld
  grid is symmetric, and it is not: ride into a river tile and the
  current stops you stepping back out. Roughly 2.7% of sampled
  outworld links are one-way, and the unchanged-room fast path kept
  the invented exit forever, so Mudlet's pathfinder would route
  through a door the game does not have. A road now links up fully
  once you have ridden it in both directions.

- **Badlands and ashlands are recognised as bulk terrain.** They are
  walkable fill, about 23k tiles between them, and used to reach the
  client with no terrain name at all, which the "unknown means
  interesting" rule reads as a landmark worth keeping. `roads` mode
  was keeping about 3% of the world's land it exists to drop. Needs
  the matching server change, which is already live.

- **Exits that pointed at rooms which do not exist are fixed
  server-side.** Some areas write exit destinations in a form the room
  itself never uses — no leading slash, a doubled separator, or a
  trailing `.c` — and the server hashed that raw string into the room
  id it sent you. The id never matched the room you actually walked
  into, so the mapper drew a phantom next door and then drew the real
  room separately. Shanty Town was the worst of it and was effectively
  unmappable. The server now hashes the canonical path, so the ids
  agree. Note that phantoms already sitting in your saved map will not
  clean themselves up; they simply stop being created. Delete them in
  Mudlet's map editor, or `mapper reset` and rewalk. (Reported by
  Chosig, mudlet-package#3.)

- **Pre-created outworld neighbours inherit the current area** instead
  of collecting in Mudlet's "Default Area" as a ghost outline of
  everywhere you have been, and arriving on an older stray repairs it
  rather than flipping the mapper view. Indoor zones keep the previous
  behaviour. `roads` mode also prunes those strays as you ride over
  them. (Arthr, PR #10.)

## v1.0.15 — 2026-07-04

- **Manual or automatic map saving.** On a really big accumulated map
  even v1.0.14's idle-deferred flush can freeze Mudlet for a few
  seconds — Icesus' world simply outgrows what Mudlet's `saveMap`
  handles gracefully. The save cadence is now the player's choice:
  `auto` (default) keeps the idle-deferred flush, `manual` never saves
  on a timer — you save via `mapper save` or the new HUD badge, with a
  console reminder at most once per 15 minutes while idle and out of
  combat. Two controls sit at the right end of the location row: a
  `map saved` / `map: N unsaved` badge (click to save now) and a
  `save: auto|manual` pill (click to toggle). Both modes still flush
  on exit, disconnect and package teardown; a new
  `sysDisconnectionEvent` hook covers network drops and server reboots
  too. The choice persists in `Icesus.settings.lua`, deliberately a
  separate file from the map state so `mapper reset` keeps it.
  (PR #8, Steve De Jongh / sdejongh / Arthr.)
- **`mapper on|off` — non-destructive pause.** `mapper off` freezes
  the map exactly as it is: `Room.Info` is ignored, so nothing is
  added, rewired or recentered, and the saved files stay put. `mapper
  on` resumes. The kill switch for a misbehaving mapper mid-session
  without reaching for the destructive `mapper reset`. Shows as a red
  `map: off` on the HUD badge; persists across sessions. (PR #8,
  Steve De Jongh / sdejongh / Arthr.)
- **Rooms deleted in the map editor come back.** Accidentally deleting
  a room left it un-recreatable (#7): the idmap still held its old
  integer id, so every rebuild aimed `set*` calls at a room that
  wasn't there, and the unchanged-room fast path skipped it — and its
  neighbours — forever, leaving severed exits. Walking back into the
  deleted room now re-adds it under its old id, rebuilds it in full,
  and invalidates the neighbours' cached signatures so their exits
  rewire as you walk back through.
- **Channel feed: raw colour codes stripped.** Some server-side
  composers (the hunt event's warden chatter, for one) leak raw
  pinkfish tokens like `%^BOLD%^` into GMCP chat text; the chat panel
  now strips them defensively before rendering.
  (Icesus-mud/issues#667)
- **Hot-upgrade self-heal.** `setupHUD` now rebuilds a stale HUD
  instead of early-returning on it, so widgets introduced by a new
  version actually appear after an auto-update whose teardown died
  silently. (PR #8.)
- Test harness: `tools/mudlet-dev/test_mapper.lua` grew from 17 to 62
  checks — save modes, reminder throttle, pause toggle, settings
  persistence across `mapper reset`, deleted-room recovery, and the
  colour-code strip.

## v1.0.14 — 2026-06-15

- **Fluid walking and combat — the mapper no longer saves at a bad
  time.** Two compounding costs were making the package feel slow on
  well-travelled profiles (issue #4, plus in-combat lag reports):
  - `onRoomInfo` rebuilt the room on *every* `Room.Info` — re-applying
    `setRoomName`/`setExit`/`setRoomCoordinates` and re-marking the map
    dirty even when you walked back through an unchanged room. Each
    step then dragged a full `saveMap` + `table.save` behind it. The
    package now keeps a per-room signature (name, area, sorted exits,
    coords, terrain) in the persisted id-map; an unchanged room just
    recenters the view and writes nothing. Any real change still
    triggers the full rebuild. (Fast-path contributed by Steve De
    Jongh / Arthr, PR #5.)
  - The map was flushed to disk on a blind 30s cadence, so a large
    accumulated map could stutter the client mid-walk or mid-fight.
    Saving is now deferred: it happens only after ~10s idle and never
    during combat, with a 5-minute hard cap so a crash still can't
    lose much mapping. (Idle-deferral approach and thresholds from
    Steve De Jongh / Arthr.)

  Net effect: once you've visited a room you can speedwalk and fight
  through it with no mapper-induced latency. Existing maps upgrade in
  place — the signature cache fills in as you move and is wiped by
  `mapper reset` / stale-map auto-recovery like the rest of the state.

## v1.0.13 — 2026-05-26

- **Outworld terrain palette.** Server now ships categorical
  terrain names (water, swamp, mountain, plains, forest, ice) on
  `Room.Info` for all outworld tiles, not just road/path. Package
  paints each tile with the pinkfish "classic" 16-color RGB
  (BLUE water, RED swamp, GREEN forest, HI_BLACK mountain,
  HI_YELLOW plains, HI_CYAN ice) and a single distinctive glyph
  on water/swamp/mountain. Forest/plains/ice rely on env color
  for identity. Road and path keep their glyph and shift to
  pinkfish YELLOW + WHITE for palette consistency.
- **Mapper auto-recovers from a wiped map.** When `Icesus.idmap.lua`
  references room IDs that Mudlet no longer knows about (e.g. the
  player deleted the map via Mudlet's UI), `mapper.install()` now
  detects the mismatch by sampling room names and self-resets so
  the next room walked starts a fresh map. Previously the package
  thought every room was "already placed" and refused to redraw
  until the player ran `mapper reset` manually (reported by Uno,
  issue #472).

## v1.0.12 — 2026-05-25

- **EXP gauge switches to advancement-point progress at level cap.**
  Once `Char.Status.level` hits 100, the package reads `s.tna` (cost
  of the next advancement point) instead of `s.tnl` (cost of the
  next level, which is frozen at the level-100 sentinel and stops
  being meaningful). The gauge relabels to `AP  X / Y  P% to next
  point` and tracks usable experience toward your next adv point.
  Below cap, behavior is unchanged.

## v1.0.11 — 2026-05-24

- **Hot-upgrade crash fix.** v1.0.10 introduced `idMap.areaCoords`
  and `idMap.gridmoded`, but my install path only ran `loadIdMap`
  (which defaults the new fields) when `icesus.mapper.idMap` was
  nil. On a hot upgrade from v1.0.7–v1.0.10 the in-memory `idMap`
  survives without the new fields, and the first `Room.Info` after
  upgrade tripped `attempt to index field 'areaCoords' (a nil
  value)`. `markCoord`, `freeCoord`, and the gridmode check now
  lazily initialise the new fields, so an upgraded session
  self-heals on the next room movement.

## v1.0.10 — 2026-05-24

- **New-player login is quiet.** On a fresh Mudlet install where the
  bundled `generic_mapper` is present, the mapper widget's
  `mapOpenEvent` fires while the player is still at the new-character
  name prompt — and `generic_mapper`'s handler responds with
  `send("look")`, naming the character "look". v1.0.8 already
  uninstalled `generic_mapper`, but via `tempTimer(1, …)` which lost
  the race. Uninstall now runs synchronously at the top of
  `icesus.install()`, before any handler can fire.
- **All package output deferred to first `Char.Base`.** Character
  creation sees no banners, no `Icesus removed generic_mapper`
  notice, and no mapper-side bookkeeping. The `Icesus vX.Y.Z ready.`
  line lands the moment the character is logged in.
- **Fresh-profile mapper noise gone.** `loadMap` is now guarded by
  `io.exists` — Mudlet's "Unable to open map file for reading" +
  debug dump no longer fires on a profile with no saved map yet.
  (Mudlet emits that from C++; `pcall` couldn't suppress it.)
- **Overworld auto-gridmode.** First `Room.Info` with `r.coords` in
  an area flips it to `setGridMode(areaId, true)` — the outworld
  reads as a pixel map instead of node-and-line. Detection is
  data-driven (server only ships coords for outworld), no hardcoded
  area id, persisted via `idMap.gridmoded` across reconnects.
- **Terrain glyphs.** `r.terrain == "road"` paints `#` in saddle
  brown; `r.terrain == "path"` paints `.` in burlywood, via
  `setRoomChar` + `setRoomEnv`. Custom envs registered once at
  mapper boot.
- **Indoor stacking fix.** Buildings entered via special exits used
  to all anchor at `(0,0,0)` — Shanty Town shops piled into a
  jumble at the origin. Unplaced rooms now anchor at the last
  placed room (where the player just walked from) and `freeCoord`
  spirals outward to find a free slot per-area; every placement is
  registered into `idMap.areaCoords` so future buildings respect
  it.

## v1.0.9 — 2026-05-12

- **Auto-updater no longer trips on its own reinstall.**
  `installPackage()` was being called without first removing the
  installed Icesus, producing Mudlet's `Package Icesus is already
  installed` error and stalling the update. Now uninstalls first
  via a `sysUninstallPackage` event hook plus 5s/10s `tempTimer`
  retries as belt-and-braces against Mudlet issue #719
  (`uninstallPackage` can hang). Anonymous timers + event handlers
  survive the teardown — they live in Mudlet's runtime pool, not
  the package XML.
- **Single-source version.** `icesus.version` reads from
  `getPackageInfo("Icesus").version` so the literal in `Icesus.xml`
  can't drift from `package/config.lua`. Literal kept as a fallback
  for dev hot-reload from disk.
- **Visible error feedback.** `sysDownloadError` now echoes a
  `couldn't reach GitHub` notice instead of swallowing the failure
  silently after the `Installing…` line.

## v1.0.8 — 2026-05-11

- **Auto-removes `generic_mapper`.** Mudlet's default profile ships
  the bundled `generic_mapper` package which hooks the same
  `Room.Info` events we drive (via room-title triggers) and
  competes for Mudlet mapper room IDs — producing a confused
  double graph. On install we walk `getPackages()`, find it, and
  call `uninstallPackage("generic_mapper")` (deferred via
  `tempTimer(0)` so the uninstall doesn't run inside our own
  install stack). A yellow banner tells the player what happened.
  No-op if the package isn't present.

## v1.0.7 — 2026-05-11

- **One-liner install.** README now leads with
  `lua installPackage("…releases/latest/download/Icesus.mpackage")`
  so players never have to leave the Mudlet command line.
- **Self-update on session start.** New `icesus.update` module
  fetches the GitHub master `config.lua` 10 seconds after the load
  banner, parses the version, and if it's newer than the installed
  build calls `installPackage(URL)` (deferred via `tempTimer(0)`
  so the re-install doesn't kill the in-flight callback). Default
  on; set `icesus.config.autoUpdate = false` to opt out. Uses
  `downloadFile` + `sysDownloadDone` so the check is non-blocking
  and silently no-ops if GitHub is unreachable.
- **Numeric version compare.** Naive string compare would have
  treated `"1.0.10"` as older than `"1.0.9"`; the comparator now
  splits on digit runs and compares numerically.

## v1.0.6 — 2026-05-11

- **`mapper reset` no longer breaks the mapper.** Two bugs landed
  together: the reset rebuilt `idMap` without the `placed` table
  (next room → error in indoor positioning) and `deleteMap()` left
  Mudlet's player-room pointer dangling, which segfaulted Mudlet
  on the next `centerview()`. Reset now walks `idToRoom` and calls
  `deleteRoom()` per id instead — slower but stable — and the new
  `idMap` includes `placed`.
- **Mapper errors surface in the main console.** Wrapping
  `icesus.mapper.onRoomInfo` in a bare `pcall` was hiding bugs
  like the one above. Now any error from the mapper path prints
  to the main console in red, so future failures are obvious
  instead of mysterious.

## v1.0.5 — 2026-05-11

Mapper Y-axis fix. v1.0.4 placed rooms below their parent when the
player walked north (and below-east when walking northeast). Mudlet
uses geographic convention (+y = north on screen) but the package
was coded with array convention (+y = south).

- **`DIR_OFFSET` table sign-flipped on the Y axis.** north now
  contributes +1, south -1; northeast / northwest / southeast /
  southwest follow.
- **Outworld coords flipped on the Y axis.** The server's `coords`
  uses array convention (positive y = further south on the world
  grid) — we now pass `-y` to `setRoomCoordinates` so the outworld
  draws with north up.

**Existing v1.0.4 users:** type `mapper reset` in-game after
upgrading to discard the mirror-image map; new walks then build a
correctly oriented graph.

## v1.0.4 — 2026-05-11

Drive Mudlet's built-in mapper from `gmcp.Room.Info` so `F11` shows a
graph as the player walks. Closes the second checklist item on
[Mudlet wiki: Listing your MUD](https://wiki.mudlet.org/w/Listing_Your_MUD)
("Ensure that the Mudlet mapper works with your MUD"), pairing with the
server-side `IAC GA` work for the first.

- **`icesus.mapper` module.** New section inside `icesus.core` that
  consumes the server-provided `id` (8-char hex of room file_name),
  `exits` mapping (dir → 8-char hash, or 0 for shrouded), and
  `coords` (outworld grid only) and translates them into
  Mudlet's mapper API (`addRoom`, `setExit`, `setSpecialExit`,
  `setRoomCoordinates`, `addAreaName`, `setRoomArea`).
- **Room persistence.** Hex-id → Mudlet int-id mapping saved to
  `<profile>/Icesus.idmap.lua`, the map data to
  `<profile>/Icesus.map.dat`. Reload-on-start, debounced 30s
  save, plus save on `sysExitEvent` (clean disconnect).
- **Indoor layout.** Server only ships `coords` for outworld grid
  tiles. Indoor rooms get topology layout: the very first room
  anchors at (0,0,0), and each newly-seen neighbour is placed at
  `parent_coords + DIR_OFFSET[dir]` so Mudlet draws a graph
  instead of stacking everything at the origin.
- **Mapper-hostile rooms skipped.** Server omits `id` for
  `/void/...` and pre-nether rooms — those don't pollute the map.
- **Shrouded exits.** `dest_hash == 0` renders as an exit stub
  (direction visible, no link) so the player sees the option
  without learning the destination they haven't walked yet.
- **`mapper reset` alias.** New alias nukes `Icesus.map.dat`,
  `Icesus.idmap.lua`, and calls `deleteMap()` so a corrupted map
  can be cleared in-game without leaving Mudlet.
- **Test fixture.** `tools/mudlet-dev/fixtures/mapper.json` walks
  a synthetic newbie-school path through cardinal, special,
  shrouded, outworld, and void rooms; with one back-step revisit
  to confirm no node duplication.

## v1.0.3 — 2026-05-10

Polish pass surfaced by the Greptile auto-review on the
[mudlet-package-repository submission](https://github.com/Mudlet/mudlet-package-repository/pull/650).

- **PSP gauge teardown.** `refreshGauges()` lazy-creates the PSP gauge when `pspmax` becomes positive, but never hid it again when `pspmax` later dropped to zero — the empty gauge would stay stuck in the vitals row for the rest of the session. Now the `else` branch hides the gauge, and the recreation path explicitly `:show()`s it again so the gauge reappears cleanly when psionic max comes back.
- **GMCP subscription list completed.** `subscribeGMCP()` was sending `"Char 1"` and `"Room 1"` as parent subscriptions plus explicit subs for *some* sub-packages, but missing `Char.Maxstats`, `Char.Casting`, `Char.EnemyDeath`, and `Room.Info` — all of which already had registered handlers. Now all explicit sub-packages match the handler list.
- **Stale version comment.** Script header was `-- v1.0.1` while `icesus.version` had been bumped to `"1.0.2"`. Fixed.

## v1.0.2 — 2026-05-10

Player-facing copy pass. No code changes.

- **`config.lua` description rewritten** for the package manager / packages.mudlet.org listing. Old text opened with "GMCP-driven HUD..." and ended on a list of GMCP package identifiers — accurate but read like developer documentation. New text leads with what Icesus is and what the package keeps visible while you play.
- **Load banner shortened.** Replaced the lowercase comma-separated subsystem inventory with a single anchor line: "Deep, earned progression in a world that rewards commitment." The version still prints, so the load confirmation is intact.

## v1.0.1 — 2026-05-10

Adopt the server's new typed chat packages. Server-side, the legacy
`Comm.Channel` GMCP bucket was split into four typed packages so
clients can route by semantics instead of brittle `chan` strings
(mudlib PR #566).

- **Subscribe to the four new packages** — `Room.Speech` (say /
  whisper / sing / emote / npc_say), `Comm.Channel.Tell` (private
  tells), `Comm.Channel.Text` (broadcast channels). The legacy
  `Comm.Channel` handler is dropped: the server still emits it as
  back-compat passthrough, so listening to both would
  double-render.
- **`Room.Ambient` deliberately ignored.** Third-person NPC
  narration ("the bear sniffs the air") is already in the main
  console — mirroring it to the chat panel is what was leaking
  monster emotes into the player-say feed in v1.0. That bug is
  now gone.
- **Emote rendering fixed.** For `kind="emote"` the server already
  embeds the talker's name in `text`, so the client now renders
  verbatim instead of double-printing the name.
- **Self echoes styled.** Own messages render `you: ...` in dim
  grey instead of guessing from name comparison — uses the new
  `self=1` flag on each packet.
- **Headless fixture refreshed** to exercise all four new packages
  plus a self-echo case.

## v1.0.0 — 2026-05-10

First stable release. The HUD is feature-complete enough to recommend
to every Icesus player: banner, vitals, location, momentum, casting,
effects, cooldowns, enemy panel, and channel feed all read from
GMCP and stay in sync without a single hand-written trigger. Visual
language is ported from the play.icesus.org web client so the two
clients feel like siblings.

What's in the box:

- **Top banner** — identity (name / level / race / guild) and carry
  summary (money / divine favor / weight %), with a full-width forest
  EXP gauge below.
- **Bottom strip** — slim glass HP / SP / EP gauges (PSP if applicable)
  with a vertical-gradient fill, plus a location/exits row showing room,
  area, `SAFE` chip, and open exits as short cyan letters.
- **Right column** — momentum and special-momentum click buttons,
  glacier-cyan casting bar that turns amber for non-spell `busy`
  activities (camping, smelting, fishing), per-effect colour-coded
  status badges, cooldown pills with adaptive density, enemy bars
  using the server's 12-tier shape buckets, and a channel feed
  miniconsole with timestamps.
- **HP critical pulse** — gauge alternates between two red shades when
  HP drops below 25 %.
- **Hot-reload safe** — editing in Mudlet's IDE replaces the running
  HUD cleanly; no leftover gauges, no error spam.

GMCP packages consumed: `Char.Base`, `Char.Vitals`, `Char.Maxstats`,
`Char.Status`, `Char.Casting`, `Char.Cooldowns`, `Char.EnemyDeath`,
`Comm.Channel`, `Room.Info`.

The 0.x line (v0.1 → v0.3.5) was the feedback build. Entries below
are kept as historical record.

## v0.3.5 — 2026-05-10

Visual consistency pass: the EXP bar still wore v0.3.3's flat-block
chrome while the vitals had moved on to slim glass, and the exits row
font was too small to read at desktop resolution.

- **EXP bar matches the vitals.** Same vertical gradient, same 5 px
  radius, same dark inner border, same 10 pt text. Bottom and top
  strips now share one visual language instead of two.
- **Exits row font bumped 10 → 13 pt.** Row height grew 24 → 28 px to
  fit; bottom border 60 → 64 px. Room name + area + exit letters now
  read at a glance instead of squinting.

## v0.3.4 — 2026-05-10

Bottom-strip rework after the v0.3.3 screenshot showed flat, overly tall
HP/SP/EP blocks dominating the screen and the exits row sitting in the
wrong place.

- **Vitals row moved above the exits row.** Reading order now goes
  console → vitals → location → input. The exits/SAFE strip sits
  directly above Mudlet's command line, the gauges sit just above the
  exits, and the bottom border shrunk from 94 px to 60 px (vitals 32
  + exits 24 + 4 px gap).
- **Slim, glassy gauges.** HP/SP/EP/PSP redesigned: height halved
  (58 → 32 px), vertical gradient (lighter top, darker bottom) instead
  of v0.3.3's flat horizontal block, 5 px corner radius, dark inner
  border for depth. Reads as a soft pill rather than a solid colour
  field. Less screen real estate, less garish, easier on the eye.
- **Cast bar unchanged.** Stays horizontal (gradient direction matches
  fill direction for progress) — only the vitals adopted the vertical
  glass treatment.
- **HP critical pulse + lazy PSP gauge** now use the same vertical
  style so the pulse doesn't flatten the bar back to v0.3.3 chrome,
  and PSP appears in the same slim shape when it lights up.

## v0.3.3 — 2026-05-10

Real fix for the "fonts still tiny" problem from v0.3.2 — and the
cooldown clip while we're here.

- **Fonts now actually grow.** v0.3.2's pt-size bumps were CSS
  `font-size` declarations in `setStyleSheet`, which Qt silently
  ignores on this Mudlet build (it honours colour and background
  but not font sizing inside QLabel stylesheets). Each widget now
  also calls Geyser's `setFontSize()` after construction, which
  routes through QFont and actually takes. Channels MiniConsole
  was unaffected because it was already using the native fontSize
  constructor param.
- **Vitals labels stop clipping.** Bumped to `setFontSize(12)` on
  the gauge text instead of 14 — "HP 142/200" now fits inside a
  ~95 px gauge slot.
- **Cooldown / effect pills built from whitespace, not CSS.** Qt's
  HTML-in-QLabel renderer ignores inline `padding` and `border`
  too, so v0.3.2 cooldowns rendered as run-together text without
  the pill chrome. Replaced with literal `&nbsp;` spacing inside
  coloured `background` spans — always works, looks like pills,
  and sidesteps the CSS dead end.
- **Adaptive cooldown density.** When 3+ cooldowns are active,
  long names truncate to 8 chars + ellipsis; at 4+ the seconds
  suffix is dropped too. Keeps 3 pills on screen even with
  "breath weapon 90s" running.
- **Location bar cellpadding** so "Vaerlon exits:" stops running
  together when the bigger font crowds the columns.

## v0.3.2 — 2026-05-10

Second pass on font sizes after a real-monitor screenshot. v0.3.1's
"bigger" pt sizes still rendered ~10 px tall against ~16 px console
text. Bumped harder this time so the HUD reads at desktop resolution.

- Fonts now: identity 18 pt (was 14), vitals 17 pt (was 13), EXP /
  cast / momentum / enemies / carry 14 pt (was 12), location 14 pt
  (was 11), effect & cooldown badges 13 pt (was 10), channels
  miniconsole 13 pt (was 12).
- Borders grew to fit: top 72 → 92 px, bottom 74 → 94 px (location
  28 + vitals 58 + gaps), right column 340 → 360 px.
- Right-column panel heights bumped proportionally: momentum buttons
  32 → 38 px, cast bar 26 → 32 px, badge rows 26 → 32 px, enemy
  panel 200 → 220 px.

Known: a row of 3+ long-named cooldowns (e.g. "breath weapon 90s")
clips at the right edge again with the bigger pill font. A future
pass should either truncate the name when many cooldowns are active
or wrap to a second row.

## v0.3.1 — 2026-05-10

Follow-up to v0.3.0 after first real-world testing. The HUD looked
cramped at proper monitor resolutions and a few signals weren't
flowing through to the user.

- **Bigger type, across the board.** Identity → 14 pt, vitals →
  13 pt, EXP / cast / momentum / enemies / channels → 12 pt,
  effect & cooldown badges → 10 pt. Banner border grew from 60 → 72
  px and bottom border from 46 → 74 px (location row + vitals)
  to fit. Right column nudged from 320 → 340 px.
- **Location & exits strip.** New 24 px row above the vitals,
  fed by `Room.Info`. Renders the room short, area, a teal
  `SAFE` chip when applicable, and the open exits as short-form
  cyan letters (`n e s w u`). Cleared to "—" off-grid.
- **Busy indicator.** `Char.Status.busy` + `activity` (camping,
  smelting, fishing, …) now repaints the cast bar amber with
  `busy: <activity>` so non-spell actions get the same visual
  signal that spells already had. Spell casts still win when both
  fire at once because they carry real progress.
- **Identity name plumbing.** `refreshIdentity` now reads
  `gmcp.Char.Base` directly as a fallback so the name appears
  even when state hasn't been populated yet (race between hot
  install and the first `Char.Base` burst). Also subscribes
  `Char.Base 1` / `Char.Status 1` / `Char.Cooldowns 1` explicitly
  on the wire — defensive against future server-side gating.
- **EXP gauge cap.** Caps the EXP bar at `expMaxW` (default 720 px)
  so the centered label stays close to the eye on widescreen
  monitors instead of getting marooned in a sea of green.

## v0.3.0 — 2026-05-10

Visual refresh, ported from the play.icesus.org web client. The HUD
keeps its Mudlet-native shape (right column for combat / channels,
bottom strip for vitals) but adopts the web client's colour palette,
gauge gradients, and panel hierarchy. New top banner gives the
character their own line.

**New panels**

- **Top banner.** A 60 px strip above the main console with two rows:
  identity (name, level, race, guild) on the left and carry summary
  (money, divine favor, weight %) on the right; a full-width green
  EXP gauge on row two. Identity reads `Char.Base`; everything else
  rides on `Char.Status` (`level`, `exp`, `tnl`, `money`, `dfavor`,
  `carry_wt` / `max_wt`).
- **Cooldowns row.** Compact pills (name + seconds) under the
  effects strip. Pill colour shifts red → cyan → green as the
  cooldown ticks down, matching the web client's `.cooldown-badge`
  / `.cooldown-expiring` rules.
- **PSP gauge.** Lazily appears on the bottom bar when
  `Char.Maxstats.maxpsp > 0`, so non-psionic characters keep the
  three-gauge layout.

**Visual refresh**

- **Web-client palette** (ice-blue accents, deep navy panels, dim
  border greys) ported as `icesus.palette`. Every widget now reads
  from those tokens rather than ad-hoc hex.
- **Gradient gauges.** HP, SP, EP, PSP, EXP and the cast bar all
  use Qt's `qlineargradient` for a two-tone fill that matches the
  web client's `.gauge-fill.*` rules.
- **HP critical pulse.** When HP drops below 25 % the gauge gradient
  alternates between two red shades on a 0.6 s timer, mirroring the
  `.gauge-fill.hp.critical` animation.
- **Per-effect colours.** Effect badges colour-coded per known name
  (bleeding red, stunned amber, poisoned green, burning orange,
  death-sickness purple, frozen ice, blessed gold, cursed violet);
  unknown effects fall back to a neutral grey.
- **Enemy bars** use the web client's per-bucket gradient so a
  critical target reads dark crimson and an excellent one reads
  lush green at a glance.
- **Momentum buttons** in the web client's orange / purple style
  with a subtle border tint when armed.

**Plumbing**

- Subscribes to `Char.Base` so identity / class / race / guild reach
  the HUD as soon as the server pushes them.
- New fake-server fixture entries for `Char.Base` plus richer
  `Char.Status` so the screenshot harness exercises every panel.

**Known limits**

- Cooldown pill row clips when more than ~3 long-named cooldowns
  are active at once; future work might wrap to a second row.
- The character `title` field arrives but isn't rendered yet —
  squeezing it into the banner without crowding needs a designerly
  pass.

## v0.2.2 — 2026-05-10

- **Enemy HP bar renders the block character.** The full-block glyph
  was sent as raw UTF-8 bytes (`\xe2\x96\x88`) and Mudlet's Qt HTML
  renderer was mangling them somewhere along the pipeline. Switched
  to the HTML numeric entity `&#9608;`, which reaches the renderer
  with the encoding already settled. (#2, thanks @yogurtking — first
  community PR on the package.)

## v0.2.1 — 2026-05-09

Hotfix.

- **Top of the right column was hidden behind the bottom panel.**
  v0.2.0 nested the right column as a `Container` with a `VBox` child,
  and the VBox ignored its `x/y` config and rendered at (0, 0) of the
  parent — overlapping the momentum / cast / effects widgets. Replaced
  the nested layout with a single Container with absolute-positioned
  children, all visible.
- **Momentum click callbacks** now use closures instead of
  `setClickCallback("dotted.path")`, which doesn't resolve table
  members in current Mudlet.

## v0.2.0 — 2026-05-09

Bug-fix + feature release.

**Fixes**

- **Vitals gauges actually update.** v0.1 read `gmcp.Char.Vitals.sp`
  and `.ep`; the server sends `mana` and `moves` (per `gmcp_d.c`).
  All three gauges now show real values.
- **Bars no longer 64 px tall.** Bottom border reduced from 64 to 36 px
  with the gauges filling it; gauges start empty (0 / 1) instead of
  full (1 / 1) so an unconnected install reads correctly.
- **Bottom row no longer overlaps the right column.** Bottom HBox now
  ends at `100% - borderRight` instead of stretching the full width.

**New**

- **Momentum buttons.** Two clickable labels on the right column light
  up when `Char.Status.momentum` / `special_momentum` are set; click
  fires `use <name>`.
- **Casting / busy bar.** Fills over `Char.Casting.progress / cps`,
  clears on completion or interruption.
- **Status effects strip.** Renders badges for `Char.Status.effects`.
- **`Core.Hello` on connect** so the server identifies us as Mudlet.

## v0.1.0 — 2026-05-09

First public release. Feedback build.

- Vitals gauges (HP / SP / EP) from `Char.Vitals` + `Char.Maxstats`.
- Enemy panel from `Char.Status.enemies`, cleared on `Char.EnemyDeath`.
  HP rendered to the server's 12-tier shape buckets, colour-coded.
- Channel feed in a side miniconsole from `Comm.Channel`, with optional
  timestamps.
- Geyser HUD: hot-reload safe.
- GMCP subscriptions: `Char 1`, `Char.Vitals 1`, `Comm 1`, `Room 1`.
