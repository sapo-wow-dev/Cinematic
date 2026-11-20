-- The Help hub's Game Settings page: every game setting Cinematic
-- changes for a while where your own change wins (sets marked playerWins,
-- ns.ApplyCVarSet; and the profiles' Cooldown Manager and personal resource
-- display switches, Profiles.lua), one row each: what it's for, ours, yours
-- and now. Keep yours puts yours back and Cinematic leaves it alone for good
-- (db.cvarsLeftAlone, kept by Reset Settings); Use ours writes ours again at
-- once if it's in use now (also after you changed it yourself), else next
-- time. Yours can be set right here (ns.SetYourCVar): a switch, the style's
-- menu, or a number box; one a HUD row sets links to that row instead. A
-- filter box and a state menu narrow the rows; Used for opens the setting
-- that decides Ours; each row is /cine find cvar:<name>. Lives as you look at it.
local _, ns = ...
local L = ns.L

local REFRESH = 0.5 -- seconds between updates while shown
local ROW_H = 22
local OURS_COLOR, YOURS_COLOR, DIM_COLOR = "|cff40ff40", "|cff66ccff", "|cff888888"

-- The sections, in order, by the setting's name.
local SECTIONS = {
	{ "^UnitName", "Names over heads" },
	{ "^nameplate", "Nameplates" },
	{ "[Cc]ombatText", "Combat text" },
	{ "", "Other" },
}

