-- Vitals Vision's low mana (its Mana tabs): as your mana runs dry, the world
-- drains toward a cold grey and dark edges close in. A player's wish
-- (Discord "Low/OOM Vision", 2026-11-23). Mana is secret (WoW Forever: even
-- out of a fight), so the game sets the overlay's alpha from your mana
-- through a curve (engine rule forever.unitpower.mana-secret); the look on it
-- is fixed, so nothing runs per frame for it but a light check of where it
-- shows. A veil blended over the world, not multiplied: a multiplying layer
-- ignores its alpha, and blending toward grey takes colour out, the closest
-- an addon gets to grayscale.
-- The Vision tab's Mana tab is its switch (off to start); the Style tab's
-- Mana tab its look. Both pages build their rows from here (LowHealth.lua's
-- panels call ns.ManaVisionRows and ns.ManaVisionStyleRows).

local _, ns = ...
ns.Module("visions", function() -- (only with Visions loaded, Modules.lua)
local L = ns.L

local DEFAULTS = ns.DEFAULTS
local TAB = "tabOn:VitalsVision:mana" -- the Vision tab's Mana tab: low mana at all (off to start)
ns.VITALS_MANA_TAB = TAB
DEFAULTS[TAB] = false
ns.SetPageMaster({ TAB }, "lowHealth")
-- (The Style tab's Mana tab, LowHealth.lua's ns.VITALS_TABS.mana: off with this one.)
if ns.VITALS_TABS and ns.VITALS_TABS.mana then ns.SetPageMaster({ ns.VITALS_TABS.mana }, TAB) end
DEFAULTS.lowManaAlways = true         -- its Show in row's Always (the rest: ROW_KEY's ticks and rule)
DEFAULTS.lowManaVisionStart = 0.3     -- mana (0-1) it starts showing below
DEFAULTS.lowManaVisionFull = 0.05     -- ...and is all the way in at
DEFAULTS.lowManaVisionCalm = 0.6      -- strength out of a fight
DEFAULTS.lowManaVisionLook = "cold"   -- a LOOKS key (Cold to start: the user's pick, 2026-11-23)
DEFAULTS.lowManaVisionStrength = 0.7  -- how strong the veil and edges are at full
DEFAULTS.lowManaVisionEdges = true    -- dark edges closing in
DEFAULTS.lowManaVisionReach = 0.25    -- share of the screen the edges cover

local ROW_KEY = "vision:lowMana"
-- The looks: the veil's colour (blended over the world) and the edges'.
local LOOKS = {
	drain = { veil = { 0.42, 0.45, 0.52 }, edge = { 0.03, 0.05, 0.1 } },
	cold = { veil = { 0.2, 0.3, 0.52 }, edge = { 0.01, 0.04, 0.14 } },
	dusk = { veil = { 0.28, 0.24, 0.32 }, edge = { 0.05, 0.02, 0.07 } },
}
local VEIL_MOST = 0.55   -- the veil's opacity at Strength 100% (more hides the world)
local EDGE_MOST = 0.95   -- the edges' darkness at Strength 100%
local TEST_TIME, TEST_HOLD = 8, 2 -- the test: mana falling over this, then held
local CHECK_EVERY = 0.25 -- seconds between checks of where it shows (rules aren't cheap)

local db
local screen          -- the screen's drawer: { frame, veil, edges }
local driver          -- runs the checks (its own frame: on with the UI hidden too)
local test            -- the page's test: { start } while it runs
local curves = {}     -- by "start:full"
local secretError     -- the last error setting the game's alpha (for the test's log)

local function Secret(value)
	return issecretvalue and issecretvalue(value)
end

-- The look's settings: the Style page's own while it's on and its Mana tab
-- is, else the defaults.
local function Look()
	local look = ns.StyleLook and ns.StyleLook("lowHealthStyle") or db
	if ns.VITALS_TABS and ns.VITALS_TABS.mana and not ns.PageOn(ns.VITALS_TABS.mana) then look = DEFAULTS end
	return look
end

-- 0 above Starts, 1 at Full and under, eased between.
local function Thresholds()
	local start = math.min(1, math.max(0.02, db.lowManaVisionStart or DEFAULTS.lowManaVisionStart))
	local full = math.max(0, math.min(start - 0.01, db.lowManaVisionFull or DEFAULTS.lowManaVisionFull))
	return start, full
end
local function Ease(t) return t * t * (3 - 2 * t) end
local function LevelAt(share)
	local start, full = Thresholds()
	if share >= start then return 0 end
	if share <= full then return 1 end
	return Ease((start - share) / (start - full))
end
ns.ManaVisionLevelAt = LevelAt -- (the offline check's)

-- The same as a curve for the game: mana share -> alpha. Straight lines, so
-- the ease in steps. nil where there's no curve API (Classic Era).
local EASE_STEPS = 6
local function Curve()
	local start, full = Thresholds()
	local key = ("%.3f:%.3f"):format(start, full)
	if curves[key] ~= nil then return curves[key] or nil end
	curves[key] = false
	if not (C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType and UnitPowerPercent) then
		return nil
	end
	local ok, curve = pcall(C_CurveUtil.CreateCurve)
	if ok and curve then
		curve:SetType(Enum.LuaCurveType.Linear)
		curve:AddPoint(0, 1)
		curve:AddPoint(full, 1)
		for i = 1, EASE_STEPS - 1 do
			local t = i / EASE_STEPS
			curve:AddPoint(full + (start - full) * t, Ease(1 - t))
		end
		curve:AddPoint(start, 0)
		if start < 1 then curve:AddPoint(1, 0) end
		curves[key] = curve
	end
	return curves[key] or nil
end
ns.ManaVisionCurve = Curve

-- A drawer: a frame whose alpha is the level, the veil and edges on it at
-- the look's full strength.
local function NewDrawer(parent)
	local d = { frame = CreateFrame("Frame", nil, parent) }
	d.frame:SetAllPoints(parent)
	d.veil = d.frame:CreateTexture(nil, "BACKGROUND")
	d.veil:SetAllPoints(d.frame)
	d.veil:SetColorTexture(1, 1, 1, 1)
	d.edges = ns.CreateVignette(d.frame)
	return d
end

-- The look on a drawer (w, h: its size, a preview's; the screen's if nil).
-- calm: out of a fight (the strength out of combat).
local function Paint(d, calm, w, h)
	local look = Look()
	local colors = LOOKS[look.lowManaVisionLook] or LOOKS.cold
	local strength = (look.lowManaVisionStrength or DEFAULTS.lowManaVisionStrength)
		* (calm and (db.lowManaVisionCalm or DEFAULTS.lowManaVisionCalm) or 1)
	local v = colors.veil
	d.veil:SetVertexColor(v[1], v[2], v[3], math.min(1, strength * VEIL_MOST))
	local e = colors.edge
	local edgeAlpha = look.lowManaVisionEdges and math.min(1, strength * EDGE_MOST) or 0
	ns.SetVignette(d.edges, look.lowManaVisionReach or DEFAULTS.lowManaVisionReach, edgeAlpha, e[1], e[2], e[3], w, h)
	d.strength, d.edgeAlpha = strength, edgeAlpha
end

-- Whether this character has mana at all (a warrior, a rogue: none). Max
-- mana stays readable (the rule); secret: say yes.
local function HasMana()
	local max = UnitPowerMax("player", 0)
	if Secret(max) then return true end
	return type(max) == "number" and max > 0
end
ns.ManaVisionHasMana = HasMana

local function Fighting()
	return InCombatLockdown() or ns.Flag(UnitAffectingCombat("player"))
end

local rowShows, rowReadAt = true, -1
local function RowShows(now)
	if db.lowManaAlways then return true end
	if now - rowReadAt >= CHECK_EVERY then
		rowReadAt = now
		local ok, shows = pcall(ns.RowOnNow, ROW_KEY, false, true)
		rowShows = ok and shows and true or false
	end
	return rowShows
end

-- (In a pcall, not a closure made each time.)
local function GameAlpha(frame, curve)
	frame:SetAlpha(UnitPowerPercent("player", 0, false, curve))
end

-- Mana's share now, when it's plain; nil when secret.
local function ManaShare()
	local mana, max = UnitPower("player", 0), UnitPowerMax("player", 0)
	if Secret(mana) or Secret(max) or type(mana) ~= "number" or type(max) ~= "number" or max <= 0 then return nil end
	return mana / max
end

-- What's wanted now: "test" (the test's share), "game" (the curve), or nil (hidden).
local function Wanted(now)
	if test then
		if now - test.start > TEST_TIME + TEST_HOLD then
			test = nil
		else
			return "test"
		end
	end
	if not ns.Setting(TAB) or not HasMana() or ns.Flag(UnitIsDeadOrGhost("player")) or not RowShows(now) then
		return nil
	end
	return "game"
end

-- The test's mana: from just over Starts to nothing (from full, nothing
-- showed for most of it).
local function TestShareAt(seconds)
	local start = Thresholds()
	return math.min(1, start + 0.05) * (1 - math.min(1, seconds / TEST_TIME))
