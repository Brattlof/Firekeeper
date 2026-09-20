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
--   * Sending may simply not work. We do not ask permission first: the result
--     code of a real send is the only trustworthy answer, and a send that does
--     not go out costs nothing but a debug line.
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

-- Deliberately *not* consulted here: `AreOutgoingAddonChatMessagesRestricted`.
-- It answers true on this client far more often than anything is actually
-- blocked — CooldownCollaborator hit the same thing and stopped trusting it —
-- and gating on it silently killed every send. The result code of a real
-- attempt is the authority. See docs/RESEARCH.md, FK-4.
local function outgoingAllowed()
	return FK.Capabilities.Has("addonComm")
end

--- The channel's index, joining it the first time we need it.
--
-- Only ever call this from something the player did. Joining a channel is one
-- of the actions the client will refuse to a timer or an event handler — it
-- answers "blocked from an action only available to the Blizzard UI" — so the
-- join hangs off `/fk find` and `/fk host` rather than off login
-- (docs/RESEARCH.md, FK-19).
--
-- `JoinChannelByName` is preferred over `JoinPermanentChannel`: the permanent
-- one is written into the player's chat settings and can take the /1 slot,
-- which is not ours to spend.
function Discovery:Channel(fromUserAction)
	if self.channelIndex then
		return self.channelIndex
	end
	if not FK.Capabilities.Has("customChannel") then
		return nil
	end

	-- Everything that sends goes through here, including the host ticker and the
	-- reply to a SEEK, so the guard has to be here rather than at the call the
	-- player typed. Without it one failed join meant the next ticker tried again
	-- from a C_Timer callback, which is exactly what this is supposed to avoid.
	if not fromUserAction then
		return nil
	end
	if self.joinFailed then
		return nil -- do not hammer a join that already came back empty
	end

	if type(_G.JoinChannelByName) == "function" then
		pcall(_G.JoinChannelByName, self.CHANNEL)
	else
		pcall(_G.JoinPermanentChannel, self.CHANNEL)
	end

	local ok, index = pcall(_G.GetChannelName, self.CHANNEL)
	if ok and type(index) == "number" and index > 0 then
		self.channelIndex = index
		FK.Diag("campChannel", index)
		return index
	end
	self.joinFailed = true
	FK.Diag("campChannel", "join failed")
	return nil
end

--- Forgets the channel, so the next thing the player types joins again.
-- Called when a send is refused with a channel error: the index is cached and
-- the player may have left the channel or had it renumbered underneath us.
function Discovery:ForgetChannel()
	self.channelIndex = nil
	self.joinFailed = false
end

--- Sends on the camp channel.
--
-- `fromTimer` marks a send the player did not ask for directly. Those are the
-- ones at risk of being refused, and the first one is written down so we find
-- out rather than guess (docs/RESEARCH.md, FK-19).
local recordedTimerSend = false

local function send(message, fromTimer)
	if not outgoingAllowed() then
		return false
	end
	local index = Discovery:Channel(not fromTimer)
	if not index then
		if fromTimer and not recordedTimerSend then
			recordedTimerSend = true
			FK.Diag("timerSend", "no channel to send on")
		end
		return false
	end
	local ok, result = pcall(C_ChatInfo.SendAddonMessage, FK.Comm.PREFIX, message, "CHANNEL", index)

	if fromTimer and not recordedTimerSend then
		recordedTimerSend = true
		FK.Diag("timerSend", ok and FK.Comm.enumName(Enum and Enum.SendAddonMessageResult, result)
			or ("threw: " .. tostring(result)))
	end

	if not ok then
		FK.Debug("channel send threw; camp discovery is off for this session")
		return false
	end
	if not FK.Comm.WasSent(result) then
		FK.Debug("channel message not sent, result %s",
			FK.Comm.enumName(Enum and Enum.SendAddonMessageResult, result))
		local invalid = Enum and Enum.SendAddonMessageResult
			and Enum.SendAddonMessageResult.InvalidChannel
		if invalid and result == invalid then
			Discovery:ForgetChannel()
		end
		return false
	end
	return true
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

