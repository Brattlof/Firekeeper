local _, FK = ...

-- What the local player can put on a fire: their professions, their skill, and
-- from that the camp objects they should know.
--
-- Whether Forever keeps the retail profession API is open (docs/RESEARCH.md,
-- FK-1), so there are three ways in, ending with the player simply telling us.
local Professions = FK.RegisterModule("Professions", {})
FK.Professions = Professions

Professions.known = {} -- profession name -> skill level

local function fromRetailApi()
	if not (FK.Capabilities.Has("professionsApi") and type(GetProfessions) == "function") then
		return nil
	end
	local found = {}
	local indexes = { GetProfessions() }
	for _, index in ipairs(indexes) do
		local name, _, rank = GetProfessionInfo(index)
		if name then
			found[name] = rank or 0
		end
	end
	return next(found) and found or nil
end

local function fromSpellBook()
	if not FK.Capabilities.Has("spellBookScan") then
		return nil
	end
	local found = {}
	for index = 1, 12 do
		local info = C_SpellBook.GetSpellBookSkillLineInfo(index)
		-- Skill lines include class spell tabs, so only the twelve professions count.
		if info and info.name and FK.Data.professionSet[info.name] then
			found[info.name] = info.skillLineRank or 0
		end
	end
	return next(found) and found or nil
end

local function fromSavedInput()
	local stored = FK.charDb and FK.charDb.professions
	return stored and next(stored) and stored or nil
end

function Professions:Scan()
	self.known = fromRetailApi() or fromSpellBook() or fromSavedInput() or {}
	return self.known
end

--- Manual fallback: `/fk prof Blacksmithing 145`
function Professions:Set(name, skill)
	FK.charDb.professions = FK.charDb.professions or {}
	FK.charDb.professions[name] = tonumber(skill) or 0
	self.known[name] = FK.charDb.professions[name]
end

--- Camp objects this character should be able to place, newest tier first.
-- Objects whose skill requirement is unknown are included: better to offer one
-- the player has not learned than to hide one they have.
function Professions:PlaceableObjects()
	local placeable = {}
	for profession, skill in pairs(self.known) do
		for _, object in ipairs(FK.Data.campObjectsByProfession[profession] or {}) do
			if not object.skill or skill >= object.skill then
				table.insert(placeable, object)
			end
		end
	end
	table.sort(placeable, function(a, b)
		if (a.tier or 1) ~= (b.tier or 1) then return (a.tier or 1) > (b.tier or 1) end
		return a.name < b.name
	end)
	return placeable
end

function Professions:PlaceableIds()
	local ids = {}
	for _, object in ipairs(self:PlaceableObjects()) do
		table.insert(ids, object.id)
	end
	return ids
end

function Professions:OnLogin()
	self:Scan()
	FK.Debug("professions: " .. (next(self.known) and "found" or "none detected, use /fk prof"))
end
