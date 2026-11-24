-- /cine debug stylelinks: the links between a frame's settings and its Style
-- page (2026-11-24, "we have links from a page's settings to its style but we
-- don't have a link back"). A test kit test (Dev/TestKit.lua), nothing to do:
-- CineMode off (the kit's), each page opened, its link icon found, checked
-- and clicked. Steps:
--   1 back      each Style page: its gear (ns.SettingsIcon) shown after its
--               tabs, its art loaded, nothing over it; clicked, its settings
--               page is the one on screen. A shot each. Unit Frames' three:
--               another HUD sub-tab picked first, then landed at their own
--               (Your Cast Bar at Cast bar), a shot of where.
--   2 offcard   Letterbox Style with its switch off: the gear still shown
--               over the off card, and still opens Letterbox
--   3 forward   each settings page: its palette (ns.StyleIcon) shown,
--               clicked, its Style page on screen
--   4 none      Combat Text, Text on You and Style General: no gear
-- The tables match Tools/offline/stylebacklinks.lua's. Into
-- CinematicDB.styleLinksTestLog. Dev copy only.
local _, ns = ...

-- Style page = where its gear goes back to.
local BACK = {
	-- (third: the HUD sub-tab it opens at, not the last one picked there)
	{ "Unit Style", "HUD:units", "units" }, { "Unit Cast Style", "HUD:units", "units" },
	{ "Player Cast Style", "HUD:units", "playercast" },
	{ "Personal Style", "HUD:prd" }, { "Raid Style", "HUD:party" }, { "Action Style", "HUD:bars" },
	{ "Cooldown Manager Style", "HUD:cdm" }, { "Minimap Style", "HUD:minimap" },
	{ "Bubble Style", "Chat bubbles" }, { "Tooltip Style", "Tooltips" },
	{ "Nameplate Style", "Nameplates" }, { "Nameplate Marks", "Nameplates" }, { "Cast Bar Style", "Nameplates" },
	{ "Name Style", "Nameplate Names" },
	{ "Letterbox Style", "Letterbox" }, { "Tint Style", "Tint" }, { "Weather Style", "Weather" },
	{ "Vitals Style", "Vitals Vision" }, { "Roll Style", "Roll Vision" },
	{ "Quest Talk Style", "Quest Vision" }, { "Quest Item Style", "Quest Vision" },
	{ "Damage Vision Look", "Damage Vision" }, { "Emote Vision Style", "Emote Vision" },
	{ "Card Styles", "Card Vision" }, { "Visions Style", "Visions General" },
}
-- Settings page = its palette's Style page.
local FORWARD = {
	{ "Letterbox", "Letterbox Style" }, { "Tint", "Tint Style" }, { "Weather", "Weather Style" },
	{ "Vitals Vision", "Vitals Style" }, { "Roll Vision", "Roll Style" }, { "Quest Vision", "Quest Talk Style" },
	{ "Damage Vision", "Damage Vision Look" }, { "Emote Vision", "Emote Vision Style" },
	{ "Card Vision", "Card Styles" }, { "Visions General", "Visions Style" }, { "Nameplates", "Nameplate Style" },
	{ "Nameplate Names", "Name Style" }, { "Chat bubbles", "Bubble Style" }, { "Tooltips", "Tooltip Style" },
	{ "Minimap", "Minimap Style" },
}
local NONE = { "Combat Text Style", "Self Text Style", "Style General" }

local function Panel() return _G.SettingsPanel or _G.InterfaceOptionsFrame or UIParent end

-- The shown link of that kind going to want, on the page on screen.
local function ShownLink(kind, want)
	for _, icon in ipairs(ns.allLinkIcons or {}) do
		if icon.linkKind == kind and (not want or icon.linkPage == want) and icon:IsVisible() then return icon end
	end
end

-- Opens page, finds its link to want, checks it and clicks it. shot: one
-- screenshot of the page first. Returns the icon.
local function Walk(r, page, kind, want, shot, section)
	if not ns.PageMade(page) then
		r:Log(page .. ": not on this client, left out")
		return nil, true
	end
	ns.OpenOptions(page)
	r:Sleep(0.6)
	local icon = ShownLink(kind, want)
	if not icon then
		local other = ShownLink(kind)
		r:Verdict(false, ("%s: no %s link to %s shown%s"):format(page, kind, want,
			other and (" (one to " .. tostring(other.linkPage) .. ")") or ""))
		return
	end
	local art = icon:GetRegions()
	local loaded = art and art.GetTexture and art:GetTexture() ~= nil
	local hits = r:Overlaps(icon, Panel())
	r:Verdict(loaded and #hits == 0, ("%s: %s link shown, art %s, covers %s"):format(page, kind,
		loaded and "loaded" or "MISSING", #hits == 0 and "nothing" or table.concat(hits, ", ")))
	if shot then r:Shot(page, { behind = Panel() }) end
	-- (A HUD sub-tab: another one picked there first, out of sight, so a
	-- gear going by the last one picked lands wrong: the user, 2026-11-24.)
	if section and ns.OpenFramesSection then
		ns.OpenFramesSection(section == "highlight" and "units" or "highlight")
		ns.OpenOptions(page)
		r:Sleep(0.6)
	end
	icon:Click()
	r:Sleep(0.6)
	r:Verdict(ns.PageOnScreen(want), ("%s: clicked, %s on screen"):format(page, want))
	if section then
		local now = ns.FramesSectionOpen and ns.FramesSectionOpen()
		r:Verdict(now == section, ("%s: at its %s sub-tab (%s)"):format(page, section, tostring(now)))
		r:Shot(page .. " landed", { behind = Panel() })
	end
	return icon
end

ns.TestKit.Define({
	name = "stylelinks",
	key = "styleLinksTest",
	title = "Style links test",
	about = "every Style page's gear back to its settings, and each settings page's palette to its Style page",
	settings = { "letterboxStyle" },
	context = function()
		return ("style loaded %s, visions %s, atmosphere %s"):format(tostring(ns.ModuleLoaded and ns.ModuleLoaded("style")),
			tostring(ns.ModuleLoaded and ns.ModuleLoaded("visions")),
			tostring(ns.ModuleLoaded and ns.ModuleLoaded("atmosphere")))
	end,
	steps = {
		{ key = "back", title = "each Style page's gear", seconds = 110, run = function(r)
			if not (ns.SettingsIcon and ns.PageMade and ns.PageOnScreen) then return r:Fail("no links: Style isn't loaded") end
			if ns.MakeLazyPages then ns.MakeLazyPages("stylelinks test") end
			local found, left = 0, 0
			for _, each in ipairs(BACK) do
				local icon, out = Walk(r, each[1], "settings", each[2], true, each[3])
				if icon then found = found + 1 elseif out then left = left + 1 end
			end
			r:Verdict(found + left == #BACK, ("%d of %d gears found and working, %d not on this client"):format(
				found, #BACK - left, left))
		end },
		{ key = "offcard", title = "a gear over an off card", seconds = 8, run = function(r)
			local key = ns.PageSwitchKey and ns.PageSwitchKey("Letterbox Style")
			if not key then return r:Skip("Letterbox Style has no switch") end
			r:Set(key, false)
			local icon = Walk(r, "Letterbox Style", "settings", "Letterbox", true)
			r:Verdict(icon ~= nil, "Letterbox Style off: its gear still there, and it opens Letterbox")
		end },
		{ key = "forward", title = "each settings page's palette", seconds = 30, run = function(r)
			local found, left = 0, 0
			for _, each in ipairs(FORWARD) do
				local icon, out = Walk(r, each[1], "style", each[2], false)
				if icon then found = found + 1 elseif out then left = left + 1 end
			end
			r:Verdict(found + left == #FORWARD, ("%d of %d palettes found and working"):format(found, #FORWARD - left))
		end },
		{ key = "none", title = "no gear where there's nowhere back", seconds = 4, run = function(r)
			for _, page in ipairs(NONE) do
				if ns.PageMade(page) then
					ns.OpenOptions(page)
					r:Sleep(0.6)
					local icon = ShownLink("settings")
					r:Verdict(icon == nil, ("%s: no gear%s"):format(page, icon and (" (one to " .. tostring(icon.linkPage) .. ")") or ""))
				end
			end
		end },
	},
})
