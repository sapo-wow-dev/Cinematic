-- /cine debug resetcvars: does Reset Settings give your game settings back,
-- the game's Damage numbers above all, with two of Cinematic's features
-- holding them (fixes ca8a9fb and 553ff33, audit 2026-11-23; ledger
-- Tools/tests/reset-cvars.md)? The REAL reset, then your whole setup put
-- back: a copy of your saved settings (account and character) rides
-- through the reset in what it keeps, and goes back after it.
--   1 setup  Combat Text Style on with Your damage Cinematic's, CineMode's
--            Hide combat text on, CineMode on: both hold the game's Damage
--            numbers (off). Yours set to on for the run if they were off.
--   2 reset  ns.ResetAddon(true), its own reload held back (as Forever's
--            "Type /reload to finish"): yours right away, every set let go,
--            nothing of yours left saved; your copy put in what it kept.
--            Then the Reload button.
--   3 after  after the reload, Cinematic as a fresh reset left it: your
--            Damage numbers yours? (PASS/FAIL) Then your copy put back, and
--            the Reload button again.
--   4 back   your setup back: the profile, the profiles' count, and every
--            game setting Cinematic holds or saved as before step 2
--            (PASS/FAIL per one; yours: the saved value
--            while one of ours holds it). At the end the run's settings go back.
-- Don't touch the welcome window in step 3: the next reload takes it away.
-- Stopped midway (or /cine debug resetcvars restore): your copy goes back
-- and it asks to reload. Into CinematicDB.resetCvarsTestLog. Dev copy only.
local _, ns = ...

local KEY = "resetCvarsTest"
local BACKUP = KEY .. "Backup"
local DAMAGES = { "floatingCombatTextCombatDamage", "floatingCombatTextCombatDamage_v2" }

-- A deep copy (a table met twice is copied once, so both keys share it).
local function DeepCopy(source, seen)
	if type(source) ~= "table" then return source end
	seen = seen or {}
	if seen[source] then return seen[source] end
	local copy = {}
	seen[source] = copy
	for k, v in pairs(source) do copy[DeepCopy(k, seen)] = DeepCopy(v, seen) end
	return copy
end

local function SetByLabel(label)
	for _, set in ipairs(ns.cvarSets or {}) do
		if set.label == label then return set end
	end
end

