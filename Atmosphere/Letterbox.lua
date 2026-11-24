-- The letterbox bars (the Atmosphere hub's Letterbox page): the frame, when
-- they come in (CineMode, a new place, the letterbox key, Chat Cam's Ultra
-- immersive) and the framerate counter lifted over them. Out of Effects.lua
-- (2026-11-22), so it's left out with the rest of Atmosphere (Modules.lua).
-- How bars are drawn (ns.MakeLetterboxBars, ns.DrawLetterbox, ns.LetterboxLook)
-- stays in Effects.lua: Combat Vision and the Style previews draw them too.
local _, ns = ...
ns.Module("atmosphere", function() -- (the rest of this file: only with Atmosphere loaded, Modules.lua)
local L = ns.L

local letterboxProgress = 0

function ns.CreateLetterbox()
	ns.letterbox = CreateFrame("Frame", "CinematicLetterbox", UIParent)
	ns.CoverWorld(ns.letterbox)
	-- (The bars' frame reaches up over the notch strip so the top bar sits on
	-- the screen's edge; Fit keeps it so while the bars move.)
	function ns.letterbox:Fit()
		ns.FitWorldCover(self)
		self.gap = self.notchGap
	end
	ns.letterbox:SetFrameStrata("BACKGROUND")
	ns.letterbox:SetFrameLevel(2) -- (over the tint and Vitals Vision, Tint.lua)
	ns.letterbox:EnableMouse(false)
	ns.MakeLetterboxBars(ns.letterbox)

	ns.letterbox:Hide()
	ns.AddOverlay(ns.letterbox)
end

-- The game's frame rate counter (Ctrl+R) sits at the bottom of the screen in
-- WorldFrame, which draws under UIParent (the letterbox) whatever its strata:
-- it moves up above the bottom bar while the bars show. Where the game puts
-- it is kept, and taken again if the game moves it.
local framerate = { height = 0 }

local function LiftFramerate(height)
	local counter = _G.FramerateFrame
	if type(counter) ~= "table" or type(counter.GetNumPoints) ~= "function" then
		return
	end
	framerate.height = height
	if not framerate.hooked then
		framerate.hooked = true
		hooksecurefunc(counter, "SetPoint", function()
			if framerate.moving then
				return
			end
			-- The game placed it: keep that, lifted again a frame later (once
			-- it has set all its points).
			framerate.points = nil
			if framerate.height > 0 and not framerate.pending then
				framerate.pending = true
				C_Timer.After(0, function()
					framerate.pending = false
					LiftFramerate(framerate.height)
				end)
			end
		end)
	end
	if not framerate.points then
		if height == 0 or ns.NumPoints(counter) == 0 then
			return -- (where the game put it, untouched)
		end
		framerate.points = {}
		for i = 1, ns.NumPoints(counter) do
			framerate.points[i] = { counter:GetPoint(i) }
		end
	end
	local lift = height * UIParent:GetEffectiveScale() / counter:GetEffectiveScale()
	framerate.moving = true
	counter:ClearAllPoints()
	for _, point in ipairs(framerate.points) do
		counter:SetPoint(point[1], point[2], point[3], point[4], point[5] + lift)
	end
	framerate.moving = false
end

-- The world between the bars (the Letterbox page's "Draw the world between
-- the bars", letterboxWorld): WorldFrame moved in from the top and bottom by
-- the bars' height, so the game draws the world only in the strip between
-- them, a wider view with nothing behind the bars. WorldFrame is protected:
-- it can't move in a fight, so a fight that starts with the world between the
-- bars holds the bars as they are (not out, not in, not taller) till it ends
-- (the user, 2026-11-24: "combat prevents us from leaving it"); a fight that
-- starts with the world whole keeps it whole. Left alone while the game's own
-- cutscene places it (CinematicFrame.lua). Engine rule
-- forever.worldframe.move-out-of-fights. Never touched by players who don't
-- turn it on. (at: the offset now, WorldFrame units, 0 = whole screen;
-- ns.worldSqueeze: the same, for ns.NotchGap; wanted, elapsed: the last call
-- held, played after the fight; p: the switch's 0-1, eased when it's flipped.)
local world = { at = 0 }

local function PlaceWorld(offset)
	if offset < 0.5 then offset = 0 end
	if InCombatLockdown() or (CinematicFrame and CinematicFrame:IsShown()) then return end
	if math.abs(offset - world.at) < 0.25 then return end
	world.at = offset
	ns.worldSqueeze = offset > 0 and offset or nil
	WorldFrame:ClearAllPoints()
	if offset > 0 then
		WorldFrame:SetPoint("TOPLEFT", nil, "TOPLEFT", 0, -offset)
		WorldFrame:SetPoint("BOTTOMRIGHT", nil, "BOTTOMRIGHT", 0, offset)
	else
		WorldFrame:SetAllPoints()
	end
end

-- The whole screen again (Cinematic shutting down; in a fight: after it).
function ns.LetterboxWorldBack()
	if world.at > 0 then PlaceWorld(0) end
end

local function WatchWorld()
	if world.watch then return end
	world.watch = CreateFrame("Frame")
	for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "CINEMATIC_STOP", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED" }) do
		world.watch:RegisterEvent(event)
	end
	-- A cutscene about to start: the whole screen first, as the game works out
	-- its own shape from WorldFrame's size (CinematicFrame.lua fires this just
	-- before it places it).
	if EventRegistry and EventRegistry.RegisterCallback then
		EventRegistry:RegisterCallback("CinematicFrame.CinematicStarting", function()
			ns.LetterboxWorldBack()
		end, world.watch)
	end
	world.watch:SetScript("OnEvent", function(_, event)
		-- (The cutscene's end put it on the whole screen itself.)
		if event == "CINEMATIC_STOP" then world.at, ns.worldSqueeze = 0, nil end
		ns.letterboxDirty = true
		-- The fight held the bars: what was asked meanwhile, at once if it was
		-- Cinematic shutting down (no tick comes after that).
		if event == "PLAYER_REGEN_ENABLED" and world.wanted ~= nil then
			local wanted, elapsed = world.wanted, world.elapsed
			world.wanted = nil
			if elapsed >= 1e5 then ns.UpdateLetterbox(wanted, elapsed) end
		end
	end)
end

-- Chat Cam's Ultra immersive (ChatCam.lua): through a conversation the bars
-- come in (CineMode or not) and grow to twice their height, room for its
-- subtitles; back to as they were after.
local immersiveProgress = 0

-- The letterbox key (Cinematic_ToggleLetterbox) and a place new to you
-- (CardMoments.lua, with the Letterbox tab's "Show bars on discovering a new
-- place"): the bars in or out whatever CineMode and the Show in row say. The
-- key's pick lasts till CineMode goes on or off; a fight takes the bars out
-- meanwhile if they're off in combat, and they come back after.
-- (until: GetTime the new place's bars go; key: the key's pick, true in,
-- false out, nil none; keyCine: made in CineMode or not; wanted: last tick's
-- answer, for the key to flip; forced: in, the letterbox's own switch or not;
-- cine: last tick's CineMode. One table: Lua's cap on a file's locals.)
local bars = { untilAt = 0, key = nil, keyCine = false, wanted = false, forced = false, cine = false }

-- True while the letterbox bars are up or coming in (CineMode's, a new
-- place's, the key's), with some height: Cards.lua's No letterbox: Don't show.
function ns.LetterboxUp()
	if not (bars.target == 1 or letterboxProgress > 0) then return false end
	return ns.LetterboxHeight(ns.LetterboxLook(), UIParent:GetWidth(), UIParent:GetHeight()) >= 1
end

function ns.LetterboxOnDiscover()
	local db = ns.db
	if not (db and db.letterboxOnDiscover) then return end
	bars.untilAt = GetTime() + (db.letterboxDiscoverTime or 8)
end

function ns.LetterboxExtra(wanted, inCombat, cinematic)
	local db = ns.db
	cinematic = cinematic and true or false
	bars.cine = cinematic
	if bars.key ~= nil and bars.keyCine ~= cinematic then bars.key = nil end
	local outForFight = inCombat and db.letterboxOffInCombat
	local discover = GetTime() < bars.untilAt and db.letterboxOnDiscover and db.letterboxPage ~= false
		and db.visualEffects ~= false
	bars.forced = false
	if bars.key == false then
		wanted = false
	elseif (bars.key or discover) and not wanted and not outForFight then
		wanted, bars.forced = true, true
	end
	bars.wanted = wanted and true or false
	return bars.wanted
end

function Cinematic_ToggleLetterbox()
	if not ns.db then return end
	bars.key = not bars.wanted
	bars.keyCine = bars.cine
	ns.letterboxDirty = true
	ns.Print(bars.key and L["letterbox bars on"] or L["letterbox bars off"])
end

function ns.UpdateLetterbox(cinematic, elapsed)
	-- (The world between the bars in a fight: the bars held till it ends.)
	if world.at > 0 and InCombatLockdown() then
		world.wanted, world.elapsed = cinematic and true or false, elapsed or 0
		return
	end
	local immersive = ns.ChatCamImmersive and ns.ChatCamImmersive() or false
	-- (Show me's demo, ShowMe.lua: the bars with the setting off, too)
	local target = ((cinematic and (ns.db.letterbox or ns.effectsDemo or bars.forced)) or immersive) and 1 or 0
	local grow = immersive and 1 or 0
	local squeeze = ns.db.letterboxWorld and 1 or 0
	if letterboxProgress == target and immersiveProgress == grow and (world.p or 0) == squeeze
		and not ns.letterboxDirty then
		return
	end
	ns.letterboxDirty = false
	local look = ns.LetterboxLook()
	bars.target = target
	letterboxProgress = ns.Approach(letterboxProgress, target, elapsed,
		ns.LetterboxTime(look, target > letterboxProgress))
	immersiveProgress = ns.Approach(immersiveProgress, grow, elapsed, ns.LetterboxTime(look, grow > immersiveProgress))
	ns.letterbox:Fit()
	local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight() + (ns.letterbox.gap or 0)
	if immersiveProgress > 0 then
		local g = immersiveProgress * immersiveProgress * (3 - 2 * immersiveProgress)
		local share = screenH > 0 and ns.LetterboxHeight(look, screenW, screenH) / screenH or 0
		look = setmetatable({ letterboxSizeBy = "height", letterboxSize = share * (1 + g) }, { __index = look })
	end

	-- Smoothstep so the bars ease in and out.
	local t = letterboxProgress * letterboxProgress * (3 - 2 * letterboxProgress)
	local height = ns.DrawLetterbox(ns.letterbox, look, screenW, screenH, t)
	ns.letterbox:SetShown(letterboxProgress > 0)
	-- The switch flipped with the bars up: the world eases in or out over the
	-- bars' own time (with the bars out it just takes the new side).
	world.p = letterboxProgress > 0 and ns.Approach(world.p or 0, squeeze, elapsed,
		ns.LetterboxTime(look, squeeze > (world.p or 0))) or squeeze
	if world.p > 0 and letterboxProgress > 0 then
		WatchWorld()
		-- (Fading bars are full height at once: the world eases in with them.)
		local inset = look.letterboxMotion == "fade" and height * t or height
		local e = world.p * world.p * (3 - 2 * world.p)
		PlaceWorld(inset * e * ns.letterbox:GetEffectiveScale() / WorldFrame:GetEffectiveScale())
	else
		ns.LetterboxWorldBack()
	end
	-- The frame rate counter hangs on WorldFrame: the world between the bars
	-- has lifted it that much already.
	local lifted = world.at * WorldFrame:GetEffectiveScale() / ns.letterbox:GetEffectiveScale()
	LiftFramerate(letterboxProgress > 0 and math.max(0, height - lifted) or 0)
end
end)
