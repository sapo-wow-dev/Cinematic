-- /cine debug mouseplate: the Nameplates page's Mouseover row (Target
-- section, under Your target: the plate of the unit under the mouse shows
-- whole, without targeting it; a player's wish, 2026-11-23). One action: put
-- the mouse on a mob you haven't targeted and hold it there, then move it
-- off when the box says. Out of combat, a few mobs in view.
-- (Named mouseplate: /cine debug hoverplate was taken by the older hover
-- watch, arg:find("^hover"), and never ran. Tools/kit-names.py checks now.)
--   1 page   the row opened as /cine find row:plate:YourMouseover does: its
--            label under the Target section's Nameplates row (Your target's),
--            nothing over it (r:Overlaps), shot; greyed with the Nameplates
--            page off (the switch tree), shot
--   2 ready  CineMode on, the row OFF; every plate's alpha (the baseline)
--   3 hover  waits for the GAME's mouseover on an untargeted unit with a
--            plate (not our own state), then samples it every 0.25 s (run 2:
--            in a Stormwind crowd the unit under the mouse changed before a
--            read 4 s later). Row off, 2 s: stays faded as before. Row ticked
--            Always: once one plate has stayed under the mouse for the fade
--            in, it's whole (frame and health bar near 1; name logged) with
--            the other plates under it; shot
--   4 leave  waits for the mouse to leave THAT plate: fading (not cut) at
--            0.3 s, back down with the others and its hold let go after; shot
--   5 names  the Mouseover names row alone (2026-11-24, the same player's
--            wish): on a hovered NPC whose name is hidden, its name shows,
--            its health bar stays hidden, the other plates as they were;
--            mouse off: the name gone; shots
-- Everything changed is put back at the end. Into CinematicDB.hoverPlateTestLog.
-- Dev copy only.
local _, ns = ...

local function Known(value)
	return not (issecretvalue and issecretvalue(value))
end

-- A region's alpha as drawn (its parents' too), or nil unread.
local function Drawn(region)
	if not (region and region.GetAlpha) then return nil end
	local ok, alpha
	if region.GetEffectiveAlpha then
		ok, alpha = pcall(region.GetEffectiveAlpha, region)
	end
	-- (A font string without GetEffectiveAlpha, run 3's name: its own alpha
	-- times its parent's as drawn.)
	if not ok then
		local okOwn, own = pcall(region.GetAlpha, region)
		local parent = region.GetParent and region:GetParent()
		local up = parent and Drawn(parent)
		ok, alpha = okOwn and Known(own) and up ~= nil, okOwn and up and own * up
	end
	if not ok or not Known(alpha) then return nil end
	local okShown, shown = pcall(region.IsVisible, region)
	if okShown and Known(shown) and not shown then return 0 end
	return alpha
end

local function Text(value)
	return value and ("%.2f"):format(value) or "?"
end

-- The plate's frame, health bar and name as drawn.
local function PlateParts(plate)
	local frame = plate and plate.UnitFrame
	if not frame then return nil end
	local bar = frame.healthBar or frame.HealthBar or (frame.HealthBarsContainer and frame.HealthBarsContainer.healthBar)
	-- (The name as drawn: the game's, or Name Style's own text in its place,
	-- ns.PlateNameText: the game's is hidden then. Run 10 read only the game's.)
	local name = Drawn(frame.name)
	local ours = ns.PlateNameText and ns.PlateNameText(plate)
	local oursAlpha = ours and Drawn(ours)
	if oursAlpha and (not name or oursAlpha > name) then name = oursAlpha end
	return Drawn(frame), Drawn(bar), name, bar ~= nil, frame.name ~= nil or ours ~= nil
end

local function OwnPlate()
	local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "player")
	return ok and plate or nil
end

