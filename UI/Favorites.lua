-- Favorites: a star left of each settings page's "Search this page" box adds
-- the place you're at to your favorites (or takes it off): the page, and the
-- tab open in every row of tabs on it, however deep, so a favorite opens
-- right there again. Kept for the whole account (CinematicDB.favorites, in
-- the order starred: { page = English name, tabs = { { key, index, label } },
-- label }; an old plain name: that page alone). At login a Favorites line
-- goes on top of Cinematic's left list, one line under it a favorite, only
-- while you have one; its page has a tile a favorite, changed as you star.
-- The lines are made at login only: the game's left list can't take lines
-- changed after that on Forever (/cine debug favlines 2026-11-20: Escape >
-- Options in a fight then blocked 1831 lines), so a star changed asks for a
-- reload. (The star by each page's title, placed by reading the page, broke
-- on page after page; the user picked this fixed spot, 2026-11-20.)
-- Tests: /cine debug favorites, /cine debug favstars (dev copy).
local _, ns = ...
local L = ns.L

local atLogin = {} -- (the favorites the left list was made from)
local made = {} -- (the lines made: favorite's place in the list -> "hub", "page" or "jump")
local starArt -- ("atlas" or "texture": which star this client draws)
local stars, tiles, page = {}, {}, nil

-- (An old favorite, a page's name: that page, no tabs.)
local function Entry(each)
	if type(each) == "string" then return { page = each, tabs = {} } end
	if type(each) == "table" and type(each.page) == "string" then
		each.tabs = type(each.tabs) == "table" and each.tabs or {}
		return each
	end
end
local function List()
	if type(CinematicDB) ~= "table" then return {} end
	if type(CinematicDB.favorites) ~= "table" then CinematicDB.favorites = {} end
	local list = CinematicDB.favorites
	for i = #list, 1, -1 do
		local entry = Entry(list[i])
		if entry then list[i] = entry else table.remove(list, i) end
	end
	return list
end
function ns.Favorites() return List() end
function ns.FavoritesAtLogin() return atLogin end
function ns.FavoriteLineKind(i) return made[i] end
function ns.FavoriteStarArt() return starArt end

-- (A page's name as shown, and where it is: its hub, for a tile.)
local function LabelOf(name)
	return ns.PageTileLabel and ns.PageTileLabel(name) or L[name]
end
local function WhereOf(name)
	local hub = ns.PageHub and ns.PageHub(name)
	return hub and L[hub] or L["Cinematic"]
end

-- A row of tabs by what's always the same about it: the page it's on (the
-- first frame up from it with a page's name) and its tabs' names.
local function RowKey(row)
	local frame, owner = row.parent, "?"
	for _ = 1, 12 do
		if not frame then break end
		if type(frame.pageName) == "string" then
			owner = frame.pageName
			break
		end
		frame = frame.GetParent and frame:GetParent()
	end
	return owner .. "|" .. table.concat(row.labels, "/")
end
-- A row shown now: its picked tab drawn (rows whose tabs aren't drawn, picked
-- by icons instead, are left out: the icon already says it).
local function RowShown(row)
	local tab = row.tabs[row.tabs.picked or 0]
	return tab and tab:IsVisible() and true or false
end
local function TopOf(row)
	local tab = row.tabs[row.tabs.picked]
	local top, scale = tab:GetTop(), tab:GetEffectiveScale()
	return (top or 0) * (scale or 1)
end

-- Where you are in the settings now: the page shown (a hub's icon or tab by
-- its own name) and each row of tabs shown on it, top row first, with its
-- open tab. Nil: no Cinematic page shown.
function ns.FavoriteHere()
	local key = ns.ShownOptionsPage and ns.ShownOptionsPage()
	if not key or key == "" or key == "Favorites" then return nil end
	local canvas = ns.settingsCanvases and ns.settingsCanvases[key]
	local name = canvas and ns.HubTileShowing and ns.HubTileShowing(canvas) or key
	local rows = {}
	for _, row in ipairs(ns.tabRows or {}) do
		if RowShown(row) then rows[#rows + 1] = row end
	end
	table.sort(rows, function(a, b) return TopOf(a) > TopOf(b) end)
	local here = { page = name, tabs = {} }
	for _, row in ipairs(rows) do
		local i = row.tabs.picked
		here.tabs[#here.tabs + 1] = { key = RowKey(row), index = i, label = row.labels[i] }
	end
	return here
end

-- Same place: same page, same tab in each row.
local function Same(a, b)
	if not (a and b) or a.page ~= b.page or #a.tabs ~= #b.tabs then return false end
	for i, tab in ipairs(a.tabs) do
		if tab.key ~= b.tabs[i].key or tab.index ~= b.tabs[i].index then return false end
	end
	return true
end
local function IndexOf(place)
	for i, each in ipairs(List()) do if Same(each, place) then return i end end
end
-- (A page's name alone: that page with no tabs, or any favorite of it.)
function ns.IsFavorite(place)
	if type(place) == "string" then
		for _, each in ipairs(List()) do if each.page == place then return true end end
		return false
	end
	return IndexOf(place) ~= nil
end

-- A favorite's name: its page's, then each open tab's that says more (not
-- one named as the page or a part already in it), Cooldown Manager › CDM.
function ns.FavoriteLabel(place)
	local parts = { LabelOf(place.page) }
	local seen = { [parts[1]] = true }
	for _, tab in ipairs(place.tabs or {}) do
		local label = tab.label
		if type(label) == "string" and label ~= "" and not seen[label] then
			seen[label] = true
			parts[#parts + 1] = label
		end
	end
	return table.concat(parts, " \226\128\186 ")
end

local function SameAsLogin()
	local now = List()
	if #now ~= #atLogin then return false end
	for i, each in ipairs(now) do if not Same(atLogin[i], each) then return false end end
	return true
end

-- Each row's tab opened as kept, top row first, a frame apart (a tab's own
-- rows show once it's open). A row not found (renamed since, or its page
-- changed) ends it there: the page and the tabs up to it stay open.
local function OpenTabs(place, step)
	step = step or 1
	local tab = place.tabs[step]
	if not tab then return end
	for _, row in ipairs(ns.tabRows or {}) do
		if RowKey(row) == tab.key and RowShown(row) then
			if row.tabs.picked ~= tab.index and row.tabs[tab.index] then pcall(row.click, tab.index) end
			C_Timer.After(0, function() OpenTabs(place, step + 1) end)
			return
		end
	end
end
ns.FavoriteOpenTabs = OpenTabs -- (the test's)
-- A favorite opened: its page, then its tabs.
function ns.OpenFavorite(place)
	place = Entry(place)
	if not place then return end
	ns.OpenOptions(place.page)
	C_Timer.After(0, function() OpenTabs(place) end)
end

local function PaintStar(star)
	local here = star:IsVisible() and ns.FavoriteHere()
	local on = here and IndexOf(here) ~= nil or false
	star.on, star.here = on, here or nil -- (the test's)
	local over = star:IsMouseOver()
	if star.offAtlas then
		-- (the game's hollow star while off, the gold one while on)
		star.icon:SetAtlas(on and star.onAtlas or star.offAtlas)
		star.icon:SetVertexColor(1, 1, 1)
		star.icon:SetAlpha((on or over) and 1 or 0.8)
	else
		-- (no hollow star: the gold one, dimmed while off, never grey)
		star.icon:SetVertexColor(on and 1 or 0.75, on and 1 or 0.68, on and 1 or 0.5)
		star.icon:SetAlpha(on and 1 or (over and 0.9 or 0.55))
	end
end
-- Every star shown painted for where you are (a page shown, a hub's icon or
-- a tab picked: Options.lua calls it).
function ns.FavoriteStarsPaint()
	for _, star in ipairs(stars) do
		if star:IsVisible() then PaintStar(star) end
	end
end
local PaintTiles

-- Asks for the reload that brings the left list in line, or takes the ask
-- away when your favorites are back to what it shows.
local POPUP = "CINEMATIC_FAVORITES_RELOAD"
local function AskReload()
	if not StaticPopupDialogs then return end
	if SameAsLogin() then
		if StaticPopup_Hide then StaticPopup_Hide(POPUP) end
		return
	end
	StaticPopupDialogs[POPUP] = StaticPopupDialogs[POPUP] or {
		text = L["Your favorites changed. Reload to update the Favorites lines on the left?"],
		button1 = RELOADUI or L["Reload"], button2 = L["Later"],
		OnAccept = function() ns.Reload() end,
		cineReload = 1, -- (Forever: the secure Reload laid over it, Reload.lua)
		timeout = 0, whileDead = true, hideOnEscape = true,
	}
	if StaticPopup_Show then StaticPopup_Show(POPUP) end
end
function ns.FavoritesReloadPopup() return POPUP end

-- Adds a place to your favorites (at the end) or takes it off; a page's
-- name: that page with no tabs (off: every favorite of it). True if changed.
function ns.SetFavorite(place, on)
	if type(place) == "string" then
		if place == "" or place == "Favorites" then return false end
		if not on then
			local list, changed = List(), false
			for i = #list, 1, -1 do
				if list[i].page == place then
					table.remove(list, i)
					changed = true
				end
			end
			if changed then
				ns.FavoriteStarsPaint()
				if PaintTiles then PaintTiles() end
				AskReload()
			end
			return changed
		end
		place = { page = place, tabs = {} }
	end
	if type(place) ~= "table" or type(place.page) ~= "string" or place.page == "Favorites" then return false end
	local list, at = List(), IndexOf(place)
	if on and not at then
		place.label = ns.FavoriteLabel(place)
		list[#list + 1] = place
	elseif not on and at then
		table.remove(list, at)
	else
		return false
	end
	ns.FavoriteStarsPaint()
	if PaintTiles then PaintTiles() end
	AskReload()
	return true
end

-- The star left of a page's "Search this page" box (a hub's, or a plain
-- page's own: Options.lua makes the box and calls this), at the same spot on
-- every page. A click: where you are now starred, or unstarred.
function ns.AddFavoriteStar(box)
	if not box or box.favoriteStar then return end
	local star = CreateFrame("Button", nil, box:GetParent())
	star:SetSize(16, 16)
	-- (6 px off the box's drawn border: its Left piece reaches past the box)
	local edge = box.Left and box.Left.GetLeft and box.Left or box
	star:SetPoint("RIGHT", edge, "LEFT", -6, 0)
	star.edge = edge -- (the tests')
	star:SetFrameLevel(box:GetFrameLevel() + 1)
	star.icon = star:CreateTexture(nil, "ARTWORK")
	star.icon:SetAllPoints()
	local atlas, off = "auctionhouse-icon-favorite", "auctionhouse-icon-favorite-off"
	local function Has(name) return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) end
	if Has(atlas) then
		star.icon:SetAtlas(atlas)
		star.onAtlas = atlas
		star.offAtlas = Has(off) and off or nil
		starArt = star.offAtlas and "atlas, hollow when off" or "atlas"
	else
		star.icon:SetTexture("Interface\\Common\\ReputationStar")
		star.icon:SetTexCoord(0, 0.5, 0, 0.5)
		starArt = "texture"
	end
	star:SetScript("OnClick", function(self)
		local here = ns.FavoriteHere()
		if here then ns.SetFavorite(here, IndexOf(here) == nil) end
		PaintStar(self)
	end)
	star:SetScript("OnEnter", function(self)
		PaintStar(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.on and L["In your favorites, open at this tab. Click to remove it."]
			or L["Click to add this page, open at this tab, to your favorites."], 1, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	star:SetScript("OnLeave", function(self)
		PaintStar(self)
		GameTooltip:Hide()
	end)
	star:SetScript("OnShow", PaintStar)
	box.favoriteStar, star.box = star, box
	stars[#stars + 1] = star
end
-- (The tests': the stars, and the one shown now.)
function ns.FavoriteStars() return stars end
function ns.FavoriteStarShown()
	for _, star in ipairs(stars) do if star:IsVisible() then return star end end
end

-- A favorite's line showing a page that has a line of its own (Profiles,
-- Keybinds...): its frame borrowed while this line shows, given back after,
-- as the hubs' band lines do theirs (Options.lua menu.HubLine); then its tabs.
local function PageLine(key, label, place, i)
	local name = place.page
	local canvas = ns.settingsCanvases and ns.settingsCanvases[name]
	local frame = CreateFrame("Frame")
	frame.name, frame.parent = label, "Cinematic"
	local kept
	-- (Not a hub's own frame: its band lines hand that round among themselves.)
	local hub = false
	for _, each in ipairs(ns.HubNames and ns.HubNames() or {}) do if each == name then hub = true end end
	if canvas and not hub and ns.MenuCategory and ns.MenuCategory(name) then
		frame:SetScript("OnShow", function(self)
			kept = { parent = canvas:GetParent(), points = {} }
			for n = 1, canvas:GetNumPoints() do kept.points[n] = { canvas:GetPoint(n) } end
			canvas:SetParent(self)
			canvas:ClearAllPoints()
			canvas:SetAllPoints(self)
			canvas:Show()
			C_Timer.After(0, function() OpenTabs(place) end)
		end)
		frame:SetScript("OnHide", function(self)
			if not kept or canvas:GetParent() ~= self then return end
			canvas:SetParent(kept.parent)
			canvas:ClearAllPoints()
			for _, point in ipairs(kept.points) do canvas:SetPoint(unpack(point)) end
			if not kept.parent then canvas:Hide() end
			kept = nil
		end)
		made[i] = "page"
	else
		-- (Anything else: the page opened where it is, its own line lit.)
		frame:SetScript("OnShow", function()
			C_Timer.After(0, function() ns.OpenFavorite(place) end)
		end)
		made[i] = "jump"
	end
	frame:Hide() -- (made shown, its OnShow would never come as the list shows it)
	ns.AddMenuLine(key, frame, label, "Favorites")
end

-- The Favorites page: a tile a favorite (click: open it; right-click: take
-- it off). Made at login only when you have one (the line is made then too).
local TILE_W, TILE_H, GAP = 190, 40, 8
function ns.CreateFavoritesPage(kit)
	atLogin, made = {}, {}
	for _, each in ipairs(List()) do atLogin[#atLogin + 1] = each end
	if #atLogin == 0 then return end
	local canvas, content = kit.CreateScrollPage(true)
	local title = kit.Label(content, "GameFontNormalLarge", L["Favorites"])
	title:SetPoint("TOPLEFT", 16, -16)
	local intro = kit.PageIntro(content, title,
		L["Your favorite places. The star left of a page's search box adds the page, open at its tab."])
	local note = kit.Label(content, "GameFontHighlightSmall", "")
	note:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -10)
	note.searchSkip = true
	local grid = CreateFrame("Frame", nil, content)
	grid:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -10)
	grid:SetPoint("RIGHT", content, "RIGHT", -16, 0)
	grid:SetHeight(1)
	local function Tile(i)
		local tile = tiles[i]
		if tile then return tile end
		tile = CreateFrame("Button", nil, grid)
		tile:SetSize(TILE_W, TILE_H)
		tile:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		local edge = tile:CreateTexture(nil, "BACKGROUND")
		edge:SetAllPoints()
		edge:SetColorTexture(0.45, 0.38, 0.2, 0.8)
		local fill = tile:CreateTexture(nil, "BORDER")
		fill:SetPoint("TOPLEFT", 1, -1)
		fill:SetPoint("BOTTOMRIGHT", -1, 1)
		fill:SetColorTexture(0.06, 0.05, 0.04, 0.95)
		local glow = tile:CreateTexture(nil, "HIGHLIGHT")
		glow:SetPoint("TOPLEFT", 1, -1)
		glow:SetPoint("BOTTOMRIGHT", -1, 1)
		glow:SetColorTexture(1, 0.82, 0, 0.12)
		tile.name = kit.Label(tile, "GameFontNormal", "")
		tile.name:SetPoint("TOPLEFT", 10, -7)
		tile.name:SetPoint("RIGHT", -8, 0)
		tile.name:SetWordWrap(false)
		tile.name.searchSkip = true
		tile.where = kit.Label(tile, "GameFontHighlightSmall", "")
		tile.where:SetPoint("TOPLEFT", tile.name, "BOTTOMLEFT", 0, -3)
		tile.where:SetTextColor(0.6, 0.57, 0.5)
		tile.where.searchSkip = true
		tile:SetScript("OnClick", function(self, button)
			if button == "RightButton" then ns.SetFavorite(self.place, false)
			else ns.OpenFavorite(self.place) end
		end)
		tile:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L["Click to open. Right-click to remove."], 1, 1, 1, 1, true)
			GameTooltip:Show()
		end)
		tile:SetScript("OnLeave", function() GameTooltip:Hide() end)
		tiles[i] = tile
		return tile
	end
	function PaintTiles()
		local list = List()
		local perRow = math.max(1, math.floor(((grid:GetWidth() or 0) + GAP) / (TILE_W + GAP)))
		for i, place in ipairs(list) do
			local tile = Tile(i)
			tile.place, tile.page = place, place.page
			tile.name:SetText(place.label or ns.FavoriteLabel(place))
			tile.where:SetText(WhereOf(place.page))
			tile:ClearAllPoints()
			local row, col = math.floor((i - 1) / perRow), (i - 1) % perRow
			tile:SetPoint("TOPLEFT", grid, "TOPLEFT", col * (TILE_W + GAP), -row * (TILE_H + GAP))
			tile:Show()
		end
		for i = #list + 1, #tiles do tiles[i]:Hide() end
		if #list == 0 then
			note:SetText(L["No favorites left. Click the star left of a page's search box to add one."])
		else
			note:SetText(SameAsLogin() and "" or L["The lines on the left change after a reload."])
		end
		content:SetHeight(120 + math.ceil(math.max(#list, 1) / perRow) * (TILE_H + GAP))
	end
	grid:SetScript("OnSizeChanged", function() PaintTiles() end)
	canvas:HookScript("OnShow", function() PaintTiles() end)
	kit.RegisterSubpage(canvas, "Favorites", L["Favorites"])
	page = canvas
	-- A line a favorite under it, in the order starred.
	for i, place in ipairs(atLogin) do
		local key, label = "Favorites/" .. i, place.label or ns.FavoriteLabel(place)
		local function Tabs() C_Timer.After(0, function() OpenTabs(place) end) end
		if ns.AddFavoriteHubLine and ns.AddFavoriteHubLine(key, label, "Favorites", place.page, Tabs) then
			made[i] = "hub"
		else
			PageLine(key, label, place, i)
		end
	end
end
function ns.FavoritesPage() return page end
function ns.FavoriteTiles() return tiles end -- (the test's)

-- After the left list is handed to the game: Favorites open (a new line
-- comes folded, its lines hidden; our own category, set before the game
-- draws the list, as the fold does).
function ns.FavoritesAfterFlush()
	local category = ns.MenuCategory and ns.MenuCategory("Favorites")
	if type(category) == "table" and category.SetExpanded then pcall(category.SetExpanded, category, true) end
end
