---
paths:
  - "**/*.lua"
  - "*.toc"
---

# Writing Lua for the Forever client

Forever is the retail client (`WOW_PROJECT_ID == WOW_PROJECT_MAINLINE`) running a
level-60 game, version 1.60.x, interface `16001`. Blizzard's UI source for it is the
`forever` branch of Gethe/wow-ui-source. Items marked *(beta report)* come from a single
community source and are not confirmed here; plan for them, do not cite them as fact.

## APIs

- An API is absent until checked. Classic globals such as `GetSpellInfo`,
  `GetItemInfo`, `UnitAura` and `CombatLogGetCurrentEventInfo` are gone, and retail ones
  may be restricted. Check with the `wow-api` skill, then follow CONTRIBUTING.md: a probe
  in `Core/Capabilities.lua`, a fallback, a row in `docs/RESEARCH.md`.
- An undefined global from luacheck is a question, not a typo to silence. Check it
  before adding it to `read_globals` in `.luacheckrc`.
- Never branch on `select(4, GetBuildInfo()) >= 100000`: Forever answers 16001.
- Registering an event the client does not know throws and aborts the rest of the file
  *(beta report)*. Guard uncertain events with `C_EventUtils.IsEventValid`.
- `ReloadUI()` is protected *(beta report)*. Tell the player to type `/reload`.

## Restrictions and secret values

Forever carries the 12.0 restriction system. The API documentation marks it per
function: `HasRestrictions`, `SecretReturns`, `SecretWhen...Restricted`,
`SecretArguments`, and `Environment = "SecureOnly"` (not callable by addons).

- A secret value cannot be compared, used in arithmetic, or concatenated; even a
  truth test may throw *(beta report)*. Test with `issecretvalue(v)` where the value
  enters the addon and drop it there. `pcall` does not make it readable, and neither
  does leaving combat.
- `UnitName` and aura data can come back secret: the docs mark them with
  `SecretWhenUnitNameIdentityRestricted` and `SecretWhenUnitAuraRestricted`.
- Do not build on the combat log. `COMBAT_LOG_EVENT_UNFILTERED` is restricted, and on
  12.0 clients registering it errors.
- `ADDON_RESTRICTION_STATE_CHANGED` and `C_RestrictedActions.GetAddOnRestrictionState()`
  say when combat, encounter, map or chat restrictions are active.

## Addon messages

See `docs/PROTOCOL.md`.

- The prefix is at most 16 characters, and the receiver must call
  `C_ChatInfo.RegisterAddonMessagePrefix` for it.
- The payload is at most 255 bytes, with no NUL.
- `C_ChatInfo.SendAddonMessage` returns an `Enum.SendAddonMessageResult` rather than
  throwing. Anything other than `Success` (throttled, lockdown, not in a group) means
  the message did not go.
- Each prefix may burst about 10 messages and regains one per second.

## Chat

- `SendChatMessage` to SAY or YELL needs a hardware event outdoors, and CHANNEL
  always does. Send only from a slash command or a click, never from an event or a
  timer.

## Frames, events and saved variables

- Never overwrite a Blizzard function or frame field; post-hook with `hooksecurefunc`.
  Leave protected frames alone while `InCombatLockdown()` is true.
- Saved variables exist from this addon's `ADDON_LOADED`, and world state from
  `PLAYER_LOGIN`; see `Core/Init.lua`. They are written only on `/reload`, logout or
  quit. The beta (1.60.1.69913) never reads them back, so every login and `/reload`
  starts from defaults (`docs/RESEARCH.md`, FK-9). A lost database must cost the player
  nothing worse than defaults.
- No new globals: `local _, FK = ...` and hang everything off `FK`. The saved variables
  and slash command globals in `.luacheckrc` are the only exceptions.
- Prefer `C_Timer` to `OnUpdate`. If you must use `OnUpdate`, throttle on elapsed time.
