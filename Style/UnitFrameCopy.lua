-- The game's own unit frames, as a recipe the Unit Frames page's preview
-- draws its game look from (Tools/preview-match-plan.md, way B: copy the
-- live frame). Each part's art (atlas), place and size, in the frame's own
-- units from its frame art's top-left corner: the frame art, the portrait and
-- its mask, the health and power bars (their fill and mask), the name, the
-- level and its circle, the player's corner piece, the target's reaction
-- strip. Read off the live frame while it's up, out of fights and with the
-- game's look on it (so it's the game's, not ours), and kept per client
-- (CinematicDB.unitFrameRecipes), so a preview can be drawn with no target.
-- Before any read: the frames as WoW Forever draws them (the Preview Match
-- run of 2026-11-20, /cine debug previewmatch units). Nothing of the game's
-- art is kept: atlas names only, drawn by the game at runtime.
local _, ns = ...

-- The built-in recipes (Forever 1.60.1, 2026-11-20). x, y: from the frame
-- art's top-left, right and down; w, h: size.
local BUILT_IN = {
	PLAYER = {
		art = { x = 0, y = 0, w = 198, h = 71, atlas = "UI-HUD-UnitFrame-Player-PortraitOn" },
		portrait = { x = 6.7, y = 5, w = 60, h = 60 },
		portraitMask = { x = 6.7, y = 5, w = 60, h = 60, atlas = "UI-HUD-UnitFrame-Player-Portrait-Mask" },
		health = { x = 70, y = 29, w = 124, h = 20, atlas = "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health" },
		healthMask = { x = 68.3, y = 22.5, w = 127.5, h = 31.7, atlas = "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health-Mask" },
		power = { x = 70, y = 46.7, w = 124, h = 10, atlas = "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana" },
		powerMask = { x = 68.3, y = 44.2, w = 127.5, h = 15.8, atlas = "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana-Mask" },
		name = { x = 74.2, y = 16.7, w = 116, h = 12, size = 10, justify = "CENTER" },
		circle = { x = -4.2, y = 39.2, w = 38, h = 38, atlas = "UI-HUD-UnitFrame-SmallCircle" },
		level = { x = 5.8, y = 52.5, w = 19, h = 14, size = 14, justify = "RIGHT" },
		corner = { x = 41.7, y = 39.2, w = 32, h = 32, atlas = "UI-HUD-UnitFrame-Player-PortraitOn-CornerEmbellishment" },
	},
	TARGET = {
		art = { x = 0, y = 0, w = 194, h = 68, atlas = "UI-HUD-UnitFrame-Target-PortraitOn" },
		portrait = { x = 129.2, y = 3.3, w = 57.5, h = 57.5 },
		portraitMask = { x = 129.2, y = 3.3, w = 57.5, h = 57.5, atlas = "CircleMask" },
		reaction = { x = -3.3, y = 10, w = 134, h = 17.5, atlas = "UI-HUD-UnitFrame-Target-PortraitOn-Type" },
		health = { x = 1.7, y = 25, w = 126, h = 20, atlas = "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health" },
		healthMask = { x = 0.8, y = 18.3, w = 127.5, h = 31.7, atlas = "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health-Mask" },
		-- (Not read yet: the run's target had no power. Under the health bar, as the player's.)
		power = { x = 1.7, y = 42.5, w = 126, h = 10, atlas = "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana", guess = true },
		name = { x = 5, y = 14.2, w = 116.7, h = 11.7, size = 10, justify = "CENTER" },
		circle = { x = 161.7, y = 37.5, w = 38, h = 38, atlas = "UI-HUD-UnitFrame-SmallCircle" },
		level = { x = 175, y = 50.8, w = 11, h = 14, size = 14, justify = "RIGHT" },
	},
}
BUILT_IN.FOCUS = BUILT_IN.TARGET
ns.UNIT_FRAME_RECIPES = BUILT_IN

local FRAME_NAMES = { PLAYER = "PlayerFrame", TARGET = "TargetFrame", FOCUS = "FocusFrame" }
local UNITS = { PLAYER = "player", TARGET = "target", FOCUS = "focus" }

local function Plain(value)
	if issecretvalue and issecretvalue(value) then return nil end
	return value
end
local function Call(object, method, ...)
	if type(object) ~= "table" or type(object[method]) ~= "function" then return nil end
	local results = { pcall(object[method], object, ...) }
	if not results[1] then return nil end
	return unpack(results, 2)
end
local function Region(value)
	return type(value) == "table" and type(value.GetObjectType) == "function" and type(value.GetRect) == "function"
		and value or nil
end

