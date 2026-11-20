-- /cine debug shoulder selffront: Keep the shoulder when selecting yourself
-- (shoulderCamFakeSelf, ShoulderCam.lua) right after it's ticked, with no
-- /reload (user 2026-11-20, 15:17: ticked, then six clicks on the player
-- frame selected them anyway, fine after a /reload; the log had our button
-- over the frame, level 51 to its 1, and the mouse on PlayerFrame). The
-- cause tried here: your player frame is toplevel, so a click on it while the
-- option's off brings it in front of every frame of its strata, whatever
-- their levels, till a /reload; ours, placed after, stays behind it.
-- One run, CineMode off for it (put back), your option put back at the end:
--   1 raise   the option off: you left-click your player frame (it selects
--             you: fine), as before ticking it
--   2 cause   the option on, with ours kept from coming in front
--             (ns.shoulderSelfHoldFront): you hover your frame; what the game
--             says is under the mouse. PlayerFrame = the cause shown
--   3 fix     ours let come in front, still hovering: under the mouse ours
--             now (PASS/FAIL)
--   4 click   an NPC targeted, a left-click on your frame: target cleared,
--             not you (PASS/FAIL)
-- Into CinematicDB.shoulderSelfFront. Dev copy only.
local _, ns = ...

local run

local function Text(value)
	local ok, text = pcall(tostring, value)
	return ok and text or "?"
end
local function Write(text)
	local lines = ns.db.shoulderSelfFront
	if #lines < 2000 then lines[#lines + 1] = ("%.2f %s"):format(GetTime() - run.began, text) end
end
local function Box(head, line) ns.PadTestBox(head, line, 1, 0.82, 0) end
local function Self() return UnitExists("target") and ns.Flag(UnitIsUnit("target", "player")) end
local function Other() return UnitExists("target") and not Self() end
local function Button() return (ns.ShoulderFakeSelfState and ns.ShoulderFakeSelfState() or {}).button end
local function CineOn() return ns.IsCineModeOn and ns.IsCineModeOn() and true or false end
local function SetCine(on)
	if CineOn() ~= on and _G.Cinematic_ToggleCineMode then _G.Cinematic_ToggleCineMode() end
end
local function Name(frame)
	if not frame then return "the world" end
	return Text(frame.GetDebugName and frame:GetDebugName() or frame.GetName and frame:GetName())
end
-- (On your frame or a part of it.)
local function OnFrame(focus)
	local frame = _G.PlayerFrame
	for _ = 1, 6 do
		if not focus then return false end
		if focus == frame then return true end
		focus = focus.GetParent and focus:GetParent()
	end
	return false
end
local function Levels()
	local frame, button = _G.PlayerFrame, Button()
	return ("your frame %s %d%s, ours %s %d%s shown %s"):format(frame:GetFrameStrata(), frame:GetFrameLevel(),
		frame:IsToplevel() and " toplevel" or "", button and button:GetFrameStrata() or "?",
		button and button:GetFrameLevel() or -1, button and button:IsToplevel() and " toplevel" or "",
		Text(button and button:IsShown()))
