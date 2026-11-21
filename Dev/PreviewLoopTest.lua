-- /cine debug previewloop: the Style General preview's "Cannot anchor to a
-- region dependent on it" (UnitStyle.lua DressUnit, the health bar pinned to
-- the portrait), seen as its Visions tab opened (2026-11-20, the Favorites
-- test). A test kit test (Dev/TestKit.lua), nothing to do: it opens Style
-- General, then clicks its inner row's Interface and Visions tabs in turn
-- (twice, a second apart). Steps:
--   1 open        Style General opened, its preview there (PASS/FAIL)
--   2-5 clicks    Interface, Visions, Interface, Visions: per click, the units
--                 whose portrait hangs on their own health bar with the chain
--                 of anchors (ns.PreviewAnchorCheck), the addon log's preview
--                 lines; PASS when no loop was seen; a screenshot at each Visions
-- Into CinematicDB.previewLoopTestLog. Dev copy only.
local _, ns = ...

-- The addon log's lines since mark that matter here.
local function NewLines(mark)
	local log = CinematicDB and CinematicDB.log or {}
	local out = {}
	for i = mark + 1, #log do
		local line = tostring(log[i])
		if line:find("preview anchors", 1, true) or line:find("UnitStyle.lua", 1, true) then out[#out + 1] = line end
	end
	return out
end

-- A row of tabs shown now with a tab named label: the row and that tab's index.
local function RowWith(label)
	for _, row in ipairs(ns.tabRows or {}) do
		local lit = row.tabs[row.tabs.picked or 0]
		if lit and lit:IsVisible() then
			for i, each in ipairs(row.labels) do if each == label then return row, i end end
		end
	end
end

local function Click(number, label)
	return { key = "click" .. number, title = label .. " tab clicked", seconds = 3, run = function(r)
		local row, index = RowWith(ns.L[label])
		if not row then
			r:Fail(("no row with a %s tab shown"):format(label))
			return
		end
		local mark, loops = #(CinematicDB.log or {}), ns.previewLoops or 0
		local ok, err = pcall(row.click, index)
		r:Verdict(ok, ("clicked %s (tab %d)%s"):format(label, index, ok and "" or (": " .. tostring(err))))
		r:Sleep(1)
		if label == "Visions" then r:Shot(label .. " " .. number, { behind = ns.generalStylePreview }) end
		local lines = NewLines(mark)
		for _, line in ipairs(lines) do r:Log("log: " .. line) end
		local seen = (ns.previewLoops or 0) - loops
		r:Verdict(seen == 0, ("%d anchor loop(s), %d preview log line(s)"):format(seen, #lines))
	end }
end

ns.TestKit.Define({
	name = "previewloop",
	key = "previewLoopTest",
	title = "Preview loop test",
	about = "Style General's preview tabs clicked in turn: no portrait/health anchor loop, nothing to do",
	settings = { "styleTheme", "ufShape", "styleGeneral" },
	context = function()
		return ("preview check %s, loops so far %s"):format(tostring(ns.PreviewAnchorCheck ~= nil),
			tostring(ns.previewLoops or 0))
	end,
	steps = {
		{ key = "open", title = "Style General opened", seconds = 2, run = function(r)
			if not (ns.OpenOptions and ns.PreviewAnchorCheck) then
				r:Fail("the settings or the preview check aren't there")
				return
			end
			local mark = #(CinematicDB.log or {})
			local ok, err = pcall(ns.OpenOptions, "Style General")
			r:Sleep(1)
			for _, line in ipairs(NewLines(mark)) do r:Log("log: " .. line) end
			r:Verdict(ok and ns.generalStylePreview ~= nil, ("opened %s, preview %s"):format(
				ok and "ok" or tostring(err), tostring(ns.generalStylePreview ~= nil)))
		end },
		Click(1, "Interface"),
		Click(2, "Visions"),
		Click(3, "Interface"),
		Click(4, "Visions"),
	},
})
