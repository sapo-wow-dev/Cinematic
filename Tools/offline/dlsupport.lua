-- DaylightUI support checks (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/dlsupport.lua < /dev/null
-- The addon kit's first run with DaylightUI v2.2.7 (qb025, 2026-11-25)
-- showed:
-- 1. Its own loot roll window (Skins, since 2.2, on by default) and Roll
--    Vision's both up at every roll: an Addon Conflicts row now, its own while
--    unpicked, its window held hidden with Ours, gone with its setting off.
-- 2. Hide keybinds and Hide macro names reached only the game's pet buttons
--    it keeps: they stand aside for good under its action bars, and the
--    Standard Frames page doesn't build the two checkboxes.
-- 3. Its setup window's screen dim and its login reveal's outlines (unnamed)
--    counted as missed frames: left alone now, with its named windows.
-- Says PASS or FAIL per check. (Optional first argument: another .toc.)

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local ns, wow = dofile("Tools/offline/load.lua")("forever", arg and arg[1] or "CinematicDev.toc")

local function RollsRow()
	for _, row in ipairs(ns.CONFLICTS) do
		if row.key == "rolls" and row.addon == "DaylightUI" then return row end
	end
end
Check("1 no DaylightUI: no loot roll row", RollsRow() == nil)

-- A stand-in DaylightUI: its settings, Skins module on, the setup window's
-- dim and two reveal outlines (one with its light).
local settings = { Skins = {} }
local veil = CreateFrame("Frame", nil, UIParent)
local outline1, outline2 = CreateFrame("Frame", nil, UIParent), CreateFrame("Frame", nil, UIParent)
outline1.shine = CreateFrame("Frame", nil, UIParent)
rawset(_G, "DaylightUI", {
	Get = function(_, scope, path) return settings[scope] and settings[scope][path] end,
	GetModule = function(_, name) return name == "Skins" and { enabled = true } or nil end,
	InstallerUI = { Veil = function() return veil end },
	Fade = { revealOverlays = { outline1, outline2 } },
})
local stack = CreateFrame("Frame", "DaylightUIRollStack", UIParent)
local IsLoaded = C_AddOns.IsAddOnLoaded
local loaded = { DaylightUI = true, DaylightUI_Skins = true, DaylightUI_ActionBars = true, DaylightUI_Chat = true }
C_AddOns.IsAddOnLoaded = function(addon) return loaded[addon] or false end -- luacheck: ignore 122
-- Its chat bubble drawn over a game bubble that's up (kit run qea48).
local gameBubble = CreateFrame("Frame")
rawset(_G, "C_ChatBubbles", { GetAllChatBubbles = function() return { gameBubble } end })
local bubbleCopy = CreateFrame("Frame", nil, UIParent)
bubbleCopy.balloon, bubbleCopy.said = CreateFrame("Frame", nil, gameBubble), "If your glass is full"
for _, addon in ipairs({ "DaylightUI", "DaylightUI_Skins", "DaylightUI_ActionBars", "DaylightUI_Chat" }) do
	wow.Fire("ADDON_LOADED", addon)
end

-- 1. The loot roll window.
local row = RollsRow()
Check("1 its Skins: a Loot roll window row", row ~= nil and row.group == "windows", row and row.group)
ns.db.rollWindow = true
local state, pick = ns.ConflictState("rolls")
Check("1 its window on by default: Roll Vision stands aside (unpicked = Theirs)",
	state == row and pick == "theirs", tostring(pick))
settings.Skins["rolls.enabled"] = false
Check("1 its window off: no clash, Roll Vision plays", ns.ConflictState("rolls") == nil)
settings.Skins["rolls.enabled"] = true
ns.db.conflictPicks = { ["DaylightUI:rolls"] = "ours" }
state, pick = ns.ConflictState("rolls")
Check("1 Ours: Roll Vision plays", state == row and pick == "ours", tostring(pick))
local hidden = row and row.hide and row.hide() or {}
Check("1 Ours: its window held hidden", hidden[1] == stack, #hidden)
ns.db.conflictPicks = {}

-- 2. Hide keybinds and Hide macro names.
local who, yieldRow = ns.FeatureYieldedTo("hideKeybinds")
Check("2 its bars: Hide keybinds stands aside for good", who == "DaylightUI" and yieldRow == nil, who)
Check("2 its bars: Hide macro names too", ns.FeatureYieldedTo("hideMacroText") == "DaylightUI")
ns.MakeLazyPages("dlsupport")
local foundKeys = ns.FindEntryOf and ns.FindEntryOf("hideKeybinds")
local foundMacros = ns.FindEntryOf and ns.FindEntryOf("hideMacroText")
local foundBook = ns.FindEntryOf and ns.FindEntryOf("barsWithSpellbook")
pcall(ns.FindSetting, "barsWithSpellbook")
Check("2 the page has no Hide keybinds checkbox", foundKeys == nil or foundKeys.control == nil)
Check("2 nor Hide macro names", foundMacros == nil or foundMacros.control == nil)
Check("2 Show while the spellbook is open still there", foundBook ~= nil)

-- 3. Left alone.
ns.BuildManagedList() -- (runs the support files' scanners)
Check("3 its setup window left alone", ns.IsLeftAlone("DaylightUIInstaller"))
Check("3 its Welcome back line left alone", ns.IsLeftAlone("DaylightUIWelcomeHolder"))
Check("3 the Escape menu (its lines on it) left alone", ns.IsLeftAlone("GameMenuFrame"))
Check("3 its screen dim left alone", ns.IsLeftAloneFrame(veil))
Check("3 its reveal outlines left alone", ns.IsLeftAloneFrame(outline1) and ns.IsLeftAloneFrame(outline2))
Check("3 and the light over one", ns.IsLeftAloneFrame(outline1.shine))
Check("3 its chat bubble over a game bubble left alone", ns.IsLeftAloneFrame(bubbleCopy))
Check("3 a frame of nobody's isn't", not ns.IsLeftAloneFrame(CreateFrame("Frame", nil, UIParent)))
C_AddOns.IsAddOnLoaded = IsLoaded -- luacheck: ignore 122

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
