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
			-- An object with no stated skill used to be included on the grounds
			-- that offering too much beats hiding something. Now that every
			-- object carries its requirement, the only ones left without are the
			-- upgraded campfire kits, which need a blueprint — and claiming a
			-- ten-slot fire you cannot build makes the planner promise a camp
			-- that never appears.
			local reachable = object.skill and skill >= object.skill
			if reachable or (not object.skill and object.source ~= "blueprint") then
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

--- How many of this object are in your bags, or nil if the client will not say.
--
-- Skill says what you could make. It does not say what you are carrying, and
-- the two are very different at a campfire: an empty-handed blacksmith was
-- being offered a Sharpening Wheel by the panel and advertised as able to place
-- one to the whole group.
function Professions.CountOf(object)
	if not object or not C_Item or type(C_Item.GetItemCount) ~= "function" then
		return nil
	end
	local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
	local itemId = FK.Data.ItemIdFor(object, faction)
	if not itemId then
		return nil
	end
	local ok, count = pcall(C_Item.GetItemCount, itemId)
	if not ok or type(count) ~= "number" then
		return nil
	end
	return count
end

--- The objects you could make *and* are actually carrying.
-- Returns nil when bag counts cannot be read at all, so a caller can tell the
-- difference between "you have none" and "we cannot see your bags".
function Professions:CarriedObjects()
	local placeable = self:PlaceableObjects()
	local readable = false
	local carried = {}

	for _, object in ipairs(placeable) do
		local count = Professions.CountOf(object)
		if count ~= nil then
			readable = true
			if count > 0 then
				table.insert(carried, object)
			end
		end
	end

	if not readable then
		return nil
	end
	return carried
end

--- What to tell the group you can put on the fire.
--
-- What you are carrying when the client will say, and what your skill allows
-- when it will not — telling people you can place something you do not have
-- makes the planner assign you a slot you cannot fill.
function Professions:PlaceableIds()
	local objects = self:CarriedObjects() or self:PlaceableObjects()
	local ids = {}
	for _, object in ipairs(objects) do
		table.insert(ids, object.id)
	end
	return ids
end

function Professions:OnLogin()
	self:Scan()
	FK.Debug("professions: " .. (next(self.known) and "found" or "none detected, use /fk prof"))
end
