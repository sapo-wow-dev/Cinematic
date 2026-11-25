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

-- (Its chat part on for this character as our pages are made: it loads
-- after us. Read with no character, as the game's Forever client.)
local ENABLED = { DaylightUI = true, DaylightUI_Chat = true }
local ns, wow = dofile("Tools/offline/load.lua")("forever", arg and arg[1] or "CinematicDev.toc", function()
	rawset(C_AddOns, "GetAddOnEnableState", function(name, character)
		if character ~= nil then return 0 end -- (with a character: wrong on Forever)
		return ENABLED[name] and 2 or 0
	end)
	rawset(C_AddOns, "IsAddOnLoadable", function(name) return ENABLED[name] == true end)
end)
-- (Hooks run, as in the game: the stand-in's never do. Only ones made from
-- here on: the support's, and Addon Conflicts' holds.)
_G.hooksecurefunc = function(target, name, post) -- luacheck: ignore 122
	if type(target) == "string" then target, name, post = _G, target, name end
	local old = target[name]
	rawset(target, name, function(...)
		local a, b, c, d = old(...)
		post(...)
		return a, b, c, d
	end)
end

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
for _, frame in ipairs({ bubbleCopy, bubbleCopy.balloon }) do -- (alpha kept: the stand-in's isn't)
	rawset(frame, "SetAlpha", function(self, alpha) rawset(self, "_alphaNow", alpha) end)
	rawset(frame, "GetAlpha", function(self) return rawget(self, "_alphaNow") or 1 end)
end
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

-- 4. Its chat part on: the Chat Bubble Style page isn't made (its icon,
-- Chat's tab, the off-screen bubbles' Style button, Style General's row)
-- and the look stands aside for good (its copies hide the game's bubble ours
-- is on), with no Conflicts row. (The user, 2026-11-25.) Without it, the page
-- is there: Tools/offline/findcheck.lua finds Bubble Style's settings.
ns.db.styleGeneral, ns.db.bubblesStyle = true, true
Check("4 its chat part on: will load", ns.AddonWillLoad("DaylightUI_Chat") == true)
Check("4 an addon that's off: won't", ns.AddonWillLoad("DaylightUI_Bags") == false)
Check("4 the page left out", ns.PageGone("Bubble Style") == true)
Check("4 no Bubble Style page made", not (ns.HasOptionsPage and ns.HasOptionsPage("Bubble Style")),
	ns.HasOptionsPage and tostring(ns.HasOptionsPage("Bubble Style")) or "no HasOptionsPage")
local chatTab = false
for _, tab in ipairs(ns.ShowInTabs("chat")) do
	if tab[2] == "Bubble Style" then chatTab = true end
end
Check("4 no Bubble Style tab on the Chat icon", not chatTab)
Check("4 its bubble settings not found by search", ns.FindEntryOf("bubblesFont") == nil)
Check("4 our look stands aside", ns.StyleOn("bubblesStyle") == false)
local gone = ns.StylePageGone("bubblesStyle")
Check("4 for DaylightUI", gone ~= nil and gone.addon == "DaylightUI", gone and gone.addon)
Check("4 another Style page as before", ns.StylePageGone("tooltipStyle") == nil)
local bubbleRow
for _, each in ipairs(ns.CONFLICTS) do
	if each.key == "style:bubbles" and each.addon == "DaylightUI" then bubbleRow = each end
end
Check("4 no Chat bubble look row on the Conflicts page", bubbleRow == nil)
Check("4 the tooltip look's row still there", (function()
	for _, each in ipairs(ns.CONFLICTS) do
		if each.key == "style:tooltip" and each.addon == "DaylightUI" then return true end
	end
	return loaded.DaylightUI_Tooltip ~= true
end)())
C_AddOns.IsAddOnLoaded = IsLoaded -- luacheck: ignore 122

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
