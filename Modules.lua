-- Parts of the addon that can be left out, so their code never runs (no
-- frames, events, hooks or update loops): Visions, from its General page's
-- Load Visions switch (2026-11-21), and Cameras, from Camera > General's
-- Load Cameras, Style from Style > General's Load Style, and Atmosphere from
-- Atmosphere > General's Load Atmosphere. One addon in the game's AddOns
-- list, not one per part.
--
-- A part's files load as every file does, but only their settings and data
-- run then (ns.DEFAULTS and the like: profiles, sharing and Reset keep them
-- with the part left out). The rest of each file is a function handed to
-- ns.Module. The saved settings arrive only once every file has run
-- (ADDON_LOADED), so those functions wait till then: ns.RunModules runs them
-- in .toc order as the first thing at ADDON_LOADED (Locales.lua calls it
-- before it sets the language, so they see what the files saw as they
-- loaded), each part's unless it's switched off.
--
-- The choice is CinematicDB.load<Part> (loadVisions = false: left out),
-- outside the profiles: a profile can't take a part away, and it needs a
-- /reload either way. Tools/offline/modules.lua checks both ways.
local _, ns = ...

-- name -> the CinematicDB key that leaves it out (false)
local PARTS = { visions = "loadVisions", cameras = "loadCameras", style = "loadStyle", atmosphere = "loadAtmosphere" }
ns.MODULE_KEYS = PARTS

