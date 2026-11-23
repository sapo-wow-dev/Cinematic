-- Friendly NPCs tab's "Far, behind walls" (nameServiceFarDim): past 28 yards a
-- Service NPCs name fades to it while its plate is dimmed (PlateParts'
-- plateSightNear.service, ns.PlateSightFloor); within 28 yards every dimmed
-- name hides as before; other far names stay up; nothing fades in fights.
--   python -I Tools/offline/run.py Tools/offline/servicefardim.lua [forever|retail] < /dev/null

local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local failed = 0
local function Check(label, ok, got)
	print((ok and "ok   " or "FAIL ") .. label .. (ok and "" or ("  (got " .. tostring(got) .. ")")))
	if not ok then failed = failed + 1 end
end

Check("1 default 0 (hide)", ns.DEFAULTS.nameServiceFarDim == 0, ns.DEFAULTS.nameServiceFarDim)
Check("2 fresh db has it", ns.db.nameServiceFarDim == 0, ns.db.nameServiceFarDim)

local F = ns.PlateSightFloor
Check("3 near: hides whatever the row", F(true, nil, false, 50) == 0, F(true, nil, false, 50))
Check("4 near service: hides, not the slider", F(true, true, false, 50) == 0, F(true, true, false, 50))
Check("5 far, not service: left up", F(false, nil, false, 0) == nil, F(false, nil, false, 0))
Check("6 far service, 0: hides", F(false, true, false, 0) == 0, F(false, true, false, 0))
Check("7 far service, 40: 0.4", F(false, true, false, 40) == 0.4, F(false, true, false, 40))
Check("8 far service, 100: shown", F(false, true, false, 100) == 1, F(false, true, false, 100))
Check("9 far service in a fight: left up", F(false, true, true, 0) == nil, F(false, true, true, 0))
Check("10 not asked yet (nil near) counts as far", F(nil, true, false, 0) == 0, F(nil, true, false, 0))
Check("11 setting missing: hides", F(false, true, false, nil) == 0, F(false, true, false, nil))

-- SetPlateBody keeps the Service NPCs mark, only while the name shows.
local plate = CreateFrame("Frame")
ns.SetPlateBody(plate, 0, 1, 0, 0.5, 1)
Check("12 kept by Service NPCs: marked", ns.plateSightNear.service[plate] == true, ns.plateSightNear.service[plate])
ns.SetPlateBody(plate, 0, 1, 0, 1, 0)
Check("13 kept by its own row: not marked", ns.plateSightNear.service[plate] == nil, ns.plateSightNear.service[plate])
ns.SetPlateBody(plate, 0, 1, 0, 0.5, 1)
ns.SetPlateBody(plate, 1, 0)
Check("14 name gone: mark gone", ns.plateSightNear.service[plate] == nil, ns.plateSightNear.service[plate])

-- The slider is on the Friendly NPCs tab's page (made on first open: made here).
for _, entry in ipairs(ns.lazySettingsPages or {}) do
	if not entry.made then entry.Make("servicefardim") end
end
-- (Found by what dragging it sets: the stand-in's sliders keep no range.)
local found
for i = 1, 2000 do
	local slider = _G["CinematicOptionsSlider" .. i]
	if not slider then break end
	local script = slider.GetScript and slider:GetScript("OnValueChanged")
	if script then
		ns.db.nameServiceFarDim = 0
		pcall(script, slider, 35)
		if ns.db.nameServiceFarDim == 35 then found = slider break end
	end
end
Check("15 its slider sets it", found ~= nil)
if found then
	ns.db.nameServiceFarDim = 0
	found:Refresh()
	Check("16 its value reads 0%", tostring(found.title:GetText() or ""):find("^|cffffd1000%%|r$") ~= nil,
		found.title:GetText())
end
ns.db.nameServiceFarDim = 0

print(failed == 0 and "servicefardim: all passed" or ("servicefardim: " .. failed .. " failed"))
if failed > 0 then os.exit(1) end
