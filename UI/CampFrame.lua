local _, FK = ...

-- The camp panel. Five tabs, between them covering everything the slash
-- commands do, because nobody should have to remember `/fk legacy fieldGuide 2`
-- to use a setting.
--
-- Drawn from UI/Theme.lua rather than a Blizzard frame template, so the addon
-- keeps its own look and a template this client may not ship cannot stop the
-- panel from appearing (docs/RESEARCH.md, FK-6).
local UI = FK.RegisterModule("UI", {})
FK.UI = UI

local WIDTH, HEIGHT, ROW_HEIGHT = 420, 430, 15
local PIP_SIZE, PIP_GAP = 9, 4
local TABS = { "Camp", "Place", "Buffs", "Find", "You" }

-- Status colours, so the same idea reads the same way on every tab.
local STATUS_COLOR = {
	missing = "ff5450",
	available = "fad161",
	placed = "73d957",
	class = "8a8a8a",
}

local function colored(hex, text)
	return ("|cff%s%s|r"):format(hex, text)
end

--- What a given player is being told to place, read off a plan we already have
-- rather than by planning the camp again.
local function suggestionFor(plan, player)
	for _, suggestion in ipairs(plan.suggestions) do
		if suggestion.player == player then
			return suggestion
		end
	end
	return nil
end

-- Rows ------------------------------------------------------------------

