local FK, t = ...

local Nearby = FK.Nearby
local tests = {}

local here = { uiMapID = 1440, x = 0.5, y = 0.5 }
local world = { width = 4000, height = 3000 }

local function at(x, y, mapID)
	return { uiMapID = mapID or 1440, x = x, y = y }
end

function tests.north_is_a_falling_y()
	-- Map coordinates run y downwards, so the top of the map is north.
	t.equals(Nearby.Direction(here, at(0.5, 0.1)), "north", "up the map is north")
	t.equals(Nearby.Direction(here, at(0.5, 0.9)), "south", "down the map is south")
	t.equals(Nearby.Direction(here, at(0.9, 0.5)), "east", "right is east")
	t.equals(Nearby.Direction(here, at(0.1, 0.5)), "west", "left is west")
end

function tests.the_diagonals_are_named_too()
	t.equals(Nearby.Direction(here, at(0.9, 0.1)), "north-east", "up and right")
	t.equals(Nearby.Direction(here, at(0.9, 0.9)), "south-east", "down and right")
	t.equals(Nearby.Direction(here, at(0.1, 0.9)), "south-west", "down and left")
	t.equals(Nearby.Direction(here, at(0.1, 0.1)), "north-west", "up and left")
end

function tests.standing_on_someone_is_not_a_direction()
	t.equals(Nearby.Direction(here, at(0.5, 0.5)), "right here", "no bearing to yourself")
end

function tests.yards_come_from_the_map_size()
	-- A tenth of a 4000 yard wide map is 400 yards. Compared with a tolerance
	-- because 0.6 - 0.5 is not exactly 0.1 in a double.
	t.isTrue(math.abs(Nearby.Yards(here, at(0.6, 0.5), world) - 400) < 0.001, "across")
	t.isTrue(math.abs(Nearby.Yards(here, at(0.5, 0.6), world) - 300) < 0.001, "and down a 3000 yard map")
end

function tests.without_a_map_size_there_is_no_honest_distance()
	t.equals(Nearby.Yards(here, at(0.6, 0.5), nil), nil, "no size, no number")
	t.equals(Nearby.Yards(here, at(0.6, 0.5), { width = 0, height = 0 }), nil, "and no guessing from zero")
end

function tests.the_closest_guildie_is_listed_first()
	Nearby.Clear()
	Nearby.Upsert("Far", at(0.9, 0.5), 100)
	Nearby.Upsert("Near", at(0.55, 0.5), 100)
	Nearby.Upsert("Elsewhere", at(0.5, 0.5, 1), 100)

	local active = Nearby.Active(100, here, world)
	t.equals(active[1].name, "Near", "nearest first")
	t.equals(active[2].name, "Far", "then further")
	t.equals(active[3].name, "Elsewhere", "another zone last")
	t.equals(active[1].direction, "east", "with a direction to walk")
end

function tests.a_stale_position_is_dropped()
	Nearby.Clear()
	Nearby.Upsert("Ana", at(0.5, 0.4), 0)
	t.count(Nearby.Active(Nearby.EXPIRY + 1, here, world), 0, "five minutes old is too old")

	Nearby.Prune(Nearby.EXPIRY + 1)
	t.equals(Nearby.entries.Ana, nil, "and pruning clears the table")
end

function tests.indoors_everyone_is_still_listed()
	Nearby.Clear()
	Nearby.Upsert("Ana", at(0.5, 0.4), 100)

	-- No position for us: the game gives none in an instance.
	local active = Nearby.Active(100, nil, world)
	t.count(active, 1, "Ana is still there")
	t.equals(active[1].yards, nil, "we just cannot say how far")
	t.equals(active[1].sameMap, false, "or whether it is even the same map")
end

function tests.standing_on_someone_reads_like_english()
	-- It used to say "Bo — right here of here".
	t.equals(Nearby.Line({ name = "Bo", sameMap = true, direction = "right here" }),
		"Bo — right here", "with no distance")
	t.equals(Nearby.Line({ name = "Bo", sameMap = true, yards = 0.4, direction = "right here" }),
		"Bo — right here", "and with one")
end

function tests.the_line_reads_like_a_sentence()
	t.equals(Nearby.Line({ name = "Ana", sameMap = true, yards = 140.4, direction = "north-east" }),
		"Ana — 140 yards north-east", "same map, with a distance")
	t.equals(Nearby.Line({ name = "Bo", sameMap = false }, "Ashenvale"),
		"Bo — Ashenvale", "another map, by name")
end

return tests
