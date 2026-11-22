-- Cinematic: the Cameras page's editor for scenes (CustomTriggers.lua): the
-- Triggers and Ends lines in a scene's drawer, the New scene panel, and the
-- window that shares a scene or a shot (Shots.lua) as text, or adds one
-- someone shared.
local _, ns = ...
ns.Module("cameras", function() -- (the rest of this file: only with Cameras loaded, Modules.lua)
local L = ns.L

-- A dropdown of { value, text } choices (or a function giving them), or on a
-- client without the modern dropdown a button that steps through them.
local function Menu(parent, width, choices, get, set)
	local function List() return type(choices) == "function" and choices() or choices end
	local ok, menu = ns.MenuDropdown(parent)
	if ok and menu and menu.SetupMenu then
		menu:SetWidth(width)
		menu:SetupMenu(function(_, root)
			for _, choice in ipairs(List()) do
				root:CreateRadio(choice.text, function() return ns.GetDB() ~= nil and get() == choice.value end,
					function() set(choice.value) end)
			end
		end)
		menu.Refresh = function(self) self:GenerateMenu() end
	else
		menu = ns.PanelButton(parent)
		menu:SetSize(width, 22)
		menu:SetScript("OnClick", function()
			local list, now = List(), get()
			for i, choice in ipairs(list) do
				if choice.value == now then
					set(list[i % #list + 1].value)
					return
				end
			end
			if list[1] then set(list[1].value) end
		end)
		menu.Refresh = function(self)
			local now = get()
			for _, choice in ipairs(List()) do
				if choice.value == now then
					self:SetText(choice.text)
					return
				end
			end
			self:SetText("")
		end
	end
	menu.searchSkip = true
	return menu
end
ns.ChoiceMenu = Menu
-- (Shown only while test() holds; refreshed as before.)
local function ShownWhile(control, test)
	local refresh = control.Refresh
	control.Refresh = function(self)
		local shown = test() and true or false
		self:SetShown(shown)
		if shown and refresh then refresh(self) end
	end
	return control
end

-- A trigger's camera choices in the menus' order: its cameras (camera scripts
-- among them, CameraScripts.lua), your shots where it has the cozy camera,
-- then No camera.
function ns.CameraChoiceValues(cameras)
	local list, none = {}, nil
	for _, value in ipairs(cameras) do
		if value == "none" or value == false then none = value else list[#list + 1] = value end
	end
	for _, value in ipairs(cameras) do
		if value == "cozy" and not ns.SHOTS_RETIRED then
			for _, shot in ipairs((ns.ShotList())) do list[#list + 1] = "shot:" .. shot end
		end
	end
	if none ~= nil then list[#list + 1] = none end
	return list
end
-- A camera menu's New shot... entry: a new shot of the cozy camera, picked
-- with set(value), and My Shots opened on it to set its numbers.
function ns.NewShotFor(set)
	local id = ns.AddShot("cozy")
	if not id then
		ns.Print((L["You have %d shots already: delete one to make another."]):format(ns.SHOT_MAX))
		return
	end
	set("shot:" .. id)
	ns.myShotsSelect = id
	ns.OpenOptions("My Shots")
end
ns.CUSTOM_CAMERA_TIP = "The camera it plays: one that runs where you stand, a camera script, or a shot of yours (New " ..
	"shot... makes one and opens My Shots). The flight, RP walk, auto-run, quest and chat cameras " ..
	"aren't listed here because they need you flying, walking or talking to an NPC, and they have " ..
	"their own scenes."

-- Where the lines read and write a scene's settings: list() its triggers (a
-- copy), setList(list), and get/set for until, after, name, camera, music,
-- cine. A saved scene's row (RowStore; a built-in scene's list is its extra
-- triggers), or the New scene panel's draft, kept until Save (TableStore).
local function RowStore(id)
	return {
		list = function()
			local copy = {}
			for i, source in ipairs(ns.SceneTriggers(id)) do copy[i] = source end
			return copy
		end,
		setList = function(list) ns.SetSceneTriggers(id, list) end,
		get = function(field) return ns.GetDB().cameraRows[id .. "." .. field] end,
		set = function(field, value) ns.GetDB().cameraRows[id .. "." .. field] = value end,
	}
end
local function TableStore(data)
	return {
		list = function()
			local copy = {}
			for i, source in ipairs(data.triggers) do copy[i] = source end
			return copy
		end,
		setList = function(list) data.triggers = list end,
		get = function(field) return data[field] end,
		set = function(field, value) data[field] = value end,
	}
end
-- The triggers a line can pick: the library's (TriggerLibrary.lua), and New
-- trigger... to make one (and open its page).
local function LibChoices()
	local list = {}
	for _, id in ipairs((ns.TriggerLibList())) do list[#list + 1] = { value = "t:" .. id, text = ns.TriggerLabel(id) } end
	-- (Ours too: the standing-still ones, whose code says when they're on.)
	for _, each in ipairs(ns.BuiltInTriggers()) do
		if each.source then
			list[#list + 1] = { value = "t:" .. ns.OursTriggerId(each.key), text = each.name .. "  |cff999999" ..
				L["(ours)"] .. "|r" }
		end
	end
	if #list < ns.TRIGGER_LIB_MAX then list[#list + 1] = { value = "new", text = L["New trigger..."] } end
	return list
end
-- A trigger for a new line: the first of the library's not in the list yet,
-- else a new one (/cheer to start with). Its source ("t:<id>"), or nil (full).
local function NextTrigger(list)
	local taken = {}
	for _, source in ipairs(list) do taken[source] = true end
	for _, id in ipairs((ns.TriggerLibList())) do
		if not taken["t:" .. id] then return "t:" .. id end
	end
	local id = ns.AddLibTrigger("emote:cheer")
	return id and "t:" .. id or nil
end
ns.NextSceneTrigger = NextTrigger

-- A scene's lines on parent: its Triggers, a line each (each a trigger of
-- the library, picked, with Edit to open its page), and a line for + Add trigger
-- (kit.actions: more controls for that line, { control, x }). A built-in
-- scene's own triggers come first, locked, a line each (kit.builtinLabel). kit: At,
-- BlockAt(line, control, x) (the Triggers lines, from 1), resize(lines) (the
-- Triggers' lines shown now), Tooltip, AddControl, x, Saved(), typing(i, text).
local function BuildLines(parent, store, kit)
	local Tooltip, AddControl, x, Saved = kit.Tooltip, kit.AddControl, kit.x, kit.Saved
	local offset = 0
	local function Count() return #store.list() end
	-- (A built-in scene's own triggers first: a line each, laid out as the
	-- triggers of your own below them, "or" between. Each can be taken off
	-- the scene (the x) and put back (the +): a taken-off one stays on its
	-- line, dimmed, so the lines don't move.)
	if kit.builtinLabel then
		for j, each in ipairs(kit.builtinLabel) do
			local key = each.key
			local function Dropped() return ns.TriggerDropped(key) end
			if j > 1 then
				kit.BlockAt(j, parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"), x):SetText(L["or"])
			end
			local own = kit.BlockAt(j, parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight"), x + 24)
			own:SetWidth(270)
			-- (Its page on the Triggers page: its Only if, timing, priority.)
			local edit = kit.BlockAt(j, ns.PanelButton(parent), x + 300)
			edit:SetSize(60, 22)
			edit:SetText(L["Edit"])
			edit.searchSkip = true
			edit:SetScript("OnClick", function()
				if ns.OpenTriggerPage then ns.OpenTriggerPage("b:" .. key) end
			end)
			Tooltip(edit, L["Opens this trigger's page."])
			own:SetJustifyH("LEFT")
			own:SetWordWrap(false)
			local toggle = kit.BlockAt(j, CreateFrame("Button", nil, parent), x + 424)
			toggle:SetSize(16, 16)
			toggle:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
			toggle:SetScript("OnClick", function()
				ns.SetTriggerDropped(key, not Dropped())
				Saved()
			end)
			toggle.Refresh = function(self)
				local dropped = Dropped()
				-- (Both colors: they're one on Forever.)
				local shade = dropped and 0.45 or 0.9
				own:SetText(dropped and (each.name .. "  " .. L["(off)"]) or each.name)
				own:SetTextColor(shade, shade, shade)
				own:SetVertexColor(shade, shade, shade)
				self:SetNormalTexture(dropped and "Interface\\Buttons\\UI-PlusButton-Up"
					or "Interface\\Buttons\\UI-StopButton")
			end
			Tooltip(toggle, L["Take this trigger off the scene (it then starts nothing), or put it back."])
			AddControl(toggle)
		end
		offset = math.max(1, #kit.builtinLabel)
	end

	-- A line per trigger: "or", the trigger (the library's, picked), Edit
	-- and remove. Made for the most a scene can have, shown for those it has.
	-- (What starts it, when it ends and its priority are the trigger's own:
	-- the Triggers page.)
	for i = 1, ns.SCENE_TRIGGER_MAX do
		local line = i + offset
		local function Shown() return i <= Count() end
		local function Lib() return tostring(store.list()[i] or ""):match("^t:(Trig%a+)$") end
		local orText = kit.BlockAt(line, parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"), x)
		orText:SetText(L["or"])
		local pick = kit.BlockAt(line, Menu(parent, 270, LibChoices, function() return store.list()[i] end,
			function(value)
				local list = store.list()
				if value == "new" then
					local id = ns.AddLibTrigger("emote:cheer")
					if not id then return end
					list[i] = "t:" .. id
					store.setList(list)
					Saved()
					if ns.OpenTriggerPage then ns.OpenTriggerPage(id) end
					return
				end
				list[i] = value
				store.setList(list)
				Saved()
			end), x + 20)
		local pickRefresh = pick.Refresh
		pick.Refresh = function(self)
			local shown = Shown()
			self:SetShown(shown)
			orText:SetShown(shown and line > 1)
			if shown then pickRefresh(self) end
		end
		Tooltip(pick, L["A trigger that starts this scene; any one of them starts it."])
		AddControl(pick)

		local edit = kit.BlockAt(line, ns.PanelButton(parent), x + 300)
		edit:SetSize(60, 22)
		edit:SetText(L["Edit"])
		edit.searchSkip = true
		edit:SetScript("OnClick", function()
			local id = Lib()
			if id and ns.OpenTriggerPage then ns.OpenTriggerPage(id) end
		end)
		ShownWhile(edit, function() return Shown() and Lib() ~= nil end)
		Tooltip(edit, L["Opens this trigger's page; changes there apply to every scene using it."])
		AddControl(edit)

		-- (A scene of yours keeps one trigger at least.)
		local remove = kit.BlockAt(line, CreateFrame("Button", nil, parent), x + 424)
		remove:SetSize(16, 16)
		remove:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
		remove:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
		remove:SetScript("OnClick", function()
			local list = store.list()
			table.remove(list, i)
			store.setList(list)
			Saved()
		end)
		remove.Refresh = function(self) self:SetShown(Shown() and (kit.builtinLabel ~= nil or Count() > 1)) end
		Tooltip(remove, L["Take this trigger off the scene (it stays on the Triggers page)."])
		AddControl(remove)
	end

	-- + Add trigger, on the line after the last (with kit.actions beside it).
	local add = ns.PanelButton(parent)
	add:SetSize(120, 22)
	add:SetText(L["+ Add trigger"])
	add.searchSkip = true
	add:SetScript("OnClick", function()
		local list = store.list()
		local source = NextTrigger(list)
		if not source then return end
		list[#list + 1] = source
		store.setList(list)
		Saved()
	end)
	Tooltip(add, L["Another trigger for this scene. Any one of its triggers starts it."])
	local placed -- (the line the actions sit on now)
	local block = CreateFrame("Frame", nil, parent)
	block.Refresh = function()
		local count = Count()
		local line = offset + count + 1
		add:SetShown(count < ns.SCENE_TRIGGER_MAX)
		if line ~= placed then
			placed = line
			add:ClearAllPoints()
			kit.BlockAt(line, add, x + 20)
			for _, each in ipairs(kit.actions or {}) do
				each[1]:ClearAllPoints()
				kit.BlockAt(line, each[1], each[2])
			end
		end
		kit.resize(line)
	end
	AddControl(block)
end

-- A saved scene's drawer: a scene of yours' Ends and Triggers lines and a
-- Share button on its Name line, or a built-in scene's Triggers (its own,
-- then yours). kit: At, BlockAt, resize, Changed(), Tooltip, AddControl, x,
-- shareX, builtinLabel (a built-in scene's own triggers' names, a list).
function ns.BuildCustomTriggerLines(drawer, id, kit)
	local custom = kit.builtinLabel == nil
	BuildLines(drawer, RowStore(id), { At = custom and kit.At or nil, BlockAt = kit.BlockAt, resize = kit.resize,
		Tooltip = kit.Tooltip, AddControl = kit.AddControl, x = kit.x, builtinLabel = kit.builtinLabel,
		Saved = function()
			ns.CustomTriggersChanged()
			kit.Changed()
		end })
	if not custom then return end
	local share = kit.At("Name", ns.PanelButton(drawer), kit.shareX)
	share:SetSize(70, 22)
	share:SetText(L["Share"])
	share.searchSkip = true
	share:SetScript("OnClick", function()
		ns.ShowCameraShare(ns.ExportCameraTrigger(id), (L["Share %s"]):format(ns.CustomTriggerLabel(id)))
	end)
	kit.Tooltip(share, L["Text a friend can import to add this scene."])
end

-- The New scene panel, above the Cameras page's rows: a scene made in it
-- isn't one until Save, which adds it to the rows (where it sorts as the
-- rest do). Cancel drops it. kit: width, Tooltip, onSaved(id), onShown(shown).
-- Gives the panel; panel:Open() starts a fresh draft.
function ns.BuildTriggerDraft(parent, kit)
	local LINE_H, LABEL_W, TOP = 34, 62, 26
	local LINES = { "Name", "Camera" }
	local panel = CreateFrame("Frame", nil, parent)
	panel:SetSize(kit.width, TOP + LINE_H * (#LINES + 2) + 8)
	panel:Hide()
	local back = panel:CreateTexture(nil, "BACKGROUND")
	back:SetAllPoints()
	back:SetColorTexture(0, 0, 0, 0.35)
	local edge = panel:CreateTexture(nil, "BORDER")
	edge:SetPoint("TOPLEFT")
	edge:SetPoint("BOTTOMLEFT")
	edge:SetWidth(2)
	edge:SetColorTexture(0.73, 0.89, 0.54, 0.8)
	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 10, -8)
	title:SetText(L["New scene"])

	local data = { triggers = {} }
	local store = TableStore(data)
	local own = {} -- (its controls, refreshed together)
	local function RefreshAll() for _, control in ipairs(own) do control:Refresh() end end
	local function At(line, control, x)
		local index = 1
		for i, each in ipairs(LINES) do if each == line then index = i end end
		control:SetPoint("LEFT", panel, "TOPLEFT", x, -(TOP + (index - 0.5) * LINE_H))
		return control
	end
	local function BlockAt(line, control, x)
		control:SetPoint("LEFT", panel, "TOPLEFT", x, -(TOP + (#LINES + line - 0.5) * LINE_H))
		return control
	end
	for _, line in ipairs(LINES) do
		local label = At(line, panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"), 10)
		label:SetText(({ Name = L["Name"], Camera = L["Camera"] })[line])
	end
	BlockAt(1, panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"), 10):SetText(L["Triggers"])

	-- (What it needs to be saved: a trigger.)
	local function Ready() return #data.triggers > 0 end
	local save -- (below)

	local name = At("Name", ns.SkinEditBox(CreateFrame("EditBox", nil, panel, "InputBoxTemplate")), LABEL_W + 16)
	name:SetSize(220, 20)
	name:SetAutoFocus(false)
	name:SetMaxLetters(40)
	local nameHint = name:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	nameHint:SetPoint("LEFT", 2, 0)
	nameHint:SetPoint("RIGHT", -2, 0)
	nameHint:SetJustifyH("LEFT")
	nameHint:SetWordWrap(false)
	name:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	name:SetScript("OnEditFocusGained", function() nameHint:Hide() end)
	name:SetScript("OnEditFocusLost", function(self)
		local text = self:GetText():gsub("[%c|]", ""):match("^%s*(.-)%s*$")
		data.name = text ~= "" and text or nil
		nameHint:SetShown(not data.name)
	end)
	name.Refresh = function(self)
		if not self:HasFocus() then self:SetText(data.name or "") end
		nameHint:SetText(ns.DescribeTriggerSource(data.triggers[1]))
		nameHint:SetShown(not data.name and not self:HasFocus())
	end
	kit.Tooltip(name, L["Your own name for it; leave empty to show what starts it."])
	own[#own + 1] = name

	-- (Its camera: the ones that run where you stand, the moving ones (their
	-- scripts) and yours, by name, as the General page has them; not our
	-- cameras' scripts or their parts, Fly-by say: those aren't cameras.)
	local MOVING = { walk = true, run = true }
	local camera = At("Camera", Menu(panel, 150, function()
		local list = {}
		for _, value in ipairs(ns.CameraChoiceValues(ns.CUSTOM_TRIGGER_CAMERAS)) do
			local id = ns.IsScriptCamera(value) and value:sub(8)
			local script = id and (MOVING[id] and ns.FindCameraScript(id) or ns.MyCameraScript(id))
			if not id then
				list[#list + 1] = { value = value, text = ns.CameraName(value) or tostring(value) }
			elseif script then
				list[#list + 1] = { value = value, text = script.name }
			end
		end
		if not ns.SHOTS_RETIRED and #(ns.ShotList()) < ns.SHOT_MAX then
			list[#list + 1] = { value = "newshot", text = L["New shot..."] }
		end
		return list
	end, function() return data.camera end, function(value)
		if value == "newshot" then
			ns.NewShotFor(function(shot) data.camera = shot end)
		else
			data.camera = value
		end
		RefreshAll()
	end), LABEL_W + 4)
	kit.Tooltip(camera, L[ns.CUSTOM_CAMERA_TIP])
	own[#own + 1] = camera
	local function Tick(label, field, x, tip)
		local check = ns.SkinCheck(CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate"))
		check:SetSize(26, 26)
		local text = check.Text or check.text or check:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		text:SetPoint("LEFT", check, "RIGHT", 2, 0)
		text:SetFontObject("GameFontHighlight")
		text:SetText(label)
		check:SetScript("OnClick", function(self) data[field] = self:GetChecked() and true or nil end)
		check.Refresh = function(self)
			self:SetChecked(data[field] and true or false)
		end
		kit.Tooltip(check, tip)
		own[#own + 1] = At("Camera", check, x)
	end
	Tick(L["Music"], "music", LABEL_W + 170, L["Music starts as its camera starts (Audio page)."])
	Tick("CineMode", "cine", LABEL_W + 260, L["Turns CineMode on while its camera runs, if Start in CineMode is off."])

	save = ns.PanelButton(panel)
	save:SetSize(90, 22)
	save:SetText(L["Save"])
	save.Refresh = function(self) self:SetEnabled(Ready()) end
	kit.Tooltip(save, L["Adds it to the rows below."])
	local cancel = ns.PanelButton(panel)
	cancel:SetSize(90, 22)
	cancel:SetText(CANCEL or L["Cancel"])

	BuildLines(panel, store, {
		At = At, BlockAt = BlockAt, Tooltip = kit.Tooltip, x = LABEL_W + 4,
		AddControl = function(control) own[#own + 1] = control end,
		actions = { { save, LABEL_W + 280 }, { cancel, LABEL_W + 376 } },
		resize = function(lines) panel:SetHeight(TOP + LINE_H * (#LINES + lines) + 8) end,
		Saved = RefreshAll,
	})
	own[#own + 1] = save

	function panel:Close()
		self:Hide()
		kit.onShown(false)
	end
	cancel:SetScript("OnClick", function() panel:Close() end)
	save:SetScript("OnClick", function()
		-- (The boxes as they are, even mid-typing.)
		for _, control in ipairs(own) do
			if control.HasFocus and control:HasFocus() then control:ClearFocus() end
		end
		if not Ready() then return end
		local id = ns.AddCustomTrigger(data.triggers[1], nil, data.camera, data.name)
		if not id then
			ns.Print((L["You have %d scenes of your own already: delete one to make another."]):format(
				ns.CUSTOM_TRIGGER_MAX))
			return
		end
		ns.SetSceneTriggers(id, data.triggers)
		local rows = ns.GetDB().cameraRows
		rows[id .. ".music"] = data.music
		rows[id .. ".cine"] = data.cine
		ns.CustomTriggersChanged()
		panel:Close()
		kit.onSaved(id)
	end)

	-- A name to start with: My Scene, or My Scene (1), (2)... where one of
	-- yours has it. (You can still give two the same name.)
	local function NextName()
		local rows, taken = ns.GetDB().cameraRows, {}
		for id in tostring(rows.custom or ""):gmatch("[^,]+") do
			local mine = rows[id .. ".name"]
			if type(mine) == "string" then taken[mine] = true end
		end
		local base = L["My Scene"]
		if not taken[base] then return base end
		local n = 1
		while taken[("%s (%d)"):format(base, n)] do n = n + 1 end
		return ("%s (%d)"):format(base, n)
	end

	function panel:Open()
		wipe(data)
		local first = NextTrigger({})
		data.triggers, data.camera, data.name = { first }, "cozy", NextName()
		self:Show()
		RefreshAll()
		kit.onShown(true)
	end
	return panel
end

-- Deleting a built-in trigger (CameraRows' deleted list), once you've said
-- yes: its rows go, and it starts no camera, until Add back.
function ns.ConfirmDeleteBuiltInTrigger(key, name, done)
	if not StaticPopupDialogs.CINEMATIC_DELETE_BUILTIN_TRIGGER then
		StaticPopupDialogs.CINEMATIC_DELETE_BUILTIN_TRIGGER = {
			text = L["Delete the scene %s? It won't start a camera until you bring it back with Add back, above the " ..
				"rows. Its settings are kept."],
			button1 = DELETE or L["Delete"], button2 = CANCEL or L["Cancel"],
			OnAccept = function(_, data) data() end,
			timeout = 0, whileDead = true, hideOnEscape = true,
		}
	end
	StaticPopup_Show("CINEMATIC_DELETE_BUILTIN_TRIGGER", (tostring(name):gsub("|", "")), nil, function()
		ns.SetSceneDeleted(key, true) -- (a group's members with it)
		done()
	end)
end

-- The Add back menu: the built-in scenes you've deleted, one to bring
-- back (or all of them). Shown only while there are any. label(key): a
-- scene's name; onChanged() after one comes back.
function ns.BuildAddBackMenu(parent, label, onChanged)
	local function Back(key)
		if key == "all" then
			for _, each in ipairs(ns.DeletedTriggers()) do ns.SetSceneDeleted(each, false) end
		else
			ns.SetSceneDeleted(key, false)
		end
		onChanged()
	end
	local ok, menu = ns.MenuDropdown(parent)
	if ok and menu and menu.SetupMenu then
		menu:SetWidth(120)
		if menu.SetDefaultText then menu:SetDefaultText(L["Add back"]) end
		menu:SetupMenu(function(_, root)
			for _, key in ipairs(ns.DeletedTriggers()) do
				root:CreateButton(label(key), function() Back(key) end)
			end
			if #ns.DeletedTriggers() > 1 then root:CreateButton(L["All of them"], function() Back("all") end) end
		end)
		menu.Refresh = function(self)
			self:SetShown(#ns.DeletedTriggers() > 0)
			self:GenerateMenu()
		end
	else
		-- (No modern dropdown: one button brings them all back.)
		menu = ns.PanelButton(parent)
		menu:SetSize(120, 22)
		menu:SetText(L["Add back all"])
		menu:SetScript("OnClick", function() Back("all") end)
		menu.Refresh = function(self) self:SetShown(#ns.DeletedTriggers() > 0) end
	end
	menu.searchSkip = true
	return menu
end

-- Deleting a trigger of your own, once you've said yes.
function ns.ConfirmRemoveCustomTrigger(id, done)
	if not StaticPopupDialogs.CINEMATIC_REMOVE_CAMERA_TRIGGER then
		StaticPopupDialogs.CINEMATIC_REMOVE_CAMERA_TRIGGER = {
			text = L["Delete the scene %s and its settings?"],
			button1 = DELETE or L["Delete"], button2 = CANCEL or L["Cancel"],
			OnAccept = function(_, data) data() end,
			timeout = 0, whileDead = true, hideOnEscape = true,
		}
	end
	local name = tostring(ns.CustomTriggerLabel(id)):gsub("|", "")
	StaticPopup_Show("CINEMATIC_REMOVE_CAMERA_TRIGGER", name, nil, function()
		ns.RemoveCustomTrigger(id)
		done()
	end)
end

-- (The share window: UI/ShareWindow.lua, loaded with Cameras left out too:
-- Style Themes and Vitals share through it.)
end) -- (ns.Module "cameras")
