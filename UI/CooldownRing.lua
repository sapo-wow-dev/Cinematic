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
local WHITE = "Interface\\Buttons\\WHITE8X8"

-- The look: Style > Cooldown Manager (Style/CdmStyle.lua; its switch cdmStyle).
-- Defaults here, so the ring works with Style left out (Modules.lua).
local DEFAULTS = ns.DEFAULTS
DEFAULTS.cdmStyle = true
DEFAULTS.cdmRingStyle = "pips" -- pips, smooth, liquid, bar
DEFAULTS.cdmRingScale = 1.36 -- the ring's size to the icon's
DEFAULTS.cdmRingTrack = 0.75 -- how dark the spent part shows (0: hidden)
DEFAULTS.cdmRingColor = "class" -- class, grad (green to red), custom, white
DEFAULTS.cdmRingR, DEFAULTS.cdmRingG, DEFAULTS.cdmRingB = 0.88, 0.75, 0.38
DEFAULTS.cdmAmountPlace = "middle" -- middle, bottom
DEFAULTS.cdmAmountSize = 13
local function Look()
	if ns.StyleLook then return ns.StyleLook("cdmStyle") end
	return DEFAULTS -- (Style left out: the ring's own look)
end

local function Secret(value) return issecretvalue and issecretvalue(value) or false end
local function Plain(value) return type(value) == "number" and not Secret(value) and value or nil end

-- Red at the ring's start (12 o'clock) to green at its end: what's left after
-- a hit is the start, so it reddens as it drains.
local function Hue(t)
	return math.min(1, 2 * (1 - t)) * 0.95, math.min(1, 2 * t) * 0.85, 0.16
end

-- A piece's color at place t (0 the ring's start, 1 its end), by the page's Color.
local function ColorAt(look, t)
	local mode = look.cdmRingColor
	if mode == "grad" then return Hue(t) end
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

local function AbsorbNumber(text)
	if type(text) ~= "string" or Secret(text) then return nil end
	local number = text:match("[Aa]bsorb%a*%s+(%d[%d,]*)")
	return number and tonumber((number:gsub(",", ""))) or nil
end

