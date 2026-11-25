-- The Toggle visual effects key with Atmosphere loaded or left out (the audit
-- kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-25-toggle-effects-left-out.md):
--   python -I Tools/offline/run.py Tools/offline/togglefxmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/togglefxmatrix.lua forever --base <ref>
-- Atmosphere loaded or left out (Load Atmosphere unticked, after the reload),
-- Enable Visual Effects on or off, then the key (Bindings.xml's
-- Cinematic_ToggleVisualEffects). Each cell: what it says in chat and whether
-- Enable Visual Effects flipped.
-- The rule (as the letterbox key, Modules.lua's KEY_STAND_INS): left out, the
-- key says Atmosphere isn't loaded and changes nothing.
-- Each cell its own load in its own process (a part left out needs a fresh load).
local LUA = os.getenv("CINE_LUA") or "lua5.1"
local client, state, effects = ...
client = client or "forever"

if state then
	local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
		if state == "out" then CinematicDB = { loadAtmosphere = false } end -- luacheck: ignore 111
	end)
	ns.db.visualEffects = effects == "on"
	local said
	ns.Print = function(text) said = tostring(text) end
	Cinematic_ToggleVisualEffects() -- luacheck: ignore 113
	local words = said == nil and "nothing" or said:find("isn't loaded", 1, true) and "notLoaded"
		or said:find("visual effects on", 1, true) and "on" or said:find("visual effects off", 1, true) and "off"
		or said
	local flipped = (ns.db.visualEffects == true) ~= (effects == "on")
	print(("CELLRESULT said=%s %s"):format(words, flipped and "flipped" or "kept"))
	return
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "toggle-effects-key",
	fixed = { client = client },
	dims = {
		{ "atmosphere", { "loaded", "out" } },
		{ "effects", { "on", "off" } },
	},
	cell = function(c)
		local pipe = io.popen(("%s Tools/offline/togglefxmatrix.lua %s %s %s 2>&1"):format(LUA, client,
			c.atmosphere == "out" and "out" or "in", c.effects))
		local out = pipe:read("*a")
		pipe:close()
		return out:match("CELLRESULT ([^\r\n]*)") or ("no result: " .. out:sub(-200))
	end,
	pins = {
		{ "atmosphere=loaded effects=on", "said=off flipped" },
		{ "atmosphere=loaded effects=off", "said=on flipped" },
		{ "atmosphere=out", "said=notLoaded kept" },
	},
})
