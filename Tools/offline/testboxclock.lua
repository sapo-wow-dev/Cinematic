-- The test box's timers (Frames.lua ns.PadTestBoxClock, the test kit's
-- Kit.Clock): time on the step, the run, what's left, then "took" at the end
-- (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/testboxclock.lua < /dev/null
-- The user, 2026-11-21: "i want timers". Says PASS or FAIL per check.
-- luacheck: ignore 111 112 113 121
local F = dofile("Tools/style-lab/frames.lua")
local now = 100
local ns = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", function(w) F.Install(w) end)
GetTime = function() return now end
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end
Check("minutes and seconds", ns.PadTestTime(65) == "1:05" and ns.PadTestTime(0) == "0:00", ns.PadTestTime(65))
local Kit = ns.TestKit
Check("the kit's clock is there", Kit and type(Kit.Clock) == "function")
-- (Timers set before the box is made: shown once it is.)
local run = { began = 100, stepBegan = 100 }
ns.PadTestBoxClock(function() return Kit.Clock(run) end)
ns.PadTestBox("Step 1: hands off", "")
local box = ns.padTestBox
local function Tick(seconds)
	now = now + seconds
	local update = box:GetScript("OnUpdate")
	update(box, 0.3)
	return box.clock:GetText()
end
Check("step and run time", Tick(5) == "step 0:05    run 0:05", box.clock:GetText())
run.stepBegan, run.expectEnd = now, now + 30
Check("a countdown on a step of known length", Tick(10) == "step 0:10    run 0:15    about 0:20 left", box.clock:GetText())
Check("past its length: any moment now", Tick(25):find("any moment now$") ~= nil, box.clock:GetText())
Check("the box grows for its timer line", box:GetHeight() > box.text:GetStringHeight() + box.sub:GetStringHeight() + 48,
	box:GetHeight())
ns.PadTestBoxClock(function() return "took 0:50" end)
Check("the run's time at the end", Tick(1) == "took 0:50", box.clock:GetText())
ns.PadTestBoxClock(nil)
Check("off again", (box.clock:GetText() or "") == "", box.clock:GetText())
-- (Every test's mid-screen prompt on a dark panel too: bare text couldn't be
-- read over rough ground.)
ns.TestPrompt("Target yourself", 4)
local prompt
for _, child in ipairs({ WorldFrame:GetChildren() }) do if child.text and child.panel then prompt = child end end
Check("a test prompt has its dark panel", prompt ~= nil and prompt.panel:IsShown())
if prompt then
	Check("the panel around the words", prompt.panel:GetWidth() > prompt.text:GetWidth()
		and prompt.panel:GetHeight() > prompt.text:GetStringHeight(), ("%.0fx%.0f"):format(prompt.panel:GetWidth(), prompt.panel:GetHeight()))
end
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
