local _, FK = ...

FK.Data = FK.Data or {}

-- What each profession can put on a fire.
--
-- Every entry below, including the exact buff amounts, comes from the client's
-- own item tooltip, read through Wowhead's Forever database:
--
--   https://nether.wowhead.com/forever/tooltip/item/<itemId>
--
-- Each `itemId` was checked by fetching it and confirming the name came back as
-- expected, so the ids are verified rather than assumed. See docs/DATA.md for
-- the method and its limits.
--
-- `amounts` is a buff's value at each level band the tooltip lists, lowest
-- first: camp buffs scale with level, so a single number would be wrong.
-- `percent` is used instead where the tooltip gives a flat percentage.
--
-- confidence:
--   confirmed — observed in the game client and reported with a build number
--   reported  — from the client's tooltip data, an official panel, or a guide
--   unknown   — the object exists, but we cannot say what it does
--
-- effect kinds:
--   buff      — a one-hour campsite buff, keyed to Data/BuffGroups.lua
--   workspace — stands in for a city profession station (anvil, lab, ...)
--   slots     — a campfire, which is the fire itself rather than a thing on it
--   utility   — something else useful (vendor, repair, rested experience, ...)
--   unknown   — the object is real but we cannot say what it does yet
--
-- `spellId` is the spell the item casts to put the object down. The client
-- announces a finished cast, so this is how the addon notices what you placed
-- rather than waiting to be told.
--
-- `supersedes` names a lower-tier object whose benefits this one also provides,
-- from the tooltip phrase "provides all of the benefits of". The planner uses
-- it to avoid suggesting both: an Anvil already carries the Sharpening Wheel's
-- buff, so placing both wastes a slot.
FK.Data.campObjects = {
	-- Alchemy
	{
		id = "mana_well", name = "Mana Well", itemId = 279956, spellId = 1307259,
		profession = "Alchemy", tier = 1, skill = 20, source = "trainer",
		effect = { kind = "buff", buff = "mana_regen", amounts = { 10, 15, 20, 24, 29 } },
		note = "Mana per 5 seconds.",
		confidence = "reported",
	},
	{
		id = "fermenter", name = "Fermenter", itemId = 279970, spellId = 1307242,
		profession = "Alchemy", tier = 2, skill = 140, source = "blueprint",
		effect = { kind = "workspace", workspace = "alchemy" },
		supersedes = "mana_well",
		note = "Allows the creation of certain reagents.",
		confidence = "reported",
	},
	{
		id = "alchemy_laboratory", name = "Alchemy Laboratory", itemId = 279990, spellId = 1307172,
		profession = "Alchemy", tier = 3, skill = 300, source = "blueprint",
		effect = { kind = "workspace", workspace = "alchemy" },
		supersedes = "mana_well",
		confidence = "reported",
	},

	-- Blacksmithing
	{
		id = "sharpening_wheel", name = "Sharpening Wheel", itemId = 279944, spellId = 1307392,
		profession = "Blacksmithing", tier = 1, skill = 20, source = "trainer",
		effect = { kind = "buff", buff = "strength", amounts = { 6, 11, 20, 34 } },
		note = "Strength, not Attack Power. Blizzard's deep dive recap said Attack Power "
			.. "and the guide sites repeated it, but the item's own tooltip says Strength, "
			.. "exclusive with Strength of Earth Totem.",
		confidence = "reported",
	},
	{
		id = "anvil", name = "Anvil", itemId = 279988, spellId = 1307175,
		profession = "Blacksmithing", tier = 2, skill = 140, source = "blueprint",
		effect = { kind = "workspace", workspace = "blacksmithing" },
		supersedes = "sharpening_wheel",
		confidence = "reported",
	},
	{
		id = "master_forge", name = "Master Forge", itemId = 279955, spellId = 1307261,
		profession = "Blacksmithing", tier = 3, skill = 300, source = "blueprint",
		effect = { kind = "workspace", workspace = "blacksmithing" },
		supersedes = "sharpening_wheel",
		confidence = "reported",
	},

	-- Enchanting
	{
		id = "enchanted_lute", name = "Enchanted Lute", itemId = 279976, spellId = 1307234,
		profession = "Enchanting", tier = 1, skill = 20, source = "trainer",
		effect = { kind = "buff", buff = "armor", amounts = { 28, 71, 114, 163, 211, 260, 308 } },
		note = "The tooltip interleaves three scaling tracks: Armor, all stats and all "
			.. "resistances. Only the Armor numbers are recorded, because the other two "
			.. "cannot be read off unambiguously.",
		confidence = "reported",
	},
	{
		id = "arcane_salvager", name = "Arcane Salvager", itemId = 279985, spellId = 1307223,
		profession = "Enchanting", tier = 2, skill = 140, source = "blueprint",
		effect = { kind = "utility", utility = "disenchanting" },
		supersedes = "enchanted_lute",
		confidence = "reported",
	},
	{
		id = "arcane_forge", name = "Arcane Forge", itemId = 279987, spellId = 1307176,
		profession = "Enchanting", tier = 3, skill = 300, source = "blueprint",
		effect = { kind = "workspace", workspace = "enchanting" },
		supersedes = "enchanted_lute",
		confidence = "reported",
	},

	-- Engineering: the one chain whose tooltips do not promise the lower tier's
	-- benefits, so nothing supersedes anything here.
	{
		id = "reagent_bot", name = "Reagent Bot", itemId = 279950, spellId = 1307266,
		profession = "Engineering", tier = 1, skill = 20, source = "trainer",
		effect = { kind = "utility", utility = "reagent_vendor" },
		confidence = "reported",
	},
	{
		id = "repair_bot", name = "Repair Bot", itemId = 279949, spellId = 1307385,
		profession = "Engineering", tier = 2, skill = 140, source = "blueprint",
		effect = { kind = "utility", utility = "repair" },
		note = "Sells reagents and repairs gear, so it covers the Reagent Bot in practice, "
			.. "but its tooltip does not say so.",
		confidence = "reported",
	},
	{
		id = "anarchists_workbench", name = "Anarchist's Workbench", itemId = 279989, spellId = 1307174,
		profession = "Engineering", tier = 3, skill = 300, source = "blueprint",
		effect = { kind = "workspace", workspace = "engineering" },
		confidence = "reported",
	},

	-- Herbalism
	{
		id = "incense_candle", name = "Incense Candle", itemId = 279962, spellId = 1307251,
		profession = "Herbalism", tier = 1, skill = 20, source = "trainer",
		effect = { kind = "buff", buff = "intellect", amounts = { 2, 6, 12, 18, 25 } },
		confidence = "reported",
	},
	{
		id = "greenhouse", name = "Greenhouse", itemId = 279964, spellId = 1307248,
		profession = "Herbalism", tier = 2, skill = 140, source = "blueprint",
		effect = { kind = "utility", utility = "herb_growing" },
		supersedes = "incense_candle",
		confidence = "reported",
	},
	{
		id = "seed_hybridizer", name = "Seed Hybridizer", itemId = 279947, spellId = 1307387,
		profession = "Herbalism", tier = 3, skill = 300, source = "blueprint",
		effect = { kind = "utility", utility = "seed_hybridising" },
		supersedes = "incense_candle",
		confidence = "reported",
	},

	-- Leatherworking
	{
		id = "camp_tent", name = "Camp Tent", itemId = 279978, spellId = 1307230,
		profession = "Leatherworking", tier = 1, skill = 20, source = "trainer",
		effect = { kind = "utility", utility = "rested_experience" },
		note = "Raises Rested experience to 5% of a level, and does nothing if yours is "
			.. "already higher. No class buff competes with it.",
		confidence = "reported",
	},
	{
		id = "tanning_rack", name = "Tanning Rack", itemId = 279941, spellId = 1307395,
		profession = "Leatherworking", tier = 2, skill = 140, source = "blueprint",
		effect = { kind = "workspace", workspace = "leatherworking" },
		supersedes = "camp_tent",
		confidence = "reported",
	},
	{
		id = "sewing_machine", name = "Sewing Machine", itemId = 279945, spellId = 1307391,
		profession = "Leatherworking", tier = 3, skill = 300, source = "blueprint",
		effect = { kind = "workspace", workspace = "leatherworking" },
		supersedes = "camp_tent",
		confidence = "reported",
	},

	-- Mining
	{
		id = "lodestone", name = "Lodestone", itemId = 279960, spellId = 1307254,
		profession = "Mining", tier = 1, skill = 20, source = "trainer",
		effect = { kind = "buff", buff = "attack_power", amounts = { 12, 20, 32, 49, 67, 90 } },
		note = "Melee attack power specifically.",
		confidence = "reported",
	},
	{
		id = "rock_garden", name = "Rock Garden", itemId = 279948, spellId = 1307386,
		profession = "Mining", tier = 2, skill = 140, source = "blueprint",
		effect = { kind = "utility", utility = "mining_node" },
		supersedes = "lodestone",
		confidence = "reported",
	},
	{
		id = "molten_foundry", name = "Molten Foundry", itemId = 279952, spellId = 1307264,
		profession = "Mining", tier = 3, skill = 300, source = "blueprint",
		effect = { kind = "workspace", workspace = "mining" },
		supersedes = "lodestone",
		confidence = "reported",
	},

	-- Skinning
	{
		id = "camp_chair", name = "Camp Chair", itemId = 279979, spellId = 1307229,
		profession = "Skinning", tier = 1, skill = 20, source = "trainer",
		effect = { kind = "buff", buff = "crit", percent = 2 },
		note = "2% critical strike with all spells and attacks: a flat percentage rather "
			.. "than a level-scaled amount.",
		confidence = "reported",
	},
	{
		id = "field_guide", name = "Field Guide", itemId = 279969, spellId = 1307243,
		profession = "Skinning", tier = 2, skill = 140, source = "blueprint",
		effect = { kind = "utility", utility = "track_beasts" },
		supersedes = "camp_chair",
		note = "Shares a name with the Legacy perk that shortens the camp cooldown; unrelated.",
		confidence = "reported",
	},
	{
		id = "trappers_workbench", name = "Trapper's Workbench", itemId = 279938, spellId = 1307397,
		profession = "Skinning", tier = 3, skill = 300, source = "blueprint",
		effect = { kind = "utility", utility = "trap" },
		supersedes = "camp_chair",
		confidence = "reported",
	},

	-- Tailoring
	{
		id = "faction_banner", name = "Faction Banner", itemId = 279973, spellId = 1307239,
		-- Two separate items, one per faction, each with its own placement
		-- spell. A Horde player owns neither the Alliance item nor its spell, so
		-- both have to be looked up by faction or the button points at something
		-- they cannot use and the placement is never noticed.
		byFaction = {
			Alliance = { itemId = 279973, spellId = 1307239 },
			Horde = { itemId = 279972, spellId = 1307240 },
		},
		profession = "Tailoring", tier = 1, skill = 20, source = "trainer",
		effect = { kind = "buff", buff = "spirit", amounts = { 14, 19, 27, 32 } },
		note = "Two items, one per faction, and it only buffs your own faction.",
		confidence = "reported",
	},
	{
		id = "spinning_wheel", name = "Spinning Wheel", itemId = 279943, spellId = 1307393,
		profession = "Tailoring", tier = 2, skill = 140, source = "blueprint",
		effect = { kind = "workspace", workspace = "tailoring" },
		supersedes = "faction_banner",
		confidence = "reported",
	},
	{
		id = "loom", name = "Loom", itemId = 279959, spellId = 1307255,
		profession = "Tailoring", tier = 3, skill = 300, source = "blueprint",
		effect = { kind = "workspace", workspace = "tailoring" },
		supersedes = "faction_banner",
		confidence = "reported",
	},

	-- Cooking. The campfire kits are the fire itself: each says it allows a
	-- number of *additional* camp features, which is what settles whether an
	-- upgraded fire eats a slot (docs/RESEARCH.md, FK-2).
	{
		id = "basic_campfire_kit", name = "Basic Campfire Kit", itemId = 279981, spellId = 1307227,
		profession = "Cooking", tier = 1, skill = 1, source = "trainer",
		effect = { kind = "slots", slots = 3 },
		confidence = "reported",
	},
	{
		id = "journeyman_campfire_kit", name = "Journeyman Campfire Kit", itemId = 279961, spellId = 1307252,
		profession = "Cooking", tier = 2, source = "blueprint",
		effect = { kind = "slots", slots = 5 },
		confidence = "reported",
	},
	{
		id = "expert_campfire_kit", name = "Expert Campfire Kit", itemId = 279974, spellId = 1307237,
		profession = "Cooking", tier = 3, source = "blueprint",
		effect = { kind = "slots", slots = 10 },
		confidence = "reported",
	},
	{
		id = "cookies_feast", name = "Cookie's Feast", itemId = 279957, spellId = 1307257,
		profession = "Cooking", tier = 2, skill = 140, source = "blueprint",
		effect = { kind = "utility", utility = "feast" },
		note = "Stamina-boosting food. Needs a cooking fire nearby rather than any campfire.",
		confidence = "reported",
	},
	{
		id = "iron_oven", name = "Iron Oven", itemId = 279982, spellId = 1307226,
		profession = "Cooking", tier = 3, skill = 300, source = "blueprint",
		effect = { kind = "workspace", workspace = "cooking" },
		confidence = "reported",
	},

	-- First Aid
	{
		id = "first_aid_kit", name = "First Aid Kit", itemId = 279968, spellId = 1307244,
		profession = "First Aid", tier = 1, skill = 20, source = "trainer",
		effect = { kind = "buff", buff = "stamina", amounts = { 3, 8, 21, 34, 45, 56 } },
		confidence = "reported",
	},
	{
		id = "toxin_study", name = "Toxin Study", itemId = 279940, spellId = 1307396,
		profession = "First Aid", tier = 2, skill = 140, source = "blueprint",
		effect = { kind = "utility", utility = "potions" },
		supersedes = "first_aid_kit",
		confidence = "reported",
	},
	{
		id = "plague_doctors_laboratory", name = "Plague Doctor's Laboratory", itemId = 279951, spellId = 1307265,
		profession = "First Aid", tier = 3, skill = 300, source = "blueprint",
		effect = { kind = "utility", utility = "potions" },
		supersedes = "first_aid_kit",
		confidence = "reported",
	},

	-- Fishing
	{
		id = "fish_bowl", name = "Fish Bowl", itemId = 279967, spellId = 1307245,
		profession = "Fishing", tier = 1, skill = 20, source = "trainer",
		effect = { kind = "buff", buff = "all_stats", percent = 8 },
		note = "8% increased stats: a flat percentage rather than a level-scaled amount.",
		confidence = "reported",
	},
	{
		id = "fishing_rack", name = "Fishing Rack", itemId = 279965, spellId = 1307247,
		profession = "Fishing", tier = 2, skill = 140, source = "blueprint",
		effect = { kind = "utility", utility = "uncommon_fish" },
		supersedes = "fish_bowl",
		confidence = "reported",
	},
	{
		id = "fishing_hut", name = "Fishing Hut", itemId = 279966, spellId = 1307246,
		profession = "Fishing", tier = 3, skill = 300, source = "blueprint",
		effect = { kind = "utility", utility = "rare_fish" },
		supersedes = "fish_bowl",
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

-- Placement spell to object, for reading UNIT_SPELLCAST_SUCCEEDED.
local bySpell = {}
for _, object in ipairs(FK.Data.campObjects) do
	if object.spellId then
		bySpell[object.spellId] = object
	end
end

FK.Data.campObjectsBySpell = bySpell

-- Faction variants go in the same index, so a Horde banner placement is
-- recognised as a Faction Banner too.
for _, object in ipairs(FK.Data.campObjects) do
	for _, variant in pairs(object.byFaction or {}) do
		if variant.spellId then
			bySpell[variant.spellId] = object
		end
	end
end

--- The camp object a finished cast just placed, or nil.
function FK.Data.ObjectForSpell(spellId)
	return bySpell[tonumber(spellId) or spellId]
end

--- The item this player would actually place, which differs by faction for the
-- Faction Banner. `faction` is UnitFactionGroup's "Alliance" or "Horde".
function FK.Data.ItemIdFor(object, faction)
	if object and object.byFaction and faction and object.byFaction[faction] then
		return object.byFaction[faction].itemId
	end
	return object and object.itemId or nil
end

function FK.Data.GetObject(id)
	return byId[id]
end

-- The Cooking campfires, smallest first. `/fk new expert` and the slot guard
-- both read this rather than hard-coding three, five and ten.
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
function FK.Data.UnknownEffects()
	local unknown = {}
	for _, object in ipairs(FK.Data.campObjects) do
		if not object.effect or object.effect.kind == "unknown" then
			table.insert(unknown, object)
		end
	end
	return unknown
end

--- The buff an object ends up providing, following `supersedes` to the object
-- whose benefits it carries. An Anvil gives the Sharpening Wheel's Strength.
function FK.Data.EffectiveBuff(object)
	local seen = {}
	while object do
		local effect = object.effect
		if effect and effect.kind == "buff" then
			return effect.buff, object
		end
		if not object.supersedes or seen[object.id] then
			return nil
		end
		seen[object.id] = true
		object = byId[object.supersedes]
	end
	return nil
end
