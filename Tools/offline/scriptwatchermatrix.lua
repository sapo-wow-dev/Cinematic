-- The camera scripts' watcher with Enable Cameras off (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-script-watcher-loop.md):
--   python -I Tools/offline/run.py Tools/offline/scriptwatchermatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/scriptwatchermatrix.lua forever --base <ref>
-- CameraScripts.lua's per-frame watcher (it works out which scene's on and
-- starts, steps and ends a script): Enable Cameras on or off, with a script
-- playing or nothing. Each cell: whether its loop runs ("loop on"/"loop off").
-- The rule: with Enable Cameras off and nothing of a script left, no loop
-- (the in-game gating test, 2026-11-25: it ran every frame, 90 times in a step).
local client = arg and arg[1] or "forever"
local made = {}
local cvars = { cameraDistanceMaxZoomFactor = "1.9" }
local camZoom = 10
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	GetCVar = function(name) return cvars[name] end
	SetCVar = function(name, value) cvars[name] = tostring(value) end
	GetCameraZoom = function() return camZoom end
	UnitAffectingCombat = function() return false end
	IsIndoors = function() return false end
	-- luacheck: pop
	local create = CreateFrame
	CreateFrame = function(...) -- luacheck: ignore 121
		local frame = create(...)
		local info = debug.getinfo(2, "Sl")
		if info then made[#made + 1] = { frame = frame, at = tostring(info.source):gsub("\\", "/") .. ":" .. info.currentline } end
		return frame
	end
end
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local function FrameAt(file, pattern)
	local n = 0
	for line in io.lines(file) do
		n = n + 1
		if line:find(pattern) then
			for _, each in ipairs(made) do
				if each.at:find(file .. ":" .. n, 1, true) then return each.frame end
			end
		end
	end
	error("matrix: no frame made at " .. file .. " " .. pattern)
end
local watcher = FrameAt("Camera/CameraScripts.lua", "^local watcher = CreateFrame")
local db = ns.db
local now = 100
GetTime = function() return now end -- luacheck: ignore 121
db.enabled = true

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "script-watcher-loop",
	fixed = { client = client },
	dims = {
		-- (zoomedOut last: on the old code its held zoom max outlives the cell.)
		{ "script", { "none", "playing", "zoomedOut" } },
		{ "cameras", { "on", "off" } },
	},
	cell = function(c)
		ns.StopCameraScript()
		camZoom = 10
		db.cameraModes, db.cameraScenes = true, true
		-- (A cell before's held zoom max let go: one frame with the camera back in.)
		ns.SyncFeatureLoops()
		local update = watcher._scripts and watcher._scripts.OnUpdate
		if update then pcall(update, watcher, 0.05) end
		if c.script == "playing" or c.script == "zoomedOut" then
			-- (A slow zoom of its own, played as by hand: still going 2 s later.)
			local zoom = ns.NewCameraScriptStep("zoom")
			zoom.to, zoom.secs, zoom.past = 30, 20, "yes"
			local script = { id = "watcherTest", name = "Watcher test", steps = { zoom }, ending = {}, rules = {} }
			if ns.PlayCameraScript(script) ~= true then return "didn't play" end
			-- (Stopped with the camera still out past where it began: its raised zoom
			-- max held till you zoom back in. Run 6 of the in-game gating test.)
			if c.script == "zoomedOut" then
				-- (A second of its frames first: its zoom step raises the max.)
				for _ = 1, 20 do
					now = now + 0.05
					local update = watcher._scripts and watcher._scripts.OnUpdate
					if update then pcall(update, watcher, 0.05) end
				end
				camZoom = 30
				ns.StopCameraScript()
			end
		end
		db.cameraModes = c.cameras == "on"
		now = now + 2
		ns.SyncFeatureLoops()
		local on = watcher._scripts and watcher._scripts.OnUpdate ~= nil
		ns.StopCameraScript()
		return on and "loop on" or "loop off"
	end,
	pins = {
		{ "", "loop on" },
		{ "cameras=off script=none", "loop off" },
		{ "cameras=off script=zoomedOut", "loop off" },
	},
})
