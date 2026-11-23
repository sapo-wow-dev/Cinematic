-- Square minimap check (dev tool, offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/squaremap.lua < /dev/null
-- The Style hub's Minimap page (Style/MinimapStyle.lua): Square minimap on
-- and off, its border, standing aside for another addon's square minimap
-- (before and after ours), the page and Enable Style switches putting the
-- round map back, a faded minimap's blank mask coming back square
-- (UI/NodeSweep.lua), and the update moving Interface Recolor's off switch
-- to the new page (Migrations.lua). Says PASS or FAIL per check.
-- (Optional first argument: another .toc to load, to run it on older code.)
local ns = dofile("Tools/offline/load.lua")("forever", arg and arg[1])

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local SQUARE = "Interface\\ChatFrame\\ChatFrameBackground"
local map = _G.Minimap
local masks = {}
map.SetMaskTexture = function(_, path) masks[#masks + 1] = path end
local function LastMask() return masks[#masks] end
-- (The game's ring: its alpha kept, as the game's texture would.)
local ring = { alpha = 1 }
function ring.SetAlpha(self, a) self.alpha = a end
function ring.GetAlpha(self) return self.alpha end
_G.MinimapCompassTexture = ring
_G.GetMinimapShape = nil

local db = ns.db
db.styleGeneral, db.minimapStyle, db.mmSquare = true, true, false
local function Refresh() ns.RefreshMinimapStyle() end
local function Shape() return type(_G.GetMinimapShape) == "function" and _G.GetMinimapShape() or "none" end

Refresh()
Check("page on to start", ns.StyleOn("minimapStyle") == true, tostring(ns.StyleOn("minimapStyle")))
Check("square off by default: no mask set, round", #masks == 0 and Shape() == "none", #masks .. " " .. Shape())

db.mmSquare = true
Refresh()
local on, maskOk, edges = ns.MinimapSquareState()
Check("square on: square mask", LastMask() == SQUARE, tostring(LastMask()))
Check("...shape SQUARE", Shape() == "SQUARE", Shape())
Check("...the round ring hidden", ring.alpha == 0, ring.alpha)
Check("...border shown", on and maskOk and edges, tostring(on) .. " " .. tostring(maskOk) .. " " .. tostring(edges))
local count = #masks
Refresh()
Check("...a second refresh sets nothing again", #masks == count, #masks - count)

db.mmSquareBorderSize = 0
Refresh()
Check("border off: hidden", select(3, ns.MinimapSquareState()) == false)
db.mmSquareBorderSize = 2

-- (A faded minimap's blank mask, then back: square again.)
if ns.SetMinimapBlobsHidden then
	ns.SetMinimapBlobsHidden(true)
	ns.SetMinimapBlobsHidden(false)
	Check("faded and back: square mask again", LastMask() == SQUARE, tostring(LastMask()))
end

db.mmSquare = false
Refresh()
Check("square off: round mask back", LastMask() ~= SQUARE and LastMask() ~= nil, tostring(LastMask()))
Check("...shape back to none", Shape() == "none", Shape())
Check("...the ring back", ring.alpha == 1, ring.alpha)
Check("...border hidden", select(3, ns.MinimapSquareState()) == false)

-- The page off, then Enable Style off, with square on: round.
db.mmSquare = true
Refresh()
db.minimapStyle = false
Refresh()
Check("page off: round", Shape() == "none" and LastMask() ~= SQUARE and ring.alpha == 1, Shape() .. " " .. tostring(LastMask()))
db.minimapStyle = true
Refresh()
db.styleGeneral = false
Refresh()
Check("Enable Style off: round", Shape() == "none" and LastMask() ~= SQUARE, Shape() .. " " .. tostring(LastMask()))
db.styleGeneral = true

-- Another addon's square minimap first: left be.
db.mmSquare = false
Refresh()
local function Theirs() return "SQUARE" end
_G.GetMinimapShape = Theirs
count = #masks
db.mmSquare = true
Refresh()
Check("another addon's square map: ours stands aside", ns.MinimapSquareState() == false and #masks == count
	and _G.GetMinimapShape == Theirs, tostring(ns.MinimapSquareState()) .. " " .. (#masks - count))

-- Ours first, then another addon's: turning ours off leaves theirs be.
_G.GetMinimapShape = nil
Refresh()
Check("ours on again once theirs is gone", ns.MinimapSquareState() == true and Shape() == "SQUARE")
_G.GetMinimapShape = Theirs
count = #masks
Refresh()
Check("theirs after ours: their shape and mask left be", _G.GetMinimapShape == Theirs and #masks == count
	and ns.MinimapSquareState() == false, #masks - count)
_G.GetMinimapShape = nil

-- The rows added the same day: size, border color, parts hidden for good.
local function Part()
	local part = { alpha = 1, mouse = true }
	function part.SetAlpha(self, a) self.alpha = a end
	function part.GetAlpha(self) return self.alpha end
	function part.EnableMouse(self, m) self.mouse = m end
	function part.IsMouseEnabled(self) return self.mouse end
	return part
end
local zoomIn, zoomOut, dial = Part(), Part(), Part()
map.ZoomIn, map.ZoomOut = zoomIn, zoomOut
_G.MinimapCluster = { DielFrame = dial }
local scale = 1
map.SetScale = function(_, value) scale = value end
map.GetScale = function() return scale end
db.mmScale = 1.5
Refresh()
Check("size 150%", scale == 1.5, scale)
db.mmScale = 1
Refresh()
Check("size back to 100%", scale == 1, scale)
db.mmHideZoom, db.mmHideDial = true, true
Refresh()
Check("zoom buttons hidden, no mouse", zoomIn.alpha == 0 and zoomOut.alpha == 0 and zoomIn.mouse == false)
Check("dial hidden", dial.alpha == 0)
db.minimapStyle = false
Refresh()
Check("page off: zoom buttons and dial back", zoomIn.alpha == 1 and dial.alpha == 1 and zoomIn.mouse == true)
db.minimapStyle = true
db.mmHideZoom, db.mmHideDial = false, false
Refresh()
Check("rows off: still back", zoomIn.alpha == 1 and dial.alpha == 1)
for _, case in ipairs({ { "gold", 0.93 }, { "black", 0 }, { "white", 1 } }) do
	db.mmBorderColor = case[1]
	Refresh()
	local edge = ns.MinimapPartsState().edge
	Check("border color " .. case[1], math.abs(edge[1] - case[2]) < 0.01, edge[1])
end
db.mmBorderColor = "theme"

-- The update: Interface Recolor off means the new page off.
local saved = { irStyle = false, profiles = { A = { irStyle = false }, B = { irStyle = true }, C = {} },
	profileResetPoints = { R = { irStyle = false, minimapStyle = true } } }
ns.MinimapPageFromRecolor(saved)
Check("update: Recolor off, page off", saved.minimapStyle == false, tostring(saved.minimapStyle))
Check("...in a profile copy", saved.profiles.A.minimapStyle == false, tostring(saved.profiles.A.minimapStyle))
Check("...Recolor on: page left at its default", saved.profiles.B.minimapStyle == nil and saved.profiles.C.minimapStyle == nil)
Check("...a page switch already saved kept", saved.profileResetPoints.R.minimapStyle == true)
Check("the update marked done", db.minimapPageV1 == true)

print(fails == 0 and "ALL PASS" or (fails .. " FAIL"))
os.exit(fails == 0 and 0 or 1)
