-- Tooltip Faction and PvP rows (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/tooltipfaction.lua < /dev/null
-- A player asked (Discord, 2026-11-20) to show the faction line only on the
-- other faction. The Faction and PvP row split in two: Faction (yours, and
-- neutral units) and FactionEnemy (the other faction's). Checks which lines the
-- Tooltips page takes out of an Alliance and a Horde player's tooltip (you are
-- Alliance here), each row on and off, and the update that starts FactionEnemy
-- as Faction was set. Says PASS or FAIL per check.

-- luacheck: push ignore 111 112 113 121 122 212
local ns = dofile("Tools/offline/load.lua")("forever", arg and arg[1], function()
	LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Warrior", DRUID = "Druid" }
	LOCALIZED_CLASS_NAMES_FEMALE = { WARRIOR = "Warrior", DRUID = "Druid" }
	FACTION_ALLIANCE, FACTION_HORDE = "Alliance", "Horde"
	UnitFactionGroup = function() return "Alliance", "Alliance" end
end)
-- luacheck: pop

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local lines = {}
for i = 1, 6 do
	lines[i] = UIParent:CreateFontString("GameTooltipTextLeft" .. i)
	_G["GameTooltipTextLeft" .. i] = lines[i]
end
local tooltip = CreateFrame("GameTooltip", "CineTestTooltip", UIParent)
local function CutOf(texts)
	for i = 1, 6 do
		lines[i]:SetText(texts[i])
		lines[i]:Show()
	end
	local cut = ns.TooltipLinesToCut(tooltip, #texts, "target")
	local out = {}
	for i = 2, #texts do
		if cut[i] then out[#out + 1] = texts[i] end
	end
	return table.concat(out, ",")
end

local db = ns.db
db.enabled, db.handleTooltips, db.tooltipFullAfter = true, true, 2
local master = ns.PageSwitchOf("handleTooltips")
while master do
	db[master] = true
	master = ns.PageSwitchOf(master)
end
for _, part in ipairs(ns.TOOLTIP_PARTS) do
	db["tooltipShow" .. part .. "First"] = true
end
local ALLY = { "Guinevere", "Druid", "Alliance", "PvP" }
local HORDE = { "Grommash", "Warrior", "Horde", "PvP" }
local NEUTRAL = { "Some Merchant", "<Trade Goods>" }

Check("FactionEnemy is a part of the grid", (function()
	for _, part in ipairs(ns.TOOLTIP_PARTS) do
		if part == "FactionEnemy" then return true end
	end
end)())

db.tooltipShowFactionFirst, db.tooltipShowFactionEnemyFirst = false, true
Check("yours off: your faction's lines go", CutOf(ALLY) == "Alliance,PvP", CutOf(ALLY))
Check("yours off: the other faction's stay", CutOf(HORDE) == "", CutOf(HORDE))
Check("yours off: a neutral NPC's tooltip untouched", CutOf(NEUTRAL) == "", CutOf(NEUTRAL))

db.tooltipShowFactionFirst, db.tooltipShowFactionEnemyFirst = true, false
Check("enemies off: your faction's stay", CutOf(ALLY) == "", CutOf(ALLY))
Check("enemies off: the other faction's go", CutOf(HORDE) == "Horde,PvP", CutOf(HORDE))

db.tooltipShowFactionFirst, db.tooltipShowFactionEnemyFirst = false, false
Check("both off: Alliance goes", CutOf(ALLY) == "Alliance,PvP", CutOf(ALLY))
Check("both off: Horde goes", CutOf(HORDE) == "Horde,PvP", CutOf(HORDE))

-- Your faction unreadable (as it may be in a fight): the one read before is
-- kept, so the Horde line stays on the enemies' row and isn't hidden.
CutOf(ALLY) -- (a tooltip while it's readable: Alliance kept)
local readable = UnitFactionGroup
_G.UnitFactionGroup = function() error("secret") end
db.tooltipShowFactionFirst, db.tooltipShowFactionEnemyFirst = false, true
Check("faction unreadable: the other faction's stay", CutOf(HORDE) == "", CutOf(HORDE))
Check("faction unreadable: yours still go", CutOf(ALLY) == "Alliance,PvP", CutOf(ALLY))
_G.UnitFactionGroup = readable
db.tooltipShowFactionFirst, db.tooltipShowFactionEnemyFirst = true, true

-- The update: FactionEnemy starts as Faction was set (saved settings and profiles).
db.tooltipFactionEnemyV1 = nil
db.tooltipShowFactionFirst, db.tooltipShowFactionLater = false, false
db.tooltipShowFactionEnemyFirst, db.tooltipShowFactionEnemyLater = nil, nil
db.profiles = db.profiles or {}
db.profiles.CineTest = { settings = { tooltipShowFactionLater = false } }
ns.RunMigrations()
Check("update copies Faction's First", db.tooltipShowFactionEnemyFirst == false, tostring(db.tooltipShowFactionEnemyFirst))
Check("update copies Faction's Later", db.tooltipShowFactionEnemyLater == false, tostring(db.tooltipShowFactionEnemyLater))
Check("update reaches profiles", db.profiles.CineTest.settings.tooltipShowFactionEnemyLater == false)
Check("update runs once", db.tooltipFactionEnemyV1 == true)
db.profiles.CineTest = nil

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
