-- Range Hint Style (Style/RangeHintStyle.lua, the look in UI/RangeHint.lua),
-- offline (Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/rangehintstyle.lua [forever|retail]
-- Every option draws what it says on the mark: shapes and their weights,
-- size, color by custom / theme / class / school, opacity, glow, the spell's
-- icon (tint, round); the words (each kind, Too far / Too close on Forever
-- only, side, font, size, color, outline, shadow, case); the background
-- (pill, panel, border); motion (fade times, show after, hide after, rise,
-- grow, pulse); no sound (removed). The defaults draw the first
-- look; page off and each folder tab off give the defaults; a theme writes
-- the mark's colors and font; the page and its icon tab are wired.
-- PASS or FAIL lines.
-- luacheck: push ignore 111 112 113 121 122 143
package.path = "Tools/offline/?.lua;" .. package.path
local client = arg and arg[1] or "forever"
local wow = dofile("Tools/offline/wow.lua")
wow.Install(client)
local ns = {}
for line in io.lines("CinematicDev.toc") do -- (Range Hint: dev copy only)
	line = line:gsub("\r", "")
	if line ~= "" and not line:find("^#") then
		local chunk = loadfile((line:gsub("\\", "/")))
		if chunk then
			local ok, err = pcall(chunk, "CinematicDev", ns)
			if not ok then wow.Warn(line .. ": " .. tostring(err)) end
		end
	end
end
wow.Fire("ADDON_LOADED", "CinematicDev")
wow.Fire("PLAYER_LOGIN")

local now = 1000
GetTime = function() return now end
local SPELLS = {
	[116] = { name = "Frostbolt", range = 30, min = 0, harmful = true, icon = "frostbolt-icon" },
	[75] = { name = "Auto Shot", range = 35, min = 5, harmful = true, icon = "autoshot-icon" },
	[99999] = { name = "Mystery Bolt", range = 30, min = 0, harmful = true, icon = "mystery-icon" },
}
local bars = { [1] = 116 }
GetActionInfo = function(slot) if bars[slot] then return "spell", bars[slot] end end
C_Spell = C_Spell or {}
C_Spell.GetSpellInfo = function(id)
	local s = SPELLS[id]
	if s then return { name = s.name, maxRange = s.range, minRange = s.min } end
end
C_Spell.GetSpellName = function(id) return SPELLS[id] and SPELLS[id].name end
C_Spell.GetSpellTexture = function(id) return SPELLS[id] and SPELLS[id].icon end
C_Spell.IsSpellHarmful = function(id) return SPELLS[id] and SPELLS[id].harmful or false end
C_Spell.IsSpellHelpful = function() return false end
local answer = false
C_Spell.IsSpellInRange = function() return answer end
UnitExists = function(unit) return unit == "target" or unit == "player" end
UnitIsDeadOrGhost = function() return false end
UnitClass = function() return "Mage", "MAGE" end
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 856, U_CHAT_SCROLL_BUTTON = 1115, MAP_PING = 3175 }
local played = {}
PlaySound = function(id) played[#played + 1] = id end
-- luacheck: pop

local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. client .. ": " .. text)
	if not ok then failed = failed + 1 end
end
local function Near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.011 end

local RH = ns.RangeHint
Check(RH and ns.RangeHintDraw and ns.RangeHintMakeParts and ns.RangeHintLook, "the look's code loaded")
Check(ns.CreateRangeHintStylePanel ~= nil, "the Style page's builder loaded (Style module)")
if not (RH and ns.RangeHintDraw) then print("FAIL stopping"); os.exit(1) end

