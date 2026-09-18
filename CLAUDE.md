# Firekeeper

A campsite planner addon for World of Warcraft: Forever. Lua 5.1, no libraries.
README.md says what it does; these rules apply to every change:

@CONTRIBUTING.md

## Checks

- `lua5.1 tests/run.lua` (LuaJIT works locally) runs the pure-Lua tests.
- `luacheck -q .` must be clean.

CI runs both on every pull request. A hook also runs them after each Lua edit when the
tools are installed.

## The client

Forever is the retail client running a level-60 game: product `wow_classic_beta`,
folder `_classic_beta_`, version 1.60.x, interface `16001`. Classic API habits do not
carry over and retail ones are not guaranteed. `.claude/rules/wow-lua.md` lists the
traps and loads when you touch Lua; the `wow-api` skill checks a specific API.

## Working with the game

The repository is linked into the client's `Interface/AddOns/Firekeeper`, so saved
files are what the game loads. A Lua edit needs `/reload` in game; a new file or a
`.toc` edit needs a full client restart.

You cannot see the game. When a change needs checking in the client, tell the user
exactly what to type and what to look for, then use the `game-session` skill to read
what the client wrote to disk. Saved variables are written only on `/reload`, logout,
or quit.
