local FK, t = ...

local Data = FK.Data
local tests = {}

function tests.every_profession_has_three_objects()
	t.count(Data.campObjects, 36, "twelve professions, three objects each")
	t.count(Data.Gaps(), 0, "no profession is short")
	for _, profession in ipairs(Data.professions) do
		t.count(Data.campObjectsByProfession[profession] or {}, 3, profession .. " has three")
	end
end

function tests.object_ids_are_unique()
	local seen, duplicates = {}, 0
	for _, object in ipairs(Data.campObjects) do
		if seen[object.id] then
			duplicates = duplicates + 1
		end
		seen[object.id] = true
	end
	t.equals(duplicates, 0, "no id is used twice")
end

function tests.a_buff_effect_names_a_group_that_exists()
	for _, object in ipairs(Data.campObjects) do
		local effect = object.effect or {}
		if effect.kind == "buff" then
			t.isTrue(Data.buffGroups[effect.buff], object.name .. " names a known buff group")
		end
	end
end

function tests.unknown_effects_are_listed_for_reporting()
	local unknown = Data.UnknownEffects()
	t.isTrue(#unknown > 0, "the beta still has objects nobody has seen")
	for _, object in ipairs(unknown) do
		t.equals(object.effect.kind, "unknown", object.name .. " is listed because its effect is unknown")
	end
end

function tests.the_sourced_effects_are_the_ones_we_can_cite()
	-- Twelve objects have an effect from a source we can point at; the rest are
	-- a name and nothing more. If this number moves, docs/DATA.md moves with it.
	local unknown = #Data.UnknownEffects()
	t.equals(#Data.campObjects - unknown, 12, "twelve objects have a sourced effect")
	t.equals(unknown, 24, "and twenty-four are still just a name")
end

function tests.campfires_are_sorted_and_capped()
	t.count(Data.campfires, 3, "three Cooking campfires")
	t.equals(Data.campfires[1].effect.slots, 3, "smallest first")
	t.equals(Data.MaxCampfireSlots(), 10, "the expert fire is the largest known")
end

function tests.a_campfire_can_be_named_in_a_command()
	-- Parenthesised: the lookup also returns the campfire's name, and a bare
	-- call would push that into the assertion's `expected` argument.
	t.equals((Data.SlotsForCampfireName("expert")), 10, "'expert' finds the ten-slot fire")
	t.equals((Data.SlotsForCampfireName("Journeyman")), 5, "case does not matter")
	t.equals((Data.SlotsForCampfireName("basic campfire kit")), 3, "a full name with spaces works")
	t.equals((Data.SlotsForCampfireName("sharpening wheel")), nil, "a non-campfire is not a campfire")
	t.equals((Data.SlotsForCampfireName("")), nil, "and neither is nothing")
end

return tests
