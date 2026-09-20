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
		"|cffffff00/fk cd|r — cooldowns for your characters",
		"|cffffff00/fk prof <name> <skill>|r — set a profession by hand",
		"|cffffff00/fk legacy <fieldGuide|permanence> <rank>|r — record Legacy ranks",
		"|cffffff00/fk caps|r — what this client lets the addon do",
		"|cffffff00/fk gaps|r — camp objects still missing from the data",
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
