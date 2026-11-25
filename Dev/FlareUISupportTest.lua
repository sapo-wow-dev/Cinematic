-- /cine debug flareui: FlareUI's target frame with ours (Support/FlareUI.lua).
-- Player report 2026-11-23: "the target frame is super glitchy" with both on.
-- In the Gamepad UI FlareUI keeps the game's TargetFrame shown at alpha 0 over
-- its own (the gamepad target menu needs it up); our Target row put it back to
-- full each time it came back, a frozen game frame over FlareUI's. It's left
-- alone now. Runs in either mode and says which; the Gamepad UI is the case
-- the fix is for (Forever decides it at login, from the gamepad in use).
-- Steps:
--   0 solo    FlareUI alone with Cinematic (a Reload), if it isn't loaded
--   1 setup   FlareUI up, its target frame made (its ready recipe below: you
--             turn Unit Frames on if it's off); mode; how TargetFrame is kept
--   2 target  you target anything (skipped if you already have a target)
--   3 rows    hands off: the Target row hidden, then shown, then CineMode on
--             and off: TargetFrame stays invisible each time (gamepad), and
--             FlareUI's frame hides and comes back; a shot of each
--   4 own     hands off: its frames the addon test can't see up (buff
--             reminders, loot feed, flag carriers, the box behind the event
--             boxes: each made only when its option is on, or in a
--             battleground): each one made is shown, its row hidden, then
--             shown, and put back. (2026-11-25, the addon kit's first run.)
--   5 back    your addon list back (a Reload), if step 0 changed it
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

-- Its frames that fade by a row of their own, or with a game frame the addon
-- test seldom sees: the row's key (as frameForce has it) and the frame.
local OWN = {
	{ "addon:flareReminders", "FlareUI_BuffReminders" },
	{ "addon:flareLootFeed", "FlareUI_LootFeed" },
	{ "flags", "FlareUI_FlagCarriers" },
	{ "topcenter", "FlareUI_BattlegroundObjectivesBox" },
}

local function ForceRow(key, state)
	ns.db.frameForce[key] = state
	if ns.db.frameForceAt then ns.db.frameForceAt[key] = state and GetTime() or nil end
	ns.RefreshFrameForce()
end

local function Effective(frame)
	local alpha = frame:GetEffectiveAlpha()
	if issecretvalue and issecretvalue(alpha) then return nil end
	return alpha
end

-- One of OWN: shown if it wasn't (out of fights: some hold secure buttons),
-- its row hidden then shown, and all of it put back.
local function CheckOwn(r, key, name)
	local frame = _G[name]
	if not frame then
		r:Skip(name .. " not made (its option is off in FlareUI, or not in a battleground)")
		return
	end
	local wasShown = ns.Flag(frame:IsShown())
	if not wasShown then frame:Show() end
	local own = frame:GetAlpha()
	r:Sleep(0.5)
	r:Log(("%s: shown before %s, its own alpha %s, faded by us %s"):format(name, tostring(wasShown),
		tostring(own), tostring(ns.IsFaded(frame))))
	ForceRow(key, "hide")
	r:Sleep(1.5)
	local hidden = Effective(frame)
	if hidden == nil then
		r:Log(name .. ": alpha reads secret, not judged")
	else
		r:Verdict(hidden < 0.05, ("%s: hidden by its row %s (%.2f)"):format(name, key, hidden))
	end
	r:Shot(name .. " hidden by " .. key, { behind = frame })
	ForceRow(key, "show")
	r:Sleep(1.5)
	local back = Effective(frame)
	if back ~= nil and type(own) == "number" and not (issecretvalue and issecretvalue(own)) then
		if own < 0.05 then
			r:Log(("%s: its own alpha is %.2f (faded by FlareUI itself): coming back not judged"):format(name, own))
		else
			r:Verdict(back > 0.3, ("%s: back with its row shown (%.2f)"):format(name, back))
		end
	end
	if not wasShown then frame:Hide() end
end

-- Ready for a test: its unit frames made (Tools/addon-kit/addons/FlareUI.md).
-- Every FlareUI module starts off, and one only starts at login, so turning
-- Unit Frames on takes a reload: the recipe closes its tour (or welcome) and
-- opens its window on that page, and the guide is the clicks. Its other pages
-- (buffs, quest tracker, XP bar...) aren't needed: rows with no frame are
-- just untested, and battleground frames are the "own" step's business.
local function FlareDB()
	local flare = _G.FlareUI
	return type(flare) == "table" and type(flare.db) == "table" and flare.db or nil
end
local function FlareGamepadUI()
	local flare = _G.FlareUI
	return type(flare) == "table" and type(flare.IsGamepadUI) == "function" and flare.IsGamepadUI() or false
end
local function FlarePanel()
	local flare = _G.FlareUI
	local panel = type(flare) == "table" and flare.SettingsPanel
	return type(panel) == "table" and panel or nil
end
local function Welcome()
	for _, name in ipairs({ "FlareUI_Tour", "FlareUI_Welcome" }) do
		local frame = _G[name]
		if frame and ns.Flag(frame:IsShown()) then return frame end
	end
end

ns.TestKit.DefineAddonReady("FlareUI", {
	about = "its Unit Frames page on: its player and target frames made, its tour closed",
	ready = function()
		local db = FlareDB()
		if not (db and type(db.profile) == "table") then return false, "its settings didn't load" end
		if Welcome() then return false, "its setup tour (or welcome) is open" end
		if not (_G.FlareUI_UF_Player and _G.FlareUI_UF_Target) then
			local uf = db.profile.unitframes
			local on = type(uf) == "table" and uf.enabled
			return false, on and "Unit Frames on but no frames yet (a reload pending, or its frames' own switch off)"
				or "its Unit Frames page is off"
		end
		return true
	end,
	make = function(r)
		if InCombatLockdown() then r:Log("FlareUI setup: in a fight, left alone") return end
		local db = FlareDB()
		local tour = Welcome()
		if tour and db and type(db.global) == "table" then
			-- (Closing it marks it seen: put back after.)
			r:Keep("flare:welcomeSeen", db.global.welcomeSeen == nil and "<nil>" or db.global.welcomeSeen)
			tour:Hide()
			r:Log("closed FlareUI's " .. tour:GetName())
		end
		local panel = FlarePanel()
		if not (_G.FlareUI_UF_Player and _G.FlareUI_UF_Target) and panel and panel.Open and not FlareGamepadUI() then
			-- (Not in the Gamepad UI: FlareUI says code opening its window there can hang the game.)
			r:Keep("flare:panelOpened", true)
			pcall(panel.Open, panel, "uf")
			r:Log("opened FlareUI's window on its Unit Frames page")
		end
	end,
	putBack = function(extra)
		local done = {}
		local panel = FlarePanel()
		if extra["flare:panelOpened"] and panel and panel.IsShown and panel.Hide and not InCombatLockdown()
			and panel:IsShown() then
			pcall(panel.Hide, panel)
			done[#done + 1] = "its window closed"
		end
		local was = extra["flare:welcomeSeen"]
		local db = FlareDB()
		if was ~= nil and db and type(db.global) == "table" then
			if was == "<nil>" then was = nil end
			db.global.welcomeSeen = was
			done[#done + 1] = "its tour's seen mark as it was"
		end
		if #done > 0 then return "FlareUI: " .. table.concat(done, ", ") end
	end,
	guide = {
		"Window not open? Click the minimap's addon button, then FlareUI.",
		"In FlareUI's window, click Unit Frames on the left.",
		"Click Turn On.",
		"Click Reload Now at the bottom of FlareUI's window.",
		"Click Reload Now in the box that opens.",
	},
})

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
		for _, each in ipairs(OWN) do
			local was = extra["force:" .. each[1]]
			if was ~= nil then ForceRow(each[1], was ~= "<nil>" and was or nil) end
		end
		if ns.IsCineModeOn and Cinematic_ToggleCineMode and extra.cineWas ~= nil
			and (ns.IsCineModeOn() and true or false) ~= extra.cineWas then
			Cinematic_ToggleCineMode()
		end
		return "Target row and CineMode as they were"
	end,
	steps = {
		-- (FlareUI alone with Cinematic: the queue runs it after the addon kit
		-- has put your list back, without FlareUI, 2026-11-25. As the kit's
		-- solo stages, with a Reload; the last step puts the list back.)
		{ key = "solo", title = "FlareUI alone with Cinematic", run = function(r)
			if ns.AddonUp("FlareUI") then r:Log("FlareUI already loaded") return end
			if not ns.SoloAddons then r:Fail("no /cine debug solo here (dev copy only)") return end
			if type(CinematicDB.soloAddons) == "table" then ns.SoloAddons("off", true) end
			ns.SoloAddons("FlareUI", true)
			CinematicDB.flareUITestSolo = true
			r:Log("solo for FlareUI: " .. table.concat(CinematicDB.soloAddons and CinematicDB.soloAddons.keep or {}, ", "))
			r:WaitFor("Reload, for FlareUI alone with Cinematic",
				{ check = function() return false end, buttons = { { kind = "reload" } } })
		end },
		{ key = "setup", title = "FlareUI and how it keeps TargetFrame", run = function(r)
			if ns.AddonUp("FlareUI") then r:AddonReady("FlareUI") end
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
		{ key = "own", title = "its own rows and battleground frames (hands off)", seconds = 16, run = function(r)
			if not ns.AddonUp("FlareUI") then r:Skip("FlareUI isn't loaded") return end
			if InCombatLockdown() then r:Skip("in a fight: its frames hold secure buttons") return end
			for _, each in ipairs(OWN) do
				local before = ns.db.frameForce[each[1]]
				r:Keep("force:" .. each[1], before or "<nil>")
				CheckOwn(r, each[1], each[2])
				ForceRow(each[1], before)
				r:Log(("%s: row put back (forced %s before)"):format(each[1], tostring(before)))
			end
		end },
		{ key = "back", title = "your addon list back", run = function(r)
			if not CinematicDB.flareUITestSolo then r:Log("FlareUI was loaded already: list left as it was") return end
			CinematicDB.flareUITestSolo = nil
			ns.SoloAddons("off", true)
			r:Log("addon list put back")
			r:WaitFor("Reload, to get your addons back",
				{ check = function() return false end, buttons = { { kind = "reload" } } })
		end },
		-- (A step after the last Reload, so the run picks up and ends DONE at
		-- login, not cut off: as the addon kit's done step.)
		{ key = "done", title = "done", run = function(r)
			r:Log("addons now: " .. (ns.AddonUp("FlareUI") and "FlareUI still loaded" or "your list"))
		end },
	},
})
