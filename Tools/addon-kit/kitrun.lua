-- The addon kit's probes run offline, on the stand-in game (Dev/AddonKit.lua,
-- the same lines CinematicDB.addonKitLog gets in game). From the repo root:
--
--   python -I Tools/offline/run.py Tools/addon-kit/kitrun.lua <forever|retail> <out.txt> [Addon,Addon...] < /dev/null
--
-- With addons named, the stand-in says they're loaded (C_AddOns.IsAddOnLoaded
-- and the run's addons= list) once Cinematic has: what our code reads of
-- them, not their own code, which never runs offline. For diff.py's selftest
-- and quick checks; the real runs are in game (/cine debug addonkit, step 5).
local client, out, addons = ...
assert(client == "forever" or client == "retail", "usage: kitrun.lua <forever|retail> <out.txt> [Addon,Addon...]")
assert(out, "usage: kitrun.lua <forever|retail> <out.txt> [Addon,Addon...]")
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
assert(ns.AddonKit, "no ns.AddonKit: Dev/AddonKit.lua not in CinematicDev.toc?")
-- (The kit's own files must load cleanly.)
for _, warning in ipairs(wow.warnings) do
	if tostring(warning):find("AddonKit") or tostring(warning):find("AddonSupport") then
		print("kitrun: " .. tostring(warning))
		os.exit(1)
	end
end
assert(ns.AddonKit.TOUCHES and ns.AddonKit.HOOKS, "no Dev/AddonKitTouches.lua (touchpoints.py --update)")

local loaded, list = {}, {}
for name in (addons or ""):gmatch("[^,]+") do
	loaded[name] = true
	list[#list + 1] = name
end
table.sort(list)
if #list > 0 then
	local function IsLoaded(name) return loaded[name] or false end
	C_AddOns.IsAddOnLoaded = IsLoaded -- luacheck: ignore 122
	rawset(_G, "IsAddOnLoaded", IsLoaded)
end
ns.AddonKit.loadedOverride = list

local lines = ns.AddonKit.Run(#list > 0 and ("offline " .. table.concat(list, "+")) or "offline baseline")
local file = assert(io.open(out, "w"))
for _, line in ipairs(lines) do file:write(line, "\n") end
file:close()
print(("kitrun %s: %s"):format(client, lines[#lines]))
