# Firekeeper

An addon for **World of Warcraft: Forever** that helps a group build a good campsite.

A basic campfire holds three objects, each player may add one, and those objects share a
one-hour cooldown. Camp buffs do not stack with the equivalent class buff, so the
Incense Candle's Intellect is wasted if a mage is standing right there. The game does not
tell you what the people around the fire can place. Firekeeper does.

```
Camp: 1/3 slots used

on the fire   Incense Candle — Ana

Suggested
  Bo → Sharpening Wheel ?
  Cy → Alchemy Lab ?

Would be wasted
  Di: Faction Banner — Spirit is already covered by Divine Spirit

On cooldown
  Ez — 42m
```

## What it does

- **Plans the fire.** Everyone running Firekeeper shares which camp objects they can
  place and when their cooldown is up. The planner picks one object per player, never
  two with the same effect, and skips any buff your group's classes already cover.
- **Tracks the shared cooldown**, across your alts, adjusted for the Legacy perk
  Field Guide.
- **Announces the camp** to party, raid, or say, so people know what is up and how many
  slots are free.
- **Finds a fire.** `/fk host` tells other Firekeeper users where your camp is and how
  many slots are free; `/fk find` lists the ones you have heard about, nearest first, and
  `/fk find 2` drops the game's own waypoint on one. Hosting is off until you ask for it.
- **Says what your trades can place.** `/fk train` lists each profession with the camp
  objects you can already put down and how much skill the next one needs.
- **Finds your guild.** `/fk guild` lists guildies running Firekeeper with the distance
  in yards and which way to walk. Sharing your own position is off until you turn it on.
- **Names the buffs you are missing.** `/fk buffs` reads what everyone at the fire is
  actually carrying and says who can fix it, which is also how the planner knows a camp
  object would be wasted. When the client will not show auras it says so instead of
  guessing.
- **Says what it does not know.** `/fk gaps` lists the camp objects still missing from
  the data and `/fk caps` prints which APIs this client actually allows.

## Status

Early, and honest about it. Forever's beta opened on 17 September 2026 and the game
launches on 4 November 2026. Two things are still unsettled:

1. **The data.** Every camp object and every buff amount is in, read from the client's own
   tooltip data. It is datamined rather than seen in game, so it is all marked `reported`. Every entry in `Data/CampObjects.lua` carries a
   confidence level, and anything not yet seen in game is marked with a `?` in the
   panel. See [docs/DATA.md](docs/DATA.md).
2. **The API.** Blizzard has published no addon notes for Forever. Every uncertain call is
   probed once at login (`Core/Capabilities.lua`); when something is missing the addon
   drops to a simpler mode instead of erroring. See [docs/RESEARCH.md](docs/RESEARCH.md).

If addon-to-addon messages turn out to be unavailable, Firekeeper still works as a
single-player planner over what you can see and type.

## The panel

`/fk` opens the camp panel, or left-click the flame on your minimap. The panel is drawn
by the addon rather than borrowed from a Blizzard template, so it looks the same whatever
the client ships: charcoal, an ember rule under the title, and a row of pips showing the
fire's slots — lit for used, dark for free — which is the one thing worth reading from
across the screen. Drag the title bar to move it; it remembers where you put it. The
minimap button is draggable around the edge and can be hidden with `/fk minimap`.

## Install

Copy the repository into the `Interface/AddOns` folder of your Forever install, in a
folder named `Firekeeper`, or download a packaged release. Which product folder Forever
uses is not confirmed yet; it is the one the client writes its `WTF` directory into.

## Commands

| Command | What it does |
| --- | --- |
| `/fk` | Open the camp panel |
| `/fk minimap` | Show or hide the minimap button |
| `/fk new [slots\|campfire]` | Start a fresh camp: a number, or `basic`, `journeyman`, `expert` |
| `/fk place <object>` | Record what you put on the fire |
| `/fk plan` | Print the suggested placements |
| `/fk announce` | Post the camp to party, raid, or say |
| `/fk find [n]` | Camps other people are hosting; a number sets a waypoint |
| `/fk host` | Tell people where this fire is, or stop |
| `/fk guild [share]` | Guildies nearby, and whether you share your own spot |
| `/fk buffs` | Class buffs your group is missing, and who can cast them |
| `/fk cd` | Camp cooldowns for all your characters |
| `/fk train` | What each profession can place, and how far the next one is |
| `/fk prof <name> <skill>` | Set a profession by hand, if the API will not tell us |
| `/fk legacy fieldGuide <rank>` | Record Legacy ranks that change camp maths |
| `/fk caps` | What this client lets the addon do |
| `/fk gaps` | Camp objects still missing from the data |

## Contributing

The most useful thing you can send is a camp object you have actually seen: open a
[camp object sighting](../../issues/new?template=camp-object.yml) and paste the tooltip.
Code contributions are welcome too, see [CONTRIBUTING.md](CONTRIBUTING.md).

The planner is plain Lua with no WoW API in it, so the rules can be tested without
logging in:

```sh
lua5.1 tests/run.lua
```

## License

MIT, see [LICENSE](LICENSE). Not affiliated with Blizzard Entertainment.
