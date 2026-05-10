# Contributing

Thanks for wanting to help! This is a small project and we want to keep
it that way. PRs that add a focused feature or fix a focused bug are
the gold standard.

## Before you write code

Open an issue describing what you want to add. Two reasons: (1) it lets
the GMCP-spec side stay coordinated with the mudlib team, and (2) it
prevents two people from writing the same panel in parallel.

If you're adding something not on the README's roadmap, propose it in an
issue first — happy to expand scope, but small package > big package.

## Layout

```
.
├── package/
│   ├── config.lua         ← Mudlet manifest. Bump `version` on a release.
│   └── Icesus.xml         ← Hand-edited Mudlet XML; the Lua source lives
│                            in the <script> CDATA blocks.
├── build/build.sh         ← Builds dist/Icesus.mpackage.
├── docs/                  ← GMCP reference + design notes.
└── README.md
```

For v1.0 the entire package is one Lua script. As more panels land
(minimap, party, sound), we'll likely split each major one into its
own `<Script>` block under the `Icesus` group, all sharing the
`icesus.*` global namespace.

## Editing the package

The fast loop is in Mudlet itself: install the package, open the script
in Mudlet's IDE (`Toolbox → Scripts`), edit, save (`Ctrl+S`). The save
re-runs the script, which tears down the previous HUD and rebuilds —
zero-friction iteration.

When you're done, copy your edits back into `package/Icesus.xml`. There's
no auto-export pipeline yet; this is the friction point we'd most like
to fix (see issue: "auto-export Lua from Mudlet IDE back to repo").

## Style

**Lua** — match what's there:

- Two-space indent.
- Functions on the `icesus` table or in local closures, never global.
- `pcall` around anything that touches Geyser widgets that may have
  been destroyed (hot-reload fights us otherwise).
- Don't introduce new globals. The whole package gets one: `icesus`.

**XML** — keep it readable. Each `<Script>` should have a `<name>` that
matches a function namespace (`icesus.minimap`, `icesus.cooldowns`).

**No new dependencies.** Vanilla Mudlet only — no MDK, no third-party
Lua libraries fetched at install time. The package has to install with
one click and run offline.

## GMCP discipline

Two rules that aren't negotiable, because they protect players:

1. **Don't display data more precise than the server sent.** The enemy
   `hp` field is bucketed to 12 tiers on purpose (`gmcp_d.c:411-427`).
   A bar that interpolates to 1% precision is dishonest.
2. **Subscribe via `Core.Supports.Set`** — don't assume a package is
   active. If you add a new module, extend the supports list in
   `icesus.subscribeGMCP()`.

The GMCP spec is `docs/gmcp-reference.md`. If a field name disagrees
with `doc/help/gmcp.doc` in the mudlib repo, the mudlib repo wins —
file an issue here so we update the mirror.

## Commit messages

One commit per logical change. Imperative subject ("add cooldowns
panel"), body explains *why* if it's not obvious from the diff. Match
the style in `git log`.

## Testing

There's no automated test suite — Mudlet packages live or die by how
they feel in-game. The headless harness in `tools/mudlet-dev/` is for
layout iteration, not regression testing. Before you submit a PR:

1. Build it (`./build/build.sh`).
2. Install the built `.mpackage` into a clean Mudlet profile.
3. Connect to Icesus and exercise whatever you changed.
4. Disconnect, uninstall, reinstall — check the HUD tears down cleanly
   (no leftover gauges, no error spam in Mudlet's debug console).
5. Drop a screenshot of the new feature into the PR description.

If the feature touches the GMCP wire (new package subscribed, new
field consumed), a one-liner in the PR confirming you saw the data
arrive (`display(gmcp.Char.Whatever)` in the Mudlet command line) is
the cheapest possible verification.

## Releases

Maintainers cut releases via `gh release create`. The `.mpackage` zip
attaches to the release, and the README install link points at "latest".
Versioning is semver: minor bumps for new modules, patch for fixes,
major for a `gmcp.doc` field rename that breaks the package.

## Questions

Open an issue, or ping in the Icesus Discord (`#dev` channel). We're
friendly.
