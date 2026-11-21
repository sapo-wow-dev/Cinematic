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
		self.words = words
		self.history = self.history or {}
		self.history[#self.history + 1] = words
		lastSet = self
	end
	fs.SetShadowColor = function() end
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
db.selfTextFollow = false
Frame(1)
Message("DAMAGE", S("-7"), { 1, 0.1, 0.1 })
Frame(0.02)
Check("follow off: the middle", math.abs(Newest().x) < 100, Newest().x)
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
