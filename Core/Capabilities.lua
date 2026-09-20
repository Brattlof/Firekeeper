local _, FK = ...

-- Forever is a new client and Blizzard has published no addon API notes for it.
-- Rather than assume a call exists and break on login, every uncertain API is
-- probed once here. Each module then asks `FK.Capabilities.Has("addonComm")`
-- and degrades to something that still works.
--
-- `/fk caps` prints the result, which is also what we ask beta testers to paste
-- into a bug report. See docs/RESEARCH.md.
local Capabilities = FK.RegisterModule("Capabilities", {})
FK.Capabilities = Capabilities

local probes = {
	addonComm = function()
		return C_ChatInfo ~= nil
			and type(C_ChatInfo.SendAddonMessage) == "function"
			and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function"
			and Enum ~= nil and Enum.SendAddonMessageResult ~= nil
			and Enum.RegisterAddonMessagePrefixResult ~= nil
	end,
	professionsApi = function()
		return type(_G.GetProfessions) == "function"
			or (C_TradeSkillUI ~= nil and type(C_TradeSkillUI.GetAllProfessionTradeSkillLines) == "function")
	end,
	spellBookScan = function()
		return C_SpellBook ~= nil and type(C_SpellBook.GetSpellBookSkillLineInfo) == "function"
	end,
	unitAuras = function()
		return C_UnitAuras ~= nil and type(C_UnitAuras.GetAuraDataByIndex) == "function"
	end,
	-- The call existing is not the same as being allowed to make it: it is
	-- marked RequiresUnitAuraAccess with FailureMode = "Error", so this probe
	-- actually reads an aura rather than checking a type. See docs/RESEARCH.md,
	-- FK-10.
	auraRead = function()
		if C_UnitAuras == nil or type(C_UnitAuras.GetAuraDataByIndex) ~= "function" then
			return false
		end
		local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", 1, "HELPFUL")
		if not ok then
			return false
		end
		return not (type(_G.issecretvalue) == "function" and _G.issecretvalue(aura))
	end,
	groupRoster = function()
		return type(_G.GetNumGroupMembers) == "function" and type(_G.UnitClass) == "function"
	end,
	mapPosition = function()
		return C_Map ~= nil and type(C_Map.GetBestMapForUnit) == "function"
			and type(C_Map.GetPlayerMapPosition) == "function"
	end,
	-- Both are present at runtime on 1.60.1 but undeclared in the API
	-- documentation, which is why camp discovery treats them as optional.
	customChannel = function()
		-- Either join call will do: Discovery prefers JoinChannelByName and
		-- falls back. Requiring the one it does not prefer would switch camp
		-- discovery off over a call it never makes.
		return (type(_G.JoinChannelByName) == "function"
				or type(_G.JoinPermanentChannel) == "function")
			and type(_G.GetChannelName) == "function"
	end,
	-- The button hangs off the client's own Minimap frame. Present on
	-- 1.60.1.69913; probed because a frame is not an API contract.
	-- Camp object icons on the Place tab. Present on 1.60.1.69913; without it
	-- every object falls back to the addon's own flame, which is a worse panel
	-- rather than a broken one.
	-- Clicking an object on the Place tab uses the item, which only a secure
	-- action button can do. The template is defined in this build's XML, but
	-- that is not proof an addon can instantiate one, so this actually makes
	-- one. See docs/RESEARCH.md, FK-23.
	secureButtons = function()
		local ok, button = pcall(CreateFrame, "Button", nil, UIParent, "SecureActionButtonTemplate")
		if not ok or not button then
			return false
		end
		button:Hide()
		return type(button.SetAttribute) == "function"
	end,
	-- Whether the panel can tell you are empty-handed, rather than offering you
	-- an object you have none of.
	bagCounts = function()
		if C_Item == nil or type(C_Item.GetItemCount) ~= "function" then
			return false
		end
		local ok, count = pcall(C_Item.GetItemCount, 6948) -- Hearthstone
		return ok and type(count) == "number"
	end,
	itemIcons = function()
		return C_Item ~= nil and type(C_Item.GetItemIconByID) == "function"
	end,
	minimapFrame = function()
		return _G.Minimap ~= nil and type(_G.Minimap.GetCenter) == "function"
	end,
	userWaypoint = function()
		return C_Map ~= nil and type(C_Map.SetUserWaypoint) == "function"
	end,
	-- Outgoing addon chat is allowed realm by realm, so this is a question
	-- about the realm rather than about the client. See docs/RESEARCH.md, FK-11.
	addonCommOutgoing = function()
		if C_ChatInfo == nil or type(C_ChatInfo.AreOutgoingAddonChatMessagesRestricted) ~= "function" then
			return false
		end
		local ok, restricted = pcall(C_ChatInfo.AreOutgoingAddonChatMessagesRestricted)
		return ok and restricted == false
	end,
}

