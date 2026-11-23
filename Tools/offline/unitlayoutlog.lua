-- Unit frame layout line in /cine log (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/unitlayoutlog.lua < /dev/null
-- ns.UnitLayoutMeasure (Style/UnitStyle.lua), what /cine log's "unit frames:"
-- lines are made of: a theme-shaped frame's portrait against its rows (the
-- name strip down to the last bar that shows), and against the portrait's spot
-- at the frame's first fit. For "the portrait moved from the default look"
-- (2026-11-23), a frame already off when its unit was first seen. Checked: a
-- centered frame is ok; rows laid out for 2 with the mana bar then shown read
-- OFF; a portrait moved from its first fit reads OFF; a hidden strip or mana bar
-- isn't counted; secret reads give nil, not an error; and the setup summary
-- (ns.SetupSummary) carries the lines. Says PASS or FAIL per check.
-- (Optional first argument: another .toc to load, to run it on older code.)
local SECRET = setmetatable({}, { __tostring = function() return "secret" end })

-- luacheck: push ignore 111 112 113 121 122 212
local ns = dofile("Tools/offline/load.lua")("forever", arg and arg[1], function()
	issecretvalue = function(value) return value == SECRET end
	-- (The summary lists the other addons: none here.)
	C_AddOns = C_AddOns or {}
	C_AddOns.GetNumAddOns = function() return 0 end
end)
-- luacheck: pop

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

-- A region from its top and height (screen y grows upward).
local secret = false
local function Box(top, height)
	local r = { top = top, height = height, shown = true }
	function r:GetTop() if secret then return SECRET end return self.top end
	function r:GetBottom() if secret then return SECRET end return self.top - self.height end
	function r:IsShown() return self.shown end
	return r
end

-- The boar's look: portrait 66 tall, its middle at 467; strip 16, health 20, 2 gaps.
local frame = Box(500, 100)
local portrait = Box(500, 66)          -- middle 467
local strip = Box(486, 16)             -- rows 486 .. 448: middle 467
local health = Box(468, 20)
local power = Box(446, 10)
power.shown = false

local r = ns.UnitLayoutMeasure(frame, { health, power }, strip, portrait, -33)
Check("centered frame is ok", r and not r.bad and math.abs(r.off) < 0.01 and r.rows == 1, r and r.off)
Check("moved is 0 at the first fit's spot", r and r.moved == 0, r and r.moved)

-- Darius: the mana bar shows, the rows not laid out again (fit in a fight).
power.shown = true
r = ns.UnitLayoutMeasure(frame, { health, power }, strip, portrait, -33)
Check("mana bar shown, rows not refit: OFF", r and r.bad and r.rows == 2 and r.off > 1.5, r and r.off)

-- Laid out again for 3 rows (strip 486 .. mana 436 = middle 461): portrait centered on it.
portrait.top = 494
r = ns.UnitLayoutMeasure(frame, { health, power }, strip, portrait, -39)
Check("refit for the mana bar is ok", r and not r.bad, r and (r.off .. " " .. tostring(r.moved)))

-- The portrait itself moved from its first fit, rows still centered on it.
r = ns.UnitLayoutMeasure(frame, { health, power }, strip, portrait, -33)
Check("portrait moved from its first fit: OFF", r and r.bad and math.abs(r.moved + 6) < 0.01, r and r.moved)

-- Strip hidden: the rows start at the health bar.
strip.shown = false
portrait.top = 500
power.shown = false
r = ns.UnitLayoutMeasure(frame, { health, power }, strip, portrait, nil)
Check("hidden strip not counted", r and math.abs(r.off - 9) < 0.01 and r.moved == nil, r and r.off)

-- Secret reads (a fight on Forever): nil, no error.
secret = true
local ok, value = pcall(ns.UnitLayoutMeasure, frame, { health, power }, strip, portrait, -33)
Check("secret reads give nil", ok and value == nil, value)
secret = false

-- The summary carries the lines.
local was = ns.UnitLayoutLines
ns.UnitLayoutLines = function() return { "TargetFrame (shape petal, out of fights): OFF, test line" } end
local okSummary, summary = pcall(ns.SetupSummary)
Check("summary has the unit frames line", okSummary and tostring(summary):find("unit frames: TargetFrame", 1, true) ~= nil,
	not okSummary and summary or nil)
ns.UnitLayoutLines = function() error("boom") end
okSummary, summary = pcall(ns.SetupSummary)
Check("a failing check doesn't break the summary", okSummary and tostring(summary):find("check failed", 1, true) ~= nil,
	not okSummary and summary or nil)
ns.UnitLayoutLines = was

-- The real collector runs without a fitted frame (nothing to say, no error).
local okLines, lines = pcall(ns.UnitLayoutLines)
Check("collector with no fitted frame", okLines and type(lines) == "table" and #lines == 0, not okLines and lines or nil)

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
