-- The dev copy's Control Gallery page (the Dev hub): one of every kind of
-- control the settings pages use that can be built on its own, each made by
-- its own real builder, side by side, so they can be compared by eye and a
-- change to one seen at once (the user, 2026-11-27: "normalize menu controls
-- to create a uniform look ... I need a way to see these choices"). The full
-- list, with the ones only a page can build, is Tools/ui/control-map.md; the
-- ids here (B1, D3...) are its ids. Each row: id and name, the builder, its
-- uses, and the control itself, working on values of this page's own
-- (nothing saved, no setting changed). A pick shows on the line under the
-- title. Each row is made in a pcall: a builder that fails says so on its
-- row and the rest still show. /cine debug controllooks (ControlLooksTest.lua)
-- shoots this page and its menus in both menu looks. Only in CinematicDev.toc.
local _, ns = ...

local LABEL_W, ROW_GAP, CONTROL_X = 300, 14, 320
local GREY = "|cff888888"

-- This page's own values: { get, set } fields, so no setting is touched.
local values = { game = 3, own = { [1] = true, [3] = true }, raw = 2, studio = 5, radio = "small", pick = "small",
	segments = "small", tiles = "b", check = true, switch = true, pill = true, slider = 40, studioSlider = 60,
	box = 12, tab = 1 }
local function Field(name)
	return { noSettingId = true, get = function() return values[name] end, set = function(v) values[name] = v end }
end

local LONG = {} -- (18: longer than a menu's 15 rows, so the long-list scroll shows)
for i = 1, 18 do LONG[i] = { value = i, text = "Choice " .. i } end
local SHORT = { { "off", "Off" }, { "small", "Small" }, { "big", "Big" } }

local function TextOf(list, value)
	for _, o in ipairs(list) do
		if (o.value or o[1]) == value then return o.text or o[2] end
	end
	return tostring(value)
end

-- Every row: { id, section, name, builder, uses, make(spot, Picked, kit, C) -> control or nil, why }.
-- (make places the control at spot's TOPLEFT; Studio rows (studio = true) wait for the Style part.)
local ROWS = {}
local function Add(row) ROWS[#ROWS + 1] = row end

-- The menus a test can open: { label, open(), close() } (ControlLooksTest.lua).
local menus = {}
local function CloseMenus()
	local manager = Menu and Menu.GetManager and Menu.GetManager()
	if manager and manager.CloseMenus then pcall(manager.CloseMenus, manager) end
	local C = ns.Studio and ns.Studio.C
	if C and C.CloseList then C.CloseList() end
end
local function AddMenu(label, open)
	menus[#menus + 1] = { label = label, open = open, close = CloseMenus }
end

------------------------------------------------------------------- Buttons
Add({ id = "B1", section = "Buttons", name = "Panel button", builder = "ns.PanelButton, Skin.lua", uses = "~164",
	make = function(spot)
		local b = ns.PanelButton(spot:GetParent())
		b:SetSize(120, 22)
		b:SetText("Panel button")
		return b
	end })
Add({ id = "B2", section = "Buttons", name = "Game button, not skinned", builder = "UIPanelButtonTemplate alone",
	uses = "4", make = function(spot)
		local b = CreateFrame("Button", nil, spot:GetParent(), "UIPanelButtonTemplate")
		b:SetSize(120, 22)
		b:SetText("Unskinned")
		return b
	end })
Add({ id = "B3", section = "Buttons", name = "Studio button", builder = "Studio.C.Button, Studio/Controls.lua",
	uses = "19", studio = true, make = function(spot, _, _, C)
		local row = CreateFrame("Frame", nil, spot:GetParent())
		row:SetSize(300, 20)
		local plain = C.Button(row, "Plain", 70)
		plain:SetPoint("LEFT")
		local on = C.Button(row, "On", 70)
		on:SetPoint("LEFT", plain, "RIGHT", 6, 0)
		on:Paint("on")
		local action = C.Button(row, "Action", 70, "action")
		action:SetPoint("LEFT", on, "RIGHT", 6, 0)
		return row
	end })
Add({ id = "B4", section = "Buttons", name = "Studio tool button (with arrow)", builder = "Studio.C.PanelTool",
	uses = "Studio bars", studio = true, make = function(spot, _, _, C)
		return C.PanelTool(spot:GetParent(), "Reset", true)
	end })
Add({ id = "B5", section = "Buttons", name = "Welcome flat buttons (main, box, text)",
	builder = "ns.FlatStyle.Button, Profiles/Welcome.lua", uses = "~20", make = function(spot)
		local S = ns.FlatStyle
		if not (S and S.Button) then return nil, "ns.FlatStyle isn't loaded" end
		local row = CreateFrame("Frame", nil, spot:GetParent())
		row:SetSize(320, 30)
		local main = S.Button(row, "Main", "main", function() end)
		main:SetPoint("LEFT")
		local box = S.Button(row, "Box", "box", function() end)
		box:SetPoint("LEFT", main, "RIGHT", 6, 0)
		local text = S.Button(row, "Text link", nil, function() end)
		text:SetPoint("LEFT", box, "RIGHT", 6, 0)
		return row
	end })
Add({ id = "B6", section = "Buttons", name = "Close buttons (skinned, game's)", builder = "ns.SkinClose / UIPanelCloseButton",
	uses = "~29", make = function(spot)
		local row = CreateFrame("Frame", nil, spot:GetParent())
		row:SetSize(80, 24)
		local skinned = ns.SkinClose(CreateFrame("Button", nil, row, "UIPanelCloseButton"))
		skinned:SetPoint("LEFT")
		local raw = CreateFrame("Button", nil, row, "UIPanelCloseButton")
		raw:SetPoint("LEFT", skinned, "RIGHT", 12, 0)
		return row
	end })
Add({ id = "B7", section = "Buttons", name = "Keybind button", builder = "CreateKeybindButton = PanelButton 140x22",
	uses = "Keybinds", make = function(spot)
		local b = ns.PanelButton(spot:GetParent())
		b:SetSize(140, 22)
		b:SetText("CTRL-K") -- (its look only: the real one listens for a key)
		return b
	end })
Add({ id = "B8", section = "Buttons", name = "Style icon buttons", builder = "ns.StyleIconButton, StylePages.lua",
	uses = "8", make = function(spot)
		if not ns.StyleIconButton then return nil, "Style isn't loaded" end
		local row = CreateFrame("Frame", nil, spot:GetParent())
		row:SetSize(140, 22)
		local last
		for _, icon in ipairs({ "pop", "dock", "scene", "close" }) do
			local b = ns.StyleIconButton(row, icon, icon)
			if last then b:SetPoint("LEFT", last, "RIGHT", 4, 0) else b:SetPoint("LEFT") end
			last = b
		end
		return row
	end })

------------------------------------------------------------------- On / off
Add({ id = "T1", section = "On / off", name = "Checkbox", builder = "kit.Check (UICheckButtonTemplate + SkinCheck)",
	uses = "~266", make = function(spot, Picked, kit)
		local check = kit.Check(spot:GetParent(), Field("check"), "Something on", nil, function(v)
			values.check = v
			Picked("T1", v and "on" or "off")
		end)
		check:Refresh()
		return check, nil, -4, 2
	end })
Add({ id = "T2", section = "On / off", name = "Header switch (pill)", builder = "ns.MakeSwitchLook, Options.lua",
	uses = "every page switch", make = function(spot, Picked)
		local b = CreateFrame("Button", nil, spot:GetParent())
		ns.MakeSwitchLook(b)
		ns.PaintSwitchLook(b, values.pill)
		b:SetScript("OnClick", function(self)
			values.pill = not values.pill
			ns.PaintSwitchLook(self, values.pill)
			Picked("T2", values.pill and "on" or "off")
		end)
		return b
	end })
Add({ id = "T3", section = "On / off", name = "Studio switch (flat tick)", builder = "Studio.C.Switch (copy of rows.Toggle)",
	uses = "Studio rows", studio = true, make = function(spot, Picked, _, C)
		local switch
		switch = C.Switch(spot:GetParent(), function(v)
			values.switch = v
			switch:SetValue(v)
			Picked("T3", v and "on" or "off")
		end)
		switch:SetValue(values.switch)
		return switch
	end })

------------------------------------------------------------------ Dropdowns
Add({ id = "D1", section = "Dropdowns and menus", name = "Game dropdown, skinned (radio list)",
	builder = "kit.Dropdown / rows.Dropdown", uses = "~59", make = function(spot, Picked, kit)
		local drop = kit.Dropdown(spot:GetParent(), Field("game"), LONG, 200,
			function(v) Picked("D1", TextOf(LONG, v)) end)
		if not drop then return nil, "No dropdown template on this client." end
		AddMenu("D1 game dropdown", function() if drop.OpenMenu then drop:OpenMenu() end end)
		return drop
	end })
Add({ id = "D2", section = "Dropdowns and menus", name = "Game dropdown, its own menu (titles, ticks)",
	builder = "ns.MenuDropdown + SetupMenu", uses = "~26", make = function(spot, Picked)
		local ok, drop = ns.MenuDropdown(spot:GetParent())
		if not (ok and drop and drop.SetupMenu) then return nil, "No dropdown template on this client." end
		drop:SetWidth(170)
		drop:SetupMenu(function(_, root)
			for i = 1, 6 do
				if i == 1 or i == 4 then ns.MenuTitle(root, i == 1 and "First group" or "Second group") end
				root:CreateCheckbox("Tick " .. i, function() return values.own[i] or false end, function()
					values.own[i] = not values.own[i] or nil
					Picked("D2", "Tick " .. i .. (values.own[i] and " on" or " off"))
					return MenuResponse and MenuResponse.Refresh
				end)
			end
		end)
		AddMenu("D2 own-menu dropdown", function() if drop.OpenMenu then drop:OpenMenu() end end)
		return drop
	end })
Add({ id = "D3", section = "Dropdowns and menus", name = "Game dropdown, not skinned",
	builder = "CreateFrame(\"DropdownButton\") directly", uses = "1 (Chat Copy)", make = function(spot, Picked)
		local ok, drop = pcall(CreateFrame, "DropdownButton", nil, spot:GetParent(), "WowStyle1DropdownTemplate")
		if not (ok and drop and drop.SetupMenu) then return nil, "No dropdown template on this client." end
		drop:SetWidth(200)
		drop:SetupMenu(function(_, root)
			for _, o in ipairs(LONG) do
				root:CreateRadio(o.text, function() return values.raw == o.value end, function()
					values.raw = o.value
					Picked("D3", o.text)
				end)
			end
		end)
		AddMenu("D3 unskinned dropdown", function() if drop.OpenMenu then drop:OpenMenu() end end)
		return drop
	end })
Add({ id = "D4", section = "Dropdowns and menus", name = "Studio dropdown (own list, Find box)",
	builder = "Studio.C.Drop <- R.Drop", uses = "~13", studio = true, make = function(spot, Picked, _, C)
		local drop
		drop = C.Drop(spot:GetParent(), 200, LONG, function(v)
			values.studio = v
			drop:SetValue(v)
			Picked("D4", TextOf(LONG, v))
		end)
		drop:SetValue(values.studio)
		AddMenu("D4 Studio dropdown", function() drop:Click() end)
		return drop
	end })
Add({ id = "D5", section = "Dropdowns and menus", name = "Grid cell button + tick menu",
	builder = "ns.GridMenuButton + ns.TickMenu", uses = "every grid row", make = function(spot, Picked)
		if not ns.GridMenuButton then return nil, "ns.GridMenuButton isn't loaded." end
		local button = ns.GridMenuButton(spot:GetParent(), 140)
		local function Words()
			local n = 0
			for i = 1, 6 do if values.own[i] then n = n + 1 end end
			button:SetText(n == 0 and "-" or n .. " ticked")
		end
		Words()
		button:SetScript("OnClick", function(self)
			local entries = {}
			for i = 1, 6 do
				entries[i] = { "Tick " .. i, function() return values.own[i] or false end, function()
					values.own[i] = not values.own[i] or nil
					Picked("D5", "Tick " .. i .. (values.own[i] and " on" or " off"))
				end }
			end
			ns.TickMenu(self, entries, Words)
		end)
		AddMenu("D5 grid tick menu", function() button:Click() end)
		return button
	end })
Add({ id = "D6", section = "Dropdowns and menus", name = "Right-click menu", builder = "ns.ContextMenu",
	uses = "15", make = function(spot, Picked)
		local button = ns.PanelButton(spot:GetParent())
		button:SetSize(140, 22)
		button:SetText("Right-click me")
		button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		local function Open(self)
			if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
			ns.ContextMenu(self, function(_, root)
				ns.MenuTitle(root, "A title")
				for _, o in ipairs(SHORT) do
					root:CreateRadio(o[2], function() return values.radio == o[1] end, function()
						values.radio = o[1]
						Picked("D6", o[2])
					end)
				end
				ns.MenuDivider(root)
				root:CreateButton("An action", function() Picked("D6", "An action") end)
			end)
		end
		button:SetScript("OnClick", Open)
		AddMenu("D6 right-click menu", function() Open(button) end)
		return button
	end })

---------------------------------------------------------------- Few choices
Add({ id = "C1", section = "A few choices", name = "Radio as checkboxes", builder = "kit.Choice <- *.Choices",
	uses = "~65", make = function(spot, Picked, kit)
		local row = CreateFrame("Frame", nil, spot:GetParent())
		row:SetSize(300, 24)
		local last
		for _, o in ipairs(SHORT) do
			local choice = kit.Choice(row, Field("radio"), o[1], o[2])
			choice:HookScript("OnClick", function() Picked("C1", o[2]) end)
			if last then choice:SetPoint("LEFT", last.Text or last.text or last, "RIGHT", 16, 0)
			else choice:SetPoint("LEFT") end
			choice:Refresh()
			last = choice
		end
		return row
	end })
Add({ id = "C2", section = "A few choices", name = "Round radio", builder = "BoxLine line.Pick (UIRadioButtonTemplate)",
	uses = "~38", make = function(spot, Picked, kit)
		local line = kit.BoxLine(spot:GetParent())
		for _, o in ipairs(SHORT) do
			line:Pick(o[2], Field("pick"), o[1], nil, function() Picked("C2", o[2]) end)
		end
		return line
	end })
Add({ id = "C3", section = "A few choices", name = "Studio segments", builder = "Studio.C.Segments <- R.Choice",
	uses = "~87", studio = true, make = function(spot, Picked, _, C)
		local options = {}
		for i, o in ipairs(SHORT) do options[i] = { value = o[1], text = o[2] } end
		local seg
		seg = C.Segments(spot:GetParent(), options, function(v)
			values.segments = v
			seg:SetValue(v)
			Picked("C3", TextOf(SHORT, v))
		end)
		seg:SetValue(values.segments)
		return seg
	end })
Add({ id = "C4", section = "A few choices", name = "Studio tiles (fonts)", builder = "Studio.C.Tiles",
	uses = "Studio looks", studio = true, make = function(spot, Picked, _, C)
		local options = { { value = "a", text = "Friz", font = "Fonts\\FRIZQT__.TTF" },
			{ value = "b", text = "Arial", font = "Fonts\\ARIALN.TTF" },
			{ value = "c", text = "Morpheus", font = "Fonts\\MORPHEUS.TTF" },
			{ value = "d", text = "Skurri", font = "Fonts\\SKURRI.TTF" } }
		local tiles
		tiles = C.Tiles(spot:GetParent(), options, function(v)
			values.tiles = v
			tiles:SetValue(v)
			Picked("C4", TextOf(options, v))
		end, nil, 3, 360)
		tiles:SetValue(values.tiles)
		return tiles
	end })

-------------------------------------------------------------------- Amounts
Add({ id = "A1", section = "Amounts", name = "Slider", builder = "kit.Slider (OptionsSliderTemplate + SkinSlider)",
	uses = "~227", make = function(spot, Picked, kit)
		local slider = kit.Slider(spot:GetParent(), Field("slider"), "Amount", 0, 100, 5, "%d%%", nil,
			function(v) Picked("A1", v) end)
		return slider, nil, 0, -14
	end })
Add({ id = "A2", section = "Amounts", name = "Studio slider (value box)", builder = "Studio.C.Slider",
	uses = "Studio rows", studio = true, make = function(spot, Picked, _, C)
		local box
		box = C.Slider(spot:GetParent(), 260, { min = 0, max = 100, step = 1, unit = "%" }, function(v)
			values.studioSlider = v
			box:SetValue(v, 50)
			Picked("A2", v)
		end)
		box:SetValue(values.studioSlider, 50)
		return box
	end })
Add({ id = "A3", section = "Amounts", name = "Number box", builder = "BoxLine line.Box (InputBox + SkinEditBox)",
	uses = "~54", make = function(spot, Picked, kit)
		local line = kit.BoxLine(spot:GetParent())
		line:Box("Size", Field("box"), 1, 40, 1, "%d", nil, nil, function(v) Picked("A3", v) end, nil, "px")
		return line
	end })

----------------------------------------------------------------- Typing
Add({ id = "E1", section = "Typing", name = "Text box, skinned", builder = "ns.SkinEditBox(InputBoxTemplate)",
	uses = "~37", make = function(spot)
		local box = ns.SkinEditBox(CreateFrame("EditBox", nil, spot:GetParent(), "InputBoxTemplate"))
		box:SetSize(200, 20)
		box:SetAutoFocus(false)
		box:SetText("Some words")
		return box, nil, 6, 0
	end })
Add({ id = "E2", section = "Typing", name = "Text box, not skinned", builder = "InputBoxTemplate alone",
	uses = "Emote picker", make = function(spot)
		local box = CreateFrame("EditBox", nil, spot:GetParent(), "InputBoxTemplate")
		box:SetSize(200, 20)
		box:SetAutoFocus(false)
		box:SetText("Some words")
		return box, nil, 6, 0
	end })
Add({ id = "E3", section = "Typing", name = "Search box (game's)", builder = "SearchBoxTemplate, not skinned",
	uses = "~8", make = function(spot)
		local ok, box = pcall(CreateFrame, "EditBox", nil, spot:GetParent(), "SearchBoxTemplate")
		if not ok then return nil, "No SearchBoxTemplate here." end
		box:SetSize(200, 20)
		box:SetAutoFocus(false)
		return box, nil, 6, 0
	end })

--------------------------------------------------------------------- Color
Add({ id = "K1", section = "Color", name = "Palette chips", builder = "ns.ColorPalette.Chip", uses = "2",
	make = function(spot, Picked)
		local palette = ns.ColorPalette
		if not (palette and palette.Chip) then return nil, "Style isn't loaded" end
		local row = CreateFrame("Frame", nil, spot:GetParent())
		row:SetSize(140, 22)
		local last
		for _, c in ipairs({ { 1, 0.82, 0 }, { 0.4, 0.7, 1 }, { 0.9, 0.3, 0.3 } }) do
			local chip = palette.Chip(row, 22, function() end, function() Picked("K1", "a color") end)
			if chip.swatch then chip.swatch:SetColorTexture(c[1], c[2], c[3], 1) end
			if last then chip:SetPoint("LEFT", last, "RIGHT", 4, 0) else chip:SetPoint("LEFT") end
			last = chip
		end
		return row
	end })

---------------------------------------------------------------------- Tabs
Add({ id = "N1", section = "Tabs", name = "Folder tabs", builder = "ns.FolderTabs, Options.lua", uses = "~20",
	make = function(spot, Picked)
		local list = { { "First" }, { "Second" }, { "Third" } }
		local panel, _, Show, _, height = ns.FolderTabs(spot:GetParent(), list, function(i)
			values.tab = i
			Picked("N1", list[i][1])
		end, nil, 360)
		panel:SetSize(360, 30)
		if Show then Show(values.tab) end
		return panel, nil, 0, -(height or 24)
	end })

-- The rows' notes for what only a page can build (the map's other ids).
local ELSEWHERE = {
	"Only on their pages (see Tools/ui/control-map.md):",
	"Style page segments, tiles, flat tick, flat slider, swatch (Style > any Look panel)",
	"Combat Text segments (Style > Combat Text), CineMode page segments and pills (CineMode)",
	"Cooldown Manager pills and tabs, Why window tabs and chips, Rule editor chips",
	"Welcome cards and switch, Profiles cards, hub icon tiles, list rows of each page",
}

function ns.CreateControlGalleryPage(kit)
	local canvas, content = kit.CreateScrollPage(true)
	local title = kit.Label(content, "GameFontNormalLarge", "Control Gallery")
	title:SetPoint("TOPLEFT", 16, -16)
	local intro = kit.PageIntro(content, title, "One of every control the settings pages use that can be made on "
		.. "its own, each by its real builder. Ids match Tools/ui/control-map.md. Picks change only this page's own "
		.. "values: nothing is saved. Switch the menu look (Style, General) to see each in both looks.")
	local picked = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	picked:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -8)
	picked:SetText(GREY .. "Pick something: it shows here.")
	local byId = {}
	for _, row in ipairs(ROWS) do byId[row.id] = row end
	local function Picked(id, text)
		picked:SetText(("Picked |cffffd100%s|r in %s %s"):format(tostring(text), id, byId[id] and byId[id].name or ""))
	end

	local below, section = picked, nil
	local function Section(text)
		local head = kit.Label(content, "GameFontNormal", text)
		head:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -22)
		local line = content:CreateTexture(nil, "ARTWORK")
		line:SetColorTexture(1, 0.82, 0, 0.3)
		line:SetHeight(1)
		line:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -3)
		line:SetPoint("RIGHT", content, "RIGHT", -16, 0)
		below = line
	end
	local made = {}
	local function MakeRow(row)
		local frame = CreateFrame("Frame", nil, content)
		frame:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -ROW_GAP)
		frame:SetPoint("RIGHT", content, "RIGHT", -16, 0)
		local name = kit.Label(frame, "GameFontHighlight", "|cffffd100" .. row.id .. "|r  " .. row.name)
		name:SetPoint("TOPLEFT")
		name:SetWidth(LABEL_W)
		local how = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		how:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
		how:SetWidth(LABEL_W)
		how:SetJustifyH("LEFT")
		how:SetText(row.builder .. "\n" .. row.uses .. " uses")
		frame:SetHeight(math.max(34, name:GetStringHeight() + how:GetStringHeight() + 4))
		local spot = CreateFrame("Frame", nil, frame)
		spot:SetSize(1, 1)
		spot:SetPoint("TOPLEFT", CONTROL_X, 0)
		local note = frame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
		note:SetPoint("TOPLEFT", spot, "TOPLEFT", 0, -2)
		note:SetJustifyH("LEFT")
		row.frame, row.spot, row.note = frame, spot, note
		made[#made + 1] = row
		below = frame
	end
	for _, row in ipairs(ROWS) do
		if row.section ~= section then
			section = row.section
			Section(section)
		end
		MakeRow(row)
	end
	Section("Not here")
	local rest = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	rest:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -10)
	rest:SetJustifyH("LEFT")
	rest:SetText(table.concat(ELSEWHERE, "\n"))

	-- Each row's control, made on first show (the Studio's are made with the
	-- Style part, which may load after this page). Each in a pcall.
	local function Fill()
		local C = ns.Studio and ns.Studio.C
		for _, row in ipairs(made) do
			if not row.control and not row.failed and (not row.studio or C) then
				local ok, control, why, dx, dy = pcall(row.make, row.spot, Picked, kit, C)
				if ok and control then
					row.control = control
					control:ClearAllPoints()
					-- (Made on the row's frame or on content: placed at its spot either way.)
					if control:GetParent() == content then control:SetParent(row.frame) end
					control:SetPoint("TOPLEFT", row.spot, "TOPLEFT", dx or 0, dy or 0)
					control:Show()
					row.note:SetText("")
				else
					row.failed = true
					row.error = ok and (why or "made nothing") or tostring(control)
					row.note:SetText("|cffff6060" .. row.error .. "|r")
				end
			elseif row.studio and not C then
				row.note:SetText("The Style part isn't loaded: no Studio controls.")
			end
		end
	end

	-- (ControlLooksTest.lua: the page, its scroll, its rows and its menus.)
	ns.controlGallery = { canvas = canvas, content = content, rows = made, menus = menus, Fill = Fill,
		scroll = content:GetParent(), CloseMenus = CloseMenus }

	canvas:SetScript("OnShow", kit.PageShown(function()
		Fill()
		kit.FitContentHeight(content)
	end, content))
	canvas:Hide()
	kit.RegisterSubpage(canvas, "Control Gallery", "Control Gallery")
end
