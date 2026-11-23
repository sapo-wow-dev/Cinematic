-- /cine debug elvfishbar: ElvUI's player cast bar (ElvUF_Player_CastBar)
-- hides while you fish, as the game's does (Hide the Fishing cast bar,
-- Camera.lua). Player report 2026-11-23: it stayed up. An oUF bar has no
-- OnEvent of its own and only Show()s itself, so Camera's cast watcher hooks
-- it with ElvUI loaded and checks it on each of your casts. Needs ElvUI on.
-- Steps:
--   1 setup   ElvUI loaded, its bar there, the Fishing page and its option on
--   2 fish    you cast Fishing: 0.5 s in, the bar shown but at alpha 0,
--             marked cinematicFishingHidden, hooked; a shot behind it
--   3 recast  the bobber goes (catch it or let it go): after, the bar not
--             visible (hidden or alpha 0)
-- Into CinematicDB.elvFishBarTestLog. Dev copy only.
local _, ns = ...

local function Bar() return _G.ElvUF_Player_CastBar end
local function Fields(r, label)
	local bar = Bar()
	r:Fields(label, {
		shown = function() return bar:IsShown() end,
		visible = function() return bar:IsVisible() end,
		alpha = function() return bar:GetAlpha() end,
		effective = function() return bar:GetEffectiveAlpha() end,
		fishingHidden = function() return bar.cinematicFishingHidden end,
		channel = function() return (UnitChannelInfo("player")) end,
	})
end

ns.TestKit.Define({
	name = "elvfishbar",
	key = "elvFishBarTest",
	title = "ElvUI Fishing cast bar",
	about = "ElvUI's cast bar hides while you fish; you cast Fishing once",
	needs = "ElvUI on, a fishing pole and water to fish in",
	settings = { "handleFishing", "hideFishingCastBar" },
	context = function()
		return ("ElvUI up: %s, bar: %s"):format(tostring(ns.AddonUp("ElvUI")), tostring(Bar() ~= nil))
	end,
	steps = {
		{ key = "setup", title = "ElvUI and the Fishing option", run = function(r)
			if not ns.AddonUp("ElvUI") or not Bar() then
				r:Fail("ElvUI isn't loaded (or has no player cast bar): turn it on and run again")
				return
			end
			r:Set("handleFishing", true)
			r:Set("hideFishingCastBar", true)
			r:Pass("ElvUI loaded, ElvUF_Player_CastBar there, Fishing page and its option on")
		end },
		{ key = "fish", title = "cast Fishing", proven = "q7970 2026-11-23: shown, alpha 0, marked, shot clear",
			run = function(r)
			if not Bar() then r:Skip("no ElvUI bar") return end
			r:WaitFor("Cast FISHING once (the bobber in the water).", {
				events = { "UNIT_SPELLCAST_CHANNEL_START" },
				filter = function(_, unit) return unit == "player" end,
			})
			r:Sleep(0.5)
			Fields(r, "ElvUI bar while fishing")
			local bar = Bar()
			r:Verdict(bar:IsShown(), "ElvUI showed its bar for the cast (so hiding it is ours to do)")
			r:Verdict(bar.cinematicFishingHidden == true, "the bar is marked cinematicFishingHidden")
			r:Verdict(bar:GetAlpha() == 0, "the bar's alpha is 0: " .. tostring(bar:GetAlpha()))
			r:Shot("ElvUI cast bar while fishing: nothing should show", { behind = bar })
		end },
		{ key = "recast", title = "after the bobber goes", proven = "q7970 2026-11-23: hidden after the cast",
			run = function(r)
			if not Bar() then r:Skip("no ElvUI bar") return end
			r:WaitFor(nil, { events = { "UNIT_SPELLCAST_CHANNEL_STOP" },
				filter = function(_, unit) return unit == "player" end })
			r:Sleep(0.5)
			Fields(r, "ElvUI bar after the cast")
			local bar = Bar()
			r:Verdict(not bar:IsVisible() or bar:GetAlpha() == 0, "the bar didn't come back up after the cast")
		end },
	},
})
