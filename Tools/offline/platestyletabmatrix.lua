-- The Nameplates page's Style tab switch over Smart's marks and Default's colors (the audit
-- kit's matrix, Tools/offline/matrix.lua; fix card Tools/audits/2026-11-26-plate-style-tab.md):
--   python -I Tools/offline/run.py Tools/offline/platestyletabmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/platestyletabmatrix.lua forever --base <ref>
-- The Style tab (tabOn:Nameplates:PlateStyleShow, where Nameplate Style's Show in row is) on or
-- off; the Nameplates page on or off; Nameplate Style on or off; Smart's marks on or off;
-- Default's colors giving hostile NPCs a bar color (set) or none (unset); and the Show in row
-- showing them: Always out of CineMode, Always in it, or Out of combat ticked in CineMode (the
-- states where it's off are Tools/offline/platecolorsshowmatrix.lua's). A hostile NPC's plate
-- (a stand-in, the real UpdatePlateParts, RefreshTargetArrow and TintTarget) that no row fits,
-- settled. Each cell: Smart's level (its marks, and every row's look and colors go by it) and
-- the bar's color ("-" the game's, "kind" Default's).
-- The rule (2026-11-26): a tab is a container: the Style tab off, Smart's marks and Default's
-- colors are off, whatever its Show in row says. (Its switch was read nowhere.)

local client = arg and arg[1] or "forever"
local now = 1000
local UNIT = "nameplate3"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
	-- luacheck: push ignore 111 112 113 121 122
	GetTime = function() return now end
	InCombatLockdown = function() return false end
	UnitAffectingCombat = function() return false end
	UnitGUID = function(unit) if unit == UNIT then return "Creature-0-1-2-3-4" end end
	UnitReaction = function(unit) if unit == UNIT then return 2 end end
	UnitCanAttack = function() return true end
	UnitIsTapDenied = function() return false end
	-- luacheck: pop
end)
local db = ns.db

local function Up(fn, name)
	for i = 1, 255 do
		local n, v = debug.getupvalue(fn, i)
		if not n then return nil end
		if n == name then return v end
	end
end
local RefreshTargetArrow = Up(ns.RefreshPlateLook, "RefreshTargetArrow")
local tints = RefreshTargetArrow and Up(Up(RefreshTargetArrow, "TintTarget"), "tints")
local levels = Up(ns.UpdatePlateParts, "levels")

local plate = CreateFrame("Frame")
local unitFrame = CreateFrame("Button", nil, plate)
plate.UnitFrame, plate.namePlateUnitToken = unitFrame, UNIT
unitFrame.unit = UNIT
unitFrame.healthBar = CreateFrame("StatusBar", nil, unitFrame)
unitFrame.name = unitFrame:CreateFontString()
C_NamePlate.GetNamePlates = function() return { plate } end -- luacheck: ignore 122
C_NamePlate.GetNamePlateForUnit = function(unit) if unit == UNIT then return plate end end -- luacheck: ignore 122

local KIND = { 1, 0, 0 }
local function Bar(tint)
	local colour = tint and tint.bar
	if not (colour and colour[1]) then return "-" end
	local level = colour.level or tint.level or 0
	if level <= 0 then return "-" end
	return ("kind@%.2f"):format(level)
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "plate-style-tab",
	fixed = { client = client },
	dims = {
		{ "tab", { "on", "off" } },
		{ "page", { "on", "off" } },
		{ "style", { "on", "off" } },
		{ "smart", { "on", "off" } },
		{ "default", { "set", "unset" } },
		{ "shown", { "always-out", "always-cine", "row-cine" } },
	},
	cell = function(c)
		if not (tints and levels) then error("PlateParts' tables not found") end
		db["tabOn:Nameplates:PlateStyleShow"] = c.tab == "on"
		db.styleGeneral = true
		db.handlePlates = c.page == "on"
		db.handlePlateStyle = c.style == "on"
		db.plateMarks = c.smart == "on"
		db.markOrder = "target"
		db.fadeInTime, db.fadeOutTime, db.combatFadeInTime = 1, 1, 1
		db.plateKindColor_hostileNpcs = c.default == "set" and "custom" or "game"
		db.plateKindColor_hostileNpcsR, db.plateKindColor_hostileNpcsG, db.plateKindColor_hostileNpcsB = KIND[1], KIND[2], KIND[3]
		db.plateNameColor = "game"
		db.targetArrowAlways = c.shown ~= "row-cine"
		db.quietShow["platemark:show"] = c.shown == "row-cine" or nil
		local cine = c.shown ~= "always-out"
		local active = cine and c.page == "on"
		for _ = 1, 40 do
			now = now + 0.1
			ns.UpdatePlateParts(active, 0.1, cine)
		end
		now = now + 1
		ns.UpdatePlateParts(active, 0.1, cine)
		RefreshTargetArrow(plate)
		return ("smart=%.2f bar=%s"):format(levels.TargetArrow or 0, Bar(tints[unitFrame]))
	end,
	pins = {
		-- (The tab on: Smart by its own switch, Default's colors when set, both under Nameplate Style.)
		{ "tab=on", "smart=0.00 bar=-" },
		{ "tab=on style=on smart=on", "smart=1.00 bar=-" },
		{ "tab=on style=on default=set", "smart=0.00 bar=kind@1.00" },
		{ "tab=on style=on smart=on default=set", "smart=1.00 bar=kind@1.00" },
		-- (The tab off: neither, whatever the rest says.)
		{ "tab=off", "smart=0.00 bar=-" },
	},
})
