local addonName, FK = ...

FK.name = addonName
FK.version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version") or "dev"

local PREFIX = "|cffff8a3dFirekeeper|r: "

function FK.Print(message, ...)
	if select("#", ...) > 0 then
		message = message:format(...)
	end
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. message)
end

function FK.Debug(message, ...)
	if not (FirekeeperDB and FirekeeperDB.debug) then
		return
	end
	FK.Print("|cff888888" .. tostring(message) .. "|r", ...)
end

local defaults = {
	debug = false,
	-- Legacy perks change camp maths but cannot be read from the API yet, so
	-- the player tells us their ranks. See docs/RESEARCH.md, question FK-3.
	legacy = {
		fieldGuide = 0, -- shortens the shared object cooldown
		permanence = 0, -- lengthens camp buffs
	},
	-- Off by default: a position is the one genuinely personal thing this
	-- addon can broadcast, so `/fk guild share` has to ask for it.
	shareWithGuild = false,
	-- Class buffs that are off until asked for, by `/fk buffs <key>`.
	optionalBuffs = {},
	-- Per character: when this character last contributed an object.
	characters = {},
}

local function applyDefaults(target, source)
	for key, value in pairs(source) do
		if type(value) == "table" then
			target[key] = type(target[key]) == "table" and target[key] or {}
			applyDefaults(target[key], value)
		elseif target[key] == nil then
			target[key] = value
		end
	end
end

FK.modules = {}

--- Registers a module. `OnLoad` runs once saved variables exist, `OnLogin`
-- once the player is in the world.
function FK.RegisterModule(name, module)
	FK.modules[name] = module
	module.name = name
	return module
end

local function forEachModule(method)
	for name, module in pairs(FK.modules) do
		if type(module[method]) == "function" then
			local ok, err = pcall(module[method], module)
			if not ok then
				FK.Print("|cffff4040%s failed in %s:|r %s", name, method, tostring(err))
			end
		end
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, loadedAddon)
	if event == "ADDON_LOADED" and loadedAddon == addonName then
		FirekeeperDB = FirekeeperDB or {}
		FirekeeperCharDB = FirekeeperCharDB or {}
		applyDefaults(FirekeeperDB, defaults)
		FK.db = FirekeeperDB
		FK.charDb = FirekeeperCharDB
		forEachModule("OnLoad")
	elseif event == "PLAYER_LOGIN" then
		forEachModule("OnLogin")
		FK.Print("loaded (%s). Type |cffffff00/fk|r to open the camp panel.", FK.version)
	end
end)

FK.eventFrame = frame
