---
name: add-camp-object
description: Turn a camp object sighting into an entry in Data/CampObjects.lua, following docs/DATA.md. The sighting can be a GitHub issue from the camp-object template or details the user pastes. Use when the user mentions a camp object, a sighting issue, or new campsite data.
argument-hint: "[issue number]"
allowed-tools: Bash(gh issue view *)
---

# Add or confirm a camp object

The data is Firekeeper's most valuable part, and its one rule is to never invent any of
it. Every field comes from the sighting or stays empty.

## 1. Read the sighting

If an issue number was given, read the issue:

```bash
gh issue view $0 --json number,title,body,labels,author,url
```

Issue forms put each field under a `### <Label>` heading, and an empty field reads
`_No response_`. Otherwise, use what the user pasted.

Then read `docs/DATA.md`, `Data/CampObjects.lua`, and `Data/BuffGroups.lua`.

## 2. Build the entry

| Field | From |
| --- | --- |
| `id` | The name in `snake_case`. Keep an existing entry's `id`, because other clients send ids over the wire (`docs/PROTOCOL.md`). |
| `name`, `profession` | As reported. The profession must match `FK.Data.professions` exactly. |
| `tier` | `1` for a trainer or camping NPC. A blueprint is `2` or `3`; if the report does not say which, ask. Do not infer it from the skill level. |
| `skill` | The reported number, or leave it out. |
| `source` | `"trainer"` or `"blueprint"`. |
| `effect` | `buff` with a key from `Data/BuffGroups.lua`, or `workspace`, `slots`, `utility`, or `{ kind = "unknown" }` when the tooltip is missing. |
| `confidence` | See below. |
| `note` | Anything a reader should not have to guess, such as the build and who saw it. |

**Confidence:**
- `confirmed` requires a client build and tooltip text seen in game.
- A sighting without a build stays `reported`. Ask the reporter for the output of `/fk caps`.
- An object whose effect nobody knows is `unknown`.

**If the object already exists:** update its entry in place, never duplicate it.
Confirming a `reported` entry usually means raising `confidence`, filling in `skill`,
and adding the build to `note`.

**If the object gives a buff no group covers yet:** add the group to
`Data/BuffGroups.lua`. List the class buffs that give the same stat, and set
`confidence = "reported"`. Whether camp buffs and class buffs really overwrite each
other is still open (`docs/RESEARCH.md`, FK-7).

## 3. Check and ship

- Run `lua5.1 tests/run.lua` and `luacheck -q .`. If a profession now has three
  objects, `/fk gaps` stops listing it.
- Follow `.claude/rules/git-conventions.md`. Use a branch such as
  `feat/<id>-camp-object` and one commit, titled like
  `(feat): Add the Tanning Rack camp object` or
  `(feat): Confirm the Sharpening Wheel on build 1.60.1`.
- Write `Closes #<issue>` in the pull request body. In the PR description, quote the
  tooltip text the entry rests on.
