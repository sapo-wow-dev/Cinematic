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
-- ns.CooldownGrid(parent, opts) gives the grid; grid.Show(tab, ids) lists a
-- bar's rows and gives the height. opts: { width, Tooltip(frame, text),
-- Enabled(), Changed() (after a change: the page lists again and fits),
-- KeyGet(key), KeyPut(key, value) }.
local _, ns = ...
local L = ns.L

local MODES = { { "always", L["Always"] }, { "ready", L["When ready"] }, { "recharge", L["While recharging"] },
	{ "proc", L["When it procs"] }, { "never", L["Never"] } }
local BUFF_MODES = { { "always", L["Always"] }, { "combat", L["In combat"] }, { "quiet", L["Out of combat"] },
	{ "hidden", L["Hidden"] } }
-- (In a cell: short, the columns are narrow.)
local SHORT = { always = L["Always"], ready = L["Ready"], recharge = L["Recharging"], proc = L["Procs"],
	never = L["Never"], combat = L["In fights"], quiet = L["Out of fights"], hidden = L["Hidden"] }
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
-- with no groups, read as an empty bar, 2026-11-22. The add column: wide
-- with no groups, its words saying what a group is; narrow once there are.)
local COL_MAX, ADD_WIDE, ADD_NARROW = 120, 176, 70
local ROW_H, HEAD_H = 22, 34

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
}
local LOOK_COLUMNS = { essential = { "numbers", "keybinds", "notBuff", "flash" }, utility = { "numbers", "keybinds", "notBuff", "flash" },
	buffs = { "numbers" }, bars = { "numbers" } }
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
	own = { 0.23, 0.19, 0.05, 1, 0.66, 0.53, 0.16, 1, 1, 0.85, 0.4 },
	bar = { 0.17, 0.14, 0.05, 1, 0.5, 0.4, 0.12, 1, 1, 0.82, 0 },
	follow = { 0, 0, 0, 0.3, 0.3, 0.28, 0.24, 1, 0.62, 0.6, 0.54 },
	off = { 0.1, 0.09, 0.08, 1, 0.27, 0.25, 0.18, 1, 0.8, 0.77, 0.69 },
	on = { 0.23, 0.19, 0.05, 1, 0.83, 0.65, 0.17, 1, 1, 0.85, 0.4 },
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
		if bright then edge:SetColorTexture(1, 0.82, 0, 1) else edge:SetColorTexture(s[5], s[6], s[7], s[8]) end
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

	local function KindOf(key)
		if key == state.tab then return "group" end
		return BUFF_TAB[state.tab] and "buff" or "spell"
	end
	local function NameOf(key)
		if key == state.tab then return opts.BarName and opts.BarName(key) or tostring(key) end
		local ok, name = pcall(GetName, key)
		return ok and type(name) == "string" and name or L["Spell %d"]:format(key)
	end
	local function ModesFor() return BUFF_TAB[state.tab] and BUFF_MODES or MODES end

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

	-- What a cell says: text, style, and its value (a mode, or a look's value).
	local function CellLook(key, col)
		local kind = KindOf(key)
		if col.look then
			local own, shown = LookGet(col.look, kind, key, state.tab, opts)
			if kind == "group" then return LOOK[col.look].Text(own), "bar", own end
			if own == nil then return LOOK[col.look].Text(shown), "follow", nil end
			return LOOK[col.look].Text(own), "own", own
		end
		local mode, own
		if col.other then mode, own = OtherwiseOf(kind, key, state.tab)
		else mode, own = CellOf(kind, key, state.tab, col.id) end
		local text = SHORT[mode] or tostring(mode)
		-- (The bar's Otherwise is what its row follows: gold, set or its default.)
		if kind == "group" then return text, (own or col.other) and "bar" or "follow", own and mode or nil end
		return text, own and "own" or "follow", own and mode or nil
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
	-- Top: Look switch and a hint.
	local hint = grid:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, -4)
	hint:SetWidth(WIDTH - 200)
	hint:SetJustifyH("LEFT")
	hint:SetWordWrap(false)
	local showsSwitch = Box(grid, 92, 20)
	local lookSwitch = Box(grid, 60, 20)
	lookSwitch:SetPoint("TOPRIGHT", grid, "TOPRIGHT", 0, 0)
	showsSwitch:SetPoint("RIGHT", lookSwitch, "LEFT", 1, 0)
	Tip(showsSwitch, L["Where each icon shows, group by group."])
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
	-- The heading row: Spell, a heading per column, and + (a new group).
	local spellHead = grid:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	spellHead:SetText(L["Spell"])
	local heads = {}
	local function Head(i)
		if heads[i] then return heads[i] end
		local head = Box(grid, 60, HEAD_H)
		head.text:ClearAllPoints()
		head.text:SetPoint("TOPLEFT", head, "TOPLEFT", 4, -4)
		head.text:SetPoint("TOPRIGHT", head, "TOPRIGHT", -4, -4)
		head.text:SetFontObject("GameFontNormalSmall")
		head.sub = head:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		head.sub:SetPoint("BOTTOMLEFT", head, "BOTTOMLEFT", 4, 4)
		head.sub:SetPoint("BOTTOMRIGHT", head, "BOTTOMRIGHT", -4, 4)
		head.sub:SetJustifyH("LEFT")
		head.sub:SetWordWrap(false)
		head.text:SetJustifyH("LEFT")
		head.dot = head:CreateTexture(nil, "OVERLAY")
		head.dot:SetSize(6, 6)
		head.dot:SetColorTexture(0.37, 0.83, 0.43, 1)
		head.dot:SetPoint("TOPRIGHT", head, "TOPRIGHT", -4, -4)
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
				return L["Otherwise: where none of the groups to its left fits. A row's own setting, a spell's grey while it follows its bar."]
			end
			return ("%s\n%s\n\n%s"):format(ns.CooldownGroupName(col.group), ns.CooldownGroupWhere(col.group),
				L["Click to change its places, name or order. Groups are read left to right: the first that fits decides."])
		end)
		heads[i] = head
		return head
	end
	-- (A column of its own before Otherwise, where the next group goes.)
	local plus = Box(grid, ADD_WIDE, HEAD_H)
	plus.text:ClearAllPoints()
	plus.text:SetPoint("TOPLEFT", plus, "TOPLEFT", 4, -4)
	plus.text:SetPoint("TOPRIGHT", plus, "TOPRIGHT", -4, -4)
	plus.text:SetJustifyH("LEFT")
	plus.text:SetFontObject("GameFontNormalSmall")
	plus.sub = plus:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	plus.sub:SetPoint("BOTTOMLEFT", plus, "BOTTOMLEFT", 4, 4)
	plus.sub:SetPoint("BOTTOMRIGHT", plus, "BOTTOMRIGHT", -4, 4)
	plus.sub:SetJustifyH("LEFT")
	plus.sub:SetWordWrap(false)
	Tip(plus, L["Adds a group: some places and a combat, where icons can show differently."])
	plus:SetScript("OnClick", function()
		if not Enabled() then return end
		local group = ns.AddCooldownGroup()
		if group then
			state.editing, state.open = group.id, nil
			Changed()
		end
	end)
	grid.plus = plus

	-- ---------------------------------------------------------------------
	-- The group editor, under the heading row while one is picked.
	local editor = CreateFrame("Frame", nil, grid)
	editor:SetSize(WIDTH, 84)
	do
		local back = editor:CreateTexture(nil, "BACKGROUND")
		back:SetAllPoints()
		back:SetColorTexture(0.12, 0.1, 0.06, 0.95)
	end
	local function EditingGroup() return state.editing and ns.CooldownPlaceGroup(state.editing) end
	local nameLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	nameLabel:SetPoint("TOPLEFT", editor, "TOPLEFT", 8, -10)
	nameLabel:SetText(L["Name"])
	local nameBox = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
	if ns.SkinEditBox then ns.SkinEditBox(nameBox) end
	nameBox:SetSize(170, 20)
	nameBox:SetAutoFocus(false)
	nameBox:SetMaxLetters(24)
	nameBox:SetPoint("LEFT", nameLabel, "LEFT", 46, 0)
	local namePlace = nameBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	namePlace:SetPoint("LEFT", nameBox, "LEFT", 2, 0)
	namePlace:SetPoint("RIGHT", nameBox, "RIGHT", -2, 0)
	namePlace:SetJustifyH("LEFT")
	namePlace:SetWordWrap(false)
	nameBox:HookScript("OnTextChanged", function(self) namePlace:SetShown(self:GetText() == "") end)
	Tip(nameBox, L["Its name in the grid. Empty: its places."])
	local function SaveName(self)
		self:ClearFocus()
		local group = EditingGroup()
		if group and self:GetText() ~= group.name then
			group.name = self:GetText()
			Changed()
		end
	end
	nameBox:SetScript("OnEnterPressed", SaveName)
	nameBox:SetScript("OnEditFocusLost", function(self)
		if self.saving then return end
		self.saving = true
		SaveName(self)
		self.saving = nil
	end)
	nameBox:SetScript("OnEscapePressed", function(self)
		local group = EditingGroup()
		self:SetText(group and group.name or "")
		self:ClearFocus()
	end)
	local function SmallButton(text, width, tip, onClick)
		local button = Box(editor, width, 20)
		Paint(button, "off", text)
		Tip(button, tip)
		button:SetScript("OnClick", function(self, mouse)
			if Enabled() then onClick(self, mouse) end
		end)
		return button
	end
	local earlier = SmallButton("<", 22, L["Checked earlier: moves this group one column left."], function()
		if ns.MoveCooldownGroup(state.editing, -1) then Changed() end
	end)
	local later = SmallButton(">", 22, L["Checked later: moves this group one column right."], function()
		if ns.MoveCooldownGroup(state.editing, 1) then Changed() end
	end)
	local rule = SmallButton(L["Rule..."], 56, L["Write where this group fits as a rule (CQL). Empty it to go back to places."], function()
		local group = EditingGroup()
		if not group or not ns.OpenRuleEditor then return end
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
	end)
	local delete = SmallButton(L["Delete"], 60, L["Deletes this group and every cell in its column, on every bar."], function()
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
	delete:SetPoint("TOPRIGHT", editor, "TOPRIGHT", -8, -6)
	rule:SetPoint("RIGHT", delete, "LEFT", -6, 0)
	later:SetPoint("RIGHT", rule, "LEFT", -12, 0)
	earlier:SetPoint("RIGHT", later, "LEFT", -2, 0)
	local orderLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	orderLabel:SetPoint("RIGHT", earlier, "LEFT", -6, 0)
	orderLabel:SetText(L["Order"])
	local whereLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	whereLabel:SetPoint("TOPLEFT", editor, "TOPLEFT", 8, -36)
	whereLabel:SetText(L["Where"])
	local placeButtons = {}
	local PLACE_LIST = { { "any", L["Anywhere"] } }
	for _, place in ipairs(ns.COOLDOWN_RULE_PLACES) do PLACE_LIST[#PLACE_LIST + 1] = place end
	local x = 54
	for _, place in ipairs(PLACE_LIST) do
		local width = place[1] == "bg" and 84 or place[1] == "world" and 76 or 66
		local button = SmallButton(place[2], width, L["Click to add or take out this place. Pick any number."], function()
			local group = EditingGroup()
			if not group or group.cql then return end
			local places = group.places
			if place[1] == "any" then
				group.places = places.any and {} or { any = true }
			elseif places.any then
				group.places = {}
				for _, other in ipairs(ns.COOLDOWN_RULE_PLACES) do
					if other[1] ~= place[1] then group.places[other[1]] = true end
				end
			else
				places[place[1]] = not places[place[1]] or nil
				local all = true
				for _, other in ipairs(ns.COOLDOWN_RULE_PLACES) do all = all and places[other[1]] end
				if all then group.places = { any = true } end
			end
			Changed()
		end)
		button:SetPoint("TOPLEFT", editor, "TOPLEFT", x, -32)
		button.place = place[1]
		placeButtons[#placeButtons + 1] = button
		x = x + width + 2
	end
	local whenLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	whenLabel:SetPoint("TOPLEFT", editor, "TOPLEFT", 8, -62)
	whenLabel:SetText(L["When"])
	local combatButtons = {}
	x = 54
	for _, combat in ipairs(ns.COOLDOWN_RULE_COMBATS) do
		local button = SmallButton(combat[2], 92, L["In a fight (the Calm Timer after one too), out of one, or either."], function()
			local group = EditingGroup()
			if not group or group.cql then return end
			group.combat = combat[1]
			Changed()
		end)
		button:SetPoint("TOPLEFT", editor, "TOPLEFT", x, -58)
		button.combat = combat[1]
		combatButtons[#combatButtons + 1] = button
		x = x + 94
	end
	-- (A group written as a rule: its words in place of the places and combat.)
	local cqlText = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	cqlText:SetPoint("TOPLEFT", editor, "TOPLEFT", 54, -38)
	cqlText:SetPoint("RIGHT", editor, "RIGHT", -120, 0)
	cqlText:SetJustifyH("LEFT")
	cqlText:SetWordWrap(false)
	local usePlaces = SmallButton(L["Use places"], 90, L["Back to picking places and combat (the rule is dropped)."], function()
		local group = EditingGroup()
		if group then
			ns.SetCooldownGroupText(group, "")
			Changed()
		end
	end)
	usePlaces:SetPoint("TOPRIGHT", editor, "TOPRIGHT", -8, -34)
	local function EditorShow()
		local group = EditingGroup()
		editor:SetShown(group ~= nil and not state.look)
		if not editor:IsShown() then return 0 end
		if not nameBox:HasFocus() then nameBox:SetText(group.name or "") end
		namePlace:SetText(ns.CooldownGroupWhere(group))
		namePlace:SetShown(nameBox:GetText() == "")
		local _, index = ns.CooldownPlaceGroup(group.id)
		earlier:SetAlpha(index > 1 and 1 or 0.35)
		later:SetAlpha(index < #ns.CooldownPlaceGroups() and 1 or 0.35)
		Paint(delete, state.sure == group.id and "danger" or "off", state.sure == group.id and L["Sure?"] or L["Delete"])
		local own = group.cql ~= nil
		for _, button in ipairs(placeButtons) do
			button:SetShown(not own)
			local on = group.places and (group.places[button.place] or (group.places.any and button.place ~= "any"))
			Paint(button, (group.places and group.places[button.place]) and "on" or "off")
			button.text:SetAlpha((on and button.place ~= "any" and group.places.any) and 0.6 or 1)
		end
		for _, button in ipairs(combatButtons) do
			button:SetShown(not own)
			Paint(button, group.combat == button.combat and "on" or "off")
		end
		whenLabel:SetShown(not own)
		cqlText:SetShown(own)
		usePlaces:SetShown(own)
		if own then cqlText:SetText(ns.ColoredRule and ns.ColoredRule(group.cql) or group.cql) end
		editor:SetHeight(own and 60 or 84)
		return editor:GetHeight()
	end
	grid.editor = editor
	grid.placeButtons, grid.combatButtons, grid.deleteButton, grid.nameBox = placeButtons, combatButtons, delete, nameBox
	grid.moveButtons = { earlier, later }

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
		row.check = Box(grid, CHECK_W, CHECK_W)
		row.tick = row.check:CreateTexture(nil, "OVERLAY")
		row.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
		row.tick:SetPoint("TOPLEFT", -3, 3)
		row.tick:SetPoint("BOTTOMRIGHT", 3, -3)
		Tip(row.check, L["Tick rows to set them all at once, or to copy one onto others."])
		row.check:SetScript("OnClick", function()
			if not Enabled() or row.key == nil then return end
			state.selected[row.key] = not state.selected[row.key] or nil
			Changed()
		end)
		row.name = CreateFrame("Button", nil, grid)
		row.name:SetSize(NAME_W, ROW_H)
		row.icon = row.name:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(16, 16)
		row.icon:SetPoint("LEFT", row.name, "LEFT", 0, 0)
		row.label = row.name:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		row.label:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
		row.label:SetPoint("RIGHT", row.name, "RIGHT", -2, 0)
		row.label:SetJustifyH("LEFT")
		row.label:SetWordWrap(false)
		-- (The name ticks it too: a bigger target than the box.)
		row.name:SetScript("OnClick", function() row.check:GetScript("OnClick")(row.check) end)
		LiveTip(row.name, function()
			if row.key == state.tab then return L["The bar's row: every spell on it follows this row's cells until set on its own."] end
			return row.label:IsTruncated() and row.label:GetText() or nil
		end)
		row.cells = {}
		-- Its tick box seen only under the pointer, or while any row's ticked
		-- (a column of empty boxes read as stray squares, 2026-11-22). Kept
		-- shown at no alpha: still there to click, no flicker moving onto it.
		function row.ShowTick()
			local over = row.name:IsMouseOver() or row.check:IsMouseOver()
			for _, cell in ipairs(row.cells) do over = over or (cell:IsShown() and cell:IsMouseOver()) end
			row.tickSeen = (next(state.selected) ~= nil or over) and true or false
			row.check:SetAlpha(row.tickSeen and 1 or 0)
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
		local cell = Box(grid, 60, ROW_H)
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
				-- (Each click the next value; a spell's comes back round to following.)
				local values = LookValues(self.col.look, kind)
				local own = LookGet(self.col.look, kind, row.key, state.tab, opts)
				local list = {}
				if kind ~= "group" then list[1] = { nil } end
				for _, value in ipairs(values) do list[#list + 1] = { value } end
				local at = 0
				for k, item in ipairs(list) do
					if item[1] == own then at = k end
				end
				SetCell(row.key, self.col, list[at % #list + 1][1])
				Changed()
				return
			end
			local same = state.open and state.open.key == row.key and state.open.j == j
			state.open = not same and { key = row.key, j = j } or nil
			state.editing = nil
			Changed()
		end)
		LiveTip(cell, function(self)
			if not self.col or row.key == nil then return nil end
			local text, style = CellLook(row.key, self.col)
			local where = self.col.look and LOOK[self.col.look].label or self.col.other and L["Otherwise"]
				or ns.CooldownGroupName(self.col.group)
			local value = self.col.look and text or FULL[self.mode] or text
			local tip = ("%s, %s: %s"):format(NameOf(row.key), where, value)
			if style == "follow" then
				tip = tip .. "\n" .. (KindOf(row.key) == "group" and L["As its Otherwise, until set."]
					or L["Follows the bar's row, until set."])
			end
			return tip .. "\n\n" .. (self.col.look and L["Click for the next choice. Right-click: back to following."]
				or L["Click to choose. Right-click: back to following."])
		end)
		cell:HookScript("OnEnter", function() if row.ShowTick then row.ShowTick() end end)
		cell:HookScript("OnLeave", function() if row.ShowTick then row.ShowTick() end end)
		row.cells[j] = cell
		return cell
	end
	grid.rows = rows

	-- ---------------------------------------------------------------------
	-- The choices, under the row whose cell is open.
	local chooser = CreateFrame("Frame", nil, grid)
	chooser:SetSize(WIDTH - CHECK_W - GAP, 52)
	do
		local back = chooser:CreateTexture(nil, "BACKGROUND")
		back:SetAllPoints()
		back:SetColorTexture(0.12, 0.1, 0.06, 0.95)
		local edge = chooser:CreateTexture(nil, "BORDER")
		edge:SetPoint("TOPLEFT")
		edge:SetPoint("BOTTOMLEFT")
		edge:SetWidth(2)
		edge:SetColorTexture(1, 0.82, 0, 0.7)
	end
	local chooserTitle = chooser:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	chooserTitle:SetPoint("TOPLEFT", chooser, "TOPLEFT", 10, -6)
	chooserTitle:SetPoint("RIGHT", chooser, "RIGHT", -30, 0)
	chooserTitle:SetJustifyH("LEFT")
	chooserTitle:SetWordWrap(false)
	local chooserClose = Box(chooser, 18, 18)
	chooserClose:SetPoint("TOPRIGHT", chooser, "TOPRIGHT", -4, -4)
	Paint(chooserClose, "off", "x")
	Tip(chooserClose, L["Close"])
	chooserClose:SetScript("OnClick", function()
		state.open = nil
		Changed()
	end)
	local choices = {}
	local function Choice(i)
		if choices[i] then return choices[i] end
		local box = Box(chooser, 80, 20)
		box:SetScript("OnClick", function(self)
			if not Enabled() or not state.open then return end
			local col = Columns()[state.open.j]
			if not col then return end
			SetCell(state.open.key, col, self.value)
			Changed()
		end)
		choices[i] = box
		return box
	end
	-- When ready's parts (a spell's or a bar's), under the choices while it's When ready.
	local readyLabel = chooser:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	readyLabel:SetText(L["When ready:"])
	local function Tick(label, tip, part)
		local check = CreateFrame("CheckButton", nil, chooser, "UICheckButtonTemplate")
		if ns.SkinCheck then check = ns.SkinCheck(check) or check end
		check:SetSize(20, 20)
		check.label = chooser:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		check.label:SetPoint("LEFT", check, "RIGHT", 1, 0)
		check.label:SetText(label)
		Tip(check, tip)
		check:SetScript("OnClick", function(self)
			if not (Enabled() and state.open) then return end
			SetReadyPart(KindOf(state.open.key), state.open.key, state.tab, part, self:GetChecked() and true or false)
			Changed()
		end)
		return check
	end
	local powerTick = Tick(L["Wait for resources"], L["The icon also waits until you have the resources to cast it."], "power")
	local anyTimeTick = Tick(L["Out of fights too"], L["Out of fights, the icon also shows once it's ready."], "anyTime")
	local earlyLabel = chooser:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	earlyLabel:SetText(L["Show early (sec)"])
	local earlyBox = CreateFrame("EditBox", nil, chooser, "InputBoxTemplate")
	if ns.SkinEditBox then ns.SkinEditBox(earlyBox) end
	earlyBox:SetSize(36, 20)
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
	grid.readyParts = { power = powerTick, anyTime = anyTimeTick, early = earlyBox }

	local function ChooserShow(key, col)
		local kind = KindOf(key)
		local list = {}
		if not col.other or kind ~= "group" then
			-- (What it follows, by name, first.)
			local follows
			if kind == "group" then
				follows = L["As Otherwise (%s)"]:format(SHORT[(OtherwiseOf(kind, key, state.tab))] or "?")
			else
				local barMode
				if col.other then barMode = (OtherwiseOf("group", state.tab, state.tab))
				else barMode = CellOf("group", state.tab, state.tab, col.id) end
				follows = L["Same as bar (%s)"]:format(SHORT[barMode] or "?")
			end
			list[1] = { nil, follows }
		else
			local set = db().cooldownGroupDefaults[key]
			if not (set and set.mode) then
				list[1] = { nil, L["Default (%s)"]:format(SHORT[(OtherwiseOf(kind, key, state.tab))] or "?") }
			end
		end
		for _, mode in ipairs(ModesFor()) do list[#list + 1] = { mode[1], mode[2] } end
		local _, _, own = CellLook(key, col)
		local where = col.other and L["Otherwise"] or ns.CooldownGroupName(col.group)
		chooserTitle:SetText(L["%s in %s shows:"]:format(NameOf(key), where))
		local x, y = 10, -24
		local width = chooser:GetWidth()
		for i, item in ipairs(list) do
			local box = Choice(i)
			box.value = item[1]
			box.text:SetText(item[2])
			box:SetWidth(math.max(64, math.min(150, (box.text:GetStringWidth() or 60) + 16)))
			if x + box:GetWidth() > width - 8 then
				x, y = 10, y - 22
			end
			box:ClearAllPoints()
			box:SetPoint("TOPLEFT", chooser, "TOPLEFT", x, y)
			Paint(box, item[1] == nil and (own == nil and "on" or "follow") or (own == item[1] and "on" or "off"))
			box:Show()
			x = x + box:GetWidth() - 1
		end
		for i = #list + 1, #choices do choices[i]:Hide() end
		y = y - 24
		-- (When ready's parts, while this cell says When ready.)
		local mode = col.other and (OtherwiseOf(kind, key, state.tab)) or (CellOf(kind, key, state.tab, col.id))
		local ready = mode == "ready" and kind ~= "buff"
		for _, part in ipairs({ readyLabel, powerTick, powerTick.label, anyTimeTick, anyTimeTick.label, earlyLabel, earlyBox }) do
			part:SetShown(ready)
		end
		if ready then
			local power, earlyOn, early, anyTime = ReadyParts(kind, key, state.tab)
			readyLabel:ClearAllPoints()
			readyLabel:SetPoint("TOPLEFT", chooser, "TOPLEFT", 10, y - 5)
			powerTick:ClearAllPoints()
			powerTick:SetPoint("TOPLEFT", chooser, "TOPLEFT", 78, y)
			powerTick:SetChecked(power and true or false)
			anyTimeTick:ClearAllPoints()
			anyTimeTick:SetPoint("TOPLEFT", chooser, "TOPLEFT", 218, y)
			anyTimeTick:SetChecked(anyTime and true or false)
			earlyLabel:ClearAllPoints()
			earlyLabel:SetPoint("TOPLEFT", chooser, "TOPLEFT", 350, y - 5)
			earlyBox:ClearAllPoints()
			earlyBox:SetPoint("LEFT", earlyLabel, "RIGHT", 8, 0)
			if not earlyBox:HasFocus() then earlyBox:SetText(not earlyOn and "0" or early and tostring(early) or "") end
			y = y - 24
		end
		chooser:SetHeight(-y + 4)
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
		back:SetColorTexture(0.14, 0.12, 0.07, 0.95)
	end
	local bulkCount = bulk:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	bulkCount:SetPoint("LEFT", bulk, "LEFT", 8, 0)
	local function BulkButton(width, tip, onClick)
		local box = Box(bulk, width, 20)
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
		local list = { { nil, L["Same as bar"] } }
		if not col then return col, list end
		if col.look then
			for _, value in ipairs(LookValues(col.look, "spell")) do list[#list + 1] = { value, LOOK[col.look].Text(value) } end
		else
			for _, mode in ipairs(ModesFor()) do list[#list + 1] = { mode[1], SHORT[mode[1]] } end
		end
		return col, list
	end
	local bulkCol = BulkButton(110, L["Which column to set. Click for the next, right-click for the one before."], function(_, mouse)
		local count = #Columns()
		state.bulkCol = (state.bulkCol - 1 + (mouse == "RightButton" and -1 or 1)) % count + 1
		state.bulkValue = 1
		Layout()
	end)
	local bulkValue = BulkButton(90, L["What to set it to. Click for the next, right-click for the one before."], function(_, mouse)
		local _, list = BulkValues()
		state.bulkValue = (state.bulkValue - 1 + (mouse == "RightButton" and -1 or 1)) % #list + 1
		Layout()
	end)
	local bulkSet = BulkButton(40, L["Sets that column of every ticked row."], function()
		local col, list = BulkValues()
		if not col then return end
		local value = (list[state.bulkValue] or list[1])[1]
		for key in pairs(state.selected) do SetCell(key, col, value) end
		Changed()
	end)
	local bulkCopy = BulkButton(70, L["Copies the ticked row: its cells, Otherwise and looks."], function()
		local key = next(state.selected)
		if key == nil then return end
		local kind = KindOf(key)
		local d = db()
		local clip = { kind = kind, cells = ns.CooldownCellsOf(kind, key), look = {}, name = NameOf(key) }
		local _, own = OtherwiseOf(kind, key, state.tab)
		clip.mode = own and (OtherwiseOf(kind, key, state.tab)) or nil
		for _, what in ipairs({ "numbers", "keybinds", "notBuff" }) do clip.look[what] = ns.CooldownRowOwn(key, what) end
		clip.flash = d.cooldownFlashReady[key]
		state.clip = clip
		Layout()
	end)
	local bulkPaste = BulkButton(80, L["Puts the copied row on every ticked row: their cells, Otherwise and looks become its."], function()
		local clip = state.clip
		if not clip then return end
		local d = db()
		for key in pairs(state.selected) do
			if KindOf(key) == clip.kind then
				ns.SetCooldownCells(clip.kind, key, clip.cells)
				SetOtherwise(clip.kind, key, state.tab, clip.mode)
				for what, value in pairs(clip.look) do ns.SetCooldownRow(key, what, value) end
				for _, what in ipairs({ "numbers", "keybinds", "notBuff" }) do
					if clip.look[what] == nil then ns.SetCooldownRow(key, what, nil) end
				end
				if clip.kind == "spell" then d.cooldownFlashReady[key] = clip.flash end
			end
		end
		if ns.ApplyCooldownNumbers then ns.ApplyCooldownNumbers() end
		if ns.ApplyCooldownKeybinds then ns.ApplyCooldownKeybinds() end
		Changed()
	end)
	local bulkClear = BulkButton(20, L["Unticks every row."], function()
		wipe(state.selected)
		Changed()
	end)
	Paint(bulkClear, "off", "x")
	bulkClear:SetPoint("RIGHT", bulk, "RIGHT", -4, 0)
	bulkPaste:SetPoint("RIGHT", bulkClear, "LEFT", -4, 0)
	bulkCopy:SetPoint("RIGHT", bulkPaste, "LEFT", -4, 0)
	local inLabel = bulk:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	inLabel:SetText(L["In"])
	inLabel:SetPoint("LEFT", bulk, "LEFT", 110, 0)
	bulkCol:SetPoint("LEFT", inLabel, "RIGHT", 6, 0)
	local toLabel = bulk:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	toLabel:SetText(L["set"])
	toLabel:SetPoint("LEFT", bulkCol, "RIGHT", 6, 0)
	bulkValue:SetPoint("LEFT", toLabel, "RIGHT", 6, 0)
	bulkSet:SetPoint("LEFT", bulkValue, "RIGHT", 4, 0)
	grid.bulk = bulk
	grid.bulkButtons = { col = bulkCol, value = bulkValue, set = bulkSet, copy = bulkCopy, paste = bulkPaste, clear = bulkClear }
	local function BulkShow()
		local count = 0
		for key in pairs(state.selected) do
			if key ~= state.tab then count = count + 1 end
		end
		bulk:SetShown(count > 0)
		if count == 0 then return 0 end
		bulkCount:SetText(L["%d ticked"]:format(count))
		local col, list = BulkValues()
		local name = not col and "?" or col.look and LOOK[col.look].label or col.other and L["Otherwise"]
			or ns.CooldownGroupName(col.group)
		Paint(bulkCol, "off", name)
		Paint(bulkValue, "off", (list[state.bulkValue] or list[1])[2])
		Paint(bulkSet, "on", L["Set"])
		bulkCopy:SetShown(count == 1)
		Paint(bulkCopy, "off", L["Copy row"])
		bulkPaste:SetShown(state.clip ~= nil)
		Paint(bulkPaste, "off", L["Paste row"])
		return bulk:GetHeight()
	end

	-- In Look: the bar's own looks (Close the gaps...) on a line under the grid.
	local extras = CreateFrame("Frame", nil, grid)
	extras:SetSize(WIDTH, 24)
	local extrasLabel = extras:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	extrasLabel:SetPoint("LEFT", extras, "LEFT", 0, 0)
	extrasLabel:SetText(L["This bar:"])
	local extraParts = {}
	local function ExtrasShow()
		local list = state.look and BAR_EXTRAS[state.tab]
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
				part = { label = extras:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"), box = Box(extras, 70, 20) }
				part.label:SetText(LOOK[what].label)
				Tip(part.box, LOOK[what].tip .. "\n" .. L["Click for the next choice."])
				part.box:SetScript("OnClick", function()
					if not Enabled() then return end
					local values = LookValues(what, "group")
					local now = LookGet(what, "group", state.tab, state.tab, opts)
					local at = 0
					for k, value in ipairs(values) do
						if value == now then at = k end
					end
					LookSet(what, "group", state.tab, values[at % #values + 1], opts)
					Changed()
				end)
				extraParts[what] = part
			end
			part.label:ClearAllPoints()
			part.label:SetPoint("LEFT", extras, "LEFT", x, 0)
			part.label:Show()
			x = x + (part.label:GetStringWidth() or 100) + 6
			part.box:ClearAllPoints()
			part.box:SetPoint("LEFT", extras, "LEFT", x, 0)
			Paint(part.box, "bar", LOOK[what].Text(LookGet(what, "group", state.tab, state.tab, opts)))
			part.box:Show()
			x = x + 80
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
		Paint(showsSwitch, state.look and "off" or "on", L["When it shows"])
		Paint(lookSwitch, state.look and "on" or "off", L["Look"])
		hint:SetText(state.look and L["Gold: set for this spell, grey: follows the bar. Click to step."]
			or L["The first group that fits decides. Gold: set, grey: follows the bar."])
		local groups = ns.CooldownPlaceGroups()
		local plusShown = not state.look and #groups < ns.COOLDOWN_GROUP_MAX
		local plusW = groups[1] and ADD_NARROW or ADD_WIDE
		local free = WIDTH - CHECK_W - NAME_W - GAP * 2 - (plusShown and (plusW + GAP) or 0)
		local colW = math.min(COL_MAX, math.floor((free - GAP * (n - 1)) / math.max(n, 1)))
		local x0 = CHECK_W + GAP + NAME_W + GAP
		-- (Each column's left: Otherwise after the add column.)
		local function ColX(j, col)
			local x = x0 + (j - 1) * (colW + GAP)
			if col.other and plusShown then x = x + plusW + GAP end
			return x
		end
		local y = -26
		-- Headings. (Spell level with their middle.)
		spellHead:ClearAllPoints()
		spellHead:SetPoint("LEFT", grid, "TOPLEFT", CHECK_W + GAP, y - HEAD_H / 2)
		local _, nowIndex = ns.CooldownGroupNow()
		local trouble, otherDead = ns.CooldownGroupTrouble()
		for j, col in ipairs(cols) do
			local head = Head(j)
			head.col = col
			head:SetSize(colW, HEAD_H)
			head:ClearAllPoints()
			head:SetPoint("TOPLEFT", grid, "TOPLEFT", ColX(j, col), y)
			local style, name, sub, dot = "off"
			if col.look then
				name, sub = LOOK[col.look].label, ""
			elseif col.other then
				name, sub = L["Otherwise"], L["everywhere else"]
				-- (In use: said only once there's a group it could be told from.)
				dot = groups[1] ~= nil and nowIndex == nil and not otherDead
				if otherDead then style = "warn" end
			else
				name, sub = ns.CooldownGroupName(col.group), ns.CooldownGroupWhere(col.group)
				if not (col.group.name and col.group.name:find("%S")) then sub = col.group.cql and L["rule"] or "" end
				dot = nowIndex == col.index
				if trouble[col.index] then style = "warn" end
			end
			Paint(head, style, name, col.id ~= nil and state.editing == col.id)
			head.text:SetTextColor(1, 0.82, 0)
			head.sub:SetText(sub)
			head.dot:SetShown(dot and true or false)
			head:Show()
		end
		for j = n + 1, #heads do heads[j]:Hide() end
		plus:SetShown(plusShown)
		plus:SetSize(plusW, HEAD_H)
		plus:ClearAllPoints()
		plus:SetPoint("TOPLEFT", grid, "TOPLEFT", x0 + (n - 1) * (colW + GAP), y)
		Paint(plus, "follow", groups[1] and L["+ Group"] or L["+ Add a group"])
		plus.text:SetTextColor(1, 0.82, 0)
		plus.sub:SetText(groups[1] and "" or L["places where icons differ"])
		grid.layout = { colW = colW, plusW = plusW, plusShown = plusShown, x0 = x0 }
		y = y - HEAD_H - GAP
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
			for i, group in ipairs(groups) do
				local t = trouble[i]
				if t then
					count = count + 1
					local line = TroubleLine(count)
					if t.kind == "dead" then
						line:SetText(L["%s is never used: %s already take every place and time it has. Move it left or change its places."]:format(
							ns.CooldownGroupName(group), table.concat(t.by, ", ")))
					else
						line:SetText(L["%s has no place yet, so it does nothing. Click its heading to pick some."]:format(
							ns.CooldownGroupName(group)))
					end
				end
			end
			if otherDead then
				count = count + 1
				TroubleLine(count):SetText(L["Otherwise is never used: the groups take every place, in and out of combat."])
			end
		end
		for i, line in ipairs(troubleLines) do
			if i <= count then
				line:ClearAllPoints()
				line:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, y - 2)
				line:Show()
				y = y - (line:GetStringHeight() or 12) - 4
			else
				line:Hide()
			end
		end
		-- Rows: the bar's, then each spell's.
		local keys = { state.tab }
		for _, id in ipairs(state.ids) do keys[#keys + 1] = id end
		local openShown = false
		for i, key in ipairs(keys) do
			local row = Row(i)
			row.key = key
			local isBar = key == state.tab
			row.check:SetShown(not isBar)
			row.check:ClearAllPoints()
			row.check:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, y - (ROW_H - CHECK_W) / 2)
			Paint(row.check, state.selected[key] and "on" or "off", "")
			row.tick:SetShown(state.selected[key] and true or false)
			row.ShowTick()
			row.name:ClearAllPoints()
			row.name:SetPoint("TOPLEFT", grid, "TOPLEFT", CHECK_W + GAP, y)
			row.name:Show()
			row.label:SetFontObject(isBar and "GameFontNormal" or "GameFontHighlight")
			row.label:SetText(NameOf(key))
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
				cell:SetSize(colW, ROW_H)
				cell:ClearAllPoints()
				cell:SetPoint("TOPLEFT", grid, "TOPLEFT", ColX(j, col), y)
				local text, style, value = CellLook(key, col)
				local open = state.open and state.open.key == key and state.open.j == j
				Paint(cell, style, text, open)
				cell.mode = (col.other and (OtherwiseOf(KindOf(key), key, state.tab)))
					or (col.id and (CellOf(KindOf(key), key, state.tab, col.id))) or value
				cell:SetAlpha((col.index and trouble[col.index] and trouble[col.index].kind == "dead") and 0.45 or 1)
				cell:Show()
			end
			for j = n + 1, #row.cells do row.cells[j]:Hide() end
			y = y - ROW_H - (isBar and 6 or GAP)
			-- (The open cell's choices under its row.)
			if not state.look and state.open and state.open.key == key and cols[state.open.j] then
				local height = ChooserShow(key, cols[state.open.j])
				chooser:ClearAllPoints()
				chooser:SetPoint("TOPLEFT", grid, "TOPLEFT", CHECK_W + GAP, y)
				y = y - height - GAP
				openShown = true
			end
		end
		for i = #keys + 1, #rows do
			local row = rows[i]
			row.key = nil
			row.check:Hide()
			row.name:Hide()
			for _, cell in ipairs(row.cells) do cell:Hide() end
		end
		if not openShown then
			chooser:Hide()
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
		grid:SetHeight(-y)
		return -y
	end
	grid.Layout = Layout

	-- A bar's rows (tab: its group; ids its spells, in order): lays out, gives the height.
	function grid.Show(tab, ids)
		if tab ~= state.tab then
			state.open, state.editing, state.bulkCol, state.bulkValue = nil, nil, 1, 1
			wipe(state.selected)
		end
		state.tab, state.ids = tab, ids or {}
		local listed = {}
		for _, id in ipairs(state.ids) do listed[id] = true end
		for key in pairs(state.selected) do
			if not listed[key] then state.selected[key] = nil end
		end
		return Layout()
	end
	return grid
end
