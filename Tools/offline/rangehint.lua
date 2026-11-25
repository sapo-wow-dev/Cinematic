-- Range Hint (UI/RangeHint.lua), offline (Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/rangehint.lua
-- Off by default. On: no target, a dead target or no attack spell on your
-- bars shows nothing; a target out of the spell's range fades the mark in
-- with the spell's name, back in range fades it out; no answer (a friend, a
-- secret answer) shows nothing; Auto picks the longest-range attack on your
-- bars; a picked spell wins over Auto; the page turned off hides it; no
-- target stops the watching. Its row and icon are wired (Show in section,
-- Interface hub). Both clients. PASS or FAIL lines.
-- luacheck: push ignore 111 112 113 121 122 143
package.path = "Tools/offline/?.lua;" .. package.path
local client = arg and arg[1] or "forever"
local wow = dofile("Tools/offline/wow.lua")
wow.Install(client)
local ns = {}
for line in io.lines("Cinematic.toc") do
	line = line:gsub("\r", "")
	if line ~= "" and not line:find("^#") then
		local chunk = loadfile((line:gsub("\\", "/")))
		if chunk then
			local ok, err = pcall(chunk, "Cinematic", ns)
			if not ok then wow.Warn(line .. ": " .. tostring(err)) end
		end
	end
end
wow.Fire("ADDON_LOADED", "Cinematic")
wow.Fire("PLAYER_LOGIN")

-- The game: your bars (slot -> spell), each spell's range and kind, the
-- target, and the range answer.
local SPELLS = {
	[116] = { name = "Frostbolt", range = 30, harmful = true },
	[2136] = { name = "Fire Blast", range = 20, harmful = true },
	[133] = { name = "Fireball", range = 35, harmful = true },
	[1459] = { name = "Arcane Intellect", range = 30, harmful = false },
	[6603] = { name = "Auto Attack", range = 0, harmful = true },
}
local bars = { [1] = 116, [2] = 2136, [3] = 1459, [4] = 6603 }
local target = { exists = false, dead = false }
local answer = {} -- spell id -> true, false or nil
local asked = {}
GetActionInfo = function(slot)
	if bars[slot] then return "spell", bars[slot] end
end
C_Spell = C_Spell or {}
C_Spell.GetSpellInfo = function(id)
	local spell = SPELLS[id]
	if spell then return { name = spell.name, maxRange = spell.range, minRange = 0 } end
end
C_Spell.GetSpellName = function(id) return SPELLS[id] and SPELLS[id].name end
C_Spell.IsSpellHarmful = function(id) return SPELLS[id] and SPELLS[id].harmful or false end
C_Spell.IsSpellHelpful = function(id) return SPELLS[id] and not SPELLS[id].harmful or false end
C_Spell.IsSpellInRange = function(id, unit)
	asked[#asked + 1] = id
	if unit == "target" and target.exists then return answer[id] end
end
UnitExists = function(unit) return unit == "target" and target.exists or unit == "player" end
UnitIsDeadOrGhost = function(unit) return unit == "target" and target.dead or false end
UnitClass = function() return "Mage", "MAGE" end
-- luacheck: pop

local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. client .. ": " .. text)
	if not ok then failed = failed + 1 end
end

local RH = ns.RangeHint
Check(RH and ns.RangeHintChoices and ns.RangeHintRefresh, "the file loaded")
if not RH then print("FAIL stopping: no ns.RangeHint"); os.exit(1) end
local frame = RH.frame
Check(_G.CinematicRangeHint == frame, "its frame is CinematicRangeHint (the HUD row's)")
Check(ns.DEFAULTS.showInRange == false and ns.DEFAULTS.handleRangeHint == true,
	"off by default: its icon's switch off, its page under it on (one switch turns it on)")
