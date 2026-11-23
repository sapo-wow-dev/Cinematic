-- /cine debug cardevents: Card Vision's Events tab as rebuilt 2026-11-23 (the
-- user's pick of three mockups): the card type tiles over the preview, the
-- picked type's Size, Test and Edit under it, and a folder tab for each
-- situation (Combat, Places and travel...) with its cards' rows. Nothing to
-- do: every step runs by itself.
--   1 layout  the page open: every tile and tab on the page, inside its view,
--             nothing over them, no off card; a screenshot
--   2 pick    each tile clicked: it's the type picked, the preview and the
--             Size line turn to it, the rows lit are its cards (as many as
--             the tabs' counts say); a screenshot of two
--   3 tabs    each tab clicked: only its rows shown, all of its group, the
--             page as long as they are; a screenshot of each
--   4 taboff  Combat's tab switched off by its right-click: greyed, its cards
--             off with the tab named as why (/cine why), Places' still on;
--             back on after; a screenshot
--   5 find    a card on another tab (Reputation, on Progress): its row
--             flashed and /cine find cardReputationOn both show its tab
--             and the row in view
--   6 pageoff Card Vision switched off: the page's off card shows
-- Settings put back after. Into CinematicDB.cardEventsTestLog. Dev copy only.
local _, ns = ...

local PAGE = "Card Vision"
local COMBAT_TAB = "tabOn:Card Vision/events:1"

-- The page's parts (CardsPage.lua's ns.cardEventsPage), the page opened first.
local function Open(r)
	ns.OpenOptions(PAGE)
	r:Sleep(0.8)
	return ns.cardEventsPage
end

-- Whether a frame is drawn inside the settings' scroll view, side to side
-- and (with tall) top to bottom too.
local function InView(frame, tall)
	local panel = SettingsPanel or UIParent
	local l, rt, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
	local pl, pr, pt, pb = panel:GetLeft(), panel:GetRight(), panel:GetTop(), panel:GetBottom()
	if not (l and rt and t and b and pl and pr and pt and pb) then return false end
	if l < pl or rt > pr then return false end
	return not tall or (t <= pt and b >= pb)
end

-- The page scrolled so frame sits near the view's top (run 1, 2026-11-23:
-- the tab row was below the window's bottom, its shots never showed it).
local function ScrollTo(frame)
	local scroll = frame:GetParent()
	while scroll and not scroll.SetVerticalScroll do scroll = scroll:GetParent() end
	local content = scroll and scroll.GetScrollChild and scroll:GetScrollChild()
	local top, frameTop = content and content:GetTop(), frame:GetTop()
	if not (top and frameTop) then return end
	local range = scroll:GetVerticalScrollRange() or 0
	scroll:SetVerticalScroll(math.max(0, math.min(range, top - frameTop - 40)))
end

local function LitCount(page)
	local n = 0
	for _, group in ipairs(page.groups) do
		for _, item in ipairs(group.items) do
			if ns.CardBase(item.id) == page.Picked() then n = n + 1 end
		end
	end
	return n
end

