-- Style hooks that can't be taken off, resting once their page is off (the
-- audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-25-style-hooks-rest.md):
--   python -I Tools/offline/run.py Tools/offline/stylehooksrestmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/stylehooksrestmatrix.lua forever --base <ref>
-- what: a tooltip shown (Tooltip Style), the target frame's auras laid out
-- (Unit Frames Style's buff row lift), the minimap's ring turned (Minimap
-- Style's tinted ring copy). page: on, or on then switched off (put back),
-- or (tooltip) a tooltip never dressed while it was on. Each cell: how many
-- of three such game calls did our work (Dress, the lift's Apply, the copy
-- turned).
-- The rule (page off = no cost): three while on; none once put back.
local client = arg and arg[1] or "forever"
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db
-- (hooksecurefunc for real from here: the hooks below are made after the load.)
do
	-- luacheck: push ignore 111 112 113 121 122
	hooksecurefunc = function(target, name, post)
		if type(target) == "string" then target, name, post = _G, target, name end
		local old = target[name]
		if type(old) ~= "function" then return end
		target[name] = function(...)
			local a, b, c, d = old(...)
			post(...)
			return a, b, c, d
		end
	end
	-- luacheck: pop
end

local function Up(fn, wanted)
	for i = 1, 120 do
		local name, value = debug.getupvalue(fn, i)
		if not name then break end
		if name == wanted then return value, i end
	end
end
local function Count(fn, wanted, into)
	local old, at = Up(fn, wanted)
	if not at then return false end
	debug.setupvalue(fn, at, function(...)
		into.n = into.n + 1
		return old(...)
	end)
	return true
end

-- Tooltips: their Apply (the shows' hooks call it), Dress counted.
local tipApply = Up(ns.RefreshTooltipStyle, "Apply")
local tipWork = { n = 0 }
local tipReady = tipApply and Count(tipApply, "Dress", tipWork)
local function NewTooltip()
	local tip = wow.CreateFrame("Frame", nil, UIParent)
	tip.NineSlice = wow.CreateFrame("Frame", nil, tip)
	tip.NineSlice.Center = tip.NineSlice:CreateTexture()
	tip.GetUnit = function() return nil end
	return tip
end

-- The target frame's aura row: its UpdateAuras hook, its Apply counted.
local target = wow.CreateFrame("Button", "TargetFrame", UIParent)
target.UpdateAuras = function() end
local liftWork = { n = 0 }
local liftReady = false
if ns.UnitAuraLift then
	ns.UnitAuraLift(target, nil)
	-- (The hook wraps the game's method: its post call holds Apply.)
	local wrapped = target.UpdateAuras
	local post = wrapped and Up(wrapped, "post")
	liftReady = post and Count(post, "Apply", liftWork) or false
end

-- The minimap's ring and its tinted copy (made by TintRings), the copy's turns counted.
local TintRings = Up(ns.RefreshMinimapStyle, "TintRings")
local holder = wow.CreateFrame("Frame", "MinimapCluster", UIParent)
local ring = holder:CreateTexture()
ring.GetAtlas = function() return "ui-hud-minimap-frame" end
ring.GetRotation = function(self) return self._turn or 0 end
ring.SetRotation = function(self, turn) self._turn = turn end
_G.MinimapCompassTexture = ring
local turns = { n = 0 }
local mapReady = false
if TintRings then
	TintRings({ 1, 0, 0 })
	local lift = (Up(TintRings, "lifts") or {})[ring]
	if lift then
		rawset(lift, "SetRotation", function() turns.n = turns.n + 1 end)
		mapReady = true
	end
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "style-hooks-rest",
	fixed = { client = client },
	dims = {
		{ "what", { "tooltip", "auras", "minimap" } },
		{ "page", { "on", "onThenOff", "neverDressed" } },
	},
	cell = function(c)
		db.styleGeneral = true
		if c.what == "tooltip" then
			if not tipReady then return "no stand-in" end
			local tip = NewTooltip()
			db.tooltipStyle = c.page ~= "neverDressed"
			if c.page ~= "neverDressed" then tipApply(tip) end
			if c.page == "onThenOff" then
				db.tooltipStyle = false
				tipApply(tip)
			end
			tipWork.n = 0
			for _ = 1, 3 do tipApply(tip) end
			db.tooltipStyle = true
			return ("work=%d"):format(tipWork.n)
		elseif c.page == "neverDressed" then
			return "n/a"
		elseif c.what == "auras" then
			if not liftReady then return "no stand-in" end
			db.ufStyle = true
			if c.page == "onThenOff" then db.ufStyle = false end
			liftWork.n = 0
			for _ = 1, 3 do target:UpdateAuras() end
			db.ufStyle = true
			return ("work=%d"):format(liftWork.n)
		else
			if not mapReady then return "no stand-in" end
			TintRings({ 1, 0, 0 })
			if c.page == "onThenOff" then TintRings(nil) end
			turns.n = 0
			for i = 1, 3 do ring:SetRotation(i / 10) end
			local out = ("work=%d"):format(turns.n)
			TintRings({ 1, 0, 0 })
			return out
		end
	end,
	pins = {
		{ "", "work=0" },
		{ "page=on", "work=3" },
		{ "page=neverDressed what=auras", "n/a" },
		{ "page=neverDressed what=minimap", "n/a" },
	},
})
