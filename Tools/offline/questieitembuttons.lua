-- Questie's quest item buttons fade with the Quest tracker row (dev tool,
-- offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/questieitembuttons.lua < /dev/null
-- Questie makes one item button per quest you can take
-- (C_QuestLog.GetMaxNumQuestsCanAccept: 40 on Forever). We faded a fixed 35,
-- so buttons 36-40 stayed up (2026-11-21). Says PASS or FAIL per check.
-- (Optional first argument: another .toc to load, to run it on older code.)
local ns, wow = dofile("Tools/offline/load.lua")("forever", arg and arg[1])

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local faded = {}
local fadeWithRow = ns.FadeWithRow
ns.FadeWithRow = function(key, group, names, ...)
	if key == "quests" then
		for _, name in ipairs(names) do faded[name] = true end
	end
	return fadeWithRow(key, group, names, ...)
end
rawset(C_QuestLog, "GetMaxNumQuestsCanAccept", function() return 40 end)
rawset(C_Timer, "NewTicker", function() return { Cancel = function() end } end)
local loaded = C_AddOns and C_AddOns.IsAddOnLoaded
if C_AddOns then
	rawset(C_AddOns, "IsAddOnLoaded", function(name) return name == "Questie" or (loaded and loaded(name)) end)
end
wow.Fire("ADDON_LOADED", "Questie")

Check("its tracker fades with the Quest tracker row", faded.Questie_BaseFrame)
Check("item button 1 fades", faded.Questie_ItemButton1)
Check("item button 35 fades", faded.Questie_ItemButton35)
Check("item button 40 fades (the game's 40th quest)", faded.Questie_ItemButton40)
Check("no button past the game's count", not faded.Questie_ItemButton41)

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
