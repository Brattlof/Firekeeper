local _, FK = ...

-- One panel: the fire, who is standing at it, and what each of them should
-- place. Deliberately plain frames and font strings, because which UI templates
-- Forever ships is not yet known (docs/RESEARCH.md, FK-6) and a missing
-- template must not stop the addon from loading.
local UI = FK.RegisterModule("UI", {})
FK.UI = UI

local WIDTH, HEIGHT, ROW_HEIGHT = 340, 300, 16

local function createFrame()
	local frame = CreateFrame("Frame", "FirekeeperCampFrame", UIParent, "BasicFrameTemplateWithInset")
	if not frame then
		frame = CreateFrame("Frame", "FirekeeperCampFrame", UIParent)
	end
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetClampedToScreen(true)
	frame:Hide()

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", 0, -6)
	title:SetText("Firekeeper")
	frame.title = title

	local header = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	header:SetPoint("TOPLEFT", 14, -32)
	frame.header = header

	local body = CreateFrame("Frame", nil, frame)
	body:SetPoint("TOPLEFT", 14, -52)
	body:SetPoint("BOTTOMRIGHT", -14, 40)
	frame.body = body
	frame.rows = {}

	local placeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	if placeButton then
		placeButton:SetSize(150, 22)
		placeButton:SetPoint("BOTTOMLEFT", 14, 12)
		placeButton:SetText("I placed this")
		placeButton:SetScript("OnClick", function()
			local suggestion = FK.Camp:SuggestionForSelf()
			if suggestion then
				FK.Camp:MarkPlaced(FK.Roster.SelfKey(), suggestion.objectId)
			else
				FK.Print("nothing suggested for you: use |cffffff00/fk place <object>|r")
			end
		end)
		frame.placeButton = placeButton
	end

	local announceButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	if announceButton then
		announceButton:SetSize(130, 22)
		announceButton:SetPoint("BOTTOMRIGHT", -14, 12)
		announceButton:SetText("Announce camp")
		announceButton:SetScript("OnClick", function() FK.Camp:Announce() end)
	end

	return frame
end

local function row(frame, index)
	local existing = frame.rows[index]
	if existing then
		return existing
	end
	local line = frame.body:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	line:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
	line:SetPoint("RIGHT", frame.body, "RIGHT", 0, 0)
	line:SetJustifyH("LEFT")
	frame.rows[index] = line
	return line
end

function UI:Refresh()
	local frame = self.frame
	if not frame or not frame:IsShown() then
		return
	end

	local plan = FK.Camp:Plan()
	frame.header:SetText(("Camp: |cffffff00%d/%d|r slots used"):format(plan.used, plan.capacity))

	local lines = {}

	for _, entry in ipairs(FK.Camp.placed) do
		local object = FK.Data.GetObject(entry.objectId)
		table.insert(lines, ("|cff40ff40on the fire|r  %s — %s"):format(object and object.name or entry.objectId, entry.player))
	end

	if #plan.suggestions > 0 then
		table.insert(lines, " ")
		table.insert(lines, "|cffffd100Suggested|r")
		for _, suggestion in ipairs(plan.suggestions) do
			local mark = suggestion.confidence == "confirmed" and "" or " |cff888888?|r"
			table.insert(lines, ("  %s → %s%s"):format(suggestion.player, suggestion.name, mark))
		end
	end

	if #plan.redundant > 0 then
		table.insert(lines, " ")
		table.insert(lines, "|cffffd100Would be wasted|r")
		for _, entry in ipairs(plan.redundant) do
			table.insert(lines, ("  |cff888888%s: %s — %s|r"):format(entry.player, entry.name, FK.Plan.ReasonText(entry.reason)))
		end
	end

	if #plan.waiting > 0 then
		table.insert(lines, " ")
		table.insert(lines, "|cffffd100On cooldown|r")
		for _, entry in ipairs(plan.waiting) do
			table.insert(lines, ("  |cff888888%s — %s|r"):format(entry.player, FK.Cooldowns.Format(entry.readyIn)))
		end
	end

	local silent = FK.Roster:Silent()
	if #silent > 0 then
		table.insert(lines, " ")
		table.insert(lines, ("|cff888888No Firekeeper: %s|r"):format(table.concat(silent, ", ")))
	end

	if #lines == 0 then
		lines = { "|cff888888Nobody at this fire has told us what they can place.|r" }
	end

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
