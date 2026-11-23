-- The welcome shelf's groups (Profiles/Welcome.lua SHELF_GROUPS, by their
-- hub) in the settings' left-list order (Options.lua menu.order): the user,
-- 2026-11-22, "the order should reflect what we have in settings".
-- Run: python -I Tools/offline/run.py Tools/offline/shelforder.lua
local function Read(path)
	local f = assert(io.open(path, "rb"))
	local text = f:read("*a")
	f:close()
	return text
end
local order = {}
local list = Read("Options.lua"):match("local menu = { order = (%b{})")
assert(list, "menu.order not found in Options.lua")
for name in list:gmatch('"([^"]+)"') do order[#order + 1] = name end
local place = {}
for i, name in ipairs(order) do place[name] = i end
local groups = Read("Profiles/Welcome.lua"):match("local SHELF_GROUPS = (%b{})")
assert(groups, "SHELF_GROUPS not found in Profiles/Welcome.lua")
local hubs = {}
for hub in groups:gmatch('hub = "([^"]+)"') do hubs[#hubs + 1] = hub end
local fails, last = 0, 0
for _, hub in ipairs(hubs) do
	local at = place[hub]
	if not at then
		fails = fails + 1
		print("FAIL shelf group " .. hub .. ": not in menu.order")
	elseif at < last then
		fails = fails + 1
		print(("FAIL shelf group %s before the one above it in settings (%d < %d)"):format(hub, at, last))
	else
		last = at
	end
end
local _, count = groups:gsub("key = ", "")
if count ~= #hubs then
	fails = fails + 1
	print(("FAIL %d shelf groups, %d with a hub"):format(count, #hubs))
end
print(("shelf order: %s"):format(table.concat(hubs, ", ")))
print(fails == 0 and "ALL PASS" or (fails .. " FAIL"))
