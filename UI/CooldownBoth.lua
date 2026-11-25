-- Cinematic: a spell's cooldown drawn over its DoT (or buff) on the Cooldown
-- Manager's Essential and Utility icons: the row's Shows set to Both
-- (db.cooldownRowSettings[spell or bar].notBuff = "both"; the page's Look
-- grid, UI/CooldownGrid.lua). While the DoT is up the game keeps its own
-- swipe and countdown on the icon; this draws the spell's cooldown beside it,
-- in the look picked on Style > Cooldown Manager's Cooldown + DoT tab
-- (Style/CdmStyle.lua): ring, edge pips, row pips, bar under or corner number.
-- (The user, 2026-11-25: "we need a way for the player to see either the
-- cooldown, the dot, or both"; "more choices the better". Ledger
-- Tools/tests/cdm-both.md.)
--
-- How, with every time secret in a fight (rule
-- forever.duration.spell-cooldown-draws-in-fights): the game's duration
-- object, C_Spell.GetSpellCooldownDuration(id, true). The addon never reads
-- its numbers; the game does: pips and ring pieces take their alpha from
-- EvaluateRemainingPercent through a step curve each, the bar drains by
-- SetTimerDuration, the corner number is SetFormattedText of
-- GetRemainingDuration (its alpha from a curve too, so 0 shows nothing).
local ADDON_NAME, ns = ...

local ART = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Textures\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local LOOKS = { ring = true, edge = true, row = true, bar = true, corner = true }
local COUNTS = { [4] = true, [8] = true, [12] = true }

local DEFAULTS = ns.DEFAULTS
DEFAULTS.cdmBothLook = "ring" -- ring, edge, row, bar, corner
DEFAULTS.cdmBothPips = 8 -- 4, 8 or 12 (ring, edge and row)
DEFAULTS.cdmBothColor = "custom" -- class, custom, white
DEFAULTS.cdmBothR, DEFAULTS.cdmBothG, DEFAULTS.cdmBothB = 0.94, 0.62, 0.15
DEFAULTS.cdmBothTrack = 0.75 -- how dark the spent part shows (0: hidden)

-- The page's third folder tab (UI/CooldownRing.lua's ns.CDM_STYLE_TABS):
-- right-clicked off, the look reads its defaults.
local BOTH_TAB = 3
ns.CDM_STYLE_BOTH_TAB = BOTH_TAB
local function Look()
	if ns.StyleLook then return ns.StyleLook("cdmStyle", not ns.CdmStyleTabOn(BOTH_TAB)) end
	return DEFAULTS
end
ns.CooldownBothLook = Look

local function Secret(value) return issecretvalue and issecretvalue(value) or false end
local function Plain(value) return type(value) == "number" and not Secret(value) and value or nil end

local function LookOf(look)
	local kind = LOOKS[look.cdmBothLook] and look.cdmBothLook or "ring"
	local count = tonumber(look.cdmBothPips)
	if not COUNTS[count] then count = 8 end
	return kind, count
end

