-- The red error text's alpha (Effects.lua's ns.UpdateCVars: Hide errors in
-- combat / out of combat), every state (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-errors-alpha.md):
--   python -I Tools/offline/run.py Tools/offline/errorsalphamatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/errorsalphamatrix.lua forever --base <ref>
-- Another addon (or the game) has the error frame at 0.5. The hide boxes on
-- or off; before that, our pass hid it or not; then our pass runs. Each cell:
-- the frame's alpha (0 hidden by us, 1 put back by us, 0.5 left as it was).
-- The rule (decided 2026-11-25): with the boxes off we write 1 back only if
-- we last set it to 0; otherwise we leave it alone.
local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db
local alpha = 1
-- luacheck: push ignore 111 112 113 121 122
UIErrorsFrame = UIErrorsFrame or CreateFrame("Frame", "UIErrorsFrame", UIParent)
-- luacheck: pop
rawset(UIErrorsFrame, "SetAlpha", function(_, a) alpha = a end)
rawset(UIErrorsFrame, "GetAlpha", function() return alpha end)

-- (Our pass, now: past its half-second wait.)
local function Pass()
	ns.cvarsSeen.at = -math.huge
	return pcall(ns.UpdateCVars, false)
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "errors-alpha",
	fixed = { client = client },
	dims = {
		{ "box", { "on", "off" } },
		{ "before", { "ours", "none" } },
	},
	cell = function(c)
		db.enabled, db.handleQuality = true, true
		-- (From the last cell: nothing of ours held.)
		db.hideErrorsInCombat, db.hideErrorsOutOfCombat = false, false
		alpha = 0
		Pass()
		alpha = 0.5 -- (another addon's)
		if c.before == "ours" then
			db.hideErrorsInCombat, db.hideErrorsOutOfCombat = true, true
			local ok, err = Pass()
			if not ok then return "error " .. tostring(err) end
			if alpha ~= 0 then return "not hidden: " .. tostring(alpha) end
		end
		db.hideErrorsInCombat, db.hideErrorsOutOfCombat = c.box == "on", c.box == "on"
		local ok, err = Pass()
		if not ok then return "error " .. tostring(err) end
		return "alpha=" .. tostring(alpha)
	end,
	pins = {
		{ "box=on", "alpha=0" },
		{ "box=off before=ours", "alpha=1" },
		{ "box=off before=none", "alpha=0.5" },
	},
})
