-- Finding one camera script (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/findcamerascript.lua <forever|retail>
-- ns.FindCameraScript made every built-in camera's script to find one (~220 KB
-- of garbage a look, Tools/perf/ledger.md 2026-11-23). Now it makes only the
-- one asked for. Checked: for every id ns.CameraScripts() lists, the script
-- found is the same as the list's first with that id (built-in, a built-in
-- you edited, yours), an unknown id gives none, and a look makes far less
-- memory than the whole list. PASS or FAIL.
-- luacheck: push ignore 111 112 113 121 122
local client = arg and arg[1] or "forever"
package.path = "Tools/offline/?.lua;" .. package.path
local wow = dofile("Tools/offline/wow.lua")
wow.Install(client)
local ns = {}
for line in io.lines("Cinematic.toc") do
	line = line:gsub("\r", "")
	if line ~= "" and not line:find("^#") then
		local chunk, loadErr = loadfile((line:gsub("\\", "/")))
		if not chunk then print("FAIL " .. line .. " doesn't compile: " .. tostring(loadErr)) end
		if chunk then
			local ok, err = pcall(chunk, "Cinematic", ns)
			if not ok then wow.Warn(line .. ": " .. tostring(err)) end
		end
	end
end
wow.Fire("ADDON_LOADED", "Cinematic")
wow.Fire("PLAYER_LOGIN")
-- luacheck: pop

local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. text)
	if not ok then failed = failed + 1 end
end
Check(ns.FindCameraScript and ns.CameraScripts, "ns.FindCameraScript and ns.CameraScripts found")
if not (ns.FindCameraScript and ns.CameraScripts) then return print("1 FAILED") end

local function Same(a, b, seen)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	seen = seen or {}
	if seen[a] == b then return true end
	seen[a] = b
	for k, v in pairs(a) do if not Same(v, b[k], seen) then return false end end
	for k in pairs(b) do if a[k] == nil then return false end end
	return true
end
local function AllSame(label)
	local first, ids, bad = {}, 0, {}
	for _, script in ipairs(ns.CameraScripts()) do
		if script.id and not first[script.id] then first[script.id] = script; ids = ids + 1 end
	end
	for id, want in pairs(first) do
		if not Same(ns.FindCameraScript(id), want) then bad[#bad + 1] = tostring(id) end
	end
	Check(ids > 5 and #bad == 0, ("%s: %d ids, each found as the list has it%s"):format(label, ids,
		#bad > 0 and (" - differ: " .. table.concat(bad, ", ")) or ""))
end
AllSame("built-ins")

-- One of yours, and a built-in you edited.
if ns.AddCameraScript then
	local mine = ns.AddCameraScript(nil, "Mine")
	Check(mine and ns.FindCameraScript(mine.id) == mine, "yours: found, the saved table itself")
end
local builtinId = ns.CameraScripts()[1].id
local edited
if ns.EditBuiltinCameraScript then
	local copy = ns.FindCameraScript("quest")
	copy.steps = copy.steps or {}
	edited = ns.EditBuiltinCameraScript(copy)
end
Check(edited and ns.FindCameraScript("quest") == edited and edited.edited and edited.builtin,
	"a built-in you edited: your kept table, marked edited and built-in")
AllSame("with one of yours and an edited built-in")
Check(ns.FindCameraScript("no-such-camera") == nil, "an unknown id: none")
Check(ns.FindCameraScript(builtinId).builtin == true, "a built-in: marked built-in")

-- Memory: one look against the whole list.
collectgarbage("collect")
collectgarbage("stop")
local before = collectgarbage("count")
for _ = 1, 20 do ns.CameraScripts() end
local whole = (collectgarbage("count") - before) / 20
before = collectgarbage("count")
for _ = 1, 20 do ns.FindCameraScript("quest") end
local one = (collectgarbage("count") - before) / 20
collectgarbage("restart")
Check(one < whole / 4, ("a look made %.1f KB (the whole list %.1f KB)"):format(one, whole))

print(failed == 0 and "ALL PASSED" or (failed .. " FAILED"))
