-- Cinematic: the Cooldown Manager page's grid (2026-11-22). One bar at a time
-- (the page's tabs): its bar row on top, then its spells (or tracked buffs);
-- across, the place groups (CooldownRules.lua), read left to right, then
-- Otherwise (each row's own mode). A cell gold is set for that row; grey, it
-- follows (a spell its bar's row). Clicking a cell opens a strip of choices
-- under its row (no dropdowns); right-click puts it back to following.
-- Clicking a group's heading opens its editor: name, places (any number),
-- combat, order, a CQL rule, delete. Rows can be ticked to set one column of
-- them all at once, or to copy one row onto others. A Look switch turns the
-- grid to each row's looks (countdown numbers, keybinds...), each cell
-- stepping through its values as it's clicked.
-- ns.CooldownGrid(parent, opts) gives the grid; grid.ShowBar(tab, ids) lists a
-- bar's rows and gives the height. opts: { width, Tooltip(frame, text),
-- Enabled(), Changed() (after a change: the page lists again and fits),
-- KeyGet(key), KeyPut(key, value) }.
local ADDON_NAME, ns = ...
local L = ns.L

local MODES = { { "always", L["Always"] }, { "ready", L["When ready"] }, { "recharge", L["While recharging"] },
	{ "proc", L["When it procs"] }, { "never", L["Never"] } }
-- (Missing: shown while the buff is off you, a reminder; Missing: each, on a
-- group of buffs that count as one: UI/CooldownMissing.lua, 2026-11-23.)
local BUFF_MODES = { { "always", L["Always"] }, { "combat", L["In combat"] }, { "quiet", L["Out of combat"] },
	{ "missing", L["Missing"] }, { "missingeach", L["Missing: each"] }, { "hidden", L["Hidden"] } }
-- (In a cell: short, the columns are narrow.)
local SHORT = { always = L["Always"], ready = L["Ready"], recharge = L["Recharging"], proc = L["Procs"],
	never = L["Never"], combat = L["In fights"], quiet = L["Out of fights"], missing = L["Missing"], missingeach = L["Missing: each"],
	hidden = L["Hidden"] }
local FULL = {}
for _, mode in ipairs(MODES) do FULL[mode[1]] = mode[2] end
for _, mode in ipairs(BUFF_MODES) do FULL[mode[1]] = mode[2] end
local BUFF_TAB = { buffs = true, bars = true, otherbuffs = true }
local NO_LOOK = { other = true, otherbuffs = true }
local OWN_MODES = { ready = "cooldownReadyOnly", recharge = "cooldownRechargeOnly", proc = "cooldownProcOnly",
	always = "cooldownAlwaysShow", never = "cooldownNeverShow" }
ns.COOLDOWN_SHORT_MODE = SHORT

-- Sizes (px).
local CHECK_W, NAME_W, GAP = 16, 150, 3
-- (Columns no wider than this, from the left: one stretched across the page,
-- with no groups, read as an empty bar, 2026-11-22. + Add group: a small
-- pill at the headings' end; with no groups, a card over the table.)
-- (190: at 120 two scenes left half the panel empty, 2026-11-22; the cells
-- and headings centered in them.)
local COL_MAX, ADD_W, COMPACT_W = 190, 96, 92
local ROW_H, BAR_H, HEAD_H = 24, 34, 34

local function db() return ns.GetDB and ns.GetDB() or ns.db end
local function GroupDefaults(group)
	local all = db().cooldownGroupDefaults
	all[group] = all[group] or {}
	return all[group]
end

-- ---------------------------------------------------------------------------
-- Each row's Otherwise (its own mode), and its When ready parts.

-- A spell's own When ready parts: where they're kept (its ID or its base),
-- or nil while it uses its bar's.
local function OwnReadyKey(id)
	local d = db()
	for _, key in ipairs({ id, ns.BaseSpell and ns.BaseSpell(id) or id }) do
		if d.cooldownReadyOnly[key] or d.cooldownEarlyOn[key] ~= nil or d.cooldownNeedsPower[key] ~= nil
			or d.cooldownReadyAnyTime[key] ~= nil or d.cooldownReadyEarly[key] ~= nil then
			return key
		end
	end
end
ns.CooldownOwnReadyKey = OwnReadyKey

-- A spell's own mode set (nil: back to following its bar). Newly When ready:
-- its bar's When ready parts, unless it has its own.
local function SetSpellMode(id, group, mode)
	local d = db()
	if mode == "ready" and not OwnReadyKey(id) then
		local _, power, early, anyTime = ns.CooldownGroupSettings(group or "other", false)
		d.cooldownEarlyOn[id], d.cooldownReadyEarly[id] = true, early
		d.cooldownNeedsPower[id] = power or nil
		d.cooldownReadyAnyTime[id] = anyTime or nil
	end
	for value, key in pairs(OWN_MODES) do
		d[key][id] = value == mode or nil
	end
end

-- The When ready parts of a row: a spell's own (seeded from its bar's the
-- first time one changes), else its bar's. Early: seconds or nil (the
-- default share); earlyOn false: back once it's ready.
local function ReadyParts(kind, key, tab)
	if kind == "group" then
		local _, power, early, anyTime = ns.CooldownGroupSettings(key, false)
		return power, true, early, anyTime
	end
	local own = OwnReadyKey(key)
	if own then
		local d = db()
		return d.cooldownNeedsPower[own], d.cooldownEarlyOn[own], d.cooldownReadyEarly[own], d.cooldownReadyAnyTime[own]
	end
	local _, power, early, anyTime = ns.CooldownGroupSettings(tab or "other", false)
	return power, true, early, anyTime
end
local function SetReadyPart(kind, key, tab, part, value)
	local d = db()
	if kind == "group" then
		local set = GroupDefaults(key)
		if part == "power" then set.power = value or nil
		elseif part == "anyTime" then set.anyTime = value or nil
		else set.early = value end
		return
	end
	local own = OwnReadyKey(key)
	if not own then
		own = key
		local power, _, early, anyTime = ReadyParts("group", tab or "other")
		d.cooldownEarlyOn[own], d.cooldownReadyEarly[own] = true, early
		d.cooldownNeedsPower[own], d.cooldownReadyAnyTime[own] = power or nil, anyTime or nil
	end
	if part == "power" then d.cooldownNeedsPower[own] = value or nil
	elseif part == "anyTime" then d.cooldownReadyAnyTime[own] = value or nil
	else d.cooldownEarlyOn[own], d.cooldownReadyEarly[own] = true, value end
end
ns.CooldownSetReadyPart = SetReadyPart

-- What a row's Otherwise is ("mode", whether it's its own).
local function OtherwiseOf(kind, key, tab)
	if kind == "group" then
		local mode = ns.CooldownGroupSettings(key, false)
		local set = db().cooldownGroupDefaults[key]
		return mode, set and set.mode ~= nil
	elseif kind == "buff" then
		return ns.CooldownBuffMode(key, tab, false)
	end
	return ns.CooldownSpellMode(key, tab, false)
end
local function SetOtherwise(kind, key, tab, mode)
	if kind == "group" then
		GroupDefaults(key).mode = mode
	elseif kind == "buff" then
		db().cooldownBuffMode[key] = mode
	else
		SetSpellMode(key, tab, mode)
	end
	if ns.readyPace then ns.readyPace.due = true end
end
ns.CooldownSetOtherwise = SetOtherwise

-- What a row shows in a group's column ("mode", whether it's the row's own cell).
local function CellOf(kind, key, tab, id)
	local own = ns.CooldownCell(kind, key, id)
	if own then return own, true end
	if kind ~= "group" then
		local bar = ns.CooldownCell("group", tab, id)
		if bar then return bar, false end
	end
	return (OtherwiseOf(kind, key, tab)), false
end
ns.CooldownGridCell = CellOf

-- ---------------------------------------------------------------------------
-- The looks (the old row settings): what each takes and how it reads.

local function GameNumbersText()
	local ok, on = pcall(GetCVarBool, "countdownForCooldowns")
	return (ok and on) and L["Game's (on)"] or L["Game's (off)"]
