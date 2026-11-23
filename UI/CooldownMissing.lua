-- Cinematic: the Cooldown Manager's Missing mode for tracked buffs
-- (2026-11-23). A tracked buff (or bar) set to Missing shows while the buff
-- is off you, a reminder to put it back on, and fades while it's on
-- (ns.CooldownBuffShows, Frames.lua). With the bar's Hide When Inactive on
-- (Edit Mode), the game hides a buff's icon while it's off you. Its place
-- stays in the bar (the game's template lays hidden icons out too,
-- includeAsLayoutChildWhenHidden), so each time the game hides a Missing
-- one, it's shown again here. Only our Show(): no field of the game's icon
-- is written and none of its code is called (its reads go secret in fights).
-- Hidden again once it's no longer Missing. Probed by /cine debug cdmgrid
-- missing (Tools/tests/cdm-missing-buff.md).
local _, ns = ...

local hooked = setmetatable({}, { __mode = "k" }) -- icon -> true once its SetShown is hooked
local shownHere = setmetatable({}, { __mode = "k" }) -- icon -> true while shown here, not by the game
local groupOf = setmetatable({}, { __mode = "k" }) -- icon -> its bar's group ("buffs", "bars")
-- (Counts for the test and the debug line: icons shown here, Shows refused
-- (protected in a fight), and put back.)
local stats = { shown = 0, refused = 0, putBack = 0 }
ns.cooldownMissingStats = stats

local function Flag(value)
	if issecretvalue and issecretvalue(value) then return false end
	return value and true or false
end

-- Whether a tracked buff icon's buff is on you (plain in fights too: the
-- icon's aura instance is secret there, its type isn't).
local function Active(icon)
	return type(icon.auraInstanceID) ~= "nil"
end
ns.CooldownBuffActive = Active

