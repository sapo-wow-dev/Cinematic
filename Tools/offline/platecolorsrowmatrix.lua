-- Default's colors under a Smart row that fits (the audit kit's matrix, Tools/offline/matrix.lua;
-- fix card Tools/audits/2026-11-26-plate-colors-row.md):
--   python -I Tools/offline/run.py Tools/offline/platecolorsrowmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/platecolorsrowmatrix.lua forever --base <ref>
-- A hostile NPC's plate (a stand-in plate, the real RefreshTargetArrow and TintTarget), Smart's
-- marks and Default's colors both shown (the Show in row's Always), and the row that fits it:
-- none; your target's row with Plate color Don't change, The game's, Same as its mark with no
-- part ticked, My own with the bar, the name or every part ticked; or the Mouseover row as it
-- comes (Same as its mark, nothing ticked). Default's colors: none set, the hostile NPCs' bar
-- color, the name's color, or both. Each cell: what colors each part (name, bar, border):
-- "-" the game's, "row" the row's, "kind" Default's kind color, "name" Default's name color.
-- The rule (2026-11-26): a row takes over only the parts it colors, and The game's the whole
-- plate; every other part keeps Default's colors. (PlateLook's decided: any row with a Plate
-- color, coloring nothing, took Default's away.)

local client = arg and arg[1] or "forever"
local now = 1000
local mouse, isTarget = false, false
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

-- (One plate, a hostile NPC's: your target or under the mouse as the cell says.)
local plate = CreateFrame("Frame")
local unitFrame = CreateFrame("Button", nil, plate)
plate.UnitFrame, plate.namePlateUnitToken = unitFrame, UNIT
unitFrame.unit = UNIT
unitFrame.healthBar = CreateFrame("StatusBar", nil, unitFrame)
unitFrame.name = unitFrame:CreateFontString()
C_NamePlate.GetNamePlates = function() return { plate } end -- luacheck: ignore 122
C_NamePlate.GetNamePlateForUnit = function(unit) -- luacheck: ignore 122
	if unit == UNIT or (unit == "target" and isTarget) or (unit == "mouseover" and mouse) then return plate end
end

local KIND, NAME, ROW = { 1, 0, 0 }, { 0, 0, 1 }, { 0.1, 0.2, 0.3 }
local function Same(c, want)
	return math.abs(c[1] - want[1]) < 0.001 and math.abs(c[2] - want[2]) < 0.001 and math.abs(c[3] - want[3]) < 0.001
end
-- (A part's color as the painter blends it: its own level, else the plate's.)
local function Part(tint, part)
	local colour = tint and tint[part]
	if not (colour and colour[1]) then return "-" end
	local level = colour.level or tint.level or 0
	if level <= 0 then return "-" end
	local word = Same(colour, KIND) and "kind" or Same(colour, NAME) and "name" or "row"
	return math.abs(level - 1) < 0.001 and word or ("%s@%.2f"):format(word, level)
end

local ROWS = { "none", "pass", "game", "same-none", "mouseover", "custom-bar", "custom-name", "custom-all" }
local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "plate-colors-row",
	fixed = { client = client },
	dims = {
		{ "row", ROWS },
		{ "default", { "unset", "bar", "name", "both" } },
	},
	cell = function(c)
		if not tints then error("TintTarget's tints not found") end
		db.styleGeneral, db.handlePlateStyle, db.plateMarks, db.handlePlates = true, true, true, true
		db.targetArrowAlways = true -- (the Show in row's Always: marks and colors shown, at full)
		db.markOrder = "target,mouseover"
		-- Default's colors.
		db.plateKindColor_hostileNpcs = (c.default == "bar" or c.default == "both") and "custom" or "game"
		db.plateKindColor_hostileNpcsR, db.plateKindColor_hostileNpcsG, db.plateKindColor_hostileNpcsB = KIND[1], KIND[2], KIND[3]
		db.plateNameColor = (c.default == "name" or c.default == "both") and "custom" or "game"
		db.plateNameColorR, db.plateNameColorG, db.plateNameColorB = NAME[1], NAME[2], NAME[3]
		-- The row that fits.
		isTarget = c.row ~= "none" and c.row ~= "mouseover"
		mouse = c.row == "mouseover"
		local how = ({ pass = "-", game = "game", ["same-none"] = "same" })[c.row] or "custom"
		db.targetArrowPlateColor = how
		db.targetArrowPlateR, db.targetArrowPlateG, db.targetArrowPlateB = ROW[1], ROW[2], ROW[3]
		db.targetColorBar = c.row == "custom-bar" or c.row == "custom-all"
		db.targetColorName = c.row == "custom-name" or c.row == "custom-all"
		db.targetColorBorder = c.row == "custom-all"
		for _ = 1, 40 do
			now = now + 0.1
			ns.UpdatePlateParts(true, 0.1, true)
		end
		now = now + 1
		RefreshTargetArrow(plate)
		local tint = tints[unitFrame]
		return ("name=%s bar=%s border=%s"):format(Part(tint, "name"), Part(tint, "bar"), Part(tint, "border"))
	end,
	pins = {
		-- (No row with a color of its own: Default's colors, whichever are set.)
		{ "default=unset", "name=- bar=- border=-" },
		{ "default=bar", "name=- bar=kind border=-" },
		{ "default=name", "name=name bar=- border=-" },
		{ "default=both", "name=name bar=kind border=-" },
		-- (The game's: the whole plate the game's.)
		{ "row=game", "name=- bar=- border=-" },
		-- (A row coloring some parts: those its, the rest Default's.)
		{ "row=custom-bar default=unset", "name=- bar=row border=-" },
		{ "row=custom-bar default=bar", "name=- bar=row border=-" },
		{ "row=custom-bar default=name", "name=name bar=row border=-" },
		{ "row=custom-bar default=both", "name=name bar=row border=-" },
		{ "row=custom-name default=unset", "name=row bar=- border=-" },
		{ "row=custom-name default=bar", "name=row bar=kind border=-" },
		{ "row=custom-name default=name", "name=row bar=- border=-" },
		{ "row=custom-name default=both", "name=row bar=kind border=-" },
		{ "row=custom-all", "name=row bar=row border=row" },
	},
})
