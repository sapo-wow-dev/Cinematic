-- Plate Layout (Plates/PlateLayout.lua) on a stand-in with real anchor
-- geometry (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/platelayout.lua < /dev/null
-- A small frame model (points, sizes, scales, rects; GetPoint refused on
-- "live" plates as the game refuses it) and a plate laid out the way
-- Forever's Blizzard_NamePlates lays one out (UpdateAnchors,
-- UpdateControlAnchors, the XML anchors). Checks, by where things end up:
-- nothing touched with no layout; a nudge moves only that part (and what
-- hangs on it); applying again or the game laying the plate out again never
-- doubles it; a part reset or the switch off puts back the game's exact
-- places; a plate laid out before we watched is seeded from the copy's
-- recipe; hanging on another part, the loop refused; sizing; Balanced
-- centering what's shown; parts counted while shown. PASS or FAIL per check.
-- luacheck: ignore 111 112 113 121 122 212 213 431 432
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end
local function Near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.01 end

-- The frame model ------------------------------------------------------------
local Frame = {}
Frame.__index = Frame
local H = { LEFT = "L", RIGHT = "R", CENTER = "C", TOP = "C", BOTTOM = "C", TOPLEFT = "L", TOPRIGHT = "R",
	BOTTOMLEFT = "L", BOTTOMRIGHT = "R" }
local V = { LEFT = "C", RIGHT = "C", CENTER = "C", TOP = "T", BOTTOM = "B", TOPLEFT = "T", TOPRIGHT = "T",
	BOTTOMLEFT = "B", BOTTOMRIGHT = "B" }
