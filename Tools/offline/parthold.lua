-- A part the Show-in rows hide (Frames.lua's SetHidden) is put back at the
-- alpha it should have once let go, not at the one it had when hidden
-- (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/parthold.lua < /dev/null
-- A shaped Style theme clears the target's name strip (alpha 0) and its
-- Name background row hides it too; back on the game's look Style gives it
-- alpha 1, but the row put back the 0 it had saved: the strip stayed gone
-- till a /reload (the side-by-side run, 2026-11-21, Codex and the game's
-- look after Fel or Reel). Says PASS or FAIL per check.
-- luacheck: ignore 111 112 113
local F = dofile("Tools/style-lab/frames.lua")
local ns = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", function(w) F.Install(w) end)
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end
Check("the hide is reachable", type(ns.UnitPartSetHidden) == "function")
if ns.UnitPartSetHidden then
	local frame = CreateFrame("Frame", nil, UIParent)
	local strip = frame:CreateTexture(nil, "ARTWORK")
	-- (Cleared by a theme, then hidden by its row.)
	strip:SetAlpha(0)
	ns.UnitPartSetHidden(strip, true)
	Check("hidden", strip:GetAlpha() == 0, strip:GetAlpha())
	-- (Given back while hidden: still hidden.)
	strip:SetAlpha(1)
	Check("kept hidden while held", strip:GetAlpha() == 0, strip:GetAlpha())
	-- (Let go: the alpha it was given, not the 0 it had.)
	ns.UnitPartSetHidden(strip, false)
	Check("back at the alpha it was given while held", strip:GetAlpha() == 1, strip:GetAlpha())
	-- (A plain hide and show: its own alpha back.)
	local glow = frame:CreateTexture(nil, "ARTWORK")
	glow:SetAlpha(0.6)
	ns.UnitPartSetHidden(glow, true)
	Check("a part's hide", glow:GetAlpha() == 0, glow:GetAlpha())
	ns.UnitPartSetHidden(glow, false)
	Check("its own alpha back", math.abs(glow:GetAlpha() - 0.6) < 1e-6, glow:GetAlpha())
end
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
