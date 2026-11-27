-- Default's colors by Nameplate Style's Show in row, faded (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-26-plate-colors-show.md):
--   python -I Tools/offline/run.py Tools/offline/platecolorsshowmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/platecolorsshowmatrix.lua forever --base <ref>
-- A hostile NPC's plate (a stand-in plate, the real UpdatePlateParts, RefreshTargetArrow and
-- TintTarget) that no Smart row fits, Default's colors giving hostile NPCs a bar color (set) or
-- none (unset), Nameplate Style on or off, Smart's marks on or off, and the Show in row (on the
-- Nameplates page's Style tab): Always ticked, Out of combat ticked (the rest of the row: in
-- CineMode only), or nothing ticked. CineMode on or off, and either settled there or a quarter
-- of the way through the change (fade in and fade out times 1 s, 0.25 s after CineMode came
-- or went). Each cell: the bar's color ("-" the game's, "kind" Default's) and how far it's in.
-- The rule (2026-11-26): Default's colors show as the Show in row says, as Smart's marks do
-- (its Always; in CineMode the rest of it too), eased in and out at CineMode's fade times,
-- never a snap. (They painted at full wherever the marks' level was 0.)

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

-- (One plate, a hostile NPC's, no row fitting it: not your target, not under the mouse.)
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
-- (The pass, as Effects runs it: active in CineMode with the Nameplates page on.)
local function Tick(cine, elapsed)
	now = now + elapsed
	ns.UpdatePlateParts(cine, elapsed, cine)
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "plate-colors-show",
	fixed = { client = client },
	dims = {
		{ "default", { "set", "unset" } },
		{ "style", { "on", "off" } },
		{ "smart", { "on", "off" } },
		{ "show", { "always", "cinemode", "none" } },
		{ "cine", { "on", "off" } },
		{ "phase", { "settled", "fading" } },
	},
	cell = function(c)
		if not tints then error("TintTarget's tints not found") end
		db.styleGeneral, db.handlePlates = true, true
		db.handlePlateStyle = c.style == "on"
		db.plateMarks = c.smart == "on"
		db.markOrder = "target"
		db.fadeInTime, db.fadeOutTime, db.combatFadeInTime = 1, 1, 1
		db.plateKindColor_hostileNpcs = c.default == "set" and "custom" or "game"
		db.plateKindColor_hostileNpcsR, db.plateKindColor_hostileNpcsG, db.plateKindColor_hostileNpcsB = KIND[1], KIND[2], KIND[3]
		db.plateNameColor = "game"
		db.targetArrowAlways = c.show == "always"
		db.quietShow["platemark:show"] = c.show == "cinemode" or nil
		local cine = c.cine == "on"
		-- (Settled in the other state first for a change, else in this one.)
		local before = c.phase == "fading" and not cine or (c.phase ~= "fading" and cine)
		for _ = 1, 40 do Tick(before, 0.1) end
		now = now + 1 -- (the rows read anew)
		if c.phase == "fading" then
			Tick(cine, 0.25)
		else
			Tick(cine, 0.1)
		end
		RefreshTargetArrow(plate)
		return "bar=" .. Bar(tints[unitFrame])
	end,
	pins = {
		-- (Nothing set, or Nameplate Style off: the game's.)
		{ "", "bar=-" },
		-- (Always: in and out of CineMode, at full.)
		{ "default=set style=on show=always", "bar=kind@1.00" },
		-- (The rest of the row, in CineMode: in, eased in as it comes, out as it goes.)
		{ "default=set style=on show=cinemode cine=on phase=settled", "bar=kind@1.00" },
		{ "default=set style=on show=cinemode cine=on phase=fading", "bar=kind@0.25" },
		{ "default=set style=on show=cinemode cine=off phase=fading", "bar=kind@0.75" },
		-- (Out of CineMode with no Always, or nothing ticked: the game's.)
		{ "default=set style=on show=cinemode cine=off phase=settled", "bar=-" },
		{ "default=set style=on show=none", "bar=-" },
	},
})
