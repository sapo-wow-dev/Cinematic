-- Quality of life's AddOns list on All (addonListAll, "Default Addon list
-- opening to All"): the game's AddOns window opens on your character in game
-- ("All" only at character select, by Blizzard's design: Blizzard_AddOnList's
-- addonCharacter). With it on, the first time the window opens after a login
-- or reload it's on All, through the game's own AddonList_ClearCharacterDropdown.
-- Pick your character and it stays till the next reload, as the game's own pick
-- does. Off for players, on in the dev copy (Core.lua DEFAULTS).
--
-- Nothing else: the window's own Okay / Reload UI saves your ticks and reloads.
-- (Until 2026-11-21 a secure /reload lay over Reload UI on Forever, for fear
-- the All we write blocked its reload. It never was (shouldReload stays
-- secure, /cine debug addonlist), and the cover's save, run from our code, was
-- dropped by the game: no tick was ever saved, the reload brought them all
-- back.) (/cine debug addonlist)

local _, ns = ...

local cleared  -- this load's window was put on All by us
local hooked

local function Shown(list)
	if cleared or not ns.db or not ns.Setting("addonListAll") then return end
	if type(AddonList_ClearCharacterDropdown) ~= "function" then return end
	cleared = true
	xpcall(AddonList_ClearCharacterDropdown, geterrorhandler())
	-- (The dropdown's words come from its menu: made again to say All.)
	local dropdown = list.Dropdown
	if dropdown and dropdown.GenerateMenu then xpcall(function() dropdown:GenerateMenu() end, geterrorhandler()) end
	if AddonList_Update then xpcall(AddonList_Update, geterrorhandler()) end
end

local function Hook()
	local list = _G.AddonList
	if hooked or not (list and list.HookScript) then return end
	hooked = true
	list:HookScript("OnShow", Shown)
	if list:IsShown() then Shown(list) end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("ADDON_LOADED")
watcher:SetScript("OnEvent", Hook)

-- (The test's: what this load did, and a fresh start for its run.)
function ns.AddonListAllState()
	return { cleared = cleared, hooked = hooked }
end
function ns.AddonListAllRestart()
	cleared = nil
end
