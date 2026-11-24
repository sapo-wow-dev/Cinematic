-- The rule editor opened with only what it needs (offline, Lua 5.1 via
-- Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/ruleeditortarget.lua < /dev/null
-- 2026-11-23 a stand-in target without SetText (Dev/AtmosphereTest.lua) made
-- typing raise "GridRows.lua:404: attempt to call a nil value" in Changed().
-- The editor needs label, Text and Close only; SetText and ResetToGrid are
-- called when there. Tools/errors/known.lua: rule-editor-optional-callback.
-- Types into the real editor and clicks Reset to grid, both clients, with a
-- bare target and a full one. PASS or FAIL per check.
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

-- The editor's EditBox (its only one), found among its frames.
local function FindBox(frame)
	for _, child in ipairs({ frame:GetChildren() }) do
		if child:GetObjectType() == "EditBox" then return child end
		local found = FindBox(child)
		if found then return found end
	end
end
-- Its Reset to grid button: the button whose OnClick calls ResetToGrid.
local function FindReset(frame)
	for _, child in ipairs({ frame:GetChildren() }) do
		if child.GetText and child:GetText() == "Reset to grid" then return child end
		local found = FindReset(child)
		if found then return found end
	end
end

-- The lines capped at two rows (2026-11-24, the user: "our list is getting
-- too long"): a closed line shows two rows and a +N with the count behind
-- it, kept clear of the right edge; +N opens it (Fewer, every word shown,
-- the open state kept per line) and Fewer closes it; a word in the rule
-- comes out from behind; the +N's dot is on for a true word behind it;
-- lines that fit have none; the Tooltip line only on a tooltip row.
-- Buttons placed and sized for real here: widths kept, text 6 px a letter.
local function CapChecks(ns, wow)
	local M = wow.Methods
	M.SetWidth = function(self, w) self._w = w end
	M.GetWidth = function(self) return self._w or 100 end
	M.SetHeight = function(self, h) self._h = h end
	M.GetHeight = function(self) return self._h or 20 end
	M.GetStringWidth = function(self)
		local text = tostring(self._text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
		return #text * 6
	end
	-- (A button's label: its font string, which its SetText fills.)
	M.SetFontString = function(self, fs) self._fs = fs end
	M.GetFontString = function(self) return self._fs end
	M.SetText = function(self, text)
		self._text = text
		if self._fs then self._fs._text = text end
	end
	M.ClearAllPoints = function(self) self._at = nil end
	M.SetPoint = function(self, _, rel, relPoint, x, y)
		if type(rel) == "number" then x, y = rel, relPoint end
		self._at = { x = x or 0, y = y or 0 }
	end
	ns.db.ruleEditorOpen = {}
	local facts = {}
	local realFacts = ns.RuleFactsFor
	ns.RuleFactsFor = function() return facts end
	local rule = ""
	local function Open(key)
		ns.OpenRuleEditor({ key = key, label = "Cap", Text = function() return rule end, SetText = function() end,
			Close = function() end })
	end
	Open("minimap")
	local editor = _G.CinematicRuleEditor
	local lines = editor and editor.lines
	Check("cap: the editor's lines there", type(lines) == "table" and #lines > 5)
	if type(lines) ~= "table" then ns.RuleFactsFor = realFacts return end
	local RIGHT = 560 - 28
	local function Line(key)
		for _, line in ipairs(lines) do if line.key == key then return line end end
	end
	-- Rows a line uses now (its shown buttons' y), and its widest right edge.
	local function Look(line)
		local ys, rows, edge, shown = {}, 0, 0, 0
		local function Note(button)
			if not (button:IsShown() and button._at) then return end
			if not ys[button._at.y] then ys[button._at.y], rows = true, rows + 1 end
			edge = math.max(edge, button._at.x + button:GetWidth())
		end
		for _, piece in ipairs(line.pieces) do
			if piece.button:IsShown() then shown = shown + 1 end
			Note(piece.button)
		end
		if line.more then Note(line.more) end
		return rows, edge, shown
	end
	local target, mouse = Line("enemy"), Line("hover")
	Check("cap: Target and Mouse over lines found", target ~= nil and mouse ~= nil)
	if not (target and mouse) then ns.RuleFactsFor = realFacts return end
	local editorClosed = editor:GetHeight()
	for _, line in ipairs({ target, mouse }) do
		local rows, edge, shown = Look(line)
		local label = tostring(line.more and line.more:GetText() or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
		Check(("cap %s: closed, two rows (%d)"):format(line.key, rows), rows == 2)
		Check(("cap %s: nothing past the right edge (%d of %d)"):format(line.key, edge, RIGHT), edge <= RIGHT)
		Check(("cap %s: +N counts what's behind it (%s, %d hidden)"):format(line.key, label, #line.hidden),
			#line.hidden > 0 and label == "+" .. #line.hidden and line.more:IsShown())
		Check(("cap %s: shown + hidden = all (%d + %d of %d)"):format(line.key, shown, #line.hidden, #line.pieces),
			shown + #line.hidden == #line.pieces)
	end
	-- Target's first words stay in front (the most used).
	local front = {}
	for i = 1, 3 do front[i] = target.pieces[i].button:IsShown() end
	Check("cap: Enemy, Friend and Anything targeted shown closed", front[1] and front[2] and front[3])
	Check("cap: On a unit frame shown closed (Mouse over)", mouse.pieces[6].field == "hoverframe"
		and mouse.pieces[6].button:IsShown())
	-- Open: every word, Fewer, kept.
	target.more:GetScript("OnClick")(target.more)
	local _, edge, shown = Look(target)
	local label = tostring(target.more:GetText() or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	Check("cap: +N opens the line (every word shown)", shown == #target.pieces, shown)
	Check("cap: open, it reads Fewer", label == ns.L["Fewer"], label)
	Check("cap: open, nothing past the right edge", edge <= RIGHT, edge)
	Check("cap: the open state kept", ns.db.ruleEditorOpen.enemy == true)
	Check("cap: open, the editor taller", editor:GetHeight() > editorClosed,
		("%s vs %s"):format(tostring(editor:GetHeight()), tostring(editorClosed)))
	Open("minimap")
	Check("cap: still open when the editor opens again", select(3, Look(target)) == #target.pieces)
	target.more:GetScript("OnClick")(target.more)
	Check("cap: Fewer closes it", #target.hidden > 0 and ns.db.ruleEditorOpen.enemy == nil)
	-- A word in the rule comes out from behind the +N.
	local behind = target.hidden[#target.hidden]
	local word
	for w, field in pairs(ns.RULE_WORDS) do if field == behind.field and w == field then word = w end end
	local count = #target.hidden
	rule = "combat and " .. tostring(word)
	Open("minimap")
	Check(("cap: \"%s\" in the rule is shown, closed"):format(tostring(word)), behind.button:IsShown())
	Check("cap: one fewer behind the +N", #target.hidden == count - 1, #target.hidden)
	rule = ""
	-- The +N's dot: on for a true word behind it, off else.
	Open("minimap")
	facts = {}
	editor:GetScript("OnUpdate")(editor, 1)
	Check("cap: +N dot off, nothing behind it true", not target.more.dot:IsShown())
	facts = { [target.hidden[1].field] = true }
	editor:GetScript("OnUpdate")(editor, 1)
	Check("cap: +N dot on, a word behind it true (" .. target.hidden[1].field .. ")", target.more.dot:IsShown())
	-- Lines that fit have no +N; the Logic line never does.
	local logic = Line("and")
	Check("cap: Logic has no +N", logic and logic.more == nil)
	local role = Line("tank")
	Check("cap: Role (fits) no +N shown", role and not role.more:IsShown())
	-- The Tooltip line: only on a tooltip row.
	local tip = Line("tipenemy")
	Check("cap: Tooltip line hidden on another row", tip and not tip.name:IsShown()
		and not tip.pieces[1].button:IsShown())
	Open("tooltip:All")
	Check("cap: Tooltip line shown on the Tooltips row", tip and tip.name:IsShown() and tip.pieces[1].button:IsShown())
	editor:Hide()
	ns.RuleFactsFor = realFacts
end

for _, client in ipairs({ "forever", "retail" }) do
	print("== " .. client)
	local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
	local okCap, capErr = pcall(CapChecks, ns, wow)
	Check("cap checks ran", okCap, capErr)
	local bare = { label = "Bare", Text = function() return "combat" end, Close = function() end }
	local ok, err = pcall(ns.OpenRuleEditor, bare)
	Check("opens with label, Text and Close only", ok, err)
	local editor = _G.CinematicRuleEditor
	local box = editor and FindBox(editor)
	Check("editor and its box there", box ~= nil)
	if box then
		box:SetText("combat and resting")
		ok, err = pcall(box:GetScript("OnTextChanged"), box, true)
		Check("typing with no SetText", ok, err)
		local reset = FindReset(editor)
		Check("Reset to grid button there", reset ~= nil)
		if reset then
			ok, err = pcall(reset:GetScript("OnClick"), reset)
			Check("Reset to grid with no ResetToGrid", ok, err)
		end
		-- A full target still gets each call.
		local got = {}
		ns.OpenRuleEditor({ label = "Full", Text = function() return "" end,
			SetText = function(text) got.set = text end, ResetToGrid = function() got.reset = true end,
			Close = function() got.close = true end })
		box:SetText("flying")
		box:GetScript("OnTextChanged")(box, true)
		Check("full target's SetText gets the typing", got.set == "flying", got.set)
		if reset then reset:GetScript("OnClick")(reset) end
		Check("full target's ResetToGrid called", got.reset == true)
	end
end

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
