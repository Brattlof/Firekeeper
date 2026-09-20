# The camp object data

`Data/CampObjects.lua` is the addon's picture of what each profession can put on a fire.
It is incomplete, and it says so rather than filling gaps with plausible-sounding
entries.

## Confidence

`confidence` describes the entry itself — its name, profession and tier:

| Level | Meaning | Shown as |
| --- | --- | --- |
| `confirmed` | Seen in the game client, reported with a build number | no mark |
| `reported` | Named in an official panel, patch note, or guide site | `?` in the panel |
| `unknown` | The object exists, but we cannot place it yet | `?` in the panel |

What the object *does* is tracked separately, in `effect.kind`, because a name can be
well sourced while its buff is not. `effect.kind == "unknown"` is the normal state for
most of the table right now.

A plan built on anything other than `confirmed` data sets `uncertain`, which is how the
panel knows to mark it and `/fk plan` knows to add a note.

## What is known so far

All thirty-six objects — twelve professions, three tiers each — are named, from the
[zockify camping system page](https://www.zockify.com/forever/camping-system/), which
matches the shorter list in the [Icy Veins camping guide](https://www.icy-veins.com/wow-forever/camping).
Tier 1 unlocks at skill 20; tiers 2 and 3 come from Blueprint recipes.

The effects are the hole. Only four are sourced: the Sharpening Wheel's Attack Power,
the Faction Banner's Spirit, the Incense Candle's Intellect, and the three Cooking
campfire kits that set the camp to three, five and ten slots. The other twenty-six
objects are a name and nothing else.

That is deliberate. A community addon publishes exact buff values and item IDs for all
thirty-six, but it carries no licence and its numbers are not on Wowhead or any guide
site, so they are one person's unverified figures. Copying them would put numbers in
this table that nobody here can stand behind. `/fk gaps` lists those twenty-six instead,
and a tooltip from anyone playing the beta settles one of them for good.

## Adding an object

1. Open a [camp object sighting](../../../issues/new?template=camp-object.yml) with the
   tooltip text, or send a pull request directly.
2. Add an entry to `FK.Data.campObjects` with an `id` in `snake_case`, the profession,
   the tier (1 to 3), the skill level if known, and the effect.
3. Pick the effect kind: `buff` (keyed to `Data/BuffGroups.lua`), `workspace`, `slots`,
   `utility`, or `unknown` when the object is real but its effect is not.
4. Set `confidence`, and add a `note` for anything a reader should not have to guess at.
5. If the object gives a buff that no group in `Data/BuffGroups.lua` covers yet, add the
   group too, along with the class buffs it does not stack with.

Effects that are not `buff` are never treated as redundant, because two workspaces do
different jobs. Two buffs in the same group are interchangeable, and that is what stops
the planner from wasting a slot.
