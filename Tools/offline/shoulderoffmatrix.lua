-- The Shoulder Cam giving your settings back as it goes off, every state (the
-- audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-22-cameras-shoulder-fight-off.md):
--   python -I Tools/offline/run.py Tools/offline/shoulderoffmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/shoulderoffmatrix.lua --base 7c3e0c1^ --new 7c3e0c1
-- It goes off by its key (the setting), Enable Cameras above it, or a logout, in a fight or not,
-- mid-glide (the soft target and Outline Mode held, with Keep Character
-- Centered) or not (only centering held); then it stays off (the fight ends,
-- or the next login with it off) or it's on again (turned back on in the
-- fight, or the next login with it on). On a stand-in CVar store that, as the
-- game does, refuses the soft target and outline CVars in fights (an
-- ADDON_ACTION_BLOCKED). Each cell: protected writes refused, the soft target,
-- Outline Mode and centering at the end (yours or held), and whether a soft
-- or outline value of yours is still kept to give back. The rule: nothing
-- protected written in a fight; once out of it and the glide's over, the soft
-- target and outlines are yours; centering is yours while it's off, held
-- while it's on. (7c3e0c1 fixed "off in a fight" and "logout in a fight":
-- yours were written there, refused, then forgotten for good.)

local client = arg and arg[1] or "forever"
local PROTECTED = { SoftTargetEnemy = true, SoftTargetEnemyArc = true, SoftTargetEnemyRange = true,
	OutlineEngineMode = true, RAIDOutlineEngineMode = true }
local cvars = {}
local fight = false
local blocked = 0

local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	GetCVar = function(name) return cvars[name] or "0" end
	SetCVar = function(name, value)
		if fight and PROTECTED[name] then
			blocked = blocked + 1 -- (the game's ADDON_ACTION_BLOCKED: no write)
			return
		end
		cvars[name] = tostring(value)
	end
	InCombatLockdown = function() return fight end
	-- luacheck: pop
end

local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
ns.db.shoulderCamNoticed = true
ns.db.cameraModes = true -- (Cameras > General's Enable Cameras: a fresh install's is off)
ns.db.shoulderCamTargetTurn = false -- (no turn to the target: no new glide when it's on again)

local YOURS = { SoftTargetEnemy = "1", SoftTargetEnemyArc = "0", SoftTargetEnemyRange = "20",
	OutlineEngineMode = "2", CameraKeepCharacterCentered = "1" }
local HELD = { SoftTargetEnemy = "3", SoftTargetEnemyArc = "2", SoftTargetEnemyRange = "45",
	OutlineEngineMode = "0", CameraKeepCharacterCentered = "0" }

-- The Shoulder Cam on, and what it holds now.
local function Held(glide)
	for cvar, value in pairs(YOURS) do cvars[cvar] = value end
	cvars.CameraKeepCharacterCentered = HELD.CameraKeepCharacterCentered
	local yours = { CameraKeepCharacterCentered = YOURS.CameraKeepCharacterCentered }
	if glide then
		for _, cvar in ipairs({ "SoftTargetEnemy", "SoftTargetEnemyArc", "SoftTargetEnemyRange", "OutlineEngineMode" }) do
			cvars[cvar] = HELD[cvar]
			yours[cvar] = YOURS[cvar]
		end
	end
	ns.db.shoulderCamYours = yours
	ns.db.shoulderCam = true
end

local function Is(cvars_, names)
	local mine, held = true, true
	for _, name in ipairs(names) do
		if cvars_[name] ~= YOURS[name] then mine = false end
		if cvars_[name] ~= HELD[name] then held = false end
	end
	return mine and "yours" or held and "held" or "other"
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "shoulder-off",
	fixed = { client = client },
	dims = {
		{ "how", { "key", "page", "logout" } },
		{ "fight", { "out", "in" } },
		{ "held", { "glide", "plain" } },
		{ "next", { "staysoff", "onagain" } },
	},
	cell = function(c)
		fight, blocked = false, 0
		Held(c.held == "glide")
		fight = c.fight == "in"
		if c.how ~= "logout" then
			-- (Its key, or Enable Cameras off above it.)
			local key = c.how == "key" and "shoulderCam" or "cameraModes"
			ns.db[key] = false
			ns.ApplyShoulderCam()
			if c.next == "onagain" then -- (on again, still in the fight)
				ns.db[key] = true
				ns.ApplyShoulderCam()
			end
			fight = false
			wow.Fire("PLAYER_REGEN_ENABLED")
			ns.ApplyShoulderCam() -- (its poller's next look, out of the fight)
		else
			wow.Fire("PLAYER_LOGOUT")
			fight = false
			-- (The next login: the setting as it's left then.)
			ns.db.shoulderCam = c.next == "onagain"
			ns.ApplyShoulderCam()
		end
		local yours = ns.db.shoulderCamYours or {}
		local kept = false
		for cvar in pairs(PROTECTED) do
			if yours[cvar] ~= nil then kept = true end
		end
		local out = ("blocked=%d soft=%s outline=%s centered=%s kept=%s"):format(blocked,
			Is(cvars, { "SoftTargetEnemy", "SoftTargetEnemyArc", "SoftTargetEnemyRange" }),
			Is(cvars, { "OutlineEngineMode" }), Is(cvars, { "CameraKeepCharacterCentered" }), kept and "yes" or "no")
		-- (Off again, all back, for the next cell.)
		fight = false
		ns.db.shoulderCam, ns.db.cameraModes = false, true
		ns.ApplyShoulderCam()
		ns.db.shoulderCamYours = nil
		return out
	end,
	pins = {
		-- (Off: every setting yours, nothing protected written in a fight, nothing kept.)
		{ "", "blocked=0 soft=yours outline=yours centered=yours kept=no" },
		-- (On again: centering held by it again; the soft target and outlines
		-- yours, no glide going.)
		{ "next=onagain", "blocked=0 soft=yours outline=yours centered=held kept=no" },
	},
})
