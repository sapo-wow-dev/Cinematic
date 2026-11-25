-- /cine debug findtabs: /cine find landing on the wrong tab or card. Nothing
-- to do: it runs /cine find on ids one after another, each from where the
-- last one left the settings, and says DONE. (A test kit test, Dev/TestKit.lua,
-- since 2026-11-25: before, the queue couldn't tell it had ended.)
--   1 plates  ids on the Nameplates and Names icons' tabs (2026-11-20:
--             /cine find row:plate:FriendlyNPCs opened the Nameplates page on
--             its Dungeons & raids tab, the glow where the Friendly tab's row
--             would be). Traced: every save of the page's picked tab (with
--             who called it) and every Nameplates or Names icon pick.
--   2 cards   Card Vision's Settings tab shows one event's settings at a
--             time: /cine find on another event's setting opened it on the
--             last event, the glow on an empty spot (2026-11-25). Now it
--             picks the setting's event first.
--   3 off     the flight line's slider at 0 reads Off (your value put back)
-- For each id: what /cine find said, whether its control is on screen (its
-- frame visible, its page shown), and a screenshot. PASS when visible. Out of
-- a fight. Into CinematicDB.findTabsTestLog. Dev copy only.
local _, ns = ...

local WAIT = 1.5 -- seconds after each /cine find (it glows once the page settles)

local tracing -- the run's r while a step traces

local function SavedTab()
	local open = ns.db and ns.db.sectionsOpen
	return tostring(open and open["Nameplates/tab"])
end

-- Who called: the first few lines of the stack below the hook, file:line only.
local function Caller()
	local stack = debugstack(3, 6, 0) or ""
	local lines = {}
	for file, line in stack:gmatch("([%w_]+%.lua)\"?%]?:(%d+)") do
		lines[#lines + 1] = file .. ":" .. line
		if #lines >= 5 then break end
	end
	return table.concat(lines, " < ")
end

-- The traces, put in once (they log only while a step traces).
local traced
local function Trace()
	if traced then return end
	traced = true
	local kit = ns.lowHealthKit and ns.lowHealthKit.SectionState
	if kit and kit.Save then
		local save = kit.Save
		kit.Save = function(section, open, ...)
			if tracing and type(section) == "table" and section.id == "Nameplates/tab" then
				tracing:Log(("    tab saved: %s -> %s (%s)"):format(tostring(section.open), tostring(open), Caller()))
			end
			return save(section, open, ...)
		end
	end
end

-- (ns.PickPlatesIcon is made as the Nameplates page is built, lazily: wrapped
-- once it's there, and again if it's made anew.)
local pickWrap
local function TracePick()
	local pick = ns.PickPlatesIcon
	if pick and pick ~= pickWrap then
		pickWrap = function(names, ...)
			if tracing then
				tracing:Log(("    icon picked: %s, tab before %s (%s)"):format(names and "Names" or "Nameplates", SavedTab(),
					Caller()))
			end
			local results = { pick(names, ...) }
			if tracing then tracing:Log("      tab after the pick: " .. SavedTab()) end
			return unpack(results)
		end
		ns.PickPlatesIcon = pickWrap
	end
end

-- One /cine find, waited on, checked.
local function Find(r, id, where)
	r:Log(("--- /cine find %s (should open %s); tab before %s ---"):format(id, where, SavedTab()))
	TracePick()
	local ok, text, pageName = pcall(ns.FindSetting, id)
	r:Log(("  /cine find said: %s"):format(ok and (tostring(text) .. " on " .. tostring(pageName))
		or ("error " .. tostring(text))))
	r:Sleep(WAIT)
	TracePick()
	local entry = ns.FindEntryOf and ns.FindEntryOf(id)
	local frame = entry and entry.edges and entry.edges.top
	local page = entry and entry.page and entry.page.canvas
	local visible = frame and frame:IsVisible() and true or false
	r:Verdict(visible, ("%s: its control %s on screen (tab %s; control %s, shown flag %s; its page %s shown %s)"):format(
		id, visible and "is" or "is NOT", SavedTab(), frame and "found" or "NOT in the index",
		tostring(frame and frame:IsShown()), tostring(entry and entry.page and entry.page.key),
		tostring(page and page:IsVisible())))
	r:Shot(id, { behind = SettingsPanel })
end

local function Cases(cases)
	return function(r)
		if InCombatLockdown() then return r:Fail("in a fight: settings can't open") end
		if not ns.FindSetting then return r:Fail("no ns.FindSetting") end
		Trace()
		tracing = r
		for _, case in ipairs(cases) do Find(r, case[1], case[2]) end
		tracing = nil
	end
end

ns.TestKit.Define({
	name = "findtabs",
	key = "findTabsTest",
	title = "/cine find lands on its tab",
	about = "/cine find on ids in Nameplates, Names and Card Vision tabs: each control on screen, nothing to do",
	settings = { "cardDepartureLineEdges" },
	finish = function()
		tracing = nil
		if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
	end,
	steps = {
		{ key = "plates", title = "Nameplates and Names tabs", run = Cases({
			-- (First right after a /reload, the page not built yet: the player's
			-- way. The Dungeons & raids tab's dropdowns have no ids.)
			{ "row:plate:FriendlyNPCs", "Nameplates, Friendly (page not built yet)" },
			{ "row:plate:EnemyNPCs", "Nameplates, Enemy" },
			{ "row:name:ServiceNPCs", "Names, Friendly NPCs" },
			{ "row:plate:FriendlyNPCs", "Nameplates, Friendly (from Names)" },
			{ "row:name:ServiceNPCs", "Names, Friendly NPCs (from Nameplates)" },
		}) },
		{ key = "cards", title = "Card Vision events", run = Cases({
			{ "storyZoneGap", "Card Vision, Settings, New zone" },
			{ "cardDepartureLineEdges", "Card Vision, Settings, Flight departure (from New zone)" },
		}) },
		-- (The flight line's slider all the way left reads Off, the line up the
		-- whole way: "0 s" read as never shown, 2026-11-25.)
		{ key = "off", title = "flight line slider at 0 reads Off", run = function(r)
			local entry = ns.FindEntryOf and ns.FindEntryOf("cardDepartureLineEdges")
			local slider = entry and entry.edges and entry.edges.bottom
			if not (slider and slider.Refresh and slider.title) then return r:Fail("the slider wasn't found") end
			r:Set("cardDepartureLineEdges", 0)
			slider:Refresh()
			local off = slider.title:GetText() or ""
			r:Verdict(off:find(ns.L["Off"], 1, true) ~= nil and slider:IsVisible(), ("at 0 it reads %q, on screen %s"):format(
				off, tostring(slider:IsVisible())))
			r:Shot("slider at 0", { behind = SettingsPanel })
		end },
	},
})
