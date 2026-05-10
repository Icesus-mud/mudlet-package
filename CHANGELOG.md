# Changelog

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
