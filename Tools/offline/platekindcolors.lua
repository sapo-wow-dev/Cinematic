-- Default's colors per kind of unit, Fade, the name's color, rows' looks and plates'
-- change time (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/platekindcolors.lua < /dev/null
-- Nameplate Style's Colors part (Tools/style-studio/page-mock.html, 2026-11-25): on a
-- stand-in game (Forever, then retail) ns.PlateUnitKind sorts units (Not your kill first,
-- players by side, NPCs by reaction), ns.PlateKindColour gives each kind's color (the
-- game's: none; Class only means something for players; the theme's accent; My own),
-- ns.PlateNameColour (Same as the bar, My own), ns.PlateKindFade (None, Darker, Lighter,
-- Into a color), all off while Nameplate Style is off; a row's "Default's colors" takes
-- the kind's, else its reaction's; a row's Look counts whatever its Plate color
-- (rowLookFollowsV1 cleared the unused ones); plates change at CineMode's fade times.
-- PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212 431
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end
local function Near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.001 end

local function RunClient(client, toc)
	print("== " .. client .. " " .. toc)
	-- (Units: a GUID, a reaction, attackable, tapped, a class.)
	local units = {
		nameplate1 = { guid = "Player-1-0001", enemy = true, reaction = 2, class = "MAGE" },
		nameplate2 = { guid = "Player-1-0002", enemy = false, reaction = 5, class = "PALADIN" },
		nameplate3 = { guid = "Creature-0-1-2-3-4", enemy = true, reaction = 2 },
		nameplate4 = { guid = "Creature-0-1-2-3-5", enemy = false, reaction = 4 },
		nameplate5 = { guid = "Creature-0-1-2-3-6", enemy = false, reaction = 5 },
		nameplate6 = { guid = "Creature-0-1-2-3-7", enemy = true, reaction = 2, tapped = true },
	}
	local fight = false
	local ns = dofile("Tools/offline/load.lua")(client, toc, function()
		UnitGUID = function(unit) return units[unit] and units[unit].guid end
		UnitReaction = function(unit) return units[unit] and units[unit].reaction end
		UnitCanAttack = function(_, unit) return units[unit] and units[unit].enemy or false end
		UnitIsTapDenied = function(unit) return units[unit] and units[unit].tapped or false end
		UnitClass = function(unit)
			local u = units[unit]
			if u and u.class then return u.class, u.class end
		end
		InCombatLockdown = function() return fight end
		RAID_CLASS_COLORS = RAID_CLASS_COLORS or {}
		RAID_CLASS_COLORS.MAGE = { r = 0.25, g = 0.78, b = 0.92 }
		RAID_CLASS_COLORS.PALADIN = { r = 0.96, g = 0.55, b = 0.73 }
	end)
	local db = ns.db
	-- The audit kit's cells (Tools/audits/2026-11-25-nameplate-style-mock.md): what changed, run on
	-- the old code and the new. First, before anything the old code hasn't got, and only calls it had
	-- too (the change time read as each did).
	if client == "forever" then
		local Matrix = dofile("Tools/offline/matrix.lua")
		Matrix.Run({
			name = "platekindcolors",
			fixed = { client = client },
			dims = { { "case", { "rowlook", "fight", "nofight" } } },
			cell = function(c)
				if c.case == "rowlook" then
					db.targetArrowPlateColor, db.targetArrowLookFont = "-", "marcellus"
					local rowLook = ns.PlateRowLookFor and ns.PlateRowLookFor("target")
					db.targetArrowLookFont = nil
					return rowLook and rowLook.fontValue == "marcellus" and "counts" or "ignored"
				end
				db.fadeInTime, db.combatFadeInTime, db.plateStyleFadeTime = 1.2, 0.3, 0.6
				fight = c.case == "fight"
				local time = ns.PlateChangeTime and ns.PlateChangeTime() or db.plateStyleFadeTime
				fight = false
				return tostring(time)
			end,
			pins = { { "case=rowlook", "counts" }, { "case=fight", "0.3" }, { "case=nofight", "1.2" } },
		})
	end
	Check("ns.PlateUnitKind exists", type(ns.PlateUnitKind) == "function")
	if type(ns.PlateUnitKind) ~= "function" then return end

	-- Which kind each unit is.
	local want = { nameplate1 = "enemyPlayers", nameplate2 = "friendlyPlayers", nameplate3 = "hostileNpcs",
		nameplate4 = "neutralNpcs", nameplate5 = "friendlyNpcs", nameplate6 = "tapped" }
	for unit, kind in pairs(want) do
		Check("kind of " .. unit, ns.PlateUnitKind(unit) == kind, ns.PlateUnitKind(unit))
	end

	-- Every kind starts at the game's: nothing painted, nothing on. (The saved settings are
	-- one table across both runs: the first run's picks cleared.)
	for key in pairs(db) do
		if type(key) == "string" and (key:find("^plateKind") or key:find("^plateNameColor")) then db[key] = nil end
	end
	db.handlePlateStyle = true
	db.styleGeneral = true
	for unit in pairs(want) do
		Check("fresh: no color for " .. unit, ns.PlateKindColour(unit) == nil)
	end
	Check("fresh: Default's colors off", ns.PlateDefaultColoursOn() == false)
	Check("fresh: no Fade", ns.PlateKindFade("nameplate3") == nil)
	Check("fresh: name the game's", ns.PlateNameColour("nameplate3") == nil)

	-- Class: players get theirs.
	db.plateKindColor_enemyPlayers = "class"
	local r, g, b = ns.PlateKindColour("nameplate1")
	Check("Class on enemy players: the mage's", Near(r, 0.25) and Near(g, 0.78) and Near(b, 0.92), tostring(r))
	Check("Class on: Default's colors on", ns.PlateDefaultColoursOn() == true)
	Check("Class on enemy players: hostile NPCs untouched", ns.PlateKindColour("nameplate3") == nil)

	-- My own: friendly players only.
	db.plateKindColor_friendlyPlayers = "custom"
	db.plateKindColor_friendlyPlayersR, db.plateKindColor_friendlyPlayersG, db.plateKindColor_friendlyPlayersB = 0.2, 0.9, 0.5
	r, g, b = ns.PlateKindColour("nameplate2")
	Check("My own on friendly players", Near(r, 0.2) and Near(g, 0.9) and Near(b, 0.5), tostring(r))
	Check("My own on friendly players: friendly NPCs untouched", ns.PlateKindColour("nameplate5") == nil)

	-- Not your kill first: a tapped hostile NPC takes the tapped line, not hostile NPCs'.
	db.plateKindColor_hostileNpcs = "custom"
	db.plateKindColor_hostileNpcsR, db.plateKindColor_hostileNpcsG, db.plateKindColor_hostileNpcsB = 1, 0, 0
	db.plateKindColor_tapped = "custom"
	db.plateKindColor_tappedR, db.plateKindColor_tappedG, db.plateKindColor_tappedB = 0.5, 0.5, 0.5
	r = ns.PlateKindColour("nameplate6")
	Check("tapped: its own line", Near(r, 0.5), tostring(r))
	r = ns.PlateKindColour("nameplate3")
	Check("hostile NPC: its line", Near(r, 1), tostring(r))

	-- The name: Same as the bar, My own.
	db.plateNameColor = "same"
	r = ns.PlateNameColour("nameplate3")
	Check("name Same as the bar", Near(r, 1), tostring(r))
	db.plateNameColor = "custom"
	db.plateNameColorR, db.plateNameColorG, db.plateNameColorB = 0.1, 0.2, 0.3
	r, g, b = ns.PlateNameColour("nameplate3")
	Check("name My own", Near(r, 0.1) and Near(g, 0.2) and Near(b, 0.3), tostring(r))

	-- Fade.
	db.plateKindFade_hostileNpcs = "darker"
	local fade = ns.PlateKindFade("nameplate3")
	Check("Fade Darker", fade and fade.mode == "darker")
	db.plateKindFade_hostileNpcs = "custom"
	db.plateKindFade_hostileNpcsR, db.plateKindFade_hostileNpcsG, db.plateKindFade_hostileNpcsB = 0, 0, 1
	fade = ns.PlateKindFade("nameplate3")
	Check("Fade Into a color", fade and Near(fade[3], 1) and not fade.mode)
	Check("Fade: another kind none", ns.PlateKindFade("nameplate5") == nil)

	-- Nameplate Style off: none of it.
	db.handlePlateStyle = false
	Check("page off: Default's colors off", ns.PlateDefaultColoursOn() == false)
	Check("page off: no Fade", ns.PlateKindFade("nameplate3") == nil)
	db.handlePlateStyle = true

	-- A row's "Default's colors": the kind's, else its reaction's.
	db.targetArrowPlateColor = "default"
	r = ns.TargetPlateColour("nameplate3", "target")
	Check("row Default's colors: the kind's", Near(r, 1) and select(2, ns.TargetPlateColour("nameplate3", "target")) == 0)
	r, g = ns.TargetPlateColour("nameplate5", "target")
	Check("row Default's colors: a kind at the game's takes its reaction's (green)", Near(r, 0) and Near(g, 1), tostring(r))

	-- A row's look counts whatever its Plate color (was: only while Custom).
	db.targetArrowPlateColor = "-"
	db.targetArrowLookFont = "marcellus"
	local look = ns.PlateRowLookFor and ns.PlateRowLookFor("target")
	Check("row look counts with Plate color Don't change", look and look.fontValue == "marcellus",
		look and tostring(look.fontValue) or "no look")
	db.targetArrowLookFont = nil

	-- The migration: a row not Custom has its unused look cleared; a Custom one kept.
	db.rowLookFollowsV1 = nil
	db.markOrder = "target,focus"
	db.targetArrowPlateColor, db.targetArrowLookTexture = "gold", "glass"
	db.focusMarkPlateColor, db.focusMarkLookTexture = "custom", "soft"
	ns.RunMigrations()
	Check("migration: not Custom, cleared", db.targetArrowLookTexture == nil, tostring(db.targetArrowLookTexture))
	Check("migration: Custom, kept", db.focusMarkLookTexture == "soft", tostring(db.focusMarkLookTexture))

	-- Plates change at CineMode's fade times.
	db.fadeInTime, db.combatFadeInTime = 1.2, 0.3
	fight = false
	Check("change time out of fights: Fade in time", Near(ns.PlateChangeTime(), 1.2), tostring(ns.PlateChangeTime()))
	fight = true
	Check("change time in fights: Combat fade in time", Near(ns.PlateChangeTime(), 0.3), tostring(ns.PlateChangeTime()))
	fight = false
	Check("Change time's own setting gone", ns.DEFAULTS.plateStyleFadeTime == nil)

end

RunClient("forever", "CinematicDev.toc")
RunClient("retail", "CinematicDev.toc")
print(fails == 0 and "all passed" or (fails .. " failed"))
-- luacheck: pop
