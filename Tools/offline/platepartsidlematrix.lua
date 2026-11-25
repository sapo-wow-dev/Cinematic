-- The plate parts' pass with the Nameplates page off (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-plate-parts-idle.md):
--   python -I Tools/offline/run.py Tools/offline/platepartsidlematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/platepartsidlematrix.lua forever --base <ref>
-- The Nameplates page on or off; a Style override on the Health bar (hidden)
-- or none; a kind with parts of its own (Use custom parts) or none; the
-- target marks' own row (Always) on or off. The pass run till settled, then
-- one tick more. Each cell: the Health bar's level, the target marks' level,
-- and the calls that tick made to the rows (Style overrides, icon rows, part rows).
-- The rule (audit 2026-11-25, D15): the levels as before in every cell; with
-- the page off, nothing overriding and all settled, the tick only checks the
-- overrides and the target marks' row (12 calls), not every part's loops.
local client = arg and arg[1] or "forever"
local now = 1000
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	GetTime = function() return now end
	InCombatLockdown = function() return false end
	-- luacheck: pop
end
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
db.styleGeneral, db.styleOverrides = true, true -- (Enable Style: off on a fresh install)
db.handlePlateStyle, db.plateMarks = true, true -- (the marks' Smart page, under Default: they draw only with it on. Audit 2026-11-25, OK'd by the user)

local function Upvalue(fn, name)
	for i = 1, 255 do
		local n, v = debug.getupvalue(fn, i)
		if not n then return nil end
		if n == name then return v end
	end
end
local Update = ns.UpdatePlateParts
local levels = Upvalue(Update, "levels")
local calls = 0
for _, name in ipairs({ "StyleOverride", "PlateIconWanted", "PlateRowWanted" }) do
	local fn = ns[name]
	ns[name] = function(...)
		calls = calls + 1
		return fn(...)
	end
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "plate-parts-idle",
	fixed = { client = client, cine = "off" },
	dims = {
		{ "page", { "on", "off" } },
		{ "override", { "none", "hide" } },
		{ "custom", { "none", "one" } },
		{ "arrow", { "on", "off" } },
	},
	cell = function(c)
		db.handlePlates = c.page == "on"
		db.styleOver_platePartHealth = c.override == "hide" and "hide" or "row"
		db.plateOwnPartsEnemies = c.custom == "one"
		db.targetArrowAlways = c.arrow == "on"
		for _ = 1, 200 do
			now = now + 0.05
			Update(false, 0.05, false)
		end
		calls = 0
		now = now + 0.05
		Update(false, 0.05, false)
		return ("health=%.2f arrow=%.2f calls=%d"):format(levels.Health or -1, levels.TargetArrow or -1, calls)
	end,
	pins = {
		-- (Out of CineMode the parts are the game's but for an override; the
		-- target marks by their row. Page on: every loop, as before.)
		{ "page=on override=none custom=none arrow=on", "health=1.00 arrow=1.00 calls=18" },
		{ "page=on override=none custom=none arrow=off", "health=1.00 arrow=0.00 calls=18" },
		{ "page=on override=hide custom=none arrow=on", "health=0.00 arrow=1.00 calls=18" },
		{ "page=on override=hide custom=none arrow=off", "health=0.00 arrow=0.00 calls=18" },
		-- (A kind's own parts: their overrides read once a tick, not once a kind.)
		{ "page=on override=none custom=one arrow=on", "health=1.00 arrow=1.00 calls=18" },
		{ "page=on override=none custom=one arrow=off", "health=1.00 arrow=0.00 calls=18" },
		{ "page=on override=hide custom=one arrow=on", "health=0.00 arrow=1.00 calls=18" },
		{ "page=on override=hide custom=one arrow=off", "health=0.00 arrow=0.00 calls=18" },
		-- (Page off, an override set: the loops run.)
		{ "page=off override=hide arrow=on", "health=0.00 arrow=1.00 calls=19" },
		{ "page=off override=hide arrow=off", "health=0.00 arrow=0.00 calls=19" },
		-- (Page off, nothing overriding, settled: only the checks.)
		{ "page=off override=none arrow=on", "health=1.00 arrow=1.00 calls=12" },
		{ "page=off override=none arrow=off", "health=1.00 arrow=0.00 calls=12" },
	},
})
