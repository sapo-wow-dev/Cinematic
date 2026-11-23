-- /cine debug pvpcard: Entering a PvP fight's card (Cards.lua's combatPvp,
-- CombatVision.lua's FightCard) plays in place of Entering combat's when a
-- fight against a player starts. Steps:
--   1 page    the Card Vision page open: its row "Entering a PvP fight" on the
--             Events tab's Combat tab (a tab per situation since 2026-11-23),
--             with Entering combat's card type, under its row, nothing over
--             it; a screenshot
--   2 duel    nothing to do: a pretend duel starts (the fight's check
--             handed pretend unit reads: your target an enemy player, a
--             duelist, you in the open world; the game's globals untouched): the PvP card plays with its own
--             words; then a pretend mob fight: Entering combat's card with
--             its own words (PASS/FAIL), a screenshot of each card. (A real
--             enemy player's reads are untested: UnitGUID is "PvP restricted
--             for addons" in the API docs.)
--   3 find    nothing to do: /cine find cardCombatPvpOn (and Entering
--             combat's and Duel's, the same kind of row) from three starts:
--             settings closed, open on Card Vision's Settings tab, open on
--             another page; the row on screen each time and nothing over it
--             (PASS/FAIL), with where it was if not; a screenshot of each
--             PvP find. (Run 5, 2026-11-23: from closed or another page, the
--             top rows ended up above the view: the preview docking small as
--             the page scrolled moved them. ShowMatch looks again; run 6: the
--             first find after a reload, the page made then, still missed:
--             it now looks till the row stays put.)
--   4 update  nothing to do: players who had Cinematic before don't get it
--             on. Your own settings are such a player's: the update ran at
--             login and saved the row; a pretend player's (live, a saved
--             profile, one they'd ticked it in, a reset point) after the
--             update; and with the row off a pretend duel shows the usual
--             card (PASS/FAIL)
-- Settings put back after. Offline: Tools/offline/pvpcard.lua.
-- Into CinematicDB.pvpCardTestLog. Dev copy only.
local _, ns = ...

-- Finds a text on the page showing words.
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

-- A pretend fight start: the fight's check is handed pretend unit reads
-- (your target the pretend unit: a duelist, an enemy player you can attack;
-- a mob, an enemy that's no player; you in the open world). Never by
-- swapping the game's globals: that taints its frames till a reload
-- (2026-11-23, 1322 CompactUnitFrame errors; Tools/errors/known.lua's
-- test-global-swap-taint). Gives what fired and how ns.CardPvpFight told it.
local PRETEND = {
	duelist = { guid = "Player-0000-00000001", player = true },
	mob = { guid = "Creature-0-0000-0000-00000-299-0000000001", player = false },
}
local function PretendReads(pretend)
	local function Mine(unit) return unit == "target" end
	return {
		IsInInstance = function() return false, "none" end,
		UnitExists = function(unit) return Mine(unit) end,
		UnitCanAttack = function(_, unit) return Mine(unit) end,
		UnitGUID = function(unit) return Mine(unit) and pretend.guid or nil end,
		UnitIsPlayer = function(unit) return Mine(unit) and pretend.player end,
		UnitIsUnit = function() return false end,
	}
end
local function PretendFightStart(pretend)
	local reads, fired = PretendReads(pretend), nil
	local Fire = ns.Cards.Fire
	ns.Cards.Fire = function(id, card, ...)
		if not fired and (id == "combatIn" or id == "combatPvp") then fired = { id = id, name = card and card.name } end
		return Fire(id, card, ...)
	end
	local okHow, how = pcall(ns.CardPvpFight, reads)
	local ok, err = pcall(ns.CardFightCard, true, reads)
	ns.Cards.Fire = Fire
	if not ok then fired = { id = "error", name = tostring(err) } end
	return fired, okHow and tostring(how) or ("error " .. tostring(how)) -- (nil: no enemy player seen)
end

ns.TestKit.Define({
	name = "pvpcard",
	key = "pvpCardTest",
	title = "Entering a PvP fight card",
	about = "the PvP combat card: its row, then a pretend duel and a pretend mob fight, nothing to do",
	settings = { "cards", "combatOnEnter", "cardCombatPvpOn", "combatTextPvp" },
	context = function()
		return ("cards %s, combatOnEnter %s, cardCombatPvpOn %s, combatTextPvp %s"):format(
			tostring(ns.db.cards), tostring(ns.db.combatOnEnter), tostring(ns.db.cardCombatPvpOn),
			tostring(ns.db.combatTextPvp))
	end,
	steps = {
		{ key = "page", title = "its row on the Card Vision page", proven = "run 4, 2026-11-23: 4/4", run = function(r)
			ns.OpenOptions("Card Vision")
			r:Sleep(0.8)
			local panel = SettingsPanel or UIParent
			-- (The Events tab has a folder tab per situation: its row's tab
			-- picked and the row scrolled to, as the page's search does.)
			if not ns.CardEventFlash then return r:Fail("no ns.CardEventFlash: the Events tab wasn't built") end
			ns.CardEventFlash("combatPvp")
			r:Sleep(0.8)
			local label = FindText(panel, ns.L["Entering a PvP fight"])
			if not label then
				r:Shot("Card Vision page, no PvP row seen", { behind = panel })
				return r:Fail("no \"Entering a PvP fight\" row on the Card Vision page")
			end
			local before = FindText(panel, ns.L["Entering combat"])
			r:Log(("card type: %s (Entering combat's %s)"):format(ns.CardBase("combatPvp"), ns.CardBase("combatIn")))
			r:Verdict(ns.CardBase("combatPvp") == ns.CardBase("combatIn") and before and before:GetTop() > label:GetTop(),
				"under Entering combat, with its card type")
			local hits = r:Overlaps(label:GetParent(), panel) -- (its row: the name with its tick and +)
			r:Verdict(#hits == 0, "nothing over its row")
			r:Shot("Card Vision Events tab: the PvP row", { behind = panel })
			if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
		end },
		{ key = "duel", title = "a pretend duel starts, then a pretend mob fight", proven = "run 4, 2026-11-23: 4/4", run = function(r)
			r:Set("cards", true)
			r:Set("combatOnEnter", true)
			r:Set("cardCombatPvpOn", true)
			r:Set("combatTextPvp", ns.DEFAULTS.combatTextPvp) -- (its own words as they come)
			local words = ns.CardWords("combatTextPvp")
			for _, case in ipairs({
				{ who = "duelist", unit = PRETEND.duelist, want = "combatPvp", words = words },
				{ who = "mob", unit = PRETEND.mob, want = "combatIn", words = ns.CardWords("combatTextIn") },
			}) do
				ns.Cards.Cut("combatIn")
				ns.Cards.Cut("combatPvp")
				r:Sleep(0.5)
				local fired, how = PretendFightStart(case.unit)
				r:Log(("pretend %s: ns.CardPvpFight %s, fired %s \"%s\""):format(case.who, tostring(how),
					fired and fired.id or "none", fired and tostring(fired.name) or ""))
				r:Verdict(fired and fired.id == case.want and fired.name == case.words,
					("pretend %s: %s with \"%s\""):format(case.who, case.want, tostring(case.words)))
				r:Sleep(0.6)
				r:Shot("the card as the pretend " .. case.who .. " fight starts")
			end
		end },
		{ key = "find", title = "/cine find takes you to its row", proven = "run 7, 2026-11-23: 18/18", run = function(r)
			-- (The user, 2026-11-23: /cine find cardCombatPvpOn didn't take them
			-- there. Each id from three starts: settings closed, open on the
			-- Settings tab of Card Vision, open on another page. Entering
			-- combat and Duel alongside: the same kind of row.)
			local function Where(id)
				local entry = ns.FindEntryOf and ns.FindEntryOf(id)
				if not entry then return nil, "no search entry" end
				local tick = entry.edges and entry.edges.top
				if not tick then return nil, "no edges" end
				local scroll = entry.page.canvas and entry.page.canvas.scroll
				local top, bottom = tick:GetTop(), tick:GetBottom()
				local sTop, sBottom = scroll and scroll:GetTop(), scroll and scroll:GetBottom()
				local inView = top and sTop and bottom and sBottom and top <= sTop + 1 and bottom >= sBottom - 1
				local row = tick:GetParent()
				return tick, ("page %s, tick visible %s, row visible %s, in view %s (tick %s-%s, scroll %s-%s, scrolled %s)")
					:format(tostring(entry.page.key), tostring(tick:IsVisible()), tostring(row and row:IsVisible()),
					tostring(inView), tostring(top), tostring(bottom), tostring(sTop), tostring(sBottom),
					tostring(scroll and scroll:GetVerticalScroll())), inView and tick:IsVisible()
			end
			local starts = {
				{ name = "settings closed", go = function() if SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end end },
				{ name = "on Card Vision's Settings tab", go = function() ns.OpenOptions("Card Settings") end },
				{ name = "on another page (Camera)", go = function() ns.OpenOptions("Camera") end },
			}
			for _, start in ipairs(starts) do
				for _, id in ipairs({ "cardCombatPvpOn", "combatOnEnter", "cardDuelOn" }) do
					if SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
					r:Sleep(0.4)
					start.go()
					r:Sleep(0.6)
					local said, page = ns.FindSetting(id)
					r:Sleep(3.2) -- (the search looks till the row stays put, 3 s at most)
					local _, line, ok = Where(id)
					r:Log(("%s, /cine find %s: said \"%s\" (%s); %s"):format(start.name, id, tostring(said),
						tostring(page), tostring(line)))
					r:Verdict(ok, ("%s: /cine find %s shows its row"):format(start.name, id))
				-- (Card Vision's preview docks small at the view's top as it
				-- scrolls: nothing of it, or anything else, over the row.)
				local tick = ns.FindEntryOf(id) and ns.FindEntryOf(id).edges.top
				if ok and tick then
					local hits = r:Overlaps(tick:GetParent(), SettingsPanel)
					r:Verdict(#hits == 0, ("%s: nothing over %s's row"):format(start.name, id))
				end
					if id == "cardCombatPvpOn" then
						r:Shot(start.name .. ": /cine find cardCombatPvpOn", { behind = SettingsPanel })
					end
				end
			end
			if SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
		end },
		{ key = "update", title = "players from before keep it off", proven = "run 8, 2026-11-23: 6/6", run = function(r)
			-- (Your own saved settings are a player's from before it: Cinematic
			-- was here before the card. What the update did to them at login.)
			r:Log(("you: new install %s, update done %s, the row %s (default %s)"):format(tostring(ns.newInstall),
				tostring(ns.db.pvpCardOffV1), tostring(rawget(ns.db, "cardCombatPvpOn")),
				tostring(ns.DEFAULTS.cardCombatPvpOn)))
			r:Verdict(ns.DEFAULTS.cardCombatPvpOn == true, "on by default (a new install)")
			r:Verdict(ns.newInstall ~= true and ns.db.pvpCardOffV1 == true,
				"your settings taken as a player's from before, the update run")
			-- (Never ticked by you, only by these tests, which put it back.)
			r:Verdict(rawget(ns.db, "cardCombatPvpOn") == false, "your row is off, though the default's now on")
			-- A pretend player from before: their live settings, a saved
			-- profile, one that had it ticked, a reset point. The update on them.
			if not ns.PvpCardOffForOld then return r:Fail("no ns.PvpCardOffForOld") end
			local before = { combatOnEnter = true,
				profiles = { Mine = { combatOnEnter = true }, Theirs = { cardCombatPvpOn = true } },
				profileResetPoints = { Cinema = { combatOnEnter = true } } }
			ns.PvpCardOffForOld(before)
			r:Log(("pretend player after the update: live %s, profile Mine %s, Theirs %s, reset point %s"):format(
				tostring(before.cardCombatPvpOn), tostring(before.profiles.Mine.cardCombatPvpOn),
				tostring(before.profiles.Theirs.cardCombatPvpOn), tostring(before.profileResetPoints.Cinema.cardCombatPvpOn)))
			r:Verdict(before.cardCombatPvpOn == false and before.profiles.Mine.cardCombatPvpOn == false
				and before.profileResetPoints.Cinema.cardCombatPvpOn == false, "pretend player from before: off everywhere")
			r:Verdict(before.profiles.Theirs.cardCombatPvpOn == true, "a profile they'd ticked it in keeps it")
			-- Off, so no card at a fight's start with an enemy player: the usual one.
			r:Set("cards", true)
			r:Set("combatOnEnter", true)
			r:Set("cardCombatPvpOn", false)
			ns.Cards.Cut("combatIn")
			ns.Cards.Cut("combatPvp")
			r:Sleep(0.5)
			local fired = PretendFightStart(PRETEND.duelist)
			r:Log(("row off, pretend duelist: fired %s \"%s\""):format(fired and fired.id or "none",
				fired and tostring(fired.name) or ""))
			r:Verdict(fired and fired.id == "combatIn", "row off: a duel shows the usual card, not the PvP one")
		end },
	},
})