-- Whether a buff is on you from anyone (the user, 2026-11-23: "any caster").
-- The game's icon lights for your own casts only (its NeedsAddedAuraUpdate
-- skips an aura whose sourceUnit isn't "player"), so another priest's
-- Fortitude left it dark. Out of fights your buffs are read here by name
-- (any rank, any caster); in fights those reads are refused on Forever
-- (rule forever.auras.fight-apis-error), so there: the icon, or a buff
-- someone else put on you before the fight (yours go by the icon: it drops
-- them as they end).
local readNames = {} -- buff name -> "player" (yours) or "other" (anyone else's)
local readDirty = true
local function GetName(id)
	if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
	return (GetSpellInfo(id))
end
local function Fighting() return InCombatLockdown() or Flag(UnitAffectingCombat("player")) end

local function Plain(value)
	if issecretvalue and issecretvalue(value) then return nil end
	return value
end
-- Your buffs now, out of fights only; false when they can't be read.
function ns.CooldownReadBuffs()
	if Fighting() then return false end
	local read = {}
	local byIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
	for i = 1, 80 do
		local name, source
		if byIndex then
			local ok, aura = pcall(byIndex, "player", i, "HELPFUL")
			if not ok then return false end
			if type(aura) ~= "table" then break end
			name, source = Plain(aura.name), Plain(aura.sourceUnit)
		elseif UnitBuff then
			local ok, auraName, _, _, _, _, _, caster = pcall(UnitBuff, "player", i)
			if not ok then return false end
			if auraName == nil then break end
			name, source = Plain(auraName), Plain(caster)
		else
			return false
		end
		if type(name) == "string" and read[name] ~= "other" then
			read[name] = source == "player" and "player" or "other"
		end
	end
	readNames, readDirty = read, false
	return true
end
-- (For the test: what was read.)
function ns.CooldownReadBuffNames() return readNames end

-- The names an icon's buff goes by: its spell's, and its linked auras'.
local namesOf = setmetatable({}, { __mode = "k" }) -- icon -> { cooldownID, names }
local function NamesOf(icon)
	local kept = namesOf[icon]
	if kept and kept.id == icon.cooldownID then return kept.names end
	local names, seen = {}, {}
	local function Add(id)
		id = Plain(id)
		if type(id) ~= "number" then return end
		local ok, name = pcall(GetName, id)
		name = ok and Plain(name)
		if type(name) == "string" and not seen[name] then
			seen[name] = true
			names[#names + 1] = name
		end
	end
	Add(ns.CooldownIconSpellOf and ns.CooldownIconSpellOf(icon))
	local info = ns.IconCooldownInfo and ns.IconCooldownInfo(icon)
	if type(info) == "table" then
		Add(info.spellID)
		Add(info.overrideSpellID)
		local linked = Plain(info.linkedSpellIDs)
		if type(linked) == "table" then
			for _, id in ipairs(linked) do Add(id) end
		end
	end
	if #names > 0 then namesOf[icon] = { id = icon.cooldownID, names = names } end
	return names
end
ns.CooldownBuffNames = NamesOf

-- Ready-made alternatives (2026-11-23): buffs that stand in for each other,
-- any rank (by name, so each client's own words): a buff set Missing counts
-- as on you while one of its alternatives is, cast by anyone. Used by Missing
-- alone, so nothing changes for anyone else. Paladin blessings pair with
-- their Greater blessing only (Might and Kings from two paladins both go on).
-- An ID a client hasn't got gives no name and drops out.
local ALTERNATIVES = {
	{ 1243, 21562 }, -- Power Word: Fortitude, Prayer of Fortitude
	{ 14752, 27681 }, -- Divine Spirit, Prayer of Spirit
	{ 976, 27683 }, -- Shadow Protection, Prayer of Shadow Protection
	{ 1459, 23028 }, -- Arcane Intellect, Arcane Brilliance
	{ 1126, 21849 }, -- Mark of the Wild, Gift of the Wild
	{ 19740, 25782 }, -- Blessing of Might, Greater Blessing of Might
	{ 19742, 25894 }, -- Blessing of Wisdom, Greater Blessing of Wisdom
	{ 20217, 25898 }, -- Blessing of Kings, Greater Blessing of Kings
	{ 1038, 25895 }, -- Blessing of Salvation, Greater Blessing of Salvation
	{ 20911, 25899 }, -- Blessing of Sanctuary, Greater Blessing of Sanctuary
	{ 19977, 25890 }, -- Blessing of Light, Greater Blessing of Light
	{ 687, 706, 28176 }, -- Demon Skin, Demon Armor, Fel Armor
	{ 168, 7302, 6117, 30482 }, -- Frost Armor, Ice Armor, Mage Armor, Molten Armor
	{ 324, 24398 }, -- Lightning Shield, Water Shield
}
ns.COOLDOWN_BUFF_ALTERNATIVES = ALTERNATIVES
local altNames, altTries = nil, 0 -- name -> { its alternatives' names }
local function AltNames()
	if altNames then return altNames end
	local built, missingName = {}, false
	for _, set in ipairs(ALTERNATIVES) do
		local names = {}
		for _, id in ipairs(set) do
			local ok, name = pcall(GetName, id)
			name = ok and Plain(name)
			if type(name) == "string" then names[#names + 1] = name else missingName = true end
		end
		for _, name in ipairs(names) do
			built[name] = built[name] or {}
			for _, other in ipairs(names) do
				if other ~= name then table.insert(built[name], other) end
			end
		end
	end
	-- (Spell names can come late at login: tried again a few times.)
	altTries = altTries + 1
	if not missingName or altTries >= 5 then altNames = built end
	return built
end
-- (Built again on entering the world, and for the offline check.)
function ns.CooldownBuffAlternativesReset() altNames, altTries = nil, 0 end
-- A buff's ready-made alternatives (names), or nil.
function ns.CooldownBuffAlternatives(name)
	local list = type(name) == "string" and AltNames()[name]
	return list and #list > 0 and list or nil
end

-- Whether any of these names is on you as read: its own (in a fight, yours
-- go by the icon), or an alternative's (any caster; in a fight the read from
-- before it: the icon doesn't track an alternative).
local function NamesOnYou(names, fighting)
	for _, name in ipairs(names) do
		local who = readNames[name]
		if who == "other" or (who == "player" and not fighting) then return true end
	end
	for _, name in ipairs(names) do
		for _, alt in ipairs(ns.CooldownBuffAlternatives(name) or {}) do
			if readNames[alt] then return true end
		end
	end
	return false
end

local function OnYou(icon)
	if Active(icon) then return true end
	local fighting = Fighting()
	if readDirty and not fighting then ns.CooldownReadBuffs() end
	return NamesOnYou(NamesOf(icon), fighting)
end
ns.CooldownBuffOnYou = OnYou

-- ---------------------------------------------------------------------------
-- Buff groups (2026-11-23, mockup B): tracked buffs that count as one, as
-- Demon Skin or Demon Armor, Fortitude or Prayer of Fortitude. Ticked rows on
-- the page, Count as one buff: one row in the grid, its settings kept under
-- its first buff's ID (the lead), so every mode and scene cell works on it
-- as on any buff. db.cooldownBuffGroups: lead's base spell ID -> { lead,
-- member, ... } (base IDs, the page's order). Each member follows the lead's
-- mode (ns.CooldownBuffKey). Missing on a group ("Missing: any one"): one
-- reminder, the first member's icon in the bar, while none of them is on
-- you; "Missing: each" (missingeach): each member a reminder of its own.
local leadOf, builtFrom, builtVersion = {}, nil, -1
local groupsVersion = 0
local function Groups()
	local d = ns.db
	if not d then return {} end
	if type(d.cooldownBuffGroups) ~= "table" then d.cooldownBuffGroups = {} end
	return d.cooldownBuffGroups
end
local function Base(id)
	if ns.BaseSpell then
		local ok, base = pcall(ns.BaseSpell, id)
		if ok and type(base) == "number" then return base end
	end
	return id
end
local function Map()
	local groups = Groups()
	if builtFrom ~= groups or builtVersion ~= groupsVersion then
		wipe(leadOf)
		for lead, members in pairs(groups) do
			if type(members) == "table" then
				for _, id in ipairs(members) do leadOf[id] = lead end
				leadOf[lead] = lead
			end
		end
		builtFrom, builtVersion = groups, groupsVersion
	end
	return leadOf
end
-- A buff's group lead (nil: in no group).
function ns.CooldownBuffLead(id)
	if type(id) ~= "number" then return nil end
	local map = Map()
	return map[id] or map[Base(id)]
end
-- The key a buff's settings are kept under: its group's lead, else itself.
function ns.CooldownBuffKey(id)
	return ns.CooldownBuffLead(id) or id
end
-- A group's members (lead first), or nil.
function ns.CooldownBuffMembers(lead)
	local members = Groups()[lead]
	return type(members) == "table" and members or nil
end
-- Buffs made one group, in this order (a group among them brings its members);
-- the first is the lead. Gives the lead.
function ns.SetCooldownBuffGroup(ids)
	local groups, list, seen = Groups(), {}, {}
	local function Add(id)
		if type(id) == "number" and not seen[id] then
			seen[id] = true
			list[#list + 1] = id
		end
	end
	for _, id in ipairs(ids) do
		local members = groups[id]
		if type(members) == "table" then
			for _, member in ipairs(members) do Add(member) end
			groups[id] = nil
		else
			Add(id)
		end
	end
	if #list < 2 then return list[1] end
	groups[list[1]] = list
	groupsVersion = groupsVersion + 1
	return list[1]
end
-- A group split back into its buffs (each its own settings again).
function ns.UngroupCooldownBuff(lead)
	Groups()[lead] = nil
	groupsVersion = groupsVersion + 1
end
-- (A profile switch or a reset swaps the table: Map sees it's another one.)

local iconOf = setmetatable({}, { __mode = "v" }) -- base spell ID -> its icon in the bar (the pass's)
-- A buff's icon in the bar now (a pooled icon may have gone to another spell).
local function IconFor(id)
	local icon = iconOf[id]
	if not icon or icon.cooldownID == nil then return nil end
	local now = ns.CooldownIconSpellOf and ns.CooldownIconSpellOf(icon)
	if not now or Base(now) ~= id then return nil end
	return icon
end
-- Whether a member buff is on you: its icon's, else read by its name.
local function MemberOnYou(id)
	local icon = IconFor(id)
	if icon then return OnYou(icon) end
	local fighting = Fighting()
	if readDirty and not fighting then ns.CooldownReadBuffs() end
	local ok, name = pcall(GetName, id)
	name = ok and Plain(name)
	return type(name) == "string" and NamesOnYou({ name }, fighting) or false
end
-- Whether a buff icon set Missing (mode) shows now: its buff off you; in a
-- group on Missing: any one, none of the group on you and this the first
-- member's icon in the bar.
function ns.CooldownMissingShows(icon, mode)
	local id = ns.CooldownIconSpellOf and ns.CooldownIconSpellOf(icon)
	local base = id and Base(id)
	if base then iconOf[base] = icon end
	local lead = base and ns.CooldownBuffLead(base)
	local members = lead and ns.CooldownBuffMembers(lead)
	if not members or mode ~= "missing" then return not OnYou(icon) end
	local first
	for _, member in ipairs(members) do
		if member == base then
			if OnYou(icon) then return false end
		elseif MemberOnYou(member) then
			return false
		end
		if not first then
			local other = member == base and icon or IconFor(member)
			if other and other.cooldownID ~= nil then first = other end
		end
	end
	return first == icon
end
local MISSING = { missing = true, missingeach = true }
ns.COOLDOWN_MISSING_MODES = MISSING

do
	local events = CreateFrame("Frame")
	events:RegisterUnitEvent("UNIT_AURA", "player")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	events:RegisterEvent("PLAYER_ENTERING_WORLD")
	events:SetScript("OnEvent", function(_, event)
		readDirty = true
		if event == "PLAYER_ENTERING_WORLD" and ns.CooldownBuffAlternativesReset then ns.CooldownBuffAlternativesReset() end
	end)
end

local function Handled()
	return ns.db and ns.PageOn and ns.PageOn("handleCooldowns") or false
end

-- Whether an icon is Missing and its buff off you: it should show.
local function Wanted(icon)
	local group = groupOf[icon]
	if not group or icon.cooldownID == nil or not Handled() then return false end
	local id = ns.CooldownIconSpellOf and ns.CooldownIconSpellOf(icon)
	if not id then return false end
	local mode = ns.CooldownBuffMode(id, group)
	return MISSING[mode] and ns.CooldownMissingShows(icon, mode) or false
end

-- Whether Show/Hide may be called on it now: reachable (not forbidden, nor
-- refusing our code in a fight: Checks.lua), and not protected in a fight.
local function Touchable(icon)
	if ns.Reachable and not ns.Reachable(icon) then return false end
	if InCombatLockdown() and icon.IsProtected and Flag(icon:IsProtected()) then return false end
	return true
end

local function IsShownPlain(icon)
	local ok, shown = pcall(icon.IsShown, icon)
	if not ok or (issecretvalue and issecretvalue(shown)) then return nil end
	return shown and true or false
end

-- Shows a Missing icon the game hid.
local function Bring(icon)
	if not Wanted(icon) or IsShownPlain(icon) ~= false then return end
	if not Touchable(icon) then
		stats.refused = stats.refused + 1
		return
	end
	if pcall(icon.Show, icon) then
		shownHere[icon] = true
		stats.shown = stats.shown + 1
		if ns.readyPace then ns.readyPace.due = true end
	end
end

-- Hides one shown here that's no longer Missing, if the game would have it hidden.
local function PutBack(icon)
	shownHere[icon] = nil
	local settings = _G.CooldownViewerSettings
	if Active(icon) or not icon.hideWhenInactive or (settings and Flag(settings:IsVisible())) then return end
	if Touchable(icon) and pcall(icon.Hide, icon) then stats.putBack = stats.putBack + 1 end
end

local function Hook(icon)
	if hooked[icon] or type(icon.SetShown) ~= "function" then return end
	hooked[icon] = true
	-- (After the game's own SetShown: its UpdateShownState. Not Hide: the
	-- pool hides an icon it lets go, which must stay hidden.)
	hooksecurefunc(icon, "SetShown", Bring)
end

-- Whether any buff, bar or scene cell says Missing.
local function AnyIn(t, depth)
	if type(t) ~= "table" then return MISSING[t] or false end
	if depth > 3 then return false end
	for _, v in pairs(t) do
		if AnyIn(v, depth + 1) then return true end
	end
	return false
end
function ns.CooldownMissingAny()
	local db = ns.db
	if not db then return false end
	if AnyIn(db.cooldownBuffMode, 1) or AnyIn(db.cooldownBuffCells, 0) or AnyIn(db.cooldownGroupCells, 0) then
		return true
	end
	local defaults = db.cooldownGroupDefaults or {}
	for _, group in pairs(ns.COOLDOWN_BUFF_GROUPS or {}) do
		if defaults[group] and MISSING[defaults[group].mode] then return true end
	end
	return false
end

local function Visit(icon, _, bar)
	local group = ns.COOLDOWN_BUFF_GROUPS[bar]
	if not group then return end
	groupOf[icon] = group
	local id = ns.CooldownIconSpellOf and ns.CooldownIconSpellOf(icon)
	if id and icon.cooldownID ~= nil then iconOf[Base(id)] = icon end
	if Wanted(icon) then
		Hook(icon)
		Bring(icon)
	elseif shownHere[icon] and not Active(icon) then
		PutBack(icon)
	elseif shownHere[icon] then
		shownHere[icon] = nil -- (its buff's on: the game shows it now)
	end
end

-- Four times a second: Missing icons the game hid shown, others put back.
-- Nothing to do (no Missing anywhere, none shown here): no walk.
function ns.CooldownMissingPass()
	if not ns.EachCooldownIcon then return end
	local any = Handled() and ns.CooldownMissingAny()
	if not any and not next(shownHere) then return end
	if any then
		ns.EachCooldownIcon(Visit, true)
	else
		for icon in pairs(shownHere) do PutBack(icon) end
	end
end

-- (For the test: whether an icon is shown here.)
function ns.CooldownMissingShownHere(icon) return shownHere[icon] == true end

if C_Timer and C_Timer.NewTicker then
	C_Timer.NewTicker(0.25, function() ns.Guard(ns.CooldownMissingPass) end)
end
