-- No settings page counts as open after login (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/settingsclosed.lua <forever|retail>
-- ns.OurSettingsShown (our pages on screen) turns the idle checks' slowing
-- off (ns.SlowChecks: "settings open"). The Favorites page was left shown
-- with no parent, so from login every session counted as settings open until
-- the window was opened and closed once: the frames pass and its lists ran at
-- full pace standing still (Tools/perf/ledger.md, 2026-11-22). Every page,
-- made at login or later: none listed as shown, and the slow checks on.
-- PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122
local client = arg and arg[1] or "forever"
package.path = "Tools/offline/?.lua;" .. package.path
local wow = dofile("Tools/offline/wow.lua")
wow.Install(client)
local ns = {}
for line in io.lines("Cinematic.toc") do
	line = line:gsub("\r", "")
	if line ~= "" and not line:find("^#") then
		local chunk = loadfile((line:gsub("\\", "/")))
		if chunk then
			local ok, err = pcall(chunk, "Cinematic", ns)
			if not ok then wow.Warn(line .. ": " .. tostring(err)) end
		end
	end
end
wow.Fire("ADDON_LOADED", "Cinematic")
wow.Fire("PLAYER_LOGIN")
InCombatLockdown = function() return false end
UnitAffectingCombat = function() return false end
-- luacheck: pop

local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. text)
	if not ok then failed = failed + 1 end
end
local function Listed()
	local names = {}
	for canvas in pairs(ns.shownSettingsCanvases or {}) do
		for name, each in pairs(ns.settingsCanvases or {}) do
			if each == canvas then names[#names + 1] = name end
		end
		if #names == 0 then names[1] = "(a page not in ns.settingsCanvases)" end
	end
	return names
end

Check(ns.OurSettingsShown ~= nil and ns.SlowChecks ~= nil, "OurSettingsShown and SlowChecks found")
local names = Listed()
Check(#names == 0, "after login no page counts as shown" .. (#names > 0 and (": " .. table.concat(names, ", ")) or ""))
Check(not ns.OurSettingsShown(), "after login: settings not open")

-- The pages made when first needed, too.
Check(ns.MakeLazyPages ~= nil, "ns.MakeLazyPages found")
if ns.MakeLazyPages then ns.MakeLazyPages("test") end
names = Listed()
Check(#names == 0, "with the later pages made: none shown" .. (#names > 0 and (": " .. table.concat(names, ", ")) or ""))
ns.db.calmTime = 0
ns.InCalm = function() return false end
ns.FightLingering = function() return false end
Check(ns.SlowChecks(), "standing still out of a fight: the idle checks slow down")

print(failed == 0 and "ALL PASSED" or (failed .. " FAILED"))