-- Each setting's name as the game's options call it (else the setting's own).
local NAMES = {
	UnitNameOwn = "My name", UnitNameNPC = "All NPC names", UnitNameHostleNPC = "Enemy NPC names",
	UnitNameInteractiveNPC = "Interactive NPC names", UnitNameFriendlySpecialNPCName = "Special NPC names",
	UnitNameNonCombatCreatureName = "Critter and companion names", UnitNameFriendlyPlayerName = "Friendly player names",
	UnitNameFriendlyPetName = "Friendly pet names", UnitNameFriendlyGuardianName = "Friendly guardian names",
	UnitNameFriendlyTotemName = "Friendly totem names", UnitNameFriendlyMinionName = "Friendly minion names",
	UnitNameEnemyPlayerName = "Enemy player names", UnitNameEnemyPetName = "Enemy pet names",
	UnitNameEnemyGuardianName = "Enemy guardian names", UnitNameEnemyTotemName = "Enemy totem names",
	UnitNameEnemyMinionName = "Enemy minion names", UnitNamePlayerGuild = "Guild names",
	UnitNameFocused = "Target's name",
	nameplateShowAll = "Always show nameplates", nameplateForceShowUnitName = "Always show names on nameplates",
	nameplateShowEnemies = "Enemy nameplates", nameplateShowEnemyPlayers = "Enemy player nameplates",
	nameplateShowEnemyMinions = "Enemy minion nameplates", nameplateShowEnemyPets = "Enemy pet nameplates",
	nameplateShowEnemyGuardians = "Enemy guardian nameplates", nameplateShowEnemyTotems = "Enemy totem nameplates",
	nameplateShowEnemyMinus = "Minor enemy nameplates", nameplateShowFriends = "Friendly nameplates",
	nameplateShowFriendlyPlayers = "Friendly player nameplates", nameplateShowFriendlyNPCs = "Friendly NPC nameplates",
	nameplateShowFriendlyMinions = "Friendly minion nameplates", nameplateShowFriendlyPets = "Friendly pet nameplates",
	nameplateShowFriendlyGuardians = "Friendly guardian nameplates",
	nameplateShowFriendlyTotems = "Friendly totem nameplates",
	nameplateShowFriendlyPlayerMinions = "Friendly minion nameplates",
	nameplateShowFriendlyPlayerPets = "Friendly pet nameplates",
	nameplateShowFriendlyPlayerGuardians = "Friendly guardian nameplates",
	nameplateShowFriendlyPlayerTotems = "Friendly totem nameplates",
	nameplateShowOnlyNameForFriendlyPlayerUnits = "Only names on friendly player nameplates",
	nameplateShowOffscreen = "Show offscreen nameplates", nameplateStyle = "Nameplate style",
	nameplateUseClassColorForFriendlyPlayerUnitNames = "Class colors for friendly names",
	nameplateShowSelf = "Personal resource display",
	enableFloatingCombatText = "Floating combat text", floatingCombatTextCombatDamage = "Damage numbers",
	floatingCombatTextCombatHealing = "Healing numbers", floatingCombatTextPetMeleeDamage = "Pet melee damage",
	floatingCombatTextPetSpellDamage = "Pet spell damage",
	floatingCombatTextCombatHealingAbsorbSelf = "Shields on you",
	floatingCombatTextCombatHealingAbsorbTarget = "Shields on your target",
	floatingCombatTextCombatDamage_v2 = "Damage numbers", floatingCombatTextCombatHealing_v2 = "Healing numbers",
	floatingCombatTextPetMeleeDamage_v2 = "Pet melee damage", floatingCombatTextPetSpellDamage_v2 = "Pet spell damage",
	floatingCombatTextCombatHealingAbsorbSelf_v2 = "Shields on you",
	floatingCombatTextCombatHealingAbsorbTarget_v2 = "Shields on your target",
	ObjectSelectionCircle = "Target circle", findYourselfAnywhere = "Self highlight",
	findYourselfInRaid = "Self highlight in raids", findYourselfInBG = "Self highlight in battlegrounds",
	raidFramesDisplayBuffs = "Raid frame buffs",
	raidFramesDisplayDebuffs = "Raid frame debuffs", cooldownViewerEnabled = "Cooldown Manager",
}

-- What each set is for, by its label (the dev copy's Held Game Settings names).
-- (Third: what /cine find opens for it, the setting that decides Ours.)
local PURPOSES = {
	{ "^Names", "CineMode hides names", "handleNames" },
	{ "^Plates off$", "Faded nameplates can't be clicked", "handlePlates" },
	{ "^Combat text off$", "CineMode out of fights", "hideCombatText" },
	{ "^Target circle off$", "CineMode hides the target circle", "row:targetcircle" },
	{ "^Self highlight off$", "CineMode hides your self highlight", "row:selfhighlight" },
	{ "^Duel plates$", "Duel Vision", "duelHideOthers" },
	{ "^Instance plates off", "CineMode in dungeons and raids", "handlePlates" },
	{ "^All plates on$", "CineMode fades nameplates", "handlePlates" },
	{ "^Friendly player", "CineMode fades nameplates", "handlePlates" },
	{ "^Friendly minion", "CineMode fades nameplates", "handlePlates" },
	{ "^Offscreen plates", "Nameplates page: offscreen plates", "plateOffscreen" },
	{ "^Raid ", "Raid frame auras fade" },
	{ "^Game's damage numbers off$", "Combat Text Style" },
	{ "^Nameplate style$", "Style: nameplate style", "handlePlateStyle" },
	{ "^Class color names$", "Name Style: class colors" },
}
local SWITCH_PURPOSES = {
	cooldownViewerEnabled = "Profile: Cooldown Manager", nameplateShowSelf = "Profile: personal resource display",
}

local COLUMNS = { -- heading, share of the width
	{ "Setting", 0.25 }, { "Used for", 0.23 }, { "Ours", 0.07 }, { "Yours", 0.16 }, { "Now", 0.08 }, { "", 0.21 },
}

-- The state menu's choices (nil: every row).
local STATES = {
	{ nil, "All" }, { "ours", "Cinematic's now" }, { "changed", "Changed by you" }, { "kept", "Kept as yours" },
	{ "idle", "Not in use" },
}

ns.OnLanguage(function()
	for _, section in ipairs(SECTIONS) do section[2] = L[section[2]] end
	for cvar, name in pairs(NAMES) do NAMES[cvar] = L[name] end
	for _, purpose in ipairs(PURPOSES) do purpose[2] = L[purpose[2]] end
	for cvar, purpose in pairs(SWITCH_PURPOSES) do SWITCH_PURPOSES[cvar] = L[purpose] end
	for _, state in ipairs(STATES) do state[2] = L[state[2]] end
	for _, column in ipairs(COLUMNS) do column[1] = column[1] ~= "" and L[column[1]] or "" end
end)

local function Same(a, b)
	return a == b or (tonumber(a) ~= nil and tonumber(a) == tonumber(b))
end

-- A value as the options show it: on and off for switches, a style's name.
local function Shown(cvar, value)
	if value == nil then
		return ""
	end
	value = tostring(value)
	if cvar == "nameplateStyle" then
		local names = ns.GamePlateStyles and ns.GamePlateStyles()
		local name = names and names[(tonumber(value) or -1) + 1]
		if name then return name end
	elseif value == "0" then
		return L["Off"]
	elseif value == "1" then
		return L["On"]
	end
	return value
end

-- A value for the Ours and Now columns: Off quieter than On, so the rows
-- read at a glance.
local function Value(cvar, value)
	local text = Shown(cvar, value)
	if value ~= nil and tostring(value) == "0" and cvar ~= "nameplateStyle" then return DIM_COLOR .. text .. "|r" end
	return text
end

local function Purpose(label)
	for _, purpose in ipairs(PURPOSES) do
		if tostring(label or ""):find(purpose[1]) then return purpose[2], purpose[3] end
	end
	return label or ""
end

-- How Yours is set on a row: "row" (a HUD row sets it: a link), "style"
-- (the style's menu), "switch" (on/off), "number" (a box), or nil (the game
-- won't let it be changed: just its value).
local function Kind(row)
	if row.owner then return "row" end
	if C_CVar and C_CVar.GetCVarInfo then
		local ok, _, _, _, _, locked, _, readOnly = pcall(C_CVar.GetCVarInfo, row.cvar)
		if ok and (locked or readOnly) then return nil end
	end
	if row.cvar == "nameplateStyle" and ns.GamePlateStyles and ns.GamePlateStyles() then return "style" end
	local function Bool(value) return value == nil or value == "0" or value == "1" end
	if Bool(row.now) and Bool(row.yours) then
		for value in pairs(row.values) do
			if not Bool(value) then return "number" end
		end
		return "switch"
	end
	return "number"
end

-- The game's own default for a setting (nil: unknown).
local function GameDefault(cvar)
	local get = (C_CVar and C_CVar.GetCVarDefault) or GetCVarDefault
	if not get then return nil end
	local ok, value = pcall(get, cvar)
	return ok and value or nil
end

-- Whether a row passes the filter box's words (any of its name, setting
-- name, or what it's used for) and the state menu's pick.
local function Passes(row, words, state)
	if state and row.state ~= state then return false end
	if not words or words == "" then return true end
	local text = (row.name .. " " .. row.cvar .. " " .. (row.purpose or "")):lower()
	for word in words:lower():gmatch("%S+") do
		if not text:find(word, 1, true) then return false end
	end
	return true
end
ns.GameSettingsPasses = Passes -- (Tools/offline/gamesettingsedit.lua)

-- The rows as they are now, in sections: { cvar, name, purposes, ours,
-- yours, now, state, canYours, canOurs, switch }.
local function Gather()
	local lone = ns.db and ns.db.cvarsLeftAlone or {}
	local saved = ns.db and ns.db.savedCVars or {}
	local byCVar, list = {}, {}
	local function Row(cvar)
		local row = byCVar[cvar]
		if not row then
			row = { cvar = cvar, name = NAMES[cvar] or cvar, purposes = {}, seen = {}, values = {} }
			byCVar[cvar] = row
			list[#list + 1] = row
		end
		return row
	end
	for _, set in ipairs(ns.cvarSets or {}) do
		if set.playerWins then
			for cvar, value in pairs(set.values) do
				if GetCVar(cvar) ~= nil then
					local row = Row(cvar)
					local purpose, find = Purpose(set.label)
					if not row.seen[purpose] then
						row.seen[purpose] = true
						row.purposes[#row.purposes + 1] = purpose
					end
					row.find = row.find or find
					row.values[tostring(value)] = true
				end
			end
		end
	end
	for _, switch in ipairs(ns.ProfileSwitchRows and ns.ProfileSwitchRows() or {}) do
		if GetCVar(switch.cvar) ~= nil then
			local row = Row(switch.cvar)
			row.switch = switch
			row.purposes[#row.purposes + 1] = SWITCH_PURPOSES[switch.cvar] or switch.name
			row.values["1"] = true
		end
	end
	for _, row in ipairs(list) do
		local cvar = row.cvar
		row.now = GetCVar(cvar)
		local holder = ns.CVarHolder and ns.CVarHolder(cvar)
		local switch = row.switch
		if holder then
			row.ours = holder.values[cvar]
		elseif switch and switch.wanted then
			row.ours = "1"
		else
			-- (In use now by none: what the sets would write.)
			local values = {}
			for value in pairs(row.values) do values[#values + 1] = Value(cvar, value) end
			table.sort(values)
			row.oursText = table.concat(values, " / ")
		end
		local inUse = holder ~= nil or (switch and switch.wanted and ns.db.enabled) or false
		if lone[cvar] then
			row.yours, row.state = row.now, "kept"
		elseif saved[cvar] ~= nil then
			row.yours = saved[cvar]
		elseif switch and switch.turnedOn then
			row.yours = "0" -- (Cinematic turned it on: it was off)
		else
			row.yours = row.now
		end
		if not row.state then
			if inUse and row.ours ~= nil and Same(row.now, row.ours) then
				row.state = "ours"
			elseif inUse then
				row.state = "changed"
			else
				row.state = "idle"
			end
		end
		if ns.CVarRowOwner then
			local owner, ownerLabel = ns.CVarRowOwner(cvar)
			row.owner, row.ownerLabel = owner, ownerLabel
		end
		row.kind = Kind(row)
		row.canYours = not lone[cvar]
		row.canOurs = lone[cvar] or (row.state == "changed") or false
		local section = #SECTIONS
		for i, info in ipairs(SECTIONS) do
			if cvar:find(info[1]) then section = i break end
		end
		row.section = section
		row.purpose = table.concat(row.purposes, ", ")
	end
	table.sort(list, function(a, b)
		if a.section ~= b.section then return a.section < b.section end
		if a.name ~= b.name then return a.name < b.name end
		return a.cvar < b.cvar
	end)
	return list
end
ns.GameSettingsRows = Gather -- (Tools/offline/gamesettingsedit.lua, Dev/GameSettingsEditTest.lua)

local STATE_TIPS = {
	ours = "Cinematic's value is in use now. Yours comes back when it's done, or when you pick Keep yours.",
	changed = "In use by Cinematic, but you changed it yourself, so yours stands for now. Cinematic changes it " ..
		"again next time it needs it, unless you pick Keep yours. Use ours puts ours back now.",
	idle = "Yours. Cinematic changes it only while it needs it, then puts yours back.",
	kept = "Kept as yours: Cinematic never changes it. Some of its features may look different. Use ours lets " ..
		"Cinematic change it again.",
}
ns.OnLanguage(function()
	for key, tip in pairs(STATE_TIPS) do STATE_TIPS[key] = L[tip] end
end)

local function Pick(row, ours)
	local ok
	if ours then
		if row.switch and row.switch.leftAloneKey then (ns.ProfileSwitchMarks and ns.ProfileSwitchMarks() or ns.db)[row.switch.leftAloneKey] = nil end
		ok = ns.UseOurCVar(row.cvar)
	else
		ok = ns.KeepYourCVar(row.cvar)
	end
	return ok
end
local function FightNote()
	ns.Print(L["the game won't change nameplate and name settings in a fight: try again once it's over"])
end
-- Yours set from the page (a switch, the menu, the box).
local function SetYours(row, value)
	if not ns.SetYourCVar(row.cvar, value) then FightNote() end
end

function ns.CreateGameSettingsPage(kit)
	local canvas, content = kit.CreateScrollPage(true)
	local title = kit.Label(content, "GameFontNormalLarge", L["Game Settings"])
	title:SetPoint("TOPLEFT", 16, -16)
	local intro = kit.PageIntro(content, title, L["Game settings Cinematic changes while it needs them, then puts back to yours."])

	local allOurs = ns.PanelButton(content)
	allOurs:SetSize(140, 24)
	allOurs:SetText(L["Use ours for all"])
	allOurs:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -10)
	local allYours = ns.PanelButton(content)
	allYours:SetSize(140, 24)
	allYours:SetText(L["Keep yours for all"])
	allYours:SetPoint("LEFT", allOurs, "RIGHT", 8, 0)

	-- The filter box and the state menu: narrow the rows (and what the two
	-- buttons above act on).
	local Refresh
	local words, state = "", nil
	local okBox, filter = pcall(CreateFrame, "EditBox", nil, content, "SearchBoxTemplate")
	if not okBox or not filter then
		filter = ns.SkinEditBox(CreateFrame("EditBox", nil, content, "InputBoxTemplate"))
	end
	filter:SetSize(150, 20)
	filter:SetAutoFocus(false)
	filter:SetPoint("LEFT", allYours, "RIGHT", 14, 0)
	filter.searchSkip = true
	if filter.Instructions then filter.Instructions:SetText(L["Filter settings"]) end
	kit.Tooltip(filter, L["Shows only the settings whose name or use has these words."])
	filter:HookScript("OnTextChanged", function(self)
		words = (self:GetText() or ""):match("^%s*(.-)%s*$")
		if Refresh then Refresh() end
	end)
	filter:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
	end)
	filter:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	local okMenu, stateMenu = ns.MenuDropdown(content)
	if okMenu and stateMenu and stateMenu.SetupMenu then
		stateMenu:SetWidth(130)
		stateMenu:SetPoint("LEFT", filter, "RIGHT", 8, 0)
		stateMenu.searchSkip = true
		stateMenu:SetupMenu(function(_, root)
			for _, choice in ipairs(STATES) do
				root:CreateRadio(choice[2], function() return state == choice[1] end, function()
					state = choice[1]
					Refresh()
				end)
			end
		end)
	else
		stateMenu = nil
	end

	local summary = kit.Label(content, "GameFontHighlightSmall", "")
	summary:SetPoint("TOPLEFT", allOurs, "BOTTOMLEFT", 0, -8)
	summary:SetPoint("RIGHT", content, "RIGHT", -16, 0)
	summary:SetJustifyH("LEFT")

	local grid = CreateFrame("Frame", nil, content)
	grid:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -6)
	grid:SetPoint("RIGHT", content, "RIGHT", -16, 0)
	grid:SetHeight(ROW_H)

	local function Lay(cells, parent)
		local width = grid:GetWidth() or 0
		local x = 0
		for i, column in ipairs(COLUMNS) do
			local cell = cells[i]
			if cell then
				cell:ClearAllPoints()
				cell:SetPoint("LEFT", parent, "LEFT", x + 2, 0)
				cell:SetWidth(math.max(1, width * column[2] - 4))
			end
			x = x + width * column[2]
		end
		return width
	end
	local function ColumnX(width, index)
		local x = 0
		for i = 1, index - 1 do x = x + width * COLUMNS[i][2] end
		return x
	end

	local head = CreateFrame("Frame", nil, grid)
	head:SetPoint("TOPLEFT")
	head:SetPoint("TOPRIGHT")
	head:SetHeight(ROW_H)
	local headCells = {}
	for i, column in ipairs(COLUMNS) do
		local text = head:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		text:SetJustifyH("LEFT")
		text:SetWordWrap(false)
		text:SetText(column[1])
		headCells[i] = text
	end

	local function RowTip(owner, row, extra)
		GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
		GameTooltip:SetText(row.name, 1, 0.82, 0)
		if extra then GameTooltip:AddLine(extra, 1, 1, 1, true) end
		GameTooltip:AddLine(STATE_TIPS[row.state], 1, 1, 1, true)
		GameTooltip:AddLine(L["Used for:"] .. " " .. row.purpose, 0.8, 0.8, 0.8, true)
		local default = GameDefault(row.cvar)
		if default ~= nil then
			GameTooltip:AddLine(L["Game default:"] .. " " .. Shown(row.cvar, default), 0.8, 0.8, 0.8)
		end
		GameTooltip:AddLine(row.cvar, 0.5, 0.5, 0.5)
		GameTooltip:Show()
	end

	-- Lines: a section heading or a setting's row, made as needed.
	local lines = {}
	local function Line(index)
		local line = lines[index]
		if line then return line end
		line = CreateFrame("Frame", nil, grid)
		line:SetHeight(ROW_H)
		line:SetPoint("TOPLEFT", 0, -index * ROW_H)
		line:SetPoint("RIGHT")
		line:EnableMouse(true)
		line.stripe = line:CreateTexture(nil, "BACKGROUND")
		line.stripe:SetAllPoints()
		line.heading = line:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		line.heading:SetPoint("LEFT", 2, 0)
		line.cells = {}
		for i = 1, 5 do
			local cell = line:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
			cell:SetJustifyH("LEFT")
			cell:SetWordWrap(false)
			line.cells[i] = cell
		end
		-- (Small text, set before the words: Cyrillic needs the font first.)
		for key, label in pairs({ yours = L["Keep yours"], ours = L["Use ours"] }) do
			local button = ns.PanelButton(line)
			button:SetNormalFontObject("GameFontNormalSmall")
			button:SetHighlightFontObject("GameFontHighlightSmall")
			button:SetDisabledFontObject("GameFontDisableSmall")
			button:SetHeight(ROW_H - 2)
			button:SetText(label)
			line[key] = button
		end
		line.yours:SetScript("OnClick", function()
			if line.row and not Pick(line.row, false) then FightNote() end
			Refresh()
		end)
		line.ours:SetScript("OnClick", function()
			if line.row and not Pick(line.row, true) then FightNote() end
			Refresh()
		end)
		-- Used for: opens the setting that decides Ours.
		line.used = CreateFrame("Button", nil, line)
		line.used:SetHeight(ROW_H)
		line.used.searchSkip = true
		line.used:SetScript("OnClick", function()
			local row = line.row
			if row and row.find and ns.FindSetting then ns.FindSetting(row.find) end
		end)
		line.used:SetScript("OnEnter", function(self)
			local row = line.row
			if not row then return end
			line.cells[2]:SetText("|cffffd100" .. row.purpose .. "|r")
			RowTip(self, row, L["Click to open the setting that decides Ours."])
		end)
		line.used:SetScript("OnLeave", function()
			GameTooltip:Hide()
			if line.row then line.cells[2]:SetText(line.purposeText or "") end
		end)
		-- Yours: a switch, the style's menu, a number box, or a link to the
		-- HUD row that sets it.
		line.check = ns.SkinCheck(CreateFrame("CheckButton", nil, line, "UICheckButtonTemplate"))
		line.check:SetSize(20, 20)
		line.check.searchSkip, line.check.noSettingId = true, true
		line.check:SetScript("OnClick", function(self)
			if line.row then SetYours(line.row, self:GetChecked() and "1" or "0") end
			Refresh()
		end)
		line.check:SetScript("OnEnter", function(self)
			if line.row then RowTip(self, line.row, L["Your own value: Cinematic puts this back when it's done."]) end
		end)
		line.check:SetScript("OnLeave", function() GameTooltip:Hide() end)
		line.box = ns.SkinEditBox(CreateFrame("EditBox", nil, line, "InputBoxTemplate"))
		line.box:SetSize(60, ROW_H - 4)
		line.box:SetAutoFocus(false)
		line.box.searchSkip, line.box.noSettingId = true, true
		line.box:SetScript("OnEnterPressed", function(self)
			local text = (self:GetText() or ""):match("^%s*(.-)%s*$")
			if line.row and text ~= "" then SetYours(line.row, text) end
			self:ClearFocus()
			Refresh()
		end)
		line.box:SetScript("OnEscapePressed", function(self)
			self:ClearFocus()
			Refresh()
		end)
		line.link = CreateFrame("Button", nil, line)
		line.link:SetHeight(ROW_H)
		line.link.searchSkip = true
		line.link.text = line.link:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		line.link.text:SetPoint("LEFT")
		line.link.text:SetText(L["set by its row"])
		line.link:SetWidth((line.link.text:GetStringWidth() or 60) + 4)
		line.link:SetScript("OnClick", function()
			if line.row and line.row.owner and ns.FindSetting then ns.FindSetting("row:" .. line.row.owner) end
		end)
		line.link:SetScript("OnEnter", function(self)
			local row = line.row
			if row then
				RowTip(self, row, (L["Your own value follows its %s row. Click to open it."]):format(row.ownerLabel or "?"))
			end
		end)
		line.link:SetScript("OnLeave", function() GameTooltip:Hide() end)
		local okStyle, style = ns.MenuDropdown(line)
		if okStyle and style and style.SetupMenu then
			style:SetWidth(110)
			style.searchSkip, style.noSettingId = true, true
			style:SetupMenu(function(_, root)
				for at, name in ipairs(ns.GamePlateStyles and ns.GamePlateStyles() or {}) do
					local value = tostring(at - 1)
					root:CreateRadio(name, function() return line.row and Same(line.row.yours, value) end, function()
						if line.row then SetYours(line.row, value) end
						Refresh()
					end)
				end
			end)
			line.style = style
		end
		line:SetScript("OnEnter", function(self)
			if self.row then RowTip(self, self.row) end
		end)
		line:SetScript("OnLeave", function() GameTooltip:Hide() end)
		lines[index] = line
		return line
	end

	-- Every part of a line but its stripe, for a heading or "Nothing found".
	local function HideParts(line)
		for _, cell in ipairs(line.cells) do cell:Hide() end
		for _, part in ipairs({ line.yours, line.ours, line.used, line.check, line.box, line.link }) do part:Hide() end
		if line.style then line.style:Hide() end
	end

	-- Yours on a line: its control placed in the column, the value's text
	-- beside it.
	local function DrawYours(line, row, width)
		local x = ColumnX(width, 4) + 2
		local cell = line.cells[4]
		local kind = row.kind
		if kind == "style" and not line.style then kind = "number" end
		local value = Shown(row.cvar, row.yours) .. (row.state == "kept" and " " .. L["(kept)"] or "")
		local color = row.state ~= "ours" and YOURS_COLOR or ""
		line.check:SetShown(kind == "switch")
		line.box:SetShown(kind == "number")
		line.link:SetShown(kind == "row")
		if line.style then line.style:SetShown(kind == "style") end
		cell:ClearAllPoints()
		if kind == "switch" then
			line.check:ClearAllPoints()
			line.check:SetPoint("LEFT", line, "LEFT", x - 2, 0)
			line.check:SetChecked(row.yours == "1")
			cell:SetPoint("LEFT", line.check, "RIGHT", 0, 0)
			cell:SetText(color .. value)
		elseif kind == "style" then
			line.style:ClearAllPoints()
			line.style:SetPoint("LEFT", line, "LEFT", x, 0)
			line.style:SetWidth(math.max(60, width * COLUMNS[4][2] - 6))
			if line.drawnStyle ~= row.yours then
				line.drawnStyle = row.yours
				line.style:GenerateMenu()
			end
			cell:SetText("")
		elseif kind == "number" then
			line.box:ClearAllPoints()
			line.box:SetPoint("LEFT", line, "LEFT", x + 4, 0)
			if not line.box:HasFocus() then line.box:SetText(tostring(row.yours or "")) end
			cell:SetPoint("LEFT", line.box, "RIGHT", 4, 0)
			cell:SetText(row.state == "kept" and (DIM_COLOR .. L["(kept)"]) or "")
		elseif kind == "row" then
			cell:SetPoint("LEFT", line, "LEFT", x, 0)
			cell:SetText(color .. Shown(row.cvar, row.yours))
			line.link:ClearAllPoints()
			line.link:SetPoint("LEFT", cell, "LEFT", (cell:GetStringWidth() or 0) + 6, 0)
		else
			cell:SetPoint("LEFT", line, "LEFT", x, 0)
			cell:SetText(color .. value)
		end
		cell:SetWidth(math.max(1, width * COLUMNS[4][2] - 30))
	end

	local shownRows = {}
	function Refresh()
		local rows = Gather()
		Lay(headCells, head)
		local index, lastSection, inUse, kept = 0, nil, 0, 0
		local lastPurpose
		for i = #shownRows, 1, -1 do shownRows[i] = nil end
		for _, row in ipairs(rows) do
			if row.state == "ours" then inUse = inUse + 1 elseif row.state == "kept" then kept = kept + 1 end
		end
		for _, row in ipairs(rows) do
			if Passes(row, words, state) then
				shownRows[#shownRows + 1] = row
				if row.section ~= lastSection then
					lastPurpose = nil
					lastSection = row.section
					index = index + 1
					local line = Line(index)
					line.row, line.settingKey = nil, nil
					line.heading:SetText(SECTIONS[row.section][2])
					line.heading:Show()
					line.stripe:SetColorTexture(0.45, 0.38, 0.2, 0.25)
					HideParts(line)
					line:Show()
				end
				index = index + 1
				local line = Line(index)
				line.row = row
				line.settingKey = "cvar:" .. row.cvar -- (/cine find cvar:<name>, Options.lua's search index)
				line.heading:Hide()
				line.stripe:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.04 or 0)
				local width = Lay(line.cells, line)
				local c = line.cells
				c[1]:SetText(row.name)
				-- (The same use as the row above: left blank, so a section's uses
				-- read as groups, not a wall of one line. Its tooltip still says it.)
				local repeated = row.purpose == lastPurpose
				line.purposeText = repeated and "" or (DIM_COLOR .. row.purpose)
				lastPurpose = row.purpose
				c[2]:SetText(line.purposeText)
				line.used:ClearAllPoints()
				line.used:SetPoint("LEFT", c[2], "LEFT")
				line.used:SetWidth(math.max(1, math.min((c[2]:GetStringWidth() or 0) + 2, width * COLUMNS[2][2] - 4)))
				line.used:SetShown(row.find ~= nil and not repeated)
				c[3]:SetText(row.state == "ours" and (OURS_COLOR .. Shown(row.cvar, row.ours))
					or row.oursText or Value(row.cvar, row.ours))
				c[5]:SetText(Value(row.cvar, row.now))
				for _, cell in ipairs(c) do cell:Show() end
				DrawYours(line, row, width)
				-- (The buttons in the last column, each half its width: Keep yours,
				-- then Use ours, the one shown alone taking the first spot.)
				local x = width * (1 - COLUMNS[#COLUMNS][2]) + 2
				-- (Each as wide as its words and a margin, at most half the column.)
				local half = math.max(1, math.floor((width * COLUMNS[#COLUMNS][2] - 6) / 2))
				local function Fit(button)
					local text = button:GetFontString()
					local words = text and text:GetStringWidth() or 0
					button:SetWidth(math.max(1, math.min(half, math.floor(words + 16))))
					return button:GetWidth() or half
				end
				local yoursWidth = Fit(line.yours)
				Fit(line.ours)
				line.yours:ClearAllPoints()
				line.yours:SetPoint("LEFT", line, "LEFT", x, 0)
				line.ours:ClearAllPoints()
				line.ours:SetPoint("LEFT", line, "LEFT", row.canYours and x + yoursWidth + 4 or x, 0)
				line.yours:SetShown(row.canYours)
				line.ours:SetShown(row.canOurs)
				line:Show()
			end
		end
		if #shownRows == 0 then
			index = index + 1
			local line = Line(index)
			line.row, line.settingKey = nil, nil
			line.heading:SetText(DIM_COLOR .. L["Nothing found"] .. "|r")
			line.heading:Show()
			line.stripe:SetColorTexture(0, 0, 0, 0)
			HideParts(line)
			line:Show()
		end
		for i = index + 1, #lines do
			lines[i]:Hide()
			lines[i].row, lines[i].settingKey = nil, nil
		end
		grid:SetHeight(ROW_H * (index + 1))
		summary:SetText((L["%d settings: %s%d Cinematic's now|r, %s%d kept as yours|r."]):format(#rows, OURS_COLOR,
			inUse, YOURS_COLOR, kept)
			.. (#shownRows < #rows and (" " .. (L["%d shown."]):format(#shownRows)) or ""))
		allYours.rows, allOurs.rows = shownRows, shownRows
		if stateMenu and stateMenu.drawn ~= (state or "") then
			stateMenu.drawn = state or ""
			stateMenu:GenerateMenu()
		end
	end
	-- (Rows made before a search looks at the page: its own box, the main
	-- one, /cine find cvar:<name>.)
	ns.searchPrepare[#ns.searchPrepare + 1] = function() Refresh() end
	-- (Dev/GameSettingsEditTest.lua and the offline check: the filter set as
	-- typing and picking do, and the lines drawn.)
	ns.GameSettingsPage = {
		Refresh = Refresh, lines = lines,
		SetFilter = function(text, pick)
			state = pick
			filter:SetText(text or "")
			words = text or ""
			Refresh()
		end,
	}

	allOurs:SetScript("OnClick", function(self)
		local blocked
		for _, row in ipairs(self.rows or {}) do
			if row.canOurs and not Pick(row, true) then blocked = true end
		end
		if blocked then FightNote() end
		Refresh()
	end)
	allYours:SetScript("OnClick", function(self)
		local blocked
		for _, row in ipairs(self.rows or {}) do
			if row.canYours and not Pick(row, false) then blocked = true end
		end
		if blocked then FightNote() end
		Refresh()
	end)

	local since = 0
	ns.SetOnUpdate(canvas, function(_, elapsed)
		since = since + elapsed
		if since < REFRESH then return end
		since = 0
		Refresh()
		kit.FitContentHeight(content)
	end)
	grid:SetScript("OnSizeChanged", function() if canvas:IsShown() then Refresh() end end)
	canvas:SetScript("OnShow", kit.PageShown(Refresh, content))
	canvas:Hide()
	kit.RegisterSubpage(canvas, "Game settings", L["Game Settings"])
end
