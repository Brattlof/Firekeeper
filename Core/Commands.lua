local _, FK = ...

local Commands = FK.RegisterModule("Commands", {})

local handlers = {}

local function usage()
	FK.Print("commands:")
	for _, line in ipairs({
		"|cffffff00/fk|r — open the camp panel",
		"|cffffff00/fk new [slots|campfire]|r — start a fresh camp (default 3 slots)",
		"|cffffff00/fk place <object>|r — record what you put on the fire",
		"|cffffff00/fk plan|r — print the suggested placements",
		"|cffffff00/fk announce|r — post the camp to party or say",
		"|cffffff00/fk find [n]|r — camps other people are hosting; a number sets a waypoint",
		"|cffffff00/fk host|r — tell people where this fire is, or stop",
		"|cffffff00/fk guild [share]|r — guildies nearby; `share` toggles sharing your own spot",
		"|cffffff00/fk buffs [key]|r — class buffs your group is missing; a key toggles an optional one",
		"|cffffff00/fk cd|r — cooldowns for your characters",
		"|cffffff00/fk train|r — what each profession can place, and what is next",
		"|cffffff00/fk prof <name> <skill>|r — set a profession by hand",
		"|cffffff00/fk legacy <fieldGuide|permanence> <rank>|r — record Legacy ranks",
		"|cffffff00/fk caps|r — what this client lets the addon do",
		"|cffffff00/fk gaps|r — camp objects still missing from the data",
		"|cffffff00/fk minimap|r — show or hide the minimap button",
		"|cffffff00/fk debug|r — toggle debug output",
	}) do
		FK.Print(line)
	end
end

function handlers.plan()
	local plan = FK.Camp:Plan()
	FK.Print("camp: %d/%d slots used.", plan.used, plan.capacity)

	if #plan.suggestions == 0 then
		FK.Print("no suggestions: nobody nearby has an object that would add something.")
	end
	for _, suggestion in ipairs(plan.suggestions) do
		FK.Print("  %s should place |cffffff00%s|r", suggestion.player, suggestion.name)
	end
	for _, entry in ipairs(plan.redundant) do
		FK.Print("  |cff888888skip %s (%s) — %s|r", entry.name, entry.player, FK.Plan.ReasonText(entry.reason))
	end
	for _, entry in ipairs(plan.waiting) do
		FK.Print("  |cff888888%s is on cooldown for %s|r", entry.player, FK.Cooldowns.Format(entry.readyIn))
	end

	local silent = FK.Roster:Silent()
	if #silent > 0 then
		FK.Print("|cff888888no Firekeeper data from: %s|r", table.concat(silent, ", "))
	end
	if plan.uncertain then
		FK.Print("|cff888888some of this rests on datamined values; see /fk gaps|r")
	end
end

function handlers.new(rest)
	rest = (rest or ""):gsub("^%s*(.-)%s*$", "%1")
	local slots = tonumber(rest)

	if rest ~= "" and not slots then
		slots = FK.Data.SlotsForCampfireName(rest)
		if not slots then
			FK.Print("|cffff4040no campfire called '%s'|r. Try a number, or: %s",
				rest, table.concat(FK.Data.CampfireNames(), ", "))
			return
		end
	end

	if slots then
		if slots < 1 or slots ~= math.floor(slots) then
			FK.Print("|cffff4040a camp holds a whole number of objects, at least one|r")
			return
		end
		local max = FK.Data.MaxCampfireSlots()
		if slots > max then
			FK.Print("|cff888888the largest campfire known holds %d; using that|r", max)
			slots = max
		end
	end

	FK.Camp:Reset(slots)
	FK.Print("new camp with %d slots.", FK.Camp.slots)
end

function handlers.place(rest)
	if not rest or rest == "" then
		FK.Print("what did you place? e.g. |cffffff00/fk place sharpening_wheel|r")
		return
	end
	local objectId = rest:lower():gsub("%s+", "_")
	local ok, err = FK.Camp:MarkPlaced(FK.Roster.SelfKey(), objectId)
	if ok then
		FK.Print("noted: %s.", FK.Data.GetObject(objectId).name)
	else
		FK.Print("|cffff4040%s|r", err)
	end
end

function handlers.announce()
	FK.Camp:Announce()
end

