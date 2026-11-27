-- Plays a scenario through Cinematic on the replay bench and prints the report.
-- From the repo root (Lua 5.1, or python -I Tools/offline/run.py instead of lua5.1):
--   lua5.1 Tools/sim/run.lua <scenario> [client] [fps] [profile]
-- <scenario>: a file (Tools/sim/scenarios/<name>.lua, returning one), or a
-- synthetic one by name: idle, city, fight (Tools/sim/synthetic.lua; made up,
-- for testing the bench). client: forever (default), retail, classic_era.
-- luacheck: push ignore 113
local args = arg or {}
local name, client, fps, profile = args[1] or "idle", args[2] or "forever", tonumber(args[3] or "") or 60, args[4]
local scenario
local path = name:find("%.lua$") and name or ("Tools/sim/scenarios/" .. name .. ".lua")
local f = io.open(path, "r")
if f then
	f:close()
	scenario = dofile(path)
else
	local Synthetic = dofile("Tools/sim/synthetic.lua")
	if not Synthetic[name] then
		print("no scenario " .. name .. " (a file under Tools/sim/scenarios/, or idle, city, fight)")
		os.exit(1)
	end
	scenario = Synthetic[name]()
end
local Bench = dofile("Tools/sim/bench.lua")
local bench = Bench.New({ client = client, fps = fps })
bench:Play(scenario, { profile = profile })
print(bench:Report())
-- luacheck: pop
