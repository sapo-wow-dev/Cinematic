-- A plate's second line (an NPC's title, a player's guild) with Name Style's
-- switches (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-25-guild-line-name-style.md):
--   python -I Tools/offline/run.py Tools/offline/guildlinestylematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/guildlinestylematrix.lua forever --base <ref>
-- A stand-in plate of a Baker (title <Baker>, its name hidden: a title shown
-- alone), Name Style's All names set: second line 150% and 50% opacity,
-- Brackets kept, Icons on or off. Enable Style on or off, Name Style's switch
-- on or off, the Names grid's Service NPCs tab on or off (Vendors ticked).
-- Each cell: the line's words (<Baker>, Baker, its icon, or none: an icon asked for, none
-- offline), its opacity (half = ours), its size set (big = ours) and whether
-- the Service NPCs row counts it (kept).
-- The rule (page off = every setting on it off; a tab is a container): Name
-- Style's look only with Enable Style and Name Style on; a kind's tick only
-- with its tab on.
local client = arg and arg[1] or "forever"
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db
if ns.MapTabContainers then ns.MapTabContainers() end -- (a timer in game)
local TAB = "tabOn:Nameplates:NamesService"

local function Up(fn, wanted)
	for i = 1, 80 do
		local name, value = debug.getupvalue(fn, i)
		if not name then break end
		if name == wanted then return value, i end
	end
end
local function Set(fn, wanted, value)
	local _, at = Up(fn, wanted)
	if at then debug.setupvalue(fn, at, value) end
	return at ~= nil
end
local Refresh = Up(ns.SetPlateGuild, "Refresh")
local LineText = Refresh and Up(Refresh, "LineText")
local ready = LineText and Set(LineText, "IsPlayer", function() return false end)
	and Set(LineText, "PlateTitle", function() return "<Baker>" end)
	and Set(ns.PlateServiceMatch, "PlateTitle", function() return "<Baker>" end)

local unitFrame = wow.CreateFrame("Frame")
local name = unitFrame:CreateFontString()
rawset(name, "GetFont", function() return "Fonts\\FRIZQT__.TTF", 12, "" end)
rawset(name, "GetFontObject", function() return nil end)
rawset(name, "GetShadowOffset", function() return 1, -1 end)
rawset(name, "GetShadowColor", function() return 0, 0, 0, 1 end)
rawset(name, "GetTextColor", function() return 1, 1, 1 end)
rawset(name, "GetScale", function() return 1 end)
local plate = wow.CreateFrame("Frame")
plate.UnitFrame, plate.namePlateUnitToken = unitFrame, "nameplate1"
unitFrame.name = name
ns.PlateNameText = function() return name end
ns.NameRowOf = function() return "all" end
local sized = false
ns.SetPlateNameFont = function(_, _, _, _, scale) sized = scale ~= 1 end
local lineAlpha
local create = unitFrame.CreateFontString
rawset(unitFrame, "CreateFontString", function(self, ...)
	local line = create(self, ...)
	rawset(line, "SetAlpha", function(_, alpha) lineAlpha = alpha end)
	return line
end)

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "guild-line-name-style",
	fixed = { client = client },
	dims = {
		{ "style", { "on", "off" } },
		{ "page", { "on", "off" } },
		{ "icons", { "on", "off" } },
		{ "tab", { "on", "off" } },
	},
	cell = function(c)
		if not ready then return "no stand-in" end
		db.styleGeneral, db.plateNameStyle = c.style == "on", c.page == "on"
		db[ns.NameLookKey("all", "Line2Size")], db[ns.NameLookKey("all", "Line2Alpha")] = 1.5, 0.5
		db.nameServiceBrackets, db.nameServiceBracketsWithName, db.nameServiceIcons = true, false, c.icons == "on"
		db.handleNames, db[TAB], db.nameServiceVendor = true, c.tab == "on", true
		if ns.ServiceKindsChanged then ns.ServiceKindsChanged() end
		sized, lineAlpha = false, nil
		ns.SetPlateGuild(plate, 1, 0)
		local line = ns.PlateLine2Text(plate)
		local words = line and (tostring(line._text):find("^|T") and "icon" or line._text) or "none"
		local kept = ns.PlateServiceMatch(plate, "nameplate1") and "yes" or "no"
		local out = ("line=%s alpha=%s size=%s kept=%s"):format(words,
			line and (lineAlpha and lineAlpha < 0.9 and "half" or "full") or "-", line and (sized and "big" or "usual") or "-",
			kept)
		ns.SetPlateGuild(plate, 0, 0)
		db.styleGeneral, db.plateNameStyle, db[TAB] = true, true, true
		db[ns.NameLookKey("all", "Line2Size")], db[ns.NameLookKey("all", "Line2Alpha")] = nil, nil
		db.nameServiceBrackets, db.nameServiceBracketsWithName, db.nameServiceIcons = false, true, false
		return out
	end,
	pins = {
		-- (Name Style off: the game's look, no brackets (their default), no icons.)
		{ "tab=on", "line=Baker alpha=full size=usual kept=yes" },
		{ "tab=off", "line=Baker alpha=full size=usual kept=no" },
		{ "style=on page=on icons=off tab=on", "line=<Baker> alpha=half size=big kept=yes" },
		{ "style=on page=on icons=off tab=off", "line=<Baker> alpha=half size=big kept=no" },
		-- (Icons on: a Vendor's icon; with its kind off (the tab), none: the name alone.)
		{ "style=on page=on icons=on tab=on", "line=icon alpha=half size=big kept=yes" },
		{ "style=on page=on icons=on tab=off", "line=none alpha=- size=- kept=no" },
	},
})
