-- A nameplate's fill after a full-color theme is left (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/platefullwhite.lua [forever|retail] < /dev/null
-- Audit 2026-11-22: a full-color texture (Sunset's) whitens the fill and puts
-- the bar's color on a strip under it. Going back, the fill's color came back
-- only while the strip showed, so a plate whose strip never got a color (its
-- color refused, a secret) stayed white. On a stand-in bar: whitened with its
-- strip refused, then the theme left: the game's color back on the fill; and
-- one whose strip did show, as before. PASS or FAIL per check.

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local client = arg and arg[1] or "forever"
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")

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
Check(client .. ": Full found", Full ~= nil)

-- A plate bar keeping its fill's color; its strip refuses a color (a secret).
local function Bar(refuse)
	local bar = wow.CreateFrame("StatusBar")
	local fill = { color = { 0.8, 0.1, 0.1 } }
	fill.SetVertexColor = function(_, r, g, b) fill.color = { r, g, b } end
	rawset(bar, "GetStatusBarTexture", function() return fill end)
	rawset(bar, "GetStatusBarColor", function() return 1, 1, 1 end) -- (Forever reads white)
	local create = bar.CreateTexture
	rawset(bar, "CreateTexture", function(self, ...)
		local strip = create(self, ...)
		rawset(strip, "SetVertexColor", function() if refuse then error("secret refused") end end)
		return strip
	end)
	bar.fill = fill
	return bar
end
local function Color(bar) return ("%.1f %.1f %.1f"):format(bar.fill.color[1], bar.fill.color[2], bar.fill.color[3]) end

if Full then
	for _, refuse in ipairs({ true, false }) do
		local label = refuse and "strip refused" or "strip shown"
		local bar = Bar(refuse)
		local state = { full = true, color = { 0.8, 0.1, 0.1 } }
		Full(bar, state, nil)
		Check(client .. ": " .. label .. ": fill whitened", Color(bar) == "1.0 1.0 1.0", Color(bar))
		state.full = false
		Full(bar, state, nil)
		Check(client .. ": " .. label .. ": the game's color back on the fill", Color(bar) == "0.8 0.1 0.1", Color(bar))
	end
end

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
