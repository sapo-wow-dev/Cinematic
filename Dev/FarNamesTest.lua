-- /cine debug farnames: far names smaller (Effects.lua's ns.plates.FAR_NAME_CVARS,
-- 2026-11-23): in CineMode with names over heads on (Forever), the game
-- shrinks plates past 40 yards from the camera to 0.65 in ONE step, and our
-- names on them with them. Nothing to do: stand in a city street with NPCs
-- near and far on screen, out of combat.
--   1 held    the set holds, with its values (nameplateMinScale 0.65, the
--             two distances crossed at 40); PASS/FAIL
--   2 plates  every plate's scale: some far ones at 0.65 of the near ones,
--             and only those two scales (one step, never a gradual scale:
--             whole-pixel pops, rule all.fontstring.scale-steps-by-font-size);
--             screenshot, friendly names kept up for it
-- (Step 1 passed in run 12 but stays: it sets up step 2, names on and plates
-- near and far, at no cost to you.)
-- Into CinematicDB.farNamesTestLog. Dev copy only.
local _, ns = ...

local function Call(f, ...)
	if not f then return nil end
	local ok, a, b = pcall(f, ...)
	if ok then return a, b end
	return nil
end

local function Plain(value)
	if issecretvalue and issecretvalue(value) then return nil end
	return value
end

local function Band(unit)
	if Call(CheckInteractDistance, unit, 3) == true then return "<10yd" end
	if Call(CheckInteractDistance, unit, 4) == true then return "10-28yd" end
	return ">28yd"
end

local function Plates()
	local ok, plates = pcall(C_NamePlate.GetNamePlates)
	if not (ok and type(plates) == "table") then return {} end
	local list = {}
	for _, plate in ipairs(plates) do
		local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
		if unit and not (plate.IsForbidden and Call(plate.IsForbidden, plate)) then
			list[#list + 1] = { unit = unit, band = Band(unit), scale = Plain(Call(plate.GetEffectiveScale, plate)),
				name = Plain(Call(UnitName, unit)) }
		end
	end
	return list
end

ns.TestKit.Define({
	name = "farnames",
	key = "farNamesTest",
	title = "Far names smaller",
	about = "far plates and our names on them one step smaller in CineMode (Forever): nothing to do",
	cineMode = true,
	settings = { "plateNameStyle" },
	cvars = { "nameplateMinScale", "nameplateMaxScale", "nameplateMinScaleDistance", "nameplateMaxScaleDistance",
		"nameplateMaxDistance" },
	steps = {
		{ key = "held", title = "the set holds", run = function(r)
			if ns.isRetail then return r:Skip("retail: its plates scale themselves, the set is Forever's") end
			if InCombatLockdown() then
				r:WaitFor("Leave the fight first", { events = { "PLAYER_REGEN_ENABLED" } })
			end
			if not ns.db.plateNameStyle then r:Set("plateNameStyle", true) end
			-- (Plates near and far at once, no time limit.)
			r:WaitFor("Stand where NPCs are on screen both NEAR and FAR (past 28 yards): a city street works. "
				.. "It goes on by itself.", { check = function()
					local near, far = false, false
					for _, plate in ipairs(Plates()) do
						if plate.band == ">28yd" then far = true else near = true end
					end
					return near and far and "both" or nil
				end })
			r:Sleep(1.5) -- (the plate pass holds the set)
			local set = ns.plates and ns.plates.FAR_NAME_CVARS
			local wrong = {}
			for name, want in pairs(set and set.values or {}) do
				local now = GetCVar(name)
				if tonumber(now) ~= tonumber(want) then wrong[#wrong + 1] = ("%s %s (wants %s)"):format(name, tostring(now), want) end
			end
			r:Log(("set: %s, active %s, platesForced %s"):format(tostring(set and set.label), tostring(set and set.active),
				tostring(ns.PlatesForcedHere and ns.PlatesForcedHere(true))))
			r:Verdict(set ~= nil and set.active and #wrong == 0,
				#wrong == 0 and "held, every value as set" or ("not as set: " .. table.concat(wrong, ", ")))
		end },
		{ key = "plates", title = "far plates one step smaller", run = function(r)
			local list = Plates()
			local scales, top = {}, 0
			for i, plate in ipairs(list) do
				r:Log(("%d: %s %s, scale %s"):format(i, tostring(plate.name), plate.band, tostring(plate.scale)))
				if type(plate.scale) == "number" then
					local key = ("%.3f"):format(plate.scale)
					scales[key] = (scales[key] or 0) + 1
					top = math.max(top, plate.scale)
				end
			end
			local kinds, small, other = {}, 0, 0
			for key, count in pairs(scales) do
				kinds[#kinds + 1] = key .. " x" .. count
				local value = tonumber(key)
				if math.abs(value - top * 0.65) < 0.01 then small = small + count
				elseif math.abs(value - top) > 0.01 then other = other + count end
			end
			table.sort(kinds)
			r:Log("scales seen: " .. table.concat(kinds, ", "))
			-- (Friendly names kept up for the shot: CineMode faded them all,
			-- run 12's shot showed none. NamesTest's flag, Effects.lua.)
			ns.namesTestKeepFriends = true
			r:Sleep(1)
			r:Shot("far names smaller, friendly names kept up")
			ns.namesTestKeepFriends = nil
			r:Verdict(small > 0, ("%d plate(s) at 0.65 of the full %.3f"):format(small, top))
			r:Verdict(other == 0, ("one step only: %d plate(s) at any other scale"):format(other))
		end },
	},
})