end
local function TestShare(now) return TestShareAt(now - test.start) end

-- (Painted at each check while it shows: a few textures, and the look
-- follows every switch over it, a tab's right-click too.)
local shownMode
local function Update()
	if not db or not screen then return end
	local now = GetTime()
	local mode = Wanted(now)
	if not mode then
		if shownMode then screen.frame:Hide() end
		shownMode = nil
		return
	end
	Paint(screen, not Fighting())
	shownMode = mode
	screen.level = nil
	if mode == "test" then
		-- (Its level kept plain: once the game has set the alpha from your
		-- mana, GetAlpha reads secret even after a plain one, Forever 2026-11-23.)
		screen.level = LevelAt(TestShare(now))
		screen.frame:SetAlpha(screen.level)
	else
		local curve = Curve()
		if curve then
			local ok, err = pcall(GameAlpha, screen.frame, curve)
			secretError = not ok and tostring(err) or nil
			if not ok then screen.frame:SetAlpha(0) end
		else
			local share = ManaShare()
			screen.frame:SetAlpha(share and LevelAt(share) or 0)
		end
	end
	screen.frame:Show()
end

-- Settings changed (the pages): painted again, checked again.
function ns.RefreshManaVision()
	if not screen then return end
	wipe(curves) -- (their points follow Starts and Full)
	rowReadAt = -1
	Update()
end

-- The page's test: your mana falling to nothing over 8 seconds on the
-- screen (plain, whatever the game says), whatever the switches say.
function ns.TestManaVision()
	if not screen then return end
	test = { start = GetTime() }
	ns.RefreshManaVision()
end
function ns.StopManaVisionTest()
	test = nil
	ns.RefreshManaVision()
end
function ns.ManaVisionTestLeft()
	if not test then return nil end
	return math.max(0, test.start + TEST_TIME + TEST_HOLD - GetTime())
end

-- (The test's and /cine debug's: what it's doing now.)
function ns.ManaVisionState()
	if not screen then return { ready = false } end
	local mana, max = UnitPower("player", 0), UnitPowerMax("player", 0)
	return {
		ready = true, mode = shownMode, shown = screen.frame:IsShown(),
		alpha = screen.frame:GetAlpha(), level = screen.level, strength = screen.strength, edgeAlpha = screen.edgeAlpha,
		on = ns.Setting(TAB) and true or false, hasMana = HasMana(), curve = Curve() ~= nil,
		manaSecret = Secret(mana) and true or false, maxSecret = Secret(max) and true or false,
		error = secretError, frame = screen.frame,
	}
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		db = ns.GetDB()
		local holder = CreateFrame("Frame", nil, UIParent)
		ns.CoverWorld(holder)
		holder:SetFrameStrata("BACKGROUND")
		holder:SetFrameLevel(2) -- (over Vitals Vision's health edges, under the letterbox)
		holder:EnableMouse(false)
		ns.AddOverlay(holder) -- (shown with the UI hidden too)
		screen = NewDrawer(holder)
		screen.frame:Hide()
		driver = CreateFrame("Frame")
		local wait = 0
		ns.SetOnUpdate(driver, ns.Profiled("Mana Vision", function(_, elapsed)
			wait = wait - elapsed
			if wait > 0 then return end
			wait = CHECK_EVERY
			Update()
		end))
		events:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
		events:RegisterUnitEvent("UNIT_MAXPOWER", "player")
		events:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
		for _, other in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_DEAD",
			"PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_ENTERING_WORLD" }) do
			events:RegisterEvent(other)
		end
	end
	Update()
end)

