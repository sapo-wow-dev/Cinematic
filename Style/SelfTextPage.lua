-- The Style hub's Text on You Style page (SelfTextStyle.lua draws the texts;
-- the plan and mock: Tools/self-text-page-plan.md). Top to bottom: its title
-- and Enable switch, an Experimental notice, status chips (what's going on
-- right now), the changed line, its Show in row, a live preview (you from
-- behind, your combat text drawn by the real code on the preview's own
-- board), then three tabs: General (who draws it, where, motion, busy
-- fights), Look (quick looks, font, edge, sizes, shadow, fade) and Kinds
-- (each kind's switch and sample, and the picked one's own look under the
-- list, each part its General one's till changed).

local _, ns = ...
local L = ns.L

local PREVIEW_W, PREVIEW_H = 520, 210
local SCALE = 0.9           -- the preview's texts: UI units to its own (0.6 read too small in game, 2026-11-21)
local OVER_X = -0.1         -- over your shoulder: you this share of its width left of its middle
                            -- (-0.2 left your free side no room: texts cut at its edge, run 3)
local LIFT = -50            -- UI units: where the texts start, from its middle (room to climb in it)
local GAME_Y = 62           -- pixels up from its middle: where the game draws (above your head, not your chest)
local PLAY_EVERY = 0.38     -- seconds between the preview's samples

-- The fight mix the preview plays (words, kind, crit).
local MIX = {
	{ "-26", "damage" }, { "+120 [Sapo]", "heal" }, { "Dodge", "miss" }, { "-31", "damage" }, { "-74", "damage", true },
	{ "+20 Mana", "power" }, { "<2 Combo Points>", "combo" }, { "-18", "damage" }, { "<Demon Skin>", "aura" },
	{ "Overpower!", "alert" }, { "+412", "heal", true }, { "-22", "damage" }, { "-22", "damage" }, { "Absorb", "shield" },
	{ "Mana Low", "low" }, { "+64", "heal" }, { "+Combat", "combat" },
}

-- Quick looks: each sets these parts at once.
local LOOKS = {
	{ id = "game", label = L["The game's"], font = "game", edge = "game", size = 1, crit = 1.5, motion = "up" },
	{ id = "clean", label = L["Clean"], font = "rajdhani", edge = "edge", size = 1.1, crit = 1.4, motion = "up" },
	{ id = "bold", label = L["Bold"], font = "lilita", edge = "both", size = 1.25, crit = 1.9, motion = "pop" },
	{ id = "comic", label = L["Comic"], font = "titan", edge = "both", size = 1.2, crit = 2.1, motion = "arc" },
	{ id = "small", label = L["Small"], font = "bebas", edge = "game", size = 0.8, crit = 1.3, motion = "up" },
}
ns.SELF_TEXT_LOOKS = LOOKS
local LOOK_KEYS = { font = "selfTextFont", edge = "selfTextEdge", size = "selfTextSize", crit = "selfTextCrit",
	motion = "selfTextMotion" }

-- The page's own parts, for the tests (Tools/offline/selftextpage.lua).
local page = { SCALE = SCALE }
ns.selfTextPage = page

local function DB() return ns.GetDB() or {} end
local function Groups() return ns.SELF_TEXT_GROUPS end
local function GroupOf(id)
	for _, group in ipairs(Groups()) do if group.id == id then return group end end
end

-- What a chip says now ----------------------------------------------------------
-- Each gives its words, a dot ("good", "warn", "off") and whether it shows.
local CHIPS = {}
CHIPS[1] = function() -- the game's text
	local yielded = ns.StyleSwitchYielded and ns.StyleSwitchYielded("selfTextStyle")
	if yielded then return L["Game's text"], (L["%s draws it"]):format(yielded.addon), "warn" end
	if not ns.StyleOn("selfTextStyle") then return L["Game's text"], L["as it is (page off)"], "off" end
	local by = ns.SelfTextBy and ns.SelfTextBy() or "game"
	if by == "game" then
		local state = ns.SelfTextState and ns.SelfTextState()
		if state and not state.rowOn then return L["Game's text"], L["as it is here (Show in)"], "off" end
		return L["Game's text"], L["as it is"], "off"
	end
	if by == "none" then return L["Game's text"], L["hidden"], "good" end
	local on = GetCVar("enableFloatingCombatText")
	if tostring(on) ~= "1" then return L["Game's text"], L["off in the game: nothing to copy"], "warn" end
	return L["Game's text"], L["copied"], "good"
end
CHIPS[2] = function() -- the Shoulder Cam
	local db = DB()
	if not (db.shoulderCam and (not ns.ShoulderCamUnlocked or ns.ShoulderCamUnlocked())) then
		return L["Shoulder Cam"], L["off"], "off"
	end
	local over = (tonumber(GetCVar("test_cameraOverShoulder")) or 0) ~= 0
	return L["Shoulder Cam"], over and L["over your shoulder"] or L["behind you"], over and "good" or "off"
end
CHIPS[3] = function() -- the game's Text on Me ticks
	local on, all = 0, 0
	for _, group in ipairs(Groups()) do
		local tick = ns.SelfTextGameTick(group.id)
		if tick then
			all = all + 1
			if tick == "on" then on = on + 1 end
		end
	end
	return L["Text on Me"], (L["%d of %d kinds on"]):format(on, all), on == all and "good" or "warn"
end
CHIPS[4] = function() -- another addon's pick (none: not shown)
	for _, row in ipairs(ns.CONFLICTS or {}) do
		if row.key == "style:selftext" and ns.ConflictTheirsOn and ns.ConflictTheirsOn(row) then
			local pick = ns.ConflictPick(row)
			return row.addon, pick == "theirs" and L["theirs"] or (pick == "ours" and L["yours (Ours)"] or L["both"]),
				pick == "theirs" and "warn" or "good"
		end
	end
	return nil
end
CHIPS[5] = function() -- the last fight's counts
	local fight = ns.SelfTextStats and ns.SelfTextStats.fight
	if not fight or fight.copied == 0 then return L["Last fight"], L["none yet"], "off" end
	return L["Last fight"], (L["%d copied, %d left out"]):format(fight.copied, fight.dropped),
		fight.dropped > fight.copied / 2 and "warn" or "good"
end
local CHIP_OPENS = { [2] = "Shoulder Cam", [4] = "Addon Conflicts" }
local CHIP_TIPS = {
	L["Whether the game's own text about you is being copied into ours."],
	L["Where the camera has you: your text sits by you over your shoulder."],
	L["How many kinds the game makes: its own Text on Me settings in its Combat options."],
	L["Another addon draws text about you too: who draws it."],
	L["How many of the game's texts were copied in your last fight."],
}
page.CHIPS = CHIPS
local DOT = { good = { 0.28, 0.78, 0.29 }, warn = { 0.88, 0.63, 0.13 }, off = { 0.45, 0.45, 0.45 } }

-- The settings the changed line names, with their words.
local NAMED = {
	{ "selfTextBy", L["Who draws it"] }, { "selfTextSide", L["Side"] }, { "selfTextFollow", L["Follow the Shoulder Cam"] },
	{ "selfTextHeight", L["Height"] }, { "selfTextAcross", L["Across"] }, { "selfTextLife", L["Time shown"] },
	{ "selfTextMotion", L["Motion"] }, { "selfTextMerge", L["Merge repeats"] }, { "selfTextMost", L["At most"] },
	{ "selfTextSticky", L["Crits stay"] }, { "selfTextFont", L["Font"] }, { "selfTextEdge", L["Edge"] },
	{ "selfTextSize", L["Size"] }, { "selfTextCrit", L["Crit size"] }, { "selfTextShadow", L["Shadow"] },
	{ "selfTextFade", L["Fades from"] },
}
-- A kind with a part of its own (its look differs from General's).
local function KindChanged(id)
	local db = DB()
	for _, part in ipairs(ns.SELF_TEXT_PARTS) do
		local key = "selfText_" .. id .. part
		if db[key] ~= nil and db[key] ~= ns.DEFAULTS[key] then return true end
	end
	return false
end
page.KindChanged = KindChanged
function page.ChangedList()
	local db, list = DB(), {}
	for _, named in ipairs(NAMED) do
		if db[named[1]] ~= nil and db[named[1]] ~= ns.DEFAULTS[named[1]] then list[#list + 1] = named[2] end
	end
	for _, group in ipairs(Groups()) do
		if KindChanged(group.id) then list[#list + 1] = group.label end
	end
	return list
end

-- Puts a kind back to its group's look (every part).
function page.ClearKind(id)
	local db = DB()
	for _, part in ipairs(ns.SELF_TEXT_PARTS) do
		local key = "selfText_" .. id .. part
		db[key] = ns.DEFAULTS[key]
	end
end
function page.ApplyLook(id)
	for _, look in ipairs(LOOKS) do
		if look.id == id then
			local db = DB()
			for part, key in pairs(LOOK_KEYS) do db[key] = look[part] end
			db.selfTextLook = id
			return true
		end
	end
	return false
end

function ns.CreateSelfTextStylePanel(kit)
	-- (WoW Forever only for now: every test ran there; on retail the game's
	-- combat text may be made differently. No page, no icon there.)
	if ns.isRetail then return end
	local canvas, content = kit.CreateScrollPage()
	local function Changed() ns.RefreshSelfTextStyle() end
	local title = kit.Label(content, "GameFontNormalLarge", L["Text on You Style"])
	title:SetPoint("TOPLEFT", 16, -16)
	local intro = kit.PageIntro(content, title,
		L["Your floating combat text, drawn beside you, with its own look for each kind."])

	-- An Experimental notice, as Combat Text Style's: the page copies the
	-- game's own text, which a patch could change.
	local skull = content:CreateTexture(nil, "ARTWORK")
	skull:SetSize(20, 20)
	skull:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -10)
	skull:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
	local warnTitle = kit.Label(content, "GameFontNormalLarge", L["Experimental"])
	warnTitle:SetPoint("LEFT", skull, "RIGHT", 6, 0)
	warnTitle:SetTextColor(1, 0.25, 0.2)
	local warnText = kit.Label(content, "GameFontHighlightSmall",
		L["Copies the game's own combat text; a game patch can change how it's made."])
	warnText:SetPoint("TOPLEFT", skull, "BOTTOMLEFT", 0, -6)
	warnText:SetWidth(520)
	warnText:SetJustifyH("LEFT")

	local switch = kit.PageSwitch(content, "selfTextStyle", L["Enable Page"],
		L["Turns this page's combat text on or off."], warnText, Changed)
	local stack = kit.Stack(switch, "check")
	local rows = ns.StyleRows(kit, content, stack, Changed, "selfTextStyle", nil, { pictures = true,
		default = function(key) return ns.DEFAULTS[key] end })
	local function PageOn() return rows.On(DB()) end
	local function Ours() return PageOn() and (DB().selfTextBy or "ours") == "ours" end
	page.Ours = Ours

	-- Status chips: a row of them, each a word and a dot; two open a page.
	local chipRow = CreateFrame("Frame", nil, content)
	chipRow:SetSize(560, 22)
	stack:Add(chipRow, "label")
	page.chips = {}
	local lastChip
	for index, read in ipairs(CHIPS) do
		local chip = CreateFrame("Button", nil, chipRow)
		chip:SetHeight(20)
		local back = chip:CreateTexture(nil, "BACKGROUND")
		back:SetAllPoints()
		back:SetColorTexture(0.12, 0.1, 0.07, 0.95)
		chip.dot = chip:CreateTexture(nil, "ARTWORK")
		chip.dot:SetSize(7, 7)
		chip.dot:SetPoint("LEFT", 7, 0)
		chip.words = chip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		chip.words:SetPoint("LEFT", chip.dot, "RIGHT", 5, 0)
		kit.Tooltip(chip, CHIP_TIPS[index])
		chip.searchSkip = true
		chip.pageSwitch = false
		chip:SetScript("OnClick", function()
			if CHIP_OPENS[index] and ns.OpenOptions then ns.OpenOptions(CHIP_OPENS[index]) end
		end)
		chip.Refresh = function(self)
			local name, state, dot = read()
			-- (A chip with nothing to say isn't there: [[hide-unclickable]].)
			self:SetShown(name ~= nil)
			if not name then return end
			self.words:SetText(("%s |cff9c927b%s|r"):format(name, state or ""))
			local color = DOT[dot] or DOT.off
			self.dot:SetColorTexture(color[1], color[2], color[3], 1)
			local wide = self.words:GetStringWidth()
			self:SetWidth(24 + ((type(wide) == "number" and not (issecretvalue and issecretvalue(wide))) and wide or 120))
			self.state, self.dotKind = state, dot
		end
		if lastChip then chip:SetPoint("LEFT", lastChip, "RIGHT", 6, 0) else chip:SetPoint("LEFT", chipRow, "LEFT", 0, 0) end
		lastChip = chip
		kit.AddControl(chip)
		page.chips[index] = chip
	end

	-- What's changed from the usual, in a line.
	local changedRow = CreateFrame("Frame", nil, content)
	changedRow:SetSize(560, 16)
	stack:Add(changedRow, "label")
	local changedText = changedRow:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	changedText:SetPoint("LEFT")
	changedText:SetWidth(560)
	changedText:SetJustifyH("LEFT")
	changedText:SetWordWrap(false)
	changedRow.Refresh = function()
		local list = page.ChangedList()
		changedText:SetText(#list > 0 and (L["Changed: %s"]):format(table.concat(list, ", ")) or L["Changed: nothing yet"])
	end
	changedRow.pageSwitch = false
	kit.AddControl(changedRow)
	page.changedText = changedText

	-- Show in (the default row, [[default-show-in-row]]).
	local showHeader = stack:Header(content, L["Show in"])
	local lastRow = ns.ShowTable(content, showHeader, {
		opts = { anyFight = true }, underHeader = true,
		{ key = ns.SELF_TEXT_ROW, label = L["Text on You"], alwaysKey = "selfTextAlways",
			alwaysOn = function() return DB().selfTextAlways ~= false end,
			setAlways = function(value) DB().selfTextAlways = value Changed() end,
			alwaysTip = L["Shows everywhere, so the other columns don't change anything."],
			apply = Changed },
	}, L["Text on You"])
	stack:Continue(lastRow, "label")

	-- The preview -----------------------------------------------------------------
	local preview = CreateFrame("Frame", nil, content)
	preview:SetSize(PREVIEW_W, PREVIEW_H)
	if ns.StyleScene then ns.StyleScene(preview) end
	if preview.SetClipsChildren then preview:SetClipsChildren(true) end
	stack:Add(preview, "label")
	-- (Every control the kit holds has a Refresh: it calls them all, and a
	-- preview without one broke opening the page, 2026-11-21.)
	preview.Refresh = function() end
	kit.AddControl(preview)
	page.preview = preview
	local view = { over = true, ghost = false, playing = true }
	page.view = view
	-- You, from behind: a model of your character facing away.
	local model = CreateFrame("PlayerModel", nil, preview)
	-- (Framed as the Shoulder Cam frames you: your upper body, big, its feet
	-- below the preview's edge. Whole and small, it left the preview empty.)
	model:SetSize(260, PREVIEW_H * 1.8)
	pcall(model.SetUnit, model, "player")
	pcall(model.SetFacing, model, math.pi)
	page.model = model
	-- (A model draws on through its page faded to 0: the off card fades the
	-- page, and you stood under it, 2026-11-21. Hidden while anything over it
	-- is faded out; a frame of its own watches, the model's own OnUpdate stops
	-- once it's hidden.)
	local function Faded()
		local frame = preview
		while frame do
			local ok, alpha = pcall(frame.GetAlpha, frame)
			if ok and type(alpha) == "number" and alpha <= 0.01 then return true end
			frame = frame:GetParent()
		end
		return false
	end
	page.ModelFaded = Faded
	local modelWatch = CreateFrame("Frame", nil, preview)
	ns.SetOnUpdate(modelWatch, function()
		local hide = Faded()
		if model:IsShown() == hide then model:SetShown(not hide) end
	end)
	page.modelWatch = modelWatch
	-- (The preview's size now: the page widens it, the docked window sizes it
	-- as dragged. Laid out for 520 x 210 alone, docked bigger the texts sat in
	-- its top-left corner, the mark off them and you under its bottom edge,
	-- the user 2026-11-21. Everything zooms with its height.)
	local function Size()
		local w, h = preview:GetWidth(), preview:GetHeight()
		if not (type(w) == "number" and w > 1 and type(h) == "number" and h > 1) then return PREVIEW_W, PREVIEW_H end
		return w, h
	end
	local function Zoom() return select(2, Size()) / PREVIEW_H end
	local function Scale() return SCALE * Zoom() end
	page.Scale = Scale
	local function YouX() -- (UI units across from the preview's middle, as the board takes it)
		return view.over and (OVER_X * Size()) / Scale() or 0
	end
	page.YouX = YouX
	local function PlaceModel()
		local w, h = Size()
		local zoom = h / PREVIEW_H
		model:SetSize(260 * zoom, h * 1.8)
		model:ClearAllPoints()
		model:SetPoint("BOTTOM", preview, "BOTTOM", view.over and OVER_X * w or 0, -h * 0.85)
	end
	PlaceModel()
	-- The texts: on their own layer over the preview, the real code's board,
	-- in a scroll frame so they're cut at its edges (SetClipsChildren on the
	-- preview let them out: /cine debug selftextpage run 2, 2026-11-21).
	local clip = CreateFrame("ScrollFrame", nil, preview)
	clip:SetAllPoints(preview)
	clip:SetFrameLevel(preview:GetFrameLevel() + 20)
	clip.layoutSkip = true
	local layer = CreateFrame("Frame", nil, clip)
	layer:SetSize(PREVIEW_W, PREVIEW_H)
	clip:SetScrollChild(layer)
	layer.layoutSkip = true
	page.clip = clip
	local board = ns.SelfTextNewBoard(layer, layer, SCALE, YouX, LIFT)
	board.middleY = GAME_Y / SCALE
	page.board = board
	local ghost -- (made below: where the game draws, zoomed too)
	local function Fit()
		local w, h = Size()
		layer:SetSize(w, h)
		board.scale = Scale()
		PlaceModel()
		if ghost then
			ghost:ClearAllPoints()
			ghost:SetPoint("CENTER", preview, "CENTER", 0, GAME_Y * h / PREVIEW_H)
		end
	end
	page.Fit = Fit
	-- (Sized here, not by the Style previews' fit (ApplyPreviewFit): it scaled
	-- and moved them from the samples' middle on each refresh, you included,
	-- whose frame runs past the edges on purpose.)
	model.zoomSkip, modelWatch.zoomSkip = true, true
	preview:HookScript("OnSizeChanged", Fit)
	-- Where the game would draw it: a faint box in the middle (Game's spot).
	ghost = CreateFrame("Frame", nil, preview)
	ghost:SetSize(110, 22)
	ghost:SetPoint("CENTER", preview, "CENTER", 0, GAME_Y) -- (where the game's look draws: board.middleY; Fit zooms it)
	ghost:SetFrameLevel(preview:GetFrameLevel() + 10)
	ghost.zoomSkip = true
	local ghostBack = ghost:CreateTexture(nil, "BACKGROUND")
	ghostBack:SetAllPoints()
	ghostBack:SetColorTexture(1, 1, 1, 0.08)
	local ghostWords = ghost:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	ghostWords:SetPoint("CENTER")
	ghostWords:SetText(L["the game's spot"])
	ghost:Hide()
	page.ghost = ghost

	-- Playing: samples from the mix (or the picked kind's) while it shows.
	local picked -- (the Kinds tab's picked kind: it plays alone)
	local round = 0
	local function PlayOne()
		local db = DB()
		if (db.selfTextBy or "ours") == "none" then return end
		local pool = {}
		if picked then
			local group = GroupOf(picked)
			if group then
				pool[1] = { group.sample, group.id }
				if group.critSample then pool[2] = { group.critSample, group.id, true } end
				pool[#pool + 1] = { group.sample, group.id }
			end
		else
			for _, sample in ipairs(MIX) do
				if ns.SelfTextShows(sample[2]) then pool[#pool + 1] = sample end
			end
		end
		if #pool == 0 then return end
		round = round % #pool + 1
		local sample = pool[round]
		if (db.selfTextBy or "ours") == "game" then
			ns.SelfTextGameSample(sample[1], sample[2], board)
		else
			ns.SelfTextSample(sample[1], sample[2], sample[3], board)
		end
	end
	page.PlayOne = PlayOne
	local ticker, test
	local function SetPlaying(on)
		view.playing = on
		if ticker then ticker:Cancel() ticker = nil end
		if test then test:SetText(on and L["Stop"] or L["Play"]) end
		if on and preview:IsVisible() then
			PlayOne()
			ticker = C_Timer.NewTicker(PLAY_EVERY, function()
				if view.playing and preview:IsVisible() then PlayOne() end
			end)
		end
	end
	page.SetPlaying = SetPlaying
	-- (Play / Stop: [[running-button-state]].)
	if ns.StylePreviewTest then
		test = ns.StylePreviewTest(preview, kit, L["Plays samples of your combat text, over and over."],
			function() SetPlaying(not view.playing) end)
		test:SetText(L["Stop"])
		page.playButton = test
	end
	preview:HookScript("OnShow", function() SetPlaying(view.playing) end)
	preview:HookScript("OnHide", function()
		if ticker then ticker:Cancel() ticker = nil end
		board:Clear()
	end)
	-- The preview's own buttons, along its bottom (not settings: what it shows).
	local function SmallButton(text, tip, onClick, after)
		local button = ns.PanelButton(preview)
		button:SetSize(98, 18)
		button:SetText(text)
		-- (Right of the preview's own Backdrop icon, 22 wide at its corner: on it they overlapped.)
		if after then button:SetPoint("LEFT", after, "RIGHT", 4, 0) else button:SetPoint("BOTTOMLEFT", preview, "BOTTOMLEFT", 34, 8) end
		button:SetFrameLevel(preview:GetFrameLevel() + 30)
		kit.Tooltip(button, tip)
		button:SetScript("OnClick", onClick)
		button.Refresh = function() end
		button.pageSwitch, button.zoomSkip = false, true
		kit.AddControl(button)
		return button
	end
	local camButton
	camButton = SmallButton(L["Over shoulder"], L["Shows you as the Shoulder Cam puts you, or right behind you."], function()
		view.over = not view.over
		camButton:SetText(view.over and L["Over shoulder"] or L["Behind you"])
		PlaceModel()
	end)
	page.camButton = camButton
	local ghostButton = SmallButton(L["Game's spot"], L["Shows where the game would draw it."], function()
		view.ghost = not view.ghost
		ghost:SetShown(view.ghost)
	end, camButton)
	page.ghostButton = ghostButton
	-- Play on screen: at your real spot, the options faded out meanwhile.
	local onScreen
	onScreen = SmallButton(L["Play on screen"], L["Plays samples where yours really show, the options faded out for a moment."], function()
		if page.onScreenUntil and GetTime() < page.onScreenUntil then return end
		page.onScreenUntil = GetTime() + 4
		onScreen:SetText(L["Playing..."])
		local panel = _G.SettingsPanel
		local faded = panel and not InCombatLockdown() and pcall(panel.SetAlpha, panel, 0.12)
		for index, sample in ipairs(MIX) do
			C_Timer.After((index - 1) * 0.2, function() ns.SelfTextSample(sample[1], sample[2], sample[3]) end)
		end
		C_Timer.After(4, function()
			if faded and panel then pcall(panel.SetAlpha, panel, 1) end
			onScreen:SetText(L["Play on screen"])
		end)
	end, ghostButton)
	page.onScreenButton = onScreen
	-- Drag to place: a gold mark at the texts' start; up and down sets
	-- Height, sideways Across (snapped to 5).
	local handle = CreateFrame("Button", nil, preview)
	handle:SetSize(14, 14)
	handle:SetFrameLevel(preview:GetFrameLevel() + 40)
	handle.zoomSkip = true -- (placed by PlaceHandle, every frame)
	local ring = handle:CreateTexture(nil, "OVERLAY")
	ring:SetAllPoints()
	ring:SetColorTexture(1, 0.82, 0, 0.9)
	local hole = handle:CreateTexture(nil, "OVERLAY", nil, 1)
	hole:SetPoint("TOPLEFT", 3, -3)
	hole:SetPoint("BOTTOMRIGHT", -3, 3)
	hole:SetColorTexture(0.05, 0.05, 0.05, 0.9)
	-- (Right-click: back where it starts, Height and Across only; before, only
	-- their sliders' Reset did it and the mark never said so, the user 2026-11-21.)
	kit.Tooltip(handle, L["Drag to move the texts; right-click to put them back."])
	handle:RegisterForDrag("LeftButton")
	handle:RegisterForClicks("RightButtonUp")
	function page.PlaceReset()
		local db = DB()
		db.selfTextHeight, db.selfTextAcross = ns.DEFAULTS.selfTextHeight, ns.DEFAULTS.selfTextAcross
	end
	handle:SetScript("OnClick", function(_, button)
		if button ~= "RightButton" then return end
		page.PlaceReset()
		Changed()
		kit.Refresh()
	end)
	local drag
	local function Snap(v, low, high) return math.max(low, math.min(high, math.floor(v / 5 + 0.5) * 5)) end
	function page.DragTo(dxPixels, dyPixels, from)
		local db = DB()
		from = from or { height = db.selfTextHeight or 0, across = db.selfTextAcross or 0 }
		db.selfTextHeight = Snap(from.height + dyPixels / Scale(), -300, 300)
		db.selfTextAcross = Snap(from.across + dxPixels / Scale(), -300, 300)
	end
	local function PlaceHandle()
		local db = DB()
		handle:ClearAllPoints()
		-- (Where the texts start: your spot, its side as damage taken goes (Split's
		-- other side mirrors it), Across and Height. On your spot alone it sat on
		-- your hip, away from them, 2026-11-21.)
		local side = ns.SelfTextSideOf and ns.SelfTextSideOf("damage", YouX()) or 0
		handle:SetPoint("CENTER", preview, "CENTER", (YouX() + side * ns.SELF_TEXT_SIDE + (db.selfTextAcross or 0)) * Scale(),
			((db.selfTextHeight or 0) + LIFT) * Scale())
	end
	page.PlaceHandle = PlaceHandle
	handle:SetScript("OnDragStart", function(self)
		local x, y = GetCursorPosition()
		local db = DB()
		drag = { x = x, y = y, scale = self:GetEffectiveScale(), height = db.selfTextHeight or 0, across = db.selfTextAcross or 0 }
	end)
	handle:SetScript("OnDragStop", function()
		drag = nil
		Changed()
		kit.Refresh()
	end)
	ns.SetOnUpdate(handle, function()
		if drag then
			local x, y = GetCursorPosition()
			page.DragTo((x - drag.x) / drag.scale, (y - drag.y) / drag.scale, drag)
		end
		PlaceHandle()
	end)
	handle.Refresh = function(self) self:SetShown(Ours() and true or false) end
	handle.pageSwitch = false
	kit.AddControl(handle)
	page.handle = handle
	if ns.StylePopout then ns.StylePopout(preview, kit.Tooltip) end

	-- Tabs ----------------------------------------------------------------------------
	local hosts, _, TabsShown, _, _, _, tabFrames = ns.PageTabsBelow(content, preview, {
		{ L["General"], L["Who draws it, where it sits and how it moves."] },
		{ L["Look"], L["Its font, edge and size."] },
		{ L["Kinds"], L["Each kind's own look."] },
	}, "Self Text Style/page", nil, nil, nil, function(index)
		-- (Off the Kinds tab: the mix again.)
		if index ~= 3 and picked then
			picked = nil
			page.picked = nil
			kit.Refresh()
		end
	end)
	page.hosts = hosts
	page.tabFrames = tabFrames -- (its tab buttons: /cine debug selftextpage clicks them)
	-- (What's made from here on goes onto a tab, its heading at the tab's top.)
	local made = {}
	for _, object in ipairs({ content:GetChildren() }) do made[object] = true end
	for _, object in ipairs({ content:GetRegions() }) do made[object] = true end
	local function Into(i, header)
		for _, set in ipairs({ { content:GetChildren() }, { content:GetRegions() } }) do
			for _, object in ipairs(set) do
				if not made[object] then
					made[object] = true
					object:SetParent(hosts[i])
				end
			end
		end
		header:ClearAllPoints()
		header:SetPoint("TOPLEFT", hosts[i], "TOPLEFT", 0, 0)
	end

	-- General ---------------------------------------------------------------------------
	local generalTop = stack:Header(content, L["Who draws it"])
	rows.Choices(L["Who draws it"], "selfTextBy", {
		{ "ours", L["Ours"], L["Ours, with this page's look and place."] },
		{ "game", L["The game's"], L["The game's own, as it normally is."] },
		{ "none", L["None"], L["No combat text about you."] },
	})
	rows.Section(L["Where"])
	rows.Choices(L["Side"], "selfTextSide", {
		{ "over", L["Over you"], L["Right over you."] },
		{ "free", L["Free side"], L["On your side away from the screen's middle."] },
		{ "split", L["Split"], L["Taken on one side, gained on the other."] },
	}, Ours)
	rows.Check("selfTextFollow", L["Follow the Shoulder Cam"], L["Sits beside you while the camera is over your shoulder."], Ours)
	rows.Slider("selfTextHeight", L["Height"], -300, 300, 5, "%d", nil, L["Moves it up or down from your spot."], Ours)
	rows.Slider("selfTextAcross", L["Across"], -300, 300, 5, "%d", nil, L["Moves it left or right from your spot."], Ours)
	rows.Slider("selfTextLife", L["Time shown"], 0.6, 4, 0.1, "%.1f sec", nil, L["How long each text stays."], Ours)
	rows.Choices(L["Motion"], "selfTextMotion", {
		{ "up", L["Up"], L["Rises, as the game's."] },
		{ "down", L["Down"], L["Falls."] },
		{ "arc", L["Arc"], L["Curves out to the side."] },
		{ "pop", L["Pop"], L["Crits start big and settle."] },
	}, Ours)
	rows.Section(L["Busy fights"])
	rows.Check("selfTextMerge", L["Merge repeats"], L["The same kind within half a second shows once, with how many."], Ours)
	rows.Slider("selfTextMost", L["At most"], 5, 40, 1, "%d", nil, L["How many texts show at once; the oldest goes first."], Ours)
	rows.Check("selfTextSticky", L["Crits stay"], L["A crit holds a moment where it popped."], Ours)
	Into(1, generalTop)

	-- Look ------------------------------------------------------------------------------
	local lookTop = stack:Header(content, L["Quick looks"])
	local looksRow = CreateFrame("Frame", nil, content)
	looksRow:SetSize(560, 46)
	stack:Add(looksRow, "label")
	page.lookButtons = {}
	local lastLook
	for _, look in ipairs(LOOKS) do
		local tile = CreateFrame("Button", nil, looksRow)
		tile:SetSize(100, 44)
		local back = tile:CreateTexture(nil, "BACKGROUND")
		back:SetAllPoints()
		back:SetColorTexture(0.1, 0.1, 0.12, 0.95)
		tile.edges = ns.MakeStyleEdges and ns.MakeStyleEdges(tile)
		local sample = tile:CreateFontString(nil, "OVERLAY")
		sample:SetPoint("TOP", 0, -5)
		pcall(sample.SetFont, sample, ns.SelfTextFontFile(look.font), math.floor(15 * look.size), look.edge == "edge" and "OUTLINE" or "")
		sample:SetTextColor(1, 0.2, 0.2)
		sample:SetText("-26")
		local name = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		name:SetPoint("BOTTOM", 0, 5)
		name:SetText(look.label)
		kit.Tooltip(tile, (L["Sets the font, edge, sizes and motion to %s's."]):format(look.label))
		tile:SetScript("OnClick", function()
			page.ApplyLook(look.id)
			Changed()
			kit.Refresh()
		end)
		tile.Refresh = function(self)
			local on = (DB().selfTextLook or "game") == look.id
			if self.edges and self.edges.SetColor then self.edges:SetColor(on and 1 or 0.3, on and 0.82 or 0.3, on and 0 or 0.3) end
			name:SetTextColor(on and 1 or 0.85, on and 0.82 or 0.85, on and 0 or 0.85)
			self:SetEnabled(Ours() and true or false)
		end
		tile.value = look.id
		if lastLook then tile:SetPoint("LEFT", lastLook, "RIGHT", 8, 0) else tile:SetPoint("LEFT", looksRow, "LEFT", 0, 0) end
		lastLook = tile
		kit.AddControl(tile)
		page.lookButtons[#page.lookButtons + 1] = tile
	end
	rows.Section(L["Text"])
	-- (No first choice: the font list starts with The game's already; the
	-- page's own made it "The game's, The game's", 2026-11-21.)
	rows.Font("selfTextFont", L["The text's font."], Ours)
	rows.Choices(L["Edge"], "selfTextEdge", {
		{ "game", L["Shadow"], L["A drop shadow, as the game's."] },
		{ "edge", L["Outline"], L["A thin outline."] },
		{ "both", L["Both"], L["An outline and a shadow."] },
		{ "none", L["None"], L["No edge."] },
	}, Ours)
	rows.Slider("selfTextSize", L["Size"], 0.5, 3, 0.05, "%.2f", nil, L["How big the text is."], Ours)
	rows.Slider("selfTextCrit", L["Crit size"], 1, 3, 0.1, "%.1f", nil, L["A crit's size, times a hit's."], Ours)
	rows.Slider("selfTextShadow", L["Shadow"], 0, 1, 0.05, "%.2f", nil, L["How dark the shadow is."], Ours)
	rows.Slider("selfTextFade", L["Fades from"], 0.2, 0.95, 0.05, "%.2f", nil, L["When in its time a text starts fading."], Ours)
	Into(2, lookTop)

	-- Kinds -----------------------------------------------------------------------------
	local kindsTop = stack:Header(content, L["Kinds"])
	stack:Note(content, L["Each kind starts with General's look. Click one to give it its own; the preview plays it alone."], 520)
	page.kindRows = {}
	local Pick -- (made under the list: it opens the kind's Look panel)
	for _, group in ipairs(Groups()) do
		local row = CreateFrame("Button", nil, content)
		row:SetSize(520, 24)
		stack:Add(row, "label")
		local glow = row:CreateTexture(nil, "BACKGROUND")
		glow:SetAllPoints()
		glow:SetColorTexture(1, 0.82, 0, 0.12)
		local hover = row:CreateTexture(nil, "HIGHLIGHT")
		hover:SetAllPoints()
		hover:SetColorTexture(1, 1, 1, 0.05)
		local showKey = "selfText_" .. group.id .. "Show"
		local check = kit.Check(row, showKey, "", (L["Shows %s."]):format(group.label), function(value)
			DB()[showKey] = value
			-- (Its color "off" from before 2026-11-21: on again means its color too.)
			if value and DB()["selfText_" .. group.id .. "Color"] == "off" then DB()["selfText_" .. group.id .. "Color"] = "game" end
			Changed()
			kit.Refresh()
		end)
		check:SetPoint("LEFT", row, "LEFT", 0, 0)
		check:SetSize(22, 22)
		kit.GreyUnless(check, Ours)
		local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		name:SetPoint("LEFT", check, "RIGHT", 4, 0)
		name:SetText(group.label)
		local sample = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		sample:SetPoint("RIGHT", row, "RIGHT", -24, 0)
		local badge = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		badge:SetPoint("RIGHT", sample, "LEFT", -12, 0)
		badge:SetTextColor(0.88, 0.63, 0.13)
		local chevron = row:CreateFontString(nil, "OVERLAY", "GameFontDisable")
		chevron:SetPoint("RIGHT", row, "RIGHT", -6, 0)
		row.searchLabel = group.label
		row:SetScript("OnClick", function() Pick(group.id) end)
		kit.Tooltip(row, (L["%s: click to give it its own look."]):format(group.label))
		row.Refresh = function(self)
			local shows = ns.SelfTextShows(group.id)
			local r, g, b = ns.SelfTextColorOf(group.id, nil)
			sample:SetText(group.sample)
			sample:SetTextColor(r, g, b, shows and 1 or 0.35)
			name:SetAlpha(shows and 1 or 0.45)
			local tick = ns.SelfTextGameTick(group.id)
			badge:SetText(tick == "off" and L["off in the game's options"] or "")
			name:SetText(group.label .. (KindChanged(group.id) and " |cffffd100*|r" or ""))
			glow:SetShown(picked == group.id)
			chevron:SetText(picked == group.id and "v" or ">")
			self.badgeText, self.picked = badge:GetText(), picked == group.id
		end
		row.pageSwitch = false
		kit.AddControl(row)
		page.kindRows[group.id] = row
	end
	-- The picked kind's own look: its own Look panel, docked beside the
	-- settings as Combat Text's texts' are (an editor folded open under the
	-- list read as lost, the user 2026-11-21). Its settings the kind's own
	-- (selfText_<kind><part>), each its group's till changed. Made the first
	-- time it's opened.
	local looks = {}
	page.kindLooks = looks
	local offPage = { Add = function(_, control) control:Hide() return control end }
	local function KindLook(id)
		if looks[id] then return looks[id] end
		local group = GroupOf(id)
		local function Key(part) return "selfText_" .. id .. part end
		local function IsOwn(db) return Ours(db) and ns.SelfTextPart(id, "Color") == "custom" end
		local styleRows = ns.StyleRows(kit, content, offPage, Changed, "selfTextStyle", Key)
		local button, pop = styleRows.Look("", group.label, {
			tabs = {
				default = function(part) return ns.DEFAULTS[Key(part)] end,
				copyKind = "selfText", copyName = group.label,
				resetLabel = L["Clear (as General's)"],
			},
			groups = {
				{ "Color", { { "color", "Color" } } },
				{ "Text", { { "text", "Text" } } },
				{ "Motion", { { "motion", "Motion" } } },
				{ "Sound", { { "sound", "Sound" } } },
			},
			color = function(look)
				look.Section(L["Color"])
				look.Segments(L["Color"], "Color", {
					{ "game", L["The game's"], L["The color the game gives it."] },
					{ "custom", L["Its own"], L["A color of its own."] },
				}, nil, Ours)
				look.Chips(L["Its color"], { "R", "G", "B" }, L["Its own color."], IsOwn)
				-- (A kind the game makes only with its own tick on: said here too.)
				if ns.SelfTextGameTick(id) ~= nil then
					look.Section(L["The game makes this kind only with its Text on Me tick on (Options > Combat). Cinematic never changes it for you."])
				end
			end,
			text = function(look)
				look.Section(L["Text"])
				look.Font("Font", L["Its font."], Ours, { "general", L["General's"] })
				look.Slider("Size", L["Size"], 50, 250, 5, "%d%%", 100, L["Its size, times General's."], Ours)
				if group.crit then
					look.Slider("Crit", L["Crit size"], 0, 300, 10, "%d%%", 100, L["Its crits' size, times a hit's (0: General's)."], Ours)
				end
			end,
			motion = function(look)
				look.Section(L["Motion"])
				look.Segments(L["Side"], "Side", {
					{ "general", L["General's"], L["As General's Side."] },
					{ "over", L["Over you"], L["Right over you."] },
					{ "left", L["Left"], L["On your left."] },
					{ "right", L["Right"], L["On your right."] },
				}, nil, Ours)
				look.Segments(L["Motion"], "Motion", {
					{ "general", L["General's"], L["As General's Motion."] },
					{ "up", L["Up"], L["Rises."] }, { "down", L["Down"], L["Falls."] },
					{ "arc", L["Arc"], L["Curves out."] }, { "pop", L["Pop"], L["Crits start big."] },
				}, nil, Ours)
			end,
			sound = function(look)
				look.Section(L["Sound"])
				look.Segments(L["Sound"], "Sound", {
					{ "none", L["None"], L["No sound."] },
					{ "tick", L["Tick"], L["A soft tick."] },
					{ "ping", L["Ping"], L["The map's ping."] },
					{ "alarm", L["Alarm"], L["The raid warning sound."] },
				}, nil, Ours)
			end,
		})
		if button then button:Hide() end
		-- (Closed, by its X or another panel opening: the preview plays the mix again.)
		pop:HookScript("OnHide", function()
			if picked == id then
				picked, page.picked = nil, nil
				Changed()
				kit.Refresh()
			end
		end)
		looks[id] = { pop = pop, key = Key }
		return looks[id]
	end
	page.KindLook = KindLook
	-- (Click a kind: its panel opens and the preview plays it alone; again:
	-- closed. Another kind's: that one's in its place.)
	function Pick(id)
		if picked == id then
			picked, page.picked = nil, nil
			if looks[id] then looks[id].pop:Hide() end
		else
			local was = picked and looks[picked]
			picked, page.picked = id, id
			if was then was.pop:Hide() end
			KindLook(id).pop:Show()
		end
		Changed()
		kit.Refresh()
	end
	page.Pick = Pick
	Into(3, kindsTop)

	-- Reset page: every kind's parts too (the editor's keys aren't the page's).
	if kit.OnReset then
		kit.OnReset(content, function()
			for _, group in ipairs(Groups()) do page.ClearKind(group.id) end
			local db = DB()
			db.selfTextLook = ns.DEFAULTS.selfTextLook
			local open = picked and looks[picked]
			picked, page.picked = nil, nil
			if open then open.pop:Hide() end
			Changed()
		end)
	end

	canvas:SetScript("OnShow", kit.PageShown(function()
		kit.Refresh()
		TabsShown()
	end, content))
	canvas:Hide()
	kit.RegisterSubpage(canvas, "Self Text Style", L["Text on You Style"])
end
