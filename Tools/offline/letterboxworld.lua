-- The world between the letterbox bars (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/letterboxworld.lua < /dev/null
-- Atmosphere/Letterbox.lua's letterboxWorld on a stand-in WorldFrame that
-- keeps its points, on both clients:
--   the switch off (the default): WorldFrame never touched;
--   on: moved in from the top and bottom by the bars' height;
--   a fight with the world between the bars: the bars held (asked out, they
--   stay) and the world too, out after it; one starting whole: whole, bars
--   free; Cinematic shut down in a fight: held, then out and whole after it;
--   the game's cutscene up: left alone; its end: placed again;
--   the switch flipped with the bars up: eased out and in, not at once;
--   the switch off, and the bars out: the whole screen;
--   the notch gap reads the same with the world squeezed; the frame rate
--   counter (on WorldFrame) lifted only by what the world didn't;
--   a cutscene starting: the whole screen before the game measures it.
-- PASS or FAIL per check; exits 1 on any FAIL.
-- luacheck: push ignore 111 112 113 121 122 212 431
local fails = 0
local function Check(client, name, ok, detail)
	if not ok then fails = fails + 1 end
	print(("%s %s: %s%s"):format(ok and "PASS" or "FAIL", client, name, detail and (" (" .. tostring(detail) .. ")") or ""))
end

local function RunClient(client)
	local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
	if not (ns.UpdateLetterbox and ns.LetterboxWorldBack) then
		Check(client, "Atmosphere loaded", false)
		return
	end
	if not ns.letterbox then ns.CreateLetterbox() end
	local lockdown = false
	InCombatLockdown = function() return lockdown end
	CinematicFrame = wow.CreateFrame("Frame", "CinematicFrame")
	CinematicFrame:Hide()
	UIParent.GetHeight = function() return 768 end
	UIParent.GetWidth = function() return 1835 end
	UIParent.GetTop = function() return 768 end
	-- WorldFrame: its offsets kept, every move counted.
	local W = { top = 0, bottom = 0, moves = 0 }
	WorldFrame.ClearAllPoints = function() W.moves = W.moves + 1 end
	WorldFrame.SetAllPoints = function() W.top, W.bottom = 0, 0 end
	WorldFrame.SetPoint = function(_, p, _, _, _, y)
		if p == "TOPLEFT" then W.top = y elseif p == "BOTTOMRIGHT" then W.bottom = y end
	end
	WorldFrame.GetTop = function() return 768 + W.top end
	WorldFrame.GetEffectiveScale = function() return 1 end
	-- The game's cutscene-starting callback, and its frame rate counter (a
	-- WorldFrame child at the bottom: it rises with the world by itself).
	local starting
	EventRegistry = { RegisterCallback = function(_, name, fn) if name == "CinematicFrame.CinematicStarting" then starting = fn end end }
	local fps = { y = 0, points = { { "BOTTOM", WorldFrame, "BOTTOM", 0, 0 } } }
	FramerateFrame = {
		GetNumPoints = function() return #fps.points end,
		GetPoint = function(_, i) return unpack(fps.points[i]) end,
		ClearAllPoints = function() end,
		SetPoint = function(_, _, _, _, _, y) fps.y = y end,
		GetEffectiveScale = function() return 1 end,
	}
	local db = ns.db
	db.letterbox = true
	local look = ns.LetterboxLook()
	local bar = ns.LetterboxHeight(look, 1835, 768)
	local function Tick()
		ns.letterboxDirty = true
		ns.UpdateLetterbox(true, 10)
	end
	local function Squeezed() return math.abs(W.top + bar) < 0.5 and math.abs(W.bottom - bar) < 0.5 end
	local function Full() return W.top == 0 and W.bottom == 0 end

	db.letterboxWorld = false
	Tick()
	Check(client, "switch off: WorldFrame never touched", W.moves == 0, W.moves .. " moves")
	db.letterboxWorld = true
	Tick()
	Check(client, "switch on: the world between the bars", Squeezed(), ("top %s bottom %s bar %.1f"):format(W.top, W.bottom, bar))
	Check(client, "notch gap 0 with the world squeezed", ns.NotchGap() == 0, ns.NotchGap())
	Check(client, "frame rate counter not lifted again (the world lifted it)", math.abs(fps.y) < 0.5, fps.y)
	local moves = W.moves
	Tick()
	Check(client, "the same bars again: no move", W.moves == moves, W.moves - moves)
	-- A fight: the bars held as they are, the world between them.
	wow.Fire("PLAYER_REGEN_DISABLED")
	Check(client, "a fight's first event: still between the bars", Squeezed())
	lockdown = true
	moves = W.moves
	db.letterbox = false
	ns.letterboxDirty = true
	ns.UpdateLetterbox(false, 10) -- (the bars asked out in the fight)
	Check(client, "in the fight: bars held up, world untouched", W.moves == moves and Squeezed()
		and ns.letterbox:IsShown() and ns.LetterboxUp())
	lockdown = false
	wow.Fire("PLAYER_REGEN_ENABLED")
	ns.UpdateLetterbox(false, 10)
	Check(client, "after the fight: bars out, the whole screen", Full() and not ns.letterbox:IsShown())
	-- A fight starting with the world whole: whole through it, bars free.
	lockdown = true
	db.letterbox = true
	Tick()
	Check(client, "a fight with the world whole: bars come in, world untouched", Full() and ns.letterbox:IsShown())
	lockdown = false
	wow.Fire("PLAYER_REGEN_ENABLED")
	Tick()
	Check(client, "after it: between the bars", Squeezed())
	-- Cinematic shut down in a fight: held, then out and whole after it.
	lockdown = true
	ns.UpdateLetterbox(false, 1e6)
	ns.LetterboxWorldBack()
	Check(client, "shut down in a fight: held", Squeezed() and ns.letterbox:IsShown())
	lockdown = false
	wow.Fire("PLAYER_REGEN_ENABLED")
	Check(client, "shut down in a fight: out and whole after it", Full() and not ns.letterbox:IsShown())
	Tick()
	-- The game's cutscene: the whole screen as it starts (it measures
	-- WorldFrame), then it places WorldFrame itself.
	Check(client, "cutscene starting: the callback is there", starting ~= nil)
	if starting then starting() end
	Check(client, "cutscene starting: the whole screen first", Full())
	CinematicFrame:Show()
	W.top, W.bottom = -50, 50 -- (the game's own placing)
	moves = W.moves
	Tick()
	Check(client, "cutscene up: left alone", W.moves == moves and W.top == -50)
	CinematicFrame:Hide()
	W.top, W.bottom = 0, 0 -- (its OnHide: SetAllPoints)
	wow.Fire("CINEMATIC_STOP")
	Tick()
	Check(client, "cutscene over: between the bars again", Squeezed())
	-- The switch flipped with the bars up: eased, not at once.
	local time = ns.LetterboxTime(look, false)
	db.letterboxWorld = false
	ns.UpdateLetterbox(true, time * 0.5)
	local mid = W.bottom
	Check(client, "switch off: eased (halfway: part of the bars' height)", mid > 0.5 and mid < bar - 0.5,
		("%.1f of %.1f, time %.2f s"):format(mid, bar, time))
	ns.UpdateLetterbox(true, time * 0.6)
	Check(client, "switch off: the whole screen once eased", Full())
	Check(client, "switch off: frame rate counter lifted over the bar", math.abs(fps.y - bar) < 0.5, fps.y)
	db.letterboxWorld = true
	ns.UpdateLetterbox(true, ns.LetterboxTime(look, true) * 0.5)
	Check(client, "switch on: eased in", W.bottom > 0.5 and W.bottom < bar - 0.5, W.bottom)
	ns.UpdateLetterbox(true, ns.LetterboxTime(look, true))
	Check(client, "switch on: between the bars once eased", Squeezed())
	db.letterboxWorld = false
	Tick()
	Check(client, "switch off with the bars up: the whole screen", Full())
	db.letterboxWorld = true
	Tick()
	db.letterbox = false
	ns.UpdateLetterbox(false, 1e6)
	Check(client, "bars out: the whole screen", Full())
	-- Cinematic shutting down puts it back too.
	db.letterbox = true
	Tick()
	ns.LetterboxWorldBack()
	Check(client, "LetterboxWorldBack: the whole screen", Full())
	db.letterbox, db.letterboxWorld = nil, nil
end

RunClient("forever")
RunClient("retail")
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
-- luacheck: pop
