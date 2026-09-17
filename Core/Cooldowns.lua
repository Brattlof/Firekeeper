local _, FK = ...

-- Objects contributed to a campsite share a one-hour cooldown per player, and
-- the Legacy perk Field Guide shortens it. The maths lives here, away from the
-- game API, so tests can move the clock around freely.
local Cooldowns = {}
FK.Cooldowns = Cooldowns

Cooldowns.BASE_SECONDS = 60 * 60
Cooldowns.FIELD_GUIDE_PER_RANK = 0.08 -- rank 1 was shown at 8%

--- How long the shared cooldown lasts for a player with this Legacy setup.
function Cooldowns.Duration(legacy)
	local ranks = legacy and legacy.fieldGuide or 0
	local reduction = math.min(ranks * Cooldowns.FIELD_GUIDE_PER_RANK, 0.9)
	return math.floor(Cooldowns.BASE_SECONDS * (1 - reduction) + 0.5)
end

--- Seconds left before `lastPlaced` is off cooldown, or 0 when it is ready.
function Cooldowns.Remaining(lastPlaced, now, legacy)
	if not lastPlaced then
		return 0
	end
	local elapsed = (now or 0) - lastPlaced
	return math.max(Cooldowns.Duration(legacy) - elapsed, 0)
end

function Cooldowns.IsReady(lastPlaced, now, legacy)
	return Cooldowns.Remaining(lastPlaced, now, legacy) <= 0
end

--- "42m", "9m 05s", "ready"
function Cooldowns.Format(seconds)
	if not seconds or seconds <= 0 then
		return "ready"
	elseif seconds >= 600 then
		return ("%dm"):format(math.ceil(seconds / 60))
	elseif seconds >= 60 then
		return ("%dm %02ds"):format(math.floor(seconds / 60), seconds % 60)
	end
	return ("%ds"):format(math.floor(seconds))
end

--- Records that a character contributed an object, for the roster and for
-- "which of my alts still has a camp object up".
function Cooldowns.RecordPlacement(characterKey, objectId, now)
	if not FK.db then
		return
	end
	FK.db.characters[characterKey] = FK.db.characters[characterKey] or {}
	local record = FK.db.characters[characterKey]
	record.lastPlaced = now
	record.lastObject = objectId
	return record
end

function Cooldowns.ForCharacter(characterKey, now)
	local record = FK.db and FK.db.characters[characterKey]
	if not record then
		return 0
	end
	return Cooldowns.Remaining(record.lastPlaced, now, FK.db.legacy)
end
