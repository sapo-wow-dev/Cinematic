-- /cine debug platerange: distance on nameplates in game: the Smart rows'
-- Within / Past ~30 yards and the Nameplates page's Enemies within ~30 yd
-- (Tools/plate-distance-plan.md, ledger Tools/tests/plate-distance.md). ~30
-- is ns.NEAR_YARDS, measured by your spell nearest 30 yards, in fights and
-- out (2026-11-25: no yards box, it promised any number). Your one action:
-- stand near red mobs, out of a fight (a step asks you closer if none is in
-- reach). Steps:
--   1 rows    two Smart rows for the run, NPC within ~30 yd (green arrow) and
--             NPC past ~30 yd (red glow), every Style switch over them on;
--             both ids valid, what measures ~30 here (PASS/FAIL)
--   2 plates  10 samples over 5 s of every plate: the row it goes by
--             (ns.PlateRowNow) against ns.UnitWithinYards(unit, 30), no plate
--             both within and past, marks drawn, the cost of 40 asks; a shot
--   3 drawer  Nameplate Marks open: the NPC row's line says Within ~30 yards
--             with "N yd" after it, inside the drawer, no dropdown cut; a shot
--   4 nearby  Enemies within ~30 yd, the Hostile NPCs and Enemy players rows
--             emptied, CineMode on (and back): enemy plates within shown by
--             that row (ns.PlateItemsWhy), further hidden, both ways on the
--             same mobs by the test's own distance (ns.plates.nearYards), each
--             fade eased; the row's label on the Nameplates page; a shot
--   5 fight   both on in a fight: no blocked action, the yards still answered
--             (proven, run 10 q44a9)
-- Settings put back at the end (your rows, switches, CineMode as it was).
-- Into CinematicDB.plateRangeTestLog. Dev copy only.
local _, ns = ...
-- (Step 4's: the kinds' ticks emptied, the row on.)
local KIND_PREFIXES = { "plateAlways", "plateGroup", "plateCombat", "plateCombatPvP", "plateCinematic", "plateInCities",
	"plateInInstances", "plateInPvP", "plateInBGs", "plateTargetEnemy", "plateTargetFriendly" }
