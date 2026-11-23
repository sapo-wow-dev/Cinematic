-- /cine debug findresults: /cine find's results window (UI/Find.lua), in the
-- game, hands off (2026-11-23: "/cine find vision heal visions takes you to
-- the wheel"; the window lists every match, ranked). Steps:
--   1 pages    the settings' pages as search sees them: how many, the Heal
--              Vision page among them (it wasn't, 2026-11-23: /cine find
--              handleHealVision found nothing), Visions loaded
--   2 ranked   searches and their best match (the offline check's,
--              Tools/offline/findrank.lua, on the game's own frames), each
--              timed
--   3 window   /cine find vision heal visions: the window shown, on screen,
--              its rows inside it, the best marked, a shot
--   3b look    the window's look: every line an icon, no title cut, no two
--              pages the same, the best tinted, a section folded and opened,
--              Up/Down picking, the bar, no empty band, shots
--   4 open     the best clicked: its page open, the window beside the
--              settings, a shot
--   5 typed    words typed in the window's box and Enter: its best opens
-- Into CinematicDB.findResultsTestLog. Dev copy only.
local _, ns = ...

local CASES = {
	{ "vision heal visions", "Heal Vision" }, { "heal vison", "Heal Vision" }, { "healvision", "Heal Vision" },
	{ "nameplates", "Nameplates" }, { "name plates", "Nameplates" }, { "letterbox size", "Size" },
	{ "mouse", "Cursor Hide" }, { "cdm", "Cooldown Manager" }, { "import", "Import" },
	{ "how do i hide the minimap", "Minimap" }, { "quest talk", "Dialogue" }, { "camera", "Cameras" },
}

local function Inside(inner, outer)
	local l, r, t, b = inner:GetLeft(), inner:GetRight(), inner:GetTop(), inner:GetBottom()
	local L, R, T, B = outer:GetLeft(), outer:GetRight(), outer:GetTop(), outer:GetBottom()
	if not (l and L) then return false end
	return l >= L - 1 and r <= R + 1 and t <= T + 1 and b >= B - 1
end

ns.TestKit.Define({
	name = "findresults",
	key = "findResultsTest",
	title = "/cine find: ranked results window",
	about = "searches ranked, the results window shown and clicked, nothing to do",
	steps = {
		{ key = "pages", proven = "findresults run 1: 106 pages, Heal Vision there with Visions loaded", title = "the pages search sees", run = function(r)
			local pages = ns.SettingsPages and ns.SettingsPages() or {}
			local heal = false
			for _, page in ipairs(pages) do
				if page.key == "Heal Vision" then heal = true end
			end
			r:Log(("%d pages; Visions loaded %s; Heal Vision page %s"):format(#pages,
				tostring(ns.ModuleLoaded and ns.ModuleLoaded("visions")), tostring(heal)))
			r:Verdict(heal == (ns.ModuleLoaded and ns.ModuleLoaded("visions") or false),
				"the Heal Vision page is searched exactly when Visions is loaded")
		end },
		{ key = "ranked", proven = "findresults run 6: 12 of 12 with page titles, 37-373 ms", title = "searches and their best match", run = function(r)
			if not (ns.BuildSearchIndex and ns.SearchRank) then return r:Fail("no ns.SearchRank") end
			local started = debugprofilestop()
			local index = ns.BuildSearchIndex()
			r:Log(("index: %d entries in %.0f ms"):format(#index, debugprofilestop() - started))
			for _, case in ipairs(CASES) do
				local at = debugprofilestop()
				local results = ns.SearchRank(index, case[1])
				local took = debugprofilestop() - at
				local top = results[1]
				local second = results[2]
				r:Verdict(top and top.text == case[2], ("%s -> %s [%s] (wanted %s; then %s; %d matches, %.0f ms)"):format(
					case[1], top and top.text or "nothing", top and (top.page.name or "Cinematic") or "-", case[2],
					second and second.text or "-", #results, took))
				r:Sleep(0.05)
			end
		end },
		{ key = "window", proven = "findresults run 6: 9 rows inside, Best match marked, shot", title = "the results window", run = function(r)
			ns.FindSetting("vision heal visions")
			r:Sleep(0.5)
			local window = _G.CinematicFindWindow
			local rows, count = ns.FindResultsShown()
			r:Verdict(window and window:IsVisible(), "the window shown")
			if not rows then return r:Fail("no rows") end
			r:Log("count line: " .. tostring(count))
			r:Verdict(#rows >= 3, ("%d rows listed"):format(#rows))
			r:Verdict(rows[1].kind:find("Best match", 1, true) ~= nil, "the first marked Best match: " .. rows[1].kind)
			r:Verdict(Inside(window, UIParent), "the window on screen")
			local out = 0
			for i, row in ipairs(window.rows) do
				if row:IsShown() then
					if not Inside(row, window) then out = out + 1 end
					local over = row.label:GetStringWidth() > row.label:GetWidth() + 1
					-- (An empty text reads nil in the game: run 5 stopped here.)
					r:Log(("row %d: %s | %s | %s%s"):format(i, row.label:GetText() or "", row.kind:GetText() or "",
						row.where:GetText() or "", over and " (label cut)" or ""))
				end
			end
			r:Verdict(out == 0, ("rows inside the window (%d outside)"):format(out))
			r:Shot("results window", { behind = window })
		end },
		{ key = "look", proven = "findresults run 7: icons (Cinematic's on Keybinds/Profiles), no cut or same titles, fold opens, keys, bar, 14 px under the last line", title = "the window's look: icons, folds, keys, bar", run = function(r)
			-- (2026-11-23, the user of the first look: three "Card Vision"
			-- lines, "Page" on every line, no bar, room left at the bottom.)
			ns.FindSetting("visions")
			r:Sleep(0.5)
			local rows, count, window = ns.FindResultsShown()
			if not rows then return r:Fail("no window") end
			r:Log("count line: " .. tostring(count))
			local noIcon, cut, titles, same = 0, 0, {}, {}
			for i, line in ipairs(rows) do
				local row = line.row
				if not row.icon:GetTexture() then noIcon = noIcon + 1 end
				if row.label:GetStringWidth() > row.label:GetWidth() + 1 then cut = cut + 1 end
				local plain = (line.label or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
				if line.entry and line.entry.rank == 0 then
					if titles[plain] then same[#same + 1] = plain end
					titles[plain] = true
				end
				r:Log(("line %d: %s | %s | %s"):format(i, plain, line.kind or "", line.where or ""))
			end
			r:Verdict(noIcon == 0, ("every line an icon (%d without)"):format(noIcon))
			r:Verdict(cut == 0, ("no title cut off (%d cut)"):format(cut))
			r:Verdict(#same == 0, "no two pages with the same title: " .. table.concat(same, ", "))
			r:Verdict(rows[1].best and not rows[2].best, "the best line tinted, only it")
			local fold = rows[2].item
			r:Verdict(fold and fold.members ~= nil, "its section's other pages folded under it: " .. tostring(rows[2].label))
			local last = window.rows[#window.rows]
			local room = last:GetBottom() and window:GetBottom() and (last:GetBottom() - window:GetBottom())
			r:Log("room under the last line: " .. tostring(room and ("%.0f"):format(room)))
			r:Verdict(room and room >= 0 and room < 24, "no empty band at the bottom, the last line inside")
			r:Verdict(window.bar:IsVisible(), "the scroll bar shown (more than fits)")
			local bl, br = window.bar:GetLeft(), window.bar:GetRight()
			r:Verdict(bl and br and bl >= window:GetLeft() and br <= window:GetRight() and br > (rows[1].row:GetRight() or 0),
				"the bar inside the window, right of the lines")
			r:Shot("visions: icons, best, fold", { behind = window })
			if fold and fold.members then
				local before = #window.items
				rows[2].row:Click()
				r:Sleep(0.3)
				r:Verdict(#window.items == before + #fold.members and window:IsShown(),
					("a click on the fold lists its %d pages, the window kept"):format(#fold.members))
				r:Shot("fold opened", { behind = window })
				rows[2].row:Click()
			end
			local press = window.box:GetScript("OnArrowPressed")
			-- (From the first line: a click on the fold picked it. Run 6.)
			ns.FindResultsKeys.Pick(1)
			press(window.box, "DOWN")
			press(window.box, "DOWN")
			rows = ns.FindResultsShown()
			r:Verdict(window.selected == 3 and rows[3].picked and not rows[1].picked, "Down twice: the third line picked")
			for _ = 1, 12 do press(window.box, "DOWN") end
			r:Verdict(window.offset > 0 and window.selected > window.offset and window.selected <= window.offset + 9,
				("the picked line kept in view: line %d, from %d"):format(window.selected, window.offset))
			r:Verdict(math.abs((window.bar:GetValue() or 0) - window.offset) < 0.5, "the bar follows: " .. tostring(window.bar:GetValue()))
			r:Shot("picked further down", { behind = window })
			window:Hide()
		end },
		{ key = "open", proven = "findresults run 6: page opened, window kept, docked right, gap 3, no overlap", title = "the best clicked", run = function(r)
			-- (Its own search: step 3 may be left out, proven.)
			ns.FindSetting("vision heal visions")
			r:Sleep(0.5)
			local window = _G.CinematicFindWindow
			local row = window and window.rows[1]
			if not (row and row.entry) then return r:Fail("no first row") end
			row:Click()
			r:Sleep(1)
			local settings = _G.SettingsPanel or _G.InterfaceOptionsFrame
			r:Verdict(settings and settings:IsShown(), "the settings open")
			local canvas = row.entry.page.canvas
			r:Verdict(canvas and canvas:IsVisible(), "its page shown: " .. tostring(row.entry.page.name))
			r:Verdict(window:IsShown(), "the window still open")
			-- (Screen pixels: the two can have different scales. Either side,
			-- and never over the settings: run 2 it sat on them, pushed back on
			-- screen from their right.)
			local function Box(frame)
				local scale = frame:GetEffectiveScale()
				return frame:GetLeft() * scale, frame:GetRight() * scale, frame:GetTop() * scale, frame:GetBottom() * scale
			end
			local wl, wr, wt, wb = Box(window)
			local sl, sr, st, sb = Box(settings)
			local overlap = math.max(0, math.min(wr, sr) - math.max(wl, sl)) * math.max(0, math.min(wt, st) - math.max(wb, sb))
			local gap = wl >= sr - 1 and wl - sr or sl - wr
			r:Log(("window %.0f-%.0f, settings %.0f-%.0f, screen %.0f: %s side, gap %.0f, overlap %.0f px2"):format(
				wl, wr, sl, sr, UIParent:GetRight() * UIParent:GetEffectiveScale(), wl >= sr - 1 and "right" or "left",
				gap, overlap))
			r:Verdict(overlap == 0, "the window not over the settings")
			r:Verdict(gap >= -1 and gap < 30, "the window docked beside the settings")
			r:Shot("best opened", { behind = settings })
		end },
		{ key = "typed", proven = "findresults run 6: letterbox size + Enter opened Letterbox Size", title = "words typed in the window", run = function(r)
			local window = _G.CinematicFindWindow
			if not window then return r:Fail("no window") end
			window.box:SetText("letterbox size")
			local enter = window.box:GetScript("OnEnterPressed")
			if enter then enter(window.box) end
			r:Sleep(1)
			local rows = ns.FindResultsShown()
			r:Verdict(rows and rows[1] and rows[1].entry and rows[1].entry.text == "Size",
				"letterbox size: best " .. tostring(rows and rows[1] and rows[1].label))
			local entry = rows and rows[1] and rows[1].entry
			r:Verdict(entry and entry.page.canvas and entry.page.canvas:IsVisible(),
				"its page opened: " .. tostring(entry and entry.page.name))
			r:Shot("typed and opened", { behind = window })
			window:Hide()
			local settings = _G.SettingsPanel or _G.InterfaceOptionsFrame
			if settings and settings:IsShown() then HideUIPanel(settings) end
		end },
	},
})