-- What the rest of the addon asks a part as it plays, with that part left
-- out: "no", nothing done. (Every nameplate asks Quest Vision about its unit;
-- the panels tell Quest Talk where the game's window was.) Only ones called
-- without a check first: a check (if ns.X then) is left to find nothing.
local function No() return false end
local function Nothing() end
ns.MODULE_STAND_INS = {
	visions = { IsQuestMob = No, SoftPlateHidden = No, CardOn = No, SetQuestMark = Nothing, NoteTalkSpot = Nothing,
		ShowTimeOfDayTitle = Nothing },
	-- (Every camera off and why; no scene, script or camera running; the
	-- calls that move or stop one doing nothing.)
	cameras = {
		TriggerSetting = No, TriggerStartsCine = No, TriggerHasCamera = No, StillRunsAFK = No, CameraRowsScripted = No,
		CameraCall = No, TriggerRowNow = Nothing, PlayingCameraScript = Nothing, PlayingCameraKey = Nothing,
		FlightDuration = Nothing, ActiveEvent = Nothing, FindCameraScript = Nothing,
		CameraRowsOff = function() return true end,
		CameraRowsOffWhy = function() return "Cameras aren't loaded (Load Cameras is off)" end,
		CameraWheelCant = function() return ns.L["Cameras aren't loaded"] end,
		PlayCameraScript = function() return false, ns.L["Cameras aren't loaded"] end,
		ToggleFlyBy = function() return false, ns.L["Cameras aren't loaded"] end,
		StopOrbitNow = Nothing, StopIdleZoomNow = Nothing, CancelDeathZoom = Nothing, UpdateOrbit = Nothing,
		UpdateTaxi = Nothing, HookCameraInput = Nothing, HookTaxiRoutes = Nothing, LoginZoom = Nothing,
		StandUpFromDeathTest = Nothing, LieDownForDeathTest = Nothing, CloseCameraWheel = Nothing,
		StopCameraScript = Nothing, CallCameraFunction = Nothing, OpenCameraWheel = Nothing, OnPlayerZoom = Nothing,
	},
	-- (No theme, override or row look: the game's look, as with every Style
	-- page off. The swipe texture the cooldown text uses either way.)
	style = {
		StyleOverride = Nothing, ThemePanel = Nothing, ThemeRing = Nothing, ThemeOrnament = Nothing,
		ThemeTailArt = Nothing, HideThemeSlice = Nothing, ThemeNoSnap = Nothing, DressThemeGrain = Nothing,
		DressThemeCorners = Nothing, RefreshQuestTrackerStyle = Nothing, RestoreStyleThemeBackup = Nothing,
		RestoreDeletedStyleTheme = Nothing, DressThemeSlice = No, PlateLooksOn = No, PlateLookNow = No,
		ActiveStyleTheme = function() return {} end, StyleThemeBackups = function() return {}, {} end,
		AddProfileStyleTheme = function() return nil, ns.ModuleLeftOutLine("style") end,
		SQUARE_SWIPE = "Interface\\Buttons\\WHITE8X8",
	},
	-- (No tint, letterbox, haze, Graphics+ or music: nothing drawn, written or
	-- faded. Death Vision's screen, a Vision, is made and run by the tint's
	-- calls: with the tint left out these make and run it alone. The music
	-- volume isn't remembered, as with the Audio page off.)
	atmosphere = {
		CreateTint = function() if ns.CreateDeathScreen then ns.CreateDeathScreen() end end,
		UpdateTint = function(_, elapsed) if ns.UpdateDeathVision then ns.UpdateDeathVision(elapsed or 0) end end,
		HideTintWash = Nothing, RefreshTint = Nothing, CreateLetterbox = Nothing, UpdateLetterbox = Nothing,
		LetterboxUp = No, LetterboxOnDiscover = Nothing, UpdateMusic = Nothing, StopMusicNow = Nothing,
		StopCombatMusicNow = Nothing, StopDeathSongNow = Nothing, MusicTrace = Nothing, PickDeathSong = Nothing,
		SetDeathSong = Nothing, EndSceneMusic = Nothing,
		RestoreMusicVolume = function() if ns.db then ns.db.musicVolume = nil end end,
		music = { managing = false, level = 0, volume = 1 },
	},
}

-- The game's key bindings (Bindings.xml) call some of a part's functions by
-- name, and no addon can take a binding away: left out, each says so.
local KEY_STAND_INS = {
	cameras = { "Cinematic_CameraWheel", "Cinematic_CustomTrigger", "Cinematic_ToggleShoulderCam" },
	atmosphere = { "Cinematic_ToggleLetterbox" },
}
-- (The line a left-out part's key or command prints.)
local LEFT_OUT_LINE = {
	visions = "Visions isn't loaded (Visions > General)",
	cameras = "Cameras aren't loaded (Camera > General > Load Cameras)",
	style = "Style isn't loaded (Style > General > Load Style)",
	atmosphere = "Atmosphere isn't loaded (Atmosphere > General > Load Atmosphere)",
}
function ns.ModuleLeftOutLine(name)
	local line = LEFT_OUT_LINE[name] or name
	return ns.L and ns.L[line] or line
end

-- The one Reload box for every part whose Load box differs from what's
-- loaded now: from a Load box (Options.lua ns.LoadPartBox) and from picking a
-- profile that leaves parts out (Profiles.lua ns.ProfilePartsPicked), the
-- same box and words either way (the user, 2026-11-22: "keep everything in
-- sync"). Where the game puts its boxes, as every Reload box of ours.
-- lead: what comes before "reload now..." (a profile's name), or nil.
-- Nothing to reload: the box goes. True: it's up.
local ASK_ORDER = { "visions", "cameras", "style", "atmosphere" }
local ASK_WORDS = {
	visions = { load = "load Visions", leave = "leave Visions out" },
	cameras = { load = "load the cameras", leave = "leave the cameras out" },
	style = { load = "load Style", leave = "leave Style out" },
	atmosphere = { load = "load Atmosphere", leave = "leave Atmosphere out" },
}
ns.MODULES_RELOAD_POPUP = "CINEMATIC_LOAD_PARTS"
function ns.AskModulesReload(lead)
	local L = ns.L
	local which = ns.MODULES_RELOAD_POPUP
	local changes = {}
	for _, part in ipairs(ASK_ORDER) do
		local words = ASK_WORDS[part]
		if words and ns.ModuleWanted(part) ~= ns.ModuleLoaded(part) then
			changes[#changes + 1] = L[ns.ModuleWanted(part) and words.load or words.leave]
		end
	end
	if StaticPopup_Hide then StaticPopup_Hide(which) end -- (its text anew, or gone)
	if #changes == 0 then return false end
	StaticPopupDialogs[which] = {
		text = "%s", button1 = RELOADUI or L["Reload"], button2 = L["Later"],
		OnAccept = function() ns.Reload() end,
		cineReload = 1, -- (Forever: a secure Reload over the button, QoL/Reload.lua)
		timeout = 0, whileDead = true, hideOnEscape = true,
	}
	-- ("a, b and c": three joined by "and" read badly, run 5 of profileparts.)
	local ask = #changes < 2 and (changes[1] or "")
		or table.concat(changes, ", ", 1, #changes - 1) .. L[" and "] .. changes[#changes]
	local text = lead and L["%s: reload now to %s?"]:format(lead, ask) or L["Reload now to %s?"]:format(ask)
	StaticPopup_Show(which, text)
	return true
end

local queue = {}
local ran = false
local loaded = {} -- name -> true: its code ran (false: left out)

-- (ns.Guard isn't loaded yet: the error goes to the game's handler, as a
-- file's error as it loads would, and the other parts still run.)
local function Run(fn)
	xpcall(fn, function(err)
		local handler = geterrorhandler and geterrorhandler()
		if handler then handler(err) end
		return err
	end)
end

-- Whether the saved settings want this part (true before they arrive).
function ns.ModuleWanted(name)
	local key = PARTS[name]
	local db = _G.CinematicDB
	return not (key and type(db) == "table" and db[key] == false)
end

-- Whether this part's code is running (false: left out, or not yet started).
function ns.ModuleLoaded(name)
	return loaded[name] == true
end

-- Each part's files, by name (Tint.lua), as their code was handed in: what
-- /cine debug loadparts checks the game's running loops against (a loop
-- from one of them with the part left out is a leak).
local partFiles = {}
function ns.ModuleFiles(name)
	return partFiles[name] or {}
end

-- fn: the rest of a part's file. (Handed in after the start, it runs now.)
function ns.Module(name, fn)
	assert(PARTS[name], "unknown module " .. tostring(name))
	-- (The game's stack text; offline, Lua's own.)
	local stack = (debugstack and debugstack(2, 1, 0)) or (debug and debug.traceback and debug.traceback("", 2)) or ""
	local file = type(stack) == "string" and stack:match("([%w_]+%.lua)")
	if file then
		partFiles[name] = partFiles[name] or {}
		partFiles[name][file] = true
	end
	if ran then
		if loaded[name] then Run(fn) end
		return
	end
	queue[#queue + 1] = { name = name, fn = fn }
end

-- fn: what another file does when this part is left out (takes away its
-- wheel slots, say), as the parts start. (Handed in after: runs now.)
local leftOut = {}
function ns.ModuleLeftOut(name, fn)
	assert(PARTS[name], "unknown module " .. tostring(name))
	if ran then
		if not loaded[name] then Run(fn) end
		return
	end
	leftOut[#leftOut + 1] = { name = name, fn = fn }
end

-- A part's settings: most of its files' DEFAULTS are set in the code that
-- waits, some deep in it (after frames and hooks). So the defaults a part
-- added are noted as it runs, written into the saved settings as it's
-- switched off (ns.SetModuleWanted: CinematicDB.moduleDefaults[name],
-- copies), and put back into ns.DEFAULTS while it's left out: the profiles
-- carry, save and reset every key in DEFAULTS, and would drop the part's
-- settings without them.
local function Copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = Copy(v) end
	return out
end
local added = {} -- name -> { key = default } this load, from its code
local base = {} -- key -> true: in DEFAULTS as the files had loaded (before any part ran)

function ns.RunModules()
	if ran then return end
	ran = true
	-- (How things stood as they started, for /cine debug loadparts: before
	-- Core.lua's ns.db and the language, as the files saw it when loading.)
	ns.moduleStart = { db = ns.db ~= nil, locale = ns.locale, combat = InCombatLockdown and InCombatLockdown() or false,
		saved = type(_G.CinematicDB) == "table" }
	for name in pairs(PARTS) do loaded[name] = ns.ModuleWanted(name) end
	local list = queue
	queue = nil
	local DEFAULTS = ns.DEFAULTS
	for k in pairs(DEFAULTS) do base[k] = true end
	for _, each in ipairs(list) do
		if loaded[each.name] then
			local before = {}
			for k in pairs(DEFAULTS) do before[k] = true end
			Run(each.fn)
			local mine = added[each.name] or {}
			added[each.name] = mine
			for k, v in pairs(DEFAULTS) do
				if not before[k] and type(v) ~= "function" then mine[k] = Copy(v) end
			end
		end
	end
	local db = _G.CinematicDB
	local kept = type(db) == "table" and type(db.moduleDefaults) == "table" and db.moduleDefaults or {}
	for name in pairs(PARTS) do
		if not loaded[name] and type(kept[name]) == "table" then
			for k, v in pairs(kept[name]) do
				if DEFAULTS[k] == nil then DEFAULTS[k] = Copy(v) end
			end
		end
	end
	for _, each in ipairs(leftOut) do
		if not loaded[each.name] then Run(each.fn) end
	end
	leftOut = nil
	for name, list in pairs(ns.MODULE_STAND_INS) do
		if not loaded[name] then
			for key, fn in pairs(list) do
				if ns[key] == nil then ns[key] = fn end
			end
		end
	end
	for name, list in pairs(KEY_STAND_INS) do
		if not loaded[name] then
			for _, global in ipairs(list) do
				if rawget(_G, global) == nil then
					_G[global] = function() if ns.Print then ns.Print(ns.ModuleLeftOutLine(name)) end end
				end
			end
		end
	end
end

local ON_LEAVE = {
	atmosphere = function() if ns.GraphicsPlusPutBack then ns.GraphicsPlusPutBack() end end,
}

-- Leaves a part out from the next /reload (wanted false), or brings it back.
-- Its defaults are written down only now, while its code has run (2,000
-- and more for Visions: not kept in every player's saved settings), and
-- taken out again once it's loaded (below).
function ns.SetModuleWanted(name, wanted)
	local key = PARTS[name]
	local db = _G.CinematicDB
	if not key or type(db) ~= "table" then return end
	db[key] = wanted and true or false
	-- (What a part must undo as it's left out, now, while its code is here:
	-- Graphics+'s settings back to the game's, which keeps them between sessions.)
	if not wanted and loaded[name] and ON_LEAVE[name] then Run(ON_LEAVE[name]) end
	-- (Ticked again before a reload, still loaded: its code has its defaults, no copy.)
	if wanted and loaded[name] and type(db.moduleDefaults) == "table" then
		db.moduleDefaults[name] = nil
		if next(db.moduleDefaults) == nil then db.moduleDefaults = nil end
	end
	if wanted or not loaded[name] or not added[name] then return end
	local kept = {}
	for k, v in pairs(added[name]) do kept[k] = v end
	-- (And every default made since the files loaded that isn't another
	-- part's: its pages' as they were built (a tab's switch, tabOn:<page>:<n>;
	-- a camera's row), the Keybinds tabs'... Put back only where missing.)
	local others = {}
	for other, list in pairs(added) do
		if other ~= name then for k in pairs(list) do others[k] = true end end
	end
	for k, v in pairs(ns.DEFAULTS) do
		if not base[k] and not others[k] and kept[k] == nil and type(v) ~= "function" then kept[k] = Copy(v) end
	end
	if type(db.moduleDefaults) ~= "table" then db.moduleDefaults = {} end
	db.moduleDefaults[name] = kept
end

-- (Loaded again: its code has its defaults, the copy goes. At login:
-- CinematicDB is made at ADDON_LOADED, after the parts ran.)
local cleaner = CreateFrame("Frame")
cleaner:RegisterEvent("PLAYER_LOGIN")
cleaner:SetScript("OnEvent", function(self)
	self:UnregisterAllEvents()
	local db = _G.CinematicDB
	if type(db) ~= "table" or type(db.moduleDefaults) ~= "table" then return end
	for name in pairs(PARTS) do
		if loaded[name] then db.moduleDefaults[name] = nil end
	end
	if next(db.moduleDefaults) == nil then db.moduleDefaults = nil end
end)
