-- /cine debug talknames: names while you talk to an NPC (2026-11-24: a
-- player wished names gone while talking, with DialogueUI; the npc rule word
-- meant interacting then, and a vendor's title stayed up through the talk,
-- the Service NPCs row keeping it). One action: talk to an NPC (right-click
-- a vendor or anyone with a chat window), then close the window when the
-- box says. Out of combat, CineMode on (the test turns it on).
--   1 page    the menu: /cine find row:name:AllNames opens the Names icon,
--             its All names row over the tabs, the Names icon's Target tab
--             with your target's Names row and Mouseover names, nothing over
--             them (r:Overlaps), shot; the Nameplates icon's Target tab: no
--             All names, no names rows, shot
--   2 talk    the Target names row's rule "not (interacting and npc)"
--             (the player's case). Before the talk: names on plates counted.
--             Waits for the talk: interacting and npc on, your target an NPC
--             with a plate. Its name (and a title in its place) gone, the
--             rule saying hidden; then the Target rule cleared and the All
--             names row's rule "not interacting": every plate's name gone;
--             shots
--   3 close   waits for the window closed: interacting off, the All names
--             rule shows again, names back on as many plates as before; shot
-- Everything changed is put back at the end. Into CinematicDB.talkNamesTestLog.
-- Dev copy only.
local _, ns = ...

local TARGET_RULE = "not (interacting and npc)"
local ALL_RULE = "not interacting"
local TARGET_KEY, ALL_KEY = "name:YourTarget", "name:AllNames"

local function Known(value)
	return not (issecretvalue and issecretvalue(value))
end

-- A font string with exactly these words, shown, under root.
local function FindText(root, words)
	local function Walk(frame, depth)
		if depth > 30 then return nil end
		for _, region in ipairs({ frame:GetRegions() }) do
			if region.GetText then
				local text = region:GetText()
				if type(text) == "string" and Known(text) and text == words and region:IsVisible() then
					return region
				end
			end
		end
		for _, child in ipairs({ frame:GetChildren() }) do
			local hit = Walk(child, depth + 1)
			if hit then return hit end
		end
	end
	return root and Walk(root, 0) or nil
end

local function PlateUnit(plate)
	return plate and (plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit))
end

-- Every plate's name now: how many show one (over 0.05), and the target's.
local function Names()
	local count, target, text = 0, nil, nil
	local own = C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("player")
	for _, plate in ipairs(C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates() or {}) do
		local unit = PlateUnit(plate)
		if type(unit) == "string" and plate ~= own then
			local level, share = ns.PlateNameLevel(unit, plate)
			if level > 0.05 then count = count + 1 end
			if ns.Flag(UnitIsUnit(unit, "target")) then target, text = level, share end
		end
	end
	return count, target, text
end

local function Words()
	local facts = ns.RuleFactsNow()
	return ("interacting %s, npc %s, target %s, friendlynpc %s, neutralnpc %s, hostilenpc %s"):format(
		tostring(facts.interacting), tostring(facts.npc), tostring(facts.target), tostring(facts.friendlynpc),
		tostring(facts.neutralnpc), tostring(facts.hostilenpc)), facts
end

