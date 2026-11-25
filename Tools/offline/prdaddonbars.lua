-- Another addon's bars on the personal bar rows fade with the game's own
-- personal resource display off (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/prdaddonbars.lua < /dev/null
-- With the game's display off (nameplateShowSelf 0), the frames' pass left
-- the Personal health and resource bar rows out entirely, and with them
-- EllesmereUI's resource bars, which stand in for that display: hidden rows
-- kept them up (addon kit run q0d2b, 2026-11-25: ERB_PrimaryBar "ours 1.00").
-- Now only the display's own frames are left out. Says PASS or FAIL.

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc")

-- Its resource bars' setup runs (Support/EllesmereUI.lua: FadeWithRows on prd and prdpower).
local IsLoaded = C_AddOns.IsAddOnLoaded
C_AddOns.IsAddOnLoaded = function(addon) return addon == "EllesmereUIResourceBars" or IsLoaded(addon) end -- luacheck: ignore 122
wow.Fire("ADDON_LOADED", "EllesmereUIResourceBars")
C_AddOns.IsAddOnLoaded = IsLoaded -- luacheck: ignore 122

Check("its health bar is an addon bar on those rows", ns.PersonalAddonBar("ERB_HealthBar"))
Check("its power bar too", ns.PersonalAddonBar("ERB_PrimaryBar"))
Check("the game's own display isn't", not ns.PersonalAddonBar("PersonalResourceDisplayFrame"))
Check("nor a frame on another row", not ns.PersonalAddonBar("ERB_CastBarFrame"))

local game = { name = "PersonalResourceDisplayFrame", group = "prdpower" }
local stand = { name = "CinematicPersonalPower", group = "prdpower" }
local health = { name = "ERB_HealthBar", group = "prd" }
local power = { name = "ERB_PrimaryBar", group = "prdpower" }
local other = { name = "ChatFrame1", group = "chat" }
local managed = { game, stand, health, power, other }

local function Has(list, entry)
	for _, e in ipairs(list) do if e == entry then return true end end
	return false
end
local on = ns.PersonalPassEntries(managed, true, {})
Check("display on: every entry in the pass", #on == 5, #on)
local off = ns.PersonalPassEntries(managed, false, {})
Check("display off: its health bar still in the pass", Has(off, health))
Check("display off: its power bar still in the pass", Has(off, power))
Check("display off: the game's display left out", not Has(off, game))
Check("display off: our stand-in left out", not Has(off, stand))
Check("display off: other rows' frames kept", Has(off, other))

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
