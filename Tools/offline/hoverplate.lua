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

-- Mouse off every unit: both go down, and are forgotten. Each plate's look
-- is redrawn as it starts fading and once it's gone (run 7: PlateParts' own
-- mouse check could run first and leave it plain for the whole fade).
local redrawn, realRefresh = {}, ns.RefreshPlateLook
ns.RefreshPlateLook = function(plate) redrawn[#redrawn + 1] = plate end
mouse = nil
Step(0.01)
local atLeave = 0
for _, each in ipairs(redrawn) do if each == plateB then atLeave = atLeave + 1 end end
Check(atLeave == 1, ("the plate left: its look redrawn as it starts fading (%d)"):format(atLeave))
for _ = 1, 100 do Step(0.05) end
local seen = {}
for _, each in ipairs(redrawn) do seen[each] = (seen[each] or 0) + 1 end
Check((seen[plateA] or 0) >= 1 and (seen[plateB] or 0) >= 2,
	("each plate's look redrawn once faded (A %d, B %d)"):format(seen[plateA] or 0, seen[plateB] or 0))
ns.RefreshPlateLook = realRefresh
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

-- Nameplate Style's Mouseover row (its look: a white bar...) while the plate
-- fades back down after the mouse left: it keeps that row, not the plain
-- look popping in for the fade (the user, 2026-11-23). Gone once faded.
ns.db.handlePlates = true
mouse = nil
clock = clock + 1
if ns.PlateRowNow then
	local before = ns.PlateRowNow(plateA, "nameplate1")
	p.hover.leaving[plateA] = 0.5
	clock = clock + 1
	local fading = ns.PlateRowNow(plateA, "nameplate1")
	p.hover.leaving[plateA] = nil
	clock = clock + 1
	local after = ns.PlateRowNow(plateA, "nameplate1")
	Check(before ~= "mouseover", "mouse elsewhere, nothing fading: not the Mouseover look (" .. tostring(before) .. ")")
	Check(fading == "mouseover", "fading back down: keeps the Mouseover look (" .. tostring(fading) .. ")")
	Check(after ~= "mouseover", "faded: the Mouseover look gone (" .. tostring(after) .. ")")
else
	Check(false, "ns.PlateRowNow loaded")
end

-- The Mouseover names row (YourMouseover in the Names groups): the same
-- watcher, the name alone. The plate row off: the plate under the mouse is
-- tracked for its name, but its body isn't lifted.
local function Upvalue(fn, name)
	for i = 1, 200 do
		local n, v = debug.getupvalue(fn, i)
		if not n then return nil end
		if n == name then return v, i end
	end
end
local mouseGroup
for _, group in ipairs(ns.NAME_GROUPS) do
	if group.key == "YourMouseover" then mouseGroup = group end
end
Check(mouseGroup and mouseGroup.plateOnly and mouseGroup.mouse and #mouseGroup.cvars == 0,
	"names: its own Names group, no game setting (plateOnly)")
Check(mouseGroup and ns.HasNameSettings(mouseGroup), "names: the row is never greyed")
Check(ns.DEFAULTS.nameAlwaysYourMouseover == false and ns.DEFAULTS.nameCombatYourMouseover == false
	and ns.DEFAULTS.nameKeepYourMouseover == false, "names: its boxes are settings, off to start")
local nameLevel = Upvalue(p.HoverNameWanted, "nameLevel")
Check(type(nameLevel) == "table", "names: the names' fade table read")
nameLevel = nameLevel or {}
ns.db.handlePlates, ns.db.plateAlwaysYourMouseover = true, false
mouse = "A"
clock = clock + 1
nameLevel.YourMouseover = 0
Check(not p.HoverNameWanted() and p.HoverPlate() == nil, "names: row down, nothing tracked")
nameLevel.YourMouseover = 1
clock = clock + 1
Check(p.HoverNameWanted() and not p.HoverWanted(), "names: row up, the plate row still off")
Check(p.HoverPlate() == plateA, "names: the plate under the mouse is tracked")
for _ = 1, 100 do Step(0.05) end
Check(p.HoverLevel(plateA) == 1, "names: the mouse's level whole after the fade in")
Check(p.HoverBodyLevel(plateA) == 0, "names: the plate itself not lifted (plate row off)")
Check(p.HoverBodyLevel(plateB) == 0 and p.HoverLevel(plateB) == 0, "names: another plate untouched")
ns.db.plateAlwaysYourMouseover = true
clock = clock + 1
Check(p.HoverBodyLevel(plateA) == 1, "names + plate rows: the plate whole")
ns.db.plateAlwaysYourMouseover = false
clock = clock + 1
-- (CineMode's fade all the way down: every plate out but what a row keeps.)
local levelWas = p.level
p.level = 0
-- The name share PlateAlphas gives the plate under the mouse, plates forced on.
local PlateAlphas = Upvalue(ns.DescribePlateNameKept, "PlateAlphas")
local _, forcedAt = Upvalue(ns.DescribePlateNameKept, "platesForced")
if PlateAlphas and forcedAt then
	debug.setupvalue(ns.DescribePlateNameKept, forcedAt, true)
	local ok, alpha, body, name = pcall(PlateAlphas, "mouseover", plateA)
	Check(ok and alpha and alpha > 0.99 and name and name > 0.99 and body == 0,
		("names: the plate under the mouse shows its name (alpha %s, body %s, name %s)")
			:format(tostring(alpha), tostring(body), tostring(name)))
	local okB, alphaB = pcall(PlateAlphas, "nameplate2", plateB)
	Check(okB and alphaB == 0, "names: another plate keeps no name (" .. tostring(alphaB) .. ")")
	mouse = nil
	for _ = 1, 100 do Step(0.05) end
	local okC, alphaC = pcall(PlateAlphas, "mouseover", plateA)
	Check(okC and alphaC == 0, "names: the mouse gone, the name fades back out (" .. tostring(alphaC) .. ")")
	debug.setupvalue(ns.DescribePlateNameKept, forcedAt, false)
else
	Check(false, "names: PlateAlphas and platesForced read")
end
nameLevel.YourMouseover = 0
p.level = levelWas

print(failed == 0 and "ALL PASS" or (failed .. " FAILED"))
if failed > 0 then os.exit(1) end
