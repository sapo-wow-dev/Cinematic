-- The edge haze's update loop (Atmosphere/Focus.lua), every state (the audit
-- kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-23-focus-haze-loop.md):
--   python -I Tools/offline/run.py Tools/offline/focusloopmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/focusloopmatrix.lua --base <ref>
-- Haze strength (dofScale) 0 or up, a camera script of your own with an Edge
-- haze running or not, CineMode on or off, the Haze switch (depthOfField) on
-- or off, its Show in row saying yes or no (Core's effectWanted.haze), and a
-- demo or preview (/cine doftest, a slider moved) showing or not. Each cell:
-- whether the loop runs (every frame) and whether the haze draws (after 4 s).
-- The rule (release review 2026-11-23): the loop runs only while there's a
-- haze to draw: in CineMode with the switch on and Haze strength up or a
-- script's Edge haze, or a demo or preview. At Haze strength 0 (the default)
-- it ran every frame in CineMode drawing nothing. What draws doesn't change.
local client = arg and arg[1] or "forever"
local now = 100
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
	-- luacheck: push ignore 111 112 113 121 122
	GetTime = function() return now end
	-- luacheck: pop
end)
local frame = _G.CinematicFocus

local function Run(seconds)
	for _ = 1, seconds * 10 do
		now = now + 0.1
		local update = frame:GetScript("OnUpdate")
		if update then update(frame, 0.1) end
	end
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "focus-haze-loop",
	fixed = { client = client },
	dims = {
		{ "strength", { "zero", "up" } },
		{ "script", { "none", "haze" } },
		{ "cine", { "on", "off" } },
		{ "dof", { "on", "off" } },
		{ "row", { "yes", "no" } },
		{ "demo", { "none", "showing" } },
	},
	cell = function(c)
		local db = ns.db
		db.enabled, db.visualEffects = true, true
		ns.effectWanted = ns.effectWanted or {}
		-- (Nothing left over from the cell before: faded out with it all off.)
		ns.FocusDemoStop()
		db.depthOfField = false
		ns.CameraScriptHaze = function() return nil end
		ns.WakeFeatureLoop(frame)
		Run(3)
		ns.SyncFeatureLoops()

		db.dofScale = c.strength == "up" and 0.5 or 0
		db.depthOfField = c.dof == "on"
		ns.lastCinematic = c.cine == "on" or nil
		ns.effectWanted.haze = c.row == "yes"
		ns.CameraScriptHaze = function() return c.script == "haze" and 0.4 or nil end
		if c.demo == "showing" then ns.FocusDemo(30, 0.3) end
		ns.SyncFeatureLoops() -- (the once-a-second gate)
		local loop = frame:GetScript("OnUpdate") ~= nil
		Run(4)
		local draws = ns.FocusAlphaNow() > 0
		ns.FocusDemoStop()
		return ("loop=%s draws=%s"):format(loop and "on" or "off", draws and "yes" or "no")
	end,
	pins = {
		{ "", "loop=off draws=no" },
		-- (In CineMode with the switch on and a haze: the loop where its row says,
		-- and drawn. Off the row, no loop: Audit 2026-11-25, OK'd by the user,
		-- was loop=on draws=no.)
		{ "strength=up cine=on dof=on", "loop=off draws=no" },
		{ "script=haze cine=on dof=on", "loop=off draws=no" },
		{ "strength=up cine=on dof=on row=yes", "loop=on draws=yes" },
		{ "script=haze cine=on dof=on row=yes", "loop=on draws=yes" },
		-- (A demo or preview: shown whatever the switches say.)
		{ "demo=showing", "loop=on draws=yes" },
	},
})
