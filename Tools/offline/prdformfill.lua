-- The Personal Resource Display's power fill put back after a form change
-- (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/prdformfill.lua [forever|retail] < /dev/null
-- Audit 2026-11-22: the game's fill was kept only as first seen, so a druid
-- who picked a PRD texture in caster form (mana), shifted to Bear, then set
-- the texture back to the game's got the mana fill on the rage bar. And with
-- just a color of ours, a new fill after a shift wasn't greyed under it. On
-- stand-in bars that keep their fill: ours over the game's new one, the
-- game's newest back, and greyed under our color. PASS or FAIL per check.

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local client = arg and arg[1] or "forever"
local MANA, RAGE = "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana", "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Rage"
local power
local function Install(wow)
	-- luacheck: push ignore 111 112 113 121 122
	issecretvalue = function() return false end
	Enum = { PowerType = { Mana = 0 } }
	UnitPowerType = function() return 0 end
	hooksecurefunc = function(a, b, c)
		local tbl, name, fn = a, b, c
		if type(a) == "string" then tbl, name, fn = _G, a, b end
		local orig = tbl[name]
		rawset(tbl, name, function(...)
			local r = { orig(...) }
			fn(...)
			return unpack(r)
		end)
	end
	-- A status bar keeping its fill (a texture's file or atlas) and its grey.
	local function Bar(start)
		local bar = wow.CreateFrame("StatusBar")
		local fill = { value = start, desaturated = false }
		fill.GetTexture = function() return fill.value end
		fill.GetAtlas = function() return fill.value end
		fill.SetDesaturated = function(_, on) fill.desaturated = on and true or false end
		rawset(bar, "SetStatusBarTexture", function(_, value) fill.value, fill.desaturated = value, false end)
		rawset(bar, "GetStatusBarTexture", function() return fill end)
		bar.fill = fill
		return bar
	end
	power = Bar(MANA)
	local holder = wow.CreateFrame("Frame")
	holder.healthBar = Bar("health")
	local root = wow.CreateFrame("Frame", "PersonalResourceDisplayFrame")
	root.HealthBarsContainer, root.PowerBar = holder, power
	-- luacheck: pop
end
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
db.styleGeneral, db.prdStyle = true, true

-- 1: a texture of ours picked in caster form.
db.prdTexture = "smooth"
ns.RefreshPersonalStyle()
local ours = power.fill.value
Check(client .. ": 1 our fill on", ours ~= MANA, tostring(ours))
-- 2: into Bear: the game's rage fill, ours again over it.
power:SetStatusBarTexture(RAGE)
Check(client .. ": 2 ours kept over the game's new fill", power.fill.value == ours, tostring(power.fill.value))
-- 3: the texture back to the game's: its newest, rage, not the mana first seen.
db.prdTexture = "game"
ns.RefreshPersonalStyle()
Check(client .. ": 3 the game's rage fill back", power.fill.value == RAGE, tostring(power.fill.value))
-- 4: just a mana color of ours (a theme's): a new fill after a shift greyed under it.
db.prdManaColor = "custom"
db.prdManaR, db.prdManaG, db.prdManaB = 0.2, 0.4, 0.9
ns.RefreshPersonalStyle()
power:SetStatusBarTexture(MANA)
Check(client .. ": 4 the new fill greyed under our color", power.fill.desaturated == true,
	tostring(power.fill.desaturated))

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
