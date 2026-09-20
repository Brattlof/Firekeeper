local _, FK = ...

-- Finding a fire somebody else already lit, and telling people about yours.
--
-- Group and guild channels only reach people you already know, so this rides a
-- custom chat channel that anyone running Firekeeper joins. Three things about
-- that are not guaranteed on Forever, so each is probed and each has a
-- fallback (docs/RESEARCH.md, FK-11):
--
--   * `JoinPermanentChannel` is present at runtime but undeclared in the API
--     documentation, so it is called inside a pcall.
--   * `C_ChatInfo.AreOutgoingAddonChatMessagesRestricted` exists and its own
--     documentation says outgoing addon chat is allowed "on a realm-by-realm
--     basis". On a realm that says no, hosting quietly does nothing and the
--     list only ever holds camps you were told about some other way.
--   * The player's position is not readable indoors or in an instance, and a
--     camp with no coordinates is not worth announcing.
--
-- There are deliberately no map pins. A custom pin needs a canvas data
-- provider and templates this client has not been shown to have (FK-6), while
-- `C_Map.SetUserWaypoint` is one call and puts the camp in the game's own
-- waypoint arrow.
-- ponytail: a list plus the built-in waypoint. Draw real pins only if someone
-- confirms the map canvas templates exist on Forever.
local Discovery = FK.RegisterModule("Discovery", {})
FK.Discovery = Discovery

Discovery.CHANNEL = "FirekeeperCamps"
Discovery.HOST_INTERVAL = 90 -- seconds between unprompted host broadcasts
Discovery.SEEK_THROTTLE = 10 -- seconds between seeks, so one key cannot spam

Discovery.hosting = false
Discovery.channelIndex = nil

local lastSeek, lastHost = 0, 0

local function now()
	return GetTime and GetTime() or 0
end

local function outgoingAllowed()
	if not FK.Capabilities.Has("addonComm") then
		return false
	end
	if C_ChatInfo and type(C_ChatInfo.AreOutgoingAddonChatMessagesRestricted) == "function" then
		local ok, restricted = pcall(C_ChatInfo.AreOutgoingAddonChatMessagesRestricted)
		if ok and restricted then
			return false
		end
	end
	return true
end

--- The channel's index, joining it the first time we need it.
function Discovery:Channel()
	if self.channelIndex then
		return self.channelIndex
	end
	if not FK.Capabilities.Has("customChannel") then
		return nil
	end

	pcall(_G.JoinPermanentChannel, self.CHANNEL)
	local ok, index = pcall(_G.GetChannelName, self.CHANNEL)
	if ok and type(index) == "number" and index > 0 then
		self.channelIndex = index
		FK.Diag("campChannel", index)
		return index
	end
	FK.Diag("campChannel", "join failed")
	return nil
end

local function send(message)
	if not outgoingAllowed() then
		return false
	end
	local index = Discovery:Channel()
	if not index then
		return false
	end
	local ok = pcall(C_ChatInfo.SendAddonMessage, FK.Comm.PREFIX, message, "CHANNEL", index)
	if not ok then
		FK.Debug("channel send failed; camp discovery is off for this session")
	end
	return ok
end

--- Where the player is, or nil when the client will not say (indoors, in an
-- instance, or no map API at all).
function Discovery.Position()
	if not FK.Capabilities.Has("mapPosition") then
		return nil
	end

	local ok, uiMapID = pcall(C_Map.GetBestMapForUnit, "player")
	if not ok or type(uiMapID) ~= "number" then
		return nil
	end

	local gotPosition, position = pcall(C_Map.GetPlayerMapPosition, uiMapID, "player")
	if not gotPosition or not position then
		return nil
	end

	local gotXY, x, y = pcall(position.GetXY, position)
	if not gotXY or type(x) ~= "number" or type(y) ~= "number" then
		return nil
	end
	return { uiMapID = uiMapID, x = x, y = y }
