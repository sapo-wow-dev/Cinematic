-- The switch tree has the same shape whichever parts load (the audit kit's
-- matrix, Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-gate-tree-shape.md):
--   python -I Tools/offline/run.py Tools/offline/gatetreematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/gatetreematrix.lua forever --base <ref>
-- Every part loaded, or one left out; each switch whose master was set inside
-- a part's own code (the Breath Bar's, the Scenes/Triggers/Scripts/My Shots
-- pages', Emote Vision's Nameplates tab, the Vitals pages' tabs). Each cell:
-- the switch it's under (ns.PageSwitchOf), or "none". The rule: the same
-- master whichever parts load, so a left-out part's switches read off through
-- it (Core.lua's LEFT_OUT_SWITCHES) as they do with it loaded.
-- (Each load its own process, as partrowsmatrix.lua: one per load, cached.)
local LUA = os.getenv("CINE_LUA") or "lua5.1"
local client, load = ...
client = client or "forever"
local PARTS = { visions = "loadVisions", cameras = "loadCameras", style = "loadStyle", atmosphere = "loadAtmosphere" }
local MASTERS = {
	breathBar = "handleFrames",
	cameraScenes = "cameraModes", cameraTriggers = "cameraModes", cameraScriptsPage = "cameraModes",
	cameraShots = "cameraModes",
	emoteVisionPlates = "emoteVision",
	["tabOn:Vitals:general"] = "lowHealth", ["tabOn:Vitals:blizzard"] = "lowHealth",
	["tabOn:Vitals:cinematic"] = "lowHealth", ["tabOn:Vitals:swirl"] = "lowHealth",
	["tabOn:Vitals:effect"] = "lowHealth", ["tabOn:Vitals:mana"] = "tabOn:VitalsVision:mana",
	["tabOn:VitalsVision:health"] = "lowHealth", ["tabOn:VitalsVision:mana"] = "lowHealth",
	-- (Style's Overrides tab and Visions Style: set in Style's part, lost with it left out. Audit 2026-11-25)
	styleOverrides = "styleGeneral", visionsStyle = "styleGeneral",
}
local KEYS = {}
for key in pairs(MASTERS) do KEYS[#KEYS + 1] = key end
table.sort(KEYS)

if load then
	local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
		if PARTS[load] then CinematicDB = { [PARTS[load]] = false } end -- luacheck: ignore 111
	end)
	for _, key in ipairs(KEYS) do
		print(("R %s %s"):format(key, tostring(ns.PageSwitchOf(key) or "none")))
	end
	return
end

local cache = {}
local function Run(name)
	if not cache[name] then
		local pipe = io.popen(("%s Tools/offline/gatetreematrix.lua %s %s 2>&1"):format(LUA, client, name))
		local out = pipe:read("*a")
		pipe:close()
		local got = {}
		for key, result in out:gmatch("R (%S+) ([^\r\n]*)") do got[key] = result end
		got.raw = out:sub(-200)
		cache[name] = got
	end
	return cache[name]
end

local pins = {}
for _, key in ipairs(KEYS) do pins[#pins + 1] = { "switch=" .. key, MASTERS[key] } end
local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "gate-tree-shape",
	fixed = { client = client },
	dims = {
		{ "load", { "all", "visions", "cameras", "style", "atmosphere" } }, -- (all, or that part left out)
		{ "switch", KEYS },
	},
	cell = function(c)
		local got = Run(c.load)
		return got[c.switch] or ("no result: " .. got.raw)
	end,
	pins = pins, -- (each its master, whichever parts load)
})
