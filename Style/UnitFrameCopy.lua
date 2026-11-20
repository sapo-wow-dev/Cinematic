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
-- Retail's own, over those (12.1.5, the Preview Match run of 2026-11-20): the
-- target's and focus's level on the left of the name strip, no circle, the
-- name after it, left. Their place is secret there most of the time (the
-- name's always), so a read can't be counted on to give it.
local RETAIL = {
	TARGET = {
		name = { x = 31, y = 9.5, w = 90, h = 12, size = 10, justify = "LEFT" },
		level = { x = 4, y = 10.5, w = 15, h = 10, size = 10, justify = "CENTER" },
		circle = { hidden = true },
	},
}
RETAIL.FOCUS = RETAIL.TARGET
local function BuiltIn(id)
	local base = BUILT_IN[id]
	local over = ns.isRetail and RETAIL[id]
	if not over then return base end
	local merged = {}
	for role, entry in pairs(base or {}) do merged[role] = entry end
	for role, entry in pairs(over) do merged[role] = entry end
	return merged
end

-- (The target of target: the target's, else the focus's; one look for both.)
local FRAME_NAMES = { PLAYER = { "PlayerFrame" }, TARGET = { "TargetFrame" }, FOCUS = { "FocusFrame" }, PET = { "PetFrame" },
	TOT = { "TargetFrameToT", "FocusFrameToT" } }
local UNITS = { PlayerFrame = "player", TargetFrame = "target", FocusFrame = "focus", PetFrame = "pet",
	TargetFrameToT = "targettarget", FocusFrameToT = "focustarget" }

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

-- A texture's mask (the first one on it).
local function MaskOf(texture)
	local count = Plain(Call(texture, "GetNumMaskTextures"))
	if type(count) ~= "number" or count < 1 then return nil end
	return Region(Call(texture, "GetMaskTexture", 1))
end

-- Every region in a frame's tree that shows (textures, masks, texts), with
-- how deep it is (a frame's own parts and its children's, down to 6).
-- (skip(child): true leaves that child frame and all in it out.)
local function Walk(frame, visit, depth, skip)
	depth = depth or 0
	if depth > 6 then return end
	for _, region in ipairs({ Call(frame, "GetRegions") }) do visit(region) end
	for _, child in ipairs({ Call(frame, "GetChildren") }) do
		if Plain(Call(child, "IsShown")) and not Plain(Call(child, "IsForbidden")) and not (skip and skip(child)) then
			Walk(child, visit, depth + 1, skip)
		end
	end
end

local function Area(region)
	local w, h = Call(region, "GetSize")
	w, h = Plain(w), Plain(h)
	return (type(w) == "number" and type(h) == "number" and w == w and h == h) and w * h or 0
end

-- The game's parts on one of its frames (Forever's and retail's layout; the
-- pet's and others' found by what they are: the frame art is its biggest
-- piece of unit frame art).
local GameRegions
GameRegions = function(frame, id)
	local holder = Region(frame.PlayerFrameContainer) and frame.PlayerFrameContainer
		or Region(frame.TargetFrameContainer) and frame.TargetFrameContainer
	local content = frame.PlayerFrameContent or frame.TargetFrameContent
	local main = type(content) == "table" and (content.PlayerFrameContentMain or content.TargetFrameContentMain)
	main = type(main) == "table" and main or nil
	local bars = main and type(main.HealthBarsContainer) == "table" and main.HealthBarsContainer
	-- (The target of target names its parts in capitals: HealthBar, Name. Forever 2026-11-20.)
	local health = Region(frame.healthbar) or Region(frame.HealthBar)
	local power = Region(frame.manabar) or Region(frame.ManaBar)
	local name = frame.GetName and frame:GetName()
	-- (Its art as shown: the player's is a taller one with a class resource bar
	-- under the power (an Elemental shaman's Maelstrom over mana, retail
	-- 2026-11-20), another in a vehicle.)
	local art
	if holder then
		for _, key in ipairs({ "FrameTexture", "AlternatePowerFrameTexture", "VehicleFrameTexture" }) do
			local texture = Region(holder[key])
			if texture and Plain(Call(texture, "IsVisible")) then
				art = texture
				break
			end
		end
		art = art or Region(holder.FrameTexture)
	end
	local parts = {
		art = art or Region(frame.FrameTexture) or (name and Region(_G[name .. "Texture"])),
		portrait = Region(frame.portrait) or Region(frame.Portrait),
		health = health,
		power = power,
		name = Region(frame.name) or Region(frame.Name),
		circle = main and Region(main.LevelBackgroundCircle),
		level = id == "PLAYER" and Region(_G.PlayerLevelText) or (main and Region(main.LevelText)),
		reaction = main and Region(main.ReputationColor),
	}
	-- (Each one's mask, as the game put it on: by its key, else read off it.)
	parts.portraitMask = holder and Region(holder.PlayerPortraitMask or holder.PortraitMask) or MaskOf(parts.portrait)
	parts.healthMask = bars and Region(bars.HealthBarMask) or MaskOf(health and Call(health, "GetStatusBarTexture"))
	parts.powerMask = power and Region(power.ManaBarMask) or MaskOf(power and Call(power, "GetStatusBarTexture"))
	local contextual = type(content) == "table" and content.PlayerFrameContentContextual
	if id == "PLAYER" and type(contextual) == "table" then parts.corner = Region(contextual.PlayerPortraitCornerIcon) end
	if id == "PLAYER" then
		local area = main and type(main.AlternatePowerBarArea) == "table" and main.AlternatePowerBarArea
		local second = Region(area and area.AlternatePowerBar) or Region(_G.AlternatePowerBar)
		if second then
			parts.power2 = second
			parts.power2Mask = Region(second.PowerBarMask) or MaskOf(Call(second, "GetStatusBarTexture"))
		end
	end
	-- (Its target of target: where its art sits on this frame. Your pet's on yours.)
	local tot = Region(frame.totFrame) or (name and Region(_G[name .. "ToT"]))
	if (id == "TARGET" or id == "FOCUS") and tot and Plain(Call(tot, "IsVisible")) then
		parts.totFrame = tot
		parts.tot = GameRegions(tot, "TOT").art or tot
	end
	local pet = Region(_G.PetFrame)
	if id == "PLAYER" and pet and Plain(Call(pet, "IsVisible")) then
		parts.petFrame = pet
		parts.pet = GameRegions(pet, "PET").art or pet
	end
	if not parts.art then
		local best, most = nil, 0
		Walk(frame, function(region)
			local atlas = Call(region, "GetObjectType") == "Texture" and Plain(Call(region, "GetAtlas"))
			if type(atlas) == "string" and atlas:find("UnitFrame", 1, true) and not atlas:find("Bar", 1, true)
				and Plain(Call(region, "IsVisible")) and Area(region) > most then
				best, most = region, Area(region)
			end
		end)
		parts.art = best
	end
	return parts
end

local function Round(value) return math.floor(value * 10 + 0.5) / 10 end
local RECIPE_VERSION = 2

-- Where a point of a region is, in screen units (its rect readable).
local POINTS = { TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 },
	RIGHT = { 1, 0.5 }, BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 } }
