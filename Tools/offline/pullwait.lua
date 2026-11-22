-- Wait at pull (Health & Resources, fightWaitPull) and the player frame
-- (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/pullwait.lua <forever|retail>
-- A mob pulls you and nothing has hit you yet: health and power at rest.
-- The PRD's bars wait (Wait at pull, on to start with); the player frame
-- doesn't: it's in the fight's shown list at once, as before 2.1.0 (a
-- player's report, 2026-11-22: it came up only once they were hit).
-- PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122
local client = arg and arg[1] or "forever"
package.path = "Tools/offline/?.lua;" .. package.path
local wow = dofile("Tools/offline/wow.lua")
wow.Install(client)
local now = 1000
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
GetTime = function() return now end
local fighting = false
InCombatLockdown = function() return fighting end
UnitAffectingCombat = function() return fighting end
-- luacheck: pop

local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. text)
	if not ok then failed = failed + 1 end
end

-- (The HUD handled and Health & Resources on, as the player has it; a fresh
-- profile here starts with the page off, and then nothing waits.)
ns.db.handleFrames, ns.db.personalResources, ns.db.prdKeepUp = true, true, true
Check(ns.db.fightWaitPull == true, "Wait at pull on to start with")
Check(ns.PersonalResourcesOn(nil, "player") and ns.PersonalResourcesOn(nil, "prd"), "Health & Resources rows on")
-- (At rest well before the pull: nothing changed for a minute.)
now = now + 60
wow.Fire("PLAYER_REGEN_DISABLED")
fighting = true
Check(ns.FightHold("prd") == true, "PRD health bar waits at the pull")
Check(not ns.FightHold("player"), "player frame doesn't wait at the pull")

-- The fight's shown list: the player frame's row is in it at once.
if ns.ForgetCombatShown then ns.ForgetCombatShown() end
local shown = ns.CombatShownFrames and ns.CombatShownFrames()
Check(shown ~= nil, "fight's shown list worked out")
if shown then
	Check(ns.IsCombatShowOn("player") ~= true or shown.PlayerFrame == true,
		"PlayerFrame shown at the pull (row ticked In combat: " .. tostring(ns.IsCombatShowOn("player")) .. ")")
end

-- Hit: the PRD's wait ends too.
wow.Fire("UNIT_HEALTH", "player")
Check(not ns.FightHold("prd"), "PRD health bar up once your health changes")

print(failed == 0 and "ALL PASS" or (failed .. " FAILED"))
