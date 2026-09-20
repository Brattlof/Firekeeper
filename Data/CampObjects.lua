local _, FK = ...

FK.Data = FK.Data or {}

-- Every profession has three campsite objects. The first is learned at skill 20
-- from a trainer or a camping NPC; the later ones come from Blueprint recipes
-- that drop from dungeon bosses.
--
-- All thirty-six names, professions and tiers below come from a public guide
-- (see docs/DATA.md). What those objects actually *do* is mostly still unknown:
-- only the effects marked below appear in a source we can cite. Nothing here is
-- invented to fill a gap, so most entries carry `effect = { kind = "unknown" }`
-- and `/fk gaps` lists them as work still to do.
--
-- confidence — how well the entry itself (name, profession, tier) is attested:
--   confirmed — observed in the game client and reported with a build number
--   reported  — named in an official panel, patch note, or guide site
--   unknown   — the object exists but we cannot place it yet
--
-- effect kinds — what the object does, tracked separately from `confidence`,
-- because a name can be well sourced while its buff is not:
--   buff      — a one-hour campsite buff, keyed to Data/BuffGroups.lua
--   workspace — stands in for a city profession station (anvil, lab, ...)
--   slots     — raises how many objects the campsite holds
--   utility   — something else useful (vendor, repair, ...)
--   unknown   — the object is real but we cannot say what it does yet
FK.Data.campObjects = {
	-- Alchemy
	{
		id = "mana_well",
		name = "Mana Well",
		profession = "Alchemy",
		tier = 1,
		skill = 20,
		source = "trainer",
		effect = { kind = "unknown" },
		confidence = "reported",
	},
	{
		id = "fermenter",
		name = "Fermenter",
		profession = "Alchemy",
		tier = 2,
		source = "blueprint",
		effect = { kind = "unknown" },
		confidence = "reported",
	},
	{
		id = "alchemy_laboratory",
		name = "Alchemy Laboratory",
		profession = "Alchemy",
		tier = 3,
		source = "blueprint",
		effect = { kind = "workspace", workspace = "alchemy" },
		confidence = "reported",
		note = "Earlier guides called this the Alchemy Lab and placed it at tier 1.",
	},

	-- Blacksmithing
	{
		id = "sharpening_wheel",
		name = "Sharpening Wheel",
		profession = "Blacksmithing",
		tier = 1,
		skill = 20,
		source = "trainer",
		effect = { kind = "buff", buff = "attack_power" },
		confidence = "reported",
		note = "Sources disagree: one calls this Attack Power, another Strength. Needs a tooltip.",
	},
	{
		id = "anvil",
		name = "Anvil",
		profession = "Blacksmithing",
		tier = 2,
		skill = 140,
		source = "blueprint",
		effect = { kind = "workspace", workspace = "blacksmithing" },
		confidence = "reported",
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
		confidence = "reported",
		note = "Skill level reported; the exact effect is not confirmed.",
	},

	-- Enchanting
	{
		id = "enchanted_lute",
		name = "Enchanted Lute",
		profession = "Enchanting",
		tier = 1,
		skill = 20,
		source = "trainer",
		effect = { kind = "unknown" },
		confidence = "reported",
	},
	{
		id = "arcane_salvager",
		name = "Arcane Salvager",
		profession = "Enchanting",
		tier = 2,
		source = "blueprint",
		effect = { kind = "unknown" },
		confidence = "reported",
	},
	{
		id = "arcane_forge",
		name = "Arcane Forge",
		profession = "Enchanting",
		tier = 3,
		source = "blueprint",
		effect = { kind = "unknown" },
		confidence = "reported",
	},

	-- Engineering
	{
		id = "reagent_bot",
		name = "Reagent Bot",
		profession = "Engineering",
		tier = 1,
		skill = 20,
		source = "trainer",
		effect = { kind = "unknown" },
		confidence = "reported",
	},
	{
		id = "repair_bot",
		name = "Repair Bot",
		profession = "Engineering",
		tier = 2,
		source = "blueprint",
		effect = { kind = "unknown" },
		confidence = "reported",
	},
	{
		id = "anarchists_workbench",
		name = "Anarchist's Workbench",
		profession = "Engineering",
		tier = 3,
		source = "blueprint",
		effect = { kind = "unknown" },
		confidence = "reported",
	},

	-- Herbalism
	{
		id = "incense_candle",
		name = "Incense Candle",
		profession = "Herbalism",
		tier = 1,
		skill = 20,
		source = "trainer",
		effect = { kind = "buff", buff = "intellect" },
		confidence = "reported",
	},
	{
		id = "greenhouse",
		name = "Greenhouse",
		profession = "Herbalism",
		tier = 2,
		source = "blueprint",
		effect = { kind = "unknown" },
		confidence = "reported",
	},
	{
		id = "seed_hybridizer",
		name = "Seed Hybridizer",
		profession = "Herbalism",
		tier = 3,
		source = "blueprint",
		effect = { kind = "unknown" },
		confidence = "reported",
	},

	-- Leatherworking
	{
		id = "camp_tent",
		name = "Camp Tent",
		profession = "Leatherworking",
		tier = 1,
		skill = 20,
		source = "trainer",
		effect = { kind = "unknown" },
		confidence = "reported",
	},
	{
		id = "tanning_rack",
		name = "Tanning Rack",
		profession = "Leatherworking",
		tier = 2,
		source = "blueprint",
		effect = { kind = "workspace", workspace = "leatherworking" },
		confidence = "reported",
		note = "Some advanced Leatherworking recipes require it.",
	},
	{
		id = "sewing_machine",
		name = "Sewing Machine",
		profession = "Leatherworking",
		tier = 3,
		source = "blueprint",
		effect = { kind = "unknown" },
		confidence = "reported",
	},

	-- Mining
	{
		id = "lodestone",
		name = "Lodestone",
		profession = "Mining",
		tier = 1,
		skill = 20,
		source = "trainer",
		effect = { kind = "unknown" },
		confidence = "reported",
	},
	{
		id = "rock_garden",
		name = "Rock Garden",
		profession = "Mining",
		tier = 2,
		source = "blueprint",
		effect = { kind = "unknown" },
		confidence = "reported",
	},
	{
		id = "molten_foundry",
		name = "Molten Foundry",
		profession = "Mining",
		tier = 3,
		source = "blueprint",
		effect = { kind = "unknown" },
		confidence = "reported",
	},

	-- Skinning
	{
		id = "camp_chair",
		name = "Camp Chair",
		profession = "Skinning",
		tier = 1,
		skill = 20,
		source = "trainer",
		effect = { kind = "unknown" },
		confidence = "reported",
	},
	{
		id = "field_guide",
		name = "Field Guide",
		profession = "Skinning",
		tier = 2,
		source = "blueprint",
		effect = { kind = "unknown" },
		confidence = "reported",
		note = "Shares a name with the Legacy perk that shortens the camp cooldown; unrelated.",
	},
	{
		id = "trappers_workbench",
		name = "Trapper's Workbench",
		profession = "Skinning",
		tier = 3,
		source = "blueprint",
		effect = { kind = "unknown" },
		confidence = "reported",
	},

	-- Tailoring
	{
		id = "faction_banner",
		name = "Faction Banner",
		profession = "Tailoring",
		tier = 1,
		skill = 20,
		source = "trainer",
		effect = { kind = "buff", buff = "spirit" },
		confidence = "reported",
	},
	{
		id = "spinning_wheel",
		name = "Spinning Wheel",
		profession = "Tailoring",
		tier = 2,
		source = "blueprint",
		effect = { kind = "unknown" },
		confidence = "reported",
	},
	{
		id = "loom",
		name = "Loom",
		profession = "Tailoring",
		tier = 3,
		source = "blueprint",
		effect = { kind = "unknown" },
		confidence = "reported",
	},

	-- Cooking: the campfire itself, which is why these buy slots rather than buffs.
	{
		id = "basic_campfire_kit",
		name = "Basic Campfire Kit",
		profession = "Cooking",
		tier = 1,
		skill = 20,
		source = "trainer",
		effect = { kind = "slots", slots = 3 },
		confidence = "reported",
	},
	{
		id = "journeyman_campfire_kit",
		name = "Journeyman Campfire Kit",
		profession = "Cooking",
		tier = 2,
		source = "blueprint",
		effect = { kind = "slots", slots = 5 },
		confidence = "reported",
	},
	{
		id = "expert_campfire_kit",
		name = "Expert Campfire Kit",
		profession = "Cooking",
		tier = 3,
		source = "blueprint",
		effect = { kind = "slots", slots = 10 },
		confidence = "reported",
	},

	-- First Aid
	{
		id = "first_aid_kit",
		name = "First Aid Kit",
		profession = "First Aid",
		tier = 1,
		skill = 20,
		source = "trainer",
		effect = { kind = "unknown" },
		confidence = "reported",
		note = "Earlier guides called this the Camping Kit.",
	},
	{
		id = "toxin_study",
		name = "Toxin Study",
		profession = "First Aid",
		tier = 2,
		source = "blueprint",
		effect = { kind = "unknown" },
		confidence = "reported",
	},
	{
		id = "plague_doctors_laboratory",
		name = "Plague Doctor's Laboratory",
		profession = "First Aid",
		tier = 3,
		source = "blueprint",
		effect = { kind = "unknown" },
		confidence = "reported",
	},

	-- Fishing
	{
		id = "fish_bowl",
		name = "Fish Bowl",
		profession = "Fishing",
		tier = 1,
		skill = 20,
		source = "trainer",
		effect = { kind = "unknown" },
		confidence = "reported",
	},
	{
		id = "fishing_rack",
		name = "Fishing Rack",
		profession = "Fishing",
		tier = 2,
		source = "blueprint",
		effect = { kind = "unknown" },
		confidence = "reported",
	},
	{
		id = "fishing_hut",
		name = "Fishing Hut",
		profession = "Fishing",
		tier = 3,
		source = "blueprint",
		effect = { kind = "unknown" },
		confidence = "reported",
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

-- The Cooking campfires, smallest first. `/fk new expert` and the slot guard
-- both read this rather than hard-coding three, five and ten, so a campfire
-- nobody has found yet only has to be added to the table above.
local campfires = {}
for _, object in ipairs(FK.Data.campObjects) do
	if object.effect and object.effect.kind == "slots" then
		table.insert(campfires, object)
	end
end
table.sort(campfires, function(a, b)
	return (a.effect.slots or 0) < (b.effect.slots or 0)
end)

FK.Data.campfires = campfires

--- The capacity of the largest campfire we know about.
function FK.Data.MaxCampfireSlots()
	local max = 0
	for _, campfire in ipairs(campfires) do
		max = math.max(max, campfire.effect.slots or 0)
	end
	return max > 0 and max or 3
end

--- Slots for a campfire named in a slash command: "expert", "Journeyman", ...
function FK.Data.SlotsForCampfireName(text)
	local needle = tostring(text or ""):lower():gsub("%s+", "_")
	if needle == "" then
		return nil
	end
	for _, campfire in ipairs(campfires) do
		if campfire.id:find(needle, 1, true) or campfire.name:lower():find(needle, 1, true) then
			return campfire.effect.slots, campfire.name
		end
	end
	return nil
end

--- "Basic Campfire Kit (3)", for telling the player what they can type.
function FK.Data.CampfireNames()
	local names = {}
	for _, campfire in ipairs(campfires) do
		table.insert(names, ("%s (%d)"):format(campfire.name, campfire.effect.slots or 0))
	end
	return names
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

--- Objects we can name but whose effect nobody has reported yet.
-- The names came from a guide; the tooltips have to come from players.
function FK.Data.UnknownEffects()
	local unknown = {}
	for _, object in ipairs(FK.Data.campObjects) do
		if not object.effect or object.effect.kind == "unknown" then
			table.insert(unknown, object)
		end
	end
	return unknown
end