-- Records what the drawing sets on each part (the stand-in's setters keep nothing).
local function Record(object)
	local rec = { shown = true }
	object._rec = rec
	object.SetTexture = function(_, v) rec.texture = v end
	object.SetVertexColor = function(_, r, g, b, a) rec.color = { r, g, b, a } end
	object.SetDesaturated = function(_, v) rec.desat = v end
	object.SetSize = function(_, w, h) rec.size = { w, h } end
	object.SetWidth = function(_, w) rec.width = w end
	object.SetHeight = function(_, h) rec.height = h end
	object.Show = function() rec.shown = true end
	object.Hide = function() rec.shown = false end
	object.SetShown = function(_, v) rec.shown = v and true or false end
	object.IsShown = function() return rec.shown end
	object.ClearAllPoints = function() rec.points = {} end
	object.SetPoint = function(_, ...) rec.points = rec.points or {}; rec.points[#rec.points + 1] = { ... } end
	object.SetAllPoints = function() rec.all = true end
	object.SetTextColor = function(_, r, g, b) rec.textColor = { r, g, b } end
	object.SetFont = function(_, file, size, flags) rec.font = { file, size, flags } end
	object.SetShadowOffset = function(_, x, y) rec.shadow = { x, y } end
	object.SetText = function(_, t) rec.text = t end
	object.GetText = function() return rec.text end
	object.AddMaskTexture = function() rec.masked = true end
	object.RemoveMaskTexture = function() rec.masked = false end
	return rec
end
local p = RH.parts
local shape, glow, text = Record(p.shape), Record(p.glow), Record(p.text)
local backs, edges = {}, {}
for i = 1, 3 do backs[i] = Record(p.back[i]) end
for i = 1, 4 do edges[i] = Record(p.edges[i]) end
Record(p.holder)

local db = ns.db
db.styleGeneral = true
db.handleRangeHint = true
db.showInRange = true
db.handleFrames = true
local function Draw(spell, why) return ns.RangeHintDraw(p, { spell = spell or 116, why = why or "out of range" }) end
local function Set(key, value) db[key] = value; return Draw() end
local function Reset()
	for key in pairs(ns.RANGE_STYLE_TAB_OF) do db[key] = nil end
	for i = 1, 5 do db[("tabOn:%s:%d"):format(ns.RANGE_STYLE_TABS, i)] = nil end
	db.rangeHintStyle = true
end

-- The defaults: the first look.
Reset()
local w, h = Draw()
Check(shape.texture and shape.texture:find("RangeMark_chevron_normal$"), "default: the chevron, normal line (" .. tostring(shape.texture) .. ")")
Check(shape.size and shape.size[1] == 24, "default: 24 px")
Check(Near(shape.color[1], 0.94) and Near(shape.color[2], 0.54) and Near(shape.color[3], 0.31), "default: the soft orange")
Check(not glow.shown, "default: no glow")
Check(text.text == "Frostbolt" and text.shown, "default: the spell's name")
Check(Near(text.textColor[1], 0.95) and Near(text.textColor[2], 0.72), "default: the words in soft peach")
Check(text.shadow and text.shadow[1] == 1 and text.shadow[2] == -1, "default: a shadow under the words")
Check(text.font and text.font[3] == "", "default: no outline")
Check(not backs[1].shown and not edges[1].shown, "default: nothing behind it, no border")
local TH = math.ceil(p.text:GetStringHeight() or 0) -- (the stand-in's text height)
Check(w == 50 and h == 24 + TH, ("default: the frame fits the mark over the words (%s x %s)"):format(tostring(w), tostring(h)))

-- Shapes and weights.
for _, s in ipairs({ "double", "dot", "ring", "bracket", "arrow" }) do
	Set("rangeHintShape", s)
	Check(shape.texture and shape.texture:find("RangeMark_" .. s .. "_normal$") and shape.shown, "shape " .. s)
end
Set("rangeHintShape", "chevron")
Set("rangeHintWeight", "bold")
Check(shape.texture:find("_bold$"), "Line: bold")
Set("rangeHintWeight", "thin")
Check(shape.texture:find("_thin$"), "Line: thin")
Reset()
Set("rangeHintShape", "none")
Check(not shape.shown and text.shown, "None: just the words")
Reset()
Set("rangeHintShape", "icon")
Check(shape.texture == "frostbolt-icon" and shape.desat == true, "Spell icon: the spell's own icon, greyed to take the color")
Set("rangeHintIconTint", false)
Check(shape.desat == false and shape.color[1] == 1, "Spell icon untinted: its own colors")
Set("rangeHintIconRound", true)
Check(shape.masked == true, "Round icon: cut round")
Set("rangeHintIconRound", false)
Check(shape.masked == false, "and square again")
Reset()
Set("rangeHintScale", 2)
Check(shape.size[1] == 48, "Size 200%: 48 px")
Reset()

-- Colors.
Set("rangeHintColorBy", "class")
Check(Near(shape.color[1], 0.25) and Near(shape.color[3], 0.92), "Color by class: the mage's")
Set("rangeHintColorBy", "school")
Check(Near(shape.color[1], 0.5) and Near(shape.color[2], 1) and Near(shape.color[3], 1), "Color by school: Frostbolt frost blue")
db.rangeHintR, db.rangeHintG, db.rangeHintB = 0.1, 0.2, 0.3
Draw(99999)
Check(Near(shape.color[1], 0.1) and Near(shape.color[3], 0.3), "a spell the school list doesn't know: the custom color")
local accent = ns.ThemeAccent and ns.ThemeAccent()
Set("rangeHintColorBy", "theme")
if type(accent) == "table" then
	Check(Near(shape.color[1], accent[1]), "Color by theme: the theme's accent")
else
	Check(Near(shape.color[1], 0.1), "Color by theme with the game's theme (no accent): the custom color")
end
Reset()
Set("rangeHintGlow", 0.6)
Check(glow.shown and glow.texture:find("RangeMark_chevron_glow$") and Near(glow.color[4], 0.6)
	and Near(glow.size[1], 40), "Glow: the chevron's glow, 60%, drawn 1/0.6 as big")
Reset()

-- The words.
Set("rangeHintText", "words")
Check(text.text == "Out of range", "Shows: Out of range")
Set("rangeHintText", "spellrange")
Check(text.text == "Frostbolt (30 yd)", "Shows: spell and range")
Set("rangeHintText", "farclose")
Check(text.text == "Too far", "Shows: Too far")
Draw(116, "too close")
Check(text.text == "Too close", "Shows: Too close when too close")
Set("rangeHintText", "none")
Check(not text.shown and shape.shown, "Shows: none, just the mark")
Reset()
Set("rangeHintCase", "upper")
Check(text.text == "FROSTBOLT", "Letters: capitals")
Reset()
Set("rangeHintOutline", 2)
Check(text.font[3] == "THICKOUTLINE", "Outline: thick")
Set("rangeHintShadow", "none")
Check(text.shadow[1] == 0, "Shadow: none")
Set("rangeHintTextSize", 2)
Check(text.font[2] == 24, "Size 200%: the words twice as big")
Set("rangeHintTextColor", "mark")
Check(Near(text.textColor[1], 0.94), "Words in the mark's color")
Set("rangeHintTextColor", "white")
Check(text.textColor[1] == 1 and text.textColor[3] == 1, "Words in white")
Reset()
Set("rangeHintSide", "left")
local tp = text.points and text.points[1]
Check(tp and tp[1] == "LEFT", "Side left: the words on the left")
w, h = Draw()
Check(w == 24 + 50 and h == 24, ("side by side: the frame as wide as both (%s x %s)"):format(w, h))
Set("rangeHintSide", "above")
tp = text.points and text.points[1]
Check(tp and tp[1] == "TOP", "Side over: the words on top")
Reset()

-- The background.
Set("rangeHintBack", "pill")
Check(backs[1].shown and backs[2].shown and backs[3].shown and backs[1].texture:find("RangeMark_pill$"),
	"Soft pill: its two round ends and middle")
Check(Near(backs[2].color[4], 0.5), "at 50%")
w, h = Draw()
Check(w == 50 + 12 and h == 24 + TH + 12, "padding 6 round it")
Set("rangeHintBorder", "thin")
Check(not edges[1].shown, "a pill keeps its round edge: no line")
Set("rangeHintBack", "panel")
Check(backs[1].shown and not backs[2].shown and edges[1].shown and edges[1].color[1] == 0, "Panel with a thin dark line")
Set("rangeHintBorder", "mark")
Check(Near(edges[1].color[1], 0.94), "a line in the mark's color")
Reset()

-- Page off: the first look. A part's Enable off: that part OFF, not its
-- default (the user, 2026-11-25: "I have text disabled and I still see
-- text"; this check had said "Mark tab off: the default shape" before).
local function PartOff(n, off)
	local key = ("tabOn:%s:%d"):format(ns.RANGE_STYLE_TABS, n)
	if off then db[key] = false else db[key] = nil end
end
db.rangeHintShape, db.rangeHintText, db.rangeHintBack = "ring", "words", "pill"
db.rangeHintStyle = false
Draw()
Check(shape.texture:find("chevron") and text.text == "Frostbolt" and not backs[1].shown, "page off: the first look")
db.rangeHintStyle = true
PartOff(2, true)
Draw()
Check(not text.shown and (text.text == "" or text.text == nil) and shape.shown, "Text off: no words at all, the mark still up")
Check(ns.RangeHintLook.rangeHintText == "none", "Text off: its Shows reads None, not Spell name")
PartOff(2, false)
db.rangeHintText = "spell" -- (its default too: off must still hide it)
PartOff(2, true)
Draw()
Check(not text.shown, "Text off with Shows on its default (Spell name): still no words")
PartOff(2, false)
PartOff(1, true)
db.rangeHintGlow = 0.8
Draw()
Check(not shape.shown and not glow.shown and text.shown, "Mark off: no shape, no glow, the words still up")
PartOff(1, false)
PartOff(3, true)
Draw()
Check(shape.texture:find("ring") and not backs[1].shown and not edges[1].shown, "Background off: nothing behind it")
PartOff(3, false)
PartOff(1, true); PartOff(2, true)
Draw()
Check(not shape.shown and not text.shown, "Mark and Text both off: nothing to see")
PartOff(1, false); PartOff(2, false)
-- (The page off wins: the first look whatever the parts say.)
PartOff(2, true)
db.rangeHintStyle = false
Draw()
Check(text.shown and text.text == "Frostbolt", "page off with Text off: the first look, words and all")
db.rangeHintStyle = true
PartOff(2, false)
Reset()

-- Motion: drive the live watcher with a clock.
local frame = RH.frame
local function Run(seconds)
	local fn = frame:GetScript("OnUpdate")
	local t = 0
	while fn and t < seconds - 1e-9 do
		now = now + 0.05
		fn(frame, 0.05)
		t = t + 0.05
		fn = frame:GetScript("OnUpdate")
	end
end
-- (The live mark's alpha: the mark frame's, recorded.)
local live = { alpha = 0 }
local markFrame = p.holder
markFrame.SetAlpha = function(_, a) live.alpha = a end
markFrame.SetScale = function(_, s) live.scale = s end
local offsets = {}
markFrame.SetPoint = function(_, _, _, _, _, y) offsets[#offsets + 1] = y end
markFrame.ClearAllPoints = function() end
answer = true
RH.Fake(nil)
Run(1)
Check(live.alpha == 0, "(in range: nothing)")
db.rangeHintFadeIn = 0
answer = false
RH.Fake(nil)
Run(0.15)
Check(live.alpha == 1, "Fade in 0: up at once")
answer = true; Run(1)
db.rangeHintFadeIn = 1
answer = false; Run(0.5)
Check(live.alpha > 0.3 and live.alpha < 0.7, ("Fade in 1 s: halfway after half a second (%.2f)"):format(live.alpha))
answer = true; Run(2)
db.rangeHintFadeIn = 0
db.rangeHintDelay = 0.5
answer = false; Run(0.3)
Check(live.alpha == 0, "Show after 0.5 s: not yet at 0.3 s")
Run(0.5)
Check(live.alpha == 1, "and up after it")
answer = true; Run(1)
db.rangeHintDelay = 0
db.rangeHintHideAfter = 2
answer = false; Run(1)
Check(live.alpha == 1, "Hide after 2 s: up at 1 s")
Run(2)
Check(live.alpha == 0, "gone after 2 s out of range")
answer = true; Run(0.5)
answer = false; Run(0.3)
Check(live.alpha == 1, "back in range and out again: up again")
answer = true; Run(1)
db.rangeHintHideAfter = 0
db.rangeHintFadeIn = 1
db.rangeHintEnter = "rise"
for i = #offsets, 1, -1 do offsets[i] = nil end
answer = false; Run(0.3)
Check(offsets[#offsets] and offsets[#offsets] < 0, "Rise: below its spot while coming in")
Run(1)
Check(offsets[#offsets] == 0, "and at its spot once up")
answer = true; Run(2)
db.rangeHintEnter = "grow"
answer = false; Run(0.3)
Check(live.scale and live.scale < 1, "Grow: smaller while coming in")
Run(1)
Check(live.scale == 1, "and full size once up")
answer = true; Run(2)
db.rangeHintEnter = "fade"
db.rangeHintFadeIn = 0
db.rangeHintPulse = "start"
answer = false; Run(0.6)
local low = live.alpha
Check(low < 1, ("Pulse: breathes as it comes up (%.2f)"):format(low))
Run(4)
Check(live.alpha == 1, "First 3 seconds: then holds still")
answer = true; Run(1)
db.rangeHintPulse = "off"
db.rangeHintAlpha = 0.5
answer = false; Run(0.2)
Check(Near(live.alpha, 0.5), "Opacity 50%: up at half")
answer = true; Run(1)
db.rangeHintAlpha = nil
-- Motion off: no motion, whatever its settings say (up and gone at once).
db.rangeHintFadeIn, db.rangeHintDelay, db.rangeHintPulse, db.rangeHintEnter = 1, 0.5, "always", "rise"
PartOff(4, true)
answer = false; Run(0.1)
Check(live.alpha == 1 and offsets[#offsets] == 0, "Motion off: up at once, no delay, no rise, no pulse")
Run(2)
Check(live.alpha == 1, "Motion off: holds still (no pulse)")
answer = true; Run(0.1)
Check(live.alpha == 0, "Motion off: gone at once")
PartOff(4, false)
db.rangeHintFadeIn, db.rangeHintDelay, db.rangeHintPulse, db.rangeHintEnter = 0, 0, "off", "fade"
-- A look changed while the mark is up (from any page, no refresh called):
-- drawn within a quarter second. (Run q946a: Text off kept its words.)
answer = false; Run(0.5)
Check(text.shown, "(up, with its words)")
PartOff(2, true)
Run(0.3)
Check(not text.shown, "Text switched off while it's up: the words go within 0.3 s")
PartOff(2, false)
db.rangeHintShape = "ring"
Run(0.3)
Check(shape.texture and shape.texture:find("ring"), "a shape changed while it's up: drawn within 0.3 s")
db.rangeHintShape = "chevron"
answer = true; Run(1)

-- No sound (built, then removed 2026-11-25, the user): it comes up silent.
for i = #played, 1, -1 do played[i] = nil end
answer = false; Run(0.5)
Check(#played == 0 and ns.RangeHintCue == nil and ns.DEFAULTS.rangeHintSound == nil, "no sound as it comes up")
answer = true; Run(1)
Reset()

-- Too close: Forever only (a spell with a least range, the target near).
bars = { [1] = 75 }
wow.Fire("ACTIONBAR_SLOT_CHANGED")
db.rangeHintText = "farclose"
RH.FakeNear(true)
answer = false; Run(0.3)
local st = RH.State()
if client == "retail" then
	Check(st.why == "out of range", "retail: no Too close (its check is blocked in fights)")
else
	Check(st.why == "too close" and text.text == "Too close", "Forever: Auto Shot with the target near: Too close")
end
RH.FakeNear(false)
Run(0.3)
Check(RH.State().why == "out of range" and text.text == "Too far", "the target far: Too far")
RH.FakeNear(nil)
answer = true; Run(1)
bars = { [1] = 116 }
wow.Fire("ACTIONBAR_SLOT_CHANGED")
Reset()

-- The Test button's demo: up with no target needed, then gone.
-- luacheck: push ignore 121 122
UnitExists = function(unit) return unit == "player" end
RH.Demo(5)
Run(0.5)
Check(RH.State().why == "test" and live.alpha == 1, "Test: the mark up for 5 s")
Run(5)
Check(live.alpha == 0 and not RH.Demoing(), "and gone after")
UnitExists = function(unit) return unit == "target" or unit == "player" end
-- luacheck: pop

-- A theme writes the mark's look.
local forge = ns.StyleThemeByKey and ns.StyleThemeByKey("forge")
local fs = forge and forge.settings
Check(fs and fs.rangeHintStyle == true and fs.rangeHintColorBy == "custom" and Near(fs.rangeHintR, 1)
	and fs.rangeHintFont == "general", "Emberforge theme: the mark in its cast color, its font")
local game = ns.StyleThemeByKey and ns.StyleThemeByKey("game")
Check(game and game.settings.rangeHintR == nil, "The game's theme leaves the mark as it is")

-- Wiring.
Check(ns.ShowInTabs and #ns.ShowInTabs("range") == 3, "the Range Hint icon's tabs: Show, Settings, Style")
Check(ns.SHARED_STYLE.rangeHintFont ~= nil, "its font can follow General's")

print(failed == 0 and ("ALL PASS " .. client) or (failed .. " FAILED " .. client))
if failed > 0 then os.exit(1) end
