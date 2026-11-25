-- An NPC's line with Chat Cam off (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-cameras-chat-cam-off.md):
--   python -I Tools/offline/run.py Tools/offline/chatcamoffmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/chatcamoffmatrix.lua forever --base <ref>
-- An NPC says a line (CHAT_MSG_MONSTER_SAY). Chat Cam's row set to it or to no
-- camera, Enable Cameras on or off (turned off here), and the Chat scene
-- playing as its script with Ultra immersive's subtitles or not. Each cell:
-- whether the line waits for its bubble (ns.WhenBubble: a per-frame bubble
-- scan for half a second) to be looked at.
-- The rule: only Chat Cam on here, or its script scene showing subtitles,
-- waits for a bubble; otherwise the line costs nothing.
local client = arg and arg[1] or "forever"
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db
db.enabled = true
-- (Its rows' When: Always, so it's on here.)
for _, key in ipairs({ "Chat", "ChatNearby" }) do
	for _, id in ipairs(ns.TriggerRowIds(key)) do db.cameraRows[id .. ".always"] = true end
end
local waits = 0
ns.WhenBubble = function() waits = waits + 1 end
local running = false
ns.CameraScriptRunning = function(key) return running and key == "Chat" end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "chat-cam-off",
	fixed = { client = client },
	dims = {
		{ "row", { "chat", "none" } },
		{ "cameras", { "on", "off" } },
		{ "script", { "subtitles", "no" } },
	},
	cell = function(c)
		db.chatCamera, db.chatNearbyCamera = c.row, c.row
		for _, key in ipairs({ "Chat", "ChatNearby" }) do ns.SetCameraRowOn(ns.TriggerRowIds(key)[1], c.row == "chat") end
		db.cameraModes = c.cameras == "on"
		running = c.script == "subtitles"
		db.chatCamImmersive = c.script == "subtitles"
		ns.CameraRowsChanged()
		waits = 0
		wow.Fire("CHAT_MSG_MONSTER_SAY", "Hello there.", "Guard")
		return waits > 0 and "waits" or "no wait"
	end,
	pins = {
		{ "", "no wait" },
		{ "row=chat cameras=on", "waits" },
		{ "script=subtitles", "waits" },
	},
})
