-- /cine debug ahdress: the dressing room beside the Auction House
-- (QoL/AhDressUp.lua, WoW Forever). One real action: open the Auction House.
-- Then the test docks the game's SideDressUpFrame, dresses you in one of your
-- own items, checks the AH stays open and the dressing room is beside it on
-- screen, scans which game fields the docking and the dress-up left tainted
-- (the panel manager's FramePositionDelegate, UIPanelWindows, the two frames),
-- closes the AH, and checks dress-ups go to the usual Dressing Room again.
local _, ns = ...
if not ns.TestKit or ns.isRetail then return end

local SLOTS = { 5, 1, 3, 7, 8, 10, 6, 9, 15, 16, 17 }

-- One of your equipped items the dressing room can show.
local function MyItem()
	for _, slot in ipairs(SLOTS) do
		local link = GetInventoryItemLink("player", slot)
		if link and (not (C_Item and C_Item.IsDressableItemByID) or C_Item.IsDressableItemByID(link)) then
			return link, slot
		end
	end
end

-- Game fields an addon wrote (issecurevariable), on a few roots; a frame's own
-- fields only (its children are walked one level).
local ROOTS = { { "FramePositionDelegate", 3 }, { "UIPanelWindows", 3 }, { "SideDressUpFrame", 1 },
	{ "AuctionHouseFrame", 1 }, { "DressUpFrame", 1 } }
local function Scan()
	local list, seen = {}, {}
	if type(issecurevariable) ~= "function" then return list end
	local function Walk(t, path, depth)
		if seen[t] or depth < 1 then return end
		seen[t] = true
		pcall(function()
			for key, value in pairs(t) do
				if type(key) == "string" then
					local ok, secure, who = pcall(issecurevariable, t, key)
					if ok and not secure then list[path .. "." .. key] = tostring(who or "?") end
					if type(value) == "table" and not (issecretvalue and issecretvalue(value))
						and not (value.GetObjectType and depth <= 1) then
						Walk(value, path .. "." .. key, depth - 1)
					end
				end
			end
		end)
	end
	for _, root in ipairs(ROOTS) do
		local t = _G[root[1]]
		if type(t) == "table" then Walk(t, root[1], root[2]) end
	end
	return list
end

local function LogScan(r, label, list, before)
	local keys = {}
	for path in pairs(list) do
		if not (before and before[path]) then keys[#keys + 1] = path end
	end
	table.sort(keys)
	r:Log(("taint %s: %d new tainted field(s)"):format(label, #keys))
	for i = 1, math.min(#keys, 30) do r:Log(("    %s  (by %s)"):format(keys[i], list[keys[i]])) end
	return keys
end

local function OnScreen(frame)
	if not (frame and frame:IsVisible()) then return false end
	local s, u = frame:GetEffectiveScale(), UIParent:GetEffectiveScale()
	local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
	if not (left and right and top and bottom) then return false end
	return left * s >= -1 and bottom * s >= -1 and right * s <= UIParent:GetRight() * u + 1
		and top * s <= UIParent:GetTop() * u + 1
end

local function State(r, label)
	local st = ns.AhDressUpState and ns.AhDressUpState() or {}
	r:Fields(label, {
		wanted = function() return st.wanted end, docked = function() return st.docked end,
		ahShown = function() return st.ahShown end, sideShown = function() return st.sideShown end,
		sideVisible = function() return st.sideVisible end, parentIsAH = function() return st.parentIsAH end,
		dressUpShown = function() return DressUpFrame and DressUpFrame:IsShown() end,
	})
	return st
end

local base -- the tainted fields before the run touched anything

ns.TestKit.Define({
	name = "ahdress", key = "ahDressTest", title = "Dressing room beside the Auction House",
	about = "Ctrl+Click on an auction dresses you beside the AH, which stays open (QoL/AhDressUp.lua)",
	settings = { "ahDressUp", "handleQuality" },
	needs = "stand by an auctioneer",
	steps = {
		{ key = "gate", title = "the row's switch and its page's", proven = "q52a0 2026-11-23 4/4", run = function(r)
			r:Verdict(ns.DEFAULTS and ns.DEFAULTS.ahDressUp == false, "off by default")
			r:Set("handleQuality", true)
			r:Set("ahDressUp", true)
			r:Verdict(ns.Setting("ahDressUp") == true, "on with the row and the page on")
			r:Set("handleQuality", false)
			r:Verdict(not ns.Setting("ahDressUp"), "off with the Quality of Life page off")
			r:Set("handleQuality", true)
			r:Verdict(type(SideDressUpFrame) == "table" and type(SetUpSideDressUpFrame) == "function",
				"the game's side dressing room and its docking call are there")
			base = Scan()
			local n = 0
			for _ in pairs(base) do n = n + 1 end
			r:Log(("taint before: %d tainted field(s) already"):format(n))
		end },
		{ key = "open", title = "open the Auction House (your one action)", run = function(r)
			-- (Here too: the gate step is left out once proven.)
			r:Set("handleQuality", true)
			r:Set("ahDressUp", true)
			base = base or Scan()
			if ns.RefreshAhDressUp then ns.RefreshAhDressUp() end
			-- (Run 3, 2026-11-23: the AH opened and was gone a second later, no
			-- trace; opened again it worked. Each hide is logged with its stack,
			-- and it's asked again till it stays open 1.5 s.)
			local hides = {}
			local function Watch()
				if not AuctionHouseFrame or hides.hooked then return end
				hides.hooked = true
				AuctionHouseFrame:HookScript("OnHide", function()
					if not hides.on then return end
					local stack = debugstack and debugstack(2, 8, 0) or "?"
					if issecretvalue and issecretvalue(stack) then stack = "secret" end
					hides[#hides + 1] = ("%.1f %s"):format(GetTime(), stack:gsub("\n", " | "))
				end)
			end
			hides.on = true
			local closedAt
			local closer = CreateFrame("Frame")
			closer:RegisterEvent("AUCTION_HOUSE_CLOSED")
			closer:RegisterEvent("AUCTION_HOUSE_SHOW")
			closer:SetScript("OnEvent", function(_, event)
				if event == "AUCTION_HOUSE_CLOSED" then closedAt = GetTime() end
				Watch()
			end)
			for try = 1, 3 do
				if not (AuctionHouseFrame and AuctionHouseFrame:IsShown()) then
					r:WaitFor(try == 1 and "Talk to an auctioneer and open the Auction House"
						or "It closed by itself: open the Auction House again", {
						check = function() return AuctionHouseFrame and AuctionHouseFrame:IsShown() end,
					})
				end
				Watch()
				local opened = GetTime()
				r:Sleep(1.5)
				local st = ns.AhDressUpState and ns.AhDressUpState() or {}
				r:Log(("try %d: open %s after 1.5 s, docked %s, AUCTION_HOUSE_CLOSED %s"):format(try,
					tostring(st.ahShown), tostring(st.docked),
					closedAt and ("%.1f s after opening"):format(closedAt - opened) or "no"))
				for i = 1, #hides do
					r:Log("  AH hidden at " .. hides[i])
					hides[i] = nil
				end
				if st.ahShown then break end
				closedAt = nil
				r:Verdict(false, ("try %d: the Auction House stayed open"):format(try))
			end
			hides.on = false
			closer:UnregisterAllEvents()
			local st = State(r, "after opening")
			r:Verdict(st.ahShown, "Auction House open")
			r:Verdict(st.docked and st.parentIsAH, "dressing room docked to it")
			r:Verdict(not st.sideShown, "nothing shown yet (it opens on a dress-up)")
			LogScan(r, "after docking", Scan(), base)
		end },
		{ key = "dress", title = "dress up beside the open Auction House", run = function(r)
			local link, slot = MyItem()
			if not link then return r:Skip("nothing equipped the dressing room can show") end
			r:Log(("dressing up slot %d: %s"):format(slot, link))
			local before = Scan()
			local ran = r:Probe("DressUpLink", DressUpLink, link)
			r:Verdict(ran, "the dress-up ran without an error (Forever: the side frame's ModelBackground)")
			r:Sleep(1)
			local st = State(r, "after the dress-up")
			r:Verdict(st.ahShown, "Auction House still open")
			r:Verdict(st.sideShown and st.sideVisible, "side dressing room shown")
			r:Verdict(not (DressUpFrame and DressUpFrame:IsShown()), "the big Dressing Room stayed closed")
			r:Verdict(OnScreen(SideDressUpFrame), "dressing room fully on screen")
			r:Fields("places", {
				ahRight = function() return AuctionHouseFrame:GetRight() end,
				sideLeft = function() return SideDressUpFrame:GetLeft() end,
				sideTop = function() return SideDressUpFrame:GetTop() end,
				ahTop = function() return AuctionHouseFrame:GetTop() end,
				screenRight = function() return UIParent:GetRight() end,
				panelWidth = function() return AuctionHouseFrame:GetAttribute("UIPanelLayout-width") end,
			})
			LogScan(r, "after the dress-up", Scan(), before)
			r:Shot("Auction House with the dressing room beside it",
				{ behind = { AuctionHouseFrame, SideDressUpFrame } })
			-- A second item swaps in the same frame.
			local other = GetInventoryItemLink("player", slot == 5 and 7 or 5)
			if other then
				r:Probe("DressUpLink (second)", DressUpLink, other)
				r:Sleep(0.5)
				r:Verdict(AuctionHouseFrame:IsShown() and SideDressUpFrame:IsShown(), "second dress-up: still both open")
			end
			-- Its close button (the game's: HideUIPanel on it) leaves the AH open.
			local close = _G.SideDressUpFrameCloseButton
			if close then
				r:Probe("close button", close.Click, close)
				r:Sleep(0.5)
				r:Verdict(not SideDressUpFrame:IsShown() and AuctionHouseFrame:IsShown(),
					"its close button closes it, the AH stays")
			end
		end },
		{ key = "close", title = "close the Auction House: back to the usual Dressing Room", proven = "q52a0 2026-11-23 3/3", run = function(r)
			r:Probe("CloseAuctionHouse", C_AuctionHouse.CloseAuctionHouse)
			r:Sleep(1)
			local st = State(r, "after closing")
			r:Verdict(not st.ahShown, "Auction House closed")
			r:Verdict(not st.docked and not st.parentIsAH, "undocked")
			local link = MyItem()
			if link then
				r:Probe("DressUpLink (AH closed)", DressUpLink, link)
				r:Sleep(0.5)
				r:Verdict(DressUpFrame and DressUpFrame:IsShown() and not SideDressUpFrame:IsVisible(),
					"dress-ups open the usual Dressing Room again")
				if DressUpFrame and DressUpFrame:IsShown() then HideUIPanel(DressUpFrame) end
			end
			LogScan(r, "at the end", Scan(), base)
		end },
	},
})
