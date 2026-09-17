local _, FK = ...

-- The fire in front of you: how many slots it has and what is already on it.
--
-- There is no known way yet to read a campsite's contents from the API
-- (docs/RESEARCH.md, FK-5), so the camp is assembled from what players tell
-- each other: you mark what you place, and everyone running Firekeeper sees it.
local Camp = FK.RegisterModule("Camp", {})
FK.Camp = Camp

Camp.slots = FK.Plan and FK.Plan.DEFAULT_SLOTS or 3
Camp.placed = {}
Camp.startedAt = nil

function Camp:Reset(slots)
	self.slots = slots or FK.Plan.DEFAULT_SLOTS
	self.placed = {}
	self.startedAt = time and time() or 0
	if FK.UI and FK.UI.Refresh then
		FK.UI:Refresh()
	end
end

--- Someone put an object on the fire.
function Camp:MarkPlaced(player, objectId, silent)
	local object = FK.Data.GetObject(objectId)
	if not object then
		return false, ("unknown camp object: %s"):format(tostring(objectId))
	end

	for _, entry in ipairs(self.placed) do
		if entry.player == player then
			return false, ("%s has already contributed to this camp"):format(player)
		end
	end

	table.insert(self.placed, { player = player, objectId = objectId })

	if object.effect and object.effect.kind == "slots" then
		self.slots = math.max(self.slots, object.effect.slots or self.slots)
	end

	if player == FK.Roster.SelfKey() then
		FK.Cooldowns.RecordPlacement(player, objectId, time and time() or 0)
	end

	if not silent then
		FK.Comm:AnnounceCamp(self)
	end
	if FK.UI and FK.UI.Refresh then
		FK.UI:Refresh()
	end
	return true
end

--- Takes another player's view of the camp when it is more complete than ours.
function Camp:Adopt(slots, placedIds, sender)
	if #placedIds < #self.placed then
		return
	end
	self.slots = math.max(slots or self.slots, self.slots)
	self.placed = {}
	for _, objectId in ipairs(placedIds) do
		if FK.Data.GetObject(objectId) then
			table.insert(self.placed, { player = sender, objectId = objectId })
		end
	end
	if FK.UI and FK.UI.Refresh then
		FK.UI:Refresh()
	end
end

function Camp:Plan()
	FK.Roster:ScanGroup()
	return FK.Plan.Evaluate({
		slots = self.slots,
		placed = self.placed,
		covered = FK.Roster:Coverage(),
		contributors = FK.Roster:Contributors(time and time() or 0),
	})
end

--- What this character should place, if anything.
function Camp:SuggestionForSelf()
	local plan = self:Plan()
	local selfKey = FK.Roster.SelfKey()
	for _, suggestion in ipairs(plan.suggestions) do
		if suggestion.player == selfKey then
			return suggestion, plan
		end
	end
	return nil, plan
end

local function buffSummary(plan)
	local labels = {}
	for _, entry in ipairs(FK.Camp.placed) do
		local object = FK.Data.GetObject(entry.objectId)
		local effect = object and object.effect
		if effect and effect.kind == "buff" then
			table.insert(labels, FK.Data.buffGroups[effect.buff] and FK.Data.buffGroups[effect.buff].label or effect.buff)
		elseif effect and effect.kind == "workspace" then
			table.insert(labels, object.name)
		end
	end
	if #labels == 0 then
		return "no buffs yet"
	end
	return table.concat(labels, ", ")
end

--- "Camp up: Attack Power, Alchemy Lab. 1 slot free."
function Camp:AnnouncementText()
	local plan = self:Plan()
	local free = math.max(plan.capacity - plan.used, 0)
	return ("Camp up: %s. %d/%d slots used%s"):format(
		buffSummary(plan),
		plan.used,
		plan.capacity,
		free > 0 and (", %d free"):format(free) or ""
	)
end

function Camp:Announce(channelName)
	local target = channelName or (IsInRaid and IsInRaid() and "RAID" or (IsInGroup and IsInGroup() and "PARTY" or "SAY"))
	SendChatMessage(self:AnnouncementText(), target)
end

function Camp:OnLogin()
	self:Reset()
end
