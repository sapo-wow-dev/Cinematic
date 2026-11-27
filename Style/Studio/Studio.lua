-- Style Studio's two hosts (Tools/style-studio/plan.md section 3), one body:
--   ns.OpenStyleStudio(frameId, variant, partId): the Studio window, 960 x 640, docked
--     beside the settings like the CQL editor: the rail of frames, the stage (the frame's
--     preview, its parts clickable), the inspector, the footer.
--   ns.StyleEditorPage(kit, content, stack, frameId, opts): the same editor in one column
--     on a Style page (its preview on top, then the inspector), with Open in Studio.
-- Both draw the inspector with Studio.Body: status, Looks, Applies to, Part, then each
-- recipe's rows (source mark, label, control, reset).
local _, ns = ...
ns.Module("style", function()
local L = ns.L
local Studio = ns.Studio
local C = Studio.C
local FLAT = "Interface\\Buttons\\WHITE8x8"
local LABEL_W = 110 -- (room for "Custom color" whole: it was cut, run qd398)

-- Hosts listening for changes (each redraws what it shows).
local hosts = {}
Studio.OnChange(function(f)
	for host in pairs(hosts) do
		if host:IsVisible() and (not f or host.f == f or host.showsAll) then ns.Guard(host.Redraw, host) end
	end
end)

-- ns.OpenStylePage(page, frameId, variant): opens a Style page and picks the variant on
-- its editor (the pages' links go here, not to the Studio window: the user, 2026-11-25).
function ns.OpenStylePage(page, frameId, variant)
	if ns.OpenOptions then ns.OpenOptions(page) end
	if variant == nil then return end
	for host in pairs(hosts) do
		if not host.showsAll and host.f and host.f.id == frameId then host:Pick(nil, variant) end
	end
end

-- Every page's editor (not the Studio window's): the tests' way to them.
function ns.StylePageHosts()
	local list = {}
	for host in pairs(hosts) do if not host.showsAll then list[host] = true end end
	return list
end

-- (== true: the offline stand-in's stub answer isn't a fight.)
local function InFight() return InCombatLockdown and InCombatLockdown() == true end

-- A small mark: dot, diamond or caret, colored (C.MARKS).
local function Mark(parent)
	local m = CreateFrame("Button", nil, parent)
	m:SetSize(12, 16)
	m.dot = C.NoSnap(m:CreateTexture(nil, "ARTWORK"))
	m.dot:SetTexture(FLAT)
	m.dot:SetPoint("CENTER")
	m.caret = C.Text(m, "GameFontNormalSmall")
	m.caret:SetPoint("CENTER", 0, -2)
	m.caret:SetText("^")
	function m:SetSource(source)
		self.source = source
		local info = C.MARKS[source or "game"] or C.MARKS.game
		local color = info[2] or C.Role("accent")
		self.dot:SetRotation(0)
		self.caret:Hide()
		self.dot:Show()
		if source == "theme" or source == "general" then
			self.dot:SetSize(6, 6)
			self.dot:SetRotation(math.pi / 4)
		elseif source == "follows" then
			self.dot:Hide()
			self.caret:Show()
			self.caret:SetTextColor(color[1], color[2], color[3])
		elseif source == "yours" or source == "preview" then
			self.dot:SetSize(6, 6)
		else
			self.dot:SetSize(4, 4)
		end
		self.dot:SetVertexColor(color[1], color[2], color[3], source == "game" and 0.7 or 1)
	end
	C.Tip(m, function(self) local info = C.MARKS[self.source or "game"] return info and L[info[3]] end)
	return m
end

-- Body ------------------------------------------------------------------------------
-- body = Studio.Body(parent, width, host): body:Draw(f, variant, partId); body.height.
local function MakeRow(body, entry)
	-- (The nameplate editor (f.pickers): a wider name column, "Friendly players" whole, run q496d.)
	local LABEL_W = Studio.Pickers(body) and 124 or LABEL_W
	local prop = entry.prop
	local row = CreateFrame("Frame", nil, body.inner)
	row:SetSize(body.width, 24)
	row.prop, row.part, row.group = prop, entry.part, entry.group
	row.mark = Mark(row)
	row.mark:SetPoint("LEFT", 0, 0)
	row.mark:SetScript("OnClick", function()
		if row.mark.source == "follows" then body.host:Pick(nil, Studio.FirstVariant(body.f)) end
	end)
	row.label = C.Text(row, "GameFontHighlight", C.LABEL)
	row.label:SetPoint("LEFT", 14, 0)
	row.label:SetWidth(LABEL_W - 16)
	row.label:SetWordWrap(false)
	row.label:SetText(prop.label or "")
	local hit = CreateFrame("Button", nil, row)
	hit:SetPoint("TOPLEFT", row.label, "TOPLEFT", -2, 3)
	hit:SetPoint("BOTTOMRIGHT", row.label, "BOTTOMRIGHT", 2, -3)
	hit:RegisterForClicks("RightButtonUp")
	C.Tip(hit, function() return prop.tip end)
	hit:SetScript("OnClick", function() body.host:RowMenu(row) end)
	-- (A button or a note has no label and nothing to reset: no right-click spot over it,
	-- Plate Layout run q4715 found it under Mirror.)
	if prop.kind == "button" or prop.kind == "text" then hit:Hide() end
	row.reset = CreateFrame("Button", nil, row)
	row.reset:SetSize(14, 14)
	row.reset:SetPoint("RIGHT", 0, 0)
	local rt = C.Text(row.reset, "GameFontNormalSmall", C.DIM)
	rt:SetPoint("CENTER")
	rt:SetText("x")
	C.Tip(row.reset, L["Back to what it follows."])
	row.reset:SetScript("OnClick", function()
		Studio.Reset("prop", body.f, body.variant, row.part.id, prop, L["Reset"] .. " " .. (prop.label or ""))
	end)
	local controlW = body.width - LABEL_W - 18
	local f = body.f
	local pickers = Studio.Pickers(body)
	local function Variant() return body.variant end
	local function Key() return Studio.KeyOf(prop, Variant()) end
	local function Set(value) Studio.Set(f, prop, Variant(), value, row.part) end
	local function Hover(value)
		if value == nil then body.host:ShowStage() return end
		local key = Key()
		if key ~= nil then
			Studio.ShowFor(body.host:Preview(), key, value)
			body.host:Badge(L["Preview: not saved"])
		end
	end
	local options = prop.options
	-- (A list made by a function is told the variant shown: a choice can read "Default's"
	-- on a Smart row and "Theme's" on Default, Nameplate Style 2026-11-25.)
	if type(options) == "function" then
		local raw = options
		options = function() return raw(Variant()) end
	end
	local kind = prop.kind
	local control
	if kind == "seg" then
		local opts = type(options) == "function" and options() or options or {}
		-- (The mock's rule, 2026-11-25, for the nameplate editor (f.pickers): 3 choices or
		-- fewer, one segmented switch; more, the picker (a line opening the list). Elsewhere
		-- too wide for one line still wraps, as the old pages showed every choice.)
		if pickers and #opts > 3 then
			control = C.Drop(row, controlW, options, Set, Hover)
		else
			control = C.Segments(row, opts, Set, Hover, controlW)
			-- (pickers: 3 or fewer that don't fit on one line, the picker too; wrapped, Layout's
			-- Balance stacked its three down the page, the user 2026-11-25 "this looks bad".)
			if pickers and control:GetHeight() > 24 then
				control:Hide()
				control:ClearAllPoints()
				control = C.Drop(row, controlW, options, Set, Hover)
			end
		end
		if control:GetHeight() > 24 then
			row:SetHeight(control:GetHeight() + 2)
			row.label:ClearAllPoints()
			row.label:SetPoint("TOPLEFT", 14, -5)
			row.mark:ClearAllPoints()
			row.mark:SetPoint("TOPLEFT", 0, -6)
		end
	elseif kind == "tiles" and pickers then
		-- (Looks judged by eye, as one picker line: its sample and name, the list with each one's.)
		control = C.Drop(row, controlW, options, Set, Hover)
		control:SetHeight(26)
		row:SetHeight(28)
	elseif kind == "tiles" then
		control = C.Tiles(row, options, Set, Hover, prop.few or (controlW > 230 and 5 or 4), controlW)
		row:SetHeight(30)
	elseif kind == "slider" then
		control = C.Slider(row, controlW, prop, Set, function(value)
			if value == nil then body.host:ShowStage() return end
			local key = Key()
			if key ~= nil then Studio.ShowFor(body.host:Preview(), key, value) end
		end)
		-- (Its value box names its setting and redraws with the row: the number-box checks,
		-- Tools/offline/boxwords.lua.)
		if type(Key()) == "string" then control.edit.settingKey = Key() end
		control.edit.Refresh = function() row:Update() end
	elseif kind == "color" then
		control = C.Chips(row, prop, Set, function(r, g, b)
			local keys = Studio.RGB(prop, Variant())
			local writes = { { keys[1], r }, { keys[2], g }, { keys[3], b } }
			if prop.custom ~= nil then table.insert(writes, 1, { Key(), prop.custom }) end
			Studio.Apply(f, Studio.Describe(f, prop, Variant(), row.part, L["Custom"]), writes)
		end, Hover, function() return Studio.RGBValues(prop, Variant()) end)
		-- (f.pickers: always the picker line, its swatch after it while it's the color's own.)
		if pickers or control:GetWidth() + (prop.rgb and 22 or 0) > controlW then
			control:Hide()
			local swatch = control.swatch
			-- (Picking its own color (My own, Into a color): the palette opens at once.)
			local function PickColor(value)
				Set(value)
				if swatch and prop.custom ~= nil and value == prop.custom then swatch:Click() end
			end
			local drop = C.Drop(row, pickers and (controlW - 30) or math.min(controlW - 24, 150), options, PickColor, Hover)
			if swatch then swatch:SetParent(row) swatch:ClearAllPoints() swatch:SetPoint("LEFT", drop, "RIGHT", 4, 0) end
			function drop:SetValueAndSwatch(value)
				self:SetValue(value)
				if swatch then
					swatch.color:SetVertexColor(Studio.RGBValues(prop, Variant()))
					swatch:SetShown(prop.custom == nil or value == prop.custom)
				end
			end
			control = drop
		end
	elseif kind == "switch" then
		control = C.Switch(row, Set)
	elseif kind == "swatch" then
		-- (A color alone: picking one may switch its setting to Custom, prop.setKey/setTo.)
		control = CreateFrame("Button", nil, row)
		control:SetSize(36, 18)
		control.color = control:CreateTexture(nil, "ARTWORK")
		control.color:SetPoint("TOPLEFT", 2, -2)
		control.color:SetPoint("BOTTOMRIGHT", -2, 2)
		control.color:SetTexture(FLAT)
		C.Edge(control, C.Role("edge"), 0.8)
		control:SetScript("OnClick", function()
			local r0, g0, b0 = Studio.RGBValues(prop, Variant())
			ns.OpenColorPicker(r0, g0, b0, function(r, g, b)
				local keys = Studio.RGB(prop, Variant())
				local writes = { { keys[1], r }, { keys[2], g }, { keys[3], b } }
				if prop.setKey then table.insert(writes, 1, { Studio.KeyOf({ key = prop.setKey }, Variant()), prop.setTo }) end
				Studio.Apply(f, Studio.Describe(f, prop, Variant(), row.part, L["Custom"]), writes)
			end)
		end)
		function control:SetValue()
			self.color:SetVertexColor(Studio.RGBValues(prop, Variant()))
		end
		hooksecurefunc(control, "SetEnabled", function(self, on) self:SetAlpha(on and 1 or 0.45) end)
	elseif kind == "drop" then
		control = C.Drop(row, math.min(controlW, 200), options, Set, Hover)
	elseif kind == "button" then
		-- (pickers: a plain button in the settings' column; red, at the labels' edge, it read as a
		-- warning, the user 2026-11-25 "this looks bad")
		control = C.Button(row, prop.text or prop.label, nil, not pickers and "action" or nil)
		control:SetScript("OnClick", function() ns.Guard(prop.run, body.host) end)
		row.label:SetText("")
	elseif kind == "text" then
		control = C.Text(row, "GameFontHighlightSmall", C.DIM)
		control:SetWidth(body.width - 16)
		control:SetWordWrap(true)
		row.label:SetText("")
	end
	if control then
		control:SetPoint("LEFT", row, "LEFT", ((kind == "button" and not pickers) or kind == "text") and 14 or LABEL_W, 0)
		row.control = control
	end
	function row:Update()
		local db = ns.GetDB() or {}
		local shown = Studio.Shown(prop, db, Variant())
		self:SetShown(shown)
		if not shown then return false end
		if kind == "text" then
			local text = type(prop.text) == "function" and prop.text(db, Variant()) or prop.text or prop.label
			self.control:SetText(text or "")
			self:SetHeight(math.max(16, self.control:GetStringHeight() + 4))
			self.mark:Hide()
			self.reset:Hide()
			return true
		end
		local source, value = Studio.SourceOf(f, prop, Variant())
		self.mark:SetSource(source)
		-- (A mark only where it says something: yours, follows, General's or a preview. The
		-- game's and the theme's go unmarked: calm look, 2026-11-25.)
		self.mark:SetShown(source ~= nil and source ~= "game" and source ~= "theme")
		self.reset:SetShown(source == "yours")
		if rawget(self.control, "SetValueAndSwatch") then self.control:SetValueAndSwatch(value)
		elseif self.control.SetValue then
			if kind == "slider" then
				self.control:SetValue(value, Studio.ResetValue(f, prop, Variant()))
			else
				self.control:SetValue(value)
			end
		end
		local on = prop.free or not f.switch or ns.StyleOn(f.switch, db)
		if on and prop.test then on = prop.test(db, Variant()) and true or false end
		if self.control.SetEnabled then self.control:SetEnabled(on) end
		self.label:SetTextColor(on and C.LABEL[1] or 0.45, on and C.LABEL[2] or 0.45, on and C.LABEL[3] or 0.45)
		return true
	end
	return row
end

local function Header(body, text)
	-- (As the old Look panels' sections (StylePages.lua's rows.Section): the name in white
	-- over a thin line. The user, 2026-11-25: "revert the looks".)
	local h = CreateFrame("Frame", nil, body.inner)
	h:SetSize(body.width, 22)
	h.text = C.Text(h, "GameFontHighlight", { 1, 1, 1 })
	h.text:SetPoint("BOTTOMLEFT", 0, 5)
	h.text:SetText(text or "")
	local rule = h:CreateTexture(nil, "ARTWORK")
	rule:SetHeight(1)
	rule:SetPoint("BOTTOMLEFT", 0, 0)
	rule:SetPoint("BOTTOMRIGHT", 0, 0)
	rule:SetColorTexture(1, 1, 1, 0.12)
	h.rule = rule
	return h
end

-- (The mock's pickers look, 2026-11-25: the frame's own (the nameplate editor), or one
-- page's host asking for it (opts.pickers: the nameplates' Cast Bars tab).)
-- (The settings' box beside the preview, and the picked part tab open into it: one color.)
Studio.BOX = { 0.075, 0.079, 0.09 }
function Studio.Pickers(body)
	return (body.f and body.f.pickers) or (body.host and body.host.pickers) or false
end
function Studio.Body(parent, width, host)
	local body = CreateFrame("Frame", nil, parent)
	body:SetSize(width, 10)
	body.width, body.host = width, host
	body.inner = body
	body.rows, body.heads, body.pool = {}, {}, {}
	body.status = CreateFrame("Frame", nil, body)
	body.status:SetSize(width, 24)
	C.Fill(body.status, { 0.12, 0.1, 0.05 }, 0.95)
	body.status.edge = C.Edge(body.status, { 0.35, 0.29, 0.13 }, 1)
	body.status.text = C.Text(body.status, "GameFontHighlightSmall", { 0.91, 0.85, 0.65 })
	body.status.text:SetPoint("LEFT", 8, 0)
	body.status.text:SetPoint("RIGHT", -84, 0)
	body.status.text:SetWordWrap(true)
	body.status.button = C.Button(body.status, "", nil, "action")
	body.status.button:SetPoint("RIGHT", -4, 0)
	-- (The calm look: no headers over the pickers; the picked part's name is the heading,
	-- what it follows under it. Looks are a menu on the tool bar, Host:LooksMenu.)
	-- (The heading as the CQL editor's: the name in gold, what it belongs to dim beside it.)
	-- (In the old pages' header font: GameFontNormal, gold, as stack:Header's.)
	body.title = C.Text(body, "GameFontNormal", C.Role("accent"))
	body.titleSub = C.Text(body, "GameFontHighlightSmall", C.DIM)
	body.titleSub:SetPoint("BOTTOMLEFT", body.title, "BOTTOMRIGHT", 8, 2)
	body.variantNote = C.Text(body, "GameFontHighlightSmall", C.DIM)
	body.variantNote:SetWidth(width)

	function body:Draw(f, variant, partId)
		local switched = self.f ~= f
		self.f, self.variant = f, variant
		local pickers = Studio.Pickers(self)
		-- (A part can be for some variants only, part.shown(variant): a Smart row's Mark.)
		local parts = {}
		for _, p in ipairs(f.parts or {}) do
			if not p.shown or p.shown(variant) then parts[#parts + 1] = p end
		end
		self.parts = parts
		local part
		for _, p in ipairs(parts) do if p.id == partId then part = p end end
		part = part or parts[1]
		self.part = part
		local y = 0
		local function Place(frame, h, gap)
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
			frame:Show()
			y = y + (h or frame:GetHeight()) + (gap or 4)
		end
		-- Status: why it isn't showing.
		local text, kind, label, fn = Studio.Status(f, variant, part and part.id)
		if text then
			self.status.text:SetText(text)
			local red = kind == "off"
			self.status.edge.Paint(red and { 0.45, 0.15, 0.15 } or { 0.35, 0.29, 0.13 }, 1)
			self.status.text:SetTextColor(red and 0.94 or 0.91, red and 0.69 or 0.85, red and 0.66 or 0.65)
			self.status.button:SetShown(label ~= nil)
			if label then
				self.status.button:SetLabel(label)
				self.status.button:SetScript("OnClick", function() ns.Guard(fn) end)
			end
			local h = math.max(24, self.status.text:GetStringHeight() + 10)
			self.status:SetHeight(h)
			Place(self.status, h, 6)
		else
			self.status:Hide()
		end
		-- The variants (the first followed by the others) and the parts: two dropdowns on
		-- one line, each only where there's more than one. (Rows of pills before; the user
		-- 2026-11-25, twice: "i hate this look".)
		local note
		-- (host.only: one variant, its own (a Smart row's drawer; Default on its tab): no Applies to.)
		local hasVariants = f.variants and #f.variants > 1 and not self.host.only
		local hasParts = #parts > 1
		local row = self.pickRow
		if not row then
			row = CreateFrame("Frame", nil, self)
			row:SetSize(self.width, 22)
			row.forLabel = C.Text(row, "GameFontHighlight", C.DIM)
			row.variantDrop = C.Drop(row, 200, {}, function(v) self.host:Pick(nil, v) end)
			row.variantDrop:SetHeight(22)
			row.variantDrop:SetPoint("LEFT", row.forLabel, "RIGHT", 8, 0)
			row.partLabel = C.Text(row, "GameFontHighlight", C.DIM)
			row.partLabel:SetText(L["Part"])
			row.partDrop = C.Drop(row, 170, {}, function(id) self.host:Pick(id) end)
			row.partDrop:SetHeight(22)
			row.partDrop:SetPoint("LEFT", row.partLabel, "RIGHT", 8, 0)
			self.pickRow = row
		end
		-- (pickers, the nameplate editor: the parts are tabs under it, not a dropdown.)
		-- (Six parts or more (Layout's ten): no room for tabs, which ran past the settings'
		-- edge, run qb407; the mock's Part picker, a line of its own under Layout for.)
		local partTabs = pickers and hasParts and #parts <= 5
		local twoLines = pickers and hasParts and not partTabs and hasVariants
		row.forLabel:SetShown(hasVariants)
		row.variantDrop:SetShown(hasVariants)
		row.partLabel:SetShown(hasParts and not partTabs)
		row.partDrop:SetShown(hasParts and not partTabs)
		row.forLabel:ClearAllPoints()
		row.forLabel:SetPoint("LEFT", row, "LEFT", 0, 0)
		row.partLabel:ClearAllPoints()
		if hasVariants then
			row.partLabel:SetPoint("LEFT", row.variantDrop, "RIGHT", 18, 0)
		else
			row.partLabel:SetPoint("LEFT", row, "LEFT", 0, 0)
		end
		if hasVariants then
			row.forLabel:SetText(f.variantsLabel or L["Applies to"])
			local vopts = {}
			for _, v in ipairs(f.variants) do vopts[#vopts + 1] = { v.id, v.label } end
			row.variantDrop.options = vopts
			row.variantDrop:SetValue(variant)
		end
		if hasParts then
			-- (A part holding settings of yours: a gold dot after its name.)
			local popts = {}
			for _, p in ipairs(parts) do
				local mine = #Studio.Changed(f, variant, p.id) > 0
				popts[#popts + 1] = { p.id, mine and (p.label .. " |cffffd100*|r") or p.label }
			end
			row.partDrop.options = popts
			row.partDrop:SetValue(part and part.id)
		end
		if twoLines then
			-- (each its label at the left, its picker at one place after both)
			row:SetHeight(52)
			row.forLabel:ClearAllPoints()
			row.forLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -4)
			row.partLabel:ClearAllPoints()
			row.partLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -34)
			for i, drop in ipairs({ row.variantDrop, row.partDrop }) do
				drop:ClearAllPoints()
				drop:SetPoint("TOPLEFT", row, "TOPLEFT", 110, i == 1 and 0 or -30)
				drop:SetWidth(math.min(200, self.width - 116))
			end
		elseif row.twoLines then
			row:SetHeight(22)
			row.variantDrop:ClearAllPoints()
			row.variantDrop:SetPoint("LEFT", row.forLabel, "RIGHT", 8, 0)
			row.variantDrop:SetWidth(200)
			row.partDrop:ClearAllPoints()
			row.partDrop:SetPoint("LEFT", row.partLabel, "RIGHT", 8, 0)
			row.partDrop:SetWidth(170)
		end
		row.twoLines = twoLines
		if hasVariants or (hasParts and not partTabs) then Place(row, twoLines and 52 or 22, 10) else row:Hide() end
		-- The parts as tabs (the mock): each name, the picked one underlined gold; on a
		-- variant past the first (a Smart row), a dot: green while it sets something in that
		-- part, grey while it sets nothing there; on the first, a gold dot for your changes.
		self.tabs = self.tabs or {}
		for _, t in ipairs(self.tabs) do t:Hide() end
		if self.tabBase then self.tabBase:Hide() end
		if partTabs then
			local x = 0
			local onFirst = variant == Studio.FirstVariant(f)
			for i, p in ipairs(parts) do
				local t = self.tabs[i]
				if not t then
					-- (Folder tabs, as the page's own (Options.lua's FolderTabs), the user 2026-11-25:
					-- "more of a folder tab style". A box each, edged left, right and top; the picked
					-- one the settings box's color, open into it over the line under the tabs.)
					t = CreateFrame("Button", nil, self)
					t:SetHeight(22)
					t.text = C.Text(t, "GameFontNormalSmall")
					t.bg = t:CreateTexture(nil, "BACKGROUND")
					t.bg:SetAllPoints()
					t.bg:SetTexture(FLAT)
					t.edges = {}
					for _, side in ipairs({ "LEFT", "RIGHT", "TOP" }) do
						local e = t:CreateTexture(nil, "BORDER")
						e:SetTexture(FLAT)
						if side == "TOP" then
							e:SetPoint("TOPLEFT") e:SetPoint("TOPRIGHT") e:SetHeight(1)
						else
							e:SetPoint("TOP" .. side) e:SetPoint("BOTTOM" .. side) e:SetWidth(1)
						end
						t.edges[#t.edges + 1] = e
					end
					t.dot = t:CreateTexture(nil, "ARTWORK")
					t.dot:SetSize(6, 6)
					t.dot:SetTexture(FLAT)
					t.line = t:CreateTexture(nil, "ARTWORK") -- (kept for the tests: unused)
					t.line:SetSize(1, 1)
					t.line:SetAlpha(0)
					t:SetScript("OnClick", function(btn) self.host:Pick(btn.partId) end)
					self.tabs[i] = t
				end
				t.partId = p.id
				local mine = #Studio.Changed(f, variant, p.id) > 0
				local dotShown = (not onFirst) or mine
				t.dot:ClearAllPoints()
				t.dot:SetPoint("LEFT", 6, 0)
				t.dot:SetShown(dotShown)
				if not onFirst then
					-- (a row: green while it sets something here, else grey)
					if mine then t.dot:SetVertexColor(0.29, 0.75, 0.29) else t.dot:SetVertexColor(0.29, 0.27, 0.24) end
				else
					local a = C.Role("accent")
					t.dot:SetVertexColor(a[1], a[2], a[3])
				end
				t.text:ClearAllPoints()
				t.text:SetPoint("LEFT", dotShown and 16 or 8, 0)
				t.text:SetText(p.label)
				local picked = part and part.id == p.id
				-- (picked: the settings box's color, a lit edge, white words, a pixel taller to
				-- open over the line; the rest dark, dim edges, gold words)
				if picked then t.bg:SetVertexColor(Studio.BOX[1], Studio.BOX[2], Studio.BOX[3], 1) else t.bg:SetVertexColor(0.05, 0.05, 0.055, 1) end
				for _, e in ipairs(t.edges) do
					if picked then e:SetVertexColor(0.42, 0.42, 0.42, 1) else e:SetVertexColor(0.24, 0.23, 0.21, 1) end
				end
				if picked then t.text:SetTextColor(1, 1, 1) else t.text:SetTextColor(1, 0.82, 0) end
				t:SetHeight(picked and 23 or 21)
				t:SetFrameLevel(self:GetFrameLevel() + (picked and 3 or 2))
				t:SetWidth(math.floor(t.text:GetStringWidth() + (dotShown and 24 or 16)))
				t:ClearAllPoints()
				t:SetPoint("BOTTOMLEFT", self, "TOPLEFT", x, -(y + 23) + (picked and -1 or 0))
				t:Show()
				C.Tip(t, function()
					if onFirst then return nil end
					return mine and L["This row changes something here."] or L["This row changes nothing here: it's all Default's."]
				end)
				x = x + t:GetWidth() + 3
			end
			-- (the line under the tabs, across the settings, the picked tab open over it)
			if not self.tabBase then
				self.tabBase = self:CreateTexture(nil, "BORDER")
				self.tabBase:SetTexture(FLAT)
				self.tabBase:SetHeight(1)
				self.tabBase:SetVertexColor(0.42, 0.42, 0.42, 1)
			end
			self.tabBase:ClearAllPoints()
			self.tabBase:SetPoint("TOPLEFT", self, "TOPLEFT", -8, -(y + 23))
			self.tabBase:SetPoint("RIGHT", self, "RIGHT", 6, 0)
			self.tabBase:Show()
			y = y + 32
		end
		if hasVariants then
			local first = f.variants[1]
			local vname = first.label
			for _, v in ipairs(f.variants) do if v.id == variant then vname = v.label end end
			-- (f.independent: variants that don't follow one another, Cards' types.)
			if f.independent then
				local own = #Studio.Changed(f, variant)
				note = own > 0 and L["%s: %d settings of yours."]:format(vname, own) or L["%s, as it comes."]:format(vname)
			elseif variant == first.id then
				note = L["The others follow %s unless they set their own."]:format(first.label)
			else
				local own = #Studio.Changed(f, variant)
				note = own > 0 and L["%s follows %s except %d settings."]:format(vname, first.label, own)
					or L["%s follows %s for everything."]:format(vname, first.label)
			end
		end
		-- The heading: the part picked (or the frame), what it follows under it.
		-- (pickers: no heading (the tabs say the part) and the note a tooltip on Applies to:
		-- the user, 2026-11-25, "any descriptive text ... should just go as a tooltip".)
		if pickers then
			self.title:Hide()
			self.variantNote:Hide()
			C.Tip(row.forLabel, note)
			if not row.forLabelHit then
				row.forLabelHit = CreateFrame("Frame", nil, row)
				row.forLabelHit:SetAllPoints(row.forLabel)
				row.forLabelHit:EnableMouse(true)
			end
			C.Tip(row.forLabelHit, note)
			note = nil
		end
		local accent = C.Role("accent")
		self.title:SetTextColor(accent[1], accent[2], accent[3])
		local multi = part and #(f.parts or {}) > 1
		self.title:SetText(multi and part.label or f.label)
		local vname
		for vi, v in ipairs(f.variants or {}) do if vi > 1 and v.id == variant then vname = v.label end end
		self.titleSub:SetText(multi and (vname and (f.label .. " · " .. vname) or f.label) or (vname or ""))
		if not pickers then Place(self.title, 20, 2) end
		if note then
			self.variantNote:SetText(note)
			Place(self.variantNote, self.variantNote:GetStringHeight(), 10)
		else
			self.variantNote:Hide()
			y = y + 6
		end
		-- The part's rows, by recipe: a group's name only where the part has more than one.
		for _, r in pairs(self.rows) do r:Hide() end
		for _, h in pairs(self.heads) do h:Hide() end
		self.shownRows = {}
		if part then
			local db = ns.GetDB() or {}
			local groupsShown = 0
			-- (pickers: a note (kind "text") is no line on the page; its words join the tooltip
			-- on its group's header.)
			local function Drawn(prop) return Studio.Shown(prop, db, variant) and not (pickers and prop.kind == "text") end
			for _, group in ipairs(part.groups) do
				for _, prop in ipairs(group.props) do
					if Drawn(prop) then groupsShown = groupsShown + 1 break end
				end
			end
			for gi, group in ipairs(part.groups) do
				local any = false
				for _, prop in ipairs(group.props) do if Drawn(prop) then any = true end end
				if any then
					-- (The part's own group, "Look", needs no name: the part's is the heading.
					-- pickers: every group named, as the tabs carry the part's.)
					if (groupsShown > 1 or pickers) and (group.recipe ~= "Look" or pickers) then
						local hk = part.id .. ":" .. gi
						local head = self.heads[hk] or Header(self, "")
						self.heads[hk] = head
						head.text:SetText((group.label and L[group.label]) or L[group.recipe] or group.recipe)
						-- (pickers: the mock's headings, dim gold and no line under them.)
						if pickers then head.text:SetTextColor(0.85, 0.68, 0.38) else head.text:SetTextColor(1, 1, 1) end
						head.rule:SetShown(not pickers)
						if pickers then
							local words = {}
							if group.tip then words[#words + 1] = group.tip end
							for _, prop in ipairs(group.props) do
								if prop.kind == "text" and Studio.Shown(prop, db, variant) then
									local t = type(prop.text) == "function" and prop.text(db, variant) or prop.text or prop.label
									if t and t ~= "" then words[#words + 1] = t end
								end
							end
							head:EnableMouse(#words > 0)
							C.Tip(head, #words > 0 and table.concat(words, "\n") or nil)
						end
						y = y + 4
						Place(head, 22, 4)
					end
					for _, prop in ipairs(group.props) do
						if pickers and prop.kind == "text" then
							local r = self.rows[prop]
							if r then r:Hide() end
						else
						local row = self.rows[prop]
						if not row or row.builtFor ~= f then
							row = MakeRow(self, { prop = prop, part = part, group = group })
							row.builtFor = f
							self.rows[prop] = row
						end
						if row:Update() then
							Place(row, row:GetHeight(), 6)
							self.shownRows[#self.shownRows + 1] = row
						end
						end
					end
				end
			end
		end
		self.height = y
		self:SetHeight(math.max(10, y))
		if switched and self.host.OnBodyResized then self.host:OnBodyResized() end
		return y
	end
	function body:Update()
		for _, row in ipairs(self.shownRows or {}) do row:Update() end
	end
	function body:Flash(prop)
		local row = self.rows[prop]
		if not row or not row:IsShown() then return end
		if not row.flash then
			row.flash = row:CreateTexture(nil, "BACKGROUND")
			row.flash:SetAllPoints()
			row.flash:SetTexture(FLAT)
		end
		local accent = C.Role("accent")
		row.flash:SetVertexColor(accent[1], accent[2], accent[3], 0.2)
		row.flash:Show()
		C_Timer.After(1.2, function() row.flash:Hide() end)
		return row
	end
	return body
end

-- Host behaviour shared by the window and the page ------------------------------------
local Host = {}
function Host:Preview() return self.preview end
function Host:ShowStage()
	-- (Only on a page that shows: the pages are made at load, before ns.db, and
	-- a card's preview reads settings (CombatVision.lua:321, 2026-11-25). Its
	-- page's OnShow draws it then. Tools/errors/known.lua studio-stage-at-load.)
	local shown = not self.IsVisible or self:IsVisible()
	if shown and ns.db and self.preview and self.preview.Refresh then ns.Guard(self.preview.Refresh, self.preview) end
	self:Badge(nil)
end
function Host:Badge(text)
	if not self.badge then return end
	self.badge:SetText(text or "")
	self.badge:SetShown(text ~= nil)
end
function Host:Pick(partId, variant)
	if variant ~= nil then self.variant = variant end
	if partId then self.partId = partId end
	self:Redraw()
end
-- Hold to compare: the frame as it was when it opened here.
function Host:Snapshot()
	-- (A list of { key, value }: a key a db key or a field; each field once.)
	local snap, seen = {}, {}
	if not self.f then return snap end
	local function Keep(key)
		if key == nil or seen[key] then return end
		if type(key) == "table" and (key.noHover or not key.set) then return end
		seen[key] = true
		snap[#snap + 1] = { key, Studio.Get(key) }
	end
	for _, v in ipairs(Studio.Variants(self.f)) do
		for _, each in ipairs(Studio.Props(self.f)) do
			if each.prop.kind ~= "button" and each.prop.kind ~= "text" then Keep(Studio.KeyOf(each.prop, v.id)) end
			for _, rk in ipairs(Studio.RGB(each.prop, v.id) or {}) do Keep(rk) end
		end
	end
	self.snap = snap
end
function Host:Compare(on)
	local db = ns.GetDB()
	if not (db and self.preview and self.preview.Refresh) then return end
	if on then
		local saved = {}
		for i, pair in ipairs(self.snap or {}) do
			saved[i] = Studio.Get(pair[1])
			if saved[i] ~= pair[2] then pcall(Studio.Put, pair[1], pair[2]) end
		end
		ns.Guard(self.preview.Refresh, self.preview)
		for i, pair in ipairs(self.snap or {}) do
			if saved[i] ~= pair[2] then pcall(Studio.Put, pair[1], saved[i]) end
		end
		self:Badge(L["As it was when you opened it"])
	else
		self:ShowStage()
	end
end
-- The row's right-click: Reset, Copy, Paste, Show on other frames.
function Host:RowMenu(row)
	local prop, f = row.prop, self.f
	local value = Studio.Get(Studio.KeyOf(prop, self.variant))
	local opts = {}
	if Studio.SourceOf(f, prop, self.variant) == "yours" then opts[#opts + 1] = { "reset", L["Reset"] } end
	-- (Copy and Paste: the Studio window's only. On a page none of the copy look stuff:
	-- the user, 2026-11-25, "all this copy look stuff needs to go". A page's host has a kit.)
	if not self.kit then
		opts[#opts + 1] = { "copy", L["Copy"] }
		if Studio.rowClip ~= nil and Studio.rowClip.kind == prop.kind then opts[#opts + 1] = { "paste", L["Paste"] } end
	end
	-- ("Show on other frames" opened the Studio window: gone with its links, 2026-11-25.)
	if not self.kit then opts[#opts + 1] = { "find", L["Show on other frames"] } end
	if #opts == 0 then return end
	C.OpenList(row.label, opts, nil, function(what)
		if what == "reset" then Studio.Reset("prop", f, self.variant, row.part.id, prop)
		elseif what == "copy" then Studio.rowClip = { kind = prop.kind, value = value }
		elseif what == "paste" then Studio.Set(f, prop, self.variant, Studio.rowClip.value, row.part)
		elseif what == "find" then ns.OpenStyleStudio(f.id, self.variant, row.part.id, prop.label) end
	end)
end
-- Copy look / Paste: a part's values by recipe and label.
function Host:CopyLook()
	local part = self.body.part
	if not part then return end
	local values = {}
	for _, group in ipairs(part.groups) do
		for _, prop in ipairs(group.props) do
			local key = Studio.KeyOf(prop, self.variant)
			if key ~= nil and prop.kind ~= "button" and prop.kind ~= "text" then
				values[group.recipe .. ":" .. (prop.label or "")] = { prop = prop, value = Studio.Get(key),
					rgb = prop.rgb and { Studio.RGBValues(prop, self.variant) } }
			end
		end
	end
	Studio.lookClip = { from = self.f.label .. " - " .. part.label, values = values }
	self:Redraw()
end
function Host:CanPaste()
	local clip, part = Studio.lookClip, self.body and self.body.part
	if not (clip and part) then return false end
	for _, group in ipairs(part.groups) do
		for _, prop in ipairs(group.props) do
			local got = clip.values[group.recipe .. ":" .. (prop.label or "")]
			if got and got.prop ~= prop and got.prop.kind == prop.kind then return true end
		end
	end
	return false
end
function Host:Paste()
	local clip, part = Studio.lookClip, self.body.part
	local writes = {}
	for _, group in ipairs(part.groups) do
		for _, prop in ipairs(group.props) do
			local got = clip.values[group.recipe .. ":" .. (prop.label or "")]
			if got and got.prop.kind == prop.kind then
				-- (Only values this setting has: a choice the other page offers and this one doesn't is left.)
				local ok = true
				local opts = type(prop.options) == "function" and prop.options() or prop.options
				if opts and prop.kind ~= "tiles" then
					ok = false
					for _, o in ipairs(opts) do if (o.value ~= nil and o.value or o[1]) == got.value then ok = true end end
				end
				if ok then
					writes[#writes + 1] = { Studio.KeyOf(prop, self.variant), got.value }
					local keys = Studio.RGB(prop, self.variant)
					if keys and got.rgb then
						for i = 1, 3 do writes[#writes + 1] = { keys[i], got.rgb[i] } end
					end
				end
			end
		end
	end
	Studio.Apply(self.f, L["Paste"] .. ": " .. clip.from .. " > " .. part.label, writes)
end
-- Looks ▾: the theme's (every setting of this variant back), then the frame's own looks.
function Host:LooksMenu(anchor)
	if InFight() then return end
	local f = self.f
	if not f then return end
	local looks = { { id = "theme", label = L["Theme's"], reset = true, values = {} } }
	for _, look in ipairs(f.looks or {}) do looks[#looks + 1] = look end
	local opts = {}
	for i, look in ipairs(looks) do opts[i] = { i, look.label, look.tip } end
	C.OpenList(anchor, opts, nil, function(i)
		local look = looks[i]
		if look and Studio.ApplyLook(f, look, self.variant) and self.Toast then
			self:Toast(L["%s look used. Undo puts it back."]:format(look.label))
		end
	end)
end
-- Reset ▾: the scopes, each with its count; a second pick confirms.
-- (2026-11-26: on a Style page (self.pageScope, ns.StyleEditorPage) the widest is the page's
-- own, what its editor shows and its Reset page resets: "Everything in Style" there reset
-- Tooltips, Minimap, Combat Text and every other Style page too. The Studio window keeps it.)
function Host:ResetMenu(anchor)
	local f, part = self.f, self.body.part
	local scopes = { { "part", L["This part: %s"]:format(part and part.label or "") } }
	if f.variants and #f.variants > 1 and self.pageScope ~= "variant" then
		local name = ""
		for _, v in ipairs(f.variants) do if v.id == self.variant then name = v.label end end
		scopes[#scopes + 1] = { "variant", L["This variant: %s"]:format(name) }
	end
	if self.pageScope then
		-- (One row for the page: its frame, or its own variant where the frame is on several pages.)
		scopes[#scopes + 1] = { "page", L["Everything on this page"], scope = self.pageScope,
			variant = self.pageVariant }
	else
		scopes[#scopes + 1] = { "frame", L["This frame: %s"]:format(f.label) }
		scopes[#scopes + 1] = { "all", L["Everything in Style"] }
	end
	local opts = {}
	for _, s in ipairs(scopes) do
		local scope, variant = s.scope or s[1], s.variant
		if variant == nil then variant = self.variant end
		local n = #Studio.ResetWrites(scope, f, variant, part and part.id)
		opts[#opts + 1] = { s[1], ("%s  (%d)"):format(s[2], n), n = n, name = s[2], scope = scope, variant = variant }
	end
	C.OpenList(anchor, opts, nil, function(id)
		local n, name, scope, variant = 0, "", nil, nil
		for _, o in ipairs(opts) do if o[1] == id then n, name, scope, variant = o.n, o.name, o.scope, o.variant end end
		if n == 0 then return end
		C.OpenList(anchor, { { "yes", L["Reset %d settings (%s)"]:format(n, name) }, { "no", L["Cancel"] } }, nil, function(answer)
			if answer ~= "yes" then return end
			Studio.Reset(scope, f, variant, part and part.id, nil, L["Reset"] .. ": " .. name)
			if self.Toast then self:Toast(L["Reset %d settings."]:format(n), true) end
		end)
	end)
end
Studio.Host = Host

-- A Test button: Test, and Stop while the frame's test runs (f.testing() true; f.stop()
-- ends it), as every Test/Run/Play button does (running-button rule).
function Studio.TestButton(button, frameOf)
	local ticker
	local function Running()
		local f = frameOf()
		return f and f.testing and f.testing() and true or false
	end
	local function Paint()
		button:SetLabel(Running() and L["Stop"] or L["Test"])
		if not Running() and ticker then ticker:Cancel() ticker = nil end
	end
	button:SetScript("OnClick", function()
		local f = frameOf()
		if not f then return end
		if Running() and f.stop then ns.Guard(f.stop) elseif f.test then ns.Guard(f.test) end
		Paint()
		if f.testing and not ticker and C_Timer and C_Timer.NewTicker then ticker = C_Timer.NewTicker(0.25, Paint) end
	end)
	button:HookScript("OnShow", Paint)
end

-- Hotspots: each part with a region on the preview, clickable.
function Studio.Hotspots(host, holder)
	host.spots = host.spots or {}
	for _, spot in pairs(host.spots) do spot:Hide() end
	local f, preview = host.f, host.preview
	if not (f and preview) then return end
	for _, part in ipairs(f.parts or {}) do
		local region = part.region and select(2, pcall(part.region, preview))
		if region and region.GetObjectType then
			local spot = host.spots[part]
			if not spot then
				spot = CreateFrame("Button", nil, holder)
				spot.edge = C.Edge(spot, C.Role("accent"), 0)
				spot.name = C.Text(spot, "GameFontHighlightSmall")
				spot.name:SetPoint("BOTTOMLEFT", spot, "TOPLEFT", 0, 2)
				spot:SetScript("OnEnter", function(self) self.edge.Paint(C.Role("accent"), 0.8) self.name:SetText(part.label) end)
				spot:SetScript("OnLeave", function(self)
					self.edge.Paint(C.Role("accent"), host.partId == part.id and 0.95 or 0)
					self.name:SetText("")
				end)
				spot:SetScript("OnClick", function() host:Pick(part.id) end)
				spot:RegisterForClicks("LeftButtonUp")
				host.spots[part] = spot
			end
			spot:SetFrameLevel(preview:GetFrameLevel() + 30)
			spot:ClearAllPoints()
			spot:SetPoint("TOPLEFT", region, "TOPLEFT", -2, 2)
			spot:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 2, -2)
			spot.edge.Paint(C.Role("accent"), host.partId == part.id and 0.95 or 0)
			spot:Show()
		end
	end
end

-- The compact host: the editor on a Style page -----------------------------------------
-- opts: { preview = the page's own preview (a frame with :Refresh), canvas = the page's
-- canvas (its Reset page counts the editor's keys), variant = the one this page shows }.
-- (opts.free: placed by its caller (holder returned on host.holder), not added to a stack:
-- a Smart row's drawer, Nameplate Style's Smart tab, the mock 2026-11-25. opts.variant: the
-- one it edits; opts.only: no Applies to (the drawer's row is its variant).)
function ns.StyleEditorPage(kit, content, stack, frameId, opts)
	opts = opts or {}
	kit = kit or {}
	local f = Studio.frames[frameId]
	assert(f, "no Style frame " .. tostring(frameId))
	if not opts.free then f.pageCanvas = opts.canvas or content end -- (a drawer's editor isn't its page)
	local host = setmetatable({ f = f, variant = opts.variant ~= nil and opts.variant or Studio.FirstVariant(f), partId = nil,
		preview = opts.preview, kit = kit, only = opts.only, pickers = opts.pickers }, { __index = Host })
	-- (opts.side: the editor right of the page's preview, not under it (the mock,
	-- 2026-11-25); the preview's fixedWidth (268) on its left, the settings in the rest.)
	local side = opts.side and opts.preview
	-- (340: what's left of the page right of a 268 preview; 452 ran past its edge, run q496d.)
	-- (310 inside the tabs' framed panel: at 340, then 326, its pickers touched the panel's right edge,
	-- run qded0.)
	local WIDTH = opts.width or (side and 310 or 480)
	local holder = CreateFrame("Frame", nil, content)
	holder:SetSize(WIDTH, 30)
	host.holder = holder
	-- Its tools under the preview: Test, Undo, Redo, Looks, Copy look, Paste, Reset.
	-- (Two rows, so nothing runs past the page's 480: what plays and Open in Studio, then
	-- what changes settings. Words, not "<" ">"; menus with the game's arrow.)
	local bar = CreateFrame("Frame", nil, holder)
	bar:SetSize(WIDTH, 48)
	bar:SetPoint("TOPLEFT")
	-- (Each row laid out again as buttons show or hide (Paste, Looks): no holes.)
	local barRows = { {}, {} }
	local function Tool(row, label, _, tip, onClick, menu)
		local b = C.PanelTool(bar, label, menu) -- (the game's Panel buttons, as the old pages)
		barRows[row][#barRows[row] + 1] = b
		if tip then C.Tip(b, tip) end
		if onClick then b:SetScript("OnClick", onClick) end
		return b
	end
	-- (One flowing line, wrapped at the page's width: Test, then what changes settings.
	-- An empty row leaves no gap; the bar is as tall as its lines.)
	function host:FlowBar()
		local x, line = 0, 0
		for _, list in ipairs(barRows) do
			for _, b in ipairs(list) do
				if b:IsShown() then
					local w = b:GetWidth()
					if x > 0 and x + w > WIDTH then x, line = 0, line + 1 end
					b:ClearAllPoints()
					b:SetPoint("TOPLEFT", x, -line * 26)
					x = x + w + 4
				end
			end
		end
		self.barHeight = (line + 1) * 26 - 4
		bar:SetHeight(self.barHeight)
	end
	-- (A line between the tools and the settings: the parts are told apart at a glance.)
	local rule = C.NoSnap(holder:CreateTexture(nil, "ARTWORK"))
	rule:SetTexture(FLAT)
	rule:SetHeight(1)
	rule:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -5)
	rule:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -5)
	rule:SetVertexColor(1, 1, 1, 0.12)
	if f.test then
		host.testB = Tool(1, L["Test"], "action", L["Plays this look once."])
		Studio.TestButton(host.testB, function() return f end)
	end
	-- (No Hold to compare on the pages: the user, 2026-11-25, "get rid of this. i hate it".)
	host.undoB = Tool(2, L["Undo"], nil, function() local d = Studio.CanUndo() return d and (L["Undo"] .. ": " .. d) or L["Nothing to undo."] end,
		function() Studio.Undo() end)
	host.redoB = Tool(2, L["Redo"], nil, function() local d = Studio.CanRedo() return d and (L["Redo"] .. ": " .. d) or L["Nothing to redo."] end,
		function() Studio.Redo() end)
	host.looksB = Tool(2, L["Looks"], nil, L["Whole looks to start from; Undo puts it back."], function(self) host:LooksMenu(self) end, true)
	-- (No Copy look or Paste on the pages: the user, 2026-11-25, "all this copy look stuff
	-- needs to go". The Studio window keeps its own.)
	host.resetB = Tool(2, L["Reset"], nil, L["Back to what each setting follows: pick how much."], function(self) host:ResetMenu(self) end, true)
	-- (No way into the Studio window from a page: the user, 2026-11-25, "hide links to the
	-- studio". The window's code stays; nothing opens it.)
	host.badge = C.Text(holder, "GameFontNormalSmall", C.AMBER)
	host.badge:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 4)
	host.badge:Hide()
	host.body = Studio.Body(holder, WIDTH, host)
	host.body:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -12)
	-- (f.pickers, the nameplate editor (the mock, 2026-11-25): no Looks or Reset ("it's
	-- complicated, remove copy features and reset features"); Undo and Redo as words under
	-- the settings, each only while there's a step to take.)
	if f.pickers or host.pickers then
		host.looksB:Hide()
		host.resetB:Hide()
		rule:Hide()
		-- (The body off the bar first: the bar then hangs under it. The other way round was a
		-- loop, the game refused it, run qb32c.)
		host.body:ClearAllPoints()
		host.body:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", host.body, "BOTTOMLEFT", 0, -10)
		-- (A dim line under the settings while there's no step to undo; side by the preview, the
		-- settings on a box a shade lighter than the panel, edged: on the panel's own grey they
		-- didn't stand apart, the user 2026-11-25 "no background difference?".)
		-- (opts.free too, a Smart row's drawer: its rectangle left open there, the user 2026-11-26
		-- "finish this rectangle")
		if side or opts.free then
			local box = holder:CreateTexture(nil, "BACKGROUND", nil, -6)
			box:SetPoint("TOPLEFT", holder, "TOPLEFT", -8, 6)
			box:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 6, -8)
			-- (cool dark, as the preview's backdrop: warm brown-grey, the user 2026-11-25 "not a fan
			-- of the background color on the right panel")
			box:SetColorTexture(Studio.BOX[1], Studio.BOX[2], Studio.BOX[3], 1)
			local edge = holder:CreateTexture(nil, "BACKGROUND", nil, -7)
			edge:SetPoint("TOPLEFT", box, "TOPLEFT", -1, 1)
			edge:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 1, -1)
			edge:SetColorTexture(0.27, 0.27, 0.29, 1)
			host.box = box
		end
		host.idle = C.Text(holder, "GameFontDisableSmall", C.DIM)
		host.idle:SetPoint("TOPLEFT", host.body, "BOTTOMLEFT", 0, -12)
		host.idle:SetText(L["Nothing changed here"])
		host.idle.searchSkip = true
	end
	function host:Redraw()
		self.body:Draw(self.f, self.variant, self.partId)
		self.partId = self.body.part and self.body.part.id
		-- (The settings' box from the line under the part tabs down: behind the tabs it made a
		-- second background, the user 2026-11-25. The tabs on the panel, as the page's.)
		if self.box then
			local base = self.body.tabBase
			self.box:ClearAllPoints()
			if base and base:IsShown() then
				self.box:SetPoint("TOPLEFT", base, "TOPLEFT", 0, 0)
			else
				self.box:SetPoint("TOPLEFT", holder, "TOPLEFT", -8, 6)
			end
			self.box:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 6, -8)
		end
		self.undoB:SetEnabled(Studio.CanUndo() ~= nil)
		self.redoB:SetEnabled(Studio.CanRedo() ~= nil)
		if (self.f.pickers or self.pickers) then
			self.undoB:Hide()
			self.redoB:Hide()
			self.looksB:Hide()
			self.resetB:Hide()
		else
			self.looksB:SetShown(#(self.f.looks or {}) > 0) -- ("Theme's" alone is Reset's job)
		end
		self:FlowBar()
		if (self.f.pickers or self.pickers) then
			-- (No Undo or Redo here: each setting's x puts it back, the user 2026-11-26 "get rid of undo,
			-- we have the X". Nor the "Nothing changed here" line that stood in for them. A Test button
			-- kept.)
			local any = self.testB ~= nil
			bar:SetShown(any)
			self.undoB:Hide()
			self.redoB:Hide()
			if self.idle then self.idle:Hide() end
			holder:SetHeight(self.body.height + (any and (self.barHeight + 10) or 4))
		else
			holder:SetHeight(self.barHeight + 12 + self.body.height)
		end
		if self.spacer then
			-- (side: what's under them starts below the taller of the two)
			local spot = side.stackSpot or side
			self.spacer:SetHeight(math.max(1, holder:GetHeight() - (spot:GetHeight() or 0)))
		end
		if self.preview then Studio.Hotspots(self, self.preview) end
		self:ShowStage()
		if self.kit and self.kit.FitContentHeight then
			ns.Guard(self.kit.FitContentHeight, content)
			-- (Again once laid out: measured as it's drawn, its last rows weren't placed yet and the
			-- page (and the tabs' framed panel down it) stopped short of them, the user 2026-11-25.)
			local kitNow = self.kit
			local function Reach()
				ns.Guard(kitNow.FitContentHeight, content)
				-- (and at least down to this column's own bottom, its box's margin with it: measured
				-- with the page, it came up short of it, run q1a89. The tabs' framed panel hangs from
				-- the page's bottom, so it follows. Never the panel hung from this column: the column
				-- hangs from the panel through the page's title, a loop the game refused, run q892b.)
				local top, bottom = content:GetTop(), holder:GetBottom()
				if top and bottom and holder:IsShown() then
					local need = top - bottom + 24
					if need > (content:GetHeight() or 0) then content:SetHeight(need) end
				end
			end
			-- (Next frame, and again a moment later: a page just opened isn't laid out by then,
			-- run q892b, Cast Bars short of its last rows till a part was picked.)
			C_Timer.After(0, Reach)
			C_Timer.After(0.15, Reach)
		end
	end
	function host:IsVisible() return holder:IsVisible() end
	hosts[host] = true
	holder.Refresh = function() host:Redraw() end
	holder:SetScript("OnShow", function() host:Snapshot() host:Redraw() end)
	if kit.AddControl then kit.AddControl(holder) end
	-- (Reset page: every setting here, fields too, back to what it follows.)
	-- (A frame on several pages (f.pages: Cast bars): each page resets and counts only its
	-- own variant, as it did before.)
	local onlyVariant = f.pages and opts.variant ~= nil
	-- (2026-11-26: Reset's widest on this page is what Reset page resets: Host:ResetMenu.)
	host.pageScope, host.pageVariant = onlyVariant and "variant" or "frame", onlyVariant and opts.variant or nil
	local pageCanvas = opts.canvas or content
	if kit.OnReset and not opts.ownReset then
		kit.OnReset(content, function()
			if onlyVariant then
				Studio.Reset("variant", f, opts.variant, nil, nil, L["Reset page"])
			else
				Studio.Reset("frame", f, nil, nil, nil, L["Reset page"])
			end
		end)
	end
	for _, each in ipairs(Studio.Props(f)) do
		for _, v in ipairs(Studio.Variants(f)) do
			if not onlyVariant or v.id == opts.variant then
				local key = Studio.KeyOf(each.prop, v.id)
				if type(key) == "string" and kit.RecordKey then kit.RecordKey(pageCanvas, key) end
				for _, rk in ipairs(Studio.RGB(each.prop, v.id) or {}) do
					if type(rk) == "string" and kit.RecordKey then kit.RecordKey(pageCanvas, rk) end
				end
			end
		end
	end
	-- /cine find and the page's search: a hidden marker per setting (its first variant's
	-- key, or a field's key name), searchAlways so the walk counts it though the editor
	-- draws only the picked part. Finding one picks its part and flashes its row.
	-- (The editor's own words (headers, part and variant buttons, its tool bar) are left
	-- out of the search: the markers stand for its settings, one each.)
	host.body.searchSkip, bar.searchSkip = true, true
	-- (A drawer's editor (opts.free): none of its own; the page's editor has them.)
	local markers = CreateFrame("Frame", nil, holder)
	if opts.free then markers.searchSkip = true end
	markers:SetAllPoints(host.body)
	markers:Hide()
	markers.searchAlways = true
	local firstVariant = onlyVariant and opts.variant or Studio.FirstVariant(f)
	for _, each in ipairs(Studio.Props(f)) do
		local prop = each.prop
		local key = prop.kind ~= "button" and prop.kind ~= "text" and Studio.KeyOf(prop, firstVariant)
		local id = type(key) == "string" and key or (type(key) == "table" and type(key.key) == "string" and key.key) or nil
		if id and prop.label and not opts.free then
			local m = CreateFrame("Frame", nil, markers)
			m:SetAllPoints(markers)
			m.searchAlways, m.settingKey, m.searchLabel, m.searchTip = true, id, prop.label, prop.tip
			m.searchEdges = { top = m, bottom = m, left = m, right = m }
			local partId = each.part.id
			m.openSection = function()
				host:Pick(partId, firstVariant)
				C_Timer.After(0, function() host.body:Flash(prop) end)
			end
		end
	end
	if opts.free then
		-- (its caller places it)
	elseif side then
		-- (Beside the preview's spot; a spacer in the stack keeps what follows under both.)
		holder:SetPoint("TOPLEFT", side.stackSpot or side, "TOPRIGHT", 14, 0)
		if side.stackSpot then side.stackSpot.keepRoom = true end -- (the page keeps its length as the preview pins: StylePages.lua's SetRoom)
		local spacer = CreateFrame("Frame", nil, content)
		spacer:SetSize(1, 1)
		spacer.searchSkip = true
		host.spacer = spacer
		stack:Add(spacer, "label")
	else
		stack:Add(holder, "label")
	end
	ns.Guard(host.Redraw, host) -- (an error drawing it: logged, the page and the ones after it still made)
	return host
end

-- The Studio window --------------------------------------------------------------------
local W, H, RAIL, INSP = 960, 640, 170, 330
local studio
local function BuildStudio()
	local win = CreateFrame("Frame", "CinematicStyleStudio", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	studio = win
	win:SetSize(W, H)
	win:SetPoint("CENTER")
	win:SetFrameStrata("DIALOG")
	win:SetToplevel(true)
	win:EnableMouse(true)
	if win.SetBackdrop then
		win:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 } })
	end
	ns.SkinWindow(win)
	-- (DockBeside's own button drew as an empty red box here (run q9b7c): it stays, out
	-- of sight, doing the docking; ours shows its words, Pop out or Dock.)
	local dock = ns.DockBeside(win, "styleStudio")
	dock:SetAlpha(0)
	dock:EnableMouse(false)
	local popB = C.Button(win, L["Pop out"])
	popB:SetPoint("TOPRIGHT", -30, -6)
	local function PopLabel() popB:SetLabel(dock:GetText() or L["Pop out"]) end
	popB:SetScript("OnClick", function()
		local fn = dock:GetScript("OnClick") -- (DockBeside's own: works with the dock button hidden)
		if fn then fn(dock, "LeftButton") end
		PopLabel()
	end)
	C.Tip(popB, L["Pop out to move the window anywhere, or dock it back by the settings."])
	win:HookScript("OnShow", function() C_Timer.After(0, PopLabel) end)
	tinsert(UISpecialFrames, "CinematicStyleStudio")
	local host = setmetatable({ showsAll = true }, { __index = Host })
	win.host = host
	hosts[host] = true
	function host:IsVisible() return win:IsVisible() end
	local close = ns.SkinClose(CreateFrame("Button", nil, win, "UIPanelCloseButton"))
	close:SetPoint("TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function() win:Hide() end)

	-- Title bar: STYLE, where you are, Find, Undo/Redo.
	local brand = C.Text(win, "GameFontNormal")
	brand:SetPoint("TOPLEFT", 14, -10)
	brand:SetText(L["Style"])
	local crumbs = C.Text(win, "GameFontHighlightSmall", C.DIM)
	crumbs:SetPoint("TOP", win, "TOP", -60, -10) -- (centered, as the CQL editor's rule name)
	crumbs:SetWidth(300)
	crumbs:SetJustifyH("CENTER")
	crumbs:SetFontObject("GameFontHighlight")
	crumbs:SetWordWrap(false)
	local find = CreateFrame("EditBox", nil, win)
	find:SetAutoFocus(false)
	find:SetFontObject("GameFontHighlightSmall")
	find:SetSize(170, 20)
	find:SetTextInsets(6, 6, 0, 0)
	C.Fill(find, C.Role("well"), 0.9)
	C.Edge(find, C.Role("edge"), 0.5)
	local findHint = C.Text(find, "GameFontDisableSmall")
	findHint:SetPoint("LEFT", 6, 0)
	findHint:SetText(L["Find a setting..."])
	-- (Right to left: X, Pop out, Redo, Undo, Find.)
	local redoB = C.Button(win, L["Redo"])
	redoB:SetPoint("RIGHT", popB, "LEFT", -10, 0)
	local undoB = C.Button(win, L["Undo"])
	undoB:SetPoint("RIGHT", redoB, "LEFT", -3, 0)
	find:SetPoint("RIGHT", undoB, "LEFT", -8, 0)
	undoB:SetScript("OnClick", function() Studio.Undo() end)
	C.Tip(undoB, function() local d = Studio.CanUndo() return d and (L["Undo"] .. ": " .. d) or L["Nothing to undo."] end)
	redoB:SetScript("OnClick", function() Studio.Redo() end)
	C.Tip(redoB, function() local d = Studio.CanRedo() return d and (L["Redo"] .. ": " .. d) or L["Nothing to redo."] end)
	local function FindShow()
		local text = find:GetText() or ""
		findHint:SetShown(text == "")
		local hits = Studio.Find(text, 40)
		if text == "" then C.CloseList() return end
		local opts = {}
		for i, hit in ipairs(hits) do
			opts[#opts + 1] = { i, ("%s  |cff888888%s - %s|r"):format(hit.prop.label, hit.part.label, hit.f.label) }
		end
		if #opts == 0 then opts[1] = { 0, L["No setting matches."] } end
		-- (Each letter typed: the list drawn again, not toggled shut. No Find box of its own.)
		C.CloseList()
		C.OpenList(find, opts, nil, function(i)
			local hit = hits[i]
			if not hit then return end
			find:SetText("")
			find:ClearFocus()
			ns.OpenStyleStudio(hit.f.id, nil, hit.part.id)
			C_Timer.After(0, function() win.body:Flash(hit.prop) end)
		end, nil, true)
	end
	find:SetScript("OnTextChanged", FindShow)
	find:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() C.CloseList() end)
	find:SetScript("OnEnterPressed", function(self)
		local hits = Studio.Find(self:GetText(), 1)
		if hits[1] then
			self:SetText("")
			self:ClearFocus()
			C.CloseList()
			ns.OpenStyleStudio(hits[1].f.id, nil, hits[1].part.id)
			C_Timer.After(0, function() win.body:Flash(hits[1].prop) end)
		end
	end)
	local titleLine = C.NoSnap(win:CreateTexture(nil, "ARTWORK"))
	titleLine:SetTexture(FLAT)
	titleLine:SetHeight(1)
	titleLine:SetPoint("TOPLEFT", 8, -32)
	titleLine:SetPoint("TOPRIGHT", -8, -32)
	titleLine:SetVertexColor(1, 1, 1, 0.1)

	-- Rail: Changed, then every frame by band.
	local rail = CreateFrame("ScrollFrame", nil, win)
	rail:SetPoint("TOPLEFT", 8, -36)
	rail:SetSize(RAIL - 8, H - 36 - 44)
	rail:EnableMouseWheel(true)
	local railBody = CreateFrame("Frame", nil, rail)
	railBody:SetSize(RAIL - 8, 10)
	rail:SetScrollChild(railBody)
	win.railSigns = C.ScrollSigns(rail, railBody)
	win.rail = rail
	rail:SetScript("OnMouseWheel", function(self, delta)
		local max = math.max(0, railBody:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - delta * 40)))
	end)
	local railItems, railHeads = {}, {}
	local BAND_COLOR = { General = { 1, 0.82, 0 }, Interface = { 0.35, 0.6, 0.9 }, Visions = { 0.85, 0.3, 0.25 },
		Atmosphere = { 0.65, 0.45, 0.9 } }
	local function RailItem(i)
		local b = railItems[i]
		if b then return b end
		b = CreateFrame("Button", nil, railBody)
		-- (The calm look: a frame's name, a gold dot when it has settings of yours, dimmed when
		-- its page is off; right-click turns it on or off. No switch drawn on every line.)
		b:SetSize(RAIL - 12, 20)
		b.pickBack = C.Fill(b, C.Role("accent"), 0)
		b.bar = C.NoSnap(b:CreateTexture(nil, "ARTWORK"))
		b.bar:SetTexture(FLAT)
		b.bar:SetSize(3, 20)
		b.bar:SetPoint("LEFT")
		b.sq = C.NoSnap(b:CreateTexture(nil, "ARTWORK"))
		b.sq:SetTexture(FLAT)
		b.sq:SetSize(6, 6)
		b.sq:SetPoint("LEFT", 8, 0)
		b.text = C.Text(b, "GameFontHighlight")
		b.text:SetPoint("LEFT", 20, 0) -- (after its band's square)
		b.text:SetPoint("RIGHT", -16, 0)
		b.text:SetWordWrap(false)
		b.dot = C.NoSnap(b:CreateTexture(nil, "ARTWORK"))
		b.dot:SetTexture(FLAT)
		b.dot:SetSize(6, 6)
		b.dot:SetPoint("RIGHT", -6, 0)
		C.Tip(b, function(self)
			if self.frameId == "__changed" then return L["Every setting of yours, by frame."] end
			return L["Right-click to turn this look on or off."]
		end)
		local hi = b:CreateTexture(nil, "HIGHLIGHT")
		hi:SetAllPoints()
		hi:SetColorTexture(1, 1, 1, 0.05)
		b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		railItems[i] = b
		return b
	end
	local function RailHead(key, text, color)
		local h = railHeads[key]
		if not h then
			h = CreateFrame("Frame", nil, railBody)
			h:SetSize(RAIL - 12, 16)
			h.sq = C.NoSnap(h:CreateTexture(nil, "ARTWORK"))
			h.sq:SetTexture(FLAT)
			h.sq:SetSize(6, 6)
			h.sq:SetPoint("LEFT", 4, 0)
			h.text = C.Text(h, "GameFontNormalSmall", { 0.54, 0.51, 0.44 })
			h.text:SetPoint("LEFT", 14, 0)
			railHeads[key] = h
		end
		h.text:SetText(text)
		h.sq:SetShown(color ~= nil)
		-- (A band (it has a color): its name at a readable size; a group inside it smaller,
		-- dim. Run q9b7c: both were tiny.)
		if color then
			h.sq:SetVertexColor(color[1], color[2], color[3])
			h.text:SetFontObject("GameFontNormal")
			h.text:SetTextColor(color[1], color[2], color[3]) -- (in its band's color, as CQL's categories)
			h:SetHeight(20)
		else
			h.text:SetFontObject("GameFontHighlightSmall")
			h.text:SetTextColor(0.6, 0.57, 0.5)
			h:SetHeight(16)
		end
		return h
	end
	local function SwitchOf(f, on)
		if InFight() then return end
		Studio.Apply(f, f.label .. " > " .. (on and L["On"] or L["Off"]), { { f.switch, on } })
	end
	function win.Rail()
		local y, n = 0, 0
		for _, h in pairs(railHeads) do h:Hide() end
		-- Changed (n): every setting of yours.
		n = n + 1
		local ch = RailItem(n)
		local total = 0
		for _, f in ipairs(Studio.Ordered()) do total = total + Studio.ChangedCount(f) end
		ch.text:SetText(L["Changed"] .. " (" .. total .. ")")
		ch.sq:Hide()
		ch.dot:Hide()
		ch.frameId = "__changed"
		ch:SetScript("OnClick", function() win.ShowChanged() end)
		ch:ClearAllPoints()
		ch:SetPoint("TOPLEFT", 0, -y)
		y = y + 22
		local band, sub
		for _, f in ipairs(Studio.Ordered()) do
			if f.band ~= band then
				band, sub = f.band, nil
				local h = RailHead("b:" .. band, L[band] or band, BAND_COLOR[band])
				h:ClearAllPoints()
				h:SetPoint("TOPLEFT", 0, -(y + 8))
				h:Show()
				y = y + 28
			end
			if f.sub and f.sub ~= sub and f.band ~= "General" then -- (General: no groups shown)
				sub = f.sub
				local h = RailHead("s:" .. band .. sub, "  " .. (L[sub] or sub), nil)
				h:ClearAllPoints()
				h:SetPoint("TOPLEFT", 6, -y)
				h:Show()
				y = y + 16
			end
			n = n + 1
			local b = RailItem(n)
			b.frameId = f.id
			b.text:SetText(f.label)
			-- (Its band's colored square, as the CQL editor's categories.)
			local bandColor = BAND_COLOR[f.band] or C.DIM
			b.sq:SetVertexColor(bandColor[1], bandColor[2], bandColor[3])
			b.sq:Show()
			local db = ns.GetDB() or {}
			local on = not f.switch or (db[f.switch] and true or false)
			b.text:SetTextColor(on and C.TEXT[1] or 0.45, on and C.TEXT[2] or 0.45, on and C.TEXT[3] or 0.45)
			local changed = Studio.ChangedCount(f) > 0
			local accent = C.Role("accent")
			b.dot:SetVertexColor(accent[1], accent[2], accent[3])
			b.dot:SetShown(changed)
			local picked = host.f == f and not win.changedView
			b.pickBack:SetVertexColor(accent[1], accent[2], accent[3], picked and 0.14 or 0)
			b.bar:SetVertexColor(accent[1], accent[2], accent[3], picked and 1 or 0)
			b:SetScript("OnClick", function(_, button)
				if button == "RightButton" then
					if f.switch then SwitchOf(f, not on) end
				else
					ns.OpenStyleStudio(f.id)
				end
			end)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", 0, -y)
			b:Show()
			y = y + 21
		end
		for i = n + 1, #railItems do railItems[i]:Hide() end
		railBody:SetHeight(y + 6)
		win.railSigns()
	end

	-- Stage: the frame's preview, fitted, its parts clickable; tools under it.
	local stageW = W - RAIL - INSP - 16
	local stage = CreateFrame("Frame", nil, win)
	stage:SetPoint("TOPLEFT", RAIL + 4, -36)
	local STAGE_MAX = H - 36 - 44 - 30
	stage:SetSize(stageW, STAGE_MAX)
	-- (A dark well, the preview on it as its own lit card with an edge: the user,
	-- 2026-11-25, "no difference between the previewer and its background". Only the
	-- preview's "Preview" caption is hidden here: the card says what it is.)
	C.Fill(stage, { 0.015, 0.014, 0.012 }, 0.96)
	C.Edge(stage, C.QUIET, 0.9)
	if stage.SetClipsChildren then stage:SetClipsChildren(true) end -- (2x zoom stays inside it)
	win.stage = stage
	host.badge = C.Text(stage, "GameFontNormalSmall", C.AMBER)
	host.badge:SetPoint("TOPLEFT", 8, -6)
	host.badge:Hide()
	local hint = C.Text(stage, "GameFontDisableSmall")
	hint:SetPoint("BOTTOM", 0, 6)
	hint:SetText(L["Click a part to edit it"])
	local slots = {} -- (frame id -> its preview, made once)
	-- (A frame with no preview: its name and a word on where to look, not an empty box.)
	local empty = CreateFrame("Frame", nil, stage)
	empty:SetSize(stageW - 60, 80)
	empty:SetPoint("CENTER", 0, 20)
	empty.title = C.Text(empty, "GameFontNormalLarge", C.Role("accent"))
	empty.title:SetPoint("TOP")
	empty.title:SetJustifyH("CENTER")
	empty.text = C.Text(empty, "GameFontHighlight", C.DIM)
	empty.text:SetPoint("TOP", empty.title, "BOTTOM", 0, -10)
	empty.text:SetWidth(stageW - 60)
	empty.text:SetJustifyH("CENTER")
	empty.text:SetText(L["Nothing to draw here: these settings change the game's own frames. Hold Peek to see them."])
	empty:Hide()
	local tools = CreateFrame("Frame", nil, win)
	tools:SetPoint("TOPLEFT", stage, "BOTTOMLEFT", 0, -5)
	tools:SetSize(stageW, 22)
	local tx = 0
	local function Tool(label, kind, tip)
		local b = C.Button(tools, label, nil, kind)
		b:SetPoint("LEFT", tx, 0)
		tx = tx + b:GetWidth() + 4
		if tip then C.Tip(b, tip) end
		return b
	end
	local testB = Tool(L["Test"], "action", L["Plays this look once."])
	Studio.TestButton(testB, function() return host.f end)

	-- In the stage's foot: your settings on this frame (up to five, then "all of them"),
	-- each a click to go there, x to put it back. Not shown with none.
	local MINE_MAX = 5
	local mine = CreateFrame("Frame", nil, stage)
	mine:SetPoint("BOTTOMLEFT", 8, 22)
	mine:SetWidth(stageW - 16)
	C.Fill(mine, { 0, 0, 0 }, 0.55)
	C.Edge(mine, C.Role("edge"), 0.35)
	mine:SetFrameLevel(stage:GetFrameLevel() + 40)
	mine.title = C.Text(mine, "GameFontNormal", C.TEXT)
	mine.title:SetPoint("TOPLEFT", 8, -6)
	mine.more = C.Button(mine, L["All of them"])
	mine.more:SetPoint("TOPRIGHT", -6, -4)
	mine.more:SetScript("OnClick", function() win.ShowChanged() end)
	mine.lines = {}
	function win.Mine(f)
		local list = Studio.Changed(f)
		mine:SetShown(#list > 0)
		if #list == 0 then return end
		mine.title:SetText(L["Yours on %s (%d)"]:format(f.label, #list))
		mine.more:SetShown(#list > MINE_MAX)
		local room = MINE_MAX
		for _, line in ipairs(mine.lines) do line:Hide() end
		mine:SetHeight(30 + math.min(#list, room) * 21)
		for i, each in ipairs(list) do
			if i > room then break end
			local line = mine.lines[i]
			if not line then
				line = CreateFrame("Button", nil, mine)
				line:SetSize(stageW - 28, 20)
				line.text = C.Text(line, "GameFontHighlight", C.LABEL)
				line.text:SetPoint("LEFT", 4, 0)
				line.text:SetPoint("RIGHT", -24, 0)
				line.text:SetWordWrap(false)
				local hi = line:CreateTexture(nil, "HIGHLIGHT")
				hi:SetAllPoints()
				hi:SetColorTexture(1, 1, 1, 0.05)
				line.x = C.Button(line, "x", 18)
				line.x:SetPoint("RIGHT", -2, 0)
				C.Tip(line.x, L["Back to what it follows."])
				mine.lines[i] = line
			end
			local vname
			for vi, v in ipairs(f.variants or {}) do if vi > 1 and v.id == each.variant then vname = v.label end end
			line.text:SetText((vname and (vname .. "  ·  ") or "") .. each.part.label .. "  ·  |cffe8e2d4" .. (each.prop.label or "") .. "|r")
			line:SetPoint("TOPLEFT", mine.title, "BOTTOMLEFT", -4, -4 - (i - 1) * 21)
			line:SetScript("OnClick", function() host:Pick(each.part.id, each.variant) end)
			line.x:SetScript("OnClick", function() Studio.Reset("prop", f, each.variant, each.part.id, each.prop) end)
			line:Show()
		end
	end
	local compareB = Tool(L["Hold to compare"], nil, L["Hold: as it was when you opened it here."])
	compareB:SetScript("OnMouseDown", function() host:Compare(true) end)
	compareB:SetScript("OnMouseUp", function() host:Compare(false) end)
	local peekB = Tool(L["Peek"], nil, L["Hold: the Studio fades so you see the real frames."])
	peekB:SetScript("OnMouseDown", function() win:SetAlpha(0.06) end)
	peekB:SetScript("OnMouseUp", function() win:SetAlpha(1) end)
	-- (2x: the preview at twice its fitted size, to judge a 1 px line; plan's Depth 7.)
	local zoomB = Tool(L["2x"], nil, L["Shows the preview twice as big."])
	zoomB:SetScript("OnClick", function(self)
		win.zoomed = not win.zoomed
		self:Paint(win.zoomed and "on" or nil)
		for _, slot in pairs(slots) do
			if slot.preview and slot.fit then slot.preview:SetScale(slot.fit * (win.zoomed and 2 or 1)) end
		end
	end)
	local pageB = Tool(L["Its page"], nil, L["Opens this look's page in the settings."])
	pageB:SetScript("OnClick", function()
		if host.f and ns.OpenOptions then ns.OpenOptions(host.f.page or "Style General") end
	end)

	-- Inspector: a scroll of the body.
	local insp = CreateFrame("ScrollFrame", nil, win)
	insp:SetPoint("TOPRIGHT", -10, -38)
	insp:SetSize(INSP - 6, H - 38 - 46)
	insp:EnableMouseWheel(true)
	local body = Studio.Body(insp, INSP - 14, host)
	insp:SetScrollChild(body)
	win.inspSigns = C.ScrollSigns(insp, body)
	insp:SetScript("OnMouseWheel", function(self, delta)
		local max = math.max(0, body:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - delta * 40)))
	end)
	host.body, win.body = body, body
	function host:OnBodyResized() insp:SetVerticalScroll(0) end
	-- The Changed view: a list in the inspector's place.
	local changedList = CreateFrame("Frame", nil, insp)
	changedList:SetSize(INSP - 14, 10)
	changedList.lines = {}
	changedList:Hide()

	-- The three columns told apart (the user, 2026-11-25: "no visible division between
	-- panels"): the rail on a darker ground with a line at its right, the settings on
	-- their own panel with a line at their left, a line over the footer.
	-- (Each column a box, as the CQL editor's picker: a dark well inside a gold-tinted edge.
	-- The user, 2026-11-25: "at least CQL has ... borders clearly defined".)
	local function Box(left, top, right, bottom)
		local box = CreateFrame("Frame", nil, win)
		box:SetPoint("TOPLEFT", win, "TOPLEFT", left, top)
		box:SetPoint("BOTTOMRIGHT", win, "BOTTOMLEFT", right, bottom)
		box:SetFrameLevel(math.max(0, win:GetFrameLevel()))
		C.Fill(box, C.Role("well"), 0.55)
		C.Edge(box, C.QUIET, 0.9)
		return box
	end
	Box(6, -36, RAIL - 2, 44)
	Box(W - INSP - 10, -36, W - 6, 44)

	-- Footer.
	local summary = C.Text(win, "GameFontHighlightSmall", C.DIM)
	summary:SetPoint("BOTTOMLEFT", 14, 16)
	summary:SetWidth(420)
	summary:SetWordWrap(false)
	local done = C.Button(win, L["Done"], 70, "action")
	done:SetPoint("BOTTOMRIGHT", -12, 12)
	done:SetScript("OnClick", function() win:Hide() end)
	local resetB = C.Button(win, L["Reset"]):SetArrow()
	resetB:SetPoint("RIGHT", done, "LEFT", -6, 0)
	resetB:SetScript("OnClick", function(self) host:ResetMenu(self) end)
	local pasteB = C.Button(win, L["Paste"])
	pasteB:SetPoint("RIGHT", resetB, "LEFT", -6, 0)
	pasteB:SetScript("OnClick", function() host:Paste() end)
	C.Tip(pasteB, function() return Studio.lookClip and L["Pastes %s here."]:format(Studio.lookClip.from) end)
	local copyB = C.Button(win, L["Copy look"])
	copyB:SetPoint("RIGHT", pasteB, "LEFT", -6, 0)
	copyB:SetScript("OnClick", function() host:CopyLook() end)
	local looksB = C.Button(win, L["Looks"]):SetArrow()
	looksB:SetPoint("RIGHT", copyB, "LEFT", -6, 0)
	looksB:SetScript("OnClick", function(self) host:LooksMenu(self) end)
	C.Tip(looksB, L["Whole looks to start from; Undo puts it back."])
	local toast = C.Text(win, "GameFontNormalSmall")
	toast:SetPoint("BOTTOM", stage, "BOTTOM", 0, 22)
	function host:Toast(text)
		toast:SetText(text)
		toast:Show()
		C_Timer.After(3, function() toast:Hide() end)
	end

	function win.ShowChanged()
		win.changedView = true
		body:Hide()
		changedList:SetParent(insp)
		changedList:Show()
		insp:SetScrollChild(changedList)
		for _, line in ipairs(changedList.lines) do line:Hide() end
		local y, n = 0, 0
		local function Line()
			n = n + 1
			local line = changedList.lines[n]
			if not line then
				line = CreateFrame("Button", nil, changedList)
				line:SetSize(INSP - 14, 18)
				line.text = C.Text(line, "GameFontHighlightSmall")
				line.text:SetPoint("LEFT", 4, 0)
				line.text:SetPoint("RIGHT", -18, 0)
				line.text:SetWordWrap(false)
				line.x = C.Button(line, "x", 16)
				line.x:SetPoint("RIGHT")
				changedList.lines[n] = line
			end
			line:ClearAllPoints()
			line:SetPoint("TOPLEFT", 0, -y)
			line:Show()
			y = y + 19
			return line
		end
		for _, f in ipairs(Studio.Ordered()) do
			local list = Studio.Changed(f)
			if #list > 0 then
				local head = Line()
				head.text:SetText("|cffffd100" .. f.label .. "|r")
				head.x:Hide()
				head:SetScript("OnClick", function() ns.OpenStyleStudio(f.id) end)
				for _, each in ipairs(list) do
					local line = Line()
					local vname = ""
					for _, v in ipairs(f.variants or {}) do if v.id == each.variant and v ~= f.variants[1] then vname = v.label .. " - " end end
					line.text:SetText("   " .. vname .. each.part.label .. " - " .. (each.prop.label or ""))
					line.x:Show()
					line.x:SetScript("OnClick", function() Studio.Reset("prop", f, each.variant, each.part.id, each.prop) win.ShowChanged() end)
					line:SetScript("OnClick", function() ns.OpenStyleStudio(f.id, each.variant, each.part.id) end)
				end
			end
		end
		if n == 0 then
			local line = Line()
			line.text:SetText(L["Nothing changed yet."])
			line.x:Hide()
		end
		changedList:SetHeight(y + 4)
		crumbs:SetText(L["Changed"])
		summary:SetText(L["Everything of yours, by frame. x puts one back."])
		win.Rail()
	end

	function host:Redraw()
		if win.changedView then win.ShowChanged() return end
		local f = self.f
		if not f then return end
		local trail = { L[f.band] or f.band }
		if f.sub then trail[#trail + 1] = L[f.sub] or f.sub end
		trail[#trail + 1] = f.label
		crumbs:SetText(table.concat(trail, " > "))
		-- The stage: this frame's preview, made once, fitted to the room.
		for id, slot in pairs(slots) do slot:SetShown(id == f.id) end
		local slot = slots[f.id]
		if not slot and f.preview then
			slot = CreateFrame("Frame", nil, stage)
			slot:SetAllPoints()
			local ok, preview = pcall(f.preview, slot, 480)
			if ok and preview then
				preview:ClearAllPoints()
				preview:SetPoint("CENTER", slot, "CENTER")
				local pw, ph = preview:GetWidth(), preview:GetHeight()
				local scale = 1
				if pw and pw > 0 then scale = math.min(scale, (stageW - 16) / pw) end
				if ph and ph > 0 then scale = math.min(scale, (STAGE_MAX - 40) / ph) end
				slot.fit = math.max(0.5, scale)
				preview:SetScale(slot.fit * (win.zoomed and 2 or 1))
				slot.preview = preview
				-- (The preview as a card on the stage: its own panel kept, a gold-tinted edge
				-- round it; its "Preview" caption hidden, kept hidden as it draws again.)
				local card = CreateFrame("Frame", nil, slot)
				card:SetPoint("TOPLEFT", preview, "TOPLEFT", -1, 1)
				card:SetPoint("BOTTOMRIGHT", preview, "BOTTOMRIGHT", 1, -1)
				card:SetFrameLevel(preview:GetFrameLevel() + 20)
				C.Edge(card, { 0.42, 0.38, 0.32 }, 1) -- (a little lighter than the stage's: the card stands out)
				local function Bare()
					for _, region in ipairs({ preview:GetRegions() }) do
						if region.GetText and region:GetText() == L["Preview"] then region:Hide() end
					end
				end
				Bare()
				if type(preview.Refresh) == "function" then hooksecurefunc(preview, "Refresh", Bare) end
			elseif not ok then
				ns.Guard(error, preview)
			end
			slots[f.id] = slot
		end
		self.preview = slot and slot.preview
		hint:SetShown(self.preview ~= nil)
		empty:SetShown(self.preview == nil)
		empty.title:SetText(f.label)
		win.Mine(f)
		testB:SetShown(f.test ~= nil)
		-- (Looks only where the frame has looks of its own: "Theme's" alone is Reset's job.)
		looksB:SetShown(#(f.looks or {}) > 0)
		body:Draw(f, self.variant, self.partId)
		self.partId = body.part and body.part.id
		if self.preview then Studio.Hotspots(self, self.preview) end
		self:ShowStage()
		undoB:SetEnabled(Studio.CanUndo() ~= nil)
		redoB:SetEnabled(Studio.CanRedo() ~= nil)
		pasteB:SetShown(self:CanPaste())
		local n = Studio.CountNow(f)
		summary:SetText(n == 1 and L["1 change on %s"]:format(f.label)
			or n > 1 and L["%d changes on %s"]:format(n, f.label) or "")
		win.Rail()
	end
	win:SetScript("OnHide", function() C.CloseList() win:SetAlpha(1) end)
	-- (Counted again as it opens: a setting changed on its page meanwhile shows.)
	win:HookScript("OnShow", function() Studio.ForgetCounts() end)
	-- (Its buttons by name, for the tests that click each: Dev/StyleStudioTest.lua.)
	win.buttons = { looks = looksB, reset = resetB, copy = copyB, paste = pasteB, done = done, undo = undoB,
		redo = redoB, pop = popB, zoom = zoomB, compare = compareB, peek = peekB, test = testB, page = pageB }
	win.find, win.railItems, win.slots, win.mine, win.insp = find, railItems, slots, mine, insp
	return win
end

-- Opens the Studio on a frame (its first variant, first part unless given); label:
-- a setting's name to Find (Show on other frames).
function ns.OpenStyleStudio(frameId, variant, partId, findText)
	if not studio then
		BuildStudio()
		-- (The settings pages are made on first open (Tools/lazy-pages-plan.md), and some
		-- frames read names from theirs (Nameplates' Smart rows: "Not your kill", not
		-- "tapped", run qd398): the waiting ones made now, a few ms a frame, then drawn again.)
		if ns.MakeLazyPagesSoon then
			ns.MakeLazyPagesSoon("style studio", nil, function()
				if studio:IsShown() then studio.host:Redraw() end
			end)
		end
	end
	local f = Studio.frames[frameId] or Studio.Ordered()[1]
	if not f then return end
	local host = studio.host
	local changing = host.f ~= f
	host.f = f
	studio.changedView = nil
	-- (The variant it opens on, settled before anything draws: a frame never sees the
	-- last frame's variant, false from a frame without any; in-game run qe98e.)
	if variant ~= nil then host.variant = variant elseif changing then host.variant = Studio.FirstVariant(f) end
	studio.body:Draw(f, host.variant, partId) -- (first layout before the scroll child swaps back)
	-- (Its scroll frame by name: after the Changed view swapped the scroll child, the body
	-- has no parent in the game (it kept one offline), run qd0c6.)
	studio.body:SetParent(studio.insp)
	studio.insp:SetScrollChild(studio.body)
	studio.body:Show()
	if changing then host.partId = nil host:Snapshot() end
	if partId then host.partId = partId end
	studio:Show()
	host:Redraw()
	if findText then
		local hits = Studio.Find(findText, 40)
		local opts = {}
		for i, hit in ipairs(hits) do opts[i] = { i, ("%s  |cff888888%s - %s|r"):format(hit.prop.label, hit.part.label, hit.f.label) } end
		C.OpenList(studio.body, opts, nil, function(i)
			local hit = hits[i]
			if hit then ns.OpenStyleStudio(hit.f.id, nil, hit.part.id) C_Timer.After(0, function() studio.body:Flash(hit.prop) end) end
		end)
	end
	return studio
end
function ns.StyleStudioWindow() return studio end
end) -- (ns.Module "style")
