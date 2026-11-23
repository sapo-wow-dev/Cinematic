-- The dressing room beside the Auction House (QoL/AhDressUp.lua), offline
-- (Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/ahdressup.lua
-- Off by default: opening the AH docks nothing. On: the AH opening docks the
-- game's SideDressUpFrame to it (SetUpSideDressUpFrame, once), the AH closing
-- undocks it, a fight undocks it and its end docks it again, the row or the
-- Quality of Life page turned off undocks it, and nothing runs in a fight.
-- PASS or FAIL lines.
-- luacheck: push ignore 111 112 113 121 122 143
package.path = "Tools/offline/?.lua;" .. package.path
local wow = dofile("Tools/offline/wow.lua")
wow.Install("forever")
local ns = {}
for line in io.lines("Cinematic.toc") do
	line = line:gsub("\r", "")
	if line ~= "" and not line:find("^#") then
		local chunk = loadfile((line:gsub("\\", "/")))
		if chunk then
			local ok, err = pcall(chunk, "Cinematic", ns)
			if not ok then wow.Warn(line .. ": " .. tostring(err)) end
		end
	end
end
wow.Fire("ADDON_LOADED", "Cinematic")
wow.Fire("PLAYER_LOGIN")

-- The game's pieces, as Blizzard's DressUpFrames.lua has them.
local combat = false
InCombatLockdown = function() return combat end
C_Timer.After = function(_, fn) fn() end
local ah = wow.CreateFrame("Frame", "AuctionHouseFrame")
ah:Hide()
local side = wow.CreateFrame("Frame", "SideDressUpFrame")
side:Hide()
local setups, closes = 0, 0
SetUpSideDressUpFrame = function(parent, closedWidth, openWidth, point, relativePoint)
	if side.parentFrame == parent then return end
	setups = setups + 1
	side.parentFrame, side.closedWidth, side.openWidth = parent, closedWidth, openWidth
	side.point = { point, relativePoint }
	side:SetParent(parent)
end
CloseSideDressUpFrame = function(parent)
	if side.parentFrame == parent then closes = closes + 1; side:Hide() end
end
-- luacheck: pop

local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. text)
	if not ok then failed = failed + 1 end
end

local function Open() ah:Show(); wow.Fire("AUCTION_HOUSE_SHOW") end
local function Close() ah:Hide(); wow.Fire("AUCTION_HOUSE_CLOSED") end
local function Docked() return side.parentFrame == ah end

Check(ns.RefreshAhDressUp and ns.AhDressUpState, "the file loaded")
Check(ns.DEFAULTS.ahDressUp == false, "off by default")

-- Off: nothing.
Open()
Check(not Docked() and setups == 0, "off: opening the AH docks nothing")
Close()

-- On.
ns.db.ahDressUp = true
ns.db.handleQuality = true
Open()
Check(Docked() and setups == 1, "on: opening the AH docks the side dressing room")
Check(side.ModelBackground and not side.ModelBackground:IsShown(),
	"the side frame has the hidden ModelBackground Forever's dress-up hides (DressUpFrames.lua:316)")
Check(side.point and side.point[1] == "TOPLEFT" and side.point[2] == "TOPRIGHT", "on the AH's right edge")
Check(side.openWidth and side.closedWidth and side.openWidth > side.closedWidth,
	"the AH's panel width grows by the dressing room's while it's shown")
wow.Fire("AUCTION_HOUSE_SHOW")
Check(setups == 1, "docked once (a second show doesn't redo it)")
side:Show()
Close()
Check(not Docked() and side.parentFrame == nil, "closing the AH undocks it")
Check(side:GetParent() == UIParent, "back on UIParent")

-- A fight.
Open()
combat = true
wow.Fire("PLAYER_REGEN_DISABLED")
Check(not Docked(), "a fight undocks it (dress-ups open the usual Dressing Room)")
local before = setups
ns.RefreshAhDressUp()
Check(setups == before and not Docked(), "nothing docks in a fight")
combat = false
wow.Fire("PLAYER_REGEN_ENABLED")
Check(Docked(), "docked again after the fight")
Close()

-- Opening in a fight: docks after it.
combat = true
Open()
Check(not Docked(), "opened in a fight: not docked")
combat = false
wow.Fire("PLAYER_REGEN_ENABLED")
Check(Docked(), "...docked once the fight ends")

-- The row off, then the page off, while the AH is open.
ns.db.ahDressUp = false
ns.RefreshAhDressUp()
Check(not Docked(), "row turned off: undocked")
ns.db.ahDressUp = true
ns.RefreshAhDressUp()
Check(Docked(), "row turned on again: docked")
ns.db.handleQuality = false
ns.RefreshAhDressUp()
Check(not Docked(), "Quality of Life page off: undocked")
ns.db.handleQuality = true
ns.RefreshAhDressUp()
Close()

-- Someone else's docking (Recruit-a-Friend) is left alone.
ns.db.ahDressUp = false
local other = wow.CreateFrame("Frame", "RecruitAFriendFrame")
side.parentFrame = other
Open()
Close()
Check(side.parentFrame == other, "another frame's docking is left alone")

for _, warning in ipairs(wow.warnings) do
	if warning:find("AhDressUp") then Check(false, "load warning: " .. warning) end
end
print(failed == 0 and "ALL PASS" or (failed .. " FAILED"))
