-- Default's Fade by kind of unit on the plates' bars and their previews (the audit kit's
-- matrix, Tools/offline/matrix.lua; fix card Tools/audits/2026-11-26-plate-kind-fade-preview.md):
--   python -I Tools/offline/run.py Tools/offline/platekindfadematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/platekindfadematrix.lua forever --base <ref>
-- PlateHealthStyle.lua's StylePlate and Gradient: with no row Fade of its own, a bar fades as
-- Default's Fade for its kind of unit (Nameplate Style's Colors, plateKindFade_<kind>). The
-- states: where (a live plate with its unit; Nameplate Style's preview, its sample picked and
-- Tapped ticked for Not your kill; General's preview, a hostile NPC: both previews are the
-- game's plate, Forever only, retail draws its own), the kind shown (each of the six, and
-- "you": the Player sample), which kinds have a Fade (none; only hostile NPCs'; only the
-- kind shown; every kind its own), the row's Fade (none: Default's; off; its own). The client.
-- Each cell: the Fade the bar takes (the kind whose Fade it is, row: the row's own) or flat.
-- The rule (2026-11-26): a preview fades as a plate of its sample's kind does.

local client = arg and arg[1] or "forever"
local parts = dofile("Tools/offline/gameplate_parts.lua")(function() end)
-- luacheck: push ignore 111 112 113 121 122 212
local UNITS = {
	hostileNpcs = { guid = "Creature-0-1-2-3-4", enemy = true, reaction = 2 },
	neutralNpcs = { guid = "Creature-0-1-2-3-5", enemy = false, reaction = 4 },
	friendlyNpcs = { guid = "Creature-0-1-2-3-6", enemy = false, reaction = 5 },
	enemyPlayers = { guid = "Player-1-0001", enemy = true, reaction = 2, class = "MAGE" },
	friendlyPlayers = { guid = "Player-1-0002", enemy = false, reaction = 5, class = "PALADIN" },
	tapped = { guid = "Creature-0-1-2-3-7", enemy = true, reaction = 2, tapped = true },
}
local unitNow
local function U(unit) return unit == "nameplate1" and unitNow and UNITS[unitNow] or nil end
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
	issecretvalue = function() return false end
	parts.Install()
	CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
	UnitGUID = function(unit) return U(unit) and U(unit).guid end
	UnitReaction = function(unit) return U(unit) and U(unit).reaction end
	UnitCanAttack = function(_, unit) return U(unit) and U(unit).enemy or false end
	UnitIsTapDenied = function(unit) return U(unit) and U(unit).tapped or false end
end)
-- luacheck: pop
local db = ns.db
for _, key in ipairs({ "handlePlateStyle" }) do
	local switch = key
	while switch do
		db[switch] = true
		switch = ns.PageSwitchOf and ns.PageSwitchOf(switch)
	end
end
db.styleGeneral = true

local KINDS = { "hostileNpcs", "neutralNpcs", "friendlyNpcs", "enemyPlayers", "friendlyPlayers", "tapped" }
-- (Each kind's Fade "Into a color", its own red: which kind's it is, read off the bar.)
local MARK = { hostileNpcs = 0.1, neutralNpcs = 0.2, friendlyNpcs = 0.3, enemyPlayers = 0.4,
	friendlyPlayers = 0.5, tapped = 0.6 }
local ROW = 0.9
-- (Nameplate Style's samples, PlateRowLook.lua's SAMPLES: a kind's index; Not your kill:
-- the hostile one with Tapped ticked; you: the Player sample.)
local SAMPLE = { hostileNpcs = 1, neutralNpcs = 2, friendlyNpcs = 3, enemyPlayers = 4, friendlyPlayers = 5,
	tapped = 1, you = 6 }

