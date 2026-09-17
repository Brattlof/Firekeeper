# Addon message protocol

Prefix: `FKPR1`. The trailing digit is the protocol version; a breaking change becomes
`FKPR2` so old clients simply stop hearing it instead of misreading it.

Messages go to `RAID`, then `PARTY`, then `GUILD`, whichever applies first. Whether
ordinary addons may send them on Forever is unverified (docs/RESEARCH.md, FK-4); when
`C_ChatInfo` is missing or a send throws, the addon disables comms for the session and
keeps planning locally.

## Messages

| Message | Shape | Meaning |
| --- | --- | --- |
| `HELLO` | `HELLO:<version>` | I just logged in. Everyone answers with `OBJ`. |
| `OBJ` | `OBJ:<version>\|<id,id,id>\|<readyIn>` | What I can place, and my cooldown in seconds. |
| `CAMP` | `CAMP:<slots>\|<id,id>` | The fire I am at: its capacity and what is on it. |

Object ids are the `id` field from `Data/CampObjects.lua`, so two clients with different
data versions still understand each other's known objects. An id the receiver does not
recognise is kept and surfaced as `unknownObjects` in the plan rather than dropped, which
is how a player learns that their addon is out of date.

## Rules

- Outgoing announcements are throttled to one every five seconds.
- `CAMP` is only adopted when the sender knows about at least as many placed objects as
  we do, so a latecomer's empty view never wipes a filled camp.
- Nothing is sent in response to combat, and no message triggers an action: messages
  change what the panel shows, never what the player does.
- The protocol carries no data about a player beyond their camp objects and cooldown.
