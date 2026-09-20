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

function tests.fortitude_covers_the_camp_stamina_buff()
	-- The First Aid Kit gives Stamina and does not stack with Power Word:
	-- Fortitude, so a priest who has actually cast it makes the kit a wasted
	-- slot.
	local covered = Buffs.ObservedCoverage({ member("Ana", "PRIEST", { "Prayer of Fortitude" }) })
	t.equals(covered.stamina, "Prayer of Fortitude", "the group version covers it too")
end

function tests.a_blessing_only_covers_what_that_blessing_gives()
	-- The bug: every one of a paladin's twelve blessings was mapped to Attack
	-- Power, so a paladin running Salvation made the planner drop the Lodestone
	-- and the camp went without its Attack Power buff.
	local salvation = Buffs.ObservedCoverage({ member("Ana", "PALADIN", { "Blessing of Salvation" }) })
	t.equals(salvation.attack_power, nil, "Salvation is not Attack Power")

	local might = Buffs.ObservedCoverage({ member("Ana", "PALADIN", { "Greater Blessing of Might" }) })
	t.equals(might.attack_power, "Greater Blessing of Might", "Might is, and so is its group version")

	local wisdom = Buffs.ObservedCoverage({ member("Ana", "PALADIN", { "Blessing of Wisdom" }) })
	t.equals(wisdom.mana_regen, "Blessing of Wisdom", "Wisdom covers the Mana Well instead")
	t.equals(wisdom.attack_power, nil, "and nothing else")

	local kings = Buffs.ObservedCoverage({ member("Ana", "PALADIN", { "Blessing of Kings" }) })
	t.equals(kings.all_stats, "Blessing of Kings", "Kings covers the Fish Bowl")
end

function tests.every_camp_buff_can_be_covered_by_an_observed_aura()
	-- The other half of the bug: five of the nine groups had no aura wired to
	-- them, so once the client let us read auras the planner got *worse* — it
	-- would suggest a Sharpening Wheel next to a shaman already running Strength
	-- of Earth Totem. Every group a camp object uses must be reachable.
	local used = {}
	for _, object in ipairs(FK.Data.campObjects) do
		local group = FK.Data.EffectiveBuff(object)
		if group then used[group] = object.name end
	end

	for group, objectName in pairs(used) do
		local reachable = false
		for aura, key in pairs(FK.Data.buffGroupByAura) do
			if key == group then reachable = true end
			local _ = aura
		end
		t.isTrue(reachable, group .. " (" .. objectName .. ") can be covered by an aura")
	end
end

function tests.each_group_is_reachable_by_its_own_class_buff()
	local cases = {
		{ "Strength of Earth Totem", "strength" },
		{ "Mark of the Wild", "armor" },
		{ "Gift of the Wild", "armor" },
		{ "Moonkin Aura", "crit" },
		{ "Blessing of Wisdom", "mana_regen" },
		{ "Blessing of Kings", "all_stats" },
		{ "Arcane Brilliance", "intellect" },
		{ "Prayer of Spirit", "spirit" },
		{ "Battle Shout", "attack_power" },
	}
	for _, case in ipairs(cases) do
		t.equals(FK.Data.BuffGroupForAura(case[1]), case[2], case[1] .. " covers " .. case[2])
	end
	t.equals(FK.Data.BuffGroupForAura("Inner Fire"), nil, "a self buff covers no camp object")
end

function tests.observed_coverage_ignores_players_we_could_not_read()
	local covered = Buffs.ObservedCoverage({ member("Ana", "MAGE", nil) })
	t.equals(covered.intellect, nil, "an unread mage proves nothing")
end

return tests
