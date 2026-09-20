local _, t, root = ...

-- The panel, executed against tests/wowmock.lua.
--
-- It cannot tell you the panel looks right. It can tell you every tab draws,
-- draws twice without leaving stale rows, and that clicking things reaches the
-- addon — which is the half that used to break silently, because `UI:Refresh`
-- wraps each tab in a pcall and a failed tab just does not appear.
local Mock = dofile(root .. "/tests/wowmock.lua")
local tests = {}

local function build()
	local state = Mock.install({ count = 0 })
	local FK = Mock.newFK()

	for _, file in ipairs({
		"Locales/enUS.lua", "Data/BuffGroups.lua", "Data/CampObjects.lua",
		"Data/ClassBuffs.lua", "Core/Wire.lua", "Core/Plan.lua", "Core/Buffs.lua",
		"Core/Cooldowns.lua", "Core/Nearby.lua", "Core/Route.lua",
	}) do
		Mock.load(FK, root, file)
	end

	-- The modules the panel reads but does not draw.
	FK.Roster = {
		SelfKey = function() return "Ana" end,
		Silent = function() return { "Zed" } end,
		Prune = function() end,
		ScanGroup = function() end,
		Coverage = function() return { intellect = "Arcane Intellect" } end,
		Contributors = function()
			return { { name = "Bo", objects = { "lodestone" }, ready = true, readyIn = 0 } }
		end,
	}
	FK.Comm = { Announce = function() end, PREFIX = "FKPR1" }
	FK.Capabilities = {
		results = { addonComm = true, unitAuras = true, mapPosition = false },
		Has = function(name) return FK.Capabilities.results[name] == true end,
		Limitations = function() return { "no saved settings came back from the client" } end,
		Report = function() return { "Firekeeper test on client 1.60.1 (interface 16001)" } end,
	}
	FK.Professions = {
		known = { Blacksmithing = 300, Herbalism = 20 },
		PlaceableObjects = function()
			local out = {}
			for _, id in ipairs({ "sharpening_wheel", "anvil", "master_forge", "incense_candle" }) do
				table.insert(out, FK.Data.GetObject(id))
			end
			return out
		end,
		PlaceableIds = function() return { "anvil" } end,
		Set = function(self, name, skill) self.known[name] = tonumber(skill) end,
	}
	FK.Auras = {
		Missing = function()
			return { members = 2, unreadable = 0, missing = {
				{ key = "intellect", label = "Arcane Intellect", scope = "group",
				  needing = { "Bo" }, providers = { "Ana" } },
			} }
		end,
	}
	FK.Discovery = {
		hosting = false,
		Found = function()
			return { { host = "Cy", free = 2, slots = 3, x = 0.4, y = 0.6,
				sameMap = true, otherLayer = true } }
		end,
		Guildies = function()
			return { { name = "Di", sameMap = true, yards = 140,
				direction = "north-east", uiMapID = 1440 } }
		end,
		Seek = function() return true end,
		StartHosting = function() return true end,
		StopHosting = function() end,
		SetSharing = function(_, on) FK.db.shareWithGuild = on return on end,
		ZoneName = function() return "Elwynn Forest" end,
		Waypoint = function() return true end,
	}
	FK.Camp = {
		placed = { { player = "Ana", objectId = "incense_candle" } },
		slots = 5,
		Plan = function(self)
			return FK.Plan.Evaluate({
				slots = 5, placed = self.placed,
				contributors = {
					{ name = "Bo", objects = { "sharpening_wheel" }, ready = true, readyIn = 0 },
					{ name = "Cy", objects = { "faction_banner" }, ready = false, readyIn = 900 },
				},
			})
		end,
		SuggestionForSelf = function() return nil end,
		MarkPlaced = function() return true end,
		Announce = function() end,
		Reset = function(self, slots) self.slots = slots or 3 end,
	}

	Mock.load(FK, root, "UI/Theme.lua")
	Mock.load(FK, root, "UI/CampFrame.lua")
	Mock.load(FK, root, "UI/MinimapButton.lua")

	FK.UI:Toggle()
	return FK, FK.UI.frame, state
end

function tests.the_panel_draws_at_all()
	local FK, panel, state = build()
	t.isTrue(panel, "the panel was created")
	t.equals(FK.diagnostics.panel, "drawn", "and recorded that it drew")
	t.isTrue(state.counters.frames > 20, "it built frames: " .. state.counters.frames)
	-- The addon's whole look is its own, so FK-6 cannot gate whether it appears.
	t.equals(state.counters.templates, 0, "and used no Blizzard template")
end