-- Every plate's frame alpha but one; returns the highest of them.
local function LogOthers(r, title, except)
	local plates = C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates() or {}
	local highest, parts, own, byPlate = 0, {}, OwnPlate(), {}
	for _, plate in ipairs(plates) do
		if plate ~= except and plate ~= own then
			local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
			local alpha = Drawn(plate.UnitFrame)
			local ok, name = pcall(UnitName, unit or "")
			parts[#parts + 1] = ("%s %s"):format(ok and Known(name) and tostring(name) or "?", Text(alpha))
			if alpha and alpha > highest then highest = alpha end
			byPlate[plate] = alpha
		end
	end
	r:Log(("%s: %d other plates: %s"):format(title, #parts, table.concat(parts, ", ")))
	return highest, #parts, byPlate
end

-- The game's own unit under the mouse: an untargeted one (not you) with a plate.
local function MousePlate()
	if not UnitExists("mouseover") or UnitIsUnit("mouseover", "player") then return nil end
	if UnitExists("target") and UnitIsUnit("mouseover", "target") then return nil end
	local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "mouseover")
	return ok and plate or nil
end

-- The unit under the mouse, for the log.
local function Who()
	local ok, name = pcall(UnitName, "mouseover")
	return ok and Known(name) and tostring(name) or "?"
end

local function FindText(root, words)
	local function Walk(frame, depth)
		if depth > 30 then return nil end
		for _, region in ipairs({ frame:GetRegions() }) do
			if region.GetText then
				local text = region:GetText()
				if type(text) == "string" and Known(text) and text == words and region:IsVisible() then
					return region
				end
			end
		end
		for _, child in ipairs({ frame:GetChildren() }) do
			local hit = Walk(child, depth + 1)
			if hit then return hit end
		end
	end
	return Walk(root, 0)
end

local heldPlate, heldColor -- (the plate step 3 read and its bar's color, for step 4)

-- Waits for the mouse on an untargeted NPC with a plate, saying in the box
-- why what's under it isn't taken (run 6 waited 90 s with no word why).
local ASK = "Put your mouse on an NPC STANDING STILL (not a player walking by) and hold it there."
local TELL = { target = "That's your TARGET: press Escape to clear it, then hover it again.",
	you = "That's you: hover an NPC.",
	player = "That's a PLAYER with no plate here: hover an NPC instead.",
	none = "It has no nameplate here: try another NPC (a guard or a vendor)." }
local function WaitHover(r, ask)
	local said
	r:WaitFor(ask or ASK, { check = function()
		local plate = MousePlate()
		if plate or not UnitExists("mouseover") then return plate end
		local why = UnitIsUnit("mouseover", "player") and "you"
			or (UnitExists("target") and UnitIsUnit("mouseover", "target")) and "target"
			or UnitIsPlayer("mouseover") and "player" or "none"
		local line = Who() .. ": " .. why
		if line ~= said then
			said = line
			r:Log("  under the mouse, not taken: " .. line)
			r:Prompt(ask or ASK, TELL[why])
		end
	end })
end

-- Every change of what the game says is under the mouse, every 0.05 s, from
-- step 3's hold to step 4's end (runs 7 and 8: "no plate under the mouse"
-- while the tooltip still showed the unit, then held again: a game blip or
-- the mouse really moving?). Logs unit exists / name / plate / our hold.
local trace
local function TraceState(plate)
	local exists = UnitExists("mouseover")
	local ok, now = pcall(C_NamePlate.GetNamePlateForUnit, "mouseover")
	now = ok and now or nil
	local where = not now and "no plate" or (now == plate and "its plate") or "another plate"
	return ("mouseover %s (%s), %s, our hold %s"):format(exists and "yes" or "NO", exists and Who() or "-", where,
		ns.plates.hover.plate == plate and "on it" or (ns.plates.hover.leaving[plate] and "fading" or "off"))
end
local function StartTrace(r, plate)
	if trace then trace:Cancel() end
	local last
	trace = C_Timer.NewTicker(0.05, function()
		local line = TraceState(plate)
		if line ~= last then
			last = line
			r:Log("  trace: " .. line)
		end
	end)
end
local function StopTrace()
	if trace then trace:Cancel() trace = nil end
end

-- The plate's health bar color as drawn ("r,g,b"), or nil unread.
local function BarColor(plate)
	local frame = plate and plate.UnitFrame
	local bar = frame and (frame.healthBar or frame.HealthBar
		or (frame.HealthBarsContainer and frame.HealthBarsContainer.healthBar))
	if not (bar and bar.GetStatusBarColor) then return nil end
	local ok, red, green, blue = pcall(bar.GetStatusBarColor, bar)
	if not ok or not (Known(red) and Known(green) and Known(blue)) or type(red) ~= "number" then return nil end
	return ("%.2f,%.2f,%.2f"):format(red, green, blue)
end

ns.TestKit.Define({
	name = "mouseplate",
	key = "hoverPlateTest",
	title = "Mouseover nameplate",
	about = "the Mouseover row: its page row, then one hover with it off and on, then the mouse off",
	needs = "An NPC standing still to mouse over",
	settings = { "plateAlwaysYourMouseover", "nameAlwaysYourMouseover", "handlePlates" },
	cvars = { "nameplateShowAll", "nameplateShowEnemies", "nameplateShowFriendlyNPCs" },
	cineMode = true,
	context = function()
		return ("CineMode %s, Nameplates page %s, Mouseover row Always %s, fade in %.2f s out %.2f s"):format(
			tostring(ns.IsCineModeOn and ns.IsCineModeOn()), tostring(ns.db.handlePlates),
			tostring(ns.db.plateAlwaysYourMouseover), ns.FadeInTime(), ns.FadeOutTime())
	end,
	putBack = function(extra)
		StopTrace()
		if extra.cineTurnedOn and ns.IsCineModeOn and ns.IsCineModeOn() and Cinematic_ToggleCineMode then
			pcall(Cinematic_ToggleCineMode)
			return "CineMode off again"
		end
		return "nothing of its own"
	end,
	steps = {
		{ key = "page", title = "the Mouseover rows on the Nameplates page", proven = "run 11 (queue q1757), 2026-11-24: 5/5",
			run = function(r)
			local panel = SettingsPanel or UIParent
			for _, on in ipairs({ true, false }) do
				r:Set("handlePlates", on)
				local text, pageName = ns.FindSetting("row:plate:YourMouseover")
				-- (Up to 5 s for the page: run 10 read it at 0.8 s with the panel
				-- still on the last page shown, Info's Bubbles.)
				local label
				for _ = 1, 20 do
					r:Sleep(0.25)
					label = FindText(panel, ns.L["Mouseover nameplates"])
					if label or not on then break end
				end
				r:Log(("Nameplates page %s: find opened %s on %s"):format(on and "on" or "off", tostring(text),
					tostring(pageName)))
				-- (Your target's row in the same grid: not the page's own title.)
				local grid = label and label:GetParent() and label:GetParent():GetParent()
				local above = grid and FindText(grid, ns.L["Names"])
				local names = grid and FindText(grid, ns.L["Mouseover names"])
				if not label then
					r:Shot("Nameplates page, no Mouseover nameplates row seen", { behind = panel })
					r:Fail("no Mouseover nameplates row shown (page " .. (on and "on" or "off") .. ")")
				else
					if on then
						r:Verdict(above ~= nil and above:GetTop() > label:GetTop(),
							"Mouseover nameplates under the Target section's Names row (Your target's)")
						r:Verdict(names ~= nil and names:GetTop() < label:GetTop(),
							"Mouseover names right under it")
						local hits = r:Overlaps(label:GetParent(), panel)
						r:Verdict(#hits == 0, "nothing over its row" .. (#hits > 0 and (": " .. table.concat(hits, ", ")) or ""))
						local nameHits = names and r:Overlaps(names:GetParent(), panel) or {}
						r:Verdict(#nameHits == 0, "nothing over the names row"
							.. (#nameHits > 0 and (": " .. table.concat(nameHits, ", ")) or ""))
						local _, namePage = ns.FindSetting("row:name:YourMouseover")
						r:Verdict(namePage ~= nil, "/cine find row:name:YourMouseover opens it (" .. tostring(namePage) .. ")")
					else
						local a = Drawn(label)
						r:Log(("its label drawn at %s with the page off"):format(Text(a)))
					end
					r:Shot("Mouseover row, Nameplates page " .. (on and "on" or "off"), { behind = panel })
				end
			end
			r:Set("handlePlates", true)
			if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
		end },
		{ key = "ready", title = "CineMode on, the row off", proven = "run 2, 2026-11-23: 2/2", run = function(r)
			r:Set("handlePlates", true)
			r:Set("plateAlwaysYourMouseover", false)
			if not (ns.IsCineModeOn and ns.IsCineModeOn()) and Cinematic_ToggleCineMode then
				r:Keep("cineTurnedOn", true)
				Cinematic_ToggleCineMode()
			end
			r:Sleep(1.5)
			r:Verdict(ns.IsCineModeOn and ns.IsCineModeOn(), "CineMode on")
			r:Verdict(not ns.plates.HoverWanted(), "the row off to start")
			LogOthers(r, "baseline", nil)
		end },
		{ key = "hover", title = "the row off, then ticked: sampled under the mouse",
			proven = "run 9 (queue q96aa), 2026-11-23: 4/4", run = function(r)
			-- (Run 6 waited 90 s and was skipped, with no word why: what's under
			-- the mouse and why it isn't taken, each new unit once.)
			-- (Run 6 waited 90 s and was skipped, with no word why: what's under
			-- the mouse and why it isn't taken, logged and said in the box.)
			-- (Off for the row-off reads: steps 1-2, which set it, are left out
			-- once proven, and run 7 had the player's own Always on.)
			r:Set("plateAlwaysYourMouseover", false)
			r:Set("nameAlwaysYourMouseover", false)
			WaitHover(r)
			-- Row off: every 0.25 s for 2 s, whatever plate is under the mouse.
			local offMax, offSeen = 0, 0
			for i = 1, 8 do
				local plate = MousePlate()
				if plate then
					offSeen = offSeen + 1
					local frame = PlateParts(plate)
					if frame and frame > offMax then offMax = frame end
					if i == 4 then r:Log(("row off, %s under the mouse: frame %s"):format(Who(), Text(frame))) end
				end
				r:Sleep(0.25)
			end
			r:Log(("row off: %d samples on a plate, highest %s"):format(offSeen, Text(offMax)))
			-- (The other plates as other rows hold them: run 4 had names kept on
			-- a few at 0.24-1.00. The row must leave them as they are.)
			local _, _, before = LogOthers(r, "row off", MousePlate())
			-- Row on: every 0.25 s for up to 8 s. "held": the same plate under the
			-- mouse since the row went on (or since the mouse came to it).
			r:Set("plateAlwaysYourMouseover", true)
			-- (Ticked in the menu, the mouse is on the menu: coming onto the unit
			-- after, the game's UPDATE_MOUSEOVER_UNIT wakes the plates' pass. The
			-- row ticked mid-hover has no such event and waited for the 2 s
			-- refresh, run 3: so the pass is woken here as the event would.)
			ns.plates.seen.at = nil
			local since, at, best = nil, nil, nil
			local wait = ns.FadeInTime() + 0.5
			for i = 1, 32 do
				local plate = MousePlate()
				if plate ~= at then at, since = plate, GetTime() end
				local frame, bar, name, hasBar, hasName = PlateParts(plate)
				if i % 2 == 0 or (frame and frame > 0.9) then
					r:Log(("  %.2f s: %s, frame %s bar %s name %s, held %s, hover level %.2f"):format(
						(i - 1) * 0.25, plate and Who() or "no plate under the mouse", Text(frame), Text(bar), Text(name),
						tostring(plate ~= nil and plate == ns.plates.hover.plate), ns.plates.HoverLevel(plate)))
				end
				if plate and GetTime() - since >= wait then
					best = { plate = plate, frame = frame, bar = bar, name = name, hasBar = hasBar, hasName = hasName }
					r:Shot("row on: the plate under the mouse", { behind = plate.UnitFrame })
					break
				end
				r:Sleep(0.25)
			end
			r:Verdict(offSeen > 0 and offMax < 0.5, ("row off: the plate under the mouse stays faded (highest %s in %d)")
				:format(Text(offMax), offSeen))
			if not best then
				return r:Skip(("no plate stayed under the mouse for %.1f s: pick an NPC standing still"):format(wait))
			end
			heldPlate = best.plate
			heldColor = BarColor(best.plate)
			StartTrace(r, best.plate)
			r:Log(("row on: its bar color %s, Nameplate Style row %s"):format(tostring(heldColor),
				tostring(ns.PlateRowNow and ns.PlateRowNow(best.plate,
				best.plate.namePlateUnitToken or (best.plate.UnitFrame and best.plate.UnitFrame.unit)))))
			local _, _, during = LogOthers(r, "row on", best.plate)
			local changed = {}
			for plate, alpha in pairs(during) do
				local was = before[plate]
				if was and alpha and math.abs(alpha - was) > 0.05 then
					changed[#changed + 1] = ("%s -> %s"):format(Text(was), Text(alpha))
				end
			end
			r:Verdict(best.frame ~= nil and best.frame > 0.9, ("row on: the plate whole (%s)"):format(Text(best.frame)))
			r:Verdict(best.hasBar and best.bar ~= nil and best.bar > 0.9,
				("row on: its health bar drawn (%s)"):format(Text(best.bar)))
			r:Log(("row on: its name %s%s"):format(Text(best.name), best.hasName and "" or " (no name found)"))
			r:Verdict(#changed == 0, "row on: the other plates left as they were"
				.. (#changed > 0 and (" (" .. table.concat(changed, ", ") .. ")") or ""))
		end },
		{ key = "leave", title = "the mouse off it", proven = "run 9 (queue q96aa), 2026-11-23: 4/4", run = function(r)
			local plate = heldPlate
			if not plate then return r:Skip("no plate held in step 3") end
			-- (Off for 0.5 s straight: run 8 took a 0.2 s blip as the mouse leaving.)
			local offSince
			r:WaitFor("Now move the mouse OFF it, onto the ground or sky.",
				{ check = function()
					if MousePlate() == plate then offSince = nil return nil end
					offSince = offSince or GetTime()
					return GetTime() - offSince >= 0.5
				end })
			local leftAt = GetTime()
			r:Sleep(0.3)
			local early = PlateParts(plate)
			local earlyColor = BarColor(plate)
			r:Sleep(ns.FadeOutTime() + 0.3)
			local frame = PlateParts(plate)
			LogOthers(r, "after", plate)
			r:Log(("its plate: frame %s 0.3 s after, %s %.1f s after, hover level %.2f"):format(Text(early), Text(frame),
				GetTime() - leftAt, ns.plates.HoverLevel(plate)))
			r:Shot("after the mouse left")
			r:Verdict(early ~= nil and early > 0.3, ("fades down, not cut (%s at 0.3 s)"):format(Text(early)))
			-- (Run 5's bug, the user 2026-11-23: the plate went back to the
			-- game's green for the fade, its Nameplate Style Mouseover look gone.)
			r:Verdict(heldColor ~= nil and earlyColor == heldColor,
				("keeps its hovered look while fading (bar %s, hovered %s)"):format(tostring(earlyColor),
				tostring(heldColor)))
			r:Verdict(ns.plates.HoverLevel(plate) == 0, "its hold let go")
			r:Verdict(frame ~= nil and frame < 0.05, ("back down to hidden (%s)"):format(Text(frame)))
			StopTrace()
		end },
		-- The Mouseover names row alone (the plate row off): the name shows on
		-- the plate under the mouse, its health bar stays hidden, the other
		-- plates stay as they were, and the name goes once the mouse leaves.
		{ key = "names", title = "Mouseover names: the name alone under the mouse",
			proven = "run 11 (queue q1757), 2026-11-24: 4/4", run = function(r)
			r:Set("handlePlates", true)
			r:Set("plateAlwaysYourMouseover", false)
			r:Set("nameAlwaysYourMouseover", false)
			if not (ns.IsCineModeOn and ns.IsCineModeOn()) and Cinematic_ToggleCineMode then
				r:Keep("cineTurnedOn", true)
				Cinematic_ToggleCineMode()
			end
			r:Sleep(1)
			WaitHover(r)
			local start = MousePlate()
			r:Sleep(0.5)
			local _, _, baseName = PlateParts(start)
			r:Log(("rows off, %s under the mouse: name %s"):format(Who(), Text(baseName)))
			if baseName and baseName > 0.5 then
				return r:Skip("its kind's names already show here: hover an NPC whose name is hidden")
			end
			local _, _, before = LogOthers(r, "names row off", start)
			r:Set("nameAlwaysYourMouseover", true)
			ns.plates.seen.at = nil -- (wake the plates' pass, as the mouse coming on would)
			local since, at, best = nil, nil, nil
			local wait = ns.FadeInTime() + 0.6
			for i = 1, 32 do
				local plate = MousePlate()
				if plate ~= at then at, since = plate, GetTime() end
				local frame, bar, name, hasBar, hasName = PlateParts(plate)
				if i % 2 == 0 then
					-- (With the sight check's reading: run 10's name stayed at 0 with
					-- every share right, frame whole: dimmed as out of sight?)
					r:Log(("  %.2f s: %s, frame %s bar %s name %s, hover level %.2f | %s"):format((i - 1) * 0.25,
						plate and Who() or "no plate under the mouse", Text(frame), Text(bar), Text(name),
						ns.plates.HoverLevel(plate), plate and ns.DescribePlateSight and ns.DescribePlateSight(plate) or "-"))
				end
				if plate and GetTime() - since >= wait then
					best = { plate = plate, bar = bar, name = name, hasBar = hasBar, hasName = hasName }
					r:Log("  " .. tostring(ns.DescribePlateNameKept(plate.namePlateUnitToken
						or (plate.UnitFrame and plate.UnitFrame.unit), plate)))
					r:Shot("Mouseover names: the name under the mouse", { behind = plate.UnitFrame })
					break
				end
				r:Sleep(0.25)
			end
			if not best then
				return r:Skip(("no plate stayed under the mouse for %.1f s: pick an NPC standing still"):format(wait))
			end
			local _, _, during = LogOthers(r, "names row on", best.plate)
			local changed = {}
			for plate, alpha in pairs(during) do
				local was = before[plate]
				if was and alpha and math.abs(alpha - was) > 0.05 then
					changed[#changed + 1] = ("%s -> %s"):format(Text(was), Text(alpha))
				end
			end
			r:Verdict(best.hasName and best.name ~= nil and best.name > 0.9,
				("its name shows (%s)"):format(Text(best.name)))
			r:Verdict(not best.hasBar or (best.bar ~= nil and best.bar < 0.1),
				("its health bar stays hidden: name alone (%s)"):format(Text(best.bar)))
			r:Verdict(#changed == 0, "the other plates left as they were"
				.. (#changed > 0 and (" (" .. table.concat(changed, ", ") .. ")") or ""))
			local plate = best.plate
			local offSince
			r:WaitFor("Now move the mouse OFF it, onto the ground or sky.", { check = function()
				if MousePlate() == plate then offSince = nil return nil end
				offSince = offSince or GetTime()
				return GetTime() - offSince >= 0.5
			end })
			r:Sleep(ns.FadeOutTime() + 0.3)
			local _, _, after = PlateParts(plate)
			r:Shot("Mouseover names: the mouse gone")
			r:Verdict(after ~= nil and after < 0.05, ("its name gone after the mouse left (%s)"):format(Text(after)))
		end },
	},
})
