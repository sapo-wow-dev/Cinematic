-- Text on You (Style/SelfTextStyle.lua), offline (Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/selftextstyle.lua < /dev/null
-- On a stand-in of the game's CombatText: the page on hides the game's frame
-- (alpha 0, kept there) and copies each message it draws into ours with the
-- secret words as given; the event of the same instant gives the kind (before
-- or after the text), combo points by the power type, no event by what else
-- happened (Low Mana, +Combat); the game's color or the kind's own; a kind
-- hidden; crits bigger; the spot follows the Shoulder Cam and Side puts it
-- beside you; Who draws The game's / None; the page off puts the game's back;
-- the page builds. Says PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212 213
local ns, wow = dofile("Tools/offline/load.lua")("forever")

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local now = 100
GetTime = function() return now end
hooksecurefunc = function(obj, name, fn)
	if type(obj) == "string" then obj, name, fn = _G, obj, name end
	local old = obj[name]
	obj[name] = function(...)
		local a, b, c, d = old(...)
		fn(...)
		return a, b, c, d
	end
end
local SECRET = {}
local function S(v) local t = { v = v } SECRET[t] = true return t end
issecretvalue = function(v) return SECRET[v] == true end
local shift = 0
ns.ShoulderYouShift = function() return shift end
UIParent.GetWidth = function() return 1920 end

-- The game's CombatText: a frame, its texts, an alpha.
local ct = CreateFrame("Frame")
ct._alpha = 1
ct.SetAlpha = function(self, a) self._alpha = a end
ct.GetAlpha = function(self) return self._alpha end
_G.CombatText = ct
local game = {}
for i = 1, 3 do
	local fs = ct:CreateFontString()
	fs._color = { 1, 1, 1 }
	fs.SetTextColor = function(self, r, g, b) self._color = { r, g, b } end
	fs.GetTextColor = function(self) return unpack(self._color) end
	game[i] = fs
end
_G.CombatTextFont = { GetFont = function() return "Fonts\\FRIZQT__.TTF", 127291, "FILTER" end }

-- Ours, recorded.
local layer = _G.CinematicSelfText
local made, lastSet = {}, nil
layer.CreateFontString = function()
	local fs = {}
	fs.SetFont = function(self, file, size, flags) self.file, self.size, self.flags = file, size, flags end
	fs.SetTextColor = function(self, r, g, b) self.color = { r, g, b } end
	fs.SetText = function(self, words)
		-- (As the game: no font yet, an error. Forever 2026-11-21.)
		if not self.file then error("FontString:SetText(): Font not set") end
		self.words = words
		self.history = self.history or {}
		self.history[#self.history + 1] = words
		lastSet = self
	end
	fs.SetShadowColor = function(self, _, _, _, a) self.shadowAlpha = a end
	fs.SetFormattedText = function(self, fmt, ...)
		if not self.file then error("FontString:SetText(): Font not set") end
		self.formatted = { fmt, ... }
		lastSet = self
	end
	fs.SetShadowOffset = function(self, x) self.shadow = x end
	fs.ClearAllPoints = function() end
	fs.SetPoint = function(self, _, _, _, x, y) self.x, self.y = x, y end
	fs.SetAlpha = function(self, a) self.alpha = a end
	fs.SetTextScale = function(self, s) self.scale = s end
	fs.Show = function(self) self.shown = true end
	fs.Hide = function(self) self.shown = false end
	made[#made + 1] = fs
	return fs
end
-- luacheck: pop

local function Frame(seconds)
	for _ = 1, math.max(1, math.floor((seconds or 0.02) / 0.02 + 0.5)) do
		now = now + 0.02
		for _, frame in ipairs(ns.selfTextFrames) do
			local update = frame._scripts.OnUpdate
			if update and frame._shown then pcall(update, frame, 0.02) end
		end
	end
end
local function Live()
	local list = {}
	for _, fs in ipairs(made) do if fs.shown then list[#list + 1] = fs end end
	return list
end
local function Newest() return lastSet end
-- A message as the game draws it: the event first (its handler runs before
-- ours), then its text, colored. kindAfter: the event after the text.
local function Message(kind, words, color, extra, kindAfter)
	local region = game[1]
	if extra then extra() end
	if kind and not kindAfter then wow.Fire("COMBAT_TEXT_UPDATE", kind) end
	region:SetTextColor(color[1], color[2], color[3])
	region:SetText(words)
	if kind and kindAfter then wow.Fire("COMBAT_TEXT_UPDATE", kind) end
	Frame(0.04)
end

local db = ns.db
db.styleGeneral, db.selfTextStyle = true, true
db.selfTextMerge = false -- (sections 1-12 count texts one by one; 13 checks merging)
ns.RefreshSelfTextStyle()
local state = ns.SelfTextState()
Check("page on: on", state.on == true and state.by == "ours")
Check("the game's frame hidden", ct._alpha == 0, ct._alpha)
Check("its texts hooked", state.hooked == 3, state.hooked)
ct:SetAlpha(1)
Check("kept hidden if the game sets it", ct._alpha == 0, ct._alpha)

-- 1. A hit: the secret words as given, the game's color, its kind.
local words = S("-26")
Message("DAMAGE", words, { 1, 0.1, 0.1 })
local hit = Newest()
Check("hit copied", hit and hit.words == words and hit.shown)
Check("hit in the game's color", hit and hit.color[1] == 1 and hit.color[2] == 0.1, hit and table.concat(hit.color, " "))
Check("hit's kind counted", ns.SelfTextStats.kinds.DAMAGE == 1)
Check("game's font when Game's", hit and hit.file == "Fonts\\FRIZQT__.TTF", hit and hit.file)
Check("a hit's size", hit and hit.size == 24, hit and hit.size)
Check("game's shadow", hit and hit.flags == "" and (hit.shadow or 0) > 0)

-- 2. A crit, bigger; the earlier text pushed up out of its way.
local before = hit.y
Message("DAMAGE_CRIT", S("-74"), { 1, 0.1, 0.1 })
local crit = Newest()
Frame(0.02)
Check("crit bigger", crit and crit.size == 36, crit and crit.size)
Check("older text pushed along", hit.y > before + 30, ("%s -> %s"):format(tostring(before), tostring(hit.y)))

-- 3. Combo points come as ENERGIZE, told by the power type then.
db.selfText_comboColor, db.selfText_comboR, db.selfText_comboG, db.selfText_comboB = "custom", 0.2, 0.4, 0.6
Message("ENERGIZE", S("<2 Combo Points>"), { 1, 1, 1 }, function() wow.Fire("UNIT_POWER_UPDATE", "player", "COMBO_POINTS") end)
local combo = Newest()
Check("combo points in combo's own color", combo and combo.color[1] == 0.2 and combo.color[3] == 0.6,
	combo and table.concat(combo.color, " "))
Message("ENERGIZE", S("+20 Mana"), { 0.3, 0.5, 1 }, function() wow.Fire("UNIT_POWER_UPDATE", "player", "MANA") end)
Check("mana stays power (the game's color)", Newest().color[3] == 1)

-- 4. No event: Low Mana by your power then, +Combat by the fight starting.
local count = #made
Message(nil, S("Mana Low"), { 1, 0.1, 0.1 }, function() wow.Fire("UNIT_POWER_UPDATE", "player", "MANA") end)
Check("no-event text still drawn", #made == count + 1 or Newest().words ~= nil)
db.selfText_lowColor = "off"
local shownBefore = ns.SelfTextStats.shown
Message(nil, S("Health Low"), { 1, 0.1, 0.1 }, function() wow.Fire("UNIT_HEALTH", "player") end)
Check("low hidden: dropped", ns.SelfTextStats.shown == shownBefore)
db.selfText_lowColor = "game"
db.selfText_combatColor = "custom"
db.selfText_combatR, db.selfText_combatG, db.selfText_combatB = 0, 1, 1
Message(nil, S("+Combat"), { 1, 1, 1 }, function() wow.Fire("PLAYER_REGEN_DISABLED") end)
Check("+Combat as combat", Newest().color[1] == 0 and Newest().color[2] == 1, table.concat(Newest().color, " "))

-- 5. The kind after its text: still found.
db.selfText_healColor = "custom"
db.selfText_healR, db.selfText_healG, db.selfText_healB = 0.5, 0.5, 0
Message("HEAL", S("+120 [Sapo]"), { 0.1, 1, 0.1 }, nil, true)
Check("kind after the text", Newest().color[1] == 0.5, table.concat(Newest().color, " "))

-- 6. The spot: the Shoulder Cam's slide, eased; Free side away from the middle; Over you.
shift = -400
Frame(1)
Message("DAMAGE", S("-9"), { 1, 0.1, 0.1 })
local spotHit = Newest()
Frame(0.02)
Check("follows you, on your free side", spotHit.x < -480 and spotHit.x > -500, spotHit.x)
db.selfTextSide = "over"
Message("DAMAGE", S("-8"), { 1, 0.1, 0.1 })
Frame(0.02)
Check("over you", math.abs(Newest().x + 400) < 2, Newest().x)
db.selfTextSide = "split"
Message("HEAL", S("+50"), { 0.1, 1, 0.1 })
Frame(0.02)
Check("split: gained on the other side", math.abs(Newest().x + 310) < 2, Newest().x)
db.selfTextSide = "free"
db.selfTextFollow = false
Frame(1)
Message("DAMAGE", S("-7"), { 1, 0.1, 0.1 })
Frame(0.02)
Check("follow off: over you in the middle (no side to be free on)", math.abs(Newest().x) < 2, Newest().x)
shift = 0
db.selfTextFollow = true
Frame(1)
Message("DAMAGE", S("-6"), { 1, 0.1, 0.1 })
Frame(0.02)
Check("no Shoulder Cam: over you, centered", math.abs(Newest().x) < 2, Newest().x)
db.selfTextSide = "split"
Message("HEAL", S("+40"), { 0.1, 1, 0.1 })
Frame(0.02)
Check("split in the middle: gained on the left", Newest().x < -80, Newest().x)
Message("DAMAGE", S("-5"), { 1, 0.1, 0.1 })
Frame(0.02)
Check("split in the middle: taken on the right", Newest().x > 80, Newest().x)
shift = -400
Frame(1)
db.selfTextSide, db.selfTextFollow = "free", true

-- 7. Texts go after their time.
Frame(2)
Check("all gone after their time", #Live() == 0, #Live())

-- 8. Who draws: None hides it all; The game's gives the game's back.
db.selfTextBy = "none"
ns.RefreshSelfTextStyle()
count = ns.SelfTextStats.shown
Message("DAMAGE", S("-5"), { 1, 0.1, 0.1 })
Check("none: nothing drawn, game's hidden", ns.SelfTextStats.shown == count and ct._alpha == 0)
db.selfTextBy = "game"
ns.RefreshSelfTextStyle()
Check("game's: its frame back", ct._alpha == 1, ct._alpha)
local copied = ns.SelfTextStats.copied
Message("DAMAGE", S("-4"), { 1, 0.1, 0.1 })
Check("game's: nothing copied", ns.SelfTextStats.copied == copied)
db.selfTextBy = "ours"
ns.RefreshSelfTextStyle()
Check("ours again: hidden", ct._alpha == 0)

-- 9. A Style font, a size.
db.selfTextFont, db.selfTextSize, db.selfTextEdge = "bebas", 2, "edge"
Message("DAMAGE", S("-3"), { 1, 0.1, 0.1 })
Check("size 2", Newest().size == 48, Newest().size)
Check("outline", Newest().flags == "OUTLINE", Newest().flags)
db.selfTextFont, db.selfTextSize, db.selfTextEdge = "game", 1, "game"

-- 10. The page off: the game's back, ours gone.
db.selfTextStyle = false
ns.RefreshSelfTextStyle()
Check("page off: the game's frame back", ct._alpha == 1)
Check("page off: ours gone", #Live() == 0)
db.styleGeneral, db.selfTextStyle = false, true
ns.RefreshSelfTextStyle()
Check("Style hub off: the game's frame back", ct._alpha == 1)

-- 11. The sample.
db.styleGeneral = true
ns.RefreshSelfTextStyle()
ns.SelfTextSample("Overpower!", "alert")
Check("sample drawn", Newest().words == "Overpower!" and Newest().shown)

-- 11b. A reused text blanked before its new words; the game's floating text held on while ours draw.
do
	local reused
	for _, fs in ipairs(made) do if fs.history and #fs.history >= 4 then reused = fs break end end
	local blanked = reused ~= nil
	if reused then
		for i = 1, #reused.history, 2 do if reused.history[i] ~= "" then blanked = false end end
	end
	Check("a reused text blanked before each use", blanked)
	Check("the game's floating text held on while ours draw", ns.SELF_TEXT_GAME_ON.active == true)
	db.selfTextBy = "game"
	ns.RefreshSelfTextStyle()
	Check("and let go for The game's", not ns.SELF_TEXT_GAME_ON.active)
	db.selfTextBy = "ours"
	ns.RefreshSelfTextStyle()
end

-- 11c. BattleText Forever and MSBT: their rows; theirs (the default) makes the page stand aside.
do
	local loadedAddons = { BattleTextForever = true, MikScrollingBattleText_Forever = true }
	C_AddOns.IsAddOnLoaded = function(name) return loadedAddons[name] or false end -- luacheck: ignore 122
	IsAddOnLoaded = C_AddOns.IsAddOnLoaded -- luacheck: ignore 121
	wow.Fire("ADDON_LOADED", "BattleTextForever")
	wow.Fire("ADDON_LOADED", "MikScrollingBattleText_Forever")
	local rows = {}
	for _, row in ipairs(ns.CONFLICTS) do if row.key == "style:selftext" then rows[row.addon] = row end end
	Check("BattleText Forever row", rows["BattleText Forever"] ~= nil)
	Check("MSBT row", rows["MikScrollingBattleText"] ~= nil)
	ns.RefreshSelfTextStyle()
	Check("theirs by default: Text on You stands aside", not ns.StyleOn("selfTextStyle") and ct._alpha == 1)
	db.conflictPicks = { ["BattleText Forever:style:selftext"] = "ours" }
	_G.MikSBT = { IsModDisabled = function() return true end }
	ns.RefreshSelfTextStyle()
	Check("BattleText picked Ours, MSBT off: Text on You draws", ns.StyleOn("selfTextStyle") and ct._alpha == 0)
	Check("Ours: BattleText's incoming listed to hide", type(rows["BattleText Forever"].hide) == "table"
		and rows["BattleText Forever"].hide[1] == "BattleTextForeverIncoming")
	db.conflictPicks = nil
	_G.BattleTextForeverDB = { enabled = false }
	ns.RefreshSelfTextStyle()
	Check("BattleText switched off in its options: Text on You draws", ns.StyleOn("selfTextStyle"))
	_G.MikSBT = nil
	ns.RefreshSelfTextStyle()
	Check("MSBT on: Text on You stands aside", not ns.StyleOn("selfTextStyle") and ct._alpha == 1)
	_G.MikSBT = { IsModDisabled = function() return true end }
	ns.RefreshSelfTextStyle()
end

-- 13. The look's new parts (2026-11-21, the page's redesign).
local NewText = layer.CreateFontString
local function Fresh()
	for _, key in ipairs({ "selfTextMerge", "selfTextMost", "selfTextSticky", "selfTextShadow", "selfTextFade",
		"selfTextAcross", "selfTextSide", "selfTextMotion", "selfTextSize", "selfTextCrit", "selfTextFont", "selfTextEdge",
		"selfTextLife", "selfTextHeight", "selfTextFollow", "selfTextAlways", "selfTextBy" }) do
		db[key] = ns.DEFAULTS[key]
	end
	for _, group in ipairs(ns.SELF_TEXT_GROUPS) do
		for _, part in ipairs(ns.SELF_TEXT_PARTS) do
			local key = "selfText_" .. group.id .. part
			db[key] = ns.DEFAULTS[key]
		end
	end
	shift = 0
	Frame(3)
end
db.styleGeneral, db.selfTextStyle = true, true
ns.RefreshSelfTextStyle()
Fresh()

-- Merge repeats: the same kind within half a second, one text "x2"; a crit,
-- another kind, or after the window: its own.
local first = ns.SelfTextSample("-5", "damage")
now = now + 0.1
local merged = ns.SelfTextSample("-6", "damage")
Check("merge: the second merged into the first", merged == nil and first.formatted ~= nil
	and first.formatted[1] == "%s x%d" and first.formatted[2] == "-6" and first.formatted[3] == 2)
local critText = ns.SelfTextSample("-50", "damage", true)
Check("merge: a crit has its own", critText ~= nil)
Check("merge: another kind has its own", ns.SelfTextSample("+5", "heal") ~= nil)
now = now + 0.6
Check("merge: after the window its own", ns.SelfTextSample("-7", "damage") ~= nil)
db.selfTextMerge = false
Check("merge off: each its own", ns.SelfTextSample("-8", "damage") ~= nil and ns.SelfTextSample("-9", "damage") ~= nil)
Fresh()

-- At most: the oldest go.
db.selfTextMost, db.selfTextMerge = 3, false
for i = 1, 5 do ns.SelfTextSample("-" .. i, "damage") end
Check("at most 3 at once", #Live() == 3, #Live())
Fresh()

-- A kind's own parts.
db.selfTextMerge = false
db.selfText_damageSize = 2
Check("kind size 2", ns.SelfTextSample("-1", "damage").size == 48)
db.selfText_damageSize = 1
db.selfText_healCrit = 3
Check("kind crit size", ns.SelfTextSample("+1", "heal", true).size == 72)
db.selfText_damageFont = "bebas"
local fontText = ns.SelfTextSample("-2", "damage")
Check("kind font", tostring(fontText.file):find("Bebas", 1, true) ~= nil, fontText.file)
db.selfText_damageFont = "general"
db.selfText_missSide = "left"
local leftText = ns.SelfTextSample("Dodge", "miss")
Frame(0.04)
Check("kind side left", leftText.x < -80, leftText.x)
db.selfText_missMotion = "down"
local downText = ns.SelfTextSample("Parry", "miss")
Frame(0.04)
local y1 = downText.y
Frame(0.3)
Check("kind motion down", downText.y < y1, ("%s -> %s"):format(tostring(y1), tostring(downText.y)))
db.selfText_shieldShow = false
Check("kind switched off: not drawn", ns.SelfTextSample("Absorb", "shield") == nil)
db.selfText_shieldShow, db.selfText_shieldColor = true, "off"
Check("kind's old Hidden color: not drawn", ns.SelfTextSample("Absorb", "shield") == nil)
db.selfText_shieldColor = "custom"
db.selfText_shieldR, db.selfText_shieldG, db.selfText_shieldB = 0.1, 0.2, 0.3
local ownText = ns.SelfTextSample("Absorb", "shield")
Check("kind's own color", ownText.color[1] == 0.1 and ownText.color[3] == 0.3)
Fresh()

-- Crits stay: a crit lasts its time and STICK more, and barely moves.
db.selfTextSticky, db.selfTextLife, db.selfTextMerge = true, 1, false
local stay = ns.SelfTextSample("-90", "damage", true)
local plain = ns.SelfTextSample("-9", "damage")
Frame(0.04)
local stayY = stay.y
Frame(0.4)
Check("a staying crit barely moves", math.abs(stay.y - stayY) < 5, ("%s -> %s"):format(tostring(stayY), tostring(stay.y)))
Frame(0.8)
Check("past its time: the hit gone, the crit still up", not plain.shown and stay.shown)
Frame(1.2)
Check("then the crit goes too", not stay.shown)
Fresh()

-- Shadow strength, fade, across.
db.selfTextShadow = 0.5
Check("shadow strength", ns.SelfTextSample("-1", "damage").shadowAlpha == 0.5)
Fresh()
db.selfTextFade, db.selfTextLife = 0.3, 1
local fading = ns.SelfTextSample("-1", "damage")
Frame(0.5)
Check("fades from 30%", fading.alpha < 1 and fading.alpha > 0, fading.alpha)
Fresh()
db.selfTextAcross, db.selfTextSide = 100, "over"
local acrossText = ns.SelfTextSample("-1", "damage")
Frame(0.04)
Check("across 100", math.abs(acrossText.x - 100) < 1, acrossText.x)
Fresh()

-- The Show in row: not Always, and the row says no here: the game's text.
db.selfTextAlways = false
local rowSays = false
ns.RowOnNow = function(key) return key == ns.SELF_TEXT_ROW and rowSays end
now = now + 1
ns.RefreshSelfTextStyle()
Check("Show in off here: the game's", ns.SelfTextState().by == "game" and ct._alpha == 1)
rowSays = true
now = now + 1
ns.RefreshSelfTextStyle()
Check("Show in on here: ours", ns.SelfTextState().by == "ours" and ct._alpha == 0)
db.selfTextAlways = true
Fresh()

-- Sounds: a kind's, once per 0.3 s, the screen's only.
local played = {}
SOUNDKIT = { MAP_PING = 101, RAID_WARNING = 102, IG_MAINMENU_OPTION_CHECKBOX_ON = 103 } -- luacheck: ignore 121
PlaySound = function(kit) played[#played + 1] = kit end -- luacheck: ignore 121
db.selfText_lowSound, db.selfTextMerge = "alarm", false
ns.SelfTextSample("Mana Low", "low")
ns.SelfTextSample("Mana Low", "low")
Check("a kind's sound, once in 0.3 s", #played == 1 and played[1] == 102, #played)
now = now + 0.4
ns.SelfTextSample("Mana Low", "low")
Check("and again after", #played == 2)
Fresh()

-- The game's Text on Me ticks, read only.
local cvars = { floatingCombatTextComboPoints_v2 = "0", floatingCombatTextAuras_v2 = "1",
	floatingCombatTextRepChanges_v2 = "0", floatingCombatTextHonorGains_v2 = "1" }
local setAny = false
local realGet, realSet = GetCVar, SetCVar
GetCVar = function(name) return cvars[name] end -- luacheck: ignore 121
SetCVar = function(...) setAny = true return realSet(...) end -- luacheck: ignore 121
Check("tick off", ns.SelfTextGameTick("combo") == "off")
Check("tick on", ns.SelfTextGameTick("aura") == "on")
Check("either of two ticks on", ns.SelfTextGameTick("reward") == "on")
Check("no tick: nil", ns.SelfTextGameTick("damage") == nil)
Check("ticks never set", not setAny)
GetCVar, SetCVar = realGet, realSet -- luacheck: ignore 121

-- This fight's counts: a new fight starts them over.
ns.SelfTextStats.fight.copied = 9
wow.Fire("PLAYER_REGEN_DISABLED")
Check("a new fight's counts", ns.SelfTextStats.fight.copied == 0)

-- The preview's board: its own texts, scaled, placed from its anchor, no
-- sounds or counts.
do
	local previewLayer = CreateFrame("Frame")
	previewLayer.CreateFontString = NewText
	local anchor = CreateFrame("Frame")
	local board = ns.SelfTextNewBoard(previewLayer, anchor, 0.5, function() return -200 end)
	local shownBefore = ns.SelfTextStats.shown
	played = {}
	db.selfText_lowSound, db.selfTextMerge = "alarm", false
	local t = ns.SelfTextSample("Mana Low", "low", false, board)
	Check("preview: drawn on its board", t ~= nil and #board.live == 1 and #ns.SelfTextScreenBoard.live == 0)
	Check("preview: scaled", t and t.size == 12, t and t.size)
	Check("preview: no counts, no sound", ns.SelfTextStats.shown == shownBefore and #played == 0)
	local update = previewLayer._scripts.OnUpdate
	update(previewLayer, 5) -- (eased straight to you)
	update(previewLayer, 0.02)
	Check("preview: from its anchor, your spot scaled", t and math.abs(t.x - (-200 - 90) * 0.5) < 2, t and t.x)
	local g = ns.SelfTextGameSample("-26", "damage", board)
	Check("preview: the game's look, over you, its size", g and g.side == 0 and g.size == 12 and db.selfTextSize == 1)
	board:Clear()
	Check("preview: cleared", #board.live == 0)
end
Fresh()

-- 14. From the in-game run 2 (2026-11-21): Pop's texts kept a line apart;
-- the game's look in the middle, not over you; a board's lift.
db.selfTextMotion, db.selfTextMerge, db.selfTextSide = "pop", false, "over"
local p1 = ns.SelfTextSample("-1", "damage")
local p2 = ns.SelfTextSample("-2", "damage")
Frame(0.1)
Check("pop: texts on a side a line apart", math.abs(p1.y - p2.y) >= p2.line * 0.95,
	("%.1f apart, a line %.1f"):format(math.abs(p1.y - p2.y), p2.line))
Fresh()
do
	local previewLayer = CreateFrame("Frame")
	previewLayer.CreateFontString = NewText
	local board = ns.SelfTextNewBoard(previewLayer, previewLayer, 0.5, function() return -200 end, -40)
	db.selfTextAcross, db.selfTextHeight = 60, 30
	local mine = ns.SelfTextSample("-3", "damage", false, board)
	local game = ns.SelfTextGameSample("-26", "damage", board)
	local update = previewLayer._scripts.OnUpdate
	update(previewLayer, 5)
	update(previewLayer, 0.01)
	Check("the game's look: in the middle, not over you", math.abs(game.x) < 1, game.x)
	-- (The game's look at the board's middle spot, no lift: MIDDLE_Y, 50, here.)
	Check("the game's look: no Across, Height or lift", math.abs(game.y - 50 * 0.5) < 3, game.y)
	Check("ours: your spot, Across, Height and the lift", math.abs(mine.x - (-200 + 60 + 90 * -1) * 0.5) < 2
		and mine.y > (30 - 40) * 0.5 - 1, ("%s %s"):format(tostring(mine.x), tostring(mine.y)))
	board:Clear()
end
Fresh()

-- 15. From run 3: a staying crit in a lane of its own, so a hit climbs past it.
db.selfTextSticky, db.selfTextMerge, db.selfTextSide = true, false, "over"
local held = ns.SelfTextSample("-74", "damage", true)
local passing = ns.SelfTextSample("-20", "damage")
Frame(0.1)
Check("a staying crit sits out of the hits' way", math.abs(held.x - passing.x) >= 40,
	("%s vs %s"):format(tostring(held.x), tostring(passing.x)))
Fresh()

-- 12. The page builds, its controls refresh.
do
	local kit, controls = ns.lowHealthKit, {}
	local page = setmetatable({
		AddControl = function(control) controls[#controls + 1] = control end,
		RegisterSubpage = function(_, id) controls.id = id end,
		Refresh = function() for _, control in ipairs(controls) do if control.Refresh then pcall(control.Refresh, control) end end end,
	}, { __index = kit })
	local ok, err = pcall(ns.CreateSelfTextStylePanel, page)
	Check("page builds", ok, err)
	Check("registered as Self Text Style", controls.id == "Self Text Style", controls.id)
end

for _, warning in ipairs(wow.warnings) do
	if warning:find("SelfText", 1, true) then Check("load: " .. warning, false) end
end
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
