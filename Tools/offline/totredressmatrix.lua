-- The target of target's frame as the game sets its bars every frame, every
-- state (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-23-tot-redress.md):
--   python -I Tools/offline/run.py Tools/offline/totredressmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/totredressmatrix.lua --base <ref>
-- The game's ToT frame sets its power bar's fill and color again every frame
-- it shows (TargetOfTargetMixin's OnUpdate). Unit Frames off, on with nothing
-- of ours on the bars (the game look), on with our health color, or a theme;
-- the game setting the power bar's fill and white again, a green mana color,
-- or the health bar's color; the same unit or a new one (a mage, class name
-- color). Each cell: what's on the frame right after the game's first set
-- (now), a moment later (after), and how often all of the frame was dressed
-- through a second of it (every frame or a few times).

local F = dofile("Tools/style-lab/frames.lua")
local client = arg and arg[1] or "forever"
local now = 100
local timers = {}
local who = "npc"

local function ToTFrame()
	local frame = CreateFrame("Button", "TargetFrameToT", UIParent)
	frame:SetSize(120, 50)
	frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 400, -80)
	frame:Show()
	frame.unit = "targettarget"
	frame.PlayerFrameContainer, frame.TargetFrameContainer, frame.TargetFrameContent = false, false, false
	frame.FrameTexture, frame.HealthBar, frame.ManaBar, frame.Name, frame.Portrait = false, false, false, false, false
	frame.portrait = frame:CreateTexture(nil, "BACKGROUND")
	frame.portrait:SetSize(36, 36)
	frame.portrait:SetPoint("TOPLEFT", 4, -4)
	frame.healthbar = CreateFrame("StatusBar", nil, frame)
	frame.healthbar:SetSize(70, 10)
	frame.healthbar:SetPoint("TOPLEFT", 44, -14)
	frame.healthbar:SetStatusBarTexture("UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Health")
	frame.healthbar:SetStatusBarColor(0, 1, 0)
	frame.manabar = CreateFrame("StatusBar", nil, frame)
	frame.manabar:SetSize(70, 6)
	frame.manabar:SetPoint("TOP", frame.healthbar, "BOTTOM", 0, -1)
	frame.manabar:SetStatusBarTexture("UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Mana")
	frame.manabar:SetStatusBarColor(1, 1, 1)
	frame.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.name:SetPoint("BOTTOMLEFT", frame.healthbar, "TOPLEFT", 0, 2)
	frame.name:SetText("Kobold")
	return frame
end

-- luacheck: push ignore 111 112 113 121 122 212
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function(w)
	F.Install(w)
	rawset(_G, "CreateFontFamily", false)
	ToTFrame()
