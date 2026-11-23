-- A unit frame part a Hover group holds hidden, around its frame being let
-- go, every state (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-22-frames-held-parts-letgo.md):
--   python -I Tools/offline/run.py Tools/offline/heldpartsmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/heldpartsmatrix.lua --base <ref>
-- The player frame up for a Hover group alone, the group with its Portrait
-- unticked (holds) or not (none); the portrait's own Standard Frames row
-- ticked (on) or not (off); the frame up or fading out; then let go (its fade
-- switch off: ns.StopFading) or not. Each cell: the portrait shown or hidden.
-- The rule: a group holds the part only while it holds the frame; let go, the
-- part is as its own row says. (7c3e0c1: only the pass over managed frames
-- let go of the hold, so a portrait held as its frame was let go stayed
-- hidden till a reload.)

local client = arg and arg[1] or "forever"
local portrait
local function Install(wow)
	-- (A real player frame with its portrait, at the paths the parts list reads.)
	local frame = wow.CreateFrame("Frame", "PlayerFrame", UIParent)
	local container = wow.CreateFrame("Frame", nil, frame)
	rawset(frame, "PlayerFrameContainer", container)
	portrait = frame:CreateTexture()
	portrait._alpha = 1
	rawset(portrait, "SetAlpha", function(self, alpha) self._alpha = alpha end)
	rawset(portrait, "GetAlpha", function(self) return self._alpha end)
	rawset(container, "PlayerPortrait", portrait)
	rawset(_G, "PlayerPortrait", portrait)
end
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
ns.db.enabled = true
ns.db.handleFrames = true -- (the HUD page on: its Unit frames rows count)

-- (FRAMES: HoldUnitParts' upvalue, where a group's unticked parts are kept.)
local FRAMES
for i = 1, 20 do
	local name, value = debug.getupvalue(ns.HoldUnitParts, i)
	if not name then break end
	if name == "FRAMES" then FRAMES = value end
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "unitparts-letgo",
	fixed = { client = client },
	dims = {
		{ "group", { "holds", "none" } },
		{ "row", { "on", "off" } },
		{ "frame", { "up", "fading" } },
		{ "letgo", { "yes", "no" } },
	},
	cell = function(c)
		if not FRAMES then return "no FRAMES" end
		local frame = _G.PlayerFrame
		ns.db.ignoredFrames.PlayerFrame = nil
		ns.db.unitPartPlayerPortrait = c.row == "on"
		FRAMES.off.PlayerFrame = c.group == "holds" and { Portrait = true } or nil
		local entry = { frame = frame, name = "PlayerFrame", baseAlpha = 1, alpha = 1 }
		table.insert(ns.managed, entry)
		ns.HoldUnitParts("PlayerFrame", true)
		if c.frame == "fading" then ns.HoldUnitParts("PlayerFrame", false, true) end
		ns.ApplyUnitFrameParts()
		if c.letgo == "yes" then ns.StopFading("PlayerFrame") end
		local out = (ns.unitPartsHidden[portrait] or portrait._alpha < 0.5) and "hidden" or "shown"
		-- (Clean for the next cell: no group, the row ticked, the frame out.)
		for i = #ns.managed, 1, -1 do
			if ns.managed[i] == entry then table.remove(ns.managed, i) end
		end
		FRAMES.off.PlayerFrame, FRAMES.held.PlayerFrame = nil, nil
		ns.db.unitPartPlayerPortrait = true
		ns.ApplyUnitFrameParts()
		return out
	end,
	pins = {
		{ "", "shown" },
		-- (Held by the group while it holds the frame, up or fading out.)
		{ "group=holds letgo=no", "hidden" },
		-- (Its own row unticked: hidden, managed or let go.)
		{ "row=off", "hidden" },
	},
})
