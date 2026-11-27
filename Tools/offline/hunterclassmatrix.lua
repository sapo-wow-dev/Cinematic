-- The hunter's right-click pull (QoL/Hunter.lua, Classic Era only) on a hunter
-- and on any other class, every state (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-hunter-class.md):
--   python -I Tools/offline/run.py Tools/offline/hunterclassmatrix.lua hunter < /dev/null
--   python -I Tools/offline/run.py Tools/offline/hunterclassmatrix.lua warrior < /dev/null
--   python -I Tools/audit.py diff Tools/offline/hunterclassmatrix.lua warrior --base <ref>
-- Loaded as a Classic Era character of the class asked (the file only runs on
-- Classic Era, whatever the client). The Hunter page on or off, Right click
-- attack also uses Auto-shot on or off, reached from the page's switch
-- (ns.RefreshHunterPull) or a profile switch/Reset (ns.SettingsChanged), the
-- mouse on a living enemy or on nothing, out of a fight.
-- Each cell: whether the fight's state driver is registered (it binds
-- right-click over enemies in fights), whether right-click is bound to the
-- pull button now, whether the every-frame watch runs, whether the pull
-- button has its macro.
-- The rule (the user, 2026-11-25): on a non-hunter nothing in Hunter.lua ever
-- binds or drives anything, whatever the setting, page or profile; a hunter
-- as before. (6e67ddd's page switch and profile refresh registered the
-- driver for every class: right-click on an enemy in a fight did nothing on
-- a warrior till /reload, the button having no macro.)
local class = arg and arg[1] or "warrior"
local CLASSES = { hunter = { "Hunter", "HUNTER", 3 }, warrior = { "Warrior", "WARRIOR", 1 } }
local classInfo = assert(CLASSES[class], "hunterclassmatrix: hunter or warrior")

local driver = {} -- frame -> the state driver's rule
local overrides = {} -- owner -> { key = button name }
local attrs = setmetatable({}, { __mode = "k" })
local mouse = "none"
local function Install(wow)
	-- luacheck: push ignore 111 112 113 121 122
	GetBuildInfo = function() return "1.15.7", "0", "", 11507 end
	UnitClass = function() return classInfo[1], classInfo[2], classInfo[3] end
	GetTime = function() return 1000 end
	RegisterStateDriver = function(frame, state, rule)
		if state == "pull" then driver[frame] = rule end
	end
	UnregisterStateDriver = function(frame, state)
		if state == "pull" then driver[frame] = nil end
	end
	SetOverrideBindingClick = function(owner, _, key, name)
		overrides[owner] = overrides[owner] or {}
		overrides[owner][key] = name
	end
	ClearOverrideBindings = function(owner) overrides[owner] = nil end
	IsMouseButtonDown = function() return false end
	UnitAffectingCombat = function() return false end
	UnitIsDeadOrGhost = function() return false end
	IsMounted = function() return false end
	UnitOnTaxi = function() return false end
	UnitExists = function(unit) return unit == "mouseover" and mouse == "enemy" or unit == "player" end
	UnitIsDead = function() return false end
	UnitCanAttack = function(_, unit) return unit == "mouseover" and mouse == "enemy" end
	-- (A profile's refresh reads Edit Mode's layouts: none, the first preset active.)
	C_EditMode = { GetLayouts = function() return { layouts = {}, activeLayout = 1 } end,
		SetActiveLayout = function() end }
	-- luacheck: pop
	local Set = wow.Methods.SetAttribute
	wow.Methods.SetAttribute = function(self, key, value)
		attrs[self] = attrs[self] or {}
		attrs[self][key] = value
		if Set then return Set(self, key, value) end
	end
end
local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", Install)
local db = ns.db

-- (The watcher by its script, Hunter.lua's: a warrior's let go of its events at login.)
local watcher, pullButton
for _, frame in ipairs(wow.frames) do
	if frame._name == "CinematicHunterPullButton" then pullButton = frame end
	local run = frame._scripts and frame._scripts.OnEvent
	local info = run and debug.getinfo(run, "S")
	if info and info.source and info.source:find("[/\\]Hunter%.lua$") then watcher = frame end
end

-- (A few frames and a second: the watch sets or lets go, the loops are synced.)
local function Settle()
	for _ = 1, 3 do
		local run = watcher and watcher:GetScript("OnUpdate")
		if run then pcall(run, watcher, 0.02) end
		if ns.SyncFeatureLoops then ns.SyncFeatureLoops() end
	end
end
local function Refresh(via)
	if via == "profile" then
		ns.SettingsChanged()
	elseif ns.RefreshHunterPull then
		ns.RefreshHunterPull()
	else
		-- (Code before 6e67ddd has no page-switch refresh: an error, so audit.py
		-- reads "old code errors", not a cell the switch never reached.)
		error("no ns.RefreshHunterPull in this code")
	end
	Settle()
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "hunter-class-" .. class, -- (one run per class: a card's row names the class's)
	fixed = { client = "era", class = class },
	dims = {
		{ "page", { "on", "off" } },
		{ "tick", { "on", "off" } },
		{ "via", { "pageSwitch", "profile" } },
		{ "mouse", { "enemy", "none" } },
	},
	cell = function(c)
		if not ns.isClassicEra then return "not era" end
		if not watcher then return "no watcher" end
		-- (Everything off first, the way the cell reaches its state.)
		mouse = "none"
		db.handleHunter, db.hunterRightClickShot = false, false
		Refresh(c.via)
		mouse = c.mouse
		db.handleHunter, db.hunterRightClickShot = c.page == "on", c.tick == "on"
		Refresh(c.via)
		local driven = false
		for _ in pairs(driver) do driven = true end
		local bound = false
		for _, keys in pairs(overrides) do
			if keys.BUTTON2 then bound = true end
		end
		local macro = pullButton and attrs[pullButton] and attrs[pullButton].macrotext
		return ("driver=%s bind=%s loop=%s macro=%s"):format(driven and "on" or "off", bound and "ours" or "none",
			watcher:GetScript("OnUpdate") and "on" or "off", macro and "set" or "none")
	end,
	pins = {
		-- (Not a hunter: nothing, ever.)
		{ "class=warrior", "driver=off bind=none loop=off macro=none" },
		-- (A hunter: the button has its macro; the rest only with the page and the tick on.)
		{ "class=hunter", "driver=off bind=none loop=off macro=set" },
		{ "class=hunter page=on tick=on", "driver=on bind=none loop=on macro=set" },
		{ "class=hunter page=on tick=on mouse=enemy", "driver=on bind=ours loop=on macro=set" },
	},
})
