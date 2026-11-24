-- Card Vision's Why line for a ticked card that can't show (dev tool,
-- offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/cardwhytab.lua [forever|retail] < /dev/null
-- Release review 2026-11-23 (6f79106): "<card> is ticked, but its tab on
-- Card Vision's Events page is off" was said whenever the card's setting read
-- off while its tick was on, whatever switch above it was off. Now only when
-- its Events tab's switch is. On the stand-in: its tab off, that line; its
-- tab on and another switch over it off, not that line; all on, allowed.
-- PASS or FAIL per check. (Optional second argument: another .toc.)
local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, arg and arg[2] or "CinematicDev.toc")

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local TAB = "tabOn:Card Vision/events:1"
local OTHER = "cinematicTestSwitch"
local db = ns.db
db.cards, db.combatOnEnter = true, true
db[TAB], db[OTHER] = true, true
-- (The chain the Events page hangs once built: the tick under its tab, the
-- tab under Card Vision's switch.)
ns.SetPageMaster({ "combatOnEnter" }, TAB)
ns.SetPageMaster({ TAB }, "cards")

local ok, why = ns.CardAllowed("combatIn", "enter")
Check("all on: Entering combat allowed (or stopped by its Show in row only)",
	ok or why == ns.L["Its Show in row says not here and now"], why)

db[TAB] = false
ok, why = ns.CardAllowed("combatIn", "enter")
Check("its tab off: the tab line", not ok and type(why) == "string" and why:find("its tab on Card Vision's Events page is off", 1, true), why)

-- (Its tab on, another switch between it and the tab off: not the tab line.)
db[TAB] = true
ns.SetPageMaster({ "combatOnEnter" }, OTHER)
ns.SetPageMaster({ OTHER }, TAB)
db[OTHER] = false
ok, why = ns.CardAllowed("combatIn", "enter")
Check("another switch off, its tab on: stopped", not ok, why)
Check("another switch off, its tab on: not the tab line",
	type(why) == "string" and not why:find("its tab on Card Vision's Events page", 1, true), why)

-- (The tick itself off: unticked.)
db[OTHER] = true
db.combatOnEnter = false
ok, why = ns.CardAllowed("combatIn", "enter")
Check("unticked: the unticked line", not ok and type(why) == "string" and why:find("is unticked", 1, true), why)

print(fails == 0 and "ALL PASS" or (fails .. " FAIL"))
if fails > 0 then os.exit(1) end
