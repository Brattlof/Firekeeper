# Open questions about the Forever client

Blizzard has published no addon API notes for World of Warcraft: Forever. The client
reports interface `16001` (version 1.60.1) and pairs the modern UI architecture with a
vanilla game, so neither Classic Era habits nor retail habits can be assumed to hold.

Every question below is answered the same way: run the addon on the beta, type
`/fk caps`, and report what you see. A question closes when someone states the client
build they tested on and what actually happened.

| ID | Question | What it changes | How to answer it |
| --- | --- | --- | --- |
| FK-1 | Does `GetProfessions` / `C_TradeSkillUI` work for an ordinary addon? | Whether professions are detected or typed in with `/fk prof` | `/fk caps` line `professionsApi`, then `/fk plan` with a known profession. On 1.60.1.69913 the probe says yes; the `/fk plan` step is still open |
| FK-2 | Does an upgraded campfire occupy an object slot, or replace the fire? | The planner currently assumes it replaces the fire, `Core/Plan.lua` | Place a cook's upgraded campfire on a full basic fire and count the slots |
| FK-3 | Can Legacy perk ranks be read from the API? | Ranks are typed in with `/fk legacy` today | Look for a Legacy namespace in the client's API and report it |
| FK-4 | May ordinary addons send addon messages, and in which channels? | Whether the group shares a plan or everyone plans alone | `/fk caps` line `addonComm`, then `/fk plan` in a party of two. On 1.60.1.69913 the probe says yes; the party test is still open |
| FK-5 | Is a campsite's contents readable: slots used, objects placed, who placed them? | Today the camp is assembled from what players report to each other | Stand at a fire somebody else built and look for an API that describes it |
| FK-6 | Which UI templates exist (`BasicFrameTemplateWithInset`, `UIPanelButtonTemplate`)? | Panel styling, `UI/CampFrame.lua` falls back to a bare frame | **Answered on 1.60.1.69913:** both exist. `/fk` draws the panel with its border and buttons, and both templates are defined in the Forever UI source (`Blizzard_UIPanelTemplates/Mainline/UIPanelTemplates.xml`, `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml`) |
| FK-7 | Do camp buffs and class buffs really overwrite rather than stack? | The whole point of the planner | Take Blessing of Might, then rest at a fire with a Sharpening Wheel, and watch the aura |
| FK-8 | Is the object cooldown one hour per player, per camp, or per object? | `Core/Cooldowns.lua` assumes one hour per player | Place an object, then try a second one at another fire |
| FK-9 | Does the client read saved variables back? A community report says the beta writes them on exit but never loads them | Cooldowns, Legacy ranks and the debug flag survive a session only if it does, `Core/Init.lua` | **Answered on 1.60.1.69913: no.** After `/fk legacy fieldGuide 2` and two `/reload`s, the first write held rank 2 and the second was back to the default 0. BugGrabber's session counter also stayed at 1 across reloads. Saving works; loading does not |
| FK-10 | May an ordinary addon read auras on party members, and when do they come back secret? | Whether `/fk buffs` works and whether the planner trusts observed auras or guesses from class, `Core/Auras.lua` | `/fk caps` lines `unitAuras` and `auraRead`, then `/fk buffs` in a party, in and out of combat |
| FK-11 | May an addon join a custom chat channel and send addon messages to it, and does this realm allow outgoing addon chat at all? | Whether `/fk find` can see strangers' camps, `Core/Discovery.lua` | `/fk caps` lines `customChannel` and `addonCommOutgoing`, then `/fk host` on one character and `/fk find` on another |
| FK-12 | Does `C_Map.SetUserWaypoint` accept a hand-built point table, given `UiMapPoint` is not present on this client? | Whether `/fk find <n>` sets a waypoint or just prints coordinates | `/fk find 1` on a camp you can see and report whether the arrow appeared |
| FK-13 | Does the minimap button draw correctly: is `Minimap` positionable by an addon, and does `Interface\Minimap\MiniMap-TrackingBorder` still exist? | Whether the minimap button appears and can be dragged, `UI/MinimapButton.lua` | `/fk caps` line `minimapFrame`, then look at the minimap: the flame icon should sit on the edge with a ring around it, and drag should move it |

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
