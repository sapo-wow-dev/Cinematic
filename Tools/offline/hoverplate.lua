-- The Nameplates page's Mouseover row (YourMouseover, under Your target),
-- offline (Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/hoverplate.lua <forever|retail>
-- Off to start (every box). On: the plate under the mouse fades up to whole,
-- another plate stays at 0, your own plate never counts, and the mouse
-- leaving fades it back to 0 and forgets it. Plates kept switched on while
-- the row is on. PASS or FAIL lines.
-- luacheck: push ignore 111 112 113 121 122 143
local client = arg and arg[1] or "forever"
package.path = "Tools/offline/?.lua;" .. package.path
local wow = dofile("Tools/offline/wow.lua")
wow.Install(client)
local ns = {}
for line in io.lines("Cinematic.toc") do
	line = line:gsub("\r", "")
	if line ~= "" and not line:find("^#") then
		local chunk = loadfile((line:gsub("\\", "/")))
		if chunk then
			local ok, err = pcall(chunk, "Cinematic", ns)
			if not ok then wow.Warn(line .. ": " .. tostring(err)) end
		end
	end
end
wow.Fire("ADDON_LOADED", "Cinematic")
wow.Fire("PLAYER_LOGIN")

-- The unit under the mouse and its plate, as the test sets them.
local mouse, own = nil, false
local plateA, plateB = CreateFrame("Frame"), CreateFrame("Frame")
local plates = { A = plateA, B = plateB }
UnitExists = function(unit) return unit == "mouseover" and mouse ~= nil or unit == "player" end
UnitIsUnit = function(a, b) return a == "mouseover" and b == "player" and own end
InCombatLockdown = function() return false end
-- (The rows' answers are kept for a frame: each step is a new one.)
local clock = 1000
GetTime = function() return clock end
local function Step(elapsed) clock = clock + elapsed; ns.plates.UpdateHover(elapsed) end
C_NamePlate = C_NamePlate or {}
C_NamePlate.GetNamePlateForUnit = function(unit) return unit == "mouseover" and plates[mouse or ""] or nil end
-- luacheck: pop

local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. text)
	if not ok then failed = failed + 1 end
end

local p = ns.plates
Check(p and p.UpdateHover and p.HoverLevel and p.HoverWanted, "the hover functions loaded")
if not (p and p.UpdateHover) then return print("1 FAILED") end
Check(ns.HasPlateSettings("YourMouseover") == true, "the row is never greyed (no game setting of its own)")

-- Off to start: every box of the row.
local anyOn = false
for key, value in pairs(ns.DEFAULTS) do
	if type(key) == "string" and key:find("YourMouseover$") and value then anyOn = key end
end
Check(not anyOn, "every box off to start" .. (anyOn and (" (" .. anyOn .. " on)") or ""))
mouse = "A"
Check(not p.HoverWanted() and p.HoverPlate() == nil, "off: no plate held for the mouse")
Step(1)
Check(p.HoverLevel(plateA) == 0, "off: the plate under the mouse stays at 0")

-- On (Always).
ns.db.handlePlates = true
ns.db.plateAlwaysYourMouseover = true
clock = clock + 1
Check(p.HoverWanted() == true, "on: wanted")
Check(p.HoverPlate() == plateA, "on: the plate under the mouse is the one")
Step(0.01)
local first = p.HoverLevel(plateA)
Check(first > 0 and first < 1, ("fades in, not popping (%.2f after 10 ms)"):format(first))
for _ = 1, 100 do Step(0.05) end
Check(p.HoverLevel(plateA) == 1, "whole after the fade in")
Check(p.HoverLevel(plateB) == 0, "another plate stays at 0")
Check(p.HoverActive(), "active while held (plates filtered)")

-- To another unit: the first fades down, the new one up.
mouse = "B"
Step(0.01)
Check(p.HoverLevel(plateA) > 0 and p.HoverLevel(plateA) < 1, "the plate left fades down, not cut")
Check(p.HoverLevel(plateB) > 0, "the new plate under the mouse fades up")

-- Mouse off every unit: both go down, and are forgotten.
mouse = nil
for _ = 1, 100 do Step(0.05) end
Check(p.HoverLevel(plateA) == 0 and p.HoverLevel(plateB) == 0, "mouse gone: both back to 0")
Check(not p.HoverActive(), "nothing left held or leaving")

-- Your own plate never counts.
mouse, own = "A", true
Check(p.HoverPlate() == nil, "your own plate is never held")
own = false

-- Row off again: let go.
ns.db.plateAlwaysYourMouseover = false
for _ = 1, 100 do Step(0.05) end
Check(p.HoverLevel(plateA) == 0 and not p.HoverActive(), "row off: nothing held")

-- Nameplates page off: nothing, even with the row ticked.
ns.db.plateAlwaysYourMouseover = true
ns.db.handlePlates = false
clock = clock + 1
Check(not p.HoverWanted(), "Nameplates page off: not wanted")

print(failed == 0 and "ALL PASS" or (failed .. " FAILED"))
if failed > 0 then os.exit(1) end