function tests.every_tab_draws_twice_without_complaint()
	local FK, panel = build()
	for _, tab in ipairs({ "Camp", "Place", "Buffs", "Find", "You" }) do
		panel.strip:Select(tab)
		FK.UI:Refresh()
		FK.UI:Refresh() -- rows and buttons are pooled, so the second pass matters
		t.isTrue(panel.tabFrames[tab]:IsShown(), tab .. " tab is shown")
	end
	-- `UI:Refresh` swallows a tab's error into FK.Debug, which is exactly how a
	-- broken tab once drew nothing and looked fine.
	t.count(FK.debugLines, 0, "no tab reported a failure: "
		.. table.concat(FK.debugLines, " | "))
end

function tests.the_place_grid_offers_what_you_can_place()
	local FK, panel = build()
	panel.strip:Select("Place")
	FK.UI:Refresh()

	local place = panel.tabFrames.Place
	t.count(place.buttons, 4, "one button per placeable object")
	t.isTrue(place.buttons[1].object, "and each carries its object")

	place.buttons[1].__scripts.OnEnter()
	place.buttons[1].__scripts.OnClick()
	place.buttons[1].__scripts.OnLeave()
	t.count(FK.debugLines, 0, "clicking one raised nothing")
end

function tests.the_place_tab_never_contradicts_the_planner()
	-- The Place tab used to red a button whenever the buff it *carries* was
	-- covered, while the planner only calls an object wasted when its own
	-- effect is that buff. So the Camp tab said "Suggested → Master Forge" and
	-- the Place tab painted that same forge red. Advice that argues with itself
	-- is worse than none.
	local FK, panel = build()
	FK.Roster.Coverage = function() return { strength = "Strength of Earth Totem" } end
	FK.Professions.PlaceableObjects = function()
		local out = {}
		for _, id in ipairs({ "sharpening_wheel", "anvil", "master_forge" }) do
			table.insert(out, FK.Data.GetObject(id))
		end
		return out
	end
	FK.Camp.placed = {}
	FK.Camp.Plan = function(self)
		return FK.Plan.Evaluate({
			slots = 3, placed = self.placed,
			covered = FK.Roster.Coverage(),
			contributors = { { name = "Ana", ready = true, readyIn = 0,
				objects = { "sharpening_wheel", "anvil", "master_forge" } } },
		})
	end
	FK.Camp.SuggestionForSelf = function(self)
		local plan = self:Plan()
		for _, suggestion in ipairs(plan.suggestions) do
			if suggestion.player == "Ana" then return suggestion, plan end
		end
		return nil, plan
	end

	panel.strip:Select("Place")
	FK.UI:Refresh()

	local suggested = FK.Camp:SuggestionForSelf()
	t.isTrue(suggested, "the planner suggested something")

	for _, button in ipairs(panel.tabFrames.Place.buttons) do
		if button.object and button.object.id == suggested.objectId then
			t.isTrue(not button.reason or not button.reason:find("Wasted"),
				"the suggested " .. button.object.name .. " is not painted wasted: "
					.. tostring(button.reason))
		end
		-- The wheel's own effect *is* the covered buff, so it is genuinely wasted.
		if button.object and button.object.id == "sharpening_wheel" then
			t.isTrue(button.reason and button.reason:find("Wasted"),
				"the wheel itself is still flagged")
		end
	end
end

function tests.a_camp_row_still_works_after_an_empty_list()
	-- Row 1 is created by the "none heard of yet" branch with a do-nothing
	-- handler. Pooled rows kept it, so the tab's only action was dead for the
	-- rest of the session once camps actually arrived.
	local FK, panel = build()
	local camps = {}
	FK.Discovery.Found = function() return camps end

	panel.strip:Select("Find")
	FK.UI:Refresh()

	camps = { { host = "Cy", free = 2, slots = 3, x = 0.4, y = 0.6, sameMap = true } }
	FK.UI:Refresh()

	local asked
	FK.Discovery.Waypoint = function(camp) asked = camp and camp.host return true end
	panel.tabFrames.Find.campRows[1].__scripts.OnClick()
	t.equals(asked, "Cy", "clicking the first row asked for its waypoint")
end

function tests.a_full_fire_refuses_another_object()
	local FK = build()
	FK.Camp = nil
	Mock.load(FK, root, "Core/Camp.lua")
	FK.Cooldowns = FK.Cooldowns
	FK.Camp.slots = 1
	FK.Camp.placed = { { player = "Bo", objectId = "incense_candle" } }

	local ok, err = FK.Camp:MarkPlaced("Ana", "lodestone", true)
	t.equals(ok, false, "a full fire refuses")
	t.isTrue(err and err:find("full"), "and says why: " .. tostring(err))

	-- A campfire replaces the fire rather than taking a slot, so it is exempt.
	local fireOk = FK.Camp:MarkPlaced("Cy", "expert_campfire_kit", true)
	t.equals(fireOk, true, "but a bigger campfire is still allowed")
end

