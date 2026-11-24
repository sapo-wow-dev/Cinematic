-- /cine debug tintlayer (dev copy only): where can a screen wash sit so that
-- what's drawn over the world keeps its own colour? A strong red wash (MOD,
-- as the tint) is laid in each place a frame or texture of ours could go, one
-- at a time, with a screenshot of each. Whatever stays its own colour in a
-- shot is drawn over the wash there. Steps:
--   1 plates   nameplate names, hands off (proven 2026-11-12: only a texture
--              of WorldFrame's own draws under them, rule forever.plate.draw-order)
--   2 numbers  the game's damage numbers over a mob, in a fight: the place
--              the tint had before 2026-11-12 (a UIParent frame, BACKGROUND 0)
--              against today's (WorldFrame's own texture) and the others.
--              Red numbers in a shot = that wash colours them. The question:
--              did moving the tint start colouring them (2026-11-23: "i would
--              have noticed")? CineMode is off, so the real tint isn't drawn.
-- Into CinematicDB.tintLayerTestLog. Dev copy only.
local _, ns = ...

-- parent: nil = none. strata nil = left as the parent gives it.
local PLACES = {
	{ key = "none", name = "no wash (reference)" },
	{ key = "uiparent", name = "UIParent frame, BACKGROUND 0 (the tint before 2026-11-12)",
		parent = "UIParent", strata = "BACKGROUND", level = 0 },
	{ key = "wfchild", name = "WorldFrame child, strata as given, level 0", parent = "WorldFrame", level = 0 },
	{ key = "wfworld", name = "WorldFrame child, WORLD 0", parent = "WorldFrame", strata = "WORLD", level = 0 },
	{ key = "wfback", name = "WorldFrame child, BACKGROUND 0", parent = "WorldFrame", strata = "BACKGROUND", level = 0 },
	{ key = "noworld", name = "no parent, WORLD 0", strata = "WORLD", level = 0 },
	{ key = "noback", name = "no parent, BACKGROUND 0", strata = "BACKGROUND", level = 0 },
	{ key = "texture", name = "a texture of WorldFrame's own, BACKGROUND layer (the tint today on Forever)",
		texture = "BACKGROUND" },
	{ key = "textureover", name = "a texture of WorldFrame's own, OVERLAY layer", texture = "OVERLAY" },
}
-- The fight step: the old place, today's, and one of each other kind.
local NUMBER_PLACES = { "none", "uiparent", "texture", "textureover", "wfchild", "noback", "none" }

local washes = {}

local function Where(frame)
	local okStrata, strata = pcall(frame.GetFrameStrata, frame)
	local okLevel, level = pcall(frame.GetFrameLevel, frame)
	return ("%s %s"):format(okStrata and tostring(strata) or "?", okLevel and tostring(level) or "?")
end

-- The nameplates up: how many, and each different strata+level seen on the
-- plates themselves and on their unit frames (where the name is).
local function Plates()
	local list = C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates() or {}
	local seen, order = {}, {}
	local function Note(text)
		if not seen[text] then
			seen[text] = true
			order[#order + 1] = text
		end
	end
	for _, plate in ipairs(list) do
		Note("plate " .. Where(plate))
		local unitFrame = plate.UnitFrame
		if type(unitFrame) == "table" and unitFrame.GetFrameStrata then
			Note("its UnitFrame " .. Where(unitFrame))
		end
	end
	return ("%d plates: %s"):format(#list, #order > 0 and table.concat(order, ", ") or "none")
end

local function Wash(place)
	local wash = washes[place]
	if wash then return wash end
	if place.texture then
		wash = WorldFrame:CreateTexture(nil, place.texture)
	else
		local frame = CreateFrame("Frame", nil, place.parent and _G[place.parent] or nil)
		if place.strata then pcall(frame.SetFrameStrata, frame, place.strata) end
		pcall(frame.SetFrameLevel, frame, place.level)
		frame:EnableMouse(false)
		wash = frame:CreateTexture(nil, "BACKGROUND")
		wash.frame = frame
		frame:SetAllPoints(WorldFrame)
	end
	wash:SetAllPoints(wash.frame or WorldFrame)
	wash:SetColorTexture(1, 0.1, 0.1, 1)
	wash:SetBlendMode("MOD")
	washes[place] = wash
	return wash
end

local function HideAll()
	for _, wash in pairs(washes) do
		wash:Hide()
		if wash.frame then wash.frame:Hide() end
	end
end

-- One place's wash up; what it got, for the log.
local function Lay(place)
	HideAll()
	if not (place.parent or place.strata or place.texture) then return "-" end
	local ok, wash = pcall(Wash, place)
	if not ok then return "failed: " .. tostring(wash) end
	if wash.frame then wash.frame:Show() end
	wash:Show()
	return wash.frame and Where(wash.frame) or ("WorldFrame texture " .. tostring(place.texture))
end

local BY_KEY = {}
for _, place in ipairs(PLACES) do BY_KEY[place.key] = place end

local function CVar(name)
	local ok, value = pcall(GetCVar, name)
	return ok and tostring(value) or "?"
end

ns.TestKit.Define({
	name = "tintlayer",
	key = "tintLayerTest",
	title = "Tint layer",
	about = "a red wash in each place a frame can sit, screenshots: nameplate names, then damage numbers in a fight",
	needs = "A mob or training dummy to keep hitting for about 40 seconds",
	cvars = { "floatingCombatTextCombatDamage_v2", "floatingCombatTextCombatDamage", "enableFloatingCombatText",
		"WorldTextScale_v2" },
	context = function()
		return ("WorldFrame %s, UIParent %s, CinematicTint %s"):format(Where(WorldFrame), Where(UIParent),
			_G.CinematicTint and (_G.CinematicTint:IsShown() and "shown" or "hidden") or "none")
	end,
	finish = function() HideAll() end,
	putBack = function() HideAll() end,
	steps = {
		{ key = "plates", title = "nameplate names under each wash",
			proven = "tintlayer run 1, 2026-11-12: only WorldFrame's own texture draws under the names",
			run = function(r)
				for index, place in ipairs(PLACES) do
					local got = Lay(place)
					r:Log(("plates %d/%d: %s | got %s | %s"):format(index, #PLACES, place.name, got, Plates()))
					r:Shot("plates: " .. place.name)
				end
				HideAll()
				r:Pass("one shot per place: names in their own colour = over the wash")
			end },
		{ key = "numbers", title = "damage numbers under each wash, in a fight",
			proven = "tintlayer queue qe41d, 2026-11-23: every wash colors the numbers (rule forever.worldtext.under-every-wash)",
			run = function(r)
			r:Probe("the real tint not drawn (CineMode off)", function()
				local drawn = ns.tintDrawn
				return _G.CinematicTint and _G.CinematicTint:IsShown() or false,
					drawn and ("last drawn: %s none=%s"):format(tostring(drawn.preset), tostring(drawn.none)) or "never drawn"
			end)
			r:Log(("number CVars: damage_v2=%s damage=%s floating=%s scale_v2=%s"):format(
				CVar("floatingCombatTextCombatDamage_v2"), CVar("floatingCombatTextCombatDamage"),
				CVar("enableFloatingCombatText"), CVar("WorldTextScale_v2")))
			local function InFight()
				return UnitAffectingCombat("player") and true or false
			end
			for index, key in ipairs(NUMBER_PLACES) do
				local place, got = BY_KEY[key]
				-- (In a fight when the shot is taken: else wait for one and lay it again.)
				repeat
					if not InFight() then
						HideAll()
						r:WaitFor(index == 1 and "Attack a mob or a training dummy and keep hitting it (the screen turns red at times)"
							or "The fight ended: hit something again and keep going", { check = InFight })
					end
					got = Lay(place)
					r:Sleep(1.5) -- (a few hits land under the wash)
				until InFight()
				r:Log(("numbers %d/%d: %s | got %s | target %s"):format(index, #NUMBER_PLACES, place.name,
					got, UnitExists("target") and "yes" or "none"))
				r:Shot("numbers: " .. place.name)
			end
			r:Pass(("%d shots, each laid in a fight"):format(#NUMBER_PLACES))
			HideAll()
			r:Log("numbers: red numbers in a shot = that wash colours them; white/yellow = drawn over it")
		end },
	},
})
