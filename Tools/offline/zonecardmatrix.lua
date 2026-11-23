-- The game's zone lines around a Zone card, every state (the audit kit's
-- matrix, Tools/offline/matrix.lua; fix card Tools/audits/2026-11-23-zone-card-gap.md):
--   python -I Tools/offline/run.py Tools/offline/zonecardmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/zonecardmatrix.lua --base <ref>
-- One place shows after another (Westfall then Duskwood, or a subzone of the
-- first), with the last card still on screen or gone, within "Not again
-- within" or after it, the Subzone row and the Territory tick on or off, and
-- on a flight path with "Not on flights" ticked or not.
-- Each cell: whether a new card played, and the game's line for the place and
-- its territory line ("Contested Territory"), hidden or shown. The rule (the
-- user, 2026-11-23, fix card 2026-11-23-zone-card-hide-again.md): with the Zone
-- card row on, the game's lines never show, as before bdb2e1d. No card for a
-- reason the player picked (the Subzone row off, Not again within, Not on
-- flights) means none at all, not the game's own look (a player on a flight:
-- "it is set to default").
-- (bdb2e1d showed them within the gap with the last card still up: the name
-- twice at Darrowmere Lake, fixed in e202b4a. The old zonecardgame.lua check 3
-- pinned only "card gone".)

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
db.cards, db.storyZoneCard, db.cardDiscoverOn, db.storyZoneNotFlying = true, true, false, true
db.storyZoneGap = 10
ns.OnTaxi = function() return false end

local played, fired = 0, nil
local Fire = ns.Cards.Fire
ns.Cards.Fire = function(id, card, ...) played, fired = played + 1, card return Fire(id, card, ...) end
local Current = ns.Cards.Current

local function Show(frameName, zone, subzone, territory)
	lines.ZoneTextString:SetText(zone)
	lines.SubZoneTextString:SetText(subzone or "")
	lines.PVPInfoTextString:SetText(territory or "")
	local frame = _G[frameName]
	frame:Show()
	local script = frame:GetScript("OnShow")
	if script then script(frame) end
	local due = timers
	timers = {}
	for _, fn in ipairs(due) do fn() end
end
local function State(name) return lines[name]._alpha == 0 and "hidden" or "shown" end

local Matrix = dofile("Tools/offline/matrix.lua")
local n = 0
Matrix.Run({
	name = "zonecard-gameline",
	fixed = { client = client },
	dims = {
		{ "place", { "zone", "subzone" } },
		{ "card", { "up", "gone" } },
		{ "gap", { "within", "after" } },
		{ "subzoneRow", { "on", "off" } },
		{ "territoryTick", { "on", "off" } },
		{ "flight", { "on", "off" } },
	},
	cell = function(c)
		n = n + 1
		db.storyZoneSubzones = c.subzoneRow == "on"
		db.storyZoneTerritory = c.territoryTick == "on"
		ns.Cards.Current = Current
		ns.OnTaxi = function() return false end
		now = now + 1000
		local first = "Zone" .. n
		Show("ZoneTextFrame", first, "")
		local up = fired
		if not up then return "no first card" end
		ns.Cards.Current = function() return c.card == "up" and up or nil end
		now = now + (c.gap == "within" and 2 or 15)
		ns.OnTaxi = function() return c.flight == "on" end
		played = 0
		if c.place == "zone" then
			Show("ZoneTextFrame", "Next" .. n, "", "Contested Territory")
		else
			Show("SubZoneTextFrame", first, "Sub" .. n, "Contested Territory")
		end
		local line = c.place == "zone" and "ZoneTextString" or "SubZoneTextString"
		local out = ("card=%s line=%s terr=%s"):format(played > 0 and "new" or "none", State(line),
			State("PVPInfoTextString"))
		ns.Cards.Current = Current
		ns.OnTaxi = function() return false end
		return out
	end,
	pins = {
		-- (No new card: none at all, the game's lines stay hidden.)
		{ "", "card=none line=hidden terr=hidden" },
		-- (After the gap, not flying, a new zone gets its card.)
		{ "place=zone gap=after flight=off", "card=new line=hidden terr=hidden" },
		-- (A subzone after the gap with the Subzone row on, not flying: its card.)
		{ "place=subzone gap=after subzoneRow=on flight=off", "card=new line=hidden terr=hidden" },
	},
})
