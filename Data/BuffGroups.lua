local _, FK = ...

FK.Data = FK.Data or {}

-- Camp buffs do not stack with the equivalent class buff: they are an
-- alternative to it, not an addition. A camp slot spent on a buff the group
-- already has is a wasted slot, so every buff a camp object can give belongs to
-- a group here, together with the class buffs that make it redundant.
--
-- Each group's `exclusive` is the spell the client's own tooltip names, which
-- is what decides the grouping. See docs/DATA.md for where those tooltips came
-- from.
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
			{ spell = "Blessing of Might", class = "PALADIN" },
			{ spell = "Battle Shout", class = "WARRIOR" },
		},
		confidence = "reported",
	},
	intellect = {
		label = "Intellect",
		classBuffs = {
			{ spell = "Arcane Intellect", class = "MAGE" },
		},
		confidence = "reported",
	},
	stamina = {
		label = "Stamina",
		classBuffs = {
			{ spell = "Power Word: Fortitude", class = "PRIEST" },
		},
		confidence = "reported",
	},
	spirit = {
		label = "Spirit",
		classBuffs = {
			-- Divine Spirit is baseline for priests in Forever rather than a
			-- Discipline talent, so any priest covers this group.
			{ spell = "Divine Spirit", class = "PRIEST" },
		},
		confidence = "reported",
	},
	mana_regen = {
		label = "Mana regeneration",
		classBuffs = {
			{ spell = "Blessing of Wisdom", class = "PALADIN" },
		},
		confidence = "reported",
	},
	armor = {
		label = "Armor",
		classBuffs = {
			{ spell = "Mark of the Wild", class = "DRUID" },
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
			{ spell = "Blessing of Kings", class = "PALADIN" },
		},
		confidence = "reported",
	},
}

-- Which buff groups a class can cover, derived from the table above so the two
-- can never drift apart.
local byClass = {}
for key, group in pairs(FK.Data.buffGroups) do
	for _, buff in ipairs(group.classBuffs) do
		byClass[buff.class] = byClass[buff.class] or {}
		byClass[buff.class][key] = buff.spell
	end
end

FK.Data.buffGroupsByClass = byClass

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
