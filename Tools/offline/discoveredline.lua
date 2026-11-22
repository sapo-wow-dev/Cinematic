-- Discovered line test (dev tool, offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/discoveredline.lua < /dev/null
-- DaylightUI's error text draws the game's "Discovered: <place>" line in a
-- row of its own (DaylightUIErrorText), so clearing the game's line left
-- theirs under our Discovered card (the user's screenshot, 2026-11-22). On
-- the stand-in game with a clock of its own: their row goes when the line
-- comes with our card, and when it comes seconds after our card; it stays
-- for another line, and with the Discovered card off. Says PASS or FAIL per
-- check. (Optional first argument: another .toc to load, to run it on older
-- code.)
local now = 100
local timers = {}

-- luacheck: push ignore 111 112 113 121 122 212
local ns, wow = dofile("Tools/offline/load.lua")("forever", arg and arg[1], function()
	GetTime = function() return now end
	C_Timer.After = function(seconds, fn) timers[#timers + 1] = { at = now + (seconds or 0), fn = fn } end
	ERR_ZONE_EXPLORED = "Discovered: %s"
	ERR_ZONE_EXPLORED_XP = "Discovered %s: %d experience gained"
	GetRealZoneText = function() return "Ashenvale" end
	GetSubZoneText = function() return "" end
end)
-- luacheck: pop

local function Advance(seconds)
	local stop = now + seconds
	while now < stop - 1e-9 do
		now = math.min(stop, now + 0.1)
		local due = {}
		for i = #timers, 1, -1 do
			if timers[i].at <= now + 1e-9 then
				due[#due + 1] = timers[i]
				table.remove(timers, i)
			end
		end
		table.sort(due, function(a, b) return a.at < b.at end)
		for _, timer in ipairs(due) do pcall(timer.fn) end
		local screen = _G.CinematicCard
		local update = screen and screen._scripts and screen._scripts.OnUpdate
		if update then pcall(update, screen, 0.1) end
	end
end

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

-- DaylightUI's error text: a holder with rows, each a .text, as its v2.1.3.
_G.DaylightUI = { Get = function() return true end }
local holder = CreateFrame("Frame", "DaylightUIErrorText", UIParent)
local rows = {}
for i = 1, 3 do
	local row = CreateFrame("Frame", nil, holder)
	row.text = row:CreateFontString()
	row:Hide()
	rows[i] = row
end
wow.Fire("ADDON_LOADED", "DaylightUI")
wow.Fire("ADDON_LOADED", "DaylightUI_QoL")
Check("our DaylightUI line hider is set", ns.DiscoveredLineHiders and #ns.DiscoveredLineHiders > 0)

ns.db.cards = true
ns.db.cardDiscoverOn = true
ns.db.cardNewZoneOn = false
local function Playing() local card = ns.Cards.Current() return card and card.id or nil end
-- Their row drawing a line, then the game's event (theirs and ours both hear it).
local function Line(row, text)
	row.text:SetText(text)
	row:Show()
	wow.Fire("UI_INFO_MESSAGE", 372, text)
end
local function Reset()
	pcall(ns.Cards.Cut, "discover")
	Advance(40)
	for _, row in ipairs(rows) do row:Hide() end
end
Check("Discovered card allowed on the stand-in", ns.CardAllowed("discover"))

-- 1. The line comes with our card: their row goes.
Reset()
Line(rows[1], "Discovered: The Dor'Danil Barrow Den")
Advance(0.2)
Check("line with card: our card on screen", Playing() == "discover", Playing())
Check("line with card: their row hidden", not rows[1]:IsShown())

-- 2. Our card first (the game's explore count said new), the line 10 s on.
Reset()
ns.DiscoverPlace("Raynewood Retreat", "Ashenvale")
Advance(10)
Line(rows[1], "Discovered: Raynewood Retreat")
Advance(0.2)
Check("line after card: their row hidden", not rows[1]:IsShown())

-- 3. Another of their lines at the same time stays.
Reset()
rows[2].text:SetText("Inventory is full.")
rows[2]:Show()
Line(rows[1], "Discovered: Mystral Lake")
Advance(0.2)
Check("other line: stays", rows[2]:IsShown())
Check("other line: the Discovered one hidden", not rows[1]:IsShown())

-- 4. The Discovered card off: theirs stays (nothing in its place).
Reset()
ns.db.cardDiscoverOn = false
Line(rows[1], "Discovered: Fire Scar Shrine")
Advance(0.2)
Check("card off: their row stays", rows[1]:IsShown())

print(fails == 0 and "all checks passed" or (fails .. " check(s) failed"))
os.exit(fails == 0 and 0 or 1)
