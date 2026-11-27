-- Addon pins on the minimap and the Addon buttons row, every state (the
-- audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-25-minimap-pins.md):
--   python -I Tools/offline/run.py Tools/offline/minimappinsmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/minimappinsmatrix.lua --base <ref>
-- Frames.lua's IsAddonMapButton, through ns.FindMinimapHeader's look over the
-- Minimap's children. One child per cell, a named Button an addon made (the
-- game's taint record says so), of a kind found on players' minimaps:
-- - a pin: Questie's quest icon (QuestieFrame<n>, Questie's
--   Modules/FramePool/QuestieFrame.lua), another pooled pin named by its
--   number, or a pin with a plain name that a HereBeDragons copy keeps in its
--   minimapPins;
-- - a real button on the map's edge, by the names the installed addons give
--   them (_forever_ AddOns, 2026-11-25): LibDBIcon's, Journey Tracker's,
--   Panorama's, MSBT's, Battle Text Forever's, EllesmereUI's, GamepadXIV's,
--   and one named <Addon>MinimapButton<n>.
-- With the pins kept by: no HereBeDragons, the shared copy
-- (LibStub "HereBeDragons-Pins-2.0"), Questie's by its LibStub name, or
-- Questie's own module (QuestieLoader._modules.HBDPins). The Minimap page on
-- or off. Each cell: faded (on the Addon buttons row) or no.
-- The rule (the user, 2026-11-25): pins are never minimap buttons, the
-- buttons on the map's edge always are (3091bab's), whatever pin library is
-- loaded. (A plain-named pin no pin library lists can't be told from a
-- button: faded, as 3091bab's hand-made buttons.)

local client = arg and arg[1] or "forever"
local addonMade = {}
local libs = {}
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	issecurevariable = function(t, key)
		local name = key == nil and t or key
		if addonMade[name] then return false, addonMade[name] end
		return true
	end
	LibStub = setmetatable({}, { __call = function(_, major) return libs[major] end })
	-- luacheck: pop
end
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db

local PIN_KINDS = { questie = true, pooled = true, hbdpin = true }
local NAMES = {
	questie = "QuestieFrame%d", pooled = "SomeAddonMapIcon%d", hbdpin = "SomeAddonWaypointIcon",
	libdbicon = "LibDBIcon10_Thing", journeytracker = "JourneyTrackerMinimapButton",
	panorama = "PanoramaMinimapButton", msbt = "MSBTForeverMinimapButton",
	battletext = "BattleTextForeverMinimapButton", ellesmere = "EllesmereUIMinimapButton",
	gamepadxiv = "GamepadXIVMinimapButton", numberedbutton = "SomeAddonMinimapButton%d",
}

local count = 0
local holder = CreateFrame("Frame", "GathererBarPins", UIParent)
local function Faded(frame)
	for _, entry in ipairs(ns.managed) do
		if entry.frame == frame then return entry.group == "minimapaddons" and "faded" or ("in " .. entry.group) end
	end
	return "no"
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "minimap-pins",
	fixed = { client = client },
	dims = {
		{ "kind", { "questie", "pooled", "hbdpin", "libdbicon", "journeytracker", "panorama", "msbt",
			"battletext", "ellesmere", "gamepadxiv", "numberedbutton" } },
		{ "pinlib", { "none", "hbd", "questiehbd", "questiemodule" } },
		{ "page", { "on", "off" } },
	},
	cell = function(c)
		db.handleFrames = true
		db.showInMinimap = c.page == "on"
		count = count + 1
		local name = NAMES[c.kind]:format(count)
		addonMade[name] = "SomeAddon"
		local child = CreateFrame("Button", name, Minimap)
		-- (The pin library holding it, when it's a pin and one is loaded.)
		local registry = {}
		if PIN_KINDS[c.kind] then registry[child] = { x = 1, y = 2, instanceID = 0 } end
		for key in pairs(libs) do libs[key] = nil end
		rawset(_G, "QuestieLoader", nil)
		if c.pinlib == "hbd" then
			libs["HereBeDragons-Pins-2.0"] = { minimapPins = registry }
		elseif c.pinlib == "questiehbd" then
			libs["HereBeDragonsQuestie-Pins-2.0"] = { minimapPins = registry }
		elseif c.pinlib == "questiemodule" then
			rawset(_G, "QuestieLoader", { _modules = { HBDPins = { minimapPins = registry } } })
		end
		ns.FindMinimapHeader()
		local out = Faded(child)
		-- (Off the map for the next cells.)
		child:SetParent(holder)
		ns.FindMinimapHeader()
		_G[name] = nil
		return out
	end,
	pins = {
		-- (A pin, or the page off: not ours to fade.)
		{ "", "no" },
		-- (A real button on the map's edge, the page on: faded, whatever pin library is loaded.)
		{ "page=on kind=libdbicon", "faded" },
		{ "page=on kind=journeytracker", "faded" },
		{ "page=on kind=panorama", "faded" },
		{ "page=on kind=msbt", "faded" },
		{ "page=on kind=battletext", "faded" },
		{ "page=on kind=ellesmere", "faded" },
		{ "page=on kind=gamepadxiv", "faded" },
		-- (A button named with a number, Button<n>: still a button.)
		{ "page=on kind=numberedbutton", "faded" },
		-- (A plain-named pin no pin library lists: a button as far as anyone can tell.)
		{ "page=on kind=hbdpin pinlib=none", "faded" },
	},
})
