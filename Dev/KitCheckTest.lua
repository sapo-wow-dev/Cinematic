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
--   5 shots     two paced screenshots, two seconds apart, in the log (PASS/FAIL)
--   6 skip      a SKIP verdict with why
-- At the end the setting is put back (checked in the log's put back line).
-- Into CinematicDB.kitCheckTestLog. Dev copy only.
local _, ns = ...

local SETTING = "kitCheckProbe" -- (a key nothing reads: safe to change)

ns.TestKit.Define({
	name = "kitcheck",
	key = "kitCheckTest",
	title = "Test kit check",
	about = "the test kit proving itself: probes, undo, CineMode off, waits, screenshots, nothing to do",
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
			r:Shot("second")
			local found = 0
			for i = before + 1, #CinematicDB.kitCheckTestLog do
				if CinematicDB.kitCheckTestLog[i]:find("screenshot", 1, true) then found = found + 1 end
			end
			r:Verdict(found == 2, found .. " screenshot lines (the files: check log opens them)")
		end },
		{ key = "skip", title = "a skip", run = function(r)
			r:Skip("nothing to check here, on purpose")
		end },
	},
})
