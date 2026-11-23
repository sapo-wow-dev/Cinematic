-- A shared profile's lists of the wrong shape (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/shareshape.lua < /dev/null
-- Audit 2026-11-22: a shared string's list settings were taken as any table.
-- The Follow HUD's undo list is written back key by key (FollowHud.lua's
-- Restore), so an imported one could write account settings (enabled,
-- customWheels) or error on an entry with no key; a Mouseover group that
-- isn't a table errored where its preset is read. Checks: the shapes taken
-- and refused (ns.KnownProfileSetting), and Restore skipping bad entries,
-- still putting back good ones. PASS or FAIL per check.

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local ns = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc")
local db = ns.db
local Known = ns.KnownProfileSetting
ns.SwitchProfileLayout = function() end -- (the stand-in has no Edit Mode)

-- 1: Follow HUD lists.
Check("1 a good undo list taken", Known("followHud", { picks = {}, undo = {
	{ key = "mouseover", old = false, new = true } } }))
Check("1 none at all taken", Known("followHud", { picks = { castBar = true } }))
Check("1 an entry with no key refused", not Known("followHud", { undo = { { old = 1, new = 2 } } }))
Check("1 an entry that isn't a table refused", not Known("followHud", { undo = { 5 } }))
Check("1 an account setting refused (enabled)", not Known("followHud", { undo = { { key = "enabled", old = false } } }))
Check("1 a debug setting refused", not Known("followHud", { undo = { { key = "debugLog", old = true } } }))
Check("1 an unknown key refused", not Known("followHud", { undo = { { key = "noSuchSetting", old = 1 } } }))
Check("1 an undo that isn't a list refused", not Known("followHud", { undo = "x" }))

-- 2: Mouseover groups.
Check("2 groups as tables taken", Known("hoverGroups", { { preset = "x", members = { "player" } } }))
Check("2 a group that's a number refused", not Known("hoverGroups", { 5 }))
Check("2 members that aren't a list refused", not Known("hoverGroups", { { members = "player" } }))

-- 3: Restore (Undo) skips what isn't a profile setting's entry, puts back the rest.
db.enabled, db.mouseover = true, true
db.followHud = { picks = {}, undo = {
	{ key = "mouseover", old = false, new = true },
	{ key = "enabled", old = false, new = true },
	{ old = 1, new = 2 },
	7,
} }
local ok, err = pcall(ns.FollowHudUndo)
Check("3 Undo runs without an error", ok, tostring(err))
Check("3 the good entry put back", db.mouseover == false, tostring(db.mouseover))
Check("3 the account setting untouched", db.enabled == true, tostring(db.enabled))
db.followHud = { undo = "not a list" }
ok, err = pcall(ns.FollowHudUndo)
Check("3 an undo that isn't a list: no error", ok, tostring(err))

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
