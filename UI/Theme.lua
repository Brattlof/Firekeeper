local _, FK = ...

-- The look of the addon, in one place so the panel and the minimap button
-- cannot drift apart.
--
-- Everything here is drawn from solid colour textures and font strings rather
-- than Blizzard's frame templates. That is not stubbornness: it keeps the
-- addon's own look, and it means a template or backdrop this client happens
-- not to ship cannot stop the UI from drawing (docs/RESEARCH.md, FK-6).
local Theme = {}
FK.Theme = Theme

-- Embers on charcoal. `ember` is the one accent; everything else is a shade of
-- the fire going out.
Theme.colors = {
	ember      = { 1.00, 0.55, 0.22 },
	emberDim   = { 0.55, 0.28, 0.10 },
	ash        = { 0.06, 0.055, 0.05 },
	ashLight   = { 0.11, 0.10, 0.09 },
	charcoal   = { 0.02, 0.02, 0.02 },
	smoke      = { 0.62, 0.60, 0.57 },
	text       = { 0.92, 0.90, 0.86 },
	gold       = { 0.98, 0.82, 0.38 },
	green      = { 0.45, 0.85, 0.40 },
	red        = { 0.90, 0.32, 0.28 },
}

Theme.ICON = "Interface\\Icons\\Spell_Fire_Fire"

--- A flat colour texture. SetColorTexture is the modern call; the fallback
-- keeps a very old client from erroring on a decoration.
function Theme.Fill(parent, layer, color, alpha)
	local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
	local r, g, b = color[1], color[2], color[3]
	if texture.SetColorTexture then
		texture:SetColorTexture(r, g, b, alpha or 1)
	else
		texture:SetTexture(r, g, b, alpha or 1)
	end
	return texture
end

--- A one pixel line, used for rules and borders.
function Theme.Line(parent, color, alpha)
	return Theme.Fill(parent, "BORDER", color, alpha)
end

--- Wraps a frame in a hairline border, drawn as four edges so there is no
-- backdrop file to be missing.
function Theme.Border(frame, color, alpha)
	local edges = {}
	for _, edge in ipairs({
		{ "TOPLEFT", "TOPRIGHT", "top" },
		{ "BOTTOMLEFT", "BOTTOMRIGHT", "bottom" },
		{ "TOPLEFT", "BOTTOMLEFT", "left" },
		{ "TOPRIGHT", "BOTTOMRIGHT", "right" },
	}) do
		local line = Theme.Fill(frame, "BORDER", color, alpha)
		line:SetPoint(edge[1])
		line:SetPoint(edge[2])
		if edge[3] == "top" or edge[3] == "bottom" then
			line:SetHeight(1)
		else
			line:SetWidth(1)
		end
		edges[edge[3]] = line
	end
	return edges
end

local function setTextColor(fontString, color)
	fontString:SetTextColor(color[1], color[2], color[3])
end

Theme.SetTextColor = setTextColor

--- A label. `font` is a Blizzard font object name; they are all guaranteed
-- because the game's own chat uses them.
function Theme.Label(parent, font, color, justify)
	local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
	setTextColor(text, color or Theme.colors.text)
	text:SetJustifyH(justify or "LEFT")
	return text
end

--- A button in the addon's own style: flat, bordered, and it warms up under
-- the cursor rather than lighting up like a Blizzard panel button.
function Theme.Button(parent, label, width, onClick)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width or 130, 22)

	local background = Theme.Fill(button, "BACKGROUND", Theme.colors.ashLight)
	background:SetAllPoints()
	button.background = background

	Theme.Border(button, Theme.colors.emberDim, 0.8)

	local text = Theme.Label(button, "GameFontHighlightSmall", Theme.colors.text, "CENTER")
	text:SetPoint("CENTER")
	text:SetText(label)
	button.text = text

	button:SetScript("OnEnter", function()
		if background.SetColorTexture then
			local c = Theme.colors.emberDim
			background:SetColorTexture(c[1], c[2], c[3], 1)
		end
		setTextColor(text, Theme.colors.gold)
	end)
	button:SetScript("OnLeave", function()
		if background.SetColorTexture then
			local c = Theme.colors.ashLight
			background:SetColorTexture(c[1], c[2], c[3], 1)
		end
		setTextColor(text, Theme.colors.text)
	end)
	button:SetScript("OnMouseDown", function() text:SetPoint("CENTER", 1, -1) end)
	button:SetScript("OnMouseUp", function() text:SetPoint("CENTER", 0, 0) end)

	if onClick then
		button:SetScript("OnClick", onClick)
	end
	return button
end

