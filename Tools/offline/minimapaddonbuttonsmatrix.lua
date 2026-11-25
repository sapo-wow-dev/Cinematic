-- Other addons' buttons on the minimap's edge and the Addon buttons row,
-- every state (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-25-minimap-addon-buttons.md):
--   python -I Tools/offline/run.py Tools/offline/minimapaddonbuttonsmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/minimapaddonbuttonsmatrix.lua --base <ref>
-- Frames.lua's ns.FindMinimapHeader looks over the Minimap's children for
-- addon buttons. One child per cell, of a kind found on players' minimaps
-- (WoW Forever's AddOns folder, 2026-11-25): a LibDBIcon button, a button an
-- addon made itself (Journey Tracker, Panorama, MSBT...), a game button, a
-- named addon pin that's a Button (GatherMate's), an addon's named Frame on
-- the map (ShortestPath's pin holder, Questie's pin group) and an unnamed
-- button. The Minimap page on or off, the minimap left alone by a Support file
-- or not, and the button taken off the map later by an addon that gathers
-- buttons (MinimapButtonButton, Leatrix Plus) or not.
-- Each cell: faded (on the Addon buttons row) or no.
-- The rule (the user, 2026-11-25): every addon's button on the map's edge is
-- on the Addon buttons row, LibDBIcon's or not; never a game button, a pin or
-- the map's other frames; let go once gathered.

local client = arg and arg[1] or "forever"
-- (The game's taint record: names an addon made are not secure.)
local addonMade = {}
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	issecurevariable = function(t, key)
		local name = key == nil and t or key
		if addonMade[name] then return false, addonMade[name] end
		return true
	end
	-- luacheck: pop
end
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db

local KINDS = {
	libdbicon = { "Button", "LibDBIcon10_Thing%d", true },
	handmade = { "Button", "JourneyTrackerMinimapButton%d", true },
	game = { "Button", "MiniMapGameButton%d", false },
	pin = { "Button", "GatherMatePin%d", true },
	frame = { "Frame", "ShortestPathForeverMinimapPins%d", true },
	unnamed = { "Button", nil, true },
}

local count = 0
local holder = CreateFrame("Frame", "GathererBar", UIParent)
local function Faded(frame)
	for _, entry in ipairs(ns.managed) do
		if entry.frame == frame then return entry.group == "minimapaddons" and "faded" or ("in " .. entry.group) end
	end
	return "no"
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "minimap-addon-buttons",
	fixed = { client = client },
	dims = {
		-- (Left alone last: a Support file's ns.LeaveAlone can't be undone.)
		{ "leftalone", { "no", "yes" } },
		{ "kind", { "libdbicon", "handmade", "game", "pin", "frame", "unnamed" } },
		{ "page", { "on", "off" } },
		{ "gathered", { "no", "yes" } },
	},
	cell = function(c)
		if c.leftalone == "yes" and not ns.IsLeftAlone("Minimap") then ns.LeaveAlone({ "Minimap" }) end
		db.handleFrames = true
		db.showInMinimap = c.page == "on"
		count = count + 1
		local kind = KINDS[c.kind]
		local name = kind[2] and kind[2]:format(count) or nil
		if name and kind[3] then addonMade[name] = "SomeAddon" end
		local child = CreateFrame(kind[1], name, Minimap)
		ns.FindMinimapHeader()
		local out = Faded(child)
		if c.gathered == "yes" then
			child:SetParent(holder)
			ns.FindMinimapHeader()
			out = out .. ">" .. Faded(child)
		end
		-- (Off the map for the next cells.)
		child:SetParent(holder)
		ns.FindMinimapHeader()
		return out
	end,
	pins = {
		-- (Not an addon's edge button, the page off or the map left alone: not ours to fade.)
		{ "", "no" },
		{ "gathered=yes", "no>no" },
		-- (An addon's button on the edge, the page on: faded; gathered later: let go.)
		{ "leftalone=no page=on kind=libdbicon gathered=no", "faded" },
		{ "leftalone=no page=on kind=libdbicon gathered=yes", "faded>no" },
		{ "leftalone=no page=on kind=handmade gathered=no", "faded" },
		{ "leftalone=no page=on kind=handmade gathered=yes", "faded>no" },
	},
})
