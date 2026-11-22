-- Settings pages made on first open (Options.lua's lazyPages, Tools/lazy-pages-plan.md phase 1), on the
-- stand-in, both clients:
--   search: typing in the main search box with pages still waiting shows "Searching...", makes them a few
--           at a time over frames (never all in the first frame), then shows the matches; the same matches
--           as with every page made first.
--   hub:    a hub's General switch off and on again (UI Manager, Visions) makes only that hub's waiting
--           pages, and leaves every page switch as it does with every page made first.
--
--   python -I Tools/offline/run.py Tools/offline/lazysearch.lua
-- Exit 1 on any problem.
-- luacheck: push ignore 111 112 113 121 122 212 431
local LUA = os.getenv("CINE_LUA") or "lua5.1"
local phase, client = ...

local function Load(which)
	local clock = 0
	local ns, wow = dofile("Tools/offline/load.lua")(which, "Cinematic.toc")
	-- (Time moves 0.4 ms a call: builds stop at their budget and go on next frame.)
	debugprofilestop = function() clock = clock + 0.4 return clock end
	-- (Only the frames whose update loop started after Mark(): the build's own, not the whole addon's.)
	local before, list, sinceScan = {}, {}, 0
	local function Mark()
		before = {}
		for _, frame in ipairs(wow.frames) do
			local scripts = rawget(frame, "_scripts")
			before[frame] = scripts and scripts.OnUpdate or false
		end
		sinceScan = 999
	end
	local function Tick()
		sinceScan = sinceScan + 1
		if sinceScan > 25 then
			sinceScan, list = 0, {}
			for _, frame in ipairs(wow.frames) do
				local scripts = rawget(frame, "_scripts")
				local fn = scripts and scripts.OnUpdate
				if fn and before[frame] ~= fn then list[#list + 1] = frame end
			end
		end
		for _, frame in ipairs(list) do
			local fn = frame._scripts.OnUpdate
			if fn then pcall(fn, frame, 0.016) end
		end
	end
	return ns, wow, Tick, Mark
end

local function Texts(wow, pattern)
	local found = {}
	for _, frame in ipairs(wow.frames) do
		for _, region in ipairs(rawget(frame, "_regions") or {}) do
			local text = rawget(region, "_text")
			if type(text) == "string" and text:find(pattern) and region._parent and region._parent._shown then
				found[#found + 1] = text
			end
		end
	end
	return found
end

local function Waiting(ns)
	local n = 0
	for _, entry in ipairs(ns.lazySettingsPages or {}) do if not entry.made then n = n + 1 end end
	return n
end

-- One phase in its own Lua state: prints "key=value" lines.
if phase then
	local ns, wow, Tick, Mark = Load(client)
	if phase == "search" or phase == "searchAll" then
		if phase == "searchAll" then ns.MakeLazyPages("test") end
		local box = ns.mainSearchBox
		print("box=" .. tostring(box ~= nil))
		local waitingBefore = Waiting(ns)
		print("waitingBefore=" .. waitingBefore)
		Mark()
		box:SetText("nameplate")
		box._scripts.OnTextChanged(box)
		print("searchingShown=" .. #Texts(wow, "Searching%.%.%."))
		print("waitingAfterFirst=" .. Waiting(ns))
		local ticks = 0
		while ticks < 20000 do
			Tick()
			ticks = ticks + 1
			if Waiting(ns) == 0 and ticks % 10 == 0 and #Texts(wow, "Searching%.%.%.") == 0 then break end
		end
		print("ticks=" .. ticks)
		print("waitingEnd=" .. Waiting(ns))
		print("searchingEnd=" .. #Texts(wow, "Searching%.%.%."))
		local matches = Texts(wow, "|cffffd100.-:|r")
		table.sort(matches)
		print("matches=" .. #matches)
		print("matchList=" .. table.concat(matches, " ; "))
		for _, line in ipairs(CinematicDB.log or {}) do
			if type(line) == "string" and (line:find("error") or line:find("ERROR")) then print("logError=" .. line:sub(1, 300)) end
		end
	elseif phase == "hub" or phase == "hubAll" then
		if phase == "hubAll" then ns.MakeLazyPages("test") end
		local db = ns.GetDB()
		local made = {}
		for _, hub in ipairs({ { "UI Manager", "handleFrames" }, { "Visions", "visionsAll" } }) do
			local before = {}
			for _, entry in ipairs(ns.lazySettingsPages or {}) do before[entry] = entry.made end
			ns.CascadeHub(hub[1], hub[2], false)
			ns.CascadeHub(hub[1], hub[2], true)
			for _, entry in ipairs(ns.lazySettingsPages or {}) do
				if entry.made and not before[entry] then made[#made + 1] = hub[1] .. ">" .. tostring(entry.name) end
			end
		end
		table.sort(made)
		print("made=" .. table.concat(made, ","))
		print("waitingEnd=" .. Waiting(ns))
		local keys = {}
		for key, value in pairs(db) do
			if type(value) == "boolean" then keys[#keys + 1] = key .. "=" .. tostring(value) end
		end
		table.sort(keys)
		print("switches=" .. table.concat(keys, ","))
	end
	os.exit(0)
end

-- The runs.
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end
local function Run(which, each)
	local pipe = io.popen(("%s Tools/offline/lazysearch.lua %s %s 2>&1"):format(LUA, which, each))
	local out, raw = {}, {}
	for line in pipe:lines() do
		raw[#raw + 1] = line
		local k, v = line:match("^(%w+)=(.*)$")
		if k then out[k] = v end
	end
	pipe:close()
	if not out.waitingEnd then print(table.concat(raw, "\n")) end
	return out
end

for _, each in ipairs({ "forever", "retail" }) do
	print("== " .. each)
	local s, all = Run("search", each), Run("searchAll", each)
	Check("the search box is there", s.box == "true")
	Check("pages wait at the start", tonumber(s.waitingBefore or 0) > 1, s.waitingBefore)
	Check("Searching... while they're made", tonumber(s.searchingShown or 0) == 1, s.searchingShown)
	Check("not all made in the first frame", tonumber(s.waitingAfterFirst or 0) > 0, s.waitingAfterFirst)
	Check("made over several frames", tonumber(s.ticks or 0) > 2, s.ticks)
	Check("all made, Searching... gone", s.waitingEnd == "0" and s.searchingEnd == "0",
		("%s waiting, %s shown"):format(tostring(s.waitingEnd), tostring(s.searchingEnd)))
	Check("matches shown", tonumber(s.matches or 0) > 0, s.matches)
	Check("the same matches as with every page made first", s.matchList == all.matchList,
		("%s vs %s"):format(tostring(s.matches), tostring(all.matches)))
	local h, hAll = Run("hub", each), Run("hubAll", each)
	Check("a hub's switch makes some of its pages", h.made ~= nil and h.made ~= "", h.made)
	Check("and not every page", tonumber(h.waitingEnd or 0) > 0, h.waitingEnd)
	Check("page switches as with every page made first", h.switches == hAll.switches)
	if h.switches ~= hAll.switches then
		local a, b = {}, {}
		for kv in (h.switches or ""):gmatch("[^,]+") do a[kv] = true end
		for kv in (hAll.switches or ""):gmatch("[^,]+") do b[kv] = true end
		for kv in pairs(a) do if not b[kv] then print("   only hub-only: " .. kv) end end
		for kv in pairs(b) do if not a[kv] then print("   only all-made: " .. kv) end end
	end
end
print(fails == 0 and "lazy search: 0 problems" or ("lazy search: %d problems"):format(fails))
os.exit(fails == 0 and 0 or 1)
-- luacheck: pop