--- A reusable list of single-line labels inside a content frame. Every tab
-- draws itself by handing this a table of strings, which keeps the drawing in
-- one place and the tabs about what they mean.
local function lineList(parent)
	local list = { frame = parent, rows = {} }

	function list:Set(lines, top)
		top = top or 0
		local maxRows = math.floor((parent:GetHeight() - top) / ROW_HEIGHT)
		for index = 1, math.max(maxRows, #self.rows, #lines) do
			if index <= math.min(#lines, maxRows) then
				local row = self.rows[index]
				if not row then
					row = FK.Theme.Label(parent, "GameFontHighlightSmall", FK.Theme.colors.text)
					row:SetPoint("TOPLEFT", 0, -top - (index - 1) * ROW_HEIGHT)
					row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
					self.rows[index] = row
				end
				row:SetText(lines[index])
				row:Show()
			elseif self.rows[index] then
				self.rows[index]:Hide()
			end
		end
	end

	return list
end

-- Slot pips -------------------------------------------------------------

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
			FK.Theme.Recolor(holder.fill,
				index <= used and FK.Theme.colors.ember or FK.Theme.colors.ash)
			holder:Show()
		elseif frame.pips[index] then
			frame.pips[index]:Hide()
		end
	end
	frame.pipRow:SetWidth(math.max(capacity, 1) * (PIP_SIZE + PIP_GAP))
end

-- Tab: Camp -------------------------------------------------------------

local function buildCampTab(parent)
	local tab = CreateFrame("Frame", nil, parent)
	tab:SetAllPoints()
	local list = lineList(tab)

	local announce = FK.Theme.Button(tab, "Announce to chat", 130, function()
		FK.Camp:Announce()
	end)
	announce:SetPoint("BOTTOMLEFT", 0, 0)

	-- The same secure treatment as the Place grid: a click uses the suggested
	-- item, and Core/Placement.lua notices what actually went down.
	local secure, place = pcall(CreateFrame, "Button", nil, tab, "SecureActionButtonTemplate")
	if secure and place then
		place.secure = true
		place:RegisterForClicks("AnyUp")
		FK.Theme.Dress(place, "Place what is suggested", 160)
		place:SetScript("PostClick", function()
			if FK.UI and FK.UI.Refresh then
				FK.UI:Refresh()
			end
		end)
	else
		place = FK.Theme.Button(tab, "Place what is suggested", 160, function()
			local suggestion = suggestionFor(FK.Camp:Plan(), FK.Roster.SelfKey())
			if suggestion then
				FK.Camp:MarkPlaced(FK.Roster.SelfKey(), suggestion.objectId)
			else
				FK.Print("nothing is suggested for you; the Place tab has everything you can put down.")
			end
			FK.UI:Refresh()
		end)
	end
	place:SetPoint("BOTTOMRIGHT", 0, 0)
	tab.placeButton = place

	function tab:Refresh(plan)
		local lines = {}

		for _, entry in ipairs(FK.Camp.placed) do
			local object = FK.Data.GetObject(entry.objectId)
			table.insert(lines, ("%s  %s — %s"):format(
				colored(STATUS_COLOR.placed, "on the fire"),
				object and object.name or entry.objectId, entry.player))
		end

		if #plan.suggestions > 0 then
			table.insert(lines, " ")
			table.insert(lines, colored("fad161", "Suggested"))
			for _, suggestion in ipairs(plan.suggestions) do
				table.insert(lines, ("  %s → %s"):format(
					suggestion.player, colored("ff8c38", suggestion.name)))
			end
		end

		if #plan.redundant > 0 then
			table.insert(lines, " ")
			table.insert(lines, colored("fad161", "Would be wasted"))
			for _, entry in ipairs(plan.redundant) do
				table.insert(lines, colored("8a8a8a", ("  %s: %s — %s"):format(
					entry.player, entry.name, FK.Plan.ReasonText(entry.reason))))
			end
		end

		if #plan.waiting > 0 then
			table.insert(lines, " ")
			table.insert(lines, colored("fad161", "On cooldown"))
			for _, entry in ipairs(plan.waiting) do
				table.insert(lines, colored("8a8a8a", ("  %s — %s"):format(
					entry.player, FK.Cooldowns.Format(entry.readyIn))))
			end
		end

		local silent = FK.Roster:Silent()
		if #silent > 0 then
			table.insert(lines, " ")
			table.insert(lines, colored("8a8a8a", "No Firekeeper: " .. table.concat(silent, ", ")))
		end

		if #lines == 0 then
			lines = { colored("8a8a8a", "Nobody at this fire has said what they can place.") }
		end

		local mine = suggestionFor(plan, FK.Roster.SelfKey())
		FK.Theme.SetTextColor(place.text,
			mine and FK.Theme.colors.text or FK.Theme.colors.smoke)

		if place.secure and not (InCombatLockdown and InCombatLockdown()) then
			local object = mine and FK.Data.GetObject(mine.objectId)
			place:SetAttribute("type", object and "item" or nil)
			place:SetAttribute("item", object and object.itemId
				and ("item:" .. object.itemId) or nil)
		end

		list:Set(lines)
	end

	return tab
end

-- Tab: Place ------------------------------------------------------------

local ICON_SIZE, GRID_COLUMNS = 30, 5

--- One object in the Place grid. Kept on the tab so the tab can hide them, but
-- parented to the grid so they lay out inside it.
--
-- Built on `SecureActionButtonTemplate` where the client has it, so clicking
-- actually uses the item and puts the object down. Using an item is a protected
-- action: an addon cannot do it for you, but a button you click yourself can.
-- Where the template is missing the button still works, it just records what
-- you tell it and leaves the using to you.
local function objectButton(tab, grid, index)
	local existing = tab.buttons[index]
	if existing then
		return existing
	end

	local column, row = (index - 1) % GRID_COLUMNS, math.floor((index - 1) / GRID_COLUMNS)

	local secure, button = pcall(CreateFrame, "Button", nil, grid, "SecureActionButtonTemplate")
	if secure and button then
		button.secure = true
		button:RegisterForClicks("AnyUp")
	else
		button = CreateFrame("Button", nil, grid)
	end
	tab.secureButtons = button.secure
	button:SetSize(ICON_SIZE, ICON_SIZE)
	button:SetPoint("TOPLEFT", column * (ICON_SIZE + 8), -row * (ICON_SIZE + 8))

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	button.icon = icon

	local edges = FK.Theme.Border(button, FK.Theme.colors.emberDim, 0.8)
	button.edges = edges

	button:SetScript("OnEnter", function()
		if GameTooltip and button.object then
			GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
			GameTooltip:AddLine(button.object.name, 1, 0.55, 0.22)
			GameTooltip:AddLine(button.detail or "", 0.92, 0.90, 0.86, true)
			if button.reason then
				GameTooltip:AddLine(button.reason, 0.62, 0.60, 0.57, true)
			end
			GameTooltip:AddLine(button.placeable and "Click to put it on the fire"
				or "You cannot place this right now", 0.62, 0.60, 0.57)
			GameTooltip:Show()
		end
	end)
	button:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	if button.secure then
		-- The item use is the attribute's doing, not ours. What was actually
		-- placed is noticed by Core/Placement.lua watching the finished cast,
		-- so nothing here has to assume the click worked.
		button:SetScript("PostClick", function()
			if FK.UI and FK.UI.Refresh then
				FK.UI:Refresh()
			end
		end)
	else
		button:SetScript("OnClick", function()
			if button.object and button.placeable then
				local ok, err = FK.Camp:MarkPlaced(FK.Roster.SelfKey(), button.object.id)
				if not ok then
					FK.Print("|cffff4040%s|r", err)
				end
				FK.UI:Refresh()
			end
		end)
	end

	tab.buttons[index] = button
	return button
end

local function buildPlaceTab(parent)
	local tab = CreateFrame("Frame", nil, parent)
	tab:SetAllPoints()
	tab.buttons = {}

	local heading = FK.Theme.Label(tab, "GameFontNormalSmall", FK.Theme.colors.text)
	heading:SetPoint("TOPLEFT", 0, 0)
	tab.heading = heading
	tab.secureButtons = false

	local grid = CreateFrame("Frame", nil, tab)
	grid:SetPoint("TOPLEFT", 0, -20)
	grid:SetPoint("BOTTOMRIGHT", 0, 60)
	tab.grid = grid

	local footer = FK.Theme.Label(tab, "GameFontHighlightSmall", FK.Theme.colors.smoke)
	footer:SetPoint("BOTTOMLEFT", 0, 30)
	footer:SetPoint("RIGHT", tab, "RIGHT", 0, 0)
	footer:SetJustifyH("LEFT")
	tab.footer = footer

	-- Starting a fresh fire belongs here: it is the other half of placing.
	local x = 0
	for _, campfire in ipairs(FK.Data.campfires) do
		local slots = campfire.effect.slots
		local button = FK.Theme.Button(tab, ("New %d-slot"):format(slots), 92, function()
			FK.Camp:Reset(slots)
			FK.Print("new camp with %d slots.", FK.Camp.slots)
			FK.UI:Refresh()
		end)
		button:SetPoint("BOTTOMLEFT", x, 0)
		x = x + 96
	end

	function tab:Refresh(plan)
		local objects = FK.Professions:PlaceableObjects()
		local selfKey = FK.Roster.SelfKey()

		local covered = FK.Roster:Coverage()

		-- Keyed the way the planner keys them, so "already on the fire" means
		-- the same thing here as it does in Plan.Evaluate: an Anvil on the fire
		-- does cover a Sharpening Wheel, because it carries its buff.
		local onFire = {}
		for _, entry in ipairs(FK.Camp.placed) do
			local object = FK.Data.GetObject(entry.objectId)
			if object then
				onFire[FK.Plan.EffectKey(object)] = object.name
			end
		end

		local spent = false
		for _, entry in ipairs(FK.Camp.placed) do
			if entry.player == selfKey then
				spent = true
			end
		end

		local readyIn = FK.Cooldowns.ForCharacter(selfKey, time and time() or 0)
		local suggestion = suggestionFor(plan, selfKey)

		heading:SetText(#objects > 0
			and ("What you can place (%d/%d slots used)"):format(plan.used, plan.capacity)
			or "Your professions do not place anything yet")

		for index = 1, math.max(#objects, #self.buttons) do
			local object = objects[index]
			if object then
				local button = objectButton(self, self.grid, index)
				button.object = object

				local icon = C_Item and C_Item.GetItemIconByID and object.itemId
					and C_Item.GetItemIconByID(object.itemId)
				button.icon:SetTexture(icon or FK.Theme.ICON)

				local carried = FK.Data.EffectiveBuff(object)
				button.detail = carried and FK.Data.buffGroups[carried]
					and FK.Data.buffGroups[carried].label or "No buff"

				local effect = object.effect or {}
				local ownBuff = effect.kind == "buff" and effect.buff or nil

				local tint, reason = FK.Theme.colors.emberDim, nil
				button.placeable = true

				local raisesCapacity = effect.kind == "slots"
				if spent then
					tint, reason = FK.Theme.colors.smoke, "You have already given this fire an object"
					button.placeable = false
				elseif not raisesCapacity and plan.used >= plan.capacity then
					tint, reason = FK.Theme.colors.smoke, "This fire is full"
					button.placeable = false
				elseif readyIn > 0 then
					tint = FK.Theme.colors.smoke
					reason = "On cooldown for " .. FK.Cooldowns.Format(readyIn)
					button.placeable = false
				elseif ownBuff and covered[ownBuff] then
					-- Only an object whose *own* effect is the covered buff is
					-- wasted. A Master Forge carries Strength but is also a
					-- workspace, and nothing covers that — reddening it told the
					-- player to skip the very thing the Camp tab was suggesting.
					tint, reason = FK.Theme.colors.red,
						"Wasted: " .. covered[ownBuff] .. " already covers it"
				elseif onFire[FK.Plan.EffectKey(object)] then
					tint, reason = FK.Theme.colors.red,
						"Wasted: " .. onFire[FK.Plan.EffectKey(object)] .. " is already on the fire"
				elseif suggestion and suggestion.objectId == object.id then
					tint, reason = FK.Theme.colors.green, "The best thing you can place here"
				end

				for _, line in pairs(button.edges) do
					FK.Theme.Recolor(line, tint)
				end
				button.reason = reason
				button.icon:SetDesaturated(not button.placeable)

				-- Point the secure button at the item, or at nothing when it
				-- would be refused. Attributes cannot be changed in combat, and
				-- nobody is building a camp mid-pull.
				if button.secure and not (InCombatLockdown and InCombatLockdown()) then
					button:SetAttribute("type", button.placeable and "item" or nil)
					button:SetAttribute("item",
						button.placeable and object.itemId and ("item:" .. object.itemId) or nil)
				end

				button:Show()
			elseif self.buttons[index] then
				self.buttons[index]:Hide()
			end
		end

		if #objects == 0 then
			footer:SetText(colored("8a8a8a",
				"Set one on the You tab if the game will not tell us which you have."))
		elseif spent then
			footer:SetText(colored("8a8a8a", "You have already contributed to this fire."))
		elseif readyIn > 0 then
			footer:SetText(colored("8a8a8a",
				"Camp cooldown: " .. FK.Cooldowns.Format(readyIn)))
		elseif self.secureButtons then
			footer:SetText(colored("8a8a8a",
				"Click one to place it. Green is the best choice here, red would be wasted."))
		else
			footer:SetText(colored("8a8a8a",
				"Use the item from your bags; clicking here only records it. "
					.. "Green is the best choice, red would be wasted."))
		end
	end

	return tab
end

-- Tab: Buffs ------------------------------------------------------------

local function buildBuffsTab(parent)
	local tab = CreateFrame("Frame", nil, parent)
	tab:SetAllPoints()
	local list = lineList(tab)

	function tab:Refresh()
		local report = FK.Plan.BuffReport({
			placed = FK.Camp.placed,
			covered = FK.Roster:Coverage(),
			contributors = FK.Roster:Contributors(time and time() or 0),
		})

		local lines = { colored("fad161", "Camp buffs") }
		for _, row in ipairs(report) do
			table.insert(lines, "  " .. colored(STATUS_COLOR[row.status] or "ffffff",
				FK.Plan.BuffReportText(row)))
		end

		-- What the group is missing that no camp object can fix.
		local ok, missing = pcall(function() return FK.Auras:Missing() end)
		table.insert(lines, " ")
		table.insert(lines, colored("fad161", "Class buffs"))
		if not ok or missing.members == 0 then
			table.insert(lines, colored("8a8a8a", "  nobody to check"))
		elseif missing.unreadable >= missing.members then
			table.insert(lines, colored("8a8a8a", "  this client will not show auras right now"))
		elseif #missing.missing == 0 then
			table.insert(lines, colored("73d957", "  everyone has what their classes can give"))
		else
			for _, entry in ipairs(missing.missing) do
				table.insert(lines, colored("8a8a8a", "  " .. FK.Buffs.MissingText(entry)))
			end
		end

		list:Set(lines)
	end

	return tab
end

-- Tab: Find -------------------------------------------------------------

--- A full-width clickable row, for lists whose entries do something.
local function actionRow(tab, index, onClick)
	local existing = tab.campRows[index]
	if existing then
		existing.onClick = onClick
		return existing
	end

	local row = CreateFrame("Button", nil, tab)
	row:SetHeight(ROW_HEIGHT)
	row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT - 16)
	row:SetPoint("RIGHT", tab, "RIGHT", 0, 0)

	local text = FK.Theme.Label(row, "GameFontHighlightSmall", FK.Theme.colors.text)
	text:SetPoint("LEFT")
	text:SetPoint("RIGHT")
	row.text = text

	row:SetScript("OnEnter", function() FK.Theme.SetTextColor(text, FK.Theme.colors.gold) end)
	row:SetScript("OnLeave", function() FK.Theme.SetTextColor(text, FK.Theme.colors.text) end)
	-- The handler is read off the row rather than captured, because these rows
	-- are pooled: row 1 is created by the "none heard of yet" branch with a
	-- no-op, and would have kept it for the rest of the session once real camps
	-- arrived, leaving the tab's only action silently dead.
	row.onClick = onClick
	row:SetScript("OnClick", function()
		if row.onClick then
			row.onClick(row.camp)
		end
	end)

	tab.campRows[index] = row
	return row
end

local function buildFindTab(parent)
	local tab = CreateFrame("Frame", nil, parent)
	tab:SetAllPoints()
	tab.campRows = {}

	local heading = FK.Theme.Label(tab, "GameFontNormalSmall", FK.Theme.colors.gold)
	heading:SetPoint("TOPLEFT", 0, 0)
	heading:SetText("Camps people are hosting")

	-- The guildie half is plain text; only the camps do something when clicked.
	local guildHolder = CreateFrame("Frame", nil, tab)
	guildHolder:SetPoint("TOPLEFT", 0, -140)
	guildHolder:SetPoint("BOTTOMRIGHT", 0, 50)
	local list = lineList(guildHolder)

	local host = FK.Theme.Button(tab, "Host this fire", 120, function()
		if FK.Discovery.hosting then
			FK.Discovery:StopHosting()
			FK.Print("packed up.")
		else
			local ok, err = FK.Discovery:StartHosting()
			FK.Print(ok and "hosting: people running Firekeeper can find this fire."
				or ("|cffff4040%s|r"):format(err or "could not host"))
		end
		FK.UI:Refresh()
	end)
	host:SetPoint("BOTTOMLEFT", 0, 0)
	tab.host = host

	local look = FK.Theme.Button(tab, "Look for camps", 120, function()
		FK.Discovery:Seek()
		FK.UI:Refresh()
	end)
	look:SetPoint("BOTTOM", 0, 0)

	local share = FK.Theme.Toggle(tab, "Share my position with my guild",
		function() return FK.db.shareWithGuild end,
		function(on) FK.Discovery:SetSharing(on) end)
	share:SetPoint("BOTTOMLEFT", 0, 26)
	share:SetPoint("RIGHT", tab, "RIGHT", 0, 0)
	tab.share = share

	local function waypoint(camp)
		if not camp then
			return
		end
		if FK.Discovery.Waypoint(camp) then
			FK.Print("waypoint set on %s's camp.", camp.host)
		else
			FK.Print("%s's camp is at |cffffff00%.0f, %.0f|r (no waypoint on this client).",
				camp.host, camp.x * 100, camp.y * 100)
		end
	end

	function tab:Refresh()
		host.text:SetText(FK.Discovery.hosting and "Stop hosting" or "Host this fire")
		share:Refresh()

		local found = FK.Discovery.Found()
		local shown = math.min(#found, 7)
		for index = 1, math.max(#self.campRows, math.max(shown, 1)) do
			local camp = found[index]
			if camp then
				local row = actionRow(self, index, waypoint)
				row.camp = camp
				local where = camp.sameMap and ("%.0f, %.0f"):format(camp.x * 100, camp.y * 100)
					or "another map"
				if camp.otherLayer then
					where = where .. colored("ff8c38", " (another layer)")
				end
				row.text:SetText(("  %s — %d of %d free, %s"):format(
					camp.host, camp.free, camp.slots, where))
				FK.Theme.SetTextColor(row.text, FK.Theme.colors.text)
				row:Show()
			elseif index == 1 then
				local row = actionRow(self, index, function() end)
				row.camp = nil
				row.text:SetText(colored("8a8a8a", "  none heard of yet"))
				row:Show()
			elseif self.campRows[index] then
				self.campRows[index]:Hide()
			end
		end

		local lines = { colored("fad161", "Guildies nearby") }
		local guildies = FK.Discovery.Guildies()
		if #guildies == 0 then
			table.insert(lines, colored("8a8a8a", "  nobody is sharing"))
		else
			for _, entry in ipairs(guildies) do
				table.insert(lines, "  " .. FK.Nearby.Line(entry, FK.Discovery.ZoneName(entry.uiMapID)))
			end
		end

		list:Set(lines, 0)
	end

	return tab
end

-- Tab: You --------------------------------------------------------------

local function buildYouTab(parent)
	local tab = CreateFrame("Frame", nil, parent)
	tab:SetAllPoints()
	tab.rows = {}
	local list = lineList(tab)

	local y = 0
	local function nextY(height)
		local at = y
		y = y + height
		return -at
	end

	local fieldGuide = FK.Theme.NumberRow(tab, "Legacy: Field Guide rank",
		function() return FK.db.legacy.fieldGuide end,
		function(value)
			FK.db.legacy.fieldGuide = math.max(math.floor(value), 0)
			FK.Print("Field Guide rank %d. Cooldown is now %s.", FK.db.legacy.fieldGuide,
				FK.Cooldowns.Format(FK.Cooldowns.Duration(FK.db.legacy)))
		end)
	fieldGuide:SetPoint("TOPLEFT", 0, nextY(22))
	fieldGuide:SetPoint("RIGHT", tab, "RIGHT", 0, 0)
	tab.fieldGuide = fieldGuide

	local permanence = FK.Theme.NumberRow(tab, "Legacy: Permanence rank",
		function() return FK.db.legacy.permanence end,
		function(value) FK.db.legacy.permanence = math.max(math.floor(value), 0) end)
	permanence:SetPoint("TOPLEFT", 0, nextY(24))
	permanence:SetPoint("RIGHT", tab, "RIGHT", 0, 0)
	tab.permanence = permanence

	local minimap = FK.Theme.Toggle(tab, "Show the minimap button",
		function() return not FK.db.minimap.hide end,
		function(on) FK.MinimapButton:SetShown(on) end)
	minimap:SetPoint("TOPLEFT", 0, nextY(20))
	minimap:SetPoint("RIGHT", tab, "RIGHT", 0, 0)
	tab.minimap = minimap

	local debugToggle = FK.Theme.Toggle(tab, "Print debug messages",
		function() return FK.db.debug end,
		function(on) FK.db.debug = on end)
	debugToggle:SetPoint("TOPLEFT", 0, nextY(22))
	debugToggle:SetPoint("RIGHT", tab, "RIGHT", 0, 0)
	tab.debugToggle = debugToggle

	-- Setting a profession by hand is the fallback for when the game will not
	-- tell us, which is exactly the moment you should not have to go and find a
	-- slash command. The name cycles rather than being typed, because there are
	-- only twelve of them and none of them is worth misspelling.
	local chosen = 1
	local setter = CreateFrame("Frame", nil, tab)
	setter:SetHeight(20)
	setter:SetPoint("TOPLEFT", 0, nextY(26))
	setter:SetPoint("RIGHT", tab, "RIGHT", 0, 0)

	local label = FK.Theme.Label(setter, "GameFontHighlightSmall", FK.Theme.colors.text)
	label:SetPoint("LEFT", 0, 0)
	label:SetText("Set a profession")

	local professionButton = FK.Theme.Button(setter, FK.Data.professions[chosen], 104, nil)
	professionButton:SetHeight(18)
	professionButton:SetPoint("LEFT", 104, 0)
	professionButton:SetScript("OnClick", function()
		chosen = chosen % #FK.Data.professions + 1
		professionButton.text:SetText(FK.Data.professions[chosen])
	end)

	local skill = CreateFrame("EditBox", nil, setter)
	skill:SetSize(40, 18)
	skill:SetPoint("LEFT", professionButton, "RIGHT", 6, 0)
	skill:SetAutoFocus(false)
	skill:SetNumeric(true)
	skill:SetMaxLetters(3)
	skill:SetFontObject("GameFontHighlightSmall")
	skill:SetTextInsets(4, 4, 0, 0)
	local skillFill = FK.Theme.Fill(skill, "BACKGROUND", FK.Theme.colors.ash)
	skillFill:SetAllPoints()
	FK.Theme.Border(skill, FK.Theme.colors.emberDim, 0.8)

	local function applyProfession()
		local value = tonumber(skill:GetText())
		if value then
			local profession = FK.Data.professions[chosen]
			FK.Professions:Set(profession, value)
			FK.Print("%s set to %d.", profession, value)
			if FK.Comm then
				FK.Comm:Announce(true)
			end
		end
		skill:ClearFocus()
		FK.UI:Refresh()
	end

	skill:SetScript("OnEnterPressed", applyProfession)
	skill:SetScript("OnEscapePressed", function() skill:ClearFocus() end)

	local apply = FK.Theme.Button(setter, "Set", 40, applyProfession)
	apply:SetHeight(18)
	apply:SetPoint("LEFT", skill, "RIGHT", 6, 0)
	tab.professionSetter = setter
	tab.professionName = professionButton
	tab.professionSkill = skill

	tab.listTop = y

	function tab:Refresh()
		fieldGuide:Refresh()
		permanence:Refresh()
		minimap:Refresh()
		debugToggle:Refresh()

		local lines = { colored("fad161", "Your professions") }
		local entries = FK.Route.Evaluate(FK.Professions.known)
		if #entries == 0 then
			table.insert(lines, colored("8a8a8a", "  none detected — set one above"))
		else
			for _, entry in ipairs(entries) do
				table.insert(lines, "  " .. FK.Route.Line(entry))
			end
		end

		table.insert(lines, " ")
		table.insert(lines, colored("fad161", "Camp cooldowns"))
		local now = time and time() or 0
		local any = false
		for key in pairs(FK.db.characters) do
			any = true
			table.insert(lines, ("  %s: %s"):format(key, FK.Cooldowns.Format(
				FK.Cooldowns.ForCharacter(key, now))))
		end
		if not any then
			table.insert(lines, colored("8a8a8a", "  nothing placed yet this session"))
		end

		table.insert(lines, " ")
		table.insert(lines, colored("fad161", "This client"))

		-- Only what is refused, plus a count. The full list ran to two dozen
		-- lines and was silently cut off by the space available; `/fk caps`
		-- still prints all of it, and it is written to the saved variables
		-- either way.
		local refused, total = {}, 0
		for name in pairs(FK.Capabilities.results) do
			total = total + 1
			if not FK.Capabilities.Has(name) then
				table.insert(refused, name)
			end
		end
		table.sort(refused)

		if total == 0 then
			table.insert(lines, colored("8a8a8a", "  not probed yet"))
		elseif #refused == 0 then
			table.insert(lines, colored("73d957",
				("  all %d checks passed"):format(total)))
		else
			table.insert(lines, colored("8a8a8a",
				("  %d of %d checks passed. Not allowed here:"):format(total - #refused, total)))
			for _, name in ipairs(refused) do
				table.insert(lines, colored("ff5450", "    " .. name))
			end
		end

		for _, limitation in ipairs(FK.Capabilities.Limitations()) do
			table.insert(lines, colored("8a8a8a", "  " .. limitation))
		end

		local unknown = FK.Data.UnknownEffects()
		if #unknown > 0 then
			table.insert(lines, colored("8a8a8a",
				("  %d camp objects still have no known effect"):format(#unknown)))
		end

		list:Set(lines, self.listTop)
	end

	return tab
end

-- The panel -------------------------------------------------------------

local function createFrame()
	local Theme = FK.Theme
	local frame = Theme.Panel("FirekeeperCampFrame", WIDTH, HEIGHT, "Firekeeper", "panelPosition")

	local header = Theme.Label(frame, "GameFontNormalSmall", Theme.colors.text)
	header:SetPoint("TOPLEFT", 14, -36)
	frame.header = header

	local pipRow = CreateFrame("Frame", nil, frame)
	pipRow:SetPoint("TOPLEFT", 14, -54)
	pipRow:SetHeight(PIP_SIZE)
	frame.pipRow = pipRow
	frame.pips = {}

	-- Actions that are worth one click from anywhere, mirrored by labelled
	-- buttons inside the tabs so a missing texture never hides a feature.
	local actions = {
		{ "Interface\\Icons\\INV_Misc_Note_01", "Announce", "Post this camp to chat",
			function() FK.Camp:Announce() end },
		{ "Interface\\Icons\\INV_Misc_Map_01", "Find camps", "Ask who is hosting a fire nearby",
			function() FK.Discovery:Seek() FK.UI:Refresh() end },
		{ "Interface\\Icons\\Spell_Fire_Fire", "New camp", "Start a fresh three-slot camp",
			function() FK.Camp:Reset() FK.UI:Refresh() end },
	}
	local x = -8
	for _, action in ipairs(actions) do
		local button = Theme.IconButton(frame.titleBar, action[1], action[2], action[3], action[4])
		button:SetPoint("RIGHT", frame.closeButton, "LEFT", x, 0)
		x = x - 24
	end

	local rule = Theme.Line(frame, Theme.colors.emberDim, 0.5)
	rule:SetPoint("TOPLEFT", 14, -70)
	rule:SetPoint("TOPRIGHT", -14, -70)
	rule:SetHeight(1)

	local body = CreateFrame("Frame", nil, frame)
	body:SetPoint("TOPLEFT", 14, -100)
	body:SetPoint("BOTTOMRIGHT", -14, 16)
	frame.body = body

	frame.tabFrames = {}
	local strip = Theme.Tabs(frame, TABS, function(name)
		for tabName, tabFrame in pairs(frame.tabFrames) do
			tabFrame:SetShown(tabName == name)
		end
		if frame:IsShown() then
			FK.UI:Refresh()
		end
	end)
	strip:SetPoint("TOPLEFT", 14, -76)

	frame.tabFrames.Camp = buildCampTab(body)
	frame.tabFrames.Place = buildPlaceTab(body)
	frame.tabFrames.Buffs = buildBuffsTab(body)
	frame.tabFrames.Find = buildFindTab(body)
	frame.tabFrames.You = buildYouTab(body)

	frame.strip = strip
	strip:Select("Camp")
	return frame
end

function UI:Refresh()
	local frame = self.frame
	if not frame or not frame:IsShown() then
		return
	end

	-- Planned once here and handed to the tab. Each tab used to plan again, and
	-- `SuggestionForSelf` a third time, so a single refresh re-planned the camp
	-- three times and re-read every unit's auras with it.
	local plan = FK.Camp:Plan()
	frame.header:SetText(("%d of %d slots used"):format(plan.used, plan.capacity))
	updatePips(frame, plan.used, plan.capacity)

	local tabName = frame.strip.selected
	local current = frame.tabFrames[tabName]
	if current and current.Refresh then
		local ok, err = pcall(current.Refresh, current, plan)
		if not ok then
			FK.Debug("the %s tab failed to draw: %s", tostring(tabName), tostring(err))
			-- Debug is off by default, so without this a broken tab shows stale
			-- content and says nothing at all. Once per tab, not every tick.
			frame.reportedFailure = frame.reportedFailure or {}
			if not frame.reportedFailure[tabName] then
				frame.reportedFailure[tabName] = true
				FK.Print("|cffff4040the %s tab hit an error and may be out of date|r", tabName)
			end
		end
	end
end

function UI:Toggle()
	if not self.frame then
		if not FK.Theme then
			FK.Print("|cffff4040the UI theme did not load; the panel cannot be drawn|r")
			FK.Diag("panel", "no FK.Theme")
			return
		end
		local ok, frameOrErr = pcall(createFrame)
		if not ok then
			FK.Print("|cffff4040the panel failed to draw:|r %s", tostring(frameOrErr))
			FK.Diag("panel", "failed: " .. tostring(frameOrErr))
			return
		end
		self.frame = frameOrErr
		FK.Diag("panel", "drawn")
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
