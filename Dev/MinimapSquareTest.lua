-- /cine debug minimapsquare: the Style hub's Minimap page (Style/MinimapStyle.lua,
-- 2026-11-23): the square minimap a player asked for (Discord, 2026-11-19),
-- with a border, and the round ring's rows moved off Interface Recolor.
-- A test kit test (Dev/TestKit.lua), NOTHING to do. Steps:
--   1 page    the Minimap page open (Options at Minimap Style): its Square
--             minimap row there, nothing over it; then the page off: its off
--             card; a screenshot of each
--   2 square  Square minimap on: GetMinimapShape says SQUARE, the mask set
--             without an error, the game's round ring hidden, the border up
--             (PASS/FAIL); a screenshot of the minimap
--   3 border  the border at 6, then off: a screenshot of each
--   4 faded   the minimap's hidden-blip mask (NodeSweep.lua, as when it's
--             faded in CineMode) on and back: still square; a screenshot
--   5 colors  the border in each color (theme, black, white, gold, class)
--   6 buttons the buttons' rings colored, even on a theme with no ring color
--   7 size    the minimap at 150%, then back
--   8 hide    zoom buttons, zone bar and dial hidden, then back
--   9 inside  zone name and clock inside the square, still there 3 s on
--  10 round   Square minimap off: shape and ring back, the game's round mask
--             set (PASS/FAIL); a screenshot
-- Every setting it touches and CineMode put back at the end (the kit's undo).
-- Into CinematicDB.minimapSquareTestLog. Dev copy only.
local _, ns = ...

local function FindText(root, words)
	local function Walk(frame, depth)
		if depth > 30 then return nil end
		for _, region in ipairs({ frame:GetRegions() }) do
			if region.GetText then
				local text = region:GetText()
				if type(text) == "string" and not (issecretvalue and issecretvalue(text)) and text == words
					and region:IsVisible() then
					return region
				end
			end
		end
		for _, child in ipairs({ frame:GetChildren() }) do
			local hit = Walk(child, depth + 1)
			if hit then return hit end
		end
	end
	return Walk(root, 0)
end

local function Shape()
	return type(_G.GetMinimapShape) == "function" and tostring(_G.GetMinimapShape()) or "none"
end
local function RingAlpha()
	local ring = _G.MinimapCompassTexture or _G.MinimapBorder
	return ring and ring:GetAlpha() or -1
end
local function State(r, label)
	local on, maskOk, edges = ns.MinimapSquareState()
	r:Log(("%s: square %s, mask set %s, border %s, shape %s, ring alpha %s, minimap %sx%s shown %s"):format(label,
		tostring(on), tostring(maskOk), tostring(edges), Shape(), tostring(RingAlpha()),
		tostring(Minimap:GetWidth()), tostring(Minimap:GetHeight()), tostring(Minimap:IsVisible())))
	return on, maskOk, edges
end
local function Apply()
	ns.RefreshMinimapStyle()
end
local function CloseOptions()
	if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
end
local function MapShot(r, label)
	CloseOptions()
	r:Shot(label)
end

ns.TestKit.Define({
	name = "minimapsquare",
	key = "minimapSquareTest",
	title = "Square minimap (Style > Minimap)",
	about = "the Minimap page, then the square minimap on, its border, faded and back, round again; nothing to do",
	settings = { "styleGeneral", "minimapStyle", "mmSquare", "mmSquareBorderSize", "mmBorderColor",
		"mmHeaderInside", "mmScale", "mmHideZoom", "mmHideZoneBar", "mmHideDial", "mmButtons" },
	context = function()
		local db = ns.db
		return ("styleGeneral %s, minimapStyle %s, mmSquare %s, border %s size %s, shape %s, other minimap addons: %s"):format(
			tostring(db.styleGeneral), tostring(db.minimapStyle), tostring(db.mmSquare), tostring(db.mmSquareBorder),
			tostring(db.mmSquareBorderSize), Shape(), tostring(ns.ConflictState and select(2, ns.ConflictState("style:minimap"))))
	end,
	putBack = function() Apply() end,
	steps = {
		{ key = "page", title = "the Minimap page: its rows, then off", run = function(r)
			r:Set("styleGeneral", true)
			r:Set("minimapStyle", true)
			r:Set("mmSquare", false)
			Apply()
			ns.OpenOptions("Minimap Style")
			r:Sleep(0.8)
			local panel = SettingsPanel or UIParent
			local label = FindText(panel, ns.L["Square minimap"])
			if not label then
				r:Shot("Minimap page, no Square minimap row", { behind = panel })
				return r:Fail("no \"Square minimap\" row on the Minimap page")
			end
			r:Pass("Square minimap row on the page")
			r:Verdict(FindText(panel, ns.L["Color the buttons' rings"]) ~= nil, "the ring's rows on it too")
			local ringed = ns.ThemeRing() ~= nil
			r:Verdict((FindText(panel, ns.L["Shade inside the edge"]) ~= nil) == ringed,
				"Shade shown only on a theme with a ring color (this one: " .. tostring(ringed) .. ")")
			local dial = FindText(panel, ns.L["Day and night dial"]) or FindText(panel, ns.L["Zone bar"])
			if dial then
				local over = r:Overlaps(dial:GetParent(), panel)
				r:Verdict(#over == 0, "the Hide line: nothing over its last box")
			end
			local hits = r:Overlaps(label:GetParent(), panel)
			r:Verdict(#hits == 0, "nothing over its row")
			r:Shot("Minimap page on", { behind = panel })
			r:Set("minimapStyle", false)
			if ns.RefreshOptions then ns.RefreshOptions() end
			r:Sleep(0.5)
			r:Shot("Minimap page off: its off card", { behind = panel })
			r:Set("minimapStyle", true)
			if ns.RefreshOptions then ns.RefreshOptions() end
			CloseOptions()
		end },
		{ key = "square", title = "Square minimap on", run = function(r)
			if ns.isRetail then return r:Skip("retail: the row is hidden there") end
			r:Set("mmSquareBorderSize", 2)
			r:Set("mmSquare", true)
			Apply()
			local on, maskOk, edges = State(r, "square")
			r:Verdict(on == true and Shape() == "SQUARE", "square on, GetMinimapShape SQUARE")
			r:Verdict(maskOk == true, "SetMaskTexture took the square mask")
			r:Verdict(RingAlpha() == 0, "the game's round ring hidden")
			r:Verdict(edges == true, "border up")
			MapShot(r, "square minimap, border 2")
		end },
		{ key = "border", title = "the border at 6, then off", run = function(r)
			if ns.isRetail then return r:Skip("retail") end
			r:Set("mmSquareBorderSize", 6)
			Apply()
			MapShot(r, "square minimap, border 6")
			r:Set("mmSquareBorderSize", 0)
			Apply()
			local _, _, edges = State(r, "border off")
			r:Verdict(edges == false, "border hidden")
			MapShot(r, "square minimap, no border")
			r:Set("mmSquareBorderSize", 2)
			Apply()
		end },
		{ key = "faded", title = "the hidden-blip mask on and back", run = function(r)
			if ns.isRetail then return r:Skip("retail") end
			if not ns.SetMinimapBlobsHidden then return r:Skip("no ns.SetMinimapBlobsHidden") end
			local was = ns.minimapBlobsHidden
			ns.SetMinimapBlobsHidden(true)
			r:Sleep(0.3)
			ns.SetMinimapBlobsHidden(false)
			r:Sleep(0.3)
			if was then ns.SetMinimapBlobsHidden(true) end
			State(r, "after the blank mask")
			r:Verdict(Shape() == "SQUARE", "still square after the blank mask")
			MapShot(r, "square after the hidden-blip mask (should be square, map drawn)")
		end },
		{ key = "colors", title = "the border's colors", run = function(r)
			if ns.isRetail then return r:Skip("retail") end
			r:Set("mmSquare", true)
			r:Set("mmSquareBorderSize", 4)
			local ring = ns.ThemeRing()
			r:Log(("theme %s, its ring color %s"):format(tostring(ns.db.styleTheme),
				ring and ("%.2f %.2f %.2f"):format(ring[1], ring[2], ring[3]) or "none"))
			for _, pick in ipairs({ "theme", "black", "white", "gold", "class" }) do
				r:Set("mmBorderColor", pick)
				Apply()
				local edge = ns.MinimapPartsState().edge
				r:Log(("%s: %.2f %.2f %.2f"):format(pick, edge[1], edge[2], edge[3]))
				MapShot(r, "border color " .. pick)
			end
			r:Set("mmBorderColor", "gold")
			Apply()
			r:Verdict(math.abs(ns.MinimapPartsState().edge[1] - 0.93) < 0.01, "gold picked: the border gold")
			r:Set("mmBorderColor", "theme")
			r:Set("mmSquareBorderSize", 2)
			Apply()
		end },
		{ key = "buttons", title = "the buttons' rings colored on this theme", run = function(r)
			r:Set("mmButtons", true)
			Apply()
			local state = ns.MinimapPartsState()
			r:Log(("buttons colored %d, theme ring %s"):format(state.buttons, tostring(ns.ThemeRing() ~= nil)))
			r:Verdict(state.buttons > 0, "the buttons' rings colored")
			MapShot(r, "buttons' rings colored")
		end },
		{ key = "size", title = "the minimap at 150%, then back", run = function(r)
			r:Set("mmScale", 1.5)
			Apply()
			r:Verdict(math.abs((ns.MinimapPartsState().scale or 0) - 1.5) < 0.01, "minimap scale 1.5")
			MapShot(r, "minimap at 150%")
			r:Set("mmScale", 1)
			Apply()
			r:Verdict(math.abs((ns.MinimapPartsState().scale or 0) - 1) < 0.01, "back to 100%")
		end },
		{ key = "hide", title = "zoom buttons, zone bar and dial hidden, then back", run = function(r)
			r:Set("mmHideZoom", true)
			r:Set("mmHideZoneBar", true)
			r:Set("mmHideDial", true)
			Apply()
			local state = ns.MinimapPartsState()
			r:Log(("hidden: zoom %s, zone %s, dial %s"):format(tostring(state.zoom), tostring(state.zone), tostring(state.dial)))
			r:Verdict(state.zoom == 0 or state.zoom == "none", "zoom buttons hidden (none: not on this client)")
			r:Verdict(state.zone == 0, "zone bar hidden")
			r:Verdict(state.dial == 0 or state.dial == "none", "dial hidden (none: not on this client)")
			MapShot(r, "zoom buttons, zone bar and dial hidden")
			r:Set("mmHideZoom", false)
			r:Set("mmHideZoneBar", false)
			r:Set("mmHideDial", false)
			Apply()
			state = ns.MinimapPartsState()
			r:Log(("back: zoom %s, zone %s, dial %s"):format(tostring(state.zoom), tostring(state.zone), tostring(state.dial)))
			r:Verdict(state.zone ~= 0 and state.dial ~= 0, "zone bar and dial back")
			MapShot(r, "zoom buttons, zone bar and dial back")
		end },
		{ key = "inside", title = "zone name and clock inside the square, then back", run = function(r)
			if ns.isRetail then return r:Skip("retail") end
			r:Set("mmSquare", true)
			r:Set("mmHeaderInside", true)
			Apply()
			r:Verdict(ns.MinimapPartsState().zoneInside == true, "the zone name moved onto the map")
			MapShot(r, "zone name and clock inside the square")
			r:Sleep(3)
			r:Verdict(ns.MinimapPartsState().zoneInside == true, "...still there 3 s later (the game didn't move it back)")
			r:Set("mmHeaderInside", false)
			Apply()
			r:Verdict(ns.MinimapPartsState().moved == 0 and not ns.MinimapPartsState().zoneInside, "put back")
			MapShot(r, "zone name and clock back over the map")
		end },
		{ key = "round", title = "Square minimap off: round again", run = function(r)
			r:Set("mmSquare", false)
			Apply()
			local on, _, edges = State(r, "round")
			r:Verdict(on == false and Shape() ~= "SQUARE", "square off, shape back")
			r:Verdict(RingAlpha() > 0, "the game's round ring back")
			r:Verdict(edges == false, "border hidden")
			MapShot(r, "round minimap again (map drawn, not blank)")
		end },
	},
})
