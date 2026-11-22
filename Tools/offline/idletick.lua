-- The idle tick's pace after a wake (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/idletick.lua <forever|retail>
-- In CineMode, standing still, the update tick slows to 10 a second
-- (ns.Pace's quiet). Every wake but a few held it at the full 0.03 s pace for
-- the longest fade: in a city, chat lines and peeks kept it at 26 a second
-- (Tools/perf/ledger.md 2026-11-22). Now only wakes that start fades of their
-- own outside the frames' pass hold it (idleTick.HARD_WAKE); the pass's own
-- fades still keep the full pace (ns.framesSettled). Pretend time. PASS or FAIL.
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
InCombatLockdown = function() return false end
UnitAffectingCombat = function() return false end
UnitIsDeadOrGhost = function() return false end
IsModifierKeyDown = function() return false end
local tooltipShown = false
GameTooltip = GameTooltip or {}
GameTooltip.IsShown = function() return tooltipShown end
-- luacheck: pop

local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. text)
	if not ok then failed = failed + 1 end
end
local idle = ns.idleTick
Check(idle and idle.Note and ns.Pace, "idleTick and ns.Pace found")
if not (idle and idle.Note) then return print("1 FAILED") end

-- Standing still in CineMode, every frame settled.
ns.lastCinematic = true
ns.framesSettled, ns.framesFadeOnly, ns.framesWake = true, nil, nil
ns.playerMoving, ns.stopWhileGliding = nil, nil
ns.previewRows, ns.layoutFadeUntil, ns.fadeDemo, ns.effectsDemo, ns.plateDemo = nil, nil, nil, nil, nil
ns.OnTaxi = function() return false end
ns.IsChatActive = function() return false end
ns.ChatCamImmersive = function() return false end
ns.CursorPosition = function() return 100, 100 end
ns.AnyUnitPartHidden = function() return false end
local settle = idle.Settle()
local function Step(dt)
	now = now + (dt or 0.05)
	return ns.Pace()
end
local function Wake(event)
	now = now + 0.01
	idle.Note(now, true, false, event)
end

Wake(nil) -- (CineMode came on: the full pace for the fades)
Check(not Step().quiet, "CineMode just came on: full pace")
Step(settle + 0.1)
Check(Step().quiet, ("after %.1f s settled: quiet (slow tick)"):format(settle))

for _, event in ipairs({ "chat message", "debuff peek", "quest reveal", "UPDATE_MOUSEOVER_UNIT", "UNIT_AURA",
	"MINIMAP_PING", "frame links" }) do
	Wake(event)
	Check(Step().quiet, "a wake by " .. event .. " doesn't hold the full pace")
end

for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "ZONE_CHANGED_NEW_AREA", "GROUP_ROSTER_UPDATE", "group changed",
	"PLAYER_MOUNT_DISPLAY_CHANGED" }) do
	Wake(event)
	local busy = not Step().quiet
	Step(settle - 0.3)
	local stillBusy = not Step().quiet
	Step(0.5)
	local quietAfter = Step().quiet
	Check(busy and stillBusy and quietAfter, ("%s: full pace for its fades (%.1f s), then quiet"):format(event, settle))
end

-- The frames' pass's own fades still keep the full pace.
Wake("chat message")
ns.framesSettled = false
Check(not Step().quiet, "a frame fading in for the chat peek: full pace while it fades")
ns.framesSettled = true
Check(Step().quiet, "the fade done: quiet")

-- A fight's start or end: full pace.
now = now + 0.01
idle.Note(now, true, true, nil)
now = now + 0.01
idle.Note(now, true, false, nil)
Check(not Step().quiet, "a fight's end: full pace")
Step(settle + 0.1)
Check(Step().quiet, "settled again")

-- A shown tooltip: the full pace only while the Tooltips page handles them
-- (its checks run on the tick). Off, the default: quiet (it held the full
-- pace on 56% of frames in a city, 2026-11-22).
Check(ns.TooltipsHandled ~= nil, "ns.TooltipsHandled found")
tooltipShown = true
ns.db.handleTooltips = false
Check(Step().quiet, "a tooltip shown, Tooltips page off: quiet")
ns.db.enabled, ns.db.handleTooltips = true, true
-- (and every switch it's under on, as a player using the page has them)
local master, steps = ns.PageSwitchOf and ns.PageSwitchOf("handleTooltips"), 0
while master and steps < 10 do
	ns.db[master] = true
	master, steps = ns.PageSwitchOf(master), steps + 1
end
local handled = ns.TooltipsHandled and ns.TooltipsHandled()
Check(handled and not Step().quiet, "a tooltip shown, Tooltips page on: full pace for its checks")
tooltipShown = false
Check(Step().quiet, "the tooltip gone, Tooltips page on: quiet")
ns.db.handleTooltips = false

print(failed == 0 and "ALL PASSED" or (failed .. " FAILED"))
