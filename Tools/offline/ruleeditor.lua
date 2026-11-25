-- The CQL rule editor, redesigned (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/ruleeditor.lua < /dev/null
-- Tools/rule-editor-redesign-plan.md (2026-11-25), UI/RuleEditor.lua and UI/RuleCatalog.lua.
-- On the stand-in game, Forever then retail, with real layout (widths kept, text 6 px a
-- letter, points kept):
--   the catalog: every word the rules know is offered once (or knowingly left out), each
--     offered word reads; retail's words only on retail, the Focus unit only with a focus
--     frame; the Tooltip category only on a tooltip row, Entering/Leaving only on fight rows;
--   the window: 600 x 600 whatever is shown; every category and unit fits its pane without
--     scrolling; no word past the pane's right edge, none on another; the sidebar fits;
--   inserting: spacing, AND by itself after a word, OR in place of that AND, Shift adds NOT,
--     a bracket; Undo and Redo; Clear;
--   typing: suggestions for "ta", "dps", "stun", Tab takes one, Escape closes the list,
--     Enter takes one or closes the editor, no new lines;
--   search: finds by label, word and alias; Enter adds the first;
--   the readout: a chip per word, true or false as the facts say; the verdict as the rule
--     reads; an error in its place; value words by name;
--   the dots, the In this rule outline, True here and In this rule lists; the remembered
--     category and unit.
-- luacheck: push ignore 111 112 113 121 122 212 431
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local function RunClient(client)
	print("== " .. client)
	local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
	local M = wow.Methods
	-- Real-enough layout: sizes kept, text 6 px a letter, a point kept per anchor.
	M.SetWidth = function(self, w) self._w = w end
	M.GetWidth = function(self) return self._w or 0 end
	M.SetHeight = function(self, h) self._h = h end
	M.GetHeight = function(self) return self._h or 0 end
	M.SetSize = function(self, w, h) self._w, self._h = w, h end
	M.GetStringWidth = function(self)
		local text = tostring(self._text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
		return #text * 6
	end
	M.SetText = function(self, text)
		self._text = text
		self._cur = #tostring(text or "") -- (as the game: the cursor to the end)
	end
	M.GetText = function(self) return self._text end
	M.SetCursorPosition = function(self, p) self._cur = p end
	M.GetCursorPosition = function(self) return self._cur or #tostring(self._text or "") end
	M.SetFocus = function(self) self._focus = true end
	M.ClearFocus = function(self) self._focus = false end
	M.HasFocus = function(self) return self._focus == true end
	M.SetEnabled = function(self, on) self._off = not on end
	M.Enable = function(self) self._off = false end
	M.Disable = function(self) self._off = true end
	M.IsEnabled = function(self) return not self._off end
	-- (Hiding runs OnHide, as the game's does: the editor's closing hands the rule back then.)
	local hide = M.Hide
	M.Hide = function(self)
		local was = self._shown ~= false
		hide(self)
		local fn = was and self._scripts and self._scripts.OnHide
		if fn then fn(self) end
	end
	M.SetTexture = function(self, t) self._tex = t end
	M.GetTexture = function(self) return self._tex end
	-- (Each button once: the editor keeps a word's button under two keys.)
	local function ShownWords(editor)
		local seen, n = {}, 0
		for _, b in pairs(editor.wordButtons) do
			if b:IsShown() and not seen[b] then seen[b], n = true, n + 1 end
		end
		return n
	end
	M.ClearAllPoints = function(self) self._at = nil end
	M.SetPoint = function(self, point, rel, relPoint, x, y)
		if type(rel) == "number" then x, y, rel = rel, relPoint, nil end
		if point == "TOPLEFT" and (rel == nil or type(rel) == "table") then
			self._at = { x = x or 0, y = y or 0, rel = rel }
		end
	end
	local now = 100
	GetTime = function() return now end
	local shift = false
	IsShiftKeyDown = function() return shift end
	IsControlKeyDown = function() return false end
	-- The facts where you stand, as the rows' would be.
	local facts = { combat = false, nocombat = true, world = true, rain = true, day = true, npc = true, friendly = true,
		target = true, warlock = true, pet = true, outdoors = true }
	ns.RuleFactsFor = function() return facts end
	ns.db.ruleEditorCat, ns.db.ruleEditorUnit = nil, nil

	-- 1. The catalog.
	local offered, twice = {}, {}
	for _, ctx in ipairs({ "row", "tooltip", "edge" }) do
		local seen = {}
		for _, it in ipairs(ns.RuleCatalogWords(ctx)) do
			local key = (it.unit and it.unit.key or "") .. "|" .. it.entry.w
			if seen[key] then twice[#twice + 1] = ctx .. ":" .. key end
			seen[key] = true
			offered[it.entry.w] = true
		end
	end
	Check("catalog: no word twice in a context", #twice == 0, table.concat(twice, ", "))
	local unreadable = {}
	for word in pairs(offered) do
		if word:find(":$") then
			if not (ns.RULE_AXES and ns.RULE_AXES[word:sub(1, -2)]) then unreadable[#unreadable + 1] = word end
		elseif not ns.CompileRule(word) then
			unreadable[#unreadable + 1] = word
		end
	end
	Check("catalog: every offered word reads", #unreadable == 0, table.concat(unreadable, ", "))
	-- Every field the rules know, offered by some word (some knowingly not: aliases' fields
	-- are covered by their word; old kind words, the cam_ words (camera: now), always/never,
	-- classes and retail-only words this client doesn't have).
	local OUT = { always = true, never = true, enemyplayer = true, hostilenpc = true, neutralplayer = true,
		neutralnpc = true, friendlyplayer = true, friendlynpc = true, hoverenemyplayer = true, hoverhostilenpc = true,
		hoverneutralplayer = true, hoverneutralnpc = true, hoverfriendlyplayer = true, hoverfriendlynpc = true }
	local offeredFields = {}
	for word in pairs(offered) do if ns.RULE_WORDS[word] then offeredFields[ns.RULE_WORDS[word]] = true end end
	local missing = {}
	for _, field in pairs(ns.RULE_WORDS) do
		local skip = OUT[field] or field:find("^cam_") or (field:find("^focus") and _G.FocusFrame == nil)
			or ({ warrior = 1, paladin = 1, hunter = 1, rogue = 1, priest = 1, deathknight = 1, shaman = 1, mage = 1,
				warlock = 1, monk = 1, druid = 1, demonhunter = 1, evoker = 1 })[field]
			or (not ns.isRetail and ({ gliding = 1, battleground = 1, arena = 1, warmode = 1, delve = 1, mythicplus = 1,
				housing = 1 })[field])
			or (not (C_Weather and C_Weather.GetCurrentWeather) and ({ rain = 1, snow = 1, sandstorm = 1, storm = 1,
				weather = 1 })[field])
			or (C_GamePad == nil and field == "gamepad")
		if not skip and not offeredFields[field] and not missing[field] then
			missing[field] = true
			missing[#missing + 1] = field
		end
	end
	table.sort(missing)
	Check("catalog: every word the rules know is offered", #missing == 0, table.concat(missing, ", "))
	local retailWords = { "gliding", "warmode", "delve", "mythicplus", "housing", "battleground", "arena" }
	local found = {}
	for _, w in ipairs(retailWords) do if offered[w] then found[#found + 1] = w end end
	Check("catalog: retail's words only on retail (" .. client .. ")",
		(#found == #retailWords) == (client == "retail") and (#found == 0) == (client ~= "retail"), table.concat(found, ", "))
	local cats = {}
	for _, cat in ipairs(ns.RuleCatalog()) do cats[cat.key] = cat end
	local units = {}
	for _, unit in ipairs(cats.units.units) do units[unit.key] = unit end
	Check("catalog: Target and Mouse units; Focus with a focus frame (" .. tostring(_G.FocusFrame ~= nil) .. ")",
		units.target and units.hover and ((units.focus ~= nil) == (_G.FocusFrame ~= nil)))
	local function InContext(ctx, word)
		for _, it in ipairs(ns.RuleCatalogWords(ctx)) do if it.entry.w == word then return true end end
		return false
	end
	Check("catalog: tipenemy only on the Tooltips row", InContext("tooltip", "tipenemy") and not InContext("row", "tipenemy"))
	Check("catalog: entering only on fight rows", InContext("edge", "entering") and not InContext("row", "entering"))
	Check("catalog: context by key", ns.RuleEditorContext({ key = "tooltip:All" }) == "tooltip"
		and ns.RuleEditorContext({ key = "card:combatIn" }) == "edge" and ns.RuleEditorContext({ key = "minimap" }) == "row"
		and ns.RuleEditorContext({ key = "minimap", context = "trigger" }) == "trigger")

	-- 1b. One name per thing (2026-11-25, the user: "the show in row says location but our cql
	-- says place"): the grids' headings are the editor's categories, and each word the grids'
	-- dropdowns offer has the grids' name for it, in the category of that heading.
	local L = ns.L
	Check("names: the grids' Combat heading is the editor's Combat", cats.fight.name == L["Combat"], cats.fight.name)
	Check("names: the grids' Location heading is the editor's Location", cats.place.name == L["Location"], cats.place.name)
	Check("names: the grids' Target heading is the Units' Target", units.target.label == L["Target"], units.target.label)
	local GRID_NAMES = { combat = { L["In combat"], "fight" }, nocombat = { L["Out of combat"], "fight" },
		calm = { L["Calm Timer"], "fight" }, camera = { L["In a camera mode"], "camera" },
		enemy = { L["Enemy targeted"], "units" }, friendly = { L["Friend targeted"], "units" } }
	local PLACE_WORDS = { bgShow = "bg", worldShow = "world", cityShow = "city", groupShow = "group", instanceShow = "instance" }
	for _, place in ipairs(ns.PLACE_SHOW or {}) do
		GRID_NAMES[PLACE_WORDS[place.list]] = { place.label, "place" }
	end
	local named = {}
	for _, it in ipairs(ns.RuleCatalogWords("row")) do
		if not it.unit or it.unit.key == "target" then named[it.entry.w] = { it.entry.l, it.cat.key } end
	end
	local differ = {}
	for word, want in pairs(GRID_NAMES) do
		local got = named[word]
		if not got or got[1] ~= want[1] or got[2] ~= want[2] then
			differ[#differ + 1] = ("%s: grid %q in %s, editor %q in %s"):format(word, want[1], want[2],
				tostring(got and got[1]), tostring(got and got[2]))
		end
	end
	table.sort(differ)
	Check("names: every grid dropdown item has the grid's name, under its heading", #differ == 0,
		table.concat(differ, "; "))
	Check("names: the target's words name it once (\"Enemy targeted\", not \"Target: Enemy targeted\")",
		ns.RuleWordName({ entry = { l = L["Enemy targeted"], named = true }, unit = units.target }) == L["Enemy targeted"])

	-- 2. The window.
	local text, closed = "", nil
	local function Open(key, rule, extra)
		text, closed = rule or "", nil
		local t = { key = key, label = "Enemy players", grid = extra and extra.grid,
			Text = function() return text end, SetText = function(s) text = s end, Close = function(s) closed = s end }
		for k, v in pairs(extra or {}) do t[k] = v end
		ns.OpenRuleEditor(t)
		return _G.CinematicRuleEditor
	end
	local editor = Open("minimap", "combat and hostile and player")
	Check("window: opens", editor ~= nil and editor:IsShown())
	local box = editor.box
	Check("window: 600 x 600", editor:GetWidth() == 600 and editor:GetHeight() == 600,
		editor:GetWidth() .. " x " .. editor:GetHeight())
	local PANE_W = 600 - 28 - 132 - 4
	local PANE_H = 600 - 38 - 62 - 6 - 20 - 6 - 50 - 22 - 40 - 2
	-- The pane as shown: its buttons in its width, none on another, its height in the room.
	local function PaneLook(what)
		local rects, bad, past = {}, {}, {}
		for _, b in pairs(editor.wordButtons) do
			if b:IsShown() and b._at and b._at.rel == editor.pane then
				local r = { x = b._at.x, y = -b._at.y, w = b:GetWidth(), h = 20, name = b.it.entry.w }
				if r.x + r.w > PANE_W - 10 then past[#past + 1] = r.name end
				for _, o in ipairs(rects) do
					if r.x < o.x + o.w and o.x < r.x + r.w and r.y < o.y + o.h and o.y < r.y + r.h and o.name ~= r.name then
						bad[#bad + 1] = r.name .. "/" .. o.name
					end
				end
				rects[#rects + 1] = r
			end
		end
		local h = editor.pane:GetHeight()
		Check(("%s: %d words, none past the right edge"):format(what, #rects), #past == 0, table.concat(past, ", "))
		Check(("%s: none on another"):format(what), #bad == 0, table.concat(bad, ", "))
		return rects, h
	end
	for _, cat in ipairs(ns.RuleCatalog()) do
		if not cat.only then
			if cat.units then
				for _, unit in ipairs(cat.units) do
					editor.ShowCategory("units", unit.key)
					local _, h = PaneLook("pane Units/" .. unit.key)
					Check(("pane Units/%s fits without scrolling (%d of %d)"):format(unit.key, h, PANE_H), h <= PANE_H)
				end
			else
				editor.ShowCategory(cat.key)
				local rects, h = PaneLook("pane " .. cat.key)
				Check(("pane %s fits without scrolling (%d of %d)"):format(cat.key, h, PANE_H), h <= PANE_H and #rects > 0)
			end
		end
	end
	Check("window: still 600 x 600 after every category", editor:GetWidth() == 600 and editor:GetHeight() == 600)
	local shownCats, lowest = 0, 0
	for _, b in ipairs(editor.catButtons) do
		if b:IsShown() then
			shownCats = shownCats + 1
			lowest = math.max(lowest, -(b._at and b._at.y or 0) + 20)
		end
	end
	Check(("sidebar: %d entries fit (%d of %d)"):format(shownCats, lowest + 32, PANE_H + 2), lowest + 32 <= PANE_H + 2)

	-- 3. Inserting.
	local function SetRule(s) editor.SetRuleText(s, #s) end
	SetRule("")
	editor.Insert("combat")
	editor.Insert("hostile")
	Check("insert: AND by itself after a word", box:GetText() == "combat and hostile", box:GetText())
	SetRule("combat")
	editor.Insert("hostile")
	editor.Insert("or")
	Check("insert: OR right after the added AND takes its place",
		box:GetText() == "combat or hostile" or box:GetText() == "combat and hostile or", box:GetText())
	SetRule("combat")
	editor.state.autoAnd = nil
	editor.Insert("or")
	editor.Insert("calm")
	Check("insert: OR typed after a word stays; no AND after OR", box:GetText() == "combat or calm", box:GetText())
	SetRule("combat and not")
	editor.Insert("calm")
	Check("insert: no AND after NOT", box:GetText() == "combat and not calm", box:GetText())
	SetRule("combat and (")
	editor.Insert("calm")
	Check("insert: no AND after (", box:GetText() == "combat and (calm", box:GetText())
	SetRule("")
	shift = true
	editor.ShowCategory("doing")
	editor.wordButtons["talking"]:GetScript("OnClick")(editor.wordButtons["talking"])
	shift = false
	Check("insert: Shift-click adds it with NOT", box:GetText() == "not talking", box:GetText())
	editor.Insert("(")
	Check("insert: a bracket after a word gets AND", box:GetText() == "not talking and (", box:GetText())
	editor.Undo()
	Check("undo: back one change", box:GetText() == "not talking", box:GetText())
	editor.Redo()
	Check("redo: forward again", box:GetText() == "not talking and (", box:GetText())
	Check("readout: a ( without ) is an error, Done off", not editor.done:IsEnabled())
	Check("readout: the error said", tostring(editor.verdict:GetText()):find("Not finished", 1, true) ~= nil,
		editor.verdict:GetText())

	-- 4. Typing: suggestions, keys.
	local function Type(s)
		box:SetText(s)
		box:SetCursorPosition(#s)
		box:GetScript("OnTextChanged")(box, true)
	end
	Type("combat and ta")
	local list = editor.state.sugg
	Check("suggest: \"ta\" lists words", #list > 0 and editor.sugg:IsShown(), #list)
	local firsts = {}
	for i = 1, math.min(3, #list) do firsts[i] = list[i].entry.w end
	Check("suggest: \"ta\" starts with words that start with it", list[1] and list[1].entry.w:sub(1, 2) == "ta",
		table.concat(firsts, ", "))
	box:GetScript("OnTabPressed")(box)
	Check("suggest: Tab takes the first", box:GetText() == "combat and " .. firsts[1], box:GetText())
	Check("suggest: the list closes after", not editor.sugg:IsShown())
	local function First(q) local m = editor.Matches(q, 3) return m[1] and m[1].entry.w end
	Check("suggest: dps -> damage", First("dps") == "damage", First("dps"))
	Check("suggest: stun -> controlled", First("stun") == "controlled", First("stun"))
	Check("suggest: buff -> aura:", First("buff") == "aura:", First("buff"))
	Check("suggest: corpse -> a dead word", (First("corpse") or ""):find("dead") ~= nil, First("corpse"))
	Type("combat and ta")
	box:GetScript("OnEscapePressed")(box)
	Check("keys: Escape closes the list first", not editor.sugg:IsShown() and editor:IsShown())
	Type("combat\n")
	Check("keys: no new lines in a rule", not box:GetText():find("\n"), box:GetText())
	Type("combat")
	box:GetScript("OnEnterPressed")(box)
	Check("keys: Enter with no list closes it, keeping the rule", not editor:IsShown() and closed == "combat", closed)

	-- 5. Search.
	editor = Open("minimap", "")
	local function Find(q)
		editor.SetFind(q)
		editor.find:GetScript("OnTextChanged")(editor.find, true) -- (the game fires it on SetText)
	end
	Find("dps")
	local damage = editor.wordButtons["damage"]
	Check("search: dps shows Damage", damage and damage:IsShown())
	local shownN = ShownWords(editor)
	Check("search: only what matches", shownN >= 1 and shownN <= 4, shownN)
	editor.find:GetScript("OnEnterPressed")(editor.find)
	Check("search: Enter adds the first", box:GetText() == "damage", box:GetText())
	Find("yards")
	Check("search: yards finds the distance words", ShownWords(editor) >= 3, ShownWords(editor))
	Find("")

	-- 6. The readout.
	editor = Open("minimap", "nocombat and rain and not hostile")
	local chips, yes = 0, 0
	for _, c in ipairs(editor.chips) do
		if c:IsShown() then
			chips = chips + 1
			if c.icon:GetTexture() == "Interface\\RaidFrame\\ReadyCheck-Ready" then yes = yes + 1 end
		end
	end
	Check("readout: a chip per word (3)", chips == 3, chips)
	Check("readout: two true here (nocombat, rain), hostile false", yes == 2, yes)
	Check("readout: the verdict as the rule reads (shown)", tostring(editor.verdict:GetText()):find("Shown", 1, true) ~= nil,
		editor.verdict:GetText())
	facts.rain = false
	editor.Refresh()
	Check("readout: follows the facts (hidden now)", tostring(editor.verdict:GetText()):find("Hidden", 1, true) ~= nil,
		editor.verdict:GetText())
	facts.rain = true
	editor = Open("minimap", "combat and nosuchword")
	local red = false
	for _, c in ipairs(editor.chips) do
		if c:IsShown() and tostring(c.text:GetText()):find("nosuchword") then red = true end
	end
	Check("readout: an unknown word is a chip of its own", red)
	Check("readout: and the verdict is the error", tostring(editor.verdict:GetText()):find("isn't a word", 1, true) ~= nil,
		editor.verdict:GetText())

	-- 7. Dots, In this rule, True here, the lists, remembered.
	editor = Open("minimap", "rain")
	editor.ShowCategory("world")
	local rain = editor.wordButtons["rain"]
	if rain then
		Check("dots: Rain true here, its dot on", rain.dot:IsShown())
		Check("in rule: Rain outlined (in the rule)", rain.fill and true)
	end
	local snow = editor.wordButtons["snow"]
	if snow then Check("dots: Snow false here, no dot", not snow.dot:IsShown()) end
	editor.ShowCategory("here")
	local any = ShownWords(editor)
	Check("True here: the true words shown", any >= 5, any)
	editor.ShowCategory("rule")
	any = ShownWords(editor)
	Check("In this rule: its one word", any == 1, any)
	-- (A sidebar click remembers it; a unit too.)
	for _, b in ipairs(editor.catButtons) do
		if b.key == "travel" then b:GetScript("OnClick")(b) end
	end
	Check("remembered: the category", ns.db.ruleEditorCat == "travel", ns.db.ruleEditorCat)
	editor.ShowCategory("units")
	for _, b in ipairs(editor.unitButtons) do
		if b.unit == "hover" then b:GetScript("OnClick")(b) end
	end
	Check("remembered: the unit", ns.db.ruleEditorUnit == "hover", ns.db.ruleEditorUnit)
	Check("units: Mouse shows hover words", editor.wordButtons["hoverhostile"] and editor.wordButtons["hoverhostile"]:IsShown())
	editor.wordButtons["hoverhostile"]:GetScript("OnClick")(editor.wordButtons["hoverhostile"])
	Check("units: Mouse's Hostile inserts hoverhostile", box:GetText() == "rain and hoverhostile", box:GetText())
	editor = Open("minimap", "")
	Check("remembered: opens on the last category clicked, and unit",
		editor.state.cat == "travel" and editor.state.unit == "hover", editor.state.cat .. "/" .. editor.state.unit)
	-- (Contexts: the Tooltip category on the Tooltips row only.)
	local function HasCat(key)
		for _, b in ipairs(editor.catButtons) do if b:IsShown() and b.key == key then return true end end
		return false
	end
	Check("context: no Tooltip category on a row", not HasCat("tip"))
	editor = Open("tooltip:All", "hoverdead")
	Check("context: Tooltip category on the Tooltips row", HasCat("tip"))
	-- (The grid note and Reset to grid, on a grid row.)
	editor = Open("minimap", "combat or calm", { grid = { combat = true, calm = true, nocombat = true } })
	editor.Refresh()
	Check("grid: a rule the dropdowns can show, no Reset to grid", not editor.resetGrid:IsShown())
	editor.SetRuleText("combat and calm", 15)
	Check("grid: one they can't, Reset to grid shown", editor.resetGrid:IsShown())
	editor:Hide()
end

RunClient("forever")
RunClient("retail")
-- luacheck: pop
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
