-- The explore count (Visions/CardMoments.lua's index of the game's Explore
-- achievements, a walk of the whole achievement list), every state (the audit
-- kit's matrix, Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-explore-index.md):
--   python -I Tools/offline/run.py Tools/offline/exploreindexmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/exploreindexmatrix.lua forever --base <ref>
-- What reads it ticked (nothing; Discovered; Explore progress; Achievement
-- step; Almost there; the Letterbox's bars on a new place), then the login's
-- timer ten seconds in, or an achievement's step done (CRITERIA_EARNED). Each
-- cell: whether the walk started. The rule: only when something on reads it.
local client = arg and arg[1] or "forever"
local timers = {}
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
	GetCategoryList = function() return {} end
	GetAchievementInfo = function() return 5, "Explore Elwynn Forest", 10, false end
	GetAchievementNumCriteria = function() return 0 end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db

-- (The login's timer: CardMoments.lua's, holding its explore table.)
local loginTimer, explore
for _, fn in ipairs(timers) do
	local info = debug.getinfo(fn, "S")
	if info.source:find("CardMoments.lua", 1, true) then
		for i = 1, 20 do
			local name, value = debug.getupvalue(fn, i)
			if not name then break end
			if name == "explore" then loginTimer, explore = fn, value end
		end
	end
end
assert(loginTimer, "no login timer")
local moments
for _, frame in ipairs(wow.frames) do
	local onEvent = frame._scripts and frame._scripts.OnEvent
	local info = onEvent and debug.getinfo(onEvent, "S")
	if info and info.source:find("CardMoments.lua", 1, true) and frame._events.CRITERIA_EARNED then moments = frame end
end
assert(moments, "no CRITERIA_EARNED frame")

local ROWS = { discover = "cardDiscoverOn", explore = "cardExploreOn", step = "cardStepOn", almost = "cardAlmostOn" }
local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "explore-index",
	fixed = { client = client },
	dims = {
		{ "reader", { "none", "discover", "explore", "step", "almost", "letterbox" } },
		{ "when", { "login", "criteria" } },
	},
	cell = function(c)
		db.enabled, db.visions, db.cards = true, true, true
		for key, row in pairs(ROWS) do db[row] = c.reader == key end
		db.letterboxOnDiscover = c.reader == "letterbox"
		explore.index, explore.co = nil, nil
		if explore.ticker then explore.ticker = nil end
		if c.when == "login" then
			pcall(loginTimer)
		else
			pcall(moments._scripts.OnEvent, moments, "CRITERIA_EARNED", 5, "Goldshire")
		end
		return "built=" .. (explore.index and "yes" or "no")
	end,
	pins = {
		{ "", "built=no" },
		{ "when=login reader=discover", "built=yes" },
		{ "when=login reader=explore", "built=yes" },
		{ "when=login reader=step", "built=yes" },
		{ "when=login reader=letterbox", "built=yes" },
		{ "when=criteria reader=explore", "built=yes" },
		{ "when=criteria reader=step", "built=yes" },
		{ "when=criteria reader=almost", "built=yes" },
	},
})
