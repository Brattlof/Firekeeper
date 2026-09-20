-- Just enough of the WoW client to run the parts of Firekeeper that draw
-- frames or read units.
--
-- `tests/run.lua` covers the pure modules, which is most of the planning. It
-- cannot reach `UI/` or the unit scanning in `Core/Roster.lua` and
-- `Core/Auras.lua`, and those are where the defects with the worst symptoms
-- have been: a tab that silently drew nothing, a raid missing its last member,
-- a unit name used as a table key when the client had made it secret.
--
-- The rule that makes this worth having: **an unknown method call is an
-- error**. A mock that quietly accepts anything proves nothing, because the
-- typo it was meant to catch sails straight through.
local Mock = {}

local FRAME_METHODS = {
	"SetSize", "SetPoint", "SetAllPoints", "ClearAllPoints", "SetFrameStrata",
	"SetFrameLevel", "EnableMouse", "SetMovable", "SetClampedToScreen",
	"RegisterForDrag", "RegisterForClicks", "StartMoving", "StopMovingOrSizing",
	"SetWidth", "SetHeight", "Raise", "SetAlpha", "SetScale", "SetParent",
	"SetTextColor", "SetJustifyH", "SetTexture", "SetColorTexture",
	"SetTexCoord", "SetVertexColor", "SetDrawLayer", "SetBlendMode",
	"SetDesaturated", "SetAutoFocus", "SetNumeric", "SetMaxLetters",
	"SetFontObject", "SetTextInsets", "ClearFocus", "SetFocus", "HighlightText",
	"SetHitRectInsets", "SetIgnoreParentScale",
}

--- A frame, texture or font string. Anything not listed above raises, which is
-- the whole point.
function Mock.widget(kind, name, counters)
	local self = { __kind = kind, __name = name, __shown = false, __scripts = {} }

	function self.Show(s) s.__shown = true end
	function self.Hide(s) s.__shown = false end
	function self.SetShown(s, shown) s.__shown = shown and true or false end
	function self.IsShown(s) return s.__shown end
	function self.GetHeight() return 220 end
	function self.GetWidth() return 140 end
	function self.GetCenter() return 400, 300 end
	function self.GetEffectiveScale() return 1 end
	function self.GetFrameLevel() return 3 end
	function self.GetPoint() return "CENTER", nil, "CENTER", 12, -8 end
	function self.GetStringWidth() return 40 end
	function self.SetText(s, value) s.__text = tostring(value) end
	function self.GetText(s) return s.__text or "0" end
	function self.SetScript(s, event, handler) s.__scripts[event] = handler end
	function self.GetScript(s, event) return s.__scripts[event] end

	function self.CreateTexture(_, _, layer)
		counters.textures = counters.textures + 1
		return Mock.widget("Texture", "texture:" .. tostring(layer), counters)
	end
	function self.CreateFontString(_, _, _, font)
		counters.fontStrings = counters.fontStrings + 1
		return Mock.widget("FontString", "fontstring:" .. tostring(font), counters)
	end

	for _, method in ipairs(FRAME_METHODS) do
		if self[method] == nil then
			self[method] = function() end
		end
	end

	-- Unknown keys: raise for anything that looks like a widget method, return
	-- nil for anything that looks like a field.
	--
	-- Addons hang their own data on frames — `button.reason`, `row.camp` — and
	-- reading one that was never set is ordinary Lua that returns nil, so a mock
	-- that raises on it reports bugs that are not there. Blizzard's widget
	-- methods are PascalCase and this addon's own fields are not, which is a
	-- good enough line to draw: a mistyped `SetPointt` still raises, while
	-- `button.reason` behaves the way the client would.
	return setmetatable(self, {
		__index = function(_, key)
			local text = tostring(key)
			if text:match("^%u") then
				error(("%s (%s) has no method %q"):format(name or "?", kind, text), 2)
			end
			return nil
		end,
	})
end

