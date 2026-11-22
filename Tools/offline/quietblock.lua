-- Settings opened in a fight with the gamepad UI: its blocked lines kept out
-- of the dev error box (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/quietblock.lua < /dev/null
-- 2026-11-22 the settings key in a fight put 5 "blocked (no event)" lines in
-- the box: ns.QuietSettingsBlock went by a flag only ns.OpenOptions set (and
-- only with _G.SmartNavigation). Now the stack itself is known, and
-- ns.PickSettingsCategory sets the flag for every caller in a fight.
-- Tools/errors/known.lua: settings-pick-in-fight-gamepad. PASS or FAIL per check.
local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc")

local fails = 0
local function Check(name, got, want)
	local ok = got == want
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. " (" .. tostring(got) .. ")")
end

Check("hooks there", type(ns.QuietSettingsBlock) == "function" and type(ns.PickSettingsCategory) == "function", true)
if type(ns.QuietSettingsBlock) ~= "function" then os.exit(1) end

-- (The stack from the dev box, 2026-11-22, cut to the lines that tell.)
local REPORTED = table.concat({
	"[C]: in function 'DisplayInterfaceActionBlockedMessage'",
	"[Blizzard_GamepadSmartNavigation/SecureHelper.lua]:19: in function <...>",
	"[C]: in function 'SetAttribute'",
	"[Blizzard_GamepadSmartNavigation/SecureHelper.lua]:156: in function 'SetSecureValue'",
	"[Blizzard_GamepadSmartNavigation/Utility.lua]:180: in function 'SmartNavigation_SetCustomCursorAnchorPointForFrame'",
	"[Blizzard_Settings_Shared/Blizzard_CategoryList.lua]:106: in function 'Init'",
	"[Blizzard_Settings_Shared/Blizzard_SettingsPanel.lua]:847: in function 'SelectCategory'",
	"[CinematicDev/Options.lua]:20578: in function 'PickSettingsCategory'",
	"[CinematicDev/Options.lua]:20607: in function 'OpenOptions'",
	"[CinematicDev/Options.lua]:20742: in function 'Cinematic_ToggleSettings'",
}, "\n")
-- (The game's own Escape > Options with a list we tainted earlier: a real
-- problem, must still show.)
local GAME_OPEN = table.concat({
	"[Blizzard_GamepadSmartNavigation/SecureHelper.lua]:156: in function 'SetSecureValue'",
	"[Blizzard_GamepadSmartNavigation/Utility.lua]:120: in function 'SmartNavigation_SetButtonFrame'",
	"[Blizzard_Settings_Shared/Blizzard_SettingsPanel.lua]:300: in function 'OnShow'",
}, "\n")

ns.SettingsOpenedInFight(false)
Check("reported stack, no flag set: quiet", ns.QuietSettingsBlock(REPORTED), true)
Check("game's own open, no flag: shown", ns.QuietSettingsBlock(GAME_OPEN), false)
Check("not a gamepad block: shown", ns.QuietSettingsBlock("[C]: in function 'SetAttribute'\n'PickSettingsCategory'"), false)
Check("not a string: shown", ns.QuietSettingsBlock(nil), false)

-- (A pick in a fight, from any caller: the flag is set, so later redraws in
-- that fight (no pick of ours in their stack) are quiet too.)
local picked
local panel = {
	IsShown = function() return true end, Show = function() end,
	SelectCategory = function(_, c) picked = c end,
}
local realLockdown = InCombatLockdown
InCombatLockdown = function() return true end -- luacheck: ignore
local category = { GetID = function() return 7 end }
ns.PickSettingsCategory(panel, category)
InCombatLockdown = realLockdown -- luacheck: ignore
Check("fight pick selected the page", picked == category, true)
Check("fight pick set the flag", ns.settingsOpenedInFight, true)
Check("then a redraw with no pick of ours: quiet", ns.QuietSettingsBlock(GAME_OPEN), true)
ns.SettingsOpenedInFight(false)
Check("flag cleared at fight end: game's open shown again", ns.QuietSettingsBlock(GAME_OPEN), false)

-- (Gamepad UI, a real fight: the window opens with NO page pick (our pick
-- moved the left list's set under our taint, and the game's Escape > Options
-- in a later fight had 1756 rows blocked: /cine debug fightopen step 3,
-- 2026-11-22). The page comes up the clean way when the fight ends, only if
-- the window is still open.)
local shownNow, selected, opened = false, nil, nil
local fakePanel = {
	IsShown = function() return shownNow end, Show = function() shownNow = true end,
	IsProtected = function() return false end,
	SelectCategory = function(_, c) selected = c end,
	GetCategory = function() return nil end,
}
local realPanel, realPad, realSettings = SettingsPanel, _G.SmartNavigation, Settings
SettingsPanel = fakePanel -- luacheck: ignore
_G.SmartNavigation = {}
Settings = setmetatable({ OpenToCategory = function(id) opened = id end }, { __index = realSettings }) -- luacheck: ignore
InCombatLockdown = function() return true end -- luacheck: ignore
ns.SettingsOpenedInFight(false)
ns.OpenOptions("Card Vision")
local waits, waitPage = ns.SettingsPickAfterFight()
Check("gamepad fight: window shown", shownNow, true)
Check("gamepad fight: no page picked", selected, nil)
Check("gamepad fight: pick waits for Card Vision", waits and waitPage, "Card Vision")
Check("gamepad fight: quiet mark set", ns.settingsOpenedInFight, true)
InCombatLockdown = realLockdown -- luacheck: ignore
wow.Fire("PLAYER_REGEN_ENABLED")
Check("fight over, window open: picked with OpenToCategory", opened ~= nil, true)
Check("fight over: nothing picked with SelectCategory", selected, nil)
Check("fight over: no longer waiting", (ns.SettingsPickAfterFight()), false)
-- (Closed during the fight: not opened again after it.)
InCombatLockdown = function() return true end -- luacheck: ignore
shownNow, opened = false, nil
ns.OpenOptions("Card Vision")
shownNow = false
InCombatLockdown = realLockdown -- luacheck: ignore
wow.Fire("PLAYER_REGEN_ENABLED")
Check("closed in the fight: not opened after it", opened, nil)
-- (No gamepad UI: picked in the fight as before. False, not nil: the
-- stand-in answers a missing global with a stub.)
_G.SmartNavigation = false
InCombatLockdown = function() return true end -- luacheck: ignore
selected = nil
ns.OpenOptions("Card Vision")
InCombatLockdown = realLockdown -- luacheck: ignore
Check("no gamepad UI: page picked in the fight", selected ~= nil, true)
Check("no gamepad UI: no pick waiting", (ns.SettingsPickAfterFight(true)), false)
SettingsPanel, _G.SmartNavigation, Settings = realPanel, realPad, realSettings -- luacheck: ignore
ns.SettingsOpenedInFight(false)

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
