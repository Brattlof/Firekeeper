std = "lua51"
max_line_length = false
codes = true
self = false

exclude_files = {
	"tests",
}

-- The WoW API. Forever ships the modern (mainline) UI on a vanilla game, so
-- both the C_* namespaces and the old global functions are in play. Anything
-- here that turns out to be missing on Forever gets a probe in
-- Core/Capabilities.lua rather than a crash on login.
read_globals = {
	"Ambiguate",
	"CreateFrame",
	"C_AddOns",
	"C_ChatInfo",
	"C_EventUtils",
	"C_Item",
	"C_Map",
	"C_SpellBook",
	"C_Timer",
	"C_TradeSkillUI",
	"C_UnitAuras",
	"DEFAULT_CHAT_FRAME",
	"Enum",
	"GetBuildInfo",
	"GetChannelName",
	"GetCursorPosition",
	"GetNumGroupMembers",
	"GetProfessionInfo",
	"GetProfessions",
	"GetRealmName",
	"GetTime",
	"InCombatLockdown",
	"IsInGroup",
	"IsInGuild",
	"GameTooltip",
	"IsInRaid",
	"JoinChannelByName",
	"JoinPermanentChannel",
	"Minimap",
	"SendChatMessage",
	"UIParent",
	"UnitClass",
	"UnitExists",
	"UnitFactionGroup",
	"UnitGUID",
	"UnitIsPlayer",
	"UnitLevel",
	"UnitPlayerControlled",
	"UnitName",
	"issecretvalue",
	"time",
}

globals = {
	"FirekeeperDB",
	"FirekeeperCharDB",
	"SLASH_FIREKEEPER1",
	"SLASH_FIREKEEPER2",
	"SlashCmdList",
}
