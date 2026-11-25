-- The Cooldown Manager's v2.1.23 numbered lines carried over to the grid,
-- every state (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-23-cooldown-lines-carry-over.md, ae2cda8):
--   python -I Tools/offline/run.py Tools/offline/cooldownlinesmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/cooldownlinesmatrix.lua forever --base <ref>
-- One spell (X, on the Essential bar) with v2.1.23 settings: its own mode
-- (none, Always, Never), its bar's line (none, a Dungeons In combat line, one
-- with no place, the situations update's rule), its own line (none, a Raids line, a line with no place, the
-- rule the situations update wrote, a real rule), another spell's rule on the
-- same bar (none, the situations' rule, a real rule), and where the settings
-- come from (your live settings, a saved profile of yours switched to, a
-- profile string pasted, a backup restored after the update ran). Each cell:
-- X's mode in a dungeon fight, a dungeon out of fights, a raid fight, an
-- open-world fight, the open world out of fights, and a dungeon boss fight.
-- The rule (v2.1.23's page, the update keeps it): X's first line that fits,
-- else its own mode, else its bar's first line that fits, else the bar's
-- default; a line with no place is anywhere; another spell's lines never
-- change X.
-- Two rules true at once (cooldown-rules-overlap, fix card
-- Tools/audits/2026-11-23-cooldown-rules-overlap.md): spells A and B each
-- with a real rule of its own ("boss", or "combat": a boss fight is a fight
-- too), A's met first or second, from your live settings or a v2.1.23
-- string. Each spell does what its own rule says where it fits (v2.1.23 read
-- each spell's own lines); the grid's first scene that fits mustn't hand one
-- spell's rule to the other. (ae2cda8 lost the second spell's.)

local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db
ns.SwitchProfileLayout = function() end -- (the stand-in has no Edit Mode)
-- (What a profile switch refreshes, other addons' rows and a Reset's backup:
-- none of them read or write the Cooldown Manager's lists; most of each cell's time.)
for _, name in ipairs({ "RefreshOptions", "BuildManagedList", "RestartTimers", "RefreshTint", "ApplyBubbles",
	"ApplyUnitFrameParts", "RefreshActionBarStyle", "RefreshMinimapStyle", "RefreshQuestTrackerStyle",
	"RefreshInterfaceRecolor", "ApplyShoulderCam", "ApplyWheelSwitches", "ApplyFrameLinks", "SplitAddonRows",
	"BackupProfile", "DropCineModeWord", "ResyncVitalsLook" }) do
	if ns[name] then ns[name] = function() end end
end

local X, OTHER = 7001, 7002
local function PagesOn()
	for _, start in ipairs({ "handleCooldowns", ns.CDM_TABS.essential, ns.CDM_TABS.utility, ns.CDM_TABS.buffs }) do
		local switch = start
		while switch do
			db[switch] = true
			switch = ns.PageSwitchOf and ns.PageSwitchOf(switch) or nil
		end
	end
end
PagesOn()

-- Where you are: faked facts, as Tools/offline/cooldowngrid.lua.
local facts
ns.RuleFactsNow = function() return facts end
local MOMENTS = {
	{ "dIn", "dungeon", true }, { "dOut", "dungeon", false }, { "rIn", "raid", true },
	{ "wIn", "world", true }, { "wOut", "world", false }, { "dBoss", "dungeon", true, true },
}
local function Be(place, fight, boss)
	facts = { combat = fight, calm = false, boss = boss or false }
	if place ~= "world" then facts[place] = true end
	facts.nocombat = not facts.combat and not facts.calm
	ns.CooldownRuleFactsStale()
end

local TABLES = { "cooldownPlaceGroups", "cooldownSpellCells", "cooldownBuffCells", "cooldownGroupCells",
	"cooldownReadyOnly", "cooldownRechargeOnly", "cooldownProcOnly", "cooldownMissingOnly", "cooldownAlwaysShow",
	"cooldownNeverShow",
	"cooldownBuffMode", "cooldownGroupDefaults" }
local function Fresh()
	for _, name in ipairs(TABLES) do db[name] = {} end
	db.cooldownSpellRules, db.cooldownGroupRules, db.cooldownBuffRules = nil, nil, nil
end
local function Modes()
	local out = {}
	for _, m in ipairs(MOMENTS) do
		Be(m[2], m[3], m[4])
		out[#out + 1] = m[1] .. "=" .. tostring((ns.CooldownSpellMode(X, "essential")))
	end
	return table.concat(out, " ")
end

-- The bar's default for X at each moment, with nothing set (v2.1.23's last word).
Fresh()
local DEFAULT = {}
for _, m in ipairs(MOMENTS) do
	Be(m[2], m[3], m[4])
	DEFAULT[m[1]] = tostring((ns.CooldownSpellMode(X, "essential")))
end

local SITUATION = "(dungeon or raid) and (combat or calm)"
local OWN = { none = nil, always = "cooldownAlwaysShow", never = "cooldownNeverShow" }
local BAR = {
	none = nil,
	place = { show = "never", combat = "in", place = "dungeon" },
	noplace = { show = "never", combat = "in" },
	situation = { show = "ready", cql = SITUATION },
}
local SPELL = {
	none = nil,
	place = { show = "ready", combat = "any", place = "raid" },
	noplace = { show = "recharge", combat = "out" },
	situation = { show = "always", cql = SITUATION },
	rule = { show = "proc", cql = "boss" },
}
local OTHERS = {
	none = nil,
	situation = { show = "always", cql = SITUATION },
	rule = { show = "never", cql = "boss" },
}

-- The v2.1.23 settings of one cell, as they were saved.
local function OldSettings(c)
	local t = {}
	if OWN[c.own] then t[OWN[c.own]] = { [X] = true } end
	if BAR[c.bar] then t.cooldownGroupRules = { essential = { BAR[c.bar] } } end
	local spells = {}
	if SPELL[c.spell] then spells[X] = { SPELL[c.spell] } end
	if OTHERS[c.other] then spells[OTHER] = { OTHERS[c.other] } end
	if next(spells) then t.cooldownSpellRules = spells end
	return t
end

-- What's right: v2.1.23's reading of the lines.
local function Fits(line, m)
	if line.cql == SITUATION then return (m[2] == "dungeon" or m[2] == "raid") and m[3] end
	if line.cql == "boss" then return m[4] == true end
	local place = line.place or "any"
	if place ~= "any" and place ~= m[2] then return false end
	if line.combat == "in" then return m[3] end
	if line.combat == "out" then return not m[3] end
	return true
end
local function Right(c)
	local out = {}
	for _, m in ipairs(MOMENTS) do
		local mode
		if SPELL[c.spell] and Fits(SPELL[c.spell], m) then
			mode = SPELL[c.spell].show
		elseif c.own ~= "none" then
			mode = c.own
		elseif BAR[c.bar] and Fits(BAR[c.bar], m) then
			mode = BAR[c.bar].show
		else
			mode = DEFAULT[m[1]]
		end
		out[#out + 1] = m[1] .. "=" .. mode
	end
	return table.concat(out, " ")
end

local dims = {
	{ "from", { "live", "profile", "string", "backup" } },
	{ "own", { "none", "always", "never" } },
	{ "bar", { "none", "place", "noplace", "situation" } },
	{ "spell", { "none", "place", "noplace", "situation", "rule" } },
	{ "other", { "none", "situation", "rule" } },
}
local pins = {}
do
	local values = {}
	local function Walk(depth)
		if depth > #dims then
			local c, parts = {}, {}
			for i, dim in ipairs(dims) do
				c[dim[1]] = values[i]
				parts[#parts + 1] = dim[1] .. "=" .. values[i]
			end
			pins[#pins + 1] = { table.concat(parts, " "), Right(c) }
			return
		end
		for _, value in ipairs(dims[depth][2]) do
			values[depth] = value
			Walk(depth + 1)
		end
	end
	Walk(1)
end

local n = 0
local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "cooldown-lines",
	fixed = { client = client },
	dims = dims,
	cell = function(c)
		n = n + 1
		-- (Nothing left from the cell before: its profile, backups, lines.)
		db.liveProfile, db.profile = "Balanced", "Balanced"
		db.profiles, db.profileBackups, db.deletedProfiles, db.profileResetPoints = {}, {}, {}, {}
		Fresh()
		local old = OldSettings(c)
		local name = "Lines" .. n
		if c.from == "live" then
			for k, v in pairs(old) do db[k] = v end
			db.cooldownGridV1 = nil
			ns.RunMigrations()
		elseif c.from == "profile" then
			db.profiles[name] = old
			db.cooldownGridV1 = nil
			ns.RunMigrations()
			if not ns.SetProfile(name) then return "can't switch" end
		elseif c.from == "string" then
			local text = ns.PackShared("CINE", 1, { format = 1, version = "v2.1.23", name = name, settings = old })
			local read, why = ns.ReadSharedProfile(text)
			if not read then return "not read: " .. tostring(why) end
			if not ns.AddSharedProfile(name, read.settings) then return "not added" end
		else
			db.profileBackups[name] = { { time = 1763000000, settings = old } }
			db.cooldownGridV1 = nil
			ns.RunMigrations()
			if not ns.RestoreBackup(name, 1) then return "not restored" end
		end
		PagesOn()
		return Modes()
	end,
	pins = pins,
})

-- Two spells' rules true at once.
local RULE_SHOW = { A = { boss = "proc", fight = "recharge" }, B = { boss = "never", fight = "ready" } }
local RULE_CQL = { boss = "boss", fight = "combat" }
local function RuleFits(rule, m)
	if rule == "boss" then return m[4] == true end
	return m[3]
end
local function OverlapModes(ids)
	local out = {}
	for _, who in ipairs({ "A", "B" }) do
		local parts = {}
		for _, m in ipairs(MOMENTS) do
			Be(m[2], m[3], m[4])
			parts[#parts + 1] = m[1] .. "=" .. tostring((ns.CooldownSpellMode(ids[who], "essential")))
		end
		out[#out + 1] = who .. ": " .. table.concat(parts, " ")
	end
	return table.concat(out, " | ")
end
local overlapDims = {
	{ "from", { "live", "string" } },
	{ "a", { "boss", "fight" } },
	{ "b", { "none", "boss", "fight" } },
	{ "order", { "afirst", "bfirst" } },
}
local overlapPins = {}
do
	local values = {}
	local function Walk(depth)
		if depth > #overlapDims then
			local c, parts = {}, {}
			for i, dim in ipairs(overlapDims) do
				c[dim[1]] = values[i]
				parts[#parts + 1] = dim[1] .. "=" .. values[i]
			end
			local out = {}
			for _, who in ipairs({ "A", "B" }) do
				local rule = who == "A" and c.a or c.b
				local modes = {}
				for _, m in ipairs(MOMENTS) do
					local mode = DEFAULT[m[1]]
					if rule ~= "none" and RuleFits(rule, m) then mode = RULE_SHOW[who][rule] end
					modes[#modes + 1] = m[1] .. "=" .. mode
				end
				out[#out + 1] = who .. ": " .. table.concat(modes, " ")
			end
			overlapPins[#overlapPins + 1] = { table.concat(parts, " "), table.concat(out, " | ") }
			return
		end
		for _, value in ipairs(overlapDims[depth][2]) do
			values[depth] = value
			Walk(depth + 1)
		end
	end
	Walk(1)
end
Matrix.Run({
	name = "cooldown-rules-overlap",
	fixed = { client = client },
	dims = overlapDims,
	cell = function(c)
		n = n + 1
		db.liveProfile, db.profile = "Balanced", "Balanced"
		db.profiles, db.profileBackups, db.deletedProfiles, db.profileResetPoints = {}, {}, {}, {}
		Fresh()
		-- (Met first: the lower id, as the update sorts rows by key.)
		local ids = c.order == "afirst" and { A = X, B = OTHER } or { A = OTHER, B = X }
		local spells = { [ids.A] = { { show = RULE_SHOW.A[c.a], cql = RULE_CQL[c.a] } } }
		if c.b ~= "none" then spells[ids.B] = { { show = RULE_SHOW.B[c.b], cql = RULE_CQL[c.b] } } end
		local old = { cooldownSpellRules = spells }
		if c.from == "live" then
			for k, v in pairs(old) do db[k] = v end
			db.cooldownGridV1 = nil
			ns.RunMigrations()
		else
			local name = "Overlap" .. n
			local text = ns.PackShared("CINE", 1, { format = 1, version = "v2.1.23", name = name, settings = old })
			local read, why = ns.ReadSharedProfile(text)
			if not read then return "not read: " .. tostring(why) end
			if not ns.AddSharedProfile(name, read.settings) then return "not added" end
		end
		PagesOn()
		return OverlapModes(ids)
	end,
	pins = overlapPins,
})
