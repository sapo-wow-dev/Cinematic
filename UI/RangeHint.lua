-- Cinematic: Range Hint. A small soft mark (a chevron and the spell's name)
-- under your character while your target is out of reach of a spell you
-- pick, nothing while it's in reach. For players who hide the target frame
-- and action bars (Discord #requests "Range Indicator added in a smooth/subtle
-- way to the HUD", Forever, 2026-11-23; ledger Tools/features/requests.md).
--
-- Its icon: the Interface hub's Range Hint, after Swing Timer (the user,
-- 2026-11-25): Show in (the HUD's "rangehint" row, In combat to start with:
-- Frames.lua) then Settings (Options.lua's CreateRangeHintPanel). Which
-- spell, per class (rangeHintSpell<CLASS>): "auto", the longest-range attack
-- on your bars, or a spell id. Its spot: Edit Mode (rangeHintX/Y, shares of
-- the screen, its middle).
--
-- How: the game's spell range check (Frames.lua's ns.SpellReachesUnit, plain
-- or nil, never secret), asked ten times a second while you have a target.
-- Only "false" shows the mark: no answer (a friend for an attack, a secret
-- answer, no spell) shows nothing. Never yards: the game gives addons no real
-- distance to an enemy.
local ADDON_NAME, ns = ...
local L = ns.L
local ART = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Textures\\"

local DEFAULTS = ns.DEFAULTS
-- Off to start with, in every profile: nobody gets it till they turn it on
-- (the user, 2026-11-25). The icon's own switch (showInRange, its "Turn on
-- Range Hint" card) off; its page switch under it on, so that one switch
-- turns it on. (Frames.lua's SHOW_IN_SWITCHES loop gave showInRange true,
-- loaded first.) Nothing of it runs while it's off: ns.RangeHintOn.
DEFAULTS.showInRange = false
DEFAULTS.handleRangeHint = true
function ns.RangeHintOn() return ns.Setting("handleRangeHint") and true or false end
-- (0.19 up: the highest spot clear of the personal resource bars and the
-- swing timer under them, measured by /cine debug rangehint, run q85c2
-- 2026-11-25. 0.3 sat on the bars, the spell's name hidden (qeb71); 0.25 on
-- the swing timer, faded till you attack (qc733).)
DEFAULTS.rangeHintX, DEFAULTS.rangeHintY = 0.5, 0.19
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE",
	"WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER" }
for _, class in ipairs(CLASSES) do
	DEFAULTS["rangeHintSpell" .. class] = "auto"
end

local CHECK_EVERY = 0.1 -- seconds between range checks

