-- The touch map: every game frame and global the addon's own code reaches
-- (method calls, field reads called, hooks), which file does it, and under
-- which setting. Runs the settings sweep (Tools/offline/sweep.lua: every page
-- opened, every setting changed and put back) on the stand-in game in touch
-- mode (wow.lua, M.StartTouches), and writes what it saw. From the repo root:
--
--   python -I Tools/offline/run.py Tools/addon-kit/touchmap.lua <forever|retail> <out.txt> < /dev/null
--
-- Tools/addon-kit/touchpoints.py runs it and compares the result with the
-- saved registry. Each line of out.txt:
--   T <path>\t<method>\t<file>\t<setting>,<setting>...
--   D <setting key>                     (every key in ns.DEFAULTS)
-- (setting: the sweep's setting id, "(page <name>)" while a page opened,
-- "(load)" while loading and logging in). First line: the format.
local client, out = ...
assert(client == "forever" or client == "retail", "usage: touchmap.lua <forever|retail> <out.txt>")
assert(out, "usage: touchmap.lua <forever|retail> <out.txt>")
local FORMAT = 1

local mode = {}
rawset(_G, "CINE_TOUCH_MODE", mode)

local function Write()
	local wow = mode.wow
	if not wow then
		print("touchmap: the stand-in never started")
		return false
	end
	local lines = {}
	for path, byMethod in pairs(wow.touches) do
		for method, byFile in pairs(byMethod) do
			for file, settings in pairs(byFile) do
				local list = {}
				for setting in pairs(settings) do list[#list + 1] = setting end
				table.sort(list)
				lines[#lines + 1] = ("T %s\t%s\t%s\t%s"):format(path, method, file, table.concat(list, ","))
			end
		end
	end
	table.sort(lines)
	local file = assert(io.open(out, "w"))
	file:write(("# addon-kit touch map, format %d, client %s\n"):format(FORMAT, client))
	local log = rawget(_G, "CinematicDB") and CinematicDB.sweepLog or {}
	local summary
	for _, line in ipairs(log) do
		local text = line:gsub("^[%d%.]+ ", "")
		if text:find("^done: ") or text:find("^stopped: ") then summary = text end
	end
	file:write(("# sweep: %s\n"):format(summary or "didn't finish"))
	for _, line in ipairs(lines) do file:write(line, "\n") end
	-- (Every setting a fresh install has: D <key>.)
	local keys = {}
	for key in pairs(mode.ns and mode.ns.DEFAULTS or {}) do
		if type(key) == "string" then keys[#keys + 1] = key end
	end
	table.sort(keys)
	for _, key in ipairs(keys) do file:write("D ", key, "\n") end
	file:close()
	print(("touchmap %s: %d touches written, sweep %s"):format(client, #lines, summary or "didn't finish"))
	return summary ~= nil and summary:find("^done") ~= nil
end

-- (The sweep ends with os.exit: the map is written first, and the run's exit
-- code is the map's, not the sweep's FAIL lines, which touch mode changes.)
local realExit = os.exit
os.exit = function() -- luacheck: ignore 122
	local ok = Write()
	realExit(ok and 0 or 1)
end
local sweep = assert(loadfile("Tools/offline/sweep.lua"))
sweep(client)
realExit(Write() and 0 or 1)
