local _, t, root = ...

-- What you are carrying, as opposed to what your skill would let you make.
-- The two are very different standing at a campfire with empty bags.
local Mock = dofile(root .. "/tests/wowmock.lua")
local tests = {}

local function build(world)
	Mock.install(world or {})
	local FK = Mock.newFK()

	for _, file in ipairs({
		"Data/BuffGroups.lua", "Data/CampObjects.lua", "Data/ClassBuffs.lua",
		"Core/Wire.lua", "Core/Plan.lua", "Core/Cooldowns.lua",
	}) do
		Mock.load(FK, root, file)
	end

	FK.charDb = { professions = {} }
	Mock.load(FK, root, "Core/Professions.lua")
	FK.Professions.known = { Blacksmithing = 300 }
	return FK
end

local function ids(objects)
	local out = {}
	for _, object in ipairs(objects or {}) do
		table.insert(out, object.id)
	end
	table.sort(out)
	return table.concat(out, ",")
end

function tests.skill_alone_offers_the_whole_chain()
	local FK = build()
	t.equals(ids(FK.Professions:PlaceableObjects()),
		"anvil,master_forge,sharpening_wheel", "a maxed smith could make all three")
end

function tests.an_empty_bag_carries_nothing()
	local FK = build({ bags = {} })
	t.equals(ids(FK.Professions:CarriedObjects()), "", "nothing in the bags, nothing offered")
	t.equals(#FK.Professions:PlaceableIds(), 0, "and the group is told nothing")
end

function tests.only_what_is_in_the_bags_is_offered()
	local FK = build({ bags = { [279988] = 2 } }) -- two Anvils
	t.equals(ids(FK.Professions:CarriedObjects()), "anvil", "the anvil only")
	t.equals(table.concat(FK.Professions:PlaceableIds(), ","), "anvil",
		"and that is what goes on the wire")
	t.equals(FK.Professions.CountOf(FK.Data.GetObject("anvil")), 2, "two of them")
	t.equals(FK.Professions.CountOf(FK.Data.GetObject("master_forge")), 0, "none of the forge")
end

function tests.a_client_that_will_not_say_falls_back_to_skill()
	-- Better to offer too much than to tell the group you can place nothing
	-- because the bags could not be read.
	local FK = build({ noBagCounts = true })
	t.equals(FK.Professions:CarriedObjects(), nil, "unreadable is not the same as empty")
	t.equals(#FK.Professions:PlaceableIds(), 3, "so skill decides instead")
	t.equals(FK.Professions.CountOf(FK.Data.GetObject("anvil")), nil, "and no count is invented")
end

function tests.the_horde_banner_is_counted_as_the_horde_item()
	local FK = build({ faction = "Horde", bags = { [279972] = 1 } })
	FK.Professions.known = { Tailoring = 300 }
	t.equals(FK.Professions.CountOf(FK.Data.GetObject("faction_banner")), 1,
		"a Horde player's own banner counts")

	local alliance = build({ faction = "Alliance", bags = { [279972] = 1 } })
	alliance.Professions.known = { Tailoring = 300 }
	t.equals(alliance.Professions.CountOf(alliance.Data.GetObject("faction_banner")), 0,
		"and the other faction's does not")
end

return tests