local function SetRule(key, text)
	ns.db.frameRules = ns.db.frameRules or {}
	ns.db.frameRules[key] = text
	ns.plates.seen.at = nil -- (the plates' pass at once)
end

ns.TestKit.Define({
	name = "talknames",
	key = "talkNamesTest",
	title = "Names while talking to an NPC",
	about = "All names and the Target names rule: the menu, then one NPC talk",
	needs = "An NPC to talk to (a vendor, a quest giver), out of combat",
	settings = { "handlePlates", "handleNames" },
	cineMode = true,
	context = function()
		local rules = ns.db.frameRules or {}
		return ("Target names rule %q, All names rule %q, All names Always %s, Service NPCs rule %q, " ..
			"Service shows %s; DialogueUI %s"):format(tostring(rules[TARGET_KEY] or ""), tostring(rules[ALL_KEY] or ""),
			tostring(ns.db.nameAlwaysAllNames), tostring(rules["name:ServiceNPCs"] or ""), tostring(ns.db.nameServiceShow),
			tostring(C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("DialogueUI") or false))
	end,
	putBack = function(extra)
		local said = {}
		if extra.rulesKept then
			ns.db.frameRules = ns.db.frameRules or {}
			for _, pair in ipairs({ { TARGET_KEY, extra.targetWas }, { ALL_KEY, extra.allWas } }) do
				ns.db.frameRules[pair[1]] = pair[2] ~= "<none>" and pair[2] or nil
				said[#said + 1] = pair[1] .. " rule back to " .. tostring(pair[2])
			end
		end
		if extra.cineTurnedOn and ns.IsCineModeOn and ns.IsCineModeOn() and Cinematic_ToggleCineMode then
			pcall(Cinematic_ToggleCineMode)
			said[#said + 1] = "CineMode off again"
		end
		return #said > 0 and table.concat(said, "; ") or "nothing of its own"
	end,
	steps = {
		{ key = "page", title = "All names over the Names tabs, the Names icon's Target tab", seconds = 15,
			proven = "run 1 (queue qa44a), 2026-11-24: 8/8", run = function(r)
			r:Set("handleNames", true)
			r:Set("handlePlates", true)
			local panel = SettingsPanel or UIParent
			local function Wait(words)
				for _ = 1, 20 do
					r:Sleep(0.25)
					local hit = FindText(panel, words)
					if hit then return hit end
				end
			end
			local _, page = ns.FindSetting("row:name:AllNames")
			local all = Wait(ns.L["All names"])
			r:Log("find row:name:AllNames opened " .. tostring(page))
			if not all then
				r:Shot("Names icon, no All names row seen", { behind = panel })
				return r:Fail("no All names row shown on the Names icon")
			end
			r:Verdict(true, "All names row shown on the Names icon")
			local _, targetPage = ns.FindSetting("row:name:YourTarget")
			local mouse = Wait(ns.L["Mouseover names"])
			local names = mouse and FindText(mouse:GetParent() and mouse:GetParent():GetParent() or panel, ns.L["Names"])
			r:Log("find row:name:YourTarget opened " .. tostring(targetPage))
			r:Verdict(mouse ~= nil and names ~= nil and names:GetTop() > mouse:GetTop(),
				"the Names icon's Target tab: Names, then Mouseover names")
			all = FindText(panel, ns.L["All names"])
			r:Verdict(all ~= nil and mouse ~= nil and all:GetTop() > mouse:GetTop(),
				"All names over the tab's rows (still shown on the Target tab)")
			for _, label in ipairs({ all, names, mouse }) do
				if label then
					local hits = r:Overlaps(label:GetParent(), panel)
					r:Verdict(#hits == 0, ("nothing over %s"):format(tostring(label:GetText()))
						.. (#hits > 0 and (": " .. table.concat(hits, ", ")) or ""))
				end
			end
			r:Shot("Names icon, Target tab, All names over it", { behind = panel })
			ns.FindSetting("row:plate:YourMouseover")
			local plates = Wait(ns.L["Mouseover nameplates"])
			r:Verdict(plates ~= nil, "the Nameplates icon's Target tab: Mouseover nameplates")
			r:Verdict(FindText(panel, ns.L["All names"]) == nil and FindText(panel, ns.L["Mouseover names"]) == nil,
				"no All names or names rows on the Nameplates icon")
			r:Shot("Nameplates icon, Target tab", { behind = panel })
			if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
		end },
		{ key = "talk", title = "talking: your target's name, then every name, gone",
			proven = "run 4 (queue q11ff), 2026-11-24: 5/5", run = function(r)
			local rules = ns.db.frameRules or {}
			r:Keep("targetWas", rules[TARGET_KEY] == nil and "<none>" or rules[TARGET_KEY])
			r:Keep("allWas", rules[ALL_KEY] == nil and "<none>" or rules[ALL_KEY])
			r:Keep("rulesKept", true)
			r:Set("handleNames", true)
			r:Set("handlePlates", true)
			SetRule(ALL_KEY, nil)
			SetRule(TARGET_KEY, TARGET_RULE)
			if not (ns.IsCineModeOn and ns.IsCineModeOn()) and Cinematic_ToggleCineMode then
				r:Keep("cineTurnedOn", true)
				Cinematic_ToggleCineMode()
			end
			r:Sleep(ns.FadeInTime() + 0.5)
			local before = Names()
			r:Keep("namesBefore", before)
			r:Log(("before the talk: %d plates show a name; %s"):format(before, (Words())))
			local heldSince
			r:WaitFor("Talk to any NPC: right-click a vendor or a quest giver, and leave its window open.",
				{ check = function()
					local facts = ns.RuleFactsNow()
					local plate = C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("target")
					if not (facts.interacting and facts.npc and plate) then heldSince = nil return nil end
					heldSince = heldSince or GetTime()
					return GetTime() - heldSince >= ns.FadeOutTime() + 0.5 or nil
				end })
			local words, facts = Words()
			r:Log("words: " .. words)
			local plate = C_NamePlate.GetNamePlateForUnit("target")
			r:Log("target: " .. tostring(ns.DescribePlateNameKept("target", plate)))
			r:Verdict(facts.interacting == true and facts.npc == true, "interacting and npc on while talking")
			r:Verdict(ns.RuleShows(TARGET_KEY, facts) == false, ("the Target names rule %q says hidden"):format(TARGET_RULE))
			local _, target, text = Names()
			r:Verdict(target ~= nil and target < 0.05, ("your target's name gone, no title in its place (%s, text %s)")
				:format(tostring(target), tostring(text)))
			r:Shot("talking: the Target names rule", { behind = plate and plate.UnitFrame })
			-- Every name: the All names row.
			-- (Sampled every 0.25 s till every name is gone, or the fade out and
			-- 3 s more: run 1 (qa44a) read 3 names and the target's at 0.95 at
			-- 3.3 s, fade out 2.7 s: slow to start, or not gated at all?)
			-- (Run 2 (q121c): no name kept but the Innkeeper's, its kind off, so
			-- 0 names from the start proved nothing. Now the rows' own levels:
			-- Service NPCs is up by default, so it must come down; and the
			-- rule's answer is kept up to 0.5 s, so it read nil at first.)
			SetRule(TARGET_KEY, nil)
			SetRule(ALL_KEY, ALL_RULE)
			local count, gone, service
			local setAt, limit = GetTime(), ns.FadeOutTime() + 3
			local serviceBefore = ns.NameRowLevel("ServiceNPCs")
			r:Log(("Service NPCs row level before: %.2f"):format(serviceBefore))
			for i = 0, math.ceil(limit / 0.25) do
				local now = ns.RuleFactsNow()
				count, target = Names()
				service = ns.NameRowLevel("ServiceNPCs")
				if i % 2 == 0 or (count == 0 and service < 0.01) then
					r:Log(("  %.2f s: %d names, target %s, Service row %.2f, Target row %.2f; All names rule %s " ..
						"(interacting %s)"):format(GetTime() - setAt, count, target and ("%.2f"):format(target) or "?",
						service, ns.NameRowLevel("YourTarget"), tostring(ns.RuleShows(ALL_KEY, now)),
						tostring(now.interacting)))
				end
				if count == 0 and service < 0.01 then gone = GetTime() - setAt break end
				r:Sleep(0.25)
			end
			r:Log(("All names %q: %d plates show a name; target %s"):format(ALL_RULE, count, tostring(target)))
			if serviceBefore < 0.5 then
				r:Log("the Service NPCs row was down before (your rows): its fade not judged")
			end
			r:Verdict(count == 0 and (serviceBefore < 0.5 or service < 0.01),
				("All names %q: every name gone, the Service row down (%d left, Service %.2f%s)"):format(ALL_RULE,
				count, service, gone and (", after %.2f s"):format(gone) or ""))
			r:Verdict(gone == nil or gone <= ns.FadeOutTime() + 1,
				("gone within the fade out and a second (%s s, fade out %.1f s)"):format(gone and ("%.2f"):format(gone)
				or "never", ns.FadeOutTime()))
			r:Keep("serviceBefore", serviceBefore)
			r:Shot("talking: All names")
		end },
		{ key = "close", title = "the window closed: names back", proven = "run 4 (queue q11ff), 2026-11-24: 2/2",
			run = function(r)
			local rules = ns.db.frameRules or {}
			if rules[ALL_KEY] ~= ALL_RULE then
				return r:Skip("step 2 sets the All names rule: run it first")
			end
			local offSince
			r:WaitFor("Now close the NPC's window.", { check = function()
				if ns.RuleFactsNow().interacting then offSince = nil return nil end
				offSince = offSince or GetTime()
				return GetTime() - offSince >= 0.3 or nil
			end })
			local closedAt = GetTime()
			local undo = CinematicDB.talkNamesTestUndo
			local serviceBefore = undo and undo.extra and tonumber(undo.extra.serviceBefore) or 0
			-- (The rows' own level, not names on plates: run 2 (q121c) closed
			-- with the target cleared and nobody near with a name.)
			local service
			for _ = 1, math.ceil((ns.FadeInTime() + 3) / 0.25) do
				service = ns.NameRowLevel("ServiceNPCs")
				if service > 0.99 then break end
				r:Sleep(0.25)
			end
			local words, facts = Words()
			r:Log("words: " .. words)
			r:Verdict(ns.RuleShows(ALL_KEY, facts) == true, "the All names rule shows again")
			local count = Names()
			local before = undo and undo.extra and tonumber(undo.extra.namesBefore) or 0
			r:Log(("after: %d plates show a name (%d before the talk); Service row %.2f after %.2f s (%.2f before)")
				:format(count, before, service, GetTime() - closedAt, serviceBefore))
			r:Verdict(serviceBefore < 0.5 or service > 0.99, ("the Service NPCs row back up (%.2f)"):format(service))
			r:Shot("the window closed: names back")
		end },
	},
})
