# The camp object data

`Data/CampObjects.lua` is the addon's picture of what each profession can put on a fire.
It is incomplete, and it says so rather than filling gaps with plausible-sounding
entries.

## Confidence

Every object carries one of three levels:

| Level | Meaning | Shown as |
| --- | --- | --- |
| `confirmed` | Seen in the game client, reported with a build number | no mark |
| `reported` | Named in an official panel, patch note, or guide site | `?` in the panel |
| `unknown` | The object exists, but its effect or skill level is not known | `?` in the panel |

A plan built on anything other than `confirmed` data sets `uncertain`, which is how the
panel knows to mark it and `/fk plan` knows to add a note.

## What is known so far

Nine objects across six professions were shown publicly, mostly at the BlizzCon deep
dive: the Blacksmithing Sharpening Wheel at skill 20, the Tailoring Faction Banner, the
Herbalism Incense Candle, the Alchemy Lab, the Leatherworking Tanning Rack, and the
Cooking campfire upgrades that raise a camp from three objects to five and then ten.

Each profession has three objects, and there are twelve professions. That means roughly
two thirds of the table is still missing. `/fk gaps` prints exactly which professions are
short, which makes the addon its own to-do list during the beta.

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