--- Which layer of a layered realm we are standing on, and the kind of unit it
-- came from, or nil.
--
-- A player's own GUID does not carry the layer, so it has to be read off some
-- non-player unit nearby. Nothing here is guaranteed: `UnitGUID` is marked
-- `SecretWhenUnitIdentityRestricted`, and a secret value cannot be split or
-- compared, so it is tested and dropped rather than parsed
-- (docs/RESEARCH.md, FK-15). With no creature in sight there is no answer, and
-- a camp without a layer is shared anyway — a missing layer is worth less than
-- a wrong one.
function Discovery.Layer()
	local units = { "target", "mouseover", "softinteract", "softenemy", "softfriend" }
	for index = 1, 40 do
		table.insert(units, "nameplate" .. index)
	end

	for _, unit in ipairs(units) do
		if UnitExists and UnitExists(unit)
			and not (UnitIsPlayer and UnitIsPlayer(unit))
			and not (UnitPlayerControlled and UnitPlayerControlled(unit)) then
			local ok, guid = pcall(UnitGUID, unit)
			if ok and not FK.IsSecret(guid) then
				local layer = FK.CampList.LayerFromGuid(guid)
				if layer then
					return layer, tostring(guid):match("^([^-]+)")
				end
			end
		end
	end
	return nil
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
		layer = Discovery.Layer(),
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
	local announced = self:Broadcast(true)

	if C_Timer and C_Timer.NewTicker and not self.ticker then
		-- A shade under the throttle window: a tick landing a hair early used to
		-- be dropped, pushing the next announce out to 180 seconds.
		self.ticker = C_Timer.NewTicker(self.HOST_INTERVAL + 1, function()
			if Discovery.hosting then
				Discovery:Broadcast(false, true)
			end
		end)
	end

	if not announced then
		return false, "could not announce this fire: nothing was sent"
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

function Discovery:Broadcast(force, fromTimer)
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
	return send(payload, fromTimer)
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
		-- Answer only if we are hosting, and only if the seeker is asking about
		-- the map we are on. The map id was being parsed nowhere, so every host
		-- on the realm answered every `/fk find` on the realm — an N times M
		-- storm that throttled away the answers that mattered.
		local wanted = tonumber(tostring(rest):match("^(%d+)"))
		local position = Discovery.Position()
		local sameMap = wanted == nil or position == nil or wanted == 0
			or wanted == position.uiMapID

		-- This reply comes from an event handler rather than from anything the
		-- player did, so it is in the same boat as the ticker (FK-19).
		if self.hosting and sameMap then
			self:Broadcast(true, true)
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

--- Camps we have heard about lately, nearest first, with our own layer
-- attached so the panel can say which of them you could actually walk to.
function Discovery.Found()
	local layer, fromUnit = Discovery.Layer()
	FK.Diag("layer", layer or "not readable")
	FK.Diag("layerFromUnitType", fromUnit or "none")

	local found = FK.CampList.Active(now(), Discovery.Position())
	for _, camp in ipairs(found) do
		-- Three conditions, and all of them matter:
		--
		--   both ends know their own number — unknown is not elsewhere;
		--   the numbers differ;
		--   and the camp is on the same map as us.
		--
		-- That last one is the subtle one. The number is a GUID's zoneUID, which
		-- varies by zone as well as by shard, so our number in one zone and a
		-- host's in another would differ even on the same shard. Comparing them
		-- across maps would invent an obstacle that is not there
		-- (docs/RESEARCH.md, FK-15).
		camp.otherLayer = (camp.sameMap
			and layer ~= nil
			and camp.layer ~= nil
			and camp.layer ~= layer) or false
	end
	return found
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
	-- Same caveat as the camp channel: this runs on a ticker, not on anything
	-- the player did (docs/RESEARCH.md, FK-19).
	local ok, result = pcall(C_ChatInfo.SendAddonMessage, FK.Comm.PREFIX, message, "GUILD")
	if not ok then
		return false
	end
	if not FK.Comm.WasSent(result) then
		FK.Debug("guild message not sent, result %s",
			FK.Comm.enumName(Enum and Enum.SendAddonMessageResult, result))
		return false
	end
	return true
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

	-- Deliberately not joining the channel here. See Discovery:Channel.

	-- Restored if the client ever hands saved variables back. On this build it
	-- never does (docs/RESEARCH.md, FK-9), so sharing starts off every session —
	-- which is the safe direction for a setting that broadcasts your position.
	if FK.db and FK.db.shareWithGuild then
		Discovery:SetSharing(true)
	end
end