function handlers.cd()
	local now = time and time() or 0
	local any = false
	for key in pairs(FK.db.characters) do
		any = true
		FK.Print("  %s: %s", key, FK.Cooldowns.Format(FK.Cooldowns.ForCharacter(key, now)))
	end
	if not any then
		FK.Print("no camp objects placed yet on any character.")
		if not FK.savedVariablesLoaded then
			FK.Print("|cff888888this list is per session: the client did not give back what was saved.|r")
		end
	end
end

function handlers.prof(rest)
	local name, skill = rest:match("^(%a[%a%s]-)%s+(%d+)$")
	if not name then
		FK.Print("usage: |cffffff00/fk prof Blacksmithing 145|r")
		return
	end
	FK.Professions:Set(name, skill)
	FK.Print("%s set to %s.", name, skill)
	FK.Comm:Announce(true)
end

function handlers.legacy(rest)
	local perk, rank = rest:match("^(%a+)%s+(%d+)$")
	if not perk or FK.db.legacy[perk] == nil then
		FK.Print("usage: |cffffff00/fk legacy fieldGuide 2|r (perks: fieldGuide, permanence)")
		return
	end
	FK.db.legacy[perk] = tonumber(rank)
	FK.Print("%s rank %s. Camp object cooldown is now %s.", perk, rank,
		FK.Cooldowns.Format(FK.Cooldowns.Duration(FK.db.legacy)))
end

function handlers.buffs(rest)
	rest = (rest or ""):gsub("^%s*(.-)%s*$", "%1"):lower()
	if rest ~= "" then
		local buff = FK.Data.classBuffByKey[rest]
		if not buff or not buff.optional then
			FK.Print("|cffff4040'%s' is not a buff you can turn on or off|r. Optional: %s",
				rest, table.concat(FK.Data.OptionalBuffKeys(), ", "))
			return
		end
		FK.db.optionalBuffs[rest] = not FK.db.optionalBuffs[rest]
		FK.Print("%s is now %s.", buff.label, FK.db.optionalBuffs[rest] and "watched" or "ignored")
		return
	end

	local result = FK.Auras:Missing()

	if result.members == 0 then
		FK.Print("nobody to check, not even you.")
		return
	end
	if result.unreadable >= result.members then
		FK.Print("this client will not show auras right now (see |cffffff00/fk caps|r).")
		FK.Print("|cff888888in combat, an encounter or a rated match that is expected.|r")
		return
	end

	if #result.missing == 0 then
		FK.Print("everyone here has the buffs their classes can give.")
	else
		FK.Print("missing buffs:")
		for _, entry in ipairs(result.missing) do
			FK.Print("  %s", FK.Buffs.MissingText(entry))
		end
	end

	if FK.Auras.stale then
		FK.Print("|cff888888some of that is the last reading we could take, not the current one.|r")
	end
	if result.unreadable > 0 then
		FK.Print("|cff888888%d of %d players could not be read.|r", result.unreadable, result.members)
	end
end

