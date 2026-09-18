---
name: game-session
description: Read what the Forever client wrote to disk after the user played or typed /reload, including Firekeeper's saved variables, Lua errors captured by BugGrabber, and the taint log. Use after asking the user to try something in game, when they report an in-game error, or before claiming a change works in the client.
allowed-tools: Bash(bash *session.sh*)
---

# Read the last game session

You cannot see the game, but the client leaves evidence on disk. It writes that
evidence only on `/reload`, logout or quit. A running client with an old file therefore
means the user has not reloaded since the thing you care about.

```bash
bash "${CLAUDE_SKILL_DIR}/session.sh"
```

The script prints the following. The client folder is taken from `WOW_DIR`, or defaults
to `C:/Program Files (x86)/World of Warcraft`.

- **Client running or not.**
- **Saved variables.** `FirekeeperDB` is account-wide (`WTF/Account/<account>/SavedVariables/`).
  `FirekeeperCharDB` is per character (`WTF/Account/<account>/<realm>/<character>/SavedVariables/`).
  Each file shows how long ago it was written.
- **Lua errors from BugGrabber**, when installed: Firekeeper's errors from the last
  session in full, with stack and locals, plus counts for other addons and for earlier
  sessions. Parsing them needs `lua5.1` or `luajit`.
- **The taint log** (`Logs/taint.log`), when enabled. Only lines naming Firekeeper are
  shown.

## Getting good evidence

WoW chat cannot be copied, so the user can only read out a word or a number. Design
tests so that the answer ends up on disk:

- Have the addon write the value to its own saved variables, for example with
  `/fk legacy fieldGuide 2`, then ask for a `/reload`.
- The client keeps the previous write as `<file>.lua.bak`. Two `/reload`s therefore
  give you a before and an after.
- Prefer Firekeeper's slash commands to `/run`. In one test on 1.60.1.69913, a `/run`
  assignment never reached the saved variables.

Ask for exactly what to do, in order. Keep anything the user must read out to a yes or
a number. Then run the script. Useful commands to ask for:

| Command | Shows |
| --- | --- |
| `/fk caps` | Build, interface, and which probed APIs this client allows |
| `/dump <expression>` | Any global expression, e.g. `/dump C_ChatInfo.IsAddonMessagePrefixRegistered("FKPR1")`. The addon's `FK` table is private; dump `FirekeeperDB` instead. |
| `/api search <term>` | Blizzard's API documentation, in game |
| `/eventtrace` | Live event log, for "does this event fire here?" |
| `/framestack` | The frame under the cursor |
| `/console scriptErrors 1` | Shows the Lua error popup without BugGrabber |
| `/console taintLog 1` | Starts writing `Logs/taint.log`, for blocked actions |

## When there is nothing to read

- **No Lua errors section**: suggest installing BugGrabber and BugSack. Both declare
  interface 16001. Without them, an error is visible only as a popup the user has to copy.
- **Saved variables back at their defaults after a `/reload`**: this is expected on
  1.60.1.69913. The beta writes saved variables but never reads them back (FK-9). Only
  the write that ends a session carries evidence, and a value set in one session is
  gone in the next.
- Report what the evidence shows and what it does not. Never describe something as
  working in game because the code looks right.