end
-- (The mouse inside our button's place, by the cursor: not by the game's
-- focus, which is what's tested.)
local function InOurs()
	local button = Button()
	if not (button and button:IsShown() and button:GetLeft()) then return false end
	local x, y = GetCursorPosition()
	local k = button:GetEffectiveScale()
	x, y = x / k, y / k
	return x >= button:GetLeft() and x <= button:GetRight() and y >= button:GetBottom() and y <= button:GetTop()
end

local function End(why)
	if not run then return end
	run.frame:SetScript("OnUpdate", nil)
	run.frame:UnregisterAllEvents()
	ns.shoulderSelfHoldFront = nil
	ns.db.shoulderCamFakeSelf = run.yours
	SetCine(run.cine)
	Write(("end: %s; your option back to %s, CineMode back %s"):format(why, Text(run.yours), Text(run.cine)))
	Write("verdicts: " .. table.concat(run.verdicts, "; "))
	ns.Log("shoulder", ("selffront: %s; %s"):format(why, table.concat(run.verdicts, "; ")))
	run = nil
end

local function Verdict(text)
	run.verdicts[#run.verdicts + 1] = text
	Write(text)
end

local function Tick(_, elapsed)
	run.clock = run.clock + elapsed
	if run.phase == "raise" then
		if not run.raised then return end
		if run.clock - run.raised < 1 then return end
		Write("after the click on your frame: " .. Levels())
		ns.shoulderSelfHoldFront = true
		ns.db.shoulderCamFakeSelf = true
		Write("option on (no reload), ours held from coming in front")
		run.phase, run.clock = "arming", 0
		Box("Self front 2/4", "hands off a moment")
	elseif run.phase == "arming" then
		if run.clock < 1.5 then return end
		local state = ns.ShoulderFakeSelfState()
		Write(("armed: want %s (%s), covered %s; %s"):format(Text(state.want), Text(state.why), Text(state.covered),
			Levels()))
		if not state.covered then
			Verdict("cause UNSURE: the option didn't cover your frame (" .. Text(state.why) .. ")")
			End("not armed")
			ns.PadTestBox("Self front run done", "/reload, then say check log", 0.3, 1, 0.3)
			return
		end
		run.phase, run.clock, run.inside = "cause", 0, nil
		Box("Self front 2/4", "HOVER YOUR PLAYER FRAME, don't click, and keep the mouse there")
	elseif run.phase == "cause" or run.phase == "fix" then
		if not InOurs() then run.inside = nil return end
		run.inside = run.inside or run.clock
		if run.clock - run.inside < (run.phase == "cause" and 0.5 or 0.8) then return end
		local focus = ns.MouseFocus and ns.MouseFocus()
		local button = Button()
		if run.phase == "cause" then
			local front = OnFrame(focus)
			Verdict(("cause %s: under the mouse %s; %s"):format(front and "SHOWN (your frame in front of ours)"
				or (focus == button and "NOT SHOWN (ours in front without the fix)") or "UNSURE", Name(focus), Levels()))
			ns.shoulderSelfHoldFront = nil
			Write("ours let come in front")
			run.phase, run.inside = "fix", nil
			Box("Self front 3/4", "KEEP HOVERING YOUR PLAYER FRAME")
		else
			Verdict(("fix %s: under the mouse %s; %s"):format(focus == button and "PASS" or "FAIL", Name(focus), Levels()))
			run.phase, run.clock = "wantOther", 0
			Box("Self front 4/4", "TARGET ANY NPC OR CREATURE (Tab or click it)")
		end
	elseif run.phase == "wantOther" then
		if not Other() then run.clock = 0 return end
		if run.clock < 1 then return end
		run.phase, run.clock, run.click = "wantClick", 0, nil
		Write("asking for the click, target " .. Text(UnitName("target")))
		Box("Self front 4/4", "LEFT-CLICK YOUR PLAYER FRAME")
	elseif run.phase == "wantClick" then
		if not run.click then return end
		if run.clock - run.click < 1.2 then return end
		Verdict(("click %s; %s"):format(Self() and "FAIL: you got selected" or UnitExists("target")
			and ("FAIL: still " .. Text(UnitName("target"))) or "PASS: target cleared", Levels()))
		End("done")
		ns.PadTestBox("Self front run done", "/reload, then say check log", 0.3, 1, 0.3)
		C_Timer.After(15, function() if not run then ns.PadTestBoxHide() end end)
	end
end

local function OnEvent(_, event, button)
	if not run then return end
	if event == "PLAYER_TARGET_CHANGED" then
		Write(("target changed: %s, under the mouse %s"):format(Self() and "you" or UnitExists("target")
			and Text(UnitName("target")) or "none", Name(ns.MouseFocus and ns.MouseFocus())))
		return
	end
	if button ~= "LeftButton" then return end
	local focus = ns.MouseFocus and ns.MouseFocus()
	if run.phase == "raise" and not run.raised then
		Write(("left-click: under the mouse %s; %s"):format(Name(focus), Levels()))
		if OnFrame(focus) then run.raised = run.clock end
	elseif run.phase == "wantClick" and not run.click then
		Write(("left-click: under the mouse %s; %s"):format(Name(focus), Levels()))
		run.click = run.clock
	end
end

function ns.ShoulderSelfFront()
	if run then
		End("stopped")
		ns.PadTestBoxHide()
		return ns.Print("shoulder selffront: stopped")
	end
	if InCombatLockdown() then return ns.Print("shoulder selffront: out of combat, please") end
	if ns.isRetail then return ns.Print("shoulder selffront: the option is WoW Forever only") end
	if not ns.Setting("shoulderCam") then return ns.Print("shoulder selffront: turn on the Shoulder Cam first") end
	ns.db.shoulderSelfFront = {}
	run = { frame = CreateFrame("Frame"), began = GetTime(), clock = 0, verdicts = {}, phase = "raise",
		yours = ns.db.shoulderCamFakeSelf, cine = CineOn() }
	Write(("start | game %s | your option %s | CineMode %s | Settings open %s"):format(Text(select(4, GetBuildInfo())),
		Text(run.yours), Text(run.cine), Text(type(_G.SettingsPanel) == "table" and _G.SettingsPanel:IsShown())))
	SetCine(false)
	ns.db.shoulderCamFakeSelf = false
	Write("option off, CineMode off; " .. Levels())
	run.frame:RegisterEvent("GLOBAL_MOUSE_DOWN")
	run.frame:RegisterEvent("PLAYER_TARGET_CHANGED")
	run.frame:SetScript("OnEvent", OnEvent)
	run.frame:SetScript("OnUpdate", Tick)
	Box("Self front 1/4", "LEFT-CLICK YOUR PLAYER FRAME (it selects you: fine)")
	ns.Print("shoulder selffront: follow the box; type it again to stop")
end

-- (Its word on /cine debug shoulder, without a line in ShoulderCamTest.lua's list.)
local base = ns.ShoulderTest
if base then
	function ns.ShoulderTest(arg)
		if type(arg) == "string" and arg:match("^selffront%s*$") then return ns.ShoulderSelfFront() end
		return base(arg)
	end
end
