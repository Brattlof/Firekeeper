local _, FK = ...

FK.Data = FK.Data or {}

-- Every profession has three campsite objects. The first is learned at skill 20
-- from a trainer or a camping NPC; the later ones come from Blueprint recipes
-- that drop from dungeon bosses.
--
-- This table is deliberately incomplete. Only a handful of objects were shown at
-- BlizzCon, so most entries below are `reported` (named in a public source, not
-- yet seen in game) and whole professions are missing. Nothing here is invented
-- to fill a gap: a missing object is missing on purpose, and `FK.Data.gaps`
-- lists what we know we are still short of.
--
-- confidence:
--   confirmed — observed in the game client and reported with a build number
--   reported  — named in an official panel, patch note, or guide site
--   unknown   — the object exists but its effect or skill level is not known
--
-- effect kinds:
--   buff      — a one-hour campsite buff, keyed to Data/BuffGroups.lua
--   workspace — stands in for a city profession station (anvil, lab, ...)
--   slots     — raises how many objects the campsite holds
--   utility   — something else useful (vendor, repair, ...)
--   unknown   — the object is real but we cannot say what it does yet
FK.Data.campObjects = {
	{
		id = "sharpening_wheel",
		name = "Sharpening Wheel",
		profession = "Blacksmithing",
		tier = 1,
		skill = 20,
		source = "trainer",
		effect = { kind = "buff", buff = "attack_power" },
		confidence = "reported",
	},
	{
		id = "anvil",
		name = "Anvil",
		profession = "Blacksmithing",
		tier = 2,
		skill = 140,
		source = "blueprint",
		effect = { kind = "workspace", workspace = "blacksmithing" },
		confidence = "unknown",
		note = "Skill level reported; the exact effect is not confirmed.",
	},
	{
		id = "master_forge",
		name = "Master Forge",
		profession = "Blacksmithing",
		tier = 3,
		skill = 300,
		source = "blueprint",
		effect = { kind = "workspace", workspace = "blacksmithing" },
		confidence = "unknown",
		note = "Skill level reported; the exact effect is not confirmed.",
	},
	{
		id = "faction_banner",
		name = "Faction Banner",
		profession = "Tailoring",
		tier = 1,
		source = "trainer",
		effect = { kind = "buff", buff = "spirit" },
		confidence = "reported",
	},
	{
		id = "incense_candle",
		name = "Incense Candle",
		profession = "Herbalism",
		tier = 1,
		source = "trainer",
		effect = { kind = "buff", buff = "intellect" },
		confidence = "reported",
	},
	{
		id = "alchemy_lab",
		name = "Alchemy Lab",
		profession = "Alchemy",
		tier = 1,
		source = "trainer",
		effect = { kind = "workspace", workspace = "alchemy" },
		confidence = "reported",
	},
	{
		id = "tanning_rack",
		name = "Tanning Rack",
		profession = "Leatherworking",
		tier = 1,
		source = "trainer",
		effect = { kind = "workspace", workspace = "leatherworking" },
		confidence = "reported",
		note = "Some advanced Leatherworking recipes require it.",
	},
	{
		id = "upgraded_campfire",
		name = "Upgraded Campfire",
		profession = "Cooking",
		tier = 2,
		source = "trainer",
		effect = { kind = "slots", slots = 5 },
		confidence = "reported",
	},
	{
		id = "grand_campfire",
		name = "Grand Campfire",
		profession = "Cooking",
		tier = 3,
		source = "blueprint",
		effect = { kind = "slots", slots = 10 },
		confidence = "unknown",
		note = "A 10-object campfire was shown; its name is a placeholder.",
	},
	{
		id = "camping_kit",
		name = "Camping Kit",
		profession = "First Aid",
		tier = 1,
		source = "trainer",
		effect = { kind = "unknown" },
		confidence = "unknown",
		note = "Appears in First Aid guides for Forever; effect not described anywhere yet.",
	},
}

-- The twelve professions, so the addon can say what it is missing rather than
-- quietly pretending a profession has nothing to offer.
FK.Data.professions = {
	"Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Herbalism",
	"Leatherworking", "Mining", "Skinning", "Tailoring",
	"Cooking", "First Aid", "Fishing",
}

FK.Data.professionSet = {}
for _, profession in ipairs(FK.Data.professions) do
	FK.Data.professionSet[profession] = true
end

local byId, byProfession = {}, {}
for _, object in ipairs(FK.Data.campObjects) do
	byId[object.id] = object
	byProfession[object.profession] = byProfession[object.profession] or {}
	table.insert(byProfession[object.profession], object)
end

FK.Data.campObjectsById = byId
FK.Data.campObjectsByProfession = byProfession

function FK.Data.GetObject(id)
	return byId[id]
end

--- Professions with fewer than the expected three objects recorded.
-- Drives `/fk gaps`, which turns the addon into a to-do list during the beta.
function FK.Data.Gaps()
	local gaps = {}
	for _, profession in ipairs(FK.Data.professions) do
		local known = byProfession[profession] or {}
		if #known < 3 then
			table.insert(gaps, { profession = profession, known = #known, missing = 3 - #known })
		end
	end
	return gaps
end
