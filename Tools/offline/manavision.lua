-- Vitals Vision's low mana (Atmosphere/ManaVision.lua; offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/manavision.lua < /dev/null
-- On both clients' stand-ins, with the game's curve stood in for (it hands
-- the curve's answer at your mana's share):
--   * the switches: Mana tab off to start, Health tab on, both under the page;
--   * the curve: none above Starts, full at Full, eased between, and the
--     plain sums agree with it;
--   * shown only with the page and the Mana tab on, mana there, alive, and
--     its Show in row on; the overlay's alpha is the curve's answer;
--   * the look: Strength and out-of-combat strength on the veil, edges off;
--   * the Health tab off: no health edges (ns.Setting), the mana still;
--   * both pages build with the Health and Mana tabs, the Style page with
--     its Mana tab, and the test runs to the end;
--   * /cine debug manavision runs to DONE with no FAIL, settings put back.
-- PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212 431
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end
local function Near(a, b) return type(a) == "number" and math.abs(a - b) < 0.02 end
local function Has(log, pattern)
	for _, line in ipairs(log or {}) do
		if line:find(pattern) then return line end
	end
end

local function RunClient(client)
	print("== " .. client)
	CinematicDB = nil -- (a fresh install each client)
	local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
	if not ns.RefreshManaVision then
		Check("ManaVision loaded", false)
		return
	end
	local now = 100
	local timers, tickers = {}, {}
	GetTime = function() return now end
	C_Timer.After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end
	C_Timer.NewTicker = function(every, fn)
		local t = { every = every, next = now + every, fn = fn, Cancel = function(self) self.cancelled = true end }
		tickers[#tickers + 1] = t
		return t
	end
	local function Advance(seconds)
		local stop = now + seconds
		while now < stop do
			now = now + 0.1
			local due = {}
			for i = #timers, 1, -1 do
				if timers[i].at <= now then due[#due + 1] = table.remove(timers, i) end
			end
			for i = #due, 1, -1 do pcall(due[i].fn) end
			for _, t in ipairs(tickers) do
				if not t.cancelled and t.next <= now then
					t.next = now + t.every
					pcall(t.fn, t)
				end
			end
			ns.RefreshManaVision()
		end
	end
	Screenshot = function() end
	ns.IsCineModeOn = function() return false end
	ns.PadTestBox = function() end
	ns.PadTestBoxHide = function() end
	ns.noRealLayout = true
	wow.Methods.SetAlpha = function(self, alpha) self._alpha = alpha end
	wow.Methods.GetAlpha = function(self) return self._alpha or 1 end

	-- The game's curve: points kept, answered at your mana's share.
	local SECRET = {}
	_G.issecretvalue = function(v) return getmetatable(v) == SECRET end
	_G.C_CurveUtil = { CreateCurve = function()
		local points = {}
		return { SetType = function() end, AddPoint = function(_, x, y) points[#points + 1] = { x, y } end, points = points }
	end }
	_G.Enum = _G.Enum or {}
	Enum.LuaCurveType = Enum.LuaCurveType or { Linear = 0 }
	local MAX, mana, dead, fighting = 1000, 1000, false, false
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
	_G.UnitPower = function() return setmetatable({ n = mana }, SECRET) end -- (secret: Forever's)
	_G.UnitPowerMax = function() return MAX end
	_G.UnitPowerPercent = function(_, _, _, curve) return Eval(curve, mana / MAX) end
	_G.UnitIsDeadOrGhost = function() return dead end
	_G.UnitAffectingCombat = function() return fighting end
	_G.InCombatLockdown = function() return fighting end

	local db = ns.db
	local TAB = ns.VITALS_MANA_TAB
	Check("Mana tab off to start", ns.DEFAULTS[TAB] == false and db[TAB] == false, tostring(db[TAB]))
	Check("Health tab on to start", ns.DEFAULTS[ns.VITALS_HEALTH_TAB] == true and db[ns.VITALS_HEALTH_TAB] == true)
	Check("Mana tab under the page", ns.PageSwitchOf(TAB) == "lowHealth", ns.PageSwitchOf(TAB))
	Check("Style's Mana tab under the Vision's", ns.PageSwitchOf(ns.VITALS_TABS.mana) == TAB,
		ns.PageSwitchOf(ns.VITALS_TABS.mana))

	-- The curve and the plain sums.
	local curve = ns.ManaVisionCurve()
	Check("a curve made", curve ~= nil)
	local L = ns.ManaVisionLevelAt
	for _, case in ipairs({ { 1, 0 }, { 0.3, 0 }, { 0.5, 0 }, { 0.05, 1 }, { 0, 1 }, { 0.175, 0.5 } }) do
		Check(("level at %d%% is %.2f"):format(case[1] * 100, case[2]), Near(L(case[1]), case[2]), L(case[1]))
	end
	for _, share in ipairs({ 0.29, 0.25, 0.2, 0.15, 0.1, 0.06 }) do
		Check(("curve agrees with the sums at %d%%"):format(share * 100), math.abs(Eval(curve, share) - L(share)) < 0.06,
			("%.3f vs %.3f"):format(Eval(curve, share), L(share)))
	end

	local function State() return ns.ManaVisionState() end
	db.lowHealth = true
	mana = 100 -- (10%)
	ns.RefreshManaVision()
	Check("page on, Mana tab off: hidden", not State().shown)
	db[TAB] = true
	ns.RefreshManaVision()
	local s = State()
	Check("Mana tab on: shown", s.shown, s.mode)
	Check("alpha is the curve's answer at 10%", Near(s.alpha, L(0.1)), s.alpha)
	Check("mana read as secret (Forever's)", s.manaSecret)
	mana = 800
	ns.RefreshManaVision()
	Check("80% mana: alpha 0", Near(State().alpha, 0), State().alpha)
	mana = 100
	db.lowHealth = false
	ns.RefreshManaVision()
	Check("page off: hidden", not State().shown)
	db.lowHealth = true
	dead = true
	ns.RefreshManaVision()
	Check("dead: hidden", not State().shown)
	dead = false
	MAX = 0
	ns.RefreshManaVision()
	Check("no mana (a warrior): hidden", not State().shown)
	MAX = 1000
	db.lowManaAlways = false
	local rowOn = false
	local realRow = ns.RowOnNow
	ns.RowOnNow = function(key) return key == "vision:lowMana" and rowOn end
	now = now + 1
	ns.RefreshManaVision()
	Check("Show in row off here: hidden", not State().shown)
	rowOn = true
	now = now + 1
	ns.RefreshManaVision()
	Check("Show in row on here: shown", State().shown)
	ns.RowOnNow = realRow
	db.lowManaAlways = true

	-- The look: strength, out of combat, edges (the Style page's: on).
	db.styleGeneral, db.lowHealthStyle = true, true
	db.lowManaVisionStrength, db.lowManaVisionCalm = 1, 0.5
	fighting = true
	ns.RefreshManaVision()
	Check("in a fight: full strength", Near(State().strength, 1), State().strength)
	fighting = false
	ns.RefreshManaVision()
	Check("out of a fight: the calm share", Near(State().strength, 0.5), State().strength)
	db.lowManaVisionEdges = false
	ns.RefreshManaVision()
	Check("edges off: none", State().edgeAlpha == 0, State().edgeAlpha)
	db.lowManaVisionEdges = true

	-- The Health tab off: no health edges, the mana still.
	db[ns.VITALS_HEALTH_TAB] = false
	ns.RefreshManaVision()
	Check("Health tab off: health's switch reads off", not ns.Setting(ns.VITALS_HEALTH_TAB))
	Check("Health tab off: mana still shown", State().shown)
	db[ns.VITALS_HEALTH_TAB] = true

	-- The pages, built.
	local okV, errV = pcall(ns.OpenOptions, "Vitals Vision")
	Check("Vitals Vision page builds", okV, errV)
	Check("its Mana tab's Test button made", ns.manaVisionTestButton ~= nil)
	local okS, errS = pcall(ns.OpenOptions, "Vitals Style")
	Check("Vitals Style page builds", okS, errS)
	Check("its Mana tab's preview made", ns.manaVisionPreview ~= nil)
	local tabs = 0
	for _, each in ipairs(ns.tabContainers or {}) do
		if each.key == TAB or each.key == ns.VITALS_HEALTH_TAB or each.key == ns.VITALS_TABS.mana then tabs = tabs + 1 end
	end
	Check("Health, Mana and Style's Mana are tab containers", tabs == 3, tabs)

	-- The page's test: shown with the tab off too, then gone.
	db[TAB] = false
	ns.TestManaVision()
	Check("test: shown with the tab off", State().shown and State().mode == "test")
	Advance(4)
	local mid = State().alpha
	Check("test: halfway, part drained", mid > 0.2 and mid < 1, mid)
	Advance(7)
	Check("test: done, hidden again", not State().shown and ns.ManaVisionTestLeft() == nil)

	-- The in-game test, through.
	db[TAB] = false
	local before = {}
	for _, key in ipairs({ TAB, "lowHealth", "lowManaVisionStart", "lowManaAlways" }) do before[key] = db[key] end
	mana = 1000
	ns.HandleSlash("debug manavision")
	Advance(40) -- (to the spell's wait: the pages' shots, the 10 s test)
	mana = 980 -- (the spell)
	wow.Fire("UNIT_POWER_UPDATE", "player", "MANA")
	Advance(15)
	local log = CinematicDB.manaVisionTestLog
	local done = Has(log, "DONE: ")
	Check("test finished DONE", done ~= nil, done or (log and log[#log]))
	Check("test: no FAIL", done and done:find(" 0 fail", 1, true) ~= nil, Has(log, "verdict FAIL") or Has(log, "FAIL"))
	for key, value in pairs(before) do
		Check("put back " .. key, db[key] == value, tostring(db[key]) .. " vs " .. tostring(value))
	end
end

RunClient("forever")
RunClient("retail")
print(fails == 0 and "ALL PASS" or (fails .. " FAIL"))
if fails > 0 then os.exit(1) end
-- luacheck: pop
