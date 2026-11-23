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
		"weatherRainR", "weatherRainG", "weatherRainB", "weatherBlendTime" },
	cvars = { "horizonStart", "farclip" },
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
		{ key = "haze", title = "camera haze preview", seconds = 4, run = function(r)
			r:Set("dofScale", 1)
			local strength = ns.FocusScaledStrength(1)
			-- (15% by default since 2026-11-23: at 2.5% even 200% showed nothing.)
			r:Verdict(strength >= 0.1, ("the camera modes' strongest haze at 100%%: %.3f (15%% by default)"):format(strength))
			ns.FocusPreview(strength)
			r:Sleep(0.3)
			local frame = _G.CinematicFocus
			r:Verdict(ns.FocusDemoRunning() and frame and frame:IsShown(), "haze frame up while previewing")
			r:Shot("camera haze")
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
	},
})
