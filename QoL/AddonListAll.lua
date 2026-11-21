-- Quality of life's AddOns list on All (addonListAll): the game's AddOns
-- window opens on your character in game ("All" only at character select, by
-- Blizzard's design: Blizzard_AddOnList's addonCharacter). With it on, the
-- first time the window opens after a login or reload it's on All, through the
-- game's own AddonList_ClearCharacterDropdown. Pick your character and it stays
-- till the next reload, as the game's own pick does. Off for players, on in the
-- dev copy (Core.lua DEFAULTS).
--
-- Forever: "All" written by our code is tainted, the window's Reload UI reads
-- it (AddonList_Update's AddonList_HasAnyChanged sets shouldReload, which
-- AddonList_OnOkay reads before ReloadUI), and Forever blocks a tainted
-- ReloadUI (QoL/Reload.lua). So there, while that button says Reload UI, a
-- secure /reload button lies over it: its PreClick closes the window saving
-- the ticks (AddonList_Hide(true): its OnHide's C_AddOns.SaveAddOns), then the
-- macro reloads. Laid by screen position from UIParent, as Reload.lua's popup
-- cover (Forever won't anchor a secure frame to the window's button), and off
-- for fights. (/cine debug addonlist)

local _, ns = ...

local cleared  -- this load's window was put on All by us
local hooked, cover, ticker

-- The window's Reload UI showing (a tick changed since it opened).
local function Reloads(list)
	local okay = list.OkayButton
	if not (okay and okay:IsShown()) then return false end
	if list.shouldReload then return true end
	local ok, text = pcall(okay.GetText, okay)
	return ok and RELOADUI ~= nil and text == RELOADUI
end

local function Place(target)
	local ok, left, bottom, width, height, scale = pcall(function()
		return target:GetLeft(), target:GetBottom(), target:GetWidth(), target:GetHeight(),
			target:GetEffectiveScale() / UIParent:GetEffectiveScale()
	end)
	if not (ok and left and bottom and width and height) then return false end
	left, bottom, width, height = left * scale, bottom * scale, width * scale, height * scale
	local at = cover.placedAt
	if at and at[1] == left and at[2] == bottom and at[3] == width and at[4] == height then return true end
	cover.placedAt = { left, bottom, width, height }
	cover:ClearAllPoints()
	cover:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
	cover:SetSize(width, height)
	return true
end

local function UpdateCover()
	if InCombatLockdown() then return end
	local list = _G.AddonList
	local want = cleared and ns.reloadBlocked and list and list:IsShown() and Reloads(list)
	if not want then
		if cover and cover:IsShown() then cover:Hide() end
		return
	end
	if not cover then
		if not ns.SecureReloadButton then return end
		cover = ns.SecureReloadButton("CinematicAddonListReload", UIParent)
		cover:SetFrameStrata("FULLSCREEN_DIALOG")
		cover:Hide()
		cover:SetScript("PreClick", function()
			if ns.ReloadSave then ns.ReloadSave() end
			if SOUNDKIT and SOUNDKIT.GS_LOGIN_CHANGE_REALM_OK then PlaySound(SOUNDKIT.GS_LOGIN_CHANGE_REALM_OK) end
			if AddonList_Hide then
				xpcall(function() AddonList_Hide(true) end, geterrorhandler())
			elseif _G.AddonList then
				_G.AddonList:Hide()
			end
		end)
		cover:SetScript("OnEnter", function(self) if self.target then self.target:LockHighlight() end end)
		cover:SetScript("OnLeave", function(self) if self.target then self.target:UnlockHighlight() end end)
	end
	cover.target = list.OkayButton
	if not Place(cover.target) then
		if cover:IsShown() then cover:Hide() end
		return
	end
	cover:SetFrameLevel(math.min(list:GetFrameLevel() + 20, 9000))
	if not cover:IsShown() then cover:Show() end
end

local function StopTicker()
	if ticker then
		ticker:Cancel()
		ticker = nil
	end
end

local function Shown(list)
	if not cleared and ns.db and ns.Setting("addonListAll") and type(AddonList_ClearCharacterDropdown) == "function" then
		cleared = true
		xpcall(AddonList_ClearCharacterDropdown, geterrorhandler())
		-- (The dropdown's words come from its menu: made again to say All.)
		local dropdown = list.Dropdown
		if dropdown and dropdown.GenerateMenu then xpcall(function() dropdown:GenerateMenu() end, geterrorhandler()) end
		if AddonList_Update then xpcall(AddonList_Update, geterrorhandler()) end
	end
	-- (Every 0.2 s while it's open: its button's words change with your
	-- ticks, and the window can be dragged.)
	if cleared and ns.reloadBlocked and not ticker then
		ticker = C_Timer.NewTicker(0.2, function()
			if not (_G.AddonList and _G.AddonList:IsShown()) then StopTicker() end
			UpdateCover()
		end)
	end
	UpdateCover()
end

local function Hook()
	local list = _G.AddonList
	if hooked or not (list and list.HookScript) then return end
	hooked = true
	list:HookScript("OnShow", Shown)
	list:HookScript("OnHide", function()
		StopTicker()
		UpdateCover()
	end)
	if list:IsShown() then Shown(list) end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
watcher:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		-- (Just before the lockdown: a secure frame can't be hidden in it.)
		if cover and cover:IsShown() then cover:Hide() end
	elseif event == "PLAYER_REGEN_ENABLED" then
		UpdateCover()
	else
		Hook()
	end
end)

-- (The test's: what this load did, and a fresh start for its run.)
function ns.AddonListAllState()
	return { cleared = cleared, hooked = hooked, cover = cover }
end
function ns.AddonListAllRestart()
	cleared = nil
	StopTicker()
	UpdateCover()
end
