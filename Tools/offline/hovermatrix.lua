-- The mouse words, every state (the audit kit's matrix, Tools/offline/matrix.lua;
-- fix card Tools/audits/2026-11-24-hover-words-gate.md):
--   python -I Tools/offline/run.py Tools/offline/hovermatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/hovermatrix.lua --base <ref>
-- A rule naming a mouse word or none, the rule editor up or not, nothing, a
-- living mob or a corpse under the mouse, its GUID plain (the world) or
-- secret (an instance). Each cell: the hover and hoverdead words after three
-- frames with the unit held still, and how often the game was asked about
-- the unit (UnitIsDeadOrGhost("mouseover")) in those frames: the cost.
-- The rule (the 2026-11-24 release review): with no rule naming a mouse word
-- and the editor down nothing is read and every word is false; otherwise the
-- words as they were (a secret GUID read every frame: it can't be compared).
-- luacheck: push ignore 111 112 113 121 122 212
local client = arg and arg[1] or "forever"
local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
	issecretvalue = function(value) return value == SECRET end
end)
local now = 100
GetTime = function() return now end
InCombatLockdown = function() return false end
UnitAffectingCombat = function() return false end
local mo, reads = nil, 0
local function Read(field, unit)
	if unit ~= "mouseover" or not mo then return nil end
	return mo[field]
end
UnitExists = function(unit)
	if unit == "mouseover" then return mo ~= nil end
	return unit == "player"
end
UnitGUID = function(unit) return Read("guid", unit) end
UnitIsDeadOrGhost = function(unit)
	if unit == "mouseover" then reads = reads + 1 end
	return Read("dead", unit) or false
end
UnitIsUnit = function() return false end
UnitIsPlayer = function() return false end
UnitCanAttack = function(_, unit) return Read("attack", unit) or false end
UnitIsFriend = function(_, unit) return not Read("attack", unit) end
UnitReaction = function() return 2 end
if client == "retail" then
	GetMouseFoci = function() return { WorldFrame } end
else
	rawset(_G, "GetMouseFoci", false)
	GetMouseFocus = function() return WorldFrame end
end
-- (The rule editor's window: a plain frame of its name stands in, shown or
-- not. The real one closes itself with the Settings window down.)
local editor = CreateFrame("Frame", nil, UIParent)
rawset(_G, "CinematicRuleEditor", editor)
editor:Hide()

local n = 0
local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "hover-words",
	fixed = { client = client },
	dims = {
		{ "rule", { "none", "hover" } },
		{ "editor", { "down", "up" } },
		{ "unit", { "none", "mob", "corpse" } },
		{ "guid", { "plain", "secret" } },
	},
	cell = function(c)
		n = n + 1
		-- (A fresh load: no rule compiled yet. A text new to the cache each
		-- cell, spaces only, so its compile is seen.)
		if ns.hoverState then ns.hoverState.used = nil end
		if c.rule == "hover" then ns.CompileRule("hoverdead or hover" .. string.rep(" ", n)) end
		if c.editor == "up" then editor:Show() else editor:Hide() end
		mo = nil
		now = now + 5
		ns.RuleFactsNow()
		if c.unit ~= "none" then
			mo = { guid = c.guid == "secret" and SECRET or ("Creature-" .. n), attack = true, dead = c.unit == "corpse" }
		end
		wow.Fire("UPDATE_MOUSEOVER_UNIT")
		reads = 0
		local facts
		for _ = 1, 3 do
			now = now + 0.02
			facts = ns.RuleFactsNow()
		end
		editor:Hide()
		return ("hover=%s dead=%s reads=%d"):format(tostring(facts.hover == true), tostring(facts.hoverdead == true),
			reads)
	end,
	pins = {
		-- (Read: a plain GUID once, then kept while it stays; a secret one every
		-- frame. One working out asks twice: HoverWords and the kind's row.)
		{ "unit=none", "hover=false dead=false reads=0" },
		{ "unit=mob guid=plain", "hover=true dead=false reads=2" },
		{ "unit=mob guid=secret", "hover=true dead=false reads=6" },
		{ "unit=corpse guid=plain", "hover=true dead=true reads=2" },
		{ "unit=corpse guid=secret", "hover=true dead=true reads=6" },
		-- (No rule with a mouse word, the editor down: nothing read, all false.)
		{ "rule=none editor=down", "hover=false dead=false reads=0" },
	},
})
-- luacheck: pop
