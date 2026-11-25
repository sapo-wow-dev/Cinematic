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
-- Settings put back at the end (your rows, names and switches). CineMode
-- off. Into CinematicDB.plateRangeTestLog. Dev copy only.
local _, ns = ...

local IN, PAST = "npcsIn20y", "npcsPast20y"
local SETTINGS = { "styleGeneral", "handlePlateStyle", "plateMarks", "markOrder", "markNames",
	IN .. "MarkStyle", IN .. "MarkColor", IN .. "MarkR", IN .. "MarkG", IN .. "MarkB",
	PAST .. "MarkStyle", PAST .. "MarkColor", PAST .. "MarkR", PAST .. "MarkG", PAST .. "MarkB",
	"npcsIn24yMarkStyle", "npcsIn24yMarkColor", "npcsIn24yMarkR", "npcsIn24yMarkG", "npcsIn24yMarkB",
	IN .. "When", PAST .. "When", "npcsIn24yWhen" }
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
	putBack = function(extra)
		if extra.plates then
			ns.ApplyCVarSet(PLATES, false)
			return "plates put back"
		end
	end,
	steps = {
		{ key = "rows", title = "two rows for the run", run = function(r)
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
		{ key = "plates", title = "plates against the rows", run = function(r)
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
		{ key = "drawer", title = "the drawer's yards box", run = function(r)
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
	},
})
