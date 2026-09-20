local _, FK = ...

-- Reading what the people around you are actually carrying.
--
-- On Forever this is allowed to fail in three different ways, so every read is
-- defensive (docs/RESEARCH.md, FK-10):
--
--   * `C_UnitAuras.GetAuraDataByIndex` is marked `RequiresUnitAuraAccess` with
--     `FailureMode = "Error"`, so without access it raises rather than
--     returning nil. Every call is inside a pcall.
--   * It is marked `SecretWhenUnitAuraRestricted`, so in combat, an encounter,
--     a challenge mode or a PvP match the aura comes back as a secret value.
--     A secret cannot be compared or concatenated and may throw even on a
--     truth test, so it is tested with `issecretvalue` before anything else
--     touches it, and dropped there.
--   * The whole namespace may simply not be there.
--
-- When a read fails we keep the last good snapshot rather than claiming the
-- group has nothing, and say it is stale. A wrong "nobody has Fortitude" is
-- worse than an old right answer.
local Auras = FK.RegisterModule("Auras", {})
FK.Auras = Auras

local MAX_AURAS = 40

Auras.lastGood = {} -- player key -> { ["Arcane Intellect"] = true }
Auras.stale = false

--- Every helpful aura on a unit, or nil when this client will not say.
function Auras.ReadUnit(unit)
	if not FK.Capabilities.Has("unitAuras") then
		return nil
	end

	local names = {}
	for index = 1, MAX_AURAS do
		local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, "HELPFUL")
		if not ok then
			return nil
		end
		-- Order matters: a secret value is tested before it is compared to nil.
		if FK.IsSecret(aura) then
			return nil
		end
		if aura == nil then
			break
		end

		local name = aura.name
		if FK.IsSecret(name) then
			return nil
		end
		if type(name) == "string" then
			names[name] = true
		end
	end
	return names
end

-- A refresh asks for coverage several times over — the header plans, then the
-- tab plans, then the tab asks again for its own reasons — and each ask used to
-- re-read up to forty auras per group member. In a forty-man that is thousands
-- of pcalled API calls every five seconds for an answer that cannot have
-- changed. One second of memory removes all of it.
local CACHE_SECONDS = 1
local cached, cachedAt = nil, -1

--- The group as Core/Buffs.lua wants it: name, class, level and auras.
function Auras:Snapshot()
	local now = GetTime and GetTime() or 0
	if cached and (now - cachedAt) < CACHE_SECONDS then
		return cached
	end
	local members = self:ReadSnapshot()
	cached, cachedAt = members, now
	return members
end

--- Forces the next Snapshot to read the client again.
function Auras:Invalidate()
	cached, cachedAt = nil, -1
end

function Auras:ReadSnapshot()
	local members, stale, seen = {}, false, {}

	-- `isSelf` is passed in rather than asked of UnitIsUnit, which is marked
	-- SecretWhenUnitComparisonRestricted: the loop already knows which unit is
	-- the player, so there is no reason to invite a secret value in.
	local function add(unit, isSelf)
		if not UnitExists(unit) then
			return
		end
		local ok, name, realm = pcall(UnitName, unit)
		if not ok then
			return
		end
		-- PlayerKey tests both returns for secrecy; a player we cannot name
		-- stays out of the list rather than being guessed at.
		local key = FK.Roster.PlayerKey(name, realm)
		if not key or seen[key] then
			return -- in a raid, raidN is also you, and once is enough
		end
		seen[key] = true

		local _, class = UnitClass(unit)
		local level = UnitLevel and UnitLevel(unit) or nil
		if FK.IsSecret(level) then
			level = nil
		end

		local auras = Auras.ReadUnit(unit)
		if auras then
			self.lastGood[key] = auras
		else
			auras = self.lastGood[key]
			if auras then
				stale = true
			end
		end

		table.insert(members, {
			name = key,
			class = class,
			level = level,
			isSelf = isSelf or false,
			auras = auras,
		})
	end

	add("player", true)
	if FK.Capabilities.Has("groupRoster") then
		local count = GetNumGroupMembers() or 0
		local inRaid = IsInRaid and IsInRaid()
		local prefix = inRaid and "raid" or "party"
		-- raid tokens run 1..N and include you; party tokens run 1..N-1 and do
		-- not. Using the party bound in a raid dropped the last member.
		for index = 1, inRaid and count or math.max(count - 1, 0) do
			add(prefix .. index)
		end
	end

	self.stale = stale
	return members
end

--- Missing class buffs for the group standing here.
function Auras:Missing()
	return FK.Buffs.Evaluate({
		members = self:Snapshot(),
		optional = FK.db and FK.db.optionalBuffs or {},
	})
end

--- Camp buff groups covered by auras we can actually see, or nil when we
-- cannot see any, in which case the planner falls back to guessing by class.
function Auras:Coverage()
	local members = self:Snapshot()
	local readable = false
	for _, member in ipairs(members) do
		if member.auras then
			readable = true
			break
		end
	end
	if not readable then
		return nil
	end
	return FK.Buffs.ObservedCoverage(members)
end

function Auras:OnLogin()
	-- One read at login tells us which of the three failure modes we are in,
	-- and `/fk caps` reports it.
	local auras = Auras.ReadUnit("player")
	FK.Debug("aura read at login: %s", auras and "ok" or "unavailable")
end
