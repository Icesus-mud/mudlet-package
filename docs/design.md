# Icesus Mudlet Package — Design

**Status:** v1.0 shipped — banner, vitals, location, momentum, casting,
effects, cooldowns, enemies, channels all live. This document keeps the
longer-term plan (minimap, party, sound, themes, GMCP sync). See
`CHANGELOG.md` for what's actually in the package and `README.md` for
the user-facing tour.
**Repo placement:** `Icesus-mud/mudlet-package` (public). Contributor-led
maintenance, with `Icesus-mud` org as owner so spec coordination with the
mudlib is institutional rather than personal. Contributors get push access
once they ship a useful PR.

## Goal

Ship an official Mudlet package that gives Icesus players a polished
GMCP-driven HUD without writing their own triggers. Icesus already emits
the data; the package is mostly UI plumbing plus a few bits the web
client doesn't have (notably an outworld minimap).

## Why a package, not just trigger packs

Players currently roll their own. Two problems with that:

1. **Channel/combat parsing via regex is fragile.** Output strings change
   when wizards reword combat, channels, or NPC chat. GMCP packages are a
   stable contract documented in `doc/help/gmcp.doc`.
2. **Everyone solves the same starter problems.** HP gauge, channel
   capture, room panel, exit buttons. A shared package is the obvious
   way to stop duplicating that.

The package is the recommended starting point; advanced players can layer
their own scripts on top.

## What the player installs

A single `.mpackage` (zip with Lua scripts, XML for triggers/GUI/aliases,
optional sounds and images). Two install paths:

1. **Mudlet → Package Manager → Install from URL** pointing at a hosted
   `.mpackage` (icesus.org or GitHub Releases). One click.
2. **Pre-configured profile bundle**: profile that fills host/port
   (`icesus.org:4443` TLS, fallback `:4000`), UTF-8 encoding, GMCP enabled,
   for new players who haven't set up Mudlet before.

On connect the package checks a manifest URL for a newer version and
offers an in-place update.

## Where the data comes from

Everything below is already on the GMCP wire (`gmcp_d.c` + `gmcp.doc`).
Nothing in the v1 scope requires new mudlib work.

| Widget                        | GMCP package                          |
|-------------------------------|---------------------------------------|
| HP / SP / EP / PSP gauges     | `Char.Vitals` + `Char.Maxstats`       |
| EXP gauge + gain float-ups    | `Char.Status` + `Char.ExpGain`        |
| Char identity (name/title/level/pos) | `Char.Base` + `Char.Status`    |
| Money / bank / divine favor   | `Char.Status`                         |
| Carry weight / volume         | `Char.Status`                         |
| Food / water / drunk icons    | `Char.Status`                         |
| Status effects (bleeding etc.)| `Char.Status.effects`                 |
| Combat enemy bars             | `Char.Status.enemies` (12-tier `hp` + `shape`) |
| Enemy cleared on death        | `Char.EnemyDeath`                     |
| Casting / skill busy bar      | `Char.Casting`                        |
| Cooldown timers panel         | `Char.Cooldowns`                      |
| Room name / exits / area      | `Room.Info`                           |
| Channels / say / tell / whisper| `Comm.Channel` ({chan, player, msg}) |
| Party panel                   | `Party.Info`                          |
| World clock                   | `World.Time`                          |
| Server status                 | `Server.Status`                       |
| Server-synced triggers        | `Client.Triggers`                     |
| Server-synced hotkeys         | `Client.Hotkeys`                      |
| Screen reader hint            | `Client.Screenreader`                 |

The package opts into all of these via `Core.Supports.Set` on connect.

## v1 feature set (the conservative cut)

Goal for v1: a clean default HUD that's strictly better than running
vanilla Mudlet, ships in a few weekends, and doesn't break anyone's
existing custom scripts.

1. **Vitals gauges** — HP/SP/EP/PSP with HP threshold colours (white →
   yellow-green → yellow → orange → red at 75/50/25/10), critical pulse
   under 25%. EXP gauge with `1.5M / 2.0M` compact format.
