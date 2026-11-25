-- The gate functions agree on a switch whose own part is left out, and a loop
-- in the switch tree can't hang them (the audit kit's matrix, Tools/offline/matrix.lua;
-- fix card Tools/audits/2026-11-25-gate-machinery.md):
--   python -I Tools/offline/run.py Tools/offline/gateleftoutmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/gateleftoutmatrix.lua forever --base <ref>
-- Each switch a part marks left out (Core.lua's LEFT_OUT_SWITCHES), with that
-- part left out and the switch itself ticked on: "off" when ns.Setting,
-- ns.PageSetting, ns.PageOn and ns.MasterOff (held) all say off (and
-- ns.StyleOn for a Style page's switch), else what each said. And two
-- switches put under each other (a loop): what ns.Setting, ns.PageSetting
-- and ns.MasterOff give, or "loops" (it never stopped: the game would hang).
-- (Each load its own process, as partrowsmatrix.lua: one per load, cached.)
local LUA = os.getenv("CINE_LUA") or "lua5.1"
local client, load = ...
client = client or "forever"
local PARTS = { visions = "loadVisions", cameras = "loadCameras", style = "loadStyle", atmosphere = "loadAtmosphere" }
local CASES = {
	{ "visions", "handleHealVision" }, { "visions", "questVision" }, { "visions", "lowHealth" },
	{ "visions", "emoteVision" }, { "visions", "cards" }, { "visions", "deathScreen" },
	{ "cameras", "cameraModes" }, { "cameras", "shoulderCam" },
	{ "style", "styleGeneral" },
	{ "atmosphere", "visualEffects" }, { "atmosphere", "tintPage" }, { "atmosphere", "tintStyle" },
	{ "atmosphere", "letterboxStyle" }, { "atmosphere", "weatherStyle" },
	{ "all", "cycle:Setting" }, { "all", "cycle:PageSetting" }, { "all", "cycle:MasterOff" },
}

if load then
	local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
		if PARTS[load] then CinematicDB = { [PARTS[load]] = false } end -- luacheck: ignore 111
	end)
	local db = ns.db
	local function B(v) return v and "on" or "off" end
	for _, case in ipairs(CASES) do
		if case[1] == load then
			local key = case[2]
			local ok, out = pcall(function()
				local fn = key:match("^cycle:(.+)$")
				if fn then
					ns.SetPageMaster({ "auditCycleA" }, "auditCycleB")
					ns.SetPageMaster({ "auditCycleB" }, "auditCycleA")
					local reads = 0
					local was = getmetatable(db)
					setmetatable(db, { __index = function(_, k)
						if k == "auditCycleA" or k == "auditCycleB" then
							reads = reads + 1
							if reads > 1000 then error("LOOPS") end
							return nil
						end
						return was and was.__index and (type(was.__index) == "function" and was.__index(db, k) or was.__index[k]) or nil
					end })
					local ran, got
					if fn == "MasterOff" then
						ran, got = pcall(ns.MasterOff, "auditCycleA", db)
					else
						ran, got = pcall(ns[fn], "auditCycleA")
					end
					setmetatable(db, was)
					ns.SetPageMaster({ "auditCycleA", "auditCycleB" }, nil)
					if not ran then return tostring(got):find("LOOPS") and "loops" or ("error " .. tostring(got):sub(1, 60)) end
					return "stops: " .. tostring(got)
				end
				local saved = db[key]
				db[key] = true
				local s, ps, p, m = B(ns.Setting(key)), B(ns.PageSetting(key)), B(ns.PageOn(key)), B(not ns.MasterOff(key, db))
				local y = key:find("Style$") and key ~= "styleGeneral" and B(ns.StyleOn(key, db)) or s
				db[key] = saved
				if s == ps and ps == p and p == m and m == y then return s end
				return ("Setting=%s PageSetting=%s PageOn=%s held=%s StyleOn=%s"):format(s, ps, p, m == "off" and "yes" or "no", y)
			end)
			print(("R %s %s"):format(key, ok and out or ("error " .. tostring(out):sub(1, 80))))
		end
	end
	return
end

local cache = {}
local function Run(name)
	if not cache[name] then
		local pipe = io.popen(("%s Tools/offline/gateleftoutmatrix.lua %s %s 2>&1"):format(LUA, client, name))
		local out = pipe:read("*a")
		pipe:close()
		local got = {}
		for key, result in out:gmatch("R (%S+) ([^\r\n]*)") do got[key] = result end
		got.raw = out:sub(-200)
		cache[name] = got
	end
	return cache[name]
end

local names = {}
local partOf = {}
for _, case in ipairs(CASES) do
	names[#names + 1] = case[2]
	partOf[case[2]] = case[1]
end
local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "gate-left-out",
	fixed = { client = client },
	dims = {
		{ "switch", names }, -- (its part left out; cycle: every part loaded)
	},
	cell = function(c)
		local got = Run(partOf[c.switch])
		return got[c.switch] or ("no result: " .. got.raw)
	end,
	pins = {
		{ "", "off" }, -- (its part left out: off whatever's saved, every gate)
		{ "switch=cycle:Setting", "stops: nil" }, -- (the loop's switch has no value saved)
		{ "switch=cycle:PageSetting", "stops: nil" },
		{ "switch=cycle:MasterOff", "stops: false" },
	},
})
