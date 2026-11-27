-- /cine debug eventfacts: the rule words the game announces by event
-- (commits 096cbe9..2a83026, fix cards Tools/audits/2026-11-25-event-fact-*.md,
-- ledger Tools/tests/event-facts.md). Each word is now asked only after its
-- events (ns.AddEventFact, Frames.lua) and the place after the zone and
-- resting events (ns.placeWatch, Core.lua). This checks each cached answer
-- against the game's live one, the whole run long: a word that stays wrong
-- for over 1.2 s FAILs, with the game's events from the 3 s before (which
-- event we'd have needed). Steps:
--   1 rest      every word and the place, cached vs live, for 6 s (hands off)
--   2 fakegroup /cine debug group party and off: group follows (hands off)
--   3 mount     YOUR ONE ACTION: mount up, then get off. mounted follows
--               IsMounted each way, PLAYER_MOUNT_DISPLAY_CHANGED counted
--   4 cost      ms per full working out now, and with every entry asked
--               again (as before the fixes) (hands off)
-- A rule naming every word is compiled for the run (the words stay read till
-- a /reload). Into CinematicDB.eventFactsTestLog. Dev copy only.
local _, ns = ...

local STALE_AFTER = 1.2 -- (the facts' 0.5 s hold + the 0.5 s settle, and the sample step)
local SAMPLE = 0.25

-- Each word: the game's answer now (live) and the facts' (cached), as strings.
local CLASSES = { "warrior", "paladin", "hunter", "rogue", "priest", "deathknight", "shaman", "mage", "warlock",
	"monk", "druid", "demonhunter", "evoker" }
local function Yes(v) return v and "on" or "off" end
local WORDS = {
	{ "class", function() local _, c = UnitClass("player") return type(c) == "string" and c:lower() or "?" end,
		function(f)
			for _, c in ipairs(CLASSES) do if f[c] == true then return c end end
			return "none"
		end },
	{ "role", function() return tostring(ns.PlayerRole() or "none") end,
		function(f) return f.tank and "TANK" or f.healer and "HEALER" or f.damage and "DAMAGER" or "none" end },
	{ "group", function() return Yes(ns.InGroup()) end, function(f) return Yes(f.group) end },
	{ "flagged", function() return Yes(ns.IsPvPFlagged()) end, function(f) return Yes(f.flagged) end },
	{ "afk", function() return Yes(ns.Flag(UnitIsAFK("player"))) end, function(f) return Yes(f.afk) end },
	{ "resting", function() return Yes(ns.Flag(IsResting())) end, function(f) return Yes(f.resting) end },
	{ "dead", function() return Yes(ns.Flag(UnitIsDeadOrGhost("player"))) end, function(f) return Yes(f.dead) end },
	{ "mounted", function() return Yes(ns.Flag(IsMounted())) end, function(f) return Yes(f.mounted) end },
	{ "casting", function()
		return Yes(ns.Flag(UnitCastingInfo("player")) or ns.Flag(UnitChannelInfo("player")))
	end, function(f) return Yes(f.casting) end },
	-- (The place: as ns.GetPlaceType worked it out before 0986748, asked now.)
	{ "place", function()
		local onTaxi = ns.OnTaxi()
		if ns.IsInCity() then return not onTaxi and "city" or "none" end
		local inInstance, kind = IsInInstance()
		if inInstance and (kind == "party" or kind == "scenario") then return "dungeon" end
		if inInstance and kind == "raid" then return "raid" end
		if inInstance and (kind == "pvp" or kind == "arena") then return "pvp" end
		if IsResting() and not onTaxi then return "inn" end
		return "none"
	end, function() return tostring(ns.GetPlaceType() or "none") end },
}
local RULE = "warrior or paladin or hunter or rogue or priest or deathknight or shaman or mage or warlock or monk"
	.. " or druid or demonhunter or evoker or tank or healer or damage or group or flagged or afk or resting or dead"
	.. " or mounted or casting"

-- The game's events, the last 3 s of them (all but the noisy ones), to say
-- which one came before a stale word. Counts per event for the whole run.
local NOISE = { COMBAT_LOG_EVENT_UNFILTERED = true, UNIT_AURA = true, UNIT_POWER_UPDATE = true,
	UNIT_POWER_FREQUENT = true, UNIT_HEALTH = true, UNIT_HEALTH_FREQUENT = true, UNIT_COMBAT = true,
	NAME_PLATE_UNIT_ADDED = true, NAME_PLATE_UNIT_REMOVED = true, UPDATE_MOUSEOVER_UNIT = true,
	CURSOR_CHANGED = true, CURSOR_UPDATE = true, SPELL_UPDATE_COOLDOWN = true, ACTIONBAR_UPDATE_COOLDOWN = true,
	BAG_UPDATE_COOLDOWN = true, SPELL_UPDATE_USABLE = true, ACTIONBAR_UPDATE_USABLE = true,
	UNIT_THREAT_LIST_UPDATE = true, UNIT_THREAT_SITUATION_UPDATE = true, UNIT_FLAGS = false,
	MODIFIER_STATE_CHANGED = true, GLOBAL_MOUSE_DOWN = true, GLOBAL_MOUSE_UP = true, UNIT_MODEL_CHANGED = true,
	UPDATE_UI_WIDGET = true, UPDATE_ALL_UI_WIDGETS = true, UNIT_PORTRAIT_UPDATE = true, COMPANION_UPDATE = true }
local recorder = { list = {}, counts = {} }
local function StartRecorder()
	if recorder.frame then return end
	recorder.frame = CreateFrame("Frame")
	-- (Every event the entries and the place listen to by name, then all the
	-- rest where the client allows it.)
	for event in pairs(ns.eventFacts and ns.eventFacts.byEvent or {}) do
		pcall(recorder.frame.RegisterEvent, recorder.frame, event)
	end
	for _, event in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS",
		"PLAYER_UPDATE_RESTING" }) do
		pcall(recorder.frame.RegisterEvent, recorder.frame, event)
	end
	pcall(recorder.frame.RegisterAllEvents, recorder.frame)
	recorder.frame:SetScript("OnEvent", function(_, event, a)
		if NOISE[event] or event:find("^CHAT_MSG") then return end
		recorder.counts[event] = (recorder.counts[event] or 0) + 1
		local list = recorder.list
		list[#list + 1] = { at = GetTime(), text = a ~= nil and (event .. "(" .. tostring(a) .. ")") or event }
		if #list > 60 then table.remove(list, 1) end
	end)
end
local function StopRecorder()
	if recorder.frame then recorder.frame:UnregisterAllEvents() recorder.frame = nil end
end
local function EventsSince(at)
	local out = {}
	for _, e in ipairs(recorder.list) do
		if e.at >= at then out[#out + 1] = ("%.2f %s"):format(e.at - at, e.text) end
	end
	return #out > 0 and table.concat(out, ", ") or "none"
end

-- One comparison of every word; a word wrong for over STALE_AFTER: once,
-- a FAIL line with the events of the 3 s before. Returns the stale ones.
local watch = { since = {}, failed = {}, agreed = {}, compared = 0 }
local function Compare(r)
	local facts = ns.RuleFactsNow()
	local now = GetTime()
	watch.compared = watch.compared + 1
	for _, w in ipairs(WORDS) do
		local okLive, live = pcall(w[2])
		local okCached, cached = pcall(w[3], facts)
		live, cached = okLive and live or ("error " .. tostring(live)), okCached and cached or ("error " .. tostring(cached))
		if live == cached then
			watch.since[w[1]] = nil
			watch.agreed[w[1]] = (watch.agreed[w[1]] or 0) + 1
		else
			watch.since[w[1]] = watch.since[w[1]] or now
			if now - watch.since[w[1]] > STALE_AFTER and not watch.failed[w[1]] then
				watch.failed[w[1]] = true
				r:Fail(("%s stale %.1f s: the game says %s, the rules read %s; the game's events since 3 s before: %s")
					:format(w[1], now - watch.since[w[1]], live, cached, EventsSince(watch.since[w[1]] - 3)))
			end
		end
	end
end
local function Watch(r, seconds)
	local stop = GetTime() + seconds
	while GetTime() < stop do
		Compare(r)
		r:Sleep(SAMPLE)
	end
end
local function Snapshot(r, label)
	local facts = ns.RuleFactsNow()
	local parts = {}
	for _, w in ipairs(WORDS) do
		local okLive, live = pcall(w[2])
		local okCached, cached = pcall(w[3], facts)
		parts[#parts + 1] = ("%s %s/%s"):format(w[1], okLive and live or "error", okCached and cached or "error")
	end
	r:Log(label .. " (game/rules): " .. table.concat(parts, ", "))
end

ns.TestKit.Define({
	name = "eventfacts",
	key = "eventFactsTest",
	title = "Event rule words",
	about = "class, role, group, flags, resting, dead, mounted, casting and the place read on their events: cached vs the game",
	needs = "A mount, somewhere you can ride (step 3; Skip step if you can't)",
	files = { "Frames.lua", "Core.lua" },
	context = function()
		local n = 0
		for _ in pairs(ns.factsUsed or {}) do n = n + 1 end
		return ("event facts: %d entries, settle %.1f s; %d words named by rules before the run"):format(
			ns.eventFacts and #ns.eventFacts.list or 0, ns.eventFacts and ns.eventFacts.settle or 0, n)
	end,
	putBack = function(extra)
		StopRecorder()
		if extra.fakeGroup ~= nil then ns.fakeGroup = extra.fakeGroup ~= "<nil>" and extra.fakeGroup or nil end
		return "event recorder off, /cine debug group as it was"
	end,
	steps = {
		{ key = "rest", title = "every word, cached vs the game, at rest",
			proven = "qa1dd 2026-11-25 Forever 2/2, 24 samples", run = function(r)
			StartRecorder()
			watch.since, watch.failed, watch.agreed, watch.compared = {}, {}, {}, 0
			local test = ns.CompileRule(RULE)
			r:Verdict(test ~= nil and ns.factsUsed.mounted and ns.factsUsed.casting,
				"a rule naming every word compiled: each read (ns.factsUsed)")
			Snapshot(r, "start")
			Watch(r, 6)
			Snapshot(r, "after 6 s")
			local bad = {}
			for _, w in ipairs(WORDS) do if watch.failed[w[1]] then bad[#bad + 1] = w[1] end end
			r:Verdict(#bad == 0, ("%d samples, every word the game's answer (stale: %s)"):format(watch.compared,
				#bad > 0 and table.concat(bad, ", ") or "none"))
		end },
		{ key = "fakegroup", title = "/cine debug group party and off", proven = "qa1dd 2026-11-25 Forever 1/1", run = function(r)
			r:Keep("fakeGroup", ns.fakeGroup)
			local real = ns.Flag(IsInGroup()) and true or false
			ns.fakeGroup = "party"
			r:Sleep(1)
			local on = ns.RuleFactsNow().group
			ns.fakeGroup = nil
			r:Sleep(1)
			local off = ns.RuleFactsNow().group
			r:Verdict(on == true and off == real, ("group with the fake party %s, after %s (your real group: %s)")
				:format(tostring(on), tostring(off), tostring(real)))
			Watch(r, 1)
		end },
		{ key = "mount", title = "mount up, then get off", run = function(r)
			local before = recorder.counts.PLAYER_MOUNT_DISPLAY_CHANGED or 0
			local seen = { on = nil, off = nil }
			local lag = {}
			local liveAt, liveWas = GetTime(), ns.Flag(IsMounted()) and true or false
			local cachedWas = ns.RuleFactsNow().mounted
			local how = r:WaitFor("Mount up, then get off your mount", { check = function()
				Compare(r)
				local now = GetTime()
				local live = ns.Flag(IsMounted()) and true or false
				local cached = ns.RuleFactsNow().mounted
				if live ~= liveWas then liveAt, liveWas = now, live end
				if cached ~= cachedWas then
					cachedWas = cached
					if cached == live then lag[#lag + 1] = ("%s %.2f s"):format(live and "on" or "off", now - liveAt) end
				end
				if live then seen.on = true elseif seen.on then seen.off = true end
				return seen.on and seen.off and cached == false and "done"
			end })
			if how ~= "done" then
				r:Skip("not mounted and off: " .. tostring(how))
				return
			end
			local events = (recorder.counts.PLAYER_MOUNT_DISPLAY_CHANGED or 0) - before
			r:Log(("PLAYER_MOUNT_DISPLAY_CHANGED %d time(s); mounted followed IsMounted: %s"):format(events,
				#lag > 0 and table.concat(lag, ", ") or "no change seen"))
			r:Verdict(events >= 2, "the game sent PLAYER_MOUNT_DISPLAY_CHANGED mounting and getting off: " .. events)
			r:Verdict(not watch.failed.mounted, "mounted never stale over " .. STALE_AFTER .. " s")
		end },
		{ key = "cost", title = "ms per full working out", proven = "qa1dd 2026-11-25 Forever 2/2, 0.054 vs 0.064 ms", run = function(r)
			local N = 200
			local t0 = debugprofilestop()
			for _ = 1, N do ns.RefreshRuleFacts() end
			local now = (debugprofilestop() - t0) / N
			t0 = debugprofilestop()
			for _ = 1, N do
				ns.EventFactChanged()
				ns.placeWatch.fresh = false
				ns.RefreshRuleFacts()
			end
			local every = (debugprofilestop() - t0) / N
			ns.EventFactChanged()
			r:Log(("full working out: %.4f ms now, %.4f ms with every entry and the place asked again (%d each)")
				:format(now, every, N))
			-- (Both are tiny: a margin for the timer's noise.)
			r:Verdict(now <= every * 1.2 + 0.002, "asking only after events costs no more than asking every time")
			Watch(r, 1)
			local bad = {}
			for _, w in ipairs(WORDS) do if watch.failed[w[1]] then bad[#bad + 1] = w[1] end end
			local counts = {}
			for _, event in ipairs({ "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_UPDATE_RESTING", "PLAYER_FLAGS_CHANGED",
				"UNIT_FLAGS", "GROUP_ROSTER_UPDATE", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS",
				"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "PLAYER_SPECIALIZATION_CHANGED" }) do
				counts[#counts + 1] = event .. " " .. (recorder.counts[event] or 0)
			end
			r:Log("the game's events this run: " .. table.concat(counts, ", "))
			r:Verdict(#bad == 0, ("the whole run, %d samples: no word stale (stale: %s)"):format(watch.compared,
				#bad > 0 and table.concat(bad, ", ") or "none"))
			StopRecorder()
		end },
	},
})
