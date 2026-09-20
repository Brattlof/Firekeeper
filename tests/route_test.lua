local FK, t = ...

local Route = FK.Route
local tests = {}

local function only(entries, profession)
	for _, entry in ipairs(entries) do
		if entry.profession == profession then
			return entry
		end
	end
end

function tests.a_new_smith_has_nothing_ready_yet()
	local entry = only(Route.Evaluate({ Blacksmithing = 5 }), "Blacksmithing")
	t.count(entry.placeable, 0, "skill 5 places nothing")
	t.equals(entry.next.name, "Sharpening Wheel", "the wheel comes first")
	t.equals(entry.short, 15, "fifteen points off")
end

function tests.skill_unlocks_in_order()
	local entry = only(Route.Evaluate({ Blacksmithing = 145 }), "Blacksmithing")
	t.count(entry.placeable, 2, "the wheel and the anvil")
	t.equals(entry.next.name, "Master Forge", "the forge is next")
	t.equals(entry.short, 155, "and it is a long way off")
end

function tests.a_maxed_profession_has_nothing_left_to_wait_for()
	local entry = only(Route.Evaluate({ Blacksmithing = 300 }), "Blacksmithing")
	t.count(entry.placeable, 3, "all three")
	t.equals(entry.next, nil, "nothing further to unlock")
	t.equals(entry.short, nil, "and nothing to be short of")
end

function tests.objects_with_no_known_requirement_are_named_not_hidden()
	-- Only tier 1 has a reported skill level for most professions, so the
	-- other two should be counted rather than quietly dropped.
	local entry = only(Route.Evaluate({ Herbalism = 20 }), "Herbalism")
	t.count(entry.placeable, 1, "the candle is ready")
	t.equals(entry.next, nil, "nothing else has a known requirement")
	t.count(entry.blueprints, 2, "but two more exist and we say so")
end

function tests.the_nearest_unlock_is_listed_first()
	local entries = Route.Evaluate({
		Blacksmithing = 139, -- one point off the anvil
		Tailoring = 1, -- nineteen off the banner
	})
	t.equals(entries[1].profession, "Blacksmithing", "one point away comes first")
	t.equals(entries[1].short, 1, "one point")
	t.equals(entries[2].profession, "Tailoring", "then the further one")
end

function tests.a_profession_with_nothing_pending_sinks_below_one_that_has()
	local entries = Route.Evaluate({ Blacksmithing = 300, Tailoring = 1 })
	t.equals(entries[1].profession, "Tailoring", "something to work towards comes first")
	t.equals(entries[2].profession, "Blacksmithing", "a finished trade sits below")
end

function tests.the_line_reads_like_a_sentence()
	local entry = only(Route.Evaluate({ Blacksmithing = 145 }), "Blacksmithing")
	t.equals(Route.Line(entry),
		"Blacksmithing 145 — Sharpening Wheel, Anvil ready, Master Forge in 155 skill",
		"readable summary")
end

function tests.no_professions_is_not_an_error()
	t.count(Route.Evaluate(nil), 0, "nil is fine")
	t.count(Route.Evaluate({}), 0, "and so is nothing known")
end

return tests
