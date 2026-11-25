-- Plate Layout: snapping a dragged part to the bar (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-plate-layout-snap.md):
--   python -I Tools/offline/run.py Tools/offline/platelayoutsnapmatrix.lua < /dev/null
--   python -I Tools/audit.py diff Tools/offline/platelayoutsnapmatrix.lua forever --base <ref>
-- A part 60 wide (its left at 100: one edge alone in reach at a time) dragged so its left, middle or right comes
-- 3 or 6 short of the bar's left (40), middle (140) or right (240). Each cell:
-- the move after snapping, and the line it lined up on. Within 4: on it
-- exactly; past 4: the move as dragged. (The bar 40..240; the part 100..160.)
-- luacheck: ignore 111 112 113 121 122 212 431
local Stub = setmetatable({}, { __index = function() return function() end end })
CreateFrame = function() return Stub end
C_Timer = { NewTicker = function() return {} end }
hooksecurefunc = function() end
issecretvalue = function() return false end
local ns = { db = {}, isRetail = false, L = setmetatable({}, { __index = function(_, k) return k end }) }
function ns.Module(_, fn) fn() end
function ns.SetOnUpdate() end
assert(loadfile("Plates/PlateLayout.lua"))("Cinematic", ns)

local LEFT, RIGHT, BAR_L, BAR_R = 100, 160, 40, 240
local EDGE = { left = LEFT, middle = (LEFT + RIGHT) / 2, right = RIGHT }
local TARGET = { left = BAR_L, middle = (BAR_L + BAR_R) / 2, right = BAR_R }
local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "platelayout-snap",
	fixed = { client = "forever" },
	dims = { { "edge", { "left", "middle", "right" } }, { "target", { "left", "middle", "right" } },
		{ "short", { "3", "6" } } },
	cell = function(c)
		local move = TARGET[c.target] - EDGE[c.edge] - tonumber(c.short)
		if not ns.PlateLayoutSnap then return ("move=%d line=none"):format(move) end
		local got, line = ns.PlateLayoutSnap(move, LEFT, RIGHT, BAR_L, BAR_R, 4)
		return ("move=%d line=%s"):format(got, line and tostring(line) or "none")
	end,
	pins = {
		-- What's right (the user's mockup, audit 2026-11-25): within 4 of a bar edge or its
		-- middle, exactly on it; 6 short, as dragged.
		{ "edge=left target=left short=3", "move=-60 line=40" },
		{ "edge=left target=middle short=3", "move=40 line=140" },
		{ "edge=left target=right short=3", "move=140 line=240" },
		{ "edge=middle target=left short=3", "move=-90 line=40" },
		{ "edge=middle target=middle short=3", "move=10 line=140" },
		{ "edge=middle target=right short=3", "move=110 line=240" },
		{ "edge=right target=left short=3", "move=-120 line=40" },
		{ "edge=right target=middle short=3", "move=-20 line=140" },
		{ "edge=right target=right short=3", "move=80 line=240" },
		{ "edge=left target=left short=6", "move=-66 line=none" },
		{ "edge=left target=middle short=6", "move=34 line=none" },
		{ "edge=left target=right short=6", "move=134 line=none" },
		{ "edge=middle target=left short=6", "move=-96 line=none" },
		{ "edge=middle target=middle short=6", "move=4 line=none" },
		{ "edge=middle target=right short=6", "move=104 line=none" },
		{ "edge=right target=left short=6", "move=-126 line=none" },
		{ "edge=right target=middle short=6", "move=-26 line=none" },
		{ "edge=right target=right short=6", "move=74 line=none" },
	},
})
