-- Platynator's ready recipe (Tools/addon-kit/addons/Platynator.md), for the
-- addon kit's stages and any Platynator test. What our support covers: its
-- plates, drawn on each game nameplate (Support/Platynator.lua). Ready = at
-- least one of its plates up. Plates come only with units near you, so the
-- recipe checks what code can read (its show options, the game's nameplate
-- settings) and the guide says where to stand. Nothing is changed by code:
-- its options are set through calls inside the addon (not global), and the
-- game's nameplate settings belong to the Nameplates page's rows. Dev copy only.
local _, ns = ...

local function Profile()
	local config = _G.PLATYNATOR_CONFIG
	if type(config) ~= "table" or type(config.Profiles) ~= "table" then return nil end
	local profile = config.Profiles[_G.PLATYNATOR_CURRENT_PROFILE or "DEFAULT"] or config.Profiles.DEFAULT
	return type(profile) == "table" and profile or nil
end

-- Its plate on a game plate: a child made from its plate template (as
-- Support/Platynator.lua finds them), shown.
local function PlatesUp()
	local plates = C_NamePlate and C_NamePlate.GetNamePlates
	local ok, list = pcall(plates or error)
	if not ok or type(list) ~= "table" then return 0 end
	local up = 0
	for _, plate in ipairs(list) do
		if ns.Reachable(plate) then
			for _, child in ipairs({ plate:GetChildren() }) do
				if ns.Reachable(child) and type(child.widgets) == "table" and child.kind ~= nil
					and type(child.SetUnit) == "function" and ns.Flag(child:IsShown()) then
					up = up + 1
					break
				end
			end
		end
	end
	return up
end

local function CVarOn(name)
	local ok, value = pcall(GetCVar, name)
	return ok and value == "1"
end

-- It has no on switch and no welcome: loaded, its plates take every game
-- plate. Which units get one is its "show nameplates" options, which it
-- writes into the game's nameplate settings at login, on loading screens and
-- after fights (Display/Initialize.lua:425).
ns.TestKit.DefineAddonReady("Platynator", {
	about = "at least one of its nameplates up",
	ready = function()
		if PlatesUp() > 0 then return true end
		local profile = Profile()
		if not profile then return false, "Platynator's settings aren't loaded yet" end
		local show = profile.show_nameplates
		if type(show) == "table" and not (show.enemy or show.friendlyNPC or show.friendlyPlayer) then
			return false, "its options show no nameplates at all (/platy, Behaviour)"
		end
		if not (CVarOn("nameplateShowEnemies") or CVarOn("nameplateShowFriends")
			or CVarOn("nameplateShowFriendlyNpcs") or CVarOn("nameplateShowFriendlyPlayers")) then
			return false, "the game's nameplates are off (the Nameplates page's rows, or the game's keys)"
		end
		return false, "no nameplate up: no unit near you"
	end,
	guide = {
		"Walk to within 20 yards of a few enemy mobs (out in the open, where mobs roam).",
		"No plates over them? Press V (the game's key for enemy nameplates).",
	},
})