2. **Delta float-ups** — `+12` / `-43` floating up the gauge as values
   change, accumulated over a small window so a flurry shows as one
   number. Same for money and divine favor.
3. **Identity row** — name, title (with name prefix stripped), level,
   position, food/water/drunk icons (only shown when not satiated/etc.),
   carry kg / L with % and over-cap warning.
4. **Status effects strip** — small badges from `Char.Status.effects`.
5. **Enemy panel** — one bar per opponent in `Char.Status.enemies`, fill
   width from the 12-tier `hp` bucket, colour from `shape`. Bar removed
   on `Char.EnemyDeath`. Combat round shape lines gagged from main
   window (the bar replaces them).
6. **Room panel** — current room name, exits as clickable colour-coded
   buttons (cardinal / vertical / special).
7. **Casting / busy bar** — fills over `Char.Casting` duration, reused
   for skill busy ticks.
8. **Cooldowns panel** — stacked list from `Char.Cooldowns` with mm:ss
   countdowns, ticked client-side.
9. **Channel routing** — `Comm.Channel` feeds a side miniconsole (or
   Mudlet's chat module). Channels gagged from main window. This is the
   single biggest reliability win over hand-rolled regex.
10. **Momentum buttons** — one-click "Use X" buttons that appear when
    `Char.Status.momentum` / `special_momentum` are set.
11. **Pinkfish** — server already converts pinkfish → ANSI when terminal
    type is set appropriately. Package sets the terminal type on connect;
    no client-side `%^...%^` parsing needed.
12. **QoL aliases** — `/forum`, `/wiki <topic>`, `/bug <text>`,
    `/help <topic>`, `/theme dark|light|highcontrast`. Nothing rebinds an
    existing in-game verb.

## v1.x — opt-in modules

Same release line, off by default, players turn them on when they want them.

- **Outworld minimap.** A Geyser miniconsole rendering the LOS-visible
  outworld grid from `Room.Info` terrain chars. Render-only-what-you-see
  is half a day's work; persistent fog-of-war (explored area memory) is a
  real project and goes here, not in v1. **This is the feature the
  Mudlet pack will have that the web client currently doesn't.**
- **Sound pack.** Level-up jingle, channel mention chime, death sound,
  combat-enter cue. Off by default. .ogg files in the package.
- **Party panel.** Members with HP bars + per-member HP delta animation,
  from `Party.Info`. Lives in a side dock, hidden when soloing.
- **Toolbar buttons.** `who`, `score`, `quests`, `news`, plus web
  buttons to forum / wiki / bug tracker.
- **Tooltips.** Hover help for every widget (port the web client's
  tooltip dictionary, ~40 entries).

## v2+ — bigger projects

Punted out of v1 because each is its own scope.

- **Indoor automapper.** Either tune Mudlet's built-in mapper per area or
  build a custom one from `Room.Info`. Real project; needs its own design
  doc.
- **`Client.Triggers` and `Client.Hotkeys` GMCP sync (read+write).**
  Triggers and hotkeys roam between web client and Mudlet automatically.
  Killer feature for a multi-client world but needs careful protocol
  thinking — what if a player edits in both clients while disconnected?
  Last-write-wins is probably fine but worth deciding deliberately.
- **Combat dashboard.** DPS estimate, attacker tracker, recent damage
  taken graph. Useful but cosmetic.
- **Localized UI labels.** Auto-detect from `set lang`, render Finnish or
  English. Every label is currently English.

## Distribution and lifecycle

- **Repo:** `github.com/Icesus-mud/mudlet-package`. Public. Issues open.
- **License:** MIT. Default for Mudlet packages.
- **Versioning:** semver tied to the GMCP spec it was built against.
  Major bump when a `gmcp.doc` field rename forces a break.
  Minor bump for new modules, patch for fixes.
- **Releases:** GitHub Releases attaches the built `.mpackage`. Manifest
  URL the package checks on connect points at `latest`.
- **Submission to mudlet.org/packages:** after one stable release. Until
  then, "install from URL" is enough.
- **CI:** a small Lua linter + an `unzip` round-trip to make sure the
  built `.mpackage` is loadable by Mudlet headless. Anything fancier
  (rendered UI screenshot diffing) is overkill for v1.

## Repo skeleton

```
mudlet-package/
├── README.md              ← features, screenshot, install link, supported clients
├── LICENSE                ← MIT
├── CONTRIBUTING.md        ← style, PR process, how to build the .mpackage
├── CHANGELOG.md           ← per-release notes, GMCP spec versions targeted
├── docs/
│   ├── gmcp-reference.md  ← derived from doc/help/gmcp.doc, auto-updateable
│   └── screenshots/
├── src/
│   ├── config.xml         ← Mudlet package manifest
│   ├── triggers/          ← XML trigger groups (gagging combat shape, channels)
│   ├── aliases/           ← /forum, /wiki, /theme, etc.
│   ├── scripts/
│   │   ├── gmcp/          ← per-package handlers (Char.Vitals, Comm.Channel, …)
│   │   ├── ui/            ← Geyser layout, gauges, panels
│   │   ├── minimap/       ← outworld renderer
│   │   └── sound/
│   └── assets/
│       ├── images/
│       └── sounds/
├── build/                 ← script that zips src/ into icesus.mpackage
└── .github/
    ├── workflows/         ← lint + build on PR
    └── ISSUE_TEMPLATE/
```

## Coordination with the mudlib

- **GMCP spec is the contract.** `doc/help/gmcp.doc` is the source of
  truth. When a wizard renames a field or adds a package, they update
  `gmcp.doc` in the same PR. The package's CI runs against a snapshot of
  `gmcp.doc` and breaks the build if a field the package consumes
  disappears.
- **Spec snapshot lives in the package repo** so the package can build
  without the mudlib repo. Refreshed by a small script that pulls
  `gmcp.doc` from the public mudlib repo and diffs.
- **No new server-side work for v1.** Every widget reads existing
  packages. New GMCP packages are the mudlib's call, not the package's.

## Open questions for player input

These are the calls worth taking to Discord / forum before locking
anything in:

1. **Default layout.** Bottom-bar gauges + right-side panels (web client
   shape) vs. classic two-column dock vs. minimal? Show two mockups.
2. **Should combat shape lines be gagged by default**, or shown in a
   dimmed colour, or untouched? Some players read the shape line for
   combat flavour even with a bar visible.
3. **Channels: gag and route to side window, or echo in both?** Some
   players like channel chatter mixed into the main flow.
4. **Sound on or off by default?**
5. **Outworld minimap: render-only-what-you-see, or persistent
   explored-area memory?** Affects how much storage the package keeps
   per character.
6. **Geyser vs Demonnic's MDK.** Cosmetic; either works. Ardewn already
   has Geyser running.
7. **Other clients?** Mudlet first is uncontroversial. Is there real
   demand for tintin++ / MUSHclient / BlightMud equivalents, or is the
   web client + Mudlet enough?

## What "done for v1" looks like

- Repo created under `Icesus-mud`, license + README + contributing in
  place.
- Manifest published at a stable URL (icesus.org or GitHub Pages).
- v1 features above all working against the live game.
- Known to work on Mudlet 4.x stable. Tested on Linux + Windows +
  macOS (community help welcome here).
- Forum thread + Discord announcement with screenshot and install
  instructions.
- Linked from icesus.org clients page.

No specific deadline. The package is value-add, not blocking anything.

## Next concrete step

Decide who maintains it. Two options:

- **Ardewn (or another player) leads.** They get push to the
  `Icesus-mud/mudlet-package` repo, drive scope, take PRs. Idles
  reviews GMCP-spec changes and keeps the mudlib side coordinated.
- **Idles seeds the repo skeleton, players contribute via PR.** Slower
  start, less ownership, but no dependence on a single maintainer.

The first option is the better pattern if Ardewn is genuinely up for
it — ask them.