local function PointOf(region, point)
	local l, b, w, h = Call(region, "GetRect")
	l, b, w, h = Plain(l), Plain(b), Plain(w), Plain(h)
	local scale = Plain(Call(region, "GetEffectiveScale"))
	local at = POINTS[point]
	if type(l) ~= "number" or type(w) ~= "number" or type(scale) ~= "number" or not at or w ~= w then return nil end
	return (l + w * at[1]) * scale, (b + h * at[2]) * scale
end

-- A text whose place the game keeps secret (retail's names and bar texts,
-- 2026-11-20: their words are, so their size is): its anchor point, from where
-- it's tied and how far, which are readable. Its justify and font too.
ns.UnitFrameTextWhy = {} -- [region] = why its place couldn't be read, for the Preview Match test's log
local function ReadTextAnchor(region, art, artL, artT)
	local ok, point, relative, relativePoint, x, y = pcall(region.GetPoint, region, 1)
	point, relativePoint, x, y = Plain(point), Plain(relativePoint), Plain(x), Plain(y)
	if not (ok and type(point) == "string" and type(relativePoint) == "string" and relative) then
		ns.UnitFrameTextWhy[region] = ("its anchor unreadable (%s %s %s)"):format(tostring(ok), tostring(point), tostring(relativePoint))
		-- (Its anchor's secret too (retail's target of target, 2026-11-20): only its
		-- side and font are read; the copy sets it on the health bar's top edge.)
		local justify = Plain(Call(region, "GetJustifyH"))
		if type(justify) ~= "string" then return nil end
		local _, size = Call(region, "GetFont")
		size = Plain(size)
		local scale, artScale = Plain(Call(region, "GetEffectiveScale")), Plain(Call(art, "GetEffectiveScale"))
		local f = (type(scale) == "number" and type(artScale) == "number" and artScale > 0) and scale / artScale or 1
		return { onBar = true, justify = justify, size = type(size) == "number" and Round(size * f) or nil }
	end
	local rx, ry = PointOf(relative, relativePoint)
	local scale, artScale = Plain(Call(region, "GetEffectiveScale")), Plain(Call(art, "GetEffectiveScale"))
	if not (rx and type(scale) == "number" and type(artScale) == "number" and artScale > 0) then
		ns.UnitFrameTextWhy[region] = ("tied at %s to %s's %s, whose place is unreadable too"):format(point,
			tostring(Plain(Call(relative, "GetName")) or Plain(Call(relative, "GetObjectType"))), relativePoint)
		return nil
	end
	ns.UnitFrameTextWhy[region] = nil
	local px, py = rx + (tonumber(x) or 0) * scale, ry + (tonumber(y) or 0) * scale
	local entry = { anchor = { point = point, x = Round(px / artScale - artL), y = Round(artT - py / artScale) } }
	local _, size = Call(region, "GetFont")
	size = Plain(size)
	entry.size = type(size) == "number" and Round(size * scale / artScale) or nil
	entry.justify = Plain(Call(region, "GetJustifyH"))
	return entry
