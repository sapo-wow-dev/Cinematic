-- The old tests' wrapper (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/testkitwrap.lua < /dev/null
-- Dev/TestKitWrap.lua on a stand-in game (Forever, then retail): every old
-- test in its list with a log is found and wrapped at login; a stand-in test
-- with its own log gets the kit's context lines on each fresh start, its run
-- before kept in <x>PrevLog, nothing added by a stop typed mid-run, its
-- return values passed through; a stand-in writing into the main log gets
-- its lines copied into <cmd>KitLog with the context first; at logout each
-- started one gets its closing errors / blocked line; /cine debug kit lists
-- the old tests. PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212 431
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end
local function Has(log, pattern)
	for _, line in ipairs(log or {}) do
		if line:find(pattern) then return line end
	end
end

local function RunClient(client)
	print("== " .. client)
	local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
	C_Timer.After = function(_, fn) fn() end

	-- Every listed old test with a log is there to wrap (a renamed start
	-- function would leave it unwrapped without a word).
	local missing = {}
	for _, entry in ipairs(ns.TestKitOld) do
		if (entry.log or entry.category) and type(ns[entry.fn]) ~= "function" then
			missing[#missing + 1] = entry.cmd .. " (ns." .. entry.fn .. ")"
		end
	end
	Check("every old test's start function is there", #missing == 0, table.concat(missing, ", "))

	-- A stand-in with its own log.
	local calls = 0
	ns.StandInOwnTest = function(stop)
		calls = calls + 1
		if stop then
			CinematicDB.standInLog[#CinematicDB.standInLog + 1] = "stopped"
		else
			CinematicDB.standInLog = { "start run " .. calls }
		end
		return "back", 2
	end
	Check("stand-in wrapped", ns.TestKit.WrapOld({ cmd = "standin", fn = "StandInOwnTest", file = "x.lua", log = "standInLog" }))
	local a, b = ns.StandInOwnTest()
	Check("return values passed through", a == "back" and b == 2, tostring(a) .. " " .. tostring(b))
	local log = CinematicDB.standInLog
	Check("context lines on a fresh start", Has(log, "kit: /cine debug standin") and Has(log, "kit context: ") ~= nil)
	Check("the test's own first line kept first", log[1] == "start run 1", log[1])
	local lines = #log
	ns.StandInOwnTest(true)
	Check("a stop adds no context", #CinematicDB.standInLog == lines + 1, #CinematicDB.standInLog)
	ns.StandInOwnTest()
	Check("the run before kept", CinematicDB.standInPrevLog and CinematicDB.standInPrevLog[1] == "start run 1"
		and Has(CinematicDB.standInPrevLog, "^stopped") ~= nil)
	Check("new run has its context", Has(CinematicDB.standInLog, "kit context: ") ~= nil)

	-- A stand-in writing into the main log.
	ns.StandInMainTest = function() ns.Log("standincat", "hello from the test") end
	Check("main-log stand-in wrapped", ns.TestKit.WrapOld({ cmd = "standinmain", fn = "StandInMainTest", file = "y.lua",
		category = "standincat" }))
	ns.Log("standincat", "before the start: not copied")
	ns.StandInMainTest()
	local kit = CinematicDB.standinmainKitLog
	Check("main-log lines copied", Has(kit, "standincat: hello from the test") ~= nil)
	Check("not before the start", Has(kit, "not copied") == nil)
	Check("context first", kit and kit[1] and kit[1]:find("kit: /cine debug standinmain", 1, true) ~= nil, kit and kit[1])
	Check("still in the main log", Has(ns.db.log, "hello from the test") ~= nil)
	ns.StandInMainTest()
	Check("typed again noted, same session", Has(CinematicDB.standinmainKitLog, "typed again") ~= nil)

	-- At logout: the closing line on both.
	wow.Fire("PLAYER_LOGOUT")
	Check("closing line, own log", Has(CinematicDB.standInLog, "kit at /reload: errors %+%d+, blocked %+%d+") ~= nil)
	Check("closing line, main-log copy", Has(CinematicDB.standinmainKitLog, "kit at /reload:") ~= nil)

	-- The list.
	local printed = {}
	local oldPrint = print
	print = function(...) printed[#printed + 1] = table.concat({ ... }, " ") end
	ns.Print = function(text) printed[#printed + 1] = text end
	ns.TestKitRun("kit")
	print = oldPrint
	local listed, header = false, false
	for _, line in ipairs(printed) do
		if line:find("favorites - FavoritesTest.lua", 1, true) then listed = true end
		if line:find("old tests (", 1, true) then header = true end
	end
	Check("/cine debug kit lists the old tests", listed and header)
end

RunClient("forever")
RunClient("retail")
print(fails == 0 and "all passed" or (fails .. " failed"))
if fails > 0 then os.exit(1) end
-- luacheck: pop
