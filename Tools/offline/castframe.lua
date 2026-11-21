-- The Cast Bars pages' unit frames (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/castframe.lua <forever|retail> < /dev/null
-- Unit Frames > Cast Bars shows each sample cast bar under its unit frame as
-- the Unit Frames preview draws it (user 2026-11-20: the drawn green and blue
-- bars over it looked nothing like the target frame), on the style lab's
-- real-layout stand-in (Tools/style-lab/frames.lua):
--   each sample has its unit frame, the game's frame copied in the game's look;
--   the cast bar under it as the game has it, room for buffs between, its
--   icon's left past the frame's left edge no further;
--   the two (target & focus, boss & arena) side by side, none on another,
--   all inside the preview;
--   joined to the frame (a theme's look), the bar right under its bars;
--   Your Cast Bar's: yours alone, no frame, unless joined.
-- Says PASS or FAIL per check; exits 1 on any FAIL.
local F = dofile("Tools/style-lab/frames.lua")
local client = ... or "forever"

-- luacheck: push ignore 111 112 113 121 122 212
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function(w)
	F.Install(w)
	rawset(_G, "CreateFontFamily", false)
end)
-- luacheck: pop

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print(("%s %s: %s%s"):format(ok and "PASS" or "FAIL", client, name, detail and (" (" .. tostring(detail) .. ")") or ""))
end