local function ColorOf(look)
	local mode = look.cdmBothColor
	if mode == "white" then return 0.95, 0.95, 0.95 end
	if mode == "class" then
		local _, class = UnitClass("player")
		local cc = _G.C_ClassColor
		local color = class and (cc and cc.GetClassColor and cc.GetClassColor(class) or RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
		if color then return color.r, color.g, color.b end
	end
	return tonumber(look.cdmBothR) or 0.94, tonumber(look.cdmBothG) or 0.62, tonumber(look.cdmBothB) or 0.15
end

-- Step curves: piece i of n lit while more than (i-1)/n is left (percent 0-1,
-- run 2), and "any left" for the corner number. Made once each.
local curves = {}
local function StepCurve(threshold)
	local key = ("%.4f"):format(threshold)
	if curves[key] ~= nil then return curves[key] or nil end
	curves[key] = false
	if not (C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType) then return nil end
	local ok, curve = pcall(C_CurveUtil.CreateCurve)
	if ok and curve then
		curve:SetType(Enum.LuaCurveType.Step)
		curve:AddPoint(0, 0)
		curve:AddPoint(threshold, 1)
		curve:AddPoint(1, 1)
		curves[key] = curve
	end
	return curves[key] or nil
end
local function PieceCurve(i, n) return StepCurve((i - 1) / n + 0.0001) end

-- What's drawn on each icon, made once per icon and look.
local draws = setmetatable({}, { __mode = "k" })

local function Piece(parent, layer)
	local t = parent:CreateTexture(nil, layer or "OVERLAY")
	t:SetTexture(WHITE)
	return t
end

local function Make(icon, kind, count)
	local d = draws[icon]
	if d and d.kind == kind and d.count == count then return d end
	if d then d.holder:Hide() end
	local art = type(icon.Icon) == "table" and type(icon.Icon.GetObjectType) == "function" and icon.Icon or icon
	local holder = CreateFrame("Frame", nil, icon)
	holder:SetAllPoints(art)
	holder:SetFrameLevel(icon:GetFrameLevel() + 8)
	d = { holder = holder, kind = kind, count = count, pieces = {}, tracks = {} }
	if kind == "ring" then
		-- (The drain ring's art, a piece per segment: CdmRing<n>_<i>.)
		local box = CreateFrame("Frame", nil, holder)
		box:SetPoint("CENTER")
		d.box = box
		for i = 1, count do
			local path = ("%sCdmRing%d_%d"):format(ART, count, i)
			local track = box:CreateTexture(nil, "BACKGROUND")
			track:SetAllPoints(box)
			track:SetTexture(path)
			local piece = box:CreateTexture(nil, "ARTWORK")
			piece:SetAllPoints(box)
			piece:SetTexture(path)
			d.tracks[i], d.pieces[i] = track, piece
		end
	elseif kind == "edge" or kind == "row" then
		for i = 1, count do
			d.tracks[i] = Piece(holder, "BACKGROUND")
			d.pieces[i] = Piece(holder, "ARTWORK")
			d.pieces[i]:SetAllPoints(d.tracks[i])
		end
	elseif kind == "bar" then
		local back = Piece(holder, "BACKGROUND")
		back:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 0, -2)
		back:SetPoint("TOPRIGHT", holder, "BOTTOMRIGHT", 0, -2)
		back:SetHeight(5)
		d.back = back
		local bar = CreateFrame("StatusBar", nil, holder)
		bar:SetAllPoints(back)
		bar:SetStatusBarTexture(WHITE)
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0)
		d.bar = bar
	else -- corner
		local top = CreateFrame("Frame", nil, holder)
		top:SetAllPoints(holder)
		top:SetFrameLevel(holder:GetFrameLevel() + 2)
		local text = top:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
		text:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -1, 2)
		d.text = text
	end
	draws[icon] = d
	return d
end

