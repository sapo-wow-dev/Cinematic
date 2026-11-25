-- Guidelime's windows left alone (Support/Guidelime.lua), offline:
--   python -I Tools/offline/run.py Tools/offline/guidelimepopups.lua < /dev/null
-- The addon kit's run q3814 (2026-11-25) found its guides window NOT COVERED:
-- one of its own popups (F.createPopupFrame: unnamed, on UIParent, an okBtn,
-- a backdrop from its own folder), opened during the setup. Its windows are
-- left alone now, with what's inside them; a look-alike of another addon's,
-- a named frame, and anything with Guidelime not loaded, never. PASS or FAIL.
-- luacheck: push ignore 111 112 113 121 122
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail ~= nil and (" (" .. tostring(detail) .. ")") or ""))
end

local loaded = true
local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", function()
	C_AddOns.IsAddOnLoaded = function(name) return name == "Guidelime" and loaded end
	rawset(_G, "IsAddOnLoaded", C_AddOns.IsAddOnLoaded)
end)
wow.Fire("ADDON_LOADED", "Guidelime")

local function Popup(bg, name)
	local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
	frame.GetBackdrop = function() return { bgFile = bg, edgeFile = "Interface/DialogFrame/UI-DialogBox-Border" } end
	frame.okBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	return frame
end
local guides = Popup("Interface/Addons/Guidelime/Icons/Black")
guides.searchBtn = CreateFrame("Button", nil, guides, "UIPanelButtonTemplate")
local other = Popup("Interface/Addons/SomeOtherAddon/Icons/Black")
local named = Popup("Interface/Addons/Guidelime/Icons/Black", "GuidelimeNamedThing")
local plain = CreateFrame("Frame", nil, UIParent)

Check("Guidelime's popup test helper is there", ns.IsGuidelimePopup ~= nil)
ns.BuildManagedList()
Check("its guides window left alone", ns.IsLeftAloneFrame(guides))
Check("a look-alike of another addon's (an okBtn, its own backdrop): not left alone", not ns.IsLeftAloneFrame(other))
Check("a named frame: not this way (names have ns.LeaveAlone)", not ns.IsLeftAloneFrame(named))
Check("a plain frame on UIParent: not left alone", not ns.IsLeftAloneFrame(plain))

-- A popup made later (its windows are made the first time they open).
local editor = Popup("Interface/Addons/Guidelime/Icons/Black")
ns.BuildManagedList()
Check("a window made after the first scan: left alone on the next", ns.IsLeftAloneFrame(editor))

print(fails == 0 and "guidelimepopups: all passed" or ("guidelimepopups: %d FAIL"):format(fails))
os.exit(fails == 0 and 0 or 1)
-- luacheck: pop
