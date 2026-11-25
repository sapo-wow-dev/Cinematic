-- The dev copy's Mouse Turn cap by its switches (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-dev-mouse-turn-gate.md):
--   python -I Tools/offline/run.py Tools/offline/mouseturnmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/mouseturnmatrix.lua forever --base <ref>
-- Cameras loaded or left out (Load Cameras), Enable Cameras on or off, the
-- Camera Settings page's Mouse Turn tab on or off, its cap ticked or not.
-- Each cell: whether its update loop runs (it holds your mouse look speed).
-- The rule: only with Cameras loaded, Enable Cameras on, its tab on and the cap ticked.
-- Each cell its own load in its own process (a part left out is a fresh load).
local LUA = os.getenv("CINE_LUA") or "lua5.1"
local client, loaded, cameras, tab, cap = ...
client = client or "forever"

if loaded then
	local made = {}
	local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
		-- luacheck: push ignore 111 121
		if loaded == "out" then CinematicDB = { loadCameras = false } end
		local create = CreateFrame
		CreateFrame = function(...)
			local frame = create(...)
			local info = debug.getinfo(2, "Sl")
			if info then made[#made + 1] = { frame = frame, at = tostring(info.source):gsub("\\", "/") .. ":" .. info.currentline } end
			return frame
		end
		-- luacheck: pop
	end)
	local frame
	local n = 0
	for line in io.lines("Dev/MouseTurn.lua") do
		n = n + 1
		if line:find("^%s*local frame = CreateFrame") then
			for _, each in ipairs(made) do
				if each.at:find("Dev/MouseTurn.lua:" .. n, 1, true) then frame = each.frame end
			end
		end
	end
	local db = ns.db
	db.enabled = true
	db.cameraModes = cameras == "on"
	db["tabOn:Camera Settings:Mouse Turn"] = tab == "on"
	db.mouseTurnCap, db.mouseTurnRamp = cap == "on", false
	if ns.SyncFeatureLoops then ns.SyncFeatureLoops() end
	print("CELLRESULT " .. ((frame and frame._scripts.OnUpdate) and "loop on" or "loop off"))
	return
end

local function Cell(c)
	local cmd = ("%s Tools/offline/mouseturnmatrix.lua %s %s %s %s %s"):format(LUA, client, c.loaded, c.cameras, c.tab, c.cap)
	local pipe = io.popen(cmd .. " 2>&1")
	local out = pipe:read("*a")
	pipe:close()
	return out:match("CELLRESULT ([^\r\n]+)") or ("no result: " .. out:sub(-200))
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "mouse-turn-gate",
	fixed = { client = client },
	dims = {
		{ "loaded", { "in", "out" } },
		{ "cameras", { "on", "off" } },
		{ "tab", { "on", "off" } },
		{ "cap", { "on", "off" } },
	},
	cell = Cell,
	pins = {
		{ "", "loop off" },
		{ "loaded=in cameras=on tab=on cap=on", "loop on" },
	},
})
