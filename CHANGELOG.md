# Changelog

## Unreleased

## 0.3.0 — 20 September 2026

- **Clicking an object on the Place tab now actually places it.** The buttons are secure
  action buttons pointed at the item, so your own click uses it — an addon cannot use an
  item for you, but a button you press yourself can. The "place what is suggested" button
  on the Camp tab works the same way. On a client without the template the panel still
  works and records what you tell it, and says so.
- **The addon notices what you placed instead of being told.** Every camp object casts a
  spell to put itself down, and the client announces a finished cast, so `/fk place` and
  the "I placed this" step are no longer needed for the record to be right.
- **A camp starts itself.** Lighting a campfire kit begins a fresh camp at that capacity
  and tells the group, and placing something more than an hour after anything last went on
  the fire is taken as a new one, since camp buffs last an hour. You should not have to
  press "new camp".
- The Place tab puts itself away while you are in combat rather than trying to rearrange
  protected buttons, and comes back the moment combat ends.
- Horde players get the Horde Faction Banner, which is a different item with a different
  spell from the Alliance one.

**Known limits, unchanged**

- This beta build writes saved settings but never reads them back, so professions, Legacy
  ranks and alt cooldowns start fresh each session. The addon says so at login.
- Nothing in the group-sharing half has been confirmed to reach another player.
- Whether the client lets an addon's button use an item is the least proven thing here:
  no Blizzard code in the 1.60.1 interface sets that attribute at all. `/fk caps` shows
  `secureButtons`, and if it does not work the panel records placements instead and says
  so rather than pretending.

## 0.2.1 — 20 September 2026

Fixes for the panel that shipped in 0.2.0, found by reviewing it afterwards.

- **The Place tab was telling you to skip the object it was recommending.** It reddened
  anything whose buff was already covered, including the tier-2 and tier-3 objects that
  merely *carry* a lower tier's buff — so the Camp tab would suggest a Master Forge while
  the Place tab painted that same forge red and called it wasted. A Master Forge is a
  blacksmithing workspace; nothing covers that. Roughly twenty of the thirty-nine objects
  were affected whenever any class buff covered a carried buff.
- **Clicking the first camp on the Find tab did nothing.** If the list had ever been empty
  — which it is when you open the panel — the first row kept a do-nothing handler for the
  rest of the session. Setting a waypoint is that tab's only action.
- A full fire now refuses another object instead of showing "4 of 3 slots used", and that
  is fixed in the camp itself, so `/fk place` gets it too.
- The Legacy rank boxes no longer wipe what you are typing when the panel refreshes.
- The You tab was silently cutting off the client report, hiding the saved-settings warning
  with it. It now lists what this client refuses, with a count.
- A tab that hits an error says so once, rather than quietly showing stale content.
- Much less work per refresh: the camp is planned once instead of three times, and auras
  are read once instead of three or four times. In a forty-man raid that was several
  thousand API calls every five seconds.

## 0.2.0 — 20 September 2026

- The panel is now five tabs and covers everything the addon does, so nothing needs a slash
  command any more. **Place** shows every object you can place as icons, coloured green for
  the best choice here and red for one that would be wasted, and you put an object on the
  fire by clicking it. **Buffs** answers the min-maxing question directly: every camp buff,
  and whether it is missing, available from somebody standing here, already burning, or
  already covered by a class buff. **Find**, **Camp** and **You** carry the rest, including
  Legacy ranks and profession skills you can type into a box instead of a command.
- Icon buttons on the title bar for announcing, looking for camps and starting a fresh one.
- Click a camp on the **Find** tab to put a waypoint on it, and set a profession by hand on
  **You** by cycling to its name and typing a skill level. Those were the last two things
  that still needed a slash command, and one of them was being advertised inside the panel.

**Known limits, unchanged from 0.1.1**

- This beta build writes saved settings but never reads them back, so professions, Legacy
  ranks and alt cooldowns start fresh each session. The addon says so at login.
- Nothing in the group-sharing half has been confirmed to reach another player.
- Every camp object effect is read from the client's tooltip data rather than seen in game.
- The panel itself has been executed against a mock but never looked at by a human, so
  expect rough edges in the layout rather than in the behaviour.

## 0.1.1 — 20 September 2026

Bug fixes, all of them found by running this repository's own `addon-reviewer` over the
0.1.0 code. Nothing in 0.1.0 was reviewed before it shipped; this is that review.

- **A well-developed character's data never reached the group.** Every object id was
  concatenated into one addon message with no length check: three maxed professions came to
  269 bytes against a 255 limit, and all twelve to 499. Over the limit the client rejects
  the message outright, so it failed silently for exactly the players with the most to
  offer — their groupmates saw them as "no Firekeeper" for ever. Messages are now packed to
  fit, and an upgraded campfire you need a blueprint for is no longer advertised as
  something you can place.
- **A paladin's blessing could hide the wrong camp buff.** All twelve blessings were treated
  as Blessing of Might, so somebody running Blessing of Salvation made the planner drop the
  Lodestone and the camp went without its Attack Power. Five other buffs — Strength, Armor,
  critical strike, mana regeneration and all stats — had no aura mapped at all, which made
  the planner *worse* whenever it could actually read auras than when it could not.
- **The last member of a raid was invisible**, and you were counted twice, because raid
  slots were counted like party slots.
- **Restricted unit names could throw**, repeatedly: the panel refreshes every five seconds,
  and every name went into a comparison and a table key without being checked first.
- **Camp discovery said more than it should.** Every host on the realm answered every
  `/fk find` on the realm, because the map the seeker asked about was never read. `/fk host`
  reported success without checking anything was sent. A forced announce ignored the
  throttle, so a guild reloading together produced a burst of messages.
- Two guildies standing on the same spot no longer read "right here of here".

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
