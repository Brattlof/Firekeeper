local _, FK = ...

-- Which class buffs the group is missing, and who could fix it.
--
-- Pure Lua on purpose, like Core/Plan.lua: it is handed a list of members and
-- what each is carrying, so it runs under plain lua5.1 in tests/. Reading the
-- auras off real players is Core/Auras.lua's job, because that part can fail.
local Buffs = {}
FK.Buffs = Buffs

local function memberHas(member, buff)
	if not member.auras then
		return nil -- we could not read this one, which is not the same as "no"
	end
	for _, aura in ipairs(buff.auras) do
		if member.auras[aura] then
			return true
		end
	end
	return false
end

local function wants(member, buff)
	if buff.who == "mana" then
		return FK.Data.manaClasses[member.class] == true
	end
	return true
end

--- Who is missing what.
--
-- state = {
--   members = {
--     { name = "Ana", class = "MAGE", level = 60, isSelf = true,
--       auras = { ["Arcane Intellect"] = true } },  -- nil auras = could not read
--   },
--   optional = { shadowprot = true },  -- buffs that are off unless asked for
-- }
function Buffs.Evaluate(state)
	state = state or {}
	local members = state.members or {}
	local optional = state.optional or {}

	local missing, unreadable = {}, 0
	for _, member in ipairs(members) do
		if not member.auras then
			unreadable = unreadable + 1
		end
	end

	for _, buff in ipairs(FK.Data.classBuffs) do
		if buff.optional and not optional[buff.key] then
			-- Off unless the player turned it on.
		else
			local providers, needing, carried = {}, {}, false

			for _, member in ipairs(members) do
				if member.class == buff.class and (member.level or 60) >= (buff.minLevel or 1) then
					table.insert(providers, member.name)
				end
				if memberHas(member, buff) then
					carried = true
				end
			end

			for _, member in ipairs(members) do
				local scopeWants = buff.scope ~= "self" or member.class == buff.class
				if scopeWants and wants(member, buff) and memberHas(member, buff) == false then
					table.insert(needing, member.name)
				end
			end

			-- A talent buff is only worth asking for once somebody is visibly
			-- carrying it: that is the only proof anyone in the group took it.
			local askable = not buff.talent or carried

			if #needing > 0 and askable and (#providers > 0 or buff.scope == "self") then
				table.sort(needing)
				table.sort(providers)
				table.insert(missing, {
					key = buff.key,
					label = buff.label,
					class = buff.class,
					scope = buff.scope,
					needing = needing,
					providers = providers,
				})
			end
		end
	end

	table.sort(missing, function(a, b)
		if #a.needing ~= #b.needing then return #a.needing > #b.needing end
		return a.key < b.key
	end)

	return { missing = missing, unreadable = unreadable, members = #members }
end

--- Camp buff groups the group already carries, seen in their actual auras.
--
-- The planner's job is to skip a camp object whose buff is already covered. A
-- mage standing there is only a guess that Arcane Intellect is up; an observed
-- aura is the real thing, so this wins over FK.Data.CoverageForClasses when
-- the auras could be read at all.
function Buffs.ObservedCoverage(members)
	local covered = {}
	for _, member in ipairs(members or {}) do
		for aura in pairs(member.auras or {}) do
			local buff = FK.Data.ClassBuffForAura(aura)
			if buff and buff.buffGroup then
				covered[buff.buffGroup] = covered[buff.buffGroup] or aura
			end
		end
	end
	return covered
end

--- "Ana, Bo need Arcane Intellect — Cy can cast it"
function Buffs.MissingText(entry)
	local who = table.concat(entry.needing, ", ")
	if entry.scope == "self" then
		return ("%s: %s"):format(who, entry.label)
	end
	if #entry.providers == 0 then
		return ("%s need %s, and nobody here can cast it"):format(who, entry.label)
	end
	return ("%s need %s — %s can cast it"):format(who, entry.label, table.concat(entry.providers, ", "))
end

return Buffs
