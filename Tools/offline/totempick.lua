-- Cooldown Manager Smart set and totems (dev tool, offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/totempick.lua < /dev/null
-- A spell with no cooldown that costs mana is When it procs by default (an
-- instant Lightning Bolt). A totem is one too, but its icon shows the totem's
-- time: once it's been put down (PLAYER_TOTEM_UPDATE, GetTotemInfo) it's left
-- to its bar (Always), kept by character. A shaman's Searing Totem never
-- showed, 2026-11-23. Says PASS or FAIL per check.
local SEARING, BOLT = 3599, 403
local totemIn = {} -- slot -> spell ID

-- luacheck: push ignore 111 112 113 121 122 212
local ns = dofile("Tools/offline/load.lua")("forever", arg and arg[1], function(wow)
	Enum = setmetatable({ PowerType = { Mana = 0, Rage = 1, Focus = 2, Energy = 3 } },
		{ __index = function() return wow.Stub end })
	GetSpellBaseCooldown = function() return 0 end
	C_Spell = setmetatable({
		GetSpellCharges = function() return nil end,
		GetSpellPowerCost = function() return { { type = 0, minCost = 50 } } end,
	}, { __index = function() return wow.Stub end })
	GetTotemInfo = function(slot)
		local id = totemIn[slot]
		return id ~= nil, "", 0, 0, 0, 1, id or 0
	end
	CinematicCharDB = nil
end)
-- luacheck: pop

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

Check("Searing Totem before it's down: When it procs", ns.SmartCooldownMode(SEARING) == "proc",
	ns.SmartCooldownMode(SEARING))
Check("Lightning Bolt: When it procs", ns.SmartCooldownMode(BOLT) == "proc")
ns.NoteTotemSlot(1) -- (an empty slot: learns nothing)
Check("an empty totem slot learns nothing", ns.SmartCooldownMode(SEARING) == "proc")
totemIn[1] = SEARING
ns.NoteTotemSlot(1)
Check("Searing Totem once down: left to its bar (Always)", ns.SmartCooldownMode(SEARING) == nil,
	ns.SmartCooldownMode(SEARING))
Check("Lightning Bolt still When it procs", ns.SmartCooldownMode(BOLT) == "proc")
Check("kept by character", type(CinematicCharDB) == "table"
	and CinematicCharDB.cooldownTotemSpells and CinematicCharDB.cooldownTotemSpells[SEARING] == true)
totemIn[1] = nil
Check("still Always once the totem's gone", ns.SmartCooldownMode(SEARING) == nil)

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
