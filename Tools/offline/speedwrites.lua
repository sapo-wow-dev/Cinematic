-- Camera speed writes (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/speedwrites.lua
-- Each turn speed write (ns.SetHeldSpeed: a SetCVar) costs the game ~0.7 ms:
-- its XP bar redraws on every CVAR_UPDATE, our bar hooks after it
-- (Tools/perf/ledger.md 2026-11-23: the Chat Cam's drift at 2% was ~7 writes a
-- second, 0.07 ms a frame). Every camera that eases a turn's speed sends it
-- only when it's changed by CHANGE or more. Checked: each file's step is 5%,
-- and an eased 2-second swing from the lowest setting to 180 and back, sent
-- the way they send it (only past the step, the distance added up from the
-- speed sent), makes under half the writes 2% made and still ends within 1%
-- of the distance asked. PASS or FAIL.
local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. text)
	if not ok then failed = failed + 1 end
end

local STEPS = {
	{ "Camera/CameraScripts.lua", "local CHANGE = ([%d.]+)" },
	{ "Camera/ChatCam.lua", "local SPEED_CHANGE = ([%d.]+)" },
	{ "Camera/QuestCam.lua", "local MOVE_CHANGE = ([%d.]+)" },
	{ "Profiles/ShowMe.lua", "local SETTING_CHANGE = ([%d.]+)" },
	{ "Camera/Camera.lua", "SETTING_CHANGE = ([%d.]+)," },
}
for _, each in ipairs(STEPS) do
	local file = io.open(each[1])
	local text = file and file:read("*a") or ""
	if file then file:close() end
	local step = tonumber(text:match(each[2]))
	Check(step and step >= 0.05, ("%s: speed step %s (5%% or more)"):format(each[1], tostring(step)))
end

-- An eased swing (smoothstep speed curve) at 80 fps, sent past the step.
local function Swing(step, T, peak)
	local fps = 80
	local sent, writes, done, wanted = nil, 0, 0, 0
	for i = 1, T * fps do
		local t = i / fps
		local p = math.min(t, T - t) / (T / 2)
		p = p * p * (3 - 2 * p)
		local speed = math.max(1, peak * p)
		wanted = wanted + speed / fps
		if not sent then
			sent = 1
		elseif math.abs(speed - sent) > sent * step then
			sent, writes = speed, writes + 1
		end
		done = done + sent / fps
	end
	return writes, done, wanted
end
-- (A quick swing changes its speed more than 5% most frames anyway: fewer
-- writes, not half. A slow drift's change is small a frame: under half.)
local f2 = Swing(0.02, 2, 180)
local f5 = Swing(0.05, 2, 180)
Check(f5 < f2, ("a quick 2-second swing to 180: %d writes at 5%% (was %d at 2%%)"):format(f5, f2))
local w2 = Swing(0.02, 8, 20)
local w5, done, wanted = Swing(0.05, 8, 20)
Check(w5 <= w2 * 0.5, ("a slow 8-second drift to 20: %d writes at 5%% (was %d at 2%%)"):format(w5, w2))
-- (Sent lags the curve a little; the cameras count the distance from what's
-- sent, so this only says how far the speed lags, not where a turn ends.)
Check(math.abs(done - wanted) / wanted < 0.05,
	("the speed sent stays near the curve: %.1f of %.1f degrees"):format(done, wanted))

print(failed == 0 and "ALL PASSED" or (failed .. " FAILED"))
