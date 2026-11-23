-- A chat window's background left partway as its window went away
-- (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/chatbgsettle.lua < /dev/null
-- Audit 2026-11-22: a chat window's background only moves while the window's
-- wanted up; going to 0 it's held where it is. But a background partway (0.4,
-- say: a short fight's end, a peek ending right after a hover) still counted
-- as fading, so the frame pass never settled (ns.framesSettled false): the
-- whole pass every tick till the window came up again. In CineMode with the
-- window faded out: the pass settles; brought up again, the background moves
-- on from where it was. PASS or FAIL per check.

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local now = 100
local ns = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", function()
	-- luacheck: push ignore 111 112 113 121 122
	GetTime = function() return now end
	InCombatLockdown = function() return false end
	UnitAffectingCombat = function() return false end
	MouseIsOver = function() return false end
	UnitIsDeadOrGhost = function() return false end
	UnitIsDead = function() return false end
	UnitIsGhost = function() return false end
	GetMouseFoci = function() return {} end
	-- (The tracking list read in the pass: none, not the stub's.)
	C_Minimap = setmetatable({ GetNumTrackingTypes = function() return 0 end },
		{ __index = function() return function() end end })
	-- luacheck: pop
end)
local chat = CreateFrame("Frame", "ChatFrame1", UIParent)
chat._alpha = 1
rawset(chat, "SetAlpha", function(self, alpha) self._alpha = alpha end)
rawset(chat, "GetAlpha", function(self) return self._alpha end)
rawset(chat, "IsMouseOver", function() return false end)
ns.db.handleFrames = true
ns.db.mouseover = false -- (no mouse on the stand-in: hovering out of it)
ns.MarkChatHolders = function() end
ns.IsChatActive = function() return false end -- (not typing: the stand-in says yes)
ns.EditModeActive = function() return false end -- (nor laying out the UI)
local ok, err = pcall(ns.BuildManagedList)
if not ok then print("note: the frame scan errored on the stand-in: " .. tostring(err)) end
local entry
for _, each in ipairs(ns.managed) do
	if each.frame == chat then entry = each end
end
Check("the chat window is faded", entry ~= nil)
if not entry then
	print("1 FAILED")
	os.exit(1)
end

local function Pass(cinematic, times)
	for _ = 1, times do
		now = now + 0.05
		local passOk, passErr = pcall(ns.UpdateFrames, cinematic, 0.05)
		if not passOk then print("pass: " .. tostring(passErr)) return end
	end
end
-- In CineMode, the window gone: its background left at 0.4.
Pass(true, 60)
Check("the window faded out in CineMode", entry.alpha == 0, ("alpha %s, row %s"):format(tostring(entry.alpha), tostring(entry.row)))
entry.backgroundAlpha = 0.4
Pass(true, 3)
Check("the pass settles with the background left partway", ns.framesSettled == true, tostring(ns.framesSettled))
Check("the background held where it was", entry.backgroundAlpha == 0.4, entry.backgroundAlpha)

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
