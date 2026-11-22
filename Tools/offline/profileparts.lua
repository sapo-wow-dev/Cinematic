-- /cine debug profileparts (Dev/ProfilePartsTest.lua) on the stand-in, both
-- clients, with pretend time: step 1 up to your click on Reload UI (the
-- stand-in can't reload: the reloads' states are Tools/offline/modules.lua's
-- on / off / back runs), its verdicts as the code has it, the box the Load
-- boxes' own, its place where the game puts it; then stopped, and your
-- profile and Load boxes put back.
--   python -I Tools/offline/run.py Tools/offline/profileparts.lua
-- Exit 1 on any problem.
-- luacheck: push ignore 111 112 113 121 122 212
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end
local function Has(log, pattern)
	for _, line in ipairs(log or {}) do
		if line:find(pattern) then return line end
	end
end

for _, client in ipairs({ "forever", "retail" }) do
	print("== " .. client)
	local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
	-- (What a profile switch reads that the stand-in hasn't: Edit Mode's
	-- layouts, the chat bubbles, a frame's layer.)
	C_EditMode = C_EditMode or {}
	C_EditMode.GetLayouts = function() return { layouts = {}, activeLayout = 1 } end
	C_ChatBubbles = C_ChatBubbles or {}
	C_ChatBubbles.GetAllChatBubbles = function() return {} end
	wow.Methods.SetFrameStrata = function(self, strata) rawset(self, "_strata", strata) end
	wow.Methods.GetFrameStrata = function(self) return rawget(self, "_strata") or "MEDIUM" end
	wow.Methods.Click = function(self, button)
		local fn = self:GetScript("OnClick")
		if fn then fn(self, button or "LeftButton") end
	end
	local now = 100
	local timers = {}
	GetTime = function() return now end
	C_Timer.After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end
	local function Advance(seconds)
		local stop = now + seconds
		while now < stop do
			now = now + 0.1
			local due = {}
			for i = #timers, 1, -1 do
				if timers[i].at <= now then due[#due + 1] = table.remove(timers, i) end
			end
			for i = #due, 1, -1 do due[i].fn() end
		end
	end
	Screenshot = function() end
	ns.PadTestBox = function() end
	ns.PadTestBoxHide = function() end
	-- The game's popups, as far as the test reads them: shown by name, with text.
	local popups = {}
	StaticPopup_Show = function(which, text)
		local f = CreateFrame("Frame", "StaticPopupStandIn" .. which, UIParent)
		f.which = which
		local info = StaticPopupDialogs[which]
		local fs = f:CreateFontString()
		fs:SetText(text)
		f.text = fs
		-- (The game's first box's spot; the stand-in keeps no points.)
		rawset(f, "GetPoint", function() return "TOP", UIParent, "TOP", 0, -135 end)
		rawset(f, "_strata", "DIALOG")
		f:Show()
		if info and info.OnShow then info.OnShow(f) end
		popups[which] = f
		return f
	end
	StaticPopup_Hide = function(which)
		local f = popups[which]
		if f then
			popups[which] = nil
			local info = StaticPopupDialogs[which]
			if info and info.OnHide then info.OnHide(f) end
			f:Hide()
		end
	end
	StaticPopup_FindVisible = function(which) return popups[which] end

	ns.db.profileChosen = true
	local startProfile = ns.ActiveProfile()
	ns.HandleSlash("debug profileparts")
	Advance(5)
	local log = CinematicDB.profilePartsTestLog
	Check("waits for your click on Reload UI", Has(log, "asked: Click Reload UI in the game's box") ~= nil)
	Check("the rest saved for after the reload", CinematicDB.profilePartsTestResume
		and CinematicDB.profilePartsTestResume.steps == "3 4", CinematicDB.profilePartsTestResume
		and CinematicDB.profilePartsTestResume.steps)
	for _, line in ipairs(log or {}) do
		-- (Edges: the stand-in's frames have no size.)
		if line:find("verdict FAIL") and not line:find("not on the welcome window", 1, true)
			and not line:find("moved under the box", 1, true) then
			Check("verdict", false, line)
		end
	end
	Check("both wanted out", Has(log, "PASS pick: Auto%-Hide UI: visions left out") and Has(log, "PASS pick: Auto%-Hide UI: cameras left out"))
	Check("the Load boxes' box, its words", Has(log, "PASS pick: Auto%-Hide UI: says") ~= nil, Has(log, ": says"))
	Check("at the game's spot", Has(log, "PASS pick: Auto%-Hide UI: at the game's spot") ~= nil)
	-- (Three parts: "a, b and c", not "a and b and c": run 5.)
	Check("the words: one list", not ns.MODULE_KEYS.style or Has(log, 'text="Auto%-Hide UI: reload now to leave Visions out, leave the cameras out and leave Style out%?"') ~= nil,
		Has(log, 'fields Auto%-Hide UI box'))
	Check("only one box up", popups.CINEMATIC_LOAD_PARTS ~= nil and popups.CINEMATIC_PROFILE_PARTS == nil)
	ns.HandleSlash("debug profileparts") -- (typed again: stopped, put back)
	Check("stopped", Has(CinematicDB.profilePartsTestLog, "STOPPED: ") ~= nil)
	Check("profile put back", ns.ActiveProfile() == startProfile, ns.ActiveProfile())
	Check("Load boxes put back", ns.ModuleWanted("visions") and ns.ModuleWanted("cameras")
		and CinematicDB.moduleDefaults == nil)
	Check("no box left up", next(popups) == nil)
	CinematicDB.profilePartsTestResume = nil

	-- Visions left out at the start (run 2 in game): step 1 ticks both and
	-- shows the box saying load it, then waits on your click; the rest after.
	local realLoaded = ns.ModuleLoaded
	ns.ModuleLoaded = function(part) if part == "visions" then return false end return realLoaded(part) end
	ns.HandleSlash("debug profileparts")
	Advance(5)
	log = CinematicDB.profilePartsTestLog
	Check("left out at the start: says so", Has(log, "left out at the start: visions") ~= nil)
	Check("left out at the start: the box says load Visions", Has(log, "PASS ready: Loading them: says load Visions") ~= nil,
		Has(log, ": says"))
	Check("left out at the start: waits on Reload UI, then every step", Has(log, "asked: Click Reload UI") ~= nil
		and CinematicDB.profilePartsTestResume and CinematicDB.profilePartsTestResume.steps == "2 3 4",
		CinematicDB.profilePartsTestResume and CinematicDB.profilePartsTestResume.steps)
	ns.HandleSlash("debug profileparts")
	ns.ModuleLoaded = realLoaded
	CinematicDB.profilePartsTestResume = nil
	-- No box up (nothing changed): no wait, a FAIL, on to the end.
	local realAsk = ns.AskModulesReload
	ns.AskModulesReload = function() end
	ns.ModuleLoaded = function(part) if part == "visions" then return false end return realLoaded(part) end
	ns.HandleSlash("debug profileparts 1")
	Advance(5)
	log = CinematicDB.profilePartsTestLog
	Check("no box: no wait on Reload UI", Has(log, "asked: Click Reload UI") == nil and Has(log, "FAIL ready: no Reload box up") ~= nil
		and Has(log, "DONE: ") ~= nil, Has(log, "DONE: "))
	ns.ModuleLoaded, ns.AskModulesReload = realLoaded, realAsk
	for _, part in ipairs({ "visions", "cameras" }) do ns.SetModuleWanted(part, true) end

	-- The welcome window under the game's boxes (Welcome.lua KeepUnderBoxes),
	-- with pretend places: a box up whose bottom is under the window's top
	-- moves the window just under it; one already clear moves nothing; all
	-- gone, the window's own spot back; closing puts it back too.
	ns.ShowWelcome()
	local w = rawget(_G, "CinematicWelcome")
	local placed = {}
	local own = { "CENTER", UIParent, "CENTER", 0, 60 }
	local top = 900
	rawset(w, "GetTop", function() return top end)
	rawset(w, "GetCenter", function() return 600, 500 end)
	rawset(w, "GetPoint", function() return unpack(placed[#placed] or own) end)
	rawset(w, "ClearAllPoints", function() end)
	rawset(w, "SetPoint", function(_, ...) placed[#placed + 1] = { ... } end)
	rawset(w, "GetEffectiveScale", function() return 1 end)
	rawset(UIParent, "GetEffectiveScale", function() return 1 end)
	local box = { shown = true, bottom = 800 }
	local frame = CreateFrame("Frame")
	rawset(frame, "IsShown", function() return box.shown end)
	rawset(frame, "GetBottom", function() return box.bottom end)
	rawset(frame, "GetEffectiveScale", function() return 1 end)
	_G.StaticPopup1 = frame
	w.KeepUnderBoxes()
	local last = placed[#placed]
	Check("a box over the window's top: moved just under it", last and last[1] == "TOP" and last[5] == 792
		and w.ownPoint ~= nil, last and table.concat({ tostring(last[1]), tostring(last[5]) }, " "))
	box.bottom = 700 -- (a taller box: under that one)
	w.KeepUnderBoxes()
	Check("a taller box: under that one", placed[#placed][5] == 692, placed[#placed][5])
	box.shown = false
	w.KeepUnderBoxes()
	Check("box gone: its own spot back", placed[#placed][1] == "CENTER" and placed[#placed][5] == 60
		and w.ownPoint == nil, placed[#placed][1])
	local n = #placed
	box.shown, box.bottom, top = true, 800, 750 -- (the window already under the box)
	w.KeepUnderBoxes()
	Check("already clear of the box: not moved", #placed == n and w.ownPoint == nil, #placed - n)
	top = 900
	w.KeepUnderBoxes()
	w.KeepUnderBoxes(true) -- (as it closes)
	Check("closing while moved: its own spot back", placed[#placed][1] == "CENTER" and w.ownPoint == nil)
	_G.StaticPopup1 = nil
end
print(fails == 0 and "profileparts: all ok" or ("profileparts: " .. fails .. " FAILED"))
os.exit(fails == 0 and 0 or 1)
-- luacheck: pop
