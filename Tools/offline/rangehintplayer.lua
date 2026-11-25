-- Range Hint is dev only (the user, 2026-11-25: "I'm not happy with it and
-- don't want it released"), offline (Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/rangehintplayer.lua [forever|retail]
-- The player copy (Cinematic.toc) has nothing of it: no file, no frame, no
-- HUD row, no Show switch, no Shoulder Cam row, no What's new entry; and
-- .pkgmeta leaves its files out of the package. PASS or FAIL lines.
-- luacheck: push ignore 111 112 113 121 122 143
package.path = "Tools/offline/?.lua;" .. package.path
local client = arg and arg[1] or "forever"
local wow = dofile("Tools/offline/wow.lua")
wow.Install(client)
local ns = {}
local tocText = {}
for line in io.lines("Cinematic.toc") do
	line = line:gsub("\r", "")
	tocText[#tocText + 1] = line
	if line ~= "" and not line:find("^#") then
		local chunk = loadfile((line:gsub("\\", "/")))
		if chunk then
			local ok, err = pcall(chunk, "Cinematic", ns)
			if not ok then wow.Warn(line .. ": " .. tostring(err)) end
		end
	end
end
wow.Fire("ADDON_LOADED", "Cinematic")
wow.Fire("PLAYER_LOGIN")
-- luacheck: pop

local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. client .. ": " .. text)
	if not ok then failed = failed + 1 end
end

local toc = table.concat(tocText, "\n")
Check(not toc:find("RangeHint"), "Cinematic.toc loads no Range Hint file")
local dev = {}
for line in io.lines("CinematicDev.toc") do dev[#dev + 1] = line:gsub("\r", "") end
dev = table.concat(dev, "\n")
Check(dev:find("UI\\RangeHint.lua", 1, true) ~= nil, "CinematicDev.toc still loads it (the dev copy)")
Check(not ns.isDev, "(the player copy)")
Check(ns.RangeHint == nil and ns.RangeHintOn == nil and ns.RangeHintChoices == nil, "no Range Hint code")
-- (rawget: the stand-in answers every unknown global with a stub; the game, nil.)
Check(rawget(_G, "CinematicRangeHint") == nil, "no Range Hint frame")
Check(ns.SHOW_IN_SWITCH.rangehint == nil, "no Range Hint Show switch")
-- (Its row's offered only while its frame exists, Frames.lua's ns.OptionAvailable.)
local offered = false
for _, item in ipairs(ns.COMBAT_SHOW or {}) do
	if item.key == "rangehint" then
		for _, name in ipairs(item.frames or {}) do
			if rawget(_G, name) then offered = true end
		end
	end
end
Check(not offered, "its HUD row isn't offered (so no Interface icon, no Show tab)")
Check(ns.ShoulderFollowRowShown == nil or ns.ShoulderFollowRowShown("shoulderCamFollowRangeHint") == false,
	"no Range hint row on Shoulder Cam's Follow HUD")
local listed = false
for _, entry in ipairs(ns.CHANGELOG_FEATURES or {}) do
	if tostring(entry.title):find("Range Hint") then listed = true end
end
Check(not listed, "no What's new entry")
local pkg = {}
for line in io.lines(".pkgmeta") do pkg[#pkg + 1] = line:gsub("\r", "") end
pkg = table.concat(pkg, "\n")
local missing = {}
for _, path in ipairs({ "UI/RangeHint.lua", "Style/RangeHintStyle.lua", "Textures/RangeMark_pill.tga" }) do
	if not pkg:find("- " .. path, 1, true) then missing[#missing + 1] = path end
end
for _, shape in ipairs({ "chevron", "double", "dot", "ring", "bracket", "arrow" }) do
	for _, kind in ipairs({ "thin", "normal", "bold", "glow" }) do
		local path = ("Textures/RangeMark_%s_%s.tga"):format(shape, kind)
		if not pkg:find("- " .. path, 1, true) then missing[#missing + 1] = path end
	end
end
Check(#missing == 0, ".pkgmeta leaves every Range Hint file out of the package" ..
	(#missing > 0 and (": missing " .. table.concat(missing, ", ")) or ""))

print(failed == 0 and ("ALL PASS " .. client) or (failed .. " FAILED " .. client))
if failed > 0 then os.exit(1) end
