-- Exit CineMode's Show in row (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/exitrow.lua <forever|retail>
-- The Exit CineMode tab's boxes, in two columns now, or a Show in row in
-- their place (exitByRow, off to start with): ticked, the boxes count for
-- nothing (CineMode stays on in fights, no place, group, moving, window or
-- NPC exit) and the row (cine:exit, its Always cineExitAlways) decides; the
-- page greys the boxes while it's ticked and the row while it isn't. Says
-- PASS or FAIL per check.
-- luacheck: push ignore 111 112 113
local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client)
-- luacheck: pop
local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. text)
	if not ok then failed = failed + 1 end
end

-- Defaults.
Check(ns.DEFAULTS.exitByRow == false, "Use a Show in row instead: off to start with")
Check(ns.DEFAULTS.cineExitAlways == false, "the row's Always: off to start with")
Check(ns.EXIT_ROW == "cine:exit", "the row's key (" .. tostring(ns.EXIT_ROW) .. ")")

-- The boxes set aside.
local db = ns.db
db.stayInCombat, db.exitByRow = false, false
Check(ns.StaysInCombat() == false, "boxes: In combat ticked exits in fights")
db.exitByRow = true
Check(ns.StaysInCombat() == true, "row: the In combat box counts for nothing")
db.stayWithWindows, db.revealAtNPCs = false, true
Check(ns.WindowsExit() == false and ns.NPCsExit() == false, "row: windows and NPCs count for nothing")

-- The row decides.
db.exitByRow, db.cineExitAlways = true, true
Check(ns.ExitRowOn() == true, "row: Always ticked exits everywhere")
db.cineExitAlways = false
Check(ns.ExitRowOn() == false, "row: nothing ticked, no exit")
db.exitByRow, db.cineExitAlways = false, true
Check(ns.ExitRowOn() == false, "boxes: the row counts for nothing")
db.cineExitAlways = false

-- The page: find its controls by setting.
local canvas = ns.settingsCanvases and ns.settingsCanvases.CineMode
Check(canvas ~= nil, "the CineMode page is made")
local found = {}
local function Walk(frame, depth)
	if depth > 30 then return end
	if type(frame.settingKey) == "string" and not found[frame.settingKey] then found[frame.settingKey] = frame end
	for _, child in ipairs({ frame:GetChildren() }) do Walk(child, depth + 1) end
end
if canvas then Walk(canvas, 0) end
local BOXES = { "stayInCombat", "offInWorld", "offInCities", "offInDungeons", "offInRaids", "offInPvP", "offInBGs",
	"offInParty", "offInRaidGroup", "offWhileMoving", "stayWithWindows", "revealAtNPCs", "movingStillAfter" }
for _, key in ipairs(BOXES) do
	local control = found[key]
	if control then control.SetEnabled = function(self, on) self._on = on end end
end
Check(found.exitByRow ~= nil, "Use a Show in row instead is on the page")
local function BoxesOn(want)
	local ok = true
	for _, key in ipairs(BOXES) do
		local control = found[key]
		if not control then
			print("  missing " .. key)
			ok = false
		else
			control:Refresh()
			if control._on ~= want then
				print("  " .. key .. " enabled " .. tostring(control._on))
				ok = false
			end
		end
	end
	return ok
end
db.offWhileMoving = true
db.exitByRow = false
Check(BoxesOn(true), "unticked: every box usable")
db.exitByRow = true
Check(BoxesOn(false), "ticked: every box greyed")

-- The row's ticks grey unless it's used (the dropdown rows' or the boxes').
local rowControls = {}
local function WalkRow(frame, depth)
	if depth > 30 then return end
	if frame.RowId and frame.RowId() == ns.EXIT_ROW then rowControls[#rowControls + 1] = frame end
	for _, child in ipairs({ frame:GetChildren() }) do WalkRow(child, depth + 1) end
end
if canvas then WalkRow(canvas, 0) end
if #rowControls > 0 then
	local row = rowControls[1]
	local enabled
	-- (Its Always box: greyed with the row.)
	for _, child in ipairs({ row:GetChildren() }) do
		if child:GetObjectType() == "CheckButton" then child.SetEnabled = function(_, on) enabled = on end end
	end
	db.exitByRow = false
	row:Refresh()
	local off = enabled
	db.exitByRow = true
	row:Refresh()
	Check(off == false and enabled == true, "the row greys unless used (" .. tostring(off) .. ", " .. tostring(enabled) .. ")")
else
	print("SKIP the row's greying: no dropdown row on this client")
end
db.exitByRow, db.offWhileMoving = false, false

print(failed == 0 and "ALL PASS" or (failed .. " FAILED"))
