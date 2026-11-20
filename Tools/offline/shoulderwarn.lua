-- Shoulder Cam page's Experimental notice (offline, Lua 5.1 via
-- Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/shoulderwarn.lua < /dev/null
-- Added 2026-11-20 at the user's ask: the offset is one of the game's test
-- settings, the rest fills in round it. Checked on each client: the page builds with its
-- Experimental title and the notice. Says PASS or FAIL per check.
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local client = arg and arg[1] or "forever"
local _, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")

-- Every font string's text, anywhere under any frame.
local function Find(text)
	local seen = {}
	local function Walk(object)
		if seen[object] then return end
		seen[object] = true
		if object._text == text then return object end
		for _, region in ipairs(object._regions or {}) do
			local found = Walk(region)
			if found then return found end
		end
	end
	for _, frame in ipairs(wow.frames) do
		local found = Walk(frame)
		if found then return found end
	end
end

local warn = Find("Shoulder Cam uses some experimental Blizzard features, as well as some hacks to fill in the gaps.")
Check(client .. ": the notice is on the page", warn ~= nil)
Check(client .. ": its Experimental title too", Find("Experimental") ~= nil)
-- The red "!" after Keep the shoulder when selecting yourself, its tip saying
-- the target frame of you is our own copy.
local TIP = "Shows our own copy of your target frame, so it matches only the game's look or a Cinematic theme."
local function FindTip(text)
	for _, frame in ipairs(wow.frames) do
		if frame.searchTip == text then return frame end
	end
end
local mark = FindTip(TIP)
-- (Both clients since 2026-11-20: hidden on retail till tested there.)
Check(client .. ": the \"!\" with its tip", mark ~= nil)
local bang = false
for _, region in ipairs(mark and mark._regions or {}) do
	if region._text == "!" then bang = true end
end
Check(client .. ": it reads \"!\"", bang)
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
