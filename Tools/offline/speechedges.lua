-- The lines from behind you find their spot with the chat window unplaced
-- (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/speechedges.lua [forever|retail] < /dev/null
-- UI/Speech.lua's spot goes beside the main chat window, by its edges. A
-- window with no place yet gives nil for its left (or right, or top): the
-- old check (an ipairs over the three) stopped at the first nil and let it
-- through, then errored on it (Speech.lua:351, the in-game gating test
-- 2026-11-25). Each edge nil in turn, and all readable: no error, a spot.
-- Says PASS or FAIL per check.
local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
ns.db.speechBehindX, ns.db.speechBehindY = nil, nil
local failed = 0
local chat = _G.ChatFrame1
for _, missing in ipairs({ "none", "left", "right", "top" }) do
	local edges = { left = 10, right = 400, top = 300 }
	if missing ~= "none" then edges[missing] = nil end
	rawset(chat, "GetLeft", function() return edges.left end)
	rawset(chat, "GetRight", function() return edges.right end)
	rawset(chat, "GetTop", function() return edges.top end)
	local ok, left, bottom = pcall(ns.SpeechBehindSpot)
	local good = ok and type(left) == "number" and type(bottom) == "number"
	print(("%s chat window's %s nil: a spot, no error (%s)"):format(good and "PASS" or "FAIL",
		missing == "none" and "nothing" or missing, ok and ("%s, %s"):format(tostring(left), tostring(bottom)) or tostring(left)))
	if not good then failed = failed + 1 end
end
print(failed == 0 and "ALL PASS" or ("%d FAIL"):format(failed))
