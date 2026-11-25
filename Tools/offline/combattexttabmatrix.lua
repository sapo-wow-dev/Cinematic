-- Combat Text Style's General tab (the audit kit's matrix, Tools/offline/matrix.lua;
-- fix card Tools/audits/2026-11-25-combat-text-general-tab.md):
--   python -I Tools/offline/run.py Tools/offline/combattexttabmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/combattexttabmatrix.lua forever --base <ref>
-- A login (one load per cell) with Combat Text Style's page on or off, its
-- General tab on or off, Hide all the game's floating text ticked and your
-- damage ours; then two seconds pass. Each cell: our numbers on or off, the
-- game's damage numbers setting (ours = held off, game = its own back), the
-- game's floating text font at login (blank or game), and the page's 2 s
-- refresh loop running or not.
-- The rule (a tab is a container; page off = all off): with either off,
-- nothing of ours: no numbers, the game's setting and font its own, no loop.
local client = arg and arg[1] or "forever"
local GAME_FONT = "Fonts\\FRIZQT__.TTF"
local TAB = "tabOn:Combat Text Style/page:1"
local cvars, tickers
local saved -- (a first login's settings, its once-only updates done: each cell logs in on a copy)

local function Login(c)
	cvars = { floatingCombatTextCombatDamage = "1", floatingCombatTextCombatDamage_v2 = "1" }
	tickers = {}
	local function Install()
		-- luacheck: push ignore 111 112 113 121 122
		GetCVar = function(name) return cvars[name] or "1" end
		SetCVar = function(name, value) cvars[name] = tostring(value) end
		C_CVar = C_CVar or {}
		C_CVar.GetCVar = GetCVar
		C_CVar.SetCVar = SetCVar
		C_Timer = {
			After = function() end,
			NewTimer = function() return { Cancel = function() end } end,
			NewTicker = function(_, fn)
				local t = { fn = fn, live = true }
				t.Cancel = function() t.live = false end
				tickers[#tickers + 1] = t
				return t
			end,
		}
		DAMAGE_TEXT_FONT = GAME_FONT
		if c then
			CinematicDB = {}
			for key, value in pairs(saved) do CinematicDB[key] = value end
			CinematicDB.styleGeneral, CinematicDB.combatTextStyle, CinematicDB.hideWorldText = true, c.page == "on", true
			CinematicDB.combatTextNumbers, CinematicDB.combatTextDamageBy, CinematicDB[TAB] = true, "ours", c.tab == "on"
		end
		-- luacheck: pop
	end
	return dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
end
saved = Login().db

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "combat-text-general-tab",
	fixed = { client = client },
	dims = {
		{ "page", { "on", "off" } },
		{ "tab", { "on", "off" } },
	},
	cell = function(c)
		local ns = Login(c)
		local font = type(DAMAGE_TEXT_FONT) == "string" and DAMAGE_TEXT_FONT:find("Blank%.ttf$") and "blank" or "game"
		ns.RefreshCombatTextStyle()
		-- (Two seconds passing: the feature loops synced, then each live timer.)
		local refreshes = 0
		local Refresh = ns.RefreshCombatTextStyle
		ns.RefreshCombatTextStyle = function(...)
			refreshes = refreshes + 1
			return Refresh(...)
		end
		for _ = 1, 2 do
			ns.SyncFeatureLoops()
			for i = 1, #tickers do
				if tickers[i].live then pcall(tickers[i].fn) end
			end
		end
		ns.RefreshCombatTextStyle = Refresh
		local numbers = (ns.CombatTextStateLine() or ""):match("^numbers on=(%a+)")
		return ("numbers=%s cvar=%s font=%s loop=%s"):format(numbers == "true" and "on" or "off",
			cvars.floatingCombatTextCombatDamage == "0" and "ours" or "game", font, refreshes > 0 and "on" or "off")
	end,
	pins = {
		{ "", "numbers=off cvar=game font=game loop=off" },
		{ "page=on tab=on", "numbers=on cvar=ours font=blank loop=on" },
		-- (The page on: its refresh runs, to catch the tab coming back on; it holds nothing.)
		{ "page=on tab=off", "numbers=off cvar=game font=game loop=on" },
	},
})
