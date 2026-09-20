local _, FK = ...

-- Camps other people are sitting at: the wire format, and the list of what we
-- have heard about lately.
--
-- Pure Lua like Core/Plan.lua, so the expiry rules and the parser can be tested
-- without a client. Joining a channel and actually sending any of this is
-- Core/Discovery.lua's job.
local CampList = {}
FK.CampList = CampList

-- A camp nobody has mentioned for this long is assumed packed up. Twenty
-- minutes is long enough to walk across a zone and short enough that the list
-- is not full of ghosts.
CampList.EXPIRY = 20 * 60

-- Map coordinates are 0..1 floats. On the wire they are whole basis points,
-- which is three bytes instead of eighteen and still lands within a few yards.
local function toWire(coordinate)
	return math.floor((tonumber(coordinate) or 0) * 10000 + 0.5)
end

local function fromWire(value)
	return (tonumber(value) or 0) / 10000
end

--- HOST:<uiMapID>|<x>|<y>|<free>|<slots>|<professions>
function CampList.EncodeHost(camp)
	return ("HOST:%d|%d|%d|%d|%d|%s"):format(
		tonumber(camp.uiMapID) or 0,
		toWire(camp.x),
		toWire(camp.y),
		math.max(tonumber(camp.free) or 0, 0),
		math.max(tonumber(camp.slots) or 0, 0),
		table.concat(camp.professions or {}, ","))
end

--- Turns a HOST payload back into a camp, or nil if it is malformed.
function CampList.DecodeHost(rest)
	local mapID, x, y, free, slots, professions =
		tostring(rest or ""):match("^(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|(.*)$")
	if not mapID then
		return nil
	end

	local list = {}
	for profession in tostring(professions):gmatch("([^,]+)") do
		table.insert(list, profession)
	end

	return {
		uiMapID = tonumber(mapID),
		x = fromWire(x),
		y = fromWire(y),
		free = tonumber(free),
		slots = tonumber(slots),
		professions = list,
	}
end

CampList.entries = {} -- host name -> camp

--- Records what a host just told us. One camp per host: a player can only sit
-- at one fire, so a new message replaces their old one rather than piling up.
function CampList.Upsert(host, camp, now)
	if not host or not camp then
		return nil
	end
	camp.host = host
	camp.heardAt = now or 0
	CampList.entries[host] = camp
	return camp
end

function CampList.Forget(host)
	CampList.entries[host] = nil
end

function CampList.Clear()
	CampList.entries = {}
end

-- Rough distance between two points on the same map. Map coordinates are not
-- square, so this is only good for ordering a list, never for a yardage.
-- ponytail: fine for "which fire is closest"; if a real distance is ever
-- needed, scale by the map's width and height from C_Map.GetMapRectOnMap.
local function roughDistance(a, b)
	local dx, dy = (a.x or 0) - (b.x or 0), (a.y or 0) - (b.y or 0)
	return math.sqrt(dx * dx + dy * dy)
end

--- Camps we have heard from recently, nearest first.
--
-- `from` is { uiMapID = 1440, x = 0.42, y = 0.61 }, and may be nil when the
-- client will not say where we are; the list is then ordered by how recently
-- we heard about each camp.
function CampList.Active(now, from)
	now = now or 0
	local active = {}

	for host, camp in pairs(CampList.entries) do
		if (now - (camp.heardAt or 0)) <= CampList.EXPIRY then
			local entry = camp
			entry.host = host
			entry.sameMap = from ~= nil and from.uiMapID == camp.uiMapID
			entry.distance = entry.sameMap and roughDistance(from, camp) or nil
			table.insert(active, entry)
		end
	end

	table.sort(active, function(a, b)
		-- A fire on your own map beats one you would have to fly to, then the
		-- nearer of two, then the one we heard about most recently.
		if a.sameMap ~= b.sameMap then
			return a.sameMap
		end
		if a.distance and b.distance and a.distance ~= b.distance then
			return a.distance < b.distance
		end
		if a.heardAt ~= b.heardAt then
			return a.heardAt > b.heardAt
		end
		return a.host < b.host
	end)

	return active
end

--- Drops camps nobody has mentioned in a while, so the table cannot grow
-- without bound on a long session.
function CampList.Prune(now)
	for host, camp in pairs(CampList.entries) do
		if ((now or 0) - (camp.heardAt or 0)) > CampList.EXPIRY then
			CampList.entries[host] = nil
		end
	end
end

return CampList
