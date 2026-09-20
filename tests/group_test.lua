local _, t, root = ...

-- `Core/Roster.lua` and `Core/Auras.lua`, executed against tests/wowmock.lua.
--
-- Both read units, so neither is reachable from the pure suites, and both have
-- had defects with quiet symptoms: a raid silently missing its last member, and
-- a unit name the client had made secret being compared and used as a table
-- key, which throws.
local Mock = dofile(root .. "/tests/wowmock.lua")
local tests = {}

local function build(world)
	local state = Mock.install(world)
	local FK = Mock.newFK()

	for _, file in ipairs({
		"Data/BuffGroups.lua", "Data/CampObjects.lua", "Data/ClassBuffs.lua",
		"Core/Wire.lua", "Core/Plan.lua", "Core/Buffs.lua", "Core/Cooldowns.lua",
	}) do
		Mock.load(FK, root, file)
	end

	FK.Capabilities = { Has = function(name) return name == "groupRoster" end, results = {} }
	Mock.load(FK, root, "Core/Roster.lua")
	Mock.load(FK, root, "Core/Auras.lua")

	return FK, state
end

local function inGroup(FK)
	local count = 0
	for _, player in pairs(FK.Roster.players) do
		if player.inGroup then
			count = count + 1
		end
	end
	return count
end

function tests.a_party_of_five_is_five()
	local FK = build({ count = 5, inRaid = false })
	FK.Roster:ScanGroup()
	t.equals(inGroup(FK), 5, "you plus party1 to party4")
end

function tests.a_raid_of_twenty_five_is_twenty_five()
	-- raid1..raidN covers the whole raid including you, so raid1 reports your
	-- own name. Counting a raid like a party dropped the last member.
	local FK = build({ count = 25, inRaid = true, names = { raid1 = "Ana" } })
	FK.Roster:ScanGroup()
	t.equals(inGroup(FK), 25, "every raider")
	t.isTrue(FK.Roster.players["raid25"], "including the last one")
end

function tests.nobody_is_listed_twice_in_a_raid()
	local FK = build({ count = 3, inRaid = true, names = { raid1 = "Ana" } })
	local members = FK.Auras:Snapshot()

	local seen, duplicates = {}, 0
	for _, member in ipairs(members) do
		if seen[member.name] then
			duplicates = duplicates + 1
		end
		seen[member.name] = true
	end
	t.equals(duplicates, 0, "the player is not both 'player' and their raid token")
	t.count(members, 3, "three members, not four")
end

function tests.a_secret_unit_name_is_skipped_rather_than_thrown_on()
	-- UnitName is SecretWhenUnitNameIdentityRestricted. A secret cannot be
	-- compared, concatenated or used as a table key.
	local FK = build({ count = 3, inRaid = false, secretUnits = { party1 = true } })

	local ok, err = pcall(function() FK.Roster:ScanGroup() end)
	t.isTrue(ok, "scanning did not throw: " .. tostring(err))
	t.equals(FK.Roster.players["<secret>"], nil, "and no secret became a table key")
end

function tests.a_secret_own_name_does_not_break_the_addon()
	-- SelfKey sits on the CHAT_MSG_ADDON path, so this one would break on every
	-- message received.
	local FK = build({ count = 0, secretUnits = { player = true } })

	local ok, err = pcall(function() return FK.Roster.SelfKey() end)
	t.isTrue(ok, "SelfKey did not throw: " .. tostring(err))

	local snapshotOk, snapshotErr = pcall(function() return FK.Auras:Snapshot() end)
	t.isTrue(snapshotOk, "nor did an aura snapshot: " .. tostring(snapshotErr))
end

function tests.a_player_key_refuses_anything_it_cannot_read()
	local FK, state = build({ count = 0 })
	t.equals(FK.Roster.PlayerKey(state.secret, "Forever"), nil, "a secret name")
	t.equals(FK.Roster.PlayerKey("Ana", state.secret), nil, "a secret realm")
	t.equals(FK.Roster.PlayerKey(nil, nil), nil, "no name at all")
	t.equals(FK.Roster.PlayerKey("Ana", ""), "Ana", "an empty realm is just the name")
	t.equals(FK.Roster.PlayerKey("Ana", "Forever"), "Ana-Forever", "and a real one is joined")
end

function tests.an_unreadable_aura_is_not_an_empty_one()
	-- The client refuses aura reads in combat. Reporting "nobody has anything"
	-- would be worse than reporting nothing.
	local FK = build({ count = 2, inRaid = false })
	local members = FK.Auras:Snapshot()
	t.isTrue(#members > 0, "the group is still listed")
	for _, member in ipairs(members) do
		t.equals(member.auras, nil, member.name .. " has no invented aura list")
	end
end

return tests
