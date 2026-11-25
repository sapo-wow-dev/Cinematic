-- The wheels' keys with their Keybinds tab off (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-wheel-key-tab.md):
--   python -I Tools/offline/run.py Tools/offline/wheelkeytabmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/wheelkeytabmatrix.lua forever --base <ref>
-- The Marker wheel and the Menu wheel, each with its Wheels page on or off;
-- the Keybinds page's Wheels tab switched on or off (its switch clicked, as
-- its right-click does). Their keys click secure buttons (Bindings.xml can't
-- ask Cinematic_KeyOn), so the wheel's own "cineoff" stops the key. Each
-- cell: the key opens the wheel or does nothing.
-- The rule (decided 2026-11-25: a tab off = everything on it off): with the
-- tab off, or the wheel's page off, its key does nothing.
local client = arg and arg[1] or "forever"
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db
wow.Fire("PLAYER_ENTERING_WORLD")

-- (The stand-in keeps no attributes: these two wheels' own, kept.)
local WHEELS = { marker = { _G.CinematicMarkerWheel, "wheelMarkerOn" }, menu = { _G.CinematicMenuWheel, "wheelMenuOn" } }
for _, each in pairs(WHEELS) do
	local frame, attrs = each[1], {}
	if frame then
		rawset(frame, "SetAttribute", function(_, k, v) attrs[k] = v end)
		rawset(frame, "GetAttribute", function(_, k) return attrs[k] end)
	end
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "wheel-key-tab",
	fixed = { client = client },
	dims = {
		{ "wheel", { "marker", "menu" } },
		{ "page", { "on", "off" } },
		{ "tab", { "on", "off" } },
	},
	cell = function(c)
		local frame, switch = WHEELS[c.wheel][1], WHEELS[c.wheel][2]
		if not frame then return "no wheel" end
		local button = c.wheel == "marker" and "CinematicMarkerWheelButton" or "CinematicMenuWheelButton"
		local tabKey = ns.KeybindTabKey("CLICK " .. button .. ":LeftButton")
		if not tabKey then return "no tab" end
		db.wheelMasterOn, db[switch] = true, c.page == "on"
		ns.ApplyWheelSwitches() -- (the wheel page's switch applied: its own Changed)
		db[tabKey] = c.tab ~= "on" -- (the other way, then its switch clicked)
		if not ns.FlipSettingKey(tabKey) then return "no tab switch" end
		local out = frame:GetAttribute("cineoff") and "key=nothing" or "key=opens"
		db[tabKey], db[switch] = true, true
		ns.ApplyWheelSwitches()
		return out
	end,
	pins = {
		{ "", "key=nothing" },
		{ "page=on tab=on", "key=opens" },
	},
})
