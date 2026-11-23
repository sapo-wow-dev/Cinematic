-- The welcome window's Style demos (Profiles/ShowMe.lua's styleThemes,
-- unitStyle and plateStyle tiles under Style on the See all shelf): a look on
-- your real frames for a moment, then yours back. The user, 2026-11-22: Style
-- had only Combat Text on the shelf, its Themes, Unit Frames and Nameplate
-- pages were links.
--   themes  three themes in turn, over everything they reach
--   frames  one theme, the unit frames only (and General's shared look)
--   plates  one theme, the nameplates and their names only
-- What a theme pick changes is kept first (ns.StyleSnapshot) and put back
-- after (ns.RestoreStyleSnapshot), with the parts a theme reaches; kept in
-- db.styleDemoRestore meanwhile, so a /reload mid-demo puts yours back at login.

local _, ns = ...
ns.Module("style", function() -- (only with Style loaded, Modules.lua)

-- The themes a demo shows, in turn; yours left out (nothing to see).
local DEMO_THEMES = { "codex", "reel", "forge", "glade" }
local EVERY = 3 -- seconds on each theme in the themes demo
-- The parts each kind keeps reaching (ns.THEME_PARTS); the rest left alone.
local KIND_PARTS = { frames = { Frames = true }, plates = { Plates = true, Names = true, Casts = true } }

local running -- { kind, round }
-- Each kind's board at the top of the screen: its Style pages' own previews,
-- drawn in the theme as it changes, so the look shows whatever's around
-- (the user, 2026-11-22: with the window faded over the middle, a theme on
-- the real frames barely showed; with no nameplates around the plates' tile
-- hid, as it couldn't play). Your real frames take the theme too.
local GAP = 12
-- (Each cut to what it shows, the user 2026-11-22: the pages' panels left dark
-- space round the frames, and the plate's bottom half empty. size: a fixed
-- one; none: the unit frames' stage at full size, the panel just round it.)
local PLATE = { make = "MakeGeneralPlatePreview", width = 300, height = 120 }
local FRAMES = { make = "MakeUnitStylePreview", width = 480 }
local BOARD_PREVIEWS = {
	frames = { FRAMES },
	plates = { PLATE },
	themes = { FRAMES, PLATE },
}
local boards = {} -- kind -> frame
local shownBoard
-- Each preview its contents' size, side by side, the board round them.
local function Arrange(board)
	local x, height = 0, 0
	for _, preview in ipairs(board.previews) do
		local stage = preview.stage
		if stage then
			local w, h = stage:GetSize()
			-- (The room LayoutStage leaves, so it lays the stage at 1, unshrunk.)
			if w and h and w > 1 and h > 1 then preview:SetSize(w + 4, h + 18) end
		end
		preview:ClearAllPoints()
		preview:SetPoint("TOPLEFT", board, "TOPLEFT", x, 0)
		x = x + preview:GetWidth() + GAP
		height = math.max(height, preview:GetHeight())
	end
	board:SetSize(math.max(x - GAP, 1), math.max(height, 1))
end
local function Redraw(board)
	for _, preview in ipairs(board.previews) do
		if preview.Refresh then pcall(preview.Refresh, preview) end
	end
end
local function Board(kind)
	if shownBoard then shownBoard:Hide() end
	shownBoard = nil
	local list = kind and BOARD_PREVIEWS[kind]
	if not list then return end
	local board = boards[kind]
	if not board then
		board = CreateFrame("Frame", nil, UIParent)
		board:SetSize(1, 1)
		board:SetPoint("TOP", UIParent, "TOP", 0, -130)
		board:SetFrameStrata("FULLSCREEN")
		board:EnableMouse(false)
		board.previews = {}
		for _, each in ipairs(list) do
			local make = ns[each.make]
			local preview = make and make(board, each.width)
			if preview then
				if each.height then preview:SetSize(each.width, each.height) end
				board.previews[#board.previews + 1] = preview
			end
		end
		boards[kind] = board
	end
	if #board.previews == 0 then return end
	board:Show()
	shownBoard = board
	-- (Drawn, cut to what it drew, drawn again at that size, till it holds: the
	-- frames' stage is its rough size till laid out on the screen; and once
	-- more a frame on, when everything can be measured.)
	local function Settle()
		Redraw(board)
		for _ = 1, 3 do
			local was = board:GetWidth() .. "x" .. board:GetHeight()
			Arrange(board)
			Redraw(board)
			if board:GetWidth() .. "x" .. board:GetHeight() == was then break end
		end
	end
	Settle()
	C_Timer.After(0, function()
		if shownBoard == board then Settle() end
	end)
end
-- The board up now (the offline check measures it: Tools/offline/styledemo.lua).
function ns.StyleDemoBoard() return shownBoard end
-- Whether a board's up, and how many previews it has.
function ns.StyleDemoBoardShown()
	return shownBoard ~= nil and shownBoard:IsShown(), shownBoard and #shownBoard.previews or 0
end

local function PutBack()
	local db = ns.GetDB and ns.GetDB()
	local kept = db and db.styleDemoRestore
	if type(kept) ~= "table" then return false end
	db.styleDemoRestore = nil
	local reach = kept.__reach
	kept.__reach = nil
	for part, value in pairs(type(reach) == "table" and reach or {}) do
		db["styleThemeReach" .. part] = value ~= "nil" and value or nil
	end
	ns.RestoreStyleSnapshot(kept)
	return true
end

local function Themes()
	local db = ns.GetDB()
	local list = {}
	for _, key in ipairs(DEMO_THEMES) do
		if key ~= db.styleTheme then list[#list + 1] = key end
	end
	return list
end

-- kind: "themes", "frames" or "plates" to start; nil to stop, yours back.
-- False: it can't start now (a fight: a theme can't be put on in one).
function ns.StyleDemo(kind)
	if not kind then
		if running then running.round = running.round + 1 end
		running = nil
		Board(nil)
		if InCombatLockdown() then return true end -- (put back once the fight ends, below)
		PutBack()
		return true
	end
	if InCombatLockdown() then return false end
	local db = ns.GetDB and ns.GetDB()
	if not db then return false end
	-- (One running already: yours back first, so its look isn't kept as yours.)
	if running or db.styleDemoRestore then ns.StyleDemo(nil) end
	local themes = Themes()
	if #themes == 0 then return false end
	local kept = ns.StyleSnapshot()
	local reach = {}
	local parts = KIND_PARTS[kind]
	for _, part in ipairs(ns.THEME_PARTS or {}) do
		local key = "styleThemeReach" .. part
		reach[part] = db[key] == nil and "nil" or db[key]
		if parts then db[key] = parts[part] and true or false end
	end
	kept.__reach = reach
	db.styleDemoRestore = kept
	running = { kind = kind, round = 1 }
	local this = running
	local function Show(i)
		if running ~= this or InCombatLockdown() then return end
		ns.ApplyStyleTheme(themes[(i - 1) % #themes + 1], true)
		Board(kind) -- (anew on each theme: the previews redrawn in it)
		if kind == "themes" and i < 3 then
			C_Timer.After(EVERY, function() if running == this then Show(i + 1) end end)
		end
	end
	local ok, err = pcall(Show, 1)
	if not ok then
		ns.StyleDemo(nil)
		error(err, 0)
	end
	return true
end

-- Whether a demo is on now.
function ns.StyleDemoRunning() return running ~= nil end

-- Yours back at login after a /reload mid-demo, and after a fight that
-- stopped one (a theme can't be put on or off in a fight).
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function()
	if running then return end
	local db = ns.GetDB and ns.GetDB()
	if db and db.styleDemoRestore then
		local ok, err = pcall(PutBack)
		if not ok and ns.Log then ns.Log("style", "demo put back: " .. tostring(err)) end
	end
end)

end) -- (ns.Module "style")
