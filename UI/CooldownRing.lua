-- Cinematic: the drain ring on the Cooldown Manager's tracked buff icons (its
-- page, Tracked Buffs tab, Look: the Ring column; db.cooldownRowSettings
-- [spell or "buffs"].ring). While the buff is on you, a ring (or bar, or the
-- icon itself) drains as your shields take damage, the amount left in the
-- middle. (Discord #requests, Forever, 2026-11-23; ledger
-- Tools/tests/cdm-shield-strength.md.)
--
-- How, with every amount secret (rule forever.absorbs.secret-out-of-combat):
-- the amount is UnitGetTotalAbsorbs("player"), all your shields together. An
-- addon can't compare or divide it (forever.curve.evaluate-refuses-secret),
-- but a StatusBar takes it (SetValue) and does the compare itself. The
-- shield's starting size is plain: the number in the cast rank's description
-- ("absorbing 44 damage"). A ring is cut into segments (Media/make_cdm_ring.py),
-- each its own StatusBar from (i-1)/n of the size to a hair above: full or
-- empty as the amount passes it. Colors go by place (green end drains first).
-- Not by spell: any tracked buff can have one (the user, 2026-11-23: "lets not
-- filter it by spells for now").
local ADDON_NAME, ns = ...

local ART = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Textures\\"
local STYLES = { pips = 8, smooth = 24 } -- ring styles: their segment counts
local PIPS_MOST = 20 -- one pip per charge up to this many (CdmRing2_* to CdmRing20_*)
local WHITE = "Interface\\Buttons\\WHITE8X8"

-- The look: Style > Cooldown Manager (Style/CdmStyle.lua; its switch cdmStyle).
-- Defaults here, so the ring works with Style left out (Modules.lua).
local DEFAULTS = ns.DEFAULTS
DEFAULTS.cdmStyle = true
DEFAULTS.cdmRingStyle = "pips" -- pips, smooth, liquid, bar
DEFAULTS.cdmRingScale = 1.36 -- the ring's size to the icon's
DEFAULTS.cdmRingTrack = 0.75 -- how dark the spent part shows (0: hidden)
DEFAULTS.cdmRingColor = "class" -- class, grad (Gradient: its two ends below), custom, white
DEFAULTS.cdmRingR, DEFAULTS.cdmRingG, DEFAULTS.cdmRingB = 0.88, 0.75, 0.38
-- (Gradient's ends, picked on the page, 2026-11-23: green full, red empty to start.)
DEFAULTS.cdmGradFullR, DEFAULTS.cdmGradFullG, DEFAULTS.cdmGradFullB = 0.2, 0.85, 0.25
DEFAULTS.cdmGradEmptyR, DEFAULTS.cdmGradEmptyG, DEFAULTS.cdmGradEmptyB = 0.95, 0.2, 0.15
-- (The amount from the icon's middle, nudged by these: the user, 2026-11-23,
-- "start in middle and add X/Y offset", in place of Middle / Bottom.)
DEFAULTS.cdmAmountX, DEFAULTS.cdmAmountY = 0, 0
DEFAULTS.cdmAmountSize = 13
-- (The icons' shape, the page's Shape tab: bars = as Action Bar Style's buttons,
-- or square / round for the Cooldown Manager alone. Style/ActionBarStyle.lua.)
DEFAULTS.cdmIconShape = "bars"
-- The page's folder tabs (Style/CdmStyle.lua's ns.PageTabsBelow), each a
-- container: right-clicked off, what's on it reads its defaults (the ring its
-- own look, the icons Same as action bars). Its saved switches: "tabOn:<id>:<n>".
ns.CDM_STYLE_TABS = "Cooldown Manager Style/look"
local RING_TAB, ICONS_TAB = 1, 2
ns.CDM_STYLE_RING_TAB, ns.CDM_STYLE_ICONS_TAB = RING_TAB, ICONS_TAB
function ns.CdmStyleTabOn(n)
	local db = ns.db
	return not (db and db[("tabOn:%s:%d"):format(ns.CDM_STYLE_TABS, n)] == false)
