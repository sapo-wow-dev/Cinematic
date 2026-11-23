-- /cine debug tooltipnowait: the Tooltips page's No wait for list (Quest
-- objective mobs) in a fight on WoW Forever, where the tooltip's own unit
-- reads secret (ledger Tools/tests/tooltip-no-wait.md). What to do: put the
-- mouse on a mob you need for a quest, then attack it and move the mouse off
-- it and back on during the fight. Steps:
--   1 before   out of a fight, the mouse on a quest mob: every way to tell
--              which unit the tooltip is about read once (probe lines), the
--              No wait answer and its route (PASS/FAIL: a quest mob skips)
--   2 fight    in the fight, the tooltip filled again (mouse off and back
--              on): the same reads; the answer and route now, against what
--              the old code gave (only the tooltip's own unit); the wait
--              state over 3 seconds and how often the tooltip was filled
--              again; a screenshot of the tooltip (PASS/FAIL)
-- Into CinematicDB.tooltipNoWaitTestLog. Dev copy only.
local _, ns = ...

local function Secret(value) return issecretvalue ~= nil and issecretvalue(value) end

-- The plate token that is the mouseover unit, or nil.
local function PlateOfMouseover()
	local ok, plates = pcall(C_NamePlate.GetNamePlates)
	for _, plate in ipairs(ok and type(plates) == "table" and plates or {}) do
		local token = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
		local okSame, same = pcall(UnitIsUnit, "mouseover", token)
		if type(token) == "string" and okSame and not Secret(same) and same then return token end
	end
	return nil
end

-- Each plate's token (both fields) and UnitIsUnit with the mouseover, one line.
local function PlateTokens(r)
	local ok, plates = pcall(C_NamePlate.GetNamePlates)
	local parts = {}
	for i, plate in ipairs(ok and type(plates) == "table" and plates or {}) do
		local field, frameUnit = plate.namePlateUnitToken, plate.UnitFrame and plate.UnitFrame.unit
		local token = field or frameUnit
		local okSame, same = pcall(UnitIsUnit, "mouseover", token)
		parts[#parts + 1] = ("%d field=%s frame=%s same=%s"):format(i, tostring(field), tostring(frameUnit),
			okSame and (Secret(same) and "SECRET" or tostring(same)) or "error")
		if i >= 8 then break end
	end
	r:Log("plates: " .. (#parts > 0 and table.concat(parts, " | ") or "none"))
end

-- Every read the No wait list could go by, one probe line each.
local function ReadAll(r)
	r:Probe("GameTooltip:GetUnit()", function() return GameTooltip:GetUnit() end)
	r:Fields("tooltip data", {
		type = function() local d = GameTooltip:GetTooltipData() return d and d.type end,
		guid = function() local d = GameTooltip:GetTooltipData() return d and d.guid end,
		owner = function() local o = GameTooltip:GetOwner() return o and (o:GetName() or "unnamed") end,
		ownerUnit = function() local o = GameTooltip:GetOwner() return o and o.unit end,
		line1 = function() return GameTooltipTextLeft1:GetText() end,
		lines = function() return GameTooltip:NumLines() end,
	})
	r:Fields("mouseover", {
		exists = function() return UnitExists("mouseover") end,
		guid = function() return UnitGUID("mouseover") end,
		name = function() return UnitName("mouseover") end,
		dead = function() return UnitIsDead("mouseover") end,
		attack = function() return UnitCanAttack("player", "mouseover") end,
		isTarget = function() return UnitIsUnit("mouseover", "target") end,
		related = function() return C_QuestLog.UnitIsRelatedToActiveQuest("mouseover") end,
	})
	local plate = PlateOfMouseover()
	r:Log("mouseover's plate token: " .. tostring(plate))
	PlateTokens(r)
	-- (The tooltip's own token against the mouseover: a plate's, as hovered.)
	pcall(function()
		local _, unit = GameTooltip:GetUnit()
		if type(unit) == "string" and not Secret(unit) then
			r:Probe("UnitIsUnit(mouseover, " .. unit .. ")", UnitIsUnit, "mouseover", unit)
		end
	end)
	-- The unit's tooltip lines as the quest check reads them (C_TooltipInfo).
	pcall(function()
		local data = C_TooltipInfo.GetUnit("mouseover")
		local lines = data and data.lines
		if Secret(lines) or type(lines) ~= "table" then
			r:Log("C_TooltipInfo.GetUnit(mouseover) lines: " .. (Secret(lines) and "SECRET" or type(lines)))
			return
		end
		for i, line in ipairs(lines) do
			r:Fields("info line " .. i, {
				type = function() return line.type end,
				text = function() return line.leftText end,
				completed = function() return line.completed end,
			})
		end
	end)
	r:Probe("ns.IsQuestMob(mouseover)", ns.IsQuestMob, "mouseover")
	r:Probe("ns.IsQuestMob(target)", ns.IsQuestMob, "target")
	if plate then r:Probe("ns.IsQuestMob(" .. plate .. ")", ns.IsQuestMob, plate) end
	if ns.QuestieObjectiveMob and ns.AddonUp("Questie") then
		r:Probe("ns.QuestieObjectiveMob(mouseover)", ns.QuestieObjectiveMob, "mouseover")
	end
	if ns.DescribeQuestMob then r:Probe("ns.DescribeQuestMob(mouseover)", ns.DescribeQuestMob, "mouseover") end
end

-- The game's last No wait answer (as the tooltip was filled), then asked now.
local function Answer(r, label)
	local last = ns.tooltipNoWaitLast
	r:Log(("%s, as filled: yes %s | route %s | tried %s | in fight %s | fills within a second %s | %.1f s ago"):format(
		label, tostring(last and last.yes), tostring(last and last.route), tostring(last and last.tried),
		tostring(last and last.fight), tostring(last and last.calls), last and GetTime() - last.at or -1))
	local okNow, now = r:Probe("SkipsWait(GameTooltip) now", ns.TooltipSkipsWait, GameTooltip)
	return last, okNow and now
end

-- The mouse on an enemy with its tooltip up.
local function Hovering()
	local okE, exists = pcall(UnitExists, "mouseover")
	local okA, attack = pcall(UnitCanAttack, "player", "mouseover")
	return okE and okA and not Secret(exists) and exists and not Secret(attack) and attack
		and GameTooltip:IsShown()
end

-- The fight check (steps fight and cine): waits for the tooltip filled in a
-- fight with the mouse on an enemy, reads everything, then watches 3 s.
local function FightCheck(r)
	r:Set("handleTooltips", true)
	r:Set("tooltipNoWaitQuest", true)
	if (ns.db.tooltipFullAfter or 0) <= 0 then r:Set("tooltipFullAfter", 2) end
	-- (UPDATE_MOUSEOVER_UNIT fires on a unit only, never on leaving one: run 1
	-- waited forever on "moved off". 4 s hovered in the fight with no fill
	-- wakes it too: the fill hook didn't run.)
	local fightAt, hoverSince
	local woke = r:WaitFor("Attack a quest mob and keep the mouse on it", { check = function()
		if not InCombatLockdown() then
			fightAt, hoverSince = nil, nil
			return false
		end
		fightAt = fightAt or GetTime()
		if not Hovering() then
			hoverSince = nil
			return false
		end
		hoverSince = hoverSince or GetTime()
		local last = ns.tooltipNoWaitLast
		if last and last.fight and last.at >= fightAt then return "filled in the fight" end
		return GetTime() - hoverSince >= 4 and "hovered 4 s in the fight, no fill"
	end })
	if woke ~= "filled in the fight" then
		r:Log("no No wait answer made in the fight: the unit fill hook didn't run while hovered")
	end
	ReadAll(r)
	local last = Answer(r, "in the fight")
	r:Log(("old code (the tooltip's own unit only) would skip: %s | new: %s by %s"):format(
		tostring(last and last.route == "tooltip"), tostring(last and last.yes), tostring(last and last.route)))
	r:Verdict(last and last.fight and last.yes, "in the fight the quest mob's tooltip skipped the wait (route "
		.. tostring(last and last.route) .. ", tried " .. tostring(last and last.tried) .. ")")
	local held = true
	for i = 1, 6 do
		r:Sleep(0.5)
		local okS, look, noWait, counting = pcall(ns.TooltipWaitState)
		local shown = GameTooltip:IsShown()
		if shown and not (okS and look) then held = false end
		r:Log(("+%.1fs: After look %s | no wait %s | countdown %s | shown %s | fills within a second %s"):format(
			i * 0.5, tostring(okS and look), tostring(noWait), tostring(counting), tostring(shown),
			tostring(ns.tooltipNoWaitLast and ns.tooltipNoWaitLast.calls)))
		if i == 2 then r:Shot("the quest mob's tooltip in the fight", { behind = GameTooltip }) end
	end
	r:Verdict(held, "while shown, the tooltip kept the After look for 3 s: " .. tostring(held))
end

ns.TestKit.Define({
	name = "tooltipnowait",
	key = "tooltipNoWaitTest",
	title = "Tooltips: No wait for quest mobs in a fight",
	about = "the No wait for list (Quest objective mobs) out of and in a fight",
	needs = "A mob you need for a quest nearby",
	settings = { "handleTooltips", "tooltipNoWaitQuest", "tooltipFullAfter" },
	cineMode = true, -- (step cine wants it on; the fight steps don't care)
	putBack = function(extra)
		if extra and extra.cineTurnedOn and ns.IsCineModeOn() then
			pcall(Cinematic_ToggleCineMode)
			return "CineMode off again"
		end
		return ""
	end,
	context = function()
		return ("questie up %s"):format(tostring(ns.AddonUp and ns.AddonUp("Questie")))
	end,
	steps = {
		{ key = "before", title = "a quest mob hovered, out of a fight",
			proven = "tooltipnowait run 1 (qf8f1): out of a fight yes by the tooltip's unit (nameplate2)",
			run = function(r)
			r:Set("handleTooltips", true)
			r:Set("tooltipNoWaitQuest", true)
			if (ns.db.tooltipFullAfter or 0) <= 0 then r:Set("tooltipFullAfter", 2) end
			r:WaitFor("Put your mouse on a mob you need for a quest (don't attack it yet)",
				{ check = function() return not InCombatLockdown() and Hovering() and "hovered" end })
			r:Sleep(0.3)
			ReadAll(r)
			local last, now = Answer(r, "out of a fight")
			r:Verdict(now == true, "out of a fight the quest mob skips the wait: " .. tostring(now)
				.. " (route " .. tostring(last and last.route) .. "; a FAIL here: not a quest mob, or the check is off)")
		end },
		{ key = "fight", title = "in the fight, hovered again (CineMode off)",
			proven = "tooltipnowait run 2 (q2085): plate-hovered quest mob skipped the wait in a fight, look held 3 s",
			run = function(r) FightCheck(r) end },
		{ key = "cine", title = "in the fight with CineMode on", run = function(r)
			-- (Your report's case: CineMode on. Its tooltip hiding (Effects.lua)
			-- hides and shows the tooltip again: every fill and its trace logged.)
			if not ns.IsCineModeOn() then
				pcall(Cinematic_ToggleCineMode)
				r:Keep("cineTurnedOn", true)
			end
			r:Log("CineMode on: " .. tostring(ns.IsCineModeOn()))
			ns.tooltipTrace = { started = GetTime() }
			local seen, wasShown
			local watch = C_Timer.NewTicker(0.1, function()
				local last = ns.tooltipNoWaitLast
				local shown = GameTooltip:IsShown() and true or false
				if last ~= seen or shown ~= wasShown then
					seen, wasShown = last, shown
					local okU, _, unit = pcall(GameTooltip.GetUnit, GameTooltip)
					local okS, look, noWait, counting = pcall(ns.TooltipWaitState)
					local okL, line1 = pcall(function() return GameTooltipTextLeft1:GetText() end)
					r:Log(("fill/show: shown %s | unit %s | line1 %s | lines %s | answer %s by %s, tried %s, fight %s"
						.. " | After look %s, no wait %s, countdown %s"):format(tostring(shown),
						okU and (Secret(unit) and "SECRET" or tostring(unit)) or "error",
						okL and (Secret(line1) and "SECRET" or tostring(line1)) or "error",
						tostring(GameTooltip:NumLines()), tostring(last and last.yes), tostring(last and last.route),
						tostring(last and last.tried), tostring(last and last.fight), tostring(okS and look),
						tostring(noWait), tostring(counting)))
				end
			end)
			FightCheck(r)
			watch:Cancel()
			local trace = ns.tooltipTrace
			ns.tooltipTrace = nil
			r:Log("CineMode tooltip trace (Effects.lua): " .. (#trace > 0 and table.concat(trace, " | ") or "none"))
		end },
	},
})
