-- The Cameras part's small always-on watches (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-cameras-small-loops.md):
--   python -I Tools/offline/run.py Tools/offline/cameraloopsmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/cameraloopsmatrix.lua forever --base <ref>
-- Three of them, each wanted or not:
--   zoomguard: one of our zooms a second ago, or none for a minute (ZoomGuard.lua's
--     per-frame watch of the camera distance);
--   the Skyriding Cam (its own matrix): its page on or off, skyriding in the air
--     or on the ground (SkyrideCam.lua's per-frame watcher; retail only);
--   campfire: Enable Cameras on or off, a buff arriving (Camera.lua's campfire buff
--     scan on every aura change of yours).
-- Each cell: whether the watch runs ("loop on"), or for the scan whether the
-- campfire buff was looked for and seen.
-- The rule: each only while what it's for can use it.
local client = arg and arg[1] or "forever"
-- (Each watch's frame: the one made on its own line of its file.)
local made = {}
local gliding = false
local function Install()
	issecretvalue = function() return false end -- luacheck: ignore 121
	C_PlayerInfo = C_PlayerInfo or {} -- luacheck: ignore 121
	C_PlayerInfo.GetGlidingInfo = function() return gliding, true, 30 end -- luacheck: ignore 122
	local create = CreateFrame
	CreateFrame = function(...) -- luacheck: ignore 121
		local frame = create(...)
		local info = debug.getinfo(2, "Sl")
		if info then made[#made + 1] = { frame = frame, at = tostring(info.source):gsub("\\", "/") .. ":" .. info.currentline } end
		return frame
	end
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local function FrameAt(file, pattern, optional)
	local n = 0
	for line in io.lines(file) do
		n = n + 1
		if line:find(pattern) then
			for _, each in ipairs(made) do
				if each.at:find(file .. ":" .. n, 1, true) then return each.frame end
			end
		end
	end
	if not optional then error("matrix: no frame made at " .. file .. " " .. pattern) end
end
local zoomFrame = FrameAt("Camera/ZoomGuard.lua", "^local frame = CreateFrame")
local skyFrame = FrameAt("Camera/SkyrideCam.lua", "^local watcher = CreateFrame", true) -- (retail only)
local db = ns.db
local now = 100
GetTime = function() return now end -- luacheck: ignore 121
db.enabled = true

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "camera-small-loops",
	fixed = { client = client },
	dims = {
		{ "watch", { "zoomguard", "campfire" } },
		{ "on", { "yes", "no" } },
	},
	cell = function(c)
		local yes = c.on == "yes"
		db.cameraModes, db.cameraScenes = true, true
		now = now + 120
		if c.watch == "zoomguard" then
			if yes then ns.CallCameraFunction("CameraZoomIn", 1) end
			now = now + 1
			ns.SyncFeatureLoops()
			return zoomFrame._scripts.OnUpdate and "loop on" or "loop off"
		end
		db.cameraModes = yes
		ns.campfireBuff = nil
		wow.Fire("UNIT_AURA", "player")
		return ns.campfireBuff and "buff seen" or "not looked"
	end,
	pins = {
		{ "on=yes", "loop on" },
		{ "on=no", "loop off" },
		{ "watch=campfire on=yes", "buff seen" },
		{ "watch=campfire on=no", "not looked" },
	},
})
-- (The Skyriding Cam's: its own matrix, as only retail has it.)
if skyFrame then
	Matrix.Run({
		name = "camera-skyride-loop",
		fixed = { client = client },
		dims = {
			{ "page", { "on", "off" } },
			{ "skyriding", { "air", "ground" } },
		},
		cell = function(c)
			db.cameraModes, db.cameraScenes = true, true
			db.skyrideCam, db.skyrideCamAlways = c.page == "on", true
			-- (Up past its start time, as the camera scripts' watch asks every frame.)
			gliding = c.skyriding == "air"
			for _ = 1, 3 do
				now = now + 1
				ns.SkyridingNow()
			end
			ns.SyncFeatureLoops()
			local on = skyFrame._scripts.OnUpdate and "loop on" or "loop off"
			-- (Down again and put away: the next cell from the ground.)
			gliding = false
			for _ = 1, 3 do
				now = now + 10
				ns.SkyridingNow()
				if skyFrame._scripts.OnUpdate then skyFrame._scripts.OnUpdate(skyFrame, 0.1) end
			end
			ns.SyncFeatureLoops()
			return on
		end,
		pins = {
			{ "", "loop off" },
			{ "page=on skyriding=air", "loop on" },
		},
	})
end
