-- Centered cooldown bars, where each icon goes (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/centerbar.lua
-- Frames.lua's PlaceBar made two closures (Goal, FadedGoal) per bar per pass:
-- ~0.7 KB a bar, 10 passes a second in fights, ~21 KB/s (Tools/perf/ledger.md
-- 2026-11-23). Now they're made once and read the bar's numbers from
-- shownIn.placing. Checked: the new code, taken from Frames.lua as it is, gives
-- every icon the same goal as the old PlaceBar (kept below) over a matrix of
-- bars (rows and columns, 1-12 icons, 1-4 a line, some shown, none shown,
-- hidden and faded ones, one just shown again), and makes no memory per bar.
-- PASS or FAIL.
local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. text)
	if not ok then failed = failed + 1 end
end

-- The upvalues PlaceBar reads, made fresh for each version.
local function Env()
	local env = { slotOf = {}, goal = {}, placeOf = {}, lineCross = {}, wanted = {}, readyTargets = {}, put = {} }
	env.shownIn = { hidden = {}, wasHidden = {}, hooked = {} }
	return env
end
local PRELUDE = [==[
local env = ...
local slotOf, goal, placeOf, lineCross, wanted, readyTargets, shownIn =
	env.slotOf, env.goal, env.placeOf, env.lineCross, env.wanted, env.readyTargets, env.shownIn
local wipe = function(t) for k in pairs(t) do t[k] = nil end end
local function Put(icon, x, y) env.put[icon] = { x, y } end
local function SetGoal(icon, x, y)
	local at = goal[icon] or {}
	at[1], at[2] = x, y
	goal[icon] = at
end
local function ByPlace(a, b)
	local placeA, placeB = placeOf[a], placeOf[b]
	if placeA ~= placeB then return placeA < placeB end
	local slotA, slotB = slotOf[a], slotOf[b]
	if slotA[5] ~= slotB[5] then return slotA[5] > slotB[5] end
	return slotA[4] < slotB[4]
end
]==]

