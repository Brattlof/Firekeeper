local _, FK = ...

-- Making a list of object ids fit in an addon message.
--
-- An addon message payload is at most 255 bytes, and the client answers
-- `InvalidMessage` for anything longer rather than truncating it. A character
-- with two maxed primaries plus Cooking, First Aid and Fishing has seventeen
-- placeable objects, which is 257 bytes before the version and cooldown fields
-- are even counted, and all twelve professions is 543. So the list that goes on
-- the wire has to be shortened deliberately, and the player never sees it fail.
--
-- Pure Lua, so the arithmetic is tested rather than hoped for.
local Wire = {}
FK.Wire = Wire

Wire.MAX_PAYLOAD = 255

--- Drops any id that another id in the list already carries the benefits of.
--
-- This costs the planner nothing. If a character can place a Master Forge, then
-- saying they can also place a Sharpening Wheel adds no option worth planning:
-- the forge provides the wheel's buff and a workspace besides. It is the
-- cheapest possible saving, because nothing is lost.
function Wire.DropSuperseded(ids)
	local present = {}
	for _, id in ipairs(ids or {}) do
		present[id] = true
	end

	local covered = {}
	for _, id in ipairs(ids or {}) do
		local object = FK.Data.GetObject(id)
		while object and object.supersedes do
			-- Only drop the lower tier when the thing superseding it is also
			-- on offer.
			if present[id] then
				covered[object.supersedes] = true
			end
			object = FK.Data.GetObject(object.supersedes)
		end
	end

	local kept = {}
	for _, id in ipairs(ids or {}) do
		if not covered[id] then
			table.insert(kept, id)
		end
	end
	return kept
end

--- How much a list of ids costs as a comma-joined string.
function Wire.Size(ids)
	local size = 0
	for index, id in ipairs(ids or {}) do
		size = size + #id + (index > 1 and 1 or 0)
	end
	return size
end

--- The longest prefix of `ids` that fits in `budget` bytes once joined.
--
-- `ids` arrives in the order the caller considers most useful first, so
-- trimming from the end drops the least useful. Returns the kept list and how
-- many were dropped, because a caller that quietly says less than it knows
-- should at least be able to say so.
function Wire.Fit(ids, budget)
	local kept, size, dropped = {}, 0, 0
	for _, id in ipairs(ids or {}) do
		local cost = #id + (#kept > 0 and 1 or 0)
		if size + cost <= (budget or Wire.MAX_PAYLOAD) then
			table.insert(kept, id)
			size = size + cost
		else
			dropped = dropped + 1
		end
	end
	return kept, dropped
end

--- Both steps at once: drop what is redundant, then trim what will not fit.
-- `overhead` is the size of everything in the message that is not the id list.
function Wire.PackIds(ids, overhead)
	local budget = Wire.MAX_PAYLOAD - (overhead or 0)
	if budget < 0 then
		budget = 0
	end
	return Wire.Fit(Wire.DropSuperseded(ids), budget)
end

return Wire
