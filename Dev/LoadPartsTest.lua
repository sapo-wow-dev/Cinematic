-- /cine debug loadparts: the parts that can be left out (Modules.lua) in
-- game, both at once: Visions General's Load Visions and Camera > General's
-- Load Cameras. It clicks the boxes itself; you click Reload in the game's
-- box twice (off, then on again; once more first if one starts left out).
-- (Was /cine debug loadvisions, Visions only, 3 runs to 2026-11-21.) Steps:
--   1 ready    one left out at the start: its box ticked, a reload first
--   2 on       both loaded: their code ran first at ADDON_LOADED (before
--              ns.db and the language), their secure buttons made, their pages
--              and wheels there; memory and frames counted; a setting of each
--              changed (Sleeping bag card, RP walk's CineMode), put back at the end
--   3 off      both boxes unticked: saved as off, the defaults copied, the
--              Reload boxes (shot); you click Reload
--   4 left out after the reload: neither's code ran (their frames, pages,
--              wheels, Why rows), their switches read off, the settings kept
--              (and in the profile), their commands and keys say so, 8 s of
--              play with no errors; memory and frames against step 2; then both
--              ticked again, the Reload box
--   5 back     after the reload: both loaded again, the copy gone, the
--              settings as changed, pages and frames back
-- Into CinematicDB.loadPartsTestLog; its numbers between the reloads in
-- CinematicDB.loadPartsTestData. Dev copy only.
local ADDON_NAME, ns = ...

-- Each part: its General page and box, a setting of its, pages, frames made
-- as its code runs, its Why tab's left-out row.
local PARTS = {
	{ part = "visions", label = "Visions", general = "Visions General", box = "loadVisionsBox",
		popup = "CINEMATIC_LOAD_PARTS", setting = "cardSleepBagOn", why = "visions", row = "visions:loaded",
		pages = { "Heal Vision", "Damage Vision", "Quest Vision", "Roll Vision", "Duel Vision", "Emote Vision",
			"Card Vision", "Visions Style", "Vitals Vision", "Death Vision", "Teleport Vision", "Vitals Style" },
		frames = { "CinematicQuestItemButton", "CinematicQuestTalkClearTarget" } },
	{ part = "cameras", label = "Cameras", general = "Cameras", box = "loadCamerasBox",
		popup = "CINEMATIC_LOAD_PARTS", setting = "walkCine", why = "cameras", row = "cameras:loaded",
		pages = { "Scenes", "Triggers", "Camera Scripts", "My Shots", "Shoulder Cam", "Camera Settings" },
		frames = { "CinematicCameraWheel", "CinematicShoulderEscapeButton" } },
}

local function Data()
	CinematicDB.loadPartsTestData = CinematicDB.loadPartsTestData or {}
	return CinematicDB.loadPartsTestData
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
	collectgarbage("collect") -- (loadvisions run 1: 94 MB on vs 71 MB back on was garbage not yet collected)
	if update then update() end
	return get and get(ADDON_NAME) or nil
end

