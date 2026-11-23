-- A camera script played while another plays, every state (the audit kit's
-- matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-22-cameras-script-replace.md):
--   python -I Tools/offline/run.py Tools/offline/scriptreplacematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/scriptreplacematrix.lua --base 7c3e0c1^ --new 7c3e0c1
-- Script A plays (its zoom step past your max or not, its When it ends with an
-- End music step or not), then B is played over it from its page (its zoom
-- past your max or not), with the camera back where A started or still out
-- past it. Then B is stopped and the camera comes back in. Each cell: which
-- one plays, the max zoom while B plays, A's End
-- music ended, and the max once it's all over. The rule: A ends as any
-- stopped script does (its music ends, its raised max put back, or kept up
-- while the camera's still out past it), B plays, and once both are over and
-- the camera's back in, the max is yours. (7c3e0c1: only A's moves stopped,
-- its Finish never ran: the max stayed raised for the session.)

local client = arg and arg[1] or "forever"
local cvars = { cameraDistanceMaxZoomFactor = "1.9" }
local zoom = 10
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	GetCVar = function(name) return cvars[name] end
	SetCVar = function(name, value) cvars[name] = tostring(value) end
	GetCameraZoom = function() return zoom end
	UnitAffectingCombat = function() return false end
	IsIndoors = function() return false end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
ns.db.enabled = true
local musicEnds = 0
ns.EndSceneMusic = function() musicEnds = musicEnds + 1 end

-- (Only CameraScripts.lua's own update loop: its function found through the
-- protecting wrapper's upvalues, as scriptreplace.lua does.)
local function From(fn, file, depth)
	if type(fn) ~= "function" or depth > 3 then return false end
	local info = debug.getinfo(fn, "S")
	if info and info.source and info.source:find(file, 1, true) then return true end
	for i = 1, 20 do
		local name, value = debug.getupvalue(fn, i)
		if not name then break end
		if From(value, file, depth + 1) then return true end
	end
	return false
end
local loops
local function Tick(times)
	if not loops then
		loops = {}
		for _, frame in ipairs(wow.frames) do
			local update = frame._scripts and frame._scripts.OnUpdate
			if update and From(update, "CameraScripts.lua", 0) then loops[#loops + 1] = frame end
		end
	end
	for _ = 1, times do
		for _, frame in ipairs(loops) do
			local update = frame._scripts and frame._scripts.OnUpdate
			if update then
				local ok, err = pcall(update, frame, 0.05)
				if not ok then error("tick: " .. tostring(err)) end
			end
		end
	end
end
local function Max()
	local max = cvars.cameraDistanceMaxZoomFactor
	return max == "1.9" and "yours" or max == "2.6" and "raised" or tostring(max)
end

local Matrix = dofile("Tools/offline/matrix.lua")
local n = 0
Matrix.Run({
	name = "script-replace",
	fixed = { client = client },
	dims = {
		{ "aPast", { "yes", "no" } },
		{ "aMusic", { "yes", "no" } },
		{ "camera", { "back", "out" } },
		{ "bPast", { "yes", "no" } },
	},
	cell = function(c)
		n = n + 1
		-- (A fresh start: nothing playing, nothing holding the max, on old code too.)
		ns.StopCameraScript()
		if ns.StopIdleZoomNow then ns.StopIdleZoomNow() end
		ns.db.savedCVars.cameraDistanceMaxZoomFactor = nil
		cvars.cameraDistanceMaxZoomFactor, zoom, musicEnds = "1.9", 10, 0
		local za = ns.NewCameraScriptStep("zoom")
		za.to, za.secs, za.past = 30, 20, c.aPast
		local ending = {}
		if c.aMusic == "yes" then ending[1] = ns.NewCameraScriptStep("endMusic") end
		local A = { id = "matrixA" .. n, name = "Matrix A" .. n, steps = { za }, ending = ending, rules = {} }
		local zb = ns.NewCameraScriptStep("zoom")
		zb.to, zb.secs, zb.past = 30, 20, c.bPast
		local B = { id = "matrixB" .. n, name = "Matrix B" .. n, steps = { zb }, ending = {}, rules = {} }
		if ns.PlayCameraScript(A) ~= true then return "A refused" end
		Tick(3)
		if c.camera == "out" then zoom = 25 end
		if ns.PlayCameraScript(B) ~= true then return "B refused" end
		Tick(3)
		local playing = ns.PlayingCameraScript and ns.PlayingCameraScript()
		playing = type(playing) == "table" and playing.name or playing
		local mid = Max()
		-- (B stopped, the camera back in: it's all over.)
		ns.StopCameraScript()
		zoom = 10
		Tick(3)
		return ("playing=%s mid=%s music=%s after=%s"):format(playing == B.name and "B" or playing == A.name and "A" or tostring(playing), mid,
			musicEnds > 0 and "ended" or "none", Max())
	end,
	pins = {
		-- (A ends, B plays; nothing raised: your max throughout.)
		{ "", "playing=B mid=yours music=none after=yours" },
		{ "aMusic=yes", "playing=B mid=yours music=ended after=yours" },
		-- (B's own Past max raises it while B plays.)
		{ "bPast=yes aMusic=no", "playing=B mid=raised music=none after=yours" },
		{ "bPast=yes aMusic=yes", "playing=B mid=raised music=ended after=yours" },
		-- (A raised it and the camera's still out past where A started: kept
		-- up, or putting it back snaps the camera in.)
		{ "aPast=yes camera=out aMusic=no", "playing=B mid=raised music=none after=yours" },
		{ "aPast=yes camera=out aMusic=yes", "playing=B mid=raised music=ended after=yours" },
	},
})
