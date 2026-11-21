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
	for _, m in ipairs({ "SetShadowColor", "SetShadowOffset", "ClearAllPoints", "SetPoint", "SetAlpha", "SetTextScale" }) do
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
ns.StyleRows = realRows
CreateFrame = realCreateFrame -- luacheck: ignore 121
Check("page builds", ok, err)
Check("registered as Self Text Style", registered == "Self Text Style", registered)
local page = ns.selfTextPage
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
local kindFont
for _, f in ipairs(fontFirsts) do if f.key == "kindFont" then kindFont = f end end
Check("a kind's font row: General's first", kindFont and kindFont.first and kindFont.first[1] == "general")

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

-- Kinds: pick one, the editor is its; its row follows it; Clear.
page.Pick("damage")
Check("picked damage", page.picked == "damage")
Check("the editor is damage's", page.Field("kindSize") == "selfText_damageSize" and page.Field("kindR") == "selfText_damageR")
db.selfText_damageColor, db.selfText_damageR, db.selfText_damageG, db.selfText_damageB = "custom", 0, 0, 1
pageKit.Refresh()
local damageRow = page.kindRows.damage
Check("its row marked changed and picked", page.KindChanged("damage") and damageRow.picked)
page.clearButton:Refresh()
Check("Clear usable", page.clearButton:IsEnabled())
page.clearButton:GetScript("OnClick")(page.clearButton)
Check("Clear: back to General's", not page.KindChanged("damage") and db.selfText_damageColor == "game")
page.Pick("damage")
Check("picked again: unpicked", page.picked == nil and page.Field("kindSize") == "selfText_otherSize")
page.kindRows.combo:Refresh()
Check("a kind the game's tick turns off: its badge", page.kindRows.combo.badgeText == "off in the game's options",
	page.kindRows.combo.badgeText)
page.kindRows.damage:Refresh()
Check("a kind with no tick: no badge", page.kindRows.damage.badgeText == "")

-- Drag to place (snapped to 5, kept in range).
db.selfTextHeight, db.selfTextAcross = 0, 0
page.DragTo(30, 61)
local function Snap(v) return math.floor(v / 5 + 0.5) * 5 end
Check("drag: height and across", db.selfTextHeight == Snap(61 / page.SCALE) and db.selfTextAcross == Snap(30 / page.SCALE)
	and db.selfTextHeight % 5 == 0 and db.selfTextHeight > 0,
	("%s %s"):format(db.selfTextHeight, db.selfTextAcross))
page.DragTo(0, 9000)
Check("drag: kept in range", db.selfTextHeight == 300)
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

-- Reset page: every kind's parts too.
db.selfText_healSize, db.selfText_comboSound, db.selfTextLook = 2, "alarm", "bold"
page.Pick("heal")
resetFn()
Check("reset: kinds cleared, nothing picked", not page.KindChanged("heal") and not page.KindChanged("combo")
	and page.picked == nil and db.selfTextLook == "game")

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