-- The client's Damage numbers settings (one or both).
local function Damages()
	local list = {}
	for _, cvar in ipairs(DAMAGES) do
		if GetCVar(cvar) ~= nil then list[#list + 1] = cvar end
	end
	return list
end

-- Your value as Cinematic sees it: the saved one while a set holds it.
local function Yours(cvar)
	local saved = ns.db and ns.db.savedCVars and ns.db.savedCVars[cvar]
	if saved ~= nil and ns.CVarHolder(cvar) then return saved end
	return GetCVar(cvar)
end

-- Every game setting Cinematic holds or keeps a value of: the sets', the
-- saved ones, the Nameplates rows', Graphics+'s.
local function Watched()
	local seen, list = {}, {}
	local function Add(cvar)
		if type(cvar) == "string" and not seen[cvar] and GetCVar(cvar) ~= nil then
			seen[cvar] = true
			list[#list + 1] = cvar
		end
	end
	for _, set in ipairs(ns.cvarSets or {}) do
		for cvar in pairs(set.values or {}) do Add(cvar) end
	end
	for _, store in ipairs({ ns.db and ns.db.savedCVars, ns.db and ns.db.cvarsBefore,
		ns.chardb and ns.chardb.cvarsBefore, ns.db and ns.db.graphicsPlusSaved }) do
		if type(store) == "table" then
			for cvar in pairs(store) do Add(cvar) end
		end
	end
	table.sort(list)
	return list
end

local function ActiveSets()
	local names = {}
	for _, set in ipairs(ns.cvarSets or {}) do
		if set.active then names[#names + 1] = tostring(set.label) end
	end
	return names
end

local function Count(t)
	local n = 0
	for _ in pairs(type(t) == "table" and t or {}) do n = n + 1 end
	return n
end

-- Your copy back as the saved settings, the run's own lines kept: true if
-- there was one. Takes hold at the next reload.
local function PutCopyBack()
	local backup = CinematicDB and CinematicDB[BACKUP]
	if type(backup) ~= "table" or type(backup.db) ~= "table" then return false end
	local db = backup.db
	for _, suffix in ipairs({ "Log", "PrevLog", "Undo", "Resume" }) do
		db[KEY .. suffix] = CinematicDB[KEY .. suffix]
	end
	db[BACKUP] = nil
	CinematicDB = db
	if type(backup.char) == "table" then CinematicCharDB = backup.char end
	return true
end

ns.TestKit.Define({
	name = "resetcvars",
	key = KEY,
	title = "Reset gives game settings back",
	about = "the real Reset Settings with two features holding Damage numbers, then your setup put back",
	needs = "Out of fights",
	settings = { "combatTextStyle", "combatTextDamageBy", "hideCombatText" },
	cvars = DAMAGES,
	cineMode = true,
	context = function()
		local parts = {}
		for _, cvar in ipairs(Damages()) do
			parts[#parts + 1] = ("%s now %s yours %s holder %s left alone %s"):format(cvar, tostring(GetCVar(cvar)),
				tostring(Yours(cvar)), tostring(ns.CVarHolder(cvar) and ns.CVarHolder(cvar).label),
				tostring(ns.db.cvarsLeftAlone and ns.db.cvarsLeftAlone[cvar]))
		end
		return ("profile %s; %s; sets held: %s"):format(tostring(ns.ActiveProfile and ns.ActiveProfile()),
			table.concat(parts, "; "), table.concat(ActiveSets(), ", "))
	end,
	putBack = function(extra)
		local said = {}
		if PutCopyBack() then
			said[#said + 1] = "your saved settings copy put back (reload to load it)"
			if ns.ReloadOrAsk then
				C_Timer.After(1, function() ns.ReloadOrAsk("Reset test: your settings are put back. Reload to load them.") end)
			end
		end
		for _, cvar in ipairs(DAMAGES) do
			local was = extra["yours_" .. cvar]
			if was ~= nil and was ~= "<nil>" and ns.SetYourCVar then
				ns.SetYourCVar(cvar, was)
				said[#said + 1] = cvar .. " yours back to " .. tostring(was)
			end
			if extra["leftAlone_" .. cvar] and ns.KeepYourCVar then
				ns.KeepYourCVar(cvar)
				said[#said + 1] = cvar .. " Keep yours ticked again"
			end
		end
		return #said > 0 and table.concat(said, ", ") or "nothing of its own"
	end,
	steps = {
		{ key = "setup", title = "two features hold Damage numbers",
			proven = "resetcvars runs 1 (retail) + 2 (forever) 2026-11-23: both hold", run = function(r)
			local damages = Damages()
			if #damages == 0 then
				r:Skip("this client has no Damage numbers setting")
				return
			end
			for _, cvar in ipairs(damages) do
				if ns.db.cvarsLeftAlone and ns.db.cvarsLeftAlone[cvar] then
					r:Keep("leftAlone_" .. cvar, true)
					ns.UseOurCVar(cvar)
					r:Log("  " .. cvar .. ": Keep yours was ticked: Ours for the run")
				end
				local was = Yours(cvar)
				if was ~= "1" then
					r:Keep("yours_" .. cvar, was)
					ns.SetYourCVar(cvar, "1")
					r:Log(("  %s: yours set to 1 for the run (was %s)"):format(cvar, tostring(was)))
				end
			end
			-- (Each page and every switch above it on: ns.StyleOn and
			-- ns.Setting need the whole chain.)
			for _, key in ipairs({ "combatTextStyle", "hideCombatText" }) do
				local seen = {}
				while key and not seen[key] do
					seen[key] = true
					if ns.db[key] ~= true then r:Set(key, true) end
					key = ns.PageSwitchOf and ns.PageSwitchOf(key)
				end
			end
			if ns.db.styleGeneral ~= true then r:Set("styleGeneral", true) end
			r:Set("combatTextDamageBy", "ours")
			if ns.RefreshCombatTextStyle then ns.RefreshCombatTextStyle() end
			local page, cine = SetByLabel("Game's damage numbers off"), SetByLabel("Combat text off")
			r:WaitFor("Turn CineMode on and stay out of fights.",
				{ buttons = { { label = "CineMode on", fn = function()
					if not ns.IsCineModeOn() and Cinematic_ToggleCineMode then Cinematic_ToggleCineMode() end
				end } },
				check = function()
					return page and page.active and cine and cine.active and not InCombatLockdown() and "both held"
				end })
			for _, cvar in ipairs(damages) do
				r:Fields(cvar, { now = function() return GetCVar(cvar) end, yours = function() return Yours(cvar) end,
					holder = function() return ns.CVarHolder(cvar) and ns.CVarHolder(cvar).label end })
			end
			r:Verdict(page and page.active and cine and cine.active,
				"Combat Text Style and CineMode's combat text off both hold Damage numbers")
		end },
		{ key = "reset", title = "the real Reset Settings",
			proven = "resetcvars runs 1 (retail) + 2 (forever) 2026-11-23: yours right after, none held", run = function(r)
			local damages = Damages()
			if InCombatLockdown() then
				r:WaitFor("Leave the fight first.", { events = { "PLAYER_REGEN_ENABLED" } })
			end
			-- (Before: your value of every watched setting and the profile, for step 4.)
			local before = {}
			for _, cvar in ipairs(Watched()) do before[cvar] = Yours(cvar) end
			r:Keep("before", before)
			r:Keep("profile", ns.ActiveProfile and ns.ActiveProfile() or "?")
			r:Keep("profiles", Count(CinematicDB.profiles))
			r:Log(("  watched: %d game settings; sets held: %s"):format(Count(before), table.concat(ActiveSets(), ", ")))
			-- Your copy (the reset changes the old tables too), then the reset,
			-- its reload held back: nothing yields from here to the copy's move.
			local old, char = CinematicDB, CinematicCharDB
			local copy = DeepCopy(old)
			copy[BACKUP] = nil
			local charCopy = type(char) == "table" and DeepCopy(char) or nil
			local Reload = ns.Reload
			ns.Reload = function() end
			local ok, err = pcall(ns.ResetAddon, true)
			ns.Reload = Reload
			local kept = CinematicDB
			if kept == old then
				r:Fail("the reset didn't run: " .. tostring(err))
				return
			end
			if type(kept) ~= "table" then
				kept = { resetKept = true }
				CinematicDB = kept
			end
			for _, suffix in ipairs({ "Log", "PrevLog", "Undo" }) do kept[KEY .. suffix] = old[KEY .. suffix] end
			kept[BACKUP] = { db = copy, char = charCopy }
			r:Verdict(ok, "Reset Settings ran: " .. tostring(err or "no error"))
			-- Right away (fix 1: yours written, nothing to write ours back).
			for _, cvar in ipairs(damages) do
				r:Verdict(GetCVar(cvar) == "1", ("%s right after the reset: %s (yours 1)"):format(cvar, tostring(GetCVar(cvar))))
			end
			local held = ActiveSets()
			r:Verdict(#held == 0, "every set let go by the reset (fix 2): " .. (#held > 0 and table.concat(held, ", ") or "none held"))
			r:Verdict(Count(ns.db.savedCVars) == 0, ("nothing of yours left saved: %d"):format(Count(ns.db.savedCVars)))
			-- (A moment later: features still running on the old settings may
			-- hold them again till the reload; logged, not judged.)
			r:Sleep(1)
			for _, cvar in ipairs(damages) do
				r:Log(("  a second later %s = %s, holder %s, saved yours %s"):format(cvar, tostring(GetCVar(cvar)),
					tostring(ns.CVarHolder(cvar) and ns.CVarHolder(cvar).label), tostring(ns.db.savedCVars[cvar])))
			end
			r:WaitFor("Click Reload. (A welcome window comes up after it: leave it, the test puts your setup back.)",
				{ buttons = { { kind = "reload" } } })
		end },
		{ key = "after", title = "after the reset's reload",
			proven = "resetcvars runs 1 (retail) + 2 (forever) 2026-11-23: yours after the reload", run = function(r)
			local damages = Damages()
			r:Log(("  CinematicDB as the reset left it: profiles %d, your copy %s"):format(Count(CinematicDB.profiles),
				tostring(type(CinematicDB[BACKUP]) == "table")))
			for _, cvar in ipairs(damages) do
				r:Fields(cvar, { now = function() return GetCVar(cvar) end, yours = function() return Yours(cvar) end,
					holder = function() return ns.CVarHolder(cvar) and ns.CVarHolder(cvar).label end })
				r:Verdict(Yours(cvar) == "1", ("%s after the reload: yours %s (want 1)"):format(cvar, tostring(Yours(cvar))))
			end
			local back = PutCopyBack()
			r:Verdict(back, "your saved settings copy put back")
			if not back then return end
			r:WaitFor("Click Reload to load your setup again.", { buttons = { { kind = "reload" } } })
		end },
		{ key = "back", title = "your setup back",
			proven = "resetcvars runs 1 (retail) + 2 (forever) 2026-11-23: profile, profiles, every game setting back", run = function(r)
			r:Sleep(4) -- (the features hold their settings again: the page's two-second refresh)
			local undo = CinematicDB[KEY .. "Undo"]
			local extra = undo and undo.extra or {}
			r:Verdict(ns.ActiveProfile and ns.ActiveProfile() == extra.profile,
				("profile %s (was %s)"):format(tostring(ns.ActiveProfile and ns.ActiveProfile()), tostring(extra.profile)))
			r:Verdict(Count(CinematicDB.profiles) == extra.profiles,
				("profiles %d (was %s)"):format(Count(CinematicDB.profiles), tostring(extra.profiles)))
			r:Verdict(CinematicDB[BACKUP] == nil, "no copy left in your saved settings")
			local diffs, n = {}, 0
			for cvar, was in pairs(type(extra.before) == "table" and extra.before or {}) do
				n = n + 1
				if was ~= "<nil>" and Yours(cvar) ~= nil and Yours(cvar) ~= was then
					diffs[#diffs + 1] = ("%s %s -> %s"):format(cvar, tostring(was), tostring(Yours(cvar)))
				end
			end
			table.sort(diffs)
			r:Verdict(#diffs == 0, ("%d game settings yours as before step 2%s"):format(n - #diffs,
				#diffs > 0 and ("; changed: " .. table.concat(diffs, ", ")) or ""))
			for _, cvar in ipairs(Damages()) do
				r:Fields(cvar, { now = function() return GetCVar(cvar) end, yours = function() return Yours(cvar) end })
			end
		end },
	},
})
