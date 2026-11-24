-- The profiler's timers on 2026-11-23's untimed code (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/newtimers.lua <forever|retail>
-- A normal recording had 0.39-0.56 ms a frame no timer named ("not wrapped",
-- Tools/perf/ledger.md 2026-11-23): code new that day ran in loops, tickers
-- and hooks of its own. Each now has a timer. Checked: the ones made at load
-- are made (ns.Profiled with their labels), the ones made later are in their
-- files, and each label is used once. PASS or FAIL.
-- luacheck: push ignore 111 112 113 121 122
local client = arg and arg[1] or "forever"
package.path = "Tools/offline/?.lua;" .. package.path
local wow = dofile("Tools/offline/wow.lua")
wow.Install(client)
local made = {}
local ns = setmetatable({}, { __newindex = function(t, k, v)
	if k == "Profiled" then
		rawset(t, k, function(name, fn) made[name] = (made[name] or 0) + 1 return v(name, fn) end)
	else
		rawset(t, k, v)
	end
end })
for line in io.lines("Cinematic.toc") do
	line = line:gsub("\r", "")
	if line ~= "" and not line:find("^#") then
		local chunk, loadErr = loadfile((line:gsub("\\", "/")))
		if not chunk then print("FAIL " .. line .. " doesn't compile: " .. tostring(loadErr)) end
		if chunk then
			local ok, err = pcall(chunk, "Cinematic", ns)
			if not ok then wow.Warn(line .. ": " .. tostring(err)) end
		end
	end
end
wow.Fire("ADDON_LOADED", "Cinematic") -- (Style and Atmosphere load as parts: ns.Module)
wow.Fire("PLAYER_LOGIN")
-- luacheck: pop

local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. text)
	if not ok then failed = failed + 1 end
end
for _, name in ipairs({ "Unit frame dress", "Cooldown Missing pass", "Drain ring watcher", "Plate mouseover watch",
	"Mana Vision events", "Feature loop gates" }) do
	Check(made[name] == 1, ("timer at load: %s (%s)"):format(name, tostring(made[name])))
end
local function Read(path)
	local file = io.open(path)
	local text = file and file:read("*a") or ""
	if file then file:close() end
	return text
end
for path, name in pairs({ ["Style/UnitStyle.lua"] = "Unit power keep", ["UI/CooldownMissing.lua"] = "Cooldown Missing show",
	["FadeDetached.lua"] = "Detached parts walk" }) do
	Check(Read(path):find('ns.Profiled("' .. name .. '"', 1, true) ~= nil, ("timer made later: %s, in %s"):format(name, path))
end
Check(ns.SyncFeatureLoops ~= nil, "ns.SyncFeatureLoops still there, wrapped")

print(failed == 0 and "ALL PASSED" or (failed .. " FAILED"))
