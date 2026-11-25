-- Combat Text Style's Spells tab (2026-11-25, the player's ask: "if i want a
-- different color for each spell i should be able to"). CombatTextPage.lua
-- makes the page and calls ns.BuildCombatTextSpells for its third tab;
-- CombatTextTexts.lua holds the spells' settings (CT.SpellOwn...);
-- CombatTextStyle.lua matches your hits to your casts and draws a listed
-- spell's in its look. Agreed design: the Combat Text by Spell plan's
-- Spells tab (one line per spell, grouped by school; the Look tab as it is).
--
-- A line per spell on the list, under a heading for its school (Shadow,
-- Fire... Abilities, Heals, Your pet): its switch, icon and name (in its
-- color), then what's changed most right in the line: Color, Size, its
-- Crits' color and its Ticks (Same or Smaller, for spells that ticked);
-- More... opens its whole look (the Look panels' Color, Text, Place,
-- Motion), x takes it off the list. Gold values are its own, grey ones its
-- school's; a right-click on an own value gives it back. Right-click a
-- line: its switch. + Add a spell opens a list of the spells this
-- character has hit with, then the rest of the spellbook. The tab is a
-- container: off, every spell its school's look (CT.SpellsOn).

local _, ns = ...
ns.Module("style", function() -- (the rest of this file: only with Style loaded, Modules.lua)
local L = ns.L
local CT = ns.CombatTexts

local WIDTH, LINE_H, HEAD_H = 560, 24, 22
-- (Each part's place in a line, from its left.)
local X = { switch = 6, icon = 42, name = 64, color = 236, size = 282, crit = 346, ticks = 398, more = 466, remove = 532 }
local SIZES = { 0.6, 0.75, 0.9, 1, 1.15, 1.3, 1.5, 1.75, 2 }
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
-- (The older spellbook calls, on clients without C_SpellBook.)
local GetSpellBookItemInfo, HasPetSpells, BOOKTYPE_PET = _G.GetSpellBookItemInfo, _G.HasPetSpells, _G.BOOKTYPE_PET

local function DB() return ns.GetDB() or {} end
local function SpellKey(name, setting) return CT.Key(CT.SpellId(name), setting) end
local function Put(name, setting, value) ns.GetDB()[SpellKey(name, setting)] = value end
local function Own(name, setting) return DB()[SpellKey(name, setting)] end
local function Pct(value) return ("%d%%"):format(math.floor((tonumber(value) or 1) * 100 + 0.5)) end

-- A heading's name for the text a spell's hits are drawn as.
local function BaseLabel(base)
	if base == "spell" then return L["Spells and abilities"] end
	return CT.Label(base)
end
-- The base a spell from the Add list would go under (its info as seen).
local function BaseOfInfo(info)
	if not info then return nil end
	if info.kind == "heal" then return "heal" end
	if info.kind == "pet" then return "pet" end
	local school = tonumber(info.school)
	if school == 1 then return "ability" end
	return school and CT.SCHOOL_NODE[school] or nil
end

-- A spell's color, or its crits' (prefix "C"), set: all three its own, or
-- none where it's what it'd have anyway.
local function SetColor(name, prefix, r, g, b)
	local usual = prefix == "C" and CT.Color(CT.SpellId(name)) or CT.Color(CT.SpellBase(name))
	local same = math.abs(r - usual[1]) < 0.004 and math.abs(g - usual[2]) < 0.004 and math.abs(b - usual[3]) < 0.004
	Put(name, prefix .. "R", not same and r or nil)
	Put(name, prefix .. "G", not same and g or nil)
	Put(name, prefix .. "B", not same and b or nil)
end
local function ClearColor(name, prefix)
	for _, part in ipairs({ "R", "G", "B" }) do Put(name, prefix .. part, nil) end
end

-- Every spell of yours in your spellbook (and your pet's): { name, icon,
-- pet } each, by name. Retail and Forever's C_SpellBook, else the older
-- spellbook calls.
local function BookSpells()
	local list, seen = {}, {}
	local function Add(id, pet)
		-- (Not the auto attack: its swings are Swings, never a spell's. Run q62d6 listed "Attack".)
		if type(id) ~= "number" or id == 6603 then return end
		local name = ns.CombatTextSpellNameOf and ns.CombatTextSpellNameOf(id)
		if name and not seen[name] then
			seen[name] = true
			list[#list + 1] = { name = name, icon = ns.CombatTextSpellIconOf(id), pet = pet }
		end
	end
	if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
		pcall(function()
			local banks = Enum and Enum.SpellBookSpellBank
			local bank = banks and banks.Player or 0
			for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
				local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
				if info and not info.shouldHide then
					for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
						local item = C_SpellBook.GetSpellBookItemInfo(i, bank)
						if item and not item.isPassive and not item.isOffSpec then Add(item.spellID) end
					end
				end
			end
			local pets = C_SpellBook.HasPetSpells and C_SpellBook.HasPetSpells()
			if type(pets) == "number" and banks and banks.Pet then
				for i = 1, pets do
					local item = C_SpellBook.GetSpellBookItemInfo(i, banks.Pet)
					if item and not item.isPassive then Add(item.spellID, true) end
				end
			end
		end)
	elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemInfo then
		pcall(function()
			local book = BOOKTYPE_SPELL or "spell"
			for tab = 1, GetNumSpellTabs() do
				local _, _, offset, count = GetSpellTabInfo(tab)
				for i = (offset or 0) + 1, (offset or 0) + (count or 0) do
					local kind, id = GetSpellBookItemInfo(i, book)
					if kind == "SPELL" and not (IsPassiveSpell and IsPassiveSpell(i, book)) then Add(id) end
				end
			end
			local pets = HasPetSpells and HasPetSpells()
			if type(pets) == "number" then
				for i = 1, pets do
					local kind, id = GetSpellBookItemInfo(i, BOOKTYPE_PET or "pet")
					if (kind == "SPELL" or kind == "PETACTION") and id then Add(id, true) end
				end
			end
		end)
	end
	table.sort(list, function(a, b) return a.name < b.name end)
	return list
end
ns.CombatTextBookSpells = BookSpells -- (the test: what the Add list offers)

-- The Add list's entries: the spells you've hit with (most hits first),
-- then the spellbook's others; each { name, icon, info, hits, added }.
local function AddEntries(filter)
	filter = filter and filter:lower() or ""
	local function Fits(name) return filter == "" or name:lower():find(filter, 1, true) ~= nil end
	local hit, book, taken = {}, {}, {}
	for name, seen in pairs(CT.Seen()) do
		if type(seen) == "table" and Fits(name) then
			hit[#hit + 1] = { name = name, icon = seen.icon, hits = tonumber(seen.hits) or 0, added = CT.SpellInfo(name) ~= nil,
				info = { school = seen.school or seen.tickSchool, kind = seen.kind, icon = seen.icon, ticks = seen.ticks } }
			taken[name] = true
		end
	end
	table.sort(hit, function(a, b)
		if a.hits ~= b.hits then return a.hits > b.hits end
		return a.name < b.name
	end)
	for _, spell in ipairs(BookSpells()) do
		if not taken[spell.name] and Fits(spell.name) then
			book[#book + 1] = { name = spell.name, icon = spell.icon, added = CT.SpellInfo(spell.name) ~= nil,
				info = { kind = spell.pet and "pet" or "damage", icon = spell.icon, unknown = not spell.pet or nil } }
		end
	end
	return hit, book
end

-- A segment-style button (as the Quick settings'): lit warmer, gold words.
local function Segment(kit, parent, words, tip, width)
	local button = CreateFrame("Button", nil, parent)
	local back = button:CreateTexture(nil, "BACKGROUND")
	back:SetAllPoints()
	local under = button:CreateTexture(nil, "ARTWORK")
	under:SetPoint("BOTTOMLEFT")
	under:SetPoint("BOTTOMRIGHT")
	under:SetHeight(2)
	under:SetColorTexture(1, 0.82, 0, 1)
	local glow = button:CreateTexture(nil, "HIGHLIGHT")
	glow:SetAllPoints()
	glow:SetColorTexture(1, 1, 1, 0.07)
	local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("CENTER", 0, 1)
	text:SetText(words)
	button:SetSize(width or math.max(56, text:GetStringWidth() + 20), 22)
	button.searchLabel = words
	if tip then kit.Tooltip(button, tip) end
	button.Lit = function(_, on)
		back:SetColorTexture(on and 0.2 or 0.1, on and 0.17 or 0.1, on and 0.08 or 0.12, 0.95)
		under:SetShown(on)
		if on then text:SetTextColor(1, 0.82, 0) else text:SetTextColor(0.85, 0.85, 0.85) end
	end
	button:Lit(false)
	return button
end

-- A color swatch button: its color; own (gold edge) or its school's (grey).
local function Swatch(parent)
	local swatch = CreateFrame("Button", nil, parent)
	swatch:SetSize(30, 15)
	swatch:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local edge = swatch:CreateTexture(nil, "BORDER")
	edge:SetPoint("TOPLEFT", -1, 1)
	edge:SetPoint("BOTTOMRIGHT", 1, -1)
	local fill = swatch:CreateTexture(nil, "ARTWORK")
	fill:SetAllPoints()
	local glow = swatch:CreateTexture(nil, "HIGHLIGHT")
	glow:SetAllPoints()
	glow:SetColorTexture(1, 1, 1, 0.15)
	swatch.Paint = function(_, color, own)
		fill:SetColorTexture(color[1], color[2], color[3], own and 1 or 0.75)
		if own then edge:SetColorTexture(0.85, 0.7, 0.25, 1) else edge:SetColorTexture(0.3, 0.3, 0.3, 1) end
	end
	return swatch
end

-- (A value as words, for the Look panel's "As Shadow: 100%".)
local function MoveChoices()
	return {
		{ "up", L["Up"], L["Rises, as the game's."] },
		{ "down", L["Down"], L["Falls."] },
		{ "arcleft", L["Arc left"], L["Rises, curving left."] },
		{ "arcright", L["Arc right"], L["Rises, curving right."] },
		{ "fan", L["Fan out"], L["Curves left and right in turn."] },
		{ "stay", L["Stays"], L["Stays where it starts, then fades."] },
	}
end
local MOVE_WORDS = {}
local EDGE_WORDS
local function Words(setting, value)
	if not EDGE_WORDS then
		EDGE_WORDS = { game = L["The game's"], both = L["Edge and shadow"], edge = L["Dark edge"], none = L["None"] }
		for _, choice in ipairs(MoveChoices()) do MOVE_WORDS[choice[1]] = choice[2] end
	end
	if setting == "Font" then return value == "game" and L["The game's"] or ns.StyleFontName(value) end
	if setting == "Edge" then return EDGE_WORDS[value] or tostring(value) end
	if setting == "Move" then return MOVE_WORDS[value] or tostring(value) end
	if setting == "Start" then return value == "bar" and L["Over the bar"] or L["Over the name"] end
	if setting == "Pop" then return value and L["On"] or L["Off"] end
	if setting == "Ticks" then return value == "small" and L["Smaller"] or L["Same look"] end
	if setting == "Y" or setting == "X" then return ("%d px"):format(tonumber(value) or 0) end
	if type(value) == "number" then return ("%d%%"):format(math.floor(value * 100 + 0.5)) end
	return tostring(value)
end

-- Puts every spell's look and switch back (the list stays): the tab's
-- Reset and the page's.
function ns.ResetCombatTextSpells()
	for _, group in ipairs(CT.SpellGroups()) do
		for _, name in ipairs(group[2]) do
			CT.Reset(CT.SpellId(name))
			Put(name, "Show", nil)
		end
	end
end

-- The tab. kit, content, stack: the page's; preview: its preview (a line
-- touched plays that spell alone: ns.combatTextSpellFocus). Gives the
-- tab's heading (CombatTextPage.lua's Into puts it at the tab's top).
function ns.BuildCombatTextSpells(kit, content, stack, preview, changed)
	local function Changed()
		if changed then changed() end
		kit.Refresh()
	end
	local function Usable()
		local db = DB()
		return ns.StyleOn("combatTextStyle", db) and db.combatTextNumbers ~= false and CT.SpellsOn() and true or false
	end
	local box -- (the lines: below)
	-- (A spell picked on the tab: the preview plays it alone while the tab shows.)
	local focused
	ns.combatTextSpellFocus = function()
		if focused and box and box:IsVisible() and CT.SpellInfo(focused) then return CT.SpellId(focused) end
	end
	local function Focus(name)
		if focused == name then return end
		focused = name
		if preview and preview.Replay then preview.Replay() end
	end

	local top = stack:Header(content, L["Your spells"])
	stack:Note(content, L["Each spell starts out looking like its school on the Look tab. Change only what you want."], 520)

	-- The tools line: + Add a spell, Find a spell, Show All or Changed, Reset.
	local tools = CreateFrame("Frame", nil, content)
	tools:SetSize(WIDTH, 26)
	stack:Add(tools, "label")
	local add = ns.PanelButton(tools)
	add:SetText(L["+ Add a spell"])
	add:SetSize(120, 22)
	add:SetPoint("LEFT", tools, "LEFT", 0, 0)
	add.searchLabel = L["Add a spell"]
	kit.Tooltip(add, L["Lists the spells you've hit with, then the rest of your spellbook."])
	local find = ns.SkinEditBox(CreateFrame("EditBox", nil, tools, "InputBoxTemplate"))
	find:SetSize(150, 20)
	find:SetPoint("LEFT", add, "RIGHT", 14, 0)
	find:SetAutoFocus(false)
	find:SetMaxLetters(40)
	find.searchLabel = L["Find a spell"]
	find.noSettingId = true -- (a filter, not a setting)
	kit.Tooltip(find, L["Shows only the spells whose name has this in it. Press Enter to add a spell by its name."])
	local hint = find:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("LEFT", 2, 0)
	hint:SetText(L["Find a spell"])
	hint.searchSkip = true
	local showChanged = false
	local all = Segment(kit, tools, L["All"], L["Every spell on the list."], 60)
	local mine = Segment(kit, tools, L["Changed"], L["Only spells with a look of their own."], 72)
	mine:SetPoint("RIGHT", tools, "RIGHT", -96, 0)
	all:SetPoint("RIGHT", mine, "LEFT", -1, 0)
	local reset = ns.PanelButton(tools)
	reset:SetText(L["Reset"])
	reset:SetSize(86, 22)
	reset:SetPoint("RIGHT", tools, "RIGHT", 0, 0)
	kit.Tooltip(reset, L["Puts every spell's look back to its school's. The list stays."])

	-- The column heads.
	local heads = CreateFrame("Frame", nil, content)
	heads:SetSize(WIDTH, 16)
	stack:Add(heads, "label")
	for _, head in ipairs({ { "switch", L["Show"] }, { "name", L["Spell"] }, { "color", L["Color"] }, { "size", L["Size"] },
		{ "crit", L["Crits"] }, { "ticks", L["Ticks"] } }) do
		local label = kit.Label(heads, "GameFontDisableSmall", head[2])
		label:SetPoint("LEFT", heads, "LEFT", X[head[1]] - (head[1] == "switch" and 4 or 0), 0)
		label.searchSkip = true
	end

	box = CreateFrame("Frame", nil, content)
	box:SetSize(WIDTH, LINE_H)
	stack:Add(box, "label")
	local empty = kit.Label(box, "GameFontHighlightSmall",
		L["No spells yet. Click + Add a spell to give one a look of its own."])
	empty:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -4)
	empty:SetWidth(520)
	empty:SetJustifyH("LEFT")
	empty.searchSkip = true
	local count = CreateFrame("Frame", nil, content)
	count:SetSize(WIDTH, 22)
	stack:Add(count, "label")
	local countText = kit.Label(count, "GameFontDisableSmall", "")
	countText:SetPoint("LEFT", count, "LEFT", 4, 0)
	countText.searchSkip = true

	-- Its whole look (More...): the Look panels' tabs, each setting its
	-- school's until set here.
	local pops = {}
	local hidden = { Add = function(_, control)
		control:Hide()
		return control
	end }
	local function OpenLook(name)
		local id = CT.SpellId(name)
		if pops[name] then
			pops[name]:SetShown(not pops[name]:IsShown())
			return
		end
		local function Usual(setting) return (CT.Usual(id, setting)) end
		local function Counted(setting) return CT.PART_OF[setting] or CT.SPELL_EXTRA_OF[setting] end
		local styleRows = ns.StyleRows(kit, content, hidden, changed or function() end, "combatTextStyle", function(setting)
			if setting:find("^ct_") or setting:find("^combatText") then return setting end
			return CT.Field(id, setting)
		end)
		local info = CT.SpellInfo(name) or {}
		local button, pop = styleRows.Look("", name, {
			tabs = {
				default = function(setting) return Counted(setting) and Usual(setting) or nil end,
				usual = function(setting) return Words(setting, Usual(setting)), Usual(setting) end,
				source = function(setting)
					if not Counted(setting) then return nil end
					local own = CT.SpellOwn(name, setting) ~= nil
					local fromName
					if CT.SPELL_EXTRA_OF[setting] then
						fromName = setting == "Ticks" and L["As its hits"] or L["Its color"]
					else
						local from = select(2, CT.Get(CT.SpellBase(name), setting))
						fromName = from == "all" and L["The game's"] or (L["%s's"]):format(CT.Label(from))
					end
					return { text = own and L["This spell"] or fromName, own = own, parent = fromName, short = fromName }
				end,
				resolved = function(setting) return Usual(setting) end,
				color = function()
					local color = CT.Color(id)
					return color[1], color[2], color[3]
				end,
				copyKind = "combatText", copyName = name,
				resetLabel = function() return L["Clear this spell"] end,
			},
			groups = {
				{ "Color", { { "textColor", "Color" }, { "critColor", "Crit color" } } },
				{ "Text", { { "font", "Font" }, { "textSize", "Size" }, { "shadow", "Edge" }, { "ticks", "Ticks" } } },
				{ "Place", { { "place", "Place" } } },
				{ "Motion", { { "motion", "Motion" } } },
			},
			textColor = function(look)
				look.Section(L["Color"])
				look.Chips(L["Its color"], { "R", "G", "B" })
			end,
			critColor = function(look)
				look.Section(L["Its crits"])
				look.Chips(L["Its crits' color"], { "CR", "CG", "CB" })
			end,
			font = function(look)
				look.Section(L["Text"])
				look.Font("Font", L["The font for it."], nil, { "game", L["The game's"] })
			end,
			textSize = function(look)
				look.Slider("Size", L["Size"], 50, 300, 5, "%d%%", 100, L["How big it is compared to the game's."])
				look.Slider("CritScale", L["Crit size"], 100, 300, 5, "%d%%", 100, L["How big its crits are compared to its hits."])
				look.Slider("CastSize", L["Bigger per second of cast"], 0, 50, 5, "+%d%%", 100,
					L["Longer casts show bigger numbers, up to 150%; instants and unknown casts stay 100%."])
			end,
			shadow = function(look)
				look.Segments(L["Edge"], "Edge", {
					{ "game", L["The game's"], L["A dark shadow up and to the right, no edge."] },
					{ "both", L["Edge and shadow"], L["A dark edge and the drop shadow."] },
					{ "edge", L["Dark edge"] },
					{ "none", L["None"] },
				})
			end,
			-- (Only for a spell that has ticked: a DoT's, a channel's.)
			ticks = info.ticks and function(look)
				look.Section(L["Its ticks"])
				look.Segments(L["Ticks"], "Ticks", {
					{ "same", L["Same look"], L["Its ticks look like its hits."] },
					{ "small", L["Smaller"], L["Its ticks are three quarters of its hits' size."] },
				})
			end,
			place = function(look)
				look.Section(L["Place"])
				look.Pair(true)
				look.Slider("Y", L["Y offset"], -80, 150, 2, "%d px", nil, L["Moves it up or down."])
				look.Slider("X", L["X offset"], -150, 150, 2, "%d px", nil, L["Moves it left or right."])
				look.Pair(false)
				look.Segments(L["Starts"], "Start", {
					{ "name", L["Over the name"], L["Where the game's hits start."] },
					{ "bar", L["Over the bar"], L["Low over the health bar, where the game's crits sit."] },
				})
			end,
			motion = function(look)
				look.Section(L["Motion"])
				look.Segments(L["Moves"], "Move", MoveChoices())
				look.Pair(true)
				look.Slider("Climb", L["Climb"], 0, 300, 10, "%d%%", 100, L["How far it moves compared to the game's."])
				look.Slider("Time", L["Time on screen"], 30, 300, 10, "%d%%", 100, L["How long it stays compared to the game's."])
				look.Pair(false)
				look.Slider("CastTime", L["Longer per second of cast"], 0, 50, 5, "+%d%%", 100,
					L["Longer casts stay longer, up to 150%; instants and unknown casts stay 100%."])
				look.Slider("Fade", L["Fades from"], 10, 95, 5, "%d%%", 100, L["How far into its time on screen it starts to fade."])
				look.Segments(L["Pops in"], "Pop", { { true, L["On"], L["Grows big for a moment, then settles, like the game's crits."] },
					{ false, L["Off"] } })
			end,
		})
		if button then button:Hide() end
		pops[name] = pop
		pop:HookScript("OnShow", function() Focus(name) end)
		pop:Show()
	end
	ns.combatTextSpellLook = OpenLook -- (the test opens one)

	-- The lines, made as needed and kept (a pool), laid out in Layout.
	local lines, headings = {}, {}
	local function Flip(name)
		Put(name, "Show", Own(name, "Show") == false and nil or false)
		Changed()
	end
	local function MakeLine()
		local row = CreateFrame("Button", nil, box)
		row:SetSize(WIDTH, LINE_H)
		row:RegisterForClicks("RightButtonUp")
		row:SetScript("OnClick", function(self) if self.name and Usable() then Flip(self.name) end end)
		local band = row:CreateTexture(nil, "BACKGROUND")
		band:SetAllPoints()
		band:SetColorTexture(1, 1, 1, 0.03)
		row.band = band
		local switch = CreateFrame("Button", nil, row)
		switch:SetSize(26, 13)
		switch:SetPoint("LEFT", row, "LEFT", X.switch, 0)
		local track = switch:CreateTexture(nil, "ARTWORK")
		track:SetAllPoints()
		local knob = switch:CreateTexture(nil, "OVERLAY")
		knob:SetSize(9, 9)
		knob:SetColorTexture(0.95, 0.95, 0.95, 1)
		switch:SetScript("OnClick", function() if row.name and Usable() then Flip(row.name) end end)
		kit.Tooltip(switch, L["Shows this spell's numbers or not."])
		row.switch, row.track, row.knob = switch, track, knob
		local icon = row:CreateTexture(nil, "ARTWORK")
		icon:SetSize(16, 16)
		icon:SetPoint("LEFT", row, "LEFT", X.icon, 0)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		row.icon = icon
		local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		label:SetPoint("LEFT", row, "LEFT", X.name, 0)
		label:SetWidth(X.color - X.name - 8)
		label:SetJustifyH("LEFT")
		label:SetWordWrap(false)
		row.label = label
		local color = Swatch(row)
		color:SetPoint("LEFT", row, "LEFT", X.color, 0)
		kit.Tooltip(color, L["Its color. Right-click: its school's again."])
		color:SetScript("OnClick", function(_, button)
			local name = row.name
			if not (name and Usable()) then return end
			Focus(name)
			if button == "RightButton" then
				ClearColor(name, "")
				return Changed()
			end
			local now = CT.Color(CT.SpellId(name))
			ns.OpenColorPicker(now[1], now[2], now[3], function(r, g, b)
				SetColor(name, "", r, g, b)
				Changed()
			end)
		end)
		row.color = color
		local size = ns.PanelButton(row)
		size:SetSize(56, 20)
		size:SetPoint("LEFT", row, "LEFT", X.size, 0)
		size:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		kit.Tooltip(size, L["How big its numbers are. Right-click: its school's again."])
		size:SetScript("OnClick", function(self, button)
			local name = row.name
			if not (name and Usable()) then return end
			Focus(name)
			if button == "RightButton" then
				Put(name, "Size", nil)
				return Changed()
			end
			ns.ContextMenu(self, function(_, root)
				for _, each in ipairs(SIZES) do
					root:CreateButton(Pct(each), function()
						CT.Field(CT.SpellId(name), "Size").set(each)
						Changed()
					end)
				end
			end)
		end)
		row.size = size
		local crit = Swatch(row)
		crit:SetPoint("LEFT", row, "LEFT", X.crit, 0)
		kit.Tooltip(crit, L["Its crits' color: its color unless set. Right-click: its color again."])
		crit:SetScript("OnClick", function(_, button)
			local name = row.name
			if not (name and Usable()) then return end
			Focus(name)
			if button == "RightButton" then
				ClearColor(name, "C")
				return Changed()
			end
			local now = CT.SpellCritColor(name)
			ns.OpenColorPicker(now[1], now[2], now[3], function(r, g, b)
				SetColor(name, "C", r, g, b)
				Changed()
			end)
		end)
		row.crit = crit
		local ticks = ns.PanelButton(row)
		ticks:SetSize(62, 20)
		ticks:SetPoint("LEFT", row, "LEFT", X.ticks, 0)
		kit.Tooltip(ticks, L["Its ticks (a DoT's, a channel's): the same as its hits, or smaller."])
		ticks:SetScript("OnClick", function()
			local name = row.name
			if not (name and Usable()) then return end
			Focus(name)
			Put(name, "Ticks", Own(name, "Ticks") ~= "small" and "small" or nil)
			Changed()
		end)
		row.ticks = ticks
		local more = ns.PanelButton(row)
		more:SetSize(62, 20)
		more:SetPoint("LEFT", row, "LEFT", X.more, 0)
		more:SetText(L["More..."])
		kit.Tooltip(more, L["Every part of its look: its font, place and motion too."])
		more:SetScript("OnClick", function() if row.name then OpenLook(row.name) end end)
		more.opensLook = true
		row.more = more
		local remove = CreateFrame("Button", nil, row)
		remove:SetSize(18, 18)
		remove:SetPoint("LEFT", row, "LEFT", X.remove, 0)
		remove:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
		remove:SetHighlightTexture("Interface\\Buttons\\UI-StopButton", "ADD")
		kit.Tooltip(remove, L["Takes it off the list. Its numbers look like its school's again."])
		remove:SetScript("OnClick", function()
			local name = row.name
			if not (name and Usable()) then return end
			if pops[name] then pops[name]:Hide() end
			if focused == name then Focus(nil) end
			CT.RemoveSpell(name)
			Changed()
		end)
		row.remove = remove
		return row
	end
	local function MakeHeading()
		local head = CreateFrame("Frame", nil, box)
		head:SetSize(WIDTH, HEAD_H)
		local chip = head:CreateTexture(nil, "ARTWORK")
		chip:SetSize(10, 10)
		chip:SetPoint("LEFT", head, "LEFT", 4, -2)
		local label = head:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		label:SetPoint("LEFT", chip, "RIGHT", 6, 0)
		local note = head:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		note:SetPoint("LEFT", label, "RIGHT", 8, 0)
		head.chip, head.label, head.note = chip, label, note
		return head
	end
	local function PaintLine(row, name)
		local id = CT.SpellId(name)
		local info = CT.SpellInfo(name) or {}
		row.name = name
		row.switch.settingKey = SpellKey(name, "Show") -- (its id for /cine find)
		row.searchLabel = name
		local usable = Usable()
		local on = Own(name, "Show") ~= false
		local base = CT.SpellBase(name)
		local baseShows = CT.Shows(base, nil, true)
		local shows = on and baseShows
		row.track:SetColorTexture(on and 0.2 or 0.22, on and 0.55 or 0.22, on and 0.22 or 0.24, 1)
		row.knob:ClearAllPoints()
		row.knob:SetPoint(on and "RIGHT" or "LEFT", row.switch, on and "RIGHT" or "LEFT", on and -2 or 2, 0)
		row.icon:SetTexture(info.icon or QUESTION)
		row.icon:SetDesaturated(not shows)
		local color = CT.Color(id)
		row.label:SetText(name)
		local k = shows and 1 or 0.45
		row.label:SetTextColor(color[1] * k + (1 - k) * 0.5, color[2] * k + (1 - k) * 0.5, color[3] * k + (1 - k) * 0.5)
		row.color:Paint(color, Own(name, "R") ~= nil)
		row.crit:Paint(CT.SpellCritColor(name), Own(name, "CR") ~= nil)
		local ownSize = Own(name, "Size")
		row.size:SetText(Pct(CT.Get(id, "Size")))
		local sizeWords = row.size:GetFontString()
		if sizeWords then
			if ownSize ~= nil then sizeWords:SetTextColor(1, 0.82, 0) else sizeWords:SetTextColor(0.6, 0.6, 0.6) end
		end
		local ticksOwn = Own(name, "Ticks")
		row.ticks:SetText(info.ticks and (ticksOwn == "small" and L["Smaller"] or L["Same"]) or "-")
		local tickWords = row.ticks:GetFontString()
		if tickWords then
			if ticksOwn ~= nil then tickWords:SetTextColor(1, 0.82, 0) else tickWords:SetTextColor(0.6, 0.6, 0.6) end
		end
		local changedParts = CT.OwnParts(id)
		local moreWords = row.more:GetFontString()
		if moreWords then
			if #changedParts > 0 then moreWords:SetTextColor(1, 0.82, 0) else moreWords:SetTextColor(0.6, 0.6, 0.6) end
		end
		for _, control in ipairs({ row.switch, row.color, row.size, row.crit, row.more, row.remove }) do
			control:SetEnabled(usable)
		end
		row.ticks:SetEnabled(usable and info.ticks and true or false)
		row:SetAlpha(usable and 1 or 0.5)
	end
	-- Draws the list again: its headings and lines, the filter and Changed
	-- applied, then the page's height.
	local function Layout()
		local filter = (find:GetText() or ""):lower()
		local y, used, usedHeads, listed, own = 0, 0, 0, 0, 0
		for _, group in ipairs(CT.SpellGroups()) do
			local base, names = group[1], group[2]
			local shown = {}
			for _, name in ipairs(names) do
				listed = listed + 1
				local isOwn = #CT.OwnParts(CT.SpellId(name)) > 0 or Own(name, "Show") == false
				if isOwn then own = own + 1 end
				if (filter == "" or name:lower():find(filter, 1, true)) and (not showChanged or isOwn) then
					shown[#shown + 1] = name
				end
			end
			if #shown > 0 then
				usedHeads = usedHeads + 1
				local head = headings[usedHeads] or MakeHeading()
				headings[usedHeads] = head
				head:ClearAllPoints()
				head:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -y)
				head:Show()
				local color = CT.Color(base)
				head.chip:SetColorTexture(color[1], color[2], color[3], 1)
				head.label:SetText(BaseLabel(base))
				head.note:SetText(not CT.Shows(base, nil, true) and L["Off on the Look tab"] or "")
				y = y + HEAD_H
				for _, name in ipairs(shown) do
					used = used + 1
					local row = lines[used] or MakeLine()
					lines[used] = row
					row:ClearAllPoints()
					row:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -y)
					row:Show()
					row.band:SetShown(used % 2 == 0)
					PaintLine(row, name)
					y = y + LINE_H
				end
			end
		end
		for i = used + 1, #lines do
			lines[i]:Hide()
			lines[i].name = nil
		end
		for i = usedHeads + 1, #headings do headings[i]:Hide() end
		empty:SetShown(listed == 0)
		if listed > 0 and used == 0 then
			empty:SetText(L["No spells match."])
			empty:Show()
		else
			empty:SetText(L["No spells yet. Click + Add a spell to give one a look of its own."])
		end
		box:SetHeight(math.max(LINE_H, y))
		countText:SetText(listed > 0 and (L["%d spells, %d with a look of their own"]):format(listed, own) or "")
		local usable = Usable()
		add:SetEnabled(usable)
		find:SetEnabled(usable)
		reset:SetEnabled(usable and own > 0)
		all:Lit(not showChanged)
		mine:Lit(showChanged)
		hint:SetShown((find:GetText() or "") == "" and not find:HasFocus())
		if kit.FitContentHeight then
			kit.FitContentHeight(content)
			C_Timer.After(0, function() kit.FitContentHeight(content) end)
		end
	end
	box.Refresh = Layout
	kit.AddControl(box)
	box:HookScript("OnShow", Layout)
	all:SetScript("OnClick", function()
		showChanged = false
		Layout()
	end)
	mine:SetScript("OnClick", function()
		showChanged = true
		Layout()
	end)
	reset:SetScript("OnClick", function()
		ns.ResetCombatTextSpells()
		Changed()
	end)

	-- The Add list: a panel by the button, the spells you've hit with, then
	-- the spellbook's; a click adds one (the list stays open for more).
	local pick
	local function AddSpell(entry)
		CT.AddSpell(entry.name, entry.info)
		Focus(entry.name)
		Changed()
	end
	-- (Enter in Find a spell: a spell of yours by that name, added.)
	local function AddByName(text)
		text = text and text:match("^%s*(.-)%s*$") or ""
		if text == "" then return false end
		local lower = text:lower()
		local hit, book = AddEntries(nil)
		for _, set in ipairs({ hit, book }) do
			for _, entry in ipairs(set) do
				if entry.name:lower() == lower then
					if not entry.added then AddSpell(entry) end
					return true
				end
			end
		end
		return false
	end
	local function BuildPick()
		pick = CreateFrame("Frame", nil, UIParent)
		pick:SetSize(380, 380)
		pick:SetFrameStrata("DIALOG")
		pick:EnableMouse(true)
		pick:SetClampedToScreen(true)
		pick:Hide()
		local bg = pick:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetColorTexture(0.05, 0.05, 0.05, 0.97)
		local edge = pick:CreateTexture(nil, "BACKGROUND", nil, -1)
		edge:SetPoint("TOPLEFT", -1, 1)
		edge:SetPoint("BOTTOMRIGHT", 1, -1)
		edge:SetColorTexture(0.4, 0.4, 0.4, 1)
		local title = pick:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		title:SetPoint("TOPLEFT", 12, -10)
		title:SetText(L["Add a spell"])
		local close = ns.PanelButton(pick)
		close:SetSize(70, 20)
		close:SetPoint("TOPRIGHT", -8, -8)
		close:SetText(CLOSE or L["Close"])
		close:SetScript("OnClick", function() pick:Hide() end)
		local search = ns.SkinEditBox(CreateFrame("EditBox", nil, pick, "InputBoxTemplate"))
		search:SetSize(240, 20)
		search:SetPoint("TOPLEFT", 16, -38)
		search:SetAutoFocus(false)
		search:SetMaxLetters(40)
		local searchHint = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		searchHint:SetPoint("LEFT", 2, 0)
		searchHint:SetText(L["Search your spells"])
		local scroll = CreateFrame("ScrollFrame", nil, pick)
		scroll:SetPoint("TOPLEFT", 8, -66)
		scroll:SetPoint("BOTTOMRIGHT", -8, 8)
		local body = CreateFrame("Frame", nil, scroll)
		body:SetSize(360, 1)
		scroll:SetScrollChild(body)
		scroll:EnableMouseWheel(true)
		scroll:SetScript("OnMouseWheel", function(self, delta)
			local most = math.max(0, body:GetHeight() - self:GetHeight())
			self:SetVerticalScroll(math.min(most, math.max(0, self:GetVerticalScroll() - delta * 48)))
		end)
		local entries, seps = {}, {}
		local function Sep(i)
			local sep = seps[i]
			if not sep then
				sep = body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
				seps[i] = sep
			end
			return sep
		end
		local function Entry(i)
			local entry = entries[i]
			if entry then return entry end
			entry = CreateFrame("Button", nil, body)
			entry:SetSize(356, 24)
			local glow = entry:CreateTexture(nil, "HIGHLIGHT")
			glow:SetAllPoints()
			glow:SetColorTexture(1, 1, 1, 0.07)
			entry.icon = entry:CreateTexture(nil, "ARTWORK")
			entry.icon:SetSize(20, 20)
			entry.icon:SetPoint("LEFT", 6, 0)
			entry.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			entry.name = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			entry.name:SetPoint("LEFT", 32, 0)
			entry.name:SetWidth(170)
			entry.name:SetJustifyH("LEFT")
			entry.name:SetWordWrap(false)
			entry.school = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			entry.school:SetPoint("LEFT", 208, 0)
			entry.right = entry:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
			entry.right:SetPoint("RIGHT", -6, 0)
			entry:SetScript("OnClick", function(self)
				if self.data and not self.data.added and Usable() then AddSpell(self.data) end
			end)
			entries[i] = entry
			return entry
		end
		local function Fill()
			local hit, book = AddEntries(search:GetText())
			local y, used, usedSeps = 0, 0, 0
			for part, set in ipairs({ hit, book }) do
				if #set > 0 then
					usedSeps = usedSeps + 1
					local sep = Sep(usedSeps)
					sep:ClearAllPoints()
					sep:SetPoint("TOPLEFT", body, "TOPLEFT", 6, -y - 4)
					sep:SetText(part == 1 and L["Your spells that hit (this character)"] or L["Other spells in your spellbook"])
					sep:Show()
					y = y + 22
					for _, data in ipairs(set) do
						used = used + 1
						local entry = Entry(used)
						entry.data = data
						entry:ClearAllPoints()
						entry:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
						entry:Show()
						entry.icon:SetTexture(data.icon or QUESTION)
						entry.name:SetText(data.name)
						local base = BaseOfInfo(data.info)
						if base then
							local color = CT.Color(base)
							entry.school:SetText(BaseLabel(base))
							entry.school:SetTextColor(color[1], color[2], color[3])
						else
							entry.school:SetText(L["Not seen yet"])
							entry.school:SetTextColor(0.55, 0.55, 0.55)
						end
						entry.right:SetText(data.added and L["In the list"] or (data.hits and (L["%d hits"]):format(data.hits)) or "")
						entry:SetAlpha(data.added and 0.5 or 1)
						y = y + 24
					end
				end
			end
			for i = used + 1, #entries do entries[i]:Hide() end
			for i = usedSeps + 1, #seps do seps[i]:Hide() end
			if used == 0 then
				usedSeps = usedSeps + 1
				local sep = Sep(usedSeps)
				sep:ClearAllPoints()
				sep:SetPoint("TOPLEFT", body, "TOPLEFT", 6, -4)
				sep:SetText(L["No spells found."])
				sep:Show()
				y = 24
			end
			body:SetHeight(math.max(1, y))
			scroll:SetVerticalScroll(0)
			searchHint:SetShown((search:GetText() or "") == "" and not search:HasFocus())
		end
		pick.Fill = Fill
		search:SetScript("OnTextChanged", Fill)
		search:SetScript("OnEditFocusGained", function() searchHint:Hide() end)
		search:SetScript("OnEditFocusLost", function() searchHint:SetShown((search:GetText() or "") == "") end)
		search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
		search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
		pick:SetScript("OnShow", Fill)
		-- (The page going away takes it too.)
		content:HookScript("OnHide", function() pick:Hide() end)
		ns.combatTextSpellPick = pick -- (the test reads it)
	end
	add:SetScript("OnClick", function(self)
		if not pick then BuildPick() end
		if pick:IsShown() then return pick:Hide() end
		pick:ClearAllPoints()
		pick:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -4)
		pick:Show()
	end)
	-- (A spell added or removed elsewhere: the open list again.)
	local refreshPick = CreateFrame("Frame", nil, tools)
	refreshPick.Refresh = function() if pick and pick:IsShown() then pick.Fill() end end
	kit.AddControl(refreshPick)
	find:SetScript("OnTextChanged", function() Layout() end)
	find:SetScript("OnEditFocusGained", function() hint:Hide() end)
	find:SetScript("OnEditFocusLost", function() hint:SetShown((find:GetText() or "") == "") end)
	find:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	find:SetScript("OnEnterPressed", function(self)
		if AddByName(self:GetText()) then self:SetText("") end
		self:ClearFocus()
	end)
	-- (The test: the tab's parts.)
	ns.combatTextSpellsTab = { box = box, tools = tools, add = add, lines = lines, headings = headings, Layout = Layout }
	return top
end
end) -- (ns.Module "style")
