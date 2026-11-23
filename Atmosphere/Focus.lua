-- Cinematic depth of field (faked): a soft pale mist around the screen edges,
-- as if the camera had pulled focus onto you. Shown in CineMode where the
-- Visual Effects page's Haze row says (depthOfField, under visualEffects; its
-- rule to start with: the camera modes), at Haze strength (dofScale, 0-1: one
-- strength everywhere since 2026-11-23, the camera pages' own Edge haze gone),
-- or a script of your own's Edge haze while it runs. /cine doftest shows it on demand.
local ADDON_NAME, ns = ...
ns.Module("atmosphere", function() -- (the rest of this file: only with Atmosphere loaded, Modules.lua)

-- (The addon's own folder: "Cinematic" hard-coded drew nothing in the dev
-- copy, folder CinematicDev, 2026-11-23: the haze was never seen there.)
local FOCUS_TEXTURE = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Textures\\Focus"
local FOCUS_IN_TIME = 3    -- seconds to pull focus in: slow, like a focus pull
local FOCUS_OUT_TIME = 0.8 -- ...and to clear again once you move
local BLEND_TIME = 1.5     -- seconds to go from no haze to full, changing modes
local DEMO_STRENGTH = 0.3  -- /cine doftest's strength, unless told another
local DEFAULT_SECONDS = 30
local PREVIEW_SECONDS = 3  -- shown this long after a strength slider moves

local frame, haze
local level, strength = 0, 0 -- how far in the focus pull is, and the haze it pulls to
local stopAt, demoStrength = 0, nil

-- The strength wanted now: the demo's, else Haze strength where its row has it.
local function WantedStrength()
	if GetTime() < stopAt then
		return demoStrength or DEMO_STRENGTH
	end
	local db = ns.db
	if not db or not db.enabled or not db.visualEffects or not db.depthOfField
		or not ns.lastCinematic then
		return 0
	end
	-- (Its Show in row since 2026-11-23, effect:haze: Core's effectWanted.
	-- Its rule to start with, "camera", has it in the camera modes only.)
	if not (ns.effectWanted and ns.effectWanted.haze) then return 0 end
	-- (A script of your own running with an Edge haze of its own: that. The
	-- built-in cameras have none: Haze strength.)
	local scripted = ns.CameraScriptHaze and ns.CameraScriptHaze()
	if scripted then return math.min(1, scripted) end
	return math.max(0, math.min(1, tonumber(db.dofScale) or 0))
end

local function OnUpdate(_, elapsed)
	local want = WantedStrength()
	if want <= 0 and level == 0 then
		return -- (off and all faded: nothing to draw)
	end
	if want > 0 then
		level = math.min(1, level + elapsed / FOCUS_IN_TIME)
		-- Coming in from nothing, start at the new strength; otherwise (one mode
		-- to the next) glide to it.
		if strength == 0 then
			strength = want
		elseif strength ~= want then
			local step = elapsed / BLEND_TIME
			strength = strength < want and math.min(want, strength + step) or math.max(want, strength - step)
		end
	else
		level = math.max(0, level - elapsed / FOCUS_OUT_TIME) -- (fades at the strength it had)
		if level == 0 then
			strength = 0
		end
	end
	-- Eased, so the pull starts gently and settles.
	local eased = level * level * (3 - 2 * level)
	haze:SetAlpha(strength * eased)
	haze:SetShown(level > 0)
end

-- Over the world, beside the tint and under the letterbox bars and the UI.
frame = CreateFrame("Frame", "CinematicFocus", UIParent)
ns.CoverWorld(frame)
frame:SetFrameStrata("BACKGROUND")
frame:SetFrameLevel(0)
frame:EnableMouse(false)
ns.AddOverlay(frame)

haze = frame:CreateTexture(nil, "ARTWORK", nil, 1)
haze:SetAllPoints()
-- (Whether the game found the file: /cine debug atmosphere checks it.)
ns.focusTextureLoaded = haze:SetTexture(FOCUS_TEXTURE)
haze:SetBlendMode("BLEND")
haze:SetAlpha(0)
haze:Hide()

-- (Runs only while it's on and in CineMode, or a demo or a fade's still
-- going. CineMode starting: on within the second, before its slow pull in.)
ns.FeatureLoop(frame, ns.Profiled("Depth of field", OnUpdate), function()
	local db = ns.db
	return level > 0 or GetTime() < stopAt
		or (db and db.enabled and db.visualEffects and db.depthOfField and ns.lastCinematic) and true or false
end)

-- Shows the haze for a while (default 30 seconds), at `value` (0-1) or the
-- demo strength. Returns false if a demo was already showing and has now
-- been stopped instead.
function ns.FocusDemo(seconds, value)
	if GetTime() < stopAt and not seconds and not value then
		stopAt = 0
		return false
	end
	if value then
		demoStrength = math.max(0, math.min(1, value))
		strength = demoStrength -- (show a new value at once, for comparing)
	end
	stopAt = GetTime() + (seconds or DEFAULT_SECONDS)
	ns.WakeFeatureLoop(frame)
	return true
end

-- A strength slider moved: show that strength for a moment.
function ns.FocusPreview(value)
	ns.FocusDemo(PREVIEW_SECONDS, value)
	level = 1 -- straight in, so you see the value now
end

-- The haze as drawn now (0-1), for /cine debug atmosphere.
function ns.FocusAlphaNow()
	return haze:IsShown() and haze:GetAlpha() or 0
end

-- Whether a demo or preview is showing (the Visual Effects page's Preview
-- button turns into Stop meanwhile; ns.FocusDemo() with nothing stops it).
function ns.FocusDemoRunning()
	return GetTime() < stopAt
end

-- The demo's strength (for /cine doftest's message).
function ns.FocusDemoStrength()
	return demoStrength or DEMO_STRENGTH
end
end)
