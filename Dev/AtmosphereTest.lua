-- /cine debug atmosphere: the Atmosphere hub's previews and Weather pages
-- (2026-11-23, "is it even on? it didn't seem to change when i adjust the
-- slider"). A test kit test (Dev/TestKit.lua), nothing to do: CineMode off
-- (the kit's), each page open, each preview started as its slider or button
-- does, and what was drawn read back (Tint.lua's ns.tintDrawn). Steps:
--   1 page        Visual Effects: Preview buttons and Style links shown, whole,
--                 nothing over them; no weather rows left there
--   2 weatherpage Weather: its Preview, weather dropdown and view distance's
--   3 stylepage   Weather Style: its picture's three weather panes tinted
--   4 vignette    5% then 50%: drawn at the eased darkness, out of CineMode;
--                 gone again once the preview ends
--   5 weather     rain, snow, sandstorm at Strength Off (50%): each its colour
--   6 inn         the glow as if in an inn, the Tint page switched off
--   7 viewdist    Reduce view distance at 50%: horizonStart pulled in, then back
--   8 haze        the camera haze at 100%: strong enough to see, its frame up
--   9 colors      your rain color and blend time; page off: the built-in ones
--  10 buttons     the vignette's Preview button clicked: Stop while it runs, again stops it
--  11 live        your vignette as you set it, no preview, out of CineMode then in it:
--                 wanted, drawn, its frame and pieces; a preview in CineMode too
--  12 innslider   Glow, in CineMode, its row on Always: the slider at 10% then 40% draws that glow;
--                 Always off, its rule (in an inn): none out of an inn
--  13 hazeslider  Haze, the same: 30% then 80% draws that haze; Always off, its rule (camera): none
--  14 worldwords  the rules' new words (rain, snow, sandstorm, storm, weather, dawn, day, dusk, night,
--                 underwater, fast) against the game's own answers; the editor's World line shown
--  15 weatherfx   the Weather page's frost, rain on the lens, lightning and heavier weather:
--                 textures found, rows and sliders shown, each drawn at its slider's strength
--                 in CineMode with its row on, the game's weatherDensity held and put back
-- Into CinematicDB.atmosphereTestLog. Dev copy only.
local _, ns = ...

local function Near(a, b) return type(a) == "number" and math.abs(a - b) < 0.02 end

local function Drawn() return ns.tintDrawn or {} end

-- Waits (up to seconds) for test() to come true; true if it did.
local function Until(r, seconds, test)
	local left = seconds
	while left > 0 do
		if test() then return true end
		r:Sleep(0.2)
		left = left - 0.2
	end
	return test() and true or false
end

-- A row's rule set for the test (your own kept, put back at the end by the
-- def's putBack, or at the next login after a /reload mid-run).
local function SetRule(r, row, rule)
	ns.db.frameRules = ns.db.frameRules or {}
	r:Keep("rule:" .. row, ns.db.frameRules[row])
	ns.db.frameRules[row] = rule
	r:Log(("  rule %s = %q"):format(row, tostring(rule)))
end

-- CineMode on for a step (the kit keeps it off: left alone meanwhile), and back off.
local function CineOn(r)
	r.def.cineMode = true
	if not (ns.IsCineModeOn and ns.IsCineModeOn()) and Cinematic_ToggleCineMode then pcall(Cinematic_ToggleCineMode) end
	Until(r, 6, function() return ns.lastCinematic end)
	r:Sleep(1)
end
local function CineOff(r)
	if ns.IsCineModeOn and ns.IsCineModeOn() and Cinematic_ToggleCineMode then pcall(Cinematic_ToggleCineMode) end
	r.def.cineMode = nil
end

local function Button(kind)
	for _, button in ipairs(ns.effectPreviewButtons or {}) do
		if button.previewFor == kind and button:IsVisible() then return button end
	end
end

-- A page opened (its id) and what's on it, each { kind } (a Preview
-- button's previewFor) or { name, frame }: shown, its label whole, nothing over it.
local function Page(r, page, label, wanted)
	local ok, err = pcall(ns.OpenOptions, page)
	r:Sleep(1)
	r:Verdict(ok, label .. " opened" .. (ok and "" or (": " .. tostring(err))))
	local panel = _G.SettingsPanel or UIParent
	local shown, clear, cut = 0, 0, 0
	for _, want in ipairs(wanted) do
		local name, control = want[1], want[2] or Button(want[1])
		if control and control:IsVisible() then
			shown = shown + 1
			local text = control.GetFontString and control:GetFontString()
			if text and not ns.noRealLayout and text:IsTruncated() == true then -- (offline: no real text to judge)
				cut = cut + 1
				r:Log(("%s's label is cut short: %q"):format(name, tostring(control:GetText())))
			end
			local hits = r:Overlaps(control, panel)
			if #hits == 0 then clear = clear + 1
			else r:Log(("%s covers: %s"):format(name, table.concat(hits, ", "))) end
		else
			r:Log(name .. ": not shown")
		end
	end
	r:Verdict(shown == #wanted and clear == shown and cut == 0,
		("%s: %d of %d controls shown, %d with nothing over them, %d label(s) cut short"):format(
		label, shown, #wanted, clear, cut))
	r:Shot(label, { behind = panel })
end

ns.TestKit.Define({
	name = "atmosphere",
	key = "atmosphereTest",
	title = "Atmosphere previews test",
	about = "Visual Effects page: each slider's and button's preview drawn out of CineMode, nothing to do",
	settings = { "visualEffects", "vignette", "vignetteStrength", "weatherTint", "weatherTintStrength", "innGlow",
		"innGlowAmount", "tintPage", "rainViewScale", "depthOfField", "dofScale", "styleGeneral", "weatherStyle",
		"weatherRainR", "weatherRainG", "weatherRainB", "weatherBlendTime", "innAlways", "hazeAlways", "weatherPage",
		"frostAlways", "rainlensAlways", "densityAlways", "weatherFrost", "weatherRainLens", "weatherDensityOn",
		"weatherFrostStrength", "weatherRainLensStrength", "weatherLightningStrength", "weatherDensityLevel" },
	cvars = { "horizonStart", "farclip", "weatherDensity" },
	-- (The rows' rules SetRule changed: yours back. "<nil>": the kit's mark for none.)
	putBack = function(extra)
		local n = 0
		for key, rule in pairs(extra) do
			local row = type(key) == "string" and key:match("^rule:(.+)$")
			if row then
				ns.db.frameRules = ns.db.frameRules or {}
				ns.db.frameRules[row] = rule ~= "<nil>" and rule or nil
				n = n + 1
			end
		end
		if ns.RefreshTint then ns.RefreshTint() end
		return n .. " row rule(s) put back"
	end,
	context = function()
		local w = ns.GetWeatherDebug and ns.GetWeatherDebug() or {}
		return ("atmosphere loaded %s, weather here %s (%s), indoors %s, place %s"):format(
			tostring(ns.ModuleLoaded and ns.ModuleLoaded("atmosphere")), tostring(w.kindName or w.kind),
			tostring(w.intensity), tostring(w.indoors), tostring(ns.GetPlaceType and ns.GetPlaceType()))
	end,
	steps = {
		{ key = "page", title = "Visual Effects page opened", seconds = 3, run = function(r)
			if not (ns.PreviewEffect and ns.OpenOptions) then
				return r:Fail("no previews: Atmosphere isn't loaded")
			end
			r:Set("visualEffects", true)
			r:Set("vignette", true)
			r:Set("weatherTint", true)
			r:Set("innGlow", true)
			r:Set("depthOfField", true)
			-- (The weather's row and sliders moved to the Weather icon: none here.)
			local links = {}
			for _, link in ipairs(ns.effectStyleLinks or {}) do
				links[#links + 1] = { link.styleLinkFor, link }
			end
			local wanted = { { "vignette" }, { "inn" }, { "haze" } }
			for _, link in ipairs(links) do wanted[#wanted + 1] = link end
			Page(r, "Effects", "Visual Effects page", wanted)
			r:Verdict(#links == 3, ("%d of 3 Style links (Tint, Letterbox, Weather)"):format(#links))
			-- (None of the weather's buttons on this page: its content holds the vignette's.)
			local here, left = Button("vignette") and Button("vignette"):GetParent(), 0
			for _, button in ipairs(ns.effectPreviewButtons or {}) do
				if (button.previewFor == "weather" or button.previewFor == "viewdist") and button:GetParent() == here then
					left = left + 1
				end
			end
			r:Verdict(here ~= nil and left == 0, ("%d weather or view distance button(s) left here"):format(left))
		end },
		{ key = "weatherpage", title = "Weather page opened", seconds = 3, run = function(r)
			local wanted = { { "weather" } }
			if ns.weatherPreviewPick then wanted[#wanted + 1] = { "weather pick", ns.weatherPreviewPick } end
			if C_Weather and C_Weather.GetCurrentWeather and GetCVar("horizonStart") ~= nil then
				wanted[#wanted + 1] = { "viewdist" }
			end
			Page(r, "Weather", "Weather page", wanted)
			r:Verdict(ns.weatherPreviewPick ~= nil, "the weather to preview is a dropdown")
		end },
		{ key = "stylepage", title = "Weather Style page opened", seconds = 3, run = function(r)
			if not ns.CreateWeatherStylePanel then return r:Skip("Style isn't loaded") end
			Page(r, "Weather Style", "Weather Style page", { { "picture", ns.weatherStylePreview } })
			local panes = ns.weatherStylePreview and ns.weatherStylePreview.panes or {}
			local tinted = 0
			for _, pane in ipairs(panes) do
				if pane.kind and pane.mix and (pane.mix[1] < 0.99 or pane.mix[2] < 0.99 or pane.mix[3] < 0.99) then
					tinted = tinted + 1
				end
			end
			r:Verdict(#panes == 4 and tinted == 3, ("picture: %d panes, %d weather panes tinted"):format(#panes, tinted))
		end },
		{ key = "vignette", title = "vignette preview, out of CineMode", seconds = 10, run = function(r)
			r:Verdict(not (ns.IsCineModeOn and ns.IsCineModeOn()), "CineMode off")
			for _, strength in ipairs({ 0.05, 0.5 }) do
				r:Set("vignetteStrength", strength)
				ns.RefreshTint()
				ns.PreviewEffect("vignette")
				local want = ns.VignetteAlpha(strength)
				local seen = Until(r, 2, function() return Near(Drawn().vignette, want) end)
				r:Verdict(seen and _G.CinematicTint and _G.CinematicTint:IsShown(), ("%d%%: drawn %s, wanted %.2f"):format(
					strength * 100, tostring(Drawn().vignette), want))
				r:Shot(("vignette %d%%"):format(strength * 100))
			end
			local gone = Until(r, ns.EFFECT_PREVIEW_SECONDS + (ns.FadeOutTime() or 1) + 3,
				function() return (Drawn().vignette or 0) == 0 end)
			r:Verdict(gone, "gone again after the preview (out of CineMode): " .. tostring(Drawn().vignette))
		end },
		{ key = "weather", title = "weather previews", seconds = 12, run = function(r)
			r:Set("weatherTintStrength", 0)
			for _, each in ipairs(ns.PreviewWeatherTypes()) do
				local kind, label, color = each[1], each[2], each[3]
				ns.PreviewEffect("weather", 4, kind)
				local want = { 1 - (1 - color[1]) * 0.5, 1 - (1 - color[2]) * 0.5, 1 - (1 - color[3]) * 0.5 }
				local seen = Until(r, 2, function()
					local d = Drawn()
					return Near(d.wr, want[1]) and Near(d.wg, want[2]) and Near(d.wb, want[3])
				end)
				local d = Drawn()
				r:Verdict(seen, ("%s: drawn %s %s %s, wanted %.2f %.2f %.2f"):format(label, tostring(d.wr), tostring(d.wg),
					tostring(d.wb), want[1], want[2], want[3]))
				r:Shot("weather " .. label)
			end
			ns.StopEffectPreview()
		end },
		{ key = "inn", title = "inn glow preview, Tint page off", seconds = 6, run = function(r)
			r:Set("innGlowAmount", 0.1)
			r:Set("tintPage", false)
			ns.RefreshTint()
			ns.PreviewEffect("inn", 4)
			local seen = Until(r, 2, function() return Near(Drawn().glow, 0.1) end)
			r:Verdict(seen, ("glow drawn %s, wanted 0.10 (the tint's own level %s)"):format(tostring(Drawn().glow),
				tostring(Drawn().level)))
			r:Shot("inn glow")
			ns.StopEffectPreview()
		end },
		{ key = "viewdist", title = "view distance preview", seconds = 8, run = function(r)
			if not ns.PreviewRainView or GetCVar("horizonStart") == nil then
				return r:Skip("no view distance setting on this client")
			end
			r:Set("rainViewScale", 0.5)
			local before = tonumber(GetCVar("horizonStart"))
			ns.PreviewRainView(3)
			local during = tonumber(GetCVar("horizonStart"))
			r:Verdict(before and during and (during < before or before <= 400),
				("horizonStart %s before, %s previewing"):format(tostring(before), tostring(during)))
			local back = Until(r, 6, function() return tonumber(GetCVar("horizonStart")) == before end)
			r:Verdict(back, "back to " .. tostring(before) .. ": " .. tostring(GetCVar("horizonStart")))
		end },
		{ key = "haze", title = "haze preview: one strength, a pale mist you can see", seconds = 5, run = function(r)
			-- (One Haze strength, 0-100% in 1% steps, 0 to start with, since
			-- 2026-11-23: "haze seems to be doing nothing", "increments of 1%",
			-- "default should be 0". And a pale mist, not mid-grey: the screen's
			-- edge measured brighter with it than without.)
			r:Verdict(ns.DEFAULTS.dofScale == 0, "Haze strength 0 to start with: " .. tostring(ns.DEFAULTS.dofScale))
			ns.OpenOptions("Effects")
			r:Sleep(0.3)
			local slider = ns.effectSliders and ns.effectSliders.haze
			local step = slider and slider.GetValueStep and slider:GetValueStep()
			r:Verdict(ns.noRealLayout or step == 1, "Haze strength moves in 1% steps: " .. tostring(step))
			-- (Its file found: a path naming "Cinematic" found nothing in the dev
			-- copy's CinematicDev folder, and the haze drew nothing at any strength
			-- while its alpha read right, 2026-11-23.)
			r:Verdict(ns.noRealLayout or ns.focusTextureLoaded == true,
				"the haze's texture loaded: " .. tostring(ns.focusTextureLoaded))
			local function Edge()
				local frame = _G.CinematicFocus
				return frame and frame:IsShown() and ns.FocusAlphaNow() or 0
			end
			ns.FocusDemo()
			r:Sleep(1)
			r:Shot("no haze")
			r:Set("dofScale", 0.6)
			ns.FocusPreview(0.6)
			r:Sleep(0.4)
			-- (Offline its loop doesn't tick: only the preview's start judged there.)
			r:Verdict(ns.FocusDemoRunning() and (ns.noRealLayout or Near(Edge(), 0.6)),
				("previewing 60%%: haze drawn %.3f"):format(Edge()))
			r:Shot("haze 60%")
			ns.FocusDemo() -- (stops it)
		end },
		{ key = "colors", title = "Weather Style colors and blend time", seconds = 4, run = function(r)
			if not ns.CreateWeatherStylePanel then return r:Skip("Style isn't loaded") end
			r:Set("styleGeneral", true)
			r:Set("weatherStyle", true)
			r:Set("weatherTintStrength", 1)
			r:Set("weatherRainR", 0.3)
			r:Set("weatherRainG", 0.5)
			r:Set("weatherRainB", 1)
			r:Set("weatherBlendTime", 2)
			ns.PreviewEffect("weather", 3, ns.WeatherTypeOf("Rain"))
			local seen = Until(r, 2, function() local d = Drawn() return Near(d.wr, 0.3) and Near(d.wg, 0.5) end)
			r:Verdict(seen, ("your rain color drawn: %s %s %s, wanted 0.30 0.50 1.00"):format(tostring(Drawn().wr),
				tostring(Drawn().wg), tostring(Drawn().wb)))
			r:Verdict(ns.WeatherBlendTime() == 2, "blend time yours: " .. tostring(ns.WeatherBlendTime()))
			r:Set("weatherStyle", false)
			ns.RefreshTint()
			local builtIn = Until(r, 2, function() return Near(Drawn().wr, 0.62) end)
			r:Verdict(builtIn and ns.WeatherBlendTime() == 8, ("page off: the built-in rain %s, blend %s"):format(
				tostring(Drawn().wr), tostring(ns.WeatherBlendTime())))
			ns.StopEffectPreview()
		end },
		{ key = "buttons", title = "Preview button turns into Stop", seconds = 4, run = function(r)
			r:Set("vignetteStrength", 0.3)
			local button = Button("vignette")
			if not button then return r:Fail("no vignette Preview button shown") end
			local text = button:GetText()
			button:Click()
			r:Sleep(0.3)
			r:Verdict(ns.EffectPreviewing("vignette") and button:GetText() == ns.L["Stop"],
				("clicked: previewing %s, says %q"):format(tostring(ns.EffectPreviewing("vignette")), tostring(button:GetText())))
			button:Click()
			r:Sleep(0.3)
			r:Verdict(not ns.EffectPreviewing("vignette") and button:GetText() == text,
				("again: previewing %s, says %q"):format(tostring(ns.EffectPreviewing("vignette")), tostring(button:GetText())))
		end },
		-- (The user, 2026-11-23: "i have it on always. yet its not showing",
		-- at 90% in CineMode, nothing at the corners; out of CineMode the
		-- preview's screenshots were dark at the edges. Your own settings, no
		-- preview, out of CineMode and then in it, everything between the
		-- setting and the screen read back each time.)
		{ key = "live", title = "your vignette as set, out of CineMode then in it", seconds = 16, run = function(r)
			ns.StopEffectPreview()
			local db = ns.db
			local function Probe(label)
				local frame = _G.CinematicTint
				local wanted = ns.effectWanted and ns.effectWanted.vignette
				local drawn = Drawn().vignette
				r:Log(("%s: CineMode %s (lastCinematic %s), wanted %s, row now %s, drawn %s (wanted %.2f)"):format(label,
					tostring(ns.IsCineModeOn and ns.IsCineModeOn()), tostring(ns.lastCinematic), tostring(wanted),
					tostring(ns.RowOnNow and ns.RowOnNow("effect:vignette", db.vignetteAlways, true)), tostring(drawn),
					ns.VignetteAlpha(db.vignetteStrength)))
				r:Log(("%s: frame shown %s, visible %s, alpha %s, effective %s, strata %s level %s, parent %s, scale %s, "
					.. "size %.0fx%.0f"):format(label, tostring(frame and frame:IsShown()), tostring(frame and frame:IsVisible()),
					tostring(frame and frame:GetAlpha()), tostring(frame and frame:GetEffectiveAlpha()),
					tostring(frame and frame:GetFrameStrata()), tostring(frame and frame:GetFrameLevel()),
					tostring(frame and frame:GetParent() and (frame:GetParent():GetName() or "unnamed")),
					tostring(frame and frame:GetEffectiveScale()), frame and frame:GetWidth() or 0, frame and frame:GetHeight() or 0))
				local pieces = {}
				-- (Every region of the tint frame shown with some alpha: the game gives
				-- a texture's file as a number, so it can't be told by name.)
				for _, region in ipairs(frame and { frame:GetRegions() } or {}) do
					-- ("x and f()" keeps f's first value only: the alpha is its fourth.)
					local a = 0
					if region.GetVertexColor then a = select(4, region:GetVertexColor()) or 0 end
					if region:IsShown() and a > 0 then
						pieces[#pieces + 1] = ("%.0fx%.0f a%.2f vis %s alpha %s"):format(region:GetWidth() or 0,
							region:GetHeight() or 0, a or 0, tostring(region:IsVisible()), tostring(region:GetAlpha()))
					end
				end
				r:Log(("%s: pieces shown with alpha %d: %s"):format(label, #pieces, table.concat(pieces, "; ")))
				local bars = _G.CinematicLetterbox
				r:Log(("%s: letterbox shown %s, strata %s level %s, parent %s"):format(label, tostring(bars and bars:IsShown()),
					tostring(bars and bars:GetFrameStrata()), tostring(bars and bars:GetFrameLevel()),
					tostring(bars and bars:GetParent() and (bars:GetParent():GetName() or "unnamed"))))
				return wanted, drawn, frame and frame:IsVisible(), #pieces
			end
			r:Log(("off once for everyone (vignetteOffV1): %s"):format(tostring(db.vignetteOffV1)))
			r:Log(("settings: visualEffects %s, vignette %s, vignetteAlways %s, vignetteStrength %s, outsideCineVignette %s"):format(
				tostring(db.visualEffects), tostring(db.vignette), tostring(db.vignetteAlways), tostring(db.vignetteStrength),
				tostring(db.outsideCineVignette)))
			local should = db.visualEffects and db.vignette and (db.vignetteStrength or 0) > 0
			local want = ns.VignetteAlpha(db.vignetteStrength)
			r:Sleep(3)
			local wanted, drawn, visible, pieces = Probe("out of CineMode")
			if db.outsideCineVignette then
				r:Verdict(should and (wanted and Near(drawn, want) and visible and pieces >= 8) or (not should and (drawn or 0) == 0),
					("out of CineMode: wanted %s, drawn %s, visible %s, %d pieces"):format(tostring(wanted), tostring(drawn),
					tostring(visible), pieces))
			end
			r:Shot("your vignette, out of CineMode")
			-- In CineMode (the kit keeps it off: left alone for this step).
			r.def.cineMode = true
			if not (ns.IsCineModeOn and ns.IsCineModeOn()) and Cinematic_ToggleCineMode then pcall(Cinematic_ToggleCineMode) end
			Until(r, 6, function() return ns.lastCinematic end)
			r:Sleep(3)
			wanted, drawn, visible, pieces = Probe("in CineMode")
			r:Verdict(should and (wanted and Near(drawn, want) and visible and pieces >= 8) or (not should and (drawn or 0) == 0),
				("in CineMode: wanted %s, drawn %s, visible %s, %d pieces"):format(tostring(wanted), tostring(drawn),
				tostring(visible), pieces))
			r:Shot("your vignette, in CineMode")
			ns.PreviewEffect("vignette", 3)
			r:Sleep(0.5)
			Probe("in CineMode, previewing")
			r:Shot("vignette preview, in CineMode")
			ns.StopEffectPreview()
			if ns.IsCineModeOn and ns.IsCineModeOn() and Cinematic_ToggleCineMode then pcall(Cinematic_ToggleCineMode) end
			r.def.cineMode = nil
		end },
		-- (The user, 2026-11-23: "the inn glow and camera haze effects also need
		-- to be tested to make sure the slider works", and each got a Show in
		-- row. Then (the user: "just call it glow and make the default show in
		-- only in Inns, same thing with camera haze") Glow and Haze, their rows
		-- starting from rules: in an inn, the camera modes. In CineMode, no
		-- preview, nothing faked: the row's Always on, each slider moved as a
		-- drag moves it, drawn where you stand; Always off, the row's own rule:
		-- gone, out of an inn and a camera mode.)
		{ key = "innslider", title = "Glow slider and row, in CineMode", seconds = 20, run = function(r)
			r:Set("visualEffects", true)
			r:Set("innGlow", true)
			local rule = ns.db.frameRules and ns.db.frameRules["effect:inn"]
			r:Log(("Glow's rule: %q (to start with %q); here: %s, indoors %s"):format(tostring(rule),
				tostring(ns.RULE_DEFAULTS["effect:inn"]), tostring(ns.GetPlaceType()), tostring(IsIndoors())))
			-- (A rule decides over the row's ticks: cleared, as a player would, for
			-- Always to show it everywhere; put back after, putBack below.)
			SetRule(r, "effect:inn", "")
			r:Set("innAlways", true)
			CineOn(r)
			ns.OpenOptions("Effects")
			r:Sleep(0.5)
			local slider = ns.effectSliders and ns.effectSliders.inn
			if not slider then return r:Fail("no Glow slider") end
			for _, value in ipairs({ 10, 40 }) do
				slider:SetValue(value) -- (as a drag: its preview starts, then ends here)
				ns.StopEffectPreview()
				local seen = Until(r, 6, function() return Near(Drawn().glow, value / 100) end)
				r:Verdict(seen, ("Always, slider at %d%%: glow drawn %s, wanted %.2f (row wanted %s)"):format(value,
					tostring(Drawn().glow), value / 100, tostring(ns.effectWanted and ns.effectWanted.inn)))
				r:Shot(("glow %d%%"):format(value))
			end
			r:Set("innAlways", false)
			SetRule(r, "effect:inn", ns.RULE_DEFAULTS["effect:inn"])
			ns.RefreshTint()
			local inInn = ns.GetPlaceType() == "inn" and IsIndoors()
			local gone = Until(r, 6, function() return (Drawn().glow or 0) == 0 end)
			r:Verdict(inInn or (gone and ns.effectWanted.inn == false),
				("Always off, its rule out of an inn: glow drawn %s, row wanted %s%s"):format(tostring(Drawn().glow),
				tostring(ns.effectWanted.inn), inInn and " (you're in an inn: not judged)" or ""))
			CineOff(r)
		end },
		{ key = "hazeslider", title = "Haze slider and row, in CineMode", seconds = 20, run = function(r)
			r:Set("visualEffects", true)
			r:Set("depthOfField", true)
			r:Log(("Haze's rule: %q (to start with %q); camera mode now %s"):format(
				tostring(ns.db.frameRules and ns.db.frameRules["effect:haze"]), tostring(ns.RULE_DEFAULTS["effect:haze"]),
				tostring(ns.CameraMode())))
			SetRule(r, "effect:haze", "")
			r:Set("hazeAlways", true)
			CineOn(r)
			ns.OpenOptions("Effects")
			r:Sleep(0.5)
			local slider = ns.effectSliders and ns.effectSliders.haze
			if not slider then return r:Fail("no Haze slider") end
			for _, value in ipairs({ 30, 80 }) do
				slider:SetValue(value) -- (as a drag: its 3 second preview, then the row's own)
				local want = value / 100 -- (one strength everywhere since 2026-11-23)
				r:Sleep(3.5)
				local seen = Until(r, 4, function() return Near(ns.FocusAlphaNow(), want) end)
				r:Verdict(seen and not ns.FocusDemoRunning(), ("Always, slider at %d%%: haze drawn %.3f, wanted %.3f (camera mode %s, row wanted %s)"):format(
					value, ns.FocusAlphaNow(), want, tostring(ns.CameraMode()), tostring(ns.effectWanted and ns.effectWanted.haze)))
				r:Shot(("haze %d%%"):format(value))
			end
			r:Set("hazeAlways", false)
			SetRule(r, "effect:haze", ns.RULE_DEFAULTS["effect:haze"])
			local gone = Until(r, 4, function() return ns.FocusAlphaNow() == 0 end)
			r:Verdict(gone and ns.effectWanted.haze == false, ("Always off, its rule out of a camera mode: haze drawn %.3f, row wanted %s"):format(
				ns.FocusAlphaNow(), tostring(ns.effectWanted.haze)))
			CineOff(r)
		end },
		-- (The rules' world words, 2026-11-23: each as the rules read it now
		-- against the game's own answers, nothing to do; then the rule editor
		-- opened on the Haze row (its rule kept: Close saves nothing here), the
		-- World and Travel lines' buttons there, inside it, none on another.)
		{ key = "worldwords", title = "world words: weather, time, under water, fast", seconds = 5, run = function(r)
			local f = ns.RuleFacts(false)
			local raw = C_Weather and C_Weather.GetCurrentWeather and C_Weather.GetCurrentWeather()
			local hour, minute = ns.TintParts.GetClockTime()
			local speed = ns.PlayerSpeedNow()
			r:Log(("game: weather type %s, intensity %s, indoors %s, submerged %s, speed %.1f, clock %s:%02d (%s)"):format(
				tostring(raw and raw.type), tostring(raw and raw.intensity), tostring(IsIndoors()), tostring(IsSubmerged()),
				speed, tostring(hour), tonumber(minute) or 0, tostring(ns.db.tintClock or "game")))
			local words = {}
			for _, word in ipairs({ "rain", "snow", "sandstorm", "storm", "weather", "dawn", "day", "dusk", "night",
				"underwater", "fast" }) do
				words[#words + 1] = word .. "=" .. tostring(f[word])
			end
			r:Log("words: " .. table.concat(words, " "))
			local kind, intensity = ns.WeatherNow()
			local time = ns.TimeOfDayWord()
			local ok = f.rain == (kind == "rain") and f.snow == (kind == "snow") and f.sandstorm == (kind == "sandstorm")
				and f.weather == (kind ~= nil) and f.storm == ((kind == "rain" or kind == "snow") and intensity >= 0.6)
				and f[time] == true and f.underwater == (IsSubmerged() and true or false)
				and f.fast == (not f.taxi and speed >= 12)
			local times = (f.dawn and 1 or 0) + (f.day and 1 or 0) + (f.dusk and 1 or 0) + (f.night and 1 or 0)
			r:Verdict(ok and times == 1, ("the words match the game's answers (weather %s, time %s)"):format(
				tostring(kind), tostring(time)))
			-- The editor: opened on the Haze row with a stand-in that saves nothing.
			ns.OpenOptions("Effects")
			r:Sleep(0.5)
			local rule = ns.db.frameRules and ns.db.frameRules["effect:haze"] or ""
			-- (A stand-in row: what the editor asks of one, each doing nothing.
			-- Without SetText, typing focus calling it raised an error, run 1.)
			ns.OpenRuleEditor({ key = "effect:haze", label = ns.L["Haze"], Text = function() return rule end,
				SetText = function() end, ResetToGrid = function() end, Close = function() end })
			r:Sleep(0.6)
			local editor = _G.CinematicRuleEditor
			if not editor or not editor:IsShown() then return r:Fail("the rule editor didn't open") end
			local byLabel, lines = {}, {}
			for _, group in ipairs(ns.RulePieces()) do
				if group[1] == ns.L["World"] or group[1] == ns.L["Travel"] then
					for _, piece in ipairs(group[3]) do
						byLabel[piece[2]] = piece[1]
						lines[#lines + 1] = piece[1]
					end
				end
			end
			local found = {}
			local function Walk(frame, depth)
				if depth > 6 then return end
				for _, child in ipairs({ frame:GetChildren() }) do
					if child.dot and child.GetText then
						local text = tostring(child:GetText() or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
						if byLabel[text] and child:IsVisible() then found[byLabel[text]] = child end
					end
					Walk(child, depth + 1)
				end
			end
			Walk(editor, 0)
			local missing, cut, covered = {}, 0, 0
			for _, word in ipairs(lines) do
				local button = found[word]
				if not button then
					missing[#missing + 1] = word
				else
					local text = button.GetFontString and button:GetFontString()
					if text and not ns.noRealLayout and text:IsTruncated() == true then cut = cut + 1 end
					local hits = r:Overlaps(button, editor)
					if #hits > 0 then
						covered = covered + 1
						r:Log(word .. " covers: " .. table.concat(hits, ", "))
					end
				end
			end
			r:Verdict(#missing == 0 and cut == 0 and covered == 0,
				("editor's World and Travel lines: %d of %d buttons, %d cut short, %d with something over them%s"):format(
				#lines - #missing, #lines, cut, covered, #missing > 0 and (" (missing " .. table.concat(missing, ", ") .. ")") or ""))
			r:Shot("rule editor: World line", { behind = editor })
			editor:Hide()
		end },
		-- (The Weather page's screen effects, 2026-11-23, WeatherFX.lua: their
		-- textures found, the page's new rows and sliders shown whole; then in
		-- CineMode each row's rule cleared and Always on, as a player would to
		-- have it now, its slider moved as a drag does: frost and rain drawn at
		-- that strength, lightning flashing (with thunder, if one is known),
		-- the game's weatherDensity held at its level, and put back after.)
		{ key = "weatherfx", title = "Weather page: frost, rain on the lens, lightning, heavier weather", seconds = 30,
			run = function(r)
			-- (First: none of it on screen with every strength 0, as after a
			-- /reload or a reset: textures left shown as made covered the screen,
			-- the user 2026-11-23, Reset Settings didn't clear them.)
			local on = {}
			for name, tex in pairs(ns.weatherFxTextures or {}) do
				if tex:IsShown() and (tex:GetAlpha() or 0) > 0 then on[#on + 1] = name end
			end
			local db0 = ns.db
			local zero = (db0.weatherFrostStrength or 0) == 0 and (db0.weatherRainLensStrength or 0) == 0
				and (db0.weatherLightningStrength or 0) == 0
			if zero then
				r:Verdict(#on == 0, ("strengths 0: nothing of it on screen (%s)"):format(#on == 0 and "none" or table.concat(on, ", ")))
				r:Shot("no weather effects")
			else
				r:Log(("strengths set (yours): on screen %s"):format(#on == 0 and "none" or table.concat(on, ", ")))
			end
			local loaded = ns.weatherFxLoaded or {}
			r:Verdict(ns.noRealLayout or (loaded.frost == true and loaded.drops == true and loaded.streaks == true),
				("textures found: frost %s, drops %s, trails %s"):format(tostring(loaded.frost), tostring(loaded.drops),
				tostring(loaded.streaks)))
			r:Set("visualEffects", true)
			r:Set("weatherPage", true)
			local wanted = {}
			ns.OpenOptions("Weather")
			r:Sleep(0.8)
			for _, fx in ipairs({ "frost", "rainlens", "lightning", "density" }) do
				local slider = ns.weatherFxSliders and ns.weatherFxSliders[fx]
				if slider then wanted[#wanted + 1] = { fx .. " slider", slider } end
				if fx ~= "density" then wanted[#wanted + 1] = { fx } end
			end
			Page(r, "Weather", "Weather page", wanted)
			CineOn(r)
			local drawn = ns.weatherFxDrawn or {}
			for _, fx in ipairs({ { "frost", "weatherFrost", 0.6 }, { "rainlens", "weatherRainLens", 0.5 } }) do
				SetRule(r, "effect:" .. fx[1], "")
				r:Set(fx[1] .. "Always", true)
				r:Set(fx[2], true)
				local slider = ns.weatherFxSliders and ns.weatherFxSliders[fx[1]]
				-- (As a drag: its 3 second preview first. From 0, so it's a change:
				-- left at 60 by run 1, setting 60 again did nothing, run 2.)
				if slider then
					slider:SetValue(0)
					slider:SetValue(fx[3] * 100)
				end
				r:Sleep(4)
				local value = fx[1] == "frost" and drawn.frost or drawn.streaks / 0.45
				r:Verdict(Near(value, fx[3]), ("%s at %d%%: drawn %.2f (row wanted %s)"):format(fx[1], fx[3] * 100,
					value or -1, tostring(ns.effectWanted and ns.effectWanted[fx[1]])))
				r:Shot(fx[1] .. " " .. fx[3] * 100 .. "%")
				r:Set(fx[1] .. "Always", false)
				SetRule(r, "effect:" .. fx[1], ns.RULE_DEFAULTS["effect:" .. fx[1]])
				r:Set(fx[1] == "frost" and "weatherFrostStrength" or "weatherRainLensStrength", 0)
				r:Sleep(fx[1] == "frost" and 5.5 or 5.5)
			end
			-- Lightning: its preview flashes every few seconds.
			r:Set("weatherLightningStrength", 0.8)
			local before = ns.lightningFlashes or 0
			ns.WeatherFxPreview("lightning", 6)
			local brightest = 0
			for _ = 1, 30 do
				r:Sleep(0.2)
				brightest = math.max(brightest, drawn.flash or 0)
			end
			local thunder = ns.thunderPlayed
			r:Verdict((ns.lightningFlashes or 0) - before >= 2 and brightest > 0.3,
				("lightning: %d flashes in 6 seconds, brightest %.2f; thunder %s"):format((ns.lightningFlashes or 0) - before,
				brightest, thunder and ("file " .. tostring(thunder.file) .. ", played " .. tostring(thunder.willPlay)) or "none known"))
			r:Set("weatherLightningStrength", 0)
			-- Heavier weather: the game's density held at its level, put back after.
			local own = GetCVar("weatherDensity")
			SetRule(r, "effect:density", "")
			r:Set("densityAlways", true)
			r:Set("weatherDensityOn", true)
			r:Set("weatherDensityLevel", own == "1" and 3 or 1)
			r:Sleep(2.5)
			local held = GetCVar("weatherDensity")
			r:Set("densityAlways", false)
			SetRule(r, "effect:density", ns.RULE_DEFAULTS["effect:density"])
			r:Set("weatherDensityLevel", 0)
			r:Sleep(2.5)
			local back = GetCVar("weatherDensity")
			r:Verdict(held == tostring(own == "1" and 3 or 1) and back == own,
				("heavier weather: yours %s, held %s, back to %s"):format(tostring(own), tostring(held), tostring(back)))
			CineOff(r)
		end },
	},
})
