local _, FK = ...

-- How far off your next camp object is.
--
-- This is the camping half of a profession planner: for each trade you have,
-- which camp objects you can already place, which one comes next, and how much
-- skill stands between you and it. It deliberately says nothing about how to
-- get that skill — which recipe is cheapest, what the reagents cost — because
-- that is a crafting addon's job and needs the whole recipe table to answer.
-- ponytail: skill thresholds only. If a full levelling route is ever wanted,
-- it wants the game's recipe data behind it, not a guess here.
--
-- Pure Lua, so it runs in tests/.
local Route = {}
FK.Route = Route

--- What each of your professions can put on a fire, now and next.
--
-- `known` is { Blacksmithing = 145, Herbalism = 300 }, straight from
-- Core/Professions.lua.
--
-- Returns one entry per profession:
--   { profession, skill, placeable = {objects}, next = object|nil,
--     short = <skill points needed>|nil, blueprints = {objects} }
--
-- `next` is the nearest object with a known skill requirement you have not
-- reached. `blueprints` are the ones whose requirement nobody has reported, so
-- the panel can say "this exists, we do not know what it takes" rather than
-- pretending they are unreachable.
function Route.Evaluate(known)
	local entries = {}

	for profession, skill in pairs(known or {}) do
		skill = tonumber(skill) or 0
		local placeable, blueprints, next_, short = {}, {}, nil, nil

		for _, object in ipairs(FK.Data.campObjectsByProfession[profession] or {}) do
			if not object.skill then
				table.insert(blueprints, object)
			elseif skill >= object.skill then
				table.insert(placeable, object)
			elseif not next_ or object.skill < next_.skill then
				next_ = object
				short = object.skill - skill
			end
		end

		table.sort(placeable, function(a, b) return (a.tier or 1) < (b.tier or 1) end)
		table.sort(blueprints, function(a, b) return (a.tier or 1) < (b.tier or 1) end)

		table.insert(entries, {
			profession = profession,
			skill = skill,
			placeable = placeable,
			next = next_,
			short = short,
			blueprints = blueprints,
		})
	end

	-- Closest to an unlock first, then the ones already sorted out, so the
	-- line worth acting on is at the top.
	table.sort(entries, function(a, b)
		if (a.short ~= nil) ~= (b.short ~= nil) then
			return a.short ~= nil
		end
		if a.short and b.short and a.short ~= b.short then
			return a.short < b.short
		end
		return a.profession < b.profession
	end)

	return entries
end

--- "Blacksmithing 145 — Sharpening Wheel ready, Anvil in 5 skill"
function Route.Line(entry)
	local parts = {}

	if #entry.placeable > 0 then
		local names = {}
		for _, object in ipairs(entry.placeable) do
			table.insert(names, object.name)
		end
		table.insert(parts, table.concat(names, ", ") .. " ready")
	end

	if entry.next then
		table.insert(parts, ("%s in %d skill"):format(entry.next.name, entry.short))
	end

	if #entry.blueprints > 0 then
		table.insert(parts, ("%d more needing a blueprint nobody has reported"):format(#entry.blueprints))
	end

	if #parts == 0 then
		parts = { "nothing known yet" }
	end

	return ("%s %d — %s"):format(entry.profession, entry.skill, table.concat(parts, ", "))
end

return Route
