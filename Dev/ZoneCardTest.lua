-- /cine debug zonecard: a place's name shows once, not twice. Steps 1-6 run
-- themselves (at most one click), step 7 only when asked for by number:
--   1 load     DaylightUI off on this character (run 1, 2026-11-22): it
--              turns DaylightUI and its QoL part on for you, one Reload
--              click, the test goes on after it; off again at the end
--   2 setup    DaylightUI's error text there and drawing the game's lines
--              (its owner of the Discovered message), our hider for it
--   3 with     a "Discovered: <place>" line as the game sends it, to
--              DaylightUI and to us: our Discovered card plays, DaylightUI's
--              row of that line goes (2026-11-22: both drew at once, the
--              user's screenshot at The Dor'Danil Barrow Den) (PASS/FAIL)
--   4 after    our card first (the game's explore count said new), the line
--              6 s later: DaylightUI's row still goes (PASS/FAIL)
--   5 other    another DaylightUI line up at the same time stays (PASS/FAIL)
--   6 off      the Discovered card off: DaylightUI's line stays (PASS/FAIL)
--   7 walk     (/cine debug zonecard 7) 90 s walking in and out of a
--              subzone: at each zone change, what draws 0.3-9 s on (the
--              game's zone lines, DaylightUI's zone title, our card), ONE or
--              BOTH per change (2026-11-19: at the Lion's Pride Inn
--              DaylightUI's zone title and ours showed at once)
--   8 gap      (/cine debug zonecard 8) no walking: made-up zones shown as
--              the game shows them. A second zone within "Not again within"
--              while the first card's still up: no new card, the game's zone
--              line stays hidden under ours (2026-11-23: a player at
--              Darrowmere Lake saw both); the card gone, a third zone: still
--              no game line; on a flight with Not on flights: no card, no
--              game line ("it is set to default", a player, 2026-11-23), and
--              off the flight a card again (PASS/FAIL)
--   9 dungeon  (/cine debug zonecard 9) no walking, no click: made-up
--              places read in place of yours a moment. Out of a dungeon seen
--              before, the game's zone name still the dungeon's: no card
--              (2026-11-23: out of the Stormwind Stockade, the big New zone
--              card for "Stormwind Stockade"); a whole new zone after: the New
--              zone card still plays (PASS/FAIL)
-- The places in 3-6 are made up ("Cinematic Test Glade 1"...), so nothing of
-- yours is counted as discovered. Into CinematicDB.zoneCardTestLog. Dev copy
-- only.
local _, ns = ...

local function Plain(value) return not (issecretvalue and issecretvalue(value)) end
local function Num(value)
	if type(value) ~= "number" then return tostring(value) end
	return Plain(value) and ("%.2f"):format(value) or "secret"
end
local function DUI() return _G.DaylightUI end
local function Holder() return _G.DaylightUIErrorText end

-- DaylightUI's error text row showing this line (shown, not fading out).
local function TheirRow(text)
	local holder = Holder()
	if type(holder) ~= "table" or not holder.GetChildren then return nil end
	for _, row in ipairs({ holder:GetChildren() }) do
		local line = type(row.text) == "table" and row.text.GetText and row.text:GetText()
		if Plain(line) and line == text and ns.Flag(row:IsShown()) then return row end
	end
	return nil
end

local function RowsLine()
	local holder, out = Holder(), {}
	if type(holder) ~= "table" or not holder.GetChildren then return "no DaylightUIErrorText" end
	for i, row in ipairs({ holder:GetChildren() }) do
		local line = type(row.text) == "table" and row.text.GetText and row.text:GetText()
		out[#out + 1] = ("row %d %s \"%s\" alpha %s"):format(i, ns.Flag(row:IsShown()) and "shown" or "hidden",
			Plain(line) and tostring(line) or "secret", Num(row:GetAlpha()))
	end
	return table.concat(out, "; ")
end

local MESSAGE = _G.LE_GAME_ERR_ZONE_EXPLORED
local ADDONS = "DaylightUI,DaylightUI_QoL"
local SaveAddOns = C_AddOns and C_AddOns.SaveAddOns or _G.SaveAddOns
-- An addon's on/off (0 off, 1 some characters, 2 all; mine: for you).
local function EnableState(name, mine)
	local fn = C_AddOns and C_AddOns.GetAddOnEnableState
	if not fn then return nil end
	local ok, state
	if mine then ok, state = pcall(fn, name, UnitName("player")) else ok, state = pcall(fn, name) end
	return ok and state or ("error " .. tostring(state))
end
local count = 0
local function Place()
	count = count + 1
	local place = ("Cinematic Test Glade %d"):format(count)
	-- (A place gets its Discovered card once: the same made-up names after a reload.)
	if ns.ForgetDiscovered then ns.ForgetDiscovered(place) end
	return place
end
local function LineFor(place) return (ERR_ZONE_EXPLORED or "Discovered: %s"):format(place) end

-- The game's line arriving: DaylightUI's handlers (its own event runner),
-- then ours, as the event reaches both.
local function Send(r, text, id, event)
	local dui = DUI()
	if dui and dui.RunEvent then pcall(dui.RunEvent, event or "UI_INFO_MESSAGE", id or MESSAGE, text) end
	if (event or "UI_INFO_MESSAGE") == "UI_INFO_MESSAGE" and ns.CardInfoLine then ns.CardInfoLine(text) end
	r:Log(("sent \"%s\": DaylightUI's row %s right after"):format(text, TheirRow(text) and "up" or "NOT up"))
end

local function Ready(r)
	if r.notReady then r:Skip(r.notReady) return false end
	return true
end

-- What draws a zone change on, for step 6 ---------------------------------------
local GAME = { "ZoneTextString", "SubZoneTextString", "PVPInfoTextString", "PVPArenaTextString" }
local LOOKS = { 0.3, 1, 2, 4, 6, 9 }
local WALK = 90

local function OnScreen(text)
	if text.GetEffectiveAlpha then return text:GetEffectiveAlpha() end
	local own, parent = text:GetAlpha(), text:GetParent()
	local above = parent and parent.GetEffectiveAlpha and parent:GetEffectiveAlpha() or 1
	if type(own) ~= "number" or type(above) ~= "number" or not Plain(own) or not Plain(above) then return nil end
	return own * above
end
local function Drawn(text)
	if type(text) ~= "table" or not text.IsVisible or not ns.Flag(text:IsVisible()) then return nil end
	local alpha = OnScreen(text)
	local words = text.GetText and text:GetText()
	if type(alpha) ~= "number" or not Plain(alpha) or alpha <= 0.05 then return nil end
	if type(words) ~= "string" or not Plain(words) or words == "" then return nil end
	return words, alpha
end
local function DrawnIn(frame, depth)
	if type(frame) ~= "table" or not frame.GetRegions then return nil end
	for _, region in ipairs({ frame:GetRegions() }) do
		if region.GetObjectType and region:GetObjectType() == "FontString" then
			local words, alpha = Drawn(region)
			if words then return words, alpha end
		end
	end
	if (depth or 0) < 3 then
		for _, child in ipairs({ frame:GetChildren() }) do
			local words, alpha = DrawnIn(child, (depth or 0) + 1)
			if words then return words, alpha end
		end
	end
	return nil
end
local function ConflictLines()
	local out = {}
	for _, row in ipairs(ns.CONFLICTS or {}) do
		if row.key == "card:zone" then
			local pick, picked = ns.ConflictPick(row)
			out[#out + 1] = ("%s's own %s, pick %s%s"):format(tostring(row.addon),
				ns.ConflictTheirsOn(row) and "on" or "off", pick, picked and "" or " (not picked)")
		end
	end
	return #out > 0 and table.concat(out, "; ") or "no Addon Conflicts row for it"
end
local function Look()
	local seen, parts = {}, {}
	for _, name in ipairs(GAME) do
		local line = _G[name]
		if line then
			local words, alpha = Drawn(line)
			parts[#parts + 1] = ("%s alpha %s%s"):format(name, Num(line:GetAlpha()),
				words and (" DRAWN \"%s\" at %s"):format(words, Num(alpha)) or "")
			if words and not seen.game then seen.game = words end
		end
	end
	local title = _G.DaylightUIZoneTitle
	if title then
		local words = DrawnIn(title)
		seen.addon = words
		parts[#parts + 1] = ("DaylightUIZoneTitle %s%s"):format(ns.Flag(title:IsShown()) and "shown" or "hidden",
			words and (" DRAWN \"%s\""):format(words) or "")
	end
	local card = ns.Cards and ns.Cards.Current and ns.Cards.Current()
	local words = DrawnIn(_G.CinematicCard)
	seen.ours = words
	parts[#parts + 1] = ("our card %s%s"):format(card and tostring(card.id) .. " \"" .. tostring(card.name) .. "\"" or "none",
		words and (" DRAWN \"%s\""):format(words) or "")
	return seen, table.concat(parts, ", ")
end

ns.TestKit.Define({
	name = "zonecard",
	key = "zoneCardTest",
	title = "Zone card test",
	about = "a place's name once: DaylightUI's Discovered line goes with our card (1-6 run themselves; 7 = walk)",
	needs = "An inn or other subzone nearby to walk in and out of",
	settings = { "cards", "cardDiscoverOn", "cardNewZoneOn", "storyZoneCard", "storyZoneGap", "storyZoneNotFlying" },
	-- (What step 1 turned on, off again: DaylightUI as it was (off for this
	-- character, or for all where only that turned it on), Visions left out.)
	putBack = function(extra)
		local said = {}
		if type(extra.addons) == "string" then
			local disable = C_AddOns and C_AddOns.DisableAddOn or _G.DisableAddOn
			local all = extra.allChars == true
			for name in extra.addons:gmatch("[^,]+") do
				if all then pcall(disable, name) else pcall(disable, name, UnitName("player")) end
			end
			if SaveAddOns then pcall(SaveAddOns) end
			said[#said + 1] = extra.addons .. " off again " .. (all and "for all characters" or "for this character")
		end
		if extra.visionsOff == true and ns.SetModuleWanted then
			ns.SetModuleWanted("visions", false)
			said[#said + 1] = "Load Visions off again"
		end
		return #said > 0 and (table.concat(said, ", ") .. " (at your next reload)") or "nothing of its own to put back"
	end,
	context = function()
		local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or _G.IsAddOnLoaded
		return ("DaylightUI_QoL loaded %s, Card Vision %s, Discovered %s, Zone card %s, Subzone card %s; %s"):format(
			tostring(ns.Flag(isLoaded("DaylightUI_QoL"))), ns.Setting("cards") and "on" or "off",
			ns.CardOn("discover") and "on" or "off", ns.CardOn("zone") and "on" or "off",
			ns.CardOn("subzone") and "on" or "off", ConflictLines())
	end,
	steps = {
		{ key = "load", title = "DaylightUI and Visions on for the test", run = function(r)
			local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or _G.IsAddOnLoaded
			local need = {}
			-- (Visions left out (Load Visions off): no Discovered card at all.
			-- Run 3, 2026-11-22: off after another test was stopped.)
			local visions = ns.ModuleLoaded and ns.ModuleLoaded("visions")
			r:Log(("Visions loaded %s, wanted %s"):format(tostring(visions),
				tostring(ns.ModuleWanted and ns.ModuleWanted("visions"))))
			if not visions and ns.SetModuleWanted then
				if ns.ModuleWanted and not ns.ModuleWanted("visions") then r:Keep("visionsOff", true) end
				ns.SetModuleWanted("visions", true)
				need[#need + 1] = "Visions"
			end
			if ns.Flag(isLoaded("DaylightUI_QoL")) then
				r:Log("DaylightUI_QoL already loaded")
			else
				local getInfo = C_AddOns and C_AddOns.GetAddOnInfo or _G.GetAddOnInfo
				local enable = C_AddOns and C_AddOns.EnableAddOn or _G.EnableAddOn
				local _, _, _, loadable, reason = getInfo("DaylightUI_QoL")
				r:Log(("DaylightUI_QoL not loaded: loadable %s, reason %s, state %s (by your name %s)"):format(
					tostring(loadable), tostring(reason), tostring(EnableState("DaylightUI_QoL")),
					tostring(EnableState("DaylightUI_QoL", true))))
				if reason == "MISSING" then return r:Skip("DaylightUI isn't installed") end
				-- (No character name: rule forever.addons.enable-no-character.
				-- Runs 2-4, 2026-11-22: by your name it read 2 and never loaded.
				-- As /cine debug solo does, which loads. Off again at the end.)
				r:Keep("addons", ADDONS)
				r:Keep("allChars", true)
				for name in ADDONS:gmatch("[^,]+") do pcall(enable, name) end
				r:Log(("on: state now %s (by your name %s)"):format(tostring(EnableState("DaylightUI_QoL")),
					tostring(EnableState("DaylightUI_QoL", true))))
				local saved = SaveAddOns and pcall(SaveAddOns)
				_, _, _, loadable, reason = getInfo("DaylightUI_QoL")
				r:Log(("saved %s; now loadable %s, reason %s"):format(tostring(saved), tostring(loadable), tostring(reason)))
				need[#need + 1] = "DaylightUI"
			end
			if #need == 0 then return end
			r:WaitFor(table.concat(need, " and ") .. " turned on for this test. Click Reload: the test goes on after it.",
				{ buttons = { { kind = "reload" } } })
		end },
		{ key = "setup", title = "DaylightUI's error text and our hider", run = function(r)
			local dui = DUI()
			local owner = dui and dui.MessageTypeOwner and MESSAGE and dui.MessageTypeOwner(MESSAGE)
			local errorText = dui and dui.Get and select(2, pcall(dui.Get, dui, "QoL", "errorText"))
			r:Log(("LE_GAME_ERR_ZONE_EXPLORED %s, its owner %s, DaylightUI errorText %s, DUI.RunEvent %s, rows: %s")
				:format(tostring(MESSAGE), tostring(owner), tostring(errorText), tostring(dui and dui.RunEvent ~= nil),
				RowsLine()))
			r:Verdict(ns.DiscoveredLineHiders and #ns.DiscoveredLineHiders > 0,
				("our hiders for other addons' Discovered line: %d"):format(#(ns.DiscoveredLineHiders or {})))
			local visions = not ns.ModuleLoaded or ns.ModuleLoaded("visions")
			if visions then r:Verdict(ns.CardInfoLine ~= nil, "our Discovered line entry (ns.CardInfoLine)") end
			if not visions then
				r.notReady = "Visions aren't loaded (Load Visions off): no Discovered card"
			elseif not dui then
				r.notReady = "DaylightUI isn't loaded"
			elseif not MESSAGE then
				r.notReady = "no LE_GAME_ERR_ZONE_EXPLORED on this client"
			elseif owner ~= "errortext" then
				r.notReady = "DaylightUI's error text isn't drawing the Discovered line (its Error text off?), owner "
					.. tostring(owner)
			end
			if r.notReady then r:Skip(r.notReady) end
			r:Set("cards", true)
			r:Set("cardDiscoverOn", true)
		end },
		{ key = "with", title = "the line with our card", run = function(r)
			if not Ready(r) then return end
			local place = Place()
			local text = LineFor(place)
			Send(r, text)
			r:Sleep(0.4)
			local card = ns.Cards.Current()
			r:Verdict(card and card.id == "discover" and card.name == place,
				("our Discovered card for it: %s \"%s\""):format(tostring(card and card.id), tostring(card and card.name)))
			r:Verdict(not TheirRow(text), "DaylightUI's row of it hidden; " .. RowsLine())
			r:Shot("our card alone", { behind = { _G.CinematicCard, Holder() } })
			ns.Cards.Cut("discover")
			r:Sleep(1.5)
		end },
		{ key = "after", title = "the line 6 s after our card", seconds = 8, run = function(r)
			if not Ready(r) then return end
			local place = Place()
			local played = ns.DiscoverPlace(place, GetRealZoneText() or "")
			r:Log("our card first: " .. tostring(played))
			r:Sleep(6)
			local text = LineFor(place)
			Send(r, text)
			r:Sleep(0.4)
			r:Verdict(not TheirRow(text), "DaylightUI's row of it hidden; " .. RowsLine())
			ns.Cards.Cut("discover")
			r:Sleep(1.5)
		end },
		{ key = "other", title = "another DaylightUI line stays", run = function(r)
			if not Ready(r) then return end
			local other = _G.ERR_INV_FULL or "Inventory is full."
			Send(r, other, _G.LE_GAME_ERR_INV_FULL, "UI_ERROR_MESSAGE")
			local text = LineFor(Place())
			Send(r, text)
			r:Sleep(0.4)
			r:Verdict(TheirRow(other) ~= nil, "their \"" .. other .. "\" row still up; " .. RowsLine())
			r:Verdict(not TheirRow(text), "the Discovered row hidden")
			ns.Cards.Cut("discover")
			r:Sleep(2.5)
		end },
		{ key = "off", title = "Discovered card off: their line stays", run = function(r)
			if not Ready(r) then return end
			r:Set("cardDiscoverOn", false)
			local text = LineFor(Place())
			Send(r, text)
			r:Sleep(0.4)
			local card = ns.Cards.Current()
			r:Verdict(not (card and card.id == "discover"), "no Discovered card: " .. tostring(card and card.id))
			r:Verdict(TheirRow(text) ~= nil, "DaylightUI's row of it up (nothing in its place); " .. RowsLine())
			r:Shot("their line, card off", { behind = Holder() })
		end },
		{ key = "walk", title = "walk in and out of a subzone", run = function(r)
			-- (Only asked for alone, /cine debug zonecard 7: the rest run with
			-- no walking. Run 2, 2026-11-22: picked up after the Reload as
			-- steps 2-7, it asked for the walk.)
			if #r.steps ~= 1 then
				r:Skip("the walk runs alone: /cine debug zonecard 7")
				return
			end
			local changes, started = {}, GetTime()
			local watcher = CreateFrame("Frame")
			for _, event in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }) do
				watcher:RegisterEvent(event)
			end
			watcher:SetScript("OnEvent", function(_, event)
				if GetTime() - started > WALK then return watcher:UnregisterAllEvents() end
				local zone, sub = GetZoneText() or "", GetSubZoneText() or ""
				local change = { place = sub ~= "" and sub or zone, drew = {} }
				changes[#changes + 1] = change
				local n = #changes
				r:Log(("change %d %s: zone \"%s\", subzone \"%s\", Zone card %s, Subzone card %s; %s"):format(n, event,
					zone, sub, ns.CardOn("zone") and "on" or "off", ns.CardOn("subzone") and "on" or "off", ConflictLines()))
				for _, after in ipairs(LOOKS) do
					C_Timer.After(after, function()
						local ok, seen, line = pcall(Look)
						if not ok then return r:Log(("change %d +%.1fs: error: %s"):format(n, after, tostring(seen))) end
						local drew = 0
						for key, words in pairs(seen) do
							if words then change.drew[key] = true drew = drew + 1 end
						end
						if drew >= 2 then change.together = true end
						r:Log(("change %d +%.1fs: %s"):format(n, after, line))
					end)
				end
			end)
			r:WaitFor("Walk into a subzone (an inn) and back out, 2 or 3 times.", { seconds = WALK,
				check = function() return GetTime() - started >= WALK + 10 end })
			watcher:UnregisterAllEvents()
			for i, change in ipairs(changes) do
				local who = {}
				for _, key in ipairs({ "game", "addon", "ours" }) do
					if change.drew[key] then
						who[#who + 1] = key == "game" and "the game's" or key == "addon" and "DaylightUI's" or "ours"
					end
				end
				r:Verdict(#who == 1, ("change %d at \"%s\": %s%s"):format(i, change.place,
					#who == 0 and "nothing drew" or table.concat(who, " + "), change.together and " at once" or ""))
			end
			if #changes == 0 then r:Skip("no zone change in the walk") end
		end },
		{ key = "gap", title = "a zone within the gap, and on a flight",
		-- (Run 1 2026-11-23 (Forever) proved parts 1-2; part 3 now expects the
		-- opposite, part 4 is new: fix card 2026-11-23-zone-card-hide-again.md.)
		run = function(r)
			-- (Only asked for by number, /cine debug zonecard 8: no DaylightUI,
			-- no walking. The game's zone frame shown on made-up names, as its
			-- own ZONE_CHANGED_NEW_AREA shows it.)
			if ns.ModuleLoaded and not ns.ModuleLoaded("visions") then
				return r:Skip("Visions aren't loaded (Load Visions off): no Zone card")
			end
			r:Set("cards", true)
			r:Set("storyZoneCard", true)
			r:Set("cardDiscoverOn", false) -- (made-up places: no Discovered wait)
			r:Set("storyZoneGap", 10)
			r:Set("storyZoneNotFlying", false)
			local zoneLine = _G.ZoneTextString
			if not (zoneLine and _G.ZoneTextFrame) then return r:Skip("no ZoneTextFrame on this client") end
			-- (flying: ns.OnTaxi says true for the one frame the zone card reads
			-- it, no longer: run 2, 2026-11-23, half a second of it woke the
			-- flight camera, its CVars and a "Value out of range" line.)
			local function ShowZone(name, flying)
				local OnTaxi = ns.OnTaxi
				if flying then ns.OnTaxi = function() return true end end
				zoneLine:SetText(name)
				if _G.SubZoneTextString then _G.SubZoneTextString:SetText("") end
				if _G.PVPInfoTextString then _G.PVPInfoTextString:SetText("") end
				if FadingFrame_Show then FadingFrame_Show(_G.ZoneTextFrame) else _G.ZoneTextFrame:Show() end
				if flying then
					r:Sleep(0) -- (the zone card's own next-frame look, queued first)
					ns.OnTaxi = OnTaxi
				end
				r:Sleep(0.5)
				local _, line = Look()
				r:Log(("shown \"%s\": %s"):format(name, line))
			end
			local function Hidden() return Plain(zoneLine:GetAlpha()) and zoneLine:GetAlpha() <= 0.05 end
			local current = ns.Cards.Current()
			if current then ns.Cards.Cut(current.id) r:Sleep(1.5) end
			local allowed, why = ns.CardAllowed("zone")
			r:Log(("Zone card allowed now: %s%s"):format(tostring(allowed), why and (" (" .. tostring(why) .. ")") or ""))
			if not allowed then return r:Skip("no Zone card can play here and now: " .. tostring(why)) end
			-- 1: a new zone: our card, the game's line hidden.
			ShowZone("Cinematic Test Vale")
			local first = ns.Cards.Current()
			r:Verdict(first and first.id == "zone" and first.name == "Cinematic Test Vale",
				("our Zone card for it: %s \"%s\""):format(tostring(first and first.id), tostring(first and first.name)))
			r:Verdict(Hidden(), "the game's zone line hidden under it: alpha " .. Num(zoneLine:GetAlpha()))
			-- 2: another zone 1.5 s on, within the gap, the first card still up.
			r:Sleep(1)
			ShowZone("Cinematic Test Marsh")
			local still = ns.Cards.Current()
			r:Verdict(first ~= nil and still == first, ("no new card, the first still up: %s \"%s\""):format(
				tostring(still and still.id), tostring(still and still.name)))
			r:Verdict(Hidden(), "the game's \"Cinematic Test Marsh\" stays hidden under our card (the fix): alpha "
				.. Num(zoneLine:GetAlpha()))
			r:Shot("one name: our card only", { behind = { _G.CinematicCard, _G.ZoneTextFrame } })
			-- 3: the card cut, a third zone still within the gap: no card, and no
			-- game line either (the user's call, 2026-11-23).
			ns.Cards.Cut("zone")
			for _ = 1, 25 do -- (its quick fade out: at most 5 s)
				if not ns.Cards.Current() then break end
				r:Sleep(0.2)
			end
			r:Log("first card gone: " .. tostring(not ns.Cards.Current()))
			ShowZone("Cinematic Test Fen")
			local none = ns.Cards.Current()
			r:Verdict(first ~= nil and not none, "no card (after one played): " .. tostring(none and none.id))
			r:Verdict(Hidden(), "with no card up the game's line still stays hidden: alpha " .. Num(zoneLine:GetAlpha()))
			-- 4: on a flight path, Not on flights ticked, the gap out of the way:
			-- no card and no game line. Then off the flight: a card (so 4's "no
			-- card" is the flight's doing).
			r:Set("storyZoneGap", 0)
			r:Set("storyZoneNotFlying", true)
			ShowZone("Cinematic Test Heath", true)
			local flying = ns.Cards.Current()
			r:Verdict(not flying, "on a flight, no card: " .. tostring(flying and flying.name))
			r:Verdict(Hidden(), "on a flight, the game's \"Cinematic Test Heath\" stays hidden: alpha "
				.. Num(zoneLine:GetAlpha()))
			r:Shot("on a flight: no name", { behind = _G.ZoneTextFrame })
			ShowZone("Cinematic Test Moor")
			local landed = ns.Cards.Current()
			r:Verdict(landed and landed.name == "Cinematic Test Moor",
				"off the flight, its card plays: " .. tostring(landed and landed.name))
			if landed then ns.Cards.Cut(landed.id) end
			-- (The game's lines back to where you are.)
			zoneLine:SetText(GetZoneText and GetZoneText() or "")
			if _G.SubZoneTextString then _G.SubZoneTextString:SetText(GetSubZoneText and GetSubZoneText() or "") end
		end },
		{ key = "dungeon", title = "out of a dungeon, its name still up",
		proven = "zonecard run 2026-11-23 (retail): 3 PASS, no card for the dungeon's leftover name, New zone's after",
		run = function(r)
			-- (Only asked for by number, /cine debug zonecard 9.)
			if #r.steps ~= 1 then return r:Skip("runs alone: /cine debug zonecard 9") end
			if ns.ModuleLoaded and not ns.ModuleLoaded("visions") then
				return r:Skip("Visions aren't loaded (Load Visions off): no Discovered card")
			end
			local reads, seen = ns.CardReads, ns.chardb and ns.chardb.cardSeen
			if not (reads and seen and ns.DiscoverHasIt) then return r:Skip("no ns.CardReads or cardSeen") end
			r:Set("cards", true)
			r:Set("cardDiscoverOn", true)
			r:Set("cardNewZoneOn", true)
			local current = ns.Cards.Current()
			if current then ns.Cards.Cut(current.id) r:Sleep(1.5) end
			local allowed, why = ns.CardAllowed("newZone")
			r:Log(("New zone card allowed now: %s%s"):format(tostring(allowed), why and (" (" .. tostring(why) .. ")") or ""))
			if not allowed then return r:Skip("no New zone card can play here and now: " .. tostring(why)) end
			-- (Made-up places, yours as they were after: the reads, and the
			-- made-up names out of what's counted as seen.)
			local DUNGEON, ID, NEW = "Cinematic Test Crypt", -9001, "Cinematic Test Downs"
			local zone, inside = DUNGEON, true
			local saved = { zone = reads.zone, instance = reads.instance, instanceInfo = reads.instanceInfo,
				explored = reads.explored }
			local hadZones = next(seen.zones) ~= nil
			if ns.ForgetDiscovered then
				for _, place in ipairs({ DUNGEON, NEW }) do ns.ForgetDiscovered(place) end
			end
			seen.instances[ID] = true
			if not hadZones then seen.zones["Cinematic Test Field"] = true end
			reads.zone = function() return zone end
			reads.instance = function() return inside, inside and "party" or "none" end
			reads.instanceInfo = function() return DUNGEON, "party", 1, "Normal", 5, 0, false, ID end
			reads.explored = function() return 0 end
			-- (No r:Sleep in the pcall, Lua 5.1 can't yield across it: the
			-- cards fire at once, read straight after.)
			local out, newCard, counted
			local ok, err = pcall(function()
				ns.DiscoverHasIt() -- (inside, seen before: nothing)
				inside = false -- (out, the name still the dungeon's)
				ns.DiscoverHasIt()
				out = ns.Cards.Current()
				counted = seen.zones[DUNGEON]
				zone = NEW -- (the real name: a whole zone new to you)
				ns.DiscoverHasIt()
				newCard = ns.Cards.Current()
			end)
			for key in pairs(saved) do reads[key] = saved[key] end
			reads.explored = saved.explored
			seen.instances[ID], seen.zones[DUNGEON], seen.zones[NEW] = nil, nil, nil
			if not hadZones then seen.zones["Cinematic Test Field"] = nil end
			r:Log(("out, zone still \"%s\": card %s \"%s\""):format(DUNGEON, tostring(out and out.id),
				tostring(out and out.name)))
			r:Verdict(not out, ("no card for the dungeon's name outside (the fix): %s \"%s\""):format(
				tostring(out and out.id), tostring(out and out.name)))
			r:Verdict(not counted, "the dungeon's name not counted as a zone")
			r:Verdict(newCard and newCard.id == "newZone" and newCard.name == NEW, ("a new zone after: %s \"%s\""):format(
				tostring(newCard and newCard.id), tostring(newCard and newCard.name)))
			r:Sleep(0.6)
			r:Shot("the New zone card", { behind = _G.CinematicCard })
			if not ok then r:Verdict(false, "error: " .. tostring(err)) end
			local card = ns.Cards.Current()
			if card then ns.Cards.Cut(card.id) r:Sleep(1.5) end
		end },
		-- 10 (2026-11-23, "DUN MOROGH" slammed big on a new character): New
		-- zone off to start with and turned off once by the update
		-- (Migrations.lua newZoneOffV1), everywhere it's saved; a new zone
		-- gets Discovered's small card; ticked again, the big one's back.
		{ key = "newzoneoff", title = "New zone off: a new zone gets the small Discovered card",
		proven = "zonecard run 2026-11-23 (Forever, queue q607a): 8 PASS, small card with New zone off, big once ticked",
		run = function(r)
			if #r.steps ~= 1 then return r:Skip("runs alone: /cine debug zonecard 10") end
			if ns.ModuleLoaded and not ns.ModuleLoaded("visions") then
				return r:Skip("Visions aren't loaded (Load Visions off): no Discovered card")
			end
			local db = ns.db
			-- (Yours as the update left them, before the test changes anything.)
			r:Verdict(ns.DEFAULTS.cardNewZoneOn == false,
				"New zone off to start with (DEFAULTS): " .. tostring(ns.DEFAULTS.cardNewZoneOn))
			r:Verdict(db.newZoneOffV1 == true, "the once-only update ran (newZoneOffV1): " .. tostring(db.newZoneOffV1))
			r:Verdict(not db.cardNewZoneOn, "New zone off in your settings now: " .. tostring(db.cardNewZoneOn))
			r:Verdict(not ns.CardOn("newZone"), "New zone's card not on (ns.CardOn): " .. tostring(ns.CardOn("newZone")))
			local onIn = {}
			for _, list in ipairs({ { "profile", db.profiles }, { "reset point", db.profileResetPoints } }) do
				for name, saved in pairs(type(list[2]) == "table" and list[2] or {}) do
					if type(saved) == "table" and saved.cardNewZoneOn == true then
						onIn[#onIn + 1] = list[1] .. " " .. tostring(name)
					end
				end
			end
			r:Verdict(#onIn == 0, "no saved profile or reset point with New zone on" ..
				(#onIn > 0 and (": " .. table.concat(onIn, ", ")) or ""))
			local reads, seen = ns.CardReads, ns.chardb and ns.chardb.cardSeen
			if not (reads and seen and ns.DiscoverHasIt) then return r:Skip("no ns.CardReads or cardSeen") end
			r:Set("cards", true)
			r:Set("cardDiscoverOn", true)
			local current = ns.Cards.Current()
			if current then ns.Cards.Cut(current.id) end
			local allowed, why = ns.CardAllowed("discover")
			r:Log(("Discovered card allowed now: %s%s"):format(tostring(allowed), why and (" (" .. tostring(why) .. ")") or ""))
			if not allowed then return r:Skip("no Discovered card can play here and now: " .. tostring(why)) end
			-- (A made-up new zone, entered with New zone as it is (off), then
			-- ticked: the reads and what's counted as seen back after each.)
			local saved = { zone = reads.zone, instance = reads.instance, instanceInfo = reads.instanceInfo,
				explored = reads.explored }
			local hadZones = next(seen.zones) ~= nil
			local function Enter(place)
				if ns.ForgetDiscovered then ns.ForgetDiscovered(place) end
				if not hadZones then seen.zones["Cinematic Test Field"] = true end
				reads.zone = function() return place end
				reads.instance = function() return false, "none" end
				reads.instanceInfo = function() return place, "none", 0, "", 0, 0, false, 0 end
				reads.explored = function() return 1 end -- (the game's count: one area, new to you)
				local ok, err = pcall(ns.DiscoverHasIt)
				for key in pairs(saved) do reads[key] = saved[key] end
				reads.explored = saved.explored
				local card = ns.Cards.Current()
				seen.zones[place] = nil
				if not hadZones then seen.zones["Cinematic Test Field"] = nil end
				if not ok then r:Verdict(false, "error: " .. tostring(err)) end
				return card
			end
			-- (A card cut fades out first: the next one waits behind it till it's gone.)
			local function Gone(what)
				for _ = 1, 40 do
					if not ns.Cards.Current() then return true end
					r:Sleep(0.1)
				end
				local left = ns.Cards.Current()
				r:Verdict(false, ("%s: a card still up after 4 s, %s \"%s\""):format(what, tostring(left and left.id),
					tostring(left and left.name)))
				return false
			end
			if not Gone("before the first place") then return end
			local SMALL, BIG = "Cinematic Test Vale", "Cinematic Test Heights"
			local card = Enter(SMALL)
			r:Verdict(card and card.id == "discover" and card.name == SMALL, ("New zone off, a new zone: %s \"%s\" (want discover)"):format(
				tostring(card and card.id), tostring(card and card.name)))
			r:Verdict(card and card.meta == ns.L["Discovered"], "its small line says Discovered: " .. tostring(card and card.meta))
			r:Sleep(0.6)
			r:Shot("the small Discovered card (New zone off)", { behind = _G.CinematicCard })
			if card then ns.Cards.Cut(card.id) end
			if not Gone("after the small card") then return end
			r:Set("cardNewZoneOn", true)
			card = Enter(BIG)
			r:Verdict(card and card.id == "newZone" and card.name == BIG, ("New zone ticked again, a new zone: %s \"%s\" (want newZone)"):format(
				tostring(card and card.id), tostring(card and card.name)))
			r:Sleep(0.6)
			r:Shot("the big New zone card (ticked again)", { behind = _G.CinematicCard })
			if card then ns.Cards.Cut(card.id) end
			Gone("after the big card")
			-- (Put back at the end by the kit: New zone off again.)
		end },
	},
})
