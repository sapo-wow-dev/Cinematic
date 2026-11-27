-- Plate Layout: a saved layout and its switches flipped (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-plate-layout-switch-back.md):
--   python -I Tools/offline/run.py Tools/offline/platelayoutswitchmatrix.lua < /dev/null
--   python -I Tools/audit.py diff Tools/offline/platelayoutswitchmatrix.lua forever --base <ref>
-- A layout saved (the level box 10 right) or none. One of the switches the layout reads
-- (Enable Style, Nameplate Style, the Layout tab's) is off as the first plate comes
-- (NAME_PLATE_UNIT_ADDED), then turned on; or all on, then that one turned off. Between
-- them the feature loops' once-a-second look (its wanted()), as Diagnostics.lua asks it.
-- Each cell: the level box at the start and after the flip (moved: the layout's place;
-- game: the game's), and whether a second look with nothing changed does nothing more
-- (quiet: no new pass over the plates, the loop off). A copy of platelayoutmatrix.lua's
-- frame model (the audit runs this file alone against old code).
-- luacheck: ignore 111 112 113 121 122 211 212 213 431 432
-- The frame model ------------------------------------------------------------
local Frame = {}
Frame.__index = Frame
local H = { LEFT = "L", RIGHT = "R", CENTER = "C", TOP = "C", BOTTOM = "C", TOPLEFT = "L", TOPRIGHT = "R",
	BOTTOMLEFT = "L", BOTTOMRIGHT = "R" }
local V = { LEFT = "C", RIGHT = "C", CENTER = "C", TOP = "T", BOTTOM = "B", TOPLEFT = "T", TOPRIGHT = "T",
	BOTTOMLEFT = "B", BOTTOMRIGHT = "B" }
local function New(parent)
	local f = setmetatable({ points = {}, w = 0, h = 0, scale = 1, shown = true, parent = parent, scripts = {} }, Frame)
	return f
end
function Frame:GetParent() return self.parent end
function Frame:SetParent(p) self.parent = p end
function Frame:SetSize(w, h) self.w, self.h = w, h end
function Frame:SetWidth(w) self.w = w end
function Frame:SetHeight(h) self.h = h end
function Frame:SetScale(s) self.scale = s end
function Frame:GetScale() return self.scale end
function Frame:GetEffectiveScale() return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1) end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:SetShown(on) self.shown = on and true or false end
function Frame:IsShown() return self.shown end
function Frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Frame:SetAlpha() end
function Frame:ClearAllPoints() self.points = {} end
function Frame:SetPoint(point, a, b, c, d)
	local rel, rp, x, y
	if type(a) == "number" then rel, rp, x, y = self.parent, point, a, b
	elseif a == nil and b == nil then rel, rp, x, y = self.parent, point, 0, 0
	else rel, rp, x, y = a or self.parent, b or point, c or 0, d or 0 end
	for i, each in ipairs(self.points) do
		if each[1] == point then table.remove(self.points, i) break end
	end
	self.points[#self.points + 1] = { point, rel, rp, x, y }
end
function Frame:SetAllPoints(rel)
	self:ClearAllPoints()
	self:SetPoint("TOPLEFT", rel, "TOPLEFT", 0, 0)
	self:SetPoint("BOTTOMRIGHT", rel, "BOTTOMRIGHT", 0, 0)
end
function Frame:GetNumPoints()
	if self.restricted then error("Can't measure restricted regions") end
	return #self.points
end
function Frame:GetPoint(i)
	if self.restricted then error("Can't measure restricted regions") end
	local p = self.points[i or 1]
	if not p then return nil end
	return p[1], p[2], p[3], p[4], p[5]
end
-- The rect on the screen (screen units): left, right, bottom, top.
function Frame:Rect(depth)
	depth = (depth or 0) + 1
	if depth > 40 then error("anchor loop") end
	if self.root then return self.root[1], self.root[2], self.root[3], self.root[4] end
	if #self.points == 0 then return nil end
	local eff = self:GetEffectiveScale()
	local left, right, cx, bottom, top, cy
	for _, p in ipairs(self.points) do
		local l, r, b, t = p[2]:Rect(depth)
		if not l then return nil end
		local hx, vy = H[p[3]], V[p[3]]
		local ax = (hx == "L" and l or hx == "R" and r or (l + r) / 2) + p[4] * eff
		local ay = (vy == "B" and b or vy == "T" and t or (b + t) / 2) + p[5] * eff
		local mh, mv = H[p[1]], V[p[1]]
		if mh == "L" then left = ax elseif mh == "R" then right = ax else cx = ax end
		if mv == "B" then bottom = ay elseif mv == "T" then top = ay else cy = ay end
	end
	local W, Hh = self.w * eff, self.h * eff
	if left and not right then right = left + W elseif right and not left then left = right - W
	elseif not left then left, right = cx - W / 2, cx + W / 2 end
	if bottom and not top then top = bottom + Hh elseif top and not bottom then bottom = top - Hh
	elseif not bottom then bottom, top = cy - Hh / 2, cy + Hh / 2 end
	return left, right, bottom, top
end
function Frame:GetLeft() local l = self:Rect() return l and l / self:GetEffectiveScale() end
function Frame:GetRight() local _, r = self:Rect() return r and r / self:GetEffectiveScale() end
function Frame:GetBottom() local _, _, b = self:Rect() return b and b / self:GetEffectiveScale() end
function Frame:GetTop() local _, _, _, t = self:Rect() return t and t / self:GetEffectiveScale() end
function Frame:GetCenter()
	local l, r, b, t = self:Rect()
	if not l then return nil end
	local e = self:GetEffectiveScale()
	return (l + r) / 2 / e, (b + t) / 2 / e
end
function Frame:HookScript(name, fn) self.scripts[name] = fn end
function Frame:SetScript(name, fn) self.scripts[name] = fn end
function Frame:GetScript(name) return self.scripts[name] end
function Frame:RegisterEvent() end
function Frame:CreateTexture() return New(self) end
function Frame:CreateFontString() return New(self) end

local UIParent = New(nil)
UIParent.root = { 0, 1000, 0, 800 }
UIParent.GetNumPoints = function() return 0 end

-- The game's plate on the model, laid out as Forever's code does ---------------
local function BuildUnitFrame(plate, live)
	local uf = New(plate)
	uf:SetAllPoints(plate)
	uf.HealthBarsContainer = New(uf)
	uf.HealthBarsContainer.healthBar = New(uf.HealthBarsContainer)
	local bar = uf.HealthBarsContainer.healthBar
	bar.Text = New(bar)
	uf.name = New(uf)
	uf.name:SetSize(120, 14)
	uf.CastBarsContainer = New(uf)
	uf.CastBarsContainer.castBar = New(uf.CastBarsContainer)
	local cast = uf.CastBarsContainer.castBar
	cast.Icon, cast.Text, cast.BorderShield = New(cast), New(cast), New(cast)
	cast.Icon:SetSize(12, 12)
	cast.Text:SetSize(60, 10)
	cast.BorderShield:SetSize(10, 12)
	uf.RaidTargetFrame = New(uf)
	uf.RaidTargetFrame:SetSize(22, 22)
	uf.ClassificationFrame = New(uf)
	uf.ClassificationFrame:SetSize(20, 20)
	uf.ClassificationFrame:SetPoint("RIGHT", uf.RaidTargetFrame, "LEFT") -- (XML)
	uf.AurasFrame = New(uf)
	uf.AurasFrame:SetAllPoints(uf)
	local auras = uf.AurasFrame
	auras.DebuffListFrame, auras.BuffListFrame, auras.CrowdControlListFrame = New(auras), New(auras), New(auras)
	auras.DebuffListFrame:SetSize(100, 20)
	auras.DebuffListFrame:SetPoint("LEFT", uf.HealthBarsContainer, "LEFT") -- (XML)
	auras.BuffListFrame:SetSize(40, 20)
	auras.BuffListFrame:SetPoint("RIGHT", uf.ClassificationFrame, "LEFT", -5, 0) -- (XML)
	auras.CrowdControlListFrame:SetSize(20, 20)
	uf.PlayerLevelDiffFrame = New(uf)
	uf.PlayerLevelDiffFrame:SetWidth(20)
	uf.PlayerLevelDiffFrame:SetPoint("TOPLEFT", bar, "TOPRIGHT", 5, 3) -- (XML)
	uf.PlayerLevelDiffFrame:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", 5, -2)
	uf.SoftTargetFrame = New(uf)
	uf.SoftTargetFrame:SetSize(24, 24)
	uf.SoftTargetFrame:SetPoint("BOTTOM", uf, "TOP", 0, -8) -- (XML)
	function uf:UpdateControlAnchors()
		local list = self.AurasFrame.CrowdControlListFrame
		list:ClearAllPoints()
		if self.PlayerLevelDiffFrame:IsShown() then
			list:SetPoint("LEFT", self.PlayerLevelDiffFrame, "RIGHT", 5, 0)
		else
			list:SetPoint("LEFT", self.HealthBarsContainer, "RIGHT", 5, 0)
		end
	end
	function uf:UpdateAnchors()
		local c = self.CastBarsContainer
		c:ClearAllPoints()
		c:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 12, 0)
		c:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -12, 0)
		c:SetHeight(20)
		local castBar = c.castBar
		castBar:ApplyStyleAndAnchoring()
		local hbc = self.HealthBarsContainer
		hbc:ClearAllPoints()
		hbc:SetPoint("BOTTOMLEFT", c, "TOPLEFT", 0, 4)
		hbc:SetPoint("BOTTOMRIGHT", c, "TOPRIGHT", 0, 4)
		hbc:SetHeight(15)
		self.name:ClearAllPoints()
		hbc.healthBar:ClearAllPoints()
		hbc.healthBar:SetPoint("TOPLEFT", hbc, "TOPLEFT", 0, 0)
		hbc.healthBar:SetPoint("BOTTOMRIGHT", hbc, "BOTTOMRIGHT", 0, 0)
		self.name:SetPoint("BOTTOMLEFT", hbc, "TOPLEFT", 0, 2)
		self.name:SetPoint("RIGHT", hbc, "RIGHT", 0, 0)
		self.RaidTargetFrame:ClearAllPoints()
		self.RaidTargetFrame:SetPoint("RIGHT", hbc, "LEFT", 0, 0)
		self.AurasFrame.DebuffListFrame:SetPoint("BOTTOM", self.name, "TOP", 0, 4)
		self:UpdateControlAnchors()
	end
	function cast:ApplyStyleAndAnchoring()
		self:ClearAllPoints()
		self.Icon:ClearAllPoints()
		self.Text:ClearAllPoints()
		self.BorderShield:ClearAllPoints()
		self.Icon:SetPoint("BOTTOMLEFT", self:GetParent(), "BOTTOMLEFT", 0, 0)
		self:SetPoint("BOTTOM", self.Icon, "TOP", 0, 0)
		self:SetPoint("LEFT", self:GetParent(), "BOTTOMLEFT", 0, 0)
		self:SetPoint("RIGHT", self:GetParent(), "BOTTOMRIGHT", 0, 0)
		self:SetHeight(7.5)
		self.Text:SetPoint("LEFT", self.Icon, "RIGHT", 2, 0)
		self.BorderShield:SetPoint("RIGHT", self.Icon, "RIGHT", 0, 0)
	end
	uf:UpdateAnchors()
	if live then
		-- (A live plate: its places can't be read.)
		local function Lock(f)
			if type(f) ~= "table" or getmetatable(f) ~= Frame or f.restricted then return end
			f.restricted = true
			for _, v in pairs(f) do if type(v) == "table" and getmetatable(v) == Frame and v.parent == f then Lock(v) end end
		end
		Lock(uf)
		uf.CastBarsContainer.castBar.restricted = true
	end
	return uf
end

local plateCount = 0
local function MakePlate(live, x)
	local plate = New(UIParent)
	plate:SetSize(237.5, 85)
	plateCount = plateCount + 1
	plate:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x or 500, 400)
	plate.UnitFrame = BuildUnitFrame(plate, live)
	plate.UnitFrame.unit = "nameplate" .. plateCount
	return plate