--- A small square button carrying an icon, with a tooltip.
--
-- Every action one of these performs is also a labelled button or a row inside
-- a tab, so a texture this client happens not to have leaves a blank square
-- rather than an unreachable feature.
function Theme.IconButton(parent, texture, tooltipTitle, tooltipLine, onClick)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(22, 22)

	local background = Theme.Fill(button, "BACKGROUND", Theme.colors.ashLight)
	background:SetAllPoints()

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", 2, -2)
	icon:SetPoint("BOTTOMRIGHT", -2, 2)
	icon:SetTexture(texture)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	button.icon = icon

	local edges = Theme.Border(button, Theme.colors.emberDim, 0.8)

	button:SetScript("OnEnter", function()
		for _, line in pairs(edges) do
			line:SetColorTexture(Theme.colors.ember[1], Theme.colors.ember[2], Theme.colors.ember[3], 1)
		end
		if GameTooltip then
			GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
			GameTooltip:AddLine(tooltipTitle, 1, 0.55, 0.22)
			if tooltipLine then
				GameTooltip:AddLine(tooltipLine, 0.62, 0.60, 0.57, true)
			end
			GameTooltip:Show()
		end
	end)
	button:SetScript("OnLeave", function()
		for _, line in pairs(edges) do
			line:SetColorTexture(Theme.colors.emberDim[1], Theme.colors.emberDim[2], Theme.colors.emberDim[3], 0.8)
		end
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	if onClick then
		button:SetScript("OnClick", onClick)
	end
	return button
end

--- A row of tabs across the top of a panel's body.
--
-- `names` is the order they appear in. `onSelect` is called with the name when
-- one is clicked, and once immediately for the first.
function Theme.Tabs(parent, names, onSelect)
	local strip = CreateFrame("Frame", nil, parent)
	strip:SetHeight(20)
	strip.buttons = {}

	local function select(name)
		for tabName, button in pairs(strip.buttons) do
			local chosen = tabName == name
			button.underline:SetShown(chosen)
			Theme.SetTextColor(button.text, chosen and Theme.colors.ember or Theme.colors.smoke)
		end
		strip.selected = name
		onSelect(name)
	end

	local x = 0
	for _, name in ipairs(names) do
		local button = CreateFrame("Button", nil, strip)
		local text = Theme.Label(button, "GameFontNormalSmall", Theme.colors.smoke, "CENTER")
		text:SetPoint("CENTER")
		text:SetText(name)
		button.text = text

		local width = math.max(text:GetStringWidth() + 16, 44)
		button:SetSize(width, 20)
		button:SetPoint("LEFT", x, 0)
		x = x + width

		local underline = Theme.Fill(button, "ARTWORK", Theme.colors.ember)
		underline:SetPoint("BOTTOMLEFT", 4, 0)
		underline:SetPoint("BOTTOMRIGHT", -4, 0)
		underline:SetHeight(2)
		underline:Hide()
		button.underline = underline

		button:SetScript("OnClick", function() select(name) end)
		button:SetScript("OnEnter", function()
			if strip.selected ~= name then
				Theme.SetTextColor(text, Theme.colors.text)
			end
		end)
		button:SetScript("OnLeave", function()
			if strip.selected ~= name then
				Theme.SetTextColor(text, Theme.colors.smoke)
			end
		end)

		strip.buttons[name] = button
	end

	strip:SetWidth(x)
	strip.Select = function(_, name) select(name) end
	select(names[1])
	return strip
end

--- A labelled on/off row. `getter` is asked every refresh, so the row cannot
-- drift from the setting it shows.
function Theme.Toggle(parent, label, getter, setter)
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(18)

	local box = CreateFrame("Frame", nil, row)
	box:SetSize(12, 12)
	box:SetPoint("LEFT", 0, 0)
	local fill = Theme.Fill(box, "ARTWORK", Theme.colors.ash)
	fill:SetAllPoints()
	Theme.Border(box, Theme.colors.emberDim, 0.9)

	local text = Theme.Label(row, "GameFontHighlightSmall", Theme.colors.text)
	text:SetPoint("LEFT", box, "RIGHT", 6, 0)
	text:SetText(label)

	function row:Refresh()
		local on = getter() and true or false
		local colour = on and Theme.colors.ember or Theme.colors.ash
		fill:SetColorTexture(colour[1], colour[2], colour[3], 1)
		Theme.SetTextColor(text, on and Theme.colors.text or Theme.colors.smoke)
	end

	row:SetScript("OnClick", function()
		setter(not getter())
		row:Refresh()
	end)
	row:SetScript("OnEnter", function() Theme.SetTextColor(text, Theme.colors.gold) end)
	row:SetScript("OnLeave", function() row:Refresh() end)
	row:Refresh()
	return row
end

--- A labelled box the player can type a number into, with a Set button.
function Theme.NumberRow(parent, label, getter, setter)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(20)

	local text = Theme.Label(row, "GameFontHighlightSmall", Theme.colors.text)
	text:SetPoint("LEFT", 0, 0)
	text:SetText(label)

	local box = CreateFrame("EditBox", nil, row)
	box:SetSize(46, 18)
	box:SetPoint("LEFT", 150, 0)
	box:SetAutoFocus(false)
	box:SetNumeric(true)
	box:SetMaxLetters(4)
	box:SetFontObject("GameFontHighlightSmall")
	box:SetTextInsets(4, 4, 0, 0)
	local boxFill = Theme.Fill(box, "BACKGROUND", Theme.colors.ash)
	boxFill:SetAllPoints()
	Theme.Border(box, Theme.colors.emberDim, 0.8)

	local function commit()
		local value = tonumber(box:GetText())
		if value then
			setter(value)
		end
		box:ClearFocus()
		row:Refresh()
	end

	box:SetScript("OnEnterPressed", commit)
	box:SetScript("OnEscapePressed", function()
		box:ClearFocus()
		row:Refresh()
	end)

	local set = Theme.Button(row, "Set", 40, commit)
	set:SetHeight(18)
	set:SetPoint("LEFT", box, "RIGHT", 6, 0)

	function row:Refresh()
		box:SetText(tostring(getter() or 0))
	end

	row:Refresh()
	return row
end

--- A panel: charcoal, hairline bordered, with a title bar carrying the addon's
-- icon, a title, and a close button. Draggable, and it remembers where it was
-- put if `positionKey` names a table in the saved variables.
function Theme.Panel(name, width, height, title, positionKey)
	local frame = CreateFrame("Frame", name, UIParent)
	frame:SetSize(width, height)
	frame:SetFrameStrata("MEDIUM")
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:Hide()

	local shadow = Theme.Fill(frame, "BACKGROUND", Theme.colors.charcoal, 0.55)
	shadow:SetPoint("TOPLEFT", -3, 3)
	shadow:SetPoint("BOTTOMRIGHT", 3, -3)

	local background = Theme.Fill(frame, "BACKGROUND", Theme.colors.ash, 0.96)
	background:SetAllPoints()

	Theme.Border(frame, Theme.colors.emberDim, 0.9)

	-- Title bar
	local bar = CreateFrame("Frame", nil, frame)
	bar:SetPoint("TOPLEFT", 1, -1)
	bar:SetPoint("TOPRIGHT", -1, -1)
	bar:SetHeight(26)
	local barFill = Theme.Fill(bar, "BACKGROUND", Theme.colors.ashLight)
	barFill:SetAllPoints()
	local barRule = Theme.Line(bar, Theme.colors.ember, 0.85)
	barRule:SetPoint("BOTTOMLEFT")
	barRule:SetPoint("BOTTOMRIGHT")
	barRule:SetHeight(1)
	frame.titleBar = bar

	local icon = bar:CreateTexture(nil, "ARTWORK")
	icon:SetSize(16, 16)
	icon:SetPoint("LEFT", 7, 0)
	icon:SetTexture(Theme.ICON)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	local titleText = Theme.Label(bar, "GameFontNormal", Theme.colors.ember)
	titleText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
	titleText:SetText(title)
	frame.titleText = titleText

	local close = CreateFrame("Button", nil, bar)
	close:SetSize(20, 20)
	close:SetPoint("RIGHT", -4, 0)
	local closeText = Theme.Label(close, "GameFontNormalLarge", Theme.colors.smoke, "CENTER")
	closeText:SetPoint("CENTER", 0, 0)
	closeText:SetText("×")
	close:SetScript("OnEnter", function() setTextColor(closeText, Theme.colors.red) end)
	close:SetScript("OnLeave", function() setTextColor(closeText, Theme.colors.smoke) end)
	close:SetScript("OnClick", function() frame:Hide() end)
	frame.closeButton = close

	-- Dragging by the bar only, so a click in the body cannot shove the panel.
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function() frame:StartMoving() end)
	bar:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		if positionKey and FK.db then
			local point, _, relativePoint, x, y = frame:GetPoint()
			FK.db[positionKey] = { point = point, relativePoint = relativePoint, x = x, y = y }
		end
	end)

	function frame:RestorePosition()
		local saved = positionKey and FK.db and FK.db[positionKey]
		if saved and saved.point then
			self:ClearAllPoints()
			self:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
		else
			self:ClearAllPoints()
			self:SetPoint("CENTER")
		end
	end

	frame:RestorePosition()
	return frame
end

return Theme