-- ---------------------------------------------------------------------------
-- The look (Style hub > Range Hint Style, Style/RangeHintStyle.lua; its page
-- switch rangeHintStyle, its folder tabs each a container). Defaults here, so
-- the mark draws with Style left out: the first look, a soft orange chevron
-- with the spell's name under it, fading in and out in 0.35 s.
-- (Tools/range-hint-style-plan.md, built 2026-11-25.)
-- ---------------------------------------------------------------------------
DEFAULTS.rangeHintStyle = true
-- Mark (tab 1)
DEFAULTS.rangeHintShape = "chevron" -- chevron, double, dot, ring, bracket, arrow, icon (the spell's), none
DEFAULTS.rangeHintScale = 1
DEFAULTS.rangeHintWeight = "normal" -- thin, normal, bold (line shapes)
DEFAULTS.rangeHintColorBy = "custom" -- custom, theme, class, school
DEFAULTS.rangeHintR, DEFAULTS.rangeHintG, DEFAULTS.rangeHintB = 0.94, 0.54, 0.31
DEFAULTS.rangeHintAlpha = 1 -- its opacity once faded in
DEFAULTS.rangeHintGlow = 0 -- a soft halo behind it, 0 (none) to 1
DEFAULTS.rangeHintIconTint = true -- the spell's icon grey, in the mark's color
DEFAULTS.rangeHintIconRound = false
-- Text (tab 2)
DEFAULTS.rangeHintText = "spell" -- spell, words ("Out of range"), farclose (Too far / Too close), spellrange, none
DEFAULTS.rangeHintSide = "below" -- below, above, left, right
DEFAULTS.rangeHintGap = 0
DEFAULTS.rangeHintFont = "game" -- the game's, "general" (General's), or a font of the Style pages'
DEFAULTS.rangeHintTextSize = 1
DEFAULTS.rangeHintTextColor = "custom" -- custom, mark (the mark's color), white
DEFAULTS.rangeHintTextR, DEFAULTS.rangeHintTextG, DEFAULTS.rangeHintTextB = 0.95, 0.72, 0.56
DEFAULTS.rangeHintOutline = 0 -- 0 none, 1 thin, 2 thick
DEFAULTS.rangeHintShadow = "on" -- on, none
DEFAULTS.rangeHintCase = "asis" -- asis, upper, lower
-- Background (tab 3)
DEFAULTS.rangeHintBack = "none" -- none, pill (a soft dark pill), panel (the theme's panel color)
DEFAULTS.rangeHintBackAlpha = 0.5
DEFAULTS.rangeHintPad = 6
DEFAULTS.rangeHintBorder = "none" -- none, thin (a dark line), mark (a line in the mark's color)
-- Motion (tab 4)
DEFAULTS.rangeHintFadeIn, DEFAULTS.rangeHintFadeOut = 0.35, 0.35 -- seconds
DEFAULTS.rangeHintDelay = 0 -- seconds out of range before it shows
DEFAULTS.rangeHintEnter = "fade" -- fade, rise, grow
DEFAULTS.rangeHintPulse = "off" -- off, start (its first 3 s), always
DEFAULTS.rangeHintHideAfter = 0 -- seconds out of range before it goes again; 0: never
-- (A Sound tab, a soft cue as it came up: built and removed 2026-11-25, the user.)

-- The page's folder tabs (the Style Studio editor's parts, each with an
-- Enable), each a container: switched off, what's on it is OFF, not its
-- default (the user, 2026-11-25: "I have text disabled and I still see
-- text"): Mark off, no shape; Text off, no words; Background off, nothing
-- behind; Motion off, no motion (up and gone at once). Its other settings
-- read their defaults. The page switched off: the first look, as every
-- Style page. Its saved switches: "tabOn:<id>:<n>" (as CdmStyle's).
ns.RANGE_STYLE_TABS = "Range Hint Style/look"
local TAB_OF = {}
for tab, keys in ipairs({
	{ "rangeHintShape", "rangeHintScale", "rangeHintWeight", "rangeHintColorBy", "rangeHintR", "rangeHintG",
		"rangeHintB", "rangeHintAlpha", "rangeHintGlow", "rangeHintIconTint", "rangeHintIconRound" },
	{ "rangeHintText", "rangeHintSide", "rangeHintGap", "rangeHintFont", "rangeHintTextSize", "rangeHintTextColor",
		"rangeHintTextR", "rangeHintTextG", "rangeHintTextB", "rangeHintOutline", "rangeHintShadow", "rangeHintCase" },
	{ "rangeHintBack", "rangeHintBackAlpha", "rangeHintPad", "rangeHintBorder" },
	{ "rangeHintFadeIn", "rangeHintFadeOut", "rangeHintDelay", "rangeHintEnter", "rangeHintPulse",
		"rangeHintHideAfter" },
}) do
	for _, key in ipairs(keys) do TAB_OF[key] = tab end
end
ns.RANGE_STYLE_TAB_OF = TAB_OF
function ns.RangeStyleTabOn(n)
	local db = ns.db
	return not (db and db[("tabOn:%s:%d"):format(ns.RANGE_STYLE_TABS, n)] == false)
end
-- A part switched off: these instead of the defaults.
local OFF_VALUE = {
	rangeHintShape = "none", rangeHintText = "none", rangeHintBack = "none", rangeHintBorder = "none",
	rangeHintFadeIn = 0, rangeHintFadeOut = 0, rangeHintDelay = 0, rangeHintEnter = "fade",
	rangeHintPulse = "off", rangeHintHideAfter = 0,
}
-- The look now: each setting as the page says (its own while the page and
-- its part are on; its part off, OFF_VALUE or its default); the defaults
-- with Style left out or the page off.
local look = setmetatable({}, { __index = function(_, key)
	if not ns.StyleLook then return DEFAULTS[key] end
	local tab = TAB_OF[key]
	local partOff = tab and not ns.RangeStyleTabOn(tab)
	if partOff and OFF_VALUE[key] ~= nil and ns.StyleOn("rangeHintStyle") then return OFF_VALUE[key] end
	local value = ns.StyleLook("rangeHintStyle", partOff)[key]
	if value == nil then return DEFAULTS[key] end -- (never nil: a setting not saved yet)
	return value
end })
ns.RangeHintLook = look

-- Spell schools: the game gives no spell's school (C_Spell.GetSpellInfo has
-- none; GetSchoolString only names a mask), so the ranged attacks' here, by
-- spell id. A spell not listed takes the custom color (Color by: School).
-- Colors: the combat log's school colors.
local SCHOOL_COLORS = {
	physical = { 1, 1, 0 }, holy = { 1, 0.9, 0.5 }, fire = { 1, 0.5, 0 }, nature = { 0.3, 1, 0.3 },
	frost = { 0.5, 1, 1 }, shadow = { 0.5, 0.5, 1 }, arcane = { 1, 0.5, 1 },
}
local SPELL_SCHOOL = {
	-- Mage
	[116] = "frost", [133] = "fire", [2136] = "fire", [5143] = "arcane", [30451] = "arcane", [2948] = "fire",
	[11366] = "fire", [30455] = "frost", [44614] = "fire", [44425] = "arcane", [44457] = "fire", [118] = "arcane",
	[2139] = "arcane", [11113] = "fire",
	-- Warlock
	[686] = "shadow", [348] = "fire", [172] = "shadow", [980] = "shadow", [702] = "shadow", [689] = "shadow",
	[1120] = "shadow", [5782] = "shadow", [5676] = "fire", [29722] = "fire", [6353] = "fire", [30108] = "shadow",
	[48181] = "shadow", [50796] = "fire", [17962] = "fire", [17877] = "shadow", [1490] = "shadow", [603] = "shadow",
	[6789] = "shadow", [27243] = "shadow", [1714] = "shadow", [18223] = "shadow",
	-- Priest
	[585] = "holy", [589] = "shadow", [8092] = "shadow", [15407] = "shadow", [14914] = "holy", [34914] = "shadow",
	[2944] = "shadow", [32379] = "shadow", [73510] = "shadow", [8122] = "shadow",
	-- Shaman
	[403] = "nature", [421] = "nature", [8042] = "nature", [8050] = "fire", [8056] = "frost", [51505] = "fire",
	[370] = "nature", [57994] = "nature",
	-- Druid
	[5176] = "nature", [8921] = "arcane", [2912] = "arcane", [5570] = "nature", [339] = "nature", [770] = "nature",
	[78674] = "arcane", [93402] = "nature", [33786] = "nature",
	-- Hunter
	[75] = "physical", [3044] = "arcane", [56641] = "physical", [1978] = "nature", [5116] = "physical",
	[19434] = "physical", [2643] = "physical", [53351] = "physical", [53301] = "fire", [53209] = "nature",
	[77767] = "nature", [19503] = "physical", [20736] = "physical", [2973] = "physical",
	-- Paladin
	[20271] = "holy", [879] = "holy", [24275] = "holy", [31935] = "holy", [20473] = "holy", [62124] = "holy",
	[853] = "holy",
	-- Warrior and rogue
	[2764] = "physical", [57755] = "physical", [100] = "physical", [3018] = "physical", [26679] = "physical",
	-- Death knight
	[47541] = "shadow", [45477] = "frost", [49576] = "physical", [77575] = "shadow", [49184] = "frost",
}
ns.RANGE_SPELL_SCHOOL = SPELL_SCHOOL

local function Plain(value)
	return not (issecretvalue and issecretvalue(value))
end

local function SpellKey()
	local _, class = UnitClass("player")
	return "rangeHintSpell" .. (class or "WARRIOR")
end

-- ---------------------------------------------------------------------------
-- The spells: every attack on your bars with a range, the longest first.
-- ---------------------------------------------------------------------------
local barSpells, barYards, scanned = {}, {}, false

local function SpellInfo(id)
	if C_Spell and C_Spell.GetSpellInfo then
		local ok, info = pcall(C_Spell.GetSpellInfo, id)
		if ok and type(info) == "table" then return info.name, info.maxRange, info.minRange end
		return nil
	end
	if GetSpellInfo then
		local name, _, _, _, minRange, maxRange = GetSpellInfo(id)
		return name, maxRange, minRange
	end
end

local function IsHarmful(id)
	local test = C_Spell and C_Spell.IsSpellHarmful or IsHarmfulSpell
	if not test then return false end
	local ok, is = pcall(test, id)
	return ok and is == true
end

local function Scan()
	wipe(barSpells)
	wipe(barYards)
	scanned = true
	if not GetActionInfo then return end
	for slot = 1, 180 do
		local ok, kind, id = pcall(GetActionInfo, slot)
		if ok and kind == "spell" and type(id) == "number" and Plain(id) and not barYards[id] then
			local _, maxRange, minRange = SpellInfo(id)
			-- (Classic Era gives Auto Shot's the wrong way round: the larger is the range.)
			if type(minRange) == "number" and Plain(minRange) and type(maxRange) == "number" and Plain(maxRange)
				and minRange > maxRange then
				maxRange = minRange
			end
			if type(maxRange) == "number" and Plain(maxRange) and maxRange > 0 and IsHarmful(id) then
				barYards[id] = maxRange
				barSpells[#barSpells + 1] = id
			end
		end
	end
	table.sort(barSpells, function(a, b)
		if barYards[a] ~= barYards[b] then return barYards[a] > barYards[b] end
		return a < b
	end)
end

-- The spell it asks now: the picked one, or the longest attack on your bars.
local function ChosenSpell()
	local db = ns.GetDB()
	local picked = db and db[SpellKey()]
	if type(picked) == "number" then return picked end
	if not scanned then Scan() end
	return barSpells[1]
end

local function SpellName(id)
	if not id then return nil end
	if C_Spell and C_Spell.GetSpellName then
		local ok, name = pcall(C_Spell.GetSpellName, id)
		if ok and type(name) == "string" then return name end
	end
	return (SpellInfo(id))
end

-- The Settings tab's Spell dropdown: Auto, then each attack on your bars,
-- the one picked kept in the list even off your bars now.
function ns.RangeHintChoices()
	Scan()
	local auto = barSpells[1]
	local list = { { value = "auto", text = auto and L["Auto (%s)"]:format(SpellName(auto) or "?")
		or L["Auto (no attack spell on your bars)"] } }
	local seen = {}
	for _, id in ipairs(barSpells) do
		seen[id] = true
		list[#list + 1] = { value = id, text = ("%s (%d yd)"):format(SpellName(id) or tostring(id), barYards[id]) }
	end
	local db = ns.GetDB()
	local picked = db and db[SpellKey()]
	if type(picked) == "number" and not seen[picked] then
		list[#list + 1] = { value = picked, text = SpellName(picked) or tostring(picked) }
	end
	return list
end
ns.RangeHintSpellKey = SpellKey

-- ---------------------------------------------------------------------------
-- The mark. CinematicRangeHint is the HUD row's frame (CineMode fades it as
-- its Show in says); the mark inside it fades by range.
-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------
-- Drawing, for the live mark and the Style page's preview alike (so they
-- can't drift): parts made once on a holder, then laid out from the look.
-- ---------------------------------------------------------------------------
local BASE = 24 -- the mark's size at 100%, pixels
local GLOW_FIT = 0.6 -- the shape's share of its glow texture (Media/make_range_marks.py)
local ROUND_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local WHITE = "Interface\\Buttons\\WHITE8X8"
-- Fonts in a language with letters of its own keep the game's (ours are Latin only).
local ROMAN = not ({ ruRU = true, koKR = true, zhCN = true, zhTW = true })[GetLocale and GetLocale() or ""]

function ns.RangeHintMakeParts(holder)
	local p = { holder = holder }
	p.back = {}
	for i = 1, 3 do p.back[i] = holder:CreateTexture(nil, "BACKGROUND") end
	p.edges = {}
	for i = 1, 4 do p.edges[i] = holder:CreateTexture(nil, "BORDER") end
	p.glow = holder:CreateTexture(nil, "BORDER", nil, 1)
	p.shape = holder:CreateTexture(nil, "ARTWORK")
	p.text = holder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	p.baseFont = { p.text:GetFont() }
	return p
end

-- The mark's color by the look: custom, the theme's accent, your class's,
-- or the spell's school (custom for a spell not listed).
local function MarkColor(spell)
	local by = look.rangeHintColorBy
	if by == "theme" and ns.ThemeAccent then
		local c = ns.ThemeAccent()
		if type(c) == "table" and c[1] then return c[1], c[2], c[3] end
	elseif by == "class" then
		local _, class = UnitClass("player")
		local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
		if c then return c.r, c.g, c.b end
	elseif by == "school" then
		local c = spell and SCHOOL_COLORS[SPELL_SCHOOL[spell]]
		if c then return c[1], c[2], c[3] end
	end
	return look.rangeHintR or 1, look.rangeHintG or 1, look.rangeHintB or 1
end
ns.RangeHintMarkColor = MarkColor

-- The words for a state: the spell's name, Out of range, Too far / Too
-- close, the spell and its reach, or none.
local function Words(spell, why, name)
	local kind = look.rangeHintText
	if kind == "none" then return nil end
	if kind == "words" then return L["Out of range"] end
	if kind == "farclose" then return why == "too close" and L["Too close"] or L["Too far"] end
	name = name or SpellName(spell) or L["Range hint"]
	if kind == "spellrange" and spell then
		local _, maxRange = SpellInfo(spell)
		if type(maxRange) == "number" and Plain(maxRange) and maxRange > 0 then
			return ("%s (%d yd)"):format(name, maxRange)
		end
	end
	return name
end

-- Lays the parts out: info = { spell, why, name (a sample's) }. Gives the
-- size it takes.
function ns.RangeHintDraw(p, info)
	info = info or {}
	local spell = info.spell
	local r, g, b = MarkColor(spell)
	local shape = look.rangeHintShape
	local size = BASE * (tonumber(look.rangeHintScale) or 1)
	-- The shape.
	local hasShape = shape ~= "none"
	if shape == "icon" then
		local icon = spell and (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spell)
			or GetSpellTexture and GetSpellTexture(spell))
		p.shape:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
		p.shape:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		local tint = look.rangeHintIconTint
		p.shape:SetDesaturated(tint and true or false)
		if tint then p.shape:SetVertexColor(r, g, b) else p.shape:SetVertexColor(1, 1, 1) end
		if look.rangeHintIconRound then
			if not p.mask then
				p.mask = p.holder:CreateMaskTexture()
				p.mask:SetTexture(ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
				p.mask:SetAllPoints(p.shape)
			end
			if not p.masked then p.shape:AddMaskTexture(p.mask); p.masked = true end
		elseif p.masked then
			p.shape:RemoveMaskTexture(p.mask); p.masked = false
		end
	elseif hasShape then
		if p.masked then p.shape:RemoveMaskTexture(p.mask); p.masked = false end
		local weight = look.rangeHintWeight or "normal" -- (the dot: its size)
		p.shape:SetTexture(ART .. "RangeMark_" .. shape .. "_" .. weight)
		p.shape:SetTexCoord(0, 1, 0, 1)
		p.shape:SetDesaturated(false)
		p.shape:SetVertexColor(r, g, b)
	end
	p.shape:SetShown(hasShape)
	p.shape:SetSize(size, size)
	-- Its glow.
	local glow = tonumber(look.rangeHintGlow) or 0
	if hasShape and glow > 0 then
		p.glow:SetTexture(ART .. "RangeMark_" .. (shape == "icon" and "dot" or shape) .. "_glow")
		p.glow:SetVertexColor(r, g, b, math.min(1, glow))
		p.glow:SetSize(size / GLOW_FIT, size / GLOW_FIT)
		p.glow:Show()
	else
		p.glow:Hide()
	end
	-- The words.
	local words = Words(spell, info.why, info.name)
	local text = p.text
	if words then
		local base = p.baseFont
		local file = base[1]
		if ROMAN and ns.StyleFontFile then file = ns.StyleFontFile(look.rangeHintFont) or file end
		local outline = tonumber(look.rangeHintOutline) or 0
		local flags = outline == 1 and "OUTLINE" or outline == 2 and "THICKOUTLINE" or ""
		local textSize = math.min(120, (base[2] or 12) * (tonumber(look.rangeHintTextSize) or 1))
		if file then text:SetFont(file, textSize, flags) end
		if look.rangeHintShadow == "none" then
			text:SetShadowOffset(0, 0)
		else
			text:SetShadowOffset(1, -1)
			text:SetShadowColor(0, 0, 0, 1)
		end
		local case = look.rangeHintCase
		if case == "upper" then words = words:upper() elseif case == "lower" then words = words:lower() end
		text:SetText(words)
		local tc = look.rangeHintTextColor
		if tc == "mark" then text:SetTextColor(r, g, b)
		elseif tc == "white" then text:SetTextColor(1, 1, 1)
		else text:SetTextColor(look.rangeHintTextR or 1, look.rangeHintTextG or 1, look.rangeHintTextB or 1) end
		text:Show()
	else
		text:SetText("")
		text:Hide()
	end
	-- The layout: the shape and the words, the words on the side picked.
	local sw, sh = hasShape and size or 0, hasShape and size or 0
	local tw = words and math.ceil(text:GetStringWidth() or 0) or 0
	local th = words and math.ceil(text:GetStringHeight() or 0) or 0
	local gap = (hasShape and words) and (tonumber(look.rangeHintGap) or 0) or 0
	local side = look.rangeHintSide
	local w, h
	if side == "left" or side == "right" then
		w, h = sw + gap + tw, math.max(sh, th)
	else
		w, h = math.max(sw, tw), sh + gap + th
	end
	local back = look.rangeHintBack
	local pad = back ~= "none" and (tonumber(look.rangeHintPad) or 0) or 0
	local W, H = math.max(1, w + 2 * pad), math.max(1, h + 2 * pad)
	local holder = p.holder
	p.shape:ClearAllPoints()
	text:ClearAllPoints()
	if side == "above" then
		text:SetPoint("TOP", holder, "TOP", 0, -pad)
		p.shape:SetPoint("BOTTOM", holder, "BOTTOM", 0, pad)
	elseif side == "left" then
		text:SetPoint("LEFT", holder, "LEFT", pad, 0)
		p.shape:SetPoint("RIGHT", holder, "RIGHT", -pad, 0)
	elseif side == "right" then
		p.shape:SetPoint("LEFT", holder, "LEFT", pad, 0)
		text:SetPoint("RIGHT", holder, "RIGHT", -pad, 0)
	else
		p.shape:SetPoint("TOP", holder, "TOP", 0, -pad)
		text:SetPoint("BOTTOM", holder, "BOTTOM", 0, pad)
	end
	if not hasShape then
		text:ClearAllPoints()
		text:SetPoint("CENTER", holder, "CENTER")
	elseif not words then
		p.shape:ClearAllPoints()
		p.shape:SetPoint("CENTER", holder, "CENTER")
	end
	p.glow:ClearAllPoints()
	p.glow:SetPoint("CENTER", p.shape, "CENTER")
	-- Behind it: a soft pill (its round ends a cut of the pill art), or a flat panel.
	local alphaBack = tonumber(look.rangeHintBackAlpha) or 0.5
	for _, t in ipairs(p.back) do t:Hide(); t:ClearAllPoints() end
	if back == "pill" then
		local capW = math.min(H / 2, W / 2)
		local left, mid, right = p.back[1], p.back[2], p.back[3]
		for i, t in ipairs(p.back) do
			t:SetTexture(ART .. "RangeMark_pill")
			t:SetVertexColor(0, 0, 0, alphaBack)
			t:SetTexCoord(i == 1 and 0 or i == 2 and 0.49 or 0.51, i == 1 and 0.5 or i == 2 and 0.51 or 1, 0, 1)
			t:Show()
		end
		left:SetPoint("TOPLEFT", holder, "TOPLEFT")
		left:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT")
		left:SetWidth(capW)
		right:SetPoint("TOPRIGHT", holder, "TOPRIGHT")
		right:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT")
		right:SetWidth(capW)
		mid:SetPoint("TOPLEFT", left, "TOPRIGHT")
		mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
	elseif back == "panel" then
		local c = ns.ThemePanel and ns.ThemePanel()
		local t = p.back[1]
		t:SetTexture(WHITE)
		t:SetTexCoord(0, 1, 0, 1)
		if type(c) == "table" and c[1] then t:SetVertexColor(c[1], c[2], c[3], alphaBack)
		else t:SetVertexColor(0.05, 0.05, 0.06, alphaBack) end
		t:SetAllPoints(holder)
		t:Show()
	end
	-- Its border: a dark line, or one in the mark's color (round a panel or none;
	-- a pill keeps its round edge).
	local border = look.rangeHintBorder
	local lined = border ~= "none" and back ~= "pill"
	for i, t in ipairs(p.edges) do
		t:SetShown(lined)
		if lined then
			t:SetTexture(WHITE)
			if border == "mark" then t:SetVertexColor(r, g, b, 1) else t:SetVertexColor(0, 0, 0, 0.9) end
			t:ClearAllPoints()
			if i == 1 then t:SetPoint("TOPLEFT", holder); t:SetPoint("TOPRIGHT", holder); t:SetHeight(1)
			elseif i == 2 then t:SetPoint("BOTTOMLEFT", holder); t:SetPoint("BOTTOMRIGHT", holder); t:SetHeight(1)
			elseif i == 3 then t:SetPoint("TOPLEFT", holder); t:SetPoint("BOTTOMLEFT", holder); t:SetWidth(1)
			else t:SetPoint("TOPRIGHT", holder); t:SetPoint("BOTTOMRIGHT", holder); t:SetWidth(1) end
		end
	end
	holder:SetSize(W, H)
	return W, H
end

local frame = CreateFrame("Frame", "CinematicRangeHint", UIParent)
frame:SetSize(140, 40)
frame:SetFrameStrata("LOW")
local mark = CreateFrame("Frame", nil, frame)
mark:SetPoint("CENTER")
mark:SetSize(140, 40)
mark:SetAlpha(0)
local alpha = 0 -- (the mark's fade, 0-1, kept here: no reading it back each frame)
local parts = ns.RangeHintMakeParts(mark)
local label = parts.text

-- (Only when the spot or the screen changed: Shoulder Cam's Frames follow you
-- slides this frame, and a fresh SetPoint on every target change put it back
-- home for a frame each time, read as its new home.)
local placedAt = {}
local function Place()
	local db = ns.GetDB()
	local x = db and tonumber(db.rangeHintX) or DEFAULTS.rangeHintX
	local y = db and tonumber(db.rangeHintY) or DEFAULTS.rangeHintY
	local w, h = UIParent:GetWidth(), UIParent:GetHeight()
	if placedAt[1] == x and placedAt[2] == y and placedAt[3] == w and placedAt[4] == h then return end
	placedAt[1], placedAt[2], placedAt[3], placedAt[4] = x, y, w, h
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * w, y * h)
end

-- ---------------------------------------------------------------------------
-- When it shows.
-- ---------------------------------------------------------------------------
local state = { out = false, spell = nil, reaches = nil, why = "off" }
local wanted, editing = 0, false
local reachForTest -- (the kit test's stand-in for the game's answer: true, false or "nil")

-- Too close rather than too far: a spell with a least range (Auto Shot's
-- dead zone, Charge) and the target within the duel distance (~10 yd).
-- Forever only: retail blocks CheckInteractDistance in fights and blames us
-- (rule forever.checkinteractdistance.plain-in-combat; retail's in
-- secrets-combat.lua). nearForTest: the kit test's stand-in.
local nearForTest
local function TooClose(spell)
	if ns.isRetail then return false end
	local _, _, minRange = SpellInfo(spell)
	if not (type(minRange) == "number" and Plain(minRange) and minRange > 0) then return false end
	if nearForTest ~= nil then return nearForTest end
	local ok, near = pcall(CheckInteractDistance, "target", 3)
	return ok and Plain(near) and near == true or false
end

-- The Style page's Test: the live mark up for a few seconds, as if out of
-- range (works with no target, and with Range Hint off: to see the look).
local demoUntil = 0

-- Whether the mark should be up now, and why (for the log and the test).
local function Evaluate()
	if GetTime() < demoUntil then return true, "test", ChosenSpell(), false end
	if not ns.Setting("handleRangeHint") then return false, "off", nil, nil end
	if not UnitExists("target") then return false, "no target", nil, nil end
	local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost("target")
	if Plain(dead) and dead then return false, "target dead", nil, nil end
	local spell = ChosenSpell()
	if not spell then return false, "no spell", nil, nil end
	local reaches
	if reachForTest ~= nil then
		if reachForTest ~= "nil" then reaches = reachForTest end
	else
		reaches = ns.SpellReachesUnit and ns.SpellReachesUnit(spell, "target")
	end
	if reaches == false then
		return true, TooClose(spell) and "too close" or "out of range", spell, reaches
	end
	return false, reaches and "in range" or "no answer", spell, reaches
end

-- The live mark laid out again (a setting, the spell or the words changed).
-- The frame takes the mark's size: Edit Mode's box and the test's bar check.
local function Redraw()
	local w, h = ns.RangeHintDraw(parts, { spell = state.spell, why = state.why })
	frame:SetSize(w, h)
end

-- Motion (Motion tab), each frame while it watches: wait the Show after time
-- out of range, fade in or out at their speeds, rise or grow coming in,
-- pulse, and go again after Hide after.
local outSince, shownSince
local function Motion(elapsed)
	local now = GetTime()
	local target = 0
	if state.out then
		outSince = outSince or now
		local delay = editing and 0 or tonumber(look.rangeHintDelay) or 0
		local hideAfter = editing and 0 or tonumber(look.rangeHintHideAfter) or 0
		local held = now - outSince
		if held >= delay and (hideAfter <= 0 or held < delay + hideAfter) then target = 1 end
	else
		outSince = nil
	end
	if target > 0 and alpha == 0 and wanted == 0 then shownSince = now end
	wanted = target
	if alpha ~= wanted then
		local time = tonumber(wanted > alpha and look.rangeHintFadeIn or look.rangeHintFadeOut) or 0
		local step = time > 0 and elapsed / time or 1
		alpha = wanted > alpha and math.min(wanted, alpha + step) or math.max(wanted, alpha - step)
	end
	-- (Rise and grow only coming in: going, it just fades.)
	local enter = look.rangeHintEnter
	local coming = wanted == 1
	mark:ClearAllPoints()
	mark:SetPoint("CENTER", frame, "CENTER", 0, (enter == "rise" and coming) and -(1 - alpha) * 8 or 0)
	mark:SetScale((enter == "grow" and coming) and (0.8 + 0.2 * alpha) or 1)
	local pulse = 1
	local mode = look.rangeHintPulse
	if alpha == 1 and shownSince and (mode == "always" or (mode == "start" and now - shownSince < 3)) then
		pulse = 0.7 + 0.3 * (0.5 + 0.5 * math.cos((now - shownSince) * 2 * math.pi / 1.6))
	end
	mark:SetAlpha(alpha * (tonumber(look.rangeHintAlpha) or 1) * pulse)
end

-- (While it's up, laid out again every REDRAW_EVERY: a look changed from any
-- page (the Style Studio editor calls no refresh of ours) shows within it.
-- Run q946a: Text switched off with the mark up kept its words till the
-- next show.)
local REDRAW_EVERY = 0.25
local checkIn, redrawIn = 0, 0
local Wake -- (below: the watcher stops through it)
local function OnUpdate(_, elapsed)
	checkIn = checkIn - elapsed
	redrawIn = redrawIn - elapsed
	if checkIn <= 0 then
		checkIn = CHECK_EVERY
		-- (Turned off from anywhere, no refresh called: stop at once.)
		if not ns.RangeHintOn() then return Wake() end
		local out, why, spell, reaches = Evaluate()
		if editing then out, why = true, "edit mode" end
		local changed = out ~= state.out or spell ~= state.spell or why ~= state.why
		if changed then
			ns.Log("range", ("%s: %s (%s)"):format(out and "shown" or "hidden", why,
				tostring(SpellName(spell) or spell)))
		end
		state.out, state.why, state.spell, state.reaches = out, why, spell, reaches
		if out and (changed or redrawIn <= 0) then
			Redraw()
			redrawIn = REDRAW_EVERY
		end
	end
	Motion(elapsed)
	if alpha == 0 and wanted == 0 and not editing and not UnitExists("target") and GetTime() >= demoUntil then
		ns.SetOnUpdate(frame, nil) -- (nothing to watch till a new target)
	end
end

-- Starts watching (a new target, a setting changed, Edit Mode); it stops by
-- itself with no target and the mark gone.
function Wake()
	-- Off: nothing runs (no watching, no layout, no spell scan) and the mark's
	-- gone at once. (Edit Mode's box and the Test only come with it on.)
	if not ns.RangeHintOn() then
		ns.SetOnUpdate(frame, nil)
		editing, demoUntil, wanted, alpha = false, 0, 0, 0
		state.out, state.why = false, "off"
		mark:SetAlpha(0)
		return
	end
	Place()
	Redraw()
	checkIn = 0
	-- (Never frame:Show() here: CineMode's fade owns the frame itself.)
	ns.SetOnUpdate(frame, OnUpdate)
end
ns.RangeHintRefresh = Wake

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
events:RegisterEvent("SPELLS_CHANGED")
events:SetScript("OnEvent", function(_, event)
	if event == "ACTIONBAR_SLOT_CHANGED" or event == "SPELLS_CHANGED" then
		scanned = false -- (looked at again when next asked)
		return
	end
	if event == "PLAYER_ENTERING_WORLD" then scanned = false end
	Wake()
end)

-- Edit Mode: a box over the mark, dragged where you want it, right-click to
-- put it back (as Combat Vision's lower third, CombatVision.lua).
local editHooks
do
	local mover
	local function Snap()
		if not mover then return end
		-- (A size of its own, not SetAllPoints: put down at one point it kept
		-- none, GetCenter gave nothing and the drop wasn't saved, test qeb71.)
		mover:ClearAllPoints()
		mover:SetSize(frame:GetWidth(), frame:GetHeight())
		mover:SetPoint("CENTER", frame, "CENTER")
	end
	local function Mover()
		if mover then return mover end
		mover = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
		mover:SetClampedToScreen(true)
		mover:SetMovable(true)
		mover:RegisterForDrag("LeftButton")
		mover:RegisterForClicks("RightButtonUp")
		mover:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
			edgeSize = 1 })
		local text = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		text:SetPoint("BOTTOM", mover, "TOP", 0, 2)
		mover.label = text
		mover:SetScript("OnDragStart", mover.StartMoving)
		mover:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
			if self.SetUserPlaced then self:SetUserPlaced(false) end
			local x, y = self:GetCenter()
			local width, height = UIParent:GetWidth(), UIParent:GetHeight()
			if type(x) == "number" and type(y) == "number" and width > 0 and height > 0 then
				local scale = self:GetEffectiveScale() / UIParent:GetEffectiveScale()
				local db = ns.GetDB()
				db.rangeHintX = math.floor(x * scale / width * 1000 + 0.5) / 1000
				db.rangeHintY = math.floor(y * scale / height * 1000 + 0.5) / 1000
			end
			Place()
			Snap()
			self.draggedAt = GetTime() -- (the button-up ending a drag isn't a click)
		end)
		mover:SetScript("OnClick", function(self)
			if self.draggedAt and GetTime() - self.draggedAt < 0.2 then return end
			local db = ns.GetDB()
			db.rangeHintX, db.rangeHintY = DEFAULTS.rangeHintX, DEFAULTS.rangeHintY
			Place()
			Snap()
			if ns.RefreshOptions then pcall(ns.RefreshOptions) end
		end)
		ns.EditModeLook(mover, true)
		return mover
	end
	-- (Edit Mode on: the mark shown as a sample, its box over it; off: both
	-- back to the range. The kit test calls these itself: opening the real
	-- Edit Mode from addon code can taint it, rule
	-- forever.editmode.updatelayoutinfo-taints.)
	local function EditEnter()
		if not ns.Setting("handleRangeHint") then return end
		editing = true
		Wake()
		Mover()
		mover.label:SetText(ns.EditModeName(L["Range hint\nDrag to move, right-click to reset"]))
		Place()
		Snap()
		mover:Show()
	end
	local function EditExit()
		editing = false
		if mover then mover:Hide() end
		Wake()
	end
	ns.OnEditMode(EditEnter, EditExit)
	editHooks = { enter = EditEnter, exit = EditExit, mover = function() return mover end }
end

-- For the kit test (Dev/RangeHintTest.lua) and the offline check
-- (Tools/offline/rangehint.lua): what it shows now and why; Fake(answer)
-- stands in for the game's range answer (true, false, "nil"; nil = the game's).
ns.RangeHint = {
	frame = frame, mark = mark, label = label,
	State = function()
		return { out = state.out, why = state.why, spell = state.spell, reaches = state.reaches,
			alpha = alpha, name = label:GetText(), watching = frame:GetScript("OnUpdate") ~= nil }
	end,
	Evaluate = Evaluate,
	Fake = function(answer) reachForTest = answer; Wake() end,
	-- (Too close's stand-in: true, false; nil = the game's.)
	FakeNear = function(near) nearForTest = near; Wake() end,
	parts = parts, Redraw = Redraw,
	-- (The Style page's Test: seconds, or 0 to stop; Demoing: running now.)
	Demo = function(seconds)
		if (seconds or 0) > 0 and not ns.RangeHintOn() then return end -- (off: no Test either)
		demoUntil = (seconds or 0) > 0 and GetTime() + seconds or 0
		checkIn = 0
		ns.SetOnUpdate(frame, OnUpdate)
	end,
	Demoing = function() return GetTime() < demoUntil end,
	Spells = function() Scan(); return barSpells, barYards end,
	Chosen = ChosenSpell,
	-- (Edit Mode's enter and exit, and its box: Dev/RangeHintTest.lua's editmode step.)
	EditEnter = editHooks.enter, EditExit = editHooks.exit, Mover = editHooks.mover,
}
