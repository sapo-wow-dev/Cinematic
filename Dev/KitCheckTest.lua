-- /cine debug kitcheck: the test kit (Dev/TestKit.lua) proving itself in
-- game, and the example to copy for a new test. Nothing for you to do: it
-- runs, takes two screenshots and says DONE. Steps:
--   1 probe     probe lines: a plain read, a secret one (Forever's mana,
--               rule forever.unitpower.mana-secret), an erroring call (PASS/FAIL)
--   2 set       a setting changed through the kit: its undo saved in
--               CinematicDB.kitCheckTestUndo before the change (PASS/FAIL)
--   3 cinemode  CineMode off while the test runs (PASS/FAIL)
--   4 wait      WaitFor with a check that comes true in 2 s, no time limit:
--               it resumes, with the value (PASS/FAIL)
--   5 shots     two paced screenshots, two seconds apart, in the log, the
--               second with a background behind a small frame (PASS/FAIL)
--   6 skip      a SKIP verdict with why
--   7 old       the old tests wrapped (Dev/TestKitWrap.lua): how many, none
--               missing; a stand-in with its own log and one writing into the
--               main log, through the real wrapper (PASS/FAIL)
-- At the end the setting is put back (checked in the log's put back line).
-- Into CinematicDB.kitCheckTestLog. Dev copy only.
local _, ns = ...

local SETTING = "kitCheckProbe" -- (a key nothing reads: safe to change)

ns.TestKit.Define({
	name = "kitcheck",
	key = "kitCheckTest",
	title = "Test kit check",
	about = "the test kit proving itself: probes, undo, CineMode off, waits, screenshots, nothing to do",
	-- needs = "A mob to fight", -- where to be or what to have: the test queue's picker shows it
	-- (none here: hands off). Say it whenever a step waits on you without words, r:WaitFor(nil, ...).
	settings = { SETTING },
	cvars = { "nameplateShowAll", "Sound_EnableAllSound" },
	context = function() return "kit check: no setup needed" end,
	steps = {
		{ key = "probe", title = "probe lines", run = function(r)
			local ok, level = r:Probe("UnitLevel(player)", UnitLevel, "player")
			r:Verdict(ok and type(level) == "number", "a plain read logs its number")
			local okMana, mana = r:Probe({ label = "UnitPower(player,0)", rule = "forever.unitpower.mana-secret" },
				UnitPower, "player", 0)
			r:Log(("mana read secret: %s (Forever expects true, retail false out of combat)"):format(
				tostring(okMana and issecretvalue ~= nil and issecretvalue(mana) or false)))
			local okBad = r:Probe("error on purpose", function() error("on purpose") end)
			r:Verdict(not okBad, "an erroring call logs ok=false with its error, the run goes on")
		end },
		{ key = "set", title = "a setting changed, undo saved", run = function(r)
			local was = ns.db[SETTING]
			r:Set(SETTING, "kit check")
			local undo = CinematicDB.kitCheckTestUndo
			local saved = undo and undo.settings and undo.settings[SETTING]
			r:Verdict(ns.db[SETTING] == "kit check" and saved ~= nil and (saved == "<nil>") == (was == nil),
				("set, undo holds %s (was %s)"):format(tostring(saved), tostring(was)))
		end },
		{ key = "cinemode", title = "CineMode off for the run", run = function(r)
			r:Sleep(1.5) -- (the kit's keep-off check runs once a second)
			r:Verdict(not ns.IsCineModeOn(), "CineMode off")
		end },
		{ key = "wait", title = "a wait with no time limit", run = function(r)
			local at = GetTime() + 2
			local value = r:WaitFor(nil, { check = function() return GetTime() >= at and "came true" end })
			r:Verdict(value == "came true", "WaitFor resumed with its value: " .. tostring(value))
		end },
		{ key = "shots", title = "two paced screenshots", run = function(r)
			local before = CinematicDB.kitCheckTestLog and #CinematicDB.kitCheckTestLog or 0
			r:Shot("first")
			local spot = CreateFrame("Frame", nil, UIParent)
			spot:SetSize(200, 60)
			spot:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
			r:Shot("second, a background behind a 200x60 frame", { behind = spot })
			spot:Hide()
			local found, backed = 0, false
			for i = before + 1, #CinematicDB.kitCheckTestLog do
				local line = CinematicDB.kitCheckTestLog[i]
				if line:find("screenshot", 1, true) then found = found + 1 end
				if line:find("background behind 1 of 1 frame", 1, true) then backed = true end
			end
			r:Verdict(found == 2, found .. " screenshot lines (the files: check log opens them)")
			r:Verdict(backed, "the second shot had its background: " .. tostring(backed))
		end },
		{ key = "skip", title = "a skip", run = function(r)
			r:Skip("nothing to check here, on purpose")
		end },
		{ key = "old", title = "the old tests wrapped (Dev/TestKitWrap.lua)", run = function(r)
			-- The last run's stand-in log, as the /reload since saved it: its
			-- closing line is the wrapper's at PLAYER_LOGOUT.
			local last = CinematicDB.kitCheckStandInLog
			if type(last) == "table" then
				local closing
				for _, line in ipairs(last) do if line:find("kit at /reload:", 1, true) then closing = line end end
				r:Verdict(closing ~= nil, "the last run's closing line at /reload: " .. tostring(closing))
			else
				r:Skip("no last run's stand-in log yet: the next kitcheck after a /reload checks its closing line")
			end
			local count, missing = ns.TestKit.WrapState()
			r:Verdict(count > 50 and #missing == 0, ("%d old tests wrapped at login, start function missing: %s"):format(
				count, #missing > 0 and table.concat(missing, ", ") or "none"))
			-- A stand-in with its own log, through the real wrapper.
			ns.KitCheckOwnStandIn = function(stop)
				if stop then table.insert(CinematicDB.kitCheckStandInLog, "stopped")
				else CinematicDB.kitCheckStandInLog = { "stand-in start" } end
			end
			ns.TestKit.WrapOld({ cmd = "kitcheck-own", fn = "KitCheckOwnStandIn", file = "KitCheckTest.lua",
				log = "kitCheckStandInLog" })
			ns.KitCheckOwnStandIn()
			ns.KitCheckOwnStandIn(true)
			ns.KitCheckOwnStandIn()
			local log, prev = CinematicDB.kitCheckStandInLog, CinematicDB.kitCheckStandInPrevLog
			local context = 0
			for _, line in ipairs(log) do if line:find("kit context: ", 1, true) then context = context + 1 end end
			r:Verdict(context > 0 and prev and prev[#prev] == "stopped",
				("own log: %d context line(s) on the new run, the run before kept (%s)"):format(context,
				prev and #prev .. " lines, last " .. tostring(prev[#prev]) or "NOT kept"))
			-- One writing into the main log, with the game's real ns.Log.
			ns.KitCheckMainStandIn = function() ns.Log("kitcheckmain", "a line from the stand-in") end
			ns.TestKit.WrapOld({ cmd = "kitcheckmain", fn = "KitCheckMainStandIn", file = "KitCheckTest.lua",
				category = "kitcheckmain" })
			ns.KitCheckMainStandIn()
			local copy, copied = CinematicDB.kitcheckmainKitLog, false
			for _, line in ipairs(copy or {}) do if line:find("a line from the stand-in", 1, true) then copied = true end end
			r:Verdict(copied, "main log line copied into kitcheckmainKitLog: " .. tostring(copied))
			-- (The own-log stand-in's log stays for the next run's closing-line
			-- check; the rest go.)
			CinematicDB.kitCheckStandInPrevLog, CinematicDB.kitcheckmainKitLog = nil, nil
		end },
	},
})
