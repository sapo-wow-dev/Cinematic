-- Cameras' settings outside its own pages, with Cameras left out (the audit
-- kit's matrix, Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-cameras-out-pages.md):
--   python -I Tools/offline/run.py Tools/offline/camerapagesoutmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/camerapagesoutmatrix.lua forever --base <ref>
-- Cameras loaded or left out (Load Cameras). Each cell: whether the Quality
-- of Life hub's Fishing page is made, and whether QoL General's "Reset the
-- zoom on login and /reload" row is there (both are Camera.lua's code).
-- The rule (2026-11-25, decided: hide what can't be used): left out, neither shows.
-- Each cell its own load in its own process.
local LUA = os.getenv("CINE_LUA") or "lua5.1"
local client, loaded = ...
client = client or "forever"

if loaded then
	local timers = {}
	local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
		-- luacheck: push ignore 111 122
		if loaded == "out" then CinematicDB = { loadCameras = false } end
		C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
		-- luacheck: pop
	end)
	for _ = 1, 3 do
		local now = timers
		timers = {}
		for _, fn in ipairs(now) do pcall(fn) end
	end
	if ns.MakeLazyPages then ns.MakeLazyPages("camerapagesoutmatrix") end
	local LOGIN = ns.L["Reset the zoom on login and /reload"]
	local found, seen = false, {}
	local function Walk(frame, depth)
		if found or seen[frame] or depth > 40 or type(frame) ~= "table" then return end
		seen[frame] = true
		if rawget(frame, "_text") == LOGIN then found = true return end
		for _, list in ipairs({ rawget(frame, "_children") or {}, rawget(frame, "_regions") or {} }) do
			for _, each in ipairs(list) do Walk(each, depth + 1) end
		end
	end
	for _, canvas in pairs(ns.settingsCanvases or {}) do Walk(canvas, 0) end
	local fishing = ns.settingsCanvases and ns.settingsCanvases.Fishing ~= nil
	print(("CELLRESULT fishing page %s, login zoom row %s"):format(fishing and "yes" or "no", found and "yes" or "no"))
	return
end

local function Cell(c)
	local pipe = io.popen(("%s Tools/offline/camerapagesoutmatrix.lua %s %s 2>&1"):format(LUA, client, c.loaded))
	local out = pipe:read("*a")
	pipe:close()
	return out:match("CELLRESULT ([^\r\n]+)") or ("no result: " .. out:sub(-200))
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "cameras-out-pages",
	fixed = { client = client },
	dims = {
		{ "loaded", { "in", "out" } },
	},
	cell = Cell,
	pins = {
		{ "loaded=in", "fishing page yes, login zoom row yes" },
		{ "loaded=out", "fishing page no, login zoom row no" },
	},
})
