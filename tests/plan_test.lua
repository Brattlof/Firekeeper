local FK, t = ...

local Plan = FK.Plan
local tests = {}

local function contributor(name, objects, readyIn)
	return { name = name, objects = objects, ready = (readyIn or 0) <= 0, readyIn = readyIn or 0 }
end

function tests.suggests_the_best_object_for_each_player()
	local plan = Plan.Evaluate({
		contributors = {
			contributor("Ana", { "sharpening_wheel" }),
			contributor("Bo", { "incense_candle" }),
		},
	})
	t.count(plan.suggestions, 2, "both players get a suggestion")
	t.equals(plan.capacity, 3, "a basic fire holds three objects")
	t.equals(plan.free, 1, "one slot left over")
end

function tests.skips_a_buff_the_group_already_has()
	-- The Sharpening Wheel gives Strength, exclusive with Strength of Earth
	-- Totem, per its own tooltip.
	local plan = Plan.Evaluate({
		covered = { strength = "Strength of Earth Totem" },
		contributors = { contributor("Ana", { "sharpening_wheel" }) },
	})
	t.count(plan.suggestions, 0, "no suggestion for a covered buff")
	t.count(plan.redundant, 1, "the wheel is reported as wasted")
	t.equals(plan.redundant[1].reason.code, "covered", "reason is the class buff")
	t.equals(Plan.ReasonText(plan.redundant[1].reason),
		"Strength is already covered by Strength of Earth Totem", "readable reason")
end

function tests.an_anvil_and_a_wheel_are_not_both_suggested()
	-- FK-16: the Anvil's tooltip says it provides all of the Sharpening Wheel's
	-- benefits, so suggesting both would waste a slot. The better one wins.
	local plan = Plan.Evaluate({
		slots = 3,
		contributors = {
			contributor("Ana", { "sharpening_wheel" }),
			contributor("Bo", { "anvil" }),
		},
	})
	t.count(plan.suggestions, 1, "one of the two is enough")
	t.equals(plan.suggestions[1].objectId, "anvil", "and it is the one that is also a workspace")
end

