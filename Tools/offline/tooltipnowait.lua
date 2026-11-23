-- The Tooltips page's No wait for list (Quest objective mobs) with the
-- tooltip's unit secret (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/tooltipnowait.lua < /dev/null
-- In a fight on WoW Forever a mob's tooltip gives its unit secret: the list
-- gave up and a quest mob's tooltip waited like any other (2026-11-23). Now
-- it goes by the unit frame's unit, else the mouseover token and the target
-- or plate that is the same unit. Old code: cases 3-5 and 7 said no.
-- PASS or FAIL per check.

local SECRET = setmetatable({}, { __tostring = function() return "SECRET" end })
-- luacheck: push ignore 111 112 113 121 122
local ns = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", function()
	issecretvalue = function(value) return value == SECRET end
end)
-- luacheck: pop
local db = ns.db

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

-- The world as each case has it.
local world
local quest = {} -- [token] = true: a quest mob
-- luacheck: push ignore 111 112 113 121 122
UnitExists = function(unit) return world.exists[unit] == true end
UnitIsUnit = function(a, b)
	if world.sameSecret then return SECRET end
	return a == b or (world.same[a] == b) or (world.same[b] == a)
end
C_NamePlate = C_NamePlate or {}
C_NamePlate.GetNamePlates = function()
	local list = {}
	for _, token in ipairs(world.plates or {}) do
		-- (Some plates carry their token only on UnitFrame.unit.)
		list[#list + 1] = world.frameTokens and { UnitFrame = { unit = token } } or { namePlateUnitToken = token }
	end
	return list
end
InCombatLockdown = function() return true end
-- luacheck: pop
ns.IsQuestMob = function(unit) return quest[unit] == true end
ns.AddonUp = function() return false end

local tooltip = {
	GetUnit = function() return "Burly Rockjaw Trogg", world.unit end,
	GetOwner = function() return world.owner end,
	GetTooltipData = function() return { type = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit } end,
}

local function Case(name, setup, want, route)
	world = { exists = { mouseover = true }, same = {}, plates = {}, unit = SECRET, owner = UIParent }
	for k in pairs(quest) do quest[k] = nil end
	db.enabled, db.handleTooltips, db.tooltipNoWaitQuest, db.tooltipFullAfter = true, true, true, 2
	setup()
	local ok, yes = pcall(ns.TooltipSkipsWait, tooltip)
	local last = ns.tooltipNoWaitLast or {}
	Check(name, ok and yes == want and (route == nil or last.route == route),
		("got %s by %s, tried %s"):format(tostring(yes), tostring(last.route), tostring(last.tried)))
end

Check("0 the No wait check found", ns.TooltipSkipsWait ~= nil)
Case("1 readable unit, a quest mob: skips by the tooltip's unit", function()
	world.unit = "mouseover"
	quest.mouseover = true
end, true, "tooltip")
Case("2 readable unit, not a quest mob: waits (the target isn't asked)", function()
	world.unit = "mouseover"
	world.same.mouseover = "target"
	quest.target = true
end, false)
Case("3 secret unit, the mouseover a quest mob: skips (old: waited)", function()
	quest.mouseover = true
end, true, "mouseover")
Case("4 secret unit, mouseover unknown, it's the target, a quest mob: skips by the target (old: waited)", function()
	world.same.mouseover = "target"
	quest.target = true
end, true, "target")
Case("5 secret unit, it's a plate the quest check knows: skips by the plate (old: waited)", function()
	world.plates = { "nameplate1", "nameplate2" }
	world.same.mouseover = "nameplate2"
	quest.nameplate2 = true
end, true, "plate")
Case("5b the same, the plate's token only on its UnitFrame.unit", function()
	world.plates, world.frameTokens = { "nameplate3" }, true
	world.same.mouseover = "nameplate3"
	quest.nameplate3 = true
end, true, "plate")
Case("6 secret unit, nothing under the mouse: waits", function()
	world.exists.mouseover = false
	quest.mouseover = true
end, false)
Case("7 secret unit on a unit frame: its unit (old: waited)", function()
	world.owner = { unit = "target" }
	quest.target = true
end, true, "frame")
Case("8 secret UnitIsUnit: target and plates not taken as the mouseover", function()
	world.sameSecret = true
	world.plates = { "nameplate1" }
	quest.target, quest.nameplate1 = true, true
end, false)
Case("9 the row unticked: waits", function()
	db.tooltipNoWaitQuest = false
	quest.mouseover = true
end, false)
Case("10 After column at 0 (no wait anyway): no", function()
	db.tooltipFullAfter = 0
	quest.mouseover = true
end, false)

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
