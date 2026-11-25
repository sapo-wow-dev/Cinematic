-- The time-of-day test commands with Visions loaded or left out (the audit
-- kit's matrix, Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-time-title-test.md):
--   python -I Tools/offline/run.py Tools/offline/timetitlematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/timetitlematrix.lua forever --base <ref>
-- /cine tinttest (the tint through every time of day, Atmosphere's, each
-- phase's title Visions') and /cine timetest all (Visions' titles, one after
-- another on timers): played through on pretend time. Each cell: "ok", or how
-- many errors and the first. A call into Visions left out happens later than
-- the command (in the tint's update, on a timer), past the command's own
-- "isn't loaded" catch: it must not error.
-- Each cell its own load in its own process.
local LUA = os.getenv("CINE_LUA") or "lua5.1"
local client, visions, cmd = ...
client = client or "forever"

if visions then
	local now = 1000
	local timers = {}
	local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
		if visions == "out" then CinematicDB = { loadVisions = false } end -- luacheck: ignore 111
		GetTime = function() return now end -- luacheck: ignore 121 122
		C_Timer.After = function(delay, fn) timers[#timers + 1] = { at = now + (delay or 0), fn = fn } end -- luacheck: ignore 122
	end)
	local errors, first = 0, nil
	local function Note(ok, err)
		if not ok then
			errors = errors + 1
			first = first or tostring(err):gsub("^.-([%w_]+%.lua:%d+:)", "%1")
		end
	end
	Note(pcall(ns.HandleSlash, cmd == "tinttest" and "tinttest 4" or "timetest all"))
	for _ = 1, 600 do -- (60 pretend seconds, a tenth at a time)
		now = now + 0.1
		local due = {}
		for i = #timers, 1, -1 do
			if timers[i].at <= now then due[#due + 1] = table.remove(timers, i).fn end
		end
		for _, fn in ipairs(due) do Note(pcall(fn)) end
		if ns.UpdateTint then Note(pcall(ns.UpdateTint, true, 0.1)) end
	end
	print(("CELLRESULT %s"):format(errors == 0 and "ok" or ("error x%d: %s"):format(errors, first)))
	return
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "time-title-test",
	fixed = { client = client },
	dims = {
		{ "visions", { "loaded", "out" } },
		{ "cmd", { "tinttest", "timetest" } },
	},
	cell = function(c)
		local pipe = io.popen(("%s Tools/offline/timetitlematrix.lua %s %s %s 2>&1"):format(LUA, client,
			c.visions == "out" and "out" or "in", c.cmd))
		local out = pipe:read("*a")
		pipe:close()
		return out:match("CELLRESULT ([^\r\n]*)") or ("no result: " .. out:sub(-200))
	end,
	pins = {
		{ "", "ok" },
	},
})
