local _, FK = ...

-- A button on the minimap, written by hand.
--
-- The usual way to do this is LibDBIcon, but this addon takes no libraries
-- (CONTRIBUTING.md), and the whole thing is one texture, one ring and a little
-- trigonometry. Every call it makes is guarded: the minimap is a frame the
-- client provides, and if a future build moves or renames it the button simply
-- does not appear rather than breaking login (docs/RESEARCH.md, FK-13).
local MinimapButton = FK.RegisterModule("MinimapButton", {})
FK.MinimapButton = MinimapButton

local SIZE = 31
local RING = "Interface\\Minimap\\MiniMap-TrackingBorder"

local function minimapRadius()
	local width = Minimap.GetWidth and Minimap:GetWidth() or 140
	-- Just outside the edge, which is where every other addon's button sits.
	return (width / 2) + 5
end

--- Puts the button at `angle` degrees around the minimap.
local function place(button, angle)
	local radian = math.rad(angle or 200)
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER",
		math.cos(radian) * minimapRadius(),
		math.sin(radian) * minimapRadius())
end

--- The angle from the minimap's centre to the cursor, which is all a drag is.
local function angleToCursor()
	local centerX, centerY = Minimap:GetCenter()
	if not centerX then
		return nil
	end
	local scale = Minimap:GetEffectiveScale()
	if not scale or scale == 0 then
		return nil
	end
	local cursorX, cursorY = GetCursorPosition()
	return math.deg(math.atan2((cursorY / scale) - centerY, (cursorX / scale) - centerX))
end

local function tooltip(button)
	if not GameTooltip then
		return
	end
	GameTooltip:SetOwner(button, "ANCHOR_LEFT")
	GameTooltip:AddLine("Firekeeper", 1, 0.55, 0.22)

	-- A camp summary, so the button answers the question without a click.
	local ok, plan = pcall(function() return FK.Camp:Plan() end)
	if ok and plan then
		GameTooltip:AddLine(("%d of %d slots used"):format(plan.used, plan.capacity), 0.92, 0.90, 0.86)
		if #plan.suggestions > 0 then
			GameTooltip:AddLine(("%d suggestion%s waiting"):format(
				#plan.suggestions, #plan.suggestions == 1 and "" or "s"), 0.98, 0.82, 0.38)
		end
	end

	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Left click: open the camp panel", 0.62, 0.60, 0.57)
	GameTooltip:AddLine("Right click: print the plan to chat", 0.62, 0.60, 0.57)
	GameTooltip:AddLine("Drag: move this button", 0.62, 0.60, 0.57)
	GameTooltip:Show()
end

function MinimapButton:Create()
	if self.button or not Minimap then
		return self.button
	end

	local button = CreateFrame("Button", "FirekeeperMinimapButton", Minimap)
	button:SetSize(SIZE, SIZE)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(20, 20)
	icon:SetPoint("CENTER", 0, 1)
	icon:SetTexture(FK.Theme.ICON)
	-- Crop the icon's own border off so it sits inside the ring.
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	button.icon = icon

	local ring = button:CreateTexture(nil, "OVERLAY")
	ring:SetSize(53, 53)
	ring:SetPoint("TOPLEFT")
	ring:SetTexture(RING)
	button.ring = ring

	button:SetScript("OnEnter", function() tooltip(button) end)
	button:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)

	button:SetScript("OnClick", function(_, mouseButton)
		if mouseButton == "RightButton" then
			FK.Commands.Run("plan")
		else
			FK.UI:Toggle()
		end
	end)

	-- Dragging: follow the cursor around the ring, and remember where it was
	-- let go of.
	button:SetScript("OnDragStart", function()
		button.dragging = true
		button:SetScript("OnUpdate", function()
			local angle = angleToCursor()
			if angle then
				place(button, angle)
				FK.db.minimap.angle = angle
			end
		end)
	end)
	button:SetScript("OnDragStop", function()
		button.dragging = false
		button:SetScript("OnUpdate", nil)
	end)

	place(button, FK.db.minimap.angle)
	self.button = button
	return button
end

--- Shows or hides the button, remembering the choice.
function MinimapButton:SetShown(shown)
	FK.db.minimap.hide = not shown
	local button = self:Create()
	if not button then
		return false
	end
	if shown then
		button:Show()
	else
		button:Hide()
	end
	return true
end

function MinimapButton:OnLogin()
	if not Minimap then
		FK.Debug("no Minimap frame; skipping the minimap button")
		return
	end
	local ok, err = pcall(function()
		self:Create()
		if FK.db.minimap.hide then
			self.button:Hide()
		end
	end)
	if not ok then
		FK.Debug("minimap button failed to draw: %s", tostring(err))
	end
end