function handlers.find(rest)
	local index = tonumber(rest)
	local found = FK.Discovery.Found()

	if index then
		local camp = found[index]
		if not camp then
			FK.Print("|cffff4040there is no camp %d in the list|r", index)
			return
		end
		if FK.Discovery.Waypoint(camp) then
			FK.Print("waypoint set on %s's camp.", camp.host)
		else
			FK.Print("%s's camp is at |cffffff00%.1f, %.1f|r (no waypoint on this client).",
				camp.host, camp.x * 100, camp.y * 100)
		end
		return
	end

	FK.Discovery:Seek()

	if #found == 0 then
		FK.Print("no camps heard of yet. Asking; try again in a moment.")
		FK.Print("|cff888888only people running Firekeeper and hosting a fire show up here.|r")
		return
	end

	FK.Print("camps heard of (|cffffff00/fk find <n>|r for a waypoint):")
	for position, camp in ipairs(found) do
		local where = camp.sameMap and ("%.1f, %.1f"):format(camp.x * 100, camp.y * 100) or "another map"
		if camp.otherLayer then
			where = where .. " |cffff8c38on another layer|r"
		end
		FK.Print("  %d. %s — %d of %d slots free, %s%s",
			position, camp.host, camp.free, camp.slots, where,
			#camp.professions > 0 and (" (" .. table.concat(camp.professions, ", ") .. ")") or "")
	end
end

function handlers.host()
	if FK.Discovery.hosting then
		FK.Discovery:StopHosting()
		FK.Print("packed up: no longer telling people about this fire.")
		return
	end
	local ok, err = FK.Discovery:StartHosting()
	if ok then
		FK.Print("hosting: people running Firekeeper can now find this fire.")
	else
		FK.Print("|cffff4040%s|r", err)
	end
end

function handlers.guild(rest)
	rest = (rest or ""):gsub("^%s*(.-)%s*$", "%1"):lower()

	if rest == "share" then
		local on = FK.Discovery:SetSharing(not FK.db.shareWithGuild)
		FK.Print("sharing your position with the guild is now %s.", on and "on" or "off")
		return
	end

	local guildies = FK.Discovery.Guildies()
	if #guildies == 0 then
		FK.Print("no guildies are sharing their position.")
	else
		FK.Print("guildies running Firekeeper:")
		for _, entry in ipairs(guildies) do
			FK.Print("  %s", FK.Nearby.Line(entry, FK.Discovery.ZoneName(entry.uiMapID)))
		end
	end

	if not FK.db.shareWithGuild then
		FK.Print("|cff888888you are not sharing yours. |cffffff00/fk guild share|r|cff888888 turns it on.|r")
	end
end

function handlers.train()
	local entries = FK.Route.Evaluate(FK.Professions.known)
	if #entries == 0 then
		FK.Print("no professions detected. |cffffff00/fk prof Blacksmithing 145|r sets one by hand.")
		return
	end
	FK.Print("camp objects by profession:")
	for _, entry in ipairs(entries) do
		FK.Print("  %s", FK.Route.Line(entry))
	end
end

function handlers.minimap()
	local shown = FK.db.minimap.hide -- hidden now means show it
	if not FK.MinimapButton:SetShown(shown) then
		FK.Print("|cffff4040this client has no minimap frame to put a button on|r")
		return
	end
	FK.Print("minimap button %s.", shown and "shown" or "hidden")
end

function handlers.caps()
	for _, line in ipairs(FK.Capabilities.Report()) do
		FK.Print(line)
	end
end

function handlers.gaps()
	local gaps = FK.Data.Gaps()
	local unknown = FK.Data.UnknownEffects()
	if #gaps == 0 and #unknown == 0 then
		FK.Print("every profession has all three objects, and every effect is recorded.")
		return
	end
	if #gaps > 0 then
		FK.Print("camp objects still missing (please report them, see the README):")
		for _, gap in ipairs(gaps) do
			FK.Print("  %s: %d of 3 known", gap.profession, gap.known)
		end
	end
	if #unknown > 0 then
		-- Grouped by profession: listing 26 objects one per line buries the chat frame.
		local byProfession, order = {}, {}
		for _, object in ipairs(unknown) do
			if not byProfession[object.profession] then
				byProfession[object.profession] = {}
				table.insert(order, object.profession)
			end
			table.insert(byProfession[object.profession], object.name)
		end
		FK.Print("named, but nobody has reported what they do (%d):", #unknown)
		for _, profession in ipairs(order) do
			FK.Print("  %s: %s", profession, table.concat(byProfession[profession], ", "))
		end
	end
end

function handlers.debug()
	FK.db.debug = not FK.db.debug
	FK.Print("debug %s.", FK.db.debug and "on" or "off")
end

--- Runs a slash command by name, for the minimap button and anything else
-- that wants the same behaviour as typing it.
function Commands.Run(command, rest)
	local handler = handlers[command]
	if not handler then
		return false
	end
	handler(rest or "")
	return true
end

function Commands:OnLoad()
	SLASH_FIREKEEPER1 = "/fk"
	SLASH_FIREKEEPER2 = "/firekeeper"
	SlashCmdList.FIREKEEPER = function(input)
		local command, rest = (input or ""):match("^(%S*)%s*(.-)$")
		command = command:lower()

		if command == "" then
			FK.UI:Toggle()
		elseif command == "help" or command == "?" then
			usage()
		elseif handlers[command] then
			handlers[command](rest)
		else
			FK.Print("unknown command |cffffff00%s|r", command)
			usage()
		end
	end
end
