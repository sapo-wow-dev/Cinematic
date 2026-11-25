-- EllesmereUI's stand-aside rows (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/euiyields.lua < /dev/null
-- The addon kit's first run with EllesmereUI (qb025, 2026-11-25) showed two
-- of our features with nothing to work on under it: Hide keybinds and Hide
-- macro names (its bars draw their own buttons and texts; ours reached only
-- the game's pet and stance buttons it keeps) and Heal Vision on the game's
-- party and raid frames (its own replace them). Each now stands aside while
-- its part is loaded (an Addon Conflicts row, pick Theirs by default), and
-- comes back with Ours. Its rows were also never on the Addon Conflicts page
-- with EllesmereUI alone: it's in that page's list now. Says PASS or FAIL.

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc")

-- A stand-in for the game's pet button 1 and its key text (alpha recorded).
local function Text()
	local t = { alpha = 1 }
	function t.SetAlpha(self, a) self.alpha = a end
	function t.SetVertexColor() end
	function t.SetTextColor() end
	return t
end
local hotkey, name = Text(), Text()
rawset(_G, "PetActionButton1", { HotKey = hotkey, Name = name })

ns.db.hideKeybinds, ns.db.hideMacroText = true, true
ns.ApplyHideKeybinds()
Check("1 no EllesmereUI: Hide keybinds fades the pet button's key", hotkey.alpha == 0, hotkey.alpha)
Check("1 no EllesmereUI: Hide macro names fades its name", name.alpha == 0, name.alpha)
Check("1 no EllesmereUI: nothing yields", ns.FeatureYieldedTo("hideKeybinds") == nil)

-- Heal Vision on: its page and every switch above it, ticked to Always.
local switch = "handleHealVision"
while switch do
	ns.db[switch] = true
	switch = ns.PageSwitchOf(switch)
end
ns.db.healVision = true
-- (No rule deciding instead of the tick: the row's default rule reads the
-- offline stand-in's facts, no group, as off.)
ns.RuleFactsNow = nil
local framesBefore, platesBefore = ns.HealVisionHere(), ns.HealVisionHere(nil, true)
Check("1 no EllesmereUI: Heal Vision on the frames", framesBefore == true, framesBefore)

-- Its action bars and raid frames load (their setups run).
local IsLoaded = C_AddOns.IsAddOnLoaded
local loaded = { EllesmereUI = true, EllesmereUIActionBars = true, EllesmereUIRaidFrames = true }
C_AddOns.IsAddOnLoaded = function(addon) return loaded[addon] or false end -- luacheck: ignore 122
for addon in pairs(loaded) do wow.Fire("ADDON_LOADED", addon) end

Check("2 its bars: Hide keybinds yields to it", ns.FeatureYieldedTo("hideKeybinds") == "EllesmereUI",
	ns.FeatureYieldedTo("hideKeybinds"))
Check("2 its bars: Hide macro names yields to it", ns.FeatureYieldedTo("hideMacroText") == "EllesmereUI")
ns.ApplyHideKeybinds()
Check("2 its bars: the pet button's key given back", hotkey.alpha == 1, hotkey.alpha)
Check("2 its bars: its name given back", name.alpha == 1, name.alpha)
Check("2 settings kept for later", ns.db.hideKeybinds == true and ns.db.hideMacroText == true)
Check("2 its raid frames: Heal Vision off on the frames", ns.HealVisionHere() == false)
Check("2 its raid frames: Heal Vision's plates as before", ns.HealVisionHere(nil, true) == platesBefore,
	tostring(platesBefore))

-- Its rows: one each, in the Frames group (a group the page knows).
local rows = {}
for _, row in ipairs(ns.CONFLICTS) do
	if row.addon == "EllesmereUI" then rows[row.key] = row end
end
Check("3 a row for the button texts", rows.hideKeybinds and rows.hideKeybinds.group == "frames")
Check("3 a row for Heal Vision", rows.healVisionFrames and rows.healVisionFrames.group == "frames")
Check("3 hideMacroText shares the button texts row", rows.hideMacroText == nil)

-- Ours picked: our features play again.
ns.db.conflictPicks = { ["EllesmereUI:hideKeybinds"] = "ours", ["EllesmereUI:healVisionFrames"] = "ours" }
ns.ApplyHideKeybinds()
Check("4 Ours: Hide keybinds back on its pet button", hotkey.alpha == 0, hotkey.alpha)
Check("4 Ours: Heal Vision back on the frames", ns.HealVisionHere() == true)
C_AddOns.IsAddOnLoaded = IsLoaded -- luacheck: ignore 122

-- The page's list (Conflicts.lua ADDONS): EllesmereUI alone lists the page.
local text = io.open("Conflicts.lua"):read("*a")
local list = text:match("local ADDONS = (%b{})") or ""
Check("5 Addon Conflicts page listed with EllesmereUI alone", list:find('"EllesmereUI"', 1, true) ~= nil, list)
Check("5 the Frames group is the page's", text:find('{ key = "frames", label = "Frames" }', 1, true) ~= nil)

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
