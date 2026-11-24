-- The Text on You Style page (Style/SelfTextPage.lua), offline (Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/selftextpage.lua < /dev/null
-- The redesign (Tools/self-text-page-plan.md) on the stand-in: the page
-- builds with its three tabs and every control refreshes; the font row has
-- no first choice of its own (it showed "The game's, The game's"); the chips
-- say what's going on (page off, copied, the game's text off, the Shoulder
-- Cam, Text on Me ticks, another addon's pick, the last fight) and the empty
-- one hides; the changed line names what's changed; quick looks set their
-- parts; picking a kind points the editor at its settings, Clear puts it
-- back, and its sample, badge and mark follow it; drag to place snaps; the
-- preview plays the mix, the picked kind alone, the game's look, or nothing;
-- Play turns into Stop and back; its buttons flip the view; Reset page
-- clears every kind. Says PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212 213
local now = 100
local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", function()
	GetTime = function() return now end
end)
-- luacheck: pop
-- (Places kept, as the game does: the checks read the buttons', the game's
-- spot's and the drag mark's back.)
local M = wow.Methods
function M:SetPoint(point, rel, relPoint, x, y)
	if type(rel) == "number" then rel, relPoint, x, y = nil, point, rel, relPoint end
	self._points = self._points or {}
	self._points[#self._points + 1] = { point, rel, relPoint, x or 0, y or 0 }
end
function M:ClearAllPoints() self._points = nil end
function M:SetSize(w, h) self._w, self._h = w, h end
function M:GetSize() return self._w or 100, self._h or 20 end
function M:GetPoint(i)
	local p = self._points and self._points[i or 1]
	if p then return unpack(p) end
	return "CENTER", nil, "CENTER", 0, 0
end
function M:GetNumPoints() return self._points and #self._points or 0 end

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

-- luacheck: push ignore 111 112 113 121 122
local timers, tickers = {}, {}
C_Timer.After = function(seconds, fn) timers[#timers + 1] = { at = now + seconds, fn = fn } end
C_Timer.NewTicker = function(_, fn)
	local t = { fn = fn, Cancel = function(self) self.cancelled = true end }
	tickers[#tickers + 1] = t
	return t
end
hooksecurefunc = function(obj, name, fn)
	if type(obj) == "string" then obj, name, fn = _G, obj, name end
	local old = obj[name]
	obj[name] = function(...)
		local a, b, c, d = old(...)
		fn(...)
		return a, b, c, d
	end
end
local cvars = { enableFloatingCombatText = "1", test_cameraOverShoulder = "1.5", floatingCombatTextComboPoints_v2 = "0" }
GetCVar = function(name) return cvars[name] end
-- (Texts the boards make: recorded, as the game's FontStrings.)
local function NewText()
	local fs = { shown = false }
	fs.SetFont = function(self, file, size) self.file, self.size = file, size end
	fs.SetTextColor = function(self, r, g, b, a) self.color = { r, g, b, a } end
	fs.SetText = function(self, words) self.words = words end
	fs.SetFormattedText = function(self, _, words, count) self.words, self.count = words, count end
	fs.SetPoint = function(self, point, rel, relPoint, x, y) self.point = { point, rel, relPoint, x, y } end
	fs.GetPoint = function(self) if self.point then return unpack(self.point) end end
	for _, m in ipairs({ "SetShadowColor", "SetShadowOffset", "ClearAllPoints", "SetAlpha", "SetTextScale" }) do
		fs[m] = function() end
	end
	fs.Show = function(self) self.shown = true end
	fs.Hide = function(self) self.shown = false end
	return fs
end
-- luacheck: pop

-- The page built again on its own kit, its Font rows' first choices noted.
local fontFirsts = {}
local realRows = ns.StyleRows
ns.StyleRows = function(...)
	local rows = realRows(...)
	local font = rows.Font
	rows.Font = function(key, tip, test, first, label)
		fontFirsts[#fontFirsts + 1] = { key = key, first = first }
		return font(key, tip, test, first, label)
	end
	-- (A Look panel's rows too: a kind's own panel, made when it opens.)
	local look = rows.Look
	rows.Look = function(label, title, spec)
		for name, made in pairs(spec) do
			if type(made) == "function" then
				spec[name] = function(inner, ...)
					local innerFont = inner.Font
					inner.Font = function(key, tip, t, first, words)
						fontFirsts[#fontFirsts + 1] = { key = key, first = first }
						return innerFont(key, tip, t, first, words)
					end
					return made(inner, ...)
				end
			end
		end
		return look(label, title, spec)
	end
	local fold = rows.Fold
	rows.Fold = function(test)
		local inner = fold(test)
		local innerFont = inner.Font
		inner.Font = function(key, tip, t, first, label)
			fontFirsts[#fontFirsts + 1] = { key = key, first = first }
			return innerFont(key, tip, t, first, label)
		end
		return inner
	end
	return rows
end
-- (As the game: a frame has no Refresh till one is set. The stand-in hands
-- any missing method a do-nothing stub, which hid a preview with none: it
-- broke opening the page in game, 2026-11-21.)
local realCreateFrame = CreateFrame
CreateFrame = function(...) -- luacheck: ignore 121
	local frame = realCreateFrame(...)
	rawset(frame, "Refresh", false)
	return frame
end
local kit, controls, resetFn, registered = ns.lowHealthKit, {}, nil, nil
local pageKit = setmetatable({
	AddControl = function(control) controls[#controls + 1] = control end,
	RegisterSubpage = function(_, id) registered = id end,
	OnReset = function(_, fn) resetFn = fn end,
	Refresh = function()
		for _, control in ipairs(controls) do
			-- (As the real kit: every control's Refresh called, none missing.
			-- A preview without one broke opening the page in game.)
			if type(control.Refresh) ~= "function" and not (type(control.Refresh) == "table" and getmetatable(control.Refresh)) then
				error("a control with no Refresh")
			end
			local ok, err = pcall(control.Refresh, control)
			if not ok then error(err) end
		end
	end,
}, { __index = kit })
local ok, err = pcall(ns.CreateSelfTextStylePanel, pageKit)
-- (A kind's Look panel is made on first open: damage's made here, its rows noted.)
if ok and ns.selfTextPage and ns.selfTextPage.KindLook then ok, err = pcall(ns.selfTextPage.KindLook, "damage") end
ns.StyleRows = realRows
CreateFrame = realCreateFrame -- luacheck: ignore 121
Check("page builds", ok, err)
Check("registered as Self Text Style", registered == "Self Text Style", registered)
local page = ns.selfTextPage
-- (The preview's size as the game keeps it: the stand-in says 100 x 20 for
-- every frame. On the page, 520 x 210; docked, what the window gives.)
local previewW, previewH = 520, 210
if page and page.preview then
	rawset(page.preview, "GetWidth", function() return previewW end)
	rawset(page.preview, "GetHeight", function() return previewH end)
	if page.Fit then page.Fit() end
end
Check("three tabs", page.hosts and #page.hosts == 3)
local db = ns.db
db.styleGeneral, db.selfTextStyle = true, true
local refreshed, refreshErr = pcall(pageKit.Refresh)
Check("every control refreshes", refreshed, refreshErr)
Check("many controls", #controls > 40, #controls)

-- The font row: no first of its own (the list starts with The game's).
local mainFont
for _, f in ipairs(fontFirsts) do if f.key == "selfTextFont" then mainFont = f end end
Check("font row found", mainFont ~= nil)
Check("font row: no first choice of its own", mainFont and mainFont.first == nil)
Check("the font list starts with The game's, once", ns.StyleFontChoices()[1].value == "game"
	and ns.StyleFontChoices()[2].value ~= "game")

-- Chips.
local chips = page.chips
local function Chip(i) chips[i]:Refresh() return chips[i].state, chips[i].dotKind, chips[i]:IsShown() end
db.selfTextStyle = false
Check("chip: page off", (Chip(1)) == "as it is (page off)")
db.selfTextStyle = true
ns.RefreshSelfTextStyle()
local state, dot = Chip(1)
Check("chip: copied", state == "copied" and dot == "good", state)
cvars.enableFloatingCombatText = "0"
ns.ApplyCVarSet(ns.SELF_TEXT_GAME_ON, false) -- (as if let go, then turned off outside)
cvars.enableFloatingCombatText = "0"
state, dot = Chip(1)
Check("chip: the game's text off", state == "off in the game: nothing to copy" and dot == "warn", state)
cvars.enableFloatingCombatText = "1"
db.selfTextBy = "none"
Check("chip: hidden", (Chip(1)) == "hidden")
db.selfTextBy = "game"
Check("chip: as it is", (Chip(1)) == "as it is")
db.selfTextBy = "ours"
db.shoulderCam = false
Check("chip: Shoulder Cam off", (Chip(2)) == "off")
db.shoulderCam = true
local unlocked = ns.ShoulderCamUnlocked
ns.ShoulderCamUnlocked = function() return true end
Check("chip: over your shoulder", (Chip(2)) == "over your shoulder")
cvars.test_cameraOverShoulder = "0"
Check("chip: behind you", (Chip(2)) == "behind you")
ns.ShoulderCamUnlocked = unlocked
state = Chip(3)
Check("chip: Text on Me counts", state and state:find("of", 1, true) ~= nil and dot ~= nil, state)
local _, _, shown = Chip(4)
Check("chip: no other addon: not there", shown == false)
local row = { key = "style:selftext", addon = "BattleText Forever", id = "BattleText Forever:style:selftext",
	theirs = function() return true end }
table.insert(ns.CONFLICTS, row)
state, dot, shown = Chip(4)
Check("chip: another addon's pick", shown and state == "theirs" and dot == "warn", state)
table.remove(ns.CONFLICTS)
ns.SelfTextStats.fight = { copied = 0, shown = 0, dropped = 0 }
Check("chip: last fight none yet", (Chip(5)) == "none yet")
ns.SelfTextStats.fight = { copied = 12, shown = 11, dropped = 1 }
Check("chip: last fight counts", (Chip(5)) == "12 copied, 1 left out")

-- The changed line.
local function ChangedText() pageKit.Refresh() return page.changedText:GetText() end
Check("nothing changed", ChangedText() == "Changed: nothing yet", ChangedText())
db.selfTextSize = 1.5
db.selfText_damageSize = 2
local line = ChangedText()
Check("changed: General's and a kind's", line:find("Size", 1, true) and line:find("Damage taken", 1, true), line)
db.selfTextSize, db.selfText_damageSize = 1, 1

-- Quick looks.
Check("five quick looks", #page.lookButtons == 5)
page.lookButtons[3]:GetScript("OnClick")(page.lookButtons[3])
Check("Bold sets its parts", db.selfTextFont == "lilita" and db.selfTextEdge == "both" and db.selfTextMotion == "pop"
	and db.selfTextLook == "bold", db.selfTextFont)
Check("an unknown look: nothing", page.ApplyLook("nope") == false)
page.ApplyLook("game")

-- Kinds: click one, its own Look panel opens (docked, as Combat Text's
-- texts'), its settings the kind's; its row follows it; Clear in the panel.
local function FindButton(frame, text)
	for _, child in ipairs({ frame:GetChildren() }) do
		if child.GetText and child:GetText() == text then return child end
		local found = FindButton(child, text)
		if found then return found end
	end
end
page.Pick("damage")
local look = page.kindLooks.damage
Check("picked damage: its panel open", page.picked == "damage" and look and look.pop:IsShown())
Check("the panel is damage's", look and look.key("Size") == "selfText_damageSize" and look.key("R") == "selfText_damageR")
local kindFont
for _, f in ipairs(fontFirsts) do if f.key == "Font" then kindFont = f end end
Check("a kind's font row: General's first", kindFont and kindFont.first and kindFont.first[1] == "general")
Check("the panel isn't under the list (no editor on the page)", page.editorFold == nil and page.clearButton == nil)
db.selfText_damageColor, db.selfText_damageR, db.selfText_damageG, db.selfText_damageB = "custom", 0, 0, 1
pageKit.Refresh()
local damageRow = page.kindRows.damage
Check("its row marked changed and picked", page.KindChanged("damage") and damageRow.picked)
local clear = look and FindButton(look.pop, "Clear (as General's)")
Check("the panel's Clear", clear ~= nil)
if clear then clear:GetScript("OnClick")(clear) end
Check("Clear: back to General's", not page.KindChanged("damage") and db.selfText_damageColor == "game")
page.Pick("heal")
Check("another kind: its panel in place of the last", page.picked == "heal" and page.kindLooks.heal.pop:IsShown()
	and not look.pop:IsShown())
do -- (the stand-in fires no OnHide: as the game does)
	local heal = page.kindLooks.heal.pop
	heal:Hide()
	heal:GetScript("OnHide")(heal)
end
Check("its panel closed: nothing picked", page.picked == nil)
page.Pick("damage")
page.Pick("damage")
Check("clicked again: closed, unpicked", page.picked == nil and not look.pop:IsShown())
page.kindRows.combo:Refresh()
Check("a kind the game's tick turns off: its badge", page.kindRows.combo.badgeText == "off in the game's options",
	page.kindRows.combo.badgeText)
page.kindRows.damage:Refresh()
-- (An empty FontString reads nil, as the game's does (rule
-- all.fontstring.empty-text-nil, the stand-in since 6e4dcfa). The user OK'd 2026-11-23.)
Check("a kind with no tick: no badge", (page.kindRows.damage.badgeText or "") == "")

-- Drag to place (snapped to 5, kept in range).
db.selfTextHeight, db.selfTextAcross = 0, 0
page.DragTo(30, 61)
local function Snap(v) return math.floor(v / 5 + 0.5) * 5 end
Check("drag: height and across", db.selfTextHeight == Snap(61 / page.SCALE) and db.selfTextAcross == Snap(30 / page.SCALE)
	and db.selfTextHeight % 5 == 0 and db.selfTextHeight > 0,
	("%s %s"):format(db.selfTextHeight, db.selfTextAcross))
page.DragTo(0, 9000)
Check("drag: kept in range", db.selfTextHeight == 300)
-- Right-click the mark: back where it starts (Height and Across only).
db.selfTextAcross, db.selfTextSize = 40, 1.5
page.handle:GetScript("OnClick")(page.handle, "LeftButton")
Check("left-click: the mark stays", db.selfTextHeight == 300 and db.selfTextAcross == 40)
page.handle:GetScript("OnClick")(page.handle, "RightButton")
Check("right-click: back to the start", db.selfTextHeight == ns.DEFAULTS.selfTextHeight
	and db.selfTextAcross == ns.DEFAULTS.selfTextAcross and db.selfTextSize == 1.5)
db.selfTextSize = ns.DEFAULTS.selfTextSize
db.selfTextHeight, db.selfTextAcross = 0, 0

-- The preview: what it plays.
local board = page.board
board.layer.CreateFontString = NewText
board:Clear()
db.selfTextMerge = false
page.PlayOne()
Check("plays the mix", #board.live == 1)
page.Pick("combo")
board:Clear()
page.PlayOne()
Check("plays the picked kind alone", board.live[1] and board.live[1].group == "combo")
page.Pick("combo")
board:Clear()
db.selfTextBy = "none"
page.PlayOne()
Check("None: plays nothing", #board.live == 0)
db.selfTextBy = "game"
page.PlayOne()
Check("The game's: its look", board.live[1] and board.live[1].side == 0 and board.live[1].motion == "up")
db.selfTextBy = "ours"
board:Clear()
db.selfText_damageShow, db.selfText_healShow = false, false
for _ = 1, 30 do page.PlayOne() end
local leaked = false
for _, text in ipairs(board.live) do if text.group == "damage" or text.group == "heal" then leaked = true end end
Check("kinds switched off: not in the mix", not leaked)
db.selfText_damageShow, db.selfText_healShow = true, true
board:Clear()

-- Play / Stop, the view's buttons.
page.preview.IsVisible = function() return true end
page.SetPlaying(false)
Check("stopped: Play", page.playButton:GetText() == "Play")
page.SetPlaying(true)
Check("playing: Stop", page.playButton:GetText() == "Stop" and #board.live >= 1)
page.camButton:GetScript("OnClick")(page.camButton)
Check("behind you", page.view.over == false and page.camButton:GetText() == "Behind you")
page.camButton:GetScript("OnClick")(page.camButton)
Check("over shoulder again", page.view.over == true)
page.ghostButton:GetScript("OnClick")(page.ghostButton)
Check("the game's spot shown", page.view.ghost == true and page.ghost:IsShown())
page.ghostButton:GetScript("OnClick")(page.ghostButton)
Check("and hidden", not page.ghost:IsShown())
page.SetPlaying(false)

-- Play on screen: samples at your real spot, the button says so, then back.
local screen = ns.SelfTextScreenBoard
screen.layer.CreateFontString = NewText
page.onScreenButton:GetScript("OnClick")(page.onScreenButton)
Check("play on screen: says so", page.onScreenButton:GetText() == "Playing...")
for _, t in ipairs(timers) do if t.at <= now + 3.5 then pcall(t.fn) end end
Check("play on screen: on the screen's board", #screen.live >= 1, #screen.live)
for _, t in ipairs(timers) do if t.at > now + 3.5 then pcall(t.fn) end end
Check("play on screen: back", page.onScreenButton:GetText() == "Play on screen")

-- From the user's look at the page (2026-11-21): the preview's buttons clear
-- of its Backdrop icon; the game's spot above your head; the drag mark where
-- the texts start (your side), not on your spot.
do
	local _, _, _, bx = page.camButton:GetPoint(1)
	Check("buttons start right of the Backdrop icon (22 wide at 6)", type(bx) == "number" and bx >= 30, bx)
	local _, _, _, gx, gy = page.ghost:GetPoint(1)
	Check("the game's spot: in the middle, above your chest", gx == 0 and gy >= 50, gy)
	Check("the game's look draws there", math.abs(page.board.middleY * page.SCALE - gy) < 0.5,
		page.board.middleY * page.SCALE)
	db.selfTextSide, db.selfTextAcross, db.selfTextHeight = "free", 0, 0
	page.view.over = true
	page.PlaceHandle()
	local _, _, _, hx = page.handle:GetPoint(1)
	local you = -0.1 * 520 / page.SCALE
	local side = ns.SelfTextSideOf("damage", you)
	Check("the drag mark: on the texts' side, not your spot", side ~= 0
		and math.abs(hx - (you + side * ns.SELF_TEXT_SIDE) * page.SCALE) < 0.5, hx)
	db.selfTextSide = "over"
	page.PlaceHandle()
	_, _, _, hx = page.handle:GetPoint(1)
	Check("Over you: the mark on you", math.abs(hx - you * page.SCALE) < 0.5, hx)
	db.selfTextSide = "free"
end

-- Docked bigger (the user's shot 2026-11-21: the texts in the top-left
-- corner, the mark off them, you under the bottom edge): everything follows
-- the window's size; the mark sits where a text starts; no Shoulder Cam view
-- (behind you): the texts and the mark straight over you.
local function MarkOnText(name)
	local board = page.board
	board:Clear()
	local update = board.layer._scripts.OnUpdate
	if update then update(board.layer, 1) end -- (your spot settled, as a second in game)
	local text = ns.SelfTextSample("-12", "damage", false, board)
	if update then update(board.layer, 0) end
	page.PlaceHandle()
	local _, _, _, tx, ty = text:GetPoint(1)
	local _, _, _, hx, hy = page.handle:GetPoint(1)
	Check(name .. ": the mark on the text's start", type(tx) == "number" and type(hx) == "number"
		and math.abs(tx - hx) < 0.5 and math.abs(ty - hy) < 0.5,
		("text %s,%s mark %s,%s"):format(tostring(tx), tostring(ty), tostring(hx), tostring(hy)))
	return tx, hx
end
do
	db.selfTextSide, db.selfTextAcross, db.selfTextHeight, db.selfTextMotion = "free", 0, 0, "up"
	page.view.over = true
	MarkOnText("on the page")
	previewW, previewH = 740, 300
	page.Fit()
	local lw, lh = page.board.layer:GetSize()
	Check("docked: the texts' layer as big as the window", lw == 740 and lh == 300, ("%s x %s"):format(lw, lh))
	Check("docked: the texts zoom with it", math.abs(page.board.scale - page.SCALE * 300 / 210) < 0.001, page.board.scale)
	local _, _, _, mx, my = page.model:GetPoint(1)
	local _, mh = page.model:GetSize()
	Check("docked: you inside it (your top in, your feet under the edge)", mx == -0.1 * 740 and my == -300 * 0.85
		and mh == 300 * 1.8 and my + mh > 300 * 0.5, ("%s %s %s"):format(mx, my, mh))
	local _, _, _, gx, gy = page.ghost:GetPoint(1)
	Check("docked: the game's spot zoomed too", gx == 0 and math.abs(gy - 62 * 300 / 210) < 0.01, gy)
	MarkOnText("docked")
	-- (The Style previews' fit runs on each refresh: it leaves you and the marks be.)
	if ns.ApplyPreviewFit then
		local _, _, _, x1, y1 = page.model:GetPoint(1)
		local _, _, _, g1, h1 = page.ghost:GetPoint(1)
		ns.ApplyPreviewFit(page.preview)
		local _, _, _, x2, y2 = page.model:GetPoint(1)
		local _, _, _, g2, h2 = page.ghost:GetPoint(1)
		Check("the previews' fit leaves you and the game's spot", x1 == x2 and y1 == y2 and g1 == g2 and h1 == h2,
			("%s,%s -> %s,%s; %s,%s -> %s,%s"):format(tostring(x1), tostring(y1), tostring(x2), tostring(y2), tostring(g1), tostring(h1), tostring(g2), tostring(h2)))
	end
	page.view.over = false
	local tx, hx = MarkOnText("behind you (no Shoulder Cam)")
	Check("behind you: texts over you, centered", math.abs(tx or 99) < 0.5 and math.abs(hx or 99) < 0.5, tx)
	db.selfTextAcross, db.selfTextHeight = 20, 30
	MarkOnText("moved")
	db.selfTextAcross, db.selfTextHeight = 0, 0
	page.view.over = true
	previewW, previewH = 520, 210
	page.Fit()
	page.board:Clear()
end

-- Reset page: every kind's parts too.
db.selfText_healSize, db.selfText_comboSound, db.selfTextLook = 2, "alarm", "bold"
page.Pick("heal")
resetFn()
Check("reset: kinds cleared, nothing picked", not page.KindChanged("heal") and not page.KindChanged("combo")
	and page.picked == nil and db.selfTextLook == "game"
	and not page.kindLooks.heal.pop:IsShown())

-- The page off: the off card fades it to 0 and the model (which draws on
-- through a faded parent) hides with it; on again, it's back.
do
	local model, watch = page.model, page.modelWatch
	local above = page.preview:GetParent()
	local tick = watch and watch._scripts.OnUpdate
	Check("model: watched", tick ~= nil)
	if tick then
		tick(watch, 0.1)
		Check("model: shown on a page that shows", model:IsShown())
		rawset(above, "GetAlpha", function() return 0 end)
		tick(watch, 0.1)
		Check("model: hidden on a faded page", not model:IsShown())
		rawset(above, "GetAlpha", nil)
		tick(watch, 0.1)
		Check("model: back when the page shows", model:IsShown())
	end
end

for _, warning in ipairs(wow.warnings) do
	if warning:find("SelfText", 1, true) then Check("load: " .. warning, false) end
end
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
