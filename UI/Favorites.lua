-- Favorites: a star left of each settings page's "Search this page" box adds
-- the place you're at to your favorites (or takes it off): the page, and the
-- tab open in every row of tabs on it, however deep, so a favorite opens
-- right there again. Kept for the whole account (CinematicDB.favorites, in
-- the order starred: { page = English name, tabs = { { key, index, label } },
-- label, name = your own name }; an old plain name: that page alone). One
-- Favorites line on top of Cinematic's left list, always there, opens a page
-- with a tile a favorite, changed the moment you star, rename or remove one:
-- no reload. (A line a favorite was tried: the game's left list can't take
-- lines changed after login on Forever, /cine debug favlines 2026-11-20:
-- Escape > Options in a fight then blocked 1831 lines, so each change needed
-- a reload; the user picked one line and no reloads, 2026-11-21. The star by
-- each page's title broke on page after page; the user picked this fixed
-- spot, 2026-11-20.)
-- Tests: /cine debug favorites, /cine debug favstars (dev copy).
local _, ns = ...
local L = ns.L

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

-- A favorite's name as shown: the one you gave it (right-click its tile,
-- Rename), else the one it got when starred.
function ns.FavoriteName(place)
	local name = type(place) == "table" and type(place.name) == "string" and place.name:match("^%s*(.-)%s*$")
	if name and name ~= "" then return name end
	return type(place) == "table" and (place.label or ns.FavoriteLabel(place)) or ""
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
	-- (nowhere to star, the Favorites page itself: no star drawn there. Known
	-- by its own box: as a page shows, the one left can still read as shown,
	-- and its star painted as that page's, 2026-11-21 in game)
	local own = page and page.searchBox and star.box == page.searchBox
	local none = own or (star:IsVisible() and not here)
	if own then star.on, star.here = false, nil end
	star.none = none or nil
	star:EnableMouse(not none)
	if none then
		star.icon:SetAlpha(0)
		return
	end
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
	return true
end

-- Gives a favorite your own name; an empty one (or its own) puts back the
-- name it got when starred. True if changed.
function ns.RenameFavorite(place, text)
	local at = IndexOf(place)
	if not at then return false end
	local entry = List()[at]
	text = type(text) == "string" and text:match("^%s*(.-)%s*$") or ""
	local auto = entry.label or ns.FavoriteLabel(entry)
	local name = (text ~= "" and text ~= auto) and text or nil
	if name == entry.name then return false end
	entry.name = name
	if PaintTiles then PaintTiles() end
	return true
end

-- The rename popup: the name in a box, Enter or Accept keeps it.
local RENAME = "CINEMATIC_FAVORITE_RENAME"
local function RenameText(popup)
	local box = popup and (popup.editBox or popup.EditBox or (popup.GetEditBox and popup:GetEditBox()))
	return box and box:GetText() or "", box
end
local function RenamePopupOf(box)
	local frame = box
	while frame and not frame.which do frame = frame:GetParent() end
	return frame
end
function ns.FavoriteRenameAsk(place)
	if not (StaticPopupDialogs and StaticPopup_Show) then return end
	StaticPopupDialogs[RENAME] = StaticPopupDialogs[RENAME] or {
		text = L["Name this favorite (empty: its own name):"],
		button1 = ACCEPT, button2 = CANCEL,
		hasEditBox = true, maxLetters = 48,
		OnShow = function(self, data)
			local _, box = RenameText(self)
			if box then
				box:SetText(ns.FavoriteName(data))
				box:HighlightText()
				box:SetFocus()
			end
		end,
		OnAccept = function(self, data) ns.RenameFavorite(data, (RenameText(self))) end,
		EditBoxOnEnterPressed = function(box)
			local popup = RenamePopupOf(box)
			if popup then
				ns.RenameFavorite(popup.data, (RenameText(popup)))
				popup:Hide()
			end
		end,
		EditBoxOnEscapePressed = function(box)
			local popup = RenamePopupOf(box)
			if popup then popup:Hide() end
		end,
		timeout = 0, whileDead = true, hideOnEscape = true,
	}
	return StaticPopup_Show(RENAME, nil, nil, place)
end
function ns.FavoriteRenamePopup() return RENAME end

-- Moves a favorite to place to in the list (the tiles' order, saved). True
-- if moved.
function ns.MoveFavorite(place, to)
	local list, at = List(), IndexOf(place)
	if not at or type(to) ~= "number" then return false end
	to = math.max(1, math.min(#list, math.floor(to)))
	if to == at then return false end
	table.insert(list, to, table.remove(list, at))
	if PaintTiles then PaintTiles() end
	return true
end

-- A favorite's icon: the one you picked (right-click its tile, Change icon),
-- else its page's own (the hubs' pages have one), else Cinematic's.
local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_Spyglass_03"
function ns.FavoriteIcon(place)
	if type(place) ~= "table" then return DEFAULT_ICON end
	if place.icon ~= nil then return place.icon end
	return ns.PageIcon and ns.PageIcon(place.page) or DEFAULT_ICON
end
-- (An icon on a texture: an atlas name, or a file (path or file ID) cropped
-- to its picture's edge as the game's icon buttons are.)
local function PaintIcon(texture, icon)
	if type(icon) == "string" and not icon:find("[\\/]") and C_Texture and C_Texture.GetAtlasInfo
		and C_Texture.GetAtlasInfo(icon) then
		texture:SetAtlas(icon)
		texture:SetTexCoord(0, 1, 0, 1)
	else
		texture:SetTexture(icon)
		texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	end
end
-- Gives a favorite an icon; nil puts back its page's. True if changed.
function ns.FavoriteSetIcon(place, icon)
	local at = IndexOf(place)
	if not at then return false end
	local entry = List()[at]
	if entry.icon == icon then return false end
	entry.icon = icon
	if PaintTiles then PaintTiles() end
	return true
end
local picker -- (the icon picker, made with the Favorites page: IconBrowser.lua)
function ns.FavoriteIconPicker() return picker end
local function PickIcon(place, owner)
	if not (picker and owner) then return end
	picker:Open(owner, place, ns.FavoriteIcon(place))
end

-- A tile's right-click menu: what it holds (the test's too). A move that
-- can't happen (the first one left, the last one right) isn't there, nor
-- Default icon while it has its page's. Change icon's function takes the
-- tile the picker opens under.
function ns.FavoriteMenuItems(place)
	local at, count = IndexOf(place), #List()
	local items = {
		{ L["Open"], function() ns.OpenFavorite(place) end },
		{ L["Rename"], function() ns.FavoriteRenameAsk(place) end },
	}
	if picker then
		items[#items + 1] = { L["Change icon"], function(owner) PickIcon(place, owner) end, icon = true }
	end
	if type(place) == "table" and place.icon ~= nil then
		items[#items + 1] = { L["Default icon"], function() ns.FavoriteSetIcon(place, nil) end }
	end
	if at and at > 1 then items[#items + 1] = { L["Move left"], function() ns.MoveFavorite(place, at - 1) end } end
	if at and at < count then items[#items + 1] = { L["Move right"], function() ns.MoveFavorite(place, at + 1) end } end
	items[#items + 1] = { L["Remove"], function() ns.SetFavorite(place, false) end, red = true }
	return items
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

-- The Favorites page: a tile a favorite (click: open it; right-click: Open,
-- Rename, Remove). Its line is always there, your favorites or none.
-- (One column: two side by side read badly, the user's call 2026-11-21;
-- wide enough for a long name, Gamepad Frames › Settings.)
local TILE_W, TILE_H, GAP, ICON = 300, 40, 8, 28
function ns.CreateFavoritesPage(kit)
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
	local perRow = 1 -- (a tile a row)
	-- Dragging a tile: it follows the cursor, the cell it would land in lit,
	-- and it's moved there as you let go.
	local slot = CreateFrame("Frame", nil, grid)
	slot:SetSize(TILE_W, TILE_H)
	local slotLine = slot:CreateTexture(nil, "OVERLAY")
	slotLine:SetAllPoints()
	slotLine:SetColorTexture(1, 0.82, 0, 0.25)
	slot:Hide()
	-- (the place in the list under the cursor: by the grid's cells)
	local function DropAt()
		local x, y = GetCursorPosition()
		local scale = grid:GetEffectiveScale()
		local left, top = grid:GetLeft(), grid:GetTop()
		if not (left and top and scale and scale > 0) then return end
		x, y = x / scale, y / scale
		local col = math.max(0, math.min(perRow - 1, math.floor((x - left) / (TILE_W + GAP))))
		local row = math.max(0, math.floor((top - y) / (TILE_H + GAP)))
		return math.max(1, math.min(#List(), row * perRow + col + 1))
	end
	ns.FavoriteDropAt = DropAt -- (the test's)
	local function Cell(i)
		local row, col = math.floor((i - 1) / perRow), (i - 1) % perRow
		return col * (TILE_W + GAP), -row * (TILE_H + GAP)
	end
	local function Tile(i)
		local tile = tiles[i]
		if tile then return tile end
		tile = CreateFrame("Button", nil, grid)
		tile:SetSize(TILE_W, TILE_H)
		tile:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		tile:RegisterForDrag("LeftButton")
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
		tile.icon = tile:CreateTexture(nil, "ARTWORK")
		tile.icon:SetSize(ICON, ICON)
		tile.icon:SetPoint("LEFT", 6, 0)
		tile.name:SetPoint("TOPLEFT", tile.icon, "TOPRIGHT", 8, 0)
		tile.name:SetPoint("RIGHT", -8, 0)
		tile.name:SetWordWrap(false)
		tile.name.searchSkip = true
		tile.where = kit.Label(tile, "GameFontHighlightSmall", "")
		tile.where:SetPoint("TOPLEFT", tile.name, "BOTTOMLEFT", 0, -3)
		tile.where:SetTextColor(0.6, 0.57, 0.5)
		tile.where.searchSkip = true
		tile:SetScript("OnDragStart", function(self)
			if #List() < 2 then return end
			self.dragging = true
			GameTooltip:Hide()
			self:SetFrameLevel(grid:GetFrameLevel() + 10)
			self:SetAlpha(0.8)
			local scale = self:GetEffectiveScale()
			local x, y = GetCursorPosition()
			local dx, dy = x / scale - (self:GetLeft() or 0), y / scale - (self:GetTop() or 0)
			slot:Show()
			self:SetScript("OnUpdate", function()
				local cx, cy = GetCursorPosition()
				self:ClearAllPoints()
				self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cx / scale - dx, cy / scale - dy)
				local to = DropAt()
				if to then
					slot:ClearAllPoints()
					slot:SetPoint("TOPLEFT", grid, "TOPLEFT", Cell(to))
				end
			end)
		end)
		tile:SetScript("OnDragStop", function(self)
			if not self.dragging then return end
			self:SetScript("OnUpdate", nil)
			slot:Hide()
			self:SetAlpha(1)
			self:SetFrameLevel(grid:GetFrameLevel() + 1)
			self.dropped = GetTime() -- (the click that ends a drag doesn't open it)
			self.dragging = nil
			local to = DropAt()
			if not (to and ns.MoveFavorite(self.place, to)) then PaintTiles() end
		end)
		tile:SetScript("OnClick", function(self, button)
			if self.dropped and GetTime() - self.dropped < 0.3 then return end
			if button ~= "RightButton" then return ns.OpenFavorite(self.place) end
			-- (a menu: Open, Rename, Remove; no menus on this client: off at once)
			if not (MenuUtil and MenuUtil.CreateContextMenu and ns.ContextMenu) then
				return ns.SetFavorite(self.place, false)
			end
			local place = self.place
			self.menu = ns.ContextMenu(self, function(_, root)
				root:CreateTitle(ns.FavoriteName(place))
				for _, item in ipairs(ns.FavoriteMenuItems(place)) do -- (Move left/right where it can)
					if item.red then root:CreateDivider() end
					local run, owner = item[2], self
					root:CreateButton(item.red and ("|cffff4040" .. item[1] .. "|r") or item[1], function() run(owner) end)
				end
			end)
		end)
		tile:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(MenuUtil and MenuUtil.CreateContextMenu and L["Click to open, drag to move. Right-click for more."]
				or L["Click to open. Right-click to remove."], 1, 1, 1, 1, true)
			GameTooltip:Show()
		end)
		tile:SetScript("OnLeave", function() GameTooltip:Hide() end)
		tiles[i] = tile
		return tile
	end
	function PaintTiles()
		local list = List()
		for i, place in ipairs(list) do
			local tile = Tile(i)
			tile.place, tile.page = place, place.page
			tile.name:SetText(ns.FavoriteName(place))
			PaintIcon(tile.icon, ns.FavoriteIcon(place))
			tile.where:SetText(WhereOf(place.page))
			if not tile.dragging then
				tile:ClearAllPoints()
				tile:SetPoint("TOPLEFT", grid, "TOPLEFT", Cell(i))
			end
			tile:Show()
		end
		for i = #list + 1, #tiles do tiles[i]:Hide() end
		note:SetText(#list == 0 and L["No favorites yet. Click the star left of a page's search box to add one."] or "")
		content:SetHeight(120 + math.ceil(math.max(#list, 1) / perRow) * (TILE_H + GAP))
	end
	grid:SetScript("OnSizeChanged", function() PaintTiles() end)
	-- (and again a frame later, the page's sizes settled by then: the grid
	-- has no place on its first show)
	canvas:HookScript("OnShow", function()
		PaintTiles()
		C_Timer.After(0, function() if canvas:IsVisible() then PaintTiles() end end)
	end)
	-- (every icon the game has, as wheels and cameras pick theirs: a pick
	-- sets the icon of the favorite it was opened for)
	if ns.IconBrowser then
		picker = ns.IconBrowser(canvas, function(place, icon) ns.FavoriteSetIcon(place, icon) end)
	end
	-- (Hidden till the settings show it, as every page: left shown, with no
	-- parent yet, it counted as "settings open" from login, so the idle
	-- checks never slowed. Tools/offline/settingsclosed.lua, 2026-11-22.)
	canvas:Hide()
	kit.RegisterSubpage(canvas, "Favorites", L["Favorites"])
	page = canvas
end
function ns.FavoritesPage() return page end
function ns.FavoriteTiles() return tiles end -- (the test's)
function ns.FavoritePaintTiles() if PaintTiles then PaintTiles() end end -- (the test's)
-- (the test's: tiles a row as laid out now)
function ns.FavoriteTilesPerRow()
	local first = tiles[1]
	if not (first and first:IsShown()) then return 0 end
	local top, n = first:GetTop(), 0
	for _, tile in ipairs(tiles) do
		if tile:IsShown() and tile:GetTop() and top and math.abs(tile:GetTop() - top) < 1 then n = n + 1 end
	end
	return n
end
