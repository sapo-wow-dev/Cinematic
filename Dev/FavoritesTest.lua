-- /cine debug favorites: the Favorites feature (UI/Favorites.lua) in game,
-- one run, no reload. It sets itself up (your favorites put aside, CineMode
-- off) and says each step on screen; you drag one tile when asked. (No fight
-- step since 2026-11-21: Escape > Options in a fight was 0 blocked three runs
-- running, and nothing since touches the left list.) Steps:
--   1 star      Keybinds opened: one star, left of its search box's border,
--               off (PASS/FAIL)
--   2 add       its star clicked: Keybinds in your favorites, the star on, no
--               popup (no reload) (PASS/FAIL)
--   3 deep      Style General opened, its inner row's Visions tab clicked,
--               starred: the favorite keeps that tab (PASS/FAIL); Interface
--               clicked: the star off, another place (PASS/FAIL); Keybinds
--               opened, then the favorite: Style General back at Visions (PASS/FAIL)
--   4 rename    Style General's favorite renamed "Test Visions" in its rename
--               popup (typed, Enter) (PASS/FAIL)
--   5 line      the Favorites line: first under Cinematic, no lines under it;
--               picked: its page, its own star not drawn (PASS/FAIL), a tile a
--               favorite, the new name on its tile, no popup, blocked +0 (PASS/FAIL)
--   6 open      each tile clicked: its page at its tabs, the star on,
--               blocked +0 (PASS/FAIL)
--   7 menu      Keybinds' tile (the first) right-clicked: its menu (Open,
--               Rename, Change icon, Move right, Remove) opens (PASS/FAIL); its
--               Move right: the tiles swap at once (PASS/FAIL); you drag
--               Keybinds' tile back to the front (the test waits): first again,
--               nothing opened (PASS/FAIL); Change icon: the picker opens
--               (PASS/FAIL); an icon picked: on its tile (PASS/FAIL); Default
--               icon: the page's back (PASS/FAIL); its Remove: the tile gone at
--               once, no popup (PASS/FAIL)
-- Then your own favorites are put back. Into CinematicDB.favoritesTestLog, a
-- screenshot a step. Run again to stop. Dev copy only.
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
	for _, place in ipairs(ns.Favorites()) do names[#names + 1] = ns.FavoriteName(place) end
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
-- A popup shown now (any: Favorites asks for nothing but a rename), by its name.
local function PopupShown()
	for n = 1, (_G.STATICPOPUP_NUMDIALOGS or 4) do
		local dialog = _G["StaticPopup" .. n]
		if dialog and dialog:IsShown() then return tostring(dialog.which) end
	end
end
-- The tiles shown now, by name.
local function TileNames()
	local out = {}
	for _, tile in ipairs(ns.FavoriteTiles()) do
		if tile:IsVisible() then out[#out + 1] = tile.name:GetText() end
	end
	return out
end
-- The Favorites line: Cinematic's first.
local function FavLine()
	local root = ns.settingsCategory
	local kids = root and root.GetSubcategories and root:GetSubcategories() or {}
	return kids[1]
end
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
local state5 -- (tiles a row as the Favorites page showed: later paints keep it)
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
	-- (your own favorites back)
	CinematicDB.favorites = state.saved or {}
	if ns.FavoriteStarsPaint then ns.FavoriteStarsPaint() end
	Say(("  your favorites put back: %s"):format(Favs()))
	local line = ("%s: %d pass, %d fail"):format(text, state.pass, state.fail)
	Say(line)
	CinematicDB.favoritesTest = nil
	ns.TestPrompt(("Favorites test %s. Say \"check log\"."):format(line), 12)
end

-- The tile showing a favorite of page, shown now.
local function TileOf(name)
	for _, each in ipairs(ns.FavoriteTiles()) do
		if each:IsVisible() and each.page == name then return each end
	end
end
local function Order() return table.concat(TileNames(), " | ") end

-- Keybinds' icon: Change icon opens the picker under its tile; an icon set
-- (as a pick in it does); Default icon puts its page's back.
local PICKED = 134400 -- (the question mark icon's file)
local function Icons(after)
	local L = ns.L
	local tile = TileOf("Keybinds")
	local place = tile and tile.place
	local before = tile and tile.icon:GetTexture()
	local change
	for _, item in ipairs(place and ns.FavoriteMenuItems(place) or {}) do
		if item[1] == L["Change icon"] then change = item[2] end
	end
	if change then change(tile) end
	Later(1, function()
		Shot("7 picker")
		local picker = ns.FavoriteIconPicker()
		Verdict(change and picker and picker:IsShown() and before ~= nil,
			("Change icon: picker %s, the tile's icon %s before"):format(picker and picker:IsShown() and "open" or "NOT OPEN",
				tostring(before)))
		Later(1, function()
			ns.FavoriteSetIcon(place, PICKED)
			if picker then picker:Hide() end
			Later(1, function()
				Shot("7 icon")
				local now = TileOf("Keybinds")
				local got = now and now.icon:GetTexture()
				Verdict(place.icon == PICKED and got == PICKED, ("an icon picked: saved %s, tile shows %s (%d wanted)"):format(
					tostring(place.icon), tostring(got), PICKED))
				local default
				for _, item in ipairs(ns.FavoriteMenuItems(place)) do
					if item[1] == L["Default icon"] then default = item[2] end
				end
				-- (a second after the shot, which takes the frame's end state)
				Later(1, function() if default then default() end end)
				Later(2, function()
					local back = TileOf("Keybinds")
					local again = back and back.icon:GetTexture()
					local still = false
					for _, item in ipairs(ns.FavoriteMenuItems(place)) do
						if item[1] == L["Default icon"] then still = true end
					end
					Verdict(default and place.icon == nil and again == before and not still,
						("Default icon: tile shows %s (%s wanted), Default icon %s"):format(tostring(again), tostring(before),
							still and "STILL OFFERED" or "gone from the menu"))
					after()
				end)
			end)
		end)
	end)
end

-- 7: Keybinds' tile right-clicked: its menu, Move right, your drag back, Remove.
local function Menu()
	Say("--- 7 of 7: a tile's menu, moves and Remove ---")
	ns.TestPrompt("Favorites test: 7 of 7, a tile's menu. Just watch.", 3)
	pcall(ns.PickSettingsCategory, _G.SettingsPanel, FavLine())
	Later(1, function()
		local tile = TileOf("Keybinds")
		Say(("  Keybinds' tile %s, tiles %q"):format(tile and "found" or "NOT FOUND", Order()))
		if tile then tile:GetScript("OnClick")(tile, "RightButton") end
		Later(1, function()
			Shot("7 menu")
			local menu = tile and tile.menu
			local open = menu and menu.IsShown and menu:IsShown()
			local items = {}
			for _, item in ipairs(tile and ns.FavoriteMenuItems(tile.place) or {}) do items[#items + 1] = item[1] end
			local L = ns.L
			Verdict(open and table.concat(items, ",") == table.concat({ L["Open"], L["Rename"], L["Change icon"], L["Move right"],
				L["Remove"] }, ","),
				("Keybinds tile (first) right-clicked: menu %s, items %s (Open, Rename, Change icon, Move right, Remove wanted)"):format(
					open and "open" or "NOT OPEN", table.concat(items, ", ")))
			-- (its Move right a second after the shot: the function the menu's button runs)
			Later(1, function()
				if menu and menu.Close then pcall(menu.Close, menu) elseif menu and menu.Hide then menu:Hide() end
				local keys = tile and tile.place
				for _, item in ipairs(keys and ns.FavoriteMenuItems(keys) or {}) do
					if item[1] == L["Move right"] then item[2]() end
				end
				Later(1, function()
					Shot("7 moved")
					local list = ns.Favorites()
					Verdict(list[2] and list[2].page == "Keybinds" and Order():find("^Test Visions") ~= nil
						and ns.FavoriteTilesPerRow() == state5,
						("Move right: tiles %q (Test Visions first wanted), %d a row (%s wanted: as when the page showed)"):format(
							Order(), ns.FavoriteTilesPerRow(), tostring(state5)))
					-- Your drag: Keybinds' tile back to the front.
					local shown = ns.FavoritesPage()
					WaitFor("Favorites test: 7 of 7. Drag the Keybinds tile in front of Test Visions. The test waits.",
						function() local l = ns.Favorites() return l[1] and l[1].page == "Keybinds" end, function()
							ns.TestPrompt("Favorites test: got it. Just watch.", 3)
							Later(1, function()
								Shot("7 dragged")
								Verdict(Order():find("^Keybinds") ~= nil and shown:IsVisible() and ns.FavoriteTilesPerRow() == state5,
									("dragged: tiles %q (Keybinds first wanted), Favorites page %s (nothing opened), %d a row (%s wanted)"):format(
										Order(), shown:IsVisible() and "still shown" or "GONE", ns.FavoriteTilesPerRow(), tostring(state5)))
								local first = TileOf("Keybinds")
								Later(1, function() Icons(function()
									if first then ns.FavoriteMenuItems(first.place)[#ns.FavoriteMenuItems(first.place)][2]() end
									Later(1, function()
										Shot("7 removed")
										local names = TileNames()
										Verdict(first ~= nil and not ns.IsFavorite("Keybinds") and #names == 1
											and names[1] == "Test Visions" and not PopupShown(),
											("Remove picked: favorites %q, tiles %q (Test Visions alone wanted), popup %s"):format(
												Favs(), table.concat(names, " | "), PopupShown() or "none"))
										Finish("DONE")
									end)
								end) end)
							end)
						end)
				end)
			end)
		end)
	end)
end

-- 5 and 6: the Favorites line and its page, then each tile clicked.
local function Line()
	Say("--- 5 of 7: the Favorites line ---")
	ns.TestPrompt("Favorites test: 5 of 7, the Favorites line. Just watch.", 3)
	local fav = FavLine()
	local under = fav and fav.GetSubcategories and fav:GetSubcategories() or {}
	local blocked0 = Blocked()
	if fav then pcall(ns.PickSettingsCategory, _G.SettingsPanel, fav) end
	Later(1, function()
		Shot("5")
		-- (the page's own star: nothing to star there, none drawn)
		local own = ns.FavoriteStarShown()
		Verdict(own and own.none and own.icon:GetAlpha() == 0 and not own:IsMouseEnabled(),
			("Favorites page's star: %s"):format(not own and "NONE (its box's star missing)"
				or (own.none and own.icon:GetAlpha() == 0) and "not drawn, not clickable" or "DRAWN"))
		local page = ns.FavoritesPage()
		-- (one column: a tile a row, the user's call 2026-11-21)
		local perRow = ns.FavoriteTilesPerRow()
		state5 = perRow
		Verdict(perRow == 1, ("tiles a row: %d (1 wanted: one column)"):format(perRow))
		local names = TileNames()
		local saved = ns.Favorites()
		Verdict(fav and fav:GetName() == ns.L["Favorites"] and #under == 0 and page and page:IsVisible()
			and #names == 2 and names[1] == ns.FavoriteName(saved[1]) and names[2] == "Test Visions"
			and not PopupShown() and Blocked() == blocked0,
			("first line %q (Favorites wanted), %d lines under it (0 wanted), page %s, tiles %q, popup %s, blocked +%d"):format(
				tostring(fav and fav:GetName()), #under, page and page:IsVisible() and "shown" or "NOT SHOWN",
				table.concat(names, " | "), PopupShown() or "none", Blocked() - blocked0))
		Say("--- 6 of 7: each tile clicked ---")
		local i = 0
		local function NextTile()
			i = i + 1
			local want = saved[i]
			if not want then return Menu() end
			pcall(ns.PickSettingsCategory, _G.SettingsPanel, fav)
			Later(1, function()
				local tile
				for _, each in ipairs(ns.FavoriteTiles()) do
					if each:IsVisible() and each.place == want then tile = each end
				end
				local b6 = Blocked()
				if tile then tile:Click("LeftButton") end
				Later(1.5, function()
					Shot("6." .. i)
					local here = ns.FavoriteHere()
					local star = ns.FavoriteStarShown()
					Verdict(tile and Same(here, want) and star and star.on and Blocked() == b6,
						("tile %q clicked: at %s (%s wanted), star %s, blocked +%d"):format(ns.FavoriteName(want),
							Where(here), Where(want), OnText(star), Blocked() - b6))
					Later(0.5, NextTile)
				end)
			end)
		end
		Later(0.5, NextTile)
	end)
end

-- 4: the deep favorite renamed in its own popup (the text typed, Enter pressed).
local function Rename()
	Say("--- 4 of 7: renamed ---")
	ns.TestPrompt("Favorites test: 4 of 7, a favorite renamed. Just watch.", 3)
	local deep = ns.Favorites()[2]
	local which = ns.FavoriteRenamePopup()
	if deep then ns.FavoriteRenameAsk(deep) end
	local popup = StaticPopup_FindVisible and StaticPopup_FindVisible(which)
	local box = popup and (popup.editBox or popup.EditBox or (popup.GetEditBox and popup:GetEditBox()))
	local had = box and box:GetText()
	Later(1, function()
		Shot("4")
		if box then
			box:SetText("Test Visions")
			local enter = box:GetScript("OnEnterPressed")
			if enter then pcall(enter, box) end
		end
		local closed = not PopupShown()
		Verdict(deep and box and had == deep.label and ns.FavoriteName(deep) == "Test Visions" and closed,
			("renamed in its popup: box had %q, name now %q (Test Visions wanted), popups %s"):format(
				tostring(had), deep and ns.FavoriteName(deep) or "?", closed and "none left" or PopupShown()))
		Later(1, Line)
	end)
end

-- 3: a place two rows of tabs deep: Style General's inner row at Visions.
local function Deep(after)
	Say("--- 3 of 7: a place two rows of tabs deep ---")
	ns.TestPrompt("Favorites test: 3 of 7, Style General at its Visions tab. Just watch.", 3)
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
				Verdict(deep and not PopupShown(), ("starred: %s (2 rows or more, the last at Visions), popup %s"):format(
					Where(saved), PopupShown() or "none"))
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

-- 1 and 2: Keybinds' star, then starred; then 3 on.
local function Start()
	Say("--- 1 of 7: Keybinds' star ---")
	ns.TestPrompt("Favorites test: 1 of 7, Keybinds. Just watch.", 3)
	pcall(ns.OpenOptions, "Keybinds")
	Later(1, function()
		Shot("1")
		local star, where = Star()
		Say(("  star art %s"):format(tostring(ns.FavoriteStarArt())))
		Verdict(star and where == "left of its search box" and star.on == false,
			("star %s, %s, %s (off wanted)"):format(star and "shown" or "NONE", where, OnText(star)))
		-- (the click a second after the shot: a shot takes the frame's end state)
		Later(1, function()
			Say("--- 2 of 7: Keybinds starred ---")
			if star then star:Click() end
		end)
		Later(2, function()
			Shot("2")
			local list = ns.Favorites()
			Verdict(star and star.on and #list == 1 and list[1].page == "Keybinds" and not PopupShown(),
				("clicked: favorites %q, star %s, popup %s"):format(Favs(), OnText(star), PopupShown() or "none"))
			Later(1, function() Deep(Rename) end)
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
	CinematicDB.favoritesTest = { saved = saved, pass = 0, fail = 0 }
	Say(("start: %s (game %s), gamepad UI %s, your favorites put aside: %s"):format(ns.isRetail and "retail" or "Forever",
		tostring((select(4, GetBuildInfo()))), _G.SmartNavigation and "there" or "not there",
		#saved > 0 and Favs() or "none"))
	CinematicDB.favorites = {}
	if ns.IsCineModeOn and ns.IsCineModeOn() and Cinematic_ToggleCineMode then pcall(Cinematic_ToggleCineMode) end
	Close()
	C_Timer.After(0.5, Start)
end

-- A reload mid-run: stopped, your favorites back.
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(self)
	self:UnregisterAllEvents()
	if State() then
		Say("  reloaded mid-run: stopped")
		Finish("stopped")
	end
end)
