-- /cine debug nameconsole: what the game's own console settings say about
-- names over heads and nameplates by distance (WoW Forever, 2026-11-23: far
-- off our names are much bigger than the game's; the user: "can we look at
-- the console for how the game draws names?"). The setting names come from
-- Wow.exe's text (Tools/tests/name-scale.md); this reads them in game and
-- tries the nameplate scale ones (rule forever.plate.no-distance-scale says
-- nameplateMinScale does nothing, 2026-10-23: rechecked). Nothing to do:
-- stand in a city with friendly NPCs near (under 10 yards), mid (10-28) and
-- far (past 28) on screen, out of combat, and leave the camera be.
--   1 settings  each candidate: value, default, the console's own help line
--               and category; plus every console command whose name has
--               name/plate/text and scale/size/dist in it (any the exe scan
--               missed)
--   2 plates    friendly plates on for the test; every plate up: its unit,
--               distance band, plate scale (own and effective) and its
--               name's; screenshot (the baseline)
--   3 minscale  nameplateMinScale 0.5, nameplateMinScaleDistance 10,
--               nameplateMaxScaleDistance 40: the same reads and a shot.
--               PASS if far plates now read smaller than near ones (the
--               game shrinking plates by distance on Forever), FAIL if every
--               plate reads the same scale
--   4 maxname   MaxUnitNameDistance's value and help (read in step 1), and
--               the soft target world text ones: logged only
-- Every setting changed is put back at the end (and at the next login after
-- a /reload mid-run). Into CinematicDB.nameConsoleTestLog. Dev copy only.
local _, ns = ...

local CANDIDATES = {
	"MaxUnitNameDistance", "MaxNameplateDistance", "nameplateMaxDistance", "nameplateMinScale", "nameplateMaxScale",
	"nameplateMinScaleDistance", "nameplateMaxScaleDistance", "nameplateSelectedScale", "nameplateLargerScale",
	"nameplateGlobalScale", "nameplateSimplifiedScale", "nameplateSize", "NamePlateSize", "NonPlayerNameplateScale",
	"SoftTargetNameplateSize", "SoftTargetWorldtextSize", "SoftTargetWorldtextNearScale",
	"SoftTargetWorldtextNearDist", "SoftTargetWorldtextFarDist", "WorldTextMinSize", "WorldTextScale_v2",
	"textScale", "userFontScale", "nameplateShowOnlyNames", "UnitNameNPC", "UnitNameFriendlySpecialNPCName",
	"nameplateShowFriends", "nameplateShowFriendlyNPCs",
}
-- (nameplateShowFriends doesn't exist on Forever, run 10.)
local FRIEND_PLATES = { nameplateShowFriendlyNPCs = "1", nameplateShowAll = "1" }
local MIN_SCALE = { nameplateMinScale = "0.5", nameplateMinScaleDistance = "10", nameplateMaxScaleDistance = "40" }

local function Text(value)
	if value == nil then return "nil" end
	if issecretvalue and issecretvalue(value) then return "secret" end
	if type(value) == "number" then return ("%.3f"):format(value) end
	return tostring(value)
end

local function Call(f, ...)
	if not f then return nil end
	local ok, a, b = pcall(f, ...)
	if ok then return a, b end
	return nil
end

-- The console's own list: [lowercase name] = its info (help, category...).
-- (ConsoleGetAllCommands: what Forever's own console calls; C_Console's
-- listed none, run 10.)
local function Commands()
	local all = _G.ConsoleGetAllCommands and Call(_G.ConsoleGetAllCommands)
	if type(all) ~= "table" or #all == 0 then all = C_Console and Call(C_Console.GetAllCommands) end
	local byName = {}
	for _, info in ipairs(type(all) == "table" and all or {}) do
		if type(info) == "table" and type(info.command) == "string" then byName[info.command:lower()] = info end
	end
	return byName, type(all) == "table" and #all or 0
end

local function Band(unit)
	if Call(CheckInteractDistance, unit, 3) == true then return 1, "<10yd" end
	if Call(CheckInteractDistance, unit, 4) == true then return 2, "10-28yd" end
	return 3, ">28yd"
end

-- Every plate up: unit, band, scales. Returns the scale per band (average).
local function LogPlates(r, title)
	-- (Run 10 read none with mobs' plates on screen: how the call went.)
	local okList, plates = false, nil
	if C_NamePlate and C_NamePlate.GetNamePlates then okList, plates = pcall(C_NamePlate.GetNamePlates) end
	r:Log(("%s: GetNamePlates ok %s, type %s, secret %s"):format(title, tostring(okList), type(plates),
		tostring(issecretvalue and issecretvalue(plates) or false)))
	if not (okList and type(plates) == "table") then plates = {} end
	local sums, counts = { 0, 0, 0 }, { 0, 0, 0 }
	r:Log(("%s: %d plates up"):format(title, #plates))
	for i, plate in ipairs(plates) do
		if plate.IsForbidden and Call(plate.IsForbidden, plate) then
			r:Log(("  %d: forbidden"):format(i))
		else
			local frame = plate.UnitFrame
			local unit = plate.namePlateUnitToken or (frame and frame.unit)
			local band, label = 3, "?"
			if unit then band, label = Band(unit) end
			local scale, effective = Call(plate.GetScale, plate), Call(plate.GetEffectiveScale, plate)
			local frameScale = frame and Call(frame.GetEffectiveScale, frame)
			local name = frame and frame.name
			local nameHeight = name and Call(name.GetStringHeight, name)
			r:Log(("  %d: %s %s, plate scale %s eff %s, frame eff %s, name height %s"):format(i,
				Text(unit and Call(UnitName, unit)), label, Text(scale), Text(effective), Text(frameScale), Text(nameHeight)))
			if type(frameScale) == "number" and not (issecretvalue and issecretvalue(frameScale)) then
				sums[band], counts[band] = sums[band] + frameScale, counts[band] + 1
			end
		end
	end
	local avg = {}
	for band = 1, 3 do avg[band] = counts[band] > 0 and sums[band] / counts[band] or nil end
	r:Log(("%s: average frame scale near %s (%d), mid %s (%d), far %s (%d)"):format(title, Text(avg[1]), counts[1],
		Text(avg[2]), counts[2], Text(avg[3]), counts[3]))
	return avg, counts
end

-- (Whether they stuck: Cinematic or the game may put one back.)
local function Stuck(r, list)
	local lines = {}
	for name, value in pairs(list) do lines[#lines + 1] = ("%s %s (wanted %s)"):format(name, Text(GetCVar(name)), value) end
	table.sort(lines)
	r:Log("after 1.5 s: " .. table.concat(lines, ", "))
end

local function SetCVars(r, list)
	for name, value in pairs(list) do
		local was = GetCVar(name)
		if was == nil then
			r:Log(("  %s: no such setting here"):format(name))
		else
			r:Keep("cvar:" .. name, was)
			local ok, err = pcall(SetCVar, name, value)
			local holder = ns.CVarHolder and ns.CVarHolder(name)
			r:Log(("  set %s %s -> %s%s (reads %s; held by %s)"):format(name, Text(was), value,
				ok and "" or (" FAILED " .. tostring(err)), Text(GetCVar(name)), holder and tostring(holder.label) or "none"))
		end
	end
end

ns.TestKit.Define({
	name = "nameconsole",
	key = "nameConsoleTest",
	title = "Name console settings",
	about = "the game's name and nameplate distance settings read, the plate scale ones tried: nothing to do",
	cvars = CANDIDATES,
	putBack = function(extra)
		if InCombatLockdown() then return "in a fight: settings not put back, /cine debug nameconsole restore after it" end
		local back = {}
		for key, value in pairs(extra) do
			local name = type(key) == "string" and key:match("^cvar:(.+)$")
			if name and type(value) == "string" then
				pcall(SetCVar, name, value)
				back[#back + 1] = name .. "=" .. value
			end
		end
		table.sort(back)
		return #back > 0 and ("settings back: " .. table.concat(back, ", ")) or "no settings to put back"
	end,
	steps = {
		{ key = "settings", title = "the candidates: value, default, help", run = function(r)
			local byName, total = Commands()
			r:Log(("console: %d commands listed"):format(total))
			for _, name in ipairs(CANDIDATES) do
				local info = byName[name:lower()]
				r:Log(("%s = %s (default %s) | type %s, category %s | help: %s"):format(name, Text(Call(GetCVar, name)),
					Text(Call(GetCVarDefault, name)), Text(info and info.commandType), Text(info and info.category),
					Text(info and info.help)))
			end
			-- (Any the exe scan missed.)
			local more = {}
			for lower, info in pairs(byName) do
				if (lower:find("name") or lower:find("plate") or lower:find("text"))
					and (lower:find("scale") or lower:find("size") or lower:find("dist")) then
					local known = false
					for _, name in ipairs(CANDIDATES) do if name:lower() == lower then known = true end end
					if not known then
						more[#more + 1] = ("%s = %s (default %s) | help: %s"):format(info.command, Text(Call(GetCVar, info.command)),
							Text(Call(GetCVarDefault, info.command)), Text(info.help))
					end
				end
			end
			table.sort(more)
			r:Log(("more name/plate/text + scale/size/dist commands: %d"):format(#more))
			for _, line in ipairs(more) do r:Log("  " .. line) end
			r:Verdict(total > 0, ("the console's list read: %d commands"):format(total))
		end },
		{ key = "plates", title = "every plate's scale, as you have it", run = function(r)
			if InCombatLockdown() then
				r:WaitFor("Leave the fight first (plate settings can't change in one)", { events = { "PLAYER_REGEN_ENABLED" } })
			end
			SetCVars(r, FRIEND_PLATES)
			r:Sleep(1.5)
			Stuck(r, FRIEND_PLATES)
			-- (Run 10 read too soon, in a field: wait, no time limit, for plates
			-- near or mid AND far at once.)
			local function Spread()
				local ok, plates = pcall(C_NamePlate.GetNamePlates)
				if not (ok and type(plates) == "table") then return nil end
				local seen = {}
				for _, plate in ipairs(plates) do
					local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
					if unit and not (plate.IsForbidden and Call(plate.IsForbidden, plate)) then seen[(Band(unit))] = true end
				end
				return (seen[1] or seen[2]) and seen[3] and "spread" or nil
			end
			r:WaitFor("Stand where NPCs are on screen both NEAR (under 28 yards) and FAR (past 28): a city street works. "
				.. "It goes on by itself once it sees both.", { check = Spread })
			local _, counts = LogPlates(r, "baseline")
			r:Shot("baseline")
			r:Verdict(counts[1] + counts[2] + counts[3] > 0, "plates up to read")
		end },
		{ key = "minscale", title = "nameplateMinScale 0.5: do far plates shrink?", run = function(r)
			if InCombatLockdown() then
				r:WaitFor("Leave the fight first (plate settings can't change in one)", { events = { "PLAYER_REGEN_ENABLED" } })
			end
			SetCVars(r, MIN_SCALE)
			r:Sleep(1.5)
			Stuck(r, MIN_SCALE)
			local avg = LogPlates(r, "min scale 0.5")
			r:Shot("min scale 0.5")
			local near, far = avg[1] or avg[2], avg[3]
			if near and far then
				r:Verdict(far < near * 0.95, ("far plates %s than near: %s vs %s"):format(far < near * 0.95 and "smaller" or
					"NOT smaller", Text(far), Text(near)))
			else
				r:Skip("no plates both near and far to compare (stand where NPCs are near and past 28 yards)")
			end
		end },
	},
})
