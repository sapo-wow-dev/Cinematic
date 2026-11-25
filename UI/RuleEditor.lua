-- The CQL rule editor (2026-11-25, Tools/rule-editor-redesign-plan.md; mockup
-- Tools/rule-editor/mockup.html). One window, 600 x 600, that never grows:
--   the rule (typed, colored, suggestions under it), the logic bar, the readout (each word
--   true or false where you stand and the verdict), the grid note, then the picker: a
--   sidebar of categories (UI/RuleCatalog.lua) with a search box, and a pane of that
--   category's words (Units: one pane, a Target / Mouse / Focus switch), and the footer.
-- Opened by ns.OpenRuleEditor(target): { label, Text(), Close(text), SetText(text)?,
-- ResetToGrid()?, grid?, key?, follow?, context? } (callers: UI/GridRows.lua's rows,
-- Camera/TriggersPage.lua, UI/CooldownGrid.lua, Visions/CombatSoundRules.lua).
local _, ns = ...
local L = ns.L

local EDIT_W, EDIT_H = 600, 600
local PAD = 14
local SIDE_W = 132
local WELL_H = 62
local GREEN = "Interface\\COMMON\\Indicator-Green"
local YES, NO = "Interface\\RaidFrame\\ReadyCheck-Ready", "Interface\\RaidFrame\\ReadyCheck-NotReady"
local FLAT = "Interface\\Buttons\\WHITE8x8"
local SEARCH_ICON = "Interface\\Common\\UI-Searchbox-Icon"

-- The theme's colors (Skin.lua's roles; StyleThemes.lua's palette when one is picked).
local DEFAULT_ROLES = { accent = { 1, 0.82, 0 }, edge = { 0.5, 0.5, 0.5 }, field = { 0.06, 0.06, 0.08 },
	window = { 0.04, 0.04, 0.05 }, well = { 0, 0, 0 } }
local function Role(role)
	local palette = ns.MenuPalette and ns.MenuPalette()
	return palette and palette[role] or DEFAULT_ROLES[role]
end
local TEXT, DIM, FAINT = { 0.92, 0.9, 0.85 }, { 0.6, 0.58, 0.54 }, { 0.42, 0.4, 0.37 }
local TRUE_C, FALSE_C, ERR_C = { 0.38, 0.88, 0.38 }, { 0.55, 0.45, 0.45 }, { 1, 0.38, 0.38 }

local function Hex(c) return ("%02x%02x%02x"):format(c[1] * 255, c[2] * 255, c[3] * 255) end
local function Colored(c, text) return "|cff" .. Hex(c) .. text .. "|r" end

-- A flat fill, and a one-pixel edge of four lines (crisp at any scale: never snapped).
local function NoSnap(t)
	if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
	if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
	return t
end
local function Fill(frame, c, a, layer, sub)
	local t = NoSnap(frame:CreateTexture(nil, layer or "BACKGROUND", nil, sub or -7))
	t:SetAllPoints()
	t:SetTexture(FLAT)
	t:SetVertexColor(c[1], c[2], c[3], a or 1)
	return t
