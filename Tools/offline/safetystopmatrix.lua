-- A safety stop putting back the game settings Cinematic holds, every state
-- (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-22-cameras-safety-stop.md):
--   python -I Tools/offline/run.py Tools/offline/safetystopmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/safetystopmatrix.lua --base bdb2e1d^ --new bdb2e1d
-- A set of game settings is held as the stop comes (ns.Suspend: repeated
-- errors, /cine stop): a camera one like the death camera's or the fly-by's
-- (camera follow at 0), the flight's own (FLIGHT_CVARS, the one let go before),
-- or a secure one (a nameplate setting, which the game refuses in fights);
-- alone, or with another set holding the same setting; in a fight or not;
-- with the setting left alone on the Game Settings page (Keep yours) or not.
-- Each cell: the setting right after the stop, once the fight's over, and
-- how many of the sets still hold it. The rule: a safety stop puts every
-- setting back as yours (a secure one once the fight ends) and nothing holds
-- it after. (bdb2e1d: only the flight's and recenter's sets were let go, so a
-- stop mid fly-by or while dead left camera follow at 0 for the session.)

local client = arg and arg[1] or "forever"
local cvars = {}
local fight = false
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	GetCVar = function(name) return cvars[name] end
	SetCVar = function(name, value) cvars[name] = tostring(value) end
	InCombatLockdown = function() return fight end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
ns.db.enabled = true

local YOURS, HELD, OTHER = "4", "0", "2"
local function State(cvar)
	local now = cvars[cvar]
	return now == YOURS and "yours" or now == HELD and "held" or now == OTHER and "other" or tostring(now)
end

local Matrix = dofile("Tools/offline/matrix.lua")
local n = 0
Matrix.Run({
	name = "safety-stop",
	fixed = { client = client },
	dims = {
		{ "set", { "camera", "flight", "secure" } },
		{ "shared", { "alone", "shared" } },
		{ "fight", { "out", "in" } },
		{ "kept", { "no", "yes" } },
	},
	cell = function(c)
		n = n + 1
		fight = false
		if ns.IsSuspended and ns.IsSuspended() then ns.Resume() end
		local cvar = c.set == "secure" and "nameplateMatrixTest" or "cameraSmoothStyle"
		cvars[cvar] = YOURS
		ns.db.savedCVars[cvar] = nil
		ns.db.cvarsLeftAlone = c.kept == "yes" and { [cvar] = true } or nil
		local main
		if c.set == "flight" then
			main = ns.FLIGHT_CVARS
			if not main then return "no FLIGHT_CVARS" end
		else
			main = ns.CVarSet("Matrix held " .. n, "test",
				{ values = { [cvar] = HELD }, secure = c.set == "secure" or nil })
		end
		local other
		if c.shared == "shared" then
			other = ns.CVarSet("Matrix other " .. n, "test",
				{ values = { [cvar] = OTHER }, secure = c.set == "secure" or nil })
			ns.ApplyCVarSet(other, true)
		end
		ns.ApplyCVarSet(main, true)
		fight = c.fight == "in"
		ns.Suspend("matrix test")
		local now = State(cvar)
		fight = false
		wow.Fire("PLAYER_REGEN_ENABLED")
		local held = (main.active and 1 or 0) + (other and other.active and 1 or 0)
		local out = ("now=%s after=%s held=%d"):format(now, State(cvar), held)
		-- (Let go and resumed for the next cell.)
		if other then ns.ApplyCVarSet(other, false) end
		ns.ApplyCVarSet(main, false)
		ns.Resume()
		ns.db.cvarsLeftAlone = nil
		return out
	end,
	pins = {
		-- (Yours at once, nothing holding it.)
		{ "", "now=yours after=yours held=0" },
		-- (A secure one in a fight: the game won't take it till the fight ends.)
		{ "set=secure fight=in", "now=held after=yours held=0" },
		-- (Left alone on the Game Settings page: never written, yours throughout.)
		{ "kept=yes", "now=yours after=yours held=0" },
	},
})
