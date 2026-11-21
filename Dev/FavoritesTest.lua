-- /cine debug favorites: the Favorites feature (UI/Favorites.lua) in game,
-- one run over a reload. It sets itself up (your favorites put aside, CineMode
-- off) and says each step on screen; you only click Reload when asked, then
-- start a fight and open Escape > Options in it. Steps:
--   1 star      Keybinds opened: one star, left of its search box, off (PASS/FAIL)
--   2 add       its star clicked: Keybinds in your favorites, the star on,
--               the reload popup up (PASS/FAIL)
--   3 deep      Style General opened, its inner row's Visions tab clicked,
--               starred: the favorite keeps that tab (PASS/FAIL); Interface
--               clicked: the star off, another place (PASS/FAIL); Keybinds
--               opened, then the favorite: Style General back at Visions (PASS/FAIL)
--   4 reload    you click Reload in the popup (Forever: its secure Reload)
--   5 lines     after it: Favorites first under Cinematic, open, a line a
--               favorite, the tab in its name (PASS/FAIL)
--   6 open      each favorite's line picked: its page at its tabs, the star
--               on, blocked +0 (PASS/FAIL)
--   7 page      the Favorites line picked: a tile a favorite; a tile's
--               right-click takes Keybinds off and asks for a reload, the
--               lines left as they are (PASS/FAIL)
--   8 fight     you start a fight and open Escape > Options: blocked +0
--               (PASS/FAIL; lines changed live gave 1831 on Forever)
-- Then your own favorites are put back (the left list shows them after your
-- next reload). Into CinematicDB.favoritesTestLog, a screenshot a step.
-- Run again to stop. Dev copy only.
local _, ns = ...

local HOOK, CHAT = "blocked (no event)", "blocked (chat line only)"

