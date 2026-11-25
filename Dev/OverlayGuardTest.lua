-- /cine debug overlayguard: overlays never left frozen on screen (overlay
-- audit 2026-11-25: a player's teleport filter stuck till Alt+F4; cards
-- 2026-11-25-teleport-lost-end, -dead-loop-clear, -safety-stop-overlays,
-- -wheel-loading-screen). Steps:
--   1 tripped  Teleport Vision's test with its drawing made to fail every
--              frame: its loop's breaker turns it off and the portal is put
--              away (it froze before); /cine resume plays it again
--   2 stop     the death screen, Teleport Vision and a Zone card showing, a
--              safety stop (ns.Suspend): all put away; resumed after
--   3 hearth   YOUR TURN, the one real action: cast your Hearthstone (or a
--              teleport) and let it take you: 4 s after its cast, no
--              portal, tooltip and cast bar at full, the cast marked over
-- Into CinematicDB.overlayGuardTestLog. Dev copy only.
local _, ns = ...

local function Tooltip() return GameTooltip and GameTooltip:GetAlpha() or -1 end

ns.TestKit.Define({
	name = "overlayguard",
	key = "overlayGuardTest",
	title = "Overlays never left frozen",
	about = "a tripped loop, a safety stop and a real Hearthstone: nothing left on screen",
	settings = { "teleportVision", "deathScreen" },
	needs = "a Hearthstone ready (or a teleport spell), out of a fight",
	steps = {
		{ key = "tripped", title = "Teleport Vision's loop made to fail", handsOff = true, seconds = 6, run = function(r)
			r:Set("teleportVision", true)
			ns.TestTeleportVision(2, true)
			r:Sleep(1)
			r:Verdict(ns.TeleportVisionShown(), "the test's portal shows before")
			-- (The errors made on purpose kept out of the error report and the
			-- safety lines, counted here instead: the kit read them as bugs.)
			local real, report, log = ns.SetVignette, ns.ReportError, ns.Log
			local caught, safety = 0, {}
			ns.ReportError = function() caught = caught + 1 end
			ns.Log = function(kind, text, ...)
				if kind == "safety" then safety[#safety + 1] = text return end
				return log(kind, text, ...)
			end
			ns.SetVignette = function() error("overlayguard: the edges' drawing made to fail") end
			r:Sleep(1.5)
			ns.SetVignette = real
			r:Verdict(caught >= 5, ("%d errors caught (5 trip the breaker)"):format(caught))
			r:Verdict(not ns.TeleportVisionShown(), "the portal put away as its loop was turned off")
			r:Shot("after the trip")
			-- (/cine resume, quietly: brings back the loop the breaker turned off.)
			ns.suspendQuiet = true
			ns.Suspend("overlayguard test")
			ns.Resume()
			ns.suspendQuiet = nil
			ns.ReportError, ns.Log = report, log
			r:Log("safety lines (made on purpose): " .. table.concat(safety, " / "))
			ns.TestTeleportVision(2, true)
			r:Sleep(1)
			r:Verdict(ns.TeleportVisionShown(), "after /cine resume the test plays again")
			if ns.TeleportVisionTesting() then ns.TestTeleportVision() end
			r:Sleep(1.5)
		end },
		{ key = "stop", title = "a safety stop with overlays up", handsOff = true, seconds = 5, run = function(r)
			r:Set("teleportVision", true)
			r:Set("deathScreen", true)
			ns.TestTeleportVision(2, true)
			if ns.TestDeathVision then ns.TestDeathVision() end
			if ns.Cards and ns.Cards.Fire then pcall(ns.Cards.Fire, "zone", { name = "Overlay test", sub = "" }, true) end
			r:Sleep(1.5)
			local death = ns.DeathScreenFrame and ns.DeathScreenFrame()
			r:Log(("before: portal %s, death screen %s, card %s"):format(tostring(ns.TeleportVisionShown()),
				tostring(death and death:IsShown()), tostring(ns.Cards and ns.Cards.Current() ~= nil)))
			r:Shot("before the stop")
			ns.suspendQuiet = true
			ns.Suspend("overlayguard test")
			r:Sleep(0.5)
			r:Verdict(not ns.TeleportVisionShown(), "portal put away by the stop")
			r:Verdict(not (death and death:IsShown()), "death screen put away by the stop")
			r:Verdict(not (ns.Cards and ns.Cards.Current()), "card put away by the stop")
			r:Shot("after the stop")
			ns.Resume()
			ns.suspendQuiet = nil
			r:Sleep(1)
			r:Verdict(not ns.TeleportVisionShown(), "after resume: no portal (its test ended with the stop)")
		end },
		{ key = "hearth", title = "a real Hearthstone", run = function(r)
			r:Set("teleportVision", true)
			-- (A new Hearthstone or teleport cast, started and ended: not a
			-- loading screen (one on the same continent has none: run 1 stuck),
			-- nor any spell's success (run 2 woke on another spell, no cast seen).)
			local before, shownDuring = ns.departCast, false
			r:WaitFor("Cast your Hearthstone (or a teleport) and let it take you", { check = function()
				local cast = ns.departCast
				if cast and cast ~= before and not cast.done and ns.TeleportVisionShown() then shownDuring = true end
				return cast and cast ~= before and (cast.done or GetTime() > cast.endsAt + 3) and true
			end })
			r:Sleep(4)
			local cast = ns.departCast
			r:Log(("the cast: %s, scene %s, done %s"):format(cast and cast.kind or "none", tostring(cast and cast.scene),
				tostring(cast and cast.done)))
			r:Verdict(shownDuring, "the portal showed during the cast (its scene playing)")
			r:Verdict(not ns.TeleportVisionShown(), "no portal 4 s after the cast")
			r:Verdict(Tooltip() >= 0.99, ("tooltip alpha %.2f (1 wanted)"):format(Tooltip()))
			local bar = _G.PlayerCastingBarFrame or _G.CastingBarFrame
			r:Verdict(not (bar and bar.cinematicTeleHidden), "cast bar not held faded")
			r:Verdict(cast ~= nil and cast ~= before and cast.done ~= nil, "a new cast seen, and marked over")
			r:Shot("4 s after the cast")
		end },
	},
})