end

--- What our fire looks like on the wire, or nil if there is nothing to say.
function Discovery:HostPayload()
	local position = Discovery.Position()
	if not position then
		return nil
	end

	local camp = FK.Camp
	local professions = {}
	for profession in pairs(FK.Professions.known or {}) do
		table.insert(professions, profession)
	end
	table.sort(professions)

	return FK.CampList.EncodeHost({
		uiMapID = position.uiMapID,
		x = position.x,
		y = position.y,
		free = math.max((camp.slots or 0) - #(camp.placed or {}), 0),
		slots = camp.slots or 0,
		professions = professions,
	})
end

--- Start telling people where this fire is.
function Discovery:StartHosting()
	if not Discovery.Position() then
		return false, "the game will not say where you are: step outside and try again"
	end
	self.hosting = true
	self:Broadcast(true)

	if C_Timer and C_Timer.NewTicker and not self.ticker then
		self.ticker = C_Timer.NewTicker(self.HOST_INTERVAL, function()
			if Discovery.hosting then
				Discovery:Broadcast()
			end
		end)
	end
	return true
end

function Discovery:StopHosting()
	self.hosting = false
	if self.ticker then
		self.ticker:Cancel()
		self.ticker = nil
	end
	send("PACK:")
end

function Discovery:Broadcast(force)
	if not self.hosting then
		return false
	end
	if not force and (now() - lastHost) < self.HOST_INTERVAL then
		return false
	end
	local payload = self:HostPayload()
	if not payload then
		return false
	end
	lastHost = now()
	return send(payload)
end

--- Ask who is sitting at a fire. Hosts answer with their own HOST message.
function Discovery:Seek()
	if (now() - lastSeek) < self.SEEK_THROTTLE then
		return false, "give it a moment"
	end
	lastSeek = now()

	local position = Discovery.Position()
	return send(("SEEK:%d"):format(position and position.uiMapID or 0))
end

function Discovery:OnMessage(kind, rest, sender)
	if kind == "HOST" then
		local camp = FK.CampList.DecodeHost(rest)
		if camp then
			FK.CampList.Upsert(sender, camp, now())
			if FK.UI and FK.UI.Refresh then
				FK.UI:Refresh()
			end
		end
	elseif kind == "SEEK" then
		-- Answer only if we are hosting: a seeker asking an empty field gets
		-- silence rather than a round of "not me" from everyone online.
		if self.hosting then
			self:Broadcast(true)
		end
	elseif kind == "PACK" then
		FK.CampList.Forget(sender)
		if FK.UI and FK.UI.Refresh then
			FK.UI:Refresh()
		end
	elseif kind == "POS" then
		local mapID, x, y = tostring(rest):match("^(%d+)|(%d+)|(%d+)$")
		if mapID then
			FK.Nearby.Upsert(sender, {
				uiMapID = tonumber(mapID),
				x = tonumber(x) / 10000,
				y = tonumber(y) / 10000,
			}, now())
		end
	elseif kind == "GONE" then
		FK.Nearby.Forget(sender)
	end
end

--- Puts the game's own waypoint arrow on a camp.
function Discovery.Waypoint(camp)
	if not camp or not FK.Capabilities.Has("userWaypoint") then
		return false
	end
	-- UiMapPoint.CreateFromCoordinates is not present on this client, so the
	-- point is built by hand in the shape SetUserWaypoint reads.
	local ok, wasSet = pcall(C_Map.SetUserWaypoint, {
		uiMapID = camp.uiMapID,
		position = { x = camp.x, y = camp.y },
	})
	-- FK-12: whether a hand-built point is accepted, given UiMapPoint is absent.
	FK.Diag("waypoint", ok and tostring(wasSet) or "error")
	return ok and wasSet == true
end

--- Camps we have heard about lately, nearest first.
function Discovery.Found()
	return FK.CampList.Active(now(), Discovery.Position())
end

-- Guildies -----------------------------------------------------------------
--
-- The same trick as hosting, over the guild channel instead of the open one:
-- the game will not say where anyone else is, so everyone who opts in says
-- where they are. Sharing is off until the player turns it on, because a
-- position is the one genuinely personal thing this addon could broadcast.

Discovery.SHARE_INTERVAL = 30

local function sendGuild(message)
	if not outgoingAllowed() then
		return false
	end
	if not (IsInGuild and IsInGuild()) then
		return false
	end
	return (pcall(C_ChatInfo.SendAddonMessage, FK.Comm.PREFIX, message, "GUILD"))
end

--- The width and height of the player's map in yards, which is the only way
-- a map fraction becomes a distance worth printing.
function Discovery.WorldSize(uiMapID)
	if not uiMapID or not C_Map or type(C_Map.GetMapWorldSize) ~= "function" then
		return nil
	end
	local ok, width, height = pcall(C_Map.GetMapWorldSize, uiMapID)
	if not ok or type(width) ~= "number" or type(height) ~= "number" then
		return nil
	end
	return { width = width, height = height }
end

function Discovery.ZoneName(uiMapID)
	if not uiMapID or not C_Map or type(C_Map.GetMapInfo) ~= "function" then
		return nil
	end
	local ok, info = pcall(C_Map.GetMapInfo, uiMapID)
	return ok and type(info) == "table" and info.name or nil
end

function Discovery:SharePosition()
	if not (FK.db and FK.db.shareWithGuild) then
		return false
	end
	local position = Discovery.Position()
	if not position then
		return false -- indoors or in an instance: say nothing rather than a stale spot
	end
	return sendGuild(("POS:%d|%d|%d"):format(
		position.uiMapID,
		math.floor(position.x * 10000 + 0.5),
		math.floor(position.y * 10000 + 0.5)))
end

function Discovery:SetSharing(enabled)
	FK.db.shareWithGuild = enabled and true or false

	if self.shareTicker then
		self.shareTicker:Cancel()
		self.shareTicker = nil
	end

	if not FK.db.shareWithGuild then
		sendGuild("GONE:")
		return false
	end

	self:SharePosition()
	if C_Timer and C_Timer.NewTicker then
		self.shareTicker = C_Timer.NewTicker(self.SHARE_INTERVAL, function()
			Discovery:SharePosition()
		end)
	end
	return true
end

--- Guildies running Firekeeper who are sharing, nearest first.
function Discovery.Guildies()
	local from = Discovery.Position()
	return FK.Nearby.Active(now(), from, from and Discovery.WorldSize(from.uiMapID) or nil)
end

function Discovery:OnLogin()
	if not FK.Capabilities.Has("addonComm") then
		return
	end

	FK.eventFrame:RegisterEvent("CHAT_MSG_ADDON")
	FK.eventFrame:HookScript("OnEvent", function(_, event, prefix, message, _, sender)
		if event ~= "CHAT_MSG_ADDON" or prefix ~= FK.Comm.PREFIX then
			return
		end
		local kind, rest = tostring(message):match("^(%u+):(.*)$")
		if kind ~= "HOST" and kind ~= "SEEK" and kind ~= "PACK"
			and kind ~= "POS" and kind ~= "GONE" then
			return
		end
		local name = Ambiguate and Ambiguate(sender, "none") or sender
		if name ~= FK.Roster.SelfKey() then
			Discovery:OnMessage(kind, rest, name)
		end
	end)

	-- Joining takes a moment after login, and there is no point holding up the
	-- rest of the addon for it.
	if C_Timer and C_Timer.After then
		C_Timer.After(10, function()
			Discovery:Channel()
		end)
	end

	-- Sharing survives a reload, so somebody who turned it on does not have to
	-- turn it on again every time.
	if FK.db and FK.db.shareWithGuild then
		Discovery:SetSharing(true)
	end
end
