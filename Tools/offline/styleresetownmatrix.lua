-- Reset > "Everything in Style" and the unit and raid frames' Look from (the audit
-- kit's matrix, Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-style-reset-own.md):
--   python -I Tools/offline/run.py Tools/offline/styleresetownmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/styleresetownmatrix.lua forever --base <ref>
-- The editor's Reset "all" goes over every Style frame, Unit frames' and Raid frames'
-- too. Their Look from (ufOwn_<frame>, rfOwn_<group>: Its own look or Follows Default)
-- is a field whose set called ns.UnitStyleSetOwn / ns.RaidStyleSetOwn, gone since the
-- pages went back to their old code: Reset counted them, wrote nothing, and the next
-- Reset counted them again. The states: the frame or group, its Look from, its page's
-- switch. Each cell: whether Reset counted it, its Look from after the Reset, whether
-- the next Reset counts it again, and after Undo. The rule (Audit 2026-11-25): what
-- Reset counts it puts back (Follows Default), the next Reset counts 0 for it, Undo
-- gives its own look back.

local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local Studio = ns.Studio
local db = ns.db

local WHICH = {
	PLAYER = { frame = "unit", key = "ufOwn_PLAYER", page = "ufStyle" },
	TARGET = { frame = "unit", key = "ufOwn_TARGET", page = "ufStyle" },
	RAID = { frame = "raid", key = "rfOwn_RAID", page = "rfStyle" },
}
-- How many of Reset all's writes are this one's field (its Look from on that variant).
local function Counted(spec, id)
	local n = 0
	local field
	for _, each in ipairs(Studio.Props(Studio.frames[spec.frame])) do
		if each.prop.label == "Look from" then field = Studio.KeyOf(each.prop, id) end
	end
	for _, w in ipairs(Studio.ResetWrites("all")) do if w[1] == field then n = n + 1 end end
	return n
end
local function Word(value) return value and "own" or "default" end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "style-reset-own",
	fixed = { client = client },
	dims = {
		{ "which", { "PLAYER", "TARGET", "RAID" } },
		{ "look", { "own", "default" } },
		{ "page", { "on", "off" } },
	},
	cell = function(c)
		local spec = WHICH[c.which]
		-- (Nothing else of yours: each cell starts from the defaults.)
		for _, w in ipairs(Studio.ResetWrites("all")) do pcall(Studio.Put, w[1], w[2]) end
		for _, other in pairs(WHICH) do db[other.key] = false end
		db[spec.key] = c.look == "own"
		db[spec.page] = c.page == "on"
		local counted = Counted(spec, c.which)
		Studio.Reset("all", Studio.frames.plates)
		local after = Word(db[spec.key])
		local again = Counted(spec, c.which)
		Studio.Undo()
		local undone = Word(db[spec.key])
		db[spec.key] = false
		return ("counted=%d after=%s again=%d undo=%s"):format(counted, after, again, undone)
	end,
	pins = {
		{ "look=own", "counted=1 after=default again=0 undo=own" },
		{ "look=default", "counted=0 after=default again=0 undo=default" },
	},
})
