-- The login's Last time line (or card) and its time of day under the zone
-- name, each event's Settings and Sounds tab on or off (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-cards-login-tabs.md):
--   python -I Tools/offline/run.py Tools/offline/loginlinesmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/loginlinesmatrix.lua forever --base <ref>
-- A real login with a last session saved: Last time as a card or a line under
-- the zone name; its event's (login) Settings tab and Sounds tab on or off;
-- the Zone event's Settings tab (where Time of day at login is ticked) on or
-- off. Each cell: whether the time of day shows, the Last time line or card
-- (or none), and whether its page-turn sound plays.
-- The rule: a tab off is a container: Settings off, nothing of that event
-- shows; Sounds off, no sound.
local client = arg and arg[1] or "forever"
local timers = {}
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	UnitAffectingCombat = function() return false end
	GetRealZoneText = function() return "Darkshore" end
	C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
ns.ProfileChosen = function() return true end
ns.GetPlayerSpeed = function() return 0 end -- (the login's moving check)
local shown, sounds, fired
ns.ShowTimeOfDayTitle = function(showTime, recap) shown = { time = showTime, recap = recap } end
ns.PlayCardCueSound = function(id) if id == "login" then sounds = sounds + 1 end end
local realFire = ns.Cards.Fire
ns.Cards.Fire = function(id, ...)
	-- (Handed to the cards: shown if Cards.lua lets it, its sound then Cards.lua's Show's.)
	if id == "login" then fired = ns.CardAllowed("login") and true or false return end
	return realFire(id, ...)
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "login-lines",
	fixed = { client = client },
	dims = {
		{ "under", { "card", "line" } },
		{ "loginSettings", { "on", "off" } },
		{ "loginSounds", { "on", "off" } },
		{ "zoneSettings", { "on", "off" } },
	},
	cell = function(c)
		db.enabled, db.cards, db.storyRecap, db.timeOfDayMessage = true, true, true, true
		db.storyZoneCard = false
		db.storyRecapUnder = c.under == "line"
		db.storyRecapDelay = 0
		db["tabOn:Card:login:settings"] = c.loginSettings == "on"
		db["tabOn:Card:login:sounds"] = c.loginSounds == "on"
		db["tabOn:Card:zone:settings"] = c.zoneSettings == "on"
		ns.chardb.session = { saved = time(), begun = time() - 3600, lastZone = "Darkshore",
			zones = { Darkshore = 600 }, quests = 3, bosses = 0, deaths = 0 }
		shown, sounds, fired, timers = nil, 0, false, {}
		wow.Fire("PLAYER_ENTERING_WORLD", true, false)
		for _, fn in ipairs(timers) do pcall(fn) end
		local recap = fired and "card" or (shown and shown.recap and "line") or "none"
		return ("time=%s recap=%s sound=%s"):format(shown and shown.time and "yes" or "no", recap,
			sounds > 0 and "yes" or "no")
	end,
	pins = {
		-- (Time of day: with the Zone event's Settings tab on.)
		{ "zoneSettings=on", "time=yes recap=none sound=no" },
		{ "zoneSettings=off", "time=no recap=none sound=no" },
		-- (Last time: with its Settings tab on; the line's sound with its Sounds tab on.)
		{ "under=card loginSettings=on zoneSettings=on", "time=yes recap=card sound=no" },
		{ "under=card loginSettings=on zoneSettings=off", "time=no recap=card sound=no" },
		{ "under=line loginSettings=on loginSounds=on zoneSettings=on", "time=yes recap=line sound=yes" },
		{ "under=line loginSettings=on loginSounds=on zoneSettings=off", "time=no recap=line sound=yes" },
		{ "under=line loginSettings=on loginSounds=off zoneSettings=on", "time=yes recap=line sound=no" },
		{ "under=line loginSettings=on loginSounds=off zoneSettings=off", "time=no recap=line sound=no" },
	},
})
