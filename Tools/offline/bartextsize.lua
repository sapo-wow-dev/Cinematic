-- A bar's numbers sized to fit their bar, outline and shadow included
-- (Style/UnitStyle.lua ns.BarTextSize; offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/bartextsize.lua < /dev/null
-- The mana numbers stood over their thin bar's edges (9 on a 10-tall bar,
-- the user's screenshot 2026-11-21). A drawn line is about 1.15 its size.
-- luacheck: ignore 111 112 113
local ns = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc")
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end
local Size = ns.BarTextSize
Check("the size rule is there", type(Size) == "function")
if Size then
	for _, case in ipairs({ { 12, 10, "OUTLINE" }, { 12, 10, "" }, { 9, 10, "OUTLINE" }, { 12, 8, "OUTLINE" }, { 12, 12, "THICKOUTLINE" } }) do
		local size, high, flags = case[1], case[2], case[3]
		local got = Size(size, high, flags)
		local edge = flags:find("THICK") and 3 or flags:find("OUTLINE") and 2 or 1
		Check(("%d on a %d-tall bar (%s) fits"):format(size, high, flags ~= "" and flags or "plain"),
			got * 1.15 + edge <= high + 0.6 or got == 6, got)
	end
	Check("a tall bar keeps its size", Size(10, 20, "OUTLINE") == 10, Size(10, 20, "OUTLINE"))
	Check("never under 6", Size(12, 4, "OUTLINE") == 6, Size(12, 4, "OUTLINE"))
	Check("the mana bar's numbers smaller than before (9 on 10)", Size(12, 10, "OUTLINE") < 9, Size(12, 10, "OUTLINE"))
end
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
