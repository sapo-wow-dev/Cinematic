-- Friendly plate rows, answered in one pass (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/friendrows.lua <forever|retail> [SavedVariables file]
-- ns.plates.FriendRowWanted went over every setting itself, six times every
-- 10 s (6-9 ms spikes, Tools/perf/ledger.md 2026-11-22). Now one pass,
-- FriendRowsTicked, answers all six. Checked against the old code (copied
-- below) on the real saved settings when given (else the fresh install's):
-- every row set, names or not, every place, PvP flagged or not, and each
-- candidate key ticked on its own. Prints both timings. PASS or FAIL.
-- luacheck: push ignore 111 112 113 121 122 143
local client = arg and arg[1] or "forever"
local svPath = arg and arg[2]
package.path = "Tools/offline/?.lua;" .. package.path
local wow = dofile("Tools/offline/wow.lua")
wow.Install(client)
local ns = {}
for line in io.lines("Cinematic.toc") do
	line = line:gsub("\r", "")
	if line ~= "" and not line:find("^#") then
		local chunk = loadfile((line:gsub("\\", "/")))
		if chunk then
			local ok, err = pcall(chunk, "Cinematic", ns)
			if not ok then wow.Warn(line .. ": " .. tostring(err)) end
		end
	end
end
wow.Fire("ADDON_LOADED", "Cinematic")
wow.Fire("PLAYER_LOGIN")
-- luacheck: pop

local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. text)
	if not ok then failed = failed + 1 end
end

local p = ns.plates
Check(p and p.FriendRowsTicked and p.FriendRowWanted, "FriendRowsTicked and FriendRowWanted loaded")
if not (p and p.FriendRowsTicked) then return print("1 FAILED") end

-- The real saved settings, when given.
if svPath then
	local env = {}
	local chunk = loadfile(svPath)
	if chunk then
		setfenv(chunk, env)
		pcall(chunk)
	end
	local saved = env.CinematicDB
	Check(type(saved) == "table", "saved settings read from " .. svPath)
	if type(saved) == "table" then
		for key, value in pairs(saved) do ns.db[key] = value end
	end
end
local count = 0
for _ in pairs(ns.db) do count = count + 1 end
print(("settings: %d keys"):format(count))

-- The old code, as it was before 2026-11-22.
local pvpNow = false
local function OldScan(rows, names, suffix)
	local pvp = pvpNow
	for key, value in pairs(ns.db) do
		if value == true and type(key) == "string" and not key:find("Part", 1, true) then
			local head = key:match("^plate") or (names and key:match("^name"))
			if head then
				for _, row in ipairs(rows) do
					if #key > #head + #row and key:sub(-#row) == row then
						local mid = key:sub(#head + 1, -#row - 1)
						local place = mid:match("^In(%u%a*)$")
						if not (place and place ~= suffix) and not (mid == "CombatPvP" and not pvp) then
							return true
						end
					end
				end
			end
		end
	end
	return false
end
-- (The rule half is the same in both: only the scan is compared.)
ns.RuleTest = function() return false end
UnitIsPVP = function() return pvpNow end -- luacheck: ignore 121

local suffixes = { "", "Cities", "Dungeons", "Raids", "World", "BGs", "Arenas", "PvP", "Instances" }
local seen = {}
for _, s in ipairs(suffixes) do seen[s] = true end
for key in pairs(ns.db) do
	local place = type(key) == "string" and key:match("^%l+In(%u%a*)")
	if place and not seen[place] then seen[place] = true suffixes[#suffixes + 1] = place end
end

local sets = {}
for name, rows in pairs(p.FRIEND_ROWS) do sets[#sets + 1] = { name = name, rows = rows } end
local function Compare(label)
	local bad = 0
	for _, pvp in ipairs({ false, true }) do
		pvpNow = pvp
		for _, suffix in ipairs(suffixes) do
			local ticked = p.FriendRowsTicked(suffix)
			for _, set in ipairs(sets) do
				for _, names in ipairs({ false, true }) do
					local old = OldScan(set.rows, names, suffix)
					local new = p.FriendRowWanted(set.rows, names, suffix, ticked)
					local alone = p.FriendRowWanted(set.rows, names, suffix)
					if old ~= new or old ~= alone then
						bad = bad + 1
						if bad <= 5 then
							print(("  differs: %s names=%s place=%s pvp=%s old=%s new=%s alone=%s"):format(set.name,
								tostring(names), suffix, tostring(pvp), tostring(old), tostring(new), tostring(alone)))
						end
					end
				end
			end
		end
	end
	Check(bad == 0, label .. (bad > 0 and (" (%d differ)"):format(bad) or ""))
end
Compare("same answers as before on these settings")

-- Each candidate key ticked on its own, everything else unticked.
local candidates = {}
local rowsAll = {}
for _, set in ipairs(sets) do for _, row in ipairs(set.rows) do rowsAll[row] = true end end
local function AddCandidates(source)
	for key in pairs(source or {}) do
		if type(key) == "string" and (key:find("^plate") or key:find("^name")) then
			for row in pairs(rowsAll) do
				if key:sub(-#row) == row then candidates[key] = true end
			end
		end
	end
end
AddCandidates(ns.db)
AddCandidates(ns.DEFAULTS)
-- (made-up ones too: another place's column, PvP fights, a Part key)
for _, extra in ipairs({ "plateInCitiesFriends", "plateInRaidsFriends", "plateCombatPvPGroupMembers",
	"nameCombatPvPMyPet", "plateInCitiesPartFriends", "nameInDungeonsYourTarget", "plateAlwaysYourTarget" }) do
	candidates[extra] = true
end
-- (On a small settings table: the candidates plus a few unrelated keys, so
-- each look is quick. Both codes read ns.db, so they see the same one.)
local realDb = ns.db
local small = { enabled = true, plateInCitiesFriendsHealth = true, nameNPCsWhenCity = true }
for key in pairs(candidates) do small[key] = false end
ns.db = small
local n, bad = 0, 0
for key in pairs(candidates) do
	n = n + 1
	ns.db[key] = true
	for _, pvp in ipairs({ false, true }) do
		pvpNow = pvp
		for _, suffix in ipairs(suffixes) do
			local ticked = p.FriendRowsTicked(suffix)
			for _, set in ipairs(sets) do
				for _, names in ipairs({ false, true }) do
					if OldScan(set.rows, names, suffix) ~= p.FriendRowWanted(set.rows, names, suffix, ticked) then
						bad = bad + 1
						if bad <= 5 then print("  differs with only " .. key .. " ticked, place " .. suffix) end
					end
				end
			end
		end
	end
	ns.db[key] = false
end
ns.db = realDb
Check(n > 20 and bad == 0, ("each of %d candidate keys ticked alone: same answers%s"):format(n,
	bad > 0 and (" (%d differ)"):format(bad) or ""))

-- A box ticked for the first time adds its key: seen at the next look (the
-- key list is kept between looks and made again for a new key).
pvpNow = false
local fresh = { enabled = true }
ns.db = fresh
Check(not p.FriendRowsTicked("Cities").plate.Friends, "no row ticked: Friends not wanted")
fresh.plateInCitiesFriends = true -- (a new key: through __newindex)
Check(p.FriendRowsTicked("Cities").plate.Friends == true, "a key added after the list was made: seen")
fresh.plateInCitiesFriends = false
Check(not p.FriendRowsTicked("Cities").plate.Friends, "the same key unticked: not wanted")
fresh.plateInCitiesFriends = true -- (an existing key: no __newindex, still read)
Check(p.FriendRowsTicked("Cities").plate.Friends == true, "ticked again: seen")
Check(not p.FriendRowsTicked("Raids").plate.Friends, "another place's column: not here")
Check(getmetatable(fresh) and rawget(fresh, "plateInCitiesFriends") == true, "the key is saved in the table itself")
-- (Any other new key leaves the list as it is: a fight's sound cue adds and
-- takes away combatHeldAmbience at every fight start and end, and relisting
-- all the settings for it was a 3.8 ms hitch out of each fight.)
local list = p.FriendRowsTicked("Cities").list
for _ = 1, 3 do
	fresh.combatHeldAmbience = "1"
	p.FriendRowsTicked("Cities")
	fresh.combatHeldAmbience = nil
	p.FriendRowsTicked("Cities")
end
fresh.someOtherNewSetting = 5
Check(p.FriendRowsTicked("Cities").list == list, "a new key that isn't plate.../name...: the list isn't made again")
Check(p.FriendRowsTicked("Cities").plate.Friends == true, "and the answers still hold")
fresh.nameInCitiesFriends = true -- (a new name... key: made again)
local after = p.FriendRowsTicked("Cities")
Check(after.list ~= list and after.name.Friends == true, "a new name... key: the list is made again and sees it")
list = after.list
fresh.plateInRaidsFriends = true -- (a new plate... key: made again)
Check(p.FriendRowsTicked("Raids").list ~= list and p.FriendRowsTicked("Raids").plate.Friends == true,
	"a new plate... key: the list is made again and sees it")
ns.db = realDb

-- Timing: one refresh's worth (the six row questions) old and new.
pvpNow = false
local clock = os.clock
local RUNS = 20
local started = clock()
for _ = 1, RUNS do
	for _, q in ipairs({ { "body", false }, { "minions", true }, { "target", false }, { "target", true },
		{ "players", true }, { "group", true } }) do
		OldScan(p.FRIEND_ROWS[q[1]], q[2], "Cities")
	end
end
local oldMs = (clock() - started) * 1000 / RUNS
started = clock()
for _ = 1, RUNS do
	local ticked = p.FriendRowsTicked("Cities")
	for _, q in ipairs({ { "body", false }, { "minions", true }, { "target", false }, { "target", true },
		{ "players", true }, { "group", true } }) do
		p.FriendRowWanted(p.FRIEND_ROWS[q[1]], q[2], "Cities", ticked)
	end
end
local newMs = (clock() - started) * 1000 / RUNS
print(("one refresh: old %.2f ms, new %.2f ms (%.1fx)"):format(oldMs, newMs, oldMs / math.max(newMs, 0.001)))
Check(newMs < oldMs, "new is faster")

print(failed == 0 and "ALL PASSED" or (failed .. " FAILED"))