Check(ns.db.showInRange == false and not ns.RangeHintOn(), "a fresh profile: off")
-- No built-in profile turns it on: none writes its switches (check.lua's
-- snapshot of every built-in profile's settings, both clients), so each
-- has the defaults: off.
for _, c in ipairs({ "forever", "retail" }) do
	local file = io.open("Tools/offline/profile-settings-" .. c .. ".txt")
	local writes = {}
	if file then
		for line in file:lines() do
			if line:find("|showInRange=") or line:find("|handleRangeHint=") then writes[#writes + 1] = line end
		end
		file:close()
	end
	Check(file ~= nil and #writes == 0, ("%s: no built-in profile turns it on%s"):format(c,
		#writes > 0 and (": " .. table.concat(writes, ", ")) or ""))
end
Check(ns.DEFAULTS.rangeHintSpellMAGE == "auto", "each class asks Auto to start with")

-- Runs the frame's watcher for a while (as the game's frames would).
local function Run(seconds)
	local fn = frame:GetScript("OnUpdate")
	local t = 0
	while fn and t < seconds do
		fn(frame, 0.05)
		t = t + 0.05
		fn = frame:GetScript("OnUpdate")
	end
end
local function Target(exists, dead)
	target.exists, target.dead = exists, dead or false
	wow.Fire("PLAYER_TARGET_CHANGED")
end

-- Off: nothing runs. A target out of range shows nothing, nothing watches
-- (no per-frame work), no spell is asked, no Test, no Edit Mode box.
answer[116] = false
for i = #asked, 1, -1 do asked[i] = nil end
Target(true)
Run(1)
Check(RH.State().alpha == 0 and not RH.State().out, "off: a target out of range shows nothing")
Check(not RH.State().watching, "off: a new target starts no watching")
Check(#asked == 0, "off: no range asked of the game")
RH.Demo(3)
Check(not RH.Demoing() and not RH.State().watching, "off: the Test does nothing")
RH.EditEnter()
Check(not (RH.Mover() and RH.Mover():IsShown()), "off: no Edit Mode box")
RH.EditExit()

-- On.
ns.db.handleRangeHint = true
ns.db.showInRange = true
ns.db.handleFrames = true
ns.RangeHintRefresh()
Check(RH.Chosen() == 116, "Auto: the longest attack on your bars (Frostbolt 30 over Fire Blast 20; not the helpful 30)")
Run(0.15)
local s = RH.State()
Check(s.out and s.why == "out of range", "out of range: shown (" .. tostring(s.why) .. ")")
Check(s.alpha > 0 and s.alpha < 1, "it fades in, not at once (alpha " .. tostring(s.alpha) .. ")")
Run(1)
s = RH.State()
Check(s.alpha == 1, "faded fully in")
Check(s.name == "Frostbolt", "it says the spell's name (" .. tostring(s.name) .. ")")

answer[116] = true
Run(1)
s = RH.State()
Check(not s.out and s.why == "in range" and s.alpha == 0, "back in range: faded out, nothing shows")

answer[116] = nil
Run(0.5)
s = RH.State()
Check(not s.out and s.why == "no answer" and s.alpha == 0, "no answer (a friend, a secret): nothing shows")

answer[116] = false
Target(true, true)
Run(1)
s = RH.State()
Check(not s.out and s.why == "target dead", "a dead target: nothing shows")

-- A picked spell wins over Auto.
target.dead = false
ns.db.rangeHintSpellMAGE = 2136
answer[2136] = false
ns.RangeHintRefresh()
Run(1)
s = RH.State()
Check(s.spell == 2136 and s.out and s.name == "Fire Blast", "a picked spell (Fire Blast) is the one asked")
ns.db.rangeHintSpellMAGE = "auto"

-- The dropdown's list: Auto first, then the attacks by range.
local choices = ns.RangeHintChoices()
Check(choices[1].value == "auto" and choices[1].text:find("Frostbolt"), "the list: Auto (Frostbolt) first")
local ids = {}
for i = 2, #choices do ids[#ids + 1] = choices[i].value end
Check(table.concat(ids, ",") == "116,2136", "then the attacks with a range, longest first, no helpful, no melee ("
	.. table.concat(ids, ",") .. ")")

-- A spell put on your bars counts after the bars change.
bars[5] = 133
wow.Fire("ACTIONBAR_SLOT_CHANGED")
Check(RH.Chosen() == 133, "a longer attack put on your bars becomes Auto's (Fireball 35)")
bars[5] = nil
wow.Fire("ACTIONBAR_SLOT_CHANGED")

-- No attack on your bars.
local saved = bars
bars = { [1] = 1459 }
wow.Fire("ACTIONBAR_SLOT_CHANGED")
ns.RangeHintRefresh()
Run(1)
s = RH.State()
Check(not s.out and s.why == "no spell", "no attack on your bars: nothing shows")
bars = saved
wow.Fire("ACTIONBAR_SLOT_CHANGED")

-- The page off.
answer[116] = false
ns.RangeHintRefresh()
Run(1)
Check(RH.State().out, "(out of range again)")
ns.db.handleRangeHint = false
Run(1)
s = RH.State()
Check(not s.out and s.why == "off" and s.alpha == 0, "the page turned off: gone")
Check(not s.watching, "turned off with no refresh called: it stops watching by itself")
ns.db.showInRange = false
ns.db.handleRangeHint = true
Run(1)
Check(not RH.State().out, "the Show in switch off (its parent): gone too")
ns.db.showInRange = true

-- No target: it stops watching.
Target(false)
Run(1)
s = RH.State()
Check(not s.watching, "no target: it stops watching (no per-frame work)")
local before = #asked
Run(1)
Check(#asked == before, "and asks nothing more")

-- Edit Mode: the mark up as a sample with its box over it; a drag saves the
-- spot (shares of the screen) and moves the mark; right-click puts it back;
-- leaving Edit Mode hides the box and the sample. Page off: no box.
ns.db.handleRangeHint = false
RH.EditEnter()
Check(not (RH.Mover() and RH.Mover():IsShown()), "Edit Mode with the page off: no box")
RH.EditExit()
ns.db.handleRangeHint = true
RH.EditEnter()
Run(1)
local mover = RH.Mover()
s = RH.State()
Check(mover and mover:IsShown(), "Edit Mode: its box is shown")
Check(s.out and s.why == "edit mode" and s.alpha == 1, "Edit Mode: the mark shows as a sample, no target needed")
local w, h = UIParent:GetWidth(), UIParent:GetHeight()
mover.GetCenter = function() return 0.25 * w, 0.75 * h end -- (dropped there)
mover:GetScript("OnDragStop")(mover)
Check(ns.db.rangeHintX == 0.25 and ns.db.rangeHintY == 0.75, ("a drag saves the spot (%s, %s)"):format(
	tostring(ns.db.rangeHintX), tostring(ns.db.rangeHintY)))
mover.GetCenter = nil
mover:GetScript("OnClick")(mover, "RightButton")
Check(ns.db.rangeHintX == 0.25, "the right-click ending a drag doesn't reset it")
mover.draggedAt = nil
mover:GetScript("OnClick")(mover, "RightButton")
Check(ns.db.rangeHintX == ns.DEFAULTS.rangeHintX and ns.db.rangeHintY == ns.DEFAULTS.rangeHintY,
	"right-click puts it back to its first spot")
RH.EditExit()
Run(1)
s = RH.State()
Check(not mover:IsShown(), "leaving Edit Mode hides the box")
Check(not s.out and s.alpha == 0, "and the sample mark (no target)")

-- Wiring: the HUD row, its section and the Interface hub's icon.
local row
for _, item in ipairs(ns.COMBAT_SHOW or {}) do if item.key == "rangehint" then row = item end end
Check(row and row.page == "rangehint" and row.default == true, "the HUD row rangehint, in its own section, In combat ticked")
Check(ns.SHOW_IN_SWITCH.rangehint == "showInRange", "its Show in switch")
-- (Style: with its page, Style/RangeHintStyle.lua, only.)
local tabsWanted = ns.CreateRangeHintStylePanel and 3 or 2
Check(ns.ShowInTabs and #ns.ShowInTabs("range") == tabsWanted, "its icon's tabs: Show, Settings"
	.. (tabsWanted == 3 and ", Style" or ""))

print(failed == 0 and ("ALL PASS " .. client) or (failed .. " FAILED " .. client))
if failed > 0 then os.exit(1) end