-- (The row's look: a stand-in for Smart Style's Default row's Fade.)
local rowLook = ns.PlateRowLookFor
local rowNow
ns.PlateRowLookFor = function(kind, over)
	if rowNow == "off" then return { gradient = false } end
	if rowNow == "on" then return { gradient = { ROW, ROW, ROW } } end
	return rowLook(kind, over)
end

local function Watch(bar)
	local fill = bar:GetStatusBarTexture()
	local got = { "flat" }
	fill.SetGradient = function(_, _, _, to)
		local r = to and to.r
		local name = r and (math.abs(r - ROW) < 0.001 and "row") or nil
		for kind, mark in pairs(MARK) do if r and math.abs(r - mark) < 0.001 then name = kind end end
		got[1] = name or ("other " .. tostring(r))
	end
	-- (A color set on the fill itself: flat again, as PlateHealthStyle's Gradient leaves it.)
	local vertex = fill.SetVertexColor
	fill.SetVertexColor = function(self, ...)
		got[1] = "flat"
		if vertex then return vertex(self, ...) end
	end
	return got
end

-- What's right, cell by cell.
local SHOWN = { "hostileNpcs", "neutralNpcs", "friendlyNpcs", "enemyPlayers", "friendlyPlayers", "tapped", "you" }
local pins = { { "", "flat" } }
-- (No row Fade: Default's for the kind shown, on a live plate and a preview alike; only hostile
-- NPCs' set: theirs alone, every other kind flat.)
for _, kind in ipairs(SHOWN) do
	local shown = kind == "you" and "friendlyPlayers" or kind
	pins[#pins + 1] = { "row=none fades=all kind=" .. kind, shown }
	pins[#pins + 1] = { "row=none fades=own kind=" .. kind, shown }
end
pins[#pins + 1] = { "row=none fades=hostile kind=hostileNpcs", "hostileNpcs" }
-- (A row's own Fade wins over Default's; its off keeps the bar flat.)
pins[#pins + 1] = { "row=on", "row" }
-- (Cells that don't exist: your own plate isn't styled; General's preview is a hostile NPC.)
pins[#pins + 1] = { "where=live kind=you", "n/a" }
for i = 2, #SHOWN do pins[#pins + 1] = { "where=general kind=" .. SHOWN[i], "n/a" } end

local where = client == "retail" and { "live" } or { "live", "preview", "general" }
local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "plate-kind-fade-" .. client,
	fixed = { client = client },
	dims = {
		{ "where", where },
		{ "kind", { "hostileNpcs", "neutralNpcs", "friendlyNpcs", "enemyPlayers", "friendlyPlayers", "tapped", "you" } },
		{ "fades", { "none", "hostile", "own", "all" } },
		{ "row", { "none", "off", "on" } },
		{ "drawn", { "first", "again" } },
	},
	cell = function(c)
		if c.where == "live" and c.kind == "you" then return "n/a" end -- (your own plate isn't styled)
		if c.where == "general" and c.kind ~= "hostileNpcs" then return "n/a" end -- (a hostile NPC only)
		-- (The settings and the unit or sample: kind, fades, row.)
		local function Set(kind, fades, row)
			local shown = kind == "you" and "friendlyPlayers" or kind
			for _, each in ipairs(KINDS) do
				local on = fades == "all" or (fades == "hostile" and each == "hostileNpcs") or (fades == "own" and each == shown)
				local key = "plateKindFade_" .. each
				db[key] = on and "custom" or "none"
				db[key .. "R"], db[key .. "G"], db[key .. "B"] = MARK[each], MARK[each], MARK[each]
			end
			rowNow = row
			unitNow = c.where == "live" and kind or nil
		end
		-- (A fresh plate or preview each cell, drawn as the code draws it.)
		local Draw, bar
		if c.where == "live" then
			local copy = CreateFrame("Frame", nil, UIParent)
			parts.Parts(copy)
			local plate = CreateFrame("Frame", nil, UIParent)
			plate.UnitFrame, copy.unit = copy, "nameplate1"
			bar = copy.HealthBarsContainer.healthBar
			Draw = function()
				bar:SetStatusBarColor(0.8, 0.1, 0.1)
				-- (As PlateRowLook.lua's row pass gives a plate its row's look, then the plates' pass.)
				ns.SetPlateBarOverride(plate, ns.PlateRowLookFor("others"))
				local real = C_NamePlate.GetNamePlates
				C_NamePlate.GetNamePlates = function() return { plate } end -- luacheck: ignore 122
				ns.RefreshPlateHealthStyle()
				C_NamePlate.GetNamePlates = real -- luacheck: ignore 122
			end
		else
			local holder = c.where == "preview" and ns.MakePlateRowLookPreview(UIParent, 480, "others")
				or ns.MakeGeneralPlatePreview(UIParent, 300)
			local game = holder.gamePlate
			if not game then
				-- (General's: its game plate, the holder's child that is one.)
				for _, child in ipairs({ holder:GetChildren() }) do
					if child.gamePlate then game = child end
				end
			end
			if not (game and ns.GamePlateReady(game)) then return "no game plate" end
			bar = game.gameCopy.HealthBarsContainer.healthBar
			Draw = function(kind)
				if c.where == "preview" then
					holder.sample = SAMPLE[kind]
					holder.states = { tapped = kind == "tapped" or nil }
				end
				holder:Refresh()
			end
		end
		-- (again: shown before as a hostile NPC with every kind's Fade (a plate reused, a
		-- preview's sample switched), then this cell's.)
		if c.drawn == "again" then
			Set("hostileNpcs", "all", "none")
			Draw("hostileNpcs")
		end
		Set(c.kind, c.fades, c.row)
		local got = Watch(bar)
		Draw(c.kind)
		return got[1]
	end,
	pins = pins,
})
