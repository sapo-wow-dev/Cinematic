-- Where the game's windows open (QoL/CenterPanels.lua's ns.PanelRowMove),
-- offline (Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/panelspots.lua < /dev/null
-- Old vs new: with Dead center off, every row (narrow, wide, talk, too wide,
-- too tall; Opposite left/right/none; centerPanels on/off) moves exactly as
-- the placement before Dead center (OldMove, a copy of it). Dead center on:
-- every row's middle on the screen's middle both ways; a talk row with
-- Opposite still kept clear (as before); a row over a dropped window goes
-- beside it (right, else left, else stays). The General page has the row,
-- under "Open windows clear of your character", greyed with it off.
-- Says PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 143
local client, toc = arg and arg[1], arg and arg[2]

if not client then
	local LUA = os.getenv("CINE_LUA") or "lua5.1"
	local failed = 0
	for _, run in ipairs({ { "forever", "Cinematic.toc" }, { "retail", "Cinematic.toc" } }) do
		print(("== %s %s"):format(run[1], run[2]))
		local pipe = io.popen(("%s Tools/offline/panelspots.lua %s %s"):format(LUA, run[1], run[2]))
		local out = pipe:read("*a")
		pipe:close()
		io.write(out)
		if not out:find("ALL PASS") then failed = failed + 1 end
	end
	print(failed == 0 and "ALL PASS" or (failed .. " RUNS FAILED"))
	if failed > 0 then os.exit(1) end
	return
end

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail ~= nil and (" (" .. tostring(detail) .. ")") or ""))
end

local ns = dofile("Tools/offline/load.lua")(client, toc)
-- luacheck: pop

-- The placement before Dead center (QoL/CenterPanels.lua's CenterRow, as of
-- 54c9272), its numbers too.
local NARROW, TALK_LEFT, NARROW_LEFT, WIDE_RIGHT, WIDE_TOP, EDGE = 560, 0.12, 0.18, 0.17, 0.115, 8
local function OldMove(r, screenWidth, screenHeight, keepClear, center)
	local rowLeft, rowRight, rowTop, rowBottom, talk = r.left, r.right, r.top, r.bottom, r.talk
	local side = talk or rowRight - rowLeft < NARROW
	local target = not center and rowLeft or (talk and screenWidth * TALK_LEFT) or (side and screenWidth * NARROW_LEFT)
		or screenWidth * (1 - WIDE_RIGHT) - (rowRight - rowLeft)
	if talk and keepClear and (target + (rowRight - rowLeft) / 2 > screenWidth / 2) == (keepClear == "right") then
		target = screenWidth - target - (rowRight - rowLeft)
	end
	local shift = math.max(target - rowLeft, -rowLeft)
	local rise
	if not center then
		rise = 0
	elseif side then
		rise = math.min((screenHeight + rowTop - rowBottom) / 2, screenHeight) - rowTop
	else
		local top = math.min(screenHeight - EDGE, math.max(screenHeight * (1 - WIDE_TOP), rowTop - rowBottom + EDGE))
		rise = top - rowTop
	end
	return shift, rise
end

local Move = ns.PanelRowMove
Check("ns.PanelRowMove is there", type(Move) == "function")
if type(Move) ~= "function" then
	print(fails .. " FAILED")
	os.exit(1)
end

-- Rows the game makes: its left slot (x 16, top 100 down), 1 or 2 wide.
local SCREENS = { { 1920, 1080 }, { 2560, 1080 }, { 1280, 960 }, { 1024, 768 } }
local ROWS = {
	{ name = "character", width = 384, height = 512 },
	{ name = "retail character", width = 540, height = 512 },
	{ name = "quest log", width = 667, height = 496 },
	{ name = "group finder", width = 563, height = 428 },
	{ name = "two side by side", width = 768, height = 512 },
	{ name = "quest giver", width = 384, height = 512, talk = true },
	{ name = "too wide", width = 3000, height = 400 },
	{ name = "too tall", width = 700, height = 1400 },
}
local function Row(each, screenHeight)
	return { left = 16, right = 16 + each.width, top = screenHeight - 100, bottom = screenHeight - 100 - each.height,
		talk = each.talk }
end

