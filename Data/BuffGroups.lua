local _, FK = ...

FK.Data = FK.Data or {}

-- Camp buffs do not stack with the equivalent class buff: they are an
-- alternative to it, not an addition. A camp slot spent on a buff the group
-- already has is a wasted slot, so every buff a camp object can give belongs to
-- a group here, together with the class buffs that make it redundant.
--
-- Each group's class buff is the spell the client's own tooltip names, which is
-- what decides the grouping. See docs/DATA.md for where those tooltips came
-- from.
--
-- `auras` lists every aura name that counts as that buff, so a rank or the
-- group version satisfies it. It defaults to the spell's own name. This table
-- is the single source of truth for which aura covers which camp buff: reading
-- it the other way round, from a list of buffs worth asking a groupmate for,
-- is what let Blessing of Salvation be mistaken for Attack Power.
--
-- `confidence` follows the same scale as Data/CampObjects.lua.
FK.Data.buffGroups = {
	strength = {
		label = "Strength",
		classBuffs = {
			-- The Sharpening Wheel's tooltip names this one specifically.
			{ spell = "Strength of Earth Totem", class = "SHAMAN" },
		},
		confidence = "reported",
	},
	attack_power = {
		label = "Attack Power",
		classBuffs = {
			{ spell = "Blessing of Might", class = "PALADIN",
				auras = { "Blessing of Might", "Greater Blessing of Might" } },
			{ spell = "Battle Shout", class = "WARRIOR" },
		},
		confidence = "reported",
	},
	intellect = {
		label = "Intellect",
		classBuffs = {
			{ spell = "Arcane Intellect", class = "MAGE",
				auras = { "Arcane Intellect", "Arcane Brilliance" } },
		},
		confidence = "reported",
	},
	stamina = {
		label = "Stamina",
		classBuffs = {
			{ spell = "Power Word: Fortitude", class = "PRIEST",
				auras = { "Power Word: Fortitude", "Prayer of Fortitude" } },
		},
		confidence = "reported",
	},
	spirit = {
		label = "Spirit",
		classBuffs = {
			-- Divine Spirit is baseline for priests in Forever rather than a
			-- Discipline talent, so any priest covers this group.
			{ spell = "Divine Spirit", class = "PRIEST",
				auras = { "Divine Spirit", "Prayer of Spirit" } },
		},
		confidence = "reported",
	},
	mana_regen = {
		label = "Mana regeneration",
		classBuffs = {
			{ spell = "Blessing of Wisdom", class = "PALADIN",
				auras = { "Blessing of Wisdom", "Greater Blessing of Wisdom" } },
		},
		confidence = "reported",
	},
	armor = {
		label = "Armor",
		classBuffs = {
			{ spell = "Mark of the Wild", class = "DRUID",
				auras = { "Mark of the Wild", "Gift of the Wild" } },
		},
		confidence = "reported",
	},
	crit = {
		label = "Critical strike",
		classBuffs = {
			{ spell = "Moonkin Aura", class = "DRUID" },
		},
		confidence = "reported",
	},
	all_stats = {
		label = "All stats",
		classBuffs = {
			{ spell = "Blessing of Kings", class = "PALADIN",
				auras = { "Blessing of Kings", "Greater Blessing of Kings" } },
		},
		confidence = "reported",
	},
}

-- Which buff groups a class can cover, and which aura covers which group. Both
-- are derived from the table above so nothing can drift apart from it.
local byClass, byAura = {}, {}
for key, group in pairs(FK.Data.buffGroups) do
	for _, buff in ipairs(group.classBuffs) do
		byClass[buff.class] = byClass[buff.class] or {}
		byClass[buff.class][key] = buff.spell

		for _, aura in ipairs(buff.auras or { buff.spell }) do
			byAura[aura] = key
		end
	end
end

FK.Data.buffGroupsByClass = byClass
FK.Data.buffGroupByAura = byAura

--- The camp buff group an observed aura makes redundant, or nil.
function FK.Data.BuffGroupForAura(auraName)
	return byAura[auraName]
end

--- Buff groups the given classes already cover.
-- @param classes array of class file names, e.g. { "MAGE", "WARRIOR" }
-- @return table mapping buff group key to the class buff that covers it
function FK.Data.CoverageForClasses(classes)
	local covered = {}
	for _, class in ipairs(classes or {}) do
		for key, spell in pairs(byClass[class] or {}) do
			covered[key] = covered[key] or spell
		end
	end
	return covered
end
