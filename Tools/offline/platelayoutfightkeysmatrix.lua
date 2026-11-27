-- Plate Layout: the arrow keys and a fight (the audit kit's matrix, Tools/offline/matrix.lua;
-- fix card Tools/audits/2026-11-25-plate-layout-fight-keys.md):
--   python -I Tools/offline/run.py Tools/offline/platelayoutfightkeysmatrix.lua < /dev/null
--   python -I Tools/audit.py diff Tools/offline/platelayoutfightkeysmatrix.lua forever --base <ref>
-- The level box picked on the Layout tab, the keys taken (the mouse on a part); then a
-- key with the mouse over the preview or away, and a fight: none, starting before the
-- key, starting right after it (before the next frame), or a frame after it. Each cell:
-- the level box's left/right after the key; in the fight, whether the page's key frame
-- holds the keyboard (shown, keyboard on, keys not passed on: then no key reaches the
-- game, the bug); and after the fight (or a frame later), whether the right arrow over
-- the preview nudges again (the mouse brought back onto a part if it was away).
-- luacheck: ignore 111 112 113 121 122 212 431
local parts = dofile("Tools/offline/gameplate_parts.lua")(function() end)
local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", function()
	issecretvalue = function() return false end
	parts.Install()
end)
local page = ns.plateLayoutPage
IsShiftKeyDown = function() return false end

-- (A frame's timers: C_Timer.After run when the cell says a frame has passed.)
local timers = {}
C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
local function NextFrame()
	local list = timers
	timers = {}
	for _, fn in ipairs(list) do fn() end
end
local fighting = false
InCombatLockdown = function() return fighting end
-- (PLAYER_REGEN_DISABLED comes just before the lockdown: the game's order.)
local function FightStarts()
	wow.Fire("PLAYER_REGEN_DISABLED")
	fighting = true
end
local function FightEnds()
	fighting = false
	wow.Fire("PLAYER_REGEN_ENABLED")
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "platelayout-fightkeys",
	fixed = { client = "forever" },
	dims = { { "mouse", { "preview", "away" } }, { "key", { "RIGHT", "W" } },
		{ "fight", { "none", "before", "soon", "later" } } },
	cell = function(c)
		-- (Code with no Layout tab, v2.1.34 and older: an error, so audit.py reads
		-- "old code errors", not a changed cell.)
		if not page then error("no Layout tab in this code (ns.plateLayoutPage)") end
		fighting = false
		timers = {}
		ns.db.plateLayout = true
		ns.db.plateLayoutData = { all = { parts = {} } }
		page.Edit("all")
		local keys = page.keys
		keys:Show()
		local passed, keyboard = true, false
		keys.SetPropagateKeyboardInput = function(_, on)
			if fighting then error("SetPropagateKeyboardInput: in combat") end
			passed = on
		end
		keys.EnableKeyboard = function(_, on)
			if fighting then error("EnableKeyboard: in combat") end
			keyboard = on and true or false
		end
		local mouse = c.mouse
		page.holder.IsVisible = function() return true end
		page.holder.IsMouseOver = function() return mouse == "preview" end
		if page.partsPanel then
			page.partsPanel.IsVisible = function() return true end
			page.partsPanel.IsMouseOver = function() return false end
		end
		page.Select("level")
		ns.PlateLayoutPageKeys() -- (as the mouse comes onto a part of the plate)
		local function Press(key)
			-- (A hidden frame gets no keys.)
			local onKey = keys:IsShown() and keys:GetScript("OnKeyDown")
			if onKey then onKey(keys, key) end
		end
		local function X()
			local p = ns.db.plateLayoutData.all.parts.level
			return p and p.x or 0
		end
		if c.fight == "before" then FightStarts() end
		Press(c.key)
		local x = X()
		if c.fight == "soon" then FightStarts() NextFrame() end
		if c.fight == "later" then NextFrame() FightStarts() end
		local inFight = "-"
		if c.fight ~= "none" then
			inFight = (keys:IsShown() and keyboard and passed == false) and "held" or "free"
			NextFrame()
			FightEnds()
		end
		NextFrame()
		-- (Then the right arrow over the preview: the mouse back onto a part if it was away.)
		if mouse ~= "preview" then
			mouse = "preview"
			ns.PlateLayoutPageKeys()
		end
		local before = X()
		Press("RIGHT")
		local after = (X() == before + 1 and passed == false) and "nudges" or "stuck"
		fighting = false
		return ("x=%d fight=%s then=%s"):format(x, inFight, after)
	end,
	pins = {
		-- What's right (the audit, 2026-11-25): the arrow nudges with the mouse on the
		-- preview, out of a fight only; in a fight the page never holds the keyboard
		-- (movement and casting keys reach the game); after it the arrows nudge again.
		{ "", "x=0 fight=free then=nudges" },
		{ "fight=none", "x=0 fight=- then=nudges" },
		{ "mouse=preview key=RIGHT fight=none", "x=1 fight=- then=nudges" },
		{ "mouse=preview key=RIGHT fight=soon", "x=1 fight=free then=nudges" },
		{ "mouse=preview key=RIGHT fight=later", "x=1 fight=free then=nudges" },
	},
})