-- Old vs new, Dead center off (and on with centerPanels off: it's under it).
local same, total, firstOff = 0, 0, nil
for _, screen in ipairs(SCREENS) do
	for _, each in ipairs(ROWS) do
		for _, keepClear in ipairs({ false, "left", "right" }) do
			for _, center in ipairs({ true, false }) do
				for _, middle in ipairs({ false, true }) do
					if not middle or not center then
						local r = Row(each, screen[2])
						local s1, r1 = OldMove(r, screen[1], screen[2], keepClear or nil, center)
						local s2, r2 = Move(r, screen[1], screen[2], keepClear or nil, center, middle, {})
						total = total + 1
						if math.abs(s1 - s2) < 0.001 and math.abs(r1 - r2) < 0.001 then
							same = same + 1
						elseif not firstOff then
							firstOff = ("%s %dx%d keep %s center %s middle %s: old %s,%s new %s,%s"):format(each.name,
								screen[1], screen[2], tostring(keepClear), tostring(center), tostring(middle), s1, r1, s2, r2)
						end
					end
				end
			end
		end
	end
end
Check(("Dead center off: every row where it was (%d of %d)"):format(same, total), same == total, firstOff)

-- Dead center on: the row's middle on the screen's middle, both ways.
local centered, count, firstBad = 0, 0, nil
for _, screen in ipairs(SCREENS) do
	for _, each in ipairs(ROWS) do
		if each.width <= screen[1] and each.height <= screen[2] then
			for _, keepClear in ipairs(each.talk and { false } or { false, "left", "right" }) do
				local r = Row(each, screen[2])
				local shift, rise = Move(r, screen[1], screen[2], keepClear or nil, true, true, {})
				local midX = (r.left + r.right) / 2 + shift
				local midY = (r.top + r.bottom) / 2 + rise
				count = count + 1
				if math.abs(midX - screen[1] / 2) < 0.001 and math.abs(midY - screen[2] / 2) < 0.001 then
					centered = centered + 1
				elseif not firstBad then
					firstBad = ("%s %dx%d: middle %s,%s"):format(each.name, screen[1], screen[2], midX, midY)
				end
			end
		end
	end
end
Check(("Dead center on: every row in the very middle (%d of %d)"):format(centered, count), centered == count, firstBad)

-- A row too wide or tall still keeps its left edge and top on the screen.
do
	local r = Row(ROWS[7], 1080)
	local shift = Move(r, 1920, 1080, nil, true, true, {})
	Check("Dead center, too wide: left edge kept on the screen", r.left + shift >= 0, r.left + shift)
	r = Row(ROWS[8], 1080)
	local _, rise = Move(r, 1920, 1080, nil, true, true, {})
	Check("Dead center, too tall: top kept on the screen", r.top + rise <= 1080, r.top + rise)
end

-- Talking with Quest Vision's Opposite clicked: kept clear of the NPC, as
-- before Dead center (Opposite wins).
for _, keepClear in ipairs({ "left", "right" }) do
	local r = Row(ROWS[6], 1080)
	local s1, r1 = OldMove(r, 1920, 1080, keepClear, true)
	local s2, r2 = Move(r, 1920, 1080, keepClear, true, true, {})
	Check("Dead center, talking with Opposite (NPC " .. keepClear .. "): as before", s1 == s2 and r1 == r2,
		("%s,%s vs %s,%s"):format(s1, r1, s2, r2))
end

-- A dropped window in the middle: the row opens beside it, not over it.
local function Overlaps(a, b)
	return a[1] < b[2] and a[2] > b[1] and a[4] < b[3] and a[3] > b[4]
end
local function Placed(r, shift, rise)
	return { r.left + shift, r.right + shift, r.top + rise, r.bottom + rise }
end
do
	local r = Row(ROWS[1], 1080) -- character, 384 wide
	local dropped = { { 760, 1160, 800, 300 } } -- a window dropped dead center
	local placed = Placed(r, Move(r, 1920, 1080, nil, true, true, dropped))
	Check("Dropped window in the middle: row beside it", not Overlaps(placed, dropped[1]),
		("row %d-%d"):format(placed[1], placed[2]))
	Check("...to its right", placed[1] >= 1160, placed[1])
	-- No room on the right: to the left.
	dropped = { { 700, 1700, 900, 200 } }
	placed = Placed(r, Move(r, 1920, 1080, nil, true, true, dropped))
	Check("No room on its right: row to its left", placed[2] <= 700 and placed[1] >= 0,
		("row %d-%d"):format(placed[1], placed[2]))
	-- No room either side: stays in the middle (over it, as without Dead center).
	dropped = { { 100, 1800, 900, 200 } }
	placed = Placed(r, Move(r, 1920, 1080, nil, true, true, dropped))
	Check("No room either side: stays dead center", math.abs((placed[1] + placed[2]) / 2 - 960) < 0.001,
		("row %d-%d"):format(placed[1], placed[2]))
	-- A dropped window off to the side, not in the way: dead center as usual.
	dropped = { { 20, 400, 900, 200 } }
	placed = Placed(r, Move(r, 1920, 1080, nil, true, true, dropped))
	Check("Dropped window not in the way: still dead center", math.abs((placed[1] + placed[2]) / 2 - 960) < 0.001,
		("row %d-%d"):format(placed[1], placed[2]))
	-- Above or below it (no overlap top to bottom): dead center.
	dropped = { { 760, 1160, 1070, 900 } }
	placed = Placed(r, Move(r, 1920, 1080, nil, true, true, dropped))
	Check("Dropped window above the row: still dead center", math.abs((placed[1] + placed[2]) / 2 - 960) < 0.001,
		("row %d-%d"):format(placed[1], placed[2]))
end

-- Settings: off by default, under the General page's switch.
Check("centerPanelsMiddle off by default", ns.DEFAULTS and ns.DEFAULTS.centerPanelsMiddle == false)

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
