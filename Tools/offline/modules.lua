-- A part left out (Modules.lua: Visions General's Load Visions, Camera >
-- General's Load Cameras): its code never runs, the rest of the addon works
-- without it, and its settings stay. Each part (and both together) on each
-- client and copy: on, then off from the settings the on run left, as a player
-- switching it off has them (its defaults in CinematicDB.moduleDefaults),
-- then back on. Each a run of its own (nothing kept between).
--
--   On:   no errors; its code ran; its pages there; a setting of its changed,
--         then its page's Load box unticked (asks to reload); every frame's
--         events and update and every Why tab once, the errors that gives
--         noted (the stand-in's stubs make some of their own).
--   Off:  no errors; no frame, hook or timer made by its files; the same
--         DEFAULTS keys as on (profiles, sharing and Reset carry them), every
--         built-in profile's base the same as on; the
--         setting kept, in the profile too; its pages gone but its General;
--         its wheel, demos and Why tab rows as left out; a command into its
--         code says so; every event, update and Why tab with no error on
--         didn't have.
--   Back: loaded again, the setting as changed, the copy of its defaults gone.
--
--   python -I Tools/offline/run.py Tools/offline/modules.lua
-- Exit 1 on any problem.
local LUA = os.getenv("CINE_LUA") or "lua5.1"
local phase, client, toc, tmp, partArg = ...
local TOCS = { "Cinematic.toc", "CinematicDev.toc" }

-- Each part: its files, pages, Load box and what shows it's left out.
local SPECS = {
	visions = {
		label = "Visions",
		-- (Every Vision's code: Visions/, and in Atmosphere/ and Dev/ the ones there.)
		files = { "@Visions/", "Atmosphere/LowHealth", "Atmosphere/VitalsSound.lua", "Atmosphere/ManaVision.lua",
			"Atmosphere/TeleportVision.lua",
			"Atmosphere/DeathVision.lua", "Dev/WindGuide.lua" },
		-- (Its one frame loaded either way: the ambience volume put back after a
		-- cue cut short.)
		allowed = { "from @Visions/CombatSoundRules.lua" },
		pages = { "Heal Vision", "Damage Vision", "Quest Vision", "Roll Vision", "Duel Vision", "Emote Vision",
			"Card Vision", "Card Styles", "Damage Vision Look", "Quest Talk Style", "Quest Item Style", "Roll Style",
			"Visions Style", "Vitals Vision", "Death Vision", "Teleport Vision", "Vitals Style" },
		general = "Visions General", box = "Load Visions", ask = "Visions",
		setting = { "cardSleepBagOn", false },
		why = { tab = "visions", row = "visions:loaded" },
		demos = { "vitals", "tele", "emote", "deathVision", "cards" },
		master = "vision",
		slash = { "report", "you've left out" },
	},
	cameras = {
		label = "Cameras",
		files = { "@Camera/" },
		allowed = {},
		pages = { "Scenes", "Triggers", "Trigger Priority", "Trigger Log", "Trigger Settings", "Camera Scripts",
			"My Shots", "Shoulder Cam", "Skyriding Cam", "Camera Settings" },
		general = "Cameras", box = "Load Cameras", ask = "Cameras",
		setting = { "walkCine", true },
		why = { tab = "cameras", row = "cameras:loaded" },
		demos = { "camera", "cameraLook", "shoulder", "afk", "flight" },
		master = "camera",
		slash = { "flyby", "Cameras aren't loaded" },
	},
	style = {
		label = "Style",
		-- (Its files bar the toolkit loaded either way: StyleFonts, StylePages,
		-- ColorPalette, and the plates' name looks, NameRowLook.)
		files = { "@Style/", "Plates/PlateThemes.lua", "Plates/NameThemes.lua", "Plates/PlateRowLook.lua",
			"Plates/PlateCopy.lua" },
		loadedFiles = { "Style/StyleFonts.lua", "Style/StylePages.lua", "Style/ColorPalette.lua" },
		-- (Loaded either way, in Style files: the Atmosphere effect pages and
		-- their tabs (LetterboxStyle.lua), Roll Vision's tabs (RollStyle.lua).)
		-- (Anything they make: frames, scripts, events, hooks, timers.)
		allowed = { "from @Style/LetterboxStyle.lua", "from @Style/RollStyle.lua", "from @Style/StylePages.lua",
			"from @Style/ColorPalette.lua", "from @Style/StyleFonts.lua" },
		pages = { "Style Themes", "Style Overrides", "Interface Recolor", "Unit Style", "Personal Style", "Raid Style",
			"Action Style", "Combat Text Style", "Nameplate Style", "Name Style", "Bubble Style", "Tooltip Style", "Minimap Style",
			"Tint Style", "Letterbox Style", "Weather Style", "Visions Style", "Vitals Style", "Card Styles", "Damage Vision Look",
			"Emote Vision Style" },
		general = "Style General", box = "Load Style", ask = "Style",
		setting = { "tooltipFont", "friz" },
		demos = { "combatText" }, -- (the bubbles demo is Chat Bubbles', an Interface page)
		switch = "styleGeneral",
	},
	atmosphere = {
		label = "Atmosphere",
		-- (The tint (its vignette and gradient helpers and clock loaded either
		-- way, for Death Vision and the time of day), the letterbox (how bars
		-- are drawn stays in Effects.lua), edge haze, music, Graphics+ (its
		-- list of settings loaded: Core's defaults), the Letterbox and Tint pages.)
		files = { "Atmosphere/Tint.lua", "Atmosphere/Focus.lua", "Atmosphere/WeatherFX.lua", "Atmosphere/Music.lua",
			"Atmosphere/Letterbox.lua",
			"Graphics.lua", "Style/LetterboxStyle.lua" },
		allowed = {},
		pages = { "Tint", "Letterbox", "Weather", "Graphics+", "Audio", "Tint Style", "Letterbox Style", "Weather Style" },
		general = "Effects", box = "Load Atmosphere", ask = "Atmosphere",
		-- (Its settings are Core.lua's: none of its own to write down.)
		setting = { "vignetteStrength", 0.33 }, noOwnDefaults = true,
		why = { tab = "atmosphere", row = "atmosphere:loaded" },
		demos = { "bars", "letterbox", "tint", "audio" },
		slash = { "doftest", "you've left out" },
		switch = "visualEffects",
	},
}
local ORDER = { "visions", "cameras", "style", "atmosphere", "both", "all" }

-- Values as Lua source (the settings handed from one run to the next).
local function Dump(value)
	if type(value) == "table" then
		local parts = {}
		for k, v in pairs(value) do
			if type(v) ~= "function" then parts[#parts + 1] = "[" .. Dump(k) .. "]=" .. Dump(v) end
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif type(value) == "string" then
		return ("%q"):format(value)
	end
	return tostring(value)
end

-- A global a part's file defines (a key binding's Cinematic_...), read by
-- another file as it loads: that file now gets nothing (the part's code runs
-- later), with the part loaded too. (MarkerWheel.lua wrapped
-- Cinematic_CameraWheel so, 2026-11-22: lost with Cameras on, an error off.)
local function GlobalsReadAtLoad()
	local bad = {}
	local files, gated = {}, {}
	for line in io.lines("CinematicDev.toc") do
		line = line:gsub("\r", "")
		if line:find("%.lua$") and not line:find("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
	end
	local text = {}
	for _, path in ipairs(files) do
		local f = io.open(path, "r")
		if f then
			text[path] = f:read("*a")
			f:close()
			if text[path]:find('ns.Module("', 1, true) then gated[path] = true end
		end
	end
	local globals = {}
	for path in pairs(gated) do
		for name in text[path]:gmatch("\n%s*function (Cinematic_[%w_]+)%s*%(") do globals[name] = path end
		for name in text[path]:gmatch("\n%s*(Cinematic_[%w_]+)%s*=[^=]") do globals[name] = path end
	end
	for _, path in ipairs(files) do
		if text[path] and not gated[path] then
			local n = 0
			for line in (text[path] .. "\n"):gmatch("([^\n]*)\n") do
				n = n + 1
				if not line:find("^%s") and not line:find("^%-%-") then
					for name, from in pairs(globals) do
						if line:find(name, 1, true) then
							bad[#bad + 1] = ("%s:%d reads %s (%s's) as it loads"):format(path, n, name, from)
						end
					end
				end
			end
		end
	end
	return bad
end

if not phase then
	local failed = false
	for _, line in ipairs(GlobalsReadAtLoad()) do
		print("modules: " .. line)
		failed = true
	end
	for _, part in ipairs(ORDER) do
		for _, eachToc in ipairs(TOCS) do
			for _, eachClient in ipairs({ "forever", "retail" }) do
				local file = os.tmpname()
				for _, eachPhase in ipairs({ "on", "off", "back" }) do
					local pipe = io.popen(("%s Tools/offline/modules.lua %s %s %s %s %s 2>&1"):format(LUA, eachPhase,
						eachClient, eachToc, file, part))
					local out = pipe:read("*a")
					pipe:close()
					io.write(out)
					if not out:find(("modules %s %s %s %s: ok"):format(part, eachPhase, eachClient, eachToc), 1, true) then
						failed = true
					end
				end
				os.remove(file)
			end
		end
	end
	print(failed and "modules: FAILED" or "modules: all ok")
	os.exit(failed and 1 or 0)
end

local parts = partArg == "both" and { "visions", "cameras" } or partArg == "all" and { "visions", "cameras", "style", "atmosphere" }
	or { partArg }

local problems = {}
local function Problem(text) problems[#problems + 1] = text end

-- What a part's files make: frames, hooks and timers, by the file that asked.
local made = {}
local errors = {}
local function Caller()
	for level = 3, 12 do
		local info = debug.getinfo(level, "S")
		if not info then return nil end
		local source = info.source or ""
		for _, part in ipairs(parts) do
			for _, file in ipairs(SPECS[part].files) do
				if source:find(file, 1, true) then return source end
			end
		end
	end
end
-- (Off and back: from the last run's saved settings.)
local db
if phase == "off" or phase == "back" then
	db = (assert(loadfile(tmp))())
end

local ns, wow = dofile("Tools/offline/load.lua")(client, toc, function(stand)
	rawset(_G, "CinematicDB", db)
	rawset(_G, "geterrorhandler", function()
		return function(err) errors[#errors + 1] = tostring(err) end
	end)
	local make = _G.CreateFrame
	rawset(_G, "CreateFrame", function(...)
		local source = Caller()
		if source then made[#made + 1] = "frame from " .. source end
		return make(...)
	end)
	rawset(_G, "hooksecurefunc", function()
		local source = Caller()
		if source then made[#made + 1] = "hook from " .. source end
	end)
	local after = stand.Stub
	-- (Every timer and ticker, every event registered, every script set or
	-- hooked, by the part's file that asked: left out, none may happen.)
	local function Note(kind)
		local source = Caller()
		if source then made[#made + 1] = kind .. " from " .. source end
	end
	rawset(_G, "C_Timer", {
		After = function() Note("timer") end,
		NewTicker = function() Note("ticker") return after end,
		NewTimer = function() Note("timer") return after end,
	})
	local M = stand.Methods
	for _, name in ipairs({ "RegisterEvent", "RegisterUnitEvent", "SetScript", "HookScript" }) do
		local real = M[name]
		M[name] = function(self, what, fn, ...)
			-- (SetScript with nil clears a script: not a leak.)
			if not (name == "SetScript" and fn == nil) then
				Note((name:find("Event") and "event " or "script ") .. tostring(what))
			end
			return real(self, what, fn, ...)
		end
	end
end)

for _, w in ipairs(wow.warnings) do Problem("load: " .. w) end
for _, e in ipairs(errors) do Problem("error: " .. e) end
-- (A once-only settings update reading a part's code must wait for it: Migrations.lua.)
for _, e in ipairs(ns.migrationErrors or {}) do Problem("settings update: " .. e) end

-- Every frame's events and update, once each (stub arguments). A call that
-- runs on and on (a loop waiting on the stand-in's clock, which never moves)
-- is cut off after a while, an error of its own.
local RUNAWAY = "ran too long"
-- (With ran set: every Lua function called, by its file and first line, for
-- the leak scan below.)
local ran
local function Once(fn, ...)
	if ran then
		debug.sethook(function(event)
			if event == "count" then error(RUNAWAY) end
			local info = debug.getinfo(2, "S")
			if info and info.what == "Lua" then ran[info.source .. ":" .. info.linedefined] = info end
		end, "c", 100000000)
	else
		debug.sethook(function() error(RUNAWAY) end, "", 2000000)
	end
	local ok, err = pcall(fn, ...)
	debug.sethook()
	return ok, err
end

-- Leaks the other way: code loaded either way that still runs with a part
-- left out and calls into it (a function the part defines, or one of its
-- stand-ins): work done for a part that isn't there. Each such function the
-- event storm ran, by file and line, with the part's names it reads.
local function InPart(source, part)
	for _, file in ipairs(SPECS[part].files) do
		if source:find(file, 1, true) then return true end
	end
	return false
end
local fileLines = {}
local function Lines(path)
	if fileLines[path] == nil then
		local list = {}
		local f = io.open(path, "r")
		if f then
			for line in f:lines() do list[#list + 1] = (line:gsub("\r", "")) end
			f:close()
		end
		fileLines[path] = list
	end
	return fileLines[path]
end
local function TocFiles()
	local list = {}
	for line in io.lines("CinematicDev.toc") do
		line = line:gsub("\r", "")
		if line:find("%.lua$") and not line:find("^#") then list[#list + 1] = (line:gsub("\\", "/")) end
	end
	return list
end
-- The names a part's files give ns (and its stand-ins), less any a loaded file gives too.
local function PartNames(part)
	local names, shared = {}, {}
	for _, path in ipairs(TocFiles()) do
		local mine = InPart("@" .. path, part)
		for _, line in ipairs(Lines(path)) do
			for name in line:gmatch("^%s*function ns%.([%w_]+)") do (mine and names or shared)[name] = true end
			for name in line:gmatch("^%s*ns%.([%w_]+)%s*=[^=]") do (mine and names or shared)[name] = true end
		end
	end
	for name in pairs(shared) do names[name] = nil end
	for name in pairs(ns.MODULE_STAND_INS and ns.MODULE_STAND_INS[part] or {}) do names[name] = true end
	return names
end
-- (Every file's text as it was loaded, for the leak scan's lines: another
-- session's edit during a run moved them, 2026-11-22.)
for _, path in ipairs(TocFiles()) do Lines(path) end

-- Reviewed: loaded code that names a part but does no work for it while
-- it's left out (a guard first, a stand-in that does nothing, one call at
-- login). By file and the function's first line, the names it may read.
-- A new one fails until it's looked at (2026-11-22 audit: the effect rows,
-- the camera delay and the orbit's every-frame loop were real, and fixed).
local LEAK_OK = {
	["Core.lua local function OnUpdate(_, elapsed)"] = { "UpdateLetterbox", "UpdateMusic", "UpdateTint",
		"db.visualEffects", "UpdateTaxi", why = "atmo/LEFT_OUT guards; UpdateTint runs Death Vision; UpdateTaxi a stand-in" },
	['Core.lua ticker:SetScript("OnEvent", ns.Profiled("Core events", function(self, event, arg1, arg2)'] = {
		"CreateLetterbox", "CreateTint", "MusicTrace", "RestoreMusicVolume", "StopCombatMusicNow", "StopDeathSongNow",
		"StopMusicNow", "HookCameraInput", "HookTaxiRoutes", "LoginZoom", "StopIdleZoomNow", "StopOrbitNow",
		"db.styleGeneral", "ShowTimeOfDayTitle", why = "login and logout: one stand-in call each; styleGeneral behind ModuleLoaded" },
	["Core.lua Guard(function()"] = { "MusicTrace", why = "login/logout trace line: a stand-in" },
	["Core.lua function ns.CameraOffBesidesRows(cam)"] = { "db.cameraModes", why = "LEFT_OUT.cameraModes returns first" },
	["Core.lua function ns.IsCameraOffHere(cam)"] = { "CameraRowsOff", why = "a stand-in: off" },
	["Core.lua local function ShouldBeCinematic(now)"] = { "ActiveEvent", "TriggerStartsCine", why = "stand-ins: no" },
	["Frames.lua function ns.ApplyUnitFrameParts()"] = { "StyleOverride", why = "a stand-in: no override" },
	["Profiles/Welcome.lua local function UpdateChoices()"] = { "ActiveStyleTheme", why = "the window's own: a stand-in" },
	-- (One part calling another left out: a stand-in.)
	["Camera/Camera.lua function ns.UpdateOrbit(cinematic, elapsed)"] = { "SetDeathSong", why = "Atmosphere's stand-in" },
	["Camera/CameraScripts.lua local function Finish(why)"] = { "EndSceneMusic", why = "Atmosphere's stand-in" },
	["Visions/Cards.lua function ns.Cards.Fire(id, card, force)"] = { "LetterboxUp", why = "Atmosphere's stand-in: no bars" },
	["Visions/FlightLine.lua local function Wanted()"] = { "FlightDuration", why = "Cameras' stand-in" },
}

local function LeakScan(part)
	local names = PartNames(part)
	local found = {}
	for _, info in pairs(ran or {}) do
		local source = info.source or ""
		local path = source:match("^@(.*)")
		local inAnyPart = false
		for _, each in ipairs(parts) do if InPart(source, each) then inAnyPart = true end end
		if path and not path:find("^Tools/") and not inAnyPart then
			local lines = Lines(path)
			local reads = {}
			for n = info.linedefined, math.min(info.lastlinedefined, #lines) do
				local code = lines[n]:gsub("%-%-.*", "")
				for name in code:gmatch("ns%.([%w_]+)") do
					if names[name] then reads[name] = true end
				end
				-- (And a left-out switch read straight from the settings, past
				-- ns.Setting: it reads on, and the part's work goes on.)
				for name in code:gmatch("db%.([%w_]+)") do
					if ns.LEFT_OUT_SWITCHES and ns.LEFT_OUT_SWITCHES[name] then reads["db." .. name] = true end
				end
			end
			local list = {}
			for name in pairs(reads) do list[#list + 1] = name end
			local key = path .. " " .. (lines[info.linedefined] or ""):gsub("^%s+", ""):gsub("%s+$", "")
			local ok = LEAK_OK[key]
			local new = {}
			for _, name in ipairs(list) do
				local fine = false
				for _, each in ipairs(ok or {}) do if each == name then fine = true end end
				if not fine then new[#new + 1] = name end
			end
			if #new > 0 then
				table.sort(new)
				found[#found + 1] = ("%s:%d (%s) reads %s"):format(path, info.linedefined, key, table.concat(new, ", "))
			end
		end
	end
	table.sort(found)
	return found
end
local function Storm()
	local seen = {}
	local list = {}
	for _, frame in ipairs(wow.frames) do list[#list + 1] = frame end
	for _, frame in ipairs(list) do
		local onEvent = frame._scripts and frame._scripts.OnEvent
		if onEvent then
			local events = {}
			for event in pairs(frame._events or {}) do events[#events + 1] = event end
			table.sort(events)
			for _, event in ipairs(events) do
				local ok, err = Once(onEvent, frame, event)
				if not ok then seen[tostring(err)] = true end
			end
		end
		local onUpdate = frame._scripts and frame._scripts.OnUpdate
		if onUpdate then
			local ok, err = Once(onUpdate, frame, 0.1)
			if not ok then seen[tostring(err)] = true end
		end
	end
	return seen
end

-- Every tab of the Why window (/cine why) filled once: errors by message,
-- and each tab's sections.
local function WhyTabs()
	local seen, tabs = {}, {}
	for _, provider in ipairs(ns.WhyProviders and ns.WhyProviders() or {}) do
		local ok, sections = pcall(provider.fn)
		if not ok then seen[tostring(sections)] = true end
		tabs[provider.id] = ok and type(sections) == "table" and sections or false
	end
	return seen, tabs
end

-- The Why window's Visions and Atmosphere tabs: Atmosphere a tab of its own
-- with its pages' rows either way, the Visions tab holding Visions only.
local function WhyVisionTabs(visionsOn)
	local _, tabs = WhyTabs()
	local ids = {}
	for _, provider in ipairs(ns.WhyProviders and ns.WhyProviders() or {}) do
		if not provider.into then ids[#ids + 1] = provider.id end
	end
	local atmo = tabs.atmosphere
	if not atmo then
		Problem("no Atmosphere tab in the Why window")
	elseif #atmo ~= 1 or #(atmo[1].rows or {}) == 0 then
		Problem(("the Why window's Atmosphere tab: %d sections, %d rows"):format(#atmo, #(atmo[1] and atmo[1].rows or {})))
	end
	local vis = tabs.visions
	if not vis then
		Problem("no Visions tab in the Why window")
	elseif #vis ~= 1 then
		Problem(("the Why window's Visions tab has %d sections, not just Visions"):format(#vis))
	elseif visionsOn and #(vis[1].rows or {}) < 2 then
		Problem("the Why window's Visions tab lists no Visions")
	end
	local order = table.concat(ids, " ")
	local want = "cameras cards visions atmosphere addons"
	if order ~= want then Problem(("the Why window's tabs go %s, not %s"):format(order, want)) end
end

-- Each built-in profile's base (ns.ProfileBase), its settings that are a
-- value (not a list): the same with a part left out as loaded. Auto-Hide UI's
-- scenes came out on with Cameras out (its base ticked them off from the
-- Cameras page's triggers), and it showed "(changed)" after a reset, 2026-11-22.
local function Bases()
	local bases = {}
	if ns.ForgetProfileBases then ns.ForgetProfileBases() end
	for _, profile in ipairs(ns.BUILTIN_PROFILES or {}) do
		local values = {}
		for k, v in pairs(ns.ProfileBase(profile.name)) do
			if type(v) ~= "table" and type(v) ~= "function" then values[k] = v end
		end
		bases[profile.name] = values
	end
	return bases
end

-- A part's General page's Load box, found by its label.
local canvases = ns.settingsCanvases or {}
local function Box(spec)
	local box
	local function Walk(frame)
		for _, child in ipairs(rawget(frame, "_children") or {}) do
			for _, region in ipairs(rawget(child, "_regions") or {}) do
				if rawget(region, "_text") == spec.box and child._kind == "CheckButton" then box = child end
			end
			Walk(child)
		end
	end
	if canvases[spec.general] then Walk(canvases[spec.general]) end
	return box
end

if phase == "on" then
	local bases = Bases()
	local keys = {}
	for k in pairs(ns.DEFAULTS) do keys[#keys + 1] = k end
	if partArg == "visions" then WhyVisionTabs(true) end
	local asked
	rawset(_G, "StaticPopup_Show", function(which, text) asked = which .. ": " .. tostring(text) end)
	-- (Not written down while they're on: only as each is switched off, below.)
	if CinematicDB.moduleDefaults then Problem("defaults saved while the parts are on") end
	-- Picking Auto-Hide UI or Blank Slate leaves Visions, Cameras and Style out and
	-- asks to reload; another built-in puts them back (nothing to reload: the
	-- popup goes); your own profile leaves them (ns.ProfilePartsPicked).
	do
		local hidden
		rawset(_G, "StaticPopup_Hide", function(which) hidden = which end)
		-- (The Load boxes' box, Modules.lua: every part this copy has.)
		local NAMES = { visions = "Visions", cameras = "Cameras", style = "Style", atmosphere = "Atmosphere" }
		local OUT = { "Reload now to unload " }
		for part in pairs(ns.MODULE_KEYS) do OUT[#OUT + 1] = NAMES[part] or part end
		for _, each in ipairs({ { "Auto-Hide UI", false, OUT }, { "Balanced", true },
			{ "Blank Slate", false, OUT }, { "Cinema", true } }) do
			asked, hidden = nil, nil
			ns.ProfilePartsPicked(each[1])
			-- (Every part: one a built-in doesn't decide yet is a problem, a
			-- reminder to add it to Auto-Hide UI / Blank Slate's leaveOut.)
			for part in pairs(ns.MODULE_KEYS) do
				if ns.ModuleWanted(part) ~= each[2] then
					Problem(("picking %s left %s wanted %s"):format(each[1], part, tostring(ns.ModuleWanted(part))))
				end
			end
			if each[3] then
				for _, text in ipairs(each[3]) do
					if not (asked and asked:find(text, 1, true) and asked:find("CINEMATIC_LOAD_PARTS", 1, true)) then
						Problem(("picking %s didn't say \"%s\": %s"):format(each[1], text, tostring(asked)))
					end
				end
			elseif asked or hidden ~= "CINEMATIC_LOAD_PARTS" then
				Problem(("picking %s with the parts loaded: asked %s, hid %s"):format(each[1], tostring(asked), tostring(hidden)))
			end
		end
		ns.ProfilePartsPicked("Auto-Hide UI")
		asked = nil
		if next((ns.ProfilePartsPicked("My own"))) or not next((ns.ProfilePartsPicked("Subtle"))) or asked then
			Problem("your own profile changed a Load box, or Subtle didn't bring them back")
		end
		local off = false
		for _, key in pairs(ns.MODULE_KEYS) do
			if CinematicDB[key] ~= true then off = true end
		end
		if off or CinematicDB.moduleDefaults then
			Problem("picking the profiles left a part off, or its defaults written down, with it back on")
		end
	end
	for _, part in ipairs(parts) do
		local spec = SPECS[part]
		if not ns.ModuleLoaded(part) then Problem(spec.label .. " didn't load") end
		local found = 0
		for _, name in ipairs(spec.pages) do
			if canvases[name] then found = found + 1 end
		end
		if found < 3 then Problem(("only %d of %s' pages there with it on"):format(found, spec.label)) end
		-- One of its settings changed, then its page's box unticked (then a
		-- /reload: the off run).
		ns.db[spec.setting[1]] = spec.setting[2]
		local box = Box(spec)
		if not box then
			Problem(("no %s box on %s"):format(spec.box, spec.general))
			ns.SetModuleWanted(part, false)
		else
			box:SetChecked(false)
			box._scripts.OnClick(box)
			if not (asked and asked:find("Reload now to unload ", 1, true) and asked:find(spec.ask, 1, true)) then
				Problem(("unticking %s didn't ask to reload: %s"):format(spec.box, tostring(asked)))
			end
		end
		local kept = CinematicDB.moduleDefaults and CinematicDB.moduleDefaults[part]
		if not spec.noOwnDefaults and (type(kept) ~= "table" or kept[spec.setting[1]] == nil) then
			Problem(("no %s defaults kept as it's switched off"):format(spec.label))
		end
		if CinematicDB[ns.MODULE_KEYS[part]] ~= false then Problem(spec.box .. " didn't save as off") end
	end
	if #made == 0 then Problem("no frames from the part's files: the check can't see them") end
	local saved = Dump(CinematicDB) -- (before the storm changes anything)
	local storm = Storm()
	for err in pairs((WhyTabs())) do storm[err] = true end
	local file = assert(io.open(tmp, "w"))
	file:write("return ", saved, ", ", Dump(keys), ", ", Dump(storm), ", ", Dump(bases), "\n")
	file:close()
elseif phase == "off" then
	local _, onKeys, onStorm, onBases = assert(loadfile(tmp))()
	local differ = 0
	for name, values in pairs(Bases()) do
		for k, v in pairs(onBases[name] or {}) do
			if values[k] ~= v and ns.DEFAULTS[k] ~= nil then
				differ = differ + 1
				if differ <= 5 then
					Problem(("%s's base has %s = %s left out, %s loaded"):format(name, k, tostring(values[k]), tostring(v)))
				end
			end
		end
	end
	if differ > 5 then Problem(("...%d built-in base settings differ in all"):format(differ)) end
	local allowed = {}
	for _, part in ipairs(parts) do
		for _, line in ipairs(SPECS[part].allowed) do allowed[#allowed + 1] = line end
	end
	for _, line in ipairs(made) do
		local ok = false
		for _, each in ipairs(allowed) do
			if line:find(each, 1, true) then ok = true end
		end
		if not ok then Problem("made while left out: " .. line) end
	end
	local missing = 0
	for _, k in ipairs(onKeys) do
		if ns.DEFAULTS[k] == nil then
			missing = missing + 1
			if missing <= 5 then Problem("default missing while left out: " .. k) end
		end
	end
	if missing > 5 then Problem(("...%d defaults missing in all"):format(missing)) end
	local _, whyTabs = WhyTabs()
	local settings = ns.ProfileSettings and ns.ProfileSettings(ns.ActiveProfile())
	for _, part in ipairs(parts) do
		local spec = SPECS[part]
		local key, value = spec.setting[1], spec.setting[2]
		if ns.db[key] ~= value then Problem(("%s' setting %s lost while left out"):format(spec.label, key)) end
		if not settings or settings[key] ~= value then Problem(("%s' setting %s not in the profile"):format(spec.label, key)) end
		if ns.ModuleLoaded(part) then Problem(spec.label .. " loaded while off") end
		for _, name in ipairs(spec.pages) do
			if canvases[name] then Problem(("%s page still there while left out: %s"):format(spec.label, name)) end
		end
		if not canvases[spec.general] then Problem(spec.general .. " gone while left out") end
		if not Box(spec) then Problem(("no %s box on %s while left out"):format(spec.box, spec.general)) end
		-- (What the menu shows there: the page with its box, not the off card
		-- over it. Camera > General showed "General is off", 2026-11-22.)
		local card = ns.PageOffCardWanted and ns.PageOffCardWanted(spec.general)
		if card ~= false then
			Problem(("%s shows %s while left out, not its Load box"):format(spec.general,
				card and "its off card" or "nothing (no such page in the menu)"))
		end
		for _, choice in ipairs(ns.MASTER_WHEEL_CHOICES or {}) do
			if choice.key == spec.master then Problem("the master wheel still has the " .. spec.master .. " wheel") end
		end
		for _, demo in ipairs(spec.demos) do
			if ns.ShowMeAvailable and ns.ShowMeAvailable(demo) then Problem("the Welcome window still offers " .. demo) end
		end
		-- (Its Why tab: one row saying it isn't loaded. Style has none.)
		local tab = spec.why and whyTabs[spec.why.tab]
		local row = tab and tab[1] and tab[1].rows and tab[1].rows[1]
		if spec.why and not (row and row.key == spec.why.row and row.status == "off") then
			Problem(("the Why window's %s tab doesn't say %s aren't loaded"):format(spec.why.tab, spec.label))
		end
		-- A command into its code: a line saying so, no error.
		if spec.slash then
			local said
			local print0 = ns.Print
			ns.Print = function(text) said = tostring(text) end
			local ok, err = pcall(ns.HandleSlash, spec.slash[1])
			ns.Print = print0
			if not ok then Problem(("/cine %s errored while left out: %s"):format(spec.slash[1], tostring(err))) end
			if not (said and said:find(spec.slash[2], 1, true)) then
				Problem(("/cine %s while left out didn't say so: %s"):format(spec.slash[1], tostring(said)))
			end
		end
		-- (Its switches read off: the master's, so every page under it.)
		if spec.switch and ns.Setting(spec.switch) ~= false then Problem(spec.switch .. " doesn't read off while left out") end
		if part == "style" and ns.StyleOn(nil) then Problem("ns.StyleOn says Style is on while left out") end
	end
	if partArg == "visions" then
		for _, vision in ipairs(ns.VISION_LIST or {}) do Problem("vision wheel still has " .. vision.key) end
		-- (Its Cards tab kept, one row saying Visions aren't loaded.)
		local cards = whyTabs.cards
		local row = cards and cards[1] and cards[1].rows and cards[1].rows[1]
		if not (row and row.key == "cards:loaded" and row.status == "off" and #cards == 1) then
			Problem("the Why window's Cards tab doesn't say Visions aren't loaded")
		end
		WhyVisionTabs(false)
	end
	-- Left out: a built-in using it asks to reload to load it; Blank Slate
	-- then wants it out as it is (nothing to reload for it; the parts still
	-- loaded ask). Every part wanted again after (Subtle), for the back run.
	do
		local asked, hidden
		rawset(_G, "StaticPopup_Show", function(which, text) asked = which .. ": " .. tostring(text) end)
		rawset(_G, "StaticPopup_Hide", function(which) hidden = which end)
		-- (Modules.lua's words, "Reload now to load Visions, Cameras")
		local WORDS = { visions = { "Visions" }, cameras = { "Cameras" }, style = { "Style" },
			atmosphere = { "Atmosphere" } }
		ns.ProfilePartsPicked("Balanced")
		for _, part in ipairs(parts) do
			if not (ns.ModuleWanted(part) and asked and asked:find(WORDS[part][1], 1, true)
				and asked:find("Reload now to load ", 1, true)) then
				Problem(("picking Balanced with %s left out didn't ask to reload it in: %s"):format(part, tostring(asked)))
			end
		end
		asked, hidden = nil, nil
		ns.ProfilePartsPicked("Blank Slate")
		for _, part in ipairs(parts) do
			if ns.ModuleWanted(part) then Problem("picking Blank Slate with " .. part .. " left out wanted it") end
		end
		-- (All out: nothing to reload. Some out: the loaded ones ask, only they.)
		local out, loadedOnes = {}, {}
		for _, part in ipairs(parts) do out[part] = true end
		for part in pairs(ns.MODULE_KEYS) do
			if not out[part] then loadedOnes[#loadedOnes + 1] = part end
		end
		if #loadedOnes == 0 then
			if asked or hidden ~= "CINEMATIC_LOAD_PARTS" then
				Problem("picking Blank Slate with every part left out asked to reload: " .. tostring(asked))
			end
		else
			for part in pairs(ns.MODULE_KEYS) do
				local says = asked and asked:find(WORDS[part][1], 1, true)
				if (out[part] and says) or (not out[part] and not says) then
					Problem(("picking Blank Slate with %s left out asked wrong about %s: %s"):format(
						table.concat(parts, "+"), part, tostring(asked)))
				end
			end
		end
		ns.ProfilePartsPicked("Subtle")
	end
	-- Back on (then a /reload: the back run).
	for _, part in ipairs(parts) do ns.SetModuleWanted(part, true) end
	local saved = Dump(CinematicDB)
	ran = {}
	for err in pairs(Storm()) do
		if not onStorm[err] then Problem("event error while left out: " .. err) end
	end
	for _, part in ipairs(parts) do
		for _, line in ipairs(LeakScan(part)) do
			Problem(("loaded code still calls into %s while it's left out: %s"):format(part, line))
		end
	end
	ran = nil
	for err in pairs((WhyTabs())) do
		if not onStorm[err] then Problem("Why window error while left out: " .. err) end
	end
	local file = assert(io.open(tmp, "w"))
	file:write("return ", saved, "\n")
	file:close()
else
	-- Back on: its code runs, the setting changed before is as it was, the
	-- copy of its defaults gone from the saved settings.
	for _, part in ipairs(parts) do
		local spec = SPECS[part]
		if not ns.ModuleLoaded(part) then Problem(spec.label .. " didn't load again") end
		if ns.db[spec.setting[1]] ~= spec.setting[2] then Problem(spec.label .. "' setting lost after off and on") end
		local found = 0
		for _, name in ipairs(spec.pages) do
			if canvases[name] then found = found + 1 end
		end
		if found < 3 then Problem(("only %d of %s' pages back"):format(found, spec.label)) end
	end
	if CinematicDB.moduleDefaults ~= nil then Problem("the copy of the defaults stayed once loaded") end
end

local tag = ("modules %s %s %s %s"):format(partArg, phase, client, toc)
for _, text in ipairs(problems) do print(tag .. ": " .. text) end
if #problems == 0 then print(tag .. ": ok") end
