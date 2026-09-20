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

## Where the data came from

Wowhead's Forever branch exposes a JSON tooltip endpoint:

```
https://nether.wowhead.com/forever/tooltip/item/279962
```

It returns the item's name and its full rendered tooltip. The `/forever/` prefix is
load-bearing — the same id without it is a 404 — and there is a matching
`/forever/tooltip/spell/<id>` for the spell an object casts.

Every row in `Data/CampObjects.lua` was read from there, and every `itemId` was checked by
fetching it and confirming the name came back as expected. So the ids are verified, not
assumed, and anyone can re-check a row with one URL. That is also the right first step for
a new object: read the tooltip before asking someone to look in game.

## What is known, and what is not

All 38 objects have a sourced effect. The buffs, with their exclusivities:

| Object | Profession | Buff | Does not stack with |
| --- | --- | --- | --- |
| Mana Well | Alchemy | Mana per 5 sec, [10][15][20][24][29] | Blessing of Wisdom |
| Sharpening Wheel | Blacksmithing | Strength, [6][11][20][34] | Strength of Earth Totem |
| Enchanted Lute | Enchanting | Armor, [28][71][114][163][211][260][308] | Mark of the Wild |
| Incense Candle | Herbalism | Intellect, [2][6][12][18][25] | Arcane Intellect |
| Lodestone | Mining | Melee Attack Power, [12][20][32][49][67][90] | Blessing of Might |
| Camp Chair | Skinning | 2% critical strike | Moonkin Aura |
| Faction Banner | Tailoring | Spirit, [14][19][27][32] | Divine Spirit |
| First Aid Kit | First Aid | Stamina, [3][8][21][34][45][56] | Power Word: Fortitude |
| Fish Bowl | Fishing | 8% all stats | Blessing of Kings |

Engineering's Reagent Bot and Leatherworking's Camp Tent give a utility rather than a buff,
so no class buff competes with them.

Three things are worth knowing about this table:

**The Sharpening Wheel is Strength, not Attack Power.** Blizzard's deep dive recap said
Attack Power and every guide site repeated that one sentence. The item's own tooltip says
Strength, exclusive with Strength of Earth Totem. Attack Power is Mining's Lodestone, which
is most likely what the recap confused it with.

**The amounts are level bands with no key.** Each buff lists four to seven values and
nothing says which player level each one applies at (docs/RESEARCH.md, FK-18). The values
are exact; the thresholds are not known.

**Cooking is not three objects.** The three campfire kits are the fire itself — each allows
a number of *additional* camp features — and Cooking's two placeable features are Cookie's
Feast and the Iron Oven. The widely copied guide-site claim that Cooking's tiers are
Basic/Journeyman/Expert Campfire Kit is wrong about what they are, though right that they
exist.

Still missing: **where any Blueprint drops** (FK-17). No source names a single boss and the
tooltips are silent on acquisition. That is now the largest hole in the table.

Nothing here has been read off a live client by a player. Wowhead's database is datamined,
so everything is `reported` rather than `confirmed`; a tooltip screenshot from the beta
would promote a row.

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
