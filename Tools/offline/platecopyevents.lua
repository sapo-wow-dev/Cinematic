-- The preview's game plate keeps none of its template's events (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/platecopyevents.lua < /dev/null
-- Known error game-nameplate-template-events (Tools/errors/known.lua): a
-- NamePlateUnitFrameTemplate copy left with the events its OnLoad registered
-- ran CompactUnitFrame_OnEvent with no unit on every target change and erred
-- in UnitWidgetSet (CompactUnitFrame.lua:1557, Forever 2026-11-23). Here the
-- template's OnLoad is stood in for (the plate's events on the copy and its
-- cast bar, an OnEvent that makes the game's call), then:
--   1. a copy made by hand and left as it is errs on PLAYER_TARGET_CHANGED,
--      as in game (the stand-in shows the error);
--   2. Plates/PlateCopy.lua's ns.MakeGamePlate + ns.GamePlateReady give a copy with no events
--      and no OnEvent, on it or its children, the cast bar's OnUpdate kept,
--      and target / soft-target changes raise nothing.
-- Uses Tools/offline/gameplate_parts.lua (the template's parts) as is.
-- luacheck: ignore 111 112 113 121 122 212 431
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail ~= nil and (" (" .. tostring(detail) .. ")") or ""))
end

local EVENTS = { "PLAYER_TARGET_CHANGED", "PLAYER_SOFT_ENEMY_CHANGED", "PLAYER_SOFT_FRIEND_CHANGED", "UNIT_AURA" }
local parts = dofile("Tools/offline/gameplate_parts.lua")(function() end)
local wow
local ns = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", function(w)
	wow = w
	issecretvalue = function() return false end
	parts.Install()
	-- (The template's OnLoad, stood in for: its events on the copy and its cast
	-- bar, and the game's handler, which reads the unit.)
	local made = CreateFrame
	CreateFrame = function(kind, name, parent, template, ...)
		local frame = made(kind, name, parent, template, ...)
		if template == "NamePlateUnitFrameTemplate" then
			local castBar = frame.CastBarsContainer and frame.CastBarsContainer.castBar
			for _, f in ipairs({ frame, castBar }) do
				if type(f) == "table" and f.RegisterEvent then
					for _, event in ipairs(EVENTS) do f:RegisterEvent(event) end
					f:SetScript("OnEvent", function(self)
						if self.unit == nil then
							error("CompactUnitFrame.lua:1557: bad argument #1 to 'UnitWidgetSet' (Usage: local uiWidgetSet = UnitWidgetSet(unit))")
						end
					end)
				end
			end
			if castBar and castBar.SetScript then castBar:SetScript("OnUpdate", function() end) end
		end
		return frame
	end
end)

local function Errors()
	local n = 0
	for _, w in ipairs(wow.warnings) do if w:find("UnitWidgetSet", 1, true) then n = n + 1 end end
	return n
end

-- 1. The error as in game: a copy left with its events.
local left = CreateFrame("Button", nil, UIParent, "NamePlateUnitFrameTemplate")
local before = Errors()
wow.Fire("PLAYER_TARGET_CHANGED")
Check("a copy left with its events errs in UnitWidgetSet on a target change (the stand-in shows it)",
	Errors() > before, Errors() - before)
-- (Cleaned up by hand, cast bar too, so it doesn't count below.)
for _, f in ipairs({ left, left.CastBarsContainer and left.CastBarsContainer.castBar }) do
	if f then
		f:UnregisterAllEvents()
		f:SetScript("OnEvent", nil)
	end
end

-- 2. The preview's game plate.
-- (Since 2026-11-23 the copy is built on the preview's first draw,
-- ns.GamePlateReady, and kept as plate.gameCopy. Read with rawget: the
-- stand-in hands back a stub for a missing capitalized field.)
local plate = ns.MakeGamePlate(UIParent)
local ready = plate and ns.GamePlateReady and ns.GamePlateReady(plate)
local copy = plate and rawget(plate, "gameCopy")
Check("the game plate is made (not the drawn fallback)", ready and type(copy) == "table" and rawget(copy, "_kind") ~= nil,
	ns.gamePlateWhy and next(ns.gamePlateWhy))
if copy and rawget(copy, "_kind") then
	local castBar = copy.CastBarsContainer and copy.CastBarsContainer.castBar
	local function Clean(frame)
		local events = rawget(frame, "_events") or {}
		return next(events) == nil and frame:GetScript("OnEvent") == nil
	end
	local all, dirty, seen = 0, {}, {}
	local function Walk(frame)
		-- (Real stand-in frames only, each once.)
		if type(frame) ~= "table" or not rawget(frame, "_kind") or seen[frame] then return end
		seen[frame] = true
		all = all + 1
		if not Clean(frame) then dirty[#dirty + 1] = tostring(frame:GetName() or frame:GetObjectType()) end
		for _, kid in ipairs({ frame:GetChildren() }) do Walk(kid) end
	end
	Walk(copy)
	Check("no events and no OnEvent on the copy or any child", #dirty == 0, ("%d of %d left: %s"):format(#dirty, all,
		table.concat(dirty, ", ")))
	Check("its cast bar keeps the OnUpdate that plays the pretend cast", castBar and castBar:GetScript("OnUpdate") ~= nil)
	before = Errors()
	for _, event in ipairs(EVENTS) do wow.Fire(event, "target") end
	Check("target and soft-target changes raise nothing", Errors() == before, Errors() - before)
end

print(fails == 0 and "all passed" or (fails .. " failed"))
if fails > 0 then os.exit(1) end
