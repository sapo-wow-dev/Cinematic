-- Unit frames' By health color without garbage per health change (offline,
-- Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/byhealthalloc.lua < /dev/null
-- Audit 2026-11-22: the health curve's lookup built four tables, a key from
-- three formats and a closure on every health change of every styled frame
-- (raid members in a fight). On stand-in curves: one curve made for the same
-- colors, a new one when a color changes, the fill painted each time, and
-- 2000 health changes making next to no garbage. PASS or FAIL per check.

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local made = 0
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	CreateColor = function(r, g, b, a)
		return { GetRGBA = function() return r, g, b, a end }
	end
	C_CurveUtil = { CreateColorCurve = function()
		made = made + 1
		return { AddPoint = function() end }
	end }
	local color = CreateColor(0.5, 0.5, 0.1, 1)
	UnitHealthPercent = function() return color end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", Install)
Check("By health can run here", ns.CanColorByHealth == true)

local bar = wow.CreateFrame("StatusBar")
local fill = { painted = 0 }
fill.SetVertexColor = function() fill.painted = fill.painted + 1 end
rawset(bar, "GetStatusBarTexture", function() return fill end)
local view = { ufHealthColor = "health" }

ns.UnitStyleByHealth(bar, view, "party1")
ns.UnitStyleByHealth(bar, view, "party1")
Check("one curve for the same colors", made == 1, made)
Check("the fill painted each time", fill.painted == 2, fill.painted)
view.ufHealthLowR = 0.5
ns.UnitStyleByHealth(bar, view, "party1")
Check("a new curve when a color changes", made == 2, made)

collectgarbage("collect")
collectgarbage("stop")
local before = collectgarbage("count")
for _ = 1, 2000 do ns.UnitStyleByHealth(bar, view, "party1") end
local kb = collectgarbage("count") - before
collectgarbage("restart")
Check("2000 health changes: next to no garbage", kb < 20, ("%.1f KB"):format(kb))

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