local function State() return CinematicDB and CinematicDB.favoritesTest end
local function Say(text)
	local log = CinematicDB and CinematicDB.favoritesTestLog
	if log then log[#log + 1] = ("%s %s"):format(date("%H:%M:%S"), text) end
end
local function Shot(what)
	local ok = pcall(function() Screenshot() end)
	Say(("  screenshot %s at %s%s"):format(what, date("%m%d%y_%H%M%S"), ok and "" or " (failed)"))
end
local function Blocked() return (ns.DevErrorCount(HOOK)) + (ns.DevErrorCount(CHAT)) end
local function PanelShown()
	local panel = _G.SettingsPanel
	return panel and panel:IsShown() and true or false
end
local function Close()
	if PanelShown() and HideUIPanel and not InCombatLockdown() then pcall(HideUIPanel, _G.SettingsPanel) end
end
local function Verdict(ok, text)
	local state = State()
	if not state then return end
	if ok then state.pass = state.pass + 1 else state.fail = state.fail + 1 end
	Say(("  verdict %s: %s"):format(ok and "PASS" or "FAIL", text))
end
local function Favs()
	local names = {}
	for _, place in ipairs(ns.Favorites()) do names[#names + 1] = place.label or ns.FavoriteLabel(place) end
	return table.concat(names, ", ")
end
-- Same place: page and each row's tab.
local function Same(a, b)
	if not (a and b) or a.page ~= b.page or #a.tabs ~= #b.tabs then return false end
	for i, tab in ipairs(a.tabs) do
		if tab.key ~= b.tabs[i].key or tab.index ~= b.tabs[i].index then return false end
	end
	return true
end
local function Where(place)
	if not place then return "nowhere" end
	local tabs = {}
	for _, tab in ipairs(place.tabs) do tabs[#tabs + 1] = ("%s=%s"):format(tostring(tab.label), tostring(tab.index)) end
	return ("%s [%s]"):format(place.page, table.concat(tabs, ", "))
end
local function OnText(star) return star and (star.on and "on" or "off") or "NONE" end
local function PopupUp()
	local which = ns.FavoritesReloadPopup()
	if StaticPopup_FindVisible then return StaticPopup_FindVisible(which) ~= nil end
	for i = 1, (_G.STATICPOPUP_NUMDIALOGS or 4) do
		local dialog = _G["StaticPopup" .. i]
		if dialog and dialog:IsShown() and dialog.which == which then return true end
	end
	return false
end
local function PopupDown() if StaticPopup_Hide then StaticPopup_Hide(ns.FavoritesReloadPopup()) end end
-- The star shown now, and whether it sits left of its search box.
local function Star()
	local star = ns.FavoriteStarShown()
	if not star then return nil, "no star shown" end
	-- (from the box's drawn border, its Left piece: 4 to 8 px apart, centers level)
	local edge = star.edge or star.box
	local r, bl = star:GetRight(), edge and edge:GetLeft()
	local _, sy = star:GetCenter()
	local by
	if star.box then by = select(2, star.box:GetCenter()) end
	local gap, drop = r and bl and bl - r, sy and by and math.abs(sy - by)
	Say(("  star %.0f px, %s px left of the box's border, centers %s px apart"):format(star:GetWidth() or 0,
		gap and ("%.1f"):format(gap) or "?", drop and ("%.1f"):format(drop) or "?"))
	local beside = gap and gap >= 4 and gap <= 8 and drop and drop <= 1.5
	return star, beside and "left of its search box"
		or ("NOT beside its box (star right %s, border left %s)"):format(tostring(r), tostring(bl))
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

-- Polls (no time limit) till check() is true.
local waitToken
local function WaitFor(prompt, check, after)
	if prompt then ns.TestPrompt(prompt, 3600) end
	local token = {}
	waitToken = token
	local function Poll()
		if waitToken ~= token or not State() then return end
		if check() then return after() end
		C_Timer.After(0.25, Poll)
	end
	Poll()
end
local function Later(seconds, fn)
	C_Timer.After(seconds, function() if State() then fn() end end)
end

local function Finish(text)
	local state = State()
	if not state then return end
	waitToken = nil
	PopupDown()
	-- (your own favorites back; the left list shows them after your next reload)
	CinematicDB.favorites = state.saved or {}
	Say(("  your favorites put back: %s"):format(Favs()))
	local line = ("%s: %d pass, %d fail"):format(text, state.pass, state.fail)
	Say(line)
	CinematicDB.favoritesTest = nil
	ns.TestPrompt(("Favorites test %s. Say \"check log\"."):format(line), 12)
end

-- 8: Escape > Options in a fight you start.
local function Fight()
	Close()
	Say("--- 8 of 8: Escape > Options in a fight ---")
	WaitFor("Favorites test: 8 of 8. Start a fight (a training dummy or any enemy). The test waits.",
		InCombatLockdown, function()
			local b8 = Blocked()
			WaitFor("Favorites test: in the fight press Escape, then click Options. The test waits.", PanelShown, function()
				local inFight = InCombatLockdown()
				ns.TestPrompt("Favorites test: got it, keep fighting a moment.", 3)
				Later(3, function()
					Shot("8")
					local new = Blocked() - b8
					if new > 0 then
						local _, stack = ns.DevErrorCount(HOOK)
						if stack then Say("  newest blocked stack:\n" .. stack) end
					end
					Verdict(inFight and new == 0, ("Escape > Options in a fight: blocked +%d (0 wanted), %s"):format(
						new, inFight and "in the fight" or "NOT in a fight"))
					WaitFor("Favorites test: close the settings and end the fight. The test waits.",
						function() return not InCombatLockdown() and not PanelShown() end, function() Finish("DONE") end)
				end)
			end)
		end)
end

-- 7: the Favorites page, a tile's right-click.
local function FavoritesPage(fav)
	Say("--- 7 of 8: the Favorites page ---")
	local b7 = Blocked()
	pcall(ns.PickSettingsCategory, _G.SettingsPanel, fav)
	Later(1, function()
		local page = ns.FavoritesPage()
		Shot("7")
		local shown = page and page:IsVisible()
		Verdict(shown and Blocked() == b7, ("Favorites page %s, blocked +%d"):format(
			shown and "shows" or "NOT SHOWN", Blocked() - b7))
		local tile
		for _, each in ipairs(ns.FavoriteTiles()) do
			if each.page == "Keybinds" and each:IsShown() then tile = each end
		end
		Say(("  Keybinds' tile %s"):format(tile and "found" or "NOT FOUND"))
		-- (a second between screenshots: two in one second save one file)
		Later(1, function()
			if tile then tile:GetScript("OnClick")(tile, "RightButton") end
			Later(1, function()
				Shot("7 removed")
				local after = fav:GetSubcategories()
				Verdict(tile ~= nil and not ns.IsFavorite("Keybinds") and PopupUp() and #after == 2,
					("Keybinds tile right-clicked: favorites %q, reload popup %s, lines still %d (2 wanted, they change after a reload)")
						:format(Favs(), PopupUp() and "up" or "NOT UP", #after))
				PopupDown()
				Fight()
			end)
		end)
	end)
end

-- 5 and 6: the lines after the reload, each one picked.
local function AfterReload()
	local state = State()
	local root = ns.settingsCategory
	Say("--- 5 of 8: the lines after the reload ---")
	ns.TestPrompt("Favorites test: 5 of 8, after the reload. Just watch.", 3)
	local blocked0 = Blocked()
	pcall(ns.OpenOptions, "Profiles")
	Later(1, function()
		Shot("5")
		local kids = root and root.GetSubcategories and root:GetSubcategories() or {}
		local fav = kids[1]
		local lines = fav and fav.GetSubcategories and fav:GetSubcategories() or {}
		local names = {}
		for _, c in ipairs(lines) do names[#names + 1] = c:GetName() end
		local open = fav and fav.IsExpanded and fav:IsExpanded()
		local saved = ns.Favorites()
		Verdict(fav and fav:GetName() == ns.L["Favorites"] and open and #saved == 2 and #names == 2
			and names[2] == saved[2].label and Blocked() == blocked0,
			("first line %q (Favorites wanted), open %s, under it %q (%d favorites), blocked +%d"):format(
				tostring(fav and fav:GetName()), tostring(open), table.concat(names, " | "), #saved, Blocked() - blocked0))
		Say("--- 6 of 8: each favorite's line picked ---")
		local i = 0
		local function NextLine()
			i = i + 1
			local line, want = lines[i], saved[i]
			if not (line and want) then return FavoritesPage(fav) end
			local b6 = Blocked()
			pcall(ns.PickSettingsCategory, _G.SettingsPanel, line)
			Later(1.5, function()
				Shot("6." .. i)
				local here = ns.FavoriteHere()
				local star = ns.FavoriteStarShown()
				Verdict(Same(here, want) and star and star.on and Blocked() == b6,
					("line %q picked: at %s (%s wanted), star %s, blocked +%d"):format(tostring(line:GetName()),
						Where(here), Where(want), OnText(star), Blocked() - b6))
				Later(0.5, NextLine)
			end)
		end
		Later(0.5, NextLine)
		state.stage = 3
	end)
end

-- 3: a place two rows of tabs deep: Style General's inner row at Visions.
local function Deep(after)
	Say("--- 3 of 8: a place two rows of tabs deep ---")
	ns.TestPrompt("Favorites test: 3 of 8, Style General at its Visions tab. Just watch.", 3)
	pcall(ns.OpenOptions, "Style General")
	Later(1, function()
		local row, visions = RowWith(ns.L["Visions"])
		local _, interface = RowWith(ns.L["Interface"])
		if not row then
			local shown = {}
			for _, each in ipairs(ns.tabRows or {}) do
				local lit = each.tabs[each.tabs.picked or 0]
				if lit and lit:IsVisible() then shown[#shown + 1] = table.concat(each.labels, "/") end
			end
			Verdict(false, "no row with a Visions tab shown; rows shown: " .. table.concat(shown, " | "))
			return Later(0.5, after)
		end
		pcall(row.click, visions)
		Later(1, function()
			local star = Star()
			if star then star:Click() end
			Later(0.5, function()
				Shot("3")
				local list = ns.Favorites()
				local saved = list[#list]
				local deep = saved and saved.page ~= "Keybinds" and #saved.tabs >= 2
					and saved.tabs[#saved.tabs].label == ns.L["Visions"]
				Verdict(deep and PopupUp(), ("starred: %s (2 rows or more, the last at Visions), popup %s"):format(
					Where(saved), PopupUp() and "up" or "NOT UP"))
				PopupDown()
				pcall(row.click, interface)
				Later(1, function()
					local now = ns.FavoriteStarShown()
					Verdict(now and now.on == false, ("Interface clicked: at %s, star %s (off wanted: another place)"):format(
						Where(ns.FavoriteHere()), OnText(now)))
					pcall(ns.OpenOptions, "Keybinds")
					Later(1, function()
						ns.OpenFavorite(saved)
						Later(1.5, function()
							Shot("3 opened")
							local here = ns.FavoriteHere()
							local back = ns.FavoriteStarShown()
							Verdict(Same(here, saved) and back and back.on,
								("Keybinds, then the favorite opened: at %s (%s wanted), star %s"):format(Where(here),
									Where(saved), OnText(back)))
							Later(0.5, after)
						end)
					end)
				end)
			end)
		end)
	end)
end

-- 1 and 2: Keybinds' star, then starred; then 3; then 4, the reload.
local function BeforeReload()
	Say("--- 1 of 8: Keybinds' star ---")
	ns.TestPrompt("Favorites test: 1 of 8, Keybinds. Just watch.", 3)
	pcall(ns.OpenOptions, "Keybinds")
	Later(1, function()
		Shot("1")
		local star, where = Star()
		Say(("  star art %s"):format(tostring(ns.FavoriteStarArt())))
		Verdict(star and where == "left of its search box" and star.on == false,
			("star %s, %s, %s (off wanted)"):format(star and "shown" or "NONE", where, OnText(star)))
		-- (the click a second after the shot: a shot takes the frame's end state)
		Later(1, function()
			Say("--- 2 of 8: Keybinds starred ---")
			if star then star:Click() end
		end)
		Later(2, function()
			Shot("2")
			local list = ns.Favorites()
			Verdict(star and star.on and #list == 1 and list[1].page == "Keybinds" and PopupUp(),
				("clicked: favorites %q, star %s, reload popup %s"):format(Favs(), OnText(star),
					PopupUp() and "up" or "NOT UP"))
			PopupDown()
			Later(1, function()
				Deep(function()
					Say("--- 4 of 8: reload from the popup ---")
					State().stage = 2
					Close()
					-- (the popup again, as a star changed asks: the last favorite off and on)
					local last = ns.Favorites()[#ns.Favorites()]
					if last then
						ns.SetFavorite(last, false)
						ns.SetFavorite(last, true)
					end
					Say(("  favorites %q, reload popup %s"):format(Favs(), PopupUp() and "up" or "NOT UP"))
					Shot("4")
					ns.TestPrompt("Favorites test: 4 of 8. Click Reload in the popup.", 3600)
				end)
			end)
		end)
	end)
end

function ns.FavoritesTest()
	if State() then return Finish("stopped") end
	if not (CinematicDB and ns.DevErrorCount and ns.SetFavorite and ns.FavoriteStarShown and ns.settingsCategory) then
		ns.Print("/cine debug favorites: the dev error box or the settings aren't there.")
		return
	end
	if InCombatLockdown() then
		ns.Print("/cine debug favorites: start it out of a fight.")
		return
	end
	CinematicDB.favoritesTestLog = {}
	local saved = {}
	for _, place in ipairs(ns.Favorites()) do saved[#saved + 1] = place end
	CinematicDB.favoritesTest = { stage = 1, saved = saved, pass = 0, fail = 0 }
	Say(("start: %s (game %s), gamepad UI %s, your favorites put aside: %s"):format(ns.isRetail and "retail" or "Forever",
		tostring((select(4, GetBuildInfo()))), _G.SmartNavigation and "there" or "not there",
		#saved > 0 and Favs() or "none"))
	CinematicDB.favorites = {}
	if ns.IsCineModeOn and ns.IsCineModeOn() and Cinematic_ToggleCineMode then pcall(Cinematic_ToggleCineMode) end
	Close()
	C_Timer.After(0.5, BeforeReload)
end

-- After the reload the test asked for: the rest, once the game has settled.
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(self)
	self:UnregisterAllEvents()
	local state = State()
	if not state then return end
	if state.stage ~= 2 then
		-- (stopped by a reload mid-run: your favorites back)
		Say("  reloaded before the test asked: stopped")
		return Finish("stopped")
	end
	Say(("  reloaded; favorites %q"):format(Favs()))
	C_Timer.After(4, AfterReload)
end)
