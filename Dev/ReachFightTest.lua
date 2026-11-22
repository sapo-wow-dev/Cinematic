-- /cine debug reachfight: ns.Reachable (Checks.lua) and ns.NumPoints (Core.lua)
-- in a real fight (issue #7; ledger Tools/tests/reach-fight.md). One thing to
-- do: start a fight (and one Reload click when EllesmereUI is off). Steps:
--   1 setup    issue #7's setup: EllesmereUI (every EllesmereUI addon
--              installed) loaded. Off: turned on for this character, one
--              Reload click, and turned off again when the run ends (it
--              loads as before after your next /reload). Not installed: SKIP
--   2 before   out of a fight: every frame and region (EnumerateFrames and
--              their GetRegions) read once: forbidden, refusing GetParent
--              (ns.Reachable doesn't probe out of fights, so it must be 0:
--              PASS/FAIL), the cost of ns.Reachable and of a bare probe
--   3 fight    waits for a fight (no time limit), then the same in it:
--              which refuse (examples by owner), whether any frame Cinematic
--              fades or any nameplate is among them (it'd now be skipped:
--              PASS/FAIL), ns.Reachable against a fresh probe for every one
--              (PASS/FAIL), CanBeAccessedInContext and
--              HasAnyAccessRestrictions against the refusals, secret
--              GetNumPoints and ns.NumPoints giving 0 for them (PASS/FAIL),
--              ns.Reachable's cost cold and remembered, against the old
--              IsForbidden-only guard and a bare probe, over every plate
--   4 after    waits for the fight to end, then: refusals gone (PASS/FAIL)
-- Reads only (no SetAlpha or other writes on game frames). Into
-- CinematicDB.reachFightTestLog. Dev copy only.
local _, ns = ...

local CHUNK = 1500 -- objects read per frame in the survey (the walk is spread out)
local EXAMPLES = 12

local function Secret(value) return issecretvalue ~= nil and issecretvalue(value) end

