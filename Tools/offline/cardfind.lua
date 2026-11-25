-- /cine find on a Card Vision event's own setting (dev tool, offline, Lua 5.1
-- via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/cardfind.lua [forever|retail] < /dev/null
-- 2026-11-25 (Discord): /cine find cardDepartureLineEdges opened the Card
-- Settings page on the event picked last (Entering combat), Flight
-- departure's slider hidden, the glow on an empty spot. Now a match on an
-- event's part picks that event first. For each id: another event picked
-- first, then /cine find; PASS when its control's own flag is shown and the
-- page's event is its own. (The stand-in hides the hub's page itself, so
-- findcheck.lua says "hidden" for every card id: the control's own flag here.)
-- PASS or FAIL per check. (Optional second argument: another .toc.)
local client = arg and arg[1] or "forever"
local ns, wow = dofile("Tools/offline/load.lua")(client, arg and arg[2] or "CinematicDev.toc")

local queue = {}
C_Timer.After = function(_, fn) queue[#queue + 1] = fn end -- luacheck: ignore 122 (the stand-in's timer)
local function RunTimers()
	for _ = 1, 10 do
		local now = queue
		if #now == 0 then return end
		queue = {}
		for _, fn in ipairs(now) do pcall(fn) end
	end
end
local _ = wow

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

ns.MakeLazyPages("cardfind")

-- An event picked as its row's Settings button does: an openSection of one of
-- its controls (the same hook), then the page refreshed.
local function PickEvent(key)
	local entry = ns.FindEntryOf(key)
	local frame = entry and entry.edges and entry.edges.top
	if frame and frame.openSection then frame.openSection() end
	ns.lowHealthKit.Refresh()
end

local CASES = {
	-- { id, its event, an id of another event picked first }
	{ "cardDepartureLineEdges", "departure", "storyZoneGap" },
	{ "cardDepartureLine", "departure", "storyZoneGap" },
	{ "storyZoneGap", "zone", "cardDepartureLineEdges" },
	{ "cardDepartureLineEdges", "departure", "storyZoneGap" },
}
-- (The page opened once first, as a player's has been: a page never shown
-- isn't refreshed, every event's parts still up.)
ns.OpenOptions("Card Settings")
RunTimers()
for _, case in ipairs(CASES) do
	local id, event, other = case[1], case[2], case[3]
	PickEvent(other)
	local entry = ns.FindEntryOf(id)
	local frame = entry and entry.edges and entry.edges.top
	if not frame then
		Check(id .. ": in /cine find's index", false, "not found")
	else
		local before = frame._shown ~= false
		local ok, text, page = pcall(ns.FindSetting, id)
		RunTimers()
		local after = frame._shown ~= false
		Check(id .. ": hidden under another event first", not before, "shown " .. tostring(before))
		Check(id .. ": /cine find opens " .. event .. " with it shown", ok and after,
			("said %s on %s, shown %s"):format(tostring(text), tostring(page), tostring(after)))
		Check(id .. ": the page's event is its own", frame.openSection and (function()
			-- (asked again: a second openSection does nothing when it's already picked)
			local was = frame._shown
			frame.openSection()
			ns.lowHealthKit.Refresh()
			return frame._shown == was and was ~= false
		end)(), nil)
	end
end

-- A setting for every card (the General tab: no event of its own) still found.
local ok, text = pcall(ns.FindSetting, "cardClearChat")
RunTimers()
Check("cardClearChat (no event): /cine find still finds it", ok and text ~= nil, text)

-- The flight line's slider at 0 reads Off (the limit off: the line up the
-- whole way), not "0 s" (read as never shown, 2026-11-25).
do
	local entry = ns.FindEntryOf("cardDepartureLineEdges")
	local slider = entry and entry.edges and entry.edges.bottom
	local title = slider and slider.tooltipLabel
	local function Read(value)
		ns.GetDB().cardDepartureLineEdges = value
		if slider.Refresh then slider:Refresh() end
		return title and title:GetText() or ""
	end
	local off, eight = Read(0), Read(8)
	Check("slider at 0 reads Off", off:find(ns.L["Off"], 1, true) ~= nil and not off:find("0 s", 1, true), off)
	Check("slider at 8 reads 8 s", eight:find("8 s", 1, true) ~= nil, eight)
end

print(fails == 0 and "ALL PASS" or (fails .. " FAIL"))
if fails > 0 then os.exit(1) end
