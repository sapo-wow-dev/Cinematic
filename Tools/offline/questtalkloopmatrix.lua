-- Quest Talk's two loops (Visions/QuestTalk.lua: the window watcher, a few
-- times a second, and the bubble's follower, every frame), every state (the
-- audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-25-quest-talk-loops.md):
--   python -I Tools/offline/run.py Tools/offline/questtalkloopmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/questtalkloopmatrix.lua forever --base <ref>
-- Quest Vision's page on or off, its Quest talk tick, CineMode on or off and
-- Allow outside CineMode ticked or not, and gamepad mode with "the game's
-- windows with a gamepad" (questTalkPadGame). No talk up. Each cell: whether
-- each loop runs. The rule: only while Quest talk can show (its setting as
-- the file reads it), or ours still show.
local client = arg and arg[1] or "forever"
local tickers = {}
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	C_Timer.NewTicker = function(_, fn)
		local handle = { fn = fn }
		function handle.Cancel() handle.cancelled = true end
		tickers[#tickers + 1] = handle
		return handle
	end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db

-- (Whether fn leads to a function of QuestTalk.lua's: the loops' wrappers,
-- ns.FeatureLoop's, hold it as an upvalue, or in their loop's table.)
local memo = {}
local function FromQuestTalk(fn)
	if memo[fn] ~= nil then return memo[fn] end
	local seen = {}
	local function Walk(f, depth)
		if depth > 6 or seen[f] or type(f) ~= "function" then return false end
		seen[f] = true
		local info = debug.getinfo(f, "S")
		if info and info.source and info.source:find("QuestTalk.lua", 1, true) then return true end
		for i = 1, 60 do
			local name, value = debug.getupvalue(f, i)
			if not name then break end
			if Walk(value, depth + 1) then return true end
			-- (A timed loop's tick reads its loop's table: { run = ... }.)
			if type(value) == "table" and Walk(rawget(value, "run"), depth + 1) then return true end
		end
		return false
	end
	memo[fn] = Walk(fn, 0)
	return memo[fn]
end
local function Follower()
	for _, frame in ipairs(wow.frames) do
		local update = frame._scripts and frame._scripts.OnUpdate
		if update and FromQuestTalk(update) then return true end
	end
	return false
end
local function Watcher()
	for _, handle in ipairs(tickers) do
		if not handle.cancelled and FromQuestTalk(handle.fn) then return true end
	end
	return false
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "quest-talk-loops",
	fixed = { client = client },
	dims = {
		{ "page", { "on", "off" } },
		{ "talk", { "on", "off" } },
		{ "cine", { "on", "off" } },
		{ "outside", { "on", "off" } },
		{ "pad", { "game", "no" } },
	},
	cell = function(c)
		db.enabled, db.visions = true, true
		db.questVision = c.page == "on"
		db.questTalk = c.talk == "on"
		db.outsideCineQuest = c.outside == "on"
		ns.lastCinematic = c.cine == "on" or nil
		db.questTalkPadGame = c.pad == "game"
		ns.IsGamePadOn = function() return c.pad == "game" end
		if ns.RefreshQuestTalk then ns.RefreshQuestTalk() end
		ns.SyncFeatureLoops() -- (the once-a-second gate)
		return ("follower=%s watcher=%s"):format(Follower() and "on" or "off", Watcher() and "on" or "off")
	end,
	pins = {
		{ "", "follower=off watcher=off" },
		{ "page=on talk=on cine=on pad=no", "follower=on watcher=on" },
		{ "page=on talk=on outside=on pad=no", "follower=on watcher=on" },
	},
})
