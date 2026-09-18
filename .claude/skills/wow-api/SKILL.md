---
name: wow-api
description: Check a WoW API function, event, enum or UI template against the Forever client, including whether it is restricted or returns secret values. Use before calling a WoW API this repo does not already use, when luacheck reports an undefined global, when adding or changing a probe in Core/Capabilities.lua, or when a docs/RESEARCH.md question needs evidence.
argument-hint: "[C_Namespace.Function | GlobalFunction | EVENT_NAME | TemplateName]"
allowed-tools: Bash(bash *wowapi.sh*)
---

# Check an API on Forever

Everything below runs `${CLAUDE_SKILL_DIR}/wowapi.sh` with bash.

## 1. Make sure the references match the client

```bash
bash "${CLAUDE_SKILL_DIR}/wowapi.sh" status
```

If the UI source or the runtime capture is missing, or the UI source is older than the
installed client, run `bash "${CLAUDE_SKILL_DIR}/wowapi.sh" sync`. It downloads about
50 MB into `~/.cache/firekeeper`, outside the repository.

## 2. Look the name up

```bash
bash "${CLAUDE_SKILL_DIR}/wowapi.sh" lookup $ARGUMENTS
```

Look up one name per call. Write namespaced functions in full (`C_ChatInfo.SendAddonMessage`),
events by their literal name (`CHAT_MSG_ADDON`), and templates by their XML name.

The output has four sections, and each is a different kind of evidence.

**Declared.** This is the entry in Blizzard's generated API documentation for that build:
arguments, returns, nilability, and restriction markers.

| Marker | Meaning |
| --- | --- |
| `Environment = "SecureOnly"` | Addons cannot call it. Stop here. |
| `HasRestrictions = true` | Works only outside some restriction (combat, encounter, chat lockdown). Needs a fallback. |
| `SecretReturns` / `SecretWhen...Restricted` | Returns can be secret values. See `.claude/rules/wow-lua.md`. |
| `SecretArguments = "NotAllowed"` | Passing it a secret value errors. |
| `MayReturnNothing`, `Nilable = true` | Handle `nil`. |

A bare name that is only declared under a namespace does not exist as a global. For
example, `GetSpellInfo` is gone and `C_Spell.GetSpellInfo` replaces it.

**Present at runtime.** This says whether a community capture of the client's globals
saw it. The build is printed with it. Declared but not present means an addon could not
reach it on that build. Events are not captured.

**Defined in XML.** A template or named frame exists only if it is defined here.

**Used by Blizzard.** Blizzard's own call sites are the best example of correct use.

## 3. Decide

- **Neither declared nor present:** it does not exist on Forever. Search the
  documentation for the concept instead, for example
  `grep -il profession ~/.cache/firekeeper/wow-ui-source/Interface/AddOns/Blizzard_APIDocumentationGenerated/*`.
- **Declared and present:** use it behind a probe in `Core/Capabilities.lua` with a
  fallback, as CONTRIBUTING.md requires, unless Firekeeper already probes it. A new
  global goes into `read_globals` in `.luacheckrc`.
- Add or update the row in `docs/RESEARCH.md` with the evidence and the build.

None of the four sections proves that the API works for an ordinary addon. Only an
in-game test on a named build does that. To get one, ask the user to type
`/dump type(C_ChatInfo.SendAddonMessage)` or `/api search SendAddonMessage`, and to
report what it printed.

For what a return value means and its edge cases, see
`https://warcraft.wiki.gg/wiki/API_<Name>`. The wiki describes retail, so the local
documentation wins wherever the two disagree.
