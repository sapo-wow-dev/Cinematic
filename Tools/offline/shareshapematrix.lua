-- A profile string's or backup's lists of the wrong shape, every state (the
-- audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-22-profiles-share-shape.md, bdb2e1d):
--   python -I Tools/offline/run.py Tools/offline/shareshapematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/shareshapematrix.lua forever --base <ref>
-- Where it comes in (a pasted profile string, a backup restored) x what the
-- list holds: the Follow HUD's (its picks and undo list, entry by entry), the
-- Mouseover groups', and a plain list (a Show in list). Each cell: whether the
-- list came in with the profile, and for the Follow HUD, what its Undo then
-- does (the Mouseover groups switch put back, the account's Enable switch).
-- The rule: a list of our own shape comes in; one that isn't (anything the
-- code would misread or that writes past the profile) is left out, whole,
-- and Undo never writes an account setting.

local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db
ns.SwitchProfileLayout = function() end -- (the stand-in has no Edit Mode)
for _, name in ipairs({ "RefreshOptions", "BuildManagedList", "RestartTimers" }) do
	if ns[name] then ns[name] = function() end end
end

local GOOD = { key = "mouseover", old = false, new = true }
local VALUES = {
	-- The Follow HUD's: { picks = {...}, undo = { entry... } }.
	["hud-good"] = { "followHud", { picks = { castBar = true }, undo = { GOOD } } },
	["hud-picksonly"] = { "followHud", { picks = { castBar = true } } },
	["hud-picks-string"] = { "followHud", { picks = "castBar", undo = { GOOD } } },
	["hud-undo-string"] = { "followHud", { picks = {}, undo = "x" } },
	["hud-entry-number"] = { "followHud", { picks = {}, undo = { GOOD, 7 } } },
	["hud-entry-nokey"] = { "followHud", { picks = {}, undo = { GOOD, { old = 1, new = 2 } } } },
	["hud-entry-account"] = { "followHud", { picks = {}, undo = { GOOD, { key = "enabled", old = false, new = true } } } },
	["hud-entry-debug"] = { "followHud", { picks = {}, undo = { GOOD, { key = "debugLog", old = true, new = false } } } },
	["hud-entry-unknown"] = { "followHud", { picks = {}, undo = { GOOD, { key = "noSuchSetting", old = 1, new = 2 } } } },
	["hud-entry-rowbad"] = { "followHud", { picks = {}, undo = { GOOD,
		{ key = "combatShow", row = true, old = false, new = true } } } },
	["hud-entry-rowok"] = { "followHud", { picks = {}, undo = { GOOD,
		{ key = "combatShow", row = "PlayerFrame", old = false, new = true } } } },
	-- Mouseover groups: a list of groups, each a table with a members list.
	["groups-good"] = { "hoverGroups", { { preset = "x", members = { "player" } } } },
	["groups-nomembers"] = { "hoverGroups", { { preset = "x" } } },
	["groups-number"] = { "hoverGroups", { 5 } },
	["groups-members-string"] = { "hoverGroups", { { preset = "x", members = "player" } } },
	-- A plain list: any table of ours (rows), not a word.
	["list-table"] = { "combatShow", { PlayerFrame = true } },
	["list-string"] = { "combatShow", "PlayerFrame" },
}
local ORDER = {}
for name in pairs(VALUES) do ORDER[#ORDER + 1] = name end
table.sort(ORDER)

local function Same(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for k, v in pairs(a) do
		if not Same(v, b[k]) then return false end
	end
	for k in pairs(b) do
		if a[k] == nil then return false end
	end
	return true
end
local function Copy(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in pairs(v) do out[k] = Copy(x) end
	return out
end
local function Word(v) return v == true and "on" or v == false and "off" or tostring(v) end

local n = 0
local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "share-shape",
	fixed = { client = client },
	dims = {
		{ "via", { "string", "backup" } },
		{ "value", ORDER },
	},
	cell = function(c)
		n = n + 1
		local key, value = VALUES[c.value][1], VALUES[c.value][2]
		db.enabled = true
		local name
		if c.via == "string" then
			local text = ns.PackShared("CINE", 1, { format = 1, version = "v2.1.25", name = "Shape" .. n,
				settings = { [key] = Copy(value), mouseover = true } })
			local read, why = ns.ReadSharedProfile(text)
			if not read then return "not read: " .. tostring(why) end
			name = "Shape" .. n
			if not ns.AddSharedProfile(name, read.settings) then return "not added" end
		else
			db.profileBackups = db.profileBackups or {}
			db.profileBackups["Shape" .. n] = { { time = 1763000000, settings = { [key] = Copy(value), mouseover = true } } }
			name = ns.RestoreBackup("Shape" .. n, 1)
			if not name then return "not restored" end
		end
		if ns.ActiveProfile() ~= name then return "not switched to" end
		local came = Same(db[key], value)
		local out = came and "taken" or "left out"
		if key == "followHud" and came then
			-- (Undo: puts back what the Follow HUD set, entry by entry.)
			db.mouseover, db.enabled = true, true
			local ok, done = pcall(ns.FollowHudUndo)
			if not ok then
				out = out .. " undo=error"
			else
				out = out .. (" undo=%s mouseover=%s enabled=%s"):format(done and "ran" or "none", Word(db.mouseover),
					Word(db.enabled))
			end
		end
		db.enabled, db.debugLog = true, nil
		return out
	end,
	pins = {
		-- (Ours: comes in; Undo puts the Mouseover groups switch back, Enable untouched.)
		{ "", "taken" },
		{ "value=hud-good", "taken undo=ran mouseover=off enabled=on" },
		{ "value=hud-entry-rowok", "taken undo=ran mouseover=off enabled=on" },
		{ "value=hud-picksonly", "taken undo=none mouseover=on enabled=on" },
		-- (Not ours: left out whole.)
		{ "value=hud-picks-string", "left out" },
		{ "value=hud-undo-string", "left out" },
		{ "value=hud-entry-number", "left out" },
		{ "value=hud-entry-nokey", "left out" },
		{ "value=hud-entry-account", "left out" },
		{ "value=hud-entry-debug", "left out" },
		{ "value=hud-entry-unknown", "left out" },
		{ "value=hud-entry-rowbad", "left out" },
		{ "value=groups-number", "left out" },
		{ "value=groups-members-string", "left out" },
		{ "value=list-string", "left out" },
	},
})
