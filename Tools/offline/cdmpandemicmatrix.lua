-- The game's pandemic border on Cooldown Manager icons with Action Bar
-- Style's Shape (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-23-style-cdm-round-pandemic.md):
--   python -I Tools/offline/run.py Tools/offline/cdmpandemicmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/cdmpandemicmatrix.lua forever --base <ref>
-- A stand-in Tracked Buffs icon whose ShowPandemicStateFrame makes the
-- game's border frame (Border.Border, FX, as CooldownPandemicFXTemplate) on
-- it, the shape (the game's, Square, Round), and the order: the border shown
-- after the shape is set, before it, or while Round and the shape set after.
-- Each cell: the game's square border and its sweep shown or hidden, and
-- whether a round glow (ActionRoundProc) shows on it.
-- Round: the square border and sweep hidden, a round glow instead. Square or
-- the game's: the game's border as it is, no glow.

local client = arg and arg[1] or "forever"
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
assert(ns.RefreshCooldownShape, "Action Bar Style didn't load")

-- (Alpha and textures kept on the stand-ins, so what shows can be read.)
local M = wow.Methods
function M:SetAlpha(alpha) self._alpha = alpha end
function M:GetAlpha() return self._alpha or 1 end
function M:SetTexture(texture) self._texture = texture end
function M:GetTexture() return self._texture end

_G.hooksecurefunc = function(target, name, post)
	if type(target) == "string" then target, name, post = _G, target, name end
	local old = target[name]
	target[name] = function(...)
		local a, b, c, d = old(...)
		post(...)
		return a, b, c, d
	end
end

local function NewItem(viewer)
	local item = CreateFrame("Frame", nil, viewer)
	item.Icon = item:CreateTexture()
	function item.Icon:GetTexCoord() return 0, 0, 0, 1, 1, 0, 1, 1 end
	-- (As CooldownViewerItemMixin:ShowPandemicStateFrame: the viewer's pooled
	-- frame, parented to the icon, kept as PandemicIcon, shown.)
	function item:ShowPandemicStateFrame()
		if not rawget(self, "PandemicIcon") then -- (the stand-in answers a stub for a missing capitalized key)
			local fx = CreateFrame("Frame", nil, self)
			fx.Border = CreateFrame("Frame", nil, fx)
			fx.Border.Border = fx.Border:CreateTexture()
			fx.FX = CreateFrame("Frame", nil, fx)
			self.PandemicIcon = fx
		end
		self.PandemicIcon:Show()
	end
	return item
end

local function Viewer()
	local viewer = CreateFrame("Frame", nil, UIParent)
	_G.BuffIconCooldownViewer = viewer
	_G.EssentialCooldownViewer, _G.UtilityCooldownViewer = nil, nil
	return viewer
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

-- A round glow shown anywhere on the border frame (its own textures and its frames').
local function Ring(fx)
	local found = false
	local function Look(frame)
		for _, region in ipairs({ frame:GetRegions() }) do
			if region:IsShown() and tostring(region:GetTexture() or ""):find("ActionRoundProc") then found = true end
		end
		for _, kid in ipairs({ frame:GetChildren() }) do Look(kid) end
	end
	Look(fx)
	return found
end

local function Read(item)
	local fx = item.PandemicIcon
	local border = fx.Border.Border:GetAlpha() > 0 and "shown" or "hidden"
	local sweep = fx.FX:GetAlpha() > 0 and "shown" or "hidden"
	return ("border %s, sweep %s, ring %s"):format(border, sweep, Ring(fx) and "shown" or "none")
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "cdm-pandemic",
	fixed = { client = client },
	dims = {
		{ "shape", { "game", "square", "round" } },
		{ "order", { "after", "before", "whileRound" } },
	},
	cell = function(c)
		local item = NewItem(Viewer())
		if c.order == "before" then
			item:ShowPandemicStateFrame()
			Shape(c.shape)
		elseif c.order == "after" then
			Shape(c.shape)
			item:ShowPandemicStateFrame()
		else
			Shape("round")
			item:ShowPandemicStateFrame()
			Shape(c.shape)
		end
		return Read(item)
	end,
	pins = {
		{ "", "border shown, sweep shown, ring none" },
		{ "shape=round", "border hidden, sweep hidden, ring shown" },
	},
})