end
local function Look()
	if ns.StyleLook then return ns.StyleLook("cdmStyle", not ns.CdmStyleTabOn(RING_TAB)) end
	return DEFAULTS -- (Style left out: the ring's own look)
end

local function Secret(value) return issecretvalue and issecretvalue(value) or false end
local function Plain(value) return type(value) == "number" and not Secret(value) and value or nil end

-- Gradient: the empty end's color at the ring's start (12 o'clock) to the full
-- end's at its end: what's left after a hit is the start, so it turns toward
-- the empty color as it drains. Blended round the color wheel (green to red
-- passes yellow, not brown).
local function ToHSV(r, g, b)
	local hi, lo = math.max(r, g, b), math.min(r, g, b)
	local d = hi - lo
	local h = 0
	if d > 0 then
		if hi == r then h = ((g - b) / d) % 6 elseif hi == g then h = (b - r) / d + 2 else h = (r - g) / d + 4 end
		h = h / 6
	end
	return h, hi > 0 and d / hi or 0, hi
end
local function FromHSV(h, s, v)
	local i = math.floor(h * 6) % 6
	local f = h * 6 - math.floor(h * 6)
	local p, q, u = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	if i == 0 then return v, u, p elseif i == 1 then return q, v, p elseif i == 2 then return p, v, u
	elseif i == 3 then return p, q, v elseif i == 4 then return u, p, v end
	return v, p, q
end
local function GradientAt(look, t)
	local h1, s1, v1 = ToHSV(tonumber(look.cdmGradEmptyR) or 0.95, tonumber(look.cdmGradEmptyG) or 0.2,
		tonumber(look.cdmGradEmptyB) or 0.15)
	local h2, s2, v2 = ToHSV(tonumber(look.cdmGradFullR) or 0.2, tonumber(look.cdmGradFullG) or 0.85,
		tonumber(look.cdmGradFullB) or 0.25)
	-- (The short way round the wheel; a grey end keeps the other's hue.)
	if s1 < 0.05 then h1 = h2 elseif s2 < 0.05 then h2 = h1 end
	local dh = h2 - h1
	if dh > 0.5 then dh = dh - 1 elseif dh < -0.5 then dh = dh + 1 end
	return FromHSV((h1 + dh * t) % 1, s1 + (s2 - s1) * t, v1 + (v2 - v1) * t)
end
ns.CooldownRingGradientAt = GradientAt

-- A piece's color at place t (0 the ring's start, 1 its end), by the page's Color.
local function ColorAt(look, t)
	local mode = look.cdmRingColor
	if mode == "grad" then return GradientAt(look, t) end
	if mode == "white" then return 0.95, 0.95, 0.95 end
	if mode == "custom" or mode == "one" then -- ("one": its name before the Look panel)
		return tonumber(look.cdmRingR) or 1, tonumber(look.cdmRingG) or 1, tonumber(look.cdmRingB) or 1
	end
	local _, class = UnitClass("player")
	local classColor = _G.C_ClassColor
	local color = class and (classColor and classColor.GetClassColor and classColor.GetClassColor(class)
		or RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
	if color then return color.r, color.g, color.b end
	return 0.95, 0.95, 0.95
end

-- (Other languages, release review 2026-11-23: the English "absorb N" and
-- "N charges" found nothing on a German or Russian client, so no shield got
-- a size and the page hid every Ring. There: the number nearest the word, in
-- the same sentence, before or after it (German "44 Schaden absorbiert"),
-- whole with that language's thousands marks (1.234, 1 234). Not a percent.
-- English clients keep the English patterns alone. Fix card
-- 2026-11-23-cdm-ring-locale.md, Tools/offline/cdmringlocalematrix.lua.)
local ABSORB_WORDS = { "absor", "assorb", "поглощ", "Поглощ", "흡수", "吸收" }
local CHARGE_WORDS = { "charge", "aufladung", "carga", "caric", "заряд", "Заряд", "충전", "充能" }
local THOUSANDS = { ",", ".", " ", "\194\160", "\226\128\175", "\226\128\137" } -- (no-break, narrow, thin spaces)
local function English()
	local locale = GetLocale and GetLocale()
	return type(locale) ~= "string" or locale:sub(1, 2) == "en"
end
-- Each number in a text: { start, end, value }.
local function Numbers(text)
	local list, at = {}, 1
	while true do
		local s, e = text:find("%d+", at)
		if not s then break end
		local digits, grouped = text:sub(s, e), true
		while grouped do
			grouped = false
			for _, mark in ipairs(THOUSANDS) do
				if text:sub(e + 1, e + #mark) == mark then
					local group = text:match("^%d%d%d", e + #mark + 1)
					if group and not text:find("^%d", e + #mark + 4) then
						digits, e, grouped = digits .. group, e + #mark + 3, true
						break
					end
				end
			end
		end
		local rest = text:sub(e + 1, e + 4)
		if not (rest:find("^%s?%%") or rest:find("^\194\160%%") or rest:find("^\226\128\175%%")
			or rest:find("^\239\188\133")) then
			list[#list + 1] = { s, e, tonumber(digits) }
		end
		at = e + 1
	end
	return list
end
local function OneSentence(gap)
	return #gap <= 40 and not (gap:find("[%.!?;]%s") or gap:find("\n") or gap:find("。", 1, true))
end
-- The number nearest one of the words (nil if none in its sentence).
local function NearWord(text, words)
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
	local lower = text:gsub("[A-Z]", string.lower) -- (ASCII only: lower() may change UTF-8 bytes)
	local numbers = Numbers(text)
	local best, bestGap
	for _, word in ipairs(words) do
		local from = 1
		while true do
			local ws, we = lower:find(word, from, true)
			if not ws then break end
			for _, number in ipairs(numbers) do
				local gap
				if number[1] > we then gap = text:sub(we + 1, number[1] - 1)
				elseif number[2] < ws then gap = text:sub(number[2] + 1, ws - 1) end
				if gap and OneSentence(gap) and (not bestGap or #gap < bestGap) then
					best, bestGap = number[3], #gap
				end
			end
			from = we + 1
		end
	end
	return best
end

local function AbsorbNumber(text)
	if type(text) ~= "string" or Secret(text) then return nil end
	if not English() then return NearWord(text, ABSORB_WORDS) end
	local number = text:match("[Aa]bsorb%a*%s+(%d[%d,]*)")
	return number and tonumber((number:gsub(",", ""))) or nil
end

-- After a /reload the game has no description for most spells (rule
-- forever.spell.description-needs-tooltip; cdmring run 2: Power Word: Shield
-- tracked, no size). A hidden tooltip set to the spell gives its text for
-- many (spellscan run 3: Power Word: Shield's "absorbing 48" came that way).
-- (Charges, 2026-11-23: Lightning Shield's "3 charges", the ring then drains
-- by the charges left, the aura's count. Planned in the ledger, built now.)
local function ChargesNumber(text)
	if type(text) ~= "string" or Secret(text) then return nil end
	if not English() then return NearWord(text, CHARGE_WORDS) end
	local number = text:match("(%d+)%s+[Cc]harges?")
	return number and tonumber(number) or nil
end

local tip
local function TooltipSize(id, parse)
	parse = parse or AbsorbNumber
	if not tip then
		local ok, made = pcall(CreateFrame, "GameTooltip", "CinematicRingTip", nil, "GameTooltipTemplate")
		if not ok then return nil end
		tip = made
	end
	tip:SetOwner(WorldFrame, "ANCHOR_NONE")
	tip:ClearLines()
	if not pcall(tip.SetSpellByID, tip, id) then return nil end
	local size
	for i = 2, math.min(tip:NumLines() or 0, 12) do
		local line = _G["CinematicRingTipTextLeft" .. i]
		size = size or parse(line and line:GetText())
	end
	tip:Hide()
	return size
end

-- A spell's first "absorb... N" number, plain (nil if none): its description,
-- else its tooltip. Kept per spell once found (a talent changing it shows on
-- the next /reload).
-- (A spell whose tooltip had none: tried again after TIP_RETRY seconds, not
-- on every tick and hit; a Ring on a buff with no shield rebuilt the hidden
-- tooltip 4 times a second, release review 2026-11-23, fix card
-- 2026-11-23-cdm-ring-size-miss.md. Not kept for good: the text can come late.)
local TIP_RETRY = 10
-- (One reader per kind of number: the absorb, the charges. Each its own kept
-- numbers and tooltip misses.)
local function Reader(parse)
	local sizes, tipMissed = {}, {} -- spell ID -> its number / GetTime() of its last empty tooltip
	return function(id)
		if not id then return nil end
		if sizes[id] then return sizes[id] end
		local size
		if C_Spell and C_Spell.GetSpellDescription then
			local ok, text = pcall(C_Spell.GetSpellDescription, id)
			size = ok and parse(text) or nil
		end
		if not size and not InCombatLockdown() then
			local missed = tipMissed[id]
			if not missed or GetTime() - missed >= TIP_RETRY then
				local okTip, found = pcall(TooltipSize, id, parse)
				size = okTip and found or nil
				tipMissed[id] = not size and GetTime() or nil
			end
		end
		if size then sizes[id] = size end
		return size
	end
end
local DescriptionSize = Reader(AbsorbNumber)
local DescriptionCharges = Reader(ChargesNumber)
ns.CooldownRingDescriptionSize = DescriptionSize
ns.CooldownRingDescriptionCharges = DescriptionCharges

-- The spell IDs an icon stands for (its own and its ranks), plain only.
local function IconSpells(icon)
	local info = ns.IconCooldownInfo and ns.IconCooldownInfo(icon)
	local ids = {}
	if type(info) ~= "table" then return ids end
	local own = Plain(info.spellID)
	if own then ids[own] = true end
	if type(info.linkedSpellIDs) == "table" and not Secret(info.linkedSpellIDs) then
		for _, id in ipairs(info.linkedSpellIDs) do
			id = Plain(id)
			if id then ids[id] = true end
		end
	end
	return ids, own
end

-- The last cast of each icon's spell (any rank): its size is the ring's full.
local lastCast = {} -- spell ID cast -> GetTime()
local function SizeFor(icon, read)
	read = read or DescriptionSize
	local ids, own = IconSpells(icon)
	local best, bestAt
	for id in pairs(ids) do
		if lastCast[id] and (not bestAt or lastCast[id] > bestAt) then best, bestAt = id, lastCast[id] end
	end
	local size = best and read(best)
	if not size and own then size = read(own) end
	if not size then
		-- (No cast seen since login: the highest rank you know.)
		for id in pairs(ids) do
			local known = C_SpellBook and C_SpellBook.IsSpellKnown and select(2, pcall(C_SpellBook.IsSpellKnown, id))
			local s = known == true and read(id)
			if s and (not size or s > size) then size = s end
		end
	end
	return size
end
ns.CooldownRingSizeFor = SizeFor

-- A charges buff's count now: the aura the game's icon keeps
-- (icon.auraDataCached, Blizzard_CooldownViewer's item data; its own number
-- in the corner comes from it). Secret in a fight maybe: a StatusBar and
-- SetText take it as the absorb. The most seen out of fights is kept per
-- icon spell, for a description with no "N charges".
local mostSeen = {} -- spell ID -> the highest plain count seen
local function Charges(icon)
	local ok, data = pcall(function() return icon.auraDataCached end)
	if not ok or type(data) ~= "table" then return nil end
	local okCount, count = pcall(function() return data.applications end)
	-- (type() only: the count may be secret, and testing one errors.)
	if not okCount or type(count) == "nil" then return nil end
	if not Secret(count) and type(count) ~= "number" then return nil end
	return count
end
ns.CooldownRingCharges = Charges

-- The most charges an icon's buff has: its description's "N charges", else
-- the most seen.
-- (The most seen kept in the saved data, db.cdmRingCharges, out of profiles:
-- Lightning Shield's description has no "3 charges", and the count seen was
-- lost on /reload, the page hiding its Ring again, cdmring q5af4. Recorded
-- whenever it reads plain, ring set or not.)
local function Saved()
	local db = ns.db
	if not db then return nil end
	db.cdmRingCharges = type(db.cdmRingCharges) == "table" and db.cdmRingCharges or {}
	return db.cdmRingCharges
end
local function Seen(id, count)
	count = Plain(count)
	if not (id and count and count > 1) then return end
	if count > (mostSeen[id] or 0) then mostSeen[id] = count end
	local saved = Saved()
	if saved and count > (saved[id] or 0) then saved[id] = count end
end
local function MostCharges(icon, id)
	if icon then
		Seen(id, Charges(icon))
		local most = SizeFor(icon, DescriptionCharges)
		if most then return most end
	end
	-- (The larger of this session's and the saved: after a /reload the first
	-- count seen, 2 with a charge used, won over the saved 3, and Lightning
	-- Shield's ring drew 2 pips, the user 2026-11-23.)
	if not id then return nil end
	local saved = Saved()
	local now, kept = mostSeen[id], saved and tonumber(saved[id])
	if now and kept then return math.max(now, kept) end
	return now or kept
end
ns.CooldownRingMostCharges = MostCharges

-- Whether a tracked buff (by its base spell) can have a ring: a shield (an
-- "absorb... N" in its description or a rank's) or a buff with charges ("N
-- charges", or more than one seen on its aura: Lightning Shield). Others get
-- no Ring on the page (2026-11-23). Unreadable in a fight: counts as fitting.
-- Only yes is kept (a description can come late).
local fits = {}
function ns.CooldownRingFits(id)
	id = Plain(id)
	if not id then return true end
	if fits[id] then return true end
	local found
	if ns.EachCooldownIcon then
		ns.EachCooldownIcon(function(icon, iconId, bar)
			if found or bar ~= "BuffIconCooldownViewer" then return end
			local plain = Plain(iconId)
			if plain and (ns.BaseSpell and ns.BaseSpell(plain) or plain) == id then found = icon end
		end, true)
	end
	local ok, size = true, nil
	if found then ok, size = pcall(SizeFor, found) end
	if not (ok and size) and found then ok, size = pcall(MostCharges, found, id) end
	if not (ok and size) then
		ok, size = pcall(DescriptionSize, id)
		if not ok then return true end -- (unreadable: left shown)
	end
	if not size then
		ok, size = pcall(DescriptionCharges, id)
		if not ok then return true end
		size = size or MostCharges(nil, id)
	end
	if size then
		fits[id] = true
		return true
	end
	return InCombatLockdown() and true or false
end

local rings = setmetatable({}, { __mode = "k" }) -- icon -> its pieces

local function Bar(parent, texture)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetStatusBarTexture(texture)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	return bar
end

-- Builds (once per icon and style) what a style draws.
local function Make(icon, style, pips)
	local ring = rings[icon]
	if ring and ring.style == style and ring.pips == pips then return ring end
	if ring then ring.holder:Hide() end
	local art = type(icon.Icon) == "table" and type(icon.Icon.GetObjectType) == "function" and icon.Icon or icon
	local holder = CreateFrame("Frame", nil, icon)
	holder:SetAllPoints(art)
	holder:SetFrameLevel(icon:GetFrameLevel() + 8)
	ring = { holder = holder, style = style, pips = pips, segs = {}, tracks = {} }
	local count = pips or STYLES[style]
	if count then
		local box = CreateFrame("Frame", nil, holder)
		box:SetPoint("CENTER")
		ring.box = box
		for i = 1, count do
			local path = ("%sCdmRing%d_%d"):format(ART, count, i)
			local track = box:CreateTexture(nil, "BACKGROUND")
			track:SetAllPoints(box)
			track:SetTexture(path)
			ring.tracks[i] = track
			local seg = Bar(box, path)
			seg:SetAllPoints(box)
			ring.segs[i] = seg
		end
	elseif style == "bar" then
		local back = holder:CreateTexture(nil, "BACKGROUND")
		back:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 0, -2)
		back:SetPoint("TOPRIGHT", holder, "BOTTOMRIGHT", 0, -2)
		back:SetHeight(5)
		ring.back = back
		local bar = Bar(holder, WHITE)
		bar:SetAllPoints(back)
		-- (Gradient: a second fill over it, a ramp see-through to solid in the
		-- full end's color, set to the same amount: cropped alike, so each spot
		-- keeps its own color.)
		local ramp = Bar(holder, ART .. "CdmDrainRamp")
		ramp:SetAllPoints(back)
		ramp:SetFrameLevel(bar:GetFrameLevel() + 1)
		ring.bar, ring.ramp = bar, ramp
	elseif style == "liquid" then
		-- (The icon dimmed; a bright copy of it fills from the bottom up to
		-- what's left.)
		local dim = holder:CreateTexture(nil, "BACKGROUND")
		dim:SetAllPoints(holder)
		dim:SetColorTexture(0, 0, 0, 0.62)
		local bar = Bar(holder, ART .. "CdmDrainGrad")
		bar:SetAllPoints(holder)
		bar:SetOrientation("VERTICAL")
		ring.bar, ring.liquid = bar, true
	end
	-- (On a frame of its own above the bars: Liquid's bar, a child frame,
	-- drew over the holder's text, cdmring run 3.)
	local top = CreateFrame("Frame", nil, holder)
	top:SetAllPoints(holder)
	top:SetFrameLevel(holder:GetFrameLevel() + 5)
	local text = top:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	ring.text, ring.font = text, text:GetFont()
	rings[icon] = ring
	return ring
end

-- The page's look on a ring: colors, the spent part, size, the amount's text.
-- (Set again only when the look changed.)
local function Paint(ring, look)
	local parts = {}
	for i, k in ipairs({ "cdmRingColor", "cdmRingR", "cdmRingG", "cdmRingB", "cdmRingTrack", "cdmRingScale",
		"cdmAmountX", "cdmAmountY", "cdmAmountSize", "cdmGradFullR", "cdmGradFullG", "cdmGradFullB", "cdmGradEmptyR",
		"cdmGradEmptyG", "cdmGradEmptyB" }) do
		parts[i] = tostring(look[k])
	end
	local key = table.concat(parts, ",")
	if ring.painted == key then return end
	ring.painted, ring.width = key, nil -- (width nil: sized again with the new scale)
	local track = tonumber(look.cdmRingTrack) or 0.75
	local n = #ring.segs
	for i, seg in ipairs(ring.segs) do
		seg:SetStatusBarColor(ColorAt(look, (i - 0.5) / n))
		ring.tracks[i]:SetVertexColor(0.1, 0.1, 0.12, track)
	end
	if ring.back then ring.back:SetColorTexture(0.1, 0.1, 0.12, track) end
	if ring.bar and not ring.liquid then
		if look.cdmRingColor == "grad" then
			ring.bar:SetStatusBarColor(GradientAt(look, 0))
			ring.ramp:SetStatusBarColor(GradientAt(look, 1))
			ring.ramp:Show()
		else
			ring.bar:SetStatusBarColor(ColorAt(look, 1))
			ring.ramp:Hide()
		end
	end
	local text = ring.text
	text:ClearAllPoints()
	text:SetPoint("CENTER", ring.holder, "CENTER", tonumber(look.cdmAmountX) or 0, tonumber(look.cdmAmountY) or 0)
	if ring.font then pcall(text.SetFont, text, ring.font, tonumber(look.cdmAmountSize) or 13, "OUTLINE") end
end

-- (The game's own count in the icon's corner, hidden while ours shows the
-- charges in the middle: "3" twice, the user 2026-11-23. Ours shows the last
-- charge too, the game's doesn't. Back when the ring goes; Amount on Hide keeps
-- it hidden: no number at all.)
local function GameCount(ring, hide)
	local apps = ring.icon and ring.icon.Applications
	if type(apps) ~= "table" or type(apps.SetAlpha) ~= "function" then return end
	if hide then
		if not ring.hidGame then pcall(apps.SetAlpha, apps, 0) end
		ring.hidGame = true
	elseif ring.hidGame then
		pcall(apps.SetAlpha, apps, 1)
		ring.hidGame = nil
	end
end

local function HideRing(ring)
	if ring then
		ring.holder:Hide()
		GameCount(ring, false)
	end
end

local function On()
	return ns.db and ns.PageOn and ns.PageOn("handleCooldowns")
end

-- A row's Ring: on or off (its style is the page's; a row saved with a style
-- of its own from before the page, "pips" and the rest, counts as on).
-- (A buff counted as one with others: its group lead's row, the grid's one
-- row for them, ns.CooldownBuffKey; release review 2026-11-23, fix card
-- 2026-11-23-cdm-ring-groups.md.)
local function RowKey(id)
	local base = ns.BaseSpell and ns.BaseSpell(id) or id
	return ns.CooldownBuffKey and ns.CooldownBuffKey(base) or base
end
local function StyleOf(id, look)
	local base = RowKey(id)
	local row = ns.CooldownRowSetting and ns.CooldownRowSetting("ring", base, "buffs")
	if row == nil or row == "off" or row == false then return false end
	local style = look.cdmRingStyle
	if not (STYLES[style] or style == "liquid" or style == "bar") then style = "pips" end
	return true, style
end

-- (Each icon's spell and size from when they could be read: in a fight the
-- spell ID the walk gives is secret, and looking its row up errored, so the
-- ring froze on its last picture, cdmring run 3: 44 and 8 pips after a hit.)
local iconSpell = setmetatable({}, { __mode = "k" })
local iconSize = setmetatable({}, { __mode = "k" })
local stats = { updates = 0, shown = 0, errors = 0 }
ns.CooldownRingStats = stats

-- A ring on an icon (a real one, or the Style page's preview's), set to an
-- amount out of size: secret in game (only StatusBars and SetText take it),
-- plain in the preview.
-- (whole: charges, each pip filled by a whole charge, in even runs: 3 charges
-- on 8 pips = 3, 3, 2.)
local function Draw(icon, style, look, size, amount, showAmount, whole, pips)
	local ring = Make(icon, style, pips)
	Paint(ring, look)
	if ring.box then
		-- (The icon's width is secret in a fight: math on it errored on every
		-- hit, cdmring run 4. Sized when it reads plain; kept through fights.)
		-- (The last plain width kept, ring.known: a Size change while the
		-- width read secret kept the old size, the user's shots 2026-11-23,
		-- 110% and 180% the same ring.)
		local ok, width = pcall(ring.holder.GetWidth, ring.holder)
		width = ok and Plain(width)
		if width and width > 0 then ring.known = width else width = ring.known end
		if width and width > 0 and width ~= ring.width then
			ring.width = width
			local scale = tonumber(look.cdmRingScale) or 1.36
			ring.box:SetSize(width * scale, width * scale)
		end
		local n = #ring.segs
		for i, seg in ipairs(ring.segs) do
			local low = (i - 1) / n * size
			if whole then low = math.floor(low) + 0.5 end -- (full at that many charges and up)
			seg:SetMinMaxValues(low, low + 0.01)
			seg:SetValue(amount)
		end
	elseif ring.bar then
		if ring.liquid then
			local texture = icon.Icon and icon.Icon.GetTexture and icon.Icon:GetTexture()
			if texture then pcall(ring.bar.SetStatusBarTexture, ring.bar, texture) end
		end
		ring.bar:SetMinMaxValues(0, size)
		ring.bar:SetValue(amount)
		if ring.ramp then
			ring.ramp:SetMinMaxValues(0, size)
			ring.ramp:SetValue(amount)
		end
	end
	if showAmount then
		ring.text:SetText(amount)
		ring.text:Show()
	else
		ring.text:Hide()
	end
	ring.size = size
	ring.holder:Show()
	return ring
end

-- (For the Style page's preview: a ring in the page's look, on a stand-in icon.)
function ns.CooldownRingDraw(icon, look, size, amount)
	local style = look.cdmRingStyle
	if not (STYLES[style] or style == "liquid" or style == "bar") then style = "pips" end
	return Draw(icon, style, look, size, amount, true)
end
ns.CooldownRingLook = Look

-- (Why each icon has no ring, for /cine debug cdmring why.)
local skipped = setmetatable({}, { __mode = "k" })
ns.CooldownRingSkipped = skipped
local function Skip(icon, why)
	skipped[icon] = why
	return HideRing(rings[icon])
end

-- One icon: its ring shown and set while its buff is on you.
local function Show(icon, id)
	local spell = Plain(id)
	if spell then iconSpell[icon] = spell else spell = iconSpell[icon] end
	if not spell then return Skip(icon, "no spell") end
	local look = Look()
	local wanted, style = StyleOf(spell, look)
	if not wanted then return Skip(icon, "row off") end
	if type(icon.auraInstanceID) == "nil" then return Skip(icon, "buff not on you") end
	if not ns.Reachable(icon) then return Skip(icon, "icon unreachable") end
	-- A shield: its absorb out of its size. Else charges: the aura's count
	-- out of the most (2026-11-23, Lightning Shield).
	-- (Each kept as { size, charges? } for when it can't be read: a fight.)
	local size, amount, whole = SizeFor(icon), nil, false
	if size then
		iconSize[icon] = { size, false }
	else
		local count = Charges(icon)
		local most = MostCharges(icon, spell) -- (records the count seen too)
		if most then
			size, whole = most, true
			iconSize[icon] = { most, true }
		elseif iconSize[icon] then
			size, whole = iconSize[icon][1], iconSize[icon][2]
		end
		if whole then amount = count end
	end
	if not size or size <= 0 then return Skip(icon, "no size (no absorb, no charges known)") end
	if not whole then
		local ok, absorbs = pcall(UnitGetTotalAbsorbs, "player")
		if not ok then return Skip(icon, "absorbs unreadable") end
		amount = absorbs
	end
	if type(amount) == "nil" then return Skip(icon, "no amount (count unread)") end -- (secret: type() only)
	stats.charges = whole and (stats.charges or 0) + 1 or stats.charges
	-- (The Amount column: hidden on rows set so.)
	local base = RowKey(spell)
	local showAmount = ns.CooldownRowSetting("ringAmount", base, "buffs") ~= false
	-- (Pips on a charges buff: one per charge, 2 to 20 (art CdmRing<n>_*,
	-- Media/make_cdm_ring.py); the user 2026-11-23, "automatic". More: 8.)
	local pips = whole and style == "pips" and Plain(size) and size >= 2 and size <= PIPS_MOST
		and size == math.floor(size) and size or nil
	local ring = Draw(icon, style, look, size, amount, showAmount, whole, pips)
	ring.icon = icon
	-- (Hidden with Amount on Hide too: Hide = no number, the user 2026-11-23.)
	GameCount(ring, whole)
	skipped[icon] = nil
	stats.shown = stats.shown + 1
end

local function Update()
	if not On() then
		for _, ring in pairs(rings) do HideRing(ring) end
		return
	end
	stats.updates = stats.updates + 1
	ns.EachCooldownIcon(function(icon, id, bar)
		if bar ~= "BuffIconCooldownViewer" then return end
		local ok, err = pcall(Show, icon, id)
		if not ok then
			stats.errors = stats.errors + 1
			if err ~= stats.lastError then
				stats.lastError = err
				if ns.Log then ns.Log("cooldownring", "error: " .. tostring(err)) end
			end
		end
	end, true)
end
ns.CooldownRingUpdate = Update

local watcher = CreateFrame("Frame")
local since = 0
ns.SetOnUpdate(watcher, ns.Profiled("Drain ring watcher", function(_, elapsed)
	since = since + elapsed
	if since < 0.25 then return end -- (the icon going on or off; amounts come by event)
	since = 0
	Update()
end))
watcher:Hide()
watcher:SetScript("OnEvent", function(_, event, unit, _, spellID)
	if unit ~= "player" then return end
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		local id = Plain(spellID)
		if id then lastCast[id] = GetTime() end
	end
	Update()
end)

-- Starts or stops it as the rows say (any ring set) and the page's switch.
function ns.ApplyCooldownRing()
	if not ns.db then return end
	local any = ns.CooldownRowAny and ns.CooldownRowAny("ring", function(v) return v ~= nil and v ~= "off" end)
	if any then
		pcall(watcher.RegisterUnitEvent, watcher, "UNIT_ABSORB_AMOUNT_CHANGED", "player")
		pcall(watcher.RegisterUnitEvent, watcher, "UNIT_AURA", "player") -- (a charge used)
		pcall(watcher.RegisterUnitEvent, watcher, "UNIT_SPELLCAST_SUCCEEDED", "player")
		watcher:Show()
	else
		watcher:UnregisterAllEvents()
		watcher:Hide()
	end
	Update()
end

-- (For the tests: an icon's ring pieces.)
function ns.CooldownRingOf(icon) return rings[icon] end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_ENTERING_WORLD")
login:SetScript("OnEvent", function() ns.ApplyCooldownRing() end)
