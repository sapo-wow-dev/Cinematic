-- Vitals Vision's low health: its edges going away when it stops being
-- wanted (Atmosphere/LowHealth.lua's Update and what wakes it), every state
-- (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-25-vitals-settle.md; what wakes it while its Health
-- tab can't show: Tools/offline/vitalswakematrix.lua):
--   python -I Tools/offline/run.py Tools/offline/vitalssettlematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/vitalssettlematrix.lua forever --base <ref>
-- Vitals on, your health secret (WoW Forever, always), plain and low, or plain
-- and full; its update left to run till it settles (secret health: asleep
-- after 3 s still, the edges left as last set). Then Vitals stops being
-- wanted, as each switch does it (with what that switch calls), or not; then
-- nothing more, or your health changing. A moment later: the edges up or
-- gone, the game's own low-health flash hidden or back, and whether a health
-- change then still wakes its update (off: it shouldn't, the CPU saving).
-- The rule: off by any switch, or CineMode ending with Allow outside CineMode
-- unticked, the edges go and the game's flash comes back; on, they stay.
local client = arg and arg[1] or "forever"
local now = 1000
local health = { kind = "secret" }
local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
local gameFlash = { alpha = 1 }
function gameFlash.SetAlpha(self, alpha) self.alpha = alpha end
function gameFlash.GetAlpha(self) return self.alpha end
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	GetTime = function() return now end
	issecretvalue = function(value) return value == SECRET end
	UnitHealth = function()
		if health.kind == "secret" then return SECRET end
		return health.kind == "low" and 100 or 1000
	end
	UnitHealthMax = function() return 1000 end
	UnitHealthPercent = function() return 0.5 end
	UnitAffectingCombat = function() return false end
	UnitIsDeadOrGhost = function() return false end
	debugstack = function() return "" end
	Enum = Enum or {}
	Enum.LuaCurveType = Enum.LuaCurveType or { Linear = 1 }
	C_CurveUtil = { CreateCurve = function() return { SetType = function() end, AddPoint = function() end } end }
	LowHealthFrame = gameFlash
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
local TAB = ns.VITALS_HEALTH_TAB

-- (An upvalue by name, a few functions deep: the edges' frame and the driver.)
local function Up(fn, want, depth)
	if type(fn) ~= "function" or (depth or 0) > 3 then return nil end
	for i = 1, 80 do
		local name, value = debug.getupvalue(fn, i)
		if not name then break end
		if name == want and value ~= nil then return value end
	end
	for i = 1, 80 do
		local name, value = debug.getupvalue(fn, i)
		if not name then break end
		local found = Up(value, want, (depth or 0) + 1)
		if found then return found end
	end
end
local edges = Up(ns.StopVitalsFlash, "frame")
local driver = Up(ns.RefreshLowHealth, "driver")
assert(edges and driver, "no Vitals frame or driver")
local events
for _, frame in ipairs(wow.frames) do
	local onEvent = frame._scripts and frame._scripts.OnEvent
	local info = onEvent and debug.getinfo(onEvent, "S")
	if info and info.source:find("LowHealth.lua", 1, true) and frame._events.UNIT_HEALTH then events = frame end
end
assert(events, "no Vitals events frame")

local function Fire(...)
	pcall(events._scripts.OnEvent, events, ...)
end
-- Its update, frame by frame (30 a second), while it's awake, for seconds.
local function Run(seconds)
	local dt = 1 / 30
	for _ = 1, math.floor(seconds / dt + 0.5) do
		now = now + dt
		if driver:IsShown() then
			local ok, err = pcall(driver._scripts.OnUpdate, driver, dt)
			if not ok then return tostring(err) end
		end
	end
end

-- How each switch turns Vitals off, with what it calls as it does.
local OFF = {
	none = function() end,
	-- (Its page's Enable Page: the page's Changed.)
	page = function()
		db.lowHealth = false
		ns.RefreshLowHealth()
	end,
	-- (Its Health tab's right-click: a tab container's switch, Options.lua's
	-- ns.TabContainer, which runs ns.tabSwitchHooks for its key.)
	tab = function()
		db[TAB] = false
		for prefix, fn in pairs(ns.tabSwitchHooks or {}) do
			if TAB:sub(1, #prefix) == prefix then fn(false) end
		end
	end,
	-- (Visions > General's Enable Visions: its switch's function.)
	visions = function()
		db.visionsAll = false
		ns.RefreshOutsideCine(true)
	end,
	-- (A profile with it off: ns.SetProfile's SettingsChanged.)
	profile = function()
		db.lowHealth = false
		if ns.SettingsChanged then pcall(ns.SettingsChanged) end
	end,
	-- (Its Health tab off with nothing called: a /run, or anything that writes
	-- the setting alone. Only a health change can tell it then.)
	quiet = function()
		db[TAB] = false
	end,
	-- (CineMode ending, Core.lua's tick: Allow outside CineMode unticked.)
	cineEnds = function()
		ns.lastCinematic = false
		ns.RefreshOutsideCine()
	end,
	-- (The same with it ticked: still wanted.)
	cineEndsAllowed = function()
		ns.lastCinematic = false
		ns.RefreshOutsideCine()
	end,
}

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "vitals-settle",
	fixed = { client = client },
	dims = {
		{ "health", { "secret", "low", "full" } },
		{ "off", { "none", "page", "tab", "visions", "profile", "quiet", "cineEnds", "cineEndsAllowed" } },
		{ "then", { "nothing", "health" } },
	},
	cell = function(c)
		db.enabled, db.visualEffects, db.visionsAll = true, true, true
		db.lowHealth, db[TAB], db.lowHealthEdges, db.lowHealthAlways = true, true, true, true
		local cine = c.off == "cineEnds" or c.off == "cineEndsAllowed"
		db.outsideCineVitals = c.off ~= "cineEnds"
		ns.lastCinematic = cine or nil
		health.kind = c.health
		-- (Wanted: woken by a health change, then left to settle, asleep with
		-- secret health once it's been still for 3 s.)
		Fire("UNIT_HEALTH", "player")
		local err = Run(6)
		if err then return "error: " .. err end
		OFF[c.off]()
		if c["then"] == "health" then Fire("UNIT_HEALTH", "player") end
		err = Run(2)
		if err then return "error: " .. err end
		local up = edges:IsShown() and "up" or "gone"
		local flash = gameFlash.alpha == 0 and "hidden" or "shown"
		-- (Then a hit with it asleep: woken or left resting.)
		driver:Hide()
		Fire("UNIT_HEALTH", "player")
		local hits = driver:IsShown() and "wake" or "rest"
		ns.lastCinematic = nil
		return ("edges=%s game=%s hits=%s"):format(up, flash, hits)
	end,
	pins = {
		-- Off by any switch, or CineMode ending with Allow outside CineMode
		-- unticked: gone, the game's flash back, hits leave it resting.
		{ "", "edges=gone game=shown hits=rest" },
		-- Still wanted: secret or low health, the edges stay (secret: the game's
		-- alpha shows them as your health says), the game's flash under them.
		{ "off=none", "edges=up game=hidden hits=wake" },
		{ "off=cineEndsAllowed", "edges=up game=hidden hits=wake" },
		{ "off=none health=full", "edges=gone game=shown hits=wake" },
		{ "off=cineEndsAllowed health=full", "edges=gone game=shown hits=wake" },
		-- (Written alone, secret health, asleep, no health change after: nothing
		-- tells it, so up till one comes (then gone, the row above). The cost of
		-- noticing (its update kept running) is what sleeping saves: the user's
		-- call, open in the card.)
		{ "off=quiet health=secret then=nothing", "edges=up game=hidden hits=wake" },
	},
})