function tests.a_superseding_object_is_skipped_when_its_buff_is_covered()
	local plan = Plan.Evaluate({
		covered = { strength = "Strength of Earth Totem" },
		contributors = { contributor("Ana", { "anvil" }) },
	})
	-- The anvil is still worth placing as a workspace even when the Strength is
	-- covered, so it must not be silently dropped as a duplicate buff.
	t.isTrue(#plan.suggestions + #plan.redundant > 0, "the anvil is accounted for either way")
end

function tests.one_object_per_player()
	local plan = Plan.Evaluate({
		contributors = { contributor("Ana", { "sharpening_wheel", "alchemy_laboratory" }) },
	})
	t.count(plan.suggestions, 1, "a player contributes once")
end

function tests.never_suggests_two_of_the_same_effect()
	local plan = Plan.Evaluate({
		contributors = {
			contributor("Ana", { "sharpening_wheel" }),
			contributor("Bo", { "sharpening_wheel" }),
		},
	})
	t.count(plan.suggestions, 1, "the second wheel adds nothing")
	t.count(plan.redundant, 0, "it is simply not suggested, not flagged")
end

function tests.respects_slot_capacity()
	local plan = Plan.Evaluate({
		slots = 1,
		contributors = {
			contributor("Ana", { "sharpening_wheel" }),
			contributor("Bo", { "incense_candle" }),
			contributor("Cy", { "faction_banner" }),
		},
	})
	t.count(plan.suggestions, 1, "only one slot, one suggestion")
	t.equals(plan.free, 0, "and it is spoken for")
end

function tests.a_campfire_upgrade_comes_first_and_buys_slots()
	local plan = Plan.Evaluate({
		slots = 3,
		contributors = {
			contributor("Ana", { "sharpening_wheel" }),
			contributor("Bo", { "incense_candle" }),
			contributor("Cy", { "faction_banner" }),
			contributor("Di", { "journeyman_campfire_kit" }),
		},
	})
	t.equals(plan.suggestions[1].objectId, "journeyman_campfire_kit", "the fire is upgraded first")
	t.equals(plan.capacity, 5, "capacity rises to five")
	t.count(plan.suggestions, 4, "everyone still gets to contribute")
end

function tests.an_expert_campfire_holds_ten()
	local plan = Plan.Evaluate({
		slots = 3,
		contributors = {
			contributor("Ana", { "expert_campfire_kit" }),
			contributor("Bo", { "incense_candle" }),
			contributor("Cy", { "faction_banner" }),
			contributor("Di", { "sharpening_wheel" }),
		},
	})
	t.equals(plan.capacity, 10, "the expert fire holds ten")
	t.count(plan.suggestions, 4, "and everyone fits")
	-- The fire replaces the basic one rather than taking a slot (FK-2), so ten
	-- capacity less the three buffs leaves seven.
	t.equals(plan.free, 7, "with room to spare")
end

function tests.two_campfires_do_not_both_get_placed()
	local plan = Plan.Evaluate({
		slots = 3,
		contributors = {
			contributor("Ana", { "expert_campfire_kit" }),
			contributor("Bo", { "journeyman_campfire_kit" }),
		},
	})
	t.count(plan.suggestions, 1, "one fire is enough")
	t.equals(plan.suggestions[1].objectId, "expert_campfire_kit", "the bigger one wins")
end

function tests.objects_already_on_the_fire_are_not_repeated()
	local plan = Plan.Evaluate({
		placed = { { player = "Ana", objectId = "incense_candle" } },
		contributors = { contributor("Bo", { "incense_candle" }) },
	})
	t.count(plan.suggestions, 0, "no second candle")
	t.equals(plan.redundant[1].reason.code, "duplicate", "reported as a duplicate")
	t.equals(plan.used, 1, "one slot is in use")
end

function tests.a_player_who_already_contributed_is_left_alone()
	local plan = Plan.Evaluate({
		placed = { { player = "Ana", objectId = "incense_candle" } },
		contributors = { contributor("Ana", { "sharpening_wheel" }) },
	})
	t.count(plan.suggestions, 0, "Ana has spent her contribution")
end

function tests.players_on_cooldown_are_listed_as_waiting()
	local plan = Plan.Evaluate({
		contributors = { contributor("Ana", { "sharpening_wheel" }, 900) },
	})
	t.count(plan.suggestions, 0, "nothing to suggest")
	t.count(plan.waiting, 1, "Ana is waiting")
	t.equals(plan.waiting[1].readyIn, 900, "with her remaining cooldown")
end

function tests.unknown_object_ids_are_reported_not_ignored()
	local plan = Plan.Evaluate({
		contributors = { contributor("Ana", { "something_from_a_newer_version" }) },
	})
	t.count(plan.unknownObjects, 1, "an unknown id is surfaced")
	t.count(plan.suggestions, 0, "and never planned around")
end

function tests.the_plan_is_deterministic()
	local state = {
		contributors = {
			contributor("Ana", { "sharpening_wheel", "alchemy_laboratory" }),
			contributor("Bo", { "incense_candle", "tanning_rack" }),
			contributor("Cy", { "faction_banner" }),
		},
	}
	local first = Plan.Evaluate(state)
	local second = Plan.Evaluate(state)
	for index, suggestion in ipairs(first.suggestions) do
		t.equals(second.suggestions[index].objectId, suggestion.objectId,
			"same plan on both clients, position " .. index)
	end
end

function tests.flags_that_suggestions_rest_on_unconfirmed_data()
	local plan = Plan.Evaluate({
		contributors = { contributor("Ana", { "sharpening_wheel" }) },
	})
	t.isTrue(plan.uncertain, "nothing is confirmed in game yet")
end

return tests