-- The icon's size, kept from when it read plain: secret in a fight (as the
-- drain ring's, cdmring run 4). Kept per icon, not per look, and read before
-- the DoT is up (Show): run 4's ring, edge and row were first made in a
-- fight, had no size, and drew nothing (the bar and number need none).
-- (The full run, cdmboth q686c: still none. The Cooldown Manager is hidden
-- out of a fight, and the walk took shown icons only, so the size was never
-- read before the fight. Now the walk takes hidden ones too (Update), and an
-- icon with none of its own takes the last size read: one bar's icons share
-- a size.)
-- (The full run again, qd5a0: the DoT's icon still had none of its own and
-- took 44, another bar's size, where run 5 read its own 50. So every icon's
-- size is read on each walk, Both or not (Show), and the fallback is its own
-- bar's: Essential and Utility icons differ.)
local iconWidth = setmetatable({}, { __mode = "k" })
local barWidth = {}
local function Width(icon, bar)
	local art = type(icon.Icon) == "table" and type(icon.Icon.GetWidth) == "function" and icon.Icon or icon
	local ok, width = pcall(art.GetWidth, art)
	width = ok and Plain(width)
	if width and width > 0 then
		iconWidth[icon] = width
		if bar then barWidth[bar] = width end
	end
	return iconWidth[icon] or (bar and barWidth[bar])
end
function ns.CooldownBothWidth(icon, bar) return iconWidth[icon], bar and barWidth[bar] end -- (the tests)

-- Places the pieces by the icon's size.
local iconBar = setmetatable({}, { __mode = "k" }) -- icon -> its bar (Show)
local function Place(d, icon)
	local width = Width(icon, iconBar[icon])
	if not width or width <= 0 or width == d.width then return end
	d.width = width
	local n = d.count
	if d.kind == "ring" then
		d.box:SetSize(width * 1.36, width * 1.36)
	elseif d.kind == "edge" then
		-- (n/4 a side, clockwise from the top left, just outside the icon.)
		local per, gap, thick = n / 4, 2, 3
		local side = width + 2 * (thick + 1)
		local len = (side - gap * (per + 1)) / per
		local o = -(thick + 1)
		for i, t in ipairs(d.tracks) do
			local s, p = math.floor((i - 1) / per), (i - 1) % per
			local along = gap + p * (len + gap)
			t:ClearAllPoints()
			if s == 0 then
				t:SetPoint("TOPLEFT", d.holder, "TOPLEFT", o + along, -o)
				t:SetSize(len, thick)
			elseif s == 1 then
				t:SetPoint("TOPRIGHT", d.holder, "TOPRIGHT", -o, -o - along)
				t:SetSize(thick, len)
			elseif s == 2 then
				t:SetPoint("BOTTOMRIGHT", d.holder, "BOTTOMRIGHT", -o - along, o)
				t:SetSize(len, thick)
			else
				t:SetPoint("BOTTOMLEFT", d.holder, "BOTTOMLEFT", o, o + along)
				t:SetSize(thick, len)
			end
		end
	elseif d.kind == "row" then
		local gap = 2
		local size = math.min(6, (width - gap * (n - 1)) / n)
		local w = (width - gap * (n - 1)) / n
		for i, t in ipairs(d.tracks) do
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", d.holder, "BOTTOMLEFT", (i - 1) * (w + gap), -3)
			t:SetSize(w, size)
		end
	end
end

-- The page's look: colors, the spent part, the number's size. (Set again
-- only when the look changed.)
local function Paint(d, look)
	local r, g, b = ColorOf(look)
	local track = tonumber(look.cdmBothTrack) or 0.75
	local key = ("%.3f,%.3f,%.3f,%.3f"):format(r, g, b, track)
	if d.painted == key then return end
	d.painted = key
	for i, piece in ipairs(d.pieces) do
		piece:SetVertexColor(r, g, b, 1)
		d.tracks[i]:SetVertexColor(0.1, 0.1, 0.12, track)
	end
	if d.back then d.back:SetVertexColor(0.1, 0.1, 0.12, track) end
	if d.bar then d.bar:SetStatusBarColor(r, g, b) end
	if d.text then d.text:SetTextColor(r, g, b) end
end

-- Draws the look on an icon: from the game's duration object (dur, in game),
-- or a plain share left 0-1 and seconds (left, seconds: the page's preview).
local function Draw(icon, look, dur, left, seconds)
	local kind, count = LookOf(look)
	local d = Make(icon, kind, count)
	Paint(d, look)
	Place(d, icon)
	if d.pieces[1] then
		for i, piece in ipairs(d.pieces) do
			if dur then
				local curve = PieceCurve(i, count)
				if curve then piece:SetAlpha(dur:EvaluateRemainingPercent(curve)) end
			else
				piece:SetAlpha((left or 0) > (i - 1) / count and 1 or 0)
			end
		end
	elseif d.bar then
		if dur then
			d.bar:SetTimerDuration(dur, 0, 1) -- (Immediate, RemainingTime)
		else
			d.bar:SetMinMaxValues(0, 1)
			d.bar:SetValue(left or 0)
		end
	elseif d.text then
		if dur then
			d.text:SetFormattedText("%.0f", dur:GetRemainingDuration())
			local curve = StepCurve(0.0001)
			if curve then d.text:SetAlpha(dur:EvaluateRemainingPercent(curve)) end
		else
			d.text:SetFormattedText("%.0f", seconds or 0)
			d.text:SetAlpha((left or 0) > 0 and 1 or 0)
		end
	end
	d.holder:Show()
	return d
end
ns.CooldownBothDraw = Draw -- (the Style page's preview, plain numbers)

local function Hide(icon)
	local d = draws[icon]
	if d then d.holder:Hide() end
end

local function On()
	return ns.db and ns.PageOn and ns.PageOn("handleCooldowns")
end

-- (In fights whether it's showing its buff may be secret: its aura's ID says,
-- as Frames.lua's ShowsBuff.)
local function ShowsAura(icon)
	local fromAura = icon.wasSetFromAura
	if Secret(fromAura) then return type(icon.auraInstanceID) == "number" end
	return fromAura == true
end

-- (Each icon's spell from when it read plain: secret in a fight.)
local iconSpell = setmetatable({}, { __mode = "k" })
local stats = { updates = 0, shown = 0, errors = 0 }
ns.CooldownBothStats = stats

local function Show(icon, id, bar)
	local spell = Plain(id)
	if spell then iconSpell[icon] = spell else spell = iconSpell[icon] end
	local group = ns.COOLDOWN_BAR_GROUPS and ns.COOLDOWN_BAR_GROUPS[bar]
	-- (The dev copy's /cine debug cdmboth: a DoT's icon given another spell's
	-- cooldown, for a character with no spell that has both.)
	local standIn = ns.cooldownBothStandIn and spell and ns.cooldownBothStandIn[spell]
	-- (Every icon's size kept while it reads plain, Both or not: out of a
	-- fight, the DoT not up yet; its bar's too, Width.)
	iconBar[icon] = bar
	Width(icon, bar)
	if not spell or not group or not (standIn or ns.CooldownBothOn(spell, group)) then return Hide(icon) end
	-- (The DoT down: the game shows the cooldown on the icon itself.)
	if not ShowsAura(icon) then return Hide(icon) end
	if ns.Reachable and not ns.Reachable(icon) then return Hide(icon) end
	local ok, dur = pcall(C_Spell.GetSpellCooldownDuration, standIn or spell, true)
	if not ok or not dur then return Hide(icon) end
	Draw(icon, Look(), dur)
	stats.shown = stats.shown + 1
end

local function Update()
	if not On() then
		for icon in pairs(draws) do Hide(icon) end
		return
	end
	stats.updates = stats.updates + 1
	ns.EachCooldownIcon(function(icon, id, bar)
		if not (ns.COOLDOWN_BAR_GROUPS and ns.COOLDOWN_BAR_GROUPS[bar]) then return end
		local ok, err = pcall(Show, icon, id, bar)
		if not ok then
			stats.errors = stats.errors + 1
			pcall(Hide, icon)
			if err ~= stats.lastError then
				stats.lastError = err
				if ns.Log then ns.Log("cooldownboth", "error: " .. tostring(err)) end
			end
		end
	end, true) -- (hidden icons too: their size read out of a fight, see Width)
end
ns.CooldownBothUpdate = Update

-- 10 a second while any row shows Both (about 0.2 ms a pass, cdmboth run 3).
local watcher = CreateFrame("Frame")
local since = 0
ns.SetOnUpdate(watcher, ns.Profiled("Cooldown + DoT", function(_, elapsed)
	since = since + elapsed
	if since < 0.1 then return end
	since = 0
	Update()
end))
watcher:Hide()

function ns.ApplyCooldownBoth()
	if not ns.db then return end
	local any = ns.CooldownRowAny and ns.CooldownRowAny("notBuff", function(v) return v == "both" end)
	if any then
		watcher:Show()
	else
		watcher:Hide()
		for icon in pairs(draws) do Hide(icon) end
	end
	Update()
end

-- (For the tests: an icon's drawn pieces.)
function ns.CooldownBothOf(icon) return draws[icon] end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_ENTERING_WORLD")
login:SetScript("OnEvent", function() ns.ApplyCooldownBoth() end)
