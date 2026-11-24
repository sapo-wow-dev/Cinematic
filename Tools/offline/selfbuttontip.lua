-- Your tooltip on Shoulder Cam's self-target stand-in (dev tool, offline, Lua
-- 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/selfbuttontip.lua < /dev/null
-- CinematicShoulderSelfButton (Camera/ShoulderCam.lua) sits over your player
-- frame while Keep the shoulder when selecting yourself is on. It had no
-- OnEnter, so hovering your portrait showed no tooltip (the mousewords run,
-- 2026-11-24). Its hover now shows your unit tooltip where the game puts a
-- unit's, and its leave or hide puts it away; its secure click attributes
-- stay as they were. Says PASS or FAIL per check.
-- (Optional first argument: another .toc to load, to run it on older code.)
dofile("Tools/offline/load.lua")("forever", arg and arg[1])

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

-- (A tooltip that remembers its owner, unit and shown state.)
local tip = _G.GameTooltip
local anchored
tip._shown = false
tip.SetOwner = function(self, owner) self._owner, self._unit = owner, nil end
tip.GetOwner = function(self) return self._owner end
tip.SetUnit = function(self, unit) self._unit = unit end
tip.Hide = function(self) self._shown, self._owner, self._unit = false, nil, nil end
rawset(_G, "GameTooltip_SetDefaultAnchor", function(t, owner) anchored = owner t:SetOwner(owner, "ANCHOR_NONE") end)

local button = _G.CinematicShoulderSelfButton
Check("the stand-in button is made", button ~= nil)
if not button then
	print("1 FAILED")
	return
end
local attrs = {}
local realSet = button.SetAttribute
button.SetAttribute = function(self, k, v) attrs[k] = v if realSet then realSet(self, k, v) end end

local enter, leave, hide = button:GetScript("OnEnter"), button:GetScript("OnLeave"), button:GetScript("OnHide")
Check("it has an OnEnter", type(enter) == "function")
Check("it has an OnLeave", type(leave) == "function")
Check("it has an OnHide", type(hide) == "function")
if enter then
	enter(button)
	Check("hover: your tooltip shown", tip._shown == true)
	Check("hover: owned by the button", tip:GetOwner() == button)
	Check("hover: of you", tip._unit == "player", tip._unit)
	Check("hover: at the game's default spot", anchored == button)
end
if leave then
	leave(button)
	Check("leave: tooltip put away", tip._shown == false)
end
-- (Someone else's tooltip up: left alone by our leave.)
local other = CreateFrame("Frame")
tip:SetOwner(other) tip:Show()
if leave then leave(button) end
Check("leave: another frame's tooltip left up", tip._shown == true and tip:GetOwner() == other)
if enter and hide then
	enter(button)
	hide(button)
	Check("hidden under the mouse: tooltip put away", tip._shown == false)
end
-- (Kept up to date while it stays: the tooltip calls its owner's
-- UpdateTooltip, as the game's unit frames have it; another's left alone.)
Check("it has an UpdateTooltip", type(button.UpdateTooltip) == "function")
if enter and button.UpdateTooltip then
	enter(button)
	tip._unit = nil
	button.UpdateTooltip(button)
	Check("update while hovered: of you again", tip._unit == "player", tip._unit)
	tip:SetOwner(other)
	tip._unit = "target"
	button.UpdateTooltip(button)
	Check("update with another's tooltip up: left alone", tip._unit == "target" and tip:GetOwner() == other)
end
Check("no secure attribute set by the hover", next(attrs) == nil, next(attrs))

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
