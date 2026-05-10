# Changelog

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
