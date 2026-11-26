-- Style Studio's controls: the grammar (Tools/style-studio/plan.md section 4), one
-- control per kind of choice, in the CQL editor's flat look (UI/RuleEditor.lua):
--   Segments (2-5 words), Tiles (looks judged by eye; More... opens the gallery),
--   Slider (with its value as an edit box and its unit), Chips (a color's source,
--   Custom's swatch), Switch, Drop (a long list, with a Find box), Button.
-- And the property row every setting sits in: source mark, label, control, reset.
local _, ns = ...
ns.Module("style", function()
local L = ns.L
local Studio = ns.Studio
local C = {}
Studio.C = C

local FLAT = "Interface\\Buttons\\WHITE8x8"
local DEFAULT_ROLES = { accent = { 1, 0.82, 0 }, edge = { 0.5, 0.5, 0.5 }, field = { 0.06, 0.06, 0.08 },
	window = { 0.04, 0.04, 0.05 }, well = { 0, 0, 0 } }
function C.Role(role)
	local palette = ns.MenuPalette and ns.MenuPalette()
	return palette and palette[role] or DEFAULT_ROLES[role]
end
local Role = C.Role
-- An option's picture on a texture: its atlas where it names one the game has, else its file. A
-- choice whose atlas isn't a name (or the client lacks it) gave "SetAtlas(): Usage" in the open list,
-- the user's log 2026-11-26 (Controls.lua:353, x2).
local function SetSample(tex, o)
	if type(o.atlas) == "string" and pcall(tex.SetAtlas, tex, o.atlas) then return true end
	if o.texture ~= nil and pcall(tex.SetTexture, tex, o.texture) then return true end
	tex:SetTexture(FLAT)
	return false
end

C.TEXT, C.DIM, C.FAINT = { 0.92, 0.9, 0.85 }, { 0.6, 0.58, 0.54 }, { 0.42, 0.4, 0.37 }
C.LABEL = { 1, 1, 1 } -- (a row's name in white, as the old pages' kit.Label GameFontHighlight)
C.QUIET = { 0.3, 0.27, 0.23 } -- (every edge that isn't picked or hovered: warm grey, not gold)
C.BLUE, C.AMBER, C.RED, C.LILAC = { 0.42, 0.66, 1 }, { 0.94, 0.63, 0.19 }, { 1, 0.38, 0.38 }, { 0.85, 0.69, 1 }

local function NoSnap(t)
	if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
	if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
	return t
end
C.NoSnap = NoSnap
function C.Fill(frame, c, a, layer, sub)
	local t = NoSnap(frame:CreateTexture(nil, layer or "BACKGROUND", nil, sub or -7))
	t:SetAllPoints()
	t:SetTexture(FLAT)
	t:SetVertexColor(c[1], c[2], c[3], a or 1)
	return t
end
function C.Edge(frame, c, a)
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
local Fill, Edge = C.Fill, C.Edge

function C.Tip(widget, text)
	-- (Hooked once; called again it only changes the words: the editor redraws often and
	-- sets its headers' and tabs' tips each time.)
	widget.studioTip = text
	if widget.studioTipHooked then return end
	widget.studioTipHooked = true
	widget:HookScript("OnEnter", function(self)
		local tip = self.studioTip
		local shown = type(tip) == "function" and tip(self) or tip
		-- (Words only: a choice list's third slot can be its color, a table, and
		-- SetText took it as words and errored, Names page 2026-11-25, Tools/errors/known.lua.)
		if type(shown) == "number" then shown = tostring(shown) end
		if shown ~= nil and type(shown) ~= "string" then
			-- (Named in the log, so the list that sent it is found: not pinned yet.)
			local words = self.text and self.text.GetText and self.text:GetText()
			if ns.Log then ns.Log("studio", ("a tip that isn't words (%s) on %s"):format(type(shown), tostring(words))) end
			return
		end
		if not shown or shown == "" then return end
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText(shown, 1, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	widget:HookScript("OnLeave", GameTooltip_Hide)
end
local Tip = C.Tip

function C.Text(parent, font, color)
	local t = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
	t:SetJustifyH("LEFT")
	if color then t:SetTextColor(color[1], color[2], color[3]) end
	return t
end

-- The game's small down arrow (a menu opens), tinted to the theme's accent.
function C.DownArrow(parent)
	local t = parent:CreateTexture(nil, "OVERLAY")
	t:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
	t:SetSize(12, 12)
	t:SetTexCoord(0.1, 0.9, 0.15, 0.85)
	local accent = Role("accent")
	t:SetVertexColor(accent[1], accent[2], accent[3], 0.9)
	return t
end

-- A flat button: :SetLabel(text), :Paint(state: nil, "on", "action").
-- font: its text's font object (the pills: GameFontHighlight; default the small one).
function C.Button(parent, label, width, kind, font)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(20)
	b.fill = Fill(b, Role("field"), 0.95)
	b.edge = Edge(b, Role("edge"), 0.5)
	local wash = NoSnap(b:CreateTexture(nil, "HIGHLIGHT"))
	wash:SetAllPoints()
	wash:SetTexture(FLAT)
	wash:SetVertexColor(1, 1, 1, 0.07)
	b.text = b:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
	b.text:SetPoint("CENTER", 0, 0)
	b.kind = kind
	b:SetScript("OnMouseDown", function(self) if self:IsEnabled() then self.text:SetPoint("CENTER", 0, -1) end end)
	b:SetScript("OnMouseUp", function(self) self.text:SetPoint("CENTER", 0, 0) end)
	function b:SetLabel(text)
		self.text:SetText(text)
		if not width then self:SetWidth(math.floor(self.text:GetStringWidth() + 18 + (self.arrow and 14 or 0) + 0.5)) end
	end
	-- A menu button: the game's small down arrow after its words (not a "v").
	function b:SetArrow()
		if self.arrow then return self end
		self.arrow = C.DownArrow(self)
		self.arrow:SetPoint("RIGHT", -6, 0)
		self.text:ClearAllPoints()
		self.text:SetPoint("CENTER", -6, 0)
		self:SetLabel(self.text:GetText() or "")
		return self
	end
	-- (The look the Style pages' Look panels had (StylePages.lua's rows.Segments, approved
	-- 2026-11-14): no outline, a dark field; the picked one lit warm with a gold line under
	-- it and gold words. The user, 2026-11-25: "keep the page layouts, revert the looks".)
	b.edge.Paint({ 0, 0, 0 }, 0)
	b.under = NoSnap(b:CreateTexture(nil, "ARTWORK"))
	b.under:SetTexture(FLAT)
	b.under:SetPoint("BOTTOMLEFT")
	b.under:SetPoint("BOTTOMRIGHT")
	b.under:SetHeight(2)
	b.under:SetVertexColor(1, 0.82, 0, 1)
	b.under:Hide()
	function b:Paint(state)
		self.state = state
		self:SetAlpha(self:IsEnabled() and 1 or 0.4)
		self.under:SetShown(state == "on")
		if state == "on" then
			self.fill:SetVertexColor(0.2, 0.17, 0.08, 0.95)
			self.text:SetTextColor(1, 0.82, 0)
		elseif self.kind == "action" then
			-- (The game's red: Test, Edit rule, Done, as the old pages' Panel buttons.)
			self.fill:SetVertexColor(0.32, 0.05, 0.03, 0.95)
			self.text:SetTextColor(1, 0.82, 0)
		else
			self.fill:SetVertexColor(0.1, 0.1, 0.12, 0.95)
			self.text:SetTextColor(0.85, 0.85, 0.85)
		end
	end
	hooksecurefunc(b, "SetEnabled", function(self) self:Paint(self.state) end)
	if width then b:SetWidth(width) end
	b:SetLabel(label or "")
	b:Paint()
	return b
end

-- A tool button as the old pages had them: the game's Panel button (ns.PanelButton, red
-- and gold, in the menu's skin), sized to its words; menu: the game's down arrow after
-- them. The same :SetLabel/:SetArrow/:Paint as C.Button (Paint "on" keeps it lit).
function C.PanelTool(parent, label, menu)
	local b = ns.PanelButton(parent)
	b:SetHeight(22)
	b.text = b:GetFontString()
	function b:SetLabel(text)
		self:SetText(text)
		local w = self.text and self.text:GetStringWidth() or 40
		self:SetWidth(math.floor((tonumber(w) or 40) + 24 + (self.arrow and 12 or 0) + 0.5))
	end
	function b:SetArrow()
		if self.arrow then return self end
		self.arrow = C.DownArrow(self)
		self.arrow:SetPoint("RIGHT", -7, 0)
		if self.text then self.text:ClearAllPoints() self.text:SetPoint("CENTER", -5, 0) end
		self:SetLabel(self:GetText() or "")
		return self
	end
	function b:Paint(state)
		self.state = state
		if state == "on" then self:LockHighlight() else self:UnlockHighlight() end
	end
	b:SetLabel(label or "")
	if menu then b:SetArrow() end
	return b
end

-- A row of buttons, one picked: options { { value, text, tip } }, onPick(value), onHover(value or nil).
-- (maxW: wider than that, the buttons wrap onto more lines, each one still a button.)
function C.Segments(parent, options, onPick, onHover, maxW)
	local box = CreateFrame("Frame", nil, parent)
	box:SetHeight(20)
	box.buttons = {}
	local x, line, widest = 0, 0, 0
	for i, o in ipairs(options) do
		local b = C.Button(box, o.text or o[2], nil, nil, "GameFontHighlight")
		b.value = o.value ~= nil and o.value or o[1]
		b:SetWidth(math.max(48, math.floor(b.text:GetStringWidth() + 20))) -- (the old segments' size)
		b:SetHeight(22)
		if maxW and x > 0 and x + b:GetWidth() > maxW then x, line = 0, line + 1 end
		b:SetPoint("TOPLEFT", x, -line * 23)
		x = x + b:GetWidth() + 1 -- (a pixel apart, as the old segments)
		widest = math.max(widest, x)
		local tip = o.tip or o[3] -- (o[3] a tip only when it's words: some lists keep a color there)
		if type(tip) == "string" or type(tip) == "function" then Tip(b, tip) end
		b:SetScript("OnClick", function() onPick(b.value) end)
		if onHover then
			b:HookScript("OnEnter", function(self) if self.state ~= "on" then onHover(self.value) end end)
			b:HookScript("OnLeave", function() onHover(nil) end)
		end
		box.buttons[i] = b
	end
	box:SetWidth(math.max(1, widest + 1))
	box:SetHeight((line + 1) * 23 - 1)
	function box:SetValue(value)
		for _, b in ipairs(self.buttons) do b:Paint(b.value == value and "on" or nil) end
	end
	function box:SetEnabled(on)
		for _, b in ipairs(self.buttons) do b:SetEnabled(on) end
	end
	return box
end

-- The picker list (Drop, and Tiles' More...): one at a time, a Find box over
-- a scrolling list; each entry drawn in its font or over its texture.
local list
local function ListFrame()
	if list then return list end
	list = CreateFrame("Frame", "CinematicStudioList", UIParent)
	list:SetFrameStrata("FULLSCREEN_DIALOG")
	list:SetToplevel(true)
	list:SetClampedToScreen(true)
	list:EnableMouse(true)
	list:SetSize(240, 280)
	Fill(list, Role("window"), 0.98)
	list.edge = Edge(list, { 0.45, 0.41, 0.34 }, 1) -- (a menu's edge: warm grey, not gold)
	local find = CreateFrame("EditBox", nil, list)
	find:SetAutoFocus(false)
	find:SetFontObject("GameFontHighlightSmall")
	find:SetPoint("TOPLEFT", 6, -6)
	find:SetPoint("TOPRIGHT", -6, -6)
	find:SetHeight(20)
	find:SetTextInsets(6, 6, 0, 0)
	Fill(find, Role("well"), 0.9)
	Edge(find, Role("edge"), 0.5)
	local hint = C.Text(find, "GameFontDisableSmall")
	hint:SetPoint("LEFT", 6, 0)
	hint:SetText(L["Find..."])
	find:SetScript("OnTextChanged", function(self)
		hint:SetShown(self:GetText() == "")
		list.Fill()
	end)
	find:SetScript("OnEscapePressed", function() list:Hide() end)
	list.find = find
	local scroll = CreateFrame("ScrollFrame", nil, list)
	scroll:SetPoint("TOPLEFT", 4, -30)
	scroll:SetPoint("BOTTOMRIGHT", -4, 4)
	scroll:EnableMouseWheel(true)
	local body = CreateFrame("Frame", nil, scroll)
	body:SetSize(232, 10)
	scroll:SetScrollChild(body)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local max = math.max(0, body:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - delta * 40)))
	end)
	list.scroll, list.body, list.rows, list.heads = scroll, body, {}, {}
	-- (The mock's picker, 2026-11-25 (Tools/style-studio/page-mock.html): each entry its
	-- sample (a bar's texture or color, a font's "Aa"), its name, and a line saying what it
	-- is (o.sub); entries in groups under a small heading (o.group).)
	function list.Fill()
		local text = (find:GetText() or ""):lower()
		local shown, heads, y, lastGroup = 0, 0, 0, nil
		local w = list.body:GetWidth()
		for _, row in ipairs(list.rows) do row:Hide() end
		for _, h in ipairs(list.heads) do h:Hide() end
		for _, o in ipairs(list.options or {}) do
			local name = tostring(o.text or o[2] or o.value or o[1])
			if text == "" or name:lower():find(text, 1, true) then
				if o.group and o.group ~= lastGroup then
					heads = heads + 1
					local h = list.heads[heads]
					if not h then
						h = C.Text(body, "GameFontDisableSmall")
						list.heads[heads] = h
					end
					h:ClearAllPoints()
					h:SetPoint("TOPLEFT", 8, -y - 7)
					h:SetText(o.group:upper())
					h:Show()
					y = y + 22
				end
				lastGroup = o.group
				shown = shown + 1
				local row = list.rows[shown]
				if not row then
					row = CreateFrame("Button", nil, body)
					row:SetSize(230, 22)
					row.sample = row:CreateTexture(nil, "BACKGROUND")
					row.sample:SetPoint("LEFT", 6, 0)
					row.sample:SetSize(60, 12)
					row.aa = C.Text(row, "GameFontHighlight")
					row.aa:SetPoint("CENTER", row, "LEFT", 36, 0)
					row.text = C.Text(row, "GameFontHighlightSmall")
					row.text:SetPoint("LEFT", 8, 0)
					row.text:SetPoint("RIGHT", -6, 0)
					row.sub = C.Text(row, "GameFontDisableSmall")
					row.sub:SetJustifyH("LEFT")
					row.sub:SetWordWrap(false)
					local hi = row:CreateTexture(nil, "HIGHLIGHT")
					hi:SetAllPoints()
					hi:SetColorTexture(1, 1, 1, 0.07)
					row.pick = row:CreateTexture(nil, "ARTWORK")
					row.pick:SetAllPoints()
					row:SetScript("OnEnter", function(self) if list.onHover then list.onHover(self.value) end end)
					row:SetScript("OnLeave", function() if list.onHover then list.onHover(nil) end end)
					row:SetScript("OnClick", function(self)
						local fn = list.onPick
						list:Hide()
						if fn then fn(self.value) end
					end)
					list.rows[shown] = row
				end
				row.value = o.value ~= nil and o.value or o[1]
				local sub = o.sub
				local rh = sub and 34 or ((o.texture or o.atlas or o.color or o.font) and 26 or 22)
				row:SetSize(w, rh)
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", 0, -y)
				y = y + rh
				row.text:SetText(name)
				row.text:SetFontObject("GameFontHighlightSmall")
				row.aa:Hide()
				if o.font then
					-- (a font: "Aa" in it at the left, its name in it too)
					row.aa:Show()
					row.aa:SetText("Aa")
					pcall(row.aa.SetFont, row.aa, o.font, 16, "")
					pcall(row.text.SetFont, row.text, o.font, 13, "")
				end
				local left = 8
				row.sample:SetVertexColor(1, 1, 1)
				if o.texture or o.atlas then
					row.sample:Show()
					SetSample(row.sample, o)
					local tint = o.tint or { 1, 1, 1 } -- (a bar texture's green comes with it: R.Texture)
					row.sample:SetVertexColor(tint[1], tint[2], tint[3])
					left = 74
				elseif o.color then
					-- (a color: a small bar of it)
					row.sample:Show()
					row.sample:SetTexture(FLAT)
					row.sample:SetVertexColor(o.color[1], o.color[2], o.color[3])
					left = 74
				else
					row.sample:Hide()
					if o.font then left = 64 end
				end
				row.text:ClearAllPoints()
				row.sub:ClearAllPoints()
				if sub then
					row.text:SetPoint("TOPLEFT", left, -4)
					row.text:SetPoint("RIGHT", -6, 0)
					row.sub:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -2)
					row.sub:SetPoint("RIGHT", -6, 0)
					row.sub:SetText(sub)
					row.sub:Show()
				else
					row.text:SetPoint("LEFT", left, 0)
					row.text:SetPoint("RIGHT", -6, 0)
					row.sub:Hide()
				end
				local accent = Role("accent")
				row.pick:SetColorTexture(accent[1], accent[2], accent[3], row.value == list.current and 0.16 or 0)
				row:Show()
			end
		end
		body:SetHeight(math.max(10, y))
		list.scroll:SetVerticalScroll(0)
		return y
	end
	list:SetScript("OnHide", function()
		if list.onHover then list.onHover(nil) end
		list.anchor = nil
	end)
	-- (A click anywhere but on the list or its button closes it: the user, 2026-11-25,
	-- "clicking again doesnt close it, going to a new tab still shows it".)
	pcall(list.RegisterEvent, list, "GLOBAL_MOUSE_DOWN")
	-- (And gone the moment its button is out of sight, whatever hid it: its window, its
	-- tab, its page. Checked only while it's open.)
	list:SetScript("OnUpdate", function(self)
		local anchor = self.anchor
		if anchor and anchor.IsVisible and not anchor:IsVisible() then self:Hide() end
	end)
	list:SetScript("OnEvent", function(self, event)
		if event ~= "GLOBAL_MOUSE_DOWN" or not self:IsShown() then return end
		if self:IsMouseOver() then return end
		if self.anchor and self.anchor.IsMouseOver and self.anchor:IsMouseOver() then return end -- (its button toggles it)
		self:Hide()
	end)
	tinsert(UISpecialFrames, "CinematicStudioList")
	return list
end
-- Opens the list under anchor; the same anchor again closes it (a toggle). It closes
-- too as anchor hides (its tab or page goes), on a click elsewhere and on Escape.
-- noFind: no Find box of its own (the Studio's Find types into its own box).
function C.OpenList(anchor, options, current, onPick, onHover, noFind)
	local f = ListFrame()
	if f:IsShown() and f.anchor == anchor then
		f:Hide()
		return false
	end
	f.options, f.current, f.onPick, f.onHover = options, current, onPick, onHover
	f.anchor = anchor
	if noFind == nil then noFind = #options <= 8 end -- (a short menu needs no Find box)
	if anchor and anchor.HookScript and not anchor.studioListHooked then
		anchor.studioListHooked = true
		anchor:HookScript("OnHide", function(self) if f.anchor == self then f:Hide() end end)
	end
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
	-- (As wide as the box it opens from, 240 at least: descriptions fit, run the mock.)
	local w = math.max(240, math.floor((anchor and anchor.GetWidth and anchor:GetWidth() or 240) + 0.5))
	f:SetWidth(w)
	f.body:SetWidth(w - 10)
	f.find:SetShown(not noFind)
	f.scroll:SetPoint("TOPLEFT", 4, noFind and -4 or -30)
	f.find:SetText("")
	f:Show()
	local y = f.Fill()
	f:SetHeight(math.min(340, (noFind and 10 or 36) + (y or #options * 22)))
	return true
end
function C.CloseList() if list then list:Hide() end end
function C.ListShown() return list and list:IsShown() and list.anchor or nil end

-- A dropdown: its value's name, opening the list.
function C.Drop(parent, width, options, onPick, onHover)
	local b = C.Button(parent, "", width or 170)
	b:Paint()
	b.edge.Paint({ 0.24, 0.24, 0.28 }, 1) -- (a box with a dim edge, as the old tiles: its arrow says it opens)
	b.text:ClearAllPoints()
	b.text:SetPoint("LEFT", 8, 0)
	b.text:SetPoint("RIGHT", -18, 0)
	b.text:SetJustifyH("LEFT")
	b.text:SetWordWrap(false)
	local arrow = C.DownArrow(b)
	arrow:SetPoint("RIGHT", -5, 0)
	-- (The picked one's sample before its name, one line: the mock's closed picker.)
	b.sample = b:CreateTexture(nil, "ARTWORK")
	b.sample:SetPoint("LEFT", 6, 0)
	b.sample:SetSize(44, 10)
	b.sample:Hide()
	b.aa = C.Text(b, "GameFontHighlight")
	b.aa:SetPoint("LEFT", 8, 0)
	b.aa:Hide()
	b.options = options
	b:SetScript("OnClick", function(self)
		local opts = type(self.options) == "function" and self.options() or self.options
		C.OpenList(self, opts, self.value, onPick, onHover)
	end)
	function b:SetValue(value)
		self.value = value
		local opts = type(self.options) == "function" and self.options() or self.options
		local name = value ~= nil and tostring(value) or ""
		local picked
		for _, o in ipairs(opts) do
			local v = o.value ~= nil and o.value or o[1]
			if v == value then name, picked = o.short or o.text or o[2], o end
		end
		self.text:SetText(name)
		self.sample:Hide()
		self.aa:Hide()
		local left = 8
		if picked and (picked.texture or picked.atlas) then
			SetSample(self.sample, picked)
			local tint = picked.tint or { 1, 1, 1 }
			self.sample:SetVertexColor(tint[1], tint[2], tint[3])
			self.sample:Show()
			left = 56
		elseif picked and picked.color then
			self.sample:SetTexture(FLAT)
			self.sample:SetVertexColor(picked.color[1], picked.color[2], picked.color[3])
			self.sample:Show()
			left = 56
		elseif picked and picked.font then
			self.aa:SetText("Aa")
			pcall(self.aa.SetFont, self.aa, picked.font, 14, "")
			self.aa:Show()
			left = 34
		end
		self.text:ClearAllPoints()
		self.text:SetPoint("LEFT", left, 0)
		self.text:SetPoint("RIGHT", -18, 0)
	end
	return b
end

-- Tiles: up to `few` looks shown as pictures (font: "Aa" in it; texture: a
-- strip of it), the picked one always among them, and More... for the list.
-- maxW: the room the row has; tiles that wouldn't fit go into More... (the picked one stays).
function C.Tiles(parent, options, onPick, onHover, few, maxW)
	few = few or 5
	local box = CreateFrame("Frame", nil, parent)
	box:SetHeight(26)
	box.tiles = {}
	box.options = options
	local more = C.Button(box, L["More..."])
	more:SetHeight(26)
	more:SetScript("OnClick", function(self)
		local opts = type(box.options) == "function" and box.options() or box.options
		C.OpenList(self, opts, box.value, onPick, onHover)
	end)
	local function Tile(i)
		local t = box.tiles[i]
		if t then return t end
		t = CreateFrame("Button", nil, box)
		t:SetSize(40, 26)
		t.fill = Fill(t, { 0.1, 0.1, 0.12 }, 0.95) -- (the old tiles' dark field)
		t.edge = Edge(t, Role("edge"), 0.5)
		t.sample = t:CreateTexture(nil, "ARTWORK")
		t.sample:SetPoint("TOPLEFT", 4, -8)
		t.sample:SetPoint("BOTTOMRIGHT", -4, 8)
		t.word = t:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		t.word:SetPoint("CENTER")
		local hi = t:CreateTexture(nil, "HIGHLIGHT")
		hi:SetAllPoints()
		hi:SetColorTexture(1, 1, 1, 0.08)
		t:SetScript("OnClick", function(self) onPick(self.value) end)
		t:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
			GameTooltip:SetText(self.name or "", 1, 1, 1)
			GameTooltip:Show()
			if onHover and self.value ~= box.value then onHover(self.value) end
		end)
		t:SetScript("OnLeave", function() GameTooltip:Hide() if onHover then onHover(nil) end end)
		box.tiles[i] = t
		return t
	end
	function box:SetValue(value)
		self.value = value
		local opts = type(self.options) == "function" and self.options() or self.options
		local shown, have = {}, false
		for _, o in ipairs(opts) do
			if #shown < few then shown[#shown + 1] = o end
			if (o.value ~= nil and o.value or o[1]) == value then have = o end
		end
		if have then
			local inside = false
			for _, o in ipairs(shown) do if o == have then inside = true end end
			if not inside and #shown > 0 then shown[#shown] = have end
		end
		local function Dress(t, o)
			t.value, t.name = (o.value ~= nil and o.value or o[1]), o.text or o[2]
			t.sample:Hide()
			t.word:SetFontObject("GameFontHighlight")
			t.word:SetText("")
			if o.texture or o.atlas then
				t.sample:Show()
				SetSample(t.sample, o)
				local tint = o.tint or { 1, 1, 1 } -- (a bar texture's green comes with it: R.Texture)
				t.sample:SetVertexColor(tint[1], tint[2], tint[3])
				t:SetWidth(40)
			elseif o.font then
				t.word:SetText("Aa")
				pcall(t.word.SetFont, t.word, o.font, 14, "")
				t:SetWidth(40)
			else
				t.word:SetFontObject("GameFontHighlightSmall")
				t.word:SetText(t.name)
				t:SetWidth(math.max(40, math.floor(t.word:GetStringWidth() + 14)))
			end
			-- (The old Look panel tiles' edges: dim, lit gold when picked.)
			if t.value == value then t.edge.Paint({ 0.66, 0.54, 0.17 }, 1) else t.edge.Paint({ 0.24, 0.24, 0.28 }, 1) end
		end
		-- (Laid out while they fit beside a More... button; the picked one put in the last
		-- place that fits if it was cut.)
		local room = maxW and (maxW - more:GetWidth() - 3) or math.huge
		local x, laid, pickedIn = 0, 0, false
		for i, o in ipairs(shown) do
			local t = Tile(i)
			Dress(t, o)
			if x + t:GetWidth() > room and laid > 0 then break end
			t:ClearAllPoints()
			t:SetPoint("LEFT", x, 0)
			t:Show()
			x = x + t:GetWidth() + 3
			laid = i
			if o == have then pickedIn = true end
		end
		if have and not pickedIn and laid > 0 then
			local t = self.tiles[laid]
			x = x - t:GetWidth() - 3
			Dress(t, have)
			t:ClearAllPoints()
			t:SetPoint("LEFT", x, 0)
			x = x + t:GetWidth() + 3
		end
		for i = laid + 1, #self.tiles do self.tiles[i]:Hide() end
		more:SetShown(#opts > laid)
		more:ClearAllPoints()
		more:SetPoint("LEFT", x, 0)
		self:SetWidth(math.max(1, x + (more:IsShown() and more:GetWidth() or 0)))
	end
	function box:SetEnabled(on)
		for _, t in ipairs(self.tiles) do t:SetEnabled(on) t:SetAlpha(on and 1 or 0.4) end
		more:SetEnabled(on)
	end
	return box
end

-- A slider: a flat track and knob, the value in a box after it with its unit.
-- prop: min, max, step, unit, scale (shown = value * scale).
function C.Slider(parent, width, prop, onSet, onSlide)
	local box = CreateFrame("Frame", nil, parent)
	box:SetSize(width, 20)
	local s = CreateFrame("Slider", nil, box)
	s:SetOrientation("HORIZONTAL")
	s:SetPoint("LEFT", 0, 0)
	s:SetSize(width - 62, 14)
	s:SetMinMaxValues(prop.min or 0, prop.max or 100)
	s:SetValueStep(prop.step or 1)
	if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
	local track = NoSnap(s:CreateTexture(nil, "BACKGROUND"))
	track:SetTexture(FLAT)
	track:SetHeight(3)
	track:SetPoint("LEFT")
	track:SetPoint("RIGHT")
	track:SetVertexColor(0.22, 0.22, 0.26, 1) -- (the old Look panel slider's track)
	local lit = NoSnap(s:CreateTexture(nil, "ARTWORK"))
	lit:SetTexture(FLAT)
	lit:SetHeight(3)
	lit:SetPoint("LEFT")
	local thumb = s:CreateTexture(nil, "OVERLAY")
	thumb:SetTexture(FLAT)
	thumb:SetSize(8, 14)
	s:SetThumbTexture(thumb)
	-- (The default's mark on the track.)
	local tick = NoSnap(s:CreateTexture(nil, "ARTWORK", nil, 1))
	tick:SetTexture(FLAT)
	tick:SetSize(1, 9)
	tick:SetVertexColor(1, 1, 1, 0.35)
	tick:Hide()
	local edit = CreateFrame("EditBox", nil, box)
	edit:SetAutoFocus(false)
	edit:SetFontObject("GameFontHighlightSmall")
	edit:SetMaxLetters(24)
	-- (prop.words: a value shown as words, { [saved] = text }, Letterbox's "With the UI" at 0:
	-- the box as wide as the longest.)
	local editW = 56
	if prop.words then
		local measure = edit:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		for _, text in pairs(prop.words) do
			measure:SetText(text)
			local w = measure:GetStringWidth()
			if type(w) == "number" then editW = math.max(editW, math.ceil(w) + 14) end
		end
		measure:Hide()
		s:SetWidth(math.max(40, width - editW - 6))
	end
	edit:SetSize(editW, 18)
	edit:SetPoint("RIGHT")
	edit:SetJustifyH("RIGHT")
	edit:SetTextInsets(4, 6, 0, 0)
	Fill(edit, { 0.1, 0.1, 0.12 }, 0.95)
	Edge(edit, { 0.24, 0.24, 0.28 }, 1)
	local scale = prop.scale or 1
	local function Shown(v)
		if prop.words then
			for saved, text in pairs(prop.words) do
				if math.abs((v or 0) - saved) < 0.0001 then return text end
			end
		end
		v = (v or 0) * scale
		local text = (math.abs(v - math.floor(v + 0.5)) < 0.001) and ("%d"):format(math.floor(v + 0.5)) or ("%.1f"):format(v)
		local unit = prop.unit or ""
		return text .. (unit ~= "" and (" " .. unit) or "")
	end
	local function Paint()
		-- (The old Look panel slider: a plain track and a gold thumb, nothing lit.)
		lit:SetVertexColor(1, 0.82, 0, 0)
		thumb:SetVertexColor(1, 0.82, 0, 1)
		local lo, hi = s:GetMinMaxValues()
		local f = hi > lo and (s:GetValue() - lo) / (hi - lo) or 0
		lit:SetWidth(math.max(1, f * s:GetWidth()))
	end
	box.setting = false
	s:SetScript("OnValueChanged", function(_, value)
		Paint()
		edit:SetText(Shown(value))
		if box.setting then return end
		if onSlide then onSlide(value) end
	end)
	s:SetScript("OnMouseUp", function(self)
		if onSlide then onSlide(nil) end
		onSet(self:GetValue())
	end)
	s:EnableMouseWheel(false)
	edit:SetScript("OnEnterPressed", function(self)
		local n = tonumber((self:GetText() or ""):match("%-?[%d%.]+"))
		self:ClearFocus()
		if n then
			n = n / scale
			local lo, hi = s:GetMinMaxValues()
			n = math.max(lo, math.min(hi, n))
			onSet(n)
		else
			self:SetText(Shown(s:GetValue()))
		end
	end)
	edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() self:SetText(Shown(s:GetValue())) end)
	function box:SetValue(value, default)
		self.setting = true
		s:SetValue(tonumber(value) or prop.min or 0)
		self.setting = false
		Paint()
		edit:SetText(Shown(tonumber(value) or 0))
		local lo, hi = s:GetMinMaxValues()
		if tonumber(default) and hi > lo then
			tick:ClearAllPoints()
			tick:SetPoint("CENTER", s, "LEFT", (default - lo) / (hi - lo) * s:GetWidth(), 0)
			tick:Show()
		else
			tick:Hide()
		end
	end
	function box:SetEnabled(on)
		s:SetEnabled(on)
		edit:SetEnabled(on)
		box:SetAlpha(on and 1 or 0.45)
	end
	box.slider, box.edit = s, edit
	return box
end

-- A switch, as the old Look panels' toggle (StylePages.lua's rows.Toggle): a small box
-- that fills gold when on, on a dark field with a dim edge, lit gold when on.
-- :SetValue(bool). (b.knob: the box, as tests and the rail asked for before.)
function C.Switch(parent, onSet)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(26, 22)
	b.fill = Fill(b, { 0.1, 0.1, 0.12 }, 0.95)
	b.edge = Edge(b, { 0.24, 0.24, 0.28 }, 1)
	local glow = NoSnap(b:CreateTexture(nil, "HIGHLIGHT"))
	glow:SetAllPoints()
	glow:SetTexture(FLAT)
	glow:SetVertexColor(1, 1, 1, 0.07)
	local box = NoSnap(b:CreateTexture(nil, "ARTWORK"))
	box:SetTexture(FLAT)
	box:SetSize(10, 10)
	box:SetPoint("CENTER")
	local boxFrame = CreateFrame("Frame", nil, b)
	boxFrame:SetAllPoints(box)
	Edge(boxFrame, { 0.45, 0.45, 0.5 }, 1)
	b.knob = box
	b:SetScript("OnClick", function(self) onSet(not self.value) end)
	function b:SetValue(value)
		self.value = value and true or false
		box:SetVertexColor(1, 0.82, 0, self.value and 1 or 0)
		if self.value then self.edge.Paint({ 0.66, 0.54, 0.17 }, 1) else self.edge.Paint({ 0.24, 0.24, 0.28 }, 1) end
	end
	hooksecurefunc(b, "SetEnabled", function(self, on) self:SetAlpha(on and 1 or 0.4) end)
	return b
end

-- Color chips: the color's sources as chips (prop.options), the Custom one with
-- its swatch; clicking the swatch opens the palette (the theme's colors first).
-- rgbNow(): the swatch's r, g, b now (the variant's keys: Studio.RGBValues).
function C.Chips(parent, prop, onPick, onSwatch, onHover, rgbNow)
	local options = type(prop.options) == "function" and prop.options() or prop.options or {}
	local box = C.Segments(parent, options, onPick, onHover)
	local sw
	if prop.rgb then
		sw = CreateFrame("Button", nil, box)
		sw:SetSize(18, 18)
		sw.color = sw:CreateTexture(nil, "ARTWORK")
		sw.color:SetPoint("TOPLEFT", 2, -2)
		sw.color:SetPoint("BOTTOMRIGHT", -2, 2)
		sw.color:SetTexture(FLAT)
		Edge(sw, Role("edge"), 0.8)
		sw:SetPoint("LEFT", box, "RIGHT", 4, 0)
		Tip(sw, L["Pick a color of your own."])
		sw:SetScript("OnClick", function()
			local r, g, b = rgbNow()
			ns.OpenColorPicker(r, g, b, function(nr, ng, nb) onSwatch(nr, ng, nb) end)
		end)
	end
	box.swatch = sw
	local setValue = box.SetValue
	function box:SetValue(value)
		setValue(self, value)
		if sw then
			sw.color:SetVertexColor(rgbNow())
			sw:SetShown(prop.custom == nil or value == prop.custom)
		end
	end
	local setEnabled = box.SetEnabled
	function box:SetEnabled(on)
		setEnabled(self, on)
		if sw then sw:SetEnabled(on) sw:SetAlpha(on and 1 or 0.45) end
	end
	return box
end

-- A scrolling column's signs (the user, 2026-11-25: the rail cut "Combat" in half at its
-- bottom and nothing said it scrolls): a thin bar at its right (its thumb as long as the
-- share shown), and a fade at the edge with more beyond it. Gives update(); kept current
-- as it scrolls or its child changes size. scroll.hasMore: there's more than it shows.
function C.ScrollSigns(scroll, child)
	local track = NoSnap(scroll:CreateTexture(nil, "OVERLAY"))
	track:SetTexture(FLAT)
	track:SetWidth(3)
	track:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, 0)
	track:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 0, 0)
	track:SetVertexColor(1, 1, 1, 0.06)
	local thumb = NoSnap(scroll:CreateTexture(nil, "OVERLAY", nil, 1))
	thumb:SetTexture(FLAT)
	thumb:SetWidth(3)
	local function Fade(top)
		local t = scroll:CreateTexture(nil, "OVERLAY", nil, 2)
		t:SetTexture(FLAT)
		t:SetHeight(26)
		t:SetPoint(top and "TOPLEFT" or "BOTTOMLEFT", scroll, top and "TOPLEFT" or "BOTTOMLEFT", 0, 0)
		t:SetPoint(top and "TOPRIGHT" or "BOTTOMRIGHT", scroll, top and "TOPRIGHT" or "BOTTOMRIGHT", -4, 0)
		local well = Role("well")
		local a, b = CreateColor and CreateColor(well[1], well[2], well[3], 0.95), CreateColor and CreateColor(well[1], well[2], well[3], 0)
		if not (a and pcall(t.SetGradient, t, "VERTICAL", top and b or a, top and a or b)) then
			t:SetVertexColor(well[1], well[2], well[3], 0.6)
		end
		return t
	end
	local topFade, bottomFade = Fade(true), Fade(false)
	local function Update()
		local view, full = scroll:GetHeight() or 0, child:GetHeight() or 0
		local more = full > view + 2
		scroll.hasMore = more
		track:SetShown(more)
		thumb:SetShown(more)
		local at = scroll:GetVerticalScroll() or 0
		local maxAt = math.max(0, full - view)
		topFade:SetShown(more and at > 2)
		bottomFade:SetShown(more and at < maxAt - 2)
		if more and view > 0 then
			local h = math.max(16, view * view / full)
			local y = (maxAt > 0 and at / maxAt or 0) * (view - h)
			local accent = Role("accent")
			thumb:SetVertexColor(accent[1], accent[2], accent[3], 0.55)
			thumb:SetHeight(h)
			thumb:ClearAllPoints()
			thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, -y)
		end
	end
	scroll:HookScript("OnVerticalScroll", Update)
	scroll:HookScript("OnShow", Update)
	child:HookScript("OnSizeChanged", Update)
	scroll.UpdateSigns = Update
	return Update
end

-- The source mark: one look everywhere (plan 4.1).
C.MARKS = {
	game = { "o", C.FAINT, "The game's value." },
	theme = { "<>", { 0.79, 0.64, 0.29 }, "From the theme." },
	general = { "<>", C.LILAC, "From the Style hub's Everything (General)." },
	follows = { "^", C.BLUE, "Follows the variant above. Click to go there." },
	yours = { "*", nil, "Yours. Right-click the row to reset it." },
	preview = { "~", C.AMBER, "Previewing: not saved." },
}
end) -- (ns.Module "style")
