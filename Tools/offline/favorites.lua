-- Favorites check (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/favorites.lua < /dev/null
-- UI/Favorites.lua on a stand-in settings window that keeps its categories
-- (Settings.Register*). Checked: with favorites saved (old plain names and a
-- place with a tab), the Favorites line is first under Cinematic, no lines
-- under it, a tile a favorite in the order starred, a tab's name after its
-- page's; with none, the line there all the same; a star left of every search
-- box; places added and taken off (same page, other tab: another place), the
-- tiles changed at once, never a reload asked, the left list never touched;
-- a favorite's tabs clicked open by row, top first, stopping at a row not
-- found; a tile's menu, rename and remove. Says PASS or FAIL.
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
Check("no lines under it (the tiles are on its page)", fav and #fav.subcategories == 0, fav and Names(fav.subcategories))
local ARROW = " " .. string.char(226, 128, 186) .. " " -- (the arrow between a page and its tab)
-- (the tiles, as the page shows them)
local function TileNames()
	local out = {}
	for _, tile in ipairs(ns.FavoriteTiles()) do if tile:IsShown() then out[#out + 1] = tile.name:GetText() end end
	return table.concat(out, ", ")
end
ns.FavoritesPage():GetScript("OnShow")(ns.FavoritesPage())
Check("a tile a favorite, in the order starred, a tab's name after its page's",
	TileNames() == "Combat Text, Profiles, Cooldown Manager" .. ARROW .. "CDM", TileNames())
Check("old names read as places", type(ns.Favorites()[1]) == "table" and ns.Favorites()[1].page == "Combat Text Style")
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

-- Places: added, found, taken off; the tiles at once, no popup ever.
local shown = {}
StaticPopup_Show = function(which) shown[which] = true end
StaticPopup_Hide = function(which) shown[which] = nil end
local function Popups() local n = 0 for _ in pairs(shown) do n = n + 1 end return n end
local place = { page = "Keybinds", tabs = { { key = "Keybinds|General/Wheels", index = 2, label = "Wheels" } } }
Check("a place added", ns.SetFavorite(place, true) == true and #ns.Favorites() == 4)
Check("its name: page, then its tab", ns.Favorites()[4].label == "Keybinds" .. ARROW .. "Wheels", ns.Favorites()[4].label)
Check("its tile at once", TileNames():find("Keybinds" .. ARROW .. "Wheels", 1, true) ~= nil, TileNames())
Check("no popup (no reload)", Popups() == 0)
local other = { page = "Keybinds", tabs = { { key = "Keybinds|General/Wheels", index = 1, label = "General" } } }
Check("same page, another tab: not that favorite", ns.IsFavorite(other) == false and ns.IsFavorite(place) == true)
Check("added again: no change", ns.SetFavorite({ page = "Keybinds", tabs = { { key = "Keybinds|General/Wheels", index = 2 } } }, true) == false)
Check("taken off", ns.SetFavorite(place, false) == true and #ns.Favorites() == 3)
Check("its tile gone at once", not TileNames():find("Wheels", 1, true), TileNames())
Check("still no popup", Popups() == 0)
Check("no line made or changed after login", #registered == count and #fav.subcategories == 0)

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
-- Its right-click: a menu (Open, Rename, Remove) where the client has menus.
local made = {}
local menuRoot = {
	CreateTitle = function(_, text) made[#made + 1] = "title:" .. text end,
	CreateDivider = function() made[#made + 1] = "-" end,
	CreateButton = function(_, text, fn) made[#made + 1] = text; made[text] = fn end,
}
local keptMenuUtil, keptContext = MenuUtil, ns.ContextMenu
MenuUtil = { CreateContextMenu = function() end }
ns.ContextMenu = function(owner, generator) generator(owner, menuRoot); return "menu" end
if tile then tile:GetScript("OnClick")(tile, "RightButton") end
local red = "|cffff4040Remove|r"
Check("right-click (the last tile): a menu titled with its name, Open, Rename, Change icon, Move left, Remove",
	table.concat(made, ",") == "title:" .. ns.FavoriteName(place) .. ",Open,Rename,Change icon,Move left,-," .. red
	and ns.IsFavorite(place), table.concat(made, ","))
-- Reordered: Move left from the menu, Move right back; the first has no Move left.
local function Order()
	local out = {}
	for _, each in ipairs(ns.Favorites()) do out[#out + 1] = each.page end
	return table.concat(out, ",")
end
local before = Order()
made["Move left"]()
Check("Move left: one place earlier, the tiles in that order",
	Order() == "Combat Text Style,Profiles,Keybinds,HUD:cdm" and TileNames():find("Keybinds" .. ARROW .. "Wheels, Cooldown", 1, true) ~= nil,
	Order() .. " / " .. TileNames())
local items = {}
for _, item in ipairs(ns.FavoriteMenuItems(place)) do items[#items + 1] = item[1] end
Check("in the middle: both moves offered", table.concat(items, ",") == "Open,Rename,Change icon,Move left,Move right,Remove", table.concat(items, ","))
ns.FavoriteMenuItems(place)[5][2]()
Check("Move right: back where it was", Order() == before, Order())
items = {}
for _, item in ipairs(ns.FavoriteMenuItems(ns.Favorites()[1])) do items[#items + 1] = item[1] end
Check("the first: no Move left", table.concat(items, ",") == "Open,Rename,Change icon,Move right,Remove", table.concat(items, ","))
Check("moved to where it is, or nowhere: no change", ns.MoveFavorite(place, 4) == false and ns.MoveFavorite({ page = "Nope", tabs = {} }, 1) == false)
-- Dragged: the Keybinds tile let go over the first cell (the cursor read
-- against the grid's cells) goes first.
local grid = tile:GetParent()
grid.GetLeft, grid.GetTop, grid.GetEffectiveScale = function() return 100 end, function() return 500 end, function() return 1 end
tile.GetEffectiveScale, tile.GetLeft, tile.GetTop = function() return 1 end, function() return 300 end, function() return 500 end
local cursorX, cursorY = 110, 490
GetCursorPosition = function() return cursorX, cursorY end
local keptGetTime = GetTime
GetTime = function() return 50 end
tile:GetScript("OnDragStart")(tile)
Check("drag started: the tile lifted", tile.dragging == true)
tile:GetScript("OnDragStop")(tile)
Check("dropped on the first cell: first", ns.Favorites()[1] == place, Order())
local opened = 0
local keptOpen = ns.OpenFavorite
ns.OpenFavorite = function() opened = opened + 1 end
tile:GetScript("OnClick")(tile, "LeftButton")
Check("the click ending the drag doesn't open it", opened == 0)
ns.OpenFavorite = keptOpen
GetTime = keptGetTime
tile.dropped = nil
ns.MoveFavorite(place, 4)
Check("moved back last", Order() == before, Order())
-- Rename: the popup, a name given, shown on the tile, no reload asked.
shown = {}
if made.Rename then made.Rename() end
local rename = ns.FavoriteRenamePopup()
Check("Rename: its popup shown", shown[rename] and StaticPopupDialogs[rename] and StaticPopupDialogs[rename].hasEditBox)
local box = { text = "", GetText = function(self) return self.text end }
shown = {}
StaticPopupDialogs[rename].OnAccept({ editBox = box }, place) -- (empty: no change)
Check("an empty name: its own kept", ns.Favorites()[#ns.Favorites()].name == nil)
box.text = "  My keys  "
shown = {}
StaticPopupDialogs[rename].OnAccept({ editBox = box }, place)
local last = ns.Favorites()[#ns.Favorites()]
Check("renamed: the name kept, trimmed", ns.FavoriteName(last) == "My keys" and last.name == "My keys", ns.FavoriteName(last))
Check("renamed: the tile shows it", tile and tile.name:GetText() == "My keys", tile and tile.name:GetText())
Check("renamed: only the rename popup, no reload", Popups() == 0, Popups())
box.text = ""
StaticPopupDialogs[rename].OnAccept({ editBox = box }, place)
Check("an empty name: back to its own", ns.Favorites()[#ns.Favorites()].name == nil and tile.name:GetText() == ns.FavoriteLabel(place))
-- Remove from the menu.
if made[red] then made[red]() end
Check("Remove: taken off", #ns.Favorites() == 3 and not ns.IsFavorite(place))
-- No menus on the client: the right-click takes it off at once.
MenuUtil, ns.ContextMenu = false, keptContext -- (false: nil brings back the stand-in)
ns.SetFavorite(place, true)
if tile then tile:GetScript("OnClick")(tile, "RightButton") end
Check("no menus: right-click takes it off", #ns.Favorites() == 3 and not ns.IsFavorite(place))
MenuUtil = keptMenuUtil
Check("Favorites can't be its own favorite", ns.SetFavorite("Favorites", true) == false)
ns.SetFavorite("Profiles", false)
Check("a page's name off: every favorite of it", not ns.IsFavorite("Profiles") and #ns.Favorites() == 2)

-- Icons: a page's own by default (a hub page's), Cinematic's for a page
-- with none; Change icon opens the picker under the tile; a pick sets it on
-- the tile; Default icon (there only then) puts the page's back.
ns.SetFavorite(place, true)
local function TileOf(page)
	for _, each in ipairs(ns.FavoriteTiles()) do if each:IsShown() and each.page == page then return each end end
end
local painted = {}
for _, each in ipairs(ns.FavoriteTiles()) do
	each.icon.SetTexture = function(self, icon) painted[self] = icon end
	each.icon.SetAtlas = function(self, icon) painted[self] = icon end
end
ns.FavoritePaintTiles()
local combat = TileOf("Combat Text Style")
Check("a hub page's tile: its page's icon", combat and painted[combat.icon] ~= nil and painted[combat.icon] == ns.PageIcon("Combat Text Style"),
	combat and tostring(painted[combat.icon]))
local keys = TileOf("Keybinds")
Check("a page with no icon: Cinematic's", keys and painted[keys.icon] == "Interface\\Icons\\INV_Misc_Spyglass_03",
	keys and tostring(painted[keys.icon]))
local picker = ns.FavoriteIconPicker()
local openedFor, openedOwner
if picker then picker.Open = function(_, owner, key) openedOwner, openedFor = owner, key end end
local change
for _, item in ipairs(ns.FavoriteMenuItems(place)) do if item[1] == "Change icon" then change = item[2] end end
if change then change(keys) end
Check("Change icon: the picker opened for that favorite, under its tile", picker and openedFor == place and openedOwner == keys)
local hasDefault = false
for _, item in ipairs(ns.FavoriteMenuItems(place)) do if item[1] == "Default icon" then hasDefault = true end end
Check("no Default icon while it has its page's", not hasDefault)
Check("a pick: set on the favorite", ns.FavoriteSetIcon(place, 132089) == true and ns.FavoriteIcon(place) == 132089)
keys = TileOf("Keybinds")
Check("a pick: shown on its tile", keys and painted[keys.icon] == 132089, keys and tostring(painted[keys.icon]))
local default
for _, item in ipairs(ns.FavoriteMenuItems(place)) do if item[1] == "Default icon" then default = item[2] end end
if default then default() end
Check("Default icon: the page's back", default ~= nil and place.icon == nil and painted[TileOf("Keybinds").icon] == "Interface\\Icons\\INV_Misc_Spyglass_03")
ns.SetFavorite(place, false)

-- The Favorites page's own star: nothing to star there, not drawn or clickable.
local favBox = ns.FavoritesPage() and ns.FavoritesPage().searchBox
local favStar = favBox and favBox.favoriteStar
local keptShown = ns.ShownOptionsPage
-- (the page left still read as shown, as in game: the star known by its own box)
ns.ShownOptionsPage = function() return "Keybinds" end
local alpha
if favStar then
	favStar.IsVisible = function() return true end
	favStar.icon.SetAlpha = function(_, a) alpha = a end -- (the stand-in texture keeps no alpha)
	ns.FavoriteStarsPaint()
end
Check("the Favorites page's star: not drawn, not clickable", favStar and favStar.none and alpha == 0
	and not favStar:IsMouseEnabled(), favStar and ("none %s, alpha %s, mouse %s"):format(tostring(favStar.none), tostring(alpha), tostring(favStar:IsMouseEnabled())) or "no star on its box")
ns.ShownOptionsPage = keptShown

-- 2. No favorites: the Favorites line there all the same, its page saying how.
local ns2, _, registered2 = Load({})
local root2 = Root(registered2)
Check("no favorites: the Favorites line still first", root2 and root2.subcategories[1] and root2.subcategories[1].name == "Favorites",
	root2 and Names(root2.subcategories))
Check("no favorites: its page made", ns2.FavoritesPage() ~= nil)
Check("no favorites: an empty saved list", ns2.Favorites() and #ns2.Favorites() == 0)

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
-- luacheck: pop
