-- The Personal Resource Display's power bar around a form change, every state
-- (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-22-style-prd-form-fill.md):
--   python -I Tools/offline/run.py Tools/offline/prdfillmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/prdfillmatrix.lua --base <ref>
-- The Style switch (General) and the Personal Resource Display page on or
-- off, a texture of ours or the game's, the mana color ours or the game's, the
-- power you start in (mana: caster, rage: Bear) and a form change or none,
-- then the page left as it is, its texture set back to the game's, or the
-- page switched off. Each cell: the power bar's fill (ours, or the game's
-- mana or rage art), whether it's greyed, and its color.
-- The rule: while the look is on, ours on the bar (our texture; our mana color
-- while the power is mana, greyed under it on the game's art); else the game's
-- art and color for the power you have NOW, never the one you started in.
-- (7c3e0c1: the game's fill was kept as first seen, so Bear's rage bar got the
-- mana art back; a new fill after a shift wasn't greyed under our color.)

local client = arg and arg[1] or "forever"
local MANA_ART, RAGE_ART = "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana", "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Rage"
local GAME_COLOR = { [MANA_ART] = { 0, 0, 1 }, [RAGE_ART] = { 1, 0, 0 } }
local OUR = { 0.2, 0.4, 0.9 }
local powerType = 0 -- (0 mana, 1 rage)
local hooks = {}     -- method name -> the addon's hook on the power bar (one per load)
local root, wowRef
local function Install(wow)
	wowRef = wow
	-- luacheck: push ignore 111 112 113 121 122
	issecretvalue = function() return false end
	Enum = Enum or {}
	Enum.PowerType = Enum.PowerType or {}
	Enum.PowerType.Mana = 0
	UnitPowerType = function() return powerType end
	-- (The addon hooks the power bar once a load: noted, so each cell's fresh
	-- bar gets the same hooks.)
	hooksecurefunc = function(a, b, c)
		local tbl, name, fn = a, b, c
		if type(a) == "string" then tbl, name, fn = _G, a, b end
		if root and tbl == root.PowerBar then hooks[name] = fn end
		local orig = tbl[name]
		rawset(tbl, name, function(...)
			local r = { orig(...) }
			fn(...)
			return unpack(r)
		end)
	end
	-- luacheck: pop
	root = wow.CreateFrame("Frame", "PersonalResourceDisplayFrame")
end

-- A status bar keeping its fill (file or atlas), the fill's grey and its color.
local function Bar(art)
	local bar = wowRef.CreateFrame("StatusBar")
	local fill = { value = art, desaturated = false }
	fill.GetTexture = function() return fill.value end
	fill.GetAtlas = function() return fill.value end
	fill.SetDesaturated = function(_, on) fill.desaturated = on and true or false end
	fill.SetVertexColor = function() end
	local color = GAME_COLOR[art] or { 1, 1, 1 }
	rawset(bar, "SetStatusBarTexture", function(_, value) fill.value, fill.desaturated = value, false end)
	rawset(bar, "GetStatusBarTexture", function() return fill end)
	rawset(bar, "SetStatusBarColor", function(_, r, g, b) color = { r, g, b } end)
	rawset(bar, "GetStatusBarColor", function() return color[1], color[2], color[3] end)
	bar.fill = fill
	bar.Color = function() return color end
	return bar
end

local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
local holder = wowRef.CreateFrame("Frame")
holder.healthBar = Bar("health")
root.HealthBarsContainer = holder

local function Same(a, b)
	return math.abs(a[1] - b[1]) < 0.01 and math.abs(a[2] - b[2]) < 0.01 and math.abs(a[3] - b[3]) < 0.01
end
local function Name(value)
	if value == MANA_ART then return "mana" end
	if value == RAGE_ART then return "rage" end
	return value == nil and "none" or "ours"
end
local function ColorName(color)
	if Same(color, OUR) then return "ours" end
	if Same(color, GAME_COLOR[MANA_ART]) then return "mana" end
	if Same(color, GAME_COLOR[RAGE_ART]) then return "rage" end
	return ("%.2f,%.2f,%.2f"):format(color[1], color[2], color[3])
end

-- The game's power bar change, as a form change does it: the power, the art, the color.
local function GameShift(bar, art)
	powerType = art == MANA_ART and 0 or 1
	bar:SetStatusBarTexture(art)
	local c = GAME_COLOR[art]
	bar:SetStatusBarColor(c[1], c[2], c[3])
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "prd-power-fill",
	fixed = { client = client },
	dims = {
		{ "page", { "on", "off", "styleOff" } },
		{ "texture", { "ours", "game" } },
		{ "manaColor", { "ours", "game" } },
		{ "start", { "caster", "bear" } },
		{ "shift", { "yes", "no" } },
		{ "after", { "keep", "textureGame", "pageOff" } },
	},
	cell = function(c)
		-- (A fresh bar per cell, with the addon's hooks on it: nothing kept from the last.)
		db.styleGeneral, db.prdStyle = true, false
		local startArt = c.start == "caster" and MANA_ART or RAGE_ART
		local otherArt = c.start == "caster" and RAGE_ART or MANA_ART
		powerType = c.start == "caster" and 0 or 1
		local bar = Bar(startArt)
		for name, fn in pairs(hooks) do
			local orig = bar[name]
			rawset(bar, name, function(...)
				local r = { orig(...) }
				fn(...)
				return unpack(r)
			end)
		end
		root.PowerBar = bar
		db.styleGeneral = c.page ~= "styleOff"
		db.prdStyle = c.page ~= "off"
		db.prdTexture = c.texture == "ours" and "smooth" or "game"
		db.prdManaColor = c.manaColor == "ours" and "custom" or "game"
		db.prdManaR, db.prdManaG, db.prdManaB = OUR[1], OUR[2], OUR[3]
		ns.RefreshPersonalStyle()
		if c.shift == "yes" then GameShift(bar, otherArt) end
		if c.after == "textureGame" then
			db.prdTexture = "game"
			ns.RefreshPersonalStyle()
		elseif c.after == "pageOff" then
			db.prdStyle = false
			ns.RefreshPersonalStyle()
		end
		local out = ("fill=%s grey=%s color=%s"):format(Name(bar.fill.value), bar.fill.desaturated and "y" or "n",
			ColorName(bar.Color()))
		db.prdStyle = false
		ns.RefreshPersonalStyle()
		return out
	end,
	pins = {
		-- (The look off (the page, Style, or switched off after): the game's art
		-- and color for the power you have now.)
		{ "start=caster shift=no", "fill=mana grey=n color=mana" },
		{ "start=bear shift=yes", "fill=mana grey=n color=mana" },
		{ "start=caster shift=yes", "fill=rage grey=n color=rage" },
		{ "start=bear shift=no", "fill=rage grey=n color=rage" },
		-- (Look on, our texture kept: ours, in our mana color while it's mana.)
		{ "page=on texture=ours after=keep start=caster shift=no manaColor=ours", "fill=ours grey=n color=ours" },
		{ "page=on texture=ours after=keep start=bear shift=yes manaColor=ours", "fill=ours grey=n color=ours" },
		{ "page=on texture=ours after=keep start=caster shift=no manaColor=game", "fill=ours grey=n color=mana" },
		{ "page=on texture=ours after=keep start=bear shift=yes manaColor=game", "fill=ours grey=n color=mana" },
		{ "page=on texture=ours after=keep start=caster shift=yes", "fill=ours grey=n color=rage" },
		{ "page=on texture=ours after=keep start=bear shift=no", "fill=ours grey=n color=rage" },
		-- (Look on, the game's art (picked, or set back after): our mana color
		-- greyed under it while it's mana.)
		{ "page=on texture=game after=keep start=caster shift=no manaColor=ours", "fill=mana grey=y color=ours" },
		{ "page=on texture=game after=keep start=bear shift=yes manaColor=ours", "fill=mana grey=y color=ours" },
		{ "page=on after=textureGame start=caster shift=no manaColor=ours", "fill=mana grey=y color=ours" },
		{ "page=on after=textureGame start=bear shift=yes manaColor=ours", "fill=mana grey=y color=ours" },
	},
})
