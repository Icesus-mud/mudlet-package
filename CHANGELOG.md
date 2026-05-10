# Changelog

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
