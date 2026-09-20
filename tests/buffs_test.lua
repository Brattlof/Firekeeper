local FK, t = ...

local Buffs = FK.Buffs
local tests = {}

local function member(name, class, auras, level)
	local set = nil
	if auras then
		set = {}
		for _, aura in ipairs(auras) do
			set[aura] = true
		end
	end
	return { name = name, class = class, level = level or 60, auras = set }
end

local function find(result, key)
	for _, entry in ipairs(result.missing) do
		if entry.key == key then
			return entry
		end
	end
end

function tests.asks_the_mage_for_intellect()
	local result = Buffs.Evaluate({
		members = { member("Ana", "MAGE", {}), member("Bo", "WARRIOR", {}) },
	})
	local entry = find(result, "intellect")
	t.isTrue(entry, "Arcane Intellect is missing")
	t.count(entry.needing, 1, "only the mana user needs it")
	t.equals(entry.needing[1], "Ana", "and that is the mage")
	t.equals(entry.providers[1], "Ana", "who can also cast it")
end

function tests.a_buff_nobody_can_cast_is_not_nagged_about()
	local result = Buffs.Evaluate({
		members = { member("Ana", "WARRIOR", {}), member("Bo", "ROGUE", {}) },
	})
	t.equals(find(result, "intellect"), nil, "no mage, no nagging about Intellect")
	t.equals(find(result, "wild"), nil, "and no druid, no Mark of the Wild")
	t.isTrue(find(result, "battleshout"), "but the warrior should shout")
end

function tests.a_talent_buff_waits_for_proof_that_somebody_has_it()
	local without = Buffs.Evaluate({
		members = { member("Ana", "PRIEST", {}), member("Bo", "MAGE", {}) },
	})
	t.equals(find(without, "spirit"), nil, "nobody is carrying Divine Spirit, so nobody is asked")

	local with = Buffs.Evaluate({
		members = { member("Ana", "PRIEST", { "Divine Spirit" }), member("Bo", "MAGE", {}) },
	})
	local entry = find(with, "spirit")
	t.isTrue(entry, "once it is seen, the rest can ask")
	t.count(entry.needing, 1, "only the mage is short")
end

function tests.the_group_version_counts()
	local result = Buffs.Evaluate({
		members = {
			member("Ana", "PRIEST", { "Prayer of Fortitude" }),
			member("Bo", "WARRIOR", { "Prayer of Fortitude" }),
		},
	})
	t.equals(find(result, "fortitude"), nil, "Prayer of Fortitude satisfies Power Word: Fortitude")
end

function tests.a_self_buff_is_only_your_own_problem()
	local result = Buffs.Evaluate({
		members = { member("Ana", "HUNTER", {}), member("Bo", "WARRIOR", {}) },
	})
	local entry = find(result, "aspect")
	t.isTrue(entry, "the hunter has no aspect up")
	t.count(entry.needing, 1, "and the warrior is not expected to have one")
	t.equals(entry.scope, "self", "it is a self buff")
end

function tests.an_optional_buff_stays_off_until_asked_for()
	local members = { member("Ana", "PRIEST", {}), member("Bo", "WARRIOR", {}) }
	t.equals(find(Buffs.Evaluate({ members = members }), "shadowprot"), nil, "off by default")

	local on = Buffs.Evaluate({ members = members, optional = { shadowprot = true } })
	t.isTrue(find(on, "shadowprot"), "on when the player asks for it")
end

function tests.a_player_we_cannot_read_is_not_assumed_to_be_missing_buffs()
	local result = Buffs.Evaluate({
		members = {
			member("Ana", "MAGE", nil), -- auras unreadable
			member("Bo", "WARRIOR", nil),
		},
	})
	t.equals(result.unreadable, 2, "both are unreadable")
	t.count(result.missing, 0, "and nothing is claimed about them")
end

function tests.an_observed_aura_covers_a_camp_buff_group()
	local covered = Buffs.ObservedCoverage({
		member("Ana", "PALADIN", { "Greater Blessing of Might" }),
		member("Bo", "MAGE", { "Arcane Intellect" }),
	})
	t.equals(covered.attack_power, "Greater Blessing of Might", "the blessing covers Attack Power")
	t.equals(covered.intellect, "Arcane Intellect", "and the mage covers Intellect")
	t.equals(covered.spirit, nil, "nothing covers Spirit, so a banner is still worth placing")
end

function tests.observed_coverage_ignores_players_we_could_not_read()
	local covered = Buffs.ObservedCoverage({ member("Ana", "MAGE", nil) })
	t.equals(covered.intellect, nil, "an unread mage proves nothing")
end

return tests