end

-- One part: its place from the art's top-left, in the art's own units.
local function ReadPart(region, art, artL, artT)
	if not Plain(Call(region, "IsVisible")) then return nil end
	local l, b, w, h = Call(region, "GetRect")
	l, b, w, h = Plain(l), Plain(b), Plain(w), Plain(h)
	local scale, artScale = Plain(Call(region, "GetEffectiveScale")), Plain(Call(art, "GetEffectiveScale"))
	if type(l) ~= "number" or type(w) ~= "number" or type(scale) ~= "number" or type(artScale) ~= "number"
		or artScale <= 0 or w ~= w or h ~= h then
		if Call(region, "GetObjectType") == "FontString" then return ReadTextAnchor(region, art, artL, artT) end
		return nil
	end
	local f = scale / artScale
	local entry = { x = Round(l * f - artL), y = Round(artT - (b + h) * f), w = Round(w * f), h = Round(h * f) }
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
		entry.size = type(size) == "number" and Round(size * f) or nil
		entry.justify = Plain(Call(region, "GetJustifyH"))
	end
	return entry
end

-- The frame's other art (an elite's dragon, a pet's happiness, a frame's
-- extra pieces): every shown texture of the game's unit frame art not one of
-- the parts, as it is, with its mask. (Not the bars' fills or their own
-- overlays, not texts: those are the unit's.)
local MAX_EXTRAS = 24
local STATES = { "Rest", "Status", "Flash", "Glow", "Highlight", "TempHPLoss", "Attack", "Combat", "PVP", "Leader" }
local function ReadExtras(frame, parts, art, artL, artT)
	local known = {}
	for _, region in pairs(parts) do known[region] = true end
	-- (Not another unit frame's art, in it or not: the target of target's, and
	-- the pet frame's, a child of the player frame. Its art came out as a
	-- second empty frame under yours, 2026-11-20.)
	local function OtherFrame(child)
		return child ~= frame and (Region(child.healthbar) or Region(child.HealthBar)) ~= nil
	end
	for _, other in ipairs({ parts.totFrame or false, parts.petFrame or false }) do
		if other then Walk(other, function(region) known[region] = true end) end
	end
	for _, bar in ipairs({ parts.health or false, parts.power or false }) do
		if bar then
			known[Call(bar, "GetStatusBarTexture") or false] = true
			Walk(bar, function(region) known[region] = true end)
		end
	end
	local list = {}
	Walk(frame, function(region)
		if #list >= MAX_EXTRAS or known[region] or Call(region, "GetObjectType") ~= "Texture" then return end
		local atlas = Plain(Call(region, "GetAtlas"))
		if not (type(atlas) == "string" and atlas:find("UnitFrame", 1, true)) then return end
		-- (Not a state the frame's in now: resting, in a fight, flashing, a health loss.)
		for _, state in ipairs(STATES) do if atlas:find(state, 1, true) then return end end
		local entry = ReadPart(region, art, artL, artT)
		if not entry or entry.w < 1 or entry.h < 1 then return end
		entry.atlas = atlas
		local layer, sub = Call(region, "GetDrawLayer")
		entry.layer, entry.sub = Plain(layer), Plain(sub)
		local r, g, b, a = Call(region, "GetVertexColor")
		r, g, b, a = Plain(r), Plain(g), Plain(b), Plain(a)
		if type(r) == "number" then entry.color = { Round(r * 10) / 10, Round(g * 10) / 10, Round(b * 10) / 10, a and Round(a * 10) / 10 or 1 } end
		entry.blend = Plain(Call(region, "GetBlendMode"))
		local mask = MaskOf(region)
		if mask then
			local m = ReadPart(mask, art, artL, artT)
			local maskAtlas = Plain(Call(mask, "GetAtlas"))
			if m and type(maskAtlas) == "string" then
				m.atlas = maskAtlas
				entry.mask = m
			end
		end
		list[#list + 1] = entry
	end, 0, OtherFrame)
	return list
end

-- Whether this client's unit frames are the kind the recipe draws (Forever's
-- and retail's; the classic clients' older frames aren't).
function ns.UnitFrameCopyable()
	local frame = _G.PlayerFrame
	return type(frame) == "table" and Region(frame.PlayerFrameContainer) ~= nil
end

-- The live frame's recipe (nil: not up, in a fight, or not the game's look on it).
-- (In a fight too: a unit frame's places and art read fine then (Forever,
-- 2026-11-20), and the target of target is mostly up in one. A part the game
-- won't tell is left out, and the one read before kept.)
function ns.ReadUnitFrameRecipe(id)
	local frame, unit
	for _, name in ipairs(FRAME_NAMES[id] or {}) do
		local candidate = _G[name]
		if candidate and not Plain(Call(candidate, "IsForbidden")) and Plain(Call(candidate, "IsVisible"))
			and UnitExists(UNITS[name]) then
			frame, unit = candidate, UNITS[name]
			break
		end
	end
	if not frame then return nil end
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
		if role ~= "totFrame" and role ~= "petFrame" then
			recipe[role] = ReadPart(region, art, l, b + h)
			-- (One the game hides is hidden in the copy too: your level at the top
			-- level, the target's level circle on retail. Not filled in from the
			-- built-in one, which is Forever's.)
			if not recipe[role] and not Plain(Call(region, "IsVisible")) then recipe[role] = { hidden = true } end
		end
	end
	-- (A part the live read must have, or it isn't the frame drawn.)
	if not (recipe.art and recipe.health and recipe.art.atlas) then return nil end
	recipe.extras = ReadExtras(frame, parts, art, l, b + h)
	-- (Its power's kind: the pet's bar is mana's for a warlock's, its own for a hunter's.)
	local ok, powerType = pcall(UnitPowerType, unit)
	recipe.info = { powerType = ok and Plain(powerType) or nil }
	-- (How big it's drawn against the screen: frames are sized against each other by it.)
	local artScale, uiScale = Plain(Call(art, "GetEffectiveScale")), UIParent:GetEffectiveScale()
	if type(artScale) == "number" and uiScale > 0 then recipe.info.scale = math.floor(artScale / uiScale * 1000 + 0.5) / 1000 end
	return recipe
end

-- A frame's recipe: the built-in one, under what was read (saved), under
-- what's read now. Read now is saved for the times the frame isn't up. A
-- frame with no built-in one (the pet's) has one once it's been read.
function ns.UnitFrameRecipe(id)
	if not FRAME_NAMES[id] then return nil end
	local base = BuiltIn(id) or {}
	local client = ns.isRetail and "retail" or "classic"
	CinematicDB = CinematicDB or {}
	CinematicDB.unitFrameRecipes = CinematicDB.unitFrameRecipes or {}
	local store = CinematicDB.unitFrameRecipes[client] or {}
	-- (Version 2: version 1's player recipe had the pet frame's art in it.)
	if store.version ~= RECIPE_VERSION then
		wipe(store)
		store.version = RECIPE_VERSION
	end
	CinematicDB.unitFrameRecipes[client] = store
	local live = ns.ReadUnitFrameRecipe(id)
	if live then
		local saved = store[id] or {}
		for role, entry in pairs(live) do
			-- (A weaker read never takes a measured one's place: a name read only by
			-- its anchor, or only its side (secret in a fight on retail), keeps the
			-- place read before and takes just its side and size. The target's name
			-- sat on its level, 2026-11-20.)
			local before = saved[role]
			local measured = type(before) == "table" and before.x ~= nil
			local weaker = type(entry) == "table" and (entry.onBar or entry.anchor)
			if measured and weaker then
				before.justify = entry.justify or before.justify
				before.size = entry.size or before.size
			elseif type(before) == "table" and before.anchor and type(entry) == "table" and entry.onBar then
				before.justify = entry.justify or before.justify
			else
				saved[role] = entry
			end
		end
		-- (A part the frame doesn't show now (its power, its level) stays as read before.)
		saved.extras = live.extras
		store[id] = saved
	end
	if not (BUILT_IN[id] or store[id]) then return nil end
	local recipe = {}
	for role, entry in pairs(base) do recipe[role] = entry end
	for role, entry in pairs(store[id] or {}) do
		if role == "extras" then
			recipe.extras = entry
		else
			-- (A read part keeps the built-in art when the read had none: the
			-- game's look was off that part.)
			local built = recipe[role]
			local merged = {}
			if entry.onBar and type(built) == "table" and built.x then
				-- (Only its side read: the built-in place stands, with that side.)
				for key, value in pairs(built) do merged[key] = value end
				merged.justify = entry.justify or merged.justify
				merged.size = entry.size or merged.size
			elseif entry.anchor then
				-- (Its anchor read here: truer than a built-in place, which may be the other client's.)
				for key, value in pairs(entry) do merged[key] = value end
			else
				for key, value in pairs(built or {}) do merged[key] = value end
				for key, value in pairs(entry) do merged[key] = value end
			end
			merged.guess = nil
			recipe[role] = merged
		end
	end
	return recipe
end
