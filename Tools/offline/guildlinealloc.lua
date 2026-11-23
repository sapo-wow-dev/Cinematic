-- The plates' guild line without garbage per frame of a fade (offline, Lua
-- 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/guildlinealloc.lua < /dev/null
-- Audit 2026-11-22: PlateGuild.lua's Refresh runs every frame a plate fades
-- (PlateParts' ApplyPlate), and made two closures and a look table each time.
-- On a stand-in plate (its line's text from a stub): the line shown in its
-- words and the row's alpha, its color set, and 2000 refreshes making next to
-- no garbage. PASS or FAIL per check.

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc")

local function Up(fn, wanted)
	for i = 1, 80 do
		local name, value = debug.getupvalue(fn, i)
		if not name then break end
		if name == wanted then return value, i end
	end
end
local Refresh = Up(ns.SetPlateGuild, "Refresh")
Check("Refresh found", Refresh ~= nil)

if Refresh then
	local _, at = Up(Refresh, "LineText")
	Check("its LineText found", at ~= nil)
	if at then debug.setupvalue(Refresh, at, function() return "<Stormwind Guard>", false, false end) end
	local shares = Up(ns.SetPlateGuild, "shares")
	local unitFrame = wow.CreateFrame("Frame")
	local name = unitFrame:CreateFontString()
	rawset(name, "GetFont", function() return "Fonts\\FRIZQT__.TTF", 12, "" end)
	rawset(name, "GetFontObject", function() return nil end)
	rawset(name, "GetShadowOffset", function() return 1, -1 end)
	rawset(name, "GetShadowColor", function() return 0, 0, 0, 1 end)
	rawset(name, "GetTextColor", function() return 0.2, 0.6, 1 end)
	rawset(name, "GetScale", function() return 1 end)
	local plate = wow.CreateFrame("Frame")
	plate.UnitFrame, plate.namePlateUnitToken = unitFrame, "nameplate1"
	unitFrame.name = name
	ns.PlateNameText = function() return name end
	local colored
	local create = unitFrame.CreateFontString
	rawset(unitFrame, "CreateFontString", function(self, ...)
		local line = create(self, ...)
		rawset(line, "SetTextColor", function(_, r, g, b) colored = ("%.1f %.1f %.1f"):format(r, g, b) end)
		return line
	end)
	shares[plate] = 0.5
	Refresh(plate)
	local line = Up(ns.SetPlateGuild, "lines")[plate]
	Check("the line made and shown", line ~= nil and line:IsShown())
	Check("in its words", line and line._text == "<Stormwind Guard>", line and line._text)
	Check("in the name's color", colored == "0.2 0.6 1.0", colored)

	collectgarbage("collect")
	collectgarbage("stop")
	local before = collectgarbage("count")
	for i = 1, 2000 do
		shares[plate] = 0.3 + (i % 5) / 10
		Refresh(plate)
	end
	local kb = collectgarbage("count") - before
	collectgarbage("restart")
	Check("2000 refreshes: next to no garbage", kb < 40, ("%.1f KB"):format(kb))
end

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
