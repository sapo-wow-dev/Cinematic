-- Cinematic: the dressing room beside the Auction House (ahDressUp, on the
-- Quality of life page; WoW Forever only). Ctrl+Click on an auction shows
-- the item on you in a small dressing room docked to the Auction House's
-- right edge, and the Auction House stays open.
--
-- Why the game closes it: the Auction House is a doublewide panel whose
-- showFailedFunc ends the AH, and the Dressing Room (DressUpFrame) a left
-- one; when both don't fit on the screen the panel manager pushes the AH out.
-- The game already has the piece that fixes it, SideDressUpFrame (Mainline
-- DressUpFrames.xml, loads on Forever, the old AH dressing room art): docked
-- to a frame with SetUpSideDressUpFrame, every dress-up goes there while that
-- frame is shown (GetFrameAndSetBackground), and it's no panel of its own.
-- Blizzard docks it for Recruit-a-Friend only.
--
-- Not in a fight: undocked when one starts (dress-ups then open the usual
-- Dressing Room), docked again after. /cine debug ahdress tests it.
local _, ns = ...

if ns.isRetail then
	return
end

local docked -- we docked SideDressUpFrame to the AH (and haven't undocked)

local function AH()
	local frame = AuctionHouseFrame
	return type(frame) == "table" and frame.IsShown and frame or nil
end

local function Side()
	local frame = SideDressUpFrame
	return type(frame) == "table" and frame.IsShown and frame or nil
end

-- What the game's dress-up needs from the frame and Forever's lacks: with
-- class backgrounds off (Camelot's DressUpFramesOverrides.lua),
-- SetDressUpBackground hides frame.ModelBackground, which only DressUpFrame
-- has: every dress-up into SideDressUpFrame errored there
-- (DressUpFrames.lua:316, /cine debug ahdress 2026-11-23) before showing it.
-- It gets a hidden one, and the race backdrop the game would have set
-- (it looks for BGTopLeft on the ModelScene, the side frame has them on itself).
local fitted
local function Fit(side)
	if fitted then
		return
	end
	fitted = true
	if not side.ModelBackground then
		local blank = side:CreateTexture(nil, "BACKGROUND")
		blank:Hide()
		side.ModelBackground = blank
	end
	local path = type(DressUpTexturePath) == "function" and DressUpTexturePath(select(2, UnitRace("player")))
	if path then
		if side.BGTopLeft then side.BGTopLeft:SetTexture(path .. 1) end
		if side.BGBottomLeft then side.BGBottomLeft:SetTexture(path .. 3) end
	end
end

local function Ready()
	return Side() and AH() and type(SetUpSideDressUpFrame) == "function" and true or false
end

-- Docks the side dressing room to the AH's right edge (the game's own call).
-- The AH's panel width grows by the dressing room's while it's shown (its
-- OnShow), so the panel manager keeps room for it.
local function Dock()
	if not Ready() or InCombatLockdown() then
		return false
	end
	local ah, side = AH(), Side()
	if side.parentFrame == ah then
		docked = true
		return true
	end
	Fit(side)
	local width = ah:GetWidth() or 0
	local ok = pcall(SetUpSideDressUpFrame, ah, width, width + (side:GetWidth() or 0), "TOPLEFT", "TOPRIGHT", -2, -26)
	docked = ok and side.parentFrame == ah or false
	return docked
end

-- Takes it off again: dress-ups go to the usual Dressing Room.
local function Undock()
	local side, ah = Side(), AH()
	if not side then
		docked = false
		return
	end
	if ah and side.parentFrame == ah then
		if side:IsShown() and type(CloseSideDressUpFrame) == "function" then
			pcall(CloseSideDressUpFrame, ah)
		end
		side.parentFrame = nil
		side:SetParent(UIParent)
		side:ClearAllPoints()
	end
	docked = false
end

local function Wanted()
	return ns.Setting("ahDressUp") and true or false
end

-- Docked while it's wanted, the AH is open and there's no fight.
local function Update()
	local ah = AH()
	local open = ah and ah:IsShown()
	if Wanted() and open then
		if not InCombatLockdown() then
			Dock()
		end
	elseif docked or (ah and Side() and Side().parentFrame == ah) then
		Undock()
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:RegisterEvent("AUCTION_HOUSE_CLOSED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		-- (Undocked as the fight starts: frames that aren't protected can still
		-- move then, and a dress-up in the fight shouldn't run the panel manager
		-- through our docking.)
		if docked then
			Undock()
		end
	elseif event == "AUCTION_HOUSE_SHOW" then
		-- (The AH's addon loads on this event and shows its frame: dock a frame later.)
		C_Timer.After(0, Update)
	elseif event == "AUCTION_HOUSE_CLOSED" then
		-- (Undocked here, not by Update: ours can hear it before the AH's frame
		-- hides itself, and Update would see it shown and keep it docked under
		-- the hidden AH, to come back with the last item next time and be
		-- undocked as the next fight starts.)
		local side, ah = Side(), AH()
		if docked or (ah and side and side.parentFrame == ah) then
			Undock()
		end
	else
		Update()
	end
end)

-- The Quality of life row's switch (and its page's) changed.
function ns.RefreshAhDressUp()
	Update()
end

-- For the test and /cine debug: where it stands.
function ns.AhDressUpState()
	local side, ah = Side(), AH()
	return {
		wanted = Wanted(),
		docked = docked and true or false,
		ahShown = ah and ah:IsShown() or false,
		sideShown = side and side:IsShown() or false,
		sideVisible = side and side:IsVisible() or false,
		parentIsAH = side and ah and side.parentFrame == ah or false,
	}
end
ns.AhDressUpDock, ns.AhDressUpUndock = Dock, Undock
