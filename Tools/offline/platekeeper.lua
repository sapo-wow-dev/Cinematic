-- The Plate parts keeper (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/platekeeper.lua <forever|retail>
-- Plates/PlateParts.lua put every faded part of every plate back to our alpha
-- each frame: ~17 parts a plate, 0.134 ms a frame at 15 plates (Tools/perf/
-- ledger.md 2026-11-23). Now only the parts the game fades itself (threat
-- glows; the cast bar where there's no CastBarsContainer) are put back each
-- frame; the rest every half second; and a plate gone lets go of its parts.
-- Checked: which parts are polled, the game's change to a threat glow undone
-- at the next frame, a change to another part undone by the half-second sweep
-- (and only then), a removed plate's parts back at the game's own alpha and
-- out of the lists, and the keeper hiding once nothing is held. PASS or FAIL.
-- luacheck: push ignore 111 112 113 121 122
local client = arg and arg[1] or "forever"
package.path = "Tools/offline/?.lua;" .. package.path
local wow = dofile("Tools/offline/wow.lua")
wow.Install(client)
local ns = {}
for line in io.lines("Cinematic.toc") do
	line = line:gsub("\r", "")
	if line ~= "" and not line:find("^#") then
		local chunk, loadErr = loadfile((line:gsub("\\", "/")))
		if not chunk then print("FAIL " .. line .. " doesn't compile: " .. tostring(loadErr)) end
		if chunk then
			local ok, err = pcall(chunk, "Cinematic", ns)
			if not ok then wow.Warn(line .. ": " .. tostring(err)) end
		end
	end
end
wow.Fire("ADDON_LOADED", "Cinematic")
wow.Fire("PLAYER_LOGIN")
local now = 100
GetTime = function() return now end
-- luacheck: pop

local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. text)
	if not ok then failed = failed + 1 end
end
local kept = ns.platePartsKept
Check(kept ~= nil and kept.Tick and kept.Fade and kept.LetGo and kept.Polled, "ns.platePartsKept found")
if not kept then return print("1 FAILED") end
ns.Reachable = function() return true end

-- A part frame: keeps its alpha.
local function Part(alpha)
	local f = { a = alpha or 1, shown = true }
	f.GetAlpha = function(self) return self.a end
	f.SetAlpha = function(self, a) self.a = a end
	f.Show, f.Hide = function(self) self.shown = true end, function(self) self.shown = false end
	f.IsShown = function(self) return self.shown end
	return f
end
local function UnitFrame(container)
	local u = { name = Part(), aggroHighlight = Part(), aggroHighlightBase = Part(), aggroHighlightAdditive = Part(),
		aggroFlash = Part(), HealthBarsContainer = Part(), RaidTargetFrame = Part(), WidgetContainer = Part() }
	if container then u.CastBarsContainer = Part() else u.castBar = Part() end
	return u
end
local function Count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
local function FadeAll(u, level)
	for _, part in ipairs(ns.PLATE_PARTS) do
		for _, frame in ipairs(ns.PlatePartFrames(u, part)) do
			kept.Fade(frame, level, kept.Polled(u, part))
		end
	end
end
local function Tick() kept.Tick(kept.keeper) end

-- Polled parts.
local u = UnitFrame(true)
Check(kept.Polled(u, "Threat") and not kept.Polled(u, "CastBar") and not kept.Polled(u, "Health")
	and not kept.Polled(u, "Name"), "polled: threat yes; container cast bar, health, name no")
Check(kept.Polled(UnitFrame(false), "CastBar"), "polled: the cast bar itself where there's no container")

FadeAll(u, 0.3)
local held, polled = Count(kept.held), Count(kept.polled)
Check(held >= 8 and polled == 4, ("one plate: %d parts held, %d polled (the 4 threat glows)"):format(held, polled))
Check(math.abs(u.HealthBarsContainer.a - 0.3) < 1e-6 and math.abs(u.aggroFlash.a - 0.3) < 1e-6, "faded to 0.3 at once")

-- The game changes a threat glow and the health bar's container.
Tick() -- (the first tick sweeps: sweepAt starts at 0)
now = now + 0.016
u.aggroFlash.a, u.HealthBarsContainer.a = 1, 1
Tick()
Check(math.abs(u.aggroFlash.a - 0.3) < 1e-6, "a threat glow the game set: ours again next frame")
Check(u.HealthBarsContainer.a == 1, "the health bar's container: left till the sweep")
now = now + 0.5
Tick()
Check(math.abs(u.HealthBarsContainer.a - 0.3) < 1e-6, "the health bar's container: ours again by the half-second sweep")

-- A second plate, then the first goes.
local v = UnitFrame(false)
FadeAll(v, 0.5)
Check(Count(kept.polled) == 9, ("two plates: %d polled (4 + 4 threat + 1 cast bar)"):format(Count(kept.polled)))
kept.LetGo(u)
local stillU = false
for frame in pairs(kept.held) do
	for _, f in pairs(u) do if f == frame then stillU = true end end
end
Check(not stillU, "a plate gone: none of its parts held")
Check(u.HealthBarsContainer.a == 1 and u.aggroFlash.a == 1 and u.name.a == 1, "a plate gone: its parts back at the game's own alpha")
Check(Count(kept.polled) == 5, ("a plate gone: %d polled left (the other plate's)"):format(Count(kept.polled)))

-- Back at full: let go; the keeper hides once nothing is held.
FadeAll(v, 1)
local hid = false
kept.keeper.Hide = function() hid = true end
Tick()
Check(Count(kept.held) == 0 and Count(kept.polled) == 0 and hid, "all at full: nothing held or polled, the keeper hidden")

-- Cost: a frame between sweeps walks only the polled parts.
for _ = 1, 15 do FadeAll(UnitFrame(true), 0.3) end
local walked = 0
local GetAlpha = Part().GetAlpha
for frame in pairs(kept.held) do
	frame.GetAlpha = function(self) walked = walked + 1 return GetAlpha(self) end
end
now = now + 0.01
Tick()
Check(walked == 60, ("15 plates, a frame between sweeps: %d parts looked at (the 60 threat glows, was every held one: %d)")
	:format(walked, Count(kept.held)))

print(failed == 0 and "ALL PASSED" or (failed .. " FAILED"))
