-- The style editor's Undo and Redo across a profile switch, load or reset, and a
-- style demo put back (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-25-style-undo-profile.md):
--   python -I Tools/offline/run.py Tools/offline/styleundoprofilematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/styleundoprofilematrix.lua forever --base <ref>
-- The editor keeps one Undo history a session (Style/Studio/Editor.lua). A profile
-- switch (ns.SetProfile) loads other settings with no reload: Undo then wrote the
-- profile left's value into the new one. The states: what happened after a change
-- (nothing, a profile switch, Reset profile, a style demo stopped: the change made
-- while it ran), and Undo or Redo pressed after it. Each cell: whether the editor
-- still had the step, and whether pressing it changed the setting. The rule (Audit
-- 2026-11-25): another profile's settings (or yours put back over a demo) start a
-- new history: nothing to undo or redo, the setting left as loaded.

local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local Studio = ns.Studio
ns.SwitchProfileLayout = function() end -- (the stand-in has no Edit Mode)
-- (What a switch refreshes after it loads: not what this reads.)
for _, name in ipairs({ "RefreshOptions", "BuildManagedList", "RestartTimers", "RefreshTint", "ApplyBubbles",
	"ApplyUnitFrameParts", "RefreshActionBarStyle", "RefreshMinimapStyle", "RefreshQuestTrackerStyle",
	"RefreshInterfaceRecolor", "ApplyShoulderCam", "ApplyWheelSwitches", "ApplyFrameLinks",
	"SplitAddonRows", "BackupProfile" }) do
	if ns[name] then ns[name] = function() end end
end
local KEY = "othersMarkSize" -- (a Nameplate Style slider, Smart rows' mark size)
local f = Studio.frames.plates

local n = 0
local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "style-undo-profile",
	fixed = { client = client },
	dims = {
		{ "after", { "nothing", "switch", "reset", "demo" } },
		{ "press", { "undo", "redo" } },
	},
	cell = function(c)
		n = n + 1
		-- (Values no profile holds: a cell's own, never one an earlier cell saved.)
		local was, now = 0.5 + n * 0.02, 0.51 + n * 0.02
		local active = ns.ActiveProfile()
		local other = active == "Subtle" and "Balanced" or "Subtle"
		while Studio.Undo() do end
		while Studio.CanRedo() do Studio.Redo() end
		ns.db[KEY] = was
		if c.after == "demo" then ns.StyleDemo("themes") end
		Studio.Apply(f, "test", { { KEY, now } })
		if c.press == "redo" then Studio.Undo() end
		if c.after == "switch" then ns.SetProfile(other)
		elseif c.after == "reset" then ns.ResetProfile()
		elseif c.after == "demo" then ns.StyleDemo(nil) end
		local loaded = ns.db[KEY]
		local has = c.press == "undo" and Studio.CanUndo() or c.press == "redo" and Studio.CanRedo()
		if c.press == "undo" then Studio.Undo() else Studio.Redo() end
		return ("history=%s value=%s"):format(has and "kept" or "cleared", ns.db[KEY] == loaded and "kept" or "changed")
	end,
	pins = {
		{ "", "history=cleared value=kept" },
		{ "after=nothing", "history=kept value=changed" },
	},
})
