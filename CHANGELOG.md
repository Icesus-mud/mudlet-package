# Changelog

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
