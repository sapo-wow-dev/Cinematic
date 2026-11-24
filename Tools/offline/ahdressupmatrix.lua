-- The dressing room beside the Auction House as the AH closes, every state
-- (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-23-ah-dressup-close.md):
--   python -I Tools/offline/run.py Tools/offline/ahdressupmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/ahdressupmatrix.lua forever --base <ref>
-- The AH open (QoL/AhDressUp.lua's row on or off), maybe a fight going on as
-- it closes, and AUCTION_HOUSE_CLOSED heard before the AH's frame hides
-- (ours was made before Blizzard_AuctionHouseUI loaded: our handler first)
-- or after. Then a fight starts.
-- Each cell: after the close, whether the side dressing room is still docked
-- to the AH (it would come back with the last item next time) and whether
-- our "docked" still says so; then whether the next fight's start ran our
-- Undock (CloseSideDressUpFrame / SetParent as a fight starts).
-- Right: closed = never docked, the next fight touches nothing.
-- Retail: the file doesn't load (Forever only).

local client = arg and arg[1] or "forever"
local combat = false
local setups, closes, reparents = 0, 0, 0
local ns, wow = dofile("Tools/offline/load.lua")(client, nil, function()
	-- luacheck: push ignore 111 112 113 121 122
	InCombatLockdown = function() return combat end
	C_Timer.After = function(_, fn) fn() end
	-- luacheck: pop
end)
local fire = wow.Fire

local Matrix = dofile("Tools/offline/matrix.lua")

-- luacheck: push ignore 111 112 113 121 122
local ah = CreateFrame("Frame", "AuctionHouseFrame")
ah:Hide()
local side = CreateFrame("Frame", "SideDressUpFrame")
side:Hide()
local setParent = side.SetParent
side.SetParent = function(self, parent, ...)
	if parent == UIParent then reparents = reparents + 1 end
	return setParent(self, parent, ...)
end
SetUpSideDressUpFrame = function(parent, closedWidth, openWidth)
	if side.parentFrame == parent then return end
	setups = setups + 1
	side.parentFrame, side.closedWidth, side.openWidth = parent, closedWidth, openWidth
	setParent(side, parent)
end
CloseSideDressUpFrame = function(parent)
	if side.parentFrame == parent then closes = closes + 1; side:Hide() end
end
-- luacheck: pop

Matrix.Run({
	name = client == "retail" and "ahdressup-close-retail" or "ahdressup-close",
	fixed = { client = client },
	dims = {
		{ "row", { "on", "off" } },
		{ "fight", { "none", "during" } },
		{ "order", { "hiddenfirst", "eventfirst" } },
	},
	cell = function(c)
		if not ns.AhDressUpState then return "not loaded" end
		-- (Clean start: AH closed, undocked, no fight.)
		combat = false
		ah:Hide()
		if ns.AhDressUpUndock then ns.AhDressUpUndock() end
		side.parentFrame = nil
		side:Hide()
		ns.db.handleQuality = true
		ns.db.ahDressUp = c.row == "on"
		-- The AH opens, an item's tried on (the side frame shows).
		ah:Show()
		fire("AUCTION_HOUSE_SHOW")
		if side.parentFrame == ah then side:Show() end
		if c.fight == "during" then
			combat = true
			fire("PLAYER_REGEN_DISABLED")
		end
		-- It closes.
		if c.order == "hiddenfirst" then
			ah:Hide()
			fire("AUCTION_HOUSE_CLOSED")
		else
			fire("AUCTION_HOUSE_CLOSED")
			ah:Hide()
		end
		if c.fight == "during" then
			combat = false
			fire("PLAYER_REGEN_ENABLED")
		end
		local state = ns.AhDressUpState()
		local after = ("closed: atAH=%s ours=%s"):format(side.parentFrame == ah and "yes" or "no",
			state.docked and "docked" or "undocked")
		-- The next fight starts.
		local c0, r0 = closes, reparents
		combat = true
		fire("PLAYER_REGEN_DISABLED")
		local touched = (closes ~= c0 or reparents ~= r0) and "undock" or "nothing"
		combat = false
		fire("PLAYER_REGEN_ENABLED")
		return after .. " nextfight=" .. touched
	end,
	pins = {
		-- (Closed: never left docked, the next fight touches nothing.)
		{ "", "closed: atAH=no ours=undocked nextfight=nothing" },
		{ "client=retail", "not loaded" },
	},
})