-- The Vision tab's Mana tab: where it shows, from how low, and a test.
-- (LowHealth.lua's CreateVitalsVisionPanel, inside the tab's section.)
function ns.ManaVisionRows(kit, content, stack, Changed)
	local function Apply()
		Changed()
		ns.RefreshManaVision()
	end
	local header = stack:Header(content, L["Show in"])
	local lastRow = ns.ShowTable(content, header, {
		opts = { anyFight = true }, underHeader = true,
		{ key = ROW_KEY, label = L["Low mana"], alwaysKey = "lowManaAlways",
			alwaysOn = function() return ns.GetDB().lowManaAlways end,
			setAlways = function(value) ns.GetDB().lowManaAlways = value Apply() end,
			alwaysTip = L["Shows everywhere, so the other columns don't change anything."],
			apply = Apply },
	}, L["Low mana"])
	stack:Continue(lastRow, "label")

	stack:Header(content, L["Low mana"])
	local line = stack:Add(kit.BoxLine(content), "label")
	line:Box(L["Starts"], "lowManaVisionStart", 10, 100, 5, "%d%%", 100,
		L["The screen starts to drain when your mana drops below this."], Apply)
	line:Box(L["Full"], "lowManaVisionFull", 0, 90, 5, "%d%%", 100,
		L["The screen is fully drained when your mana drops to this. Keep it below Starts."], Apply)
	local calm = stack:Add(kit.BoxLine(content), "label")
	calm:Box(L["Strength out of combat"], "lowManaVisionCalm", 0, 100, 5, "%d%%", 100,
		L["How strong it is out of a fight."], Apply)

	-- Test: on the screen, your mana falling to nothing; Stop with the
	-- seconds left meanwhile.
	local holder = CreateFrame("Frame", nil, content)
	holder:SetSize(420, 26)
	local button = ns.PanelButton(holder)
	button:SetSize(90, 22)
	button:SetPoint("LEFT", 2, 0)
	button:SetText(L["Test"])
	kit.Tooltip(button, L["Shows your mana running out on the screen."])
	button:SetScript("OnClick", function()
		if ns.ManaVisionTestLeft() then ns.StopManaVisionTest() else ns.TestManaVision() end
	end)
	local wait = 0
	ns.SetOnUpdate(button, function(self, elapsed)
		wait = wait - elapsed
		if wait > 0 then return end
		wait = 0.2
		local left = ns.ManaVisionTestLeft()
		self:SetText(left and L["Stop (%d)"]:format(math.ceil(left)) or L["Test"])
	end)
	button.pageSwitch = false -- (works with the switches off too)
	-- (A character without mana: said so beside it.)
	local note = kit.Label(holder, "GameFontDisableSmall", "")
	note:SetPoint("LEFT", button, "RIGHT", 12, 0)
	kit.AddControl({ debugName = "mana note", owner = content, Refresh = function()
		note:SetText(db and not HasMana() and L["This character doesn't use mana, so nothing shows."] or "")
	end })
	stack:Add(holder, "label")
	ns.manaVisionTestButton = button
	return button
