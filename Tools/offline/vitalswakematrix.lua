-- Vitals Vision's low health: what wakes its update (Atmosphere/LowHealth.lua's
-- events), every state (the audit kit's matrix, Tools/offline/matrix.lua; fix
-- card Tools/audits/2026-11-25-vitals-wake.md):
--   python -I Tools/offline/run.py Tools/offline/vitalswakematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/vitalswakematrix.lua forever --base <ref>
-- The Vitals page on or off, its Health tab on or off, the page's Test
-- running or not; then your health changing, your most health changing or
-- a fight starting. Each cell: whether its update loop was woken (its frame
-- shown, asleep before). The rule: woken only while the Health tab can show (the
-- page and the tab on), or a test running.
local client = arg and arg[1] or "forever"
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	UnitHealth = function() return 900 end
	UnitHealthMax = function() return 1000 end
	UnitAffectingCombat = function() return false end
	UnitIsDeadOrGhost = function() return false end
	debugstack = function() return "" end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
local TAB = ns.VITALS_HEALTH_TAB

-- (The driver: the frame whose update loop leads to LowHealth.lua's Update,
-- the function there that reads WantedTheme.)
local function CallsUpdate(f)
	for i = 1, 60 do
		local name = debug.getupvalue(f, i)
		if not name then return false end
		if name == "WantedTheme" then return true end
	end
	return false
end
local function FromLowHealth(fn)
	local seen = {}
	local function Walk(f, depth)
		if depth > 8 or seen[f] or type(f) ~= "function" then return false end
		seen[f] = true
		local info = debug.getinfo(f, "S")
		if info and info.source and info.source:find("LowHealth.lua", 1, true) and CallsUpdate(f) then return true end
		for i = 1, 60 do
			local name, value = debug.getupvalue(f, i)
			if not name then break end
			if Walk(value, depth + 1) then return true end
		end
		return false
	end
	return Walk(fn, 0)
end
local driver
for _, frame in ipairs(wow.frames) do
	local update = frame._scripts and frame._scripts.OnUpdate
	if update and FromLowHealth(update) then driver = frame end
end
assert(driver, "no Vitals driver")
local events
for _, frame in ipairs(wow.frames) do
	local onEvent = frame._scripts and frame._scripts.OnEvent
	local info = onEvent and debug.getinfo(onEvent, "S")
	if info and info.source:find("LowHealth.lua", 1, true) and frame._events.UNIT_HEALTH then events = frame end
end
assert(events, "no Vitals events frame")

local EVENTS = {
	health = { "UNIT_HEALTH", "player" },
	maxHealth = { "UNIT_MAXHEALTH", "player" },
	fight = { "PLAYER_REGEN_DISABLED" },
}
local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "vitals-wake",
	fixed = { client = client },
	dims = {
		{ "page", { "on", "off" } },
		{ "tab", { "on", "off" } },
		{ "test", { "running", "no" } },
		{ "event", { "health", "maxHealth", "fight" } },
	},
	cell = function(c)
		db.enabled, db.visualEffects = true, true
		db.lowHealth = c.page == "on"
		db[TAB] = c.tab == "on"
		db.outsideCineVitals = true
		if c.test == "running" then ns.TestLowHealth() end
		driver:Hide()
		pcall(events._scripts.OnEvent, events, unpack(EVENTS[c.event]))
		local woke = driver:IsShown()
		-- (The test put away for the next cell: run till it's over.)
		if ns.StopLowHealthTest then ns.StopLowHealthTest() end
		return "woke=" .. (woke and "yes" or "no")
	end,
	pins = {
		{ "", "woke=no" },
		{ "page=on tab=on", "woke=yes" },
		{ "test=running", "woke=yes" },
	},
})
