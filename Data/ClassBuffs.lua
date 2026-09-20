local _, FK = ...

FK.Data = FK.Data or {}

-- The class buffs a group should be carrying.
--
-- Adapted from BuffWarden's buff table, which is MIT licensed:
--   Copyright (c) 2026 vebjorn — https://github.com/vBaustad/BuffWarden
-- The icon paths and spell IDs are dropped, because Firekeeper says this in
-- chat and in a plain panel rather than drawing a bar of icons.
--
-- Buffs are matched by aura name, so every rank counts and the group version
-- (Prayer of Fortitude, Gift of the Wild, Greater Blessing of Might) satisfies
-- the single-target one.
--
--   key        stable id, used by `/fk buffs` and the saved variables
--   label      what a human calls it
--   class      the class that provides it
--   auras      any of these on a player means they have the buff
--   scope      "group"    — cast on everyone
--              "self"     — only the caster benefits
--              "blessing" — one per paladin, so several can stack
--   who        nil = everyone, "mana" = only classes with a mana bar
--   minLevel   level a groupmate needs before it is fair to ask them for it
--   talent     only ask once somebody in the group is seen carrying it, since
--              that is the only proof anyone has the talent
--
-- This table is only about what is worth asking a groupmate for. Which aura
-- makes a *camp* object redundant is Data/BuffGroups.lua's job and is keyed per
-- aura there — a paladin's twelve blessings do not all mean Attack Power.
FK.Data.manaClasses = {
	PRIEST = true, MAGE = true, WARLOCK = true, DRUID = true,
	PALADIN = true, SHAMAN = true, HUNTER = true,
}

local BLESSINGS = {
	"Blessing of Might", "Blessing of Wisdom", "Blessing of Kings",
	"Blessing of Salvation", "Blessing of Light", "Blessing of Sanctuary",
	"Greater Blessing of Might", "Greater Blessing of Wisdom", "Greater Blessing of Kings",
	"Greater Blessing of Salvation", "Greater Blessing of Light", "Greater Blessing of Sanctuary",
}

FK.Data.classBuffs = {
	-- Group buffs
	{
		key = "fortitude", label = "Fortitude", class = "PRIEST", scope = "group", minLevel = 1,
		auras = { "Power Word: Fortitude", "Prayer of Fortitude" },
	},
	{
		key = "spirit", label = "Divine Spirit", class = "PRIEST", scope = "group",
		who = "mana", minLevel = 30, talent = true,
		auras = { "Divine Spirit", "Prayer of Spirit" },
	},
	{
		key = "shadowprot", label = "Shadow Protection", class = "PRIEST", scope = "group",
		minLevel = 30, optional = true,
		auras = { "Shadow Protection", "Prayer of Shadow Protection" },
	},
	{
		key = "intellect", label = "Arcane Intellect", class = "MAGE", scope = "group",
		who = "mana", minLevel = 1,
		auras = { "Arcane Intellect", "Arcane Brilliance" },
	},
	{
		key = "wild", label = "Mark of the Wild", class = "DRUID", scope = "group", minLevel = 1,
		auras = { "Mark of the Wild", "Gift of the Wild" },
	},
	{
		key = "blessing", label = "a Blessing", class = "PALADIN", scope = "blessing",
		minLevel = 4,
		auras = BLESSINGS,
	},
	{
		key = "battleshout", label = "Battle Shout", class = "WARRIOR", scope = "group",
		minLevel = 1,
		auras = { "Battle Shout" },
	},

	-- Self buffs: nobody else can give you these, so they are listed as your
	-- own to fix rather than something to ask a groupmate for.
	{
		key = "innerfire", label = "Inner Fire", class = "PRIEST", scope = "self",
		auras = { "Inner Fire" },
	},
	{
		key = "magearmor", label = "an armor spell", class = "MAGE", scope = "self",
		auras = { "Frost Armor", "Ice Armor", "Mage Armor", "Molten Armor" },
	},
	{
		key = "demonarmor", label = "Demon Skin", class = "WARLOCK", scope = "self",
		auras = { "Demon Skin", "Demon Armor", "Fel Armor" },
	},
	{
		key = "aura", label = "an aura", class = "PALADIN", scope = "self",
		auras = {
			"Devotion Aura", "Retribution Aura", "Concentration Aura", "Sanctity Aura",
			"Shadow Resistance Aura", "Frost Resistance Aura", "Fire Resistance Aura",
			"Crusader Aura",
		},
	},
	{
		key = "aspect", label = "an aspect", class = "HUNTER", scope = "self",
		auras = {
			"Aspect of the Hawk", "Aspect of the Monkey", "Aspect of the Cheetah",
			"Aspect of the Pack", "Aspect of the Wild", "Aspect of the Beast",
			"Aspect of the Viper",
		},
	},
	{
		key = "trueshot", label = "Trueshot Aura", class = "HUNTER", scope = "self",
		auras = { "Trueshot Aura" },
	},
	{
		key = "shield", label = "a shield", class = "SHAMAN", scope = "self",
		auras = { "Lightning Shield", "Water Shield" },
	},
	{
		key = "omen", label = "Omen of Clarity", class = "DRUID", scope = "self",
		auras = { "Omen of Clarity" },
	},
}

-- aura name -> the buff it satisfies, so a scan is one table lookup per aura
-- rather than a walk through every buff's name list.
local byAura, byKey = {}, {}
for _, buff in ipairs(FK.Data.classBuffs) do
	byKey[buff.key] = buff
	for _, aura in ipairs(buff.auras) do
		byAura[aura] = buff
	end
end

FK.Data.classBuffByAura = byAura
FK.Data.classBuffByKey = byKey

--- The buff an aura name satisfies, or nil if we do not track it.
function FK.Data.ClassBuffForAura(auraName)
	return byAura[auraName]
end

--- Buffs that stay off until the player asks for them, for `/fk buffs <key>`.
function FK.Data.OptionalBuffKeys()
	local keys = {}
	for _, buff in ipairs(FK.Data.classBuffs) do
		if buff.optional then
			table.insert(keys, buff.key)
		end
	end
	table.sort(keys)
	return keys
end
