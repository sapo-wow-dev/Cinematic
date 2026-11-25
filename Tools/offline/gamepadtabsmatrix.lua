-- The Gamepad Frames page's tabs (the audit kit's matrix, Tools/offline/matrix.lua;
-- fix card Tools/audits/2026-11-25-gamepad-tabs.md):
--   python -I Tools/offline/run.py Tools/offline/gamepadtabsmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/gamepadtabsmatrix.lua forever --base <ref>
-- The gamepad action bars faded (a stand-in GamepadMainActionBarFrame), then
-- the page's switch, its Show tab (the frames' rows) and its Settings tab
-- (Show the action bars when you press a button) each on or off, and the
-- switches' own refresh (ns.SyncSwitches, each frames pass). Each cell:
-- whether the bars are still faded by us (managed) and whether a button
-- press brings them up (the press waits a moment, then reveals).
-- The rule (the user's): a tab is a container, off: all on it off.
-- luacheck: push ignore 111 112 113 121 122
local client = arg and arg[1] or "forever"
local now = 100
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
	GetTime = function() return now end
	InCombatLockdown = function() return false end
	UnitAffectingCombat = function() return false end
	IsFalling = function() return false end
	GetBindingAction = function() return "ACTIONBUTTON1" end
end)
LootFrame = wow.CreateFrame("Frame", nil, UIParent) -- (not looting: not fishing)
LootFrame:Hide()
ns.IsFishingNow = function() return false end
ns.IsGamePadOn = function() return false end -- (the pad's state not read: the stub's held every button)
local db = ns.db
local bars = rawget(_G, "GamepadMainActionBarFrame") or wow.CreateFrame("Frame", "GamepadMainActionBarFrame", UIParent)
local pad
for _, frame in ipairs(wow.frames) do
	if (rawget(frame, "_events") or {}).GAME_PAD_BUTTON_DOWN then pad = frame end
end
local function Managed()
	for _, entry in ipairs(ns.managed) do
		if entry.frame == bars then return true end
	end
	return false
end
local function SetAll(page, show, settings)
	db.handleFrames = true -- (the HUD on: the page's under it)
	db.handleGamepad = page
	db["tabOn:Gamepad/tab:1"], db["tabOn:Gamepad/tab:2"] = show, settings
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "gamepad-tabs",
	fixed = { client = client },
	dims = {
		{ "page", { "on", "off" } },
		{ "show", { "on", "off" } },
		{ "settings", { "on", "off" } },
	},
	cell = function(c)
		db.gamepadPressReveal = true
		SetAll(true, true, true)
		ns.SyncSwitches()
		pcall(ns.BuildManagedList)
		if not Managed() then return "not faded to start" end
		SetAll(c.page == "on", c.show == "on", c.settings == "on")
		ns.SyncSwitches()
		local managed = Managed()
		-- (A press: waits CAST_WAIT, then the pad's watch reveals the bars.)
		ns.framesWake = nil
		now = now + 5
		pad:GetScript("OnEvent")(pad, "GAME_PAD_BUTTON_DOWN", "PAD1")
		now = now + 0.5
		pad:GetScript("OnUpdate")(pad, 0.5)
		local revealed = ns.framesWake == "gamepad press"
		now = now + 30
		SetAll(true, true, true)
		ns.SyncSwitches()
		return ("faded=%s press=%s"):format(managed and "yes" or "no", revealed and "reveals" or "nothing")
	end,
	pins = {
		{ "", "faded=no press=nothing" },
		{ "page=on show=on settings=off", "faded=yes press=nothing" },
		{ "page=on show=off settings=on", "faded=no press=reveals" },
		{ "page=on show=on settings=on", "faded=yes press=reveals" },
	},
})
-- luacheck: pop
