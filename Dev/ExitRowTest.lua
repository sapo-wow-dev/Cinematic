-- /cine debug exitrow: Exit CineMode's boxes in two columns, and Use a Show
-- in row instead (exitByRow) with its row (cine:exit). Nothing to do: it
-- runs and says DONE. Steps:
--   1 live    the row on with its Always ticked: CineMode goes off for it
--             (cineOffCode "row", the Why window's words); Always unticked:
--             CineMode back by itself (PASS/FAIL)
--   2 layout  the settings open on the Exit CineMode tab: the second column
--             beside the first, When moving last in the first, the toggle under
--             its sliders, the row under the toggle; the boxes greyed with it
--             ticked, the row greyed with it unticked; a screenshot each way
-- Settings put back after. Offline: Tools/offline/exitrow.lua.
-- Into CinematicDB.exitRowTestLog. Dev copy only.
local _, ns = ...

local function Find(root, key)
	local function Walk(frame, depth)
		if depth > 30 then return nil end
		if frame.settingKey == key then return frame end
		for _, child in ipairs({ frame:GetChildren() }) do
			local hit = Walk(child, depth + 1)
			if hit then return hit end
		end
	end
	return Walk(root, 0)
end
local function FindRow(root)
	local function Walk(frame, depth)
		if depth > 30 then return nil end
		if frame.RowId and frame.RowId() == ns.EXIT_ROW then return frame end
		for _, child in ipairs({ frame:GetChildren() }) do
			local hit = Walk(child, depth + 1)
			if hit then return hit end
		end
	end
	return Walk(root, 0)
end

-- Waits up to seconds for check() (polled), giving its last answer.
local function Within(r, seconds, check)
	local untilAt = GetTime() + seconds
	local answer = check()
	while not answer and GetTime() < untilAt do
		r:Sleep(0.25)
		answer = check()
	end
	return answer
end

ns.TestKit.Define({
	name = "exitrow",
	key = "exitRowTest",
	title = "Exit CineMode: Show in row",
	about = "Exit CineMode's two columns and its Show in row, nothing to do",
	cineMode = true,
	settings = { "exitByRow", "cineExitAlways", "fadeUI", "enabled" },
	context = function()
		return ("exitByRow %s, stayInCombat %s, offWhileMoving %s, in CineMode %s"):format(
			tostring(ns.db.exitByRow), tostring(ns.db.stayInCombat), tostring(ns.db.offWhileMoving),
			tostring(ns.lastCinematic))
	end,
	steps = {
		{ key = "live", title = "the row takes CineMode off and lets it back", run = function(r)
			if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
			r:Set("enabled", true)
			r:Set("fadeUI", true)
			r:Set("cineExitAlways", true)
			r:Set("exitByRow", true)
			local off = Within(r, 6, function() return ns.cineOffCode == "row" and not ns.lastCinematic end)
			r:Verdict(off, ("row Always: CineMode off for the row (code %s, why %s, in CineMode %s)"):format(
				tostring(ns.cineOffCode), tostring(ns.cineOffWhy), tostring(ns.lastCinematic)))
			r:Probe("Why window's words", ns.CineOffReason)
			r:Set("cineExitAlways", false)
			local back = Within(r, 10, function() return ns.lastCinematic end)
			r:Verdict(back, ("row nothing ticked: CineMode back by itself (code %s, why %s)"):format(
				tostring(ns.cineOffCode), tostring(ns.cineOffWhy)))
		end },
		{ key = "layout", title = "the Exit CineMode tab", run = function(r)
			r:Set("exitByRow", false)
			ns.OpenOptions("CineMode")
			r:Sleep(0.5)
			local tab = ns.cineExitTab
			if not tab then return r:Fail("no Exit CineMode tab frame") end
			tab.openSection()
			r:Sleep(0.5)
			local box = {}
			for _, key in ipairs({ "stayInCombat", "offInRaids", "offInPvP", "offInBGs", "offWhileMoving",
				"revealAtNPCs", "movingBackAfter", "exitByRow" }) do
				box[key] = Find(tab, key)
				if not box[key] then return r:Fail("not on the tab: " .. key) end
			end
			local row = FindRow(tab)
			if not row then return r:Fail("the row isn't on the tab") end
			local function L(f) return math.floor((f:GetLeft() or 0) + 0.5) end
			local function T(f) return math.floor((f:GetTop() or 0) + 0.5) end
			r:Log(("lefts: combat %d BGs %d moving %d toggle %d row %d; tops: combat %d BGs %d PvP %d moving %d NPCs %d sliders %d toggle %d row %d")
				:format(L(box.stayInCombat), L(box.offInBGs), L(box.offWhileMoving), L(box.exitByRow), L(row),
				T(box.stayInCombat), T(box.offInBGs), T(box.offInPvP), T(box.offWhileMoving), T(box.revealAtNPCs),
				T(box.movingBackAfter), T(box.exitByRow), T(row)))
			r:Verdict(L(box.offInBGs) > L(box.stayInCombat) + 150 and math.abs(T(box.offInBGs) - T(box.stayInCombat)) < 3,
				"second column beside the first, level with it")
			r:Verdict(T(box.offWhileMoving) < T(box.offInPvP) and math.abs(L(box.offWhileMoving) - L(box.stayInCombat)) < 3,
				"When moving at the bottom of the first column")
			r:Verdict(T(box.revealAtNPCs) > T(box.offWhileMoving), "the second column ends above When moving")
			r:Verdict(T(box.exitByRow) < T(box.movingBackAfter) and T(row) < T(box.exitByRow),
				"toggle under the sliders, the row under the toggle")
			local function Usable(f) return f:IsEnabled() and true or false end
			r:Verdict(Usable(box.stayInCombat) and Usable(box.revealAtNPCs), "unticked: boxes usable")
			r:Shot("unticked: boxes usable, row greyed", { behind = tab })
			box.exitByRow:Click()
			r:Sleep(0.3)
			r:Verdict(ns.db.exitByRow == true, "clicking the toggle ticks it")
			r:Verdict(not Usable(box.stayInCombat) and not Usable(box.revealAtNPCs) and not Usable(box.offWhileMoving),
				"ticked: boxes greyed")
			r:Shot("ticked: boxes greyed, row usable", { behind = tab })
			if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
		end },
	},
})