-- The old PlaceBar (Frames.lua before 2026-11-23's fix), for reference.
local OLD = [==[
	local function PlaceBar(icons)
		table.sort(icons, ByPlace)
		local first, second = slotOf[icons[1]], slotOf[icons[2]]
		local stepX, stepY = second[4] - first[4], second[5] - first[5]
		if math.abs(stepX) < 0.5 and math.abs(stepY) < 0.5 then return end
		local across = math.abs(stepY) < 0.5
		wipe(lineCross)
		local lineLength, count = 0, 0
		for _, icon in ipairs(icons) do
			local slot = slotOf[icon]
			local cross = across and slot[5] or slot[4]
			if #lineCross == 0 or math.abs(cross - lineCross[#lineCross]) > 0.5 then
				lineCross[#lineCross + 1] = cross
			end
			if #lineCross == 1 then lineLength = lineLength + 1 end
			shownIn[icon] = readyTargets[icon] ~= 0 and not shownIn.hidden[icon]
			if shownIn[icon] then count = count + 1 end
		end
		local function Goal(icon, line, along)
			local cross = lineCross[line + 1] or lineCross[#lineCross]
			if across then
				SetGoal(icon, first[4] + along * stepX, cross)
			else
				SetGoal(icon, cross, first[5] + along * stepY)
			end
		end
		local lastLine = math.max(0, math.floor((count - 1) / lineLength))
		local inLast = count - lastLine * lineLength
		local below = count == 0 and 0 or math.max(0, #lineCross - 1 - lastLine) * lineLength
		local start = (lineLength - inLast) / 2
		local side = math.floor(start)
		local function FadedGoal(icon, k)
			if count == 0 then
				Goal(icon, math.floor(k / lineLength), k % lineLength)
			elseif k < below then
				Goal(icon, lastLine + 1 + math.floor(k / lineLength), k % lineLength)
			elseif k - below < side then
				Goal(icon, lastLine, start + inLast + (k - below))
			elseif k - below < 2 * side then
				Goal(icon, lastLine, start - 1 - (k - below - side))
			elseif below + 2 * side > 0 then
				FadedGoal(icon, 0)
			else
				Goal(icon, lastLine, start + inLast + (k - below - 2 * side))
			end
		end
		local shown, faded = 0, 0
		for _, icon in ipairs(icons) do
			wanted[icon] = true
			if shownIn[icon] then
				local line = math.floor(shown / lineLength)
				local inLine = math.min(lineLength, count - line * lineLength)
				Goal(icon, line, shown % lineLength + (lineLength - inLine) / 2)
				if shownIn.wasHidden[icon] then Put(icon, goal[icon][1], goal[icon][2]) end
				shown = shown + 1
			else
				FadedGoal(icon, faded)
				faded = faded + 1
			end
		end
		for _, icon in ipairs(icons) do shownIn[icon] = nil end
	end
]==]

-- The new code, as Frames.lua has it: from "The bar being placed" to the end of PlaceBar.
local file = io.open("Frames.lua")
local source = file:read("*a")
file:close()
local from = source:find("\t%-%- The bar being placed")
local to = source:find("\t%-%- %(Walked with hidden icons too")
Check(from and to, "the new PlaceBar found in Frames.lua")
if not (from and to) then return print("1 FAILED") end
local NEW = source:sub(from, to - 1)

local function Make(body)
	local chunk = assert(loadstring(PRELUDE .. body .. "\nreturn PlaceBar"))
	local env = Env()
	return chunk(env), env
end

-- One bar: n icons, perLine a line, laid across (rows) or down (columns).
local function Run(version, n, perLine, across, shownMask, hiddenMask, wasHiddenMask)
	local PlaceBar, env = Make(version)
	local icons = {}
	for i = 1, n do
		local icon = { id = i }
		local line, at = math.floor((i - 1) / perLine), (i - 1) % perLine
		local x, y = at * 40, -line * 40
		if not across then x, y = line * 40, -at * 40 end
		env.slotOf[icon] = { "TOPLEFT", nil, "TOPLEFT", x, y }
		env.placeOf[icon] = i
		env.readyTargets[icon] = shownMask[i] and 1 or 0
		env.shownIn.hidden[icon] = hiddenMask[i] or nil
		env.shownIn.wasHidden[icon] = wasHiddenMask[i] or nil
		icons[#icons + 1] = icon
	end
	-- (Shuffled: PlaceBar sorts them by place.)
	for i = #icons, 2, -1 do
		local j = (i * 7) % i + 1
		icons[i], icons[j] = icons[j], icons[i]
	end
	PlaceBar(icons)
	local out = {}
	for _, icon in ipairs(icons) do
		local g, p = env.goal[icon], env.put[icon]
		out[icon.id] = (g and ("%.3f,%.3f"):format(g[1], g[2]) or "-") .. (p and ("@%.3f,%.3f"):format(p[1], p[2]) or "")
	end
	return table.concat(out, " ")
end

local cases, differ = 0, {}
for _, across in ipairs({ true, false }) do
	for n = 2, 12 do
		for perLine = 1, 4 do
			for pattern = 0, 5 do
				local shown, hidden, was = {}, {}, {}
				for i = 1, n do
					if pattern == 0 then shown[i] = true
					elseif pattern == 1 then shown[i] = false
					elseif pattern == 2 then shown[i] = i % 2 == 0
					elseif pattern == 3 then shown[i] = i <= math.ceil(n / 3)
					elseif pattern == 4 then shown[i] = true hidden[i] = i % 3 == 0
					else shown[i] = i ~= 2 was[i] = i == 1 end
				end
				cases = cases + 1
				local old = Run(OLD, n, perLine, across, shown, hidden, was)
				local new = Run(NEW, n, perLine, across, shown, hidden, was)
				if old ~= new and #differ < 3 then
					differ[#differ + 1] = ("n=%d perLine=%d across=%s pattern=%d\n  old %s\n  new %s"):format(n, perLine,
						tostring(across), pattern, old, new)
				end
			end
		end
	end
end
Check(#differ == 0, ("%d bars: every icon's goal the same as the old code's%s"):format(cases,
	#differ > 0 and ("\n" .. table.concat(differ, "\n")) or ""))

-- No memory per bar (the old made ~0.7 KB in the game).
local function Garbage(version)
	local PlaceBar, env = Make(version)
	local icons = {}
	for i = 1, 8 do
		local icon = {}
		env.slotOf[icon] = { "TOPLEFT", nil, "TOPLEFT", (i - 1) % 4 * 40, -math.floor((i - 1) / 4) * 40 }
		env.placeOf[icon], env.readyTargets[icon] = i, i % 3 == 0 and 0 or 1
		icons[i] = icon
	end
	PlaceBar(icons) -- (goal tables made once)
	collectgarbage("collect")
	collectgarbage("stop")
	local before = collectgarbage("count")
	for _ = 1, 1000 do PlaceBar(icons) end
	local kb = collectgarbage("count") - before
	collectgarbage("restart")
	return kb
end
local old, new = Garbage(OLD), Garbage(NEW)
Check(new < 1 and old > new * 10, ("1000 bars: %.2f KB (the old code %.2f KB)"):format(new, old))

print(failed == 0 and "ALL PASSED" or (failed .. " FAILED"))