--- Installs the client globals the addon touches.
--
-- `world` describes the group: `{ inRaid = false, count = 0, secretUnits = {},
-- names = {} }`. It is returned so a test can change it between calls.
function Mock.install(world)
	world = world or {}
	world.count = world.count or 0
	world.secretUnits = world.secretUnits or {}
	world.names = world.names or {}

	local counters = { frames = 0, textures = 0, fontStrings = 0, templates = 0 }
	local secret = setmetatable({}, { __tostring = function() return "<secret>" end })

	_G.issecretvalue = function(value) return value == secret end
	_G.UIParent = Mock.widget("Frame", "UIParent", counters)
	_G.Minimap = Mock.widget("Minimap", "Minimap", counters)
	_G.GameTooltip = setmetatable({
		SetOwner = function() end, AddLine = function() end,
		Show = function() end, Hide = function() end,
	}, { __index = function(_, k) error("GameTooltip has no method " .. tostring(k), 2) end })

	_G.CreateFrame = function(kind, name, _, template)
		counters.frames = counters.frames + 1
		if template then
			counters.templates = counters.templates + 1
		end
		return Mock.widget(kind, name or ("anon:" .. kind), counters)
	end

	_G.GetCursorPosition = function() return 470, 250 end
	_G.GetNumGroupMembers = function() return world.count end
	_G.IsInRaid = function() return world.inRaid end
	_G.IsInGroup = function() return world.count > 0 end
	_G.IsInGuild = function() return true end
	_G.GetRealmName = function() return "Forever" end
	_G.GetTime = function() return 1000 end
	_G.UnitClass = function() return "Mage", "MAGE" end
	_G.UnitGUID = function() return "Creature-0-3893-1-146-448-00008" end
	_G.UnitPlayerControlled = function() return false end
	_G.UnitIsPlayer = function() return false end
	_G.Ambiguate = function(name) return name end

	_G.UnitExists = function(unit)
		if unit == "player" then return true end
		local index = tonumber(tostring(unit):match("%d+$"))
		if not index then return false end
		local limit = world.inRaid and world.count or math.max(world.count - 1, 0)
		return index <= limit
	end

	_G.UnitName = function(unit)
		if world.secretUnits[unit] then return secret, secret end
		if unit == "player" then return "Ana", "" end
		return world.names[unit] or unit, ""
	end

	_G.C_Timer = {
		NewTicker = function() return { Cancel = function() end } end,
		After = function() end,
	}
	_G.C_Item = { GetItemIconByID = function() return "Interface\\Icons\\INV_Misc_Bag_08" end }
	_G.C_UnitAuras = { GetAuraDataByIndex = function() return nil end }
	_G.time = _G.time or function() return 1758000000 end

	return { world = world, counters = counters, secret = secret }
end

--- The scaffolding `Core/Init.lua` would normally provide. Init itself cannot
-- be loaded here because it creates a real frame the moment it is read.
function Mock.newFK()
	local FK = { modules = {}, debugLines = {} }

	FK.RegisterModule = function(_, module) return module end
	FK.Print = function() end
	FK.Debug = function(message, ...)
		local ok, formatted = pcall(string.format, message, ...)
		table.insert(FK.debugLines, ok and formatted or tostring(message))
	end
	FK.Diag = function(key, value) FK.diagnostics[key] = value end
	FK.IsSecret = function(value)
		local ok, isSecret = pcall(_G.issecretvalue, value)
		return ok and isSecret == true
	end

	FK.diagnostics = {}
	FK.db = {
		debug = false,
		minimap = { angle = 200, hide = false },
		panelPosition = {},
		legacy = { fieldGuide = 0, permanence = 0 },
		characters = {},
		optionalBuffs = {},
		shareWithGuild = false,
		diagnostics = {},
	}
	FK.charDb = {}
	FK.version = "test"
	FK.eventFrame = { RegisterEvent = function() end, HookScript = function() end }

	return FK
end

--- Loads an addon file into `FK`, the way the game loads it.
function Mock.load(FK, root, path)
	local chunk = assert(loadfile(root .. "/" .. path))
	return chunk("Firekeeper", FK)
end

return Mock
