-- Damage Vision's boss recap as a boss fight ends, every state (the audit
-- kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-22-visions-damage-boss-end.md):
--   python -I Tools/offline/run.py Tools/offline/bossendmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/bossendmatrix.lua --base <ref>
-- ENCOUNTER_END with the boss's name plain, secret (the game's addon limits,
-- retail) or missing; its result a win, a wipe or secret; the Boss recap row
-- on or off. Each cell: whether a recap is queued, and the name it's titled
-- with (none: titled Boss). The rule: a recap for a win the addon can read,
-- with the row on; a secret value never handed on (a secret name titles it
-- Boss). (bdb2e1d: the secret name was handed to the recap.)
-- (Comparing a secret in the game errors; here it's a plain table, so the
-- old code's compare doesn't: only what it hands on shows.)

local client = arg and arg[1] or "forever"
local SECRET_NAME = setmetatable({}, { __tostring = function() return "secret" end })
local SECRET_WIN = setmetatable({}, { __tostring = function() return "secret" end })
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	issecretvalue = function(v) return v == SECRET_NAME or v == SECRET_WIN end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
ns.db.enabled, ns.db.damageVision = true, true

-- (The recap's timer: the queued recap read from its function's upvalue.)
local queued
local realAfter = C_Timer.After
C_Timer.After = function(delay, fn, ...) -- luacheck: ignore 122
	if type(fn) == "function" then
		for i = 1, 40 do
			local name, value = debug.getupvalue(fn, i)
			if not name then break end
			if name == "pending" and type(value) == "table" then queued = value end
		end
	end
	return realAfter(delay, fn, ...)
end

local NAMES = { plain = "Ragnaros", secret = SECRET_NAME, missing = nil }
local RESULTS = { win = 1, wipe = 0, secret = SECRET_WIN }
local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "damage-boss-end",
	fixed = { client = client },
	dims = {
		{ "name", { "plain", "secret", "missing" } },
		{ "result", { "win", "wipe", "secret" } },
		{ "recapRow", { "on", "off" } },
	},
	cell = function(c)
		ns.db.damageVisionRecapBoss = c.recapRow == "on"
		queued = nil
		wow.Fire("ENCOUNTER_START", 1, NAMES[c.name], 1, 20)
		wow.Fire("ENCOUNTER_END", 1, NAMES[c.name], 1, 20, RESULTS[c.result])
		if not queued then return "recap=none" end
		local name = queued.name
		local shown = name == nil and "none" or (name == SECRET_NAME and "secret") or tostring(name)
		return ("recap=%s name=%s"):format(tostring(queued.kind), shown)
	end,
	pins = {
		{ "", "recap=none" },
		{ "result=win recapRow=on", "recap=boss name=none" },
		{ "name=plain result=win recapRow=on", "recap=boss name=Ragnaros" },
	},
})
