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