local function New(parent)
	local f = setmetatable({ points = {}, w = 0, h = 0, scale = 1, shown = true, parent = parent, scripts = {},
		kids = {} }, Frame)
	if parent then parent.kids[#parent.kids + 1] = f end
	return f
end
function Frame:GetChildren() return unpack(self.kids) end
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
local function Field(root, path)
	local value = root
	for name in path:gmatch("[^.]+") do value = value and value[name] end
	return value
end
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
local hooks = 0
hooksecurefunc = function(obj, name, fn)
	local orig = obj[name]
	hooks = hooks + 1
	obj[name] = function(...)
		local a, b, c, d, e, f = orig(...)
		fn(...)
		return a, b, c, d, e, f
	end
end
CreateFrame = function(_, _, parent) return New(parent or UIParent) end
C_Timer = { NewTicker = function() return {} end, After = function(_, fn) fn() end }
issecretvalue = function() return false end
_G.UIParent = UIParent
local live = {}
C_NamePlate = {
	GetNamePlates = function() return live end,
	GetNamePlateForUnit = function(unit) for _, p in ipairs(live) do if p.UnitFrame.unit == unit then return p end end end,
}
local ns = { db = { plateLayout = true }, isRetail = false, L = setmetatable({}, { __index = function(_, k) return k end }) }
function ns.Module(_, fn) fn() end
function ns.StyleOn(key) return ns.db[key] and true or false end
function ns.Reachable() return true end
function ns.Guard(fn, ...) fn(...) end
function ns.SetOnUpdate(frame, fn) frame:SetScript("OnUpdate", fn) end
-- (Diagnostics.lua's feature loops: on while wanted() says so, as the game's.)
local loops = {}
function ns.FeatureLoop(frame, fn, wanted)
	loops[frame] = { fn = fn, wanted = wanted }
	frame:SetScript("OnUpdate", wanted() and fn or nil)
end
function ns.WakeFeatureLoop(frame)
	local loop = loops[frame]
	if loop then frame:SetScript("OnUpdate", loop.wanted() and loop.fn or nil) end
end
function ns.Log(_, text) print("  log: " .. text) end
function ns.PlateKindOf(unit) return unit == "friend" and "FriendlyNPCs" or "EnemyNPCs" end
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

local chunk = assert(loadfile("Plates/PlateLayout.lua"))
chunk("Cinematic", ns)
local inner = ns.plateLayoutInner
local function Flush() inner.Flush() end
local function L(frame) return (frame:Rect()) end
local function R(frame) local _, r = frame:Rect() return r end
local function B(frame) local _, _, b = frame:Rect() return b end
local function CX(frame) local l, r = frame:Rect() return (l + r) / 2 end
local function Snapshot(uf)
	local shot = {}
	for _, part in ipairs(ns.PLATE_LAYOUT_PARTS) do
		local f = Field(uf, part.path)
		local l, r, b, t = f:Rect()
		shot[part.key] = { l, r, b, t }
	end
	return shot
end
local function Same(a, b)
	for key, rect in pairs(a) do
		for i = 1, 4 do
			if not Near(rect[i], b[key][i]) then return false, key .. " " .. i .. " " .. tostring(rect[i]) .. " vs " ..
				tostring(b[key][i]) end
		end
	end
	return true
end
local function Set(layout)
	ns.db.plateLayoutData = { all = layout }
	ns.PlateLayoutChanged()
	Flush()
end

-- 1. No layout: nothing watched -----------------------------------------------
local plateA = MakePlate(true, 300)
live[1] = plateA
local ufA = plateA.UnitFrame
local game = Snapshot(ufA)
local hooksBefore = hooks
ns.PlateLayoutChanged()
Flush()
Check("no layout: no hooks on the plate", hooks == hooksBefore, hooks - hooksBefore)
Check("no layout: the game's places", Same(game, Snapshot(ufA)))

-- 2. A nudge: the level box only (and crowd control, which hangs on it) --------
Set({ parts = { level = { x = 10, y = -3 } } })
local now = Snapshot(ufA)
Check("nudge: level box moved 10 right", Near(now.level[1], game.level[1] + 10), now.level[1] - game.level[1])
Check("nudge: level box moved 3 down", Near(now.level[3], game.level[3] - 3), now.level[3] - game.level[3])
Check("nudge: crowd control follows the level box", Near(now.crowd[1], game.crowd[1] + 10))
Check("nudge: the bar stays", Near(now.health[1], game.health[1]) and Near(now.health[2], game.health[2]))
Check("nudge: the name stays", Near(now.name[3], game.name[3]))
Check("seeded from the copy's recipe (live plate unreadable)", ns.PlateLayoutReport():find("recipe read") ~= nil,
	ns.PlateLayoutReport())

-- 3. Again, and the game laying the plate out again: never doubled -------------
ns.PlateLayoutChanged()
Flush()
Check("applied again: not doubled", Near(L(ufA.PlayerLevelDiffFrame), game.level[1] + 10))
ufA:UpdateAnchors()
Flush()
Check("game's UpdateAnchors: still +10", Near(L(ufA.PlayerLevelDiffFrame), game.level[1] + 10),
	L(ufA.PlayerLevelDiffFrame) - game.level[1])
Check("game's UpdateAnchors: crowd control still follows", Near(L(ufA.AurasFrame.CrowdControlListFrame), game.crowd[1] + 10))

-- 4. Name moved: the debuffs (on the name) follow; again after a re-layout -----
Set({ parts = { name = { y = 6 } } })
now = Snapshot(ufA)
Check("name up 6", Near(now.name[3], game.name[3] + 6))
Check("debuffs follow the name", Near(now.debuffs[3], game.debuffs[3] + 6))
Check("level box back where the game had it", Near(now.level[1], game.level[1]) and Near(now.level[3], game.level[3]))
ufA:UpdateAnchors()
Flush()
Check("re-layout: name still +6, debuffs too", Near(B(ufA.name), game.name[3] + 6)
	and Near(B(ufA.AurasFrame.DebuffListFrame), game.debuffs[3] + 6))

-- 5. Reset: exactly the game's ------------------------------------------------
Set({ parts = {} })
Check("reset: the game's places, every part", Same(game, Snapshot(ufA)))

-- 6. Hung on another part ------------------------------------------------------
Set({ parts = { level = { to = "marker", side = "left", gap = 4 } } })
Check("level hung left of the marker, gap 4", Near(R(ufA.PlayerLevelDiffFrame), L(ufA.RaidTargetFrame) - 4),
	tostring(R(ufA.PlayerLevelDiffFrame)) .. " vs " .. tostring(L(ufA.RaidTargetFrame) - 4))
Check("loop refused: the marker on the elite mark (which hangs on the marker)",
	ns.PlateLayoutWouldLoop(plateA, "marker", "elite") == true)
Set({ parts = { marker = { to = "elite", side = "right" } } })
Check("a looping hang leaves the part where the game puts it", Near(L(ufA.RaidTargetFrame), game.marker[1]))
Set({ parts = { castIcon = { to = "health", side = "inleft", gap = 3 } } })
Check("spell icon inside the bar's left", Near(L(ufA.CastBarsContainer.castBar.Icon), game.health[1] + 3))

-- (The cast bar laid out again on its own (its style, a cast): put right on
-- the next frame, through the dirty list.)
Set({ parts = { castText = { x = 5 } } })
local castText = ufA.CastBarsContainer.castBar.Text
local gameTextL = game.castText[1]
Check("spell name 5 right", Near(L(castText), gameTextL + 5))
ufA.CastBarsContainer.castBar:ApplyStyleAndAnchoring()
Check("cast bar laid out again: the game's place till the next frame", Near(L(castText), gameTextL))
Flush()
Check("next frame: 5 right again, not 10", Near(L(castText), gameTextL + 5), L(castText) - gameTextL)

-- (Past the range, as a shared or older layout could hold: held to it. Audit 2026-11-25.)
Set({ parts = { level = { x = 400 } } })
Check("a saved 400 right lands 250 right (the range)", Near(L(ufA.PlayerLevelDiffFrame), game.level[1] + 250),
	L(ufA.PlayerLevelDiffFrame) - game.level[1])
Set({ center = "custom", cx = -999, parts = {} })
Check("a custom shift past the range is held to it too", Near(L(ufA.HealthBarsContainer), game.health[1] - 250))

-- 7. Sized ---------------------------------------------------------------------
Set({ parts = { marker = { scale = 1.5 } } })
now = Snapshot(ufA)
Check("marker 1.5 times as big", Near(now.marker[2] - now.marker[1], (game.marker[2] - game.marker[1]) * 1.5),
	now.marker[2] - now.marker[1])
Check("sized from its anchor: its right edge stays on the bar", Near(now.marker[2], game.marker[2]))
Set({ parts = {} })
Check("size put back", Same(game, Snapshot(ufA)))

-- 8. Balanced: what's shown centered on the unit --------------------------------
local function UnitCX() return CX(ufA) end
local function GroupCX(keys)
	local l, r
	for _, key in ipairs(keys) do
		local f
		for _, part in ipairs(ns.PLATE_LAYOUT_PARTS) do if part.key == key then f = Field(ufA, part.path) end end
		local fl, fr = f:Rect()
		l, r = l and math.min(l, fl) or fl, r and math.max(r, fr) or fr
	end
	return (l + r) / 2
end
local ALL = {}
for _, part in ipairs(ns.PLATE_LAYOUT_PARTS) do ALL[#ALL + 1] = part.key end
-- (These checks count every part, as all did by default before 2026-11-25: the parts
-- that only sometimes show set to Always counts. The new default after them.)
local ALWAYS = { count = "always" }
Set({ center = "balanced", parts = { marker = ALWAYS, elite = ALWAYS, buffs = ALWAYS, crowd = ALWAYS } })
Check("balanced: the whole plate's middle on the unit", Near(GroupCX(ALL), UnitCX()), GroupCX(ALL) - UnitCX())
Set({ center = "balanced", parts = { level = { count = "never" }, crowd = { count = "never" }, marker = ALWAYS,
	elite = ALWAYS, buffs = ALWAYS } })
local rest = {}
for _, key in ipairs(ALL) do if key ~= "level" and key ~= "crowd" then rest[#rest + 1] = key end end
Check("balanced, level and crowd control not counted: the rest centered", Near(GroupCX(rest), UnitCX()),
	GroupCX(rest) - UnitCX())
Check("the parts keep their places to each other", Near(L(ufA.PlayerLevelDiffFrame) - R(ufA.HealthBarsContainer),
	game.level[1] - game.health[2]))
-- (Counted while shown: the level box hidden on this plate, so not counted.)
Set({ center = "balanced", parts = { level = { count = "shown" }, crowd = { count = "never" }, marker = ALWAYS,
	elite = ALWAYS, buffs = ALWAYS } })
ufA.PlayerLevelDiffFrame:Hide()
ufA.PlayerLevelDiffFrame.scripts.OnHide()
Flush()
Check("counted while shown, hidden: left out", Near(GroupCX(rest), UnitCX()), GroupCX(rest) - UnitCX())
ufA.PlayerLevelDiffFrame:Show()
ufA.PlayerLevelDiffFrame.scripts.OnShow()
Flush()
local withLevel = {}
for _, key in ipairs(rest) do withLevel[#withLevel + 1] = key end
withLevel[#withLevel + 1] = "level"
Check("counted while shown, shown: counted", Near(GroupCX(withLevel), UnitCX()), GroupCX(withLevel) - UnitCX())
-- (The default since 2026-11-25: the marker, elite mark, buffs and crowd control count
-- only while they're up; the game never draws crowd control or buffs on a friendly NPC's
-- plate, so they never count there.)
local STEADY = { "health", "name", "level", "debuffs", "cast", "castIcon", "castText", "castShield", "softTarget" }
ufA.RaidTargetFrame:Hide()
ufA.ClassificationFrame:Hide()
Set({ center = "balanced", parts = {} })
Check("the default: no marker, elite mark, buffs or crowd control up, the rest centered",
	Near(GroupCX(STEADY), UnitCX()), GroupCX(STEADY) - UnitCX())
local icon = New(ufA.AurasFrame.CrowdControlListFrame) -- (a root on it: the row up)
ns.PlateLayoutChanged()
Flush()
local withCrowd = {}
for _, key in ipairs(STEADY) do withCrowd[#withCrowd + 1] = key end
withCrowd[#withCrowd + 1] = "crowd"
Check("the default, crowd control up on a hostile mob: counted", Near(GroupCX(withCrowd), UnitCX()),
	GroupCX(withCrowd) - UnitCX())
ufA.unit = "friend"
ns.PlateLayoutChanged()
Flush()
Check("the same on a friendly NPC's plate: not counted (the game never draws it there)",
	Near(GroupCX(STEADY), UnitCX()), GroupCX(STEADY) - UnitCX())
ufA.unit = "nameplate1"
icon:Hide()
ufA.RaidTargetFrame:Show()
ufA.ClassificationFrame:Show()
Set({ center = "custom", cx = 7, cy = -2, parts = {} })
now = Snapshot(ufA)
Check("custom: everything 7 right, 2 down", Near(now.health[1], game.health[1] + 7) and Near(now.level[3], game.level[3] - 2)
	and Near(now.softTarget[1], game.softTarget[1] + 7))

-- 9. Kinds, the switch, a new plate ----------------------------------------------
ns.db.plateLayoutData = { all = { parts = { level = { x = 10 } } }, friendly = { own = true, parts = { level = { x = -30 } } } }
local plateB = MakePlate(true, 700)
plateB.UnitFrame.unit = "friend"
live[2] = plateB
local gameB = Snapshot(plateB.UnitFrame)
ns.PlateLayoutChanged()
Flush()
Check("hostile plate: All plates' layout", Near(L(ufA.PlayerLevelDiffFrame), game.level[1] + 10))
Check("friendly plate: its own", Near(L(plateB.UnitFrame.PlayerLevelDiffFrame), gameB.level[1] - 30))
ns.db.plateLayout = false
ns.PlateLayoutChanged()
Flush()
Check("switch off: plate A the game's", Same(game, Snapshot(ufA)))
Check("switch off: plate B the game's", Same(gameB, Snapshot(plateB.UnitFrame)))
-- (Off, the game laying plates out again wakes nothing of ours: no loop running. The
-- gating audit, 2026-11-25, saw it still running with every switch off.)
ufA:UpdateAnchors()
plateB.UnitFrame:UpdateAnchors()
ufA.CastBarsContainer.castBar:ApplyStyleAndAnchoring()
Check("switch off: the game's re-layouts leave no loop of ours running",
	inner.Driver:GetScript("OnUpdate") == nil and not inner.Waiting())
Check("switch off: still the game's places after its re-layouts", Same(game, Snapshot(ufA)))
ns.db.plateLayout = true
ns.PlateLayoutChanged()
Flush()
Check("switch on again: moved again", Near(L(ufA.PlayerLevelDiffFrame), game.level[1] + 10))

-- 10. The preview's copy: a layout of its own, kept through the game's passes ---
local preview = ns.MakeGamePlate(UIParent)
preview:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
ns.GamePlateReady(preview)
local gameP = Snapshot(preview.UnitFrame)
ns.PlateLayoutApply(preview, { parts = { marker = { x = -8 } } })
Check("preview: its own layout", Near(L(preview.UnitFrame.RaidTargetFrame), gameP.marker[1] - 8))
ns.SetGamePlateLevel(preview, true)
Flush()
Check("preview: kept after the game's control pass", Near(L(preview.UnitFrame.RaidTargetFrame), gameP.marker[1] - 8))
ns.PlateLayoutApply(preview, false)
Check("preview: put back", Same(gameP, Snapshot(preview.UnitFrame)))

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
