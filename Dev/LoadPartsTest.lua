-- /cine debug loadparts: the parts that can be left out (Modules.lua) in
-- game, all at once: Visions General's Load Visions, Camera > General's
-- Load Cameras, Style > General's Load Style and Atmosphere > General's Load
-- Atmosphere (2026-11-22). It clicks the boxes itself; you click Reload in the game's
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
-- as its code runs, its Why tab's left-out row. proven: what proved it; a
-- run leaves out only the parts not proven yet (a new one: just it, one
-- reload), /cine debug loadparts full every part (the final test).
local PARTS = {
	{ part = "visions", label = "Visions", general = "Visions General", box = "loadVisionsBox",
		popup = "CINEMATIC_LOAD_PARTS", setting = "cardSleepBagOn", why = "visions", row = "visions:loaded",
		pages = { "Heal Vision", "Damage Vision", "Quest Vision", "Roll Vision", "Duel Vision", "Emote Vision",
			"Card Vision", "Visions Style", "Vitals Vision", "Death Vision", "Teleport Vision", "Vitals Style" },
		frames = { "CinematicQuestItemButton", "CinematicQuestTalkClearTarget" }, switch = "visionsAll", proven = "loadparts runs 1-5, 2026-11-21/22: left out and back, menu, leaks" },
	{ part = "cameras", label = "Cameras", general = "Cameras", box = "loadCamerasBox",
		popup = "CINEMATIC_LOAD_PARTS", setting = "walkCine", why = "cameras", row = "cameras:loaded",
		pages = { "Scenes", "Triggers", "Camera Scripts", "My Shots", "Shoulder Cam", "Camera Settings" },
		frames = { "CinematicCameraWheel", "CinematicShoulderEscapeButton" }, switch = "cameraModes", proven = "loadparts runs 1-5, 2026-11-21/22: left out and back, menu, leaks" },
	{ part = "style", label = "Style", general = "Style General", box = "loadStyleBox",
		popup = "CINEMATIC_LOAD_PARTS", setting = "abSlots",
		pages = { "Style Themes", "Unit Style", "Action Style", "Nameplate Style", "Name Style", "Tooltip Style",
			"Tint Style", "Card Styles", "Vitals Style" },
		frames = { "CinematicSelfText" }, switch = "styleGeneral", proven = "loadparts runs 1-5, 2026-11-21/22: left out and back, menu, leaks" },
	{ part = "atmosphere", label = "Atmosphere", general = "Effects", box = "loadAtmosphereBox",
		popup = "CINEMATIC_LOAD_PARTS", setting = "letterboxOnDiscover", why = "atmosphere", row = "atmosphere:loaded",
		pages = { "Tint", "Letterbox", "Graphics+", "Audio", "Tint Style", "Letterbox Style" },
		frames = { "CinematicTint", "CinematicLetterbox", "CinematicFocus" }, switch = "visualEffects", proven = "loadparts runs 1-5, 2026-11-21/22: left out and back, menu, leaks" },
}

ns.loadPartsParts = PARTS -- (Tools/offline/loadparts.lua: one marked new, the quick run)

