local _, FK = ...

-- Who is at the fire, what they can place, and which buffs their classes
-- already cover. Group members are known from the API; what each of them can
-- place only arrives if they also run Firekeeper, so everyone else is listed
-- as "unknown" rather than assumed to have nothing.
local Roster = FK.RegisterModule("Roster", {})
FK.Roster = Roster

Roster.players = {} -- name -> { name, class, objects, ready, readyIn, lastSeen, self }

local STALE_AFTER = 15 * 60

--- A name we can actually use, or nil.
--
-- `UnitName` is marked SecretWhenUnitNameIdentityRestricted, and both of its
-- returns come from that one call, so both have to be tested. A secret here
-- would otherwise be compared to "", concatenated, and then used as a table
-- key — three things that throw.
function Roster.PlayerKey(name, realm)
	if FK.IsSecret(name) or FK.IsSecret(realm) then
		return nil
	end
	if not name or type(name) ~= "string" then
		return nil
	end
	if realm and type(realm) == "string" and realm ~= "" then
		return name .. "-" .. realm
	end
	return name
end

function Roster.SelfKey()
	local ok, name, realm = pcall(UnitName, "player")
	if not ok then
		return nil
	end
	if FK.IsSecret(realm) or type(realm) ~= "string" or realm == "" then
		realm = GetRealmName and GetRealmName() or nil
		if FK.IsSecret(realm) then
			realm = nil
		end
	end
	return Roster.PlayerKey(name, realm)
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
	local inRaid = IsInRaid and IsInRaid()
	local unitPrefix = inRaid and "raid" or "party"

	local function add(unit)
		if not UnitExists(unit) then
			return
		end
		local ok, name, realm = pcall(UnitName, unit)
		if not ok then
			return
		end
		local key = Roster.PlayerKey(name, realm)
		if key then
			seen[key] = true
			local _, class = UnitClass(unit)
			self:Upsert(key, { class = class, inGroup = true })
		end
	end

	add("player")
	-- raid1..raidN covers the whole raid including you, while party1..partyN-1
	-- does not cover you. Counting raids like parties left the last member out.
	for index = 1, inRaid and members or math.max(members - 1, 0) do
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

--- Buff groups the group already covers, so the planner can skip them.
--
-- An observed aura beats a guess: a mage standing at the fire only means
-- Arcane Intellect is *possible*. When the client lets us read auras we use
-- what people are actually carrying, and otherwise fall back to assuming a
-- class provides its buff, which is the older and more optimistic answer.
function Roster:Coverage()
	local observed = FK.Auras and FK.Auras:Coverage()
	if observed then
		return observed
	end

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