local NEAR_SETTINGS = { "handlePlates", "plateAlwaysNearbyEnemies" }
for _, kind in ipairs({ "EnemyNPCs", "Enemies" }) do
	for _, prefix in ipairs(KIND_PREFIXES) do NEAR_SETTINGS[#NEAR_SETTINGS + 1] = prefix .. kind end
end

local X = ns.NEAR_YARDS
local IN, PAST = "npcsIn" .. X .. "y", "npcsPast" .. X .. "y"
local SETTINGS = { "styleGeneral", "handlePlateStyle", "plateMarks", "markOrder", "markNames",
	IN .. "MarkStyle", IN .. "MarkColor", IN .. "MarkR", IN .. "MarkG", IN .. "MarkB",
	PAST .. "MarkStyle", PAST .. "MarkColor", PAST .. "MarkR", PAST .. "MarkG", PAST .. "MarkB",
	IN .. "When", PAST .. "When" }
for _, key in ipairs(NEAR_SETTINGS) do SETTINGS[#SETTINGS + 1] = key end
local PLATES = ns.CVarSet("Plate range test: plates", "/cine debug platerange: enemy and friendly plates on for the run",
	{ values = { nameplateShowEnemies = "1", nameplateShowFriends = "1", nameplateShowFriendlyNpcs = "1" } })

local nearSeen, farSeen -- (step 4: within and up, past and fading out, seen while watching a fade)
local function Plates()
	local list = {}
	local ok, plates = pcall(C_NamePlate.GetNamePlates)
	for _, plate in ipairs(ok and plates or {}) do
		local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
		if type(unit) == "string" then list[#list + 1] = { plate = plate, unit = unit } end
	end
	return list
end
local function Enemies()
	local list = {}
	for _, each in ipairs(Plates()) do
		local okR, reaction = pcall(UnitReaction, each.unit, "player")
		local okA, attack = pcall(UnitCanAttack, "player", each.unit)
		if okR and type(reaction) == "number" and reaction <= 3 and okA and attack == true then
			list[#list + 1] = each
		end
	end
	return list
end
-- (CineMode as each step needs it, yours kept for the put back: the Smart
-- rows' marks off it, run q76d2 had CineMode on and every plate hidden.)
local function Cine(r, on)
	r:Keep("cineWas", ns.IsCineModeOn() and "on" or "off")
	if (ns.IsCineModeOn() and true or false) ~= on and Cinematic_ToggleCineMode then pcall(Cinematic_ToggleCineMode) end
end
local function CineOn(r) Cine(r, true) end
-- (Your target's plate stays up by its own row: left out of the judging.)
local function IsTarget(unit)
	local ok, same = pcall(UnitIsUnit, unit, "target")
	return ok and same == true
end

ns.TestKit.Define({
	name = "platerange",
	key = "plateRangeTest",
	title = "Distance on nameplates (~30 yd)",
	about = "Smart rows Within / Past ~30 yd and Enemies within ~30 yd on real plates",
	needs = "Stand near red mobs, out of a fight",
	settings = SETTINGS,
	cvars = { "nameplateShowEnemies", "nameplateShowFriendlyNpcs", "nameplateMaxDistance" },
	-- (CineMode left alone by the kit: steps 4-5 need it on, and put it back.)
	cineMode = true,
	putBack = function(extra)
		local said = {}
		ns.plates.nearYards = nil
		if extra.plates then
			ns.ApplyCVarSet(PLATES, false)
			said[#said + 1] = "plates put back"
		end
		if extra.cineWas and (extra.cineWas == "on") ~= (ns.IsCineModeOn() and true or false)
			and Cinematic_ToggleCineMode then
			pcall(Cinematic_ToggleCineMode)
			said[#said + 1] = "CineMode back " .. extra.cineWas
		end
		return #said > 0 and table.concat(said, ", ") or nil
	end,
	steps = {
		{ key = "rows", title = "two rows for the run", run = function(r)
			r:Keep("plates", true)
			ns.ApplyCVarSet(PLATES, true)
			Cine(r, false)
			r:Sleep(1)
			r:Verdict(not ns.IsCineModeOn(), "CineMode off for the Smart rows' steps")
			for _, key in ipairs({ "styleGeneral", "handlePlateStyle", "plateMarks" }) do r:Set(key, true) end
			r:Set("markOrder", IN .. "," .. PAST)
			r:Set(IN .. "MarkStyle", "arrow")
			r:Set(IN .. "MarkColor", "custom")
			r:Set(IN .. "MarkR", 0.2) r:Set(IN .. "MarkG", 1) r:Set(IN .. "MarkB", 0.3)
			r:Set(PAST .. "MarkStyle", "glow")
			r:Set(PAST .. "MarkColor", "custom")
			r:Set(PAST .. "MarkR", 1) r:Set(PAST .. "MarkG", 0.2) r:Set(PAST .. "MarkB", 0.2)
			-- (Always, as Add row sets it: run q88d3 left When unset and no mark showed.)
			r:Set(IN .. "When", true)
			r:Set(PAST .. "When", true)
			r:Verdict(ns.MarkRowValid(IN) and ns.MarkRowValid(PAST), "both row ids valid")
			r:Verdict(ns.StyleOn("plateMarks") == true, "Nameplate Marks on (every switch over it)")
			local calm, calmName, fight, fightName = ns.YardsRingInfo(X)
			r:Log(("~%d yd measured with: out of fights %s yd (%s), in fights %s yd (%s)"):format(X, tostring(calm),
				tostring(calmName), tostring(fight), tostring(fightName)))
			r:Verdict(calm ~= nil and calm == fight, "the same spell in fights and out: " .. tostring(calmName))
			local rings, short, long = ns.YardsRings()
			local list = {}
			for key, each in pairs(rings) do
				for _, ring in ipairs(each) do list[#list + 1] = key .. " " .. ring.yards end
			end
			r:Log(("rings: spells %s; interact %d and %d (no spell can say only)"):format(
				#list > 0 and table.concat(list, ", ") or "none", short, long))
		end },
		{ key = "plates", title = "plates against the rows", run = function(r)
			local count = r:WaitFor("Stand where mobs or NPCs have plates, out of a fight. No need to move.", {
				check = function() return not InCombatLockdown() and #Plates() >= 1 and #Plates() end })
			r:Log("plates up: " .. tostring(count))
			local looks, agree, both, unsure, wrong, marked, unmarked = 0, 0, 0, 0, {}, 0, 0
			for i = 1, 10 do
				r:Prompt(("Checking plates: %d of 10"):format(i), "Stay where you are.", (11 - i) * 0.5)
				for _, each in ipairs(Plates()) do
					looks = looks + 1
					local within = ns.UnitWithinYards(each.unit, X)
					local past = ns.UnitWithinYards(each.unit, X, true)
					local okRow, row = pcall(ns.PlateRowNow, each.plate, each.unit)
					row = okRow and row or nil
					if within == true and past == true then both = both + 1 end
					if row == IN or row == PAST then
						local mark = ns.PlateMarkFrame and ns.PlateMarkFrame(each.plate)
						if mark and mark:IsVisible() then marked = marked + 1 else unmarked = unmarked + 1 end
					end
					local want = within == true and IN or within == false and PAST or nil
					if within == nil then
						unsure = unsure + 1
					elseif row == want then
						agree = agree + 1
					elseif #wrong < 6 then
						local okName, name = pcall(UnitName, each.unit)
						wrong[#wrong + 1] = ("%s %s: within %s, row %s"):format(each.unit,
							okName and type(name) == "string" and name or "?", tostring(within), tostring(row))
					end
				end
				r:Sleep(0.5)
			end
			r:Log(("%d plate looks: %d on the right row, %d nothing could say, %d both"):format(looks, agree, unsure, both))
			if #wrong > 0 then r:Log("wrong row: " .. table.concat(wrong, "; ")) end
			r:Verdict(looks > 0 and agree + unsure == looks, ("every plate on the row its distance says (%d of %d)"):format(
				agree, looks - unsure))
			r:Verdict(both == 0, "no plate both within and past ~30")
			-- (A plate just come up can be a sample short of its mark: 1 in 10
			-- let off, as the rows, run q25e1 9 of 10.)
			r:Verdict(marked > 0 and unmarked <= math.max(1, (marked + unmarked) / 10),
				("the row's mark drawn on its plates: %d shown, %d not"):format(marked, unmarked))
			local plates = Plates()
			if #plates > 0 then
				local start = debugprofilestop()
				for i = 1, 40 do ns.UnitInBand(plates[(i - 1) % #plates + 1].unit, "In" .. X .. "y") end
				r:Log(("40 asks (kept answers): %.3f ms"):format(debugprofilestop() - start))
			end
			r:Shot("plates: green arrow within ~30 yd, red glow past")
		end },
		{ key = "drawer", title = "the drawer says Within ~30 yards", run = function(r)
			if InCombatLockdown() then return r:Skip("in a fight: the settings stay shut") end
			local ok, err = pcall(ns.OpenOptionsAt, "Nameplate Marks")
			if not ok then return r:Fail("couldn't open Nameplate Marks: " .. tostring(err)) end
			r:Sleep(0.5)
			local function Shown()
				for hint, pick in pairs(ns.yardsHints or {}) do
					if hint:IsVisible() and pick.distance == "In" .. X .. "y" then return hint end
				end
			end
			if not Shown() then
				r:WaitFor("Click the NPC - Within ~30 yards row to open its drawer.", { check = function() return (Shown()) end })
			end
			local hint = Shown()
			if not hint then return r:Fail("no Within ~30 yards line shown") end
			local drawer = hint:GetParent()
			r:Verdict((hint:GetText() or ""):find("yd") ~= nil, "after it, what measures it: " .. tostring(hint:GetText()))
			local right, edge = hint:GetRight(), drawer:GetRight()
			r:Verdict(right and edge and right <= edge, ("the hint ends inside the drawer (%s of %s)"):format(
				tostring(right and math.floor(right)), tostring(edge and math.floor(edge))))
			-- (The line's dropdowns: none cut short, "Within ~30 yards" among them.)
			local cut, seen, says = {}, 0, false
			local _, hintY = hint:GetCenter()
			for _, child in ipairs({ drawer:GetChildren() }) do
				local text = child:IsVisible() and (child.Text or child.text)
				local _, y = child:GetCenter()
				if text and text.IsTruncated and y and hintY and math.abs(y - hintY) < 6 then
					seen = seen + 1
					if text:IsTruncated() then cut[#cut + 1] = tostring(text:GetText()) end
					if text:GetText() == ns.L["Within ~30 yd"] then says = true end
				end
			end
			r:Verdict(says, "the Distance dropdown says Within ~30 yd")
			r:Verdict(#cut == 0, ("%d dropdowns on the line, cut short: %s"):format(seen,
				#cut > 0 and table.concat(cut, ", ") or "none"))
			r:Shot("the drawer: Within ~30 yards and what measures it", { behind = drawer })
		end },
		{ key = "nearby", title = "Enemies within ~30 yd, in CineMode", run = function(r)
			r:Keep("plates", true)
			ns.ApplyCVarSet(PLATES, true)
			r:Set("handlePlates", true)
			r:Set("plateAlwaysNearbyEnemies", true)
			for _, kind in ipairs({ "EnemyNPCs", "Enemies" }) do
				for _, prefix in ipairs(KIND_PREFIXES) do r:Set(prefix .. kind, false) end
			end
			local rules = ns.db.frameRules or {}
			for _, kind in ipairs({ "EnemyNPCs", "Enemies" }) do
				local rule = rules["plate:" .. kind]
				if type(rule) == "string" and rule:find("%S") then
					r:Log(("note: your %s row has a rule (%s): it may keep plates up too"):format(kind, rule))
				end
			end
			local count = r:WaitFor("Stand where red mobs have plates. No need to move.", {
				check = function() return not InCombatLockdown() and #Enemies() >= 1 and #Enemies() end })
			r:Log("enemy plates up: " .. tostring(count))
			CineOn(r)
			r:Prompt("CineMode on: watching the enemy plates.", "Stay where you are.", 3)
			r:Sleep(3)
			r:Verdict(ns.IsCineModeOn(), "CineMode on")
			-- Both ways on the same mobs, no walking: the row's distance set past
			-- the nearest enemy (it must show), then short of every enemy (it
			-- must hide), by the test's own ns.plates.nearYards (the page has
			-- none to set). Waits for an enemy in reach of any spell first.
			local function Reach()
				for _, yards in ipairs({ 5, 8, 11, 15, 20, 25, 28, 30, 35, 40, 45 }) do
					for _, each in ipairs(Enemies()) do
						if ns.UnitWithinYards(each.unit, yards) == true then return yards end
					end
				end
			end
			local reach = Reach()
			if not reach then
				local longest = select(1, ns.YardsRingInfo(45)) or 28
				reach = r:WaitFor(("Step a little closer: a red mob within about %d yards of you."):format(longest), {
					check = function() return not InCombatLockdown() and Reach() end })
			end
			if type(reach) ~= "number" then return r:Skip("no enemy in reach of any spell") end
			local short
			r:Log(("nearest enemy first within %d yd"):format(reach))
			local right, wrong, near, far, examples, fades = 0, 0, 0, 0, {}, {}
			nearSeen, farSeen = false, false
			for i = 1, 10 do
				if i == 6 then
					short = nil
					for _, yards in ipairs({ 5, 8, 11, 15, 20, 25, 28, 30, 35, 40 }) do
						local outside = true
						for _, each in ipairs(Enemies()) do
							if ns.UnitWithinYards(each.unit, yards) ~= false then outside = false end
						end
						if outside then short = yards end
					end
					r:Log("short of every enemy now: " .. tostring(short) .. " yd")
				end
				local yards = (i <= 5 or not short) and reach or short
				if ns.plates.nearYards ~= yards then
					ns.plates.nearYards = yards
					r:Log(("row set to %d yd"):format(yards))
					-- (The fade: some plate's level seen part way as it eases;
					-- judged only when a level moved at all.)
					local partWay, before, moved = false, {}, false
					for unit, level in pairs(ns.plates.nearLevels or {}) do before[unit] = level end
					for _ = 1, 30 do
						for unit, level in pairs(ns.plates.nearLevels or {}) do
							if level > 0.02 and level < 0.98 then partWay = true end
							if level ~= (before[unit] or 0) then moved = true end
							-- (Seen within and up while watching: counts for both ways,
							-- a wandering mob may be off again by the samples, q76d2.)
							if level >= 0.98 and not IsTarget(unit) and ns.UnitWithinYards(unit, yards) == true then
								nearSeen = true
							end
							-- (And a plate fading out as it's past: the hidden side, q25e1.)
							if level < (before[unit] or 0) and not IsTarget(unit) and ns.UnitWithinYards(unit, yards) == false then
								farSeen = true
							end
						end
						for unit in pairs(before) do
							if not (ns.plates.nearLevels or {})[unit] then moved = true end
						end
						r:Sleep(0.05)
					end
					fades[#fades + 1] = { yards = yards, partWay = partWay, moved = moved }
					r:Sleep(1.5) -- (the rest of the fade)
				end
				r:Prompt(("Checking enemy plates at %d yd: %d of 10"):format(yards, i), "Stay where you are.",
					(11 - i) * 0.5)
				local items = {}
				for _, item in ipairs(ns.PlateItemsWhy and ns.PlateItemsWhy() or {}) do items[item.key] = item end
				for _, each in ipairs(Enemies()) do
					local within = not IsTarget(each.unit) and ns.UnitWithinYards(each.unit, yards) or nil
					local okG, guid = pcall(UnitGUID, each.unit)
					local item = okG and type(guid) == "string" and items[guid]
					local shown = item and item.status ~= "hidden" or false
					local byRow = false
					for _, reason in ipairs(item and item.reasons or {}) do
						if (reason.text or ""):find(ns.L["Enemies in ~30 yd"], 1, true) then byRow = true end
					end
					if within == true then near = near + 1 elseif within == false then far = far + 1 end
					local ok = within == true and shown and byRow or within == false and not shown or within == nil
					if ok then right = right + 1 else
						wrong = wrong + 1
						if #examples < 6 then
							local okN, name = pcall(UnitName, each.unit)
							examples[#examples + 1] = ("%s: within %s, shown %s, by the row %s"):format(
								okN and type(name) == "string" and name or each.unit, tostring(within), tostring(shown),
								tostring(byRow))
						end
					end
				end
				r:Sleep(0.5)
			end
			r:Log(("enemy plate looks: %d within, %d further; %d right, %d wrong"):format(near, far, right, wrong))
			if #examples > 0 then r:Log("wrong: " .. table.concat(examples, "; ")) end
			-- (A plate moving across the line between samples: 1 in 10 let off.)
			r:Verdict(right + wrong > 0 and wrong <= math.max(1, (right + wrong) / 10),
				("enemies within the row's distance shown by it, further hidden (%d of %d)"):format(right, right + wrong))
			r:Verdict((near > 0 or nearSeen) and (far > 0 or farSeen or not short),
				("both ways seen: %d within (up while watching: %s), %d further (fading out while watching: %s)"):format(
					near, tostring(nearSeen), far, tostring(farSeen)))
			local said = {}
			for _, fade in ipairs(fades) do
				if fade.moved then
					said[#said + 1] = ("%d yd %s"):format(fade.yards, fade.partWay and "eased" or "JUMPED")
					r:Verdict(fade.partWay, ("the plate eased as the row went to %d yd, not popped"):format(fade.yards))
				else
					said[#said + 1] = ("%d yd: no plate crossed"):format(fade.yards)
				end
			end
			r:Log("fades: " .. table.concat(said, ", ") .. (" (Fade in %.1f s, out %.1f s)"):format(
				ns.db.fadeInTime or 0, ns.db.fadeOutTime or 0))
			ns.plates.nearYards = nil
			r:Sleep(2)
			r:Shot("CineMode: Enemies within ~30 yd")
			-- The row on the Nameplates page: its label whole, before the grid.
			if InCombatLockdown() then return r:Skip("in a fight: the settings stay shut") end
			pcall(ns.OpenOptionsAt, "Nameplates", ns.L["Enemies in ~30 yd"])
			r:Sleep(0.8)
			local label = ns.nearbyRowLabel
			if not (label and label:IsVisible()) then
				r:WaitFor("Open Interface > Nameplates, Enemy tab.", {
					check = function() return ns.nearbyRowLabel and ns.nearbyRowLabel:IsVisible() end })
				label = ns.nearbyRowLabel
			end
			if not (label and label:IsVisible()) then return r:Fail("the Enemies within ~30 yd row isn't shown") end
			local grid = ns.nearbyYardsGrid
			r:Verdict(not label:IsTruncated(), "the label whole: " .. tostring(label:GetText()))
			local labelRight, gridLeft = label:GetLeft() and (label:GetLeft() + label:GetStringWidth()), grid and grid:GetLeft()
			r:Verdict(labelRight and gridLeft and labelRight <= gridLeft, ("the label ends before the grid (%s of %s)"):format(
				tostring(labelRight and math.floor(labelRight)), tostring(gridLeft and math.floor(gridLeft))))
			r:Shot("Nameplates page: Enemies within ~30 yd", { behind = label:GetParent() })
		end },
		-- 5 fight: both on (a Smart row within ~30 and Enemies within ~30 yd,
		-- CineMode on), your pet's plate up if you have one: no blocked action
		-- (2026-11-25: 36 in one Forever fight from the interact distance, now
		-- never asked in fights) and the rows still answered by your spells.
		{ key = "fight", title = "a fight with both on: nothing blocked",
			proven = "run 10 q44a9 (Forever): 0 blocked, 30/30 answered", run = function(r)
			r:Keep("plates", true)
			ns.ApplyCVarSet(PLATES, true)
			for _, key in ipairs({ "styleGeneral", "handlePlateStyle", "plateMarks", "handlePlates" }) do r:Set(key, true) end
			r:Set("markOrder", IN)
			r:Set(IN .. "When", true)
			r:Set(IN .. "MarkStyle", "arrow")
			r:Set("plateAlwaysNearbyEnemies", true)
			CineOn(r)
			local blocked, answered, asked = 0, 0, 0
			local watch = CreateFrame("Frame")
			watch:RegisterEvent("ADDON_ACTION_BLOCKED")
			watch:SetScript("OnEvent", function(_, _, addon)
				if addon == "CinematicDev" or addon == "Cinematic" then blocked = blocked + 1 end
			end)
			local answer, which = r:WaitFor("Pull a mob and fight it for about 10 seconds.", {
				check = function() return InCombatLockdown() and "fighting" end, buttons = { "No fight" } })
			if answer == "button" and which == "No fight" then
				watch:UnregisterAllEvents()
				return r:Skip("no fight")
			end
			for i = 1, 20 do
				if not InCombatLockdown() then break end
				r:Prompt(("In the fight: %d of 20"):format(i), "Keep fighting.", (21 - i) * 0.5)
				for _, each in ipairs(Plates()) do
					asked = asked + 1
					if ns.UnitWithinYards(each.unit, X) ~= nil then answered = answered + 1 end
				end
				r:Sleep(0.5)
			end
			watch:UnregisterAllEvents()
			r:Log(("in the fight: %d plate asks, %d answered by a spell"):format(asked, answered))
			r:Verdict(blocked == 0, ("no blocked action from us in the fight: %d"):format(blocked))
			r:Verdict(asked > 0 and answered > 0, "the yards still answered in the fight, by your spells")
		end },
	},
})
