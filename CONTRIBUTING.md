# Contributing

## The most valuable contribution

Camp objects you have seen in game. Open a
[camp object sighting](../../issues/new?template=camp-object.yml) with the tooltip text
and the client build from `/fk caps`. Two thirds of the object table is still missing;
`/fk gaps` prints which professions are short.

Answering a question in [docs/RESEARCH.md](docs/RESEARCH.md) is worth as much. Say which
build you tested on and what happened, including "it did nothing".

## Code

- Clone with `git clone --recurse-submodules`, or run `git submodule update --init` in an
  existing clone. That fetches the ponytail plugin the Claude Code settings load.
- Lua 5.1, tabs for indentation, no external libraries. The addon deliberately has no
  dependencies: a new client is a bad place to inherit someone else's compatibility
  problems.
- Game logic that can be written without the WoW API belongs in `Core/Plan.lua` or
  `Core/Cooldowns.lua`, where it can be tested. Run the tests with `lua5.1 tests/run.lua`.
- Anything that calls an API not proven to exist on Forever needs a probe in
  `Core/Capabilities.lua`, a fallback, and a row in `docs/RESEARCH.md`.
- `luacheck .` must be clean. CI runs it on every push.
- Never invent game data. An object nobody has seen gets `confidence = "unknown"`, not a
  best guess at its buff.

## Releases

Tagging `vX.Y.Z` builds the zip, writes the version into the `.toc`, and creates a GitHub
release. Add `CF_API_KEY` and `WAGO_API_TOKEN` as repository secrets to also publish to
CurseForge and Wago.
