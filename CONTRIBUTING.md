# Contributing

## The most valuable contribution

Two things, now that the object table is filled in from the client's tooltip data
(see [docs/DATA.md](docs/DATA.md)):

**Where Blueprints drop.** Nobody has published a single source for any tier-2 or tier-3
recipe. If you get one, say which boss or vendor gave it.

**A tooltip screenshot from the beta.** Every effect in the table is datamined, so it is
marked `reported` rather than `confirmed`. Open a
[camp object sighting](../../issues/new?template=camp-object.yml) with the tooltip text and
the client build from `/fk caps`, and that row gets promoted. The Sharpening Wheel is the
one to settle first: its tooltip says Strength, Blizzard's recap said Attack Power.

Answering a question in [docs/RESEARCH.md](docs/RESEARCH.md) is worth as much, and
[docs/SOURCES.md](docs/SOURCES.md) says where to look before you log in. Say which
build you tested on and what happened, including "it did nothing".

## Code

- Clone with `git clone --recurse-submodules`, or run `git submodule update --init` in an
  existing clone. That fetches the ponytail plugin the Claude Code settings load.
- Lua 5.1, tabs for indentation, no external libraries. The addon deliberately has no
  dependencies: a new client is a bad place to inherit someone else's compatibility
  problems.
- Game logic that can be written without the WoW API belongs in a pure module like
  `Core/Plan.lua` or `Core/Cooldowns.lua`, where it can be tested. Run the tests with
  `lua5.1 tests/run.lua`.
- Code that draws frames or reads units is tested too, against `tests/wowmock.lua` — see
  `tests/ui_test.lua` and `tests/group_test.lua`. The mock **raises on any method it does
  not know**, which is the point: a mock that accepts anything proves nothing. It cannot
  tell you the panel looks right, only that it draws, redraws without leaving stale rows,
  and that clicking things reaches the addon. That is the half which fails silently,
  because `UI:Refresh` wraps each tab in a `pcall` and a broken tab simply does not
  appear.
- Anything that calls an API not proven to exist on Forever needs a probe in
  `Core/Capabilities.lua`, a fallback, and a row in `docs/RESEARCH.md`.
- `luacheck .` must be clean. CI runs it on every push.
- Never invent game data. An object nobody has seen gets `confidence = "unknown"`, not a
  best guess at its buff.

## Releases

Tagging `vX.Y.Z` builds the zip, writes the version into the `.toc`, and creates a GitHub
release. Add `CF_API_KEY` and `WAGO_API_TOKEN` as repository secrets to also publish to
CurseForge and Wago.