Capabilities.results = {}

function Capabilities:OnLoad()
	for name, probe in pairs(probes) do
		local ok, result = pcall(probe)
		self.results[name] = ok and result == true or false
	end
	FK.Debug("capability probe finished")
end

--- Probes again once the player is in the world, then writes the answers down.
--
-- Two reasons to repeat the work: an aura read and a look at the minimap frame
-- mean nothing at `ADDON_LOADED`, and the result is only useful to us if it
-- reaches the disk. `/fk caps` prints the same thing for the player.
function Capabilities:OnLogin()
	self:OnLoad()

	local build, interface = "?", "?"
	if type(GetBuildInfo) == "function" then
		local version, _, _, tocVersion = GetBuildInfo()
		build, interface = version or "?", tocVersion or "?"
	end

	local answers = {}
	for name in pairs(probes) do
		answers[name] = Capabilities.Has(name)
	end

	FK.Diag("addon", FK.version)
	FK.Diag("build", build)
	FK.Diag("interface", interface)
	FK.Diag("probes", answers)

	-- A probe that returns false says "no", but three different things make it
	-- say that: the call is missing, the call threw, or the answer really is no.
	-- For the one question where that difference matters, write down the raw
	-- answer as well. See docs/RESEARCH.md, FK-4.
	FK.Diag("outgoingRestricted", Capabilities.OutgoingRestrictionDetail())

	local limitations = Capabilities.Limitations()
	if #limitations > 0 then
		FK.Print("what this client will not let me do:")
		for _, line in ipairs(limitations) do
			FK.Print("|cff888888  %s|r", line)
		end
	end
end

--- What this client and realm will not let the addon do, in plain words.
--
-- Every line is driven by something actually observed this session rather than
-- by a build number, so a realm that allows more says less here, and the list
-- empties itself as Forever settles down. The addon's whole pitch is saying
-- what it does not know; this is the same idea pointed at the client.
function Capabilities.Limitations()
	local lines = {}

	if not FK.savedVariablesLoaded then
		table.insert(lines, "no saved settings came back from the client, so professions set with")
		table.insert(lines, "|cffffff00/fk prof|r, Legacy ranks and alt cooldowns start fresh this session.")
	end

	return lines
end

--- Exactly what the client says about sending addon messages, in words.
function Capabilities.OutgoingRestrictionDetail()
	if C_ChatInfo == nil then
		return "no C_ChatInfo"
	end
	if type(C_ChatInfo.AreOutgoingAddonChatMessagesRestricted) ~= "function" then
		return "no AreOutgoingAddonChatMessagesRestricted"
	end
	local ok, restricted = pcall(C_ChatInfo.AreOutgoingAddonChatMessagesRestricted)
	if not ok then
		return "call errored: " .. tostring(restricted)
	end
	return ("restricted=%s"):format(tostring(restricted))
end

function Capabilities.Has(name)
	return Capabilities.results[name] == true
end

function Capabilities.Report()
	local names = {}
	for name in pairs(probes) do
		table.insert(names, name)
	end
	table.sort(names)

	local build, interface = "?", "?"
	if type(GetBuildInfo) == "function" then
		local version, _, _, tocVersion = GetBuildInfo()
		build, interface = version or "?", tocVersion or "?"
	end

	local lines = { ("Firekeeper %s on client %s (interface %s)"):format(FK.version, build, interface) }
	for _, name in ipairs(names) do
		table.insert(lines, ("  %s: %s"):format(name, Capabilities.Has(name) and "|cff40ff40yes|r" or "|cffff4040no|r"))
	end
	for _, limitation in ipairs(Capabilities.Limitations()) do
		table.insert(lines, ("|cff888888%s|r"):format(limitation))
	end
	table.insert(lines, "|cff888888all of this is saved to disk on /reload, so you can attach the file|r")
	return lines
end
