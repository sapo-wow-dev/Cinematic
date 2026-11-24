-- /cine debug flareui: FlareUI's target frame with ours (Support/FlareUI.lua).
-- Player report 2026-11-23: "the target frame is super glitchy" with both on.
-- In the Gamepad UI FlareUI keeps the game's TargetFrame shown at alpha 0 over
-- its own (the gamepad target menu needs it up); our Target row put it back to
-- full each time it came back, a frozen game frame over FlareUI's. It's left
-- alone now. Runs in either mode and says which; the Gamepad UI is the case
-- the fix is for (Forever decides it at login, from the gamepad in use).
-- Steps:
--   1 setup   FlareUI up, its target frame made; mode; how TargetFrame is kept
--   2 target  you target anything (skipped if you already have a target)
--   3 rows    hands off: the Target row hidden, then shown, then CineMode on
--             and off: TargetFrame stays invisible each time (gamepad), and
--             FlareUI's frame hides and comes back; a shot of each
-- Into CinematicDB.flareUISupportTestLog. Dev copy only.
local _, ns = ...

local function Gamepad()
	local style = _G.C_InputInterfaceStyle
	return style ~= nil and Enum.InputDeviceInterfaceType ~= nil
		and style.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad
end
local function Ours() return _G.FlareUI_UF_Target end
local function Game() return _G.TargetFrame end
-- How FlareUI keeps the game's frame: "kept" (gamepad: up at 0), "parked"
-- (hidden for good) or "its own" (FlareUI's target frame off).
local function Mode()
	local frame = Game()
	if not rawget(frame, "FlareUI_Hidden") then return "its own" end
	return ns.Flag(frame:IsShown()) and "kept" or "parked"
end

local function Fields(r, label)
	r:Fields(label, {
		gameShown = function() return Game():IsShown() end,
		gameVisible = function() return Game():IsVisible() end,
		gameAlpha = function() return Game():GetAlpha() end,
		gameEffective = function() return Game():GetEffectiveAlpha() end,
		gameFaded = function() return ns.IsFaded(Game()) end,
		leftAlone = function() return ns.IsLeftAlone("TargetFrame") end,
		flareShown = function() return Ours():IsShown() end,
		flareAlpha = function() return Ours():GetAlpha() end,
		flareEffective = function() return Ours():GetEffectiveAlpha() end,
		cineMode = function() return ns.IsCineModeOn and ns.IsCineModeOn() end,
	})
end

-- The game's frame drawn: only a problem while FlareUI keeps it.
local function GameDrawn()
	local alpha = Game():GetEffectiveAlpha()
	if issecretvalue and issecretvalue(alpha) then return nil end
	return ns.Flag(Game():IsVisible()) and alpha > 0.01
end
local function FlareAlpha()
	local alpha = Ours():GetEffectiveAlpha()
	if issecretvalue and issecretvalue(alpha) then return nil end
	return ns.Flag(Ours():IsVisible()) and alpha or 0
end

local function Force(state)
	ns.db.frameForce.target = state
	if ns.db.frameForceAt then ns.db.frameForceAt.target = state and GetTime() or nil end
	ns.RefreshFrameForce()
end

local function Check(r, label, flareUp)
	r:Sleep(1.5)
	Fields(r, label)
	if Mode() == "kept" then
		r:Verdict(GameDrawn() == false, label .. ": the game's TargetFrame stays invisible (FlareUI keeps it at 0)")
	end
	local alpha = FlareAlpha()
	if alpha == nil then
		r:Log(label .. ": FlareUI's alpha reads secret, not judged")
	elseif flareUp then
		r:Verdict(alpha > 0.3, ("%s: FlareUI's target frame up (%.2f)"):format(label, alpha))
	else
		r:Verdict(alpha < 0.05, ("%s: FlareUI's target frame hidden (%.2f)"):format(label, alpha))
	end
	r:Shot(label .. ": one target frame (FlareUI's) or none", { behind = Ours() })
end

ns.TestKit.Define({
	name = "flareui",
	key = "flareUISupportTest",
	title = "FlareUI target frame",
	about = "FlareUI's target frame fades with the Target row; the game's one it keeps in the Gamepad UI stays invisible",
	needs = "FlareUI on (Gamepad UI for the reported case: log in with the gamepad in use)",
	-- (The kit turns CineMode off as it comes on: the rows step turns it on
	-- and off itself, and putBack puts it back.)
	cineMode = true,
	context = function()
		return ("FlareUI up: %s, its target frame: %s, Gamepad UI: %s, TargetFrame: %s, left alone: %s"):format(
			tostring(ns.AddonUp("FlareUI")), tostring(Ours() ~= nil), tostring(Gamepad()),
			Ours() and Mode() or "?", tostring(ns.IsLeftAlone("TargetFrame")))
	end,
	putBack = function(extra)
		Force(extra.forceWas ~= "<nil>" and extra.forceWas or nil)
		if ns.IsCineModeOn and Cinematic_ToggleCineMode and extra.cineWas ~= nil
			and (ns.IsCineModeOn() and true or false) ~= extra.cineWas then
			Cinematic_ToggleCineMode()
		end
		return "Target row and CineMode as they were"
	end,
	steps = {
		{ key = "setup", title = "FlareUI and how it keeps TargetFrame", run = function(r)
			if not ns.AddonUp("FlareUI") or not Ours() then
				r:Fail("FlareUI isn't loaded, or its target frame is off: turn it on and run again")
				return
			end
			r:Keep("forceWas", ns.db.frameForce.target or "<nil>")
			r:Keep("cineWas", ns.IsCineModeOn and ns.IsCineModeOn() and true or false)
			local mode = Mode()
			r:Log(("Gamepad UI %s; FlareUI's TargetFrame: %s"):format(tostring(Gamepad()), mode))
			Fields(r, "at start")
			if mode == "kept" then
				r:Verdict(ns.IsLeftAlone("TargetFrame") and not ns.IsFaded(Game()),
					"the kept TargetFrame is left alone by us")
				r:Verdict(GameDrawn() == false, "the kept TargetFrame is invisible now")
			else
				r:Log("not the Gamepad UI case (TargetFrame " .. mode .. "): the reported bug can't show;"
					.. " log in with the gamepad in use to test it")
				r:Verdict(not ns.IsLeftAlone("TargetFrame"), "TargetFrame not left alone (only the kept one is)")
			end
		end },
		{ key = "target", title = "a target", run = function(r)
			if not Ours() then r:Skip("no FlareUI target frame") return end
			if not UnitExists("target") then
				r:WaitFor("Target anything (an NPC, a player, yourself).", { check = function() return UnitExists("target") end })
			end
			r:Log("target: " .. tostring(UnitName("target")))
		end },
		{ key = "rows", title = "Target row hidden, shown; CineMode on, off (hands off)", seconds = 14, run = function(r)
			if not Ours() then r:Skip("no FlareUI target frame") return end
			if ns.IsCineModeOn and ns.IsCineModeOn() then Cinematic_ToggleCineMode() end
			Force("hide")
			Check(r, "Target row hidden", false)
			Force("show")
			Check(r, "Target row shown", true)
			Force(nil)
			if Cinematic_ToggleCineMode then
				Cinematic_ToggleCineMode()
				r:Sleep(1)
				Fields(r, "CineMode on")
				if Mode() == "kept" then
					r:Verdict(GameDrawn() == false, "CineMode on: the game's TargetFrame stays invisible")
				end
				r:Shot("CineMode on", { behind = Ours() })
				Cinematic_ToggleCineMode()
				Check(r, "CineMode off again", true)
			end
		end },
	},
})
