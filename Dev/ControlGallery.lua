-- The dev copy's Control Gallery page (the Dev hub): one of every kind of
-- choice control the settings pages use, each built by its own real builder,
-- side by side, so they can be compared by eye and a change to one seen at
-- once (the user, 2026-11-27: "normalize menu controls to create a uniform
-- look ... I need a way to see these choices"). Each row: the kind, the
-- builder that makes it, how many places use it (grep counts, 2026-11-27),
-- and the control itself, working on values of this page's own (nothing
-- saved, no setting changed). A pick shows on the line under the title.
-- Only in CinematicDev.toc.
local _, ns = ...

local LABEL_W, ROW_GAP, CONTROL_X = 300, 14, 320
local GREY = "|cff888888"

-- This page's own values: { get, set } fields, so no setting is touched.
local values = { game = 3, own = { [1] = true, [3] = true }, raw = 2, studio = 5, radio = "small",
	segments = "small", check = true, switch = true }

local LONG = {} -- (18: longer than a menu's 15 rows, so the long-list scroll shows)
for i = 1, 18 do LONG[i] = { value = i, text = "Choice " .. i } end
local SHORT = { { "off", "Off" }, { "small", "Small" }, { "big", "Big" } }

local function TextOf(list, value)
	for _, o in ipairs(list) do
		if (o.value or o[1]) == value then return o.text or o[2] end
	end
	return tostring(value)
end

-- What each kind is, as the rows list them: { title, builder, uses, where }.
local KINDS = {
	game = { "Game dropdown, skinned (radio list)", "kit.Dropdown / Dropdown() / rows.Dropdown, Options.lua",
		"~59", "CardsPage, StylePages, FrameLinks, KeyboardMap, Raid/Unit Style, Profiler..." },
	own = { "Game dropdown, its own menu (titles, ticks)", "ns.MenuDropdown + SetupMenu, Skin.lua", "~26",
		"Options (15), TintStyle, StyleThemes, GameSettings, Camera pages, PlateRowLook, PlateThemes" },
	raw = { "Game dropdown, not skinned", "CreateFrame(\"DropdownButton\") directly", "1",
		"UI/ChatCopy.lua (no HD skin, no long-list scroll)" },
	studio = { "Studio dropdown (own list, Find box)", "Studio.C.Drop <- R.Drop, Style/Studio/Controls.lua", "~13",
		"Style Studio frames: Visions, Nameplates, GeneralBand..." },
	grid = { "Grid cell button + tick menu", "ns.GridMenuButton + ns.TickMenu, UI/GridRows.lua", "every grid row",
		"Options (11 grids), CooldownGrid, CardsPage, EmoteVision" },
	radio = { "Radio buttons", "kit.Choice <- rows.Choices / look.Choices / b.Choices", "~65",
		"Style pages, DamageVision, CooldownGrid, CameraScriptsPage" },
	segments = { "Studio Segments", "Studio.C.Segments <- R.Choice", "~87", "Style Studio frames" },
	styleSeg = { "Style page Segments (gold underline)", "rows.Segments, StylePages.lua (a builder's local)", "~18",
		"Not buildable here: see Style > Combat > Combat Text, Look" },
	check = { "Checkbox", "kit.Check, Options.lua", "most on/off settings", "every page" },
	switch = { "Studio Switch", "Studio.C.Switch <- R.Switch", "Studio rows", "Style Studio frames" },
	context = { "Right-click menu", "ns.ContextMenu, Skin.lua", "15", "Favorites, RuleEditor, CameraManager, Minimap..." },
}

function ns.CreateControlGalleryPage(kit)
	local canvas, content = kit.CreateScrollPage(true)
	local title = kit.Label(content, "GameFontNormalLarge", "Control Gallery")
	title:SetPoint("TOPLEFT", 16, -16)
	local intro = kit.PageIntro(content, title, "One of every kind of choice control the settings pages use, each "
		.. "made by its real builder. Picks change only this page's own values: nothing is saved. Switch the menu "
		.. "look (Style, General) to see each in both looks.")
	local picked = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	picked:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -8)
	picked:SetText(GREY .. "Pick something: it shows here.")
	local function Picked(kind, text)
		picked:SetText(("Picked %s|r in %s"):format("|cffffd100" .. tostring(text), KINDS[kind][1]))
	end

	local below = picked
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
	-- A row: the kind's name and builder at the left, its control at CONTROL_X.
	-- Gives the row's frame (the control's anchor) and its note (for "not here" text).
	local function Row(kind)
		local info = KINDS[kind]
		local row = CreateFrame("Frame", nil, content)
		row:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -ROW_GAP)
		row:SetPoint("RIGHT", content, "RIGHT", -16, 0)
		local name = kit.Label(row, "GameFontHighlight", info[1])
		name:SetPoint("TOPLEFT")
		name:SetWidth(LABEL_W)
		local how = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		how:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
		how:SetWidth(LABEL_W)
		how:SetJustifyH("LEFT")
		how:SetText(info[2] .. "\n" .. info[3] .. " uses: " .. info[4])
		row:SetHeight(name:GetStringHeight() + how:GetStringHeight() + 4)
		local spot = CreateFrame("Frame", nil, row)
		spot:SetSize(1, 1)
		spot:SetPoint("TOPLEFT", CONTROL_X, 0)
		below = row
		return spot, row
	end
	local function Note(spot, text)
		local note = spot:GetParent():CreateFontString(nil, "ARTWORK", "GameFontDisable")
		note:SetPoint("TOPLEFT", spot, "TOPLEFT", 0, -2)
		note:SetText(text)
		return note
	end

	------------------------------------------------------------------ Dropdowns
	Section("Dropdowns (a long list)")

	do -- kit.Dropdown: the game's dropdown, skinned, one radio per choice
		local spot = Row("game")
		local drop = kit.Dropdown(content, { noSettingId = true, get = function() return values.game end,
			set = function(v) values.game = v end }, LONG, 200, function(v) Picked("game", TextOf(LONG, v)) end)
		if drop then drop:SetPoint("TOPLEFT", spot, "TOPLEFT", 0, 0) else Note(spot, "No dropdown template on this client.") end
	end

	do -- ns.MenuDropdown with a menu of its own: titles and ticks (as Plate State's)
		local spot = Row("own")
		local ok, drop = ns.MenuDropdown(content)
		if ok and drop and drop.SetupMenu then
			drop:SetWidth(170)
			drop:SetPoint("TOPLEFT", spot, "TOPLEFT", 0, 0)
			drop:SetupMenu(function(_, root)
				for i = 1, 6 do
					if i == 1 or i == 4 then ns.MenuTitle(root, i == 1 and "First group" or "Second group") end
					root:CreateCheckbox("Tick " .. i, function() return values.own[i] or false end, function()
						values.own[i] = not values.own[i] or nil
						Picked("own", "Tick " .. i .. (values.own[i] and " on" or " off"))
						return MenuResponse and MenuResponse.Refresh
					end)
				end
			end)
		else
			Note(spot, "No dropdown template on this client.")
		end
	end

	do -- the raw template, as ChatCopy makes it: no skin, no scroll
		local spot = Row("raw")
		local ok, drop = pcall(CreateFrame, "DropdownButton", nil, content, "WowStyle1DropdownTemplate")
		if ok and drop and drop.SetupMenu then
			drop:SetWidth(200)
			drop:SetPoint("TOPLEFT", spot, "TOPLEFT", 0, 0)
			drop:SetupMenu(function(_, root)
				for _, o in ipairs(LONG) do
					root:CreateRadio(o.text, function() return values.raw == o.value end, function()
						values.raw = o.value
						Picked("raw", o.text)
					end)
				end
			end)
		else
			Note(spot, "No dropdown template on this client.")
		end
	end

	-- (The Studio's controls are made with the Style part, which may load after
	-- this page: made on first show, as is the grid cell's menu.)
	local studioSpots = {}
	studioSpots.studio = Row("studio")

	do -- a grid cell: a PanelButton with an arrow, opening a menu of ticks
		local spot = Row("grid")
		local button = ns.GridMenuButton and ns.GridMenuButton(content, 140)
		if button then
			button:SetPoint("TOPLEFT", spot, "TOPLEFT", 0, 0)
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
						Picked("grid", "Tick " .. i .. (values.own[i] and " on" or " off"))
					end }
				end
				ns.TickMenu(self, entries, Words)
			end)
		else
			Note(spot, "ns.GridMenuButton isn't loaded.")
		end
	end

	---------------------------------------------------------------- Few choices
	Section("A few choices (2-5 words)")

	do -- kit.Choice: radio boxes, one per choice, sharing one value
		local spot = Row("radio")
		local key = { noSettingId = true, get = function() return values.radio end, set = function(v) values.radio = v end }
		local last
		for _, o in ipairs(SHORT) do
			local choice = kit.Choice(content, key, o[1], o[2])
			choice:HookScript("OnClick", function() Picked("radio", o[2]) end)
			if last then
				choice:SetPoint("LEFT", last.Text or last.text or last, "RIGHT", 16, 0)
			else
				choice:SetPoint("TOPLEFT", spot, "TOPLEFT", 0, 2)
			end
			choice:Refresh()
			last = choice
		end
	end

	studioSpots.segments = Row("segments")
	Note(Row("styleSeg"), "(Inside a Style page only)")

	------------------------------------------------------------------ On / off
	Section("On / off")

	do
		local spot = Row("check")
		local check = kit.Check(content, { noSettingId = true, get = function() return values.check end,
			set = function(v) values.check = v end }, "Something on", nil, function(v)
			values.check = v
			Picked("check", v and "on" or "off")
		end)
		check:SetPoint("TOPLEFT", spot, "TOPLEFT", -4, 2)
		check:Refresh()
	end

	studioSpots.switch = Row("switch")

	--------------------------------------------------------------------- Menus
	Section("Menus")

	do -- ns.ContextMenu: a title, radios, a divider, a button
		local spot = Row("context")
		local button = ns.PanelButton(content)
		button:SetSize(140, 22)
		button:SetText("Right-click me")
		button:SetPoint("TOPLEFT", spot, "TOPLEFT", 0, 0)
		button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		button:SetScript("OnClick", function(self)
			if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
			ns.ContextMenu(self, function(_, root)
				ns.MenuTitle(root, "A title")
				for _, o in ipairs(SHORT) do
					root:CreateRadio(o[2], function() return values.radio == o[1] end, function()
						values.radio = o[1]
						Picked("context", o[2])
					end)
				end
				ns.MenuDivider(root)
				root:CreateButton("An action", function() Picked("context", "An action") end)
			end)
		end)
	end

	-- The Studio's: on first show, once the Style part's code has run.
	local studioMade
	local function MakeStudio()
		if studioMade then return end
		local C = ns.Studio and ns.Studio.C
		if not C then
			for _, spot in pairs(studioSpots) do
				if not spot.note then spot.note = Note(spot, "The Style part isn't loaded: no Studio controls.") end
			end
			return
		end
		studioMade = true
		for _, spot in pairs(studioSpots) do if spot.note then spot.note:Hide() end end

		local drop
		drop = C.Drop(content, 200, LONG, function(v)
			values.studio = v
			drop:SetValue(v)
			Picked("studio", TextOf(LONG, v))
		end)
		drop:SetPoint("TOPLEFT", studioSpots.studio, "TOPLEFT", 0, 0)
		drop:SetValue(values.studio)

		local segOptions = {}
		for i, o in ipairs(SHORT) do segOptions[i] = { value = o[1], text = o[2] } end
		local seg
		seg = C.Segments(content, segOptions, function(v)
			values.segments = v
			seg:SetValue(v)
			Picked("segments", TextOf(SHORT, v))
		end)
		seg:SetPoint("TOPLEFT", studioSpots.segments, "TOPLEFT", 0, 0)
		seg:SetValue(values.segments)

		local switch
		switch = C.Switch(content, function(v)
			values.switch = v
			switch:SetValue(v)
			Picked("switch", v and "on" or "off")
		end)
		switch:SetPoint("TOPLEFT", studioSpots.switch, "TOPLEFT", 0, 0)
		switch:SetValue(values.switch)
	end

	canvas:SetScript("OnShow", kit.PageShown(function()
		MakeStudio()
		kit.FitContentHeight(content)
	end, content))
	canvas:Hide()
	kit.RegisterSubpage(canvas, "Control Gallery", "Control Gallery")
end
