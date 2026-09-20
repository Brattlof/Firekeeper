local _, FK = ...

-- Addon-to-addon messages. The protocol is deliberately tiny and human
-- readable; docs/PROTOCOL.md is the reference.
--
-- Whether ordinary addons may send these on Forever is unverified
-- (docs/RESEARCH.md, FK-4). If the API is missing or a send throws, the addon
-- keeps working with whatever the player can see for themselves.
local Comm = FK.RegisterModule("Comm", {})
FK.Comm = Comm

Comm.PREFIX = "FKPR1"
Comm.THROTTLE = 5 -- seconds between outgoing announcements

local lastSent = 0

local function channel()
	if IsInRaid and IsInRaid() then
		return "RAID"
	elseif IsInGroup and IsInGroup() then
		return "PARTY"
	elseif IsInGuild and IsInGuild() then
		return "GUILD"
	end
	return nil
end

--- The name of a value in an Enum table, for a log line a human can read.
-- `Enum.SendAddonMessageResult.Success` is 0, and "0" tells nobody anything.
local function enumName(enum, value)
	if type(enum) ~= "table" then
		return tostring(value)
	end
	for name, candidate in pairs(enum) do
		if candidate == value then
			return ("%s (%s)"):format(name, tostring(value))
		end
	end
	return tostring(value)
end

Comm.enumName = enumName

--- Did a send actually go out?
--
-- `Enum.SendAddonMessageResult.Success` is 0, and the declaration marks the
-- return as never nil. On this client it is nil anyway: CooldownCollaborator
-- reports "nil/0 == success" from the field, and comparing nil against 0 would
-- log every successful send as a failure. Treat both as sent and anything else
-- as the reason it was not. See docs/RESEARCH.md, FK-4.
function Comm.WasSent(result)
	if result == nil then
		return true
	end
	local success = Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success
	return result == (success or 0)
end

-- The first send of the session is the one worth writing down: it is the real
-- answer to FK-4, where a capability probe can only guess.
local recordedFirstSend = false

local function send(message)
	if not FK.Capabilities.Has("addonComm") then
		return false
	end
	local target = channel()
	if not target then
		if not recordedFirstSend then
			recordedFirstSend = true
			FK.Diag("firstSend", "not sent: in no group, guild or raid")
		end
		return false
	end
	-- A throw means the API is unusable here. Throttling, lockdown and the like come
	-- back as a result code instead, and only mean this one message did not go.
	local ok, result = pcall(C_ChatInfo.SendAddonMessage, Comm.PREFIX, message, target)

	if not recordedFirstSend then
		recordedFirstSend = true
		if ok then
			FK.Diag("firstSend", ("%s to %s"):format(enumName(Enum and Enum.SendAddonMessageResult, result), target))
		else
			FK.Diag("firstSend", "threw: " .. tostring(result))
		end
	end

	if not ok then
		FK.Debug("SendAddonMessage failed; falling back to local-only mode")
		FK.Capabilities.results.addonComm = false
		return false
	end
	if not Comm.WasSent(result) then
		FK.Debug("addon message not sent, result %s", enumName(Enum.SendAddonMessageResult, result))
		return false
	end
	return true
end

-- HELLO:version
-- OBJ:version|id,id,id|readyIn
-- CAMP:slots|objectId,objectId
local function encodeObjects(ids, readyIn)
	return ("OBJ:%s|%s|%d"):format(FK.version, table.concat(ids or {}, ","), math.floor(readyIn or 0))
end

local function decode(message)
	local kind, rest = message:match("^(%u+):(.*)$")
	return kind, rest
end

local function split(text, separator)
	local parts = {}
	for piece in tostring(text):gmatch("([^" .. separator .. "]+)") do
		table.insert(parts, piece)
	end
	return parts
end

--- Tells the group what this character can place and when.
function Comm:Announce(force)
	local now = GetTime and GetTime() or 0
	if not force and (now - lastSent) < Comm.THROTTLE then
		return
	end
	lastSent = now

	local ids = FK.Professions:PlaceableIds()
	local readyIn = FK.Cooldowns.ForCharacter(FK.Roster.SelfKey(), time and time() or 0)
	send(encodeObjects(ids, readyIn))
end

--- Shares the state of the fire in front of us, so latecomers see filled slots.
function Comm:AnnounceCamp(camp)
	local placedIds = {}
	for _, entry in ipairs(camp.placed or {}) do
		table.insert(placedIds, entry.objectId)
	end
	send(("CAMP:%d|%s"):format(camp.slots or FK.Plan.DEFAULT_SLOTS, table.concat(placedIds, ",")))
end

function Comm:OnMessage(message, sender)
	local kind, rest = decode(message)
	if not kind then
		return
	end

	if kind == "OBJ" then
		local version, ids, readyIn = rest:match("^([^|]*)|([^|]*)|(%-?%d+)$")
		if not version then
			return
		end
		FK.Roster:Upsert(sender, {
			objects = split(ids, ","),
			readyIn = tonumber(readyIn) or 0,
			addonVersion = version,
		})
		if FK.UI and FK.UI.Refresh then
			FK.UI:Refresh()
		end
	elseif kind == "CAMP" then
		local slots, placed = rest:match("^(%d+)|(.*)$")
		if slots then
			FK.Camp:Adopt(tonumber(slots), split(placed, ","), sender)
		end
	elseif kind == "HELLO" then
		self:Announce(true)
	end
end

function Comm:OnLogin()
	if not FK.Capabilities.Has("addonComm") then
		FK.Debug("addon messages unavailable; local-only mode")
		return
	end

	local ok, result = pcall(C_ChatInfo.RegisterAddonMessagePrefix, Comm.PREFIX)
	local registered = Enum.RegisterAddonMessagePrefixResult
	FK.Diag("prefixRegistered", ok and enumName(registered, result) or ("threw: " .. tostring(result)))
	if not ok or (result ~= registered.Success and result ~= registered.DuplicatePrefix) then
		FK.Debug("could not register the %s prefix, result %s; local-only mode", Comm.PREFIX, tostring(result))
		FK.Capabilities.results.addonComm = false
		return
	end

	FK.eventFrame:RegisterEvent("CHAT_MSG_ADDON")
	FK.eventFrame:HookScript("OnEvent", function(_, event, prefix, message, _, sender)
		if event == "CHAT_MSG_ADDON" and prefix == Comm.PREFIX then
			local name = Ambiguate and Ambiguate(sender, "none") or sender
			if name ~= FK.Roster.SelfKey() then
				Comm:OnMessage(message, name)
			end
		end
	end)

	send("HELLO:" .. FK.version)
end