-- (The game's player frame, as both clients have it: its frames are copyable.)
local player = CreateFrame("Frame", "PlayerFrame", UIParent)
player.PlayerFrameContainer = CreateFrame("Frame", nil, player)
if ns.MakeLazyPages then ns.MakeLazyPages("castframe test") end
local db = ns.GetDB()
local function Shown(preview)
	local up = preview
	while up and up ~= UIParent do
		up:Show()
		if up:GetNumPoints() == 0 and up:GetParent() then
			up:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
			if (up:GetWidth() or 0) <= 0 then up:SetSize(800, 2000) end
		end
		up = up:GetParent()
	end
end
-- (Edges on the screen: each frame's own units times its scale.)
local function Box(f)
	local k = f:GetEffectiveScale()
	return f:GetLeft() * k, f:GetRight() * k, f:GetTop() * k, f:GetBottom() * k
end
local function Inside(a, b, slack)
	slack = slack or 1
	local al, ar, at, ab = Box(a)
	local bl, br, bt, bb = Box(b)
	return al >= bl - slack and ar <= br + slack and at <= bt + slack and ab >= bb - slack
end
local function Apart(a, b)
	local al, ar, at, ab = Box(a)
	local bl, br, bt, bb = Box(b)
	return ar <= bl + 1 or br <= al + 1 or ab >= bt - 1 or bb >= at - 1
end

local preview = ns.castPreviews and ns.castPreviews["Unit Cast Style"]
Check("the Cast Bars page's preview is there", preview ~= nil)
if not preview then os.exit(1) end
Shown(preview)

for _, look in ipairs({ "game", "theme" }) do
	db.styleGeneral = true
	db.ufStyle = look == "theme"
	db.ufShape = look == "theme" and "circle" or "game"
	preview:Refresh()
	for i, plate in ipairs(preview.plates) do
		local frame, bar = plate.unitFrame, preview.samples[i]
		Check(("%s look, sample %d: its unit frame shown"):format(look, i), frame and frame:IsShown())
		if frame then
			if look == "game" then
				Check(("game look, sample %d: the game's frame copied"):format(i), frame.unit.copy and frame.unit.copy.on,
					frame.unit.copyWhy)
			end
			local joined = bar:GetTop() and frame.unit.power:GetBottom() and bar:GetTop() > frame:GetBottom() - 1
			if not joined then
				-- (The frame's size takes in its buffs and target of target: the bar a little under all of it.)
				local room = frame:GetBottom() - bar:GetTop()
				Check(("%s look, sample %d: the cast bar a little under the frame and what hangs off it"):format(look, i),
					room >= 4 and room <= 14, room)
				local under = true
				for _, aura in ipairs(frame.unit.auras or {}) do
					if aura:IsShown() and aura:GetBottom() * aura:GetEffectiveScale() < bar:GetTop() * bar:GetEffectiveScale() - 0.5 then under = false end
				end
				Check(("%s look, sample %d: the cast bar under the buffs"):format(look, i), under)
				Check(("%s look, sample %d: its bar starts inside the frame's left"):format(look, i),
					bar:GetLeft() >= frame:GetLeft() - 1, bar:GetLeft() - frame:GetLeft())
			end
			Check(("%s look, sample %d: all inside the preview"):format(look, i), Inside(plate, preview, 2))
			local unit = frame.unit
			local shown = 0
			for _, aura in ipairs(unit.auras or {}) do if aura:IsShown() then shown = shown + 1 end end
			Check(("%s look, sample %d: a row of buffs and debuffs"):format(look, i), shown == 4, shown)
			Check(("%s look, sample %d: a boss's level a skull"):format(look, i), unit.skull and unit.skull:IsShown()
				and unit.badge.text:GetAlpha() == 0)
			if look == "game" then
				Check(("game look, sample %d: the boss dragon round its portrait"):format(i), unit.dragon and unit.dragon:IsShown())
			end
			if i == 1 then
				local tot = frame.tot
				Check(("%s look: the target's target of target, hung off it"):format(look), tot and tot:IsShown() and tot.hungOn == unit)
				Check(("%s look: the target of target inside the frame's size"):format(look), tot and Inside(tot, frame, 2))
				local clear = true
				for _, aura in ipairs(unit.auras or {}) do
					if aura:IsShown() and tot and not Apart(aura, tot) then clear = false end
				end
				Check(("%s look: the target of target clear of the target's buffs"):format(look), clear)
			end
		end
	end
	if #preview.plates == 2 then
		Check(("%s look: the two samples apart"):format(look), Apart(preview.plates[1], preview.plates[2]))
	end
end

-- The health and power texts, as the game's Status Text setting shows them:
-- off, none; Both, percent left and value right; Numeric, value of most.
do
	local cvars = { statusText = "0", statusTextDisplay = "BOTH" }
	local realGet, realC = GetCVar, C_CVar
	rawset(_G, "GetCVar", function(name) return cvars[name] or realGet(name) end)
	rawset(_G, "C_CVar", setmetatable({ GetCVar = function(name) return cvars[name] or realGet(name) end }, { __index = realC }))
	db.ufStyle, db.ufShape = false, "game"
	local frame = preview.plates[1].unitFrame
	local function Texts()
		local list = {}
		for side, text in pairs(frame.unit.healthTexts or {}) do
			if text:IsShown() then list[#list + 1] = side .. "=" .. tostring(text:GetText()) end
		end
		table.sort(list)
		return table.concat(list, " ")
	end
	preview:Refresh()
	Check("Status Text off: no bar texts", Texts() == "", Texts())
	cvars.statusText = "1"
	preview:Refresh()
	Check("Status Text Both: percent left, value right", Texts() == "LEFT=62% RIGHT=343 K", Texts())
	cvars.statusTextDisplay = "NUMERIC"
	preview:Refresh()
	Check("Status Text Numeric: value of most", Texts() == "CENTER=343 K / 554 K", Texts())
	rawset(_G, "GetCVar", realGet)
	rawset(_G, "C_CVar", realC)
end

-- Your Cast Bar: yours alone, no frame over it.
local mine = ns.castPreviews["Player Cast Style"]
Check("Your Cast Bar's preview is there", mine ~= nil)
if mine then
	Shown(mine)
	db.ufStyle, db.ufShape = false, "game"
	mine:Refresh()
	local plate = mine.plates[1]
	Check("Your Cast Bar: alone, no frame over it", plate.unitFrame and not plate.unitFrame:IsShown())
	Check("Your Cast Bar: inside its preview", Inside(plate, mine, 2))
end

if fails > 0 then
	print(("%d FAIL"):format(fails))
	os.exit(1)
end
print("all PASS")
