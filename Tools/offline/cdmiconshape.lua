-- Cooldown Manager Style's Shape tab (cdmIconShape): the Cooldown Manager's
-- icons round or square on their own, whatever Action Bar Style's buttons are.
--   python -I Tools/offline/run.py Tools/offline/cdmiconshape.lua [forever|retail] < /dev/null
-- Each cell: the action buttons' shape (the game's, Square, Round), the tab's
-- pick (Same as action bars, Square, Round), and the page's switch. Reads an
-- Essential icon's crop + mask, and what the round-art helpers say (the Flash
-- when ready and our own sweeps follow them).
-- Page on: Square / Round win; "bars" follows the buttons. Page off: the buttons.

local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
assert(ns.RefreshCooldownShape, "Action Bar Style didn't load")
assert(ns.DEFAULTS.cdmIconShape == "bars", "cdmIconShape default isn't bars")

_G.hooksecurefunc = function(target, name, post)
	if type(target) == "string" then target, name, post = _G, target, name end
	local old = target[name]
	target[name] = function(...)
		local a, b, c, d = old(...)
		post(...)
		return a, b, c, d
	end
end

local GAME = { 0, 0, 0, 1, 1, 0, 1, 1 }
local function NewIcon(holder)
	local icon = holder:CreateTexture()
	icon._coords = { unpack(GAME) }
	icon._masks = {}
	function icon:SetTexCoord(...)
		if select("#", ...) == 4 then
			local l, r, t, b = ...
			self._coords = { l, t, l, b, r, t, r, b }
		else
			self._coords = { ... }
		end
	end
	function icon:GetTexCoord() return unpack(self._coords) end
	function icon:AddMaskTexture(mask) self._masks[mask] = true end
	function icon:RemoveMaskTexture(mask) self._masks[mask] = nil end
	return icon
end

-- (A fresh viewer each cell: no icon carries the last cell's dress.)
local function Viewer()
	local viewer = CreateFrame("Frame", nil, UIParent)
	local item = CreateFrame("Frame", nil, viewer)
	item.Icon = NewIcon(item)
	_G.EssentialCooldownViewer = viewer
	_G.UtilityCooldownViewer, _G.BuffIconCooldownViewer = nil, nil
	return item.Icon
end

local db = ns.db
local lookWas = ns.StyleLook
local buttons
ns.StyleLook = function(key, ...)
	local look = lookWas(key, ...)
	if key ~= "abStyle" then return look end
	return setmetatable({ abShape = buttons }, { __index = type(look) == "table" and look or {} })
end

local function Read(icon)
	local left = icon:GetTexCoord()
	local masked = next(icon._masks) ~= nil
	local art = ns.CooldownRoundArt() ~= nil
	local swipe = ns.CooldownSwipeTexture() ~= nil
	return ("crop %.2f %s art %s swipe %s"):format(left, masked and "masked" or "unmasked",
		tostring(art), tostring(swipe))
end
local ROUND = "crop 0.07 masked art true swipe true"
local SQUARE = "crop 0.00 unmasked art false swipe false"

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "cdm-icon-shape",
	fixed = { client = client },
	dims = {
		{ "buttons", { "game", "square", "round" } },
		{ "pick", { "bars", "square", "round" } },
		{ "page", { "on", "off" } },
		{ "tab", { "on", "off" } }, -- (the Icons folder tab right-clicked off)
	},
	cell = function(c)
		local icon = Viewer()
		buttons = c.buttons
		db[("tabOn:%s:%d"):format(ns.CDM_STYLE_TABS, ns.CDM_STYLE_ICONS_TAB)] = c.tab == "on"
		db.styleGeneral = true
		db.cdmStyle = c.page == "on"
		db.cdmIconShape = c.pick
		assert(ns.StyleOn("cdmStyle") == (c.page == "on"), "cdmStyle switch reads " .. tostring(ns.StyleOn("cdmStyle")))
		ns.RefreshCooldownShape()
		-- (Back again: the pick changed to the buttons' shape undoes its own.)
		local first = Read(icon)
		db.cdmIconShape = "bars"
		ns.RefreshCooldownShape()
		local back = Read(icon)
		local want = buttons == "round" and ROUND or SQUARE
		assert(back == want, ("back to bars: %s, wanted %s"):format(back, want))
		return first
	end,
	pins = {
		{ "", SQUARE }, -- (later pins win)
		{ "buttons=round", ROUND }, -- (Same as action bars, or the page off: the buttons')
		{ "pick=round page=on tab=on", ROUND },
		{ "pick=square page=on tab=on", SQUARE },
	},
})
