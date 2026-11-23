-- Cooldown Manager "Missing" buff mode (dev tool, offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/cdmmissing.lua < /dev/null
-- UI/CooldownMissing.lua, 2026-11-23: a tracked buff set to Missing shows
-- while the buff is off you and fades while it's on. On stand-in buff icons
-- (Hide When Inactive on, so the game hides an inactive one): a Missing icon
-- off you is shown, and shown again each time the game hides it; on you, left
-- to the game and faded; Missing taken off, hidden again (only with Hide When
-- Inactive on); a protected icon in a fight refused, never touched; the
-- page off puts everything back; a spare icon (no cooldown ID) and one the
-- pool let go stay hidden; no Missing anywhere, no walk. Says PASS or FAIL
-- per check. In game: /cine debug cdmgrid (steps missing, missingfight).
local fighting = false

-- luacheck: push ignore 111 112 113 121 122 212
local ns = dofile("Tools/offline/load.lua")("forever", arg and arg[1], function()
	InCombatLockdown = function() return fighting end
end)
-- luacheck: pop

-- (A real post-hook after load, for the Missing hook alone: the stand-in's
-- does nothing, and the addon's load hooks stand-ins it can't wrap.)
-- luacheck: push ignore 111 121 122
hooksecurefunc = function(a, b, c)
	local tbl, name, fn = a, b, c
	if type(a) == "string" then tbl, name, fn = _G, a, b end
	local orig = tbl[name]
	if type(orig) ~= "function" then return end
	tbl[name] = function(...)
		local r = { orig(...) }
		fn(...)
		return unpack(r)
	end
end
-- luacheck: pop

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local db = ns.db
for _, start in ipairs({ "handleCooldowns", ns.CDM_TABS.buffs }) do
	local switch = start
	while switch do
		db[switch] = true
		switch = ns.PageSwitchOf(switch)
	end
end

-- Stand-in buff icons: shown state, the game's SetShown, a hook list.
local function Icon(id, active, cooldownID)
	local icon = { id = id, shown = false, hideWhenInactive = true, cooldownID = cooldownID or id,
		auraInstanceID = active and 5 or nil, protected = false, shows = 0, hides = 0 }
	function icon:IsShown() return self.shown end
	function icon:Show() self.shown = true self.shows = self.shows + 1 end
	function icon:Hide() self.shown = false self.hides = self.hides + 1 end
	function icon:SetShown(shown) self.shown = shown and true or false end
	function icon:IsProtected() return self.protected end
	function icon:IsForbidden() return false end
	return icon
end
-- (The game's UpdateShownState, as CooldownViewer.lua has it.)
local function GameUpdate(icon)
	icon:SetShown(icon.cooldownID ~= nil and (not icon.hideWhenInactive or icon.auraInstanceID ~= nil))
end

local SKIN, ARMOR, SPARE = 687, 706, 9999
local icons = { Icon(SKIN, false), Icon(ARMOR, true), Icon(SPARE, false, nil) }
icons[3].cooldownID = nil
local walks = 0
ns.EachCooldownIcon = function(visit)
	walks = walks + 1
	for _, icon in ipairs(icons) do visit(icon, icon.id, "BuffIconCooldownViewer") end
end
ns.CooldownIconSpellOf = function(icon) return icon.id end
for _, icon in ipairs(icons) do GameUpdate(icon) end
local skin, armor, spare = icons[1], icons[2], icons[3]

-- The mode's rule.
Check("Missing, buff off you: shows", ns.CooldownBuffShows("missing", false, skin) == true)
Check("Missing, buff on you: faded", ns.CooldownBuffShows("missing", true, armor) == false)
Check("Missing with no icon (the debug line): shows", ns.CooldownBuffShows("missing", false) == true)
Check("the grid has the word", ns.COOLDOWN_SHORT_MODE.missing ~= nil)

-- Nothing Missing: no walk, nothing touched.
ns.CooldownMissingPass()
Check("no Missing anywhere: no walk", walks == 0, walks)
Check("no Missing: the game's hidden icon stays hidden", skin.shown == false)

-- Missing on both.
db.cooldownBuffMode[SKIN], db.cooldownBuffMode[ARMOR] = "missing", "missing"
db.cooldownBuffMode[SPARE] = "missing"
Check("own mode read back", ns.CooldownBuffMode(SKIN, "buffs") == "missing")
ns.CooldownMissingPass()
Check("off you: shown", skin.shown == true and ns.CooldownMissingShownHere(skin))
Check("on you: left to the game (shown, faded by the ready pass)", armor.shown == true and not ns.CooldownMissingShownHere(armor))
Check("spare icon (no cooldown ID): stays hidden", spare.shown == false)
-- The game hides it again on its own update: shown again by the hook.
GameUpdate(skin)
Check("the game's SetShown(false): shown again at once", skin.shown == true)
-- The buff put on: the game shows it, ours no more.
skin.auraInstanceID = 6
GameUpdate(skin)
ns.CooldownMissingPass()
Check("buff put on: the game's, not ours", skin.shown == true and not ns.CooldownMissingShownHere(skin))
Check("buff put on: faded", ns.CooldownBuffShows(ns.CooldownBuffMode(SKIN, "buffs"), false, skin) == false)
-- Off again: the game hides it, the hook brings it back.
skin.auraInstanceID = nil
GameUpdate(skin)
Check("buff off again: shown", skin.shown == true and ns.CooldownMissingShownHere(skin))

-- The pool lets it go (Hide, not SetShown): stays hidden.
skin:Hide()
Check("pool's Hide: not shown again", skin.shown == false)
ns.CooldownMissingPass()
Check("next pass: shown again (still in the bar, still Missing)", skin.shown == true)

-- Missing taken off: hidden again, as the game has it.
db.cooldownBuffMode[SKIN] = nil
ns.CooldownMissingPass()
Check("Missing off: hidden again", skin.shown == false and not ns.CooldownMissingShownHere(skin))
-- Hide When Inactive off: the game shows it, never hidden by us.
db.cooldownBuffMode[SKIN] = "missing"
skin.hideWhenInactive = false
GameUpdate(skin)
ns.CooldownMissingPass()
db.cooldownBuffMode[SKIN] = nil
local hidesBefore = skin.hides
ns.CooldownMissingPass()
Check("Hide When Inactive off: left shown", skin.shown == true and skin.hides == hidesBefore)
skin.hideWhenInactive = true
GameUpdate(skin)

-- A protected icon in a fight: refused, not touched.
db.cooldownBuffMode[SKIN] = "missing"
skin.protected, fighting = true, true
local refused, showsBefore = ns.cooldownMissingStats.refused, skin.shows
GameUpdate(skin)
Check("protected in a fight: refused", skin.shown == false and skin.shows == showsBefore
	and ns.cooldownMissingStats.refused > refused)
skin.protected = false
GameUpdate(skin)
Check("not protected in a fight: shown", skin.shown == true)
fighting = false

-- The page off: everything put back, no walk.
db.handleCooldowns = false
walks = 0
ns.CooldownMissingPass()
Check("page off: put back", skin.shown == false, skin.shown)
Check("page off: no walk", walks == 0, walks)
GameUpdate(skin)
Check("page off: the game's hide stays", skin.shown == false)
db.handleCooldowns = true

-- A bar's own mode Missing (the Buffs row) counts.
db.cooldownBuffMode = {}
db.cooldownGroupDefaults.buffs = db.cooldownGroupDefaults.buffs or {}
db.cooldownGroupDefaults.buffs.mode = "missing"
Check("the bar's mode Missing counts", ns.CooldownMissingAny() == true)
db.cooldownGroupDefaults.buffs.mode = nil
Check("and none left: none", ns.CooldownMissingAny() == false)

-- Any caster (2026-11-23): the game's icon lights for your own casts only;
-- your buffs are read here out of fights, anyone's counting, by name.
local FORT, PRAYER = 1243, 21562 -- (Power Word: Fortitude, Prayer of Fortitude)
local NAMES = { [FORT] = "Power Word: Fortitude", [PRAYER] = "Prayer of Fortitude", [SKIN] = "Demon Skin" }
local onYou = {} -- { name =, sourceUnit = }
local readsInFight = 0
-- luacheck: push ignore 111 112 121 122
C_Spell = C_Spell or {}
C_Spell.GetSpellName = function(id) return NAMES[id] end
C_UnitAuras = C_UnitAuras or {}
C_UnitAuras.GetAuraDataByIndex = function(unit, i)
	if fighting then
		readsInFight = readsInFight + 1
		error("Auras cannot be accessed when secret while tainted")
	end
	return unit == "player" and onYou[i] or nil
end
UnitAffectingCombat = function() return fighting end
-- luacheck: pop
local fort = Icon(FORT, false)
icons = { fort }
GameUpdate(fort)
db.cooldownBuffMode = { [FORT] = "missing" }
local function Aura(name, source) onYou[#onYou + 1] = { name = name, sourceUnit = source } end

local function Reread() for k in pairs(onYou) do onYou[k] = nil end end

-- Nothing on you: the reminder shows.
ns.CooldownReadBuffs()
ns.CooldownMissingPass()
Check("any caster: none on you, shown", fort.shown == true)
-- Another priest's Fortitude: the icon stays dark (not yours), no reminder.
Aura("Power Word: Fortitude", "party1")
ns.CooldownReadBuffs()
Check("another's Fortitude counts as on you", ns.CooldownBuffOnYou(fort) == true)
Check("another's Fortitude: faded", ns.CooldownBuffShows("missing", false, fort) == false)
ns.CooldownMissingPass()
GameUpdate(fort)
Check("another's Fortitude: not shown by us (the game hides the dark icon)", fort.shown == false)
-- In a fight: not read (it'd error), someone else's still counts.
fighting = true
Check("in a fight: another's buff from before still counts", ns.CooldownBuffOnYou(fort) == true)
Check("in a fight: no aura read tried", readsInFight == 0, readsInFight)
fighting = false
-- Your own Fortitude, read out of fights: on; in a fight, the icon decides.
Reread()
Aura("Power Word: Fortitude", "player")
ns.CooldownReadBuffs()
Check("your own, out of a fight: on", ns.CooldownBuffOnYou(fort) == true)
fighting = true
Check("your own, in a fight, icon dark: off (the icon drops it as it ends)", ns.CooldownBuffOnYou(fort) == false)
fort.auraInstanceID = 9
Check("your own, in a fight, icon lit: on", ns.CooldownBuffOnYou(fort) == true)
fort.auraInstanceID = nil
fighting = false
-- Gone: read again on the next look (UNIT_AURA marks it), shown.
Reread()
ns.CooldownReadBuffs()
Check("gone: off", ns.CooldownBuffOnYou(fort) == false)
Check("its names: the spell's", ns.CooldownBuffNames(fort)[1] == "Power Word: Fortitude")

-- Groups (mockup B, 2026-11-23): buffs that count as one, the lead's settings.
NAMES[ARMOR] = "Demon Armor"
-- (The earlier stand-ins let go, as the pool does: no cooldown ID.)
skin.cooldownID, armor.cooldownID, fort.cooldownID = nil, nil, nil
local dskin, darmor = Icon(SKIN, false), Icon(ARMOR, false)
icons = { dskin, darmor }
for _, icon in ipairs(icons) do GameUpdate(icon) end
Reread()
ns.CooldownReadBuffs()
db.cooldownBuffMode = { [ARMOR] = "hidden" } -- (Demon Armor's own, kept for an Ungroup)
db.cooldownBuffGroups = {}
Check("not grouped: its own mode", ns.CooldownBuffMode(ARMOR, "buffs") == "hidden")
Check("group made, lead first", ns.SetCooldownBuffGroup({ SKIN, ARMOR }) == SKIN)
Check("a member follows the lead's mode", ns.CooldownBuffMode(ARMOR, "buffs") ~= "hidden")
db.cooldownBuffMode[SKIN] = "missing"
Check("lead set Missing: the member too", ns.CooldownBuffMode(ARMOR, "buffs") == "missing")
-- Missing: any one, none on: one reminder, the first member's icon.
ns.CooldownMissingPass()
Check("any one, none on: the first's icon shown", dskin.shown == true)
Check("any one, none on: the other not shown", darmor.shown == false)
Check("any one: the other faded if the game shows it", ns.CooldownBuffShows("missing", false, darmor) == false)
-- Demon Armor on (its icon lit): no reminder at all.
darmor.auraInstanceID = 3
GameUpdate(darmor)
Check("any one, Armor on: Skin faded", ns.CooldownBuffShows("missing", false, dskin) == false)
ns.CooldownMissingPass()
Check("any one, Armor on: Skin put back (hidden)", dskin.shown == false)
Check("any one, Armor on: Armor faded", ns.CooldownBuffShows("missing", false, darmor) == false)
-- Missing: each: each its own reminder.
db.cooldownBuffMode[SKIN] = "missingeach"
ns.CooldownMissingPass()
Check("each, Armor on: Skin shown", dskin.shown == true)
Check("each, Armor on: Armor faded", ns.CooldownBuffShows("missingeach", false, darmor) == false)
darmor.auraInstanceID = nil
GameUpdate(darmor)
ns.CooldownMissingPass()
Check("each, both off: both shown", dskin.shown == true and darmor.shown == true)
-- A member with no icon in the bar, put on by someone else: any one counts it.
db.cooldownBuffMode[SKIN] = "missing"
ns.SetCooldownBuffGroup({ SKIN, FORT })
Check("merged: the group brings its members", #ns.CooldownBuffMembers(SKIN) == 3, #ns.CooldownBuffMembers(SKIN))
Aura("Power Word: Fortitude", "party1")
ns.CooldownReadBuffs()
ns.CooldownMissingPass()
Check("any one, a member off the bar read on you: no reminder", ns.CooldownBuffShows("missing", false, dskin) == false)
Reread()
ns.CooldownReadBuffs()
-- The lead's icon gone from the bar: the next member's shows.
icons = { darmor }
dskin.cooldownID = nil
ns.CooldownMissingPass()
Check("lead not in the bar: the next member's icon is the reminder", darmor.shown == true
	and ns.CooldownBuffShows("missing", false, darmor) == true)
dskin.cooldownID = SKIN
icons = { dskin, darmor }
-- Ungroup: each its own settings again.
ns.UngroupCooldownBuff(SKIN)
Check("ungrouped: Armor's own mode back", ns.CooldownBuffMode(ARMOR, "buffs") == "hidden")
Check("ungrouped: no lead", ns.CooldownBuffLead(ARMOR) == nil)
-- Ready-made alternatives: Demon Skin on Missing, Demon Armor on you (yours,
-- read): no reminder; in a fight the read from before still counts.
db.cooldownBuffMode = { [SKIN] = "missing" }
db.cooldownBuffGroups = {}
ns.CooldownBuffAlternativesReset()
Check("Demon Skin's alternatives: Demon Armor", (ns.CooldownBuffAlternatives("Demon Skin") or {})[1] == "Demon Armor")
Check("Fortitude's: Prayer of Fortitude", (ns.CooldownBuffAlternatives("Power Word: Fortitude") or {})[1] == "Prayer of Fortitude")
Reread()
Aura("Demon Armor", "player")
ns.CooldownReadBuffs()
darmor.cooldownID = nil -- (Demon Armor not tracked: only Demon Skin's icon in the bar)
icons = { dskin }
ns.CooldownMissingPass()
Check("alternative on you (yours): no reminder", ns.CooldownBuffShows("missing", false, dskin) == false and dskin.shown == false)
fighting = true
Check("in a fight: the alternative read before still counts", ns.CooldownBuffShows("missing", true, dskin) == false)
fighting = false
Reread()
ns.CooldownReadBuffs()
ns.CooldownMissingPass()
Check("alternative gone: the reminder", dskin.shown == true)
-- Prayer of Fortitude from another priest counts for a Fortitude reminder.
fort.cooldownID = FORT
icons = { fort }
db.cooldownBuffMode = { [FORT] = "missing" }
Aura("Prayer of Fortitude", "party2")
ns.CooldownReadBuffs()
Check("Prayer of Fortitude counts for Fortitude", ns.CooldownBuffOnYou(fort) == true)
Reread()
ns.CooldownReadBuffs()
Check("Missing: each counts as Missing anywhere", (function()
	db.cooldownBuffMode = { [SKIN] = "missingeach" }
	return ns.CooldownMissingAny()
end)())


print(fails == 0 and "ALL PASS" or (fails .. " FAIL"))
