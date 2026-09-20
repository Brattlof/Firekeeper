# Open questions about the Forever client

Blizzard has published no addon API notes for World of Warcraft: Forever. The client
reports interface `16001` (version 1.60.1) and pairs the modern UI architecture with a
vanilla game, so neither Classic Era habits nor retail habits can be assumed to hold.

Every question below is answered the same way: run the addon on the beta, type
`/fk caps`, and report what you see. A question closes when someone states the client
build they tested on and what actually happened.

Chat cannot be copied out of WoW, so the addon also writes its own answers down. At login
it records the client build and every capability probe into `FirekeeperDB.diagnostics`,
and the uncertain paths add to it as they run: whether the panel and the minimap button
drew, what index the camp channel joined on, and whether a waypoint was accepted. The
client flushes saved variables on `/reload`, logout or quit, so attaching
`WTF/Account/<account>/SavedVariables/Firekeeper.lua` answers most of the table without
anyone transcribing a line. It only ever writes that file — the beta never reads it back
(FK-9) — so it is a record of the session, not a setting.

| ID | Question | What it changes | How to answer it |
| --- | --- | --- | --- |
| FK-1 | Does `GetProfessions` / `C_TradeSkillUI` work for an ordinary addon? | Whether professions are detected or typed in with `/fk prof` | `/fk caps` line `professionsApi`, then `/fk plan` with a known profession. On 1.60.1.69913 the probe says yes; the `/fk plan` step is still open |
| FK-2 | Does an upgraded campfire occupy an object slot, or replace the fire? | The planner currently assumes it replaces the fire, `Core/Plan.lua` | Place a cook's upgraded campfire on a full basic fire and count the slots |
| FK-3 | Can Legacy perk ranks be read from the API? | Ranks are typed in with `/fk legacy` today | Look for a Legacy namespace in the client's API and report it |
| FK-4 | May ordinary addons send addon messages, and in which channels? | Whether the group shares a plan or everyone plans alone | **Answered on 1.60.1.69913, from another addon's field notes.** `AreOutgoingAddonChatMessagesRestricted` returns true here even outside combat or an encounter (`diagnostics.outgoingRestricted = restricted=true`), but that is not a real block: [CooldownCollaborator](https://github.com/Nelnamara/CooldownCollaborator) found it "firing true far more often than expected... blocking every send before it was even attempted" and stopped consulting it. Firekeeper no longer gates on it either. Separately, that addon reports `SendAddonMessage` returning **nil** for success on this client although the declaration says the return is never nil, so `result ~= Enum.SendAddonMessageResult.Success` logged every good send as a failure; `Comm.WasSent` now accepts nil or 0. Prefix registration succeeds (`prefixRegistered = Success (0)`). Still open: a result code from a real send, which needs a group or a guild — a solo character records `firstSend = not sent: in no group, guild or raid`. **Open, and now instrumented.** On 1.60.1.69913 the `addonComm` probe says the API is there, but `addonCommOutgoing` says false. That single boolean cannot tell a realm restriction from a call that errored, so the addon now writes `diagnostics.outgoingRestricted` (the raw answer), `diagnostics.firstSend` (the result code of a real send) and `diagnostics.prefixRegistered`. `/fk caps` line `addonComm`, then `/fk plan` in a party of two. On 1.60.1.69913 the probe says yes; the party test is still open |
| FK-5 | Is a campsite's contents readable: slots used, objects placed, who placed them? | Today the camp is assembled from what players report to each other | Stand at a fire somebody else built and look for an API that describes it |
| FK-6 | Which UI templates exist (`BasicFrameTemplateWithInset`, `UIPanelButtonTemplate`)? | Panel styling, `UI/CampFrame.lua` falls back to a bare frame | **Also settled by not needing them:** the panel is drawn from plain textures and font strings as of `UI/Theme.lua`, uses no template at all, and `diagnostics.panel` records `drawn` on 1.60.1.69913. **Answered on 1.60.1.69913:** both exist. `/fk` draws the panel with its border and buttons, and both templates are defined in the Forever UI source (`Blizzard_UIPanelTemplates/Mainline/UIPanelTemplates.xml`, `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml`) |
| FK-7 | Do camp buffs and class buffs really overwrite rather than stack? | The whole point of the planner | Take Blessing of Might, then rest at a fire with a Sharpening Wheel, and watch the aura |
| FK-8 | Is the object cooldown one hour per player, per camp, or per object? | `Core/Cooldowns.lua` assumes one hour per player | Place an object, then try a second one at another fire |
| FK-9 | Does the client read saved variables back? A community report says the beta writes them on exit but never loads them | Cooldowns, Legacy ranks and the debug flag survive a session only if it does, `Core/Init.lua` | **Answered on 1.60.1.69913: no.** After `/fk legacy fieldGuide 2` and two `/reload`s, the first write held rank 2 and the second was back to the default 0. BugGrabber's session counter also stayed at 1 across reloads. Saving works; loading does not |
| FK-10 | May an ordinary addon read auras on party members, and when do they come back secret? | Whether `/fk buffs` works and whether the planner trusts observed auras or guesses from class, `Core/Auras.lua` | **Partly answered on 1.60.1.69913:** `unitAuras` and `auraRead` both say yes, so an ordinary addon can read an aura outside combat; the probe reads the player's own. Still open: a party member's auras, and what comes back in combat. `/fk caps` lines `unitAuras` and `auraRead`, then `/fk buffs` in a party, in and out of combat |
| FK-11 | May an addon join a custom chat channel and send addon messages to it, and does this realm allow outgoing addon chat at all? | Whether `/fk find` can see strangers' camps, `Core/Discovery.lua` | **Partly answered on 1.60.1.69913:** joining works — `JoinPermanentChannel` put us on `FirekeeperCamps` and `GetChannelName` returned index 6 (`diagnostics.campChannel`). Sending is the open half: `addonCommOutgoing` came back false, which points at a realm restriction, but see FK-4. `/fk caps` lines `customChannel` and `addonCommOutgoing`, then `/fk host` on one character and `/fk find` on another |
| FK-12 | Does `C_Map.SetUserWaypoint` accept a hand-built point table, given `UiMapPoint` is not present on this client? | Whether `/fk find <n>` sets a waypoint or just prints coordinates | `/fk find 1` on a camp you can see and report whether the arrow appeared |
| FK-13 | Does the minimap button draw correctly: is `Minimap` positionable by an addon, and does `Interface\Minimap\MiniMap-TrackingBorder` still exist? | Whether the minimap button appears and can be dragged, `UI/MinimapButton.lua` | **Answered on 1.60.1.69913:** it draws. `diagnostics.minimapButton` records `drawn`, and no Lua error was raised. Whether it sits where a player wants it, and whether the drag saves, is still only visible in game. `/fk caps` line `minimapFrame`, then look at the minimap: the flame icon should sit on the edge with a ring around it, and drag should move it |

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
