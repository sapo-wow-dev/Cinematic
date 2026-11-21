-- The target's and focus's buffs on top, kept off a Style theme's name plate.
-- A theme (Neon Coast...) draws its own plate behind the name, a little taller
-- than the game's name strip, and with Edit Mode's Buffs On Top the game's buff
-- row sat on it (Discord report 2026-11-21). The row is lifted by what the
-- plate reaches over the game's strip.
--   * The row's place can't be read on WoW Forever (rule forever.targetframe.
--     aura-container-place-secret), so nothing here reads it: the lift is
--     worked out from our plate and the game's strip, both readable.
--   * It's moved by AdjustPointsOffset after the game places it (a hook on its
--     SetPoint, rule forever.region.adjustpointsoffset-secret): the engine sums
--     the secret. A ClearAllPoints or SetPoint from the game starts it over.
--   * Forever: one container (GetAuraContainer). Retail: each aura button not
--     hung on another aura of the frame (the start of each row).
-- Called from UnitStyle.lua each time it lays out a frame's plate.
local _, ns = ...

local GAP = 1 -- (room between the plate's top and the row, in the frame's units)
local MAX_LIFT = 20 -- (the plate's 16 high name row and its edges: more is a misread)

local lifts = setmetatable({}, { __mode = "k" })   -- frame -> its lift now (frame units)
local plates = setmetatable({}, { __mode = "k" })  -- frame -> its theme plate
local lifted = setmetatable({}, { __mode = "k" })  -- moved region -> what's on it now (its units)
local hooked = setmetatable({}, { __mode = "k" })  -- region -> its frame
local framesHooked = setmetatable({}, { __mode = "k" })

local function Readable(v)
	return v ~= nil and not (issecretvalue and issecretvalue(v))
end

-- The game's name strip (what its buff row is laid out to clear).
local function Strip(frame)
	local content = frame.TargetFrameContent
	local main = content and content.TargetFrameContentMain
	local name = frame.GetName and frame:GetName()
	return (main and main.ReputationColor) or (name and _G[name .. "NameBackground"])
		or (main and main.Name) or frame.name
end

-- The plate's highest shown edge (its corner art reaches over its frame).
local function PlateTop(plate)
	local top = plate:GetTop()
	if not Readable(top) then return nil end
	for _, region in ipairs({ plate:GetRegions() }) do
		local ok, shown, t = pcall(function() return region:IsShown(), region:GetTop() end)
		if ok and Readable(shown) and shown and Readable(t) and t > top then top = t end
	end
	return top * plate:GetEffectiveScale()
end

-- What to lift by, in the frame's units: 0 with buffs under it or no plate.
local function Need(frame)
	local plate = plates[frame]
	if not (frame.buffsOnTop == true and plate and plate:IsShown()) then return 0 end
	local strip = Strip(frame)
	local top = PlateTop(plate)
	local stripTop = strip and strip.GetTop and strip:GetTop()
	if not (top and Readable(stripTop)) then return lifts[frame] or 0 end -- (unread: as it was)
	-- (Only a strip inside the frame counts: one read off something else gave
	-- a lift of hundreds offline. And never more than the plate is tall.)
	local frameTop, frameBottom = frame:GetTop(), frame:GetBottom()
	local stripPx, scale = stripTop * strip:GetEffectiveScale(), frame:GetEffectiveScale()
	if not (Readable(frameTop) and Readable(frameBottom)) or stripPx > frameTop * scale + 0.5
		or stripPx < frameBottom * scale - 0.5 then
		return lifts[frame] or 0
	end
	local over = (top - stripPx) / scale
	if over <= 0 then return 0 end
	return math.min(over + GAP, MAX_LIFT)
end

-- The regions the game places for the row.
local function Rows(frame)
	local list = {}
	local ok, container = pcall(function() return frame.GetAuraContainer and frame:GetAuraContainer() end)
	if ok and type(container) == "table" and container.AdjustPointsOffset then
		list[1] = container
		return list
	end
	local pools = frame.auraPools
	if not (pools and pools.EnumerateActive) then return list end
	local auras = {}
	for aura in pools:EnumerateActive() do auras[aura] = true end
	for aura in pairs(auras) do
		local okP, _, rel = pcall(aura.GetPoint, aura, 1)
		if okP and not (Readable(rel) and auras[rel]) then list[#list + 1] = aura end
	end
	return list
end

-- One region to the frame's lift: by the difference from what's on it.
local function Lift(region, frame)
	local okS, ratio = pcall(function() return frame:GetEffectiveScale() / region:GetEffectiveScale() end)
	if not (okS and Readable(ratio) and ratio > 0) then return end
	local want = (lifts[frame] or 0) * ratio
	local delta = want - (lifted[region] or 0)
	if math.abs(delta) < 0.01 then return end
	-- (Two anchors: AdjustPointsOffset moves both, and one may be the game's
	-- fresh one, the other ours already: left alone rather than doubled.)
	local okN, points = pcall(region.GetNumPoints, region)
	if okN and Readable(points) and points > 1 then return end
	local ok = pcall(region.AdjustPointsOffset, region, 0, delta)
	if ok then lifted[region] = want end
end

local function Hook(region, frame)
	if hooked[region] then hooked[region] = frame return end
	hooked[region] = frame
	hooksecurefunc(region, "ClearAllPoints", function(self) lifted[self] = nil end)
	hooksecurefunc(region, "SetPoint", function(self)
		lifted[self] = nil
		local owner = hooked[self]
		if owner and (lifts[owner] or 0) ~= 0 then Lift(self, owner) end
	end)
end

local function Apply(frame)
	lifts[frame] = Need(frame)
	for _, region in ipairs(Rows(frame)) do
		Hook(region, frame)
		Lift(region, frame)
	end
end

-- From UnitStyle.lua's plate layout: frame, its plate (nil or hidden: no lift).
function ns.UnitAuraLift(frame, plate)
	if frame ~= _G.TargetFrame and frame ~= _G.FocusFrame then return end
	plates[frame] = plate
	if not framesHooked[frame] and type(frame.UpdateAuras) == "function" then
		framesHooked[frame] = true
		-- (Auras come and go, and Buffs On Top flips: the row again after the game's layout.)
		hooksecurefunc(frame, "UpdateAuras", function(self) Apply(self) end)
	end
	Apply(frame)
end

-- For the dev copy's test (Dev/AuraPlateTest.lua): the lift now, in frame units.
function ns.UnitAuraLiftNow(frame)
	return lifts[frame] or 0, frame and Need(frame)
end
