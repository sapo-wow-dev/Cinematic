-- Your target's name on its plate, every state (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-24-target-names-rule.md):
--   python -I Tools/offline/run.py Tools/offline/talknamesmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/talknamesmatrix.lua --base <ref>
-- A friendly NPC's plate, CineMode's plates forced on: targeted or not; the
-- Target names row with no rule, a rule saying yes, a rule saying no; its
-- kind's row (Friendly NPCs) up or down; a Service NPCs title or none (the
-- Service NPCs row up, Titles only). Each cell: how much of the name shows
-- and how much of that is its own text (0: a title in its place).
-- The rule (2026-11-24): a Target names rule decides your target's name
-- both ways; with none, or not your target, the rows add as before.
-- luacheck: push ignore 111 112 113 121 122 212
local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "Cinematic.toc")
local Matrix = dofile("Tools/offline/matrix.lua")
local now = 1000
GetTime = function() return now end
InCombatLockdown = function() return false end
UnitAffectingCombat = function() return false end

local function Upvalue(fn, name)
	for i = 1, 300 do
		local n, v = debug.getupvalue(fn, i)
		if not n then return nil end
		if n == name then return v, i end
	end
end
local PlateAlphas = Upvalue(ns.DescribePlateNameKept, "PlateAlphas")
local nameLevel = Upvalue(ns.DescribePlateNameKept, "nameLevel")
local targeted, service = false, false
local function Set(name, value)
	local _, at = Upvalue(PlateAlphas, name)
	if at then debug.setupvalue(PlateAlphas, at, value) end
end
Set("platesForced", true)
Set("PlateAlpha", function() return 0 end)
Set("PlateKind", function() return "FriendlyNPCs" end)
Set("IsTarget", function() return targeted end)
Set("PersonalPlate", function() return nil end)
Set("AlwaysShownTarget", function() return false end)
ns.PlateServiceMatch = function() return service, false end
ns.TargetNameRow = function() return "TargetFriendlyNPC" end
ns.HasTarget = function() return true end
ns.db.nameServiceShow = "title"
ns.db.frameRules = ns.db.frameRules or {}
local plate = CreateFrame("Frame")
plate.UnitFrame = CreateFrame("Frame")

Matrix.Run({
	name = "target-names-rule",
	fixed = { client = client },
	dims = { { "target", { "yes", "no" } }, { "rule", { "none", "yes", "no" } }, { "kind", { "up", "down" } },
		{ "service", { "match", "none" } } },
	cell = function(c)
		now = now + 1
		targeted, service = c.target == "yes", c.service == "match"
		ns.db.frameRules["name:YourTarget"] = c.rule == "yes" and "always" or c.rule == "no" and "never" or nil
		nameLevel.YourTarget = c.rule == "yes" and 1 or 0
		nameLevel.FriendlyNPCs = c.kind == "up" and 1 or 0
		nameLevel.ServiceNPCs, nameLevel.YourMouseover = 1, 0
		local alpha, _, name, _, text = PlateAlphas("nameplate1", plate)
		return ("name=%.0f text=%.0f"):format(alpha * name, text)
	end,
	pins = {
		{ "kind=down service=none", "name=0 text=1" },
		{ "kind=down service=match", "name=1 text=0" },
		{ "kind=up", "name=1 text=1" },
		{ "target=yes rule=yes", "name=1 text=1" },
		{ "target=yes rule=no", "name=0 text=1" },
	},
})
-- luacheck: pop
