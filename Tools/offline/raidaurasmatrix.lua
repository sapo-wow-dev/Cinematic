-- WoW Forever's raid aura stand-in (the Buffs and Debuffs rows of the raid
-- frames switch the game's own aura settings), every state (the audit kit's
-- matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-22-frames-raid-aura-fight.md):
--   python -I Tools/offline/run.py Tools/offline/raidaurasmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/raidaurasmatrix.lua --base <ref>
-- The row faded or shown; in a group or solo; the change seen in a fight or
-- out of one; the game's setting already switched off by us before (held)
-- or not. The change reaches the stand-in as a group change does (its
-- SetAlpha hook runs the same Apply; the stand-in's stub method can't carry
-- it). Each cell: the game's raidFramesDisplayBuffs right after the change
-- (during) and once the fight's over (after). The rule: auras off only while
-- the row's faded in a group; never switched in a fight (each switch has the
-- game rebuild its secure raid frames), switched as it ends. Retail fades the
-- icons themselves: no stand-in. (bdb2e1d: switched in a fight.)

local client = arg and arg[1] or "forever"
local cvars = { raidFramesDisplayBuffs = "1", raidFramesDisplayDebuffs = "1" }
local fight, grouped = false, false
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	GetCVar = function(name) return cvars[name] end
	SetCVar = function(name, value) cvars[name] = tostring(value) end
	InCombatLockdown = function() return fight end
	IsInGroup = function() return grouped end
	if client == "forever" then CompactUnitFrame_UtilSetBuff = false end -- (Forever: aura icons out of reach)
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
ns.db.enabled = true

-- (The stand-in: made by its scanner, found by its CVar set.)
local scanners
for i = 1, 10 do
	local name, value = debug.getupvalue(ns.AddScanner, i)
	if name == "scanners" then scanners = value end
end
for _, fn in ipairs(scanners or {}) do
	for i = 1, 30 do
		local name = debug.getupvalue(fn, i)
		if not name then break end
		if name == "AURA_CVAR_ROWS" then pcall(fn) end
	end
end
local set, standIn
for _, each in ipairs(ns.cvarSets) do
	if each.label == "Raid raidbuffs off" then set = each end
end
for _, frame in ipairs(wow.frames) do
	if set and frame.cvarSet == set then standIn = frame end
end
local alpha = 1
if standIn then rawset(standIn, "GetAlpha", function() return alpha end) end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	-- (Retail's own name: no stand-in there, so the card's Forever rows don't apply to it.)
	name = client == "retail" and "raid-aura-standin-retail" or "raid-aura-standin",
	fixed = { client = client },
	dims = {
		{ "row", { "faded", "shown" } },
		{ "group", { "yes", "no" } },
		{ "fight", { "yes", "no" } },
		{ "start", { "held", "free" } },
	},
	cell = function(c)
		if not standIn then return "no stand-in" end
		-- (The start: held (our 0 written) or free (the game's 1), out of a fight.)
		fight = false
		grouped, alpha = true, c.start == "held" and 0 or 1
		wow.Fire("GROUP_ROSTER_UPDATE")
		if cvars.raidFramesDisplayBuffs ~= (c.start == "held" and "0" or "1") then
			return "start not set: " .. cvars.raidFramesDisplayBuffs
		end
		fight = c.fight == "yes"
		grouped, alpha = c.group == "yes", c.row == "faded" and 0 or 1
		wow.Fire("GROUP_ROSTER_UPDATE")
		local during = cvars.raidFramesDisplayBuffs
		fight = false
		wow.Fire("PLAYER_REGEN_ENABLED")
		local out = ("during=%s after=%s"):format(during, cvars.raidFramesDisplayBuffs)
		-- (Back to free for the next cell.)
		grouped, alpha = false, 1
		wow.Fire("GROUP_ROSTER_UPDATE")
		return out
	end,
	pins = {
		-- (Out of a fight: switched at once; off only faded in a group.)
		{ "", "during=1 after=1" },
		{ "row=faded group=yes", "during=0 after=0" },
		-- (In a fight: left as it was, switched as the fight ends.)
		{ "fight=yes start=held", "during=0 after=1" },
		{ "fight=yes start=held row=faded group=yes", "during=0 after=0" },
		{ "fight=yes start=free row=faded group=yes", "during=1 after=0" },
		-- (Retail: the icons fade themselves, no stand-in.)
		{ "client=retail", "no stand-in" },
	},
})
