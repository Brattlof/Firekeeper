local FK, t = ...

local Wire = FK.Wire
local tests = {}

--- Everything a character with these professions at this skill could place,
-- which is what `Core/Professions.lua` hands the encoder.
local function placeable(professions, skill)
	local ids = {}
	for _, profession in ipairs(professions) do
		for _, object in ipairs(FK.Data.campObjectsByProfession[profession] or {}) do
			local reachable = object.skill and skill >= object.skill
			if reachable or (not object.skill and object.source ~= "blueprint") then
				table.insert(ids, object.id)
			end
		end
	end
	return ids
end

-- `OBJ:<version>||<cooldown>` around the id list.
local HEADER = #("OBJ:v0.1.0||0")

function tests.a_maxed_character_used_to_overflow_the_message()
	-- The bug this file exists for. Three maxed primaries plus the secondaries
	-- is eighteen objects: 256 bytes of ids, 269 with the header, against a 255
	-- byte limit. The client answers InvalidMessage and the OBJ never goes.
	local ids = placeable({ "Engineering", "Enchanting", "Alchemy", "Cooking", "First Aid", "Fishing" }, 300)
	t.isTrue(Wire.Size(ids) + HEADER > Wire.MAX_PAYLOAD,
		"unpacked it overflows: " .. (Wire.Size(ids) + HEADER) .. " bytes")

	-- Dropping what is superseded is enough on its own here, so nothing the
	-- planner could have used is lost.
	local packed, dropped = Wire.PackIds(ids, HEADER)
	t.isTrue(Wire.Size(packed) + HEADER <= Wire.MAX_PAYLOAD, "packed, it fits")
	t.equals(dropped, 0, "and nothing had to be truncated to get there")
end

function tests.two_primaries_fit_once_blueprint_fires_are_not_advertised()
	-- This character overflowed too, until the upgraded campfire kits stopped
	-- being offered to someone who cannot build them.
	local ids = placeable({ "Engineering", "Enchanting", "Cooking", "First Aid", "Fishing" }, 300)
	t.isTrue(Wire.Size(ids) + HEADER <= Wire.MAX_PAYLOAD,
		"it fits without any packing: " .. (Wire.Size(ids) + HEADER) .. " bytes")
end

function tests.every_plausible_character_fits()
	local professions = {
		"Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Herbalism",
		"Leatherworking", "Mining", "Skinning", "Tailoring", "Cooking",
		"First Aid", "Fishing",
	}
	-- Every profession at 300 is 486 bytes of ids, and still 359 after the
	-- superseded ones go, so this is the case that genuinely has to be cut
	-- short. It must produce a valid message rather than none at all.
	local ids = placeable(professions, 300)
	local packed, dropped = Wire.PackIds(ids, HEADER)
	t.isTrue(Wire.Size(packed) + HEADER <= Wire.MAX_PAYLOAD, "all twelve professions still fit")
	t.isTrue(#packed > 0, "and something is still offered")
	t.isTrue(dropped > 0, "with the caller told that some were left out")
end

function tests.a_superseded_object_is_not_offered_alongside_the_one_that_replaces_it()
	local kept = Wire.DropSuperseded({ "sharpening_wheel", "anvil", "master_forge" })
	local has = {}
	for _, id in ipairs(kept) do has[id] = true end

	t.equals(has.sharpening_wheel, nil, "the wheel adds nothing next to an anvil")
	t.isTrue(has.anvil, "the anvil stays")
	t.isTrue(has.master_forge, "and so does the forge")
end

function tests.a_lower_tier_is_kept_when_nothing_replaces_it()
	local kept = Wire.DropSuperseded({ "sharpening_wheel", "incense_candle" })
	t.count(kept, 2, "neither supersedes the other, so both are offered")
end

function tests.engineering_is_never_thinned()
	-- Engineering's tooltips do not promise the lower tier's benefits, so a
	-- Repair Bot is not a substitute for a Reagent Bot.
	local kept = Wire.DropSuperseded({ "reagent_bot", "repair_bot", "anarchists_workbench" })
	t.count(kept, 3, "all three stay on offer")
end

function tests.fitting_keeps_the_most_useful_and_counts_the_rest()
	local kept, dropped = Wire.Fit({ "aaaa", "bbbb", "cccc" }, 9)
	t.count(kept, 2, "two fit in nine bytes")
	t.equals(kept[1], "aaaa", "the first is kept")
	t.equals(dropped, 1, "and the caller is told one went")
end

function tests.a_budget_of_nothing_drops_everything_rather_than_erroring()
	local kept, dropped = Wire.Fit({ "aaaa" }, 0)
	t.count(kept, 0, "nothing fits")
	t.equals(dropped, 1, "and it says so")

	local none = Wire.PackIds({ "sharpening_wheel" }, 999)
	t.count(none, 0, "an overhead past the limit leaves no room")
end

function tests.an_empty_list_is_not_an_error()
	t.count(Wire.DropSuperseded(nil), 0, "nil")
	t.count(Wire.DropSuperseded({}), 0, "empty")
	t.equals(Wire.Size(nil), 0, "nothing costs nothing")
end

function tests.upgraded_campfires_are_not_offered_without_a_blueprint()
	-- They carry no skill requirement, so the old rule advertised them to a
	-- brand new cook and the planner promised a ten-slot fire.
	local ids = placeable({ "Cooking" }, 300)
	local has = {}
	for _, id in ipairs(ids) do has[id] = true end

	t.isTrue(has.basic_campfire_kit, "the basic kit is learned, not a blueprint")
	t.equals(has.journeyman_campfire_kit, nil, "the journeyman fire needs a blueprint")
	t.equals(has.expert_campfire_kit, nil, "and so does the expert one")
end

return tests
