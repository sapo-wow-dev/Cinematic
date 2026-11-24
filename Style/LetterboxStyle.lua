-- The Letterbox and Tint pages (their Show in rows), and Letterbox's Style
-- tab: how the letterbox bars look and come in (Effects.lua draws them, by ns.LetterboxLook). Their height by a share of
-- the screen or by a film's frame, color, opacity, a feathered inner edge, a
-- line along it, and sliding or fading in, over the UI's fade or a time of
-- their own. A preview at the top, drawn by the same code as the real bars.
-- When they show at all: the Letterbox tab (ns.CreateEffectPanel). Both in the
-- Atmosphere hub under one icon.

local ADDON_NAME, ns = ...
-- (Up to the Letterbox Style page: the Atmosphere hub's effect pages, their
-- first tab, loaded with Atmosphere, Style or not. Then the Style tab's page,
-- with Style; with Atmosphere left out Options.lua builds none. Modules.lua.)
local L = ns.L

ns.Module("atmosphere", function() -- (the Letterbox and Tint pages: only with Atmosphere loaded)
-- The Atmosphere hub's effects with a page of their own: a Show in row on
-- the first tab, the look on the Style tab (English: L at the call, once the
-- language is set). page: the first tab's page, style: the Style tab's.
local EFFECT_PAGES = {
	letterbox = { name = "Letterbox", page = "Letterbox", style = "Letterbox Style",
		tip = "Where and when the bars show.", styleTip = "How the letterbox bars look and come in.",
		intro = "Black bars at the top and bottom of the screen in CineMode, like in a movie. The row below " ..
			"sets where and when they show; with nothing ticked, they're off. Set their size and look on " ..
			"the Style tab. The Visual Effects page's Enable Page turns them off too.",
		switchTip = "When on, the bars show where the row below says. Turn it off for no letterbox anywhere; the " ..
			"row and its Style tab keep their settings for when you turn it back on." },
	tint = { name = "Tint", page = "Tint", style = "Tint Style",
		tip = "Where and when the tint shows.",
		styleTip = "The color grading: a preset, the time of day and each zone's mood.",
		intro = "The color grading over the game world in CineMode. The row below sets where and when it shows; " ..
			"with nothing ticked, it's off. Set its preset, time of day and zone tints on the Style tab. " ..
			"The Visual Effects page's Enable Page turns it off too. The UI isn't tinted.",
		switchTip = "When on, the tint shows where the row below says. Turn it off for no tint anywhere; this page " ..
			"and its Style tab keep their settings for when you turn it back on." },
	-- (Its own icon since 2026-11-23, out of the Visual Effects page: its row,
	-- strength and view distance here, its colors on the Style tab.)
	weather = { name = "Weather", page = "Weather", style = "Weather Style",
		tip = "Where and when the weather tints the scene.",
		styleTip = "Each weather's color, and how fast it comes in.",
		intro = "Rain, snow and sandstorms tint the scene in CineMode, more in heavier weather, and never under " ..
			"a roof. The row below sets where and when; with nothing ticked, it's off. Set each weather's color " ..
			"on the Style tab. The Visual Effects page's Enable Page turns it off too.",
		switchTip = "When on, the weather tints the scene where the row below says. Turn it off for no weather " ..
			"tint anywhere; this page and its Style tab keep their settings for when you turn it back on." },
}

-- A Preview button (2026-11-23): shows its effect over the world for a
-- while, CineMode or not, and is Stop while that runs (and back by itself
-- after). Greyed while usable(db) says no. anchor: a slider (the button
-- goes past its value) or another control (just right of it).
local PREVIEW_SECONDS = 8 -- (a button's; a slider's move shows ns.EFFECT_PREVIEW_SECONDS)
function ns.EffectPreviewButton(kit, parent, anchor, text, width, tip, usable, Running, Start, Stop)
	local button = ns.PanelButton(parent)
	button:SetSize(width, 20)
	if anchor.GetObjectType and anchor:GetObjectType() == "Slider" then
		button:SetPoint("LEFT", anchor, "RIGHT", 58, 0) -- (past the value, "100%")
	else
		button:SetPoint("LEFT", anchor, "RIGHT", 4, 0)
	end
	button:SetText(text)
	button.searchSkip = true
	kit.Tooltip(button, tip)
	button:SetScript("OnClick", function()
		if Running() then Stop() else Start() end
	end)
	local shown, enabled
	ns.SetOnUpdate(button, function(self)
		local running = Running() and true or false
		if running ~= shown then
			shown = running
			self:SetText(running and L["Stop"] or text)
		end
		local db = ns.GetDB()
		local can = running or (db.visualEffects ~= false and usable(db)) or false
		if can ~= enabled then
			enabled = can
			self:SetEnabled(can)
		end
	end)
	-- (For /cine debug atmosphere: Dev/AtmosphereTest.lua.)
	ns.effectPreviewButtons = ns.effectPreviewButtons or {}
	ns.effectPreviewButtons[#ns.effectPreviewButtons + 1] = button
	return button
end
-- One for a Tint.lua preview kind ("vignette", "inn", "weather"); weather: a
-- function giving the weather type to show (the Weather page's pick).
function ns.TintPreviewButton(kit, parent, anchor, kind, text, width, tip, usable, weather)
	local button = ns.EffectPreviewButton(kit, parent, anchor, text, width, tip, usable,
		function() return ns.EffectPreviewing(kind) end,
		function() ns.PreviewEffect(kind, PREVIEW_SECONDS, weather and weather() or nil) end,
		function() ns.StopEffectPreview() end)
	button.previewFor = kind
	return button
end

-- The Weather page's screen effects (WeatherFX.lua, 2026-11-23): a Show in
-- row each under the weather tint's, their strengths under its own.
EFFECT_PAGES.weather.extraRows = { { "frost", "Frost" }, { "rainlens", "Rain on the lens" },
	{ "lightning", "Lightning" }, { "density", "Heavier weather" } }

-- Under the Weather tab's rows: how strong, with a weather to preview (a
-- dropdown and Preview), the screen effects' strengths, and the view
-- distance in bad weather.
EFFECT_PAGES.weather.More = function(kit, content, stack)
	local function Picked() return ns.WeatherTypeOf(ns.GetDB().weatherPreviewKind or "Rain") end
	stack:Header(content, L["How strong"])
	local strength = stack:Add(kit.Slider(content, "weatherTintStrength", L["Strength"], 0, 100, 5, function(value)
		return value == 0 and L["Off"] or ("%d%%"):format(value)
	end, 100, function()
		ns.RefreshTint()
		ns.PreviewEffect("weather", nil, Picked())
	end), "slider")
	kit.Tooltip(strength, L["Rain, snow and sandstorms tint the scene, more strongly in heavier weather."])
	-- (Which weather the preview shows: rarely the one where you stand. On a
	-- line of its own under the slider: beside it, Preview ran past the
	-- settings' edge, in game 2026-11-23.)
	local line = stack:Add(kit.Label(content, "GameFontHighlight", L["Preview:"]), "label")
	line.searchSkip = true
	line:SetHeight(28) -- (as tall as the dropdown beside it: the next row clears it)
	local choices = {}
	for _, each in ipairs(ns.PreviewWeatherTypes()) do choices[#choices + 1] = { value = each[4], text = each[2] } end
	local pick = kit.Dropdown(content, "weatherPreviewKind", choices, 120, function()
		if ns.EffectPreviewing("weather") then ns.PreviewEffect("weather", PREVIEW_SECONDS, Picked()) end
	end)
	if pick then
		pick:SetPoint("LEFT", line, "RIGHT", 10, 0)
		kit.Tooltip(pick, L["The weather the Preview shows."])
		ns.weatherPreviewPick = pick -- (for /cine debug atmosphere)
	end
	ns.TintPreviewButton(kit, content, pick or line, "weather", L["Preview"], 80,
		L["Shows this weather's tint at its heaviest for a few seconds (at 50% while Strength is Off)."],
		function() return true end, Picked)
	-- On the screen (WeatherFX.lua): each effect's strength, Off to start with,
	-- and a Preview (the slider's move shows it for a moment too), each
	-- greyed while its row is off everywhere.
	stack:Header(content, L["On the screen"])
	local function Percent(value) return value == 0 and L["Off"] or ("%d%%"):format(value) end
	for _, fx in ipairs({
		{ "frost", "Frost", "Frost creeps in on the screen's edges in snow, and melts away after." },
		{ "rainlens", "Rain on the lens", "Drops and trails run down the screen in rain." },
		{ "lightning", "Lightning", "Now and then a flash lights up a storm, with thunder." },
	}) do
		local keys = ns.WEATHER_FX_KEYS[fx[1]]
		local slider = stack:Add(kit.Slider(content, keys.strength, L[fx[2]], 0, 100, 1, Percent, 100, function(value)
			if value > 0 then ns.WeatherFxPreview(fx[1], 3) end
		end), "slider")
		kit.Tooltip(slider, L[fx[3]])
		kit.GreyUnless(slider, function(db) return db[keys.switch] ~= false end)
		ns.EffectPreviewButton(kit, content, slider, L["Preview"], 80,
			L["Shows it for a few seconds, in CineMode or not (at 50% while it's Off)."],
			function(db) return db[keys.switch] ~= false end,
			function() return ns.WeatherFxPreviewing(fx[1]) end,
			function() ns.WeatherFxPreview(fx[1], PREVIEW_SECONDS) end,
			function() ns.WeatherFxPreview(nil) end).previewFor = fx[1]
		ns.weatherFxSliders = ns.weatherFxSliders or {}
		ns.weatherFxSliders[fx[1]] = slider -- (for /cine debug atmosphere)
	end
	-- (The game's own rain and snow: its density held at 1-3 while the row is
	-- on, yours back after. No preview: it shows only where it's raining.)
	local density = stack:Add(kit.Slider(content, "weatherDensityLevel", L["Heavier weather"], 0, 3, 1, function(value)
		return value == 0 and L["Off"] or ({ L["Light"], L["Medium"], L["Heavy"] })[value]
	end, 1), "slider")
	kit.Tooltip(density, L["Makes the game's own rain and snow thicker while its row is on, and puts yours back after."])
	kit.GreyUnless(density, function(db) return db.weatherDensityOn ~= false end)
	ns.weatherFxSliders = ns.weatherFxSliders or {}
	ns.weatherFxSliders.density = density
	-- View distance in bad weather (Graphics.lua): only where the game says
	-- the weather and has the view distance setting.
	if C_Weather and C_Weather.GetCurrentWeather and GetCVar("horizonStart") ~= nil then
		stack:Header(content, L["View distance"])
		local view = stack:Add(kit.Slider(content, "rainViewScale", L["Reduce view distance in bad weather"], 0, 100, 5,
			function(value) return value == 0 and L["Off"] or ("%d%%"):format(value) end, 100), "slider")
		kit.Tooltip(view, L["Brings the view distance in during rain, snow or sandstorms, more the heavier it gets."])
		ns.EffectPreviewButton(kit, content, view, L["Preview"], 80,
			L["Pulls the view distance in as a downpour would, for a few seconds."],
			function(db) return (db.rainViewScale or 0) > 0 end,
			function() return ns.RainViewPreviewing() end, function() ns.PreviewRainView(PREVIEW_SECONDS) end,
			function() ns.PreviewRainView(0) end).previewFor = "viewdist"
	end
end

-- Under the Letterbox tab's row: the bars for a few seconds on a place new
-- to you (CineMode or not: Effects.lua, ns.LetterboxOnDiscover).
EFFECT_PAGES.letterbox.More = function(kit, content, stack)
	-- (Letterbox.lua: WorldFrame between the bars, out of fights only.)
	stack:Header(content, L["The world"])
	stack:Add(kit.Check(content, "letterboxWorld", L["Draw the world between the bars"],
		L["Shows the whole view between the bars instead of hiding its top and bottom (it changes only out of fights)."], function(value)
			ns.GetDB().letterboxWorld = value
			ns.letterboxDirty = true
		end), "check")
	stack:Header(content, L["New places"])
	stack:Add(kit.Check(content, "letterboxOnDiscover", L["Show bars on discovering a new place"],
		L["Brings the bars in for a few seconds when you find a new place."], function(value)
			ns.GetDB().letterboxOnDiscover = value
			kit.Refresh()
		end), "check")
	local time = stack:Add(kit.Slider(content, "letterboxDiscoverTime", L["How long"], 2, 10, 1, L["%d sec"]),
		"slider")
	kit.Tooltip(time, L["How long the bars stay when you find a new place."])
	kit.GreyUnless(time, function(db) return db.letterboxOnDiscover end)
end

-- Under the Tint tab's row: how strong it is, its drift, and the zone
-- borders' timing, each slider on one line with its name (stack: inline).
EFFECT_PAGES.tint.More = function(kit, content, stack)
	stack:Header(content, L["How strong"])
	local strength = stack:Add(kit.Slider(content, "tintStrength", L["Strength"], 5, 100, 1, "%d%%", 100,
		ns.RefreshTint), "slider")
	kit.Tooltip(strength, L["How strongly the tint colors the world, for every preset."])
	if not ns.isRetail then -- (retail's world shows the tint as it is)
		stack:Add(kit.Check(content, "tintClassicBoost", L["Classic boost"],
			L["Makes the tint stronger on this client, whose brighter world shows it less."], function(value)
				ns.GetDB().tintClassicBoost = value
				ns.RefreshTint()
			end), "check")
	end
	local timeStrength = stack:Add(kit.Slider(content, "timeTintStrength", L["Time of day strength"], 0, 100, 5,
		"%d%%", 100, ns.RefreshTint), "slider")
	kit.Tooltip(timeStrength, L["How strongly the time-of-day color applies."])
	-- (All the way left is Off: tintDrift off, the amount kept for next time.)
	kit.RecordKey(content, "tintDrift")
	kit.RecordKey(content, "tintDriftAmount")
	local driftAmount = stack:Add(kit.Slider(content, {
		key = "tintDriftAmount", -- (its id for /cine find)
		get = function()
			local db = ns.GetDB()
			return db.tintDrift and db.tintDriftAmount or 0
		end,
		set = function(value)
			local db = ns.GetDB()
			db.tintDrift = value > 0
			if value > 0 then db.tintDriftAmount = value end
		end,
	}, L["Drift amount"], 0, 15, 1, function(value)
		return value == 0 and L["Off"] or ("+/-%d%%"):format(value)
	end, 100, ns.RefreshTint), "slider")
	kit.Tooltip(driftAmount, L["Lets the tint's strength slowly drift up and down by this much."])
	local mapDim = stack:Add(kit.Slider(content, "mapDim", L["Dim the world map"], 0, 80, 5,
		function(value) return value == 0 and L["Off"] or ("%d%%"):format(value) end, 100, ns.RefreshTint), "slider")
	kit.Tooltip(mapDim, L["Darkens and tints the world map in CineMode so it doesn't flash bright."])
	stack:Add(kit.Check(content, "mapDimFollowTint", L["Match the tint"],
		L["Dims the world map only as much as the tint is dark right now."], function(value)
			ns.GetDB().mapDimFollowTint = value
			ns.RefreshTint()
		end), "check")

	-- Crossing a zone border: how the old zone's tint gives way to the new one.
	stack:Header(content, L["At zone borders"])
	local zoneFade = stack:Add(kit.Slider(content, "zoneFadeTime", L["Fade time"], 0.5, 10, 0.5, L["%.1f sec"]),
		"slider")
	kit.Tooltip(zoneFade, L["How long one zone's mood takes to fade out and the next to fade in."])
	local gapFlying = stack:Add(kit.Slider(content, "zoneGapFlying", L["Pause between tints when flying"], 0, 20, 1,
		L["%d sec"]), "slider")
	kit.Tooltip(gapFlying, L["An untinted gap between two zones' moods while you're flying."])
	local gapGround = stack:Add(kit.Slider(content, "zoneGapTime", L["Pause between tints on the ground"], 0, 10, 0.5,
		L["%.1f sec"]), "slider")
	kit.Tooltip(gapGround, L["The same pause when you cross a border on foot or riding."])
end

-- An effect's two tabs (picked: 1 its Show in, 2 Style). title: the page's,
-- put under them.
function ns.EffectTabs(content, title, effect, picked)
	local info = EFFECT_PAGES[effect]
	local panel = ns.PageTabs(content, {
		{ L[info.name], info.page, L[info.tip] },
		{ L["Style"], info.style, L[info.styleTip] },
	}, picked)
	title:ClearAllPoints()
	title:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 8, -14)
end

-- An effect's first tab: its Show in row (effect:<effect>, as the Visual
-- Effects page's rows: off everywhere switches it off).
function ns.CreateEffectPanel(kit, effect)
	local info = EFFECT_PAGES[effect]
	local canvas, content = kit.CreateScrollPage()
	local title = kit.Label(content, "GameFontNormalLarge", L[info.name])
	ns.EffectTabs(content, title, effect, 1)
	local intro = kit.PageIntro(content, title, L[info.intro])
	local switch = kit.PageSwitch(content, effect .. "Page", L["Enable Page"], L[info.switchTip], intro, function()
		ns.letterboxDirty = true
		if ns.RefreshTint then ns.RefreshTint() end
	end)
	local stack = kit.Stack(switch, "check")
	local header = stack:Header(content, L["Show in"])
	-- (A row each: the page's effect, then its extraRows, the Weather page's
	-- screen effects since 2026-11-23: { effect, label } each.)
	local rows = { opts = { quiet = true, cam = true, anyFight = true }, underHeader = true }
	local function Row(fx, label)
		local key, alwaysKey = "effect:" .. fx, fx .. "Always"
		rows[#rows + 1] = { key = key, label = label, alwaysKey = alwaysKey,
			alwaysOn = function() return ns.GetDB()[alwaysKey] end,
			setAlways = function(value) ns.GetDB()[alwaysKey] = value end,
			alwaysTip = L["Shows the whole time in CineMode, including fights and the Calm Timer after them."],
			apply = function()
				local switch = ns.EFFECT_SWITCHES and ns.EFFECT_SWITCHES[fx]
				if switch then ns.GetDB()[switch] = ns.RowOnAnywhere(key, ns.GetDB()[alwaysKey]) end
				ns.letterboxDirty = true
				if ns.RefreshTint then ns.RefreshTint() end
			end }
	end
	Row(effect, L[info.name])
	for _, extra in ipairs(info.extraRows or {}) do Row(extra[1], L[extra[2]]) end
	local lastRow = ns.ShowTable(content, header, rows, L[info.name])
	stack:Continue(lastRow, "label")
	if info.More then
		info.More(kit, content, kit.Stack(lastRow, "label", true))
	end
	canvas:SetScript("OnShow", kit.PageShown(kit.Refresh, content))
	canvas:Hide()
	kit.RegisterSubpage(canvas, info.page)
end

end)

ns.Module("style", function() -- (the Letterbox Style page: only with Style loaded, Modules.lua)
function ns.CreateLetterboxStylePanel(kit)
	local canvas, content = kit.CreateScrollPage()
	local title = kit.Label(content, "GameFontNormalLarge", L["Letterbox"])
	ns.EffectTabs(content, title, "letterbox", 2)
	local intro = kit.PageIntro(content, title,
		L["How the letterbox bars at the top and bottom of the screen look."])

	local preview -- (below: drawn again as each setting changes)
	local function Changed()
		ns.RefreshLetterbox()
		if preview then preview:Refresh() end
	end

	local switch = kit.PageSwitch(content, "letterboxStyle", L["Enable Page"],
		L["When on, the bars look the way this page sets them. When off, they're Cinematic's plain black bars."],
		intro, Changed)
	local stack = kit.Stack(switch, "check")
	local rows = ns.StyleRows(kit, content, stack, Changed, "letterboxStyle")

	-- The preview: a little screen with a lake at dusk, the bars over it as
	-- the real ones are drawn, the screen's own shape. Its Test takes them out
	-- and back in.
	local PREVIEW_W = 480
	preview = CreateFrame("Frame", nil, content)
	preview:SetSize(PREVIEW_W, 270)
	if preview.SetClipsChildren then preview:SetClipsChildren(true) end
	local caption = kit.Label(preview, "GameFontDisableSmall", L["Preview"])
	caption:SetPoint("TOPLEFT", 6, -5)
	caption.searchSkip = true
	local bars = CreateFrame("Frame", nil, preview)
	bars:SetAllPoints()
	bars:SetFrameLevel(preview:GetFrameLevel() + 2)
	ns.MakeLetterboxBars(bars)
	-- (caption above the bars)
	local over = CreateFrame("Frame", nil, preview)
	over:SetAllPoints()
	over:SetFrameLevel(bars:GetFrameLevel() + 1)
	caption:SetParent(over)

	local progress, target = 1, 1
	local comeBack -- (the test's: back in once out)
	local function Draw()
		-- (The screen's shape, which can change with the resolution.)
		local width, height = UIParent:GetWidth(), UIParent:GetHeight()
		local previewH = math.floor(PREVIEW_W * height / math.max(width, 1) + 0.5)
		preview:SetHeight(previewH)
		ns.StyleScene(preview) -- (cut to the screen's shape: StylePages.lua)
		local t = progress * progress * (3 - 2 * progress)
		ns.DrawLetterbox(bars, ns.LetterboxLook(), preview:GetWidth(), previewH, t, previewH / math.max(height, 1))
		bars:SetShown(progress > 0)
	end
	function preview:Refresh()
		Draw()
	end
	ns.SetOnUpdate(preview, function(_, elapsed)
		if progress ~= target then
			progress = ns.Approach(progress, target, elapsed, ns.LetterboxTime(ns.LetterboxLook(), target > progress))
			Draw()
		elseif comeBack and progress == 0 then
			comeBack, target = nil, 1
		end
	end)
	kit.AddControl(preview)

	stack:Add(preview, "label")
	ns.StylePopout(preview, kit.Tooltip) -- (StylePages.lua)
	-- Test: the bars out, then back in once they're gone, as at a fight's start and end.
	ns.StylePreviewTest(over, kit, L["Takes the bars out and brings them back in, like at the start and end of a fight."],
		function()
			target, comeBack = 0, true
		end)


	stack:Header(content, L["Size"])
	rows.Choices(L["Set by:"], "letterboxSizeBy", {
		{ "height", L["Height"], L["Each bar a share of the screen's height."] },
		{ "aspect", L["A film's frame"], L["Shapes the space between the bars like a movie screen, on any monitor."] },
	})
	-- Top bar, a link, Bottom bar (2026-11-24). Linked (the start): the bottom
	-- goes by the top, its number paler, and either box sets both. Unlinked:
	-- each its own, the bottom keeping what it showed.
	do
		local byHeight = function(db) return db.letterboxStyle and db.letterboxSizeBy ~= "aspect" end
		local function Linked()
			local db = ns.GetDB()
			return not db or db.letterboxLinked ~= false
		end
		local line = rows.Boxes()
		local topBox, bottomBox, link
		local function Draw()
			local linked = Linked()
			if topBox then topBox:Refresh() end
			if bottomBox then
				bottomBox:Refresh()
				local c = linked and 0.6 or 1
				bottomBox:SetTextColor(c, c, c)
			end
			if link then
				link.icon:SetVertexColor(linked and 1 or 0.4, linked and 0.82 or 0.4, linked and 0 or 0.4)
			end
		end
		local function BottomShown()
			local db = ns.GetDB()
			return Linked() and db.letterboxSize or db.letterboxSizeBottom or db.letterboxSize
		end
		topBox = line:Box(L["Top bar"], {
			key = "letterboxSize",
			get = function() return ns.GetDB().letterboxSize end,
			set = function(value)
				local db = ns.GetDB()
				db.letterboxSize = value
				if Linked() then db.letterboxSizeBottom = value end
				if bottomBox then bottomBox:Refresh() end
			end,
		}, 0, 25, 1, "%d%%", 100, L["How tall the top bar is, as a share of the screen's height."], byHeight)
		local at = line:Gap(26)
		link = CreateFrame("Button", nil, line)
		link:SetSize(18, 18)
		link:SetPoint("LEFT", line, "LEFT", at - 14, 0)
		link.icon = link:CreateTexture(nil, "ARTWORK")
		link.icon:SetAllPoints()
		local LINK_TEX = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Textures\\Link" -- (Media/make_link.py)
		link.icon:SetTexture(LINK_TEX)
		link:SetHighlightTexture(LINK_TEX, "ADD")
		link.settingKey = "letterboxLinked" -- (/cine find, the Why window's links)
		-- (The page's Reset, profiles: { get, set } boxes record none themselves.)
		for _, key in ipairs({ "letterboxSize", "letterboxSizeBottom", "letterboxLinked" }) do
			kit.RecordKey(content, key)
		end
		link:SetScript("OnClick", function()
			local db = ns.GetDB()
			if db.letterboxLinked ~= false then
				-- (Unlinked: the bottom keeps the height it showed, its own now.)
				db.letterboxSizeBottom = db.letterboxSize
				db.letterboxLinked = false
			else
				-- (Linked again: the bottom takes the top's.)
				db.letterboxLinked = true
				db.letterboxSizeBottom = db.letterboxSize
			end
			Draw()
			Changed()
		end)
		kit.Tooltip(link, L["Click to link or unlink the two bars. Linked, they're the same height."])
		-- (Greyed and unclickable with the boxes: Set by a film's frame, or the
		-- page off. Its own Refresh, as GreyUnless wraps one, and the page's to
		-- refresh it: release review 2026-11-24.)
		link.Refresh = function(self) self.icon:SetAlpha(byHeight(ns.GetDB()) and 1 or 0.35) end
		kit.GreyUnless(link, byHeight)
		kit.AddControl(link)
		bottomBox = line:Box(L["Bottom bar"], {
			key = "letterboxSizeBottom",
			get = BottomShown,
			set = function(value)
				local db = ns.GetDB()
				db.letterboxSizeBottom = value
				if Linked() then db.letterboxSize = value end
				if topBox then topBox:Refresh() end
			end,
		}, 0, 25, 1, "%d%%", 100, L["How tall the bottom bar is, as a share of the screen's height."], byHeight)
		-- (And after the page's Reset, or a profile loaded.)
		local drawer = CreateFrame("Frame", nil, line)
		drawer.Refresh = Draw
		kit.AddControl(drawer)
		-- (/cine debug worldview: the controls, and the values the boxes show.)
		ns.letterboxSizeControls = { top = topBox, bottom = bottomBox, link = link }
		ns.LetterboxSizeShown = function() return ns.GetDB().letterboxSize, BottomShown() end
	end
	rows.Choices(L["Frame:"], "letterboxAspect", {
		{ 2.39, L["2.39:1 (cinema)"] },
		{ 2, L["2:1"] },
		{ 1.85, L["1.85:1"] },
	}, function(db) return db.letterboxStyle and db.letterboxSizeBy == "aspect" end)

	stack:Header(content, L["Look"])
	rows.Swatch(rows.Choices(L["Color:"], "letterboxColor", {
		{ "black", L["Black"] },
		{ "custom", L["Custom"] },
	}), "letterboxColor", { "letterboxR", "letterboxG", "letterboxB" }, L["Pick the bars' color."])
	rows.Slider("letterboxAlpha", L["Opacity"], 10, 100, 5, "%d%%", 100,
		L["How see-through the bars are."])
	rows.Choices(L["Inner edge:"], "letterboxEdge", {
		{ "hard", L["Hard"] },
		{ "soft", L["Soft (feathered)"], L["The bars fade into the scene past their edge."] },
	})
	rows.Slider("letterboxFeather", L["Feather"], 5, 80, 5, "%d", 1,
		L["How far past the bars' edge they fade into the scene."],
		function(db) return db.letterboxStyle and db.letterboxEdge == "soft" end)
	rows.Swatch(rows.Choices(L["Line along the edge:"], "letterboxLine", {
		{ "none", L["None"] },
		{ "gold", L["Gold"] },
		{ "custom", L["Custom"] },
	}), "letterboxLine", { "letterboxLineR", "letterboxLineG", "letterboxLineB" }, L["Pick the line's color."])

	stack:Header(content, L["Coming in and going"])
	rows.Choices(L["How:"], "letterboxMotion", {
		{ "slide", L["Slide in"], L["The bars grow in from the screen's edges."] },
		{ "fade", L["Fade in"], L["The bars fade in at their full height."] },
	})
	rows.Slider("letterboxTime", L["How long"], 0, 30, 1, function(value)
		return value == 0 and L["With the UI"] or ("%.1f s"):format(value / 10)
	end, 10, L["How long the bars take to come in or go. Set to 0 to match the UI's fade."])

	canvas:SetScript("OnShow", kit.PageShown(kit.Refresh, content))
	canvas:Hide()
	kit.RegisterSubpage(canvas, "Letterbox Style", L["Letterbox"])
end

-- The Weather icon's Style tab (2026-11-23): each weather's color and how
-- fast it comes in and goes (Tint.lua's ns.WeatherColor, ns.WeatherBlendTime;
-- off: the built-in ones). A picture at the top: the same scene clear, then
-- in rain, snow and a sandstorm at your strength (50% while it's Off).
function ns.CreateWeatherStylePanel(kit)
	local canvas, content = kit.CreateScrollPage()
	local title = kit.Label(content, "GameFontNormalLarge", L["Weather"])
	ns.EffectTabs(content, title, "weather", 2)
	local intro = kit.PageIntro(content, title,
		L["How the weather tints the scene: a color for each weather, and how fast it comes in and goes."])

	local preview -- (below: drawn again as each setting changes)
	local function Changed()
		ns.RefreshTint()
		if preview then preview:Refresh() end
	end
	local switch = kit.PageSwitch(content, "weatherStyle", L["Enable Page"],
		L["When on, the weather uses the colors and time set here. When off, Cinematic's own."], intro, Changed)
	local stack = kit.Stack(switch, "check")
	local rows = ns.StyleRows(kit, content, stack, Changed, "weatherStyle")

	-- The picture: four panes of one scene (a sky over ground), clear, then
	-- each weather's tint over it as the real one multiplies the world.
	local PREVIEW_W, PREVIEW_H = 480, 110
	preview = CreateFrame("Frame", nil, content)
	preview:SetSize(PREVIEW_W, PREVIEW_H + 18)
	local SKY, GROUND = { 0.78, 0.82, 0.88 }, { 0.36, 0.38, 0.34 }
	local panes = {}
	local kinds = { false }
	for _, each in ipairs(ns.PreviewWeatherTypes()) do kinds[#kinds + 1] = each end
	local paneW = PREVIEW_W / #kinds
	for i, each in ipairs(kinds) do
		local sky = preview:CreateTexture(nil, "BACKGROUND")
		sky:SetColorTexture(1, 1, 1, 1)
		sky:SetPoint("TOPLEFT", (i - 1) * paneW, -18)
		sky:SetSize(paneW - 4, PREVIEW_H * 0.55)
		local ground = preview:CreateTexture(nil, "BACKGROUND")
		ground:SetColorTexture(1, 1, 1, 1)
		ground:SetPoint("TOPLEFT", sky, "BOTTOMLEFT", 0, 0)
		ground:SetSize(paneW - 4, PREVIEW_H * 0.45)
		local name = kit.Label(preview, "GameFontHighlightSmall", each and each[2] or L["Clear"])
		name:SetPoint("BOTTOMLEFT", sky, "TOPLEFT", 2, 4)
		name.searchSkip = true
		panes[i] = { sky = sky, ground = ground, kind = each and each[1] }
	end
	preview.panes = panes -- (for /cine debug atmosphere)
	function preview.Refresh()
		local db = ns.GetDB() or {}
		local strength = db.weatherTintStrength or 0
		if strength <= 0 then strength = 0.5 end
		for _, pane in ipairs(panes) do
			local color = pane.kind and ns.WeatherColor(pane.kind) or { 1, 1, 1 }
			local mix = {}
			for c = 1, 3 do mix[c] = 1 - (1 - color[c]) * strength end
			pane.mix = mix
			local function Shade(base, dim)
				return { base[1] * mix[1] * dim, base[2] * mix[2] * dim, base[3] * mix[3] * dim, 1 }
			end
			ns.TintSetGradient(pane.sky, "VERTICAL", Shade(SKY, 0.85), Shade(SKY, 1))
			ns.TintSetGradient(pane.ground, "VERTICAL", Shade(GROUND, 0.7), Shade(GROUND, 1))
		end
	end
	kit.AddControl(preview)
	stack:Add(preview, "label")
	ns.weatherStylePreview = preview
	preview.Refresh()

	stack:Header(content, L["Colors"])
	for _, each in ipairs(ns.PreviewWeatherTypes()) do
		local name = each[4]
		rows.Color(each[2] .. ":", { "weather" .. name .. "R", "weather" .. name .. "G", "weather" .. name .. "B" },
			L["Pick this weather's tint. White is no change; darker colors darken the scene more."])
	end

	stack:Header(content, L["Coming in and going"])
	rows.Slider("weatherBlendTime", L["How long"], 1, 20, 1, L["%d sec"], 1,
		L["How long the weather's tint takes to come in as it starts, or to go as it clears or you step inside."])

	canvas:SetScript("OnShow", kit.PageShown(kit.Refresh, content))
	canvas:Hide()
	kit.RegisterSubpage(canvas, "Weather Style", L["Weather"])
end
end) -- (ns.Module "style")