-- The pages there (pages registered at all: some aren't on every client) or gone.
local function Pages(r, p, want, what)
	local canvases = ns.settingsCanvases or {}
	local data = Data()
	data.pagesThere = data.pagesThere or {}
	local wrong, list = {}, want == "record" and p.pages or (data.pagesThere[p.part] or p.pages)
	if want == "record" then
		local there = {}
		for _, name in ipairs(list) do
			if canvases[name] then there[#there + 1] = name end
		end
		data.pagesThere[p.part] = there
		r:Verdict(#there >= 3, ("%s' pages there: %s"):format(p.label, table.concat(there, ", ")))
		return
	end
	for _, name in ipairs(list) do
		if (canvases[name] ~= nil) ~= want then wrong[#wrong + 1] = name end
	end
	r:Verdict(#wrong == 0, what .. (#wrong > 0 and (": not so for " .. table.concat(wrong, ", ")) or ""))
end

local function WhyRow(id)
	for _, provider in ipairs(ns.WhyProviders and ns.WhyProviders() or {}) do
		if provider.id == id then
			local ok, sections = pcall(provider.fn)
			return ok and sections and sections[1] and sections[1].rows and sections[1].rows[1]
		end
	end
end

-- A command or key into a left-out part's code: what it said.
local function Said(fn, ...)
	local said
	local print0 = ns.Print
	ns.Print = function(text) said = tostring(text) end
	local ok = pcall(fn, ...)
	ns.Print = print0
	return ok, said
end

-- The boxes clicked to wanted (only those not already so), as you would; then
-- the Reload boxes' state and a shot, the run's place saved, and a wait for
-- your click (or the kit's Reload).
local function Flip(r, wanted, only)
	local shown = {}
	for _, p in ipairs(PARTS) do
		if not only or only[p.part] then
			local canvas = ns.settingsCanvases and ns.settingsCanvases[p.general]
			local box = canvas and canvas[p.box]
			if not box then
				r:Fail(("no %s box on %s"):format(p.label, p.general))
			else
				box:SetChecked(wanted)
				box:GetScript("OnClick")(box)
				local key = ns.MODULE_KEYS[p.part]
				r:Verdict(ns.ModuleWanted(p.part) == wanted and (CinematicDB[key] ~= false) == wanted,
					("the %s box saved it as %s (CinematicDB.%s = %s)"):format(p.label, wanted and "on" or "off", key,
					tostring(CinematicDB[key])))
				local popup = StaticPopup_FindVisible and StaticPopup_FindVisible(p.popup)
				r:Fields(p.label .. " Reload box", {
					found = function() return popup ~= nil end,
					name = function() return popup and popup:GetName() end,
					visible = function() return popup and popup:IsVisible() end,
					at = function() return popup and ("%s,%s"):format(tostring(popup:GetLeft()), tostring(popup:GetTop())) end,
					text = function()
						local t = popup and (popup.text or popup.Text or (popup:GetName() and _G[popup:GetName() .. "Text"]))
						return t and t.GetText and t:GetText()
					end,
					cover = function() local c = ns.ReloadCover and ns.ReloadCover() return c and c:IsVisible() end,
				})
				if popup and shown[#shown] ~= popup then shown[#shown + 1] = popup end
			end
		end
	end
	-- (One box for every change, loadparts run 1 had one each: the user, 2026-11-22.)
	local popup = shown[1]
	local t = popup and (popup.text or popup.Text or (popup:GetName() and _G[popup:GetName() .. "Text"]))
	local text = t and t.GetText and t:GetText()
	if type(text) ~= "string" then text = "" end
	local named = 0
	for _, p in ipairs(PARTS) do
		if (not only or only[p.part]) and text:find(p.part == "visions" and "Visions" or "cameras", 1, true) then
			named = named + 1
		end
	end
	local want = 0
	for _, p in ipairs(PARTS) do if not only or only[p.part] then want = want + 1 end end
	r:Verdict(#shown == 1 and named == want, ("one Reload box for it all: %d, naming %d of %d: %s"):format(#shown,
		named, want, text))
	if #shown > 0 then r:Shot("the Reload boxes", { behind = shown }) end
	r:SaveResume()
	local _, answer = r:WaitFor("Do you see the game's box asking to reload?",
		{ check = function() return false end, buttons = { "Yes, I see it", "No box", { kind = "reload" } } })
	r:Verdict(answer == "Yes, I see it", "you see the Reload box: " .. tostring(answer))
	r:WaitFor(answer == "Yes, I see it" and "Click Reload in that box." or "Click Reload under this one.",
		{ check = function() return false end, buttons = { { kind = "reload" } } })
end

ns.TestKit.Define({
	name = "loadparts",
	key = "loadPartsTest",
	title = "Load Visions and Cameras",
	about = "Visions and Cameras left out and back: you click Reload twice, the test does the rest",
	settings = { "cardSleepBagOn", "walkCine", "loadVisions", "loadCameras" },
	context = function()
		local start = ns.moduleStart or {}
		return ("Visions loaded %s, wanted %s; Cameras loaded %s, wanted %s; started with db %s, locale %s, combat %s, " ..
			"saved settings %s"):format(tostring(ns.ModuleLoaded("visions")), tostring(ns.ModuleWanted("visions")),
			tostring(ns.ModuleLoaded("cameras")), tostring(ns.ModuleWanted("cameras")), tostring(start.db),
			tostring(start.locale), tostring(start.combat), tostring(start.saved))
	end,
	-- (Stopped while one's off: on again from the next reload.)
	putBack = function()
		local back = {}
		for _, p in ipairs(PARTS) do
			if not ns.ModuleWanted(p.part) then
				ns.SetModuleWanted(p.part, true)
				back[#back + 1] = p.label
			end
		end
		return #back > 0 and ("Load %s on again (from the next /reload)"):format(table.concat(back, " and ")) or "both on"
	end,
	steps = {
		{ key = "ready", title = "both loaded to start", run = function(r)
			local off = {}
			for _, p in ipairs(PARTS) do
				if not ns.ModuleLoaded(p.part) then off[p.part] = true end
			end
			if not next(off) then
				r:Pass("both loaded already: no reload first")
				return
			end
			r:Log("left out at the start: its box ticked, a reload first")
			Flip(r, true, off)
		end },
		{ key = "on", title = "both loaded", run = function(r)
			local start = ns.moduleStart or {}
			r:Fields("start", { db = function() return start.db end, locale = function() return start.locale end,
				combat = function() return start.combat end, saved = function() return start.saved end })
			r:Verdict(start.db == false and start.locale == "enUS",
				"their code ran before Core.lua's settings and the language (as at file load)")
			local data = Data()
			wipe(data)
			data.settings = {}
			for _, p in ipairs(PARTS) do
				r:Verdict(ns.ModuleLoaded(p.part), p.label .. " loaded (tick its Load box and reload first if not)")
				for _, name in ipairs(p.frames) do
					local frame = rawget(_G, name)
					r:Probe(name, function()
						return frame ~= nil, frame and frame.IsProtected and frame:IsProtected(),
							frame and frame.GetAttribute and frame:GetAttribute("type")
					end)
					r:Verdict(frame ~= nil, name .. " made by its code at ADDON_LOADED")
				end
				Pages(r, p, "record")
				data.settings[p.setting] = ns.db[p.setting] == false -- (the other way from now: on unless false)
				r:Set(p.setting, data.settings[p.setting])
			end
			local cameraChoice
			for _, choice in ipairs(ns.MASTER_WHEEL_CHOICES or {}) do
				if choice.key == "camera" then cameraChoice = true end
			end
			r:Verdict(cameraChoice, "the master wheel can have the camera wheel")
			data.memOn, data.framesOn = MemoryKB(), FrameCount()
			r:Log(("memory %.0f KB, %d frames in the game"):format(data.memOn or -1, data.framesOn))
			r:Verdict(CinematicDB.moduleDefaults == nil, "no copy of their defaults while they're on")
		end },
		{ key = "off", title = "both Load boxes unticked", run = function(r)
			Flip(r, false)
		end },
		{ key = "leftout", title = "Visions and Cameras left out", run = function(r)
			local data = Data()
			local settings = ns.ProfileSettings and ns.ProfileSettings(ns.ActiveProfile())
			for _, p in ipairs(PARTS) do
				r:Verdict(not ns.ModuleLoaded(p.part), p.label .. " not loaded after the reload")
				for _, name in ipairs(p.frames) do
					r:Verdict(rawget(_G, name) == nil, name .. " never made")
				end
				Pages(r, p, false, p.label .. "' pages gone")
				Pages(r, { label = p.label, pages = { p.general } }, true, p.general .. " kept (its Load box)")
				local row = WhyRow(p.why)
				r:Verdict(row and row.key == p.row, ("Why window's %s tab: %s"):format(p.why, tostring(row and row.title)))
				local want = data.settings and data.settings[p.setting]
				r:Verdict(ns.db[p.setting] == want and ns.DEFAULTS[p.setting] ~= nil and settings
					and settings[p.setting] == want, ("%s' setting %s kept: %s, in the profile %s"):format(p.label,
					p.setting, tostring(ns.db[p.setting]), tostring(settings and settings[p.setting])))
			end
			-- Visions: every Vision's switch off, its wheel empty, the plates' check no.
			local _, all = 0, #(ns.VISION_LIST or {})
			r:Verdict(all == 0, ("vision wheel: %d slots left"):format(all))
			r:Verdict(ns.Setting("lowHealth") == false and ns.Setting("questVision") == false and ns.Setting("cards") == false,
				"Vitals, Quest and Card Vision read as off")
			r:Verdict(ns.IsQuestMob("target") == false, "nameplates' Quest Vision check answers no")
			-- Cameras: their switches off, every camera off and why, no camera wheel.
			r:Verdict(ns.Setting("cameraModes") == false and ns.Setting("shoulderCam") == false,
				"Enable Cameras and Shoulder Cam read as off")
			r:Verdict(ns.IsCameraOffHere("idle") and true or false, "the AFK camera is off here: " ..
				tostring(ns.CameraOffWhy and ns.CameraOffWhy("idle")))
			local cameraChoice
			for _, choice in ipairs(ns.MASTER_WHEEL_CHOICES or {}) do
				if choice.key == "camera" then cameraChoice = true end
			end
			r:Verdict(not cameraChoice, "the master wheel has no camera wheel")
			-- Commands and keys into their code: a line saying so.
			local ok, said = Said(ns.HandleSlash, "report")
			r:Verdict(ok and said and said:find("left out", 1, true), "/cine report: " .. tostring(said))
			ok, said = Said(ns.HandleSlash, "flyby")
			r:Verdict(ok and said and said:find("aren't loaded", 1, true), "/cine flyby: " .. tostring(said))
			ok, said = Said(Cinematic_StartCam, "idle")
			r:Verdict(ok and said and said:find("aren't loaded", 1, true), "the AFK camera's key: " .. tostring(said))
			ok, said = Said(Cinematic_CameraWheel)
			r:Verdict(ok and said and said:find("aren't loaded", 1, true), "the camera wheel's key: " .. tostring(said))
			r:Prompt("Visions and Cameras left out: 8 seconds of play.", "Nothing to do.", 8)
			r:Sleep(8)
			data.memOff, data.framesOff = MemoryKB(), FrameCount()
			r:Log(("memory %.0f KB (on: %.0f), %d frames (on: %d)"):format(data.memOff or -1, data.memOn or -1,
				data.framesOff, data.framesOn or -1))
			r:Verdict(data.memOff and data.memOn and data.memOff < data.memOn,
				("memory down %.0f KB without them"):format((data.memOn or 0) - (data.memOff or 0)))
			r:Verdict(data.framesOff < (data.framesOn or 0),
				("%d frames fewer without them"):format((data.framesOn or 0) - data.framesOff))
			Flip(r, true)
		end },
		{ key = "back", title = "both back", run = function(r)
			local data = Data()
			r:Verdict(CinematicDB.moduleDefaults == nil, "the copy of their defaults gone from the saved settings")
			for _, p in ipairs(PARTS) do
				r:Verdict(ns.ModuleLoaded(p.part), p.label .. " loaded again")
				local want = data.settings and data.settings[p.setting]
				r:Verdict(ns.db[p.setting] == want, ("%s' setting still %s"):format(p.label, tostring(ns.db[p.setting])))
				for _, name in ipairs(p.frames) do
					r:Verdict(rawget(_G, name) ~= nil, name .. " made again")
				end
				Pages(r, p, true, p.label .. "' pages back")
			end
			r:Log(("memory %.0f KB (step 2: %.0f)"):format(MemoryKB() or -1, data.memOn or -1))
		end },
	},
})
