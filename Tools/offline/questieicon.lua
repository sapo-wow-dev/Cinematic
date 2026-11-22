-- Finding Questie's quest icon on a nameplate (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/questieicon.lua <forever|retail>
-- Plates/PlateParts.lua's FindQuestieIcon made a closure and a table of the
-- plate's children per plate per look (~14 KB/s at 40 plates, Tools/perf/
-- ledger.md 2026-11-22). Now the children go as arguments. Checked: the shown
-- icon found among other children (not a hidden one, not one without an
-- Icon), none on a plate without, a plate whose GetChildren errors (a
-- forbidden one) gives none, and no memory made per look. PASS or FAIL.
-- luacheck: push ignore 111 112 113 121 122
local client = arg and arg[1] or "forever"
package.path = "Tools/offline/?.lua;" .. package.path
local wow = dofile("Tools/offline/wow.lua")
wow.Install(client)
local ns = {}
for line in io.lines("Cinematic.toc") do
	line = line:gsub("\r", "")
	if line ~= "" and not line:find("^#") then
		local chunk = loadfile((line:gsub("\\", "/")))
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
local Find = ns.FindQuestieIconNow
Check(Find ~= nil, "ns.FindQuestieIconNow found")
if not Find then return print("1 FAILED") end
ns.Reachable = function(frame) return frame ~= nil and not frame.forbidden end

local function Child(fields)
	local child = { shown = true }
	for k, v in pairs(fields or {}) do child[k] = v end
	child.IsShown = function(self) return self.shown end
	return child
end
local function Plate(children, broken)
	return { GetChildren = function()
		if broken then error("forbidden") end
		return unpack(children)
	end }
end

local icon = Child({ lastIcon = 1, Icon = {} })
local hidden = Child({ lastIcon = 1, Icon = {}, shown = false })
local noIcon = Child({ lastIcon = 1 })
local plain = Child()
local locked = Child({ lastIcon = 1, Icon = {}, forbidden = true })
Check(Find(Plate({ plain, noIcon, hidden, locked, icon, plain })) == icon,
	"the shown icon found among the plate's other children")
Check(Find(Plate({ plain, noIcon, hidden })) == nil, "a plate without one: none")
Check(Find(Plate({})) == nil, "a plate with no children: none")
Check(Find(Plate({ icon }, true)) == nil, "a plate whose GetChildren errors (forbidden): none, no error")
local many = {}
for i = 1, 30 do many[i] = plain end
many[31] = icon
Check(Find(Plate(many)) == icon, "found past 30 other children")

-- No memory made per look (a few bytes of noise allowed per 1000 looks).
local plate = Plate({ plain, noIcon, hidden, plain, plain, plain })
collectgarbage("collect")
collectgarbage("stop")
local before = collectgarbage("count")
for _ = 1, 1000 do Find(plate) end
local kb = collectgarbage("count") - before
collectgarbage("restart")
Check(kb < 2, ("1000 looks on a plate without an icon made %.2f KB (was ~0.2 KB a look)"):format(kb))

print(failed == 0 and "ALL PASSED" or (failed .. " FAILED"))
