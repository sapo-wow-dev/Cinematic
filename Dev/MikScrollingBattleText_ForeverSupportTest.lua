-- MSBT Forever's ready recipe (Support/MikScrollingBattleText.lua, which
-- waits for this folder name): no test of its own yet. All its text draws on
-- one frame, MSBTAnimationFrame, shown only while a line is moving
-- (Tools/addon-kit/addons/MikScrollingBattleText_Forever.md). Dev copy only.
local _, ns = ...

local function Profiles()
	local msbt = rawget(_G, "MikSBT")
	local profiles = type(msbt) == "table" and msbt.Profiles
	return type(profiles) == "table" and profiles or nil
end

-- Ready: its settings loaded and the addon on. Turned off, the recipe turns
-- it on as /msbt enable does (which also switches its "Blizzard damage"
-- option off: both put back after), then shows a line in Incoming and one
-- in Outgoing (its public DisplayMessage), so its frame is up for a moment.
ns.TestKit.DefineAddonReady("MikScrollingBattleText_Forever", {
	about = "turned on (its text shows as you hit or get hit)",
	ready = function()
		local profiles = Profiles()
		if not (profiles and profiles.savedVariables and profiles.currentProfile) then
			return false, "its settings aren't loaded yet"
		end
		if not rawget(_G, "MSBTAnimationFrame") then return false, "its text frame isn't made" end
		local ok, off = pcall(profiles.IsModDisabled)
		return ok and not off, "it's turned off (/msbt disable)"
	end,
	make = function(r)
		local profiles = Profiles()
		if not (profiles and profiles.savedVariables and type(profiles.SetOptionUserDisabled) == "function") then return end
		local ok, off = pcall(profiles.IsModDisabled)
		if ok and off then
			local profile = profiles.currentProfile
			r:Keep("mikScrollingBattleTextWasOff", true)
			r:Keep("mikScrollingBattleTextBlizzardDamage", type(profile) == "table" and profile.blizzardDamageEnabled == true)
			pcall(profiles.SetOptionUserDisabled, false)
			r:Log("turned MSBT on (as /msbt enable does)")
		end
		local show = rawget(_G, "MikSBT").DisplayMessage
		if type(show) == "function" then
			pcall(show, "Cinematic test: incoming", "Incoming", false, 255, 80, 80)
			pcall(show, "Cinematic test: outgoing", "Outgoing", false, 255, 255, 255)
			r:Log("two MSBT test lines on screen")
		end
	end,
	putBack = function(extra)
		local profiles = Profiles()
		if not (extra.mikScrollingBattleTextWasOff and profiles and type(profiles.SetOptionUserDisabled) == "function") then
			return
		end
		pcall(profiles.SetOptionUserDisabled, true)
		if extra.mikScrollingBattleTextBlizzardDamage == true and type(profiles.SetOption) == "function" then
			pcall(profiles.SetOption, nil, "blizzardDamageEnabled", true)
		end
		return "MSBT turned off again"
	end,
})
