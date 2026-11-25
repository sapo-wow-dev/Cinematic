-- Plate Layout: where each part of a nameplate sits (Nameplate Style's Layout
-- tab, PlateLayoutPage.lua). Every part can be nudged, sized, hung on another
-- part, and the whole plate shifted so it stays balanced on its unit.
--
-- How: a plate's places can't be read (rules all.plate.position-unreadable,
-- forever.plate.getpoint-restricted), but they can be set (forever.plate.narrow-
-- width). So each part's game anchors are mirrored: hooks on its SetPoint and
-- ClearAllPoints record what the game (or Cinematic's cast style) sets, and
-- the parts the game anchored before we were watching are seeded from our
-- copy of the game's plate (PlateCopy.lua), laid out the same way and readable
-- (rule forever.plate.template-copy-laid-out). The layout then replays those
-- anchors with your offsets after every game layout pass (UpdateAnchors,
-- UpdateControlAnchors, the cast bar's ApplyStyleAndAnchoring) and on any
-- stray re-anchor (a dirty list flushed on the next frame). A part put back
-- to the game's gets the game's own anchors replayed as they were.
-- The game's chain is kept: a part hangs on what the game hangs it on (debuffs
-- on the name, the elite mark on the marker, crowd control on the level box),
-- so moving one moves what hangs on it, unless it's hung elsewhere (to).
-- Read in Forever's Blizzard_NamePlates (2026-11-25): Tools/plate-layout-plan.md.
-- Forever only for now (one-client-fix): retail keeps the game's layout.
-- Costs nothing until a layout changes something: no hooks before that.

local _, ns = ...
ns.Module("style", function() -- (the rest of this file: only with Style loaded, Modules.lua)

-- The parts: key, the field on the plate's unit frame, its name, a tooltip;
-- scale: can be sized; hang: can be hung on another part; frame: a frame
-- (shows and hides with OnShow/OnHide), not a texture or text.
local PARTS = {
	{ key = "health", path = "HealthBarsContainer", label = "Health bar", frame = true,
		tip = "The bar and what hangs on it: the name, level box, marker and debuffs move with it." },
	{ key = "name", path = "name", label = "Name", tip = "The unit's name. Debuffs hang on it." },
	{ key = "level", path = "PlayerLevelDiffFrame", label = "Level box", scale = true, hang = true, frame = true,
		tip = "The level box at the bar's end. Crowd control hangs on it." },
	{ key = "marker", path = "RaidTargetFrame", label = "Raid marker", scale = true, hang = true, frame = true,
		tip = "A raid marker left of the bar. The elite mark hangs on it." },
	{ key = "elite", path = "ClassificationFrame", label = "Elite mark", scale = true, hang = true, frame = true,
		tip = "The elite, rare or boss mark." },
	{ key = "debuffs", path = "AurasFrame.DebuffListFrame", label = "Debuffs", scale = true, hang = true, frame = true,
		tip = "Your debuffs over the name." },
	{ key = "buffs", path = "AurasFrame.BuffListFrame", label = "Buffs", scale = true, hang = true, frame = true,
		tip = "The unit's buffs, left of the elite mark." },
	{ key = "crowd", path = "AurasFrame.CrowdControlListFrame", label = "Crowd control", scale = true, hang = true,
		frame = true, tip = "Roots, stuns and the like, right of the level box." },
	{ key = "cast", path = "CastBarsContainer.castBar", label = "Cast bar", frame = true,
		tip = "The cast bar under the health bar." },
	{ key = "castIcon", path = "CastBarsContainer.castBar.Icon", label = "Spell icon", scale = true, hang = true,
		tip = "The cast's spell icon. In most plate styles the cast bar and spell name hang on it." },
	{ key = "castText", path = "CastBarsContainer.castBar.Text", label = "Spell name", hang = true,
		tip = "The name of the spell being cast." },
	{ key = "castShield", path = "CastBarsContainer.castBar.BorderShield", label = "Can't interrupt", scale = true,
		hang = true, tip = "The shield shown for a cast you can't interrupt." },
	{ key = "softTarget", path = "SoftTargetFrame", label = "Soft target icon", scale = true, hang = true, frame = true,
		tip = "The interact or quest icon over your soft target." },
}
ns.PLATE_LAYOUT_PARTS = PARTS
local PART_BY_KEY = {}
for _, part in ipairs(PARTS) do PART_BY_KEY[part.key] = part end
-- (The center shift moves the root of the plate's chain: everything hangs on
-- the cast bars' container but the soft target icon, which hangs on the plate.)
local ROOTS = { "CastBarsContainer", "SoftTargetFrame" }

-- Sides for a part hung on another: its point, the other's, and which way
-- Gap pushes it.
local SIDES = {
	right = { "LEFT", "RIGHT", 1, 0, "Right of" }, left = { "RIGHT", "LEFT", -1, 0, "Left of" },
	above = { "BOTTOM", "TOP", 0, 1, "Above" }, below = { "TOP", "BOTTOM", 0, -1, "Below" },
	inleft = { "LEFT", "LEFT", 1, 0, "Inside left" }, inright = { "RIGHT", "RIGHT", -1, 0, "Inside right" },
	center = { "CENTER", "CENTER", 0, 0, "On its center" },
}
ns.PLATE_LAYOUT_SIDES = { "right", "left", "above", "below", "inleft", "inright", "center" }
ns.PLATE_LAYOUT_SIDE_INFO = SIDES

-- The kinds with a layout of their own (Layout for), and which of the
-- Nameplates page's kinds (ns.PlateKindOf) go with each.
ns.PLATE_LAYOUT_KINDS = { "hostile", "neutral", "friendly", "player" }
local KIND_OF = {
	Enemies = "player", Friends = "player", FriendlyNPCs = "friendly", FriendlyMinions = "friendly",
	NeutralNPCs = "neutral", NeutralMinor = "neutral",
}
function ns.PlateLayoutKindOf(unit)
	local kind = unit and ns.PlateKindOf and ns.PlateKindOf(unit)
	return KIND_OF[kind] or "hostile"
end

-- The saved layouts: CinematicDB.plateLayoutData = { all = layout, hostile =
-- layout (own = true: used), ... }; a layout = { center = "bar" | "balanced" |
-- "custom", cx, cy (custom's shift), parts = { [key] = { x, y, scale, to,
-- side, gap, count = "shown" | "never" (nil: always) } } }.
function ns.PlateLayoutData(create)
	local db = ns.db
	if not db then return nil end
	if create and type(db.plateLayoutData) ~= "table" then db.plateLayoutData = {} end
	return type(db.plateLayoutData) == "table" and db.plateLayoutData or nil
end
-- One layout (key "all" or a kind), made if asked.
function ns.PlateLayoutGet(key, create)
	local data = ns.PlateLayoutData(create)
	if not data then return nil end
	local layout = data[key]
	if type(layout) ~= "table" then
		if not create then return nil end
		layout = { parts = {} }
		data[key] = layout
	end
	if type(layout.parts) ~= "table" then layout.parts = {} end
	return layout
end
-- The part's settings in a layout, made if asked.
function ns.PlateLayoutPart(layout, key, create)
	if not layout then return nil end
	if type(layout.parts) ~= "table" then
		if not create then return nil end
		layout.parts = {}
	end
	local part = layout.parts[key]
	if type(part) ~= "table" and create then
		part = {}
		layout.parts[key] = part
	end
	return type(part) == "table" and part or nil
end

local function Num(value, default)
	return type(value) == "number" and value == value and value or default
end
-- Whether a part's settings move it at all.
local function PartMoves(p)
	return p and (Num(p.x, 0) ~= 0 or Num(p.y, 0) ~= 0 or Num(p.scale, 1) ~= 1 or (p.to and SIDES[p.side or "right"]))
		and true or false
end
ns.PlateLayoutPartMoves = PartMoves
-- Whether a layout changes anything.
local function LayoutMoves(layout)
	if type(layout) ~= "table" then return false end
	if layout.center == "balanced" then return true end
	if layout.center == "custom" and (Num(layout.cx, 0) ~= 0 or Num(layout.cy, 0) ~= 0) then return true end
	for _, p in pairs(type(layout.parts) == "table" and layout.parts or {}) do
		if PartMoves(p) then return true end
	end
	return false
end
ns.PlateLayoutMoves = LayoutMoves

-- The layout a kind's plates take: its own when it has one, else All plates'.
function ns.PlateLayoutFor(kind)
	local data = ns.PlateLayoutData()
	if not data then return nil end
	local own = kind and data[kind]
	if type(own) == "table" and own.own then return own end
	return type(data.all) == "table" and data.all or nil
end

-- On: the page's switch (and every switch over it), Forever, and a layout
-- that changes something (asked again on ns.PlateLayoutChanged).
local active
local function SwitchOn()
	return not ns.isRetail and ns.StyleOn and ns.StyleOn("plateLayout") and true or false
end
local function Active()
	if active ~= nil then return active end
	active = false
	if not SwitchOn() then return false end
	local data = ns.PlateLayoutData()
	if not data then return false end
	if LayoutMoves(data.all) then active = true end
	for _, kind in ipairs(ns.PLATE_LAYOUT_KINDS) do
		local own = data[kind]
		if type(own) == "table" and own.own and LayoutMoves(own) then active = true end
	end
	return active
end
ns.PlateLayoutActive = Active

local function Field(root, path)
	local value = root
	for name in path:gmatch("[^.]+") do
		if type(value) ~= "table" then return nil end
		value = value[name]
	end
	return value
end

-- ---------------------------------------------------------------------------
-- The game's anchors, mirrored. track[frame] = { anchors = { { point, rel,
-- relPoint, x, y } ... }, scale (the game's), applied (what we put on, as a
-- key), plate }.
local track = setmetatable({}, { __mode = "k" })
local busy = false -- (our own SetPoint calls: not the game's)
local dirty, driver = {}, CreateFrame("Frame")
driver:Hide()

local function Readable(value)
	return not (issecretvalue and issecretvalue(value))
end

-- A SetPoint's arguments as { point, rel, relPoint, x, y } (rel nil: the parent).
local function Anchor(frame, point, a, b, c, d)
	if type(point) ~= "string" then return nil end
	local rel, relPoint, x, y
	if type(a) == "number" then
		rel, relPoint, x, y = nil, point, a, b
	elseif a == nil and b == nil then
		rel, relPoint, x, y = nil, point, 0, 0
	else
		rel, relPoint, x, y = a, b or point, c, d
		if type(rel) == "string" then rel = _G[rel] end
	end
	if rel == nil and frame.GetParent then rel = frame:GetParent() end
	return { point, rel, relPoint, Num(x, 0), Num(y, 0) }
end

local ApplyPlate -- (below)
local function Dirty(plate)
	if plate and not dirty[plate] then
		dirty[plate] = true
		driver:Show()
	end
end

-- Watches a part's frame: its anchors and scale as the game sets them.
local function Watch(frame, plate)
	local t = track[frame]
	if t then
		t.plate = plate
		return t
	end
	t = { anchors = nil, plate = plate }
	track[frame] = t
	hooksecurefunc(frame, "ClearAllPoints", function(self)
		if busy then return end
		local own = track[self]
		own.anchors, own.applied = {}, nil
		Dirty(own.plate)
	end)
	hooksecurefunc(frame, "SetPoint", function(self, point, ...)
		if busy then return end
		local own = track[self]
		local anchor = Anchor(self, point, ...)
		if not anchor then return end
		own.anchors = own.anchors or {}
		local replaced = false
		for i, each in ipairs(own.anchors) do
			if each[1] == point then own.anchors[i], replaced = anchor, true end
		end
		if not replaced then own.anchors[#own.anchors + 1] = anchor end
		own.applied = nil
		Dirty(own.plate)
	end)
	if frame.SetScale then
		hooksecurefunc(frame, "SetScale", function(self, scale)
			if busy then return end
			local own = track[self]
			own.scale, own.applied, own.appliedScale = Num(scale, 1), nil, 1 -- (the game's scale on now, not ours)
			Dirty(own.plate)
		end)
	end
	return t
end

-- ---------------------------------------------------------------------------
-- The recipe: each part's anchors on our copy of the game's plate (laid out
-- as the game lays out yours), as paths, to seed a live plate's parts the
-- game anchored before we watched them. Made once per plate style and size.
local KNOWN_PATHS = {
	"HealthBarsContainer", "HealthBarsContainer.healthBar", "HealthBarsContainer.healthBar.Text",
	"HealthBarsContainer.healthBar.LeftText", "HealthBarsContainer.healthBar.RightText",
	"HealthBarsContainer.healthBar.barTexture", "HealthBarsContainer.healthBar.bgTexture", "name",
	"CastBarsContainer", "CastBarsContainer.castBar", "CastBarsContainer.castBar.Icon",
	"CastBarsContainer.castBar.Text", "CastBarsContainer.castBar.BorderShield", "CastBarsContainer.castBar.Border",
	"RaidTargetFrame", "ClassificationFrame", "PlayerLevelDiffFrame", "LevelFrame", "AurasFrame",
	"AurasFrame.DebuffListFrame", "AurasFrame.BuffListFrame", "AurasFrame.CrowdControlListFrame", "SoftTargetFrame",
	"WidgetContainer",
}
local recipe, measurePlate
local function ReadAnchors(frame, pathOf)
	local okN, count = pcall(frame.GetNumPoints, frame)
	if not (okN and type(count) == "number" and Readable(count)) then return nil end
	local list = {}
	for i = 1, count do
		local ok, point, rel, relPoint, x, y = pcall(frame.GetPoint, frame, i)
		if not (ok and Readable(point) and Readable(rel) and Readable(x) and Readable(y)) then return nil end
		local relKey = rel
		if pathOf then
			relKey = pathOf[rel]
			if relKey == nil then return nil end
		end
		list[i] = { point, relKey, relPoint, Num(x, 0), Num(y, 0) }
	end
	return list
end
local function MeasurePlate()
	if measurePlate then return measurePlate.gameCopy and measurePlate or nil end
	if not ns.MakeGamePlate then return nil end
	local plate = ns.MakeGamePlate(UIParent)
	if not (plate and ns.GamePlateReady(plate)) then return nil end
	measurePlate = plate
	plate:SetPoint("CENTER", UIParent, "BOTTOMLEFT", -2000, -2000) -- (off the screen: measured, never seen)
	plate:SetAlpha(0)
	plate.measuring = true
	return plate
end
local function Recipe()
	if recipe then return recipe end
	local plate = MeasurePlate()
	if not plate then return nil end
	local copy = plate.gameCopy
	local pathOf = { [copy] = "", [plate] = "^" }
	for _, path in ipairs(KNOWN_PATHS) do
		local frame = Field(copy, path)
		if frame then pathOf[frame] = path end
	end
	local made = {}
	for _, path in ipairs(KNOWN_PATHS) do
		local frame = Field(copy, path)
		if frame and frame.GetNumPoints then
			made[path] = ReadAnchors(frame, pathOf)
			local okS, scale = pcall(function() return frame.GetScale and frame:GetScale() end)
			if made[path] then made[path].scale = okS and Num(scale, 1) or 1 end
		end
	end
	recipe = made
	return made
end
ns.PlateLayoutRecipe = Recipe

-- A watched frame's anchors, seeded when we have none yet: read off the frame
-- where it reads (our copies), else the recipe's.
local function Seed(frame, path, unitFrame, t)
	if t.anchors and #t.anchors > 0 then return true end
	local own = ReadAnchors(frame)
	if own and #own > 0 then
		t.anchors = own
		if t.scale == nil then
			local ok, scale = pcall(frame.GetScale, frame)
			t.scale = ok and Readable(scale) and Num(scale, 1) or 1
		end
		return true
	end
	local book = Recipe()
	local list = book and book[path]
	if not list then return false end
	local anchors = {}
	for i, each in ipairs(list) do
		local rel = each[2] == "" and unitFrame or each[2] == "^" and unitFrame:GetParent() or Field(unitFrame, each[2])
		if not rel then return false end
		anchors[i] = { each[1], rel, each[3], each[4], each[5] }
	end
	t.anchors = anchors
	if t.scale == nil then t.scale = list.scale or 1 end
	return true
end

-- ---------------------------------------------------------------------------
-- Balance: each part's left and right off the unit's middle, measured on the
-- copy with the layout on (center shift none), in the plate's units.
local extentsCache = setmetatable({}, { __mode = "k" })
local version = 0

local function Shown(frame)
	local ok, shown = pcall(frame.IsShown, frame)
	return ok and Readable(shown) and shown and true or false
end

-- The center shift for a layout: dx, dy (shown: [part key] = whether it's up
-- on that plate, for parts counted only while shown; nil: as measured).
local Extents -- (below: needs the apply)
function ns.PlateLayoutShift(layout, shown)
	if type(layout) ~= "table" then return 0, 0 end
	if layout.center == "custom" then return Num(layout.cx, 0), Num(layout.cy, 0) end
	if layout.center ~= "balanced" then return 0, 0 end
	local ext = Extents(layout)
	if not ext then return 0, 0 end
	local left, right
	for key, e in pairs(ext.parts) do
		local p = layout.parts and layout.parts[key]
		local count = p and p.count
		local counts = key == "health" or count == nil or count == "always"
			or (count == "shown" and (shown == nil or shown[key]))
		if counts then
			left = left and math.min(left, e[1]) or e[1]
			right = right and math.max(right, e[2]) or e[2]
		end
	end
	if not left then return 0, 0 end
	return -(left + right) / 2, 0
end

-- ---------------------------------------------------------------------------
-- Putting a layout on a plate (a real one, or a preview's stand-in).
local loggedFail = {}
local function Fail(what, err)
	local key = what .. tostring(err)
	if loggedFail[key] then return end
	loggedFail[key] = true
	if ns.Log then ns.Log("plates", "plate layout: " .. what .. ": " .. tostring(err)) end
end

-- Puts one frame where it goes: the game's anchors moved by dx, dy (or one
-- anchor of ours, onto another part), at the game's scale times scale.
local function Place(frame, t, dx, dy, scale, hang)
	local key = ("%.2f,%.2f,%.3f,%s"):format(dx, dy, scale, hang and (tostring(hang[2]) .. hang[1] .. hang[3]
		.. hang[4] .. "," .. hang[5]) or "")
	if t.applied == key then return end
	if not hang and not (t.anchors and #t.anchors > 0) then return end -- (nothing of the game's to move yet)
	local base = t.scale or 1
	local ok, err = pcall(function()
		busy = true
		if frame.SetScale and scale ~= (t.appliedScale or 1) then frame:SetScale(base * scale) end
		frame:ClearAllPoints()
		if hang then
			frame:SetPoint(hang[1], hang[2], hang[3], (hang[4] + dx) / scale, (hang[5] + dy) / scale)
		else
			-- (Sized: one anchor only, so a frame held by two keeps its own size
			-- and grows from that point.)
			for i, each in ipairs(t.anchors) do
				if i == 1 or scale == 1 then
					frame:SetPoint(each[1], each[2], each[3], each[4] / scale + dx / scale, each[5] / scale + dy / scale)
				end
			end
		end
	end)
	busy = false
	if not ok then
		Fail("placing a part", err)
		return
	end
	t.appliedScale = scale
	t.applied = key ~= "0.00,0.00,1.000," and key or nil
end

-- Back as the game had it.
local function PutBack(frame, t)
	if not t.applied and (t.appliedScale or 1) == 1 then return end
	local ok, err = pcall(function()
		busy = true
		if frame.SetScale and (t.appliedScale or 1) ~= 1 then frame:SetScale(t.scale or 1) end
		frame:ClearAllPoints()
		for _, each in ipairs(t.anchors or {}) do frame:SetPoint(each[1], each[2], each[3], each[4], each[5]) end
	end)
	busy = false
	if not ok then Fail("putting a part back", err) end
	t.applied, t.appliedScale = nil, 1
end

-- The frame a part is hung on: another part's, or the unit frame ("plate").
local function HangTarget(unitFrame, to)
	if to == "plate" then return unitFrame end
	local part = PART_BY_KEY[to]
	return part and Field(unitFrame, part.path) or nil
end
-- A frame's anchors as far as they can be known: watched, read off it (our
-- copies), or the recipe's (by its path on the unit frame).
local function AnchorsOf(frame, unitFrame)
	local t = track[frame]
	if t and t.anchors and #t.anchors > 0 then return t.anchors end
	local own = ReadAnchors(frame)
	if own then return own end
	local book = Recipe()
	if not (book and unitFrame) then return nil end
	for _, path in ipairs(KNOWN_PATHS) do
		if Field(unitFrame, path) == frame then
			local list = book[path]
			if not list then return nil end
			local anchors = {}
			for i, each in ipairs(list) do
				anchors[i] = { each[1], each[2] == "" and unitFrame or each[2] == "^" and unitFrame:GetParent()
					or Field(unitFrame, each[2]), each[3], each[4], each[5] }
			end
			return anchors
		end
	end
	return nil
end
-- Whether hanging frame on target would loop (target already hangs on frame,
-- through any chain).
local function Loops(frame, target, unitFrame, depth)
	if target == frame then return true end
	if (depth or 0) > 12 then return true end
	for _, each in ipairs(AnchorsOf(target, unitFrame) or {}) do
		if type(each[2]) == "table" and each[2] ~= target and Loops(frame, each[2], unitFrame, (depth or 0) + 1) then
			return true
		end
	end
	return false
end

local layoutHooked = setmetatable({}, { __mode = "k" })
-- (Once anything's been moved: a switch over the page turned off elsewhere
-- (Style, Nameplate Style) puts the plates back within a second.)
local switchWatch
local function WatchSwitch()
	if switchWatch or not (C_Timer and C_Timer.NewTicker) then return end
	local was = SwitchOn()
	switchWatch = C_Timer.NewTicker(1, function()
		local now = SwitchOn()
		if now ~= was then
			was = now
			if ns.PlateLayoutChanged then ns.PlateLayoutChanged() end
		end
	end)
end
local function HookLayout(plate, unitFrame)
	if layoutHooked[unitFrame] then return end
	layoutHooked[unitFrame] = true
	if not plate.gameCopy then WatchSwitch() end
	-- (After each of the game's layout passes: ours on at once, no frame of the game's.)
	for _, method in ipairs({ "UpdateAnchors", "UpdateControlAnchors" }) do
		if type(unitFrame[method]) == "function" then
			hooksecurefunc(unitFrame, method, function(self)
				local owner = track[self] and track[self].plate or plate
				if owner and ApplyPlate then ApplyPlate(owner) end
			end)
		end
	end
	local castBar = unitFrame.CastBarsContainer and unitFrame.CastBarsContainer.castBar
	if castBar and type(castBar.ApplyStyleAndAnchoring) == "function" then
		hooksecurefunc(castBar, "ApplyStyleAndAnchoring", function() Dirty(plate) end)
	end
	track[unitFrame] = track[unitFrame] or { plate = plate }
end

-- Parts counted only while shown: [key] = up on this plate, and a watch on
-- their showing (frames only), so the shift follows.
local showHooked = setmetatable({}, { __mode = "k" })
local function ShownParts(plate, unitFrame, layout)
	local shown
	for key, p in pairs(type(layout.parts) == "table" and layout.parts or {}) do
		local part = PART_BY_KEY[key]
		if part and type(p) == "table" and p.count == "shown" then
			local frame = Field(unitFrame, part.path)
			shown = shown or {}
			shown[key] = frame and Shown(frame) or false
			if frame and part.frame and not showHooked[frame] and frame.HookScript then
				showHooked[frame] = true
				frame:HookScript("OnShow", function() Dirty(plate) end)
				frame:HookScript("OnHide", function() Dirty(plate) end)
			end
		end
	end
	return shown
end

-- Puts layout (nil: the plate's own, by its unit's kind) on a plate whose
-- UnitFrame is the game's (or our copy's). rootOff: no center shift (the
-- balance measure).
local function ApplyPlateLayout(plate, layout, rootOff)
	local unitFrame = plate and plate.UnitFrame
	if not unitFrame then return end
	if not (plate.gameCopy or ns.Reachable(plate)) then return end
	if plate.gameCopy then
		-- (A copy keeps the layout its page (or the measure) last put on it, for
		-- the game's own layout passes run on it after.)
		if layout == nil then
			layout, rootOff = plate.layoutNow or false, plate.layoutRootOff
		else
			plate.layoutNow, plate.layoutRootOff = layout, rootOff
		end
	elseif layout == nil then
		layout = Active() and ns.PlateLayoutFor(ns.PlateLayoutKindOf(unitFrame.unit)) or false
	end
	if not layout and not layoutHooked[unitFrame] then return end -- (never touched: the game's as it is)
	HookLayout(plate, unitFrame)
	local parts = layout and type(layout.parts) == "table" and layout.parts or {}
	local rootX, rootY = 0, 0
	if layout and not rootOff then
		rootX, rootY = ns.PlateLayoutShift(layout, ShownParts(plate, unitFrame, layout))
	end
	-- (Roots first: the chain hangs on them.)
	for _, path in ipairs(ROOTS) do
		local frame = Field(unitFrame, path)
		if frame and frame.ClearAllPoints then
			local t = Watch(frame, plate)
			local p = path == "SoftTargetFrame" and parts.softTarget or nil
			local dx, dy = rootX + Num(p and p.x, 0), rootY + Num(p and p.y, 0)
			local scale = math.max(0.25, Num(p and p.scale, 1))
			if dx == 0 and dy == 0 and scale == 1 then
				PutBack(frame, t)
			elseif Seed(frame, path, unitFrame, t) then
				Place(frame, t, dx, dy, scale)
			end
		end
	end
	for _, part in ipairs(PARTS) do
		if part.key ~= "softTarget" then
			local frame = Field(unitFrame, part.path)
			if frame and frame.ClearAllPoints then
				local t = Watch(frame, plate)
				local p = parts[part.key]
				if not (layout and PartMoves(p)) then
					PutBack(frame, t)
				elseif Seed(frame, part.path, unitFrame, t) then
					local scale = part.scale and math.max(0.25, Num(p.scale, 1)) or 1
					local hang
					if part.hang and p.to then
						local side = SIDES[p.side or "right"] or SIDES.right
						local target = HangTarget(unitFrame, p.to)
						if target and not Loops(frame, target, unitFrame) then
							local gap = Num(p.gap, 0)
							hang = { side[1], target, side[2], side[3] * gap, side[4] * gap }
						end
					end
					Place(frame, t, Num(p.x, 0), Num(p.y, 0), scale, hang)
				end
			end
		end
	end
end
ApplyPlate = function(plate) ns.Guard(ApplyPlateLayout, plate) end
-- (For the page's preview and the tests: a layout on a stand-in plate.)
function ns.PlateLayoutApply(plate, layout, rootOff)
	local ok, err = pcall(ApplyPlateLayout, plate, layout or false, rootOff)
	if not ok then Fail("preview", err) end
end

-- What a part hangs on, as the game (or the layout) has it: a part's key,
-- "plate", or nil when it can't be told.
function ns.PlateLayoutHangsOn(plate, key)
	local unitFrame = plate and plate.UnitFrame
	local part = PART_BY_KEY[key]
	if not (unitFrame and part) then return nil end
	local frame = Field(unitFrame, part.path)
	local t = frame and track[frame]
	local anchors = t and t.anchors or (frame and ReadAnchors(frame))
	local rel = anchors and anchors[1] and anchors[1][2]
	if not rel then return nil end
	if rel == unitFrame or rel == unitFrame:GetParent() then return "plate" end
	for _, other in ipairs(PARTS) do
		if Field(unitFrame, other.path) == rel then return other.key end
	end
	-- (On a piece of another part: the health bar's own bar, the cast bar's container.)
	for _, other in ipairs(PARTS) do
		local owner = Field(unitFrame, other.path)
		local walk, steps = rel, 0
		while type(walk) == "table" and walk.GetParent and steps < 4 do
			if walk == owner then return other.key end
			walk, steps = walk:GetParent(), steps + 1
		end
	end
	return nil
end

-- Whether hanging part on target would loop (for the page's list).
function ns.PlateLayoutWouldLoop(plate, key, to)
	local unitFrame = plate and plate.UnitFrame
	local part = PART_BY_KEY[key]
	if not (unitFrame and part) or to == "plate" then return false end
	local frame, target = Field(unitFrame, part.path), HangTarget(unitFrame, to)
	if not (frame and target) then return true end
	return Loops(frame, target, unitFrame)
end

-- Each part's extents off the unit's middle on the measuring copy, with the
-- layout on and no center shift: { parts = { [key] = { left, right } } }.
-- (Cached per layout until it changes.)
Extents = function(layout)
	local cached = extentsCache[layout]
	if cached and cached.version == version then return cached end
	local plate = MeasurePlate()
	if not plate then return nil end
	Recipe() -- (read before the layout touches the copy)
	local copy = plate.gameCopy
	plate:Show()
	ns.SetGamePlateUnit(plate, "hostile", "Defias Bandit")
	ns.SetGamePlateLevel(plate, true)
	ns.SetGamePlateStates(plate, { casting = true, marker = true, debuffs = true, crowd = true, quest = true })
	ApplyPlateLayout(plate, layout, true)
	local scaleOf = copy:GetEffectiveScale()
	local okC, center = pcall(copy.GetCenter, copy)
	if not (okC and type(center) == "number") then
		plate:Hide()
		return nil
	end
	center = center * scaleOf
	local made = { version = version, parts = {} }
	for _, part in ipairs(PARTS) do
		local frame = Field(copy, part.path)
		-- (Only what the game draws with every state on: the elite mark hidden
		-- under a marker isn't counted. In-game run qb095, 2026-11-25: counted,
		-- it pushed a plain plate 23 right.)
		local okV, visible = pcall(function() return frame and frame.IsVisible and frame:IsVisible() end)
		if frame and frame.GetLeft and okV and visible then
			local ok, left, right, eff = pcall(function()
				return frame:GetLeft(), frame:GetRight(), frame:GetEffectiveScale()
			end)
			if ok and type(left) == "number" and type(right) == "number" and right > left then
				made.parts[part.key] = { (left * eff - center) / scaleOf, (right * eff - center) / scaleOf }
			end
		end
	end
	plate:Hide()
	extentsCache[layout] = made
	return made
end
ns.PlateLayoutExtents = function(layout) return layout and Extents(layout) or nil end

-- ---------------------------------------------------------------------------
-- Live plates: put on as they come, again after the game lays one out, and
-- all of them when the layout changes.
local function AllPlates(fn)
	if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
	local ok, plates = pcall(C_NamePlate.GetNamePlates)
	if not ok or type(plates) ~= "table" then return end
	for _, plate in ipairs(plates) do fn(plate) end
end

ns.SetOnUpdate(driver, function(self)
	local list = dirty
	dirty = {}
	self:Hide()
	for plate in pairs(list) do
		ApplyPlate(plate)
		-- (A preview's copy: its page draws its guides again.)
		if plate.onLayoutDirty then plate.onLayoutDirty() end
	end
end)

-- After any change on the page (or a profile loaded): every plate again.
function ns.PlateLayoutChanged()
	active = nil
	version = version + 1
	AllPlates(function(plate)
		if Active() or layoutHooked[plate.UnitFrame or false] then ApplyPlate(plate) end
	end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("CVAR_UPDATE")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event, name)
	if event == "NAME_PLATE_UNIT_ADDED" then
		if not Active() then return end
		local plate = C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(name)
		if plate then ApplyPlate(plate) end
	elseif event == "CVAR_UPDATE" then
		-- (The plate style or size: the game lays plates out anew; the recipe and
		-- the measures go with it.)
		if type(name) == "string" and (name:lower() == "nameplatestyle" or name:lower() == "nameplatesize") then
			recipe, measurePlate = nil, nil
			version = version + 1
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		active = nil
	end
end)

-- /cine debug and the tests: what the layout is doing on the real plates (our
-- copies, the page's preview and the balance measure, left out).
function ns.PlateLayoutReport()
	local watched, moved = 0, 0
	for _, t in pairs(track) do
		if t.plate and not t.plate.gameCopy and t.anchors then
			watched = watched + 1
			if t.applied or (t.appliedScale or 1) ~= 1 then moved = moved + 1 end
		end
	end
	local book = recipe
	local seeded = 0
	for _ in pairs(book or {}) do seeded = seeded + 1 end
	return ("layout %s, %d parts watched, %d moved, recipe %s (%d parts), version %d"):format(
		Active() and "on" or "off", watched, moved, book and "read" or "not read", seeded, version)
end
-- (For Tools/offline/platelayout.lua.)
ns.plateLayoutInner = { track = track, Anchor = Anchor, Place = Place, PutBack = PutBack, Seed = Seed,
	Watch = Watch, Flush = function() driver:GetScript("OnUpdate")(driver) end }
end) -- (ns.Module "style")
