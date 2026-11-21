-- Style General's preview anchor loop (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/previewloop.lua <forever|retail> < /dev/null
-- A theme's drawn frame hangs the preview Player's portrait off its health bar
-- (UnitFrameParts MeasuredBody); drawn again, the health bar was pinned to that
-- portrait before it was freed: "Cannot anchor to a region dependent on it"
-- (Forever 2026-11-21, UnitStyle.lua DressUnit). Checks, per redraw:
--   the measured portrait really hangs off the health bar after a draw;
--   no unit's portrait hangs on its health bar when the bar is pinned
--   (ns.PreviewAnchorCheck's count stays 0).
-- Says PASS or FAIL per check; exits 1 on any FAIL.
local F = dofile("Tools/style-lab/frames.lua")
local client = ... or "forever"

-- luacheck: push ignore 111 112 113 121 122 212
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function(w)
	F.Install(w)
	rawset(_G, "CreateFontFamily", false)
end)
-- luacheck: pop

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print(("%s %s: %s%s"):format(ok and "PASS" or "FAIL", client, name, detail and (" (" .. tostring(detail) .. ")") or ""))
end

-- (A measured look for the Player frame: its portrait spot, as a theme's live frame gives.)
ns.UnitHangs = function(id)
	if id ~= "PLAYER" then return nil end
	return { portrait = { x = -0.4, y = -0.1, w = 0.35, h = 0.35 } }
end

if ns.MakeLazyPages then ns.MakeLazyPages("previewloop test") end
ns.OpenOptions("Style General")
if ns.ShowHubPage then ns.ShowHubPage("Style General") end
local preview = ns.generalStylePreview
Check("Style General has its preview", preview ~= nil)
if not preview then os.exit(1) end
local up = preview
while up and up ~= UIParent do
	up:Show()
	if up:GetNumPoints() == 0 and up:GetParent() then
		up:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
		if (up:GetWidth() or 0) <= 0 then up:SetSize(800, 2000) end
	end
	up = up:GetParent()
end

-- (The unit frames' scene among the rotating ones: the one with a Player.)
local scene
local function FindScene(frame)
	if scene then return end
	if frame.units and frame.units.PLAYER and frame.Refresh then scene = frame return end
	for _, child in ipairs({ frame:GetChildren() }) do FindScene(child) end
end
FindScene(preview)
local player = scene and scene.units.PLAYER
if scene then scene:Show() end
Check("the preview has a Player", player ~= nil)
if not player then os.exit(1) end

local function HangsOnHealth()
	for i = 1, player.portrait:GetNumPoints() do
		local _, relative = player.portrait:GetPoint(i)
		if relative == player.health then return true end
	end
	return false
end

ns.previewLoops = 0
for round = 1, 3 do
	local ok, err = pcall(scene.Refresh, scene)
	Check(("draw %d: no error"):format(round), ok, err)
	Check(("draw %d: the measured portrait hangs off the health bar"):format(round),
		player.portraitMeasured == true and HangsOnHealth())
end
Check("no portrait hung on its health bar when the bar was pinned", ns.previewLoops == 0, ns.previewLoops)

-- /cine debug previewloop (Dev/PreviewLoopTest.lua, a test kit test) on the
-- stand-in, pretend time: it opens the page, clicks the tabs, no loop seen.
-- luacheck: push ignore 121 122
do
	local now, timers, tickers = 100, {}, {}
	GetTime = function() return now end
	C_Timer.After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end
	C_Timer.NewTicker = function(every, fn)
		local t = { every = every, next = now + every, fn = fn, Cancel = function(self) self.cancelled = true end }
		tickers[#tickers + 1] = t
		return t
	end
	Screenshot = function() end
	ns.PadTestBox, ns.PadTestBoxHide = function() end, function() end
	ns.HandleSlash("debug previewloop")
	for _ = 1, 400 do
		now = now + 0.1
		local due = {}
		for i = #timers, 1, -1 do if timers[i].at <= now then due[#due + 1] = table.remove(timers, i) end end
		for i = #due, 1, -1 do due[i].fn() end
		for _, t in ipairs(tickers) do
			if not t.cancelled and t.next <= now then t.next = now + t.every t.fn(t) end
		end
	end
	local done
	for _, line in ipairs(CinematicDB.previewLoopTestLog or {}) do
		if line:find("DONE: ", 1, true) or line:find("STOPPED: ", 1, true) then done = line end
	end
	for _, line in ipairs(CinematicDB.previewLoopTestLog or {}) do
		if line:find("verdict FAIL", 1, true) then print("  " .. line) end
	end
	Check("/cine debug previewloop: DONE, 9 pass, 0 fail", done and done:find("9 pass, 0 fail", 1, true) ~= nil, done)
end
-- luacheck: pop

if fails > 0 then
	print(("%d FAIL"):format(fails))
	os.exit(1)
end
print("all PASS")
