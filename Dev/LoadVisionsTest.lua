-- /cine debug loadvisions: Visions General's Load Visions (Modules.lua) in
-- game. It clicks the box itself; you click Reload in the game's box twice
-- (off, then on again; once more first if it starts left out). Steps:
--   1 ready    left out at the start: the box ticked, a reload first
--   2 on       Visions loaded: its code ran first at ADDON_LOADED (before
--              ns.db and the language), its two secure buttons made, its
--              pages and wheel slots there; memory and frames counted; a
--              Vision setting changed (Sleeping bag card), put back at the end
--   3 off      the box unticked: saved as off, the defaults copy written,
--              the Reload box (shot); you click Reload
--   4 left out after the reload: no Vision's code ran (Visions/ and Vitals,
--              Teleport, Death: their frames, pages, wheel, Why tab gone), their
--              switches read off, the setting kept (and in the profile), /cine report
--              says it needs Visions, 8 s of play with no errors; memory and
--              frames against step 1; then ticked again, the Reload box
--   5 back     after the reload: loaded again, the copy gone, the setting as
--              changed, pages and frames back
-- Into CinematicDB.loadVisionsTestLog; its numbers between the reloads in
-- CinematicDB.loadVisionsTestData. Dev copy only.
local ADDON_NAME, ns = ...

local SETTING = "cardSleepBagOn" -- (a Vision's: Visions/SleepingBag.lua's default)
local VISION_PAGES = { "Heal Vision", "Damage Vision", "Quest Vision", "Roll Vision", "Duel Vision", "Emote Vision",
	"Card Vision", "Visions Style", "Vitals Vision", "Death Vision", "Teleport Vision", "Vitals Style" }
