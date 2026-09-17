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
	"C_Map",
	"C_SpellBook",
	"C_Timer",
	"C_TradeSkillUI",
	"C_UnitAuras",
	"DEFAULT_CHAT_FRAME",
	"GetBuildInfo",
	"GetNumGroupMembers",
	"GetProfessionInfo",
	"GetProfessions",
	"GetRealmName",
	"GetTime",
	"IsInGroup",
	"IsInGuild",
	"IsInRaid",
	"SendChatMessage",
	"UIParent",
	"UnitClass",
	"UnitExists",
	"UnitName",
	"time",
}

globals = {
	"FirekeeperDB",
	"FirekeeperCharDB",
	"SLASH_FIREKEEPER1",
	"SLASH_FIREKEEPER2",
	"SlashCmdList",
}
