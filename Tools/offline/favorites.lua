-- Favorites check (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/favorites.lua < /dev/null
-- UI/Favorites.lua on a stand-in settings window that keeps its categories
-- (Settings.Register*). Checked: with favorites saved (old plain names and a
-- place with a tab), the Favorites line is first under Cinematic with one
-- line a favorite under it, open, in the order starred, a tab's name after its
-- page's; with none, no Favorites line; a star left of every search box;
-- places added and taken off (same page, other tab: another place), a reload
-- asked only while the list differs from login's, the left list never
-- touched; a favorite's tabs clicked open by row, top first, stopping at a
-- row not found. Says PASS or FAIL.
-- luacheck: push ignore 111 112 113 121 122 212 432
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

-- Categories as the game keeps them: a name, children, a parent.
local function Install(saved, registered)
	return function(wow)
		local Category = {}
		Category.__index = Category
		function Category:GetName() return self.name end
		function Category:GetID() return self.id end
		function Category:GetParentCategory() return self.parent end
		function Category:GetSubcategories() return self.subcategories end
		function Category:SetExpanded(open) self.expanded = open end
		function Category:IsExpanded() return self.expanded end
		local id = 0
		local function New(frame, name, parent)
			id = id + 1
			local c = setmetatable({ name = name, frame = frame, subcategories = {}, parent = parent, id = id }, Category)
			if parent then table.insert(parent.subcategories, c) end
			registered[#registered + 1] = c
			return c
		end
		Settings = {
			RegisterCanvasLayoutCategory = function(frame, name) return New(frame, name) end,
			RegisterCanvasLayoutSubcategory = function(parent, frame, name) return New(frame, name, parent) end,
			RegisterAddOnCategory = function() end,
			OpenToCategory = function() end,
		}
		CinematicDB = saved
	end
end

local function Load(saved)
	local registered = {}
	local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", Install(saved, registered))
	return ns, wow, registered
end
local function Root(registered)
	for _, c in ipairs(registered) do if c.name == "Cinematic" and not c.parent then return c end end
end
local function Names(list)
	local out = {}
	for _, c in ipairs(list or {}) do out[#out + 1] = c.name end
	return table.concat(out, ", ")
end

-- 1. Favorites saved: two old plain names (a hub icon, Combat Text Style;
-- a page with a line, Profiles) and a place with a tab open (Cooldown
-- Manager at its CDM tab).
local ns, _, registered = Load({ favorites = { "Combat Text Style", "Profiles",
	{ page = "HUD:cdm", tabs = { { key = "Standard Frames|Show/CDM/Settings", index = 2, label = "CDM" } } } } })
local root = Root(registered)
Check("Cinematic's category made", root ~= nil)
local fav = root and root.subcategories[1]
Check("Favorites is the first line under Cinematic", fav and fav.name == "Favorites", root and Names(root.subcategories))
local lines = fav and Names(fav.subcategories)
local ARROW = " " .. string.char(226, 128, 186) .. " " -- (the arrow between a page and its tab)
Check("its lines, in the order starred, a tab's name after its page's", lines == "Combat Text, Profiles, Cooldown Manager" .. ARROW .. "CDM", lines)
Check("Favorites open (lines shown)", fav and fav.expanded == true)
Check("old names read as places", type(ns.Favorites()[1]) == "table" and ns.Favorites()[1].page == "Combat Text Style")
Check("line 1 (Combat Text Style): a hub line", ns.FavoriteLineKind(1) == "hub", ns.FavoriteLineKind(1))
Check("line 2 (Profiles): a page line", ns.FavoriteLineKind(2) == "page", ns.FavoriteLineKind(2))
Check("line 3 (Cooldown Manager): a hub line", ns.FavoriteLineKind(3) == "hub", ns.FavoriteLineKind(3))
local count = #registered

-- A star left of every "Search this page" box: the hubs' and the plain pages'.
local stars = ns.FavoriteStars()
local onBox = 0
for _, star in ipairs(stars) do
	if star.box and star.box.favoriteStar == star and star:GetParent() == star.box:GetParent() then onBox = onBox + 1 end
end
Check("stars made, each left of its search box", #stars > 10 and onBox == #stars, #stars .. " stars, " .. onBox .. " on a box")
-- Each star placed from its box's drawn border (its Left piece when the box
-- has one; the real gap, 4 to 8 px, is measured in game: /cine debug favorites).
local spaced = 0
for _, star in ipairs(stars) do
	if star.edge and star.edge == (star.box.Left or star.box) then spaced = spaced + 1 end
end
Check("stars placed from the box's drawn border", spaced == #stars, spaced .. " of " .. #stars)

-- Places: added, found, taken off; the reload asked while the list differs.
local shown = {}
StaticPopup_Show = function(which) shown[which] = true end
StaticPopup_Hide = function(which) shown[which] = nil end
local popup = ns.FavoritesReloadPopup()
local place = { page = "Keybinds", tabs = { { key = "Keybinds|General/Wheels", index = 2, label = "Wheels" } } }
Check("a place added", ns.SetFavorite(place, true) == true and #ns.Favorites() == 4)
Check("its name: page, then its tab", ns.Favorites()[4].label == "Keybinds" .. ARROW .. "Wheels", ns.Favorites()[4].label)
Check("reload asked", shown[popup] == true)
Check("reload popup set up for Forever's cover", StaticPopupDialogs[popup] and StaticPopupDialogs[popup].cineReload == 1)
local other = { page = "Keybinds", tabs = { { key = "Keybinds|General/Wheels", index = 1, label = "General" } } }
Check("same page, another tab: not that favorite", ns.IsFavorite(other) == false and ns.IsFavorite(place) == true)
Check("added again: no change", ns.SetFavorite({ page = "Keybinds", tabs = { { key = "Keybinds|General/Wheels", index = 2 } } }, true) == false)
Check("taken off", ns.SetFavorite(place, false) == true and #ns.Favorites() == 3)
Check("back to login's list: reload ask taken away", shown[popup] == nil)
Check("no line made or changed after login", #registered == count)

-- A favorite's tabs opened again: each row found by its key and clicked at
-- its tab, top row first, a frame apart; a row not found ends it.
local queue = {}
C_Timer.After = function(_, fn) queue[#queue + 1] = fn end
local function Drain() local n = 0 while #queue > 0 and n < 100 do n = n + 1 table.remove(queue, 1)() end end
local clicks = {}
local function Row(owner, labels)
	local holder = CreateFrame("Frame")
	holder.pageName = owner
	local tabs = { picked = 1 }
	for i = 1, #labels do
		local tab = CreateFrame("Button", nil, holder)
		tab.IsVisible = function() return true end
		tabs[i] = tab
	end
	local row = { tabs = tabs, parent = holder, labels = labels }
	row.click = function(i) clicks[#clicks + 1] = owner .. ":" .. i tabs.picked = i end
	ns.tabRows[#ns.tabRows + 1] = row
	return row
end
local outer = Row("Test Page", { "General", "Themes" })
local inner = Row("Test Page", { "Interface", "Visions" })
ns.FavoriteOpenTabs({ page = "Test Page", tabs = {
	{ key = "Test Page|General/Themes", index = 1 }, { key = "Test Page|Interface/Visions", index = 2 } } })
Drain()
Check("tabs opened: the inner row's Visions clicked, the outer already right", table.concat(clicks, ",") == "Test Page:2"
	and inner.tabs.picked == 2 and outer.tabs.picked == 1, table.concat(clicks, ","))
clicks = {}
ns.FavoriteOpenTabs({ page = "Test Page", tabs = {
	{ key = "Test Page|Renamed/Row", index = 2 }, { key = "Test Page|Interface/Visions", index = 1 } } })
Drain()
Check("a row not found: nothing past it clicked", #clicks == 0, table.concat(clicks, ","))

-- (a tile a favorite on the Favorites page; its right-click takes it off)
ns.SetFavorite(place, true)
local tile
for _, each in ipairs(ns.FavoriteTiles()) do if each.page == "Keybinds" and each:IsShown() then tile = each end end
Check("Keybinds' tile on the Favorites page", tile ~= nil, #ns.FavoriteTiles() .. " tiles")
if tile then tile:GetScript("OnClick")(tile, "RightButton") end
Check("its right-click: taken off", #ns.Favorites() == 3 and not ns.IsFavorite(place))
Check("Favorites can't be its own favorite", ns.SetFavorite("Favorites", true) == false)
ns.SetFavorite("Profiles", false)
Check("a page's name off: every favorite of it", not ns.IsFavorite("Profiles") and #ns.Favorites() == 2)

-- 2. No favorites: no Favorites line.
local ns2, _, registered2 = Load({})
local root2 = Root(registered2)
Check("no favorites: no Favorites line", root2 and root2.subcategories[1] and root2.subcategories[1].name ~= "Favorites",
	root2 and Names(root2.subcategories))
Check("no favorites: an empty saved list", ns2.Favorites() and #ns2.Favorites() == 0)

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
-- luacheck: pop