ns.TestKit.Define({
	name = "cardevents",
	key = "cardEventsTest",
	title = "Card Vision Events tab",
	about = "the Events tab's type tiles and situation tabs, nothing to do",
	settings = { "cards", COMBAT_TAB },
	context = function()
		return ("cards %s, Combat tab %s, picked %s"):format(tostring(ns.db.cards), tostring(ns.db[COMBAT_TAB]),
			tostring(ns.cardEventsPage and ns.cardEventsPage.Picked()))
	end,
	steps = {
		{ key = "layout", title = "the tiles and tabs on the page", proven = "queue qcb80, 2026-11-23: 6/6", run = function(r)
			r:Set("cards", true)
			local page = Open(r)
			if not page then return r:Fail("no ns.cardEventsPage: the Events tab wasn't built") end
			local panel = SettingsPanel or UIParent
			ScrollTo(page.tiles[1]) -- (the page at its top, as it opens)
			r:Sleep(0.3)
			r:Verdict(ns.PageOffCardWanted(PAGE) == false, "no off card over the page")
			local shown, inside, clear = 0, 0, 0
			for n, tile in ipairs(page.tiles) do
				if tile:IsVisible() then
					shown = shown + 1
					if InView(tile) then inside = inside + 1 else r:Log(("tile %d (%s) runs out of the view"):format(n, tostring(tile.style))) end
					local hits = r:Overlaps(tile, panel)
					if #hits == 0 then clear = clear + 1
					else r:Log(("tile %s covers: %s"):format(tostring(tile.style), table.concat(hits, ", "))) end
				end
			end
			r:Log(("tiles: %d shown, %d inside the view, %d with nothing over them"):format(shown, inside, clear))
			r:Verdict(shown >= 10 and inside == shown and clear == shown, "every card type's tile shown, inside, uncovered")
			local tabsIn = 0
			for i, tab in ipairs(page.tabs) do
				if tab:IsVisible() and InView(tab) then tabsIn = tabsIn + 1
				else r:Log(("tab %d (%s) not seen inside the view"):format(i, tostring(tab:GetText()))) end
			end
			r:Verdict(tabsIn == #page.groups, ("all %d situation tabs inside the view"):format(#page.groups))
			local hits = r:Overlaps(page.typeBox, panel)
			if #hits > 0 then r:Log("the picked type's Size, Test and Edit cover: " .. table.concat(hits, ", ")) end
			r:Verdict(#hits == 0 and InView(page.typeBox), "the picked type's Size, Test and Edit beside the preview, nothing over them")
			-- (Compact, run 2: the preview small, its settings beside it, so the
			-- tabs and the first rows are on the page's first screen.)
			local jl, jr = page.jumbo:GetLeft(), page.jumbo:GetRight()
			local bl = page.typeBox:GetLeft()
			r:Log(("preview %.0f wide, %.0f tall; its settings from x %.0f (preview's right %.0f), %.0f tall"):format(
				page.jumbo:GetWidth(), page.jumbo:GetHeight(), bl or 0, jr or 0, page.typeBox:GetHeight()))
			r:Verdict(jl and jr and bl and bl >= jr, "the type's settings right of the preview, not under it")
			local first = page.lists[page.Current()]
			r:Verdict(InView(page.tabs[1], true), "the tabs on the first screen, no scrolling")
			r:Log(("first rows: list top %s, view bottom %s"):format(tostring(first and first:GetTop()),
				tostring(panel:GetBottom())))
			r:Shot("Card Vision Events tab", { behind = panel })
		end },
		{ key = "pick", title = "each card type picked", proven = "run 1, 2026-11-23: 10/10", run = function(r)
			local page = Open(r)
			if not page then return r:Fail("no ns.cardEventsPage") end
			local good, tried = 0, 0
			for _, tile in ipairs(page.tiles) do
				if tile:IsVisible() then
					tried = tried + 1
					local style = tile.style
					tile:Click()
					r:Sleep(0.3)
					local users = #ns.CardStyleUsers(style)
					local badges = 0
					for _, tab in ipairs(page.tabs) do
						local n = tostring(tab:GetText()):match("%((%d+)%)")
						badges = badges + (tonumber(n) or 0)
					end
					local lit = LitCount(page)
					local ok = page.Picked() == style and lit == users and badges == users
					r:Log(("%s: picked %s, %d cards use it, %d rows lit, tabs count %d"):format(style, tostring(page.Picked()),
						users, lit, badges))
					if ok then good = good + 1 end
					if style == "danger" or style == "ticker" then
						r:Shot("picked " .. style, { behind = SettingsPanel })
					end
				end
			end
			r:Verdict(tried > 0 and good == tried, ("%d of %d types: picked, lit and counted right"):format(good, tried))
			page.Pick("danger")
		end },
		{ key = "tabs", title = "each situation tab", proven = "queue qcb80, 2026-11-23: 12/12", run = function(r)
			local page = Open(r)
			if not page then return r:Fail("no ns.cardEventsPage") end
			for g, tab in ipairs(page.tabs) do
				tab:Click()
				r:Sleep(0.4)
				local others = 0
				for n, list in ipairs(page.lists) do
					if n ~= g and list:IsVisible() then others = others + 1 end
				end
				local list = page.lists[g]
				local want = #page.groups[g].items
				local _, height = list:GetSize()
				r:Log(("tab %d %s: current %d, list shown %s, %d rows, %.0f tall, other lists shown %d"):format(g,
					tostring(tab:GetText()), page.Current(), tostring(list:IsVisible()), want, height or 0, others))
				r:Verdict(page.Current() == g and list:IsVisible() and others == 0 and (height or 0) >= want * 28 - 1,
					("tab %d: its %d rows, only its"):format(g, want))
				-- (Scrolled to the tabs: they and the tab's rows in view, nothing
				-- over the tab, the preview docked at the top included.)
				ScrollTo(tab)
				r:Sleep(0.4)
				local hits = r:Overlaps(tab, SettingsPanel)
				if #hits > 0 then r:Log(("tab %d covers: %s"):format(g, table.concat(hits, ", "))) end
				r:Verdict(InView(tab, true) and #hits == 0, ("tab %d in view once scrolled to, nothing over it"):format(g))
				r:Shot("tab " .. g, { behind = SettingsPanel })
			end
			page.tabs[1]:Click()
		end },
		{ key = "taboff", title = "Combat's tab switched off", proven = "queue qcb80, 2026-11-23: 5/5", run = function(r)
			local page = Open(r)
			if not page then return r:Fail("no ns.cardEventsPage") end
			r:Set("cards", true)
			r:Set(COMBAT_TAB, true)
			ns.FlipSettingKey(COMBAT_TAB) -- (as its right-click does)
			r:Sleep(0.4)
			local tab = page.tabs[1]
			local _, why = ns.CardAllowed("combatIn")
			local zoneOk, zoneWhy = ns.CardAllowed("zone")
			r:Log(("Combat tab %s, greyed %s; combatIn: %s; zone: %s %s"):format(tostring(ns.db[COMBAT_TAB]),
				tostring(tab.IsOff and tab.IsOff()), tostring(why), tostring(zoneOk), tostring(zoneWhy)))
			ScrollTo(tab) -- (the greyed tab in the shot)
			r:Sleep(0.3)
			r:Verdict(ns.db[COMBAT_TAB] == false and tab.IsOff and tab.IsOff(), "right-click turned it off, greyed")
			r:Verdict(not ns.CardOn("combatIn") and not ns.CardOn("death"), "its cards off (Entering combat, Death)")
			r:Verdict(type(why) == "string" and why:find(ns.L["Events"], 1, true) ~= nil, "/cine why names its tab")
			r:Verdict(not (type(zoneWhy) == "string" and zoneWhy:find(ns.L["Events"], 1, true)), "Places' cards not held by it")
			r:Shot("Combat tab off", { behind = SettingsPanel })
			ns.FlipSettingKey(COMBAT_TAB)
			r:Sleep(0.3)
			r:Verdict(ns.db[COMBAT_TAB] == true and ns.Setting("combatOnEnter") == (ns.db.combatOnEnter and true or false),
				"back on: its cards follow their ticks again")
		end },
		{ key = "find", title = "a card on another tab found", proven = "run 1, 2026-11-23: 2/2", run = function(r)
			local page = Open(r)
			if not page then return r:Fail("no ns.cardEventsPage") end
			page.tabs[1]:Click()
			r:Sleep(0.3)
			ns.CardEventFlash("reputation")
			r:Sleep(0.8)
			local g = page.tabOf.reputation
			r:Verdict(page.Current() == g, "its row's flash picked its tab (" .. tostring(page.groups[g].name) .. ")")
			page.tabs[1]:Click()
			if SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
			r:Sleep(0.5)
			local said = ns.FindSetting("cardReputationOn")
			r:Sleep(3.2) -- (the search looks till the row stays put)
			local entry = ns.FindEntryOf("cardReputationOn")
			local tick = entry and entry.edges and entry.edges.top
			r:Log(("/cine find cardReputationOn: said %s, tab now %d, tick shown %s"):format(tostring(said),
				page.Current(), tostring(tick and tick:IsVisible())))
			r:Verdict(page.Current() == g and tick and tick:IsVisible() and InView(tick, true), "/cine find shows its tab and row")
			r:Shot("/cine find cardReputationOn", { behind = SettingsPanel })
		end },
		{ key = "pageoff", title = "Card Vision switched off", proven = "run 1, 2026-11-23: 1/1", run = function(r)
			r:Set("cards", false)
			ns.lowHealthKit.Refresh()
			Open(r)
			r:Verdict(ns.PageOffCardWanted(PAGE) == true, "the page's off card shows")
			r:Shot("Card Vision off", { behind = SettingsPanel })
			r:Set("cards", true)
			ns.lowHealthKit.Refresh()
			if SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
		end },
	},
})