-- The parts this run leaves out and checks: those not proven, or all on a full run.
local function Active(r)
	local list = {}
	for _, p in ipairs(PARTS) do
		if r.full or not p.proven then list[#list + 1] = p end
	end
	return list
end
local function Has(r, part)
	for _, p in ipairs(Active(r)) do
		if p.part == part then return true end
	end
	return false
end

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

-- Every update loop that runs for seconds (/cine debug loops' audit): label
-- (File.lua:line) -> ms, and the ms a frame in all.
local function Loops(r, seconds)
	ns.loopAudit = {}
	local frames = 0
	local counter = CreateFrame("Frame")
	counter:SetScript("OnUpdate", function() frames = frames + 1 end)
	r:Sleep(seconds)
	counter:SetScript("OnUpdate", nil)
	local audit = ns.loopAudit or {}
	ns.loopAudit = nil
	local total, labels = 0, {}
	for label, row in pairs(audit) do
		total = total + row.ms
		labels[#labels + 1] = ("%s %.2f ms/%d"):format(label, row.ms, row.calls)
	end
	table.sort(labels)
	return audit, total / math.max(1, frames), labels
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
	local list = only and PARTS or Active(r)
	for _, p in ipairs(list) do
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
	for _, p in ipairs(list) do
		-- (Each part by the name the box gives it, its label: "cameras" in
		-- lowercase matched no box since it says "Cameras".)
		if (not only or only[p.part]) and text:find(p.label, 1, true) then
			named = named + 1
		end
	end
	local want = 0
	for _, p in ipairs(list) do if not only or only[p.part] then want = want + 1 end end
	r:Verdict(#shown == 1 and named == want, ("one Reload box for it all: %d, naming %d of %d: %s"):format(#shown,
		named, want, text))
	r:SaveResume()
	-- (Seen and shot in runs 1-5: the one Reload box, over the test's own.)
	if r:Proven("the game's Reload box shows and you see it (loadparts runs 1-5)") then
		r:WaitFor("Click Reload in the game's box.", { check = function() return false end, buttons = { { kind = "reload" } } })
		return
	end
	if #shown > 0 then r:Shot("the Reload boxes", { behind = shown }) end
	local _, answer = r:WaitFor("Do you see the game's box asking to reload?",
		{ check = function() return false end, buttons = { "Yes, I see it", "No box", { kind = "reload" } } })
	r:Verdict(answer == "Yes, I see it", "you see the Reload box: " .. tostring(answer))
	r:WaitFor(answer == "Yes, I see it" and "Click Reload in that box." or "Click Reload under this one.",
		{ check = function() return false end, buttons = { { kind = "reload" } } })
end

ns.TestKit.Define({
	name = "loadparts",
	key = "loadPartsTest",
	title = "Load Visions, Cameras, Style and Atmosphere",
	about = "Visions, Cameras, Style and Atmosphere left out and back: you click Reload twice, the test does the rest",
	settings = { "visionsAll", "cameraModes", "styleGeneral", "visualEffects",
		"cardSleepBagOn", "walkCine", "abSlots", "letterboxOnDiscover", "loadVisions", "loadCameras",
		"loadStyle", "loadAtmosphere" },
	context = function()
		local start = ns.moduleStart or {}
		local parts = {}
		for _, p in ipairs(PARTS) do
			parts[#parts + 1] = ("%s loaded %s, wanted %s"):format(p.label, tostring(ns.ModuleLoaded(p.part)),
				tostring(ns.ModuleWanted(p.part)))
		end
		return ("%s; started with db %s, locale %s, combat %s, saved settings %s; music volume %s"):format(
			table.concat(parts, "; "), tostring(start.db), tostring(start.locale), tostring(start.combat),
			tostring(start.saved), tostring(GetCVar("Sound_MusicVolume")))
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
			if #Active(r) == 0 then
				r:Skip("every part proven: nothing to leave out (/cine debug loadparts full checks them all)")
				return
			end
			local start = ns.moduleStart or {}
			r:Fields("start", { db = function() return start.db end, locale = function() return start.locale end,
				combat = function() return start.combat end, saved = function() return start.saved end })
			r:Verdict(start.db == false and start.locale == "enUS",
				"their code ran before Core.lua's settings and the language (as at file load)")
			local data = Data()
			wipe(data)
			data.settings = {}
			for _, p in ipairs(Active(r)) do
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
			if Has(r, "cameras") then
				local cameraChoice
				for _, choice in ipairs(ns.MASTER_WHEEL_CHOICES or {}) do
					if choice.key == "camera" then cameraChoice = true end
				end
				r:Verdict(cameraChoice, "the master wheel can have the camera wheel")
			end
			data.music = GetCVar("Sound_MusicVolume") -- (Atmosphere's music left out: yours untouched)
			local _, perFrame, labels = Loops(r, 4)
			data.loopsOn = perFrame
			r:Log(("loops with them loaded: %.3f ms a frame; %s"):format(perFrame, table.concat(labels, ", ")))
			data.memOn, data.framesOn = MemoryKB(), FrameCount()
			r:Log(("memory %.0f KB, %d frames in the game"):format(data.memOn or -1, data.framesOn))
			r:Verdict(CinematicDB.moduleDefaults == nil, "no copy of their defaults while they're on")
		end },
		-- Each General page as you see it, its part loaded, in both states of
		-- its switch (the user, 2026-11-22: Load Style sat on the Themes tab, and
		-- with a page off its off card hid the box; the runs before opened the
		-- pages with their parts left out only, and IsVisible() said "shown"
		-- under the card). On: no off card, the page's own box clear (r:Overlaps)
		-- and inside the page. Off: the off card, its Load box for this part,
		-- ticked as wanted, clear. A shot of each.
		{ key = "layout", title = "each General page, loaded, on and off",
			proven = "loadparts 2026-11-22 14:19: all four on and off, the card's box inside it, 8 shots looked at",
			run = function(r)
			local function Hide() if ns.padTestBox then ns.padTestBox:Hide() end end
			local function Back() if ns.padTestBox then ns.padTestBox:Show() end end
			for _, p in ipairs(PARTS) do
				if ns.ModuleLoaded(p.part) then
					r:Set(p.switch, true)
					if ns.PaintPageSwitches then ns.PaintPageSwitches() end
					ns.OpenOptions(p.general)
					r:Sleep(1)
					local canvas = ns.settingsCanvases and ns.settingsCanvases[p.general]
					local box = canvas and canvas[p.box]
					local label = box and (box.Text or box.text)
					local card = ns.PageOffCardWanted(p.general)
					local hits = box and box:IsVisible() and r:Overlaps(box, canvas, { label }) or { "no box shown" }
					local inside = box and canvas and box:GetRight() and canvas:GetRight()
						and (label and label:GetRight() or box:GetRight()) <= canvas:GetRight() + 1
					r:Verdict(card == false and #hits == 0 and inside,
						("%s on: off card %s, its Load box inside the page %s, over %s"):format(p.general, tostring(card),
						tostring(inside), #hits > 0 and table.concat(hits, ", ") or "nothing"))
					Hide()
					r:Shot(p.general .. " on, " .. p.label .. " loaded", { behind = _G.SettingsPanel })
					Back()
					-- Off: the card over the page, the box on it.
					r:Set(p.switch, false)
					if ns.PaintPageSwitches then ns.PaintPageSwitches() end
					ns.OpenOptions(p.general)
					r:Sleep(1)
					card = ns.PageOffCardWanted(p.general)
					local load = ns.offCardLoad
					local shown = load and load:IsVisible() and load.part == p.part
					local cardHits = shown and r:Overlaps(load, load:GetParent(), { load.label }) or { "no box on the card" }
					r:Verdict(card == true and shown and load:GetChecked() == ns.ModuleWanted(p.part) and #cardHits == 0,
						("%s off: off card %s, its Load box on it %s (%s), ticked %s, over %s"):format(p.general,
						tostring(card), tostring(shown), tostring(load and load.part), tostring(load and load:GetChecked()),
						#cardHits > 0 and table.concat(cardHits, ", ") or "nothing"))
					Hide()
					r:Shot(p.general .. " off, its card", { behind = _G.SettingsPanel })
					Back()
					r:Set(p.switch, true)
					if ns.PaintPageSwitches then ns.PaintPageSwitches() end
				else
					r:Skip(p.label .. " isn't loaded: its page as loaded can't be seen")
				end
			end
		end },
		{ key = "off", title = "both Load boxes unticked", run = function(r)
			if #Active(r) == 0 then return end
			Flip(r, false)
		end },
		{ key = "leftout", title = "Visions, Cameras, Style and Atmosphere left out", run = function(r)
			if #Active(r) == 0 then return end
			local data = Data()
			local settings = ns.ProfileSettings and ns.ProfileSettings(ns.ActiveProfile())
			for _, p in ipairs(Active(r)) do
				r:Verdict(not ns.ModuleLoaded(p.part), p.label .. " not loaded after the reload")
				for _, name in ipairs(p.frames) do
					r:Verdict(rawget(_G, name) == nil, name .. " never made")
				end
				Pages(r, p, false, p.label .. "' pages gone")
				Pages(r, { label = p.label, pages = { p.general } }, true, p.general .. " kept (its Load box)")
				if p.why then -- (Style has no Why tab)
					local row = WhyRow(p.why)
					r:Verdict(row and row.key == p.row, ("Why window's %s tab: %s"):format(p.why, tostring(row and row.title)))
				end
				local want = data.settings and data.settings[p.setting]
				r:Verdict(ns.db[p.setting] == want and ns.DEFAULTS[p.setting] ~= nil and settings
					and settings[p.setting] == want, ("%s' setting %s kept: %s, in the profile %s"):format(p.label,
					p.setting, tostring(ns.db[p.setting]), tostring(settings and settings[p.setting])))
			end
			-- (Each part's own checks, for the parts in this run only.)
			local ok, said
			if Has(r, "visions") then
				-- Visions: every Vision's switch off, its wheel empty, the plates' check no.
				local _, all = 0, #(ns.VISION_LIST or {})
				r:Verdict(all == 0, ("vision wheel: %d slots left"):format(all))
				r:Verdict(ns.Setting("lowHealth") == false and ns.Setting("questVision") == false and ns.Setting("cards") == false,
					"Vitals, Quest and Card Vision read as off")
				r:Verdict(ns.IsQuestMob("target") == false, "nameplates' Quest Vision check answers no")
				ok, said = Said(ns.HandleSlash, "report")
				r:Verdict(ok and said and said:find("left out", 1, true), "/cine report: " .. tostring(said))
			end
			if Has(r, "cameras") then
				-- Cameras: their switches off, every camera off and why, no camera wheel, their keys say so.
				r:Verdict(ns.Setting("cameraModes") == false and ns.Setting("shoulderCam") == false,
					"Enable Cameras and Shoulder Cam read as off")
				r:Verdict(ns.IsCameraOffHere("idle") and true or false, "the AFK camera is off here: " ..
					tostring(ns.CameraOffWhy and ns.CameraOffWhy("idle")))
				local cameraChoice
				for _, choice in ipairs(ns.MASTER_WHEEL_CHOICES or {}) do
					if choice.key == "camera" then cameraChoice = true end
				end
				r:Verdict(not cameraChoice, "the master wheel has no camera wheel")
				ok, said = Said(ns.HandleSlash, "flyby")
				r:Verdict(ok and said and said:find("aren't loaded", 1, true), "/cine flyby: " .. tostring(said))
				ok, said = Said(Cinematic_StartCam, "idle")
				r:Verdict(ok and said and said:find("aren't loaded", 1, true), "the AFK camera's key: " .. tostring(said))
				ok, said = Said(Cinematic_CameraWheel)
				r:Verdict(ok and said and said:find("aren't loaded", 1, true), "the camera wheel's key: " .. tostring(said))
			end
			if Has(r, "style") then
				-- Style: every Style page off whatever's saved; a page's look its defaults.
				r:Verdict(ns.StyleOn(nil) == false and ns.Setting("styleGeneral") == false,
					"Enable Style reads off (ns.StyleOn and the switch)")
			end
			if Has(r, "atmosphere") then
				-- Atmosphere: Enable Visual Effects and its pages read off; nothing of
				-- Graphics Boost's left written (put back as its box was unticked);
				-- your music volume as it was; its command and key say so.
				r:Verdict(ns.Setting("visualEffects") == false and ns.Setting("letterboxPage") == false
					and ns.Setting("graphicsPlus") == false and ns.Setting("musicInCinematic") == false,
					"Enable Visual Effects, Letterbox, Graphics Boost and Audio read as off")
				r:Verdict(next(ns.db.graphicsPlusSaved or {}) == nil, "Graphics Boost: none of its values left written")
				r:Verdict(GetCVar("Sound_MusicVolume") == data.music, ("your music volume as it was: %s (on: %s)"):format(
					tostring(GetCVar("Sound_MusicVolume")), tostring(data.music)))
				r:Verdict(not (ns.letterbox or rawget(_G, "CinematicTint")), "no letterbox or tint frame")
				ok, said = Said(ns.HandleSlash, "doftest")
				r:Verdict(ok and said and said:find("left out", 1, true), "/cine doftest: " .. tostring(said))
				ok, said = Said(Cinematic_ToggleLetterbox)
				r:Verdict(ok and said and said:find("isn't loaded", 1, true), "the letterbox key: " .. tostring(said))
			end
			r:Prompt("Left out: 8 seconds of play.", "Nothing to do.", 8)
			r:Sleep(8)
			-- (The screen as it is with Style left out: the game's own look on the
			-- frames, plates and bars, no theme. Its frames, for the eye.)
			if not r:Proven("the screen with them left out, looked at (loadparts runs 1-5)") then
				r:Shot("the screen with them left out", { behind = { _G.PlayerFrame, _G.TargetFrame } })
			end
			-- The menu as you'd open it: each part's General page, its Load box
			-- showing, no off card over it (Camera > General showed "General is
			-- off" and hid its box, 2026-11-22: the run before never opened it).
			for _, p in ipairs(Active(r)) do
				ns.OpenOptions(p.general)
				r:Sleep(1)
				local canvas = ns.settingsCanvases and ns.settingsCanvases[p.general]
				local box = canvas and canvas[p.box]
				r:Verdict(ns.PageOffCardWanted(p.general) == false and box and box:IsVisible(),
					("%s in the menu: off card %s, Load box shown %s"):format(p.general,
					tostring(ns.PageOffCardWanted(p.general)), tostring(box and box:IsVisible())))
				-- (The test's box out of the way for the shot: it covered the page's
				-- title and intro, loadparts 2026-11-22.)
				if ns.padTestBox then ns.padTestBox:Hide() end
				r:Shot(p.general .. " with " .. p.label .. " left out", { behind = _G.SettingsPanel })
				if ns.padTestBox then ns.padTestBox:Show() end
			end
			-- No loop of theirs running (the leak audit, 2026-11-22: the camera
			-- orbit's ran every frame with Cameras left out): each running loop's
			-- file against the files their code came from (Modules.lua).
			local audit, perFrame, labels = Loops(r, 4)
			local leaks = {}
			for label in pairs(audit) do
				local file = label:match("([%w_]+%.lua)")
				for _, p in ipairs(Active(r)) do
					if (file and ns.ModuleFiles(p.part)[file]) or label:find("orbit camera", 1, true) then
						leaks[#leaks + 1] = label .. " (" .. p.label .. ")"
						break
					end
				end
			end
			r:Log(("loops with them left out: %.3f ms a frame (loaded: %.3f); %s"):format(perFrame, data.loopsOn or -1,
				table.concat(labels, ", ")))
			r:Verdict(#leaks == 0, "no loop of theirs running: " .. (#leaks > 0 and table.concat(leaks, ", ") or "none"))
			local files = 0
			for _, p in ipairs(Active(r)) do for _ in pairs(ns.ModuleFiles(p.part)) do files = files + 1 end end
			r:Verdict(files > 0, ("their files known to check against: %d"):format(files))
			data.memOff, data.framesOff = MemoryKB(), FrameCount()
			r:Log(("memory %.0f KB (on: %.0f), %d frames (on: %d)"):format(data.memOff or -1, data.memOn or -1,
				data.framesOff, data.framesOn or -1))
			r:Verdict(data.memOff and data.memOn and data.memOff < data.memOn,
				("memory down %.0f KB without them"):format((data.memOn or 0) - (data.memOff or 0)))
			r:Verdict(data.framesOff < (data.framesOn or 0),
				("%d frames fewer without them"):format((data.framesOn or 0) - data.framesOff))
			-- (Ticked back and loaded again after the reload: runs 1-5. Proven, ticked
			-- back with no Reload box: they load again from your next /reload.)
			if r:Proven("ticking them back and the reload after (loadparts runs 1-5)") then
				for _, p in ipairs(Active(r)) do ns.SetModuleWanted(p.part, true) end
				if StaticPopup_Hide then StaticPopup_Hide(ns.MODULES_RELOAD_POPUP) end
				r:Log("ticked back on: they load again from your next /reload")
			else
				Flip(r, true)
			end
		end },
		{ key = "back", title = "both back",
			proven = "loadparts runs 1-5: every part loaded again, settings kept, frames and pages back",
			run = function(r)
			local data = Data()
			r:Verdict(CinematicDB.moduleDefaults == nil, "the copy of their defaults gone from the saved settings")
			for _, p in ipairs(Active(r)) do
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
