# Open questions about the Forever client

Blizzard has published no addon API notes for World of Warcraft: Forever. The client
reports `Interface: 120000` and pairs the modern UI architecture with a vanilla game, so
neither Classic Era habits nor retail habits can be assumed to hold.

Every question below is answered the same way: run the addon on the beta, type
`/fk caps`, and report what you see. A question closes when someone states the client
build they tested on and what actually happened.

| ID | Question | What it changes | How to answer it |
| --- | --- | --- | --- |
| FK-1 | Does `GetProfessions` / `C_TradeSkillUI` work for an ordinary addon? | Whether professions are detected or typed in with `/fk prof` | `/fk caps` line `professionsApi`, then `/fk plan` with a known profession |
| FK-2 | Does an upgraded campfire occupy an object slot, or replace the fire? | The planner currently assumes it replaces the fire, `Core/Plan.lua` | Place a cook's upgraded campfire on a full basic fire and count the slots |
| FK-3 | Can Legacy perk ranks be read from the API? | Ranks are typed in with `/fk legacy` today | Look for a Legacy namespace in the client's API and report it |
| FK-4 | May ordinary addons send addon messages, and in which channels? | Whether the group shares a plan or everyone plans alone | `/fk caps` line `addonComm`, then `/fk plan` in a party of two |
| FK-5 | Is a campsite's contents readable: slots used, objects placed, who placed them? | Today the camp is assembled from what players report to each other | Stand at a fire somebody else built and look for an API that describes it |
| FK-6 | Which UI templates exist (`BasicFrameTemplateWithInset`, `UIPanelButtonTemplate`)? | Panel styling, `UI/CampFrame.lua` falls back to a bare frame | `/fk` and report whether the panel has a border and buttons |
| FK-7 | Do camp buffs and class buffs really overwrite rather than stack? | The whole point of the planner | Take Blessing of Might, then rest at a fire with a Sharpening Wheel, and watch the aura |
| FK-8 | Is the object cooldown one hour per player, per camp, or per object? | `Core/Cooldowns.lua` assumes one hour per player | Place an object, then try a second one at another fire |

Two related pieces of community work are worth reading before adding to this list:
[ForeverTome's API handbook](https://github.com/Skold177/ForeverTome/tree/main/docs), which
catalogues restrictions and secret values in detail, and
[forever-bugs](https://github.com/ClassicWoWCommunity/forever-bugs) for client behaviour
in general.

## The rule this project follows

An API that has not been observed working on Forever is treated as absent. It gets a
probe in `Core/Capabilities.lua`, a fallback that still does something useful, and a row
in this table. No feature is allowed to depend on an assumption that has not been written
down here.
