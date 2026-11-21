-- /cine debug mappin: one run proving the minimap's map pin follows the
-- Minimap page's Map pin boxes in the cursor sweep (Forever since its
-- 2026-11-12 patch: every minimap name is secret, so any dot it can't
-- explain counts as a node, brings the minimap up and gets pinged; Shortest
-- Path Forever's journeys put the game's map pin on each hop).
-- It places the pin itself 25 yards ahead of you (logging where it landed
-- against your facing), then:
--   1. Map pin ticked: the sweep's points around the pin hear a plain dot;
--   2. Map pin unticked: they hear a known dot (left out), none plain;
--   3-4. the real thing, only where step 2 heard no other dot and gathering
--      tracking is on (else SKIP, saying why): Nearby Dots left to sweep on
--      its own for 10 s, the minimap stays hidden with the box unticked and
--      comes up with it ticked;
--   5. with Shortest Path Forever loaded and no journey of yours under way:
--      a journey of its own to that spot (its public API), both boxes ticked:
--      SPF's pin is a known dot; then cancelled.
-- Judged by points, not dots: secret dots share one name, so dots near each
-- other merge into one middle (the first run's false FAIL, 2026-11-21).
-- What it changes (the boxes, your pin, its journey) is saved in
-- CinematicDB.mapPinUndo and put back at the end, or at the next login after
-- a /reload mid-run.
-- The one action: CineMode on, the mouse resting over the open world.
-- Log: mapPinLog. Dev copy only (CinematicDev.toc).
local ADDON_NAME, ns = ...

local AHEAD = 25    -- yards ahead of you the test's pin goes
local OWNER = "Cinematic map pin test"

local run

local function Log(text)
	local log = ns.db.mapPinLog
	if #log < 600 then log[#log + 1] = ("%.1fs %s"):format(GetTime() - run.at, text) end
end

local function Box(text, sub, r, g, b)
	ns.PadTestBox(text, sub, r or 1, g or 0.82, b or 0)
end

local function SPF()
	local api = type(_G.ShortestPathForever) == "table" and _G.ShortestPathForever.API
	return ns.SPFLoaded and ns.SPFLoaded() and type(api) == "table" and api or nil
end

-- A point AHEAD yards in front of you on your map, or nil and why.
local function SpotAhead()
	local mapID = C_Map.GetBestMapForUnit("player")
	local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
	if not pos then return nil, "no position on the map here" end
	local continent, here = C_Map.GetWorldPosFromMapPos(mapID, pos)
	if not here then return nil, "no world position" end
	local okFacing, facing = pcall(GetPlayerFacing)
	if not okFacing or type(facing) ~= "number" or (issecretvalue and issecretvalue(facing)) then
		facing = nil
	end
	run.facing = facing
	facing = facing or 0
	-- (World x is north, y west; facing 0 is north, turning left.)
	local world = CreateVector2D(here.x + AHEAD * math.cos(facing), here.y + AHEAD * math.sin(facing))
	local okMap, onMap, mapPos = pcall(C_Map.GetMapPosFromWorldPos, continent, world, mapID)
	if not (okMap and onMap and mapPos) then return nil, "the spot ahead isn't on this map" end
	return { map = onMap, x = mapPos.x, y = mapPos.y }
end

-- The sweep's points that hear the pin (within a dot's reach of our worked-out
-- spot), by the name each heard there. (Secret dots share one name, so dots
-- near each other merge into one middle: points, not dots, tell.)
local function PointsAtPin(points, spot)
	local byName, count, nearest = {}, 0, nil
	for _, point in ipairs(points) do
		local yards = math.sqrt((point.north - spot.north) ^ 2 + (point.west - spot.west) ^ 2)
		if yards <= points.reach then
			byName[point.name] = (byName[point.name] or 0) + 1
			count = count + 1
			nearest = math.min(nearest or yards, yards)
		end
	end
	return byName, count, nearest
end

local STEPS
local Finish, NextStep, Watch

