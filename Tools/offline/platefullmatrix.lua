-- A nameplate's fill around a full-color texture (Sunset's), every state (the
-- audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-22-style-plate-full-white.md):
--   python -I Tools/offline/run.py Tools/offline/platefullmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/platefullmatrix.lua --base <ref>
-- A full-color texture whitens a plate's fill and puts its color on a thin
-- strip under it. The plate had it (or never), its color came from reading
-- the bar (retail), kept from the game's last set (Forever reads white), or
-- from nowhere; the strip took that color or refused it (a secret); the look
-- then left by the theme going (off) or a row gradient coming on; then
-- nothing more, or the game painting the bar a new color and the plate
-- styled again. Each cell: the fill's color and the strip.
-- The rule: once the full-color look is gone, the fill shows the bar's color
-- again (the game's newest, never an older one) and the strip goes; under a
-- gradient the gradient paints it. (bdb2e1d: a plate whose strip never got a
-- color stayed white.)

local client = arg and arg[1] or "forever"
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
-- luacheck: push ignore 111 112 113 121 122
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
-- luacheck: pop

-- (Full: a local of PlateHealthStyle.lua, found through the refresh's upvalues.)
local function Find(fn, name, depth, seen)
	if type(fn) ~= "function" or depth > 4 or seen[fn] then return nil end
	seen[fn] = true
	for i = 1, 60 do
		local upName, value = debug.getupvalue(fn, i)
		if not upName then break end
		if upName == name and type(value) == "function" then return value end
		local found = Find(value, name, depth + 1, seen)
		if found then return found end
	end
end
local Full = Find(ns.RefreshPlateHealthStyle, "Full", 0, {})

local GAME, NEW = { 0.8, 0.1, 0.1 }, { 0.2, 0.6, 0.2 }
-- A plate bar: its fill keeps its color; the bar reads its color back as the
-- game gave it (read) or white (Forever's); its strip may refuse a color.
local function Bar(source, refuse)
	local bar = wow.CreateFrame("StatusBar")
	local fill = { color = { GAME[1], GAME[2], GAME[3] } }
	fill.SetVertexColor = function(_, r, g, b) fill.color = { r, g, b } end
	local barColor = { GAME[1], GAME[2], GAME[3] }
	rawset(bar, "GetStatusBarTexture", function() return fill end)
	rawset(bar, "SetStatusBarColor", function(_, r, g, b)
		barColor = { r, g, b }
		fill.color = { r, g, b }
	end)
	rawset(bar, "GetStatusBarColor", function()
		if source == "read" then return barColor[1], barColor[2], barColor[3] end
		return 1, 1, 1
	end)
	local create = bar.CreateTexture
	rawset(bar, "CreateTexture", function(self, ...)
		local strip = create(self, ...)
		rawset(strip, "SetVertexColor", function() if refuse then error("secret refused") end end)
		bar.strip = strip
		return strip
	end)
	bar.fill = fill
	return bar
end
local function Same(a, b)
	return math.abs(a[1] - b[1]) < 0.01 and math.abs(a[2] - b[2]) < 0.01 and math.abs(a[3] - b[3]) < 0.01
end
local function ColorName(color)
	if Same(color, GAME) then return "game" end
	if Same(color, NEW) then return "new" end
	if Same(color, { 1, 1, 1 }) then return "white" end
	return ("%.2f,%.2f,%.2f"):format(color[1], color[2], color[3])
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "plate-full-fill",
	fixed = { client = client },
	dims = {
		{ "had", { "full", "never" } },
		{ "source", { "read", "kept", "none" } },
		{ "strip", { "takes", "refuses" } },
		{ "leave", { "off", "gradient" } },
		{ "again", { "no", "recolor" } },
	},
	cell = function(c)
		if not Full then error("Full not found") end
		local bar = Bar(c.source, c.strip == "refuses")
		local state = { color = c.source == "kept" and { GAME[1], GAME[2], GAME[3] } or nil }
		if c.had == "full" then
			state.full = true
			Full(bar, state, nil)
		end
		if c.leave == "off" then
			state.full = false
		else
			state.gradient = { 0, 0, 0 }
		end
		Full(bar, state, nil)
		if c.again == "recolor" then
			bar:SetStatusBarColor(NEW[1], NEW[2], NEW[3])
			Full(bar, state, nil)
		end
		local strip = bar.strip and (bar.strip:IsShown() and "shown" or "hidden") or "none"
		return ("fill=%s strip=%s"):format(ColorName(bar.fill.color), strip)
	end,
	pins = {
		-- (Never full-color: left alone, the game's color, its newest once it paints again.)
		{ "had=never", "fill=game strip=none" },
		{ "had=never again=recolor", "fill=new strip=none" },
		-- (Left: the bar's color back on the fill (read or kept), no strip.)
		{ "had=full", "fill=game strip=hidden" },
		-- (No color known anywhere (Forever reads white, none kept): white till
		-- the game paints it again. The user's call.)
		{ "had=full source=none", "fill=white strip=hidden" },
		-- (A gradient after: the fill under it is the gradient's to paint;
		-- Full leaves it as it is, white.)
		{ "had=full leave=gradient", "fill=white strip=hidden" },
		-- (The game's newer color after, styled again: the newer one, never the kept.)
		{ "had=full again=recolor", "fill=new strip=hidden" },
	},
})
