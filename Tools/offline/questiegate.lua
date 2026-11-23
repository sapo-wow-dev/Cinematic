-- Addon support gated as it should be (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/questiegate.lua < /dev/null
-- Audit 2026-11-22:
-- 1. The tooltip cut pass and the No wait for list asked Questie's support
--    (ns.QuestieTooltipLines, ns.QuestieObjectiveMob) on every tooltip with
--    Questie not in, as the quest item button asked ns.QuestieItemButton.
-- 2. Questie's support switched off on the Addons page still reached into
--    it (plate marks, tooltip lines, item button): only its setup stopped.
--    ns.AddonUp now says no for an addon whose support is off.
-- 3. DaylightUI's layout keeper replaced one set before it (Leatrix Plus's)
--    instead of asking it, so their layouts took turns at every login.
-- 4. A chat bubble's state made text-anchored, or hidden off the screen, had
--    no SetPoint hook: its saved spot went stale.
-- PASS or FAIL per check.

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local loaded = {}
local hooks = {} -- object -> { method = count }
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	C_AddOns = { IsAddOnLoaded = function(name) return loaded[name] == true end }
	IsAddOnLoaded = C_AddOns.IsAddOnLoaded
	hooksecurefunc = function(a, b, c)
		local tbl, name, fn = a, b, c
		if type(a) == "string" then tbl, name, fn = _G, a, b end
		hooks[tbl] = hooks[tbl] or {}
		hooks[tbl][name] = (hooks[tbl][name] or 0) + 1
		local orig = tbl[name]
		rawset(tbl, name, function(...)
			local r = { orig(...) }
			fn(...)
			return unpack(r)
		end)
	end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", Install)
local db = ns.db

-- A local of a file, found through the upvalues of ns's functions.
local function Local(name)
	local seen = {}
	local function Walk(fn, depth)
		if type(fn) ~= "function" or seen[fn] or depth > 4 then return end
		seen[fn] = true
		for i = 1, 60 do
			local upName, value = debug.getupvalue(fn, i)
			if not upName then break end
			if upName == name and type(value) == "function" then return value end
			local found = Walk(value, depth + 1)
			if found then return found end
		end
	end
	for _, value in pairs(ns) do
		local found = Walk(value, 0)
		if found then return found end
	end
end

-- 1: Questie not in: none of its support asked.
local asked = 0
for _, name in ipairs({ "QuestieTooltipLines", "QuestieObjectiveMob", "QuestieItemButton", "QuestieMarks" }) do
	local real = ns[name]
	ns[name] = function(...) asked = asked + 1 return real(...) end
end
local tooltip = wow.CreateFrame("GameTooltip")
rawset(tooltip, "GetUnit", function() return "Young Wolf", "mouseover" end)
local LinesToCut, SkipsWait = Local("LinesToCut"), Local("SkipsWait")
Check("1 the tooltip passes found", LinesToCut ~= nil and SkipsWait ~= nil)
db.enabled, db.handleTooltips, db.tooltipNoWaitQuest, db.tooltipFullAfter = true, true, true, 2
ns.IsQuestMob = function() return false end
if LinesToCut then pcall(LinesToCut, tooltip, 1, "mouseover", false) end
if SkipsWait then pcall(SkipsWait, tooltip) end
-- (The target's quest icon too: QuestMobs.lua asked Questie's marks ungated.)
do
	local wasMob, wasExists = ns.IsQuestMob, UnitExists
	ns.IsQuestMob = function() return true end
	UnitExists = function() return true end -- luacheck: ignore 121
	db.questVision, db.targetQuestIcon = true, true
	if ns.RefreshTargetQuestIcon then pcall(ns.RefreshTargetQuestIcon) end
	ns.IsQuestMob, UnitExists = wasMob, wasExists -- luacheck: ignore 121
end
Check("1 tooltips: Questie's support not asked with it not in", asked == 0, asked)
asked = 0
loaded.Questie = true
wow.Fire("ADDON_LOADED", "Questie") -- (the no forgotten as an addon loads)
if LinesToCut then pcall(LinesToCut, tooltip, 1, "mouseover", false) end
if SkipsWait then pcall(SkipsWait, tooltip) end
Check("1 and asked with it in", asked >= 2, asked)

-- 2: its support switched off on the Addons page: as if not in.
Check("2 Questie in: up", ns.AddonUp("Questie") == true)
db.addonSupportOff = { Questie = true }
-- (Before the reload its box asks for: still up, so our put-back code runs.)
Check("2 unticked, no reload yet: still up", ns.AddonUp("Questie") == true)
ns.ForgetAddonSupportAtLoad() -- (the reload)
Check("2 its support off: not up", ns.AddonUp("Questie") == false)
asked = 0
if LinesToCut then pcall(LinesToCut, tooltip, 1, "mouseover", false) end
Check("2 its support off: not asked", asked == 0, asked)
db.addonSupportOff = {}
ns.ForgetAddonSupportAtLoad()
Check("2 back on: up", ns.AddonUp("Questie") == true)

-- 3: DaylightUI's keeper asks one set before it (no DaylightUI layout here).
rawset(_G, "DaylightUI", {}) -- (its Edit Mode part not made: no layout of its own)
ns.layoutKeeper = function() return "Leatrix Plus" end
loaded.DaylightUI = true
wow.Fire("ADDON_LOADED", "DaylightUI")
Check("3 DaylightUI's keeper set", ns.layoutKeeper ~= nil)
Check("3 the keeper before it still asked", ns.layoutKeeper and ns.layoutKeeper() == "Leatrix Plus",
	tostring(ns.layoutKeeper and ns.layoutKeeper()))

-- 4: a bubble first seen text-anchored gets its SetPoint hook.
local StateOf = Local("StateOf")
Check("4 the bubble state maker found", StateOf ~= nil)
if StateOf then
	local inside = wow.CreateFrame("Frame")
	StateOf(inside)
	Check("4 its SetPoint hooked once made", hooks[inside] and hooks[inside].SetPoint == 1)
	StateOf(inside)
	Check("4 and only once", hooks[inside] and hooks[inside].SetPoint == 1)
end
local Lift = Local("Lift")
if Lift then
	local inside = wow.CreateFrame("Frame")
	local text = wow.CreateFrame("Frame")
	inside.String = text
	rawset(inside, "GetPoint", function() return "TOP", text, "TOP", 0, 0 end)
	pcall(Lift, inside)
	Check("4 one text-anchored: hooked too", hooks[inside] and hooks[inside].SetPoint == 1)
end

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
