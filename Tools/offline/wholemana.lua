-- Mana words are whole numbers, never 338.00003051758 (Style/PersonalManaText.lua
-- ns.WholeManaWords + the after-cast curve; offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/wholemana.lua < /dev/null
-- A player's screenshot 2026-11-21: mana after a cast, secret (a curve's
-- float answer) with max mana over 1000, showed every decimal. The game here
-- is a stand-in: secret = a table, AbbreviateNumbers applies rules the way
-- the game's own data does (divide, cut, decimals' divisor; none under the
-- lowest breakpoint = as it is). The real game: /cine debug wholemana.
-- luacheck: ignore 111 112 113 122
local ns = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc")
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local SECRET = {}
local function Secret(n) return setmetatable({ n = n }, SECRET) end
local function IsSecret(v) return getmetatable(v) == SECRET end
_G.issecretvalue = IsSecret
local GAME_RULES = { { 1000000, "M", 100000, 10 }, { 10000, "K", 1000, 1 }, { 1000, "K", 100, 10 } }
_G.CreateAbbreviateConfig = function(data) return { data = data } end
_G.AbbreviateNumbers = function(value, options)
	local n = IsSecret(value) and value.n or value
	local rules = {}
	if options and options.config then
		for i, r in ipairs(options.config.data) do
			rules[i] = { r.breakpoint, r.abbreviation, r.significandDivisor, r.fractionDivisor }
		end
	else
		rules = GAME_RULES
	end
	for _, r in ipairs(rules) do
		if n >= r[1] then
			local words = tostring(math.floor(n / r[3]) / r[4]):gsub("%.0$", "") .. r[2]
			return IsSecret(value) and Secret(words) or words
		end
	end
	return IsSecret(value) and Secret(tostring(n)) or tostring(n)
end
local function Plain(words) return IsSecret(words) and words.n or words end

local W = ns.WholeManaWords
Check("the whole-number words are there", type(W) == "function")
if W then
	Check("secret 338.00003051758 says 338", Plain(W(Secret(338.00003051758))) == "338", Plain(W(Secret(338.00003051758))))
	Check("secret 6337.9 says 6.3K", Plain(W(Secret(6337.9))) == "6.3K", Plain(W(Secret(6337.9))))
	Check("secret 23456.7 says 23K", Plain(W(Secret(23456.7))) == "23K", Plain(W(Secret(23456.7))))
	Check("secret 0 says 0", Plain(W(Secret(0))) == "0", Plain(W(Secret(0))))
	Check("plain 337.6 says 338", W(337.6) == "338", W(337.6))
	Check("nil stays nil", W(nil) == nil)
end

-- The after-cast sums through the game's curve: secret mana, max 7000.
local points
_G.C_CurveUtil = { CreateCurve = function()
	points = {}
	return { SetType = function() end, AddPoint = function(_, x, y) points[#points + 1] = { x, y } end, points = points }
end }
_G.Enum = _G.Enum or {}
Enum.LuaCurveType = Enum.LuaCurveType or { Linear = 0 }
local MAX, mana = 7000, 0
local function Eval(curve, x)
	local p = curve.points
	if x <= p[1][1] then return p[1][2] end
	for i = 2, #p do
		if x <= p[i][1] then
			local a, b = p[i - 1], p[i]
			return a[2] + (b[2] - a[2]) * (x - a[1]) / (b[1] - a[1])
		end
	end
	return p[#p][2]
end
_G.UnitPower = function() return Secret(mana) end
_G.UnitPowerMax = function() return MAX end
-- (The curve's answer plain: a stand-in secret can't pass as a number, and
-- the secret words were checked above. This checks the curve's sums.)
_G.UnitPowerPercent = function(_, _, _, curve) return Eval(curve, mana / MAX) end
local After = ns.ManaAfterWords
Check("the after-cast words are reachable", type(After) == "function")
if After then
	for _, case in ipairs({ { 838, 500, "338" }, { 6838, 500, "6.3K" }, { 500, 500, "0" }, { 400, 500, "0" },
		{ 501, 500, "1" }, { 7000, 0, "7K" }, { 7000, 6999, "1" }, { 1500, 7000, "0" } }) do
		mana = case[1]
		local words = Plain((After(case[2])))
		Check(("mana %d, cost %d says %s"):format(case[1], case[2], case[3]), words == case[3], words)
	end
	-- (A mana a hair over the cost by float sums still 0, a hair under a whole one rounds up.)
	mana = 500.0001
	Check("a hair over the cost says 0", Plain((After(500))) == "0", Plain((After(500))))
	mana = 837.9999
	Check("837.9999 less 500 says 338", Plain((After(500))) == "338", Plain((After(500))))
end
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
