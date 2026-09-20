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

--- The layer (shard) a unit's GUID was seen on, or nil.
--
-- A layered realm can put two players at the same coordinates without them
-- ever seeing each other, so a camp's position alone can send somebody to an
-- empty patch of grass. The layer is the fifth field of a non-player GUID —
-- `Creature-0-<server>-<instance>-<zoneUID>-<id>-<spawn>` — and a player's own
-- GUID does not carry it, which is why it has to come off a creature or an
-- object standing nearby.
--
-- Pure string work, so it is tested. Finding a unit to ask is Discovery's job,
-- and so is refusing to pass a secret value in here (docs/RESEARCH.md, FK-15).
function CampList.LayerFromGuid(guid)
	if type(guid) ~= "string" or guid == "" then
		return nil
	end
	-- Split by hand rather than with strsplit: this file has to run under plain
	-- lua5.1 in tests/, where WoW's string globals do not exist.
	local fields = {}
	for field in guid:gmatch("[^-]+") do
		table.insert(fields, field)
	end

	local unitType = fields[1]
	if unitType ~= "Creature" and unitType ~= "Vehicle" and unitType ~= "GameObject" then
		return nil
	end
	local layer = tonumber(fields[5])
	if layer and layer > 0 then
		return layer
	end
	return nil
end

--- HOST:<uiMapID>|<x>|<y>|<free>|<slots>|<layer>|<professions>
function CampList.EncodeHost(camp)
	return ("HOST:%d|%d|%d|%d|%d|%d|%s"):format(
		tonumber(camp.uiMapID) or 0,
		toWire(camp.x),
		toWire(camp.y),
		math.max(tonumber(camp.free) or 0, 0),
		math.max(tonumber(camp.slots) or 0, 0),
		math.max(tonumber(camp.layer) or 0, 0),
		table.concat(camp.professions or {}, ","))
end

--- Turns a HOST payload back into a camp, or nil if it is malformed.
--
-- Reads the layer field when it is there and does without it when it is not,
-- so a client from before the field existed is understood rather than dropped.
function CampList.DecodeHost(rest)
	rest = tostring(rest or "")

	local mapID, x, y, free, slots, layer, professions =
		rest:match("^(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|(.*)$")
	if not mapID then
		mapID, x, y, free, slots, professions =
			rest:match("^(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|(.*)$")
		layer = nil
	end
	if not mapID then
		return nil
	end

	local list = {}
	for profession in tostring(professions):gmatch("([^,]+)") do
		table.insert(list, profession)
	end

	local layerNumber = tonumber(layer)
	return {
		uiMapID = tonumber(mapID),
		x = fromWire(x),
		y = fromWire(y),
		free = tonumber(free),
		slots = tonumber(slots),
		layer = layerNumber and layerNumber > 0 and layerNumber or nil,
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
