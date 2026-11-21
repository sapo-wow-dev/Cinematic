-- Hover through a stand-in (dev tool, offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/hoverstandin.lua < /dev/null
-- In CineMode, the mouse on a frame that stands in for another for a hover
-- (ns.hoverStandIn: Shoulder Cam's button over your player frame) brings
-- that faded frame up. The hover shortcut from PR 5 (tickTables.FocusChain,
-- 2026-11-21) walked up by parents only, as before the stand-in came in, so
-- your faded player frame stayed down under the mouse. Says PASS or FAIL per check.
-- (Optional first argument: another .toc to load, to run it on older code.)
local ns = dofile("Tools/offline/load.lua")("forever", arg and arg[1])

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

-- (Time moving: the mouse's frame is kept for one frame drawn.)
local now = 100
rawset(_G, "GetTime", function() return now end)
local focus
rawset(_G, "GetMouseFoci", function() return { focus } end)

local function Shown(frame)
	frame.IsVisible = function() return true end
	frame.IsShown = function() return true end
	frame.IsMouseOver = function() return focus == frame end
	frame.IsForbidden = function() return false end
	return frame
end
local faded = Shown(CreateFrame("Frame", "CineTestFadedFrame", UIParent))
local child = Shown(CreateFrame("Button", nil, faded))
local standIn = Shown(CreateFrame("Button", nil, UIParent)) -- (pinned to the screen, not on the frame)
local other = Shown(CreateFrame("Button", nil, UIParent))
local entry = { frame = faded, group = "unitframes" }

local db = ns.db
db.mouseover = true
local managed = ns.managed
ns.managed = { entry }
local function Over(onFrame)
	now = now + 0.1
	focus = onFrame
	entry.hoverWas = nil
	ns.HoverProbe()
	return entry.hoverWas
end

Check("mouse on the frame's own child: hovered", Over(child) == true)
Check("mouse on another frame: not hovered", Over(other) == false)
ns.hoverStandIn[standIn] = faded
Check("mouse on its stand-in: hovered", Over(standIn) == true)
ns.hoverStandIn[standIn] = nil
Check("stand-in let go: not hovered", Over(standIn) == false)
-- (A stand-in pointing back at itself through a parent never loops.)
ns.hoverStandIn[standIn] = standIn
Check("a stand-in loop: answers, not hovered", Over(standIn) == false)
ns.hoverStandIn[standIn] = nil
ns.managed = managed

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