end)
GetTime = function() return now end
C_Timer.After = function(wait, fn) timers[#timers + 1] = { at = now + wait, fn = fn } end
UnitExists = function(unit) return unit == "player" or unit == "target" or unit == "targettarget" end
UnitIsPlayer = function(unit) return unit == "player" or (unit == "targettarget" and who == "mage") end
UnitClass = function(unit)
	if unit == "targettarget" and who == "mage" then return "Mage", "MAGE" end
	return "Warrior", "WARRIOR"
end
UnitReaction = function() return 2 end
UnitName = function(unit)
	if unit == "targettarget" then return who == "mage" and "Jaina" or "Kobold" end
	return "Sapo"
end
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
FACTION_BAR_COLORS = { [2] = { r = 1, g = 0.2, b = 0 } }
PowerBarColor = { MANA = { r = 0, g = 0, b = 1 } } -- (the stand-in's own answers anything)
UnitPowerType = function() return 0, "MANA" end
InCombatLockdown = function() return false end
-- luacheck: pop
local function RunTimers()
	for _ = 1, 20 do
		local due, left = {}, {}
		for _, t in ipairs(timers) do
			if t.at <= now then due[#due + 1] = t else left[#left + 1] = t end
		end
		timers = left
		if #due == 0 then return end
		for _, t in ipairs(due) do t.fn() end
	end
end

-- (All of the frame dressed: counted where Dress hands it on, the same in
-- the old code and the new: the hooks' Dress, its DressFrame.)
local function Upvalue(fn, name)
	for i = 1, 200 do
		local n, v = debug.getupvalue(fn, i)
		if not n then return nil end
		if n == name then return v, i end
	end
end
local DressFrame = Upvalue(ns.RefreshUnitStyle, "DressFrame")
local Dress = DressFrame and Upvalue(DressFrame, "Dress")
-- (Dress timed by the profiler (ns.Profiled, 2026-11-23): the wrapper's "fn" is
-- the Dress that calls DressFrame. Reach only: the same function counted.)
if Dress and not Upvalue(Dress, "DressFrame") and Upvalue(Dress, "fn") then Dress = Upvalue(Dress, "fn") end
local dressed = 0
if Dress then
	local _, index = Upvalue(Dress, "DressFrame")
	debug.setupvalue(Dress, index, function(...) dressed = dressed + 1 return DressFrame(...) end)
end

local db = ns.db
local tot = _G.TargetFrameToT
local power, health, name = tot.manabar, tot.healthbar, tot.name

local function Color(r, g, b) return ("%.2f,%.2f,%.2f"):format(r or -1, g or -1, b or -1) end
local function Look()
	local fill = power:GetStatusBarTexture()
	local art = fill and (fill.GetAtlas and fill:GetAtlas() or fill:GetTexture())
	local ours = art and not tostring(art):find("TargetofTarget") and "ours" or "game"
	return ("P=%s:%s H=%s N=%s"):format(ours, Color(power:GetStatusBarColor()), Color(health:GetStatusBarColor()),
		Color(name:GetTextColor()))
end

local MANA_FILL = "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Mana"
local function GameSet(set)
	if set == "health" then
		health:SetStatusBarColor(0, 1, 0)
	else
		power:SetStatusBarTexture(MANA_FILL)
		if set == "green" then power:SetStatusBarColor(0, 1, 0) else power:SetStatusBarColor(1, 1, 1) end
	end
end

local function Reset()
	db.ufStyle = false
	ns.RefreshUnitStyle()
	timers = {}
	now = now + 10
	who = "npc"
	health:SetStatusBarTexture("UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Health")
	health:SetStatusBarColor(0, 1, 0)
	power:SetStatusBarTexture(MANA_FILL)
	power:SetStatusBarColor(1, 1, 1)
	name:SetTextColor(1, 0.82, 0)
	-- (What those sets started, run out before the cell's own.)
	now = now + 3
	RunTimers()
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "tot-redress",
	fixed = { client = client },
	dims = {
		{ "look", { "off", "plain", "colored", "theme" } },
		{ "set", { "power", "green", "health" } },
		{ "unit", { "same", "new" } },
	},
	cell = function(c)
		Reset()
		if c.look ~= "off" then
			-- (The theme first: "game" takes the Unit Frames switch off with it.)
			ns.ApplyStyleTheme(c.look == "theme" and "forge" or "game", true)
			db.ufStyle, db.styleGeneral = true, true
			local up, steps = ns.PageSwitchOf and ns.PageSwitchOf("ufStyle"), 0
			while up and steps < 10 do db[up], up, steps = true, ns.PageSwitchOf(up), steps + 1 end
			db.ufNameColor = "class"
			db.ufHealthColor = c.look == "colored" and "custom" or (c.look == "plain" and "game" or db.ufHealthColor)
			if c.look == "colored" then db.ufHealthR, db.ufHealthG, db.ufHealthB = 0.8, 0.1, 0.1 end
		end
		ns.RefreshUnitStyle()
		now = now + 3
		RunTimers()
		if c.unit == "new" then who = "mage" end
		dressed = 0
		GameSet(c.set)
		local first = Look()
		-- (A second of it: the game sets the bars again each frame.)
		for _ = 1, 60 do
			now = now + 1 / 60
			RunTimers()
			GameSet(c.set == "health" and "health" or "power")
		end
		now = now + 0.3
		RunTimers()
		local out = ("now %s | after %s | dressed=%s"):format(first, Look(), dressed >= 30 and "every-frame"
			or dressed > 0 and "few" or "none")
		db.ufStyle = false
		ns.RefreshUnitStyle()
		return out
	end,
	pins = (function()
		-- (What's right, part by part. The power bar: the game's look but a
		-- green mana color tinted back to mana's at once (then the game's white
		-- again); a theme's fill and color. Health: the game's green, our red,
		-- or the theme's. The name: the game's gold off, else by class or
		-- reaction (a new unit's at once). All of the frame dressed on every set
		-- only where a bar carries ours (the game's set covers it); a few times
		-- where nothing of ours is on the bar set.)
		local P = {
			off = { power = "game:1.00,1.00,1.00", green = "game:0.00,1.00,0.00", health = "game:1.00,1.00,1.00" },
			plain = { power = "game:1.00,1.00,1.00", green = "game:0.00,0.55,1.00", health = "game:1.00,1.00,1.00" },
			theme = { power = "ours:0.22,0.45,0.74", green = "ours:0.22,0.45,0.74", health = "ours:0.22,0.45,0.74" },
		}
		P.colored = P.plain
		local H = { off = "0.00,1.00,0.00", plain = "0.00,1.00,0.00", colored = "0.80,0.10,0.10", theme = "0.85,0.27,0.08" }
		local N = { same = "1.00,0.20,0.00", new = "0.25,0.78,0.92" }
		local list = {}
		for _, look in ipairs({ "off", "plain", "colored", "theme" }) do
			for _, set in ipairs({ "power", "green", "health" }) do
				for _, unit in ipairs({ "same", "new" }) do
					local name = look == "off" and "1.00,0.82,0.00" or N[unit]
					local after = set == "green" and (look == "theme" and P.theme.power or "game:1.00,1.00,1.00") or P[look][set]
					local every = look == "theme" or (look == "colored" and set == "health")
					list[#list + 1] = { ("look=%s set=%s unit=%s"):format(look, set, unit),
						("now P=%s H=%s N=%s | after P=%s H=%s N=%s | dressed=%s"):format(P[look][set], H[look], name, after,
							H[look], name, every and "every-frame" or "few") }
				end
			end
		end
		return list
	end)(),
})
