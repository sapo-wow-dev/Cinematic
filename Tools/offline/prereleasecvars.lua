-- /cine prerelease's game-settings compare (Dev/Prerelease.lua CVarsBack):
--   python -I Tools/offline/run.py Tools/offline/prereleasecvars.lua [forever|retail] < /dev/null
-- Music turned on by Cinematic's own music (playing, your value saved) is held,
-- not a change, and not written back; any other change still counts and is
-- put back, music too when ours isn't playing or a different value is saved.

local client = arg and arg[1] or "forever"
local cvars = { Sound_EnableMusic = "0", Sound_MusicVolume = "0.4", cameraFov = "90" }

local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	SetCVar = function(name, value) if cvars[name] ~= nil then cvars[name] = tostring(value) end end
	GetCVar = function(name) return cvars[name] end
	-- luacheck: pop
end

local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
assert(ns.PrereleaseCVarsBack, "ns.PrereleaseCVarsBack missing")
ns.SweepCVars = function()
	local copy = {}
	for k, v in pairs(cvars) do copy[k] = v end
	return copy
end
ns.music = ns.music or {}
ns.db.savedCVars = ns.db.savedCVars or {}

local fails = 0
local function Case(name, setup, wantChanged, wantHeld, wantMusic)
	cvars = { Sound_EnableMusic = "0", Sound_MusicVolume = "0.4", cameraFov = "90" }
	ns.music.managing, ns.db.savedCVars.Sound_EnableMusic, ns.db.savedCVars.Sound_MusicVolume = nil, nil, nil
	local before = ns.SweepCVars()
	setup()
	local changed, held = ns.PrereleaseCVarsBack(before)
	local ok = #changed == wantChanged and #held == wantHeld and cvars.Sound_EnableMusic == wantMusic
		and cvars.cameraFov == "90"
	if not ok then fails = fails + 1 end
	print(("%s %s: changed %d (want %d), held %d (want %d), music %s (want %s)"):format(ok and "PASS" or "FAIL",
		name, #changed, wantChanged, #held, wantHeld, cvars.Sound_EnableMusic, wantMusic))
end

Case("our music playing, yours saved (the vista check)", function()
	ns.music.managing = true
	ns.db.savedCVars.Sound_EnableMusic, ns.db.savedCVars.Sound_MusicVolume = "0", "0.400"
	cvars.Sound_EnableMusic = "1"
end, 0, 1, "1")
Case("music left on, ours not playing", function()
	ns.db.savedCVars.Sound_EnableMusic = "0"
	cvars.Sound_EnableMusic = "1"
end, 1, 0, "0")
Case("our music playing, a different value saved", function()
	ns.music.managing = true
	ns.db.savedCVars.Sound_EnableMusic = "1"
	cvars.Sound_EnableMusic = "1"
end, 1, 0, "0")
Case("our music playing, nothing saved", function()
	ns.music.managing = true
	cvars.Sound_EnableMusic = "1"
end, 1, 0, "0")
Case("another setting changed while our music plays", function()
	ns.music.managing = true
	ns.db.savedCVars.Sound_EnableMusic = "0"
	cvars.Sound_EnableMusic, cvars.cameraFov = "1", "70"
end, 1, 1, "1")
Case("nothing changed", function() end, 0, 0, "0")

print(fails == 0 and "prereleasecvars: all pass" or ("prereleasecvars: %d FAILED"):format(fails))
if fails > 0 then os.exit(1) end