function tests.a_nameless_player_cannot_place()
	local FK = build()
	FK.Camp = nil
	Mock.load(FK, root, "Core/Camp.lua")
	FK.Camp.slots = 3
	FK.Camp.placed = {}

	local ok, err = FK.Camp:MarkPlaced(nil, "lodestone", true)
	t.equals(ok, false, "a nil player is refused")
	t.isTrue(err and err:find("who you are"), "rather than becoming a nil table index")
end

function tests.a_camp_can_be_waypointed_by_clicking_it()
	local FK, panel = build()
	local asked = false
	FK.Discovery.Waypoint = function(camp) asked = camp ~= nil return true end

	panel.strip:Select("Find")
	FK.UI:Refresh()

	local row = panel.tabFrames.Find.campRows[1]
	t.isTrue(row and row.camp, "a camp row exists and carries its camp")
	row.__scripts.OnClick()
	t.isTrue(asked, "clicking it asked for a waypoint")
end

function tests.the_switches_work_both_ways()
	local FK, panel = build()
	panel.strip:Select("You")
	FK.UI:Refresh()

	local you = panel.tabFrames.You
	you.debugToggle.__scripts.OnClick()
	t.equals(FK.db.debug, true, "the debug switch turned on")
	you.debugToggle.__scripts.OnClick()
	t.equals(FK.db.debug, false, "and off again")

	panel.strip:Select("Find")
	FK.UI:Refresh()
	panel.tabFrames.Find.share.__scripts.OnClick()
	t.equals(FK.db.shareWithGuild, true, "sharing turned on from the panel")
end

function tests.a_profession_can_be_set_without_a_command()
	local FK, panel = build()
	panel.strip:Select("You")
	FK.UI:Refresh()

	local you = panel.tabFrames.You
	local before = you.professionName.text:GetText()
	you.professionName.__scripts.OnClick()
	t.isTrue(you.professionName.text:GetText() ~= before, "the name cycles")

	local chosen = you.professionName.text:GetText()
	you.professionSkill:SetText("145")
	you.professionSkill.__scripts.OnEnterPressed()
	t.equals(FK.Professions.known[chosen], 145, "setting " .. chosen .. " took")
end

function tests.a_number_box_is_not_wiped_while_you_type_in_it()
	-- The panel refreshes every five seconds whether or not you are mid-rank.
	local FK, panel = build()
	panel.strip:Select("You")
	FK.UI:Refresh()

	local row = panel.tabFrames.You.fieldGuide
	local box = row.box
	t.isTrue(box, "the Field Guide row exposes its box")

	-- Not typing: the box tracks the stored value.
	FK.db.legacy.fieldGuide = 2
	row:Refresh()
	t.equals(box:GetText(), "2", "it shows the stored rank")

	-- Typing: a refresh must leave what is being entered alone.
	box:SetFocus()
	box:SetText("3")
	row:Refresh()
	t.equals(box:GetText(), "3", "the half-typed rank survived a refresh")

	box:ClearFocus()
	row:Refresh()
	t.equals(box:GetText(), "2", "and it tracks the stored value again once you leave")
end

function tests.the_client_summary_fits_on_the_tab()
	-- The full capability list ran past the space available and was cut off
	-- with no scrollbar, hiding the saved-variables warning with it.
	local FK, panel = build()
	panel.strip:Select("You")
	FK.UI:Refresh()
	t.count(FK.debugLines, 0, "the You tab drew: " .. table.concat(FK.debugLines, " | "))
end

function tests.the_panel_remembers_where_it_was_dragged()
	local FK, panel = build()
	panel.titleBar.__scripts.OnDragStart()
	panel.titleBar.__scripts.OnDragStop()
	t.equals(FK.db.panelPosition.point, "CENTER", "the drag was saved")
	panel:RestorePosition()
end

function tests.the_minimap_button_draws_drags_and_hides()
	local FK = build()
	FK.MinimapButton:OnLogin()

	local button = FK.MinimapButton.button
	t.isTrue(button, "the button was created")
	t.equals(FK.diagnostics.minimapButton, "drawn", "and recorded that it drew")
	t.isTrue(button.icon and button.ring, "it has its icon and its ring")

	button.__scripts.OnEnter()
	button.__scripts.OnLeave()
	button.__scripts.OnClick(button, "LeftButton")

	-- Dragging installs an OnUpdate that must move it and remember the angle.
	FK.db.minimap.angle = 200
	button.__scripts.OnDragStart()
	local onUpdate = button.__scripts.OnUpdate
	t.isTrue(onUpdate, "dragging installed an OnUpdate")
	onUpdate()
	t.isTrue(FK.db.minimap.angle ~= 200, "the drag recorded a new angle")
	button.__scripts.OnDragStop()
	t.equals(button.__scripts.OnUpdate, nil, "and cleared it on release")

	FK.MinimapButton:SetShown(false)
	t.equals(button:IsShown(), false, "hiding works")
	FK.MinimapButton:SetShown(true)
	t.equals(button:IsShown(), true, "and so does showing it again")
end

return tests