local KEPT_PAGES = { "Visions General" }
local FRAMES = { "CinematicQuestItemButton", "CinematicQuestTalkClearTarget" } -- (made as Visions' code runs)

local function Data()
	CinematicDB.loadVisionsTestData = CinematicDB.loadVisionsTestData or {}
	return CinematicDB.loadVisionsTestData
end

-- Every frame the game has (ours, its, other addons'): a count.
local function FrameCount()
	local n, frame = 0, EnumerateFrames()
	while frame do
		n = n + 1
		frame = EnumerateFrames(frame)
	end
	return n
end

local function MemoryKB()
	local update, get = _G.UpdateAddOnMemoryUsage, _G.GetAddOnMemoryUsage
	collectgarbage("collect") -- (run 1: 94 MB on vs 71 MB back on was mostly garbage not yet collected)
	if update then update() end
	return get and get(ADDON_NAME) or nil
end

local function Pages(r, list, want, what)
	local canvases = ns.settingsCanvases or {}
	local wrong = {}
	for _, name in ipairs(list) do
		if (canvases[name] ~= nil) ~= want then wrong[#wrong + 1] = name end
	end
	r:Verdict(#wrong == 0, what .. (#wrong > 0 and (": not so for " .. table.concat(wrong, ", ")) or ""))
end

local function VisionSlots()
	local n = 0
	for _, vision in ipairs(ns.VISION_LIST or {}) do
		if vision.part == "visions" then n = n + 1 end
	end
	return n, #(ns.VISION_LIST or {})
end

-- The page's box clicked to wanted, as you would; then the Reload box shot,
-- the run's place saved, and a wait for your click (or the kit's Reload).
local function Flip(r, wanted)
	local canvas = ns.settingsCanvases and ns.settingsCanvases["Visions General"]
	local box = canvas and canvas.loadVisionsBox
	if not box then
		r:Fail("no Load Visions box on Visions General")
		return
	end
	box:SetChecked(wanted)
	box:GetScript("OnClick")(box)
	r:Verdict(ns.ModuleWanted("visions") == wanted and (CinematicDB.loadVisions ~= false) == wanted,
		("the box saved Load Visions as %s (CinematicDB.loadVisions = %s)"):format(wanted and "on" or "off",
		tostring(CinematicDB.loadVisions)))
	local popup = StaticPopup_FindVisible and StaticPopup_FindVisible("CINEMATIC_LOAD_VISIONS")
	-- (Run 1: found, but on neither screenshot and its text nil; you clicked the
	-- kit's Reload. So its state, now and after the shot, and you're asked.)
	local function State(label)
		r:Fields(label, {
			found = function() return popup ~= nil end,
			name = function() return popup and popup:GetName() end,
			which = function() return popup and popup.which end,
			shown = function() return popup and popup:IsShown() end,
			visible = function() return popup and popup:IsVisible() end,
			alpha = function() return popup and popup:GetEffectiveAlpha() end,
			size = function() return popup and ("%.0fx%.0f"):format(popup:GetWidth() or 0, popup:GetHeight() or 0) end,
			at = function() return popup and ("%s,%s"):format(tostring(popup:GetLeft()), tostring(popup:GetTop())) end,
			strata = function() return popup and popup:GetFrameStrata() end,
			text = function()
				local t = popup and (popup.text or popup.Text or (popup:GetName() and _G[popup:GetName() .. "Text"]))
				return t and t.GetText and t:GetText()
			end,
			cover = function() local c = ns.ReloadCover and ns.ReloadCover() return c and c:IsVisible() end,
		})
	end
	State("Reload box as shown")
	r:Verdict(popup ~= nil, "the game's Reload box was made")
	if popup then r:Shot("the Reload box", { behind = popup }) end
	State("Reload box after the shot")
	r:SaveResume()
	local _, answer = r:WaitFor("Do you see the game's box asking to reload?",
		{ check = function() return false end, buttons = { "Yes, I see it", "No box", { kind = "reload" } } })
	r:Verdict(answer == "Yes, I see it", "you see the Reload box: " .. tostring(answer))
	State("Reload box when you answered")
	r:WaitFor(answer == "Yes, I see it" and "Click Reload in that box." or "Click Reload under this one.",
		{ check = function() return false end, buttons = { { kind = "reload" } } })
end

ns.TestKit.Define({
	name = "loadvisions",
	key = "loadVisionsTest",
	title = "Load Visions",
	about = "Visions left out and back: you click Reload twice, the test does the rest",
	settings = { SETTING, "loadVisions" },
	context = function()
		local start = ns.moduleStart or {}
		return ("Visions loaded %s, wanted %s; started with db %s, locale %s, combat %s, saved settings %s"):format(
			tostring(ns.ModuleLoaded("visions")), tostring(ns.ModuleWanted("visions")), tostring(start.db),
			tostring(start.locale), tostring(start.combat), tostring(start.saved))
	end,
	-- (Stopped while it's off: on again from the next reload.)
	putBack = function()
		if ns.ModuleWanted("visions") then return "Load Visions on" end
		ns.SetModuleWanted("visions", true)
		return "Load Visions on again (from the next /reload)"
	end,
	steps = {
		{ key = "ready", title = "Visions loaded to start", run = function(r)
			if ns.ModuleLoaded("visions") then
				r:Pass("Visions loaded already: no reload first")
				return
			end
			r:Log("Visions left out at the start: the box ticked, a reload first")
			Flip(r, true)
		end },
		{ key = "on", title = "Visions loaded", run = function(r)
			r:Verdict(ns.ModuleLoaded("visions"), "Visions loaded (tick Load Visions and reload first if not)")
			if not ns.ModuleLoaded("visions") then return end
			local start = ns.moduleStart or {}
			r:Fields("start", { db = function() return start.db end, locale = function() return start.locale end,
				combat = function() return start.combat end, saved = function() return start.saved end })
			r:Verdict(start.db == false, "Visions' code ran before Core.lua's settings (ns.db not there yet)")
			r:Verdict(start.locale == "enUS", "...and before the language was set (its text built in English, as at load)")
			for _, name in ipairs(FRAMES) do
				local frame = rawget(_G, name)
				r:Probe(name, function()
					return frame ~= nil, frame and frame.IsProtected and frame:IsProtected(),
						frame and frame.GetAttribute and frame:GetAttribute("type")
				end)
				r:Verdict(frame ~= nil, name .. " made by Visions' code at ADDON_LOADED")
			end
			Pages(r, VISION_PAGES, true, "Visions' pages are there")
			local slots = VisionSlots()
			r:Verdict(slots > 0, slots .. " Vision wheel slots from Visions/")
			local data = Data()
			wipe(data)
			data.memOn, data.framesOn = MemoryKB(), FrameCount()
			r:Log(("memory %.0f KB, %d frames in the game"):format(data.memOn or -1, data.framesOn))
			data.setting = ns.db[SETTING] == false -- (the other way from now: on unless it's false)
			r:Set(SETTING, data.setting)
			r:Verdict(ns.db.moduleDefaults == nil and CinematicDB.moduleDefaults == nil,
				"no copy of Visions' defaults while it's on")
		end },
		{ key = "off", title = "Load Visions unticked", run = function(r)
			Flip(r, false)
		end },
		{ key = "leftout", title = "Visions left out", run = function(r)
			r:Verdict(not ns.ModuleLoaded("visions"), "Visions not loaded after the reload")
			for _, name in ipairs(FRAMES) do
				r:Verdict(rawget(_G, name) == nil, name .. " never made")
			end
			Pages(r, VISION_PAGES, false, "Visions' pages gone")
			Pages(r, KEPT_PAGES, true, "Visions General kept (its Load Visions box)")
			local _, all = VisionSlots()
			r:Verdict(all == 0, ("vision wheel: %d slots left"):format(all))
			r:Verdict(ns.Setting("lowHealth") == false and ns.Setting("teleportVision") == false
				and ns.Setting("deathScreen") == false, "Vitals, Teleport and Death Vision read as off")
			r:Verdict(ns.UpdateDeathVision == nil and ns.RefreshLowHealth == nil and ns.TestTeleportVision == nil,
				"Vitals', Teleport's and Death Vision's code never ran")
			local why = {}
			for _, provider in ipairs(ns.WhyProviders and ns.WhyProviders() or {}) do why[provider.id] = true end
			r:Verdict(why.cards and why.visions and why.atmosphere, "Why window: Cards, Visions and Atmosphere tabs kept")
			local row, cardRow
			for _, provider in ipairs(ns.WhyProviders and ns.WhyProviders() or {}) do
				if provider.id == "visions" or provider.id == "cards" then
					local ok, sections = pcall(provider.fn)
					local first = ok and sections and sections[1] and sections[1].rows and sections[1].rows[1]
					if provider.id == "visions" then row = first else cardRow = first end
				end
			end
			r:Verdict(row and row.key == "visions:loaded", "Why window's Visions tab: " .. tostring(row and row.title))
			r:Verdict(cardRow and cardRow.key == "cards:loaded", "Why window's Cards tab: " .. tostring(cardRow and cardRow.title))
			r:Verdict(ns.Setting("questVision") == false and ns.Setting("cards") == false,
				"Quest Vision and Card Vision read as off")
			r:Verdict(ns.IsQuestMob("target") == false, "nameplates' Quest Vision check answers no")
			local data = Data()
			r:Verdict(ns.db[SETTING] == data.setting and ns.DEFAULTS[SETTING] ~= nil,
				("the changed Vision setting kept: %s (wanted %s), its default there"):format(tostring(ns.db[SETTING]),
				tostring(data.setting)))
			local settings = ns.ProfileSettings and ns.ProfileSettings(ns.ActiveProfile())
			r:Verdict(settings and settings[SETTING] == data.setting, "...and in the profile's settings")
			local said
			local print0 = ns.Print
			ns.Print = function(text) said = tostring(text) end
			local ok = pcall(ns.HandleSlash, "report")
			ns.Print = print0
			r:Verdict(ok and said and said:find("needs Visions", 1, true), "/cine report: " .. tostring(said))
			r:Prompt("Visions left out: 8 seconds of play.", "Nothing to do.", 8)
			r:Sleep(8)
			data.memOff, data.framesOff = MemoryKB(), FrameCount()
			r:Log(("memory %.0f KB (on: %.0f), %d frames (on: %d)"):format(data.memOff or -1, data.memOn or -1,
				data.framesOff, data.framesOn or -1))
			r:Verdict(data.memOff and data.memOn and data.memOff < data.memOn,
				("memory down %.0f KB without Visions"):format((data.memOn or 0) - (data.memOff or 0)))
			r:Verdict(data.framesOff < (data.framesOn or 0),
				("%d frames fewer without Visions"):format((data.framesOn or 0) - data.framesOff))
			Flip(r, true)
		end },
		{ key = "back", title = "Visions back", run = function(r)
			r:Verdict(ns.ModuleLoaded("visions"), "Visions loaded again")
			r:Verdict(CinematicDB.moduleDefaults == nil, "the copy of its defaults gone from the saved settings")
			local data = Data()
			r:Verdict(ns.db[SETTING] == data.setting, ("the changed Vision setting still %s"):format(tostring(ns.db[SETTING])))
			for _, name in ipairs(FRAMES) do
				r:Verdict(rawget(_G, name) ~= nil, name .. " made again")
			end
			Pages(r, VISION_PAGES, true, "Visions' pages back")
			local slots = VisionSlots()
			r:Verdict(slots > 0, slots .. " Vision wheel slots back")
			r:Log(("memory %.0f KB (step 1: %.0f)"):format(MemoryKB() or -1, data.memOn or -1))
		end },
	},
})
