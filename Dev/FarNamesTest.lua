-- /cine debug farnames: Far names, measured from YOU (2026-11-23, the user's
-- "from your character"): in CineMode with names over heads on (Forever),
-- our names more than 28 yards from you are one step smaller (the Name Style
-- page's Far names, ns.plates.FarStep; PlateParts' plateSightNear.out), and
-- the game's plates are held one size (they scale by the camera's distance,
-- so zooming moved them: /cine debug zoomstep). Nothing to do: stand in a
-- city street with NPCs near and far on screen, out of combat.
--   1 held    the game's plates held one size (Plates one size: min = max =
--             1, no camera step); PASS/FAIL
--   2 plates  every plate but your target's the same scale, and our NPC
--             names past 28 yards Far names' step of the near ones;
--             screenshot, friendly names kept up for it
-- (Was the game's step till 2026-11-23: its old checks would now FAIL by
-- design; the user's OK in Tools/audits/2026-11-23-far-names-step.md.)
-- Into CinematicDB.farNamesTestLog. Dev copy only.
local _, ns = ...

-- (Every return passed on: ns.PlateNameState's text is its 5th; a cap of
-- three made every name read "not shown" and step 1 waited forever, farnames
-- run 13, 2026-11-23: rule lua-multireturn-traps.)
local function Returns(ok, ...)
	if ok then return ... end
	return nil
end
local function Call(f, ...)
	if not f then return nil end
	return Returns(pcall(f, ...))
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

-- Each plate showing a name of ours: its band, the plate's scale and our size.
local function Plates()
	local ok, plates = pcall(C_NamePlate.GetNamePlates)
	if not (ok and type(plates) == "table") then return {} end
	local list = {}
	for _, plate in ipairs(plates) do
		local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
		if unit and not (plate.IsForbidden and Call(plate.IsForbidden, plate)) then
			local size, text
			if ns.PlateNameState then
				local _, _, s, _, t = Call(ns.PlateNameState, plate)
				size, text = s, t
			end
			list[#list + 1] = { unit = unit, band = Band(unit), scale = Plain(Call(plate.GetEffectiveScale, plate)),
				name = Plain(Call(UnitName, unit)), size = type(size) == "number" and size or nil,
				player = Call(UnitIsPlayer, unit) == true, target = Call(UnitIsUnit, unit, "target") == true,
				shown = type(text) == "table" and text.IsShown and text:IsShown() or false,
				out = ns.plateSightNear and ns.plateSightNear.out[plate] }
		end
	end
	return list
end

ns.TestKit.Define({
	name = "farnames",
	key = "farNamesTest",
	title = "Far names from you",
	about = "our names past 28 yards from you one step smaller, the game's camera step never held (Forever): nothing to do",
	needs = "A city street with NPCs near and far",
	cineMode = true,
	settings = { "plateNameStyle" },
	cvars = { "nameplateMinScale", "nameplateMaxScale", "nameplateMinScaleDistance", "nameplateMaxScaleDistance",
		"nameplateMaxDistance" },
	context = function()
		return ("Far names %s (step %s), Size by %s"):format(tostring(ns.db.plateNameFarStep),
			tostring(ns.plates and ns.plates.FarStep and ns.plates.FarStep()), tostring(ns.db.plateNameSizeBy))
	end,
	steps = {
		{ key = "held", title = "the game's camera step not held", run = function(r)
			if ns.isRetail then return r:Skip("retail: its plates scale themselves, Far names is Forever's") end
			if InCombatLockdown() then
				r:WaitFor("Leave the fight first", { events = { "PLAYER_REGEN_ENABLED" } })
			end
			if not ns.db.plateNameStyle then r:Set("plateNameStyle", true) end
			-- (Our names near and far at once, no time limit.)
			r:WaitFor("Stand where NPCs are on screen both NEAR and FAR (past 28 yards): a city street works. "
				.. "It goes on by itself.", { check = function()
					local near, far = false, false
					for _, plate in ipairs(Plates()) do
						if plate.shown then
							if plate.band == ">28yd" then far = true else near = true end
						end
					end
					return near and far and "both" or nil
				end })
			r:Sleep(1.5) -- (each name's step: read every quarter second, a change held a second)
			local set = ns.plates and ns.plates.FAR_NAME_CVARS
			local minNow, maxNow = GetCVar("nameplateMinScale"), GetCVar("nameplateMaxScale")
			r:Log(("set: %s, active %s, min scale %s, max %s, distances %s / %s"):format(tostring(set and set.label),
				tostring(set and set.active), tostring(minNow), tostring(maxNow), tostring(GetCVar("nameplateMaxScaleDistance")),
				tostring(GetCVar("nameplateMinScaleDistance"))))
			r:Verdict(set ~= nil and set.active and tonumber(minNow) == 1 and tonumber(maxNow) == 1,
				"the game's plates held one size (min = max = 1: no camera step)")
		end },
		{ key = "plates", title = "our far names one step smaller", run = function(r)
			local list = Plates()
			local step = ns.plates and ns.plates.FarStep and ns.plates.FarStep() or 0.8
			local scales, nearSizes, farSizes = {}, {}, {}
			for i, plate in ipairs(list) do
				r:Log(("%d: %s %s, plate scale %s, our size %s, step %s, shown %s"):format(i, tostring(plate.name), plate.band,
					tostring(plate.scale), tostring(plate.size), tostring(plate.out), tostring(plate.shown)))
				-- (A target's plate is bigger, the game's selected scale: left out.)
				if type(plate.scale) == "number" and not plate.target then scales[("%.2f"):format(plate.scale)] = true end
				-- (NPCs only: players' names have rows of their own sizes, run 13.)
				if plate.shown and plate.size and not plate.player then
					if plate.out then farSizes[#farSizes + 1] = plate.size else nearSizes[#nearSizes + 1] = plate.size end
				end
			end
			local kinds = {}
			for key in pairs(scales) do kinds[#kinds + 1] = key end
			table.sort(kinds)
			r:Verdict(#kinds == 1, ("the game's plates (not your target's): %d scale(s) (%s)"):format(#kinds,
				table.concat(kinds, ", ")))
			-- (Near: the size most near NPCs have.)
			local counts, near = {}, nil
			for _, size in ipairs(nearSizes) do
				local key = ("%.3f"):format(size)
				counts[key] = (counts[key] or 0) + 1
				if not near or counts[key] > counts[("%.3f"):format(near)] then near = size end
			end
			local ok, off = near ~= nil and #farSizes > 0, 0
			for _, size in ipairs(farSizes) do
				if math.abs(size / near - step) > 0.08 then off = off + 1 end
			end
			-- (Friendly names kept up for the shot: CineMode faded them all,
			-- run 12's shot showed none. NamesTest's flag, Effects.lua.)
			ns.namesTestKeepFriends = true
			r:Sleep(1)
			r:Shot("far names from you, friendly names kept up")
			ns.namesTestKeepFriends = nil
			r:Verdict(ok and off == 0, ("%d far name(s) at %.2f of the near %s (whole pixels), %d not"):format(#farSizes,
				step, tostring(near), off))
		end },
	},
})
