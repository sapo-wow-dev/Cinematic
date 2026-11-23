-- The once-only settings updates (Migrations.lua, Core.lua's load), run on a
-- real saved settings file with every update's done-flag taken off, so each
-- one runs again; the settings they leave are written out, sorted, to compare
-- one version of the code with another (Tools/offline/migrate-compare.py).
--
--   lua5.1 Tools/offline/migrate-test.lua <client> <toc> <SavedVariables file> <out file>
--
-- (client: forever or retail. The file's CinematicDB is read as the game
-- would; the clock is held still, so two runs give the same file.)
local client, toc, savedPath, outPath = ...
assert(client and toc and savedPath and outPath, "usage: migrate-test.lua <client> <toc> <saved file> <out file>")

local saved = {}
local chunk = assert(loadfile(savedPath))
setfenv(chunk, saved)
chunk()
local db = assert(saved.CinematicDB, "no CinematicDB in " .. savedPath)

-- Every done-flag off: a key ending in V and a number, set to true.
local stripped = 0
for key, value in pairs(db) do
	if type(key) == "string" and key:find("V%d+$") and value == true then
		db[key] = nil
		stripped = stripped + 1
	end
end

math.randomseed(1)
local ns = dofile("Tools/offline/load.lua")(client, toc, function()
	local now = 1700000000
	_G.time = function(t) return t and os.time(t) or now end
	_G.GetServerTime = function() return now end
	_G.date = function(format, at) return os.date(format, at or now) end
	_G.CinematicDB = db
end)
assert(ns.db, "the addon didn't load its settings")
if ns.migrationErrors then
	for _, problem in ipairs(ns.migrationErrors) do print("update failed: " .. problem) end
	os.exit(1)
end

-- Run again, every done-flag now set: nothing may change (an update not
-- guarded by its flag takes a setting at every login: 0fd4d31, the Cities
-- columns and tooltip fade time back to their defaults at each /reload). As
-- /cine prerelease's "migrations: run again" smoke, offline, on your own
-- settings. (Keys that are logs and per-session state left out, as there.)
local QUIET = { log = true, sweepLog = true, sweepPending = true, prerelease = true, prereleaseLog = true,
	selfTest = true, pageTimes = true, profiler = true, slashUsage = true, savedCVars = true, profiles = true,
	hubLastTab = true, hubKept = true, sectionsOpen = true, chatCamDebug = true, smartFindLooks = true }
local function Copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for k, v in pairs(value) do result[k] = Copy(v) end
	return result
end
local function Same(a, b)
	if a == b then return true end
	if type(a) == "number" and type(b) == "number" then return math.abs(a - b) < 1e-6 end
	if type(a) ~= "table" or type(b) ~= "table" then return false end
	for k, v in pairs(a) do
		if not Same(v, b[k]) then return false end
	end
	for k in pairs(b) do
		if a[k] == nil then return false end
	end
	return true
end
if ns.RunMigrations then
	local before = {}
	for k, v in pairs(db) do
		if not QUIET[k] then before[k] = Copy(v) end
	end
	ns.migrationErrors = nil
	ns.RunMigrations()
	local changed = {}
	for k, v in pairs(before) do
		if not Same(v, db[k]) then changed[#changed + 1] = tostring(k) end
	end
	for k in pairs(db) do
		if before[k] == nil and not QUIET[k] then changed[#changed + 1] = tostring(k) end
	end
	table.sort(changed)
	if ns.migrationErrors then
		for _, problem in ipairs(ns.migrationErrors) do print("update failed on a second run: " .. problem) end
		os.exit(1)
	end
	if #changed > 0 then
		for _, key in ipairs(changed) do
			print(("update failed: a second run changed %s (%s -> %s)"):format(key, tostring(before[key]),
				tostring(db[key])))
		end
		os.exit(1)
	end
end

-- Sorted, so equal settings give equal files.
local out = {}
local function Key(k)
	return type(k) == "string" and ("%q"):format(k) or tostring(k)
end
local function Value(v)
	if type(v) == "number" then return ("%.14g"):format(v) end
	if type(v) == "string" then return ("%q"):format(v) end
	return tostring(v)
end
local seen = {}
local function Dump(t, path)
	if seen[t] then out[#out + 1] = path .. " = (seen above)" return end
	seen[t] = true
	local keys = {}
	for k in pairs(t) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b)
		if type(a) == type(b) and (type(a) == "string" or type(a) == "number") then return a < b end
		return type(a) < type(b)
	end)
	for _, k in ipairs(keys) do
		local v, here = t[k], path .. "[" .. Key(k) .. "]"
		if type(v) == "table" then
			if next(v) == nil then out[#out + 1] = here .. " = {}" else Dump(v, here) end
		elseif type(v) ~= "function" and type(v) ~= "userdata" then
			out[#out + 1] = here .. " = " .. Value(v)
		end
	end
	seen[t] = nil
end
Dump(_G.CinematicDB, "db")
local file = assert(io.open(outPath, "w"))
file:write(table.concat(out, "\n"), "\n")
file:close()
print(("%s: %d done-flags taken off, %d lines written to %s"):format(client, stripped, #out, outPath))
