-- The minimap buttons' rings, every state (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-23-minimap-buttons-tint.md):
--   python -I Tools/offline/run.py Tools/offline/minimapbuttonsmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/minimapbuttonsmatrix.lua --base <ref>
-- Style/MinimapStyle.lua's ns.RefreshMinimapStyle: the theme (the game's look,
-- no ring color, or one with a ring color), Border color (Theme, Black, Gold,
-- Class color), Square minimap and its border size, Color the buttons' rings,
-- the page's switch, and another addon's square minimap.
-- Each cell: the color one button ring (the game's tracking border art, on the
-- Minimap) ends up in: game (its own), ring (the theme's), black, gold or class.
-- The rule (the user, 2026-11-23): with no theme ring color, the buttons take
-- the border's color only when the player picked one or the map is square with
-- a border; otherwise they keep the game's (as before 70613ac).
-- (Square is never on on retail: its row is hidden there, untested. Retail's
-- matrix has square=no only, under its own name.)

local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db

-- luacheck: push ignore 111 112 113 121 122
UnitClass = function() return "Mage", "MAGE", 8 end
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
-- luacheck: pop

local map = _G.Minimap
map.SetMaskTexture = function() end
-- (One button ring on the minimap: the tracking border's file id.)
local ring = { r = 1, g = 1, b = 1, grey = false }
function ring.GetObjectType() return "Texture" end
function ring.GetTexture() return 136430 end
function ring.GetAtlas() return nil end
function ring.SetDesaturated(self, on) self.grey = on and true or false end
function ring.SetVertexColor(self, r, g, b) self.r, self.g, self.b = r, g, b end
map.GetRegions = function() return ring end

local ORNAMENT = { 0.5, 0.9, 0.76 }
local function Brighter(color)
	local top = math.max(color[1], color[2], color[3], 0.01)
	local lift = math.min(1.25, 1 / top)
	return color[1] * lift, color[2] * lift, color[3] * lift
end
local NAMED = {
	{ "ring", ORNAMENT }, { "black", { 0, 0, 0 } }, { "gold", { 0.93, 0.74, 0.34 } }, { "class", { 0.25, 0.78, 0.92 } },
}
local function Seen()
	if not ring.grey and ring.r == 1 and ring.g == 1 and ring.b == 1 then return "game" end
	for _, named in ipairs(NAMED) do
		local r, g, b = Brighter(named[2])
		if math.abs(ring.r - r) < 0.01 and math.abs(ring.g - g) < 0.01 and math.abs(ring.b - b) < 0.01 then
			return named[1]
		end
	end
	return ("other %.2f %.2f %.2f"):format(ring.r, ring.g, ring.b)
end

local function Theirs() return "SQUARE" end
local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	-- (Retail's its own matrix, square=no only: the card's rows say which client.)
	name = client == "retail" and "minimap-buttons-tint-retail" or "minimap-buttons-tint",
	fixed = { client = client },
	dims = {
		{ "theme", { "game", "ringed" } },
		{ "border", { "theme", "black", "gold", "class" } },
		{ "square", client == "retail" and { "no" } or { "yes", "no" } },
		{ "size", { "2", "0" } },
		{ "buttons", { "on", "off" } },
		{ "page", { "on", "off" } },
		{ "others", { "yes", "no" } },
	},
	cell = function(c)
		ns.ThemeRing = function() return c.theme == "ringed" and ORNAMENT or nil end
		db.styleGeneral = true
		db.minimapStyle = c.page == "on"
		db.mmBorderColor = c.border
		db.mmSquare = c.square == "yes"
		db.mmSquareBorderSize = tonumber(c.size)
		db.mmButtons = c.buttons == "on"
		_G.GetMinimapShape = c.others == "yes" and Theirs or nil
		ns.RefreshMinimapStyle()
		local out = Seen()
		-- (Each cell from the game's look: everything let go.)
		_G.GetMinimapShape = nil
		db.minimapStyle = false
		ns.RefreshMinimapStyle()
		return out
	end,
	pins = {
		-- (The page off, another addon's minimap or the row off: the game's.)
		{ "", "game" },
		-- (A theme with a ring color: the buttons take it, square or round.)
		{ "theme=ringed buttons=on page=on others=no", "ring" },
		-- (The game's look, a border color picked: that color.)
		{ "theme=game border=black buttons=on page=on others=no", "black" },
		{ "theme=game border=gold buttons=on page=on others=no", "gold" },
		{ "theme=game border=class buttons=on page=on others=no", "class" },
		-- (The game's look, Border color Theme, a square map with a border: its black border's.)
		{ "theme=game border=theme square=yes size=2 buttons=on page=on others=no", "black" },
	},
})
