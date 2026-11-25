-- /cine debug platerange: Smart rows within / past any yards in game
-- (Tools/plate-distance-plan.md, ledger Tools/tests/plate-distance.md).
-- Your one action: stand where mobs or NPCs have plates, out of a fight (and
-- open the NPC row's drawer when it asks). Steps:
--   1 rows    two Smart rows for the run, NPC within 20 yd (green arrow) and
--             NPC past 20 yd (red glow), every Style switch over them on;
--             both ids valid (PASS/FAIL)
--   2 plates  10 samples over 5 s of every plate: the row it goes by
--             (ns.PlateRowNow) against ns.UnitWithinYards(unit, 20), no plate
--             both within and past, the rings X=20 uses, and the cost of 40
--             asks; a screenshot of the marks (PASS/FAIL)
--   3 drawer  the Nameplate Marks page open: the NPC row's yards box and its
--             "= N yd" hint shown, what they cover (r:Overlaps), a shot;
--             then 24 typed in: the row becomes npcsIn24y with its look
--             (PASS/FAIL)
--   4 nearby  the Nameplates page's Enemies within row (NearbyEnemies) at 20
--             yd, the Hostile NPCs and Enemy players rows emptied: CineMode
--             on (the test turns it on and back), 10 samples over 5 s of the
--             enemy plates: within 20 yd shown with that row as the reason
--             (ns.PlateItemsWhy), further hidden; the row's yards box on the
--             page and what it covers; a shot (PASS/FAIL)
-- Settings put back at the end (your rows, names and switches, CineMode as
-- it was). Steps 1-3 proven (run 5, qc8fe): left out unless "full". Into
-- CinematicDB.plateRangeTestLog. Dev copy only.
local _, ns = ...
-- (Step 4's: the kinds' ticks emptied, the row and its yards.)
local KIND_PREFIXES = { "plateAlways", "plateGroup", "plateCombat", "plateCombatPvP", "plateCinematic", "plateInCities",
	"plateInInstances", "plateInPvP", "plateInBGs", "plateTargetEnemy", "plateTargetFriendly" }
local NEAR_SETTINGS = { "handlePlates", "plateAlwaysNearbyEnemies", "plateNearbyYards" }
for _, kind in ipairs({ "EnemyNPCs", "Enemies" }) do
	for _, prefix in ipairs(KIND_PREFIXES) do NEAR_SETTINGS[#NEAR_SETTINGS + 1] = prefix .. kind end
end

local IN, PAST = "npcsIn20y", "npcsPast20y"
local SETTINGS = { "styleGeneral", "handlePlateStyle", "plateMarks", "markOrder", "markNames",
	IN .. "MarkStyle", IN .. "MarkColor", IN .. "MarkR", IN .. "MarkG", IN .. "MarkB",
	PAST .. "MarkStyle", PAST .. "MarkColor", PAST .. "MarkR", PAST .. "MarkG", PAST .. "MarkB",
	"npcsIn24yMarkStyle", "npcsIn24yMarkColor", "npcsIn24yMarkR", "npcsIn24yMarkG", "npcsIn24yMarkB",
	IN .. "When", PAST .. "When", "npcsIn24yWhen" }
for _, key in ipairs(NEAR_SETTINGS) do SETTINGS[#SETTINGS + 1] = key end
local PLATES = ns.CVarSet("Plate range test: plates", "/cine debug platerange: enemy and friendly plates on for the run",
	{ values = { nameplateShowEnemies = "1", nameplateShowFriends = "1", nameplateShowFriendlyNpcs = "1" } })

local function Plates()
	local list = {}
	local ok, plates = pcall(C_NamePlate.GetNamePlates)
	for _, plate in ipairs(ok and plates or {}) do
		local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
		if type(unit) == "string" then list[#list + 1] = { plate = plate, unit = unit } end
	end
	return list
end

ns.TestKit.Define({
	name = "platerange",
	key = "plateRangeTest",
	title = "Smart rows within X yards",
	about = "NPC rows within / past 20 yards on real plates, the drawer's yards box",
	needs = "Stand where mobs or NPCs have plates, out of a fight",
	settings = SETTINGS,
	cvars = { "nameplateShowEnemies", "nameplateShowFriendlyNpcs", "nameplateMaxDistance" },
	-- (CineMode left alone by the kit: step 4 needs it on, and puts it back.)
	cineMode = true,
	putBack = function(extra)
		local said = {}
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
		{ key = "rows", title = "two rows for the run", proven = "run 5 qc8fe (Forever)", run = function(r)
			r:Keep("plates", true)
			ns.ApplyCVarSet(PLATES, true)
			for _, key in ipairs({ "styleGeneral", "handlePlateStyle", "plateMarks" }) do r:Set(key, true) end
			r:Set("markOrder", IN .. "," .. PAST)
			r:Set(IN .. "MarkStyle", "arrow")
			r:Set(IN .. "MarkColor", "custom")
			r:Set(IN .. "MarkR", 0.2) r:Set(IN .. "MarkG", 1) r:Set(IN .. "MarkB", 0.3)
			r:Set(PAST .. "MarkStyle", "glow")
			r:Set(PAST .. "MarkColor", "custom")
			r:Set(PAST .. "MarkR", 1) r:Set(PAST .. "MarkG", 0.2) r:Set(PAST .. "MarkB", 0.2)
			-- (Always, as Add row sets it: run q88d3 left When unset, the page
			-- said Never and no mark showed though the rows fit.)
			r:Set(IN .. "When", true)
			r:Set(PAST .. "When", true)
			r:Verdict(ns.MarkRowValid(IN) and ns.MarkRowValid(PAST), "both row ids valid")
			r:Verdict(ns.StyleOn("plateMarks") == true, "Nameplate Marks on (every switch over it)")
			local calm, calmName, fight, fightName = ns.YardsRingInfo(20)
			r:Log(("20 yd measured with: out of fights %s yd (%s), in fights %s yd (%s)"):format(tostring(calm),
				tostring(calmName), tostring(fight), tostring(fightName)))
			local rings, short, long = ns.YardsRings()
			local list = {}
			for key, each in pairs(rings) do
				for _, ring in ipairs(each) do list[#list + 1] = key .. " " .. ring.yards end
			end
			r:Log(("rings: interact %d and %d; spells: %s"):format(short, long,
				#list > 0 and table.concat(list, ", ") or "none"))
		end },
		{ key = "plates", title = "plates against the rows", proven = "run 5 qc8fe (Forever)", run = function(r)
			local count = r:WaitFor("Stand where mobs or NPCs have plates, out of a fight. No need to move.", {
				check = function() return not InCombatLockdown() and #Plates() >= 1 and #Plates() end })
			r:Log("plates up: " .. tostring(count))
			local looks, agree, both, unsure, wrong, marked, unmarked = 0, 0, 0, 0, {}, 0, 0
			for i = 1, 10 do
				r:Prompt(("Checking plates: %d of 10"):format(i), "Stay where you are.", (11 - i) * 0.5)
				for _, each in ipairs(Plates()) do
					looks = looks + 1
					local within = ns.UnitWithinYards(each.unit, 20)
					local past = ns.UnitWithinYards(each.unit, 20, true)
					local okRow, row = pcall(ns.PlateRowNow, each.plate, each.unit)
					row = okRow and row or nil
					if within == true and past == true then both = both + 1 end
					-- (Drawn: a plate on one of the two rows has its mark shown.)
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
			r:Verdict(both == 0, "no plate both within and past 20")
			r:Verdict(marked > 0 and unmarked == 0, ("the row's mark drawn on its plates: %d shown, %d not"):format(
				marked, unmarked))
			local plates = Plates()
			if #plates > 0 then
				local start = debugprofilestop()
				for i = 1, 40 do ns.UnitInBand(plates[(i - 1) % #plates + 1].unit, "In20y") end
				r:Log(("40 asks (kept answers): %.3f ms"):format(debugprofilestop() - start))
			end
			r:Shot("plates: green arrow within 20 yd, red glow past")
		end },
		{ key = "drawer", title = "the drawer's yards box", proven = "run 5 qc8fe (Forever)", run = function(r)
			if InCombatLockdown() then return r:Skip("in a fight: the settings stay shut") end
			local ok, err = pcall(ns.OpenOptionsAt, "Nameplate Marks")
			if not ok then return r:Fail("couldn't open Nameplate Marks: " .. tostring(err)) end
			r:Sleep(0.5)
			local function Shown()
				for box, info in pairs(ns.yardsBoxes or {}) do
					if box:IsVisible() and info.pick.distance == "In20y" then return box, info end
				end
			end
			local box, info = Shown()
			if not box then
				r:WaitFor("Click the NPC - Within 20 yards row to open its drawer.", {
					check = function() return (Shown()) end })
				box, info = Shown()
			end
			if not box then return r:Fail("no yards box shown") end
			r:Verdict(box:GetText() == "20", "the box says 20: " .. tostring(box:GetText()))
			r:Verdict(info.measured:IsShown() and (info.measured:GetText() or ""):find("yd") ~= nil,
				"the hint: " .. tostring(info.measured:GetText()))
			-- (Overlaps gives what each covers; run q88d3 called it without
			-- looking.)
			for label, frame in pairs({ ["yards box"] = box, hint = info.measured }) do
				local hits = r:Overlaps(frame, box:GetParent())
				r:Verdict(#hits == 0, ("the %s covers nothing: %s"):format(label,
					#hits > 0 and table.concat(hits, "; ") or "none"))
			end
			-- (The hint inside the drawer, not past its right edge.)
			local right, edge = info.measured:GetRight(), box:GetParent():GetRight()
			r:Verdict(right and edge and right <= edge, ("the hint ends inside the drawer (%s of %s)"):format(
				tostring(right and math.floor(right)), tostring(edge and math.floor(edge))))
			-- (The dropdowns on the box's line, made narrower for it: none cut short.)
			local cut, seen = {}, 0
			local _, boxY = box:GetCenter()
			for _, child in ipairs({ box:GetParent():GetChildren() }) do
				local text = child ~= box and child:IsVisible() and (child.Text or child.text)
				local _, y = child:GetCenter()
				if text and text.IsTruncated and y and boxY and math.abs(y - boxY) < 6 then
					seen = seen + 1
					if text:IsTruncated() then cut[#cut + 1] = tostring(text:GetText()) end
				end
			end
			r:Verdict(#cut == 0, ("%d dropdowns on the line, cut short: %s"):format(seen,
				#cut > 0 and table.concat(cut, ", ") or "none"))
			r:Shot("the drawer: Within..., the yards box and its hint", { behind = box:GetParent() })
			box:SetText("24")
			box:ClearFocus()
			local onEnter = box:GetScript("OnEditFocusLost")
			if onEnter then onEnter(box) end
			r:Sleep(0.5)
			local order = ns.db.markOrder or ""
			r:Verdict(order:find("npcsIn24y", 1, true) ~= nil and not order:find("npcsIn20y", 1, true),
				"typed 24: the row is npcsIn24y now (order " .. order .. ")")
			r:Verdict(ns.db.npcsIn24yMarkStyle == "arrow", "its look came with it: " .. tostring(ns.db.npcsIn24yMarkStyle))
		end },
		{ key = "nearby", title = "Enemies within 20 yd, in CineMode", run = function(r)
			r:Keep("plates", true)
			ns.ApplyCVarSet(PLATES, true)
			r:Keep("cineWas", ns.IsCineModeOn() and "on" or "off")
			r:Set("handlePlates", true)
			r:Set("plateAlwaysNearbyEnemies", true)
			r:Set("plateNearbyYards", 20)
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
			-- (Shown within, hidden past: run 7 qa2ae. Run again since the
			-- plates fade in and out, 2026-11-25.)
			do
			local count = r:WaitFor("Stand where red mobs have plates, some near and some further. No need to move.", {
				check = function() return not InCombatLockdown() and #Enemies() >= 1 and #Enemies() end })
			r:Log("enemy plates up: " .. tostring(count))
			if not ns.IsCineModeOn() and Cinematic_ToggleCineMode then pcall(Cinematic_ToggleCineMode) end
			r:Prompt("CineMode on: watching the enemy plates.", "Stay where you are.", 3)
			r:Sleep(3)
			r:Verdict(ns.IsCineModeOn(), "CineMode on")
			-- Both ways on the plates up, no walking (run q781d had one enemy,
			-- past 20 yd: "shown" never seen): the row's yards set past the
			-- nearest enemy (it must show), then short of it (it must hide).
			-- (The nearest enemy must be inside your longest check: run q44a9's
			-- two were past a warlock's 30 yd and the step failed. Waits for one
			-- instead; a few steps toward a mob does it.)
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
			if type(reach) ~= "number" then return r:Skip("no enemy in reach of any check") end
			local short
			for _, yards in ipairs({ 5, 8, 11, 15, 20, 25, 28, 30, 35, 40 }) do
				if yards < reach then short = yards end
			end
			r:Log(("nearest enemy first within %d yd; short of it: %s yd"):format(reach, tostring(short)))
			local right, wrong, near, far, examples, fades = 0, 0, 0, 0, {}, {}
			for i = 1, 10 do
				-- (Short of every enemy picked again as it switches: run q772a's
				-- mob walked in between, nothing crossed, and it read as a jump.)
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
				if ns.db.plateNearbyYards ~= yards then
					ns.db.plateNearbyYards = yards
					r:Log(("row set to %d yd"):format(yards))
					-- (The fade: some plate's level seen part way, 0 < level < 1,
					-- as it eases in or out, not jumping. ns.plates.nearLevels.
					-- Only judged when a plate's level moved at all.)
					local partWay, before, moved = false, {}, false
					for unit, level in pairs(ns.plates.nearLevels or {}) do before[unit] = level end
					for _ = 1, 30 do
						for unit, level in pairs(ns.plates.nearLevels or {}) do
							if level > 0.02 and level < 0.98 then partWay = true end
							if level ~= (before[unit] or 0) then moved = true end
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
					local within = ns.UnitWithinYards(each.unit, yards)
					local okG, guid = pcall(UnitGUID, each.unit)
					local item = okG and type(guid) == "string" and items[guid]
					local shown = item and item.status ~= "hidden" or false
					local byRow = false
					for _, reason in ipairs(item and item.reasons or {}) do
						if (reason.text or ""):find(ns.L["Enemies within"], 1, true) then byRow = true end
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
				("enemies within the row's yards shown by it, further hidden (%d of %d)"):format(right, right + wrong))
			r:Verdict(near > 0 and (far > 0 or not short), ("both ways seen: %d within, %d further"):format(near, far))
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
			ns.db.plateNearbyYards = reach
			r:Sleep(2)
			r:Shot(("CineMode: the row at %d yd, the nearest enemy's plate up"):format(reach))
			ns.db.plateNearbyYards = 20
			end
			-- The row's yards box on the Nameplates page (opened at its own
			-- setting: run q781d's page opened scrolled away from it).
			if InCombatLockdown() then return r:Skip("in a fight: the settings stay shut") end
			pcall(ns.OpenOptionsAt, "Nameplates", nil, "plateNearbyYards")
			r:Sleep(0.8)
			local box = ns.nearbyYardsBox
			if not (box and box:IsVisible()) then
				return r:Fail("the Enemies within row's yards box isn't in view, opened at its setting")
			end
			if box.Refresh then box:Refresh() end
			r:Verdict(box:GetText() == "20", "its box says 20: " .. tostring(box:GetText()))
			-- (Its yd must end before the row's grid starts: run qa2ae's ran
			-- into the Always column's dot. Overlaps against the page said
			-- "past the edge of Frame", the scroll child narrower than the grid.)
			local yd, grid = ns.nearbyYardsText, ns.nearbyYardsGrid
			local ydRight, gridLeft = yd and yd:GetRight(), grid and grid:GetLeft()
			r:Verdict(ydRight and gridLeft and ydRight <= gridLeft,
				("the box and its yd end before the grid (%s of %s)"):format(tostring(ydRight and math.floor(ydRight)),
					tostring(gridLeft and math.floor(gridLeft))))
			r:Shot("Nameplates page: Enemies within [20] yd", { behind = box:GetParent() })
		end },
		-- 5 fight: the yards code in a fight, both features on (a Smart row in 20
		-- yd and Enemies in 20 yd, CineMode on), your pet's plate up if you have
		-- one: no blocked action (2026-11-25: 36 in one Forever fight from the
		-- interact distance, now never asked in fights) and the rows still
		-- answering by your spells.
		{ key = "fight", title = "a fight with both on: nothing blocked", proven = "run 10 q44a9 (Forever): 0 blocked, 30/30 answered",
			run = function(r)
			r:Keep("plates", true)
			ns.ApplyCVarSet(PLATES, true)
			r:Keep("cineWas", ns.IsCineModeOn() and "on" or "off")
			for _, key in ipairs({ "styleGeneral", "handlePlateStyle", "plateMarks", "handlePlates" }) do r:Set(key, true) end
			r:Set("markOrder", IN)
			r:Set(IN .. "When", true)
			r:Set(IN .. "MarkStyle", "arrow")
			r:Set("plateAlwaysNearbyEnemies", true)
			r:Set("plateNearbyYards", 20)
			if not ns.IsCineModeOn() and Cinematic_ToggleCineMode then pcall(Cinematic_ToggleCineMode) end
			local blocked, answered, asked = 0, 0, 0
			local watch = CreateFrame("Frame")
			watch:RegisterEvent("ADDON_ACTION_BLOCKED")
			watch:SetScript("OnEvent", function(_, _, addon) if addon == "CinematicDev" or addon == "Cinematic" then blocked = blocked + 1 end end)
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
					if ns.UnitWithinYards(each.unit, 20) ~= nil then answered = answered + 1 end
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
