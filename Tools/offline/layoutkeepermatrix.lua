-- Whose Edit Mode layout a profile's layout leaves alone, every state (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-22-addons-layout-keeper.md):
--   python -I Tools/offline/run.py Tools/offline/layoutkeepermatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/layoutkeepermatrix.lua forever --base <ref>
-- DaylightUI and Leatrix Plus each put a layout of their own back at every
-- login; a profile's layout switching it away too made the two take turns, so
-- a profile's layout is left to the one keeping it (ns.layoutKeeper,
-- Profiles/Layouts.lua). Which addons are in (at login, or loaded after login
-- in either order), either one's support switched off on the Addons page, and
-- whether each keeps a layout (DaylightUI set up or on one of its layouts, or
-- its Edit Mode part not made;
-- Leatrix Plus's Set edit mode layout ticked with a name). Each cell: the
-- keeper the profile's layout yields to. The rule: an addon whose support is
-- on and which keeps a layout is never overridden, whatever the load order;
-- with both keeping one, DaylightUI's (the whole-UI one) is named.
-- (bdb2e1d^: DaylightUI loaded after Leatrix Plus replaced its keeper, so
-- Leatrix Plus's layout and a profile's took turns.)

local client = arg and arg[1] or "forever"
local loaded = {}
local saved
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	C_AddOns.IsAddOnLoaded = function(name) return loaded[name] == true end
	IsAddOnLoaded = C_AddOns.IsAddOnLoaded
	CinematicDB, CinematicCharDB = saved, nil
	-- luacheck: pop
end

local DUI, LEA = "DaylightUI", "Leatrix_Plus"
-- loads: what's in and how: "none", one at login ("dui", "lea"), both loaded
-- after login in that order ("dui>lea", "lea>dui"), or both with one's
-- support switched off (saved off: after its reload).
local LOADS = {
	none = {},
	dui = { login = { DUI } },
	lea = { login = { LEA } },
	["dui>lea"] = { late = { DUI, LEA } },
	["lea>dui"] = { late = { LEA, DUI } },
	["lea>dui:duiOff"] = { late = { LEA, DUI }, off = DUI },
	["dui>lea:leaOff"] = { late = { DUI, LEA }, off = LEA },
}

local cache = {}
local function Load(name)
	if cache.name == name then return cache.ns, cache.how end
	local how = LOADS[name]
	loaded = {}
	for _, addon in ipairs(how.login or {}) do loaded[addon] = true end
	saved = how.off and { addonSupportOff = { [how.off] = true } } or nil
	-- (Their saved variables are in before their code runs: set per cell below.)
	rawset(_G, "DaylightUI", nil)
	rawset(_G, "LeaPlusDB", nil)
	local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
	for _, addon in ipairs(how.late or {}) do
		loaded[addon] = true
		wow.Fire("ADDON_LOADED", addon)
	end
	cache.name, cache.ns, cache.how = name, ns, how
	return ns, how
end

local function In(how, addon)
	for _, list in ipairs({ how.login or {}, how.late or {} }) do
		for _, name in ipairs(list) do
			if name == addon then return true end
		end
	end
	return false
end

local Matrix = dofile("Tools/offline/matrix.lua")
local pins = { { "", "keeper=none" } }
-- (Leatrix Plus in, its support on, its layout set: kept.)
for _, loads in ipairs({ "lea", "dui>lea", "lea>dui", "lea>dui:duiOff" }) do
	pins[#pins + 1] = { "loads=" .. loads .. " leaLayout=yes", "keeper=Leatrix Plus" }
end
-- (DaylightUI in, its support on, its layout set: kept, named over Leatrix Plus's.)
for _, loads in ipairs({ "dui", "dui>lea", "lea>dui", "dui>lea:leaOff" }) do
	pins[#pins + 1] = { "loads=" .. loads .. " duiLayout=yes", "keeper=DaylightUI" }
end

Matrix.Run({
	name = "layout-keeper",
	fixed = { client = client },
	dims = {
		{ "loads", { "none", "dui", "lea", "dui>lea", "lea>dui", "lea>dui:duiOff", "dui>lea:leaOff" } },
		{ "duiLayout", { "yes", "no", "unmade" } },
		{ "leaLayout", { "yes", "no" } },
	},
	cell = function(c)
		local ns, how = Load(c.loads)
		local duiYes, leaYes = c.duiLayout == "yes", c.leaLayout == "yes"
		-- (unmade: its Edit Mode part not made, so no layout of its own to say.)
		rawset(_G, "DaylightUI", In(how, DUI) and (c.duiLayout == "unmade" and {} or {
			EditMode = { AnyActive = function() return duiYes end },
			Installer = { State = function() return duiYes and "installed" or "skipped" end },
		}) or nil)
		rawset(_G, "LeaPlusDB", In(how, LEA) and {
			SetEditModeLayout = leaYes and "On" or "Off",
			EditModeLayoutName = leaYes and "Leatrix" or "",
		} or nil)
		local keeper = ns.layoutKeeper
		local ok, name = true, nil
		if keeper then ok, name = pcall(keeper) end
		if not ok then return "keeper error: " .. tostring(name) end
		return "keeper=" .. tostring(name or "none")
	end,
	pins = pins,
})
