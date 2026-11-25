-- Every settings row repaints with a part left out (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-style-override-text.md):
--   python -I Tools/offline/run.py Tools/offline/partrowsmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/partrowsmatrix.lua forever --base <ref>
-- Each part (Visions, Cameras, Style, Atmosphere) loaded or left out: every
-- page made (the lazy ones too), then every frame on every page that has a
-- Refresh asked to repaint, as opening or changing a page does. Each cell: "ok",
-- or how many rows called a function that isn't there, and the first. (The HUD Unit Frames and the
-- Nameplates parts rows called Style's StyleOverrideText with Style left out:
-- only building the pages, as stylebacklinks.lua nostyle does, didn't reach it.)
-- Each cell its own load in its own process (two loads in one ran to 5 GB).
local LUA = os.getenv("CINE_LUA") or "lua5.1"
local client, part, state = ...
client = client or "forever"
local KEYS = { visions = "loadVisions", cameras = "loadCameras", style = "loadStyle", atmosphere = "loadAtmosphere" }

if part then
	-- One cell: load, make every page, repaint every row.
	local timers = {}
	local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
		if state == "out" then CinematicDB = { [KEYS[part]] = false } end -- luacheck: ignore 111
		C_Timer.After = function(_, fn) timers[#timers + 1] = fn end -- luacheck: ignore 122
	end)
	local function RunTimers()
		for _ = 1, 3 do
			local now = timers
			timers = {}
			for _, fn in ipairs(now) do pcall(fn) end
		end
	end
	RunTimers()
	if ns.MakeLazyPages then ns.MakeLazyPages("partrowsmatrix") end
	RunTimers()
	local errors, first, seen = 0, nil, {}
	local function Walk(frame, depth)
		if seen[frame] or depth > 40 then return end
		seen[frame] = true
		local refresh = rawget(frame, "Refresh")
		if type(refresh) == "function" then
			local ok, err = pcall(refresh, frame)
			-- (Only a call to a function that isn't there: a left-out part's. The
			-- stand-in's sizes give rows errors of their own, game or not.)
			if not ok and tostring(err):find("attempt to call .-a nil value") then
				errors = errors + 1
				first = first or tostring(err):gsub("^.-([%w_]+%.lua:%d+:)", "%1")
			end
		end
		if frame.GetChildren then
			for _, child in ipairs({ frame:GetChildren() }) do Walk(child, depth + 1) end
		end
	end
	local names = {}
	for name in pairs(ns.settingsCanvases or {}) do names[#names + 1] = name end
	table.sort(names)
	for _, name in ipairs(names) do
		local canvas = ns.settingsCanvases[name]
		if type(canvas) == "table" then Walk(canvas, 0) end
	end
	print(("CELLRESULT %s"):format(errors == 0 and "ok" or ("error x%d: %s"):format(errors, first)))
	return
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "part-rows-repaint",
	fixed = { client = client },
	dims = {
		{ "part", { "visions", "cameras", "style", "atmosphere" } },
		{ "state", { "loaded", "out" } },
	},
	cell = function(c)
		local pipe = io.popen(("%s Tools/offline/partrowsmatrix.lua %s %s %s 2>&1"):format(LUA, client, c.part,
			c.state == "out" and "out" or "in"))
		local out = pipe:read("*a")
		pipe:close()
		return out:match("CELLRESULT ([^\r\n]*)") or ("no result: " .. out:sub(-200))
	end,
	pins = {
		{ "", "ok" }, -- (every row repaints, every part in or out)
	},
})
