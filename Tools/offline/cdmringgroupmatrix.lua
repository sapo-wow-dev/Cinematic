-- The drain ring and its amount on a buff group's icons (UI/CooldownRing.lua),
-- every state (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-23-cdm-ring-groups.md):
--   python -I Tools/offline/run.py Tools/offline/cdmringgroupmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/cdmringgroupmatrix.lua --base <ref>
-- Two shields (17 the lead, 1000 the other) counted as one buff or not, the
-- Ring set on the lead's row (the grid's one row for a group) or on neither,
-- Amount on or off there, and which icon is up. Each cell: whether that icon
-- has its ring, and whether the ring shows the amount.
-- The rule (release review 2026-11-23, the user's OK to fix): a group's
-- members follow its lead's row (ns.CooldownBuffKey), as every other column
-- does; not grouped, each buff has its own row.
local client = arg and arg[1] or "forever"
-- luacheck: push ignore 111 112 113 121 122 212
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
	UnitGetTotalAbsorbs = function() return 30 end
	C_Spell = C_Spell or {}
	C_Spell.GetSpellDescription = function(id)
		if id == 17 then return "A shield absorbing 44 damage." end
		if id == 1000 then return "Armor absorbing 60 damage." end
		return nil
	end
end)
-- luacheck: pop

local db = ns.db
for _, start in ipairs({ "handleCooldowns", ns.CDM_TABS.buffs, "cdmStyle" }) do
	local switch = start
	while switch do
		db[switch] = true
		switch = ns.PageSwitchOf(switch)
	end
end
db.cdmRingStyle = "pips"

local Make = CreateFrame
local function Icon(id)
	local icon = Make("Frame")
	icon.Icon = icon:CreateTexture()
	icon.spell, icon.auraInstanceID = id, 7
	return icon
end
local lead, other = Icon(17), Icon(1000)
local up = {}
ns.EachCooldownIcon = function(visit)
	for _, icon in ipairs(up) do visit(icon, icon.spell, "BuffIconCooldownViewer") end
end
ns.IconCooldownInfo = function(icon) return { spellID = icon.spell, linkedSpellIDs = { icon.spell } } end
ns.Reachable = function() return true end
ns.BaseSpell = function(id) return id end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "cdmring-groups",
	fixed = { client = client },
	dims = {
		{ "grouped", { "yes", "no" } },
		{ "ring", { "lead", "none" } },
		{ "amount", { "on", "off" } },
		{ "icon", { "lead", "other" } },
	},
	cell = function(c)
		db.cooldownRowSettings = {}
		if ns.UngroupCooldownBuff then ns.UngroupCooldownBuff(17) end
		if c.grouped == "yes" then ns.SetCooldownBuffGroup({ 17, 1000 }) end
		if c.ring == "lead" then ns.SetCooldownRow(17, "ring", "on") end
		ns.SetCooldownRow(17, "ringAmount", c.amount == "on")
		ns.SetCooldownRow(1000, "ringAmount", true) -- (the other's own, ignored in a group)
		local icon = c.icon == "lead" and lead or other
		up[1] = icon
		ns.ApplyCooldownRing()
		local ring = ns.CooldownRingOf(icon)
		local shown = ring and ring.holder:IsShown()
		local out = "ring=" .. (shown and "yes" or "no")
		if shown then out = out .. " amount=" .. (ring.text:IsShown() and "yes" or "no") end
		if ring then ring.holder:Hide() end
		return out
	end,
	pins = {
		{ "", "ring=no" },
		-- (The lead's own row: its ring, its Amount.)
		{ "ring=lead icon=lead amount=on", "ring=yes amount=yes" },
		{ "ring=lead icon=lead amount=off", "ring=yes amount=no" },
		-- (Grouped: the other follows the lead's row, Amount too.)
		{ "grouped=yes ring=lead icon=other amount=on", "ring=yes amount=yes" },
		{ "grouped=yes ring=lead icon=other amount=off", "ring=yes amount=no" },
	},
})
