local FK, t = ...

local CampList = FK.CampList
local tests = {}

local function camp(fields)
	return {
		uiMapID = fields.uiMapID or 1440,
		x = fields.x or 0.5,
		y = fields.y or 0.5,
		free = fields.free or 2,
		slots = fields.slots or 3,
		professions = fields.professions or { "Blacksmithing" },
	}
end

function tests.a_camp_survives_the_round_trip()
	local wire = CampList.EncodeHost(camp({ x = 0.4267, y = 0.6134, free = 1, slots = 5,
		professions = { "Alchemy", "Tailoring" } }))
	local back = CampList.DecodeHost(wire:match("^HOST:(.*)$"))

	t.equals(back.uiMapID, 1440, "map survives")
	t.equals(back.free, 1, "free slots survive")
	t.equals(back.slots, 5, "capacity survives")
	t.count(back.professions, 2, "both professions survive")
	-- Coordinates go over the wire as basis points, so they come back within
	-- a ten-thousandth, which is a couple of yards.
	t.isTrue(math.abs(back.x - 0.4267) < 0.0001, "x survives to basis points")
	t.isTrue(math.abs(back.y - 0.6134) < 0.0001, "y survives to basis points")
end

function tests.a_camp_with_no_professions_still_decodes()
	local wire = CampList.EncodeHost(camp({ professions = {} }))
	local back = CampList.DecodeHost(wire:match("^HOST:(.*)$"))
	t.isTrue(back, "it decodes")
	t.count(back.professions, 0, "with nobody's trade attached")
end

function tests.rubbish_is_rejected_rather_than_half_read()
	t.equals(CampList.DecodeHost("not a camp"), nil, "a sentence is not a camp")
	t.equals(CampList.DecodeHost(""), nil, "and neither is nothing")
	t.equals(CampList.DecodeHost("1440|500|500"), nil, "nor half a message")
end

function tests.a_message_fits_in_an_addon_payload()
	local wire = CampList.EncodeHost(camp({
		uiMapID = 99999,
		professions = {
			"Blacksmithing", "Leatherworking", "Alchemy", "Herbalism", "Mining",
			"Skinning", "Tailoring", "Enchanting", "Engineering", "Cooking",
			"First Aid", "Fishing",
		},
	}))
	-- The addon message limit is 255 bytes; every profession at once is the
	-- worst case anyone can send.
	t.isTrue(#wire <= 255, "the fullest possible camp still fits: " .. #wire .. " bytes")
end

function tests.one_camp_per_host()
	CampList.Clear()
	CampList.Upsert("Ana", camp({ free = 2 }), 100)
	CampList.Upsert("Ana", camp({ free = 0 }), 200)

	local active = CampList.Active(200, nil)
	t.count(active, 1, "Ana has one camp, not two")
	t.equals(active[1].free, 0, "and it is the newer one")
end

function tests.old_camps_drop_off()
	CampList.Clear()
	CampList.Upsert("Ana", camp({}), 0)
	CampList.Upsert("Bo", camp({}), 1000)

	local active = CampList.Active(1000 + CampList.EXPIRY, nil)
	t.count(active, 1, "Ana's fire went out twenty minutes ago")
	t.equals(active[1].host, "Bo", "Bo's is still listed")
end

function tests.pruning_frees_the_table()
	CampList.Clear()
	CampList.Upsert("Ana", camp({}), 0)
	CampList.Prune(CampList.EXPIRY + 1)
	t.equals(CampList.entries.Ana, nil, "the entry is gone, not just hidden")
end

function tests.the_nearest_fire_on_your_own_map_comes_first()
	CampList.Clear()
	CampList.Upsert("Far", camp({ x = 0.9, y = 0.9 }), 100)
	CampList.Upsert("Near", camp({ x = 0.52, y = 0.52 }), 100)
	CampList.Upsert("Elsewhere", camp({ uiMapID = 1, x = 0.5, y = 0.5 }), 100)

	local active = CampList.Active(100, { uiMapID = 1440, x = 0.5, y = 0.5 })
	t.equals(active[1].host, "Near", "the closest one first")
	t.equals(active[2].host, "Far", "then the far one on the same map")
	t.equals(active[3].host, "Elsewhere", "and another map last")
end

function tests.without_a_position_the_list_is_ordered_by_what_we_heard_last()
	CampList.Clear()
	CampList.Upsert("Old", camp({}), 100)
	CampList.Upsert("Recent", camp({}), 500)

	local active = CampList.Active(600, nil)
	t.equals(active[1].host, "Recent", "most recently heard of first")
	t.equals(active[1].sameMap, false, "and nothing claims to be on your map")
end

return tests
