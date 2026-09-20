# Addon message protocol

Prefix: `FKPR1`. The trailing digit is the protocol version; a breaking change becomes
`FKPR2` so old clients simply stop hearing it instead of misreading it.

`HELLO`, `OBJ` and `CAMP` go to `RAID`, then `PARTY`, then `GUILD`, whichever applies
first. Whether ordinary addons may send them on Forever is unverified
(docs/RESEARCH.md, FK-4); when `C_ChatInfo` is missing or a send throws, the addon
disables comms for the session and keeps planning locally.

`POS` and `GONE` go to `GUILD` and nowhere else. They are sent only while the player
has turned sharing on with `/fk guild share`, which is off by default and survives a
reload; nothing is sent from inside an instance, where the game gives no position.

The camp channel is joined the first time `/fk find` or `/fk host` is typed, never at
login. Joining is one of the actions this client refuses to a timer or an event handler, so
it has to hang off something the player did (FK-19). `JoinChannelByName` is used rather than
`JoinPermanentChannel`, which would be written into the player's chat settings and can take
the /1 slot.

`HOST`, `SEEK` and `PACK` are about finding strangers, so they go to the custom channel
`FirekeeperCamps`, which the addon joins ten seconds after login. Nothing is sent there
unless the player types `/fk host` or `/fk find`. Outgoing addon chat is permitted realm
by realm (FK-11), so on a realm that refuses, hosting silently does nothing rather than
erroring.

## Messages

| Message | Shape | Meaning |
| --- | --- | --- |
| `HELLO` | `HELLO:<version>` | I just logged in. Everyone answers with `OBJ`. |
| `OBJ` | `OBJ:<version>\|<id,id,id>\|<readyIn>` | What I can place, and my cooldown in seconds. |
| `CAMP` | `CAMP:<slots>\|<id,id>` | The fire I am at: its capacity and what is on it. |
| `HOST` | `HOST:<uiMapID>\|<x>\|<y>\|<free>\|<slots>\|<layer>\|<professions>` | I am sitting at a fire here, and this much of it is free. `layer` is 0 when unknown. |
| `SEEK` | `SEEK:<uiMapID>` | Is anyone hosting a fire? Only hosts answer. |
| `PACK` | `PACK:` | I have packed up; forget my fire. |
| `POS` | `POS:<uiMapID>\|<x>\|<y>` | Where I am, to my guild only, and only while I share. |
| `GONE` | `GONE:` | I stopped sharing; forget where I was. |

Object ids are the `id` field from `Data/CampObjects.lua`, so two clients with different
data versions still understand each other's known objects. An id the receiver does not
recognise is kept and surfaced as `unknownObjects` in the plan rather than dropped, which
is how a player learns that their addon is out of date.

## Rules

- Outgoing announcements are throttled to one every five seconds. A host repeats itself
  at most every 90 seconds, and `/fk find` may only ask once every 10, which keeps the
  addon well inside the roughly 10-message burst a prefix is allowed.
- A `SEEK` is answered only by someone actually hosting. An empty field stays silent
  rather than returning a chorus of "not me".
- `CAMP` is only adopted when the sender knows about at least as many placed objects as
  we do, so a latecomer's empty view never wipes a filled camp.
- Nothing is sent in response to combat, and no message triggers an action: messages
  change what the panel shows, never what the player does.
- The protocol carries no data about a player beyond their camp objects, cooldown, and
  map coordinates. Coordinates are sent in exactly two cases, both opt-in and both
  revocable in one command: while hosting a fire (`/fk host`, to the open channel), and
  while sharing with the guild (`/fk guild share`, to the guild and nobody else).
- Positions are sent as whole basis points, not floats, which keeps a message short and
  lands within a couple of yards.
- `HOST` carries the sender's layer so a seeker is not walked to coordinates on a shard
  they cannot reach. A reader that predates the field still parses the rest, and a camp
  is only called "on another layer" when both ends know their own — unknown is not the
  same as elsewhere.
