local _, FK = ...

-- Who is at the fire, what they can place, and which buffs their classes
-- already cover. Group members are known from the API; what each of them can
-- place only arrives if they also run Firekeeper, so everyone else is listed
-- as "unknown" rather than assumed to have nothing.
local Roster = FK.RegisterModule("Roster", {})
FK.Roster = Roster

Roster.players = {} -- name -> { name, class, objects, ready, readyIn, lastSeen, self }

local STALE_AFTER = 15 * 60

function Roster.PlayerKey(name, realm)
	if not name then
		return nil
	end
	if realm and realm ~= "" then
		return name .. "-" .. realm
	end
	return name
end

function Roster.SelfKey()
	local name, realm = UnitName("player")
	return Roster.PlayerKey(name, realm ~= "" and realm or GetRealmName and GetRealmName() or nil)
end

function Roster:Upsert(name, fields)
	if not name then
		return
	end
	local player = self.players[name] or { name = name }
	for key, value in pairs(fields or {}) do
		player[key] = value
	end
	player.lastSeen = GetTime and GetTime() or 0
	self.players[name] = player
	return player
end

function Roster:Forget(name)
	self.players[name] = nil
end

--- Refreshes group members from the API, keeping whatever their addon told us.
function Roster:ScanGroup()
	if not FK.Capabilities.Has("groupRoster") then
		return self.players
	end

	local seen = {}
	local members = GetNumGroupMembers() or 0
	local unitPrefix = IsInRaid and IsInRaid() and "raid" or "party"

	local function add(unit)
		if not UnitExists(unit) then
			return
		end
		local name, realm = UnitName(unit)
		local key = Roster.PlayerKey(name, realm)
		if key then
			seen[key] = true
			local _, class = UnitClass(unit)
			self:Upsert(key, { class = class, inGroup = true })
		end
	end

	add("player")
	for index = 1, math.max(members - 1, 0) do
		add(unitPrefix .. index)
	end

	for key, player in pairs(self.players) do
		if player.inGroup and not seen[key] then
			player.inGroup = false
		end
	end

	return self.players
end

function Roster:Prune()
	local now = GetTime and GetTime() or 0
	for key, player in pairs(self.players) do
		if not player.inGroup and not player.isSelf and (now - (player.lastSeen or 0)) > STALE_AFTER then
			self.players[key] = nil
		end
	end
end

--- Buff groups the classes present already cover, so the planner can skip them.
function Roster:Coverage()
	local classes = {}
	for _, player in pairs(self.players) do
		if player.class then
			table.insert(classes, player.class)
		end
	end
	return FK.Data.CoverageForClasses(classes)
end

--- Contributors in the shape Plan.Evaluate wants.
function Roster:Contributors(now)
	local contributors = {}
	for key, player in pairs(self.players) do
		if player.objects and #player.objects > 0 then
			local readyIn = player.readyIn or 0
			if player.isSelf then
				readyIn = FK.Cooldowns.ForCharacter(key, now or (time and time() or 0))
			end
			table.insert(contributors, {
				name = key,
				objects = player.objects,
				ready = readyIn <= 0,
				readyIn = readyIn,
			})
		end
	end
	table.sort(contributors, function(a, b) return a.name < b.name end)
	return contributors
end

--- Group members we have heard nothing from: they may still be able to help.
function Roster:Silent()
	local silent = {}
	for key, player in pairs(self.players) do
		if player.inGroup and not player.objects then
			table.insert(silent, key)
		end
	end
	table.sort(silent)
	return silent
end

function Roster:OnLogin()
	FK.eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
	FK.eventFrame:HookScript("OnEvent", function(_, event)
		if event == "GROUP_ROSTER_UPDATE" then
			Roster:ScanGroup()
			if FK.Comm then
				FK.Comm:Announce()
			end
		end
	end)

	local selfKey = Roster.SelfKey()
	local _, class = UnitClass("player")
	self:Upsert(selfKey, { class = class, isSelf = true, inGroup = true })
	self:ScanGroup()
end
