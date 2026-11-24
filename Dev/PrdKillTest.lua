-- /cine debug prdkill: your personal resource bars through one kill, in
-- CineMode (a player's video, 2026-11-22: both bars vanished as the target
-- died mid-fight, ~25 s, with Personal resource bar on Always). Ledger:
-- Tools/tests/prd-kill.md. One thing to do: kill one mob. Steps:
--   1 ready   CineMode on, the player's Keep up (run 2: health row under 80%
--             in every column, Personal health bar's Always off, power row
--             always up and on Always, Wait at pull off; all put back after),
--             the game's display settings, which frames hold the bars, a shot
--   2 kill    you pull one mob and kill it, then stand still; every 0.1 s the
--             bars, your own nameplate (which frame, shown, alpha, ours,
--             reachable), the display frame and our stand-ins are logged when
--             they change, with every nameplate added / removed; 40 s after
--             the fight for the Calm Timer; a shot at the first drop
--   3 verdict whether the bars dropped while their rows wanted them up, and
--             what the log shows at that moment (which of the ledger's causes)
-- Into CinematicDB.prdKillTestLog. Dev copy only.
local _, ns = ...

local AFTER = 40 -- seconds watched after the fight

-- Run 2: the player's Keep up, from their profile (Caster 2, 2026-11-22).
-- In a fight their health is secret, so the health row's 80% goes to the
-- game's curve on PersonalResourceDisplayFrame (its alpha secret), while
-- our health stand-in is up for 3 s after each health change: the suspect
-- is the power bars let go (both rows' alphas at 1) and so fading with the
-- frame's curve.
local THEIRS = {
	prHealthPrd = 0.8, prHealthPrdCalm = 0, prHealthPrdAlways = 0.8,
	prHealthPrdLinkCalm = true, prHealthPrdLinkAlways = true,
	prPowerPrd = 1, prPowerPrdCalm = 0, prPowerPrdAlways = 1,
	prPowerPrdLinkCalm = true, prPowerPrdLinkAlways = false,
	fightWaitPull = false,
}
local MAX_LINES = 900

local watch -- this run's watcher: { ticker, events, last, lines, drops, ... }

local function Secret(value) return issecretvalue and issecretvalue(value) end
-- A read for the log: "secret", "err", "nil" or the value.
local function Read(fn, ...)
	local ok, value = pcall(fn, ...)
	if not ok then return "err" end
	if Secret(value) then return "secret" end
	if type(value) == "number" then return ("%.2f"):format(value) end
	return tostring(value)
end
local function Method(frame, name)
	if type(frame) ~= "table" or type(frame[name]) ~= "function" then return "-" end
	return Read(frame[name], frame)
end
local function Id(frame)
	if type(frame) ~= "table" then return "none" end
	local ok, name = pcall(frame.GetName, frame)
	if ok and type(name) == "string" and not Secret(name) then return name end
	return tostring(frame):gsub("table: ", "")
end

local function OwnPlate()
	return C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("player")
end
local function Entry(name)
	for _, entry in ipairs(ns.managed or {}) do
		if entry.name == name then return entry end
	end
end
local function EntryAlpha(name)
	local entry = Entry(name)
	return entry and ("%.2f"):format(entry.alpha or -1) or "none"
end

-- The bars that may be drawn: the display frame's and the own plate's.
local function Bars()
	local list = {}
	local display = _G.PersonalResourceDisplayFrame
	if type(display) == "table" then
		for _, field in ipairs({ "PowerBar", "AlternatePowerBar", "ClassFrameContainer", "HealthBarsContainer", "healthbar" }) do
			if type(display[field]) == "table" then list[#list + 1] = { "prd." .. field, display[field] } end
		end
	end
	local plate = OwnPlate()
	local unitFrame = type(plate) == "table" and plate.UnitFrame
	if type(unitFrame) == "table" then
		for _, field in ipairs({ "healthBar", "HealthBarsContainer", "powerBar", "PowerBar", "classPowerBar" }) do
			if type(unitFrame[field]) == "table" then list[#list + 1] = { "plate." .. field, unitFrame[field] } end
		end
	end
	local driver = _G.NamePlateDriverFrame
	if type(driver) == "table" then
		for _, field in ipairs({ "classNamePlatePowerBar", "classNamePlateAlternatePowerBar", "classNamePlateMechanicFrame" }) do
			if type(driver[field]) == "table" then list[#list + 1] = { "driver." .. field, driver[field] } end
		end
	end
	return list
end

-- A bar drawn: visible with some alpha (nil: can't tell, secret).
local function Drawn(bar)
	local okV, visible = pcall(bar.IsVisible, bar)
	if not okV or Secret(visible) then return nil end
	if not visible then return false end
	local okA, alpha = pcall(bar.GetEffectiveAlpha, bar)
	-- (Run 3: a bar's effective alpha came back nil, and the compare killed
	-- every sample of the run.)
	if not okA or Secret(alpha) or type(alpha) ~= "number" then return nil end
	return alpha > 0.05
end

local function BarLine(bar)
	return ("vis %s alpha %s eff %s ignore %s parent %s"):format(Method(bar, "IsVisible"), Method(bar, "GetAlpha"),
		Method(bar, "GetEffectiveAlpha"), Method(bar, "IsIgnoringParentAlpha"),
		Id(select(2, pcall(bar.GetParent, bar))))
end

local function Fighting()
	return InCombatLockdown() or ns.Flag(UnitAffectingCombat("player"))
end

-- The state now, one line, and whether the power / health bars are drawn.
local function State()
	local plate = OwnPlate()
	local unitFrame = type(plate) == "table" and plate.UnitFrame
	local display = _G.PersonalResourceDisplayFrame
	local power, health = {}, {}
	local parts = {}
	for _, item in ipairs(Bars()) do
		local name, bar = item[1], item[2]
		local drawn = Drawn(bar)
		local isPower = not (name:find("ealth") or name:find("healthbar"))
		local into = isPower and power or health
		if drawn == true then into.up = true elseif drawn == nil then into.unknown = true end
		-- (Shown but taking the display frame's fade, secret or under 1: the
		-- power bar then goes with the health bar's curve.)
		if isPower and name:sub(1, 4) == "prd." then
			local okV, visible = pcall(bar.IsVisible, bar)
			local okI, ignore = pcall(bar.IsIgnoringParentAlpha, bar)
			local okA, alpha = pcall(display.GetAlpha, display)
			if okV and not Secret(visible) and visible and okI and not Secret(ignore) and not ignore
				and okA and (Secret(alpha) or type(alpha) == "number" and alpha < 0.99) then
				into.follows = true
			end
		end
		parts[#parts + 1] = name .. " " .. BarLine(bar)
	end
	local target = UnitExists("target") and (ns.Flag(UnitIsDeadOrGhost("target")) and "dead" or "alive") or "none"
	local line = ("fight %s target %s | stand-ins: health %s power %s mana %s, display entry %s | plate %s shown %s alpha %s"
		.. " uf %s alpha %s ours %s reach %s ctx %s | prd shown %s vis %s alpha %s | %s"):format(
		tostring(Fighting()), target,
		EntryAlpha("CinematicPersonalResource"), EntryAlpha("CinematicPersonalPower"), EntryAlpha("CinematicPersonalMana"),
		EntryAlpha("PersonalResourceDisplayFrame"),
		Id(plate), Method(plate, "IsShown"), Method(plate, "GetAlpha"),
		Id(unitFrame), Method(unitFrame, "GetAlpha"),
		tostring(type(unitFrame) == "table" and unitFrame.cinematicAlpha), tostring(plate and ns.Reachable(plate)),
		Method(plate, "CanBeAccessedInContext"),
		Method(display, "IsShown"), Method(display, "IsVisible"), Method(display, "GetAlpha"),
		table.concat(parts, "; "))
		.. " | ours: " .. (ns.DescribePersonalPower and select(2, pcall(ns.DescribePersonalPower)) or "-")
	return line, power, health
end

local function Say(r, text)
	if not watch or watch.lines >= MAX_LINES then return end
	watch.lines = watch.lines + 1
	r:Log(("%6.2f %s"):format(GetTime() - watch.started, text))
end

local function StopWatch()
	if not watch then return end
	if watch.ticker then watch.ticker:Cancel() end
	if watch.events then watch.events:UnregisterAllEvents() end
	watch = nil
end

local function Sample(r)
	local line, power, health = State()
	if line ~= watch.last then
		watch.last = line
		Say(r, "state " .. line)
	end
	-- (A drop: a bar its row wants up isn't drawn. Power: its stand-in at 1.
	-- Health: its stand-in at 1.)
	local powerEntry, healthEntry = Entry("CinematicPersonalPower"), Entry("CinematicPersonalResource")
	local wantPower = powerEntry and (powerEntry.alpha or 0) >= 0.99
	local wantHealth = healthEntry and (healthEntry.alpha or 0) >= 0.99
	local now = GetTime()
	for kind, bars in pairs({ power = { power, wantPower }, health = { health, wantHealth } }) do
		local drawn = bars[1]
		local down = bars[2] and (drawn.follows or not drawn.up and not drawn.unknown)
		if down and not watch.down[kind] then
			watch.down[kind] = now
			watch.drops[#watch.drops + 1] = { kind = kind, at = now - watch.started, fight = Fighting(), line = line,
				follows = drawn.follows }
			Say(r, ("DROP %s bar %s while its row wants it up (fight %s)"):format(kind,
				drawn.follows and "let go, fading with the display frame (secret or under 1)" or "not drawn",
				tostring(Fighting())))
		elseif not down and watch.down[kind] then
			Say(r, ("BACK %s bar drawn again after %.1f s"):format(kind, now - watch.down[kind]))
			watch.down[kind] = nil
		end
	end
end

local function StartWatch(r)
	StopWatch()
	watch = { started = GetTime(), lines = 0, down = {}, drops = {}, plates = {}, ownPlates = {}, errs = {} }
	watch.ticker = C_Timer.NewTicker(0.1, function()
		if not watch then return end
		local ok, err = pcall(Sample, r)
		-- (Run 2 went quiet at 52 s: the sample's error, said once each.)
		if not ok and not watch.errs[tostring(err)] then
			watch.errs[tostring(err)] = true
			Say(r, "SAMPLE ERROR " .. tostring(err))
		end
	end)
	local events = CreateFrame("Frame")
	for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED",
		"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "CVAR_UPDATE" }) do
		pcall(events.RegisterEvent, events, event)
	end
	events:SetScript("OnEvent", function(_, event, unit)
		if not watch then return end
		if event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
			local plate = C_NamePlate.GetNamePlateForUnit(unit)
			local uf = type(plate) == "table" and plate.UnitFrame
			local isPlayer = ns.Flag(UnitIsUnit(unit, "player"))
			local was = plate and watch.plates[plate]
			if plate and event == "NAME_PLATE_UNIT_ADDED" then
				watch.plates[plate] = isPlayer and "player" or tostring(unit)
				if isPlayer then watch.ownPlates[plate] = true end
			end
			-- (Your own plate's, and the target's, always; others only near a drop.)
			Say(r, ("%s %s%s plate %s (last held %s) uf alpha %s ours %s reach %s"):format(
				event == "NAME_PLATE_UNIT_ADDED" and "ADDED" or "REMOVED", tostring(unit), isPlayer and " (YOU)" or "",
				Id(plate), tostring(was), Method(uf, "GetAlpha"), tostring(type(uf) == "table" and uf.cinematicAlpha),
				tostring(plate and ns.Reachable(plate))))
		elseif event == "CVAR_UPDATE" then
			if type(unit) == "string" and unit:lower():find("nameplate") then
				Say(r, "CVAR " .. unit .. " = " .. tostring(GetCVar(unit)))
			end
		else
			Say(r, event)
		end
	end)
	watch.events = events
end

local CVARS = { "nameplateShowSelf", "NameplatePersonalShowAlways", "NameplatePersonalShowInCombat",
	"NameplatePersonalShowWithTarget", "NameplatePersonalHideDelaySeconds", "nameplateShowAll" }

ns.TestKit.Define({
	name = "prdkill",
	key = "prdKillTest",
	title = "Resource bars through a kill",
	about = "your personal resource bars, own nameplate and our stand-ins logged through one kill in CineMode",
	needs = "One mob to kill that hits you",
	settings = { "personalResources", "prdKeepUp", "prHealthPrd", "prHealthPrdLinkCalm", "prHealthPrdLinkAlways",
		"prPowerPrd", "prPowerPrdLinkCalm", "prPowerPrdLinkAlways", "prPowerPrdAlways", "fightWaitPull" },
	cvars = CVARS,
	cineMode = true,
	context = function()
		return ("Always on Personal resource bar was %s, on Personal health bar %s, In combat on it %s, enemy %s, "
			.. "calmTime %s, fightWaitPull %s, "
			.. "Keep up health %s/%s/%s power %s/%s/%s"):format(
			tostring(ns.IsCineShowOn("prdpower")), tostring(ns.IsCineShowOn("prd")),
			tostring(ns.db.combatShow and ns.db.combatShow.prd), tostring(ns.db.enemyShow and ns.db.enemyShow.prd),
			tostring(ns.db.calmTime),
			tostring(ns.db.fightWaitPull), tostring(ns.db.prHealthPrd), tostring(ns.db.prHealthPrdCalm),
			tostring(ns.db.prHealthPrdAlways), tostring(ns.db.prPowerPrd), tostring(ns.db.prPowerPrdCalm),
			tostring(ns.db.prPowerPrdAlways))
	end,
	putBack = function(extra)
		local said = {}
		if extra.prdpowerShow ~= nil then
			ns.db.cineShow.prdpower = extra.prdpowerShow ~= "<nil>" and extra.prdpowerShow or nil
			if ns.ForgetCombatShown then ns.ForgetCombatShown() end
			said[#said + 1] = "Personal resource bar's Always put back"
		end
		for _, list in ipairs({ "combatShow", "enemyShow" }) do
			local was = extra[list .. "Prd"]
			if was ~= nil and type(ns.db[list]) == "table" then
				ns.db[list].prd = was ~= "<nil>" and was or nil
				said[#said + 1] = list .. ".prd put back"
			end
		end
		if extra.prdShow ~= nil then
			ns.db.cineShow.prd = extra.prdShow ~= "<nil>" and extra.prdShow or nil
			if ns.ForgetCombatShown then ns.ForgetCombatShown() end
			said[#said + 1] = "Personal health bar's Always put back"
		end
		if extra.cineTurnedOn and ns.IsCineModeOn and ns.IsCineModeOn() and Cinematic_ToggleCineMode then
			pcall(Cinematic_ToggleCineMode)
			said[#said + 1] = "CineMode off again"
		end
		return #said > 0 and table.concat(said, ", ") or "nothing of its own"
	end,
	finish = function() StopWatch() end,
	steps = {
		{ key = "ready", title = "CineMode on, the player's Keep up", run = function(r)
			r:Set("personalResources", true)
			r:Set("prdKeepUp", true)
			for key, value in pairs(THEIRS) do r:Set(key, value) end
			if ns.IsCineShowOn("prd") then
				r:Keep("prdShow", ns.db.cineShow.prd)
				ns.db.cineShow.prd = false
				if ns.ForgetCombatShown then ns.ForgetCombatShown() end
				r:Log("unticked Always on Personal health bar (put back after)")
			end
			-- (Run 3: theirs off in fights and with an enemy target too, so the
			-- fight doesn't keep the health row up: run 2 had them on.)
			for _, list in ipairs({ "combatShow", "enemyShow" }) do
				if type(ns.db[list]) == "table" and ns.db[list].prd ~= false then
					r:Keep(list .. "Prd", ns.db[list].prd)
					ns.db[list].prd = false
					r:Log("set " .. list .. ".prd = false (put back after)")
				end
			end
			if ns.ForgetCombatShown then ns.ForgetCombatShown() end
			if not ns.IsCineShowOn("prdpower") then
				r:Keep("prdpowerShow", ns.db.cineShow.prdpower)
				ns.db.cineShow.prdpower = true
				if ns.ForgetCombatShown then ns.ForgetCombatShown() end
				r:Log("ticked Always on Personal resource bar (put back after)")
			end
			if not ns.IsCineModeOn() then
				r:Keep("cineTurnedOn", true)
				Cinematic_ToggleCineMode()
				r:Sleep(1)
			end
			r:Verdict(ns.IsCineModeOn(), "CineMode on")
			r:Verdict(ns.IsCineShowOn("prdpower"), "Personal resource bar on Always")
			r:Verdict(not ns.IsCineShowOn("prd"), "Personal health bar not on Always (theirs)")
			r:Verdict(ns.db.combatShow and ns.db.combatShow.prd == false, "Personal health bar off In combat (theirs)")
			local selfOn = GetCVar("nameplateShowSelf")
			r:Verdict(selfOn ~= "0", "the game's Personal Resource Display is on (nameplateShowSelf " .. tostring(selfOn) .. ")")
			r:Fields("display settings", {
				ShowAlways = function() return GetCVar("NameplatePersonalShowAlways") end,
				InCombat = function() return GetCVar("NameplatePersonalShowInCombat") end,
				WithTarget = function() return GetCVar("NameplatePersonalShowWithTarget") end,
				HideDelay = function() return GetCVar("NameplatePersonalHideDelaySeconds") end,
			})
			r:Probe("own nameplate", function() return Id(OwnPlate()) end)
			r:Probe("PersonalResourceDisplayFrame shown",
				function() return _G.PersonalResourceDisplayFrame and _G.PersonalResourceDisplayFrame:IsShown() end)
			for _, item in ipairs(Bars()) do r:Log("bar " .. item[1] .. ": " .. BarLine(item[2])) end
			if ns.DescribePersonalPower then r:Log("ours: " .. ns.DescribePersonalPower()) end
			r:Sleep(1.5)
			local line = State()
			r:Log("state " .. line)
			r:Shot("your bars before the fight", { behind = _G.PersonalResourceDisplayFrame })
		end },
		{ key = "kill", title = "kill one mob", run = function(r)
			StartWatch(r)
			r:WaitFor("Pull one mob and kill it, let it hit you a few times",
				{ check = function() return Fighting() and "fighting" end })
			r:Prompt("Kill it, then stand still", "The test watches by itself until 40 s after the fight.")
			local shot, fightEnd = false, nil
			while true do
				if not shot and watch and #watch.drops > 0 then
					shot = true
					r:Shot("the first drop: " .. watch.drops[1].kind .. " bar", { behind = _G.PersonalResourceDisplayFrame })
					if ns.DescribePersonalPower then r:Log("ours at the drop: " .. ns.DescribePersonalPower()) end
				end
				if not Fighting() then
					if not fightEnd then
						fightEnd = GetTime()
						r:Prompt("Fight over: stand still", "Watching the Calm Timer by itself.", AFTER)
					end
					if GetTime() - fightEnd >= AFTER then break end
				elseif fightEnd then
					fightEnd = nil
					r:Prompt("Back in a fight: kill it, then stand still", "The test watches by itself.", nil)
				end
				r:Sleep(0.5)
			end
			if ns.DescribePersonalPower then r:Log("ours at the end: " .. ns.DescribePersonalPower()) end
			r:Shot("40 s after the fight", { behind = _G.PersonalResourceDisplayFrame })
		end },
		{ key = "verdict", title = "what the log shows", run = function(r)
			local drops = watch and watch.drops or {}
			local swapped = 0
			for _ in pairs(watch and watch.ownPlates or {}) do swapped = swapped + 1 end
			r:Log(("own nameplate frames seen for you during the run: %d"):format(swapped))
			if #drops == 0 then
				r:Verdict(true, "no drop: the bars stayed drawn whenever their rows wanted them (didn't reproduce)")
			end
			for _, drop in ipairs(drops) do
				r:Verdict(false, ("%s bar dropped at %.1f s (%s%s) while its row wanted it up: %s"):format(drop.kind, drop.at,
					drop.fight and "in the fight" or "after the fight",
					drop.follows and ", let go: fading with the display frame" or "", drop.line))
			end
			StopWatch()
		end },
	},
})
