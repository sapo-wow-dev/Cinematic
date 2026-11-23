-- The Cooldown Manager's icons with Action Bar Style's Shape (the audit kit's
-- matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-23-style-cdm-round-trim.md):
--   python -I Tools/offline/run.py Tools/offline/cdmroundmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/cdmroundmatrix.lua forever --base <ref>
-- A stand-in icon on each of the three viewers the shape dresses (Essential,
-- Utility, Tracked Buffs), the shape (the game's, Square, Round), and the
-- order: the shape alone, the shape after Round (going back), and the game
-- setting the icon's crop again after it's dressed. Each cell: the icon's
-- crop (its left edge, as a share of the art) and whether a round mask is on
-- its picture.
-- Round: cut round, cropped 7% in (every icon's own edge gone: the whole
-- export checked, Tools/icons/trimscan.py, 2026-11-23). Square or the
-- game's: the game's own crop, no mask.

local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
assert(ns.RefreshCooldownShape, "Action Bar Style didn't load")

-- (hooksecurefunc for real here: the crop's hook on SetTexCoord is half of it.)
_G.hooksecurefunc = function(target, name, post)
	if type(target) == "string" then target, name, post = _G, target, name end
	local old = target[name]
	target[name] = function(...)
		local a, b, c, d = old(...)
		post(...)
		return a, b, c, d
	end
end

local GAME = { 0, 0, 0, 1, 1, 0, 1, 1 } -- (the game's crop: the whole art)
local function NewIcon(holder)
	local icon = holder:CreateTexture()
	icon._coords = { unpack(GAME) }
	icon._masks = {}
	function icon:SetTexCoord(...)
		local n = select("#", ...)
		if n == 4 then
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

local NAMES = { essential = "EssentialCooldownViewer", utility = "UtilityCooldownViewer",
	buffs = "BuffIconCooldownViewer" }
local function Viewer(which)
	local viewer = CreateFrame("Frame", nil, UIParent)
	local item = CreateFrame("Frame", nil, viewer)
	item.Icon = NewIcon(item)
	_G[NAMES[which]] = viewer
	for other, name in pairs(NAMES) do
		if other ~= which then _G[name] = nil end
	end
	return item.Icon
end

local lookWas = ns.StyleLook
local shapeNow
ns.StyleLook = function(key, ...)
	local look = lookWas(key, ...)
	if key ~= "abStyle" then return look end
	return setmetatable({ abShape = shapeNow }, { __index = type(look) == "table" and look or {} })
end
local function Shape(shape)
	shapeNow = shape
	ns.RefreshCooldownShape()
end

local function Read(icon)
	local left = icon:GetTexCoord()
	local masked = next(icon._masks) ~= nil
	return ("crop %.2f %s"):format(left, masked and "masked" or "unmasked")
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "cdm-round",
	fixed = { client = client },
	dims = {
		{ "viewer", { "essential", "utility", "buffs" } },
		{ "shape", { "game", "square", "round" } },
		{ "order", { "alone", "afterRound", "gameRecrops" } },
	},
	cell = function(c)
		local icon = Viewer(c.viewer)
		if c.order == "afterRound" then Shape("round") end
		Shape(c.shape)
		if c.order == "gameRecrops" then icon:SetTexCoord(0, 1, 0, 1) end
		return Read(icon)
	end,
	pins = {
		{ "", "crop 0.00 unmasked" },
		{ "shape=round", "crop 0.07 masked" },
	},
})