end
local function Edge(frame, c, a)
	local lines = {}
	for i, spec in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 1 },
		{ "TOPLEFT", "BOTTOMLEFT", 1, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", 1, 0 } }) do
		local t = NoSnap(frame:CreateTexture(nil, "BORDER", nil, 1))
		t:SetTexture(FLAT)
		t:SetPoint(spec[1])
		t:SetPoint(spec[2])
		if spec[3] == 1 then t:SetWidth(1) else t:SetHeight(1) end
		lines[i] = t
	end
	function lines.Paint(color, alpha)
		for i = 1, 4 do lines[i]:SetVertexColor(color[1], color[2], color[3], alpha or 1) end
	end
	lines.Paint(c, a)
	return lines
end

local function Tip(widget, text)
	widget:SetScript("OnEnter", function(self)
		local shown = type(text) == "function" and text(self) or text
		if not shown or shown == "" then return end
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText(shown, 1, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	widget:SetScript("OnLeave", GameTooltip_Hide)
end

-- A flat button: fill, edge, a label, a hover wash; :Paint(color, state) sets its look
-- (state: nil, "on" (picked/selected), "rule" (in the rule)); :SetDot(true) shows the
-- green dot at its right.
local function FlatButton(parent, font)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(20)
	b.fill = Fill(b, Role("field"), 0.95)
	b.edge = Edge(b, Role("edge"), 0.5)
	b.wash = NoSnap(b:CreateTexture(nil, "HIGHLIGHT"))
	b.wash:SetAllPoints()
	b.wash:SetTexture(FLAT)
	b.wash:SetVertexColor(1, 1, 1, 0.07)
	b.text = b:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
	b.text:SetPoint("LEFT", 8, 0)
	b.text:SetJustifyH("LEFT")
	b.dot = b:CreateTexture(nil, "OVERLAY")
	b.dot:SetSize(9, 9)
	b.dot:SetPoint("RIGHT", -5, 0)
	b.dot:SetTexture(GREEN)
	b.dot:Hide()
	b.pushed = 0
	b:SetScript("OnMouseDown", function(self) self.text:SetPoint("LEFT", 8, -1) end)
	b:SetScript("OnMouseUp", function(self) self.text:SetPoint("LEFT", 8, 0) end)
	function b:SetLabel(text, dotRoom)
		self.text:SetText(text)
		self.dotRoom = dotRoom
		self:SetWidth(math.floor(self.text:GetStringWidth() + 16 + (dotRoom and 11 or 0) + 0.5))
	end
	function b:Paint(color, state)
		local accent = Role("accent")
		if state == "rule" then
			self.fill:SetVertexColor(accent[1] * 0.22, accent[2] * 0.22, accent[3] * 0.22, 1)
			self.edge.Paint(accent, 0.9)
		elseif state == "on" then
			self.fill:SetVertexColor(color[1] * 0.2, color[2] * 0.2, color[3] * 0.2, 1)
			self.edge.Paint(color, 0.9)
		else
			local field = Role("field")
			self.fill:SetVertexColor(field[1], field[2], field[3], 0.95)
			self.edge.Paint(color, 0.42)
		end
		self.text:SetTextColor(color[1], color[2], color[3])
	end
	function b:SetDot(on) self.dot:SetShown(on and true or false) end
	return b
end

-- Places buttons left to right from x within width, wrapping; gives the height used.
local GAP, ROW_H = 4, 24
local function Flow(buttons, parent, x, y, width)
	local px, py = x, y
	for _, b in ipairs(buttons) do
		local w = b:GetWidth()
		if px > x and px + w > x + width then px, py = x, py - ROW_H end
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", parent, "TOPLEFT", px, py)
		b:Show()
		px = px + w + GAP
	end
	return y - py + ROW_H
end

local editor, target

-- The rule's pieces, for the readout and the In this rule list: words, value words
-- (axis:value), AND / OR / NOT and brackets, as Frames.lua's ns.CompileRule reads them.
local OPS = { ["and"] = "and", ["&"] = "and", ["&&"] = "and", ["or"] = "or", ["|"] = "or", ["||"] = "or",
	["not"] = "not", ["!"] = "not" }
local function Pieces(text)
	local out, i = {}, 1
	while i <= #text do
		local c = text:sub(i, i)
		if c:find("%s") then
			i = i + 1
		elseif c == "(" or c == ")" then
			out[#out + 1] = { paren = c }
			i = i + 1
		elseif c == "&" or c == "|" or c == "!" then
			local run = text:match("^[&|]+", i) or c
			out[#out + 1] = { op = OPS[run] or "and" }
			i = i + #run
		else
			local word = text:match("^[%w_]+", i)
			if not word then
				out[#out + 1] = { bad = c }
				i = i + 1
			else
				i = i + #word
				local lower = word:lower()
				if text:sub(i, i) == ":" then
					local quoted = text:match('^"([^"]*)"', i + 1)
					local value = quoted and ('"' .. quoted .. '"') or (text:match("^[%w_,%.%-']*", i + 1) or "")
					out[#out + 1] = { axis = lower, value = value, raw = word .. ":" .. value }
					i = i + 1 + #value
				elseif OPS[lower] then
					out[#out + 1] = { op = OPS[lower] }
				else
					out[#out + 1] = { word = lower, raw = word }
				end
			end
		end
	end
	return out
end

-- The word's entry in the catalog (its label, unit, category), by the word or an alias.
local byWord, byField
local function Catalogued()
	if byWord then return byWord, byField end
	byWord, byField = {}, {}
	for _, it in ipairs(ns.RuleCatalogWords("row")) do byWord[it.entry.w] = it end
	for _, ctx in ipairs({ "tooltip", "edge" }) do
		for _, it in ipairs(ns.RuleCatalogWords(ctx)) do byWord[it.entry.w] = byWord[it.entry.w] or it end
	end
	for word, it in pairs(byWord) do
		local field = ns.RULE_WORDS[word]
		if field and not byField[field] then byField[field] = it end
	end
	return byWord, byField
end
local function Lookup(word)
	local words, fields = Catalogued()
	return words[word] or fields[ns.RULE_WORDS[word] or ""]
end
-- A piece's name for people: "Target: Elite", "zone: Elwynn Forest", "In combat".
local function PieceLabel(p)
	if p.axis then
		local axis = ns.RULE_AXES and ns.RULE_AXES[p.axis]
		-- (A quoted value is one; else commas list several.)
		local values = {}
		local quoted = p.value:match('^"(.*)"$')
		if quoted then
			values[1] = quoted
		else
			for value in p.value:gmatch("[^,]+") do values[#values + 1] = value end
		end
		local names = {}
		for _, value in ipairs(values) do
			names[#names + 1] = ns.AxisValueName and ns.AxisValueName(p.axis, value:lower()) or value
		end
		return (axis and L[axis.label] or p.axis) .. ": " .. table.concat(names, ", ")
	end
	local it = Lookup(p.word)
	if not it then return p.raw or p.word end
	return ns.RuleWordName(it)
end

-- A word's full name: its unit first ("Mouse: Elite"), unless the name says it already
-- (the target's "Enemy targeted", as the grids name it).
function ns.RuleWordName(it)
	if it.unit and not it.entry.named then return it.unit.label .. ": " .. it.entry.l end
	return it.entry.l
end

local BuildEditor
function ns.OpenRuleEditor(newTarget)
	if not editor then BuildEditor() end
	if editor:IsShown() then editor:Hide() end
	editor.Open(newTarget)
end

function BuildEditor()
	local BACKDROP = BackdropTemplateMixin and "BackdropTemplate" or nil
	editor = CreateFrame("Frame", "CinematicRuleEditor", UIParent, BACKDROP)
	editor:SetSize(EDIT_W, EDIT_H)
	if editor.SetBackdrop then
		editor:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 } })
	end
	ns.SkinWindow(editor)
	editor:SetPoint("CENTER")
	editor:SetFrameStrata("DIALOG")
	editor:SetToplevel(true)
	editor:SetClampedToScreen(true)
	editor:EnableMouse(true)
	ns.DockBeside(editor, "ruleEditor")
	tinsert(UISpecialFrames, "CinematicRuleEditor") -- (Escape closes it)
	local settings = _G.SettingsPanel or _G.InterfaceOptionsFrame
	if settings then
		settings:HookScript("OnHide", function() if editor:IsShown() then editor:Hide() end end)
	end
	if ns.db then ns.db.ruleEditorOpen = nil end -- (the old editor's +N lines: gone)
	local state = { context = "row", hist = {}, fut = {}, autoAnd = nil, find = "", sugg = {}, suggOn = 1 }
	editor.state = state
	local accentParts = {} -- (painted again from the theme as it opens)

	-- Title ---------------------------------------------------------------------------
	local close = ns.SkinClose(CreateFrame("Button", nil, editor, "UIPanelCloseButton"))
	close:SetPoint("TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function() editor:Hide() end)
	local cql = CreateFrame("Frame", nil, editor)
	cql:SetPoint("TOPLEFT", PAD, -9)
	cql:SetSize(36, 16)
	cql:EnableMouse(true)
	local cqlText = cql:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	cqlText:SetPoint("LEFT")
	cqlText:SetText("CQL")
	accentParts[#accentParts + 1] = function(c) cqlText:SetTextColor(c[1], c[2], c[3]) end
	Tip(cql, L["CQL is the words a rule is written in, joined with AND, OR and NOT."])
	local heading = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	heading:SetPoint("TOP", 0, -10)
	heading:SetWidth(EDIT_W - 240)
	heading:SetWordWrap(false)
	local titleLine = NoSnap(editor:CreateTexture(nil, "ARTWORK"))
	titleLine:SetTexture(FLAT)
	titleLine:SetHeight(1)
	titleLine:SetPoint("TOPLEFT", PAD, -30)
	titleLine:SetPoint("TOPRIGHT", -PAD, -30)
	accentParts[#accentParts + 1] = function(c) titleLine:SetVertexColor(c[1], c[2], c[3], 0.25) end

	-- The rule --------------------------------------------------------------------------
	local well = CreateFrame("Frame", nil, editor)
	well:SetPoint("TOPLEFT", PAD, -38)
	well:SetSize(EDIT_W - PAD * 2, WELL_H)
	Fill(well, Role("well"), 0.85)
	local wellEdge = Edge(well, Role("edge"), 0.5)
	local typing = NoSnap(well:CreateTexture(nil, "BACKGROUND", nil, -6))
	typing:SetAllPoints()
	typing:SetTexture(FLAT)
	typing:Hide()
	accentParts[#accentParts + 1] = function(c) typing:SetVertexColor(c[1], c[2], c[3], 0.06) end
	local box = CreateFrame("EditBox", nil, well)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetFontObject(ChatFontNormal)
	box:SetPoint("TOPLEFT", 8, -7)
	box:SetPoint("BOTTOMRIGHT", -8, 7)
	box:EnableMouse(true)
	box:SetMaxLetters(255)
	if box.SetAltArrowKeyMode then box:SetAltArrowKeyMode(false) end
	-- (The words in their colors: a colored copy over the box's own grey text, as before:
	-- Forever's cursor takes the text's color, so the box's own text stays seen.)
	local over = CreateFrame("Frame", nil, well)
	over:SetAllPoints(well)
	over:SetFrameLevel(box:GetFrameLevel() + 2)
	local colored = over:CreateFontString(nil, "OVERLAY")
	colored:SetFontObject(ChatFontNormal)
	colored:SetPoint("TOPLEFT", box, "TOPLEFT")
	colored:SetWidth(EDIT_W - PAD * 2 - 16)
	colored:SetJustifyH("LEFT")
	colored:SetJustifyV("TOP")
	colored:SetWordWrap(true)
	box:SetTextColor(0.8, 0.8, 0.8, 1)
	box:SetShadowColor(0, 0, 0, 0)
	local count = over:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	count:SetPoint("BOTTOMRIGHT", -6, 4)
	well:EnableMouse(true)
	well:SetScript("OnMouseDown", function() box:SetFocus() end)
	box:SetScript("OnEditFocusGained", function()
		typing:Show()
		wellEdge.Paint(Role("accent"), 0.7)
	end)
	box:SetScript("OnEditFocusLost", function()
		typing:Hide()
		wellEdge.Paint(Role("edge"), 0.5)
	end)

	-- Suggestions, under the rule while a word's being typed.
	local sugg = CreateFrame("Frame", nil, editor)
	sugg:SetFrameStrata("FULLSCREEN_DIALOG")
	sugg:SetPoint("TOPLEFT", well, "BOTTOMLEFT", 0, -2)
	sugg:SetWidth(360)
	Fill(sugg, { 0.07, 0.065, 0.06 }, 0.98)
	local suggEdge = Edge(sugg, Role("accent"), 0.6)
	accentParts[#accentParts + 1] = function(c) suggEdge.Paint(c, 0.6) end
	sugg:Hide()
	sugg.rows = {}
	local suggHint = sugg:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	suggHint:SetText(L["Up and down to choose, Tab or Enter to take, Escape to close"])

	-- The logic bar ------------------------------------------------------------------------
	local logic = CreateFrame("Frame", nil, editor)
	logic:SetPoint("TOPLEFT", well, "BOTTOMLEFT", 0, -6)
	logic:SetSize(EDIT_W - PAD * 2, 20)

	-- The readout ----------------------------------------------------------------------------
	local readout = CreateFrame("Frame", nil, editor)
	readout:SetPoint("TOPLEFT", logic, "BOTTOMLEFT", 0, -6)
	readout:SetSize(EDIT_W - PAD * 2, 50)
	Fill(readout, Role("well"), 0.55)
	Edge(readout, Role("edge"), 0.3)
	local verdict = readout:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	verdict:SetPoint("BOTTOMRIGHT", -8, 7)
	verdict:SetJustifyH("RIGHT")
	verdict:SetWordWrap(false)
	local verdictIcon = readout:CreateTexture(nil, "OVERLAY")
	verdictIcon:SetSize(14, 14)
	verdictIcon:SetPoint("RIGHT", verdict, "LEFT", -3, 0)
	local message = readout:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	message:SetPoint("TOPLEFT", 8, -7)
	message:SetPoint("RIGHT", -8, 0)
	message:SetJustifyH("LEFT")
	message:SetWordWrap(true)
	local chips, opTexts = {}, {}
	local gridNote = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	gridNote:SetPoint("TOPLEFT", readout, "BOTTOMLEFT", 2, -4)
	gridNote:SetWidth(EDIT_W - PAD * 2 - 4)
	gridNote:SetJustifyH("LEFT")

	-- The picker -------------------------------------------------------------------------------
	local FOOT_H = 40
	local picker = CreateFrame("Frame", nil, editor)
	picker:SetPoint("TOPLEFT", readout, "BOTTOMLEFT", 0, -22)
	picker:SetPoint("BOTTOMRIGHT", -PAD, FOOT_H)
	Fill(picker, Role("well"), 0.45)
	Edge(picker, Role("edge"), 0.3)
	local side = CreateFrame("Frame", nil, picker)
	side:SetPoint("TOPLEFT", 1, -1)
	side:SetPoint("BOTTOMLEFT", 1, 1)
	side:SetWidth(SIDE_W)
	Fill(side, { 0, 0, 0 }, 0.25)
	local sideLine = NoSnap(picker:CreateTexture(nil, "BORDER"))
	sideLine:SetTexture(FLAT)
	sideLine:SetWidth(1)
	sideLine:SetPoint("TOPLEFT", side, "TOPRIGHT")
	sideLine:SetPoint("BOTTOMLEFT", side, "BOTTOMRIGHT")
	sideLine:SetVertexColor(1, 1, 1, 0.08)
	-- Find a word.
	local findWrap = CreateFrame("Frame", nil, side)
	findWrap:SetPoint("TOPLEFT", 6, -6)
	findWrap:SetPoint("TOPRIGHT", -6, -6)
	findWrap:SetHeight(20)
	Fill(findWrap, Role("well"), 0.9)
	local findEdge = Edge(findWrap, Role("edge"), 0.45)
	local findIcon = findWrap:CreateTexture(nil, "OVERLAY")
	findIcon:SetSize(12, 12)
	findIcon:SetPoint("LEFT", 5, 0)
	findIcon:SetTexture(SEARCH_ICON)
	findIcon:SetVertexColor(0.7, 0.7, 0.7)
	local find = CreateFrame("EditBox", nil, findWrap)
	find:SetPoint("TOPLEFT", 20, 0)
	find:SetPoint("BOTTOMRIGHT", -4, 0)
	find:SetAutoFocus(false)
	find:SetFontObject("GameFontHighlightSmall")
	find:SetMaxLetters(30)
	local findHint = findWrap:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	findHint:SetPoint("LEFT", 21, 0)
	findHint:SetText(L["Find a word"])
	Tip(findWrap, L["Searches every word by its name, what you'd type and what it means. Enter adds the first."])
	find:SetScript("OnEditFocusGained", function() findEdge.Paint(Role("accent"), 0.7) end)
	find:SetScript("OnEditFocusLost", function() findEdge.Paint(Role("edge"), 0.45) end)
	local catList = CreateFrame("Frame", nil, side)
	catList:SetPoint("TOPLEFT", 0, -32)
	catList:SetPoint("BOTTOMRIGHT")
	local catButtons = {}
	-- The pane, scrolling when a category's words don't fit.
	local scroll = CreateFrame("ScrollFrame", nil, picker)
	scroll:SetPoint("TOPLEFT", side, "TOPRIGHT", 1, 0)
	scroll:SetPoint("BOTTOMRIGHT", -1, 1)
	local pane = CreateFrame("Frame", nil, scroll)
	pane:SetSize(EDIT_W - PAD * 2 - SIDE_W - 4, 10)
	scroll:SetScrollChild(pane)
	scroll:EnableMouseWheel(true)
	local thumb = NoSnap(scroll:CreateTexture(nil, "OVERLAY"))
	thumb:SetTexture(FLAT)
	thumb:SetWidth(3)
	thumb:Hide()
	local function PlaceThumb()
		local range = scroll:GetVerticalScrollRange() or 0
		if issecretvalue and issecretvalue(range) then return end
		if range < 1 then thumb:Hide() return end
		local h = scroll:GetHeight()
		local size = math.max(20, h * h / (h + range))
		thumb:ClearAllPoints()
		thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", -2, -((h - size) * (scroll:GetVerticalScroll() / range)))
		thumb:SetHeight(size)
		thumb:Show()
	end
	accentParts[#accentParts + 1] = function(c) thumb:SetVertexColor(c[1], c[2], c[3], 0.5) end
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local range = self:GetVerticalScrollRange() or 0
		self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * 30)))
		PlaceThumb()
	end)
	local paneW = EDIT_W - PAD * 2 - SIDE_W - 4
	local LABEL_W = 62
	local paneTitle = pane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	paneTitle:SetPoint("TOPLEFT", 10, -9)
	local paneSub = pane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	paneSub:SetPoint("BOTTOMLEFT", paneTitle, "BOTTOMRIGHT", 8, 0)
	local emptyText = pane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	emptyText:SetPoint("TOPLEFT", 10, -34)
	emptyText:SetWidth(paneW - 20)
	emptyText:SetJustifyH("LEFT")
	local unitSwitch = CreateFrame("Frame", nil, pane)
	unitSwitch:SetPoint("TOPLEFT", 10, -30)
	unitSwitch:SetSize(240, 20)
	local unitButtons = {}

	-- Footer --------------------------------------------------------------------------------------
	local done = ns.PanelButton(editor)
	done:SetSize(96, 22)
	done:SetPoint("BOTTOMRIGHT", -PAD, 10)
	done:SetText(L["Done"])
	done:SetScript("OnClick", function() editor:Hide() end)
	if done.SetMotionScriptsWhileDisabled then done:SetMotionScriptsWhileDisabled(true) end
	Tip(done, function()
		if not done:IsEnabled() then return L["The rule isn't finished; finish it or press Escape to undo."] end
		return L["Closes the editor, keeping the rule."]
	end)
	local resetGrid = ns.PanelButton(editor)
	resetGrid:SetSize(120, 22)
	resetGrid:SetPoint("BOTTOMLEFT", PAD, 10)
	resetGrid:SetText(L["Reset to grid"])
	resetGrid:SetScript("OnClick", function()
		if target and target.ResetToGrid then target.ResetToGrid() end
		target = nil
		editor:Hide()
	end)
	Tip(resetGrid, L["Drops the rule, so the row's dropdowns decide again, ticked as they were before."])
	local followButton = ns.PanelButton(editor)
	followButton:SetSize(120, 22)
	followButton:SetPoint("LEFT", resetGrid, "RIGHT", 8, 0)
	followButton:SetText(L["Follow a row"])
	followButton:SetScript("OnClick", function(self)
		local follow = target and target.follow
		if not follow then return end
		ns.ContextMenu(self, function(_, root)
			ns.MenuTitle(root, L["Follow another row"])
			root:CreateRadio(L["None: its own settings"], function() return not follow.leader() end, function()
				follow.set(nil)
			end)
			ns.MenuDivider(root)
			for _, choice in ipairs(follow.choices()) do
				local key = choice[1]
				if key ~= follow.key then
					local loops = ns.FollowKey(key) == follow.key
					local radio = root:CreateRadio(choice[2] .. (loops and " " .. L["(follows this one)"] or ""),
						function() return follow.leader() == key end, function()
							follow.set(key)
							target = nil
							editor:Hide()
						end)
					if loops and radio and radio.SetEnabled then radio:SetEnabled(false) end
				end
			end
		end)
	end)
	Tip(followButton, L["Makes this row show whenever another row of its table does, instead of a rule."])

	-- Facts where you stand, as this rule's row reads them.
	local function Facts()
		return ns.db and ns.RuleFactsFor and ns.RuleFactsFor(target and target.key) or nil
	end
	local function IsTrue(facts, word)
		if not facts then return false end
		local field = ns.RULE_WORDS[word]
		if field then return facts[field] and true or false end
		return false
	end

	-- Editing the text -----------------------------------------------------------------------------
	local Refresh, ShowPane, Suggest, HideSuggest
	local programmatic = false
	local function Recolor()
		colored:SetText(ns.ColoredRule(box:GetText()))
		local n = #box:GetText()
		count:SetText(n > 200 and (n .. "/255") or "")
	end
	local function Changed()
		if target and target.SetText then target.SetText(box:GetText()) end
		Refresh()
		ShowPane()
	end
	local function Push()
		state.hist[#state.hist + 1] = { box:GetText(), box:GetCursorPosition() }
		if #state.hist > 50 then table.remove(state.hist, 1) end
		state.fut = {}
	end
	local function SetText(text, cursor)
		programmatic = true
		box:SetText(text)
		programmatic = false
		box:SetCursorPosition(cursor or #text)
		box:SetFocus()
		Recolor()
		Changed()
	end
	editor.SetRuleText = SetText -- (for the tests)
	box:SetScript("OnTextChanged", function(self, userInput)
		-- (No new lines in a rule: Enter is Done.)
		local text = self:GetText()
		if text:find("[\r\n]") then
			local cursor = self:GetCursorPosition()
			programmatic = true
			self:SetText((text:gsub("[\r\n]", "")))
			programmatic = false
			self:SetCursorPosition(math.max(0, cursor - 1))
		end
		Recolor()
		if userInput and not programmatic then
			-- (Typing goes in the history a word at a time.)
			local now = GetTime()
			if not state.typingAt or now - state.typingAt > 1.2 then Push() end
			state.typingAt = now
			state.autoAnd = nil
			Changed()
			Suggest()
		end
	end)
	-- A word in at the cursor: spaced from its neighbors; AND first after a word or ")";
	-- OR right after an AND that was put in for you takes its place; with not, NOT first.
	local function Insert(word, withNot)
		Push()
		state.typingAt = nil
		local text, pos = box:GetText(), box:GetCursorPosition()
		local before, after = text:sub(1, pos), text:sub(pos + 1)
		local isLogic = word == "and" or word == "or" or word == "not" or word == "(" or word == ")"
		if word == "or" and state.autoAnd and before:gsub("%s+$", "") == state.autoAnd then
			before = state.autoAnd:gsub("%s*and$", "") -- (the AND we added: OR in its place)
		end
		state.autoAnd = nil
		-- (Not after AND, OR or NOT: those want a word next. Run ofline/ruleeditor.lua
		-- caught "combat or" + a word giving "combat or and calm".)
		local lastWord = before:match("([%w_]+)%s*$")
		local afterLogic = lastWord and OPS[lastWord:lower()] ~= nil
		if (not isLogic or word == "(" or word == "not") and not afterLogic and before:find("[%w_\"%)]%s*$") then
			before = before:gsub("%s+$", "") .. " and"
			state.autoAnd = before
		end
		local piece = withNot and ("not " .. word) or word
		local lead = (before == "" or before:find("[%s(]$") or word == ")") and "" or " "
		local trail = (word ~= "(" and after:find("^[%w_(]")) and " " or ""
		SetText(before .. lead .. piece .. trail .. after, #before + #lead + #piece)
		HideSuggest()
	end
	editor.Insert = Insert -- (for the tests)
	local function Undo()
		local h = table.remove(state.hist)
		if not h then return end
		state.fut[#state.fut + 1] = { box:GetText(), box:GetCursorPosition() }
		state.autoAnd, state.typingAt = nil, nil
		SetText(h[1], h[2])
	end
	local function Redo()
		local f = table.remove(state.fut)
		if not f then return end
		state.hist[#state.hist + 1] = { box:GetText(), box:GetCursorPosition() }
		state.autoAnd, state.typingAt = nil, nil
		SetText(f[1], f[2])
	end
	editor.Undo, editor.Redo = Undo, Redo

	-- The logic bar's buttons.
	do
		local x = 0
		local LOGIC = { { "AND", "and", L["Both sides true. A word added after a word gets AND by itself."] },
			{ "OR", "or", L["Either side true. Right after an AND that was added for you, it takes its place."] },
			{ "NOT", "not", L["The next word or brackets false. Shift-click a word to add it with NOT."] },
			{ "(", "(", L["Opens a group, around what you add next."] }, { ")", ")", L["Closes the group."] } }
		for _, spec in ipairs(LOGIC) do
			local b = FlatButton(logic, "GameFontHighlightSmall")
			b:SetLabel(spec[1])
			b:SetWidth(math.max(b:GetWidth(), 30))
			b.text:ClearAllPoints()
			b.text:SetPoint("CENTER")
			b:SetScript("OnMouseDown", nil)
			b:SetScript("OnMouseUp", nil)
			b:Paint({ 0.9, 0.9, 0.9 })
			b:SetPoint("LEFT", x, 0)
			b:SetScript("OnClick", function() Insert(spec[2]) end)
			Tip(b, spec[3])
			x = x + b:GetWidth() + GAP
		end
		x = x + 10
		for _, spec in ipairs({ { L["Undo"], Undo, L["Undoes the last change (Ctrl+Z)."] },
			{ L["Redo"], Redo, L["Does it again (Ctrl+Y)."] },
			{ L["Clear"], function() Push() SetText("", 0) end, L["Empties the rule."] } }) do
			local b = FlatButton(logic, "GameFontNormalSmall")
			b:SetLabel(spec[1])
			b.text:ClearAllPoints()
			b.text:SetPoint("CENTER")
			b:SetScript("OnMouseDown", nil)
			b:SetScript("OnMouseUp", nil)
			b:SetPoint("LEFT", x, 0)
			b:SetScript("OnClick", spec[2])
			accentParts[#accentParts + 1] = function(c) b:Paint(c) end
			Tip(b, spec[3])
			x = x + b:GetWidth() + GAP
		end
	end

	-- Suggestions ------------------------------------------------------------------------------------
	local function Partial()
		local before = box:GetText():sub(1, box:GetCursorPosition())
		if before:find(":[%w_,%.%-']*$") then return "" end -- (a value being typed)
		return before:match("([%a_][%w_]*)$") or ""
	end
	-- Words for q, best first: the word starts with it, its name does, a search word does,
	-- either holds it, its tip does.
	local function Matches(q, limit)
		q = q:lower()
		if q == "" then return {} end
		local found, seen = {}, {}
		for _, it in ipairs(ns.RuleCatalogWords(state.context)) do
			local e = it.entry
			if not seen[e.w] then
				local w, l = e.w:lower(), e.l:lower()
				local score = (w:sub(1, #q) == q and 0) or (l:sub(1, #q) == q and 1)
					or (e.find and (" " .. e.find:lower()):find(" " .. q, 1, true) and 2)
					or ((w:find(q, 1, true) or l:find(q, 1, true)) and 3)
					or (e.t and e.t:lower():find(q, 1, true) and 4) or nil
				if score then
					seen[e.w] = true
					found[#found + 1] = { score = score, it = it }
				end
			end
		end
		table.sort(found, function(a, b)
			if a.score ~= b.score then return a.score < b.score end
			return #a.it.entry.w < #b.it.entry.w
		end)
		local out = {}
		for i = 1, math.min(limit, #found) do out[i] = found[i].it end
		return out
	end
	editor.Matches = Matches
	local function SuggRow(i)
		local row = sugg.rows[i]
		if row then return row end
		row = CreateFrame("Button", nil, sugg)
		row:SetHeight(18)
		row:SetPoint("TOPLEFT", 1, -1 - (i - 1) * 18)
		row:SetPoint("RIGHT", -1, 0)
		row.on = NoSnap(row:CreateTexture(nil, "BACKGROUND"))
		row.on:SetAllPoints()
		row.on:SetTexture(FLAT)
		row.word = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.word:SetPoint("LEFT", 8, 0)
		row.label = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		row.label:SetPoint("LEFT", 132, 0)
		row.dot = row:CreateTexture(nil, "OVERLAY")
		row.dot:SetSize(8, 8)
		row.dot:SetPoint("RIGHT", -8, 0)
		row.dot:SetTexture(GREEN)
		row:SetScript("OnEnter", function() state.suggOn = i Suggest(true) end)
		row:SetScript("OnClick", function() editor.TakeSuggestion(state.sugg[i]) end)
		sugg.rows[i] = row
		return row
	end
	function HideSuggest()
		state.sugg = {}
		sugg:Hide()
	end
	-- (keep: only repaint the rows, the list as it is.)
	function Suggest(keep)
		if not keep then
			local q = Partial()
			state.sugg = #q >= 2 and Matches(q, 6) or {}
			-- (A whole word typed already: no list, so Enter is Done. Run ruleeditor.lua.)
			if ns.RULE_WORDS[q:lower()] then state.sugg = {} end
			state.suggOn = 1
			state.cursorAt = box:GetCursorPosition() -- (where the arrows put it back)
		end
		if #state.sugg == 0 then sugg:Hide() return end
		local facts, accent = Facts(), Role("accent")
		for i, it in ipairs(state.sugg) do
			local row = SuggRow(i)
			row.word:SetText(Colored(it.cat.color, it.entry.w .. (it.entry.pick and "..." or "")))
			row.label:SetText(ns.RuleWordName(it))
			row.dot:SetShown(IsTrue(facts, it.entry.w))
			row.on:SetVertexColor(accent[1], accent[2], accent[3], i == state.suggOn and 0.16 or 0)
			row:Show()
		end
		for i = #state.sugg + 1, #sugg.rows do sugg.rows[i]:Hide() end
		suggHint:ClearAllPoints()
		suggHint:SetPoint("TOPLEFT", 9, -4 - #state.sugg * 18)
		sugg:SetHeight(#state.sugg * 18 + 20)
		sugg:Show()
	end
	local OpenPick
	function editor.TakeSuggestion(it)
		if not it then return end
		Push()
		local pos, q = box:GetCursorPosition(), Partial()
		local text = box:GetText()
		local before, after = text:sub(1, pos - #q), text:sub(pos + 1)
		HideSuggest()
		state.autoAnd = nil
		if it.entry.pick then
			SetText(before .. after, #before)
			OpenPick(it, well)
			return
		end
		local trail = after:find("^[%w_(]") and " " or ""
		SetText(before .. it.entry.w .. trail .. after, #before + #it.entry.w)
	end
	box:SetScript("OnTabPressed", function()
		if sugg:IsShown() then editor.TakeSuggestion(state.sugg[state.suggOn]) end
	end)
	box:SetScript("OnEnterPressed", function()
		if sugg:IsShown() then
			editor.TakeSuggestion(state.sugg[state.suggOn])
		elseif done:IsEnabled() then
			editor:Hide()
		end
	end)
	box:SetScript("OnEscapePressed", function()
		if sugg:IsShown() then HideSuggest() else editor:Hide() end
	end)
	box:SetScript("OnArrowPressed", function(self, key)
		if not sugg:IsShown() or (key ~= "UP" and key ~= "DOWN") then return end
		local n = #state.sugg
		state.suggOn = (state.suggOn - 1 + (key == "DOWN" and 1 or -1)) % n + 1
		Suggest(true)
		-- (The cursor stays where it was: the arrow chose a suggestion, not a line.)
		local at = state.cursorAt
		if at then C_Timer.After(0, function() if self:HasFocus() then self:SetCursorPosition(at) end end) end
	end)
	box:SetScript("OnCursorChanged", function(self)
		if not sugg:IsShown() then state.cursorAt = self:GetCursorPosition() end
	end)
	box:HookScript("OnEditFocusLost", function()
		C_Timer.After(0.15, function() if not box:HasFocus() then HideSuggest() end end)
	end)
	box:SetScript("OnKeyDown", function(_, key)
		if IsControlKeyDown() and key == "Z" then Undo() elseif IsControlKeyDown() and key == "Y" then Redo() end
	end)

	-- Value menus (RuleAxes.lua's Pick) ----------------------------------------------------------------
	function OpenPick(it, anchor)
		local axis = ns.RULE_AXES and ns.RULE_AXES[it.entry.pick]
		local ok, list = false, {}
		if axis and axis.Pick then ok, list = pcall(axis.Pick) end
		if not ok then list = {} end
		ns.ContextMenu(anchor, function(_, root)
			ns.MenuTitle(root, (it.entry.l:gsub("%.%.%.$", "")))
			for _, picked in ipairs(list) do
				root:CreateButton(picked[2] .. "  " .. Colored(FAINT, picked[1]), function() Insert(picked[1]) end)
			end
			if #list == 0 then
				ns.MenuTitle(root, L["Nothing to pick here now"], _G.GRAY_FONT_COLOR)
			end
		end)
	end

	-- Word buttons ---------------------------------------------------------------------------------------
	local wordButtons = {} -- (word -> its button: made once, when its category first shows)
	editor.wordButtons = wordButtons
	local function WordTip(button)
		local it = button.it
		local e = it.entry
		local facts = Facts()
		GameTooltip:SetOwner(button, "ANCHOR_BOTTOMRIGHT")
		GameTooltip:SetText(ns.RuleWordName(it), 1, 1, 1)
		GameTooltip:AddLine(e.w .. (e.pick and "..." or ""), it.cat.color[1], it.cat.color[2], it.cat.color[3])
		if e.range and ns.RangeBandInfo then
			GameTooltip:AddLine(e.t, 1, 0.82, 0, true)
			GameTooltip:AddLine(ns.RangeBandInfo(e.w), 0.8, 0.8, 0.8, true)
		elseif e.t then
			GameTooltip:AddLine(e.t, 1, 0.82, 0, true)
		end
		if e.pick then
			GameTooltip:AddLine(L["Opens a menu of what's here and what you have."], 0.6, 0.6, 0.6, true)
		else
			local yes = IsTrue(facts, e.w)
			GameTooltip:AddLine(yes and L["True where you stand now."] or L["False where you stand now."],
				yes and TRUE_C[1] or 0.6, yes and TRUE_C[2] or 0.6, yes and TRUE_C[3] or 0.6)
			GameTooltip:AddLine((L["Click adds it; Shift-click adds NOT %s."]):format(e.w), 0.6, 0.6, 0.6, true)
		end
		GameTooltip:Show()
	end
	local function WordButton(it)
		local key = (it.unit and it.unit.key or "") .. "|" .. it.entry.w
		local b = wordButtons[key]
		if b then return b end
		b = FlatButton(pane)
		b.it = it
		b:SetLabel(it.entry.l, not it.entry.pick)
		b:SetScript("OnEnter", WordTip)
		b:SetScript("OnLeave", GameTooltip_Hide)
		b:SetScript("OnClick", function(self)
			if self.it.entry.pick then OpenPick(self.it, self) else Insert(self.it.entry.w, IsShiftKeyDown()) end
		end)
		wordButtons[key] = b
		wordButtons[it.entry.w] = wordButtons[it.entry.w] or b
		return b
	end
	-- Section labels and the results' headings, pooled.
	local labels, labelsUsed = {}, 0
	local function Label(text, color)
		labelsUsed = labelsUsed + 1
		local fs = labels[labelsUsed]
		if not fs then
			fs = pane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
			fs:SetJustifyH("LEFT")
			labels[labelsUsed] = fs
		end
		fs:SetText(text)
		fs:SetTextColor((color or DIM)[1], (color or DIM)[2], (color or DIM)[3])
		fs:Show()
		return fs
	end

	-- The words in the rule (by word, and value words by axis with its colon).
	local function InRule()
		local set = {}
		for _, p in ipairs(Pieces(box:GetText())) do
			if p.word then
				set[p.word] = true
				local field = ns.RULE_WORDS[p.word]
				local it = field and Lookup(p.word)
				if it then set[it.entry.w] = true end
			elseif p.axis then
				set[p.axis .. ":"] = true
			end
		end
		return set
	end

	-- The pane -----------------------------------------------------------------------------------------
	local function Units()
		for _, cat in ipairs(ns.RuleCatalog()) do if cat.units then return cat end end
	end
	local function UnitOf(key)
		local units = Units()
		for _, unit in ipairs(units and units.units or {}) do if unit.key == key then return unit end end
		return units and units.units[1]
	end
	local function CatOf(key)
		for _, cat in ipairs(ns.RuleCatalog()) do if cat.key == key then return cat end end
	end
	local function Shows(only) return only == nil or only[state.context] end
	local shownButtons = {}
	-- A list of { it } grouped under headings (true here, in this rule, search hits).
	local function Grouped(list, y)
		local groups, order = {}, {}
		for _, it in ipairs(list) do
			local key = it.cat.key .. (it.unit and ("|" .. it.unit.key) or "")
			if not groups[key] then
				groups[key] = {}
				order[#order + 1] = key
			end
			table.insert(groups[key], it)
		end
		for _, key in ipairs(order) do
			local first = groups[key][1]
			local head = Label(first.cat.name .. (first.unit and (" - " .. first.unit.label) or ""), first.cat.color)
			head:SetWidth(0)
			head:ClearAllPoints()
			head:SetPoint("TOPLEFT", pane, "TOPLEFT", 10, y)
			y = y - 15
			local buttons = {}
			for _, it in ipairs(groups[key]) do
				local b = WordButton(it)
				buttons[#buttons + 1] = b
				shownButtons[#shownButtons + 1] = b
			end
			y = y - Flow(buttons, pane, 10, y, paneW - 24) - 4
		end
		return y
	end
	local function Section(name, words, y, cat, unit)
		local buttons = {}
		for _, e in ipairs(words) do
			if Shows(e.only) then
				local b = WordButton({ entry = e, cat = cat, unit = unit })
				buttons[#buttons + 1] = b
				shownButtons[#shownButtons + 1] = b
			end
		end
		if #buttons == 0 then return y end
		local x = 10
		if name then
			local fs = Label(name:upper())
			fs:ClearAllPoints()
			fs:SetPoint("TOPLEFT", pane, "TOPLEFT", 10, y - 5)
			fs:SetWidth(LABEL_W - 4)
			x = 10 + LABEL_W
		end
		return y - Flow(buttons, pane, x, y, paneW - x - 14) - 3
	end
	function ShowPane()
		for _, b in pairs(wordButtons) do b:Hide() end
		for i = 1, #labels do labels[i]:Hide() end
		labelsUsed = 0
		wipe(shownButtons)
		emptyText:Hide()
		unitSwitch:Hide()
		local facts, inRule = Facts(), InRule()
		local y = -34
		local find = state.find:gsub("^%s+", ""):gsub("%s+$", "")
		if find ~= "" then
			local hits = Matches(find, 60)
			paneTitle:SetText((L["Words for \"%s\""]):format(find))
			paneTitle:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
			paneSub:SetText((L["%d found"]):format(#hits))
			if #hits == 0 then
				emptyText:SetText(L["No word matches. Try what it does: stun, buff, yards..."])
				emptyText:Show()
			end
			y = Grouped(hits, y)
		elseif state.cat == "here" or state.cat == "rule" then
			local list, seen = {}, {}
			for _, it in ipairs(ns.RuleCatalogWords(state.context)) do
				local e = it.entry
				local key = (it.unit and it.unit.key or "") .. e.w
				local want = state.cat == "here" and not e.pick and IsTrue(facts, e.w) or state.cat == "rule" and inRule[e.w]
				if want and not seen[key] then
					seen[key] = true
					list[#list + 1] = it
				end
			end
			paneTitle:SetText(state.cat == "here" and L["True here"] or L["In this rule"])
			paneTitle:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
			paneSub:SetText(state.cat == "here" and L["Everything true where you stand now."] or L["The words this rule uses."])
			if #list == 0 then
				emptyText:SetText(state.cat == "here" and L["Nothing is true here now."] or L["The rule has no words yet."])
				emptyText:Show()
			end
			y = Grouped(list, y)
		else
			local cat = CatOf(state.cat) or CatOf("units")
			state.cat = cat.key
			paneTitle:SetText(cat.name)
			paneTitle:SetTextColor(cat.color[1], cat.color[2], cat.color[3])
			paneSub:SetText(cat.sub)
			if cat.units then
				local unit = UnitOf(state.unit)
				state.unit = unit.key
				unitSwitch:Show()
				for _, ub in ipairs(unitButtons) do ub:Paint(cat.color, ub.unit == unit.key and "on" or nil) end
				y = -58
				for _, sec in ipairs(unit.sections) do y = Section(sec.name, sec.words, y, cat, unit) end
			else
				for _, sec in ipairs(cat.sections) do y = Section(sec.name, sec.words, y, cat) end
			end
		end
		for _, b in ipairs(shownButtons) do
			b:Paint(b.it.cat.color, inRule[b.it.entry.w] and "rule" or nil)
			b:SetDot(not b.it.entry.pick and IsTrue(facts, b.it.entry.w))
		end
		pane:SetHeight(-y + 8)
		local range = math.max(0, pane:GetHeight() - scroll:GetHeight())
		if scroll:GetVerticalScroll() > range then scroll:SetVerticalScroll(range) end
		PlaceThumb()
	end
	editor.ShowPane = function() ShowPane() end

	-- The Target / Mouse / Focus switch.
	do
		local x = 0
		for _, unit in ipairs(Units() and Units().units or {}) do
			local b = FlatButton(unitSwitch)
			b.unit = unit.key
			b:SetLabel(unit.label, true)
			b:SetWidth(math.max(b:GetWidth(), 70))
			b:SetPoint("LEFT", x, 0)
			b:SetScript("OnClick", function()
				state.unit = unit.key
				if ns.db then ns.db.ruleEditorUnit = unit.key end
				scroll:SetVerticalScroll(0)
				ShowPane()
				Refresh()
			end)
			Tip(b, unit.sub)
			unitButtons[#unitButtons + 1] = b
			x = x + b:GetWidth() - 1 -- (joined: their edges overlap)
		end
	end

	-- The sidebar ---------------------------------------------------------------------------------------
	local function CatButton()
		local b = CreateFrame("Button", nil, catList)
		b:SetHeight(20)
		b.sel = NoSnap(b:CreateTexture(nil, "BACKGROUND"))
		b.sel:SetAllPoints()
		b.sel:SetTexture(FLAT)
		b.bar = NoSnap(b:CreateTexture(nil, "ARTWORK"))
		b.bar:SetTexture(FLAT)
		b.bar:SetPoint("TOPLEFT")
		b.bar:SetPoint("BOTTOMLEFT")
		b.bar:SetWidth(2)
		b.wash = NoSnap(b:CreateTexture(nil, "HIGHLIGHT"))
		b.wash:SetAllPoints()
		b.wash:SetTexture(FLAT)
		b.wash:SetVertexColor(1, 1, 1, 0.05)
		b.swatch = NoSnap(b:CreateTexture(nil, "ARTWORK"))
		b.swatch:SetTexture(FLAT)
		b.swatch:SetSize(5, 5)
		b.swatch:SetPoint("LEFT", 10, 0)
		b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		b.text:SetPoint("LEFT", 21, 0)
		b.count = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		b.count:SetPoint("RIGHT", -9, 0)
		b.dot = b:CreateTexture(nil, "OVERLAY")
		b.dot:SetSize(8, 8)
		b.dot:SetPoint("RIGHT", -9, 0)
		b.dot:SetTexture(GREEN)
		b:SetScript("OnClick", function(self)
			state.cat = self.key
			state.find = ""
			find:SetText("")
			find:ClearFocus()
			if ns.db then ns.db.ruleEditorCat = self.key end
			scroll:SetVerticalScroll(0)
			ShowPane()
			Refresh()
		end)
		catButtons[#catButtons + 1] = b
		return b
	end
	local sideGap = NoSnap(catList:CreateTexture(nil, "ARTWORK"))
	sideGap:SetTexture(FLAT)
	sideGap:SetHeight(1)
	sideGap:SetVertexColor(1, 1, 1, 0.08)
	local SPECIAL = { { key = "here", name = L["True here"], tip = L["Every word true where you stand now, from every list."] },
		{ key = "rule", name = L["In this rule"], tip = L["The words this rule uses."] } }
	local function LayoutCats()
		local y, used = -2, 0
		local function Next(spec)
			used = used + 1
			local b = catButtons[used] or CatButton()
			b.key, b.cat, b.special = spec.key, spec.cat, spec.special
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", 0, y)
			b:SetPoint("RIGHT", catList, "RIGHT", 0, 0)
			b.text:SetText(spec.name)
			if spec.special then
				b.text:SetFontObject("GameFontHighlightSmall")
				b.text:SetTextColor(DIM[1] + 0.2, DIM[2] + 0.2, DIM[3] + 0.2)
				b.swatch:Hide()
				b.text:SetPoint("LEFT", 12, 0)
			else
				local c = spec.cat.color
				b.text:SetTextColor(c[1], c[2], c[3])
				b.swatch:SetVertexColor(c[1], c[2], c[3], 0.9)
				b.swatch:Show()
				b.text:SetPoint("LEFT", 21, 0)
			end
			Tip(b, spec.tip)
			b:Show()
			y = y - 20
			return b
		end
		for _, spec in ipairs(SPECIAL) do Next({ key = spec.key, name = spec.name, tip = spec.tip, special = true }) end
		sideGap:ClearAllPoints()
		sideGap:SetPoint("TOPLEFT", 10, y - 4)
		sideGap:SetPoint("TOPRIGHT", -10, y - 4)
		y = y - 9
		for _, cat in ipairs(ns.RuleCatalog()) do
			if Shows(cat.only) then Next({ key = cat.key, name = cat.name, tip = cat.sub, cat = cat }) end
		end
		for i = used + 1, #catButtons do catButtons[i]:Hide() end
	end
	-- Each sidebar entry's look: selected, dimmed by a search with no hit, its dot or count.
	local function PaintCats(facts, inRule)
		local accent = Role("accent")
		local finding = state.find:find("%S") ~= nil
		local hitCats
		if finding then
			hitCats = {}
			for _, it in ipairs(Matches(state.find, 99)) do hitCats[it.cat.key] = true end
		end
		local trueHere, inRuleCount = 0, 0
		local anyTrue = {}
		for _, it in ipairs(ns.RuleCatalogWords(state.context)) do
			local e = it.entry
			if not e.pick and IsTrue(facts, e.w) then
				anyTrue[it.cat.key] = true
				if it.unit then anyTrue["unit:" .. it.unit.key] = true end
			end
		end
		local counted = {}
		for _, it in ipairs(ns.RuleCatalogWords(state.context)) do
			local e = it.entry
			if not counted[e.w] then
				counted[e.w] = true
				if not e.pick and IsTrue(facts, e.w) then trueHere = trueHere + 1 end
				if inRule[e.w] then inRuleCount = inRuleCount + 1 end
			end
		end
		for _, b in ipairs(catButtons) do
			if b:IsShown() then
				local on = not finding and state.cat == b.key
				b.sel:SetVertexColor(accent[1], accent[2], accent[3], on and 0.12 or 0)
				b.bar:SetVertexColor(accent[1], accent[2], accent[3], on and 1 or 0)
				b:SetAlpha(hitCats and not b.special and not hitCats[b.key] and 0.35 or 1)
				if b.special then
					b.dot:Hide()
					b.count:SetText(b.key == "here" and trueHere or inRuleCount)
					b.count:Show()
				else
					b.count:Hide()
					b.dot:SetShown(anyTrue[b.key] and true or false)
				end
			end
		end
		for _, ub in ipairs(unitButtons) do ub:SetDot(anyTrue["unit:" .. ub.unit]) end
	end

	-- The readout -------------------------------------------------------------------------------------
	local function Chip(i)
		local c = chips[i]
		if c then return c end
		c = CreateFrame("Button", nil, readout)
		c:SetHeight(18)
		c.fill = Fill(c, { 0.1, 0.09, 0.08 }, 0.95)
		c.edge = Edge(c, FALSE_C, 0.5)
		c.icon = c:CreateTexture(nil, "OVERLAY")
		c.icon:SetSize(12, 12)
		c.icon:SetPoint("LEFT", 4, 0)
		c.text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		c.text:SetPoint("LEFT", 18, 0)
		c:SetScript("OnEnter", function(self)
			if not self.tipLines then return end
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
			for n, line in ipairs(self.tipLines) do
				if n == 1 then GameTooltip:SetText(line[1], 1, 1, 1) else GameTooltip:AddLine(line[1], line[2], line[3], line[4], true) end
			end
			GameTooltip:Show()
		end)
		c:SetScript("OnLeave", GameTooltip_Hide)
		chips[i] = c
		return c
	end
	local function OpText(i)
		local t = opTexts[i]
		if t then return t end
		t = readout:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		opTexts[i] = t
		return t
	end
	-- The rule's words as chips, each true or false here, wrapping over two rows; what doesn't fit
	-- goes in a last "+N" chip. Then the verdict (or what's wrong).
	local function PaintReadout(facts)
		for _, c in ipairs(chips) do c:Hide() end
		for _, t in ipairs(opTexts) do t:Hide() end
		message:Hide()
		local text = box:GetText()
		local test, err = ns.CompileRule(text)
		local blank = not text:find("%S")
		if blank then
			verdictIcon:Hide()
			verdict:SetText("")
			message:SetText(target and target.grid and Colored({ 1, 0.82, 0 }, L["Blank: never shown."])
				or Colored(DIM, L["Empty: its ticks decide."]))
			message:Show()
			return
		end
		local pieces = Pieces(text)
		local x, y, row, chipN, opN, hidden = 8, -7, 1, 0, 0, 0
		-- (The second row keeps room for the verdict; with an error, its words take
		-- the whole second row, so the chips keep to the first.)
		local rows = test and 2 or 1
		local right = readout:GetWidth() - 8 - 150
		local function Room(w)
			local last = row == rows
			local limit = (last and test) and right or (readout:GetWidth() - 8 - (last and 40 or 0))
			if x + w > limit then
				if last then return false end
				row, x, y = row + 1, 8, -27
			end
			return true
		end
		for _, p in ipairs(pieces) do
			if p.op or p.paren then
				opN = opN + 1
				local t = OpText(opN)
				t:SetText(p.op and p.op:upper() or p.paren)
				local w = t:GetStringWidth() + 6
				if Room(w) then
					t:ClearAllPoints()
					t:SetPoint("TOPLEFT", readout, "TOPLEFT", x, y - 4)
					t:Show()
					x = x + w
				else
					hidden = hidden + 1
				end
			elseif p.word or p.axis then
				local known = p.axis and ns.RULE_AXES and ns.RULE_AXES[p.axis] and p.value ~= ""
					or (p.word and ns.RULE_WORDS[p.word])
				local yes = false
				if known and facts then
					if p.axis then
						local single = ns.CompileRule(p.raw)
						yes = single and single(facts) and true or false
					else
						yes = facts[ns.RULE_WORDS[p.word]] and true or false
					end
				end
				chipN = chipN + 1
				local c = Chip(chipN)
				local label = known and PieceLabel(p) or (p.raw or p.word)
				c.text:SetText(label)
				local w = c.text:GetStringWidth() + 24
				c:SetWidth(w)
				if Room(w) then
					c:ClearAllPoints()
					c:SetPoint("TOPLEFT", readout, "TOPLEFT", x, y)
					c.icon:SetTexture(known and (yes and YES or NO) or NO)
					c.icon:SetDesaturated(not yes)
					c.icon:SetAlpha(yes and 1 or 0.55)
					local col = not known and ERR_C or (yes and TRUE_C or FALSE_C)
					c.edge.Paint(col, yes and 0.75 or 0.45)
					c.text:SetTextColor(known and (yes and TEXT[1] or DIM[1] + 0.1) or ERR_C[1],
						known and (yes and TEXT[2] or DIM[2] + 0.1) or ERR_C[2], known and (yes and TEXT[3] or DIM[3] + 0.1) or ERR_C[3])
					c.tipLines = known and { { label }, { p.raw or p.word, 0.6, 0.6, 0.6 },
						{ yes and L["True where you stand now."] or L["False where you stand now."],
							yes and TRUE_C[1] or 0.7, yes and TRUE_C[2] or 0.7, yes and TRUE_C[3] or 0.7 } }
						or { { L["Not a word"] }, { (L["\"%s\" isn't a word CQL knows. Find one on the left, or type a few letters for suggestions."]):format(p.raw or p.word), 1, 0.82, 0 } }
					c:Show()
					x = x + w + 4
				else
					hidden = hidden + 1
				end
			end
		end
		if hidden > 0 then
			chipN = chipN + 1
			local c = Chip(chipN)
			c.text:SetText("+" .. hidden)
			c:SetWidth(c.text:GetStringWidth() + 14)
			c.text:SetPoint("LEFT", 7, 0)
			c.icon:SetTexture(nil)
			c.edge.Paint(DIM, 0.4)
			c.text:SetTextColor(DIM[1], DIM[2], DIM[3])
			c.tipLines = { { (L["%d more pieces"]):format(hidden) }, { L["The rule goes on past what fits here; it's all read."], 0.7, 0.7, 0.7 } }
			c:ClearAllPoints()
			c:SetPoint("TOPLEFT", readout, "TOPLEFT", x, y)
			c:Show()
		end
		for i = 1, chipN do
			if chips[i].icon:GetTexture() then chips[i].text:SetPoint("LEFT", 18, 0) end
		end
		verdict:ClearAllPoints()
		if not test then
			verdictIcon:Hide()
			verdict:SetPoint("BOTTOMLEFT", 8, 7)
			verdict:SetPoint("BOTTOMRIGHT", -8, 7)
			verdict:SetJustifyH("LEFT")
			verdict:SetText(Colored(ERR_C, (L["Not finished: %s. Closing now puts back the rule it had."]):format(err or "?")))
			return
		end
		verdict:SetPoint("BOTTOMRIGHT", -8, 7)
		verdict:SetJustifyH("RIGHT")
		local shown = facts and test(facts) and true or false
		verdictIcon:SetTexture(shown and YES or NO)
		verdictIcon:SetDesaturated(false)
		verdictIcon:Show()
		verdict:SetText(shown and Colored(TRUE_C, L["Shown right now"]) or Colored({ 1, 0.82, 0 }, L["Hidden right now"]))
	end

	-- Refresh: everything that follows where you stand (every half second, and on each change).
	function Refresh()
		if not target then return end
		local text = box:GetText()
		local grid = target.grid
		local isAlways, why
		if grid then isAlways, why = ns.ReadGridRule(text, grid) end
		resetGrid:SetShown(grid ~= nil and isAlways == nil)
		followButton:ClearAllPoints()
		if resetGrid:IsShown() then
			followButton:SetPoint("LEFT", resetGrid, "RIGHT", 8, 0)
		else
			followButton:SetPoint("BOTTOMLEFT", PAD, 10)
		end
		followButton:SetShown(target.follow ~= nil)
		local test = ns.CompileRule(text)
		done:SetEnabled(not text:find("%S") or test ~= nil)
		-- (Only for a rule that reads: an unfinished one has its error in the readout.)
		gridNote:SetShown(grid ~= nil and text:find("%S") ~= nil and test ~= nil)
		gridNote:SetText(not grid and "" or isAlways ~= nil
			and Colored(TRUE_C, L["Goes back into the dropdowns as you close it."])
			or Colored({ 1, 0.82, 0 }, (L["Stays the row's rule (it can't go in the dropdowns: %s)."]):format(tostring(why))))
		local facts = Facts()
		PaintReadout(facts)
		local inRule = InRule()
		for _, b in ipairs(shownButtons) do
			b:Paint(b.it.cat.color, inRule[b.it.entry.w] and "rule" or nil)
			b:SetDot(not b.it.entry.pick and IsTrue(facts, b.it.entry.w))
		end
		PaintCats(facts, inRule)
		if sugg:IsShown() then Suggest(true) end
	end
	editor.Refresh = function() Refresh() end

	-- Search.
	find:SetScript("OnTextChanged", function(self)
		state.find = self:GetText() or ""
		findHint:SetShown(state.find == "")
		scroll:SetVerticalScroll(0)
		ShowPane()
		Refresh()
	end)
	find:SetScript("OnEnterPressed", function(self)
		local it = Matches(state.find, 1)[1]
		if it then
			if it.entry.pick then OpenPick(it, findWrap) else Insert(it.entry.w) end
		end
	end)
	find:SetScript("OnEscapePressed", function(self)
		if self:GetText() ~= "" then self:SetText("") else self:ClearFocus() end
	end)
	findWrap:EnableMouse(true)
	findWrap:SetScript("OnMouseDown", function() find:SetFocus() end)

	local since = 0
	ns.SetOnUpdate(editor, function(_, elapsed)
		since = since + elapsed
		if since > 0.5 then
			since = 0
			Refresh()
		end
	end)
	-- (Closed any way: Done, X, Escape, Enter or the settings going.)
	editor:SetScript("OnHide", function()
		box:ClearFocus()
		find:ClearFocus()
		HideSuggest()
		local closing = target
		target = nil
		if closing then closing.Close(box:GetText()) end
	end)
	editor.Open = function(newTarget)
		target = newTarget
		state.context = ns.RuleEditorContext(newTarget)
		state.hist, state.fut, state.autoAnd, state.typingAt = {}, {}, nil, nil
		state.find = ""
		find:SetText("")
		state.cat = ns.db and ns.db.ruleEditorCat or "units"
		state.unit = ns.db and ns.db.ruleEditorUnit or "target"
		if state.cat == "tip" and state.context ~= "tooltip" then state.cat = "units" end
		if state.context == "tooltip" and not ns.db.ruleEditorCat then state.cat = "tip" end
		heading:SetText(Colored(DIM, L["Rule:"]) .. " " .. (newTarget.label or ""))
		local accent = Role("accent")
		for _, paint in ipairs(accentParts) do paint(accent) end
		LayoutCats()
		programmatic = true
		local text = newTarget.Text() or ""
		box:SetText(text)
		programmatic = false
		Recolor()
		scroll:SetVerticalScroll(0)
		editor:Show()
		ShowPane()
		box:SetFocus()
		box:SetCursorPosition(#text)
		Refresh()
	end
	-- (For the tests: show a category or a unit as a click would.)
	editor.ShowCategory = function(key, unit)
		state.cat, state.find = key, ""
		if unit then state.unit = unit end
		find:SetText("")
		ShowPane()
		Refresh()
	end
	editor.SetFind = function(text) find:SetText(text) end
	editor.box, editor.pane, editor.scroll, editor.readout, editor.sugg = box, pane, scroll, readout, sugg
	editor.catButtons, editor.unitButtons, editor.chips, editor.verdict = catButtons, unitButtons, chips, verdict
	editor.done, editor.resetGrid, editor.followButton, editor.find = done, resetGrid, followButton, find
end
