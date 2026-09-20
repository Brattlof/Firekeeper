local _, FK = ...

-- The camp panel: the fire, who is standing at it, and what each of them
-- should place.
--
-- Drawn from UI/Theme.lua rather than a Blizzard frame template, so the addon
-- keeps its own look and a template this client may not ship cannot stop the
-- panel from appearing (docs/RESEARCH.md, FK-6).
local UI = FK.RegisterModule("UI", {})
FK.UI = UI

local WIDTH, HEIGHT, ROW_HEIGHT = 360, 340, 15
local PIP_SIZE, PIP_GAP = 9, 4

local function pip(frame, index)
	local existing = frame.pips[index]
	if existing then
		return existing
	end

	local holder = CreateFrame("Frame", nil, frame.pipRow)
	holder:SetSize(PIP_SIZE, PIP_SIZE)
	holder:SetPoint("LEFT", (index - 1) * (PIP_SIZE + PIP_GAP), 0)

	holder.fill = FK.Theme.Fill(holder, "ARTWORK", FK.Theme.colors.ash)
	holder.fill:SetAllPoints()
	FK.Theme.Border(holder, FK.Theme.colors.emberDim, 0.9)

	frame.pips[index] = holder
	return holder
end

--- One pip per slot on the fire: lit for a slot in use, dark for a free one.
-- It is the one thing you want to know from across the screen.
local function updatePips(frame, used, capacity)
	for index = 1, math.max(capacity, #frame.pips) do
		if index <= capacity then
			local holder = pip(frame, index)
			local color = index <= used and FK.Theme.colors.ember or FK.Theme.colors.ash
			if holder.fill.SetColorTexture then
				holder.fill:SetColorTexture(color[1], color[2], color[3], 1)
			end
			holder:Show()
		elseif frame.pips[index] then
			frame.pips[index]:Hide()
		end
	end
	frame.pipRow:SetWidth(math.max(capacity, 1) * (PIP_SIZE + PIP_GAP))
end

local function createFrame()
	local Theme = FK.Theme
	local frame = Theme.Panel("FirekeeperCampFrame", WIDTH, HEIGHT, "Firekeeper", "panelPosition")

	-- Header: the slot count, with the pips under it.
	local header = Theme.Label(frame, "GameFontNormalSmall", Theme.colors.text)
	header:SetPoint("TOPLEFT", 14, -36)
	frame.header = header

	local pipRow = CreateFrame("Frame", nil, frame)
	pipRow:SetPoint("TOPLEFT", 14, -54)
	pipRow:SetHeight(PIP_SIZE)
	frame.pipRow = pipRow
	frame.pips = {}

	local rule = Theme.Line(frame, Theme.colors.emberDim, 0.5)
	rule:SetPoint("TOPLEFT", 14, -70)
	rule:SetPoint("TOPRIGHT", -14, -70)
	rule:SetHeight(1)

	local body = CreateFrame("Frame", nil, frame)
	body:SetPoint("TOPLEFT", 14, -78)
	body:SetPoint("BOTTOMRIGHT", -14, 44)
	frame.body = body
	frame.rows = {}

	local footRule = Theme.Line(frame, Theme.colors.emberDim, 0.5)
	footRule:SetPoint("BOTTOMLEFT", 14, 38)
	footRule:SetPoint("BOTTOMRIGHT", -14, 38)
	footRule:SetHeight(1)

	frame.placeButton = Theme.Button(frame, "I placed this", 150, function()
		local suggestion = FK.Camp:SuggestionForSelf()
		if suggestion then
			FK.Camp:MarkPlaced(FK.Roster.SelfKey(), suggestion.objectId)
		else
			FK.Print("nothing suggested for you: use |cffffff00/fk place <object>|r")
		end
	end)
	frame.placeButton:SetPoint("BOTTOMLEFT", 14, 10)

	local announce = Theme.Button(frame, "Announce camp", 140, function() FK.Camp:Announce() end)
	announce:SetPoint("BOTTOMRIGHT", -14, 10)

	return frame
end

local function row(frame, index)
	local existing = frame.rows[index]
	if existing then
		return existing
	end
	local line = FK.Theme.Label(frame.body, "GameFontHighlightSmall", FK.Theme.colors.text)
	line:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
	line:SetPoint("RIGHT", frame.body, "RIGHT", 0, 0)
	frame.rows[index] = line
	return line
end

function UI:Refresh()
	local frame = self.frame
	if not frame or not frame:IsShown() then
		return
	end

	local plan = FK.Camp:Plan()
	frame.header:SetText(("%d of %d slots used"):format(plan.used, plan.capacity))
	updatePips(frame, plan.used, plan.capacity)

	local lines = {}

	for _, entry in ipairs(FK.Camp.placed) do
		local object = FK.Data.GetObject(entry.objectId)
		table.insert(lines, ("|cff73d957on the fire|r  %s — %s"):format(
			object and object.name or entry.objectId, entry.player))
	end

	if #plan.suggestions > 0 then
		table.insert(lines, " ")
		table.insert(lines, "|cfffad161Suggested|r")
		for _, suggestion in ipairs(plan.suggestions) do
			local mark = suggestion.confidence == "confirmed" and "" or " |cff8a8a8a?|r"
			table.insert(lines, ("  %s → |cffff8c38%s|r%s"):format(suggestion.player, suggestion.name, mark))
		end
	end

	if #plan.redundant > 0 then
		table.insert(lines, " ")
		table.insert(lines, "|cfffad161Would be wasted|r")
		for _, entry in ipairs(plan.redundant) do
			table.insert(lines, ("  |cff8a8a8a%s: %s — %s|r"):format(
				entry.player, entry.name, FK.Plan.ReasonText(entry.reason)))
		end
	end

	if #plan.waiting > 0 then
		table.insert(lines, " ")
		table.insert(lines, "|cfffad161On cooldown|r")
		for _, entry in ipairs(plan.waiting) do
			table.insert(lines, ("  |cff8a8a8a%s — %s|r"):format(
				entry.player, FK.Cooldowns.Format(entry.readyIn)))
		end
	end

	local silent = FK.Roster:Silent()
	if #silent > 0 then
		table.insert(lines, " ")
		table.insert(lines, ("|cff8a8a8aNo Firekeeper: %s|r"):format(table.concat(silent, ", ")))
	end

	if #lines == 0 then
		lines = { "|cff8a8a8aNobody at this fire has told us what they can place.|r" }
	end

	-- The place button says whether there is anything for you to do.
	local suggestion = FK.Camp:SuggestionForSelf()
	FK.Theme.SetTextColor(frame.placeButton.text,
		suggestion and FK.Theme.colors.text or FK.Theme.colors.smoke)

	local maxRows = math.floor(frame.body:GetHeight() / ROW_HEIGHT)
	for index = 1, math.max(maxRows, #lines) do
		if index <= math.min(#lines, maxRows) then
			local line = row(frame, index)
			line:SetText(lines[index])
			line:Show()
		elseif frame.rows[index] then
			frame.rows[index]:Hide()
		end
	end
end

function UI:Toggle()
	if not self.frame then
		self.frame = createFrame()
	end
	if self.frame:IsShown() then
		self.frame:Hide()
	else
		self.frame:Show()
		FK.Comm:Announce(true)
		self:Refresh()
	end
end

function UI:OnLogin()
	-- Refresh on a slow ticker: cooldowns tick down and people wander off.
	if C_Timer and C_Timer.NewTicker then
		C_Timer.NewTicker(5, function()
			FK.Roster:Prune()
			UI:Refresh()
		end)
	end
end
