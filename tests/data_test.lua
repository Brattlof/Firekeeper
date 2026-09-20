local FK, t = ...

local Data = FK.Data
local tests = {}

function tests.every_profession_has_at_least_three_objects()
	-- Thirty-eight, not thirty-six. The set is eleven professions times three,
	-- plus the Horde banner's own item, plus Cooking's Cookie's Feast and Iron
	-- Oven, plus the three campfire kits, which are the fire rather than a thing
	-- placed on it.
	t.count(Data.campObjects, 38, "every object we have a tooltip for")
	t.count(Data.Gaps(), 0, "no profession is short")
	for _, profession in ipairs(Data.professions) do
		local known = Data.campObjectsByProfession[profession] or {}
		t.isTrue(#known >= 3, profession .. " has at least three, got " .. #known)
	end
	t.count(Data.campObjectsByProfession.Cooking, 5, "Cooking has three fires and two features")
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

function tests.anything_listed_as_unknown_really_is_unknown()
	-- The list is empty today. The invariant still matters: if an object is ever
	-- added without an effect, it must show up here and nowhere else.
	for _, object in ipairs(Data.UnknownEffects()) do
		t.equals(object.effect.kind, "unknown", object.name .. " is listed because its effect is unknown")
	end
end

function tests.every_object_has_a_sourced_effect()
	-- Every one of them now, read from the client's own tooltip. If this ever
	-- regresses, docs/DATA.md is wrong too.
	t.count(Data.UnknownEffects(), 0, "nothing is left as an unknown effect")
end

function tests.every_object_carries_the_item_id_it_was_verified_by()
	for _, object in ipairs(Data.campObjects) do
		t.isTrue(type(object.itemId) == "number", object.name .. " has an item id")
	end
end

function tests.a_superseding_object_carries_the_lower_tier_buff()
	-- "provides all of the benefits of a Sharpening Wheel", so the Anvil gives
	-- Strength even though its own effect is a workspace.
	t.equals((Data.EffectiveBuff(Data.GetObject("anvil"))), "strength", "the anvil carries Strength")
	t.equals((Data.EffectiveBuff(Data.GetObject("master_forge"))), "strength", "so does the forge")
	t.equals((Data.EffectiveBuff(Data.GetObject("sharpening_wheel"))), "strength", "and the wheel itself")

	-- Engineering is the exception: neither tooltip promises the lower tier.
	t.equals((Data.EffectiveBuff(Data.GetObject("repair_bot"))), nil, "the repair bot carries no buff")
	t.equals((Data.EffectiveBuff(Data.GetObject("anarchists_workbench"))), nil, "nor the workbench")
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
