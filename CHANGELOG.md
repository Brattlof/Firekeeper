# Changelog

## Unreleased

## 0.1.0 — 20 September 2026

First release, built against the Forever beta that opened on 17 September 2026. Early, and
the README says plainly what is not settled yet.

**Planning a camp**

- Camp planner: one object per player, never two with the same effect, and it skips a buff
  the group already has. A higher-tier object that carries a lower tier's buff counts as
  that buff, so an Anvil does not get planned alongside a Sharpening Wheel.
- Shared one-hour cooldown tracked per character, adjusted for the Legacy perk Field Guide.
- `/fk train` shows what each of your professions can place and how far the next one is.

**The data**

- All 38 camp objects with their exact buff amounts, exclusivities, item ids, skill
  requirements and tier replacements, read from the client's own tooltip data. Every item
  id was verified. See `docs/DATA.md`.

**Working with other people**

- Group sharing over the `FKPR1` addon message protocol, with a local-only fallback.
- `/fk find` and `/fk host` to find a camp somebody else lit, carrying the realm layer so a
  camp you cannot reach is marked.
- `/fk guild` lists guildies running Firekeeper, with distance and direction. Sharing your
  own position is off until you turn it on.
- `/fk buffs` reads what the group is actually carrying and says who can fix what is
  missing.

**Telling you what it cannot do**

- A capability probe at login (`/fk caps`), written to the saved variables so a bug report
  is a file rather than a transcription.
- It says at login when the client did not give back your saved settings, which this beta
  build does not.
- `/fk gaps` lists camp objects whose effect nobody has reported.

**Known limits on this build**

- Saved settings are written but never read back by the client, so professions set with
  `/fk prof`, Legacy ranks and alt cooldowns start fresh each session.
- Nothing in the group-sharing half has been confirmed to reach another player.
- Every camp object effect is datamined rather than seen in game.