-- One step's sweep came back: its verdict from the dots heard.
local function Judge(step, verdict, dots)
	local spot = ns.MapPinSpot()
	local names = ns.CURSOR_DOT_NAMES
	local line
	if not dots or not dots.reach then
		line = "FAIL sweep didn't finish: " .. tostring(verdict)
	elseif not spot then
		line = "FAIL no map pin spot (pin gone, or on another map)"
	else
		local byName, count, nearest = PointsAtPin(dots, spot)
		-- (Plain dots anywhere else: step 2 tells whether the pin is the only
		-- thing that could bring the minimap up, for the real reveal steps.)
		local elsewhere = 0
		for _, point in ipairs(dots) do
			if point.name == names.dot then elsewhere = elsewhere + 1 end
		end
		elsewhere = elsewhere - (byName[names.dot] or 0)
		if step.key == "box off" then run.otherDots = elsewhere end
		-- (Where the pin went against where you face: 0 = straight ahead.)
		if not run.placementLogged then
			run.placementLogged = true
			local bearing = math.deg(math.atan2(spot.west, spot.north)) % 360
			local facingDeg = run.facing and math.deg(run.facing) % 360
			local off = facingDeg and math.abs((bearing - facingDeg + 180) % 360 - 180)
			Log(("placement: pin %.1f yd away at bearing %.0f (0 north, 90 west); you faced %s; off by %s"):format(
				math.sqrt(spot.north ^ 2 + spot.west ^ 2), bearing,
				facingDeg and ("%.0f"):format(facingDeg) or "unreadable", off and ("%.0f"):format(off) or "?"))
			run.placementOff = off
		end
		Log(("plain dot points away from the pin: %d"):format(elsewhere))
		local parts = {}
		for name, n in pairs(byName) do parts[#parts + 1] = ("%s x%d"):format(name, n) end
		Log(("pin spot %.1f yd north, %.1f yd west; %d points within %.0f yd of it (nearest %s yd): %s; known dot now %s"):format(
			spot.north, spot.west, count, dots.reach, nearest and ("%.1f"):format(nearest) or "-",
			#parts > 0 and table.concat(parts, ", ") or "none", tostring(ns.MapPinIsKnownDot())))
		local want, other = names.dot, names.known
		if step.known then want, other = names.known, names.dot end
		if count == 0 then
			line = "FAIL the pin wasn't heard at any point"
		elseif not byName[want] then
			line = ("FAIL the pin heard only as %q, wanted %q"):format(other, want)
		elseif byName[other] then
			line = ("FAIL the pin heard as both (%d %q, %d %q)"):format(byName[want], want, byName[other], other)
		else
			line = ("PASS heard at %d points as %s"):format(byName[want],
				step.known and "a known dot (left out)" or "a dot (reveals)")
		end
	end
	run.verdicts[#run.verdicts + 1] = step.key .. ": " .. line
	Log("verdict " .. step.key .. ": " .. line)
	NextStep()
end

-- The real thing: reveals on (the test's own sweeps pause them), the
-- minimap's alpha watched for WATCH seconds as Nearby Dots sweeps on its
-- own. Only where step 2 heard no other dot (else something else could bring
-- it up) and with gathering tracking on (else Nearby Dots doesn't sweep).
local WATCH = 10
Watch = function(step)
	-- (Every reason at once: run 2 said only "no tracking", though 79 points
	-- heard a quest area too, so tracking alone wouldn't have let it run.)
	local reasons = {}
	if not ns.db.minimapNodesByCursor then reasons[#reasons + 1] = "Nearby Dots is off (Minimap page)" end
	if ns.IsGatheringTrackingOn and not ns.IsGatheringTrackingOn() then
		reasons[#reasons + 1] = "no ore, herb or treasure tracking on (Nearby Dots doesn't sweep without it)"
	end
	if run.otherDots == nil then
		reasons[#reasons + 1] = "step 2 didn't run"
	elseif run.otherDots > 0 then
		reasons[#reasons + 1] = ("%d points heard other dots here (a quest area, a node): somewhere with none"):format(
			run.otherDots)
	end
	local why = #reasons > 0 and table.concat(reasons, "; ") or nil
	if why then
		Log("skip " .. step.key .. ": " .. why)
		run.verdicts[#run.verdicts + 1] = step.key .. ": SKIP (" .. why .. ")"
		return NextStep()
	end
	local started, peak, upAt = GetTime(), 0, nil
	run.wait = C_Timer.NewTicker(0.2, function(ticker)
		if not run then ticker:Cancel() return end
		local into = GetTime() - started
		local alpha = Minimap:GetEffectiveAlpha()
		if alpha > peak then
			peak = alpha
			if alpha > 0.5 and not upAt then
				upAt = into
				Log(("minimap up at %.1f s"):format(into))
			end
		end
		Box(("Map pin test: %s"):format(step.say),
			("Rest the mouse over the open world, %d s left"):format(math.max(0, math.ceil(WATCH - into))), 0.3, 1, 0.3)
		-- (Up: done early. Hidden: the whole window.)
		if into < WATCH and not (step.reveal and upAt) then return end
		ticker:Cancel()
		run.wait = nil
		local up = upAt ~= nil
		local line = (up == step.reveal and "PASS " or "FAIL ") .. (up
			and ("minimap came up at %.1f s"):format(upAt) or ("minimap stayed hidden %d s (peak alpha %.2f)"):format(WATCH, peak))
		run.verdicts[#run.verdicts + 1] = step.key .. ": " .. line
		Log("verdict " .. step.key .. ": " .. line)
		NextStep()
	end)
end

-- Waits for CineMode and the faded minimap, then sweeps.
local function Sweep(step)
	run.wait = C_Timer.NewTicker(0.3, function(ticker)
		if not run then ticker:Cancel() return end
		if not ns.lastCinematic then
			Box("Turn CineMode ON", "(the test waits for it)", 1, 0.3, 0.3)
			return
		end
		ticker:Cancel()
		run.wait = nil
		Box(("Map pin test %d/%d: %s"):format(run.index, #STEPS, step.say),
			"Rest the mouse over the open world, don't move", 0.3, 1, 0.3)
		function ns.MapPinSweepDone(verdict, dots)
			ns.MapPinSweepDone = nil
			if not run then return end
			local ok, err = pcall(Judge, step, verdict, dots)
			if not ok then
				Log("error: " .. tostring(err))
				Finish(false)
			end
		end
		local ok, err = pcall(ns.CursorSweepTest, "mappin")
		if not ok then
			ns.MapPinSweepDone = nil
			Log("error: " .. tostring(err))
			Finish(false)
		end
	end)
end

STEPS = {
	{ key = "your pin", say = "your map pin, Map pin ticked", known = false,
		start = function(step)
			ns.db.minimapRevealMapPin = true
			Sweep(step)
		end },
	{ key = "box off", say = "Map pin unticked", known = true,
		start = function(step)
			ns.db.minimapRevealMapPin = false
			Sweep(step)
		end },
	{ key = "real, box off", say = "watching the minimap stay hidden (Map pin unticked)", watch = true, reveal = false,
		start = function(step) ns.db.minimapRevealMapPin = false Watch(step) end },
	{ key = "real, box on", say = "watching the minimap come up for the pin (Map pin ticked)", watch = true,
		reveal = true,
		start = function(step) ns.db.minimapRevealMapPin = true Watch(step) end },
	{ key = "SPF journey", say = "a Shortest Path journey, Not for Shortest Path ticked", known = true,
		start = function(step)
			local api = SPF()
			if not api then
				Log("skip: Shortest Path Forever isn't loaded")
				run.verdicts[#run.verdicts + 1] = step.key .. ": SKIP (SPF not loaded)"
				return NextStep()
			end
			if api.Active() then
				Log("skip: a journey of yours is under way (left alone)")
				run.verdicts[#run.verdicts + 1] = step.key .. ": SKIP (your own journey is under way)"
				return NextStep()
			end
			ns.db.minimapRevealMapPin, ns.db.minimapRevealMapPinSkipSPF = true, true
			C_Map.ClearUserWaypoint()
			local okGo, went = pcall(api.Navigate, OWNER, run.spot.map, run.spot.x, run.spot.y, "Cinematic test")
			Log(("SPF Navigate: %s %s"):format(tostring(okGo), tostring(went)))
			if okGo and went and CinematicDB.mapPinUndo then CinematicDB.mapPinUndo.spf = true end
			local waited = 0
			run.wait = C_Timer.NewTicker(0.5, function(ticker)
				if not run then ticker:Cancel() return end
				waited = waited + 0.5
				Box("Map pin test: starting a Shortest Path journey", ("waiting for its pin, %d s"):format(waited))
				local pin = C_Map.GetUserWaypoint()
				if pin and api.Active() then
					ticker:Cancel()
					run.wait = nil
					Log(("SPF's pin is up after %.1f s (journey guided %s)"):format(waited, tostring(api.Active())))
					return Sweep(step)
				end
				if waited >= 15 then
					ticker:Cancel()
					run.wait = nil
					Log(("FAIL no pin from SPF in 15 s (guided %s, pin %s)"):format(tostring(api.Active()), tostring(pin)))
					run.verdicts[#run.verdicts + 1] = step.key .. ": FAIL SPF put no map pin up in 15 s"
					NextStep()
				end
			end)
		end },
}

-- What a run changes, put back from CinematicDB.mapPinUndo (saved at its
-- start, so a /reload mid-run, which skips Finish, is put right at the next
-- login): the two boxes, your map pin and its tracking, and the test's SPF
-- journey. Returns what it did, in words.
local NIL = "<nil>" -- (SavedVariables keeps no nils in a table)
local SETTINGS = { "minimapRevealMapPin", "minimapRevealMapPinSkipSPF" }
local function PutBack()
	local undo, db = CinematicDB and CinematicDB.mapPinUndo, ns.db
	if not (undo and db) then return "nothing to put back" end
	for _, key in ipairs(SETTINGS) do
		local value = undo.settings and undo.settings[key]
		if value == NIL then value = nil end
		db[key] = value
	end
	local said = { "Map pin boxes put back" }
	local api = SPF()
	if undo.spf and api then
		local ok, cancelled = pcall(api.Cancel, OWNER)
		said[#said + 1] = "SPF test journey cancelled " .. tostring(ok and cancelled)
	end
	local pin = undo.pin
	if type(pin) == "table" and pin.uiMapID then
		pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(pin.uiMapID, pin.x, pin.y))
		said[#said + 1] = "your map pin put back"
	else
		pcall(C_Map.ClearUserWaypoint)
		said[#said + 1] = "test pin cleared (you had none)"
	end
	if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
		pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, undo.tracked == true)
	end
	CinematicDB.mapPinUndo = nil
	return table.concat(said, ", ")
end
do
	local login = CreateFrame("Frame")
	login:RegisterEvent("PLAYER_ENTERING_WORLD")
	login:SetScript("OnEvent", function(self)
		self:UnregisterAllEvents()
		if CinematicDB and CinematicDB.mapPinUndo and ns.db then
			local said = PutBack()
			local log = ns.db.mapPinLog
			if type(log) == "table" then log[#log + 1] = "login: the run was cut off (a /reload?): " .. said end
			ns.Print("map pin test was cut off: " .. said)
		end
	end)
end

NextStep = function()
	run.index = run.index + 1
	local step = STEPS[run.index]
	if not step then return Finish(true) end
	Log("step " .. step.key)
	step.start(step)
end

Finish = function(done)
	if run.wait then run.wait:Cancel() end
	ns.MapPinSweepDone = nil
	if ns.CursorTestingOff then ns.CursorTestingOff() end
	Log("put back: " .. PutBack())
	local fails, verdict = 0, table.concat(run.verdicts, "; ")
	for _, line in ipairs(run.verdicts) do if line:find("FAIL") then fails = fails + 1 end end
	verdict = (done and fails == 0 and #run.verdicts > 0 and "PASS" or "FAIL") .. " - " .. verdict
	Log("verdict " .. verdict)
	run = nil
	ns.Print("map pin test: " .. verdict)
	ns.Print("type /reload to save the log, then say check log")
	Box(done and "Test done. Type /reload, then say check log" or "Test stopped. Type /reload", verdict)
	C_Timer.After(25, function() if not run then ns.PadTestBoxHide() end end)
end

-- Typed again while running: stops.
function ns.MapPinTest()
	if run then
		Finish(false)
		return
	end
	ns.debugNoCopyWindow = true
	ns.db.mapPinLog = {}
	run = { at = GetTime(), index = 0, verdicts = {} }
	-- (A cut-off run's leftovers first, so they aren't taken for yours.)
	if CinematicDB.mapPinUndo then Log("a cut-off run's leftovers first: " .. PutBack()) end
	local okVersion, version = pcall(C_AddOns.GetAddOnMetadata, ADDON_NAME, "Version")
	local api = SPF()
	Log(("start: version %s, build %s, cursor sweep %s, SPF %s (journey %s), boxes: Map pin %s, Not for SP %s"):format(
		okVersion and tostring(version) or "?", tostring((select(4, GetBuildInfo()))),
		tostring(ns.CanCursorSweepMinimap and ns.CanCursorSweepMinimap()),
		api and "loaded" or "not loaded", api and tostring(api.Active()) or "-",
		tostring(ns.db.minimapRevealMapPin), tostring(ns.db.minimapRevealMapPinSkipSPF)))
	if not (ns.CanCursorSweepMinimap and ns.CanCursorSweepMinimap()) then
		run.verdicts[1] = "CAN'T TELL: this client doesn't use the cursor sweep (names readable, or no sweep)"
		return Finish(false)
	end
	local saved = C_Map.GetUserWaypoint()
	local undo = { settings = {}, pin = NIL, tracked = C_SuperTrack and C_SuperTrack.IsSuperTrackingUserWaypoint
		and C_SuperTrack.IsSuperTrackingUserWaypoint() == true or false }
	for _, key in ipairs(SETTINGS) do
		local value = ns.db[key]
		if value == nil then value = NIL end
		undo.settings[key] = value
	end
	if saved and saved.position then
		undo.pin = { uiMapID = saved.uiMapID, x = saved.position.x, y = saved.position.y }
	end
	CinematicDB.mapPinUndo = undo
	local spot, why = SpotAhead()
	if not spot then
		run.verdicts[1] = "CAN'T TELL: " .. why
		return Finish(false)
	end
	run.spot = spot
	local placed = C_Map.CanSetUserWaypointOnMap(spot.map)
		and C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(spot.map, spot.x, spot.y))
	Log(("pin placed %d yd ahead: map %s, %.4f, %.4f (%s); your old pin %s"):format(AHEAD, tostring(spot.map),
		spot.x, spot.y, tostring(placed), saved and "saved to put back" or "none"))
	if C_Map.GetUserWaypoint() == nil then
		run.verdicts[1] = "CAN'T TELL: the game wouldn't take a map pin here"
		return Finish(false)
	end
	NextStep()
	ns.Print("map pin test: follow the box (type it again to stop)")
end
