local _, FK = ...

-- The planner. Pure Lua on purpose: it touches no WoW API, so it runs under
-- plain lua5.1 in tests/ and can be reasoned about without logging in.
local Plan = {}
FK.Plan = Plan

Plan.DEFAULT_SLOTS = 3

-- What a campsite is worth filling with first. A campfire upgrade comes before
-- anything else because it buys slots for everyone else's objects; a buff
-- nobody else can supply beats a workspace somebody could walk to a city for.
local EFFECT_WEIGHT = {
	slots = 100,
	buff = 60,
	workspace = 50,
	utility = 40,
	unknown = 10,
}

--- A stable identity for what an object gives the camp. Two objects with the
-- same effect key are interchangeable, and placing both wastes a slot.
function Plan.EffectKey(object)
	-- An object that carries a lower tier's benefits shares its effect. Every
	-- tier-2 and tier-3 tooltip except Engineering's and Cooking's says it
	-- "provides all of the benefits of" the tier-1 object, so an Anvil already
	-- gives the Sharpening Wheel's Strength and placing both wastes a slot.
	-- Keying on the buff it ends up providing is what catches that.
	local carried = FK.Data and FK.Data.EffectiveBuff and FK.Data.EffectiveBuff(object)
	if carried then
		return "buff:" .. tostring(carried)
	end

	local effect = object.effect or { kind = "unknown" }
	if effect.kind == "buff" then
		return "buff:" .. tostring(effect.buff)
	elseif effect.kind == "workspace" then
		return "workspace:" .. tostring(effect.workspace)
	elseif effect.kind == "slots" then
		return "slots"
	elseif effect.kind == "utility" then
		return "utility:" .. tostring(effect.utility or object.id)
	end
	return "unknown:" .. tostring(object.id)
end

local function objectFor(id)
	return FK.Data and FK.Data.GetObject and FK.Data.GetObject(id) or nil
end

--- What placing this object is worth.
--
-- A superseding object gives its own effect *and* the buff of the tier it
-- replaces, so it must not score below that buff — otherwise the planner would
-- prefer a bare Sharpening Wheel over an Anvil that carries the same Strength
-- and is a workspace as well.
local function weightFor(object)
	local effect = object.effect or { kind = "unknown" }
	local weight = EFFECT_WEIGHT[effect.kind] or EFFECT_WEIGHT.unknown
	if object.supersedes and FK.Data and FK.Data.EffectiveBuff
		and FK.Data.EffectiveBuff(object) then
		weight = math.max(weight, EFFECT_WEIGHT.buff)
	end
	return weight
end

local function buffLabel(key)
	local group = FK.Data and FK.Data.buffGroups and FK.Data.buffGroups[key]
	return group and group.label or key
end

--- Plans a campsite.
--
-- state = {
--   slots        = 3,                            -- capacity of the fire that is up
--   placed       = { { player = "Ana", objectId = "incense_candle" } },
--   covered      = { attack_power = "Battle Shout" }, -- buffs the group already has
--   contributors = {                             -- everyone standing at the fire
--     { name = "Bo", ready = true, objects = { "sharpening_wheel", "anvil" } },
--     { name = "Cy", ready = false, readyIn = 900, objects = { "alchemy_laboratory" } },
--   },
-- }
--
-- Each player may add one object, and those objects share a one-hour cooldown,
-- so a plan assigns at most one object per player and never two objects with
-- the same effect.
function Plan.Evaluate(state)
	state = state or {}
	local placed = state.placed or {}
	local covered = state.covered or {}

	local capacity = state.slots or Plan.DEFAULT_SLOTS
	local placedEffects, spentPlayers = {}, {}

	for _, entry in ipairs(placed) do
		local object = objectFor(entry.objectId)
		if object then
			placedEffects[Plan.EffectKey(object)] = object.name
			if object.effect and object.effect.kind == "slots" then
				capacity = math.max(capacity, object.effect.slots or capacity)
			end
		end
		if entry.player then
			spentPlayers[entry.player] = true
		end
	end

	local used = #placed
	local free = math.max(capacity - used, 0)

	local candidates, redundant, waiting, unknownObjects = {}, {}, {}, {}

	for _, contributor in ipairs(state.contributors or {}) do
		-- Somebody who already gave their one object to this fire is neither a
		-- candidate nor waiting for a cooldown: they are simply done.
		if not spentPlayers[contributor.name] then
			if contributor.ready == false then
				table.insert(waiting, { player = contributor.name, readyIn = contributor.readyIn })
			else
				for _, objectId in ipairs(contributor.objects or {}) do
					local object = objectFor(objectId)
					if not object then
						table.insert(unknownObjects, { player = contributor.name, objectId = objectId })
					else
						local key = Plan.EffectKey(object)
						local effect = object.effect or { kind = "unknown" }
						if effect.kind == "buff" and covered[effect.buff] then
							table.insert(redundant, {
								player = contributor.name,
								objectId = objectId,
								name = object.name,
								reason = { code = "covered", buff = effect.buff, by = covered[effect.buff] },
							})
						elseif placedEffects[key] then
							table.insert(redundant, {
								player = contributor.name,
								objectId = objectId,
								name = object.name,
								reason = { code = "duplicate", by = placedEffects[key] },
							})
						else
							table.insert(candidates, {
								player = contributor.name,
								objectId = objectId,
								name = object.name,
								effectKey = key,
								score = weightFor(object),
								tier = object.tier or 1,
								confidence = object.confidence or "unknown",
							})
						end
					end
				end
			end
		end
	end

	-- Deterministic order: value first, then the better version of the same
	-- idea, then by name and player so two clients always agree on the plan.
	table.sort(candidates, function(a, b)
		if a.score ~= b.score then return a.score > b.score end
		if a.tier ~= b.tier then return a.tier > b.tier end
		if a.name ~= b.name then return a.name < b.name end
		return a.player < b.player
	end)

	local suggestions, takenPlayers, takenEffects = {}, {}, {}
	local uncertain = false

	for _, candidate in ipairs(candidates) do
		local object = objectFor(candidate.objectId)
		local raisesCapacity = object.effect and object.effect.kind == "slots"
		if not takenPlayers[candidate.player] and not takenEffects[candidate.effectKey]
			and (free > 0 or raisesCapacity) then
			takenPlayers[candidate.player] = true
			takenEffects[candidate.effectKey] = true
			table.insert(suggestions, candidate)

			if raisesCapacity then
				-- Assumption: the upgraded fire replaces the basic one rather
				-- than sitting in an object slot. See docs/RESEARCH.md, FK-2.
				local raised = math.max(capacity, object.effect.slots or capacity)
				free = free + (raised - capacity)
				capacity = raised
			else
				free = free - 1
			end

			if candidate.confidence ~= "confirmed" then
				uncertain = true
			end
		end
	end

	return {
		capacity = capacity,
		used = used,
		free = free,
		suggestions = suggestions,
		redundant = redundant,
		waiting = waiting,
		unknownObjects = unknownObjects,
		uncertain = uncertain,
	}
end

--- Turns a redundancy reason into a sentence for the panel and chat.
function Plan.ReasonText(reason)
	if not reason then
		return ""
	elseif reason.code == "covered" then
		return ("%s is already covered by %s"):format(buffLabel(reason.buff), reason.by)
	elseif reason.code == "duplicate" then
		return ("%s is already on the fire"):format(reason.by)
	end
	return reason.code or ""
end

return Plan
