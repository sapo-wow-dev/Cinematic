-- The game's templates on the offline stand-in (opt-in): a frame made from a
-- game template gets that template's real parts (frame.Icon, frame.Spark,
-- frame.Text, child frames...) with their atlas or file, size, layer, anchors,
-- hidden and alpha, read from the game's own XML by Tools/engine/templates.py
-- (Tools/engine/api/templates-<client>.lua: Blizzard's data, git-ignored, made
-- from the console's exportInterfaceFiles code). Without it the stand-in
-- hands back a stub for frame.Icon and nil for frame.Text, so code that
-- builds on a game template takes its fallback offline.
--
--   local parts = dofile("Tools/offline/templateparts.lua")
--   parts.Use("forever")       -- after wow.Install (load.lua's onInstall); nil, why when there's no recipe file
--   parts.Use({ Name = recipe }) -- recipes by hand (offline checks)
--   parts.Build(frame, "ATemplate, BTemplate")
--   parts.Stop()               -- CreateFrame as it was
--
-- Each part keeps what the XML said in region._part, and its anchors, made
-- relative to real frames, in region._partPoints = { { point, frame, relPoint,
-- x, y } } (the plain stand-in's SetPoint keeps nothing). Mixins and scripts
-- aren't run: Blizzard's Lua isn't here. Offline check: Tools/offline/templatepartscheck.lua.
local M = {}
local recipes, oldCreate

local function Resolve(owner, rel)
	-- (A region's anchors are relative to its frame by default; "$parent" is
	-- that frame for a region, the parent for a child frame; "$parent.Key" a
	-- part of it; anything else a global by name, $parent swapped for the
	-- frame's name.)
	if rel == nil or rel == "" then return owner end
	local low = rel:lower()
	if low == "$parent" then return owner end
	local key = rel:match("^%$[Pp]arent%.(.+)$")
	if key then
		local target = owner
		for piece in key:gmatch("[^%.]+") do
			if piece:lower() == "$parent" then target = target and target:GetParent() else target = target and rawget(target, piece) end
		end
		return target
	end
	local name = rel:gsub("%$[Pp]arent", (owner and owner.GetName and owner:GetName()) or "")
	return _G[name]
end

local function Named(frame, name)
	if not name then return nil end
	return (name:gsub("%$[Pp]arent", (frame and frame.GetName and frame:GetName()) or ""))
end

local function Place(region, owner, points, parentOfFrame)
	local placed = {}
	for _, p in ipairs(points or {}) do
		local base = parentOfFrame or owner
		local rel = Resolve(base, p.rel)
		placed[#placed + 1] = { p.point, rel, p.relPoint, p.x or 0, p.y or 0 }
		if region.SetPoint then pcall(region.SetPoint, region, p.point, rel, p.relPoint, p.x or 0, p.y or 0) end
	end
	rawset(region, "_partPoints", placed)
end

local Apply

local function MakePart(frame, part)
	local region
	if part.kind == "FontString" then
		region = frame:CreateFontString(Named(frame, part.name), part.layer or "OVERLAY", part.font)
	else
		region = frame:CreateTexture(Named(frame, part.name), part.layer or "ARTWORK")
	end
	rawset(region, "_part", part)
	if part.key then rawset(frame, part.key, region) end
	local name = Named(frame, part.name)
	if name and name ~= "" then _G[name] = region end
	if part.atlas and region.SetAtlas then pcall(region.SetAtlas, region, part.atlas, part.useAtlasSize) end
	if part.file and region.SetTexture then pcall(region.SetTexture, region, part.file) end
	if part.size and region.SetSize then pcall(region.SetSize, region, part.size[1] or 0, part.size[2] or 0) end
	if part.text and region.SetText then pcall(region.SetText, region, part.text) end
	if part.justifyH and region.SetJustifyH then pcall(region.SetJustifyH, region, part.justifyH) end
	if part.alpha and region.SetAlpha then pcall(region.SetAlpha, region, part.alpha) end
	if part.color and region.SetVertexColor then pcall(region.SetVertexColor, region, unpack(part.color)) end
	Place(region, frame, part.points)
	if part.setAllPoints and region.SetAllPoints then pcall(region.SetAllPoints, region, frame) end
	if part.hidden and region.Hide then region:Hide() end
	return region
end

function Apply(frame, recipe)
	if recipe.size and frame.SetSize then pcall(frame.SetSize, frame, recipe.size[1] or 0, recipe.size[2] or 0) end
	if recipe.bar and frame.SetStatusBarTexture then
		pcall(frame.SetStatusBarTexture, frame, recipe.bar.atlas or recipe.bar.file)
	end
	for _, part in ipairs(recipe.parts or {}) do MakePart(frame, part) end
	for _, child in ipairs(recipe.children or {}) do
		local made = oldCreate(child.kind or "Frame", Named(frame, child.name), frame)
		if child.parentKey then rawset(frame, child.parentKey, made) end
		Apply(made, child)
		Place(made, frame, child.points, frame)
		if child.hidden and made.Hide then made:Hide() end
	end
	local made = rawget(frame, "_templates") or {}
	made[#made + 1] = recipe.name
	rawset(frame, "_templates", made)
	for key, kv in pairs(recipe.keyValues or {}) do
		if rawget(frame, key) == nil then
			local v = kv.value
			if kv.type == "number" then v = tonumber(v) elseif kv.type == "boolean" then v = v == "true" end
			rawset(frame, key, v)
		end
	end
end

-- The parts of each named template (a comma list) on a frame; how many were known.
function M.Build(frame, template)
	local n = 0
	if type(template) ~= "string" or not recipes then return 0 end
	for name in template:gmatch("[^,%s]+") do
		local recipe = recipes[name]
		if recipe then
			Apply(frame, recipe)
			n = n + 1
		end
	end
	return n
end

function M.Use(client)
	if type(client) == "table" then
		recipes = client
	else
		local path = "Tools/engine/api/templates-" .. tostring(client) .. ".lua"
		local chunk = loadfile(path)
		if not chunk then
			return nil, path .. " missing: python -I Tools/engine/templates.py makes it from the game's code export"
		end
		recipes = chunk()
	end
	if not oldCreate then
		oldCreate = _G.CreateFrame
		_G.CreateFrame = function(kind, name, parent, template, ...)
			local frame = oldCreate(kind, name, parent, template, ...)
			if frame and type(template) == "string" then M.Build(frame, template) end
			return frame
		end
	end
	local count = 0
	for _ in pairs(recipes) do count = count + 1 end
	return count
end

function M.Stop()
	if oldCreate then _G.CreateFrame, oldCreate = oldCreate, nil end
	recipes = nil
end

function M.Recipe(name) return recipes and recipes[name] end

return M