end

-- The addon's world, enough for PlateLayout.lua --------------------------------
hooksecurefunc = function(obj, name, fn)
	local orig = obj[name]
	obj[name] = function(...)
		local a, b, c, d, e, f = orig(...)
		fn(...)
		return a, b, c, d, e, f
	end
end
local made = {} -- (the frames the file makes: its event frame among them)
CreateFrame = function(_, _, parent)
	local f = New(parent or UIParent)
	made[#made + 1] = f
	return f
end
C_Timer = { NewTicker = function() return {} end, After = function(_, fn) fn() end }
issecretvalue = function() return false end
_G.UIParent = UIParent
local live = {}
C_NamePlate = {
	GetNamePlates = function() return live end,
	GetNamePlateForUnit = function(unit) for _, p in ipairs(live) do if p.UnitFrame.unit == unit then return p end end end,
}
local chunk = assert(loadfile("Plates/PlateLayout.lua"))

-- A fresh load of the file per cell (its cached state from the start), with the
-- switches as the cell says.
local function Load(db)
	made = {}
	local ns = { db = db, isRetail = false, L = setmetatable({}, { __index = function(_, k) return k end }) }
	function ns.Module(_, fn) fn() end
	-- (Every switch over the Layout tab's: Enable Style, then Nameplate Style, then its own.)
	function ns.StyleOn(key)
		if db.styleGeneral == false then return false end
		if key == nil then return true end
		if key == "plateLayout" and db.plateStyle == false then return false end
		return db[key] and true or false
	end
	function ns.Reachable() return true end
	function ns.Guard(fn, ...) fn(...) end
	function ns.SetOnUpdate(frame, fn) frame:SetScript("OnUpdate", fn) end
	-- (Diagnostics.lua's feature loops: on while wanted() says so; wanted() asked once a
	-- second for every loop, ns.SyncFeatureLoops, and on each wake.)
	local loops = {}
	function ns.FeatureLoop(frame, fn, wanted)
		loops[#loops + 1] = { frame = frame, fn = fn, wanted = wanted }
		loops[frame] = loops[#loops]
		frame:SetScript("OnUpdate", wanted() and fn or nil)
	end
	function ns.WakeFeatureLoop(frame)
		local loop = loops[frame]
		if loop then frame:SetScript("OnUpdate", loop.wanted() and loop.fn or nil) end
	end
	function ns.Look()
		for _, loop in ipairs(loops) do ns.WakeFeatureLoop(loop.frame) end
	end
	function ns.Log() end
	function ns.PlateKindOf() return "EnemyNPCs" end
	function ns.MakeGamePlate(parent)
		local plate = New(parent)
		plate:SetSize(237.5, 85)
		plate.gamePlate = true
		return plate
	end
	function ns.GamePlateReady(plate)
		if not plate.gameCopy then
			plate.gameCopy = BuildUnitFrame(plate, false)
			plate.UnitFrame = plate.gameCopy
		end
		return true
	end
	function ns.SetGamePlateUnit() end
	function ns.SetGamePlateLevel(plate, shown)
		plate.gameCopy.PlayerLevelDiffFrame:SetShown(shown)
		plate.gameCopy:UpdateControlAnchors()
	end
	function ns.SetGamePlateStates() end
	chunk("Cinematic", ns)
	for _, f in ipairs(made) do
		if f.scripts.OnEvent then ns.events = f end
	end
	return ns
end

local SWITCH = { style = "styleGeneral", nameplateStyle = "plateStyle", layout = "plateLayout" }

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "platelayout-switch",
	fixed = { client = "forever" },
	dims = { { "switch", { "style", "nameplateStyle", "layout" } }, { "flip", { "turnOn", "turnOff" } },
		{ "saved", { "layout", "none" } } },
	cell = function(c)
		local db = { styleGeneral = true, plateStyle = true, plateLayout = true }
		if c.saved == "layout" then db.plateLayoutData = { all = { parts = { level = { x = 10 } } } } end
		local key = SWITCH[c.switch]
		if c.flip == "turnOn" then db[key] = false end
		local ns = Load(db)
		local plate = MakePlate(true, 500)
		local level = plate.UnitFrame.PlayerLevelDiffFrame
		local game = level:Rect()
		live[1] = plate
		local function Where()
			local left = level:Rect()
			if math.abs(left - game) < 0.01 then return "game" end
			if math.abs(left - game - 10) < 0.01 then return "moved" end
			return ("%+d"):format(math.floor(left - game + 0.5))
		end
		local function Flush() if ns.plateLayoutInner then ns.plateLayoutInner.Flush() end end
		ns.events.scripts.OnEvent(ns.events, "NAME_PLATE_UNIT_ADDED", plate.UnitFrame.unit)
		Flush()
		ns.Look() -- (a second goes by)
		local start = Where()
		db[key] = c.flip == "turnOn"
		ns.Look() -- (within the next second)
		Flush()
		local now = Where()
		-- (Another second, nothing changed: no new pass, no loop left on.)
		local version = ns.PlateLayoutReport():match("version (%d+)")
		ns.Look()
		local quiet = ns.PlateLayoutReport():match("version (%d+)") == version
			and ns.plateLayoutInner.Driver:GetScript("OnUpdate") == nil
		live[1] = nil
		return ("start=%s now=%s %s"):format(start, now, quiet and "quiet" or "busy")
	end,
	pins = {
		-- What's right (the audit, 2026-11-25): a saved layout is on the plates while every
		-- switch over it is on, the game's places while one is off, within a second of the
		-- flip, without a reload; with nothing saved, the game's always. Nothing more is
		-- done while nothing changes.
		{ "", "start=game now=game quiet" },
		{ "flip=turnOn saved=layout", "start=game now=moved quiet" },
		{ "flip=turnOff saved=layout", "start=moved now=game quiet" },
	},
})