-- Every frame (EnumerateFrames), then every frame's regions. (Forbidden
-- frames' regions aren't asked for.)
local function Collect(r)
	local frames, objects, owner = {}, {}, {}
	local ok, frame = pcall(EnumerateFrames)
	while ok and frame do
		frames[#frames + 1] = frame
		ok, frame = pcall(EnumerateFrames, frame)
	end
	if not ok then r:Log("EnumerateFrames stopped with an error after " .. #frames .. " frames: " .. tostring(frame)) end
	for i, f in ipairs(frames) do
		objects[#objects + 1] = f
		local okF, forbidden = pcall(f.IsForbidden, f)
		if okF and not Secret(forbidden) and not forbidden then
			local okR, regions = pcall(function() return { f:GetRegions() } end)
			if okR then
				for _, region in ipairs(regions) do
					objects[#objects + 1] = region
					owner[region] = f
				end
			end
		end
		if i % CHUNK == 0 then r:Sleep(0) end
	end
	return frames, objects, owner
end

local function NameOf(object)
	local ok, name = pcall(function() return object:GetDebugName() end)
	if ok and type(name) == "string" and not Secret(name) and name ~= "" then return name end
	return nil
end

-- Microseconds per call of fn over the list (not yielding: one stretch).
local function Time(list, fn)
	if #list == 0 then return 0 end
	local start = debugprofilestop()
	for i = 1, #list do fn(list[i]) end
	return (debugprofilestop() - start) * 1000 / #list
end
local function Probe(object) return (pcall(object.GetParent, object)) end

local function Plates()
	local list = {}
	local ok, plates = pcall(C_NamePlate.GetNamePlates)
	for _, plate in ipairs(ok and type(plates) == "table" and plates or {}) do
		list[#list + 1] = plate
		if type(plate.UnitFrame) == "table" then list[#list + 1] = plate.UnitFrame end
	end
	return list
end

local managedSet
local function Managed()
	managedSet = {}
	for _, entry in ipairs(ns.managed or {}) do
		if entry.frame then managedSet[entry.frame] = entry.name or entry.group or "?" end
	end
	return managedSet
end

-- One reading of everything: counts, examples, and the checks' agreement.
local function Survey(r, objects, owner, inFight)
	local s = { total = #objects, forbidden = 0, secretForbidden = 0, refuse = 0, disagree = 0,
		cbaFalse = 0, cbaSecret = 0, cbaCaught = 0, cbaMissed = 0, cbaFalseAlarm = 0, cbaNone = 0,
		restr = 0, restrCaught = 0, restrFalseAlarm = 0,
		secretPoints = 0, pointsNotZero = 0, managedSkipped = 0, platesSkipped = 0, examples = {}, pointExamples = {} }
	local managed = Managed()
	local plateSet = {}
	for _, object in ipairs(Plates()) do plateSet[object] = true end
	for i, object in ipairs(objects) do
		local okF, forbidden = pcall(object.IsForbidden, object)
		if okF and Secret(forbidden) then
			s.secretForbidden = s.secretForbidden + 1
		elseif okF and forbidden then
			s.forbidden = s.forbidden + 1
		else
			local reached = Probe(object)
			if not reached then
				s.refuse = s.refuse + 1
				local by = owner[object]
				local where = managed[object] and ("FADED " .. managed[object])
					or plateSet[object] and "NAMEPLATE"
					or by and ("region of " .. (NameOf(by) or "an unnamed frame"))
					or (NameOf(object) or "an unnamed frame")
				if managed[object] then s.managedSkipped = s.managedSkipped + 1 end
				if plateSet[object] then s.platesSkipped = s.platesSkipped + 1 end
				if #s.examples < EXAMPLES then s.examples[#s.examples + 1] = where end
			end
			if ns.Reachable(object) ~= reached then s.disagree = s.disagree + 1 end
			-- (The game's own checks: would they have told ahead?)
			if type(object.CanBeAccessedInContext) == "function" then
				local okC, can = pcall(object.CanBeAccessedInContext, object)
				if not okC then
					s.cbaNone = s.cbaNone + 1
				elseif Secret(can) then
					s.cbaSecret = s.cbaSecret + 1
				elseif can == false then
					s.cbaFalse = s.cbaFalse + 1
					if reached then s.cbaFalseAlarm = s.cbaFalseAlarm + 1 else s.cbaCaught = s.cbaCaught + 1 end
				elseif not reached then
					s.cbaMissed = s.cbaMissed + 1
				end
			else
				s.cbaNone = s.cbaNone + 1
			end
			if type(object.HasAnyAccessRestrictions) == "function" then
				local okH, has = pcall(object.HasAnyAccessRestrictions, object)
				if okH and not Secret(has) and has then
					s.restr = s.restr + 1
					if reached then s.restrFalseAlarm = s.restrFalseAlarm + 1 else s.restrCaught = s.restrCaught + 1 end
				end
			end
			if reached and type(object.GetNumPoints) == "function" then
				local okN, count = pcall(object.GetNumPoints, object)
				if okN and Secret(count) then
					s.secretPoints = s.secretPoints + 1
					if #s.pointExamples < EXAMPLES then
						local by = owner[object]
						s.pointExamples[#s.pointExamples + 1] = (managed[object] and "FADED " or "")
							.. (NameOf(object) or by and ("region of " .. (NameOf(by) or "an unnamed frame")) or "an unnamed frame")
					end
					if ns.NumPoints(object) ~= 0 then s.pointsNotZero = s.pointsNotZero + 1 end
				end
			end
		end
		if i % CHUNK == 0 then r:Sleep(0) end
	end
	s.stillInFight = InCombatLockdown()
	r:Log(("%s: %d objects, %d forbidden, %d with a secret IsForbidden, %d refuse GetParent, ns.Reachable differs from a fresh probe on %d"):format(
		inFight and "in the fight" or "out of a fight", s.total, s.forbidden, s.secretForbidden, s.refuse, s.disagree))
	r:Log(("  refusing: %d faded by Cinematic, %d nameplate parts; examples: %s"):format(s.managedSkipped,
		s.platesSkipped, #s.examples > 0 and table.concat(s.examples, "; ") or "none"))
	r:Log(("  CanBeAccessedInContext: false on %d (caught %d refusals, %d false alarms), missed %d, secret %d, not there or erroring %d"):format(
		s.cbaFalse, s.cbaCaught, s.cbaFalseAlarm, s.cbaMissed, s.cbaSecret, s.cbaNone))
	r:Log(("  HasAnyAccessRestrictions: true on %d (caught %d refusals, %d false alarms)"):format(
		s.restr, s.restrCaught, s.restrFalseAlarm))
	r:Log(("  GetNumPoints secret on %d, ns.NumPoints not 0 on %d of them; examples: %s"):format(s.secretPoints,
		s.pointsNotZero, #s.pointExamples > 0 and table.concat(s.pointExamples, "; ") or "none"))
	return s
end

-- The cost lines: ns.Reachable over every object that isn't forbidden, twice
-- (cold, then remembered: in a fight the first pass probes), a bare probe,
-- and every nameplate part 100 times.
local function Costs(r, objects, label)
	local open = {}
	for _, object in ipairs(objects) do
		local okF, forbidden = pcall(object.IsForbidden, object)
		if okF and not Secret(forbidden) and not forbidden then open[#open + 1] = object end
	end
	local reach = function(object) ns.Reachable(object) end
	local cold = Time(open, reach)
	local warm = Time(open, reach)
	local bare = Time(open, Probe)
	local old = Time(open, function(object) return not (object.IsForbidden and object:IsForbidden()) end)
	local plates = Plates()
	local start = debugprofilestop()
	for _ = 1, 100 do for i = 1, #plates do ns.Reachable(plates[i]) end end
	local platePass = (debugprofilestop() - start) / 100
	r:Log(("cost %s: ns.Reachable %.2f us a call cold, %.2f us remembered, the old IsForbidden-only guard %.2f us, a bare GetParent probe %.2f us (%d objects); %d nameplate parts: %.4f ms a pass"):format(
		label, cold, warm, old, bare, #open, #plates, platePass))
	return { cold = cold, warm = warm, old = old, bare = bare, plates = #plates, platePass = platePass }
end

ns.TestKit.Define({
	name = "reachfight",
	key = "reachFightTest",
	title = "Reachable in a fight",
	about = "ns.Reachable and ns.NumPoints in a real fight: what refuses, what we'd skip, what it costs",
	context = function()
		return ("EllesmereUIChat loaded: %s, nameplates now: %d, managed frames: %d"):format(
			tostring(C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("EllesmereUIChat") or false),
			#Plates(), #(ns.managed or {}))
	end,
	putBack = function(extra)
		local names = extra.enabled
		if type(names) ~= "table" or not (C_AddOns and C_AddOns.DisableAddOn) then return "nothing to put back" end
		-- (No character argument: on Forever the name doesn't reach this
		-- character, rule forever.addons.enable-no-character.)
		for _, name in ipairs(names) do pcall(C_AddOns.DisableAddOn, name) end
		if C_AddOns.SaveAddOns then pcall(C_AddOns.SaveAddOns) end
		return ("turned off again for this character: %s (they stay loaded till your next /reload)"):format(table.concat(names, ", "))
	end,
	steps = {
		{ key = "setup", title = "EllesmereUI loaded (issue #7's setup)", run = function(r)
			if not (C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetAddOnInfo and C_AddOns.EnableAddOn) then
				r:Skip("no C_AddOns on this client: the fight runs with what's loaded")
				return
			end
			local suite, off = {}, {}
			for i = 1, C_AddOns.GetNumAddOns() do
				local name = C_AddOns.GetAddOnInfo(i)
				if type(name) == "string" and name:find("^EllesmereUI") then
					suite[#suite + 1] = name
					if not C_AddOns.IsAddOnLoaded(name) then off[#off + 1] = name end
				end
			end
			if #suite == 0 then
				r:Skip("EllesmereUI isn't installed for this client: the fight runs with Cinematic alone")
				return
			end
			if #off == 0 then
				r:Pass(("EllesmereUI loaded already: %d addons"):format(#suite))
				return
			end
			-- (No character argument, then SaveAddOns: rule forever.addons.enable-no-character.)
			for _, name in ipairs(off) do C_AddOns.EnableAddOn(name) end
			if C_AddOns.SaveAddOns then pcall(C_AddOns.SaveAddOns) end
			r:Keep("enabled", off)
			local okState, state = pcall(C_AddOns.GetAddOnEnableState, "EllesmereUIChat")
			r:Log(("turned on for this run: %s; EllesmereUIChat enable state now %s (2 = on)"):format(
				table.concat(off, ", "), okState and tostring(state) or "?"))
			r:WaitFor("Click Reload. EllesmereUI comes on for this test (issue #7's setup) and goes off again when it ends.",
				{ buttons = { { kind = "reload" } }, check = function() return false end })
		end },
		{ key = "before", title = "out of a fight", run = function(r)
			-- (Did the setup take? Run 2 lost its point here: EnableAddOn with a
			-- character name did nothing on Forever.)
			local chat = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("EllesmereUIChat")
			local loadable, reason
			if C_AddOns and C_AddOns.GetAddOnInfo then
				local _
				_, _, _, loadable, reason = C_AddOns.GetAddOnInfo("EllesmereUIChat")
			end
			if loadable == nil and reason == nil and not chat then
				r:Log("EllesmereUIChat isn't installed: the fight runs with what's loaded")
			else
				r:Verdict(chat and true or false, ("EllesmereUIChat loaded for the fight: %s (loadable %s, reason %s)"):format(
					tostring(chat), tostring(loadable), tostring(reason)))
			end
			if InCombatLockdown() then
				r:WaitFor("Leave the fight first", { check = function() return not InCombatLockdown() end })
			end
			local _, objects, owner = Collect(r)
			Costs(r, objects, "out of a fight")
			local s = Survey(r, objects, owner, false)
			r:Verdict(s.refuse == 0, ("no object refuses GetParent out of a fight (ns.Reachable doesn't probe then): %d do"):format(s.refuse))
		end },
		{ key = "fight", title = "in a fight", run = function(r)
			r:WaitFor("Start a fight with any mob, near a few others if you can (more nameplates). The test does the rest.",
				{ check = function() return InCombatLockdown() end })
			r:Sleep(1)
			r:Log(("ns.Reachable asks %s in fights"):format(type(UIParent.CanBeAccessedInContext) == "function"
				and "CanBeAccessedInContext (no probe)" or "a GetParent probe (no CanBeAccessedInContext here)"))
			local _, objects, owner = Collect(r)
			local cost = Costs(r, objects, "in the fight")
			local s = Survey(r, objects, owner, true)
			if not s.stillInFight then
				r:Skip("the fight ended during the walk: start a longer one (a tougher mob, or a few at once) and run step 2 again")
				return
			end
			r:Verdict(s.managedSkipped == 0 and s.platesSkipped == 0,
				("nothing Cinematic fades and no nameplate refuses (they'd be skipped): %d faded frames, %d plate parts"):format(
				s.managedSkipped, s.platesSkipped))
			r:Verdict(s.disagree == 0, ("ns.Reachable agrees with a fresh probe on every object: %d differ"):format(s.disagree))
			r:Verdict(s.pointsNotZero == 0, ("ns.NumPoints gives 0 for every secret count (%d secret): %d don't"):format(
				s.secretPoints, s.pointsNotZero))
			r:Verdict(cost.warm < 1 and cost.platePass < 0.05,
				("cost: remembered call %.2f us (under 1), %d plate parts %.4f ms a pass (under 0.05)"):format(
				cost.warm, cost.plates, cost.platePass))
			if s.refuse == 0 then
				r:Log("nothing refused in this fight: the rule stays inferred (issue #7 had EllesmereUI's chat dock)")
			end
		end },
		{ key = "after", title = "after the fight", run = function(r)
			r:WaitFor("Finish the fight. Nothing else to do.", { check = function() return not InCombatLockdown() end })
			r:Prompt("Reading every frame after the fight, a few seconds. Please don't reload yet.")
			r:Sleep(0.5)
			local _, objects, owner = Collect(r)
			local s = Survey(r, objects, owner, false)
			r:Verdict(s.refuse == 0, ("refusals gone after the fight: %d still refuse"):format(s.refuse))
		end },
	},
})
