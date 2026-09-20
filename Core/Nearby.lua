local _, FK = ...

-- Where the guildies who run Firekeeper are standing.
--
-- The game tells an addon where *you* are and nobody else, so this is built
-- the only way it can be: everyone who opts in says where they are, and the
-- list is assembled from that. Sharing is off until the player turns it on.
--
-- Pure Lua, so the compass and the yardage can be tested without a client.
-- The sending and receiving live in Core/Discovery.lua.
local Nearby = {}
FK.Nearby = Nearby

-- A position this old is not worth showing: the player has moved on, or
-- logged out without the addon noticing.
Nearby.EXPIRY = 5 * 60

Nearby.entries = {} -- player name -> { uiMapID, x, y, heardAt }

function Nearby.Upsert(name, position, now)
	if not name or not position then
		return nil
	end
	position.heardAt = now or 0
	Nearby.entries[name] = position
	return position
end

function Nearby.Forget(name)
	Nearby.entries[name] = nil
end

function Nearby.Clear()
	Nearby.entries = {}
end

local COMPASS = {
	"north", "north-east", "east", "south-east",
	"south", "south-west", "west", "north-west",
}

--- Which way to walk, as a compass point.
--
-- Map coordinates run x east and y *south*, so north is a falling y. The
-- bearing is measured clockwise from north and then dropped into one of eight
-- buckets, each 45 degrees wide and centred on its name.
function Nearby.Direction(from, to)
	if not from or not to then
		return nil
	end
	local dx = (to.x or 0) - (from.x or 0)
	local dy = (to.y or 0) - (from.y or 0)
	if dx == 0 and dy == 0 then
		return "right here"
	end

	local bearing = math.deg(math.atan2(dx, -dy)) % 360
	local index = math.floor((bearing + 22.5) / 45) % 8
	return COMPASS[index + 1]
end

--- How far apart two points on the same map are, in yards.
--
-- `worldSize` is { width, height } from C_Map.GetMapWorldSize, which is the
-- only thing that turns a map fraction into a distance anyone can act on.
-- Without it there is no honest number, so this returns nil rather than a
-- made-up one.
function Nearby.Yards(from, to, worldSize)
	if not from or not to or not worldSize then
		return nil
	end
	local width, height = worldSize.width, worldSize.height
	if not width or not height or width <= 0 or height <= 0 then
		return nil
	end
	local dx = ((to.x or 0) - (from.x or 0)) * width
	local dy = ((to.y or 0) - (from.y or 0)) * height
	return math.sqrt(dx * dx + dy * dy)
end

--- Guildies we have heard from lately, nearest first.
--
-- `from` may be nil when the client will not say where we are, which happens
-- indoors and in instances; everyone is then listed without a distance rather
-- than dropped.
function Nearby.Active(now, from, worldSize)
	now = now or 0
	local active = {}

	for name, position in pairs(Nearby.entries) do
		if (now - (position.heardAt or 0)) <= Nearby.EXPIRY then
			local sameMap = from ~= nil and from.uiMapID == position.uiMapID
			table.insert(active, {
				name = name,
				uiMapID = position.uiMapID,
				x = position.x,
				y = position.y,
				heardAt = position.heardAt,
				sameMap = sameMap,
				yards = sameMap and Nearby.Yards(from, position, worldSize) or nil,
				direction = sameMap and Nearby.Direction(from, position) or nil,
			})
		end
	end

	table.sort(active, function(a, b)
		if a.sameMap ~= b.sameMap then
			return a.sameMap
		end
		if a.yards and b.yards and a.yards ~= b.yards then
			return a.yards < b.yards
		end
		return a.name < b.name
	end)

	return active
end

function Nearby.Prune(now)
	for name, position in pairs(Nearby.entries) do
		if ((now or 0) - (position.heardAt or 0)) > Nearby.EXPIRY then
			Nearby.entries[name] = nil
		end
	end
end

--- "Ana — 140 yards north-east" / "Bo — Ashenvale"
function Nearby.Line(entry, zoneName)
	if not entry.sameMap then
		return ("%s — %s"):format(entry.name, zoneName or "somewhere else")
	end
	if not entry.yards then
		return ("%s — %s of here"):format(entry.name, entry.direction or "nearby")
	end
	return ("%s — %d yards %s"):format(entry.name, math.floor(entry.yards + 0.5), entry.direction)
end

return Nearby
