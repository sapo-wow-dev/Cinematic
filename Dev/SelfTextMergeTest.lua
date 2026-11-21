-- /cine debug selftextmerge: Text on You's Merge repeats on real hits (the
-- page's last open question, Tools/tests/self-text-page.md Q2). A test kit
-- test (Dev/TestKit.lua) with ONE thing to do: fight a mob and let it hit
-- you a few times (a heal over time works too). The game's words for a hit
-- are secret; merged, they go through SetFormattedText("%s x%d", words, n),
-- which only offline and MSBT's code said works.
--   1 fight  the page on, ours drawing, Merge repeats on; the merge window
--            widened to 3 s for the run only (real hits come seconds apart,
--            the usual 0.5 s would rarely catch two). Waits, no time limit,
--            for a merge of the game's own texts. Then: was a merged
--            text's words secret (the real case), is it shown, its count,
--            no errors; a screenshot of it on your screen.
--   2 back   the usual window again (nothing to do): checked
-- Your settings, CineMode and the window put back at the end, after a stop,
-- and after a /reload (the kit's undo). Into CinematicDB.selfTextMergeTestLog.
-- Dev copy only.
local _, ns = ...

local WINDOW = 3 -- seconds: the run's merge window

local function Stats() return ns.SelfTextStats or {} end

ns.TestKit.Define({
	name = "selftextmerge",
	key = "selfTextMergeTest",
	title = "Text on You merge test",
	about = "Merge repeats on real (secret) hits: fight a mob, let it hit you a few times",
	settings = { "styleGeneral", "selfTextStyle", "selfTextBy", "selfTextMerge", "selfTextLife", "selfText_damageShow",
		"selfText_healShow" },
	cvars = { "enableFloatingCombatText" },
	finish = function()
		ns.selfTextMergeWindow = nil
	end,
	steps = {
		{ key = "fight", title = "real hits merged",
			say = "Fight a mob: let it HIT YOU a few times.\n(A heal over time works too.)",
			run = function(r)
				r:Set("styleGeneral", true)
				r:Set("selfTextStyle", true)
				r:Set("selfTextBy", "ours")
				r:Set("selfTextMerge", true)
				r:Set("selfTextLife", 6) -- (up for the shot: the kit waits 1.5 s before it, the merge came up to 3 s in)
				r:Set("selfText_damageShow", true)
				r:Set("selfText_healShow", true)
				ns.selfTextMergeWindow = WINDOW
				if ns.RefreshSelfTextStyle then ns.RefreshSelfTextStyle() end
				local stats = Stats()
				local merged0, secret0, copied0 = stats.merged or 0, stats.mergedSecret or 0, stats.copied or 0
				r:Log(("start: page on %s, by %s, the game's text %s, merged so far %d"):format(
					tostring(ns.SelfTextState and ns.SelfTextState().on), tostring(ns.SelfTextBy and ns.SelfTextBy()),
					tostring(GetCVar("enableFloatingCombatText")), merged0))
				r:WaitFor(nil, { check = function() return (Stats().merged or 0) - merged0 >= 1 end })
				local text = Stats().lastMerged
				local okWords, words = r:Probe("the merged text's words", function() return text and text.words end)
				local okShown, shown = r:Probe("the merged text shown", function() return text and text:IsShown() end)
				local okShownText, drawn = r:Probe("the merged text's GetText", function() return text and text:GetText() end)
				r:Log(("merged %d (of them secret %d), copied %d, its count %s, its kind %s"):format(
					(Stats().merged or 0) - merged0, (Stats().mergedSecret or 0) - secret0, (Stats().copied or 0) - copied0,
					tostring(text and text.count), tostring(text and text.group)))
				-- (Read before the shot: by its end the text may have run its time.)
				local count = text and text.count
				r:Shot("merged", { behind = text })
				local secretMerged = (Stats().mergedSecret or 0) - secret0
				local wordsSecret = okWords and issecretvalue and issecretvalue(words) or false
				r:Verdict(secretMerged >= 1 and okShown and shown == true and (count or 0) >= 2,
					("%d merges of secret words, its words secret %s, shown %s, count %s, its text %s"):format(secretMerged,
						tostring(wordsSecret), tostring(shown), tostring(count),
						okShownText and (issecretvalue and issecretvalue(drawn) and "secret" or tostring(drawn)) or "error"))
			end },
		{ key = "back", title = "the usual merge window again",
			run = function(r)
				ns.selfTextMergeWindow = nil
				r:Verdict(ns.selfTextMergeWindow == nil, "the run's window cleared")
			end },
	},
})
