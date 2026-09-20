local _, t, root = ...

-- Noticing a placement from a finished cast, against tests/wowmock.lua.
local Mock = dofile(root .. "/tests/wowmock.lua")
local tests = {}

local function build()
	Mock.install({ count = 0 })
	local FK = Mock.newFK()

	for _, file in ipairs({
		"Data/BuffGroups.lua", "Data/CampObjects.lua", "Data/ClassBuffs.lua",
		"Core/Wire.lua", "Core/Plan.lua", "Core/Cooldowns.lua",
	}) do
		Mock.load(FK, root, file)
	end

	FK.Roster = { SelfKey = function() return "Ana" end, ScanGroup = function() end,
		Coverage = function() return {} end, Contributors = function() return {} end }
	FK.Comm = { AnnounceCamp = function() end, Announce = function() end }
	FK.UI = { Refresh = function() end }

	Mock.load(FK, root, "Core/Camp.lua")
	Mock.load(FK, root, "Core/Placement.lua")
	FK.Camp:Reset(3)
	return FK
end

--- The spell a given object is placed with.
local function spellFor(FK, id)
	return FK.Data.GetObject(id).spellId
end

function tests.every_object_knows_the_spell_that_places_it()
	local FK = build()
	for _, object in ipairs(FK.Data.campObjects) do
		t.isTrue(type(object.spellId) == "number", object.name .. " has a placement spell")
		t.equals(FK.Data.ObjectForSpell(object.spellId).id, object.id,
			object.name .. " is found by its spell")
	end
end

function tests.a_finished_cast_records_the_object()
	local FK = build()
	local object, what = FK.Placement.OnCastSucceeded(spellFor(FK, "incense_candle"), 1000)
	t.equals(object.id, "incense_candle", "the candle was recognised")
	t.equals(what, "placed", "and recorded")
	t.count(FK.Camp.placed, 1, "the fire has it")
	t.equals(FK.Camp.placed[1].player, "Ana", "credited to you")
end

function tests.a_cast_that_is_not_a_camp_object_is_ignored()
	local FK = build()
	t.equals(FK.Placement.OnCastSucceeded(12345, 1000), nil, "some other spell")
	t.equals(FK.Placement.OnCastSucceeded(nil, 1000), nil, "or none at all")
	t.count(FK.Camp.placed, 0, "nothing was recorded")
end

function tests.a_campfire_starts_a_fresh_camp_at_its_own_size()
	local FK = build()
	FK.Placement.OnCastSucceeded(spellFor(FK, "incense_candle"), 1000)
	t.count(FK.Camp.placed, 1, "something is on the old fire")

	local object, what = FK.Placement.OnCastSucceeded(spellFor(FK, "expert_campfire_kit"), 1001)
	t.equals(what, "campfire", "a kit is a new fire, not a thing on one")
	t.equals(object.name, "Expert Campfire Kit", "named")
	t.equals(FK.Camp.slots, 10, "with its capacity")
	t.count(FK.Camp.placed, 0, "and nothing carried over from the last fire")
end

function tests.placing_after_an_hour_is_taken_as_a_different_fire()
	-- Camp buffs last an hour, so a placement an hour later is somewhere else.
	local FK = build()
	FK.Placement.OnCastSucceeded(spellFor(FK, "incense_candle"), 1000)
	t.equals(FK.Camp.lastPlacedAt, 1000, "the placement was stamped with the caller's clock")

	FK.Placement.OnCastSucceeded(spellFor(FK, "lodestone"), 1000 + FK.Placement.CAMP_LIFETIME + 1)
	t.count(FK.Camp.placed, 1, "the old fire's objects are gone")
	t.equals(FK.Camp.placed[1].objectId, "lodestone", "and only the new one is recorded")
end

function tests.a_long_session_does_not_make_the_fire_look_stale()
	-- The rule used to measure from the last camp reset, which only moves at
	-- login — so playing for an hour made the next placement wipe a fire you
	-- were standing at.
	local FK = build()
	FK.Camp.startedAt = 0
	FK.Camp.lastPlacedAt = nil
	FK.Placement.OnCastSucceeded(spellFor(FK, "incense_candle"), 99999)
	t.count(FK.Camp.placed, 1, "a first placement long after login is not a new fire")
end

function tests.placing_again_at_the_same_fire_does_not_reset_it()
	local FK = build()
	FK.Placement.OnCastSucceeded(spellFor(FK, "incense_candle"), 1010)
	local _, what = FK.Placement.OnCastSucceeded(spellFor(FK, "lodestone"), 1020)

	-- One object per player, so the second is refused rather than recorded —
	-- but the fire itself must not have been wiped.
	t.equals(what, "refused", "you only get one object per fire")
	t.count(FK.Camp.placed, 1, "and the first is still there")
end

function tests.a_secret_spell_id_is_asked_about_before_it_is_used()
	-- Lua cannot be made to object to a table used as a key, so a sentinel that
	-- throws proves nothing here: without the guard the lookup simply misses and
	-- returns nil. What can be checked is that the code *asks* — so this fails
	-- if the FK.IsSecret call is ever removed, which is the thing that would
	-- break the addon on a restricted client.
	local FK = build()
	local state = Mock.install({ count = 0 })

	local asked = false
	local realIsSecret = FK.IsSecret
	FK.IsSecret = function(value)
		if value == state.secret then
			asked = true
		end
		return realIsSecret(value)
	end

	local ok, err = pcall(function()
		return FK.Placement.OnCastSucceeded(state.secret, 1000)
	end)
	FK.IsSecret = realIsSecret

	t.isTrue(ok, "a secret spell id did not throw: " .. tostring(err))
	t.isTrue(asked, "the spell id was tested for secrecy before being used")
	t.count(FK.Camp.placed, 0, "and nothing was recorded from it")
end

function tests.a_campfire_tells_the_group_about_the_new_fire()
	-- Without this the group keeps the old fire's objects and hands them back
	-- the next time anyone announces.
	local FK = build()
	local announced = false
	FK.Comm.AnnounceCamp = function() announced = true end

	FK.Placement.OnCastSucceeded(spellFor(FK, "journeyman_campfire_kit"), 1000)
	t.isTrue(announced, "the new fire was announced")
end

function tests.a_horde_banner_is_recognised_too()
	local FK = build()
	local horde = FK.Data.GetObject("faction_banner").byFaction.Horde
	t.equals(FK.Data.ObjectForSpell(horde.spellId).id, "faction_banner",
		"the Horde banner's own spell is a Faction Banner")
	t.equals(FK.Data.ItemIdFor(FK.Data.GetObject("faction_banner"), "Horde"), horde.itemId,
		"and a Horde player is pointed at their own item")
	t.equals(FK.Data.ItemIdFor(FK.Data.GetObject("lodestone"), "Horde"), 279960,
		"anything without variants is the same for everyone")
end

return tests
