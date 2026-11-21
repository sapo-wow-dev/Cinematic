-- Interface Recolor with Glass (dev tool, offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/glasshook.lua < /dev/null
-- Glass (the chat addon) embeds AceHook-3.0 in the chat frames, so a chat
-- tab's own HookScript is AceHook's: HookScript(object, method, handler).
-- Interface Recolor watched each tab's OnShow with frame:HookScript, which
-- went to AceHook's and errored at every login ("Usage: HookScript(object,
-- ...)", PR 4, 2026-11-21). The game's own HookScript is used now. Says PASS
-- or FAIL per check.
-- (Optional first argument: another .toc to load, to run it on older code.)
local aceCalls, aceErrors = 0, 0
local ns, wow = dofile("Tools/offline/load.lua")("forever", arg and arg[1], function(stub)
	-- (A chat tab with Glass's AceHook on it, before the addon loads.)
	local tab = stub.NewObject("Button", "ChatFrame1Tab", UIParent)
	-- (As in the game: the widget's methods a table on its metatable's
	-- __index; the stand-in's is a function, so one is put in front of it.)
	local meta, copy = getmetatable(tab), {}
	for key, value in pairs(meta) do copy[key] = value end
	local methods = setmetatable({ HookScript = tab.HookScript }, { __index = function(_, key)
		return type(meta.__index) == "function" and meta.__index(tab, key) or nil
	end })
	copy.__index = methods
	setmetatable(tab, copy)
	tab.HookScript = function(_, object)
		aceCalls = aceCalls + 1
		if type(object) ~= "table" then
			aceErrors = aceErrors + 1
			error("Usage: HookScript(object, method, [handler]): 'object' - nil or table expected got "
				.. type(object))
		end
	end
	rawset(_G, "ChatFrame1Tab", tab)
end)

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local warned = {}
local warn = wow.Warn
wow.Warn = function(text)
	warned[#warned + 1] = text
	return warn(text)
end
rawset(C_Timer, "After", function(_, fn) fn() end) -- (the recolor pass at once)
local tab = _G.ChatFrame1Tab
local ok, err = pcall(ns.RefreshInterfaceRecolor)
Check("recolor pass with Glass's HookScript on a chat tab: no error", ok and aceErrors == 0,
	ok and ("%d AceHook errors"):format(aceErrors) or err)
Check("Glass's own HookScript left alone", aceCalls == 0, ("called %d times"):format(aceCalls))
Check("the tab's OnShow is watched (the game's HookScript)", type(tab._scripts.OnShow) == "function")
ok, err = pcall(ns.RefreshInterfaceRecolor)
Check("a second pass: no error, still not Glass's", ok and aceCalls == 0, ok and aceCalls or err)
if type(tab._scripts.OnShow) == "function" then
	ok, err = pcall(tab._scripts.OnShow, tab)
	Check("the tab showing: dressed again without an error", ok, err)
end

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
