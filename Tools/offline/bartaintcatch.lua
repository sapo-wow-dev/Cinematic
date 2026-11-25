-- The dev copy's catch for action bar calls blocked as ours
-- (Dev/BarTaintCatch.lua), offline (Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/bartaintcatch.lua
-- With the 18:48 error's own blocked calls (MultiBarBottomLeft:SetFrameStrata
-- from the spellbook's OnShow, then 300 more in the same burst): the first bar
-- call logs one scan under "bartaint" (in a fight, every field an addon wrote
-- with who, ours counted, named slots set to nil too), the rest of the burst
-- and later bursts log nothing; a blocked call that isn't the bars' (a
-- nameplate's) doesn't take the one catch. PASS or FAIL lines.
-- luacheck: push ignore 111 112 113 121 122 143
package.path = "Tools/offline/?.lua;" .. package.path
local wow = dofile("Tools/offline/wow.lua")
wow.Install("forever")

-- Taint, as issecurevariable reads it: { [table] = { key = "AddonName" } }.
local tainted = {}
local function Taint(t, key, who) tainted[t] = tainted[t] or {}; tainted[t][key] = who end
issecurevariable = function(t, key)
	if type(t) == "string" then return true end -- (globals: all the game's here)
	local who = tainted[t] and tainted[t][key]
	if who then return false, who end
	return true
end
issecretvalue = function() return false end
local fight = false
InCombatLockdown = function() return fight end
UnitAffectingCombat = function() return fight end

-- The game's pieces the scan walks: a bar with two buttons, the window
-- manager, the spellbook's micro button.
local bar = wow.CreateFrame("Frame", "MultiBarBottomLeft")
bar.actionButtons = { wow.CreateFrame("CheckButton", "MultiBarBottomLeftButton1"),
	wow.CreateFrame("CheckButton", "MultiBarBottomLeftButton2") }
bar.numButtonsShowable = 12
local delegate = wow.CreateFrame("Frame", "FramePositionDelegate")
local micro = wow.CreateFrame("Button", "PlayerSpellsMicroButton")
-- luacheck: pop

local lines = {}
local ns = {
	Log = function(category, text) lines[#lines + 1] = { category, text } end,
	Flag = function(v) return v end,
	IsCineModeOn = function() return true end,
}
assert(loadfile("Dev/BarTaintCatch.lua"))("CinematicDev", ns)

local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. text)
	if not ok then failed = failed + 1 end
end
local function Logged(find)
	local n = 0
	for _, line in ipairs(lines) do
		if line[1] == "bartaint" and (not find or line[2]:find(find, 1, true)) then n = n + 1 end
	end
	return n
end

Check(type(ns.BarTaintScan) == "function" and type(ns.BarTaintCatch) == "function", "the file loaded")

-- A clean session: the scan finds nothing.
local list = ns.BarTaintScan(3)
local n = 0
for _ in pairs(list) do n = n + 1 end
Check(n == 0, "clean: no tainted field")

-- Not the bars': a nameplate's blocked call doesn't take the one catch.
wow.Fire("ADDON_ACTION_BLOCKED", "CinematicDev", "NamePlate1:SetPoint()")
Check(Logged() == 0 and not ns.BarTaintCaught(), "a nameplate's blocked call: no scan, the catch kept")

-- The 18:48 case: fields tainted (a bar's, a button's, a window manager slot
-- left nil), in a fight, then the burst.
bar.showAllButtons = 2 -- (SetShowGrid's, written in a tainted run)
Taint(bar, "showAllButtons", "CinematicDev")
bar.actionButtons[1].container = wow.CreateFrame("Frame")
Taint(bar.actionButtons[1], "container", "OtherAddon")
Taint(delegate, "center", "CinematicDev") -- (nil: not in pairs, a named slot)
Taint(micro, "suggestedTab", "CinematicDev")
fight = true
wow.Fire("ADDON_ACTION_BLOCKED", "CinematicDev", "MultiBarBottomLeft:SetFrameStrata()")
Check(ns.BarTaintCaught(), "the first bar call is caught")
Check(Logged("first blocked bar call this session: MultiBarBottomLeft:SetFrameStrata() (by CinematicDev)") == 1,
	"one summary line, naming the call and who")
Check(Logged("in a fight true, lockdown true") == 1, "it says it was in a fight")
Check(Logged("4 tainted field(s), 3 by Cinematic") == 1, "it counts every tainted field and ours")
Check(Logged("MultiBarBottomLeft.showAllButtons (by CinematicDev)") == 1, "the bar's field, with who wrote it")
Check(Logged("MultiBarBottomLeft.actionButtons[1].container (by OtherAddon)") == 1,
	"a button's field, with another addon as the writer")
Check(Logged("FramePositionDelegate.center (slot) (by CinematicDev)") == 1,
	"the window manager's nil slot, found by name")
Check(Logged("PlayerSpellsMicroButton.suggestedTab (slot) (by CinematicDev)") == 1,
	"the micro button's alert field, found by name")
local after = #lines
for i = 1, 300 do
	wow.Fire("ADDON_ACTION_BLOCKED", "CinematicDev", ("MultiBar6Button%d:SetShown()"):format(i % 12 + 1))
end
wow.Fire("ADDON_ACTION_FORBIDDEN", "CinematicDev", "MultiBarLeft:SetPointBase()")
Check(#lines == after, "the rest of the burst and later ones: nothing more logged")

-- A client with no issecurevariable: one line, no error.
issecurevariable = nil -- luacheck: ignore 121
lines = {}
local ns2 = { Log = ns.Log, Flag = ns.Flag, IsCineModeOn = ns.IsCineModeOn }
assert(loadfile("Dev/BarTaintCatch.lua"))("CinematicDev", ns2)
Check(ns2.BarTaintScan() == nil, "no issecurevariable: the scan returns nil")
ns2.BarTaintCatch("CinematicDev", "MultiBar5:HideBase()")
Check(Logged("no issecurevariable on this client, no scan") == 1, "and the catch says so in one line")

Check(#wow.warnings == 0, "no errors in the event handlers" .. (wow.warnings[1] and (": " .. wow.warnings[1]) or ""))
print(failed == 0 and "ALL PASS" or (failed .. " FAILED"))
if failed > 0 then os.exit(1) end
