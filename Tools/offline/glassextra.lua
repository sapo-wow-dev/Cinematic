-- Glass's extra windows (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/glassextra.lua < /dev/null
-- Glass can show a chat window a second time, in a window of its own: an
-- unnamed frame on UIParent, outside GlassFrame, reached through its global
-- addon object (Glass:GetModule("ExtraWindows").views[id].frame). Our scanner
-- only looked inside GlassFrame, so those windows stayed up while the chat
-- faded (found reading Glass 2.2.0, 2026-11-25). Now each one fades with the
-- Chat window row and is linked to the window it shows; a released one, or
-- one with no game window behind it, is left out. Says PASS or FAIL per check.
-- (Optional first argument: another .toc to load, to run it on older code.)
-- luacheck: push ignore 111 112 113 121 122
local ns, wow = dofile("Tools/offline/load.lua")("forever", arg and arg[1])

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

-- Glass's scanner, caught as it's added; what it finds and claims, written down.
local scanners, found, claimed = {}, {}, {}
local AddScanner, AddFoundFrame, ClaimLinkPart = ns.AddScanner, ns.AddFoundFrame, ns.ClaimLinkPart
ns.AddScanner = function(fn) scanners[#scanners + 1] = fn return AddScanner(fn) end
ns.AddFoundFrame = function(frame, group, ...) found[frame] = group return AddFoundFrame(frame, group, ...) end
ns.ClaimLinkPart = function(addon, part, frame, info)
	claimed[frame] = { addon = addon, part = part, window = info and info.window }
	return ClaimLinkPart(addon, part, frame, info)
end

C_AddOns.IsAddOnLoaded = function(name) return name == "Glass" end
IsAddOnLoaded = C_AddOns.IsAddOnLoaded
_G.GlassFrame = CreateFrame("Frame", "GlassFrame", UIParent)
local shown = CreateFrame("Frame", nil, UIParent)
local released = CreateFrame("Frame", nil, UIParent)
local noSource = CreateFrame("Frame", nil, UIParent)
local window = CreateFrame("ScrollingMessageFrame", "ChatFrame3", UIParent)
local extra = { views = {
	["1"] = { frame = shown, source = window },
	["2"] = { frame = released, source = window, released = true },
	["3"] = { frame = noSource },
} }
_G.Glass = { GetModule = function(_, name) return name == "ExtraWindows" and extra or nil end }
wow.Fire("ADDON_LOADED", "Glass")
Check("Glass's scanner added", #scanners >= 1, #scanners)
for _, fn in ipairs(scanners) do fn() end

Check("an extra window fades with the Chat window row", found[shown] == "chat", tostring(found[shown]))
Check("and is linked to the window it shows", claimed[shown] and claimed[shown].part == "chatwindow"
	and claimed[shown].window == window, claimed[shown] and claimed[shown].part)
Check("a released one is left out", found[released] == nil and claimed[released] == nil)
Check("one with no game window behind it fades, unlinked", found[noSource] == "chat" and claimed[noSource] == nil)

-- No ExtraWindows module (an older Glass), or no Glass global: nothing breaks.
_G.Glass = { GetModule = function() error("no module") end }
local ok, err = pcall(function() for _, fn in ipairs(scanners) do fn() end end)
Check("an older Glass without extra windows: no error", ok, err)
_G.Glass = nil
ok, err = pcall(function() for _, fn in ipairs(scanners) do fn() end end)
Check("no Glass global: no error", ok, err)

print(fails == 0 and "all passed" or (fails .. " failed"))
if fails > 0 then os.exit(1) end
-- luacheck: pop
