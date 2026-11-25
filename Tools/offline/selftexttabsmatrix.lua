-- Text on You's tabs (the audit kit's matrix, Tools/offline/matrix.lua;
-- fix card Tools/audits/2026-11-25-self-text-tabs.md):
--   python -I Tools/offline/run.py Tools/offline/selftexttabsmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/selftexttabsmatrix.lua forever --base <ref>
-- Self Text Style (Style/SelfTextStyle.lua) with its page on or off, and none
-- of its tabs off or one of them (General, Look, Kinds); its Size 2 (Look) and
-- Damage taken hidden (Kinds) set. Then the page applied and two seconds pass.
-- Each cell: who draws (ours or game), the game's frame held hidden or not,
-- the game's floating combat text setting held on (ours) or its own (game), a
-- damage sample's size (big = Size 2, base = the default) or hidden, and its
-- 2 s refresh loop running or not.
-- The rule (a tab is a container; page off = all off): General off = the
-- game's text as it was; Look off = the default look; Kinds off = every kind
-- shown as the default; page off = nothing held, no loop.
local client = arg and arg[1] or "forever"
local cvars = { enableFloatingCombatText = "0" }
local tickers = {}
local now = 100
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	GetTime = function() return now end
	GetCVar = function(name) return cvars[name] or "0" end
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
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
if ns.MapTabContainers then ns.MapTabContainers() end -- (a timer in game)
local TABS = { general = "tabOn:Self Text Style/page:1", look = "tabOn:Self Text Style/page:2",
	kinds = "tabOn:Self Text Style/page:3" }

-- The game's CombatText, a stand-in: its alpha.
local ct = wow.CreateFrame("Frame", "CombatText")
_G.CombatText = ct
ct:CreateFontString()
ct._alpha = 1
ct.SetAlpha = function(self, alpha) self._alpha = alpha end
ct.GetAlpha = function(self) return self._alpha end
-- (Ours: each text's size as set.)
local layer = _G.CinematicSelfText
local Make = layer.CreateFontString
layer.CreateFontString = function(self, ...)
	local fs = Make(self, ...)
	fs.SetFont = function(text, _, size) text._size = size end
	fs.GetFont = function(text) return "font", text._size, "" end
	return fs
end

local refreshes = 0
local Refresh = ns.RefreshSelfTextStyle
ns.RefreshSelfTextStyle = function(...)
	refreshes = refreshes + 1
	return Refresh(...)
end
-- (Two seconds passing: the feature loops synced, then each live timer, the
-- load's too: the old code's refresh timer was made there.)
local function Seconds()
	ns.SyncFeatureLoops()
	for i = 1, #tickers do
		local t = tickers[i]
		if t.live then pcall(t.fn) end
	end
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	-- (Retail: no page there, so no tabs to switch off; a matrix of its own.)
	name = ns.isRetail and "self-text-tabs-retail" or "self-text-tabs",
	fixed = { client = client },
	dims = {
		{ "page", { "on", "off" } },
		{ "tabOff", ns.isRetail and { "none" } or { "none", "general", "look", "kinds" } },
	},
	cell = function(c)
		-- (Every cell from the same start: the page on, ours drawing.)
		db.styleGeneral, db.selfTextStyle, db.selfTextAlways, db.selfTextBy = true, true, true, "ours"
		for _, key in pairs(TABS) do db[key] = true end
		db.selfTextSize, db.selfText_damageShow = 2, false
		Refresh()
		db.selfTextStyle = c.page == "on"
		if TABS[c.tabOff] then db[TABS[c.tabOff]] = false end
		Refresh()
		Seconds()
		refreshes = 0
		Seconds()
		Seconds()
		local loop = refreshes > 0 and "on" or "off"
		-- (Each sample seconds after the last: none merged into one before.)
		now = now + 10
		local heal = ns.SelfTextSample("+120", "heal", false)
		local size = heal and select(2, heal:GetFont())
		now = now + 10
		local damage = ns.SelfTextSample("-26", "damage", false)
		local sample = (not heal and "none" or (size and size > 30 and "big" or "base"))
			.. (damage and "+damage" or "")
		local out = ("by=%s hidden=%s cvar=%s sample=%s loop=%s"):format(ns.SelfTextBy(),
			ct:GetAlpha() == 0 and "yes" or "no", cvars.enableFloatingCombatText == "1" and "ours" or "game", sample,
			loop)
		db.selfTextStyle = true
		for _, key in pairs(TABS) do db[key] = true end
		db.selfTextSize, db.selfText_damageShow = 1, true
		return out
	end,
	pins = {
		-- (The sample is the page's preview's: drawn with the page off too.)
		{ "page=on", "by=ours hidden=yes cvar=ours sample=big loop=on" },
		{ "page=on tabOff=general", "by=game hidden=no cvar=game sample=big loop=on" },
		{ "page=on tabOff=look", "by=ours hidden=yes cvar=ours sample=base loop=on" },
		{ "page=on tabOff=kinds", "by=ours hidden=yes cvar=ours sample=big+damage loop=on" },
		{ "page=off", "by=game hidden=no cvar=game sample=big loop=off" },
		{ "page=off tabOff=look", "by=game hidden=no cvar=game sample=base loop=off" },
		{ "page=off tabOff=kinds", "by=game hidden=no cvar=game sample=big+damage loop=off" },	},
})
