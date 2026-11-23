-- The one Reload box's Edit Mode layout reason dropped once untrue (offline,
-- Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/reloadreason.lua < /dev/null
-- Audit 2026-11-22: ns.AskReload kept a reason till the reload. Pick
-- Shoulder Cam on the welcome window (its layout made: "switch Edit Mode
-- layouts"), then Balanced: the newer switch clears layoutPending, but the box
-- still offered the layout switch, and the welcome window, seeing a box,
-- came back after a reload nothing needed. Checks: the reason in the box; a
-- newer profile's layout switch takes it out (the box gone with nothing
-- left); a parts reason beside it stays. PASS or FAIL per check.

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local shown = {}
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	StaticPopupDialogs = {}
	StaticPopup_Show = function(which, text) shown[which] = text end
	StaticPopup_Hide = function(which) shown[which] = nil end
	StaticPopup_Visible = function(which) return shown[which] ~= nil end
	C_EditMode = { GetLayouts = function() return { layouts = {}, activeLayout = 1 } end,
		SetActiveLayout = function() end }
	-- luacheck: pop
end
local ns = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", Install)
local BOX = ns.MODULES_RELOAD_POPUP
StaticPopupDialogs.CINEMATIC_LAYOUT_RELOAD = StaticPopupDialogs.CINEMATIC_LAYOUT_RELOAD or { text = "layout box" }
ns.chardb = ns.chardb or {}

-- 1: a profile's layout made this session: the box asks.
ns.OfferLayoutReload("Cinematic Shoulder")
Check("1 the box asks for the layout", ns.ReloadBoxText() ~= nil and shown[BOX] ~= nil, tostring(ns.ReloadBoxText()))
-- 2: a newer profile with no layout of its own (Balanced): untrue now, gone.
ns.db.editModeLayout = ""
ns.ApplyProfileLayout()
Check("2 its layout pending cleared", ns.chardb.layoutPending == nil)
Check("2 the reason gone", ns.ReloadBoxText() == nil, tostring(ns.ReloadBoxText()))
Check("2 the box gone with it", shown[BOX] == nil, tostring(shown[BOX]))
-- 3: with another reason beside it, that one stays.
ns.OfferLayoutReload("Cinematic Shoulder")
ns.AskReload("bars", "show this layout's action bars", "bars box")
ns.ApplyProfileLayout()
local text = ns.ReloadBoxText()
Check("3 the other reason stays", text ~= nil and text == "bars box" and shown[BOX] == "bars box", tostring(text))

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