end
local function OnOff(value) return value and L["On"] or L["Off"] end
local function ShowHide(value) return value and L["Show"] or L["Hide"] end
local LOOK = {
	numbers = { label = L["Numbers"], tip = L["Countdown numbers on the icons."], values = { "game", "show", "hide" },
		Text = function(value)
			if value == "game" then return GameNumbersText() end
			if value == "untouched" then return L["Game's"] end
			return value == "show" and L["Show"] or L["Hide"]
		end },
	keybinds = { label = L["Keybinds"], tip = L["Each spell's keybind on its icon."], values = { true, false }, Text = ShowHide },
	-- (Short: "Cooldown, not buff" was cut to "Cooldown, not..." in game, run 1.)
	notBuff = { label = L["Own cooldown"], tip = L["Shows the spell's own cooldown instead of its buff or DoT."],
		values = { true, false }, Text = OnOff },
	flash = { label = L["Flash"], tip = L["Flashes the icon for a few seconds when the spell's cooldown ends."],
		values = { true, false }, Text = OnOff },
	center = { label = L["Close the gaps"], tip = L["Closes the gaps so the shown icons sit centered."],
		values = { true, false }, Text = OnOff, bar = true },
	stayUp = { label = L["Stay up while recharging"], tip = L["Keeps the Cooldown Manager up until every cooldown in this bar is ready."],
		values = { "off", "on", "after" }, bar = true,
		Text = function(value) return value == "after" and L["After combat"] or value == "on" and L["On"] or L["Off"] end },
	stacks = { label = L["Stacks and time left"], tip = L["Shows stacks and time left on tracked buff icons."],
		values = { true, false }, Text = ShowHide, bar = true },
	-- (UI/CooldownRing.lua, 2026-11-23: a buff row's cells only on shields and
	-- buffs with charges, ns.CooldownRingFits; the bar's row always.)
	-- (On or off; its look on Style > Cooldown Manager, Style/CdmStyle.lua. A
	-- row saved with a style from before reads On.)
	ring = { label = L["Ring"], tip = L["A ring around the icon that drains as your shield takes damage or its charges are used. Its look: Style > Cooldown Manager."],
		values = { "off", "on" },
		Text = function(value) return (value == nil or value == "off" or value == false) and L["Off"] or L["On"] end },
	ringAmount = { label = L["Amount"], tip = L["What's left in the middle of the ring: the amount your shield can still absorb, or its charges."],
		values = { true, false }, Text = ShowHide },
}
local LOOK_COLUMNS = { essential = { "numbers", "keybinds", "notBuff", "flash" }, utility = { "numbers", "keybinds", "notBuff", "flash" },
	buffs = { "numbers", "ring", "ringAmount" }, bars = { "numbers" } }
local BAR_EXTRAS = { essential = { "center", "stayUp" }, utility = { "center", "stayUp" }, buffs = { "center", "stacks" } }
local RECHARGE = { essential = "cooldown", utility = "cooldownUtility" }
ns.COOLDOWN_LOOK = LOOK

-- A look's value for a row (a bar's always one; a spell's nil while it follows),
-- what it shows as (a spell following: its bar's), and its setter.
local function LookGet(what, kind, key, tab, opts)
	if what == "flash" then
		if kind == "group" then return ns.CooldownGroupFlash(key) and true or false end
		local own = db().cooldownFlashReady[key]
		if own == nil then return nil, ns.CooldownGroupFlash(tab) and true or false end
		return own
	elseif what == "center" then
		return ns.CooldownGroupCentered(key) and true or false
	elseif what == "stayUp" then
		local prefix = RECHARGE[key]
		if not (prefix and opts.KeyGet(prefix .. "WhileRecharging")) then return "off" end
		return opts.KeyGet(prefix .. "AfterCombat") and "after" or "on"
	elseif what == "stacks" then
		return opts.KeyGet("cooldownStacks") and true or false
	end
	if kind == "group" then
		local own = ns.CooldownRowOwn(key, what)
		if own == nil then own = ns.CooldownRowBase(what) end
		return own
	end
	local own = ns.CooldownRowOwn(key, what)
	if own == nil then return nil, ns.CooldownRowSetting(what, nil, tab) end
	return own
end
local function LookSet(what, kind, key, value, opts)
	if what == "flash" then
		if kind == "group" then GroupDefaults(key).flash = value and true or false
		else db().cooldownFlashReady[key] = value end
	elseif what == "center" then
		GroupDefaults(key).center = value -- (false kept: on until set)
	elseif what == "stayUp" then
		local prefix = RECHARGE[key]
		if prefix then
			opts.KeyPut(prefix .. "WhileRecharging", value ~= "off")
			opts.KeyPut(prefix .. "AfterCombat", value == "after")
		end
	elseif what == "stacks" then
		opts.KeyPut("cooldownStacks", value)
		if ns.ApplyCooldownStacks then ns.ApplyCooldownStacks() end
	else
		ns.SetCooldownRow(key, what, value)
	end
	if ns.ApplyCooldownNumbers then ns.ApplyCooldownNumbers() end
	if ns.ApplyCooldownKeybinds then ns.ApplyCooldownKeybinds() end
	if (what == "ring" or what == "ringAmount") and ns.ApplyCooldownRing then ns.ApplyCooldownRing() end
end
-- A look's choices for a row, in order (a bar's numbers with the base first when it's none of them).
local function LookValues(what, kind)
	local values = {}
	for i, value in ipairs(LOOK[what].values) do values[i] = value end
	if kind == "group" and what == "numbers" then
		local base = ns.CooldownRowBase(what)
		local listed = false
		for _, value in ipairs(values) do listed = listed or value == base end
		if not listed then table.insert(values, 1, base) end
	end
	return values
end
ns.CooldownLookGet, ns.CooldownLookSet = LookGet, LookSet

-- ---------------------------------------------------------------------------
-- Boxes: a cell, a choice, a small button. A fill, a 1 px edge, a text.

local STYLE = {
	-- (Greys, no gold: the user, 2026-11-22.)
	own = { 0.2, 0.195, 0.18, 1, 0.45, 0.44, 0.4, 1, 0.95, 0.94, 0.92 },
	bar = { 0.16, 0.155, 0.14, 1, 0.36, 0.35, 0.32, 1, 0.95, 0.94, 0.92 },
	follow = { 0, 0, 0, 0.3, 0.3, 0.29, 0.27, 1, 0.62, 0.61, 0.57 },
	off = { 0.09, 0.088, 0.08, 1, 0.3, 0.29, 0.27, 1, 0.8, 0.78, 0.74 },
	on = { 0.22, 0.215, 0.2, 1, 0.7, 0.69, 0.65, 1, 0.95, 0.94, 0.92 },
	warn = { 0.16, 0.1, 0.05, 1, 0.55, 0.4, 0.1, 1, 0.95, 0.72, 0.3 },
	danger = { 0.16, 0.07, 0.06, 1, 0.42, 0.16, 0.14, 1, 1, 0.6, 0.55 },
}

local function Box(parent, width, height)
	local box = CreateFrame("Button", nil, parent)
	box:SetSize(width or 60, height or ROW_H)
	box:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	box.fill = box:CreateTexture(nil, "BACKGROUND")
	box.fill:SetAllPoints()
	box.edges = {}
	for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", false }, { "BOTTOMLEFT", "BOTTOMRIGHT", false },
		{ "TOPLEFT", "BOTTOMLEFT", true }, { "TOPRIGHT", "BOTTOMRIGHT", true } }) do
		local edge = box:CreateTexture(nil, "BORDER")
		edge:SetPoint(side[1])
		edge:SetPoint(side[2])
		if side[3] then edge:SetWidth(1) else edge:SetHeight(1) end
		box.edges[#box.edges + 1] = edge
	end
	local glow = box:CreateTexture(nil, "HIGHLIGHT")
	glow:SetAllPoints()
	glow:SetColorTexture(1, 1, 1, 0.08)
	box.text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	box.text:SetPoint("LEFT", box, "LEFT", 3, 0)
	box.text:SetPoint("RIGHT", box, "RIGHT", -3, 0)
	box.text:SetJustifyH("CENTER")
	box.text:SetWordWrap(false)
	box.searchSkip = true
	return box
end
local function Paint(box, style, text, bright)
	local s = STYLE[style] or STYLE.off
	box.fill:SetColorTexture(s[1], s[2], s[3], s[4])
	for _, edge in ipairs(box.edges) do
		if bright then edge:SetColorTexture(0.95, 0.94, 0.92, 1) else edge:SetColorTexture(s[5], s[6], s[7], s[8]) end
	end
	box.text:SetTextColor(s[9], s[10], s[11])
	if text then box.text:SetText(text) end
	box.style = style
end
-- A hover tip worked out when the pointer comes (cells change).
local function LiveTip(frame, Get)
	frame:SetScript("OnEnter", function(self)
		local text = Get(self)
		if not text then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(text, 1, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- ---------------------------------------------------------------------------
-- Pills (the restyle, 2026-11-22: the boxes read "clunky, not stylish"): a
-- choice's small icon and word on a soft round-ended band of its color while
-- set; faint, with no band, while it follows. Each choice its own color and
-- icon (Media/make_cdm_icons.py: Textures/CdmIcons, Textures/CdmDisc).
local TEXTURES = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Textures\\"
local ICON_AT = { always = 0, ready = 1, recharge = 2, proc = 3, never = 4, hidden = 4, combat = 5, quiet = 6, add = 7,
	missing = 3, missingeach = 3 } -- (Missing: the procs spark for now, its own icon later)
local MODE_COLOR = { always = { 0.9, 0.88, 0.83 }, ready = { 0.45, 0.85, 0.48 }, recharge = { 0.42, 0.71, 1 },
	proc = { 1, 0.69, 0.33 }, never = { 1, 0.48, 0.42 }, hidden = { 1, 0.48, 0.42 }, combat = { 1, 0.6, 0.35 },
	quiet = { 0.66, 0.72, 1 }, add = { 0.85, 0.83, 0.78 }, missing = { 1, 0.85, 0.35 },
	missingeach = { 1, 0.85, 0.35 } }
-- (Neutral, no gold: gold was on everything and nothing stood out, 2026-11-22.)
local NEUTRAL = { 0.9, 0.88, 0.84 } -- (a look's value, a chip: no icon)
local WHITE, GREY, DIM, AMBER = { 0.95, 0.94, 0.92 }, { 0.66, 0.65, 0.61 }, { 0.54, 0.53, 0.49 }, { 0.88, 0.65, 0.29 }
local PILL_H = 18
-- How strong the band, by how the pill's used (none: no band).
local BAND = { own = 0.15, bar = 0.12, chosen = 0.3, chip = 0.08, picked = 0.88, inherited = 0.07 }
local PREVIEW_BLUE = { 0.42, 0.71, 1 }
ns.COOLDOWN_MODE_COLOR = MODE_COLOR

-- A list to pick from under a chip: items { { value, text }... }, the one
-- now ticked. (Chips that went to the next value each click read as
-- broken, the user 2026-11-22: "why is that a cycle option? that sucks".
-- Where the client has no menus: the next one, as before.)
local function PickMenu(owner, items, current, onPick)
	if not (ns.GRID_MENUS and ns.ContextMenu) then
		local at = 0
		for k, item in ipairs(items) do
			if item[1] == current then at = k end
		end
		onPick(items[at % #items + 1][1])
		return
	end
	ns.ContextMenu(owner, function(_, root)
		for _, item in ipairs(items) do
			root:CreateRadio(item[2], function() return item[1] == current end, function() onPick(item[1]) end)
		end
	end)
end
ns.CooldownPickMenu = PickMenu

local function PillButton(parent, width, height)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width or 80, height or ROW_H)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b.band = {}
	for _, part in ipairs({ "left", "mid", "right" }) do
		local t = b:CreateTexture(nil, "BACKGROUND")
		t:SetHeight(PILL_H)
		if part == "mid" then
			t:SetTexture("Interface\\Buttons\\WHITE8X8")
		else
			t:SetTexture(TEXTURES .. "CdmDisc")
			t:SetWidth(PILL_H / 2)
			if part == "left" then t:SetTexCoord(0, 0.5, 0, 1) else t:SetTexCoord(0.5, 1, 0, 1) end
		end
		b.band[part] = t
	end
	-- (A ring round it: the cell that decides, while previewing.)
	b.ring = {}
	for _, part in ipairs({ "left", "mid", "right" }) do
		local t = b:CreateTexture(nil, "BACKGROUND", nil, -2)
		t:SetHeight(PILL_H + 4)
		if part == "mid" then
			t:SetTexture("Interface\\Buttons\\WHITE8X8")
		else
			t:SetTexture(TEXTURES .. "CdmDisc")
			t:SetWidth((PILL_H + 4) / 2)
			if part == "left" then t:SetTexCoord(0, 0.5, 0, 1) else t:SetTexCoord(0.5, 1, 0, 1) end
		end
		-- (White, a thin line: blue behind the pill tinted its color, red
		-- "Never" on blue was 1.7:1, the contrast check, 2026-11-22.)
		t:SetVertexColor(0.95, 0.94, 0.92, 0.75)
		t:Hide()
		b.ring[part] = t
	end
	b.ringIn = {}
	for _, part in ipairs({ "left", "mid", "right" }) do
		local t = b:CreateTexture(nil, "BACKGROUND", nil, -1)
		t:SetHeight(PILL_H + 1)
		if part == "mid" then
			t:SetTexture("Interface\\Buttons\\WHITE8X8")
		else
			t:SetTexture(TEXTURES .. "CdmDisc")
			t:SetWidth((PILL_H + 1) / 2)
			if part == "left" then t:SetTexCoord(0, 0.5, 0, 1) else t:SetTexCoord(0.5, 1, 0, 1) end
		end
		t:SetVertexColor(0.1, 0.1, 0.105, 1)
		t:Hide()
		b.ringIn[part] = t
	end
	b.ring.mid:SetPoint("LEFT", b.ring.left, "RIGHT", 0, 0)
	b.ring.right:SetPoint("LEFT", b.ring.mid, "RIGHT", 0, 0)
	b.ringIn.mid:SetPoint("LEFT", b.ringIn.left, "RIGHT", 0, 0)
	b.ringIn.right:SetPoint("LEFT", b.ringIn.mid, "RIGHT", 0, 0)
	b.band.left:SetPoint("LEFT", b, "LEFT", 0, 0)
	b.ring.left:SetPoint("LEFT", b, "LEFT", -2, 0)
	b.ringIn.left:SetPoint("LEFT", b, "LEFT", -0.5, 0)
	b.band.mid:SetPoint("LEFT", b.band.left, "RIGHT", 0, 0)
	b.band.right:SetPoint("LEFT", b.band.mid, "RIGHT", 0, 0)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetTexture(TEXTURES .. "CdmIcons")
	b.icon:SetSize(12, 12)
	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.text:SetJustifyH("LEFT")
	b.text:SetWordWrap(false)
	b.searchSkip = true
	-- (Under the pointer: its band, stronger. None before the round of
	-- 2026-11-22: "mouseover kind of sucks", only a tooltip reacted.)
	local function Hover(on)
		b.hovered = on
		if b.repaint then b.repaint() end
	end
	b:HookScript("OnEnter", function() Hover(true) end)
	b:HookScript("OnLeave", function() Hover(false) end)
	return b
end
-- Paints a pill: mode (its icon and color; nil: a look's value, no icon),
-- its text, how it's used ("own", "bar", "chosen": a band; "follow": faint;
-- "choice": full color, no band), and bright (its cell open: a stronger
-- band). Gives its width.
local SetPill
function SetPill(b, mode, text, how, bright, compact, blank)
	b.repaint = function() SetPill(b, mode, text, how, bright, compact, blank) end
	-- (A button as wide as its words, measured each time: measured once as
	-- it was made, the game's real font was wider and cut "Open wor...",
	-- "In comb...", 2026-11-22.)
	if b.fit then b:SetWidth(1000) end
	local color = MODE_COLOR[mode] or NEUTRAL
	local at = ICON_AT[mode]
	-- (compact: a narrow column, its icon alone; its word in the tooltip.)
	compact = compact and at ~= nil
	b.text:SetText(text or "")
	b.text:SetShown(not compact)
	b.icon:ClearAllPoints()
	b.text:ClearAllPoints()
	local x = 8
	if at then
		b.icon:SetTexCoord(at / 8, (at + 1) / 8, 0, 1)
		b.icon:Show()
		x = x + 16
	else
		b.icon:Hide()
	end
	local textW = b.text:GetStringWidth()
	textW = type(textW) == "number" and textW or 40
	if compact then textW = -6 end
	local room = b:GetWidth()
	room = type(room) == "number" and room or 999
	local width = math.min(x + textW + 10, room)
	-- (A grid cell's pill centered in its column: b.center.)
	local off = b.center and math.max(math.floor((room - width) / 2), 0) or 0
	if at then b.icon:SetPoint("LEFT", b, "LEFT", off + 8, 0) end
	b.text:SetPoint("LEFT", b, "LEFT", off + x, 0)
	b.text:SetWidth(math.max(width - x - 8, 10))
	b.band.left:ClearAllPoints()
	b.band.left:SetPoint("LEFT", b, "LEFT", off, 0)
	if b.ring then
		b.ring.left:ClearAllPoints()
		b.ring.left:SetPoint("LEFT", b, "LEFT", off - 2, 0)
		b.ringIn.left:ClearAllPoints()
		b.ringIn.left:SetPoint("LEFT", b, "LEFT", off - 0.5, 0)
	end
	local band = BAND[how]
	if bright then band = (band or 0) + 0.2 end
	if b.hovered then band = (band or 0) + 0.18 end
	for _, t in pairs(b.band) do
		t:SetShown(band ~= nil)
		if band then t:SetVertexColor(color[1], color[2], color[3], band) end
	end
	b.band.mid:SetWidth(math.max(width - PILL_H, 1))
	local alpha = how == "follow" and 0.42 or how == "inherited" and 0.7 or how == "same" and 0.55
		or how == "ghost" and 0.38 or 1
	if how == "picked" then
		b.text:SetTextColor(0.08, 0.08, 0.07, 1)
		b.icon:SetVertexColor(0.08, 0.08, 0.07, 1)
	else
		b.text:SetTextColor(color[1], color[2], color[3], alpha)
		b.icon:SetVertexColor(color[1], color[2], color[3], alpha)
	end
	-- (blank: nothing shown till the pointer's on it, then its faint icon.)
	if blank and not b.hovered then
		b.icon:Hide()
		b.text:Hide()
	end
	-- (Dark words on a light fill: no shadow, it smudged them, 2026-11-22.)
	if b.text.SetShadowOffset then
		if how == "picked" then b.text:SetShadowOffset(0, 0) else b.text:SetShadowOffset(1, -1) end
	end
	b.style = how
	b.pillWidth = width
	if b.fit then b:SetWidth(width) end
	if b.ring then
		b.ring.mid:SetWidth(math.max(width + 4 - (PILL_H + 4), 1))
		b.ringIn.mid:SetWidth(math.max(width + 1 - (PILL_H + 1), 1))
		for _, t in pairs(b.ring) do
			t:SetShown(b.ringed and true or false)
			-- (A ghost cell: the outline faint, a place to click. A preview's: plain.)
			t:SetVertexColor(0.95, 0.94, 0.92, how == "ghost" and (b.hovered and 0.32 or 0.14) or 0.75)
		end
		-- (Inside the ring: the ground, under a pill with no band of its own.)
		for _, t in pairs(b.ringIn) do t:SetShown(b.ringed and true or false) end
	end
	return width
end
ns.CooldownSetPill = SetPill

-- A texture shaded left to right (both clients' ways; neither: flat).
local function Shade(t, r, g, b, a1, a2)
	t:SetTexture("Interface\\Buttons\\WHITE8X8")
	t:SetVertexColor(1, 1, 1, 1)
	if CreateColor and pcall(t.SetGradient, t, "HORIZONTAL", CreateColor(r, g, b, a1), CreateColor(r, g, b, a2)) then return end
	if pcall(t.SetGradientAlpha, t, "HORIZONTAL", r, g, b, a1, r, g, b, a2) then return end
	t:SetColorTexture(r, g, b, (a1 + a2) / 2)
end

-- A spell's settings saved under another of its IDs (a talent's override,
-- from old situations) moved onto its base ID, the one the page edits; one
-- already on the base wins. Live reads took the override first, so the page
-- and the icon disagreed (audit, 2026-11-22). Run as the page lists spells.
local BASE_TABLES = { "cooldownReadyOnly", "cooldownRechargeOnly", "cooldownProcOnly", "cooldownAlwaysShow",
	"cooldownNeverShow", "cooldownNeedsPower", "cooldownEarlyOn", "cooldownReadyEarly", "cooldownReadyAnyTime",
	"cooldownFlashReady", "cooldownRowSettings", "cooldownSpellCells", "cooldownBuffMode", "cooldownBuffCells" }
function ns.CooldownKeysToBase()
	if not ns.BaseSpell then return 0 end
	local d, moved = db(), 0
	for _, name in ipairs(BASE_TABLES) do
		local all = d[name]
		if type(all) == "table" then
			local keys = {}
			for key in pairs(all) do
				if type(key) == "number" then keys[#keys + 1] = key end
			end
			for _, key in ipairs(keys) do
				local ok, base = pcall(ns.BaseSpell, key)
				if ok and type(base) == "number" and base ~= key then
					if all[base] == nil then
						all[base] = all[key]
					elseif type(all[base]) == "table" and type(all[key]) == "table" then
						-- (Both with cells or row settings: the override's ones the
						-- base hasn't got kept too, not dropped. Audit 2026-11-22.)
						for field, value in pairs(all[key]) do
							if all[base][field] == nil then all[base][field] = value end
						end
					end
					all[key] = nil
					moved = moved + 1
				end
			end
		end
	end
	return moved
end

-- ---------------------------------------------------------------------------

function ns.CooldownGrid(parent, opts)
	local WIDTH = opts.width or 600
	local grid = CreateFrame("Frame", nil, parent)
	grid:SetSize(WIDTH, 1)
	local state = { tab = nil, ids = {}, look = false, open = nil, editing = nil, selected = {}, clip = nil,
		bulkCol = 1, bulkValue = 1, sure = nil }
	grid.state = state
	local Tip = opts.Tooltip or function() end
	local function Enabled() return not opts.Enabled or opts.Enabled() end
	local GetName = (C_Spell and C_Spell.GetSpellName) or function(id) return (GetSpellInfo(id)) end
	local GetIcon = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
	local Layout -- (below)
	local function Changed()
		ns.CooldownRuleFactsStale()
		if ns.readyPace then ns.readyPace.due = true end
		Layout()
		if opts.Changed then opts.Changed() end
	end
	grid.Changed = Changed

	local FollowedOtherwise -- (below, by the choices)
	local function KindOf(key)
		if key == state.tab then return "group" end
		return BUFF_TAB[state.tab] and "buff" or "spell"
	end
	local function NameOf(key)
		if key == state.tab then return opts.BarName and opts.BarName(key) or tostring(key) end
		local ok, name = pcall(GetName, key)
		return ok and type(name) == "string" and name or L["Spell %d"]:format(key)
	end
	-- (A buff's In combat / Out of combat: offered only where already picked;
	-- scenes say in or out of combat now, the two said it twice. 2026-11-22.)
	-- A buffs tab's row for a group of buffs that count as one (its lead's ID).
	local function IsGroup(key)
		return key ~= state.tab and BUFF_TAB[state.tab] and ns.CooldownBuffMembers and ns.CooldownBuffMembers(key) ~= nil
			or false
	end
	-- (On the grid too: Layout is at Lua's 60-upvalue cap.)
	grid.IsGroup = IsGroup
	-- A mode's words; on a group's row Missing says it's any one of them.
	local function ModeText(mode, key, short)
		if mode == "missing" and IsGroup(key) then return short and L["Missing: any"] or L["Missing: any one"] end
		return (short and SHORT[mode]) or FULL[mode] or SHORT[mode] or tostring(mode)
	end
	-- (Missing: each only on a group's row: one buff has nothing to tell apart.)
	local function ModesFor(current, key)
		if not BUFF_TAB[state.tab] then return MODES end
		local list = {}
		for _, mode in ipairs(BUFF_MODES) do
			local offered = (mode[1] ~= "combat" and mode[1] ~= "quiet") or mode[1] == current
			if mode[1] == "missingeach" then offered = (key ~= nil and IsGroup(key)) or mode[1] == current end
			if offered then list[#list + 1] = { mode[1], ModeText(mode[1], key) } end
		end
		return list
	end

	-- The columns now: { id = group id } per group, then { other = true };
	-- in Look, { look = what } per look.
	local function Columns()
		local cols = {}
		if state.look then
			for _, what in ipairs(LOOK_COLUMNS[state.tab] or {}) do cols[#cols + 1] = { look = what } end
			return cols
		end
		for i, group in ipairs(ns.CooldownPlaceGroups()) do cols[#cols + 1] = { id = group.id, group = group, index = i } end
		cols[#cols + 1] = { other = true }
		return cols
	end
	grid.Columns = Columns
	-- The line under a buff's name: a group's other buffs; a buff on Missing
	-- anywhere, the ready-made ones that count for it too. Nil: none. Then
	-- a short one for when it doesn't fit the name's column ("or X +2").
	local function Either(names)
		local full = L["or %s"]:format(table.concat(names, L[" or "]))
		local short = #names > 1 and L["or %s +%d"]:format(names[1], #names - 1) or full
		return full, short
	end
	function grid.SubLine(key)
		if key == state.tab or not BUFF_TAB[state.tab] then return nil end
		if IsGroup(key) then
			local others = {}
			for k, member in ipairs(ns.CooldownBuffMembers(key)) do
				if k > 1 then others[#others + 1] = NameOf(member) end
			end
			return Either(others)
		end
		local alts = ns.CooldownBuffAlternatives and ns.CooldownBuffAlternatives(NameOf(key))
		if not alts then return nil end
		local missing = ns.COOLDOWN_MISSING_MODES or {}
		local onMissing = missing[(OtherwiseOf("buff", key, state.tab))] or false
		for _, col in ipairs(Columns()) do
			if not onMissing and col.id and missing[(CellOf("buff", key, state.tab, col.id))] then onMissing = true end
		end
		if not onMissing then return nil end
		return Either(alts)
	end

	-- What a cell says: text, style, and its value (a mode, or a look's value).
	local function CellLook(key, col)
		local kind = KindOf(key)
		if col.look then
			local own, shown = LookGet(col.look, kind, key, state.tab, opts)
			if kind == "group" then return LOOK[col.look].Text(own), "bar", own, nil end
			if own == nil then return LOOK[col.look].Text(shown), "follow", nil, nil end
			return LOOK[col.look].Text(own), "own", own, nil
		end
		local mode, own
		if col.other then mode, own = OtherwiseOf(kind, key, state.tab)
		else mode, own = CellOf(kind, key, state.tab, col.id) end
		local text = ModeText(mode, key, true)
		-- (The bar's Otherwise is what its row follows: gold, set or its default.)
		if kind == "group" then
			-- (The bar's scene cell the same as its Otherwise changes nothing:
			-- faint, so "Always | Always" doesn't read as two settings. 2026-11-22.)
			if own and not col.other and mode == (OtherwiseOf(kind, key, state.tab)) then return text, "same", mode, mode end
			return text, (own or col.other) and "bar" or "follow", own and mode or nil, mode
		end
		return text, own and "own" or "follow", own and mode or nil, mode
	end
	grid.CellLook = CellLook

	-- A cell set: value nil puts it back to following.
	local function SetCell(key, col, value)
		local kind = KindOf(key)
		if col.look then
			LookSet(col.look, kind, key, value, opts)
		elseif col.other then
			SetOtherwise(kind, key, state.tab, value)
		else
			ns.SetCooldownCell(kind, key, col.id, value)
		end
	end
	grid.SetCell = SetCell

	-- ---------------------------------------------------------------------
	-- Top: a hint, and When it shows | Look as tabs (a gold line under the picked one).
	local hint = grid:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, -6)
	hint:SetWidth(WIDTH - 310)
	hint:SetJustifyH("LEFT")
	hint:SetWordWrap(false)
	local function TabButton(width)
		local b = CreateFrame("Button", nil, grid)
		b:SetSize(width, 22)
		b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		b.text:SetPoint("CENTER", b, "CENTER", 0, 1)
		b.line = b:CreateTexture(nil, "ARTWORK")
		b.line:SetPoint("BOTTOMLEFT")
		b.line:SetPoint("BOTTOMRIGHT")
		b.line:SetHeight(2)
		b.line:SetColorTexture(1, 0.82, 0, 1) -- the game's gold
		local glow = b:CreateTexture(nil, "HIGHLIGHT")
		glow:SetAllPoints()
		glow:SetColorTexture(1, 1, 1, 0.05)
		b.searchSkip = true
		return b
	end
	local function PaintTab(b, text, on)
		b.text:SetText(text)
		if on then b.text:SetTextColor(WHITE[1], WHITE[2], WHITE[3]) else b.text:SetTextColor(DIM[1], DIM[2], DIM[3]) end
		b.line:SetShown(on and true or false)
	end
	local lookSwitch = TabButton(56)
	local showsSwitch = TabButton(100)
	lookSwitch:SetPoint("TOPRIGHT", grid, "TOPRIGHT", 0, 0)
	showsSwitch:SetPoint("RIGHT", lookSwitch, "LEFT", 0, 0)
	local tabBase = grid:CreateTexture(nil, "BORDER")
	tabBase:SetPoint("BOTTOMLEFT", showsSwitch, "BOTTOMLEFT")
	tabBase:SetPoint("BOTTOMRIGHT", lookSwitch, "BOTTOMRIGHT")
	tabBase:SetHeight(1)
	tabBase:SetColorTexture(1, 1, 1, 0.1)
	Tip(showsSwitch, L["Where each icon shows, scene by scene."])
	Tip(lookSwitch, L["Each icon's looks: countdown numbers, keybinds, flash."])
	for _, which in ipairs({ { showsSwitch, false }, { lookSwitch, true } }) do
		which[1]:SetScript("OnClick", function()
			if not Enabled() then return end
			state.look, state.open, state.editing, state.bulkCol, state.bulkValue = which[2], nil, nil, 1, 1
			Changed()
		end)
	end
	grid.showsSwitch, grid.lookSwitch = showsSwitch, lookSwitch

	-- ---------------------------------------------------------------------
	-- The heading row: Spell, a heading per column (no boxes: its name, its
	-- places under, a gold line under them all), then + Add group.
	local spellHead = grid:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	spellHead:SetText(L["Spell"]:upper())
	local headLine = grid:CreateTexture(nil, "BORDER")
	headLine:SetHeight(1)
	headLine:SetColorTexture(1, 1, 1, 0.14)
	local heads = {}
	grid.heads = heads -- (read by Tools/offline/cooldowngrid.lua)
	local function Head(i)
		if heads[i] then return heads[i] end
		local head = CreateFrame("Button", nil, grid)
		head:SetSize(60, HEAD_H)
		head:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		head.searchSkip = true
		-- (Its group's editor open: a soft gold behind it.)
		head.back = head:CreateTexture(nil, "BACKGROUND")
		head.back:SetAllPoints()
		head.back:SetColorTexture(1, 1, 1, 0.06)
		head.under = head:CreateTexture(nil, "ARTWORK")
		head.under:SetPoint("BOTTOMLEFT")
		head.under:SetPoint("BOTTOMRIGHT")
		head.under:SetHeight(2)
		head.under:SetColorTexture(WHITE[1], WHITE[2], WHITE[3], 1)
		local glow = head:CreateTexture(nil, "HIGHLIGHT")
		glow:SetAllPoints()
		glow:SetColorTexture(1, 1, 1, 0.05)
		head.text = head:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		head.text:SetPoint("TOPLEFT", head, "TOPLEFT", 2, -6)
		head.text:SetPoint("TOPRIGHT", head, "TOPRIGHT", -10, -6)
		head.text:SetJustifyH("CENTER")
		head.text:SetWordWrap(false)
		head.sub = head:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		head.sub:SetPoint("BOTTOMLEFT", head, "BOTTOMLEFT", 2, 5)
		head.sub:SetPoint("BOTTOMRIGHT", head, "BOTTOMRIGHT", -2, 5)
		head.sub:SetJustifyH("LEFT")
		head.sub:SetWordWrap(false)
		head.dot = head:CreateTexture(nil, "OVERLAY")
		-- (Round, as the pills: a square read as a stray mark, 2026-11-22.)
		head.dot:SetSize(7, 7)
		head.dot:SetTexture(TEXTURES .. "CdmDisc")
		head.dot:SetVertexColor(0.37, 0.83, 0.43, 1)
		head.dot:SetPoint("TOPRIGHT", head, "TOPRIGHT", -2, -8)
		-- (A scene's place in the order, small in the bottom-left corner: the
		-- one further left wins. The user, 2026-11-23.)
		head.order = head:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		head.order:SetPoint("BOTTOMLEFT", head, "BOTTOMLEFT", 3, 3)
		if head.order.SetTextScale then head.order:SetTextScale(0.8) end
		head:SetScript("OnClick", function(self)
			if not Enabled() or not self.col or self.col.other or self.col.look then return end
			state.editing = state.editing ~= self.col.id and self.col.id or nil
			state.open, state.sure = nil, nil
			Changed()
		end)
		LiveTip(head, function(self)
			local col = self.col
			if not col then return nil end
			if col.look then return LOOK[col.look].tip end
			if col.other then
				return L["Any place and time no scene covers. Faint: the same as the top row."]
			end
			return ("%s\n%s\n\n%s"):format(ns.CooldownGroupName(col.group), ns.CooldownGroupWhere(col.group),
				L["Click to edit this scene. Where scenes overlap, the one further left wins."])
		end)
		heads[i] = head
		return head
	end
	local function AddGroup()
		if not Enabled() then return end
		local group = ns.AddCooldownGroup()
		if group then
			state.editing, state.open = group.id, nil
			Changed()
		end
	end
	-- + Add group: a small pill at the headings' end, once there are groups.
	-- The previewer (2026-11-22, mockups K and L): a place picked, the scenes
	-- read as if you were there (UI/CooldownRules.lua), the grid outlines the
	-- cell that decides on each row, and the real bars follow.
	local previewButton = PillButton(grid, 120, PILL_H + 4)
	previewButton.fit = true
	Tip(previewButton, L["See a place from anywhere: the grid shows what decides there, and your bars on screen act as if you were there."])
	local previewMenu = CreateFrame("Frame", nil, grid)
	previewMenu:SetSize(332, 10)
	previewMenu:EnableMouse(true)
	previewMenu.cdmPopup = true -- (the lab's audit: meant to cover what's under it)
	previewMenu:Hide()
	do
		local back = previewMenu:CreateTexture(nil, "BACKGROUND")
		back:SetAllPoints()
		back:SetColorTexture(0.07, 0.065, 0.06, 1)
		for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", false }, { "BOTTOMLEFT", "BOTTOMRIGHT", false },
			{ "TOPLEFT", "BOTTOMLEFT", true }, { "TOPRIGHT", "BOTTOMRIGHT", true } }) do
			local edge = previewMenu:CreateTexture(nil, "BORDER")
			edge:SetPoint(side[1])
			edge:SetPoint(side[2])
			if side[3] then edge:SetWidth(1) else edge:SetHeight(1) end
			edge:SetColorTexture(1, 1, 1, 0.16)
		end
	end
	-- Two lists side by side: where (as you are, or a place) and when (as you
	-- are, or in or out of combat). Picks take at once; it stays open to try
	-- another, shut by the button. (One list of place-and-fight pairs till
	-- 2026-11-22; the user: "a 2nd tab for combat".)
	local previewItems = {}
	local function Current(which)
		local pick = ns.cdmPreview
		return pick and pick[which] or nil
	end
	local function PreviewList(which, title, first, list, x)
		local head = previewMenu:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		head:SetPoint("TOPLEFT", previewMenu, "TOPLEFT", x + 8, -8)
		head:SetText(title)
		local items = { { nil, first } }
		for _, each in ipairs(list) do items[#items + 1] = { each[1], each[2] } end
		for i, item in ipairs(items) do
			local b = PillButton(previewMenu, 152, 22)
			b:SetPoint("TOPLEFT", previewMenu, "TOPLEFT", x + 4, -24 - (i - 1) * 22)
			b.value, b.label, b.which = item[1], item[2], which
			b:SetScript("OnClick", function(self)
				local place, combat = Current("place"), Current("combat")
				if self.which == "place" then place = self.value else combat = self.value end
				ns.SetCooldownPreview(place, combat)
				Changed()
			end)
			previewItems[#previewItems + 1] = b
		end
		return #items
	end
	local previewRows = math.max(PreviewList("place", L["Where"], L["Where you are"], ns.COOLDOWN_PREVIEW_PLACES or {}, 6),
		PreviewList("combat", L["When"], L["Any time"], ns.COOLDOWN_PREVIEW_COMBATS or {}, 168))
	previewMenu:SetHeight(30 + previewRows * 22)
	local function PaintPreviewItems()
		for _, b in ipairs(previewItems) do
			b:SetWidth(152)
			SetPill(b, nil, b.label, b.value == Current(b.which) and "picked" or "choice")
			b:SetWidth(152)
		end
	end
	grid.PaintPreviewItems = PaintPreviewItems
	previewButton:SetScript("OnClick", function()
		if not Enabled() then return end
		if InCombatLockdown and InCombatLockdown() then return end
		previewMenu:SetShown(not previewMenu:IsShown())
		if previewMenu:IsShown() then
			PaintPreviewItems()
			previewMenu:SetFrameLevel(grid:GetFrameLevel() + 45)
			previewMenu:ClearAllPoints()
			previewMenu:SetPoint("TOPLEFT", previewButton, "BOTTOMLEFT", 0, -4)
		end
	end)
	grid.previewButton, grid.previewMenu, grid.previewItems = previewButton, previewMenu, previewItems
	-- (The banner while previewing: what decides there, and back to live.)
	local banner = CreateFrame("Frame", nil, grid)
	banner:SetSize(WIDTH, 22)
	do
		local back = banner:CreateTexture(nil, "BACKGROUND")
		back:SetAllPoints()
		back:SetColorTexture(PREVIEW_BLUE[1], PREVIEW_BLUE[2], PREVIEW_BLUE[3], 0.1)
		local edge = banner:CreateTexture(nil, "BORDER")
		edge:SetPoint("TOPLEFT")
		edge:SetPoint("BOTTOMLEFT")
		edge:SetWidth(2)
		edge:SetColorTexture(PREVIEW_BLUE[1], PREVIEW_BLUE[2], PREVIEW_BLUE[3], 0.8)
	end
	banner.text = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	banner.text:SetPoint("LEFT", banner, "LEFT", 10, 0)
	banner.text:SetPoint("RIGHT", banner, "RIGHT", -110, 0)
	banner.text:SetJustifyH("LEFT")
	banner.text:SetWordWrap(false)
	banner.text:SetTextColor(0.8, 0.9, 1)
	banner.back = PillButton(banner, 100, 20)
	banner.back.fit = true
	banner.back:SetPoint("RIGHT", banner, "RIGHT", -6, 0)
	banner.back:SetScript("OnClick", function()
		ns.SetCooldownPreview(nil)
		Changed()
	end)
	grid.banner = banner
	-- (Back to live as the page hides, and when a real fight starts.)
	grid:HookScript("OnHide", function()
		previewMenu:Hide()
		if ns.cdmPreview then ns.SetCooldownPreview(nil) end
	end)
	ns.CooldownPreviewChanged = function() if grid:IsVisible() then Changed() end end

	-- Select: tick rows to set them all at once or copy one onto others.
	local selectButton = PillButton(grid, 70, PILL_H + 4)
	selectButton.fit = true
	Tip(selectButton, L["Tick spells to set them all at once, or copy one spell's row onto others."])
	selectButton:SetScript("OnClick", function()
		if not Enabled() then return end
		state.selecting = not state.selecting or nil
		if not state.selecting then wipe(state.selected) end
		Changed()
	end)
	grid.selectButton = selectButton
	local plus = PillButton(grid, ADD_W, PILL_H + 4)
	plus.fit = true
	Tip(plus, L["Adds a scene: places and times, like dungeon fights, where icons can show differently."])
	plus:SetScript("OnClick", AddGroup)
	grid.plus = plus
	-- With none yet: a card over the table saying what a group is.
	local addCard = CreateFrame("Frame", nil, grid)
	addCard:SetSize(WIDTH, 44)
	do
		local back = addCard:CreateTexture(nil, "BACKGROUND")
		back:SetAllPoints()
		Shade(back, 1, 1, 1, 0.06, 0.02)
		for _, side in ipairs({ "TOP", "BOTTOM" }) do
			local edge = addCard:CreateTexture(nil, "BORDER")
			edge:SetPoint(side .. "LEFT")
			edge:SetPoint(side .. "RIGHT")
			edge:SetHeight(1)
			edge:SetColorTexture(1, 1, 1, 0.1)
		end
		local mark = addCard:CreateTexture(nil, "ARTWORK")
		mark:SetTexture(TEXTURES .. "CdmIcons")
		mark:SetTexCoord(0, 1 / 8, 0, 1)
		mark:SetVertexColor(GREY[1], GREY[2], GREY[3])
		mark:SetSize(16, 16)
		mark:SetPoint("LEFT", addCard, "LEFT", 10, 0)
		addCard.title = addCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		addCard.title:SetPoint("TOPLEFT", addCard, "TOPLEFT", 34, -7)
		addCard.title:SetText(L["Icons show the same in every scene"])
		addCard.title:SetTextColor(0.95, 0.9, 0.77)
		addCard.sub = addCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		addCard.sub:SetPoint("TOPLEFT", addCard.title, "BOTTOMLEFT", 0, -3)
		addCard.sub:SetText(L["Add a scene to make them differ in some places, like dungeons in combat."])
		addCard.button = Box(addCard, 96, 22)
		addCard.button:SetPoint("RIGHT", addCard, "RIGHT", -10, 0)
		Paint(addCard.button, "on", L["+ Add scene"])
		addCard.button.fill:SetColorTexture(WHITE[1], WHITE[2], WHITE[3], 1)
		addCard.button.text:SetTextColor(0.08, 0.08, 0.07)
		for _, edge in ipairs(addCard.button.edges) do edge:SetColorTexture(WHITE[1], WHITE[2], WHITE[3], 1) end
		Tip(addCard.button, L["Adds a scene: places and times, like dungeon fights, where icons can show differently."])
		addCard.button:SetScript("OnClick", AddGroup)
	end
	grid.addCard = addCard

	-- ---------------------------------------------------------------------
	-- The group editor, under the heading row while one is picked.
	local editor = CreateFrame("Frame", nil, grid)
	editor:SetSize(WIDTH, 84)
	do
		local back = editor:CreateTexture(nil, "BACKGROUND")
		back:SetAllPoints()
		back:SetColorTexture(0.105, 0.1, 0.09, 0.97)
	end
	local function EditingGroup() return state.editing and ns.CooldownPlaceGroup(state.editing) end
	-- (No Name line: a scene names itself by its rule till you name it, and
	-- Edit by Delete opens this box in its place. The user, 2026-11-23: "a
	-- lot of wasted space".)
	-- (A plain box like the chips: the game's input box was the one black,
	-- square thing on the page, 2026-11-22.)
	local nameBox = CreateFrame("EditBox", nil, editor)
	nameBox:SetFontObject("GameFontHighlight")
	nameBox:SetTextInsets(8, 8, 0, 0)
	nameBox:SetSize(150, 22)
	nameBox:Hide()
	do
		local fill = nameBox:CreateTexture(nil, "BACKGROUND")
		fill:SetAllPoints()
		fill:SetColorTexture(1, 1, 1, 0.06)
		local under = nameBox:CreateTexture(nil, "BORDER")
		under:SetPoint("BOTTOMLEFT")
		under:SetPoint("BOTTOMRIGHT")
		under:SetHeight(1)
		under:SetColorTexture(1, 1, 1, 0.28)
	end
	nameBox:SetAutoFocus(false)
	nameBox:SetMaxLetters(24)
	local namePlace = nameBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	namePlace:SetPoint("LEFT", nameBox, "LEFT", 8, 0)
	namePlace:SetPoint("RIGHT", nameBox, "RIGHT", -2, 0)
	namePlace:SetJustifyH("LEFT")
	namePlace:SetWordWrap(false)
	nameBox:HookScript("OnTextChanged", function(self) namePlace:SetShown(self:GetText() == "") end)
	Tip(nameBox, L["Its name. Leave it empty to name it by its rule."])
	local function SaveName(self)
		self:ClearFocus()
		state.renaming = nil
		local group = EditingGroup()
		local typed = self:GetText()
		-- (Left empty, or as it shows: still named by its rule.)
		if group and not (typed == "" and ns.CooldownGroupAutoNamed(group))
			and typed ~= ns.CooldownGroupName(group) and typed ~= group.name then
			group.name = typed
		end
		Changed()
	end
	nameBox:SetScript("OnEnterPressed", SaveName)
	nameBox:SetScript("OnEditFocusLost", function(self)
		if self.saving then return end
		self.saving = true
		SaveName(self)
		self.saving = nil
	end)
	nameBox:SetScript("OnEscapePressed", function(self)
		self.saving = true
		self:ClearFocus()
		self.saving = nil
		state.renaming = nil
		Changed()
	end)
	-- (Pills, as the grid's: they were the last boxes on the page, 2026-11-22.)
	local function SmallButton(text, _, tip, onClick)
		local button = PillButton(editor, 200, 22)
		button.fit = true
		button.label = text
		button:SetWidth(SetPill(button, nil, text, "chip"))
		Tip(button, tip)
		button:SetScript("OnClick", function(self, mouse)
			if Enabled() then onClick(self, mouse) end
		end)
		return button
	end
	local earlier = SmallButton("<", 22, L["Moves this scene left. Where scenes overlap, the one further left wins."], function()
		if ns.MoveCooldownGroup(state.editing, -1) then Changed() end
	end)
	local later = SmallButton(">", 22, L["Moves this scene right. Where scenes overlap, the one further left wins."], function()
		if ns.MoveCooldownGroup(state.editing, 1) then Changed() end
	end)
	-- (A scene written as a rule: opened from the pen, as on every Show in row.)
	local function OpenRule()
		local group = EditingGroup()
		if not group or not ns.OpenRuleEditor or not Enabled() then return end
		local was = ns.CooldownGroupText(group)
		ns.OpenRuleEditor({
			key = "cdm",
			label = ns.CooldownGroupName(group),
			Text = function() return ns.CooldownGroupText(group) end,
			SetText = function() end,
			Close = function(text)
				if not ns.SetCooldownGroupText(group, text) then ns.SetCooldownGroupText(group, was) end
				Changed()
			end,
		})
	end
	local delete = SmallButton(L["Delete"], 60, L["Deletes this scene and what was set in it, on every tab."], function()
		-- (Twice: a column of cells goes with it.)
		if state.sure ~= state.editing then
			state.sure = state.editing
			Layout()
			return
		end
		ns.RemoveCooldownGroup(state.editing)
		state.editing, state.sure = nil, nil
		Changed()
	end)
	-- (Its name: Edit opens the box in Order's place; Enter, a click away or
	-- Escape closes it. The user, 2026-11-23.)
	local rename = SmallButton(L["Edit"], 40, L["Renames this scene. Left empty, it's named by its rule."], function()
		state.renaming = state.editing
		Changed()
		nameBox:SetFocus()
		nameBox:HighlightText()
	end)
	-- (Placed under the headings, beside the dropdowns: EditorShow.)
	rename:SetPoint("RIGHT", delete, "LEFT", -4, 0)
	nameBox:SetPoint("RIGHT", delete, "LEFT", -6, 0)
	later:SetPoint("RIGHT", rename, "LEFT", -12, 0)
	earlier:SetPoint("RIGHT", later, "LEFT", -2, 0)
	-- (No "on every tab" note by the name: it said nothing, the user 2026-11-22.
	-- Delete's tooltip still says it goes on every tab.)
	local orderLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	orderLabel:SetPoint("RIGHT", earlier, "LEFT", -6, 0)
	orderLabel:SetText(L["Order"])

	-- Where and when: the standard Show in row (UI/GridRows.lua), its Combat
	-- and Location dropdowns and the pen. (Chips of its own till 2026-11-22;
	-- the user: "why are we redesigning the wheel... why not use our show in
	-- row style?")
	local WHEN_LAYOUT = { always = false, groups = { ns.GRID_COMBAT, ns.GRID_LOCATION }, menuW = 120 }
	local kit = setmetatable({ controls = {}, Refresh = function() Changed() end }, { __index = ns.GRID_KIT })
	local function Picked(place)
		local group = EditingGroup()
		return group and group.places and (group.places.any or group.places[place]) and true or false
	end
	-- The Location list: Open world (cities and inns with it), Instances
	-- (dungeons and raids at once), Dungeons, Raids, BGs & arenas. (No Cities
	-- or Inns of their own, Instances added: the user, 2026-11-22. A scene
	-- that has a city or inn without the open world, an old one, still shows
	-- them.) Each item ticks its places together; all of them: Anywhere.
	local PLACE_ITEMS = {
		{ L["Open world"], { "world", "city", "inn" }, "world" },
		{ L["Instances"], { "dungeon", "raid" }, "instance" },
		{ L["Dungeons"], { "dungeon" }, "dungeon" },
		{ L["Raids"], { "raid" }, "raid" },
		{ L["BGs & arenas"], { "bg" }, "bg" },
	}
	local TOWN_ITEMS = { { L["Cities"], { "city" }, "city" }, { L["Inns"], { "inn" }, "inn" } }
	local placeEntries = {}
	local function PlaceItem(item)
		return { item[1], function()
			for _, place in ipairs(item[2]) do
				if not Picked(place) then return false end
			end
			return true
		end, function()
			local group = EditingGroup()
			if not group or group.cql then return end
			local on = true
			for _, place in ipairs(item[2]) do on = on and Picked(place) end
			local places = {}
			for _, other in ipairs(ns.COOLDOWN_RULE_PLACES) do
				if Picked(other[1]) then places[other[1]] = true end
			end
			for _, place in ipairs(item[2]) do places[place] = not on or nil end
			local all = true
			for _, other in ipairs(ns.COOLDOWN_RULE_PLACES) do all = all and places[other[1]] end
			group.places = all and { any = true } or places
		end, nil, nil, place = item[3] }
	end
	-- (Filled for the scene open: its old town items only where it has them.)
	local function FillPlaces(group)
		for k = #placeEntries, 1, -1 do placeEntries[k] = nil end
		for _, item in ipairs(PLACE_ITEMS) do placeEntries[#placeEntries + 1] = PlaceItem(item) end
		local places = group and group.places or {}
		if not places.any and not places.world then
			for _, item in ipairs(TOWN_ITEMS) do
				if places[item[3]] then placeEntries[#placeEntries + 1] = PlaceItem(item) end
			end
		end
	end
	FillPlaces(nil)
	-- (Both ticked: any time. The last one ticked stays: a scene is always in
	-- one or the other, so it's greyed.)
	local combatEntries = {}
	for _, combat in ipairs({ { "in", L["In combat"], "out" }, { "out", L["Out of combat"], "in" } }) do
		combatEntries[#combatEntries + 1] = { combat[2],
			function()
				local group = EditingGroup()
				return group and group.combat ~= combat[3] or false
			end,
			function()
				local group = EditingGroup()
				if not group or group.cql then return end
				if group.combat == "any" then group.combat = combat[3]
				elseif group.combat == combat[3] then group.combat = "any" end
			end,
			function()
				local group = EditingGroup()
				return not (group and group.combat == combat[1])
			end, nil, combat = combat[1] }
	end
	-- (Both ticked reads "Any time", not "All".)
	combatEntries.allText = L["Any time"]
	placeEntries.allText = L["Anywhere"]
	local headTop = CreateFrame("Frame", nil, editor)
	headTop:SetSize(1, 1)
	headTop:SetPoint("TOPLEFT", editor, "TOPLEFT", 8, -6)
	local headings = ns.GridHeadings(kit, editor, headTop, 0, WHEN_LAYOUT)
	local headH = kit.headingHeight or 16
	local whenRow = ns.GridRow(kit, editor, 0, WHEN_LAYOUT, {
		menus = { [ns.GRID_COMBAT] = combatEntries, [ns.GRID_LOCATION] = placeEntries },
		help = { [ns.GRID_COMBAT] = L["In a fight (the Calm Timer after one too), out of one, or both."],
			[ns.GRID_LOCATION] = L["Where this scene fits. Tick any number."] },
	})
	whenRow:SetPoint("TOPLEFT", editor, "TOPLEFT", 8, -6 - headH)
	-- (Order, Edit and Delete on the dropdowns' line, at the right.)
	delete:SetPoint("TOPRIGHT", editor, "TOPRIGHT", -8, -6 - headH)
	-- The pen: the scene as a rule; on a rule, back to the dropdowns.
	local pen = ns.PanelButton(editor)
	pen:SetSize(22, 20)
	pen:SetPoint("LEFT", whenRow, "RIGHT", 2, 0)
	pen.icon = pen:CreateTexture(nil, "OVERLAY")
	pen.icon:SetSize(14, 14)
	pen.icon:SetPoint("CENTER")
	pen:SetScript("OnClick", function()
		local group = EditingGroup()
		if not group or not Enabled() then return end
		if group.cql then
			ns.SetCooldownGroupText(group, "")
			Changed()
		else
			OpenRule()
		end
	end)
	LiveTip(pen, function()
		local group = EditingGroup()
		return group and group.cql and L["Back to the dropdowns (the rule is dropped)."]
			or L["Opens the rule editor for more options than the dropdowns have."]
	end)
	-- (A scene written as a rule: its words in the dropdowns' place, a click opens it.)
	local cqlButton = ns.PanelButton(editor)
	cqlButton:SetSize(ns.GridWidth(WHEN_LAYOUT) - 2, 20)
	cqlButton:SetPoint("TOPLEFT", whenRow, "TOPLEFT", 0, -2)
	local cqlText = cqlButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	cqlText:SetPoint("LEFT", 6, 0)
	cqlText:SetPoint("RIGHT", -6, 0)
	cqlText:SetJustifyH("LEFT")
	cqlText:SetWordWrap(false)
	cqlButton:SetScript("OnClick", OpenRule)
	Tip(cqlButton, L["Click to open the editor."])
	local function EditorShow()
		local group = EditingGroup()
		editor:SetShown(group ~= nil and not state.look)
		if not editor:IsShown() then return 0 end
		-- (Renaming: the box in Order's place. Named by its rule: empty, its
		-- rule greyed in it.)
		local renaming = state.renaming == group.id
		nameBox:SetShown(renaming)
		for _, part in ipairs({ rename, earlier, later, orderLabel }) do part:SetShown(not renaming) end
		if not nameBox:HasFocus() then
			nameBox:SetText(ns.CooldownGroupAutoNamed(group) and "" or group.name)
		end
		namePlace:SetText(ns.CooldownGroupText(group) ~= "" and ns.CooldownGroupText(group) or L["Scene"])
		namePlace:SetShown(nameBox:GetText() == "")
		local _, index = ns.CooldownPlaceGroup(group.id)
		earlier:SetAlpha(index > 1 and 1 or 0.35)
		later:SetAlpha(index < #ns.CooldownPlaceGroups() and 1 or 0.35)
		local sure = state.sure == group.id
		delete:SetWidth(200)
		-- (No icon's room: with "never" for its red it kept the icon's space and
		-- came out too wide, 2026-11-22. A plain chip, its words red.)
		local function Red()
			SetPill(delete, nil, sure and L["Sure?"] or L["Delete"], sure and "chosen" or "chip")
			delete.text:SetTextColor(1, 0.48, 0.42)
			for _, t in pairs(delete.band) do
				if t:IsShown() then t:SetVertexColor(1, 0.48, 0.42, (sure and 0.3 or 0.1) + (delete.hovered and 0.15 or 0)) end
			end
			delete.repaint = Red -- (hovered: red still)
			return delete.pillWidth
		end
		delete:SetWidth(200)
		delete:SetWidth(Red())
		local own = group.cql ~= nil
		whenRow:SetShown(not own)
		if not own then
			FillPlaces(group)
			whenRow:Refresh()
		end
		for _, heading in ipairs(headings) do heading:SetShown(not own) end
		cqlButton:SetShown(own)
		if own then cqlText:SetText(ns.ColoredRule and ns.ColoredRule(group.cql) or group.cql) end
		pen.icon:SetTexture(TEXTURES .. (own and "GridIcon" or "Quill"))
		editor:SetHeight(6 + headH + 30)
		return editor:GetHeight()
	end
	grid.editor = editor
	grid.placeEntries, grid.combatEntries, grid.deleteButton, grid.nameBox = placeEntries, combatEntries, delete, nameBox
	grid.whenRow, grid.penButton, grid.cqlButton = whenRow, pen, cqlButton
	grid.moveButtons = { earlier, later }
	grid.renameButton = rename

	-- Under the headings: a line per group that's never in use or unfinished.
	local troubleLines = {}
	local function TroubleLine(i)
		if troubleLines[i] then return troubleLines[i] end
		local line = grid:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		line:SetTextColor(0.95, 0.72, 0.3)
		line:SetWidth(WIDTH)
		line:SetJustifyH("LEFT")
		troubleLines[i] = line
		return line
	end
	grid.troubleLines = troubleLines

	-- ---------------------------------------------------------------------
	-- The rows: a tick (not the bar's), the icon and name, a cell per column.
	local rows = {}
	local function Row(i)
		if rows[i] then return rows[i] end
		local row = {}
		-- (Behind it: the bar's gold band, or a faint one under the pointer; a hairline under.)
		row.band = grid:CreateTexture(nil, "BACKGROUND")
		-- (A moment's light on a row just copied or pasted onto: nothing showed
		-- either had happened, the user 2026-11-22.)
		row.flash = grid:CreateTexture(nil, "BACKGROUND", nil, 1)
		row.flash:Hide()
		row.sep = grid:CreateTexture(nil, "BORDER")
		row.sep:SetHeight(1)
		row.sep:SetColorTexture(1, 1, 1, 0.05)
		row.check = Box(grid, CHECK_W - 2, CHECK_W - 2)
		row.tick = row.check:CreateTexture(nil, "OVERLAY")
		row.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
		row.tick:SetDesaturated(true)
		row.tick:SetPoint("TOPLEFT", -3, 3)
		row.tick:SetPoint("BOTTOMRIGHT", 3, -3)
		Tip(row.check, L["Tick spells to set them all at once, or to copy one onto others."])
		row.check:SetScript("OnClick", function()
			if not Enabled() or row.key == nil then return end
			state.selected[row.key] = not state.selected[row.key] or nil
			Changed()
		end)
		row.name = CreateFrame("Button", nil, grid)
		row.name:SetSize(NAME_W, ROW_H)
		row.icon = row.name:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(18, 18)
		row.icon:SetPoint("LEFT", row.name, "LEFT", 0, 0)
		row.label = row.name:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		row.label:SetJustifyH("LEFT")
		row.label:SetWordWrap(false)
		-- (The bar's row: what it is, under its name.)
		row.sub = row.name:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		row.sub:SetJustifyH("LEFT")
		-- (Short and kept in its column: the longer line ran under the first cell, 2026-11-22.)
		row.sub:SetWordWrap(false)
		row.sub:SetWidth(NAME_W - 28)
		row.sub:SetText(L["for every spell"])
		row.sub:SetTextColor(DIM[1], DIM[2], DIM[3])
		-- (The name does nothing: it ticked the row till 2026-11-22, a surprise; the box does.)
		LiveTip(row.name, function()
			if row.key == state.tab then return L["Every spell in %s does what this row says, unless you set it on its own."]:format(NameOf(state.tab)) end
			return row.label:IsTruncated() and row.label:GetText() or nil
		end)
		row.cells = {}
		-- Its tick box seen only under the pointer, or while any row's ticked
		-- (a column of empty boxes read as stray squares, 2026-11-22), and a
		-- faint band across the row under the pointer. Kept shown at no
		-- alpha: still there to click, no flicker moving onto it.
		function row.ShowTick()
			local over = row.name:IsMouseOver() or row.check:IsMouseOver()
			for _, cell in ipairs(row.cells) do over = over or (cell:IsShown() and cell:IsMouseOver()) end
			-- (Shown while Select is on or a row's ticked: on hover only, nobody
			-- found them, 2026-11-22.)
			row.tickSeen = (state.selecting or next(state.selected) ~= nil) and row.key ~= state.tab and true or false
			row.check:SetAlpha(row.tickSeen and 1 or 0)
			if row.key ~= state.tab then
				row.band:SetColorTexture(1, 1, 1, 0.045)
				row.band:SetShown((over or state.selected[row.key]) and true or false)
			end
		end
		for _, frame in ipairs({ row.name, row.check }) do
			frame:HookScript("OnEnter", row.ShowTick)
			frame:HookScript("OnLeave", row.ShowTick)
		end
		rows[i] = row
		return row
	end
	local function Cell(row, j)
		if row.cells[j] then return row.cells[j] end
		local cell = PillButton(grid, 60, ROW_H)
		cell.center = true
		cell:SetScript("OnClick", function(self, mouse)
			if not Enabled() or row.key == nil or not self.col then return end
			local kind = KindOf(row.key)
			if mouse == "RightButton" then
				-- (Back to following; a bar's look or Otherwise has nothing to follow.)
				if kind ~= "group" or not (self.col.look or self.col.other) then
					SetCell(row.key, self.col, nil)
					if state.open and state.open.key == row.key and state.open.j == j then state.open = nil end
					Changed()
				end
				return
			end
			if self.col.look then
				-- (A list of its choices; a spell's first: following its tab's row.
				-- Two choices in all: the other one, a plain switch.)
				local look = LOOK[self.col.look]
				local own = LookGet(self.col.look, kind, row.key, state.tab, opts)
				local list = {}
				if kind ~= "group" then list[1] = { nil, L["Same as %s"]:format(NameOf(state.tab)) } end
				for _, value in ipairs(LookValues(self.col.look, kind)) do list[#list + 1] = { value, look.Text(value) } end
				local function Pick(value)
					SetCell(row.key, self.col, value)
					Changed()
				end
				if #list <= 2 then
					-- (Not "a and b or c": the other choice may be false.)
					if list[1][1] == own then Pick(list[2][1]) else Pick(list[1][1]) end
				else
					PickMenu(self, list, own, Pick)
				end
				return
			end
			local same = state.open and state.open.key == row.key and state.open.j == j
			state.open = not same and { key = row.key, j = j } or nil
			state.editing = nil
			Changed()
		end)
		LiveTip(cell, function(self)
			if not self.col or row.key == nil then return nil end
			-- (Only when its word can't be read: an icon alone, or cut short.
			-- On every cell they covered what you meant to click, 2026-11-22.)
			if not (self.compact or self.text:IsTruncated()) then return nil end
			local text, style = CellLook(row.key, self.col)
			local where = self.col.look and LOOK[self.col.look].label
				or self.col.other and (ns.CooldownPlaceGroups()[1] and L["Everywhere else"] or L["everywhere"])
				or ns.CooldownGroupName(self.col.group)
			local value = self.col.look and text or FULL[self.mode] or text
			local tip = ("%s, %s: %s"):format(NameOf(row.key), where, value)
			if style == "follow" then
				tip = tip .. "\n" .. (KindOf(row.key) == "group" and L["Same as Everywhere else until you set it."]
					or L["Same as the %s row until you set it."]:format(NameOf(state.tab)))
			end
			return tip .. "\n\n" .. (self.col.look and L["Click to pick. Right-click: back to following."]
				or L["Click to choose. Right-click: back to following."])
		end)
		cell:HookScript("OnEnter", function() if row.ShowTick then row.ShowTick() end end)
		cell:HookScript("OnLeave", function() if row.ShowTick then row.ShowTick() end end)
		row.cells[j] = cell
		return cell
	end
	grid.rows = rows

	-- ---------------------------------------------------------------------
	-- The choices: a small pop-up under the open cell, over the grid (a strip
	-- under the row pushed every row below down, 2026-11-22). A choice picked
	-- closes it (When ready stays, for its parts); a click anywhere else too.
	local POP_W = 208 -- (a scene's name fits on the title's line)
	local catcher = CreateFrame("Button", nil, grid)
	catcher.cdmCatcher = true -- (the lab's overlap audit leaves it out)
	catcher:SetAllPoints(grid)
	catcher:Hide()
	catcher:SetScript("OnClick", function()
		state.open = nil
		Changed()
	end)
	local chooser = CreateFrame("Frame", nil, grid)
	chooser:SetSize(POP_W, 52)
	chooser:EnableMouse(true)
	chooser.cdmPopup = true
	do
		local back = chooser:CreateTexture(nil, "BACKGROUND")
		back:SetAllPoints()
		back:SetColorTexture(0.07, 0.065, 0.06, 1) -- (solid: a pill showed through, 2026-11-22)
		for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", false }, { "BOTTOMLEFT", "BOTTOMRIGHT", false },
			{ "TOPLEFT", "BOTTOMLEFT", true }, { "TOPRIGHT", "BOTTOMRIGHT", true } }) do
			local edge = chooser:CreateTexture(nil, "BORDER")
			edge:SetPoint(side[1])
			edge:SetPoint(side[2])
			if side[3] then edge:SetWidth(1) else edge:SetHeight(1) end
			edge:SetColorTexture(1, 1, 1, 0.16)
		end
	end
	local chooserTitle = chooser:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	chooserTitle:SetPoint("TOPLEFT", chooser, "TOPLEFT", 8, -6)
	chooserTitle:SetPoint("RIGHT", chooser, "RIGHT", -24, 0)
	chooserTitle:SetJustifyH("LEFT")
	-- (Two lines: "Serpent Sting in Dungeon fi..." was cut short, 2026-11-22.)
	chooserTitle:SetWordWrap(true)
	if chooserTitle.SetMaxLines then pcall(chooserTitle.SetMaxLines, chooserTitle, 2) end
	local chooserClose = PillButton(chooser, 22, 18)
	chooserClose:SetPoint("TOPRIGHT", chooser, "TOPRIGHT", -2, -2)
	SetPill(chooserClose, nil, "x", "choice")
	chooserClose.text:SetFontObject("GameFontHighlight")
	chooserClose:SetWidth(22)
	chooserClose:SetScript("OnClick", function()
		state.open = nil
		Changed()
	end)
	local choices = {}
	local function Choice(i)
		if choices[i] then return choices[i] end
		local box = PillButton(chooser, POP_W - 12, 22)
		box:SetScript("OnClick", function(self)
			if not Enabled() or not state.open then return end
			local col = Columns()[state.open.j]
			if not col then return end
			SetCell(state.open.key, col, self.value)
			-- (Picked: shut, but for When ready: its parts are in it.)
			if self.value ~= "ready" or KindOf(state.open.key) == "buff" or col.look then state.open = nil end
			Changed()
		end)
		choices[i] = box
		return box
	end
	-- When ready's parts (a spell's or a bar's), under the choices while it's When ready.
	local readyLabel = chooser:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	-- (Inside the pop-up, two lines at most: it ran past its edge, 2026-11-22.)
	readyLabel:SetWidth(POP_W - 20)
	readyLabel:SetJustifyH("LEFT")
	readyLabel:SetText(L["When ready:"])
	-- (Toggle chips, filled while on: the game's square checkboxes were the
	-- last of its own art on the page, and the lab can't draw them. 2026-11-22.)
	local function Tick(label, tip, part)
		local check = PillButton(chooser, 200, 22)
		check.fit = true
		check.label = check.text -- (its words are its own)
		check.labelText = label
		check.on = false
		function check:SetChecked(on)
			self.on = on and true or false
			self:SetWidth(200)
			self:SetWidth(SetPill(self, nil, label, self.on and "picked" or "chip"))
		end
		function check:GetChecked() return self.on end
		Tip(check, tip)
		check:SetScript("OnClick", function(self)
			if not (Enabled() and state.open) then return end
			self:SetChecked(not self.on)
			SetReadyPart(KindOf(state.open.key), state.open.key, state.tab, part, self.on)
			Changed()
		end)
		check:SetChecked(false)
		return check
	end
	local powerTick = Tick(L["Wait for resources"], L["The icon also waits until you have the resources to cast it."], "power")
	local anyTimeTick = Tick(L["Out of fights too"], L["Out of fights, the icon also shows once it's ready."], "anyTime")
	local earlyLabel = chooser:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	earlyLabel:SetText(L["Show early (seconds)"])
	-- (A soft field like the scene name's: not the game's black box.)
	local earlyBox = CreateFrame("EditBox", nil, chooser)
	earlyBox:SetFontObject("GameFontHighlightSmall")
	earlyBox:SetTextInsets(6, 6, 0, 0)
	earlyBox:SetJustifyH("CENTER")
	earlyBox:SetSize(40, 20)
	do
		local fill = earlyBox:CreateTexture(nil, "BACKGROUND")
		fill:SetAllPoints()
		fill:SetColorTexture(1, 1, 1, 0.06)
		local under = earlyBox:CreateTexture(nil, "BORDER")
		under:SetPoint("BOTTOMLEFT")
		under:SetPoint("BOTTOMRIGHT")
		under:SetHeight(1)
		under:SetColorTexture(1, 1, 1, 0.28)
	end
	earlyBox:SetAutoFocus(false)
	earlyBox:SetNumeric(true)
	earlyBox:SetMaxLetters(4)
	Tip(earlyBox, L["How many seconds before it's ready the icon comes back. Leave empty for %d%% of its cooldown."]:format(
		(ns.READY_EARLY or 0.3) * 100))
	local function SaveEarly(self)
		self:ClearFocus()
		if not state.open then return end
		local kind = KindOf(state.open.key)
		local _, earlyOn, early = ReadyParts(kind, state.open.key, state.tab)
		local now = not earlyOn and "0" or early and tostring(early) or ""
		if self:GetText() ~= now then
			SetReadyPart(kind, state.open.key, state.tab, "early", tonumber(self:GetText()))
			Changed()
		end
	end
	earlyBox:SetScript("OnEnterPressed", SaveEarly)
	earlyBox:SetScript("OnEditFocusLost", function(self)
		if self.saving then return end
		self.saving = true
		SaveEarly(self)
		self.saving = nil
	end)
	grid.chooser, grid.choices = chooser, choices
	-- (In the page's view: under the cell it ran past the view's bottom, cut,
	-- the user's shot 2026-11-23. Above the cell when it fits there; else the
	-- page scrolls down till it fits under. On grid: Layout is at Lua's
	-- 60-upvalue cap, a new local here would be one more.)
	grid.FitChooser = function(cell, right, height)
		local scroll = grid:GetParent()
		while scroll and not scroll.GetVerticalScroll do scroll = scroll:GetParent() end
		if not scroll then return end
		local s, v = cell:GetEffectiveScale(), scroll:GetEffectiveScale()
		local top, bottom = cell:GetTop(), cell:GetBottom()
		local viewTop, viewBottom = scroll:GetTop(), scroll:GetBottom()
		for _, n in ipairs({ top or 0, bottom or 0, viewTop or 0, viewBottom or 0, s or 0, v or 0 }) do
			if type(n) ~= "number" then return end
		end
		if not (top and bottom and viewTop and viewBottom and s and v) then return end
		local need = (height + 2) * chooser:GetEffectiveScale()
		local below = bottom * s - viewBottom * v
		local above = viewTop * v - top * s
		if below >= need then return end
		if above >= need then
			chooser:ClearAllPoints()
			if right then
				chooser:SetPoint("BOTTOMRIGHT", cell, "TOPRIGHT", 0, 2)
			else
				chooser:SetPoint("BOTTOMLEFT", cell, "TOPLEFT", 0, 2)
			end
			return "above"
		end
		-- (Next frame: the grid's new height sets the scroll range first.)
		local by = (need - below) / v + 4
		C_Timer.After(0, function()
			local range = scroll:GetVerticalScrollRange() or 0
			scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll() + by, range))
		end)
		return "scroll"
	end
	grid.readyParts = { power = powerTick, anyTime = anyTimeTick, early = earlyBox }

	-- A row's Otherwise if it had none of its own (its bar's, or the Smart
	-- pick): its own mode set aside a moment, read, put back.
	local OWN_TABLES = { "cooldownReadyOnly", "cooldownRechargeOnly", "cooldownProcOnly", "cooldownAlwaysShow", "cooldownNeverShow" }
	function FollowedOtherwise(kind, key)
		local d = db()
		if kind == "buff" then
			local kept = d.cooldownBuffMode[key]
			d.cooldownBuffMode[key] = nil
			-- (pcall: an error there mustn't lose the row's own setting.
			-- Audit 2026-11-22.)
			local ok, mode = pcall(ns.CooldownBuffMode, key, state.tab, false)
			d.cooldownBuffMode[key] = kept
			return ok and mode or nil
		end
		local kept = {}
		for i, name in ipairs(OWN_TABLES) do kept[i] = d[name][key] d[name][key] = nil end
		local ok, mode = pcall(ns.CooldownSpellMode, key, state.tab, false)
		for i, name in ipairs(OWN_TABLES) do d[name][key] = kept[i] end
		return ok and mode or nil
	end
	local function ChooserShow(key, col)
		local kind = KindOf(key)
		local list = {}
		local followed
		if not col.other or kind ~= "group" then
			-- (What it follows, by name, first.)
			local follows, followed
			if kind == "group" then
				followed = (OtherwiseOf(kind, key, state.tab))
				follows = L["As everywhere else (%s)"]:format(SHORT[followed] or "?")
			else
				-- (What it would be with nothing of its own here: its bar's cell,
				-- else its own Otherwise; in Otherwise, its bar's or the Smart
				-- pick. "Same as bar" said the bar's when it wasn't. Audit, 2026-11-22.)
				local barCell = not col.other and ns.CooldownCell("group", state.tab, col.id)
				if col.other then
					followed = FollowedOtherwise(kind, key)
					follows = L["Default (%s)"]:format(SHORT[followed] or "?")
				elseif barCell then
					followed = barCell
					-- (The tab's name: "bar" meant nothing, 2026-11-22.)
					follows = L["Same as %s (%s)"]:format(NameOf(state.tab), SHORT[followed] or "?")
				else
					followed = (OtherwiseOf(kind, key, state.tab))
					follows = L["As everywhere else (%s)"]:format(SHORT[followed] or "?")
				end
			end
			list[1] = { nil, follows, followed }
		else
			local set = db().cooldownGroupDefaults[key]
			if not (set and set.mode) then
				followed = (OtherwiseOf(kind, key, state.tab))
				list[1] = { nil, L["Default (%s)"]:format(SHORT[followed] or "?"), followed }
			end
		end
		local _, _, current = CellLook(key, col)
		for _, mode in ipairs(ModesFor(current, key)) do list[#list + 1] = { mode[1], mode[2] } end
		local _, _, own = CellLook(key, col)
		local where = col.other and (ns.CooldownPlaceGroups()[1] and L["Everywhere else"] or L["everywhere"])
			or ns.CooldownGroupName(col.group)
		-- (No scenes: the spell's name alone, not "in everywhere".)
		-- (Its width set first, so how many lines it takes is known: the
		-- second line was measured as none and cut, run 21.)
		chooserTitle:SetWidth(POP_W - 32)
		chooserTitle:SetText(ns.CooldownPlaceGroups()[1] and L["%s in %s"]:format(NameOf(key), where) or NameOf(key))
		-- (One under another, a pill each in its choice's color; the one set has its band.)
		local titleH = chooserTitle:GetStringHeight()
		titleH = type(titleH) == "number" and titleH > 0 and titleH or 12
		local y = -8 - titleH - 6
		for i, item in ipairs(list) do
			local box = Choice(i)
			box.value = item[1]
			local chosen = (item[1] == nil and own == nil) or (item[1] ~= nil and own == item[1])
			box:SetWidth(POP_W - 12)
			-- (Picked: filled light, dark words: a grey band read as the hover's.)
			SetPill(box, item[3] or item[1], item[2], chosen and "picked" or (item[1] == nil and "follow" or "choice"))
			box:ClearAllPoints()
			box:SetPoint("TOPLEFT", chooser, "TOPLEFT", 6, y)
			box:Show()
			y = y - 22
		end
		for i = #list + 1, #choices do choices[i]:Hide() end
		y = y - 4
		-- (When ready's parts, while this cell says When ready.)
		local mode = col.other and (OtherwiseOf(kind, key, state.tab)) or (CellOf(kind, key, state.tab, col.id))
		local ready = mode == "ready" and kind ~= "buff"
		for _, part in ipairs({ readyLabel, powerTick, anyTimeTick, earlyLabel, earlyBox }) do
			part:SetShown(ready)
		end
		if ready then
			local power, earlyOn, early, anyTime = ReadyParts(kind, key, state.tab)
			-- (One under another, under a hairline.)
			readyLabel:SetText(kind == "group" and L["When ready, for all of %s:"]:format(NameOf(state.tab))
				or L["When ready, for this spell everywhere:"])
			readyLabel:ClearAllPoints()
			readyLabel:SetPoint("TOPLEFT", chooser, "TOPLEFT", 10, y - 2)
			local labelH = readyLabel:GetStringHeight()
			y = y - 6 - (type(labelH) == "number" and labelH > 0 and labelH or 10)
			powerTick:ClearAllPoints()
			powerTick:SetPoint("TOPLEFT", chooser, "TOPLEFT", 6, y)
			powerTick:SetChecked(power and true or false)
			y = y - 24
			-- (Out of fights too: only while on, to turn it off. An Out of combat
			-- scene says it now; two ways round confused, 2026-11-22.)
			anyTimeTick:SetShown(anyTime and true or false)
			if anyTime then
				anyTimeTick:ClearAllPoints()
				anyTimeTick:SetPoint("TOPLEFT", chooser, "TOPLEFT", 6, y)
				anyTimeTick:SetChecked(true)
				y = y - 26
			else
				y = y - 2
			end
			earlyLabel:ClearAllPoints()
			earlyLabel:SetPoint("TOPLEFT", chooser, "TOPLEFT", 10, y - 5)
			earlyBox:ClearAllPoints()
			earlyBox:SetPoint("LEFT", earlyLabel, "RIGHT", 8, 0)
			if not earlyBox:HasFocus() then earlyBox:SetText(not earlyOn and "0" or early and tostring(early) or "") end
			y = y - 24
		end
		chooser:SetHeight(-y + 4)
		-- (Over the grid: above its cells, the catcher just under it.)
		chooser:SetFrameLevel(grid:GetFrameLevel() + 40)
		catcher:SetFrameLevel(grid:GetFrameLevel() + 39)
		catcher:Show()
		chooser:Show()
		return chooser:GetHeight()
	end

	-- ---------------------------------------------------------------------
	-- The ticked rows' bar: set one column of them all, copy a row, paste it.
	local bulk = CreateFrame("Frame", nil, grid)
	bulk:SetSize(WIDTH, 28)
	do
		local back = bulk:CreateTexture(nil, "BACKGROUND")
		back:SetAllPoints()
		back:SetColorTexture(0.11, 0.105, 0.095, 0.97)
	end
	local bulkCount = bulk:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	bulkCount:SetPoint("LEFT", bulk, "LEFT", 8, 0)
	bulkCount:SetTextColor(WHITE[1], WHITE[2], WHITE[3]) -- (no gold: the last of it, 2026-11-22)
	local function BulkButton(width, tip, onClick)
		local box = PillButton(bulk, width, 22)
		box.fit = true
		Tip(box, tip)
		box:SetScript("OnClick", function(self, mouse)
			if Enabled() then onClick(self, mouse) end
		end)
		return box
	end
	-- (Each a button stepping round its list: right-click steps back.)
	local function BulkValues()
		local cols = Columns()
		local col = cols[state.bulkCol] or cols[1]
		local list = { { nil, L["Same as %s"]:format(NameOf(state.tab)) } }
		if not col then return col, list end
		if col.look then
			for _, value in ipairs(LookValues(col.look, "spell")) do list[#list + 1] = { value, LOOK[col.look].Text(value) } end
		else
			for _, mode in ipairs(ModesFor()) do list[#list + 1] = { mode[1], SHORT[mode[1]] } end
		end
		return col, list
	end
	-- (Lists to pick from: they went to the next each click, 2026-11-22.)
	local bulkCol = BulkButton(110, L["Which scene to set."], function(self)
		local items = {}
		for j, col in ipairs(Columns()) do
			items[j] = { j, col.look and LOOK[col.look].label or col.other and L["Everywhere else"] or ns.CooldownGroupName(col.group) }
		end
		PickMenu(self, items, state.bulkCol, function(j)
			state.bulkCol, state.bulkValue = j, 1
			Layout()
		end)
	end)
	local bulkValue = BulkButton(90, L["What to set it to."], function(self)
		local _, list = BulkValues()
		local items = {}
		for k, item in ipairs(list) do items[k] = { k, item[2] } end
		PickMenu(self, items, state.bulkValue, function(k)
			state.bulkValue = k
			Layout()
		end)
	end)
	local bulkSet = BulkButton(40, L["Sets it on every ticked spell."], function()
		local col, list = BulkValues()
		if not col then return end
		local value = (list[state.bulkValue] or list[1])[1]
		for key in pairs(state.selected) do SetCell(key, col, value) end
		Changed()
	end)
	-- Lights rows a moment (keys a set), then the grid as it was.
	local function Flash(keys, color)
		state.flash = { keys = keys, color = color }
		Layout()
		local mine = state.flash
		C_Timer.After(1.2, function()
			if state.flash ~= mine then return end
			state.flash, state.pasted = nil, nil
			if grid:IsShown() then Layout() end
		end)
	end
	local bulkCopy = BulkButton(70, L["Copies everything set on this spell."], function()
		local key = next(state.selected)
		if key == nil then return end
		local kind = KindOf(key)
		local d = db()
		local clip = { kind = kind, cells = ns.CooldownCellsOf(kind, key), look = {}, name = NameOf(key) }
		local _, own = OtherwiseOf(kind, key, state.tab)
		clip.mode = own and (OtherwiseOf(kind, key, state.tab)) or nil
		for _, what in ipairs({ "numbers", "keybinds", "notBuff" }) do clip.look[what] = ns.CooldownRowOwn(key, what) end
		clip.flash = d.cooldownFlashReady[key]
		-- (Its own When ready parts too: they were left behind, and the paste
		-- took its bar's. Audit, 2026-11-22.)
		local partsKey = kind == "spell" and OwnReadyKey(key)
		if partsKey then
			clip.parts = { d.cooldownNeedsPower[partsKey], d.cooldownEarlyOn[partsKey], d.cooldownReadyEarly[partsKey],
				d.cooldownReadyAnyTime[partsKey] }
		end
		clip.key = key
		state.clip = clip
		Flash({ [key] = true }, PREVIEW_BLUE)
	end)
	local bulkPaste = BulkButton(80, L["Gives the ticked spells everything set on the copied one."], function()
		local clip = state.clip
		if not clip then return end
		local d = db()
		local pasted, count = {}, 0
		for key in pairs(state.selected) do
			if KindOf(key) == clip.kind and key ~= clip.key then
				pasted[key], count = true, count + 1
				-- (Only cells of scenes still there: a deleted one's id can come back.)
				local cells = {}
				for id, mode in pairs(clip.cells) do
					if ns.CooldownPlaceGroup(id) then cells[id] = mode end
				end
				ns.SetCooldownCells(clip.kind, key, cells)
				SetOtherwise(clip.kind, key, state.tab, clip.mode)
				if clip.kind == "spell" then
					local p = clip.parts or {}
					d.cooldownNeedsPower[key], d.cooldownEarlyOn[key] = p[1], p[2]
					d.cooldownReadyEarly[key], d.cooldownReadyAnyTime[key] = p[3], p[4]
				end
				for what, value in pairs(clip.look) do ns.SetCooldownRow(key, what, value) end
				for _, what in ipairs({ "numbers", "keybinds", "notBuff" }) do
					if clip.look[what] == nil then ns.SetCooldownRow(key, what, nil) end
				end
				if clip.kind == "spell" then d.cooldownFlashReady[key] = clip.flash end
			end
		end
		if ns.ApplyCooldownNumbers then ns.ApplyCooldownNumbers() end
		if ns.ApplyCooldownKeybinds then ns.ApplyCooldownKeybinds() end
		state.pasted = count
		Changed()
		Flash(pasted, MODE_COLOR.ready)
	end)
	-- (Buffs: the ticked ones made one group that counts as one, in the
	-- page's order; one group ticked alone, split back. Mockup B, 2026-11-23.)
	local function TickedGroup()
		local only
		for key in pairs(state.selected) do
			if key ~= state.tab then
				if only then return nil end
				only = key
			end
		end
		return only and IsGroup(only) and only or nil
	end
	local bulkGroup = BulkButton(110, L["Makes the ticked buffs count as one: any of them on you is enough."], function()
		local lead = TickedGroup()
		if lead then
			ns.UngroupCooldownBuff(lead)
		else
			local ids = {}
			for _, key in ipairs(grid.RowKeys()) do
				if state.selected[key] then ids[#ids + 1] = key end
			end
			if #ids < 2 then return end
			ns.SetCooldownBuffGroup(ids)
		end
		wipe(state.selected)
		Changed()
	end)
	local bulkClear = BulkButton(20, L["Unticks every spell."], function()
		wipe(state.selected)
		Changed()
	end)
	SetPill(bulkClear, nil, "x", "choice")
	bulkClear:SetPoint("RIGHT", bulk, "RIGHT", -4, 0)
	bulkPaste:SetPoint("RIGHT", bulkClear, "LEFT", -4, 0)
	bulkCopy:SetPoint("RIGHT", bulkPaste, "LEFT", -4, 0)
	local inLabel = bulk:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	inLabel:SetText(L["Set"])
	inLabel:SetPoint("LEFT", bulk, "LEFT", 72, 0)
	bulkCol:SetPoint("LEFT", inLabel, "RIGHT", 6, 0)
	local toLabel = bulk:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	toLabel:SetText(L["to"])
	toLabel:SetPoint("LEFT", bulkCol, "RIGHT", 6, 0)
	bulkValue:SetPoint("LEFT", toLabel, "RIGHT", 6, 0)
	bulkSet:SetPoint("LEFT", bulkValue, "RIGHT", 4, 0)
	grid.bulk = bulk
	grid.bulkButtons = { col = bulkCol, value = bulkValue, set = bulkSet, copy = bulkCopy, paste = bulkPaste, clear = bulkClear,
		group = bulkGroup }
	local function BulkShow()
		local count = 0
		for key in pairs(state.selected) do
			if key ~= state.tab then count = count + 1 end
		end
		bulk:SetShown(count > 0)
		if count == 0 then return 0 end
		bulkCount:SetText(L["%d ticked"]:format(count))
		local col, list = BulkValues()
		local name = not col and "?" or col.look and LOOK[col.look].label or col.other and L["Everywhere else"]
			or ns.CooldownGroupName(col.group)
		-- (Each as wide as its words.)
		local function Put(box, text, how, mode)
			box:SetWidth(160)
			box:SetWidth(SetPill(box, mode, text, how))
		end
		local value = list[state.bulkValue] or list[1]
		Put(bulkCol, name, "own")
		-- (A chip even for Same as bar: faint words alone didn't read as a button.)
		Put(bulkValue, value[2], value[1] and "own" or "chip", not col.look and value[1] or nil)
		Put(bulkSet, L["Apply"], "picked")
		bulkCopy:SetShown(count == 1)
		-- (Says what happened: "Copied" while the copied row is the one
		-- ticked; Paste names what it puts, then how many it changed.)
		local copied = state.clip and count == 1 and state.selected[state.clip.key]
		Put(bulkCopy, copied and L["Copied"] or L["Copy row"], copied and "picked" or "chip")
		local onOthers = false
		for key in pairs(state.selected) do
			if state.clip and key ~= state.clip.key and key ~= state.tab then onOthers = true end
		end
		bulkPaste:SetShown(state.clip ~= nil and (onOthers or state.pasted ~= nil))
		if state.clip then
			local name = state.clip.name or ""
			if #name > 18 then name = name:sub(1, 16) .. "..." end
			Put(bulkPaste, state.pasted and L["Pasted on %d"]:format(state.pasted) or L["Paste %s"]:format(name),
				state.pasted and "picked" or "chip")
		end
		-- (Buffs: Count as one buff with two or more ticked; Ungroup with one group.)
		local ungroup = TickedGroup()
		bulkGroup:SetShown(BUFF_TAB[state.tab] and ns.SetCooldownBuffGroup ~= nil and (count >= 2 or ungroup ~= nil) or false)
		if bulkGroup:IsShown() then
			Put(bulkGroup, ungroup and L["Ungroup"] or L["Count as one buff"], "chip")
		end
		-- (From the right: x, then Paste, Copy and the group button where shown.
		-- Copy sat on Apply while hidden Paste kept its place, CDM lab 2026-11-22.)
		local last = bulkClear
		for _, button in ipairs({ bulkPaste, bulkCopy, bulkGroup }) do
			if button:IsShown() then
				button:ClearAllPoints()
				button:SetPoint("RIGHT", last, "LEFT", -4, 0)
				last = button
			end
		end
		return bulk:GetHeight()
	end

	-- In Look: the bar's own looks (Close the gaps...) on a line under the grid.
	local extras = CreateFrame("Frame", nil, grid)
	extras:SetSize(WIDTH, 24)
	local extrasLabel = extras:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	extrasLabel:SetPoint("LEFT", extras, "LEFT", 0, 0)
	local extraParts = {}
	local function ExtrasShow()
		local list = state.look and BAR_EXTRAS[state.tab]
		-- (The tab's name, not "This bar:": the user, 2026-11-22.)
		extrasLabel:SetText(NameOf(state.tab) .. ":")
		-- (list is false out of Look: "~= nil" left "This bar:" showing under
		-- the grid after Look, cdmgrid run 2.)
		extras:SetShown(list and true or false)
		for _, part in pairs(extraParts) do
			part.label:Hide()
			part.box:Hide()
		end
		if not list then return 0 end
		local x = 70
		for _, what in ipairs(list) do
			local part = extraParts[what]
			if not part then
				-- (Pills like the grid's: gold boxes here were the last of the old look, 2026-11-22.)
				part = { label = extras:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"), box = PillButton(extras, 90, 22) }
				part.label:SetText(LOOK[what].label)
				Tip(part.box, LOOK[what].tip)
				part.box:SetScript("OnClick", function(self)
					if not Enabled() then return end
					local list = {}
					for _, value in ipairs(LookValues(what, "group")) do list[#list + 1] = { value, LOOK[what].Text(value) } end
					local now = LookGet(what, "group", state.tab, state.tab, opts)
					local function Pick(value)
						LookSet(what, "group", state.tab, value, opts)
						Changed()
					end
					-- (Two choices: a switch; more: a list.)
					if #list > 2 then PickMenu(self, list, now, Pick)
					elseif list[1][1] == now then Pick(list[2][1]) -- (not "a and b or c": the other may be false)
					else Pick(list[1][1]) end
				end)
				extraParts[what] = part
			end
			part.label:ClearAllPoints()
			part.label:SetPoint("LEFT", extras, "LEFT", x, 0)
			part.label:Show()
			x = x + (part.label:GetStringWidth() or 100) + 6
			part.box:ClearAllPoints()
			part.box:SetPoint("LEFT", extras, "LEFT", x, 0)
			part.box:SetWidth(90)
			part.box:SetWidth(SetPill(part.box, nil, LOOK[what].Text(LookGet(what, "group", state.tab, state.tab, opts)), "bar"))
			part.box:Show()
			x = x + part.box:GetWidth() + 14
		end
		return extras:GetHeight()
	end
	grid.extraParts, grid.extras = extraParts, extras


	-- ---------------------------------------------------------------------
	-- Lays it all out from the top; gives the height.
	function Layout()
		local cols = Columns()
		local n = #cols
		local noLook = NO_LOOK[state.tab]
		if noLook then state.look = false end
		showsSwitch:SetShown(not noLook)
		lookSwitch:SetShown(not noLook)
		tabBase:SetShown(not noLook)
		PaintTab(showsSwitch, L["When it shows"], not state.look)
		PaintTab(lookSwitch, L["Look"], state.look)
		-- (Room as wide as what's beside it: + Add scene isn't there in Look.)
		-- (No hint line: it said what the page already shows. The user,
		-- 2026-11-22: "i dont see the point of these texts".)
		hint:Hide()
		local groups = ns.CooldownPlaceGroups()
		-- (No card with no scenes: + Add scene alone, by the tabs. The user,
		-- 2026-11-22: "this bar is unneeded, just add scene is good".)
		local cardShown = false
		local plusShown = not state.look and #groups < ns.COOLDOWN_GROUP_MAX
		local free = WIDTH - CHECK_W - NAME_W - GAP * 2
		local colW = math.min(COL_MAX, math.floor((free - GAP * (n - 1)) / math.max(n, 1)))
		-- (The last column's heading, "Everywhere else", needs its word's room:
		-- with nine scenes it ran into the one beside it, CDM lab 2026-11-22.
		-- The others give it up.)
		-- (84 written here: this function is at Lua's 60-upvalue cap. 84: the
		-- word "Everywhere" beside the in-use dot; at 72 the game cut it to
		-- "Everywh...", five scenes, 2026-11-22.)
		-- (72 past six columns: with nine scenes 84 left the others too narrow
		-- for "Scene", the CDM lab.)
		local otherW = colW
		local least = n <= 6 and 84 or 72
		if n > 1 and cols[n].other and colW < least then
			otherW = least
			colW = math.floor((free - least - GAP * (n - 1)) / (n - 1))
		end
		local function ColW(j) return j == n and otherW or colW end
		-- (Too narrow for its words, 4 or 5 scenes: each cell its icon alone.)
		local compact = colW < COMPACT_W
		local x0 = CHECK_W + GAP + NAME_W + GAP
		local function ColX(j) return x0 + (j - 1) * (colW + GAP) end
		grid.layout = { colW = colW, plusShown = plusShown, cardShown = cardShown, x0 = x0, compact = compact }
		local y = -30
		-- With no groups: the card saying what they are.
		addCard:SetShown(cardShown)
		local previewing = ns.CooldownPreview and ns.CooldownPreview()
		if previewing and (state.look or not groups[1]) then previewing = nil end
		banner:SetShown(previewing and true or false)
		if previewing then
			local now = ns.CooldownGroupNow()
			banner.text:SetText(L["Previewing %s: %s decides. Your icons show it now."]:format(previewing.label,
				now and ns.CooldownGroupName(now) or L["Everywhere else"]))
			banner.back:SetWidth(120)
			banner.back:SetWidth(SetPill(banner.back, nil, L["Back to live"], "chip"))
			banner:ClearAllPoints()
			banner:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, y)
			y = y - banner:GetHeight() - 6
		end
		if cardShown then
			addCard:ClearAllPoints()
			addCard:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, y)
			y = y - addCard:GetHeight() - 8
		end
		-- Headings, then the gold line under them.
		-- (The heading row has no Spell word: SPELLS is over the spells, under the bar's card.)
		spellHead:Hide()
		spellHead:ClearAllPoints()
		spellHead:SetPoint("BOTTOMLEFT", grid, "TOPLEFT", CHECK_W + GAP, y - HEAD_H + 5)
		-- (Full height when a heading has a note under its name, or names may
		-- wrap; one line's room else. At one line's, "Scene 1" and "pick
		-- places" lay on each other: the CDM lab, 2026-11-22.)
		local noted = false
		if not compact and not state.look then
			local tr = ns.CooldownGroupTrouble()
			for i in ipairs(groups) do noted = noted or tr[i] ~= nil end
		end
		local headH = (compact or noted) and HEAD_H or HEAD_H - 10
		local _, nowIndex = ns.CooldownGroupNow()
		local trouble, otherDead = ns.CooldownGroupTrouble()
		-- (Narrow columns and a name longer than they hold: every scene by its
		-- number, its name in its tooltip. A player's nine scenes from the old
		-- lines read "gr...", "Cit...", one over another, 2026-11-23.)
		local numbered = false
		if compact and not state.look and groups[1] then
			local probe = Head(1).text
			probe:SetWordWrap(false)
			local room = colW - 8
			for _, group in ipairs(groups) do
				local name = ns.CooldownGroupName(group)
				probe:SetText(name)
				local whole, longest = probe:GetStringWidth() or 0, 0
				for word in name:gmatch("%S+") do
					probe:SetText(word)
					longest = math.max(longest, probe:GetStringWidth() or 0)
				end
				if longest > room or whole > room * 2 - 8 then
					numbered = true
					break
				end
			end
		end
		local bandsTop = y
		for j, col in ipairs(cols) do
			local head = Head(j)
			head.col = col
			-- (As tall as the room the row takes: at HEAD_H over a shorter row
			-- they lay over the bar's cells and took their clicks. CDM lab, 2026-11-22.)
			local colW = ColW(j)
			head:SetSize(colW, headH)
			head:ClearAllPoints()
			head:SetPoint("TOPLEFT", grid, "TOPLEFT", ColX(j), y)
			local name
			local sub, dot = "", false
			local r, g, b = WHITE[1], WHITE[2], WHITE[3]
			if col.look then
				name = LOOK[col.look].label
			elseif col.other then
				-- (No scenes: nothing to be "otherwise" to; just what it shows. The user, 2026-11-22.)
				-- ("Otherwise" alone meant nothing, the user 2026-11-22.)
				name = groups[1] and L["Everywhere else"] or L["Shows"]
				r, g, b = GREY[1], GREY[2], GREY[3]
				-- (In use: said only once there's a group it could be told from.)
				dot = groups[1] ~= nil and nowIndex == nil and not otherDead
				-- (Narrow: no note under it, as the scenes'; the warning line says it.
				-- "never appli..." under "Everywhere...", the player's shot 2026-11-23.)
				if otherDead then r, g, b, sub = AMBER[1], AMBER[2], AMBER[3], compact and "" or L["never applies"] end
			else
				-- (Its places in its tooltip: under every name they cluttered the headings.)
				name = numbered and tostring(col.index) or ns.CooldownGroupName(col.group)
				dot = nowIndex == col.index
				local t = trouble[col.index]
				if t then
					r, g, b = AMBER[1], AMBER[2], AMBER[3]
					-- (Narrow columns: no note under it, both were cut short; the
					-- amber name and the warning lines under the headings say it.)
					sub = compact and "" or (t.kind == "todo" and L["pick places"] or L["never applies"])
				end
			end
			-- (Icons alone: the places line is hidden, so the name may take two lines.)
			-- (Two lines only with nothing under it: "pick places" sat on a wrapped name, 2026-11-22.)
			local twoLines = compact and not col.look and sub == ""
			head.text:SetWordWrap(twoLines)
			if head.text.SetMaxLines then pcall(head.text.SetMaxLines, head.text, twoLines and 2 or 1) end
			head.text:SetText(name)
			head.text:SetTextColor(r, g, b)
			head.sub:SetText(sub)
			head.sub:SetTextColor(AMBER[1], AMBER[2], AMBER[3])
			head.sub:SetShown(sub ~= "")
			-- (Scenes only, and not when the name is already its number.)
			local order = not col.look and not col.other and not numbered and col.index or nil
			head.order:SetText(order and tostring(order) or "")
			head.order:SetShown(order ~= nil)
			-- (The in-use dot right after the name: at the heading's far edge it
			-- floated away from it, 2026-11-22.)
			-- (After the name when it fits on a line; a wrapped name's would sit
			-- at the column's edge, against the next heading: then before it,
			-- the name moved over. The CDM lab, 2026-11-22.)
			local nameW = head.text:GetStringWidth()
			nameW = type(nameW) == "number" and nameW or 0
			-- (Centered, as the cells under it; the dot right after the name.
			-- Previewing: no dot, the column's band says it; it took the
			-- name's room, "Test: dungeon fig...", 2026-11-22.)
			local previewCol = previewing and ((nowIndex and col.index == nowIndex) or (not nowIndex and col.other))
			if previewing then dot = false end
			local before = dot and nameW > colW - 16
			head.text:ClearAllPoints()
			head.text:SetPoint("TOPLEFT", head, "TOPLEFT", before and 12 or 4, -6)
			head.text:SetPoint("TOPRIGHT", head, "TOPRIGHT", -4, -6)
			head.sub:SetJustifyH("CENTER")
			head.dot:ClearAllPoints()
			if before then
				head.dot:SetPoint("LEFT", head, "TOPLEFT", 2, -11)
			else
				head.dot:SetPoint("LEFT", head, "TOPLEFT", math.floor(colW / 2 + math.min(nameW, colW - 14) / 2) + 5, -11)
			end
			head.dot:SetShown(dot and true or false)
			head.back:SetShown((col.id ~= nil and state.editing == col.id) or previewCol and true or false)
			if previewCol then
				head.back:SetColorTexture(PREVIEW_BLUE[1], PREVIEW_BLUE[2], PREVIEW_BLUE[3], 0.14)
				head.text:SetTextColor(0.85, 0.93, 1)
			else
				head.back:SetColorTexture(1, 1, 1, 0.06)
			end
			head.under:SetShown(col.id ~= nil and state.editing == col.id)
			head:Show()
		end
		-- (The row as tall as its tallest heading: a two-line name and its note
		-- ran past it, and the warning lines under the row lay on them, 2026-11-23.)
		local needH = headH
		for j = 1, n do
			local head = heads[j]
			local h = 6 + (head.text:GetStringHeight() or 12) + 4
			if head.sub:IsShown() then h = h + (head.sub:GetStringHeight() or 10) + 7 end
			needH = math.max(needH, math.ceil(h))
		end
		if needH > headH then
			headH = needH
			for j = 1, n do heads[j]:SetHeight(headH) end
		end
		for j = n + 1, #heads do heads[j]:Hide() end
		plus:SetShown(plusShown)
		if plusShown then
			-- (Up by the tabs: a column of its own took room the scenes need, 2026-11-22.)
			plus:SetSize(ADD_W, PILL_H + 4)
			plus:SetWidth(SetPill(plus, "add", L["Add scene"], "chip"))
		end
		local preview = ns.CooldownPreview and ns.CooldownPreview()
		previewButton:SetShown(not state.look and groups[1] ~= nil)
		if not groups[1] then previewMenu:Hide() end
		previewButton:SetWidth(200)
		-- (No icon: the eye is Always's, it read as a setting, 2026-11-22.)
		if previewMenu:IsShown() and grid.PaintPreviewItems then grid.PaintPreviewItems() end
		previewButton:SetWidth(SetPill(previewButton, nil, preview and L["Preview: %s"]:format(preview.label)
			or L["Preview a place"], preview and "chosen" or "chip"))
		if preview then
			previewButton.text:SetTextColor(0.85, 0.93, 1)
			previewButton.icon:SetVertexColor(0.85, 0.93, 1)
			for _, t in pairs(previewButton.band) do t:SetVertexColor(PREVIEW_BLUE[1], PREVIEW_BLUE[2], PREVIEW_BLUE[3], 0.28) end
		end
		selectButton:SetShown(not state.look)
		if not state.look then
			selectButton:SetWidth(120)
			selectButton:SetWidth(SetPill(selectButton, nil, state.selecting and L["Done"] or L["Select rows"],
				state.selecting and "picked" or "chip"))
		end
		-- (One row of actions from the left, the view tabs on the right: spread
		-- over both ends with Preview alone on the left, it read as clutter.)
		local lastAction
		for _, button in ipairs({ previewButton, plus, selectButton }) do
			if button:IsShown() then
				button:ClearAllPoints()
				if lastAction then
					button:SetPoint("LEFT", lastAction, "RIGHT", 6, 0)
				else
					button:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, 1)
				end
				lastAction = button
			end
		end
		-- (No line under the headings: the bar's card under them is the edge;
		-- a line and the card's top made a double rule with a gap, 2026-11-22.
		-- One-line names: the room for a second line taken back.)
		y = y - headH
		headLine:Hide()
		-- The editor.
		local edited = EditorShow()
		if edited > 0 then
			editor:ClearAllPoints()
			editor:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, y)
			y = y - edited - GAP
		end
		-- Trouble lines.
		local count = 0
		if not state.look then
			-- (Scenes with no places: one line for them all; one each never used.)
			local todo, dead = {}, {}
			for i, group in ipairs(groups) do
				local t = trouble[i]
				if t and t.kind == "dead" then
					dead[#dead + 1] = { ns.CooldownGroupName(group), t.by }
				elseif t then
					todo[#todo + 1] = ns.CooldownGroupName(group)
				end
			end
			-- (One line each for one or two; one line for more: seven of them
			-- were a wall, the CDM lab, 2026-11-22.)
			if dead[3] then
				local names = {}
				for i, each in ipairs(dead) do names[i] = each[1] end
				count = count + 1
				TroubleLine(count):SetText(L["%s never apply: scenes further left already cover their places."]:format(
					table.concat(names, ", ")))
			else
				for _, each in ipairs(dead) do
					count = count + 1
					TroubleLine(count):SetText((#each[2] == 1 and L["%s never applies: %s already covers every place and time it has."]
						or L["%s never applies: %s already cover every place and time it has."]):format(each[1], table.concat(each[2], ", ")))
				end
			end
			-- (Scenes with no places: said under their names when there's room;
			-- the line only for narrow columns, where it isn't. Twice was too much.)
			if todo[1] and compact then
				count = count + 1
				TroubleLine(count):SetText((#todo == 1 and L["%s has no places yet: click its heading to pick some."]
					or L["%s have no places yet: click a heading to pick some."]):format(table.concat(todo, ", ")))
			end
			if otherDead then
				count = count + 1
				TroubleLine(count):SetText(L["Everywhere else is never used: the scenes take every place, in and out of combat."])
			end
		end
		for i, line in ipairs(troubleLines) do
			if i <= count then
				line:ClearAllPoints()
				-- (First one a little lower: two-line headings, nine scenes, sat on it. CDM lab.)
				local gap = i == 1 and compact and 6 or 2
				line:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, y - gap)
				line:Show()
				y = y - (line:GetStringHeight() or 12) - gap - 2
			else
				line:Hide()
			end
		end
		-- Rows: the bar's (a gold band), then each spell's.
		local keys = { state.tab }
		for _, key in ipairs(grid.RowKeys()) do keys[#keys + 1] = key end
		local openShown = false
		local openCell, openX, openBottom
		-- (Which column decides for a row while previewing: its own cell for the
		-- scene in use, else the bar's (a spell), else Otherwise.)
		local _, nowAt = ns.CooldownGroupNow()
		local function DecideAt(key)
			local kind = KindOf(key)
			if nowAt then
				local id = cols[nowAt] and cols[nowAt].id
				if id and (ns.CooldownCell(kind, key, id) or (kind ~= "group" and ns.CooldownCell("group", state.tab, id))) then
					return nowAt
				end
			end
			return n
		end
		-- (The bar's row on a raised card of its own, then a SPELLS label and
		-- the spells: as one more row it looked like a spell, and a tree under
		-- it didn't do, 2026-11-22. Mockup J.)
		if not grid.barCard then
			grid.barCard = CreateFrame("Frame", nil, grid)
			local fill = grid.barCard:CreateTexture(nil, "BACKGROUND")
			fill:SetAllPoints()
			fill:SetColorTexture(0.135, 0.13, 0.115, 1)
			for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", false }, { "BOTTOMLEFT", "BOTTOMRIGHT", false },
				{ "TOPLEFT", "BOTTOMLEFT", true }, { "TOPRIGHT", "BOTTOMRIGHT", true } }) do
				local edge = grid.barCard:CreateTexture(nil, "BORDER")
				edge:SetPoint(side[1])
				edge:SetPoint(side[2])
				if side[3] then edge:SetWidth(1) else edge:SetHeight(1) end
				edge:SetColorTexture(1, 1, 1, 0.16)
			end
			grid.barCard:SetFrameLevel(grid:GetFrameLevel())
			grid.spellsLabel = grid:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
			grid.spellsLabel:SetText(L["Spells"]:upper())
		end
		for i, key in ipairs(keys) do
			local row = Row(i)
			row.key = key
			local isBar = key == state.tab
			local subText, subShort = grid.SubLine(key)
			local rowH = (isBar or subText) and BAR_H or ROW_H
			local decideAt = previewing and DecideAt(key)
			row.band:ClearAllPoints()
			row.band:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, y)
			row.band:SetSize(WIDTH, rowH)
			local lit = state.flash and state.flash.keys[key]
			row.flash:ClearAllPoints()
			row.flash:SetAllPoints(row.band)
			if lit then row.flash:SetColorTexture(state.flash.color[1], state.flash.color[2], state.flash.color[3], 0.22) end
			row.flash:SetShown(lit and true or false)
			if isBar then
				-- (The card right under the headings, the editor or the warnings.)
				y = y - 2
				row.band:ClearAllPoints()
				row.band:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, y)
				row.band:Hide()
				grid.barCard:ClearAllPoints()
				grid.barCard:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, y)
				grid.barCard:SetSize(WIDTH, rowH)
				grid.barCard:Show()
			end
			row.sep:ClearAllPoints()
			row.sep:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, y - rowH)
			row.sep:SetWidth(WIDTH)
			row.sep:SetShown(not isBar)
			row.check:SetShown(not isBar)
			row.check:ClearAllPoints()
			row.check:SetPoint("LEFT", grid, "TOPLEFT", 1, y - rowH / 2)
			Paint(row.check, state.selected[key] and "on" or "off", "")
			row.tick:SetShown(state.selected[key] and true or false)
			row.ShowTick()
			row.name:ClearAllPoints()
			-- (Every icon in one column, the bar's too: its card has room for it.)
			row.name:SetPoint("TOPLEFT", grid, "TOPLEFT", CHECK_W + GAP, y)
			row.name:SetSize(NAME_W, rowH)
			row.name:Show()
			row.label:SetFontObject(isBar and "GameFontHighlightMedium" or "GameFontHighlight")
			if isBar then row.label:SetTextColor(WHITE[1], WHITE[2], WHITE[3]) end
			row.label:SetText(NameOf(key))
			row.label:ClearAllPoints()
			-- (A group's row: its first buff's name, the others under it; a
			-- Missing buff's ready-made alternatives the same way.)
			row.label:SetPoint("LEFT", row.icon, "RIGHT", 7, subText and 6 or 0)
			row.label:SetPoint("RIGHT", row.name, "RIGHT", -2, subText and 6 or 0)
			row.sub:ClearAllPoints()
			row.sub:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -1)
			-- (No "for every spell": its card says it, the user, 2026-11-22.)
			row.sub:SetShown(subText ~= nil)
			if subText then
				row.sub:SetText(subText)
				if row.sub:IsTruncated() then row.sub:SetText(subShort) end
			end
			-- (A buffs bar's row is for its buffs: "spell" read wrong there, the CDM lab.)
			if isBar then row.sub:SetText(BUFF_TAB[state.tab] and L["for every buff"] or L["for every spell"]) end
			if isBar then
				row.icon:SetTexture("Interface\\Icons\\Spell_Nature_TimeStop")
			else
				local okIcon, icon = pcall(GetIcon, key)
				row.icon:SetTexture(okIcon and (type(icon) == "number" or type(icon) == "string") and icon or 134400)
			end
			row.icon:SetTexCoord(5 / 64, 59 / 64, 5 / 64, 59 / 64)
			for j, col in ipairs(cols) do
				local cell = Cell(row, j)
				cell.col = col
				cell:SetSize(ColW(j), rowH)
				cell:ClearAllPoints()
				cell:SetPoint("TOPLEFT", grid, "TOPLEFT", ColX(j), y)
				local text, style, value, mode = CellLook(key, col)
				local open = state.open and state.open.key == key and state.open.j == j
				-- (A cell that follows: its faint icon alone; the words of every one
				-- buried the few set, 2026-11-22. Narrow columns: icons alone too.)
				-- (Previewing: the cell that decides gets a ring; blank, it shows
				-- what it takes from the bar or Otherwise, faint.)
				local decides = previewing and j == decideAt
				-- (Ghost cells: a cell that follows shows its icon faint in a faint
				-- outline, so every cell reads as a place to click, and what it does
				-- there. The user, 2026-11-22: "i wouldnt know i could click under
				-- those columns"; picked from lab mock-ups, with the column bands.)
				local ghost = style == "follow" and not decides and not open
				cell.ringed, cell.decides = decides or ghost, decides
				if decides and style == "follow" then
					SetPill(cell, mode, text, "inherited", open, compact)
				elseif ghost then
					SetPill(cell, mode, text, "ghost", false, true, false)
				else
					SetPill(cell, mode, text, style, open, compact or style == "follow", style == "follow" and not open)
				end
				cell.mode, cell.compact = mode or value, compact and mode ~= nil
				if open then openCell, openX, openBottom = cell, ColX(j), y - rowH end
				cell:SetAlpha((col.index and trouble[col.index] and trouble[col.index].kind == "dead") and 0.45 or 1)
				-- (A buff that's no shield can't have a ring: its Ring and Amount
				-- hidden, not left to set and never draw. Lightning Shield, 2026-11-23.)
				local noRing = not isBar and (col.look == "ring" or col.look == "ringAmount")
					and ns.CooldownRingFits and not ns.CooldownRingFits(key)
				cell:SetShown(not noRing)
			end
			for j = n + 1, #row.cells do row.cells[j]:Hide() end
			y = y - rowH
			if isBar then
				-- (A gap under the card, no label: SPELLS said nothing, the user, 2026-11-22.)
				grid.spellsLabel:Hide()
				y = y - 8
			end
		end
		-- (The open cell's choices: a pop-up under it, turned left at the right edge.)
		-- (Every other column a faint band from its heading down, so the
		-- columns read as columns: with the ghost cells, 2026-11-22.)
		grid.colBands = grid.colBands or {}
		local banded = true
		-- (One per column, none skipped: with gaps "#" stopped short and a
		-- band from before stayed up, the CDM lab.)
		for j = 1, math.max(n, #grid.colBands) do
			local band = grid.colBands[j]
			if not band then
				band = grid:CreateTexture(nil, "BACKGROUND", nil, -2)
				band:Hide()
				grid.colBands[j] = band
			end
			if banded and j <= n and j % 2 == 1 then
				band:SetColorTexture(1, 1, 1, 0.025)
				band:ClearAllPoints()
				band:SetPoint("TOPLEFT", grid, "TOPLEFT", ColX(j), bandsTop)
				band:SetSize(ColW(j), math.max(bandsTop - y, 1))
				band:Show()
			elseif band then
				band:Hide()
			end
		end
		local lowest = y
		if not state.look and state.open and openCell and cols[state.open.j] then
			local height = ChooserShow(state.open.key, cols[state.open.j])
			chooser:ClearAllPoints()
			if openX + POP_W > WIDTH then
				chooser:SetPoint("TOPRIGHT", openCell, "BOTTOMRIGHT", 0, -2)
			else
				chooser:SetPoint("TOPLEFT", openCell, "BOTTOMLEFT", 0, -2)
			end
			grid.chooserFit = grid.FitChooser(openCell, openX + POP_W > WIDTH, height)
			lowest = math.min(y, openBottom - 2 - height)
			openShown = true
		end
		for i = #keys + 1, #rows do
			local row = rows[i]
			row.key = nil
			row.check:Hide()
			row.name:Hide()
			row.band:Hide()
			row.sep:Hide()
			for _, cell in ipairs(row.cells) do cell:Hide() end
		end
		if not openShown then
			chooser:Hide()
			catcher:Hide()
			state.open = nil
		end
		-- The bar's looks, then the ticked rows' bar.
		local extra = ExtrasShow()
		if extra > 0 then
			extras:ClearAllPoints()
			extras:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, y - 6)
			y = y - extra - 8
		end
		local bulkHeight = BulkShow()
		if bulkHeight > 0 then
			bulk:ClearAllPoints()
			bulk:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, y - 6)
			y = y - bulkHeight - 8
		end
		grid:SetAlpha(Enabled() and 1 or 0.5)
		-- (Tall enough for the pop-up too: the page's scroll would cut it off.)
		y = math.min(y, lowest - 6)
		grid:SetHeight(-y)
		return -y
	end
	grid.Layout = Layout

	-- The rows under the bar's: its spells, a group of buffs that count as one
	-- as one row (its lead's ID) where its first member is listed.
	function grid.RowKeys()
		local keys, done = {}, {}
		for _, id in ipairs(state.ids) do
			local lead = BUFF_TAB[state.tab] and ns.CooldownBuffLead and ns.CooldownBuffLead(id)
			local key = lead or id
			if not done[key] then
				done[key] = true
				keys[#keys + 1] = key
			end
		end
		return keys
	end

	-- A bar's rows (tab: its group; ids its spells, in order): lays out, gives the height.
	-- (Not grid.Show: that hid the frame's own Show, 2026-11-22.)
	function grid.ShowBar(tab, ids)
		if tab ~= state.tab then
			state.open, state.editing, state.bulkCol, state.bulkValue = nil, nil, 1, 1
			wipe(state.selected)
			state.selecting = nil
		end
		state.tab, state.ids = tab, ids or {}
		local listed = {}
		for _, key in ipairs(grid.RowKeys()) do listed[key] = true end
		for key in pairs(state.selected) do
			if not listed[key] then state.selected[key] = nil end
		end
		return Layout()
	end
	return grid
end
