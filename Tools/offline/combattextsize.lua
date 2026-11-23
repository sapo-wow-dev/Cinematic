-- Combat text numbers past the game's tallest font (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/combattextsize.lua [forever|retail] < /dev/null
-- Audit 2026-11-22: Size and Crit size go to 300% each and a long cast to 150%
-- of 36, but SetFont draws at 120 at most (font-max-120): big crits stopped
-- growing there. On stand-in font strings: the font at 120 at most, the words
-- scaled the rest (copies too), a crit's pop height in the font's own size,
-- and a small number as before. PASS or FAIL per check.

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local client = arg and arg[1] or "forever"
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")

-- (SetSize and SetHeight: locals of CombatTextStyle.lua, found through ns's functions' upvalues.)
local function Find(name)
	local seen = {}
	local function Walk(fn, depth)
		if depth > 9 or seen[fn] then return nil end
		if type(fn) == "table" then -- (the feature loops' list: the numbers' update loop waits there)
			seen[fn] = true
			for _, value in pairs(fn) do
				local found = Walk(value, depth + 1)
				if found then return found end
			end
			return nil
		end
		if type(fn) ~= "function" then return nil end
		seen[fn] = true
		for i = 1, 80 do
			local upName, value = debug.getupvalue(fn, i)
			if not upName then break end
			if upName == name and type(value) == "function" then
				local info = debug.getinfo(value, "S")
				if info.source:find("CombatTextStyle.lua", 1, true) then return value end
			end
			local found = Walk(value, depth + 1)
			if found then return found end
		end
	end
	local found = Walk(ns.FeatureLoop, 0)
	if found then return found end
	for _, value in pairs(ns) do
		found = Walk(value, 0)
		if found then return found end
	end
	-- (And the frames' scripts: the numbers' update loop.)
	for _, frame in ipairs(wow.frames) do
		for _, script in pairs(frame._scripts or {}) do
			local found = Walk(script, 0)
			if found then return found end
		end
	end
end
local SetSize, SetHeight = Find("SetSize"), Find("SetHeight")
Check(client .. ": SetSize and SetHeight found", SetSize ~= nil and SetHeight ~= nil)

local function Text()
	local text = { size = nil, scale = 1, height = nil, shown = true }
	text.SetFont = function(self, _, size) self.size = size return true end
	text.SetTextScale = function(self, scale) self.scale = scale end
	text.SetTextHeight = function(self, height) self.height = height end
	text.SetShadowOffset = function() end
	text.ClearAllPoints = function() end
	text.SetPoint = function() end
	text.SetTextColor = function() end
	text.SetShown = function(self, on) self.shown = on end
	text.IsShown = function(self) return self.shown end
	return text
end
local function Number()
	return { id = "all", text = Text(), copies = { Text(), Text() } }
end

if SetSize and SetHeight then
	local number = Number()
	SetSize(number, 36 * 3 * 1.3) -- (Size 300%, a crit: 140)
	Check(client .. ": the font at 120 at most", number.text.size == 120, number.text.size)
	Check(client .. ": the words scaled the rest", math.abs(number.text.scale * 120 - 140.4) < 0.01,
		("%.3f"):format(number.text.scale))
	Check(client .. ": its copies the same", number.copies[1].size == 120 and number.copies[1].scale == number.text.scale)
	SetHeight(number, 140.4 * 1.2) -- (a crit's pop)
	Check(client .. ": a pop's height in the font's own size", math.abs(number.text.height - 144) < 0.01,
		tostring(number.text.height))
	local small = Number()
	SetSize(small, 36)
	Check(client .. ": a hit at 36 as before", small.text.size == 36 and small.text.scale == 1,
		("%s x%s"):format(tostring(small.text.size), tostring(small.text.scale)))
end

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