-- The game's parts on one of its frames (both clients' layout).
local function GameRegions(frame, id)
	local holder = Region(frame.PlayerFrameContainer) and frame.PlayerFrameContainer
		or Region(frame.TargetFrameContainer) and frame.TargetFrameContainer
	local content = frame.PlayerFrameContent or frame.TargetFrameContent
	local main = type(content) == "table" and (content.PlayerFrameContentMain or content.TargetFrameContentMain)
	main = type(main) == "table" and main or nil
	local bars = main and type(main.HealthBarsContainer) == "table" and main.HealthBarsContainer
	local health = Region(frame.healthbar)
	local power = Region(frame.manabar)
	local parts = {
		art = holder and Region(holder.FrameTexture),
		portrait = Region(frame.portrait),
		portraitMask = holder and Region(holder.PlayerPortraitMask or holder.PortraitMask),
		health = health,
		healthMask = bars and Region(bars.HealthBarMask),
		power = power,
		powerMask = power and Region(power.ManaBarMask),
		name = Region(frame.name),
		circle = main and Region(main.LevelBackgroundCircle),
		level = id == "PLAYER" and Region(_G.PlayerLevelText) or (main and Region(main.LevelText)),
		reaction = main and Region(main.ReputationColor),
	}
	local contextual = type(content) == "table" and content.PlayerFrameContentContextual
	if id == "PLAYER" and type(contextual) == "table" then parts.corner = Region(contextual.PlayerPortraitCornerIcon) end
	return parts
end

-- One part: its place from the art's top-left, in the art's own units.
local function ReadPart(region, art, artL, artT)
	if not Plain(Call(region, "IsVisible")) then return nil end
	local l, b, w, h = Call(region, "GetRect")
	l, b, w, h = Plain(l), Plain(b), Plain(w), Plain(h)
	local scale, artScale = Plain(Call(region, "GetEffectiveScale")), Plain(Call(art, "GetEffectiveScale"))
	if type(l) ~= "number" or type(w) ~= "number" or type(scale) ~= "number" or type(artScale) ~= "number"
		or artScale <= 0 or w ~= w or h ~= h then
		return nil
	end
	local f = scale / artScale
	local entry = { x = l * f - artL, y = artT - (b + h) * f, w = w * f, h = h * f }
	for _, key in ipairs({ "x", "y", "w", "h" }) do entry[key] = math.floor(entry[key] * 10 + 0.5) / 10 end
	local kind = Call(region, "GetObjectType")
	local texture = kind == "StatusBar" and Call(region, "GetStatusBarTexture") or region
	local atlas = Plain(Call(texture, "GetAtlas"))
	-- (Only the game's own art: a Style look's texture on the bars isn't the recipe.)
	if type(atlas) == "string" and (atlas:find("UnitFrame", 1, true) or atlas:find("Mask", 1, true)) then
		entry.atlas = atlas
	end
	if kind == "FontString" then
		local _, size = Call(region, "GetFont")
		size = Plain(size)
		entry.size = type(size) == "number" and math.floor(size * f * 10 + 0.5) / 10 or nil
		entry.justify = Plain(Call(region, "GetJustifyH"))
	end
	return entry
end

-- Whether this client's unit frames are the kind the recipe draws (Forever's
-- and retail's; the classic clients' older frames aren't).
function ns.UnitFrameCopyable()
	local frame = _G.PlayerFrame
	return type(frame) == "table" and Region(frame.PlayerFrameContainer) ~= nil
end

-- The live frame's recipe (nil: not up, in a fight, or not the game's look on it).
function ns.ReadUnitFrameRecipe(id)
	local frame = _G[FRAME_NAMES[id] or ""]
	if not frame or InCombatLockdown() or Plain(Call(frame, "IsForbidden")) then return nil end
	if not (Plain(Call(frame, "IsVisible")) and UnitExists(UNITS[id])) then return nil end
	-- (Our look on it: only the game's shape keeps the game's places.)
	local view = ns.UnitStyleView and ns.UnitStyleView(id)
	if ns.StyleOn and ns.StyleOn("ufStyle") and view and (view.ufShape ~= "game" or (ns.ThemeLayout and ns.ThemeLayout())) then
		return nil
	end
	local parts = GameRegions(frame, id)
	local art = parts.art
	if not art then return nil end
	local l, b, w, h = Call(art, "GetRect")
	l, b, w, h = Plain(l), Plain(b), Plain(w), Plain(h)
	if type(l) ~= "number" or type(h) ~= "number" or w ~= w then return nil end
	local recipe = {}
	for role, region in pairs(parts) do
		recipe[role] = ReadPart(region, art, l, b + h)
	end
	-- (A part the live read must have, or it isn't the frame drawn.)
	if not (recipe.art and recipe.health and recipe.art.atlas) then return nil end
	return recipe
end

-- A frame's recipe: the built-in one, under what was read (saved), under
-- what's read now. Read now is saved for the times the frame isn't up.
function ns.UnitFrameRecipe(id)
	local base = BUILT_IN[id]
	if not base then return nil end
	local client = ns.isRetail and "retail" or "classic"
	CinematicDB = CinematicDB or {}
	CinematicDB.unitFrameRecipes = CinematicDB.unitFrameRecipes or {}
	local store = CinematicDB.unitFrameRecipes[client] or {}
	CinematicDB.unitFrameRecipes[client] = store
	local live = ns.ReadUnitFrameRecipe(id)
	if live then
		local saved = store[id] or {}
		for role, entry in pairs(live) do saved[role] = entry end
		store[id] = saved
	end
	local recipe = {}
	for role, entry in pairs(base) do recipe[role] = entry end
	for role, entry in pairs(store[id] or {}) do
		-- (A read part keeps the built-in art when the read had none: the game's
		-- look was off that part.)
		local merged = {}
		for key, value in pairs(recipe[role] or {}) do merged[key] = value end
		for key, value in pairs(entry) do merged[key] = value end
		merged.guess = nil
		recipe[role] = merged
	end
	return recipe
end
