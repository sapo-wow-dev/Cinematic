-- An update loop set from inside a hook on the game's secret work (offline,
-- Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/looplabel.lua < /dev/null
-- ns.SetOnUpdate names each loop by reading the call stack. Set from inside a
-- hook on the game's combat text SetText, the stack came back secret and
-- reading it errored (Diagnostics.lua LoopLabel, Forever 2026-11-20: the
-- mirror probe's first copy). Now: a secret stack names it "?" and the loop
-- still runs. Says PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122
local ns = dofile("Tools/offline/load.lua")("forever")

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

-- (A secret string: a table that can't be read as one.)
local SECRET = setmetatable({}, { __index = function() error("attempt to index a secret string value") end })
issecretvalue = function(v) return v == SECRET end
local secretStack = false
debugstack = function() return secretStack and SECRET or "[string \"@Interface/AddOns/Cinematic/Foo.lua\"]:12: in main chunk" end
-- luacheck: pop

local ran = 0
local frame = CreateFrame("Frame")
local ok, err = pcall(ns.SetOnUpdate, frame, function() ran = ran + 1 end)
Check("plain stack: set", ok, err)
secretStack = true
local frame2 = CreateFrame("Frame")
ok, err = pcall(ns.SetOnUpdate, frame2, function() ran = ran + 1 end)
Check("secret stack: set without an error", ok, err)
local loop = frame2:GetScript("OnUpdate")
Check("secret stack: the loop is there", type(loop) == "function")
if loop then loop(frame2, 0.016) end
Check("secret stack: the loop runs", ran == 1, ran)

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
