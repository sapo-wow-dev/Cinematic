-- The nameplates pass through a fight's Calm Timer, every state (the audit
-- kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-23-calm-plates-settle.md):
--   python -I Tools/offline/run.py Tools/offline/calmplatesmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/calmplatesmatrix.lua --base <ref>
-- A fight, then its Calm Timer (calmTime 10 s), then after it. CineMode on or
-- off, a kind ticked for fights (Enemies) or none, the kind not ticked for
-- fights (Neutral NPCs) kept up in CineMode where you are or not. Each cell,
-- at a point of the run: the Neutral NPCs' limit (combatCap, "-" = none), the
-- plates' fade level, and whether the whole pass ran on most ticks of the
-- second before ("busy") or hardly ("quiet").
-- The rule: the plates look the same as before tick by tick; only the work
-- changes. Held at 0 through the Calm Timer is settled, as in a fight
-- (2026-11-21), not a pass every tick (~27 a second, perf 2026-11-23 17:10).

local client = arg and arg[1] or "forever"
local now, locked = 1000, false
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	GetTime = function() return now end
	InCombatLockdown = function() return locked end
	UnitAffectingCombat = function() return locked end
	C_Timer.NewTicker = function() return { Cancel = function() end } end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
db.handlePlates, db.calmTime = true, 10
ns.PlateSuffix = function() return "World" end
ns.IsPvPFlagged = function() return false end -- (the stand-in's player reads as flagged)

-- (combatCap is the plate file's own: read through the pass's upvalues, the
-- same on the old code and the new.)
local function Upvalue(fn, name)
	for i = 1, 200 do
		local n, v = debug.getupvalue(fn, i)
		if not n then return nil end
		if n == name then return v end
	end
end
local combatCap = Upvalue(ns.UpdatePlates, "combatCap")

local passes = 0
local Parts = ns.UpdatePlateParts
ns.UpdatePlateParts = function(...) passes = passes + 1 return Parts(...) end

local STEP = 0.03
local function Run(cine, seconds, counts)
	local ticks, ran = 0, 0
	local stop = now + seconds
	while now < stop do
		now = now + STEP
		ticks = ticks + 1
		local before = passes
		ns.UpdatePlates(cine, STEP)
		if passes > before then ran = ran + 1 end
	end
	if counts then return ran, ticks end
end

local PHASES = {
	-- (seconds after the fight's end; the second before it is counted)
	fight = -1, calmStart = 1, calmSettled = 6, calmEnded = 10.1, after = 14,
}

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "calm-plates-settle",
	fixed = { client = client },
	dims = {
		{ "cine", { "on", "off" } },
		{ "fightKind", { "on", "off" } },
		{ "kept", { "on", "off" } },
		{ "phase", { "fight", "calmStart", "calmSettled", "calmEnded", "after" } },
	},
	cell = function(c)
		local cine = c.cine == "on"
		for _, kind in ipairs(ns.PLATE_KINDS) do
			db["plateCombat" .. kind], db["plateAlways" .. kind], db["plateGroup" .. kind] = false, false, false
			db["plateInWorld" .. kind], db["plateCinematic" .. kind] = false, false
			db["plateCombatPvP" .. kind] = false
		end
		db.plateCombatEnemies = c.fightKind == "on"
		db.plateInWorldNeutralNPCs = c.kept == "on"
		-- (A clean start: well out of any fight, settled.)
		locked = false
		now = now + 1000
		for k in pairs(combatCap) do combatCap[k] = nil end
		ns.plates.seen.at = nil
		Run(cine, 3)
		-- (A fight of 4 s.)
		locked = true
		wow.Fire("PLAYER_REGEN_DISABLED")
		local at = PHASES[c.phase]
		if at < 0 then
			Run(cine, 3)
		else
			Run(cine, 4)
			locked = false
			wow.Fire("PLAYER_REGEN_ENABLED")
			if at > 1 then Run(cine, at - 1) end
		end
		local ran, ticks = Run(cine, 1, true)
		local cap = combatCap.NeutralNPCs
		return ("cap=%s level=%.2f pass=%s"):format(cap and ("%.2f"):format(cap) or "-", ns.plates.level,
			ran > ticks / 2 and "busy" or "quiet")
	end,
	pins = {
		-- (Out of CineMode the plates are yours: nothing held, nothing to do.)
		{ "", "cap=- level=1.00 pass=quiet" },
		-- (In a fight: Neutral NPCs hidden (not ticked for fights), plates up, settled.)
		{ "cine=on phase=fight", "cap=0.00 level=1.00 pass=quiet" },
		-- (A kind ticked for fights: plates held up through the Calm Timer. Neutral
		-- NPCs fade back up where they're kept, else stay hidden: settled then.)
		{ "cine=on fightKind=on kept=on phase=calmStart", "cap=0.68 level=1.00 pass=busy" },
		{ "cine=on fightKind=on kept=on phase=calmSettled", "cap=- level=1.00 pass=quiet" },
		{ "cine=on fightKind=off kept=on phase=calmStart", "cap=0.68 level=0.32 pass=busy" },
		{ "cine=on fightKind=on kept=off phase=calmStart", "cap=0.00 level=1.00 pass=quiet" },
		{ "cine=on fightKind=on kept=off phase=calmSettled", "cap=0.00 level=1.00 pass=quiet" },
		-- (The Calm Timer's end: the plates start fading at once (0.1 s in).)
		{ "cine=on fightKind=on kept=on phase=calmEnded", "cap=- level=0.90 pass=quiet" },
		{ "cine=on fightKind=on kept=off phase=calmEnded", "cap=0.00 level=0.90 pass=quiet" },
		-- (No kind ticked for fights: the plates go as the fight ends.)
		{ "cine=on fightKind=off kept=off phase=calmStart", "cap=0.00 level=0.32 pass=busy" },
		{ "cine=on fightKind=off phase=calmSettled", "cap=- level=0.00 pass=quiet" },
		{ "cine=on fightKind=off phase=calmEnded", "cap=- level=0.00 pass=quiet" },
		{ "cine=on phase=after", "cap=- level=0.00 pass=quiet" },
	},
})