end

-- The Style tab's Mana tab: the look, and a preview of it draining.
-- rows: the page's ns.StyleRows. (LowHealth.lua's CreateVitalsStylePanel.)
-- (Its rows call the page's Changed: ns.RefreshLowHealth, which paints this
-- again too. The preview paints itself at each check.)
function ns.ManaVisionStyleRows(kit, content, stack, rows)
	rows.Choices(L["Look:"], "lowManaVisionLook", {
		{ "drain", L["Drained"], L["Gray-blue: the world's color drains away."] },
		{ "cold", L["Cold"], L["A cold, deep blue."] },
		{ "dusk", L["Dusk"], L["A dim, gray-violet dusk."] },
	})
	rows.Boxes():Box(L["Strength"], "lowManaVisionStrength", 10, 100, 5, "%d", 100,
		L["How strong the veil and the edges are when your mana is out."], nil, "%")
	local edges = rows.Check("lowManaVisionEdges", L["Dark edges"], L["Dark edges close in as your mana runs out."])
	rows.Boxes(edges):Box(L["Reach"], "lowManaVisionReach", 10, 50, 1, "%d", 100,
		L["How far in from the screen's edges they come."],
		function(d) return rows.On(d) and d.lowManaVisionEdges end, "%")

	-- The preview: the page's backdrop, the look drawn on it at your mana's
	-- low (or the test's).
	local W = 400
	local preview = CreateFrame("Frame", nil, content)
	preview:SetSize(W, 225)
	if preview.SetClipsChildren then preview:SetClipsChildren(true) end
	local stage = CreateFrame("Frame", nil, preview)
	stage:SetAllPoints()
	stage:SetFrameLevel(preview:GetFrameLevel() + 2)
	local caption = kit.Label(preview, "GameFontDisableSmall", L["Preview"])
	caption:SetPoint("TOPLEFT", 6, -5)
	caption.searchSkip = true
	local manaText = kit.Label(preview, "GameFontHighlightSmall", "")
	manaText:SetPoint("TOPRIGHT", -82, -9)
	manaText.searchSkip = true
	local d = NewDrawer(stage)
	local sim
	function preview:Refresh()
		if not self:IsVisible() then return end
		local width, height = UIParent:GetWidth(), UIParent:GetHeight()
		self:SetHeight(math.floor(W * height / math.max(width, 1) + 0.5))
		ns.StyleScene(self)
	end
	local paintWait = 0
	ns.SetOnUpdate(preview, function(self, elapsed)
		if not db then return end
		paintWait = paintWait - elapsed
		if paintWait <= 0 then
			paintWait = CHECK_EVERY
			Paint(d, false, self:GetWidth(), self:GetHeight())
		end
		local share = 0.1
		if sim then
			local t = GetTime() - sim
			if t > TEST_TIME + TEST_HOLD then sim = nil else share = TestShareAt(t) end
		end
		d.frame:SetAlpha(LevelAt(share))
		manaText:SetText(("%s %d%%"):format(L["Mana"], math.floor(share * 100 + 0.5)))
	end)
	preview.pageSwitch = false
	stack:Add(preview, "label")
	kit.AddControl(preview)
	local testButton = ns.StylePreviewTest(preview, kit, L["Shows your mana running out in the preview and on screen."],
		function()
			if ns.ManaVisionTestLeft() then
				sim = nil
				ns.StopManaVisionTest()
			else
				sim = GetTime()
				ns.TestManaVision()
			end
		end)
	local wait = 0
	ns.SetOnUpdate(testButton, function(self, elapsed)
		wait = wait - elapsed
		if wait > 0 then return end
		wait = 0.2
		local left = ns.ManaVisionTestLeft()
		self:SetText(left and L["Stop (%d)"]:format(math.ceil(left)) or L["Test"])
	end)
	ns.manaVisionPreview = preview
	return preview
end
end) -- (ns.Module "visions")
