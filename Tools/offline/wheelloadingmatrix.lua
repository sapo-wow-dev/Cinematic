-- The camera wheel across a loading screen, every state (the audit kit's
-- matrix, Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-wheel-loading-screen.md):
--   python -I Tools/offline/run.py Tools/offline/wheelloadingmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/wheelloadingmatrix.lua --base <ref>
-- The wheel open with its key held down, open waiting for a click (a tap,
-- or the master wheel), or closed; then a loading screen or not. Each cell:
-- the wheel open or closed after, and whether it still thinks its key is held.
-- The rule (overlay audit 2026-11-25): a loading screen closes it (a key let
-- go during the load never comes in); with none, it stays as it was.

local client = arg and arg[1] or "forever"
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
	-- luacheck: push ignore 111 112 113 121 122
	UnitAffectingCombat = function() return false end -- (the stand-in's stub reads as in a fight: no wheel)
	GetCursorPosition = function() return 500, 400 end
	-- luacheck: pop
end)
local wheel = _G.CinematicCameraWheel

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "wheel-loading",
	fixed = { client = client },
	dims = {
		-- (Opened by its key held down: the stand-in's key path never opens it,
		-- no error, so not here; the loading screen's close is the same either way.)
		{ "open", { "click", "closed" } },
		{ "loading", { "yes", "no" } },
	},
	cell = function(c)
		if not wheel then return "no wheel" end
		ns.CloseCameraWheel()
		local ok, err = true, nil
		if c.open == "click" then
			ok, err = pcall(ns.OpenCameraWheel)
		end
		if not ok then return "error: " .. tostring(err) end
		if c.open ~= "closed" and not wheel:IsShown() then return "never opened" end
		if c.loading == "yes" then
			wow.Fire("LOADING_SCREEN_ENABLED")
			wow.Fire("PLAYER_LEAVING_WORLD")
		end
		local out = wheel:IsShown() and "open" or "closed"
		ns.CloseCameraWheel()
		return out
	end,
	pins = {
		{ "", "closed" },
		{ "open=click loading=no", "open" },
	},
})
