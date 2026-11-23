-- The game's zone text left showing when no Zone card takes its place
-- (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/zonecardgame.lua [forever|retail] < /dev/null
-- Audit 2026-11-22, the user's call: with the Zone card row on, the game's
-- zone, subzone and territory lines were made see-through whenever the game
-- showed them, card or no card: the Subzone row off, a second place within
-- the Wait between of the last card, and "Contested Territory" with the
-- card's Territory tick off all showed nothing. Now they go only where a card
-- takes their place (territory too, while a card plays: release review). On stand-in zone text frames. PASS or FAIL per check.

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local client = arg and arg[1] or "forever"
local now = 100
local timers = {}
local lines = {}
local function Install(wow)
	-- luacheck: push ignore 111 112 113 121 122
	GetTime = function() return now end
	FadingFrame_Show = false -- (the frames' OnShow instead: the stand-in's hooks on globals do nothing)
	C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
	UnitIsDeadOrGhost = function() return false end
	for _, name in ipairs({ "ZoneTextFrame", "SubZoneTextFrame" }) do wow.CreateFrame("Frame", name, UIParent) end
	for _, name in ipairs({ "ZoneTextString", "PVPInfoTextString", "PVPArenaTextString", "SubZoneTextString" }) do
		local line = UIParent:CreateFontString()
		line._alpha = 1
		rawset(line, "SetAlpha", function(self, alpha) self._alpha = alpha end)
		_G[name] = line
		lines[name] = line
	end
	-- luacheck: pop
end
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
db.cards, db.storyZoneCard, db.storyZoneSubzones, db.cardDiscoverOn = true, true, false, false
db.storyZoneTerritory, db.storyZoneNotFlying = false, false
ns.OnTaxi = function() return false end
Check(client .. ": the Zone card's on, Subzone's off", ns.CardOn("zone") and not ns.CardOn("subzone"))

local played = 0
local Fire = ns.Cards.Fire
local fired
ns.Cards.Fire = function(id, card, ...) played, fired = played + 1, card return Fire(id, card, ...) end

local function Show(frameName, zone, subzone, territory)
	lines.ZoneTextString:SetText(zone)
	lines.SubZoneTextString:SetText(subzone or "")
	lines.PVPInfoTextString:SetText(territory or "")
	local frame = _G[frameName]
	frame:Show()
	local script = frame:GetScript("OnShow")
	if script then script(frame) end
	-- (A frame later, as the game's own timer.)
	local due = timers
	timers = {}
	for _, fn in ipairs(due) do fn() end
end
local function Alpha(name) return lines[name]._alpha end

-- 1: a new zone, a card for it: the game's zone line goes, its territory too
-- (release review 2026-11-22: left showing, it sat under the card's words).
played = 0
Show("ZoneTextFrame", "Elwynn Forest", "", "Contested Territory")
Check(client .. ": 1 the card plays", played == 1, played)
Check(client .. ": 1 the game's zone line goes", Alpha("ZoneTextString") == 0, Alpha("ZoneTextString"))
Check(client .. ": 1 Contested Territory goes with the card (its Territory tick off)", Alpha("PVPInfoTextString") == 0,
	Alpha("PVPInfoTextString"))

-- 2: into a subzone with the Subzone row off: no card, the game's line shows.
now = now + 30
played = 0
Show("SubZoneTextFrame", "Elwynn Forest", "Goldshire")
Check(client .. ": 2 no card for the subzone", played == 0, played)
Check(client .. ": 2 the game's subzone line shows", Alpha("SubZoneTextString") == 1, Alpha("SubZoneTextString"))

-- 3: another zone within the Wait between: no card, the game's line shows.
now = now + 30
Show("ZoneTextFrame", "Westfall", "")
played = 0
now = now + 2
Show("ZoneTextFrame", "Duskwood", "")
Check(client .. ": 3 no card so soon after the last", played == 0, played)
Check(client .. ": 3 the game's zone line shows", Alpha("ZoneTextString") == 1, Alpha("ZoneTextString"))
Check(client .. ": 3 and its territory line", Alpha("PVPInfoTextString") == 1, Alpha("PVPInfoTextString"))

-- 3b: the same, but the last card still on screen: the game's line stays
-- hidden under it (shown, it doubled the name, Darrowmere Lake 2026-11-23).
local Current = ns.Cards.Current
now = now + 30
Show("ZoneTextFrame", "Westfall", "")
local up = fired
Check(client .. ": 3b the Westfall card played", up ~= nil and up.name == "Westfall", up and up.name)
ns.Cards.Current = function() return up end -- (still on screen)
played = 0
now = now + 2
Show("ZoneTextFrame", "Duskwood", "")
Check(client .. ": 3b no card so soon after the last", played == 0, played)
Check(client .. ": 3b the game's zone line stays hidden under the last card", Alpha("ZoneTextString") == 0,
	Alpha("ZoneTextString"))
ns.Cards.Current = Current

-- 4: the Territory tick on: the card carries it, the game's line goes.
db.storyZoneTerritory = true
now = now + 30
Show("ZoneTextFrame", "Redridge Mountains", "", "Contested Territory")
Check(client .. ": 4 with Territory ticked its line goes too", Alpha("PVPInfoTextString") == 0,
	Alpha("PVPInfoTextString"))

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
