local _, FK = ...

-- Noticing what you put on the fire, instead of being told.
--
-- Every camp object is an item that casts a ten second spell, and the client
-- announces a finished cast with the spell's id. So the addon can watch for
-- one of the thirty-eight placement spells and record it — no "I placed this"
-- button, no `/fk place`, and no chance of the record disagreeing with the
-- fire because the player forgot to press something.
--
-- Two things it also settles for free:
--
--   * A campfire kit is a placement too, and it is the one that means "this is
--     a new fire". Casting one starts a fresh camp at that capacity.
--   * Placing anything at all means you are at a camp, which is how the addon
--     stops needing to be told that as well.
--
-- `UNIT_SPELLCAST_SUCCEEDED` is declared on this build and carries `spellID`.
-- It is marked `SecretWhenUnitSpellCastRestricted`, so the id is tested before
-- it is compared (docs/RESEARCH.md, FK-22).
local Placement = FK.RegisterModule("Placement", {})
FK.Placement = Placement

--- A camp you have not touched for this long is assumed to be a different one.
-- Camp buffs last an hour, so an hour is the natural window.
Placement.CAMP_LIFETIME = 60 * 60

--- Handles a finished cast: was it a camp object, and what does that mean?
--
-- Split out from the event handler so it can be tested without a client.
function Placement.OnCastSucceeded(spellId, now)
	if FK.IsSecret and FK.IsSecret(spellId) then
		return nil
	end

	local object = FK.Data.ObjectForSpell(spellId)
	if not object then
		return nil
	end

	local camp = FK.Camp
	local isCampfire = object.effect and object.effect.kind == "slots"
	local fresh = isCampfire

	-- A campfire is a new fire. So is placing something more than an hour after
	-- anything last went on this one, since that is how long camp buffs last.
	-- Measured from the last placement, not from when the camp was reset, or a
	-- long session would make every fire look stale.
	local touched = camp.lastPlacedAt
	if not fresh and touched and (now - touched) > Placement.CAMP_LIFETIME then
		fresh = true
	end

	if fresh then
		camp:Reset(isCampfire and object.effect.slots or nil)
	end

	if isCampfire then
		-- The fire itself is not one of the things standing on it (FK-2), so
		-- there is nothing further to record — but the group still has to be
		-- told, or their view keeps the old fire's objects and hands them back.
		if FK.Comm and FK.Comm.AnnounceCamp then
			FK.Comm:AnnounceCamp(camp)
		end
		return object, "campfire"
	end

	local ok = camp:MarkPlaced(FK.Roster.SelfKey(), object.id)
	if ok then
		-- Stamped from the caller's clock rather than the one MarkPlaced
		-- reaches for, so "an hour since the last placement" means the same
		-- thing here as it does to whoever asked.
		camp.lastPlacedAt = now
	end
	return object, ok and "placed" or "refused"
end

Placement.watching = false

function Placement:OnLogin()
	local event = "UNIT_SPELLCAST_SUCCEEDED"
	-- Registering an event this client does not know throws and takes the rest
	-- of the file with it, so ask first where we can.
	if C_EventUtils and C_EventUtils.IsEventValid and not C_EventUtils.IsEventValid(event) then
		FK.Debug("%s is not a known event here; placements must be recorded by hand", event)
		FK.Diag("placementWatch", "event not valid")
		return
	end

	-- Prefer the unit-filtered registration: the client then only sends us the
	-- player's own casts, so there is no unit token to compare at all. Every
	-- payload field but `castBarID` is in scope for the spellcast restriction,
	-- and a secret cannot be compared.
	local filtered = pcall(function()
		FK.eventFrame:RegisterUnitEvent(event, "player")
	end)
	if not filtered then
		local ok = pcall(function()
			FK.eventFrame:RegisterEvent(event)
		end)
		if not ok then
			FK.Debug("could not watch %s; placements must be recorded by hand", event)
			FK.Diag("placementWatch", "register failed")
			return
		end
	end

	Placement.watching = true
	FK.Diag("placementWatch", filtered and "watching (player only)" or "watching (all units)")

	FK.eventFrame:HookScript("OnEvent", function(_, firedEvent, unit, _, spellId)
		if firedEvent ~= event then
			return
		end
		-- Only reached when the unit-filtered registration was unavailable.
		if not filtered then
			if FK.IsSecret and FK.IsSecret(unit) then
				return
			end
			if unit ~= "player" then
				return
			end
		end

		local object, what = Placement.OnCastSucceeded(spellId, time and time() or 0)
		if not object then
			return
		end

		if what == "campfire" then
			FK.Print("new camp: %s, %d slots.", object.name, FK.Camp.slots)
		elseif what == "placed" then
			FK.Print("noted: you placed %s.", object.name)
		end

		if FK.UI and FK.UI.Refresh then
			FK.UI:Refresh()
		end
	end)
end