-- After a /reload the game has no description for most spells (rule
-- forever.spell.description-needs-tooltip; cdmring run 2: Power Word: Shield
-- tracked, no size). A hidden tooltip set to the spell gives its text for
-- many (spellscan run 3: Power Word: Shield's "absorbing 48" came that way).
local tip
local function TooltipSize(id)
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
		size = size or AbsorbNumber(line and line:GetText())
	end
	tip:Hide()
	return size
end

-- A spell's first "absorb... N" number, plain (nil if none): its description,
-- else its tooltip. Kept per spell once found (a talent changing it shows on
-- the next /reload).
local sizes = {}
local function DescriptionSize(id)
	if not id then return nil end
	if sizes[id] then return sizes[id] end
	local size
	if C_Spell and C_Spell.GetSpellDescription then
		local ok, text = pcall(C_Spell.GetSpellDescription, id)
		size = ok and AbsorbNumber(text) or nil
	end
	if not size and not InCombatLockdown() then size = TooltipSize(id) end
	if size then sizes[id] = size end
	return size
end
ns.CooldownRingDescriptionSize = DescriptionSize

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
local function SizeFor(icon)
	local ids, own = IconSpells(icon)
	local best, bestAt
	for id in pairs(ids) do
		if lastCast[id] and (not bestAt or lastCast[id] > bestAt) then best, bestAt = id, lastCast[id] end
	end
	local size = best and DescriptionSize(best)
	if not size and own then size = DescriptionSize(own) end
	if not size then
		-- (No cast seen since login: the highest rank you know.)
		for id in pairs(ids) do
			local known = C_SpellBook and C_SpellBook.IsSpellKnown and select(2, pcall(C_SpellBook.IsSpellKnown, id))
			local s = known == true and DescriptionSize(id)
			if s and (not size or s > size) then size = s end
		end
	end
	return size
end
ns.CooldownRingSizeFor = SizeFor

local rings = setmetatable({}, { __mode = "k" }) -- icon -> its pieces

local function Bar(parent, texture)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetStatusBarTexture(texture)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	return bar
end

-- Builds (once per icon and style) what a style draws.
local function Make(icon, style)
	local ring = rings[icon]
	if ring and ring.style == style then return ring end
	if ring then ring.holder:Hide() end
	local art = type(icon.Icon) == "table" and type(icon.Icon.GetObjectType) == "function" and icon.Icon or icon
	local holder = CreateFrame("Frame", nil, icon)
	holder:SetAllPoints(art)
	holder:SetFrameLevel(icon:GetFrameLevel() + 8)
	ring = { holder = holder, style = style, segs = {}, tracks = {} }
	local count = STYLES[style]
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
		local bar = Bar(holder, ART .. "CdmDrainGrad")
		bar:SetAllPoints(back)
		ring.bar = bar
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
	local key = table.concat({ tostring(look.cdmRingColor), tostring(look.cdmRingR), tostring(look.cdmRingG),
		tostring(look.cdmRingB), tostring(look.cdmRingTrack), tostring(look.cdmRingScale), tostring(look.cdmAmountPlace),
		tostring(look.cdmAmountSize) }, ",")
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
			ring.bar:SetStatusBarTexture(ART .. "CdmDrainGrad")
			ring.bar:SetStatusBarColor(1, 1, 1)
		else
			ring.bar:SetStatusBarTexture(WHITE)
			ring.bar:SetStatusBarColor(ColorAt(look, 1))
		end
	end
	local text = ring.text
	text:ClearAllPoints()
	if look.cdmAmountPlace == "bottom" then
		text:SetPoint("BOTTOM", ring.holder, "BOTTOM", 0, 2)
	else
		text:SetPoint("CENTER", ring.holder, "CENTER", 0, 0)
	end
	if ring.font then pcall(text.SetFont, text, ring.font, tonumber(look.cdmAmountSize) or 13, "OUTLINE") end
end

local function HideRing(ring)
	if ring then ring.holder:Hide() end
end

local function On()
	return ns.db and ns.PageOn and ns.PageOn("handleCooldowns")
end

-- A row's Ring: on or off (its style is the page's; a row saved with a style
-- of its own from before the page, "pips" and the rest, counts as on).
local function StyleOf(id, look)
	local base = ns.BaseSpell and ns.BaseSpell(id) or id
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
local function Draw(icon, style, look, size, amount, showAmount)
	local ring = Make(icon, style)
	Paint(ring, look)
	if ring.box then
		-- (The icon's width is secret in a fight: math on it errored on every
		-- hit, cdmring run 4. Sized when it reads plain; kept through fights.)
		local ok, width = pcall(ring.holder.GetWidth, ring.holder)
		width = ok and Plain(width)
		if width and width > 0 and width ~= ring.width then
			ring.width = width
			local scale = tonumber(look.cdmRingScale) or 1.36
			ring.box:SetSize(width * scale, width * scale)
		end
		local n = #ring.segs
		for i, seg in ipairs(ring.segs) do
			local low = (i - 1) / n * size
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

-- One icon: its ring shown and set while its buff is on you.
local function Show(icon, id)
	local spell = Plain(id)
	if spell then iconSpell[icon] = spell else spell = iconSpell[icon] end
	if not spell then return HideRing(rings[icon]) end
	local look = Look()
	local wanted, style = StyleOf(spell, look)
	if not wanted then return HideRing(rings[icon]) end
	if type(icon.auraInstanceID) == "nil" or not ns.Reachable(icon) then return HideRing(rings[icon]) end
	local size = SizeFor(icon)
	if size then iconSize[icon] = size else size = iconSize[icon] end
	if not size or size <= 0 then return HideRing(rings[icon]) end
	local ok, amount = pcall(UnitGetTotalAbsorbs, "player")
	if not ok then return HideRing(rings[icon]) end
	-- (The Amount column: hidden on rows set so.)
	local base = ns.BaseSpell and ns.BaseSpell(spell) or spell
	local showAmount = ns.CooldownRowSetting("ringAmount", base, "buffs") ~= false
	Draw(icon, style, look, size, amount, showAmount)
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
ns.SetOnUpdate(watcher, function(_, elapsed)
	since = since + elapsed
	if since < 0.25 then return end -- (the icon going on or off; amounts come by event)
	since = 0
	Update()
end)
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
