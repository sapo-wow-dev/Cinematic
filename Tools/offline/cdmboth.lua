-- A spell's cooldown drawn over its DoT (UI/CooldownBoth.lua), offline (Lua
-- 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/cdmboth.lua < /dev/null
-- On stand-in Essential icons with a stand-in duration object (the game's
-- reads are secret in fights; its curves and bars do the work): nothing set =
-- nothing drawn; Shows Both on a spell with a cooldown = its look drawn while
-- its DoT is up, hidden when it's down; Both on a DoT with no cooldown of its
-- own = nothing; Cooldown (true) = the old swap, not Both; each look (ring,
-- edge, row with 4 / 8 / 12, bar, corner) lights what's left; the page off
-- hides it. PASS/FAIL. In game: /cine debug cdmboth (the probe, then the
-- built feature's steps).
local left, total = 0.5, 30 -- the stand-in cooldown: share left, seconds
local fighting = false -- every size unreadable while true (a fight)

-- luacheck: push ignore 111 112 113 121 122 212
local ns = dofile("Tools/offline/load.lua")("forever", arg and arg[1], function()
	-- (A step curve: its points, evaluated as the game does.)
	C_CurveUtil = { CreateCurve = function()
		local c = { points = {} }
		function c:SetType() end
		function c:AddPoint(x, y) table.insert(self.points, { x, y }) end
		function c:Evaluate(x)
			local y = 0
			for _, p in ipairs(self.points) do if x >= p[1] then y = p[2] end end
			return y
		end
		return c
	end }
	Enum = Enum or {}
	Enum.LuaCurveType = { Linear = 0, Step = 1 }
	C_Spell = C_Spell or {}
	C_Spell.GetSpellCooldownDuration = function()
		return {
			EvaluateRemainingPercent = function(_, curve) return curve:Evaluate(left) end,
			GetRemainingDuration = function() return left * total end,
			GetRemainingPercent = function() return left end,
		}
	end
	GetSpellBaseCooldown = function(id) return id == 980 and 0 or 30000 end
end)
-- luacheck: pop

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local db = ns.db
local switch = "handleCooldowns"
while switch do
	db[switch] = true
	switch = ns.PageSwitchOf(switch)
end
switch = "cdmStyle"
while switch do
	db[switch] = true
	switch = ns.PageSwitchOf(switch)
end

-- Alpha, a bar's timer and text remembered on the stand-ins.
local Make = CreateFrame
local function Remember(region)
	region.SetAlpha = function(self, a) self.alpha = a end
	region.GetAlpha = function(self) return self.alpha or 1 end
	return region
end
-- luacheck: push ignore 121
CreateFrame = function(kind, ...)
	local frame = Make(kind, ...)
	local MakeTexture = frame.CreateTexture
	frame.CreateTexture = function(...) return Remember(MakeTexture(...)) end
	local MakeText = frame.CreateFontString
	frame.CreateFontString = function(...)
		local fs = Remember(MakeText(...))
		fs.SetFormattedText = function(self, fmt, ...) self.text = fmt:format(...) end
		return fs
	end
	if kind == "StatusBar" then
		frame.SetTimerDuration = function(self, dur) self.timer = dur end
	end
	frame.GetWidth = function() if fighting then return nil end return 40 end -- (secret in a fight: nil here)
	return frame
end
-- luacheck: pop

local function Icon(id, dotUp)
	local icon = CreateFrame("Frame")
	icon.Icon = icon:CreateTexture()
	icon.spell = id
	icon.wasSetFromAura, icon.auraInstanceID = dotUp, dotUp and 9 or nil
	return icon
end
local cd = Icon(172, true) -- a spell with a cooldown (30 s) and a DoT up
local dot = Icon(980, true) -- a DoT with no cooldown of its own
local icons = { cd, dot }
-- (Hidden icons, the Cooldown Manager hidden out of a fight, only with all:
-- as the game's walk, Frames.lua's EachCooldownIcon.)
ns.EachCooldownIcon = function(visit, all)
	for _, icon in ipairs(icons) do
		if all or not icon.hiddenIcon then visit(icon, icon.spell, "EssentialCooldownViewer") end
	end
end
ns.Reachable = function() return true end

local function Lit(d)
	local n = 0
	for _, piece in ipairs(d.pieces) do if piece:GetAlpha() == 1 then n = n + 1 end end
	return n
end
local function Shown(icon)
	local d = ns.CooldownBothOf(icon)
	return d ~= nil and d.holder:IsShown()
end

-- Nothing set.
ns.ApplyCooldownBoth()
Check("nothing set: nothing drawn", ns.CooldownBothOf(cd) == nil)
-- (The base is Cooldown: DEFAULTS.cooldownSpellNotBuff, Core.lua.)
Check("nothing set: the base Cooldown, the swap as before", ns.CooldownNoBuffOn(172, "essential")
	and not ns.CooldownBothOn(172, "essential"))

-- Cooldown (the old Own cooldown on): the swap, not Both.
ns.SetCooldownRow(172, "notBuff", true)
ns.ApplyCooldownBoth()
Check("Cooldown: the swap is on", ns.CooldownNoBuffOn(172, "essential"))
Check("Cooldown: not Both, nothing drawn", not ns.CooldownBothOn(172, "essential") and not Shown(cd))

-- Both, the page's look Ring with 8.
ns.SetCooldownRow(172, "notBuff", "both")
db.cdmBothLook, db.cdmBothPips = "ring", 8
ns.ApplyCooldownBoth()
local d = ns.CooldownBothOf(cd)
Check("Both: no swap (the DoT stays the game's)", not ns.CooldownNoBuffOn(172, "essential"))
Check("Both, Ring 8: 8 pieces", d and #d.pieces == 8, d and #d.pieces)
Check("Both, half left: 4 of 8 lit", d and Lit(d) == 4, d and Lit(d))
left = 0.3
ns.CooldownBothUpdate()
Check("0.3 left: 3 of 8 lit (0.3 > 0.25, not > 0.375)", Lit(d) == 3, Lit(d))
left = 0
ns.CooldownBothUpdate()
Check("ready (0 left): none lit, still shown while the DoT is up", Lit(d) == 0 and Shown(cd), Lit(d))
left = 1
ns.CooldownBothUpdate()
Check("just cast: all 8 lit", Lit(d) == 8, Lit(d))

-- A DoT with no cooldown of its own: nothing, even set to Both.
ns.SetCooldownRow(980, "notBuff", "both")
ns.CooldownBothUpdate()
Check("Both on a DoT with no cooldown: nothing drawn", not Shown(dot))

-- The DoT down: the game shows the cooldown itself; ours hides.
cd.wasSetFromAura, cd.auraInstanceID = false, nil
ns.CooldownBothUpdate()
Check("DoT down: hidden", not Shown(cd))
cd.wasSetFromAura, cd.auraInstanceID = true, 9
ns.CooldownBothUpdate()
Check("DoT up again: shown", Shown(cd))

-- Each look and count.
left = 0.5
for _, case in ipairs({ { "edge", 4, 2 }, { "edge", 12, 6 }, { "row", 8, 4 }, { "row", 12, 6 }, { "ring", 4, 2 },
	{ "ring", 12, 6 } }) do
	db.cdmBothLook, db.cdmBothPips = case[1], case[2]
	ns.CooldownBothUpdate()
	local e = ns.CooldownBothOf(cd)
	Check(("%s %d: %d pieces, %d lit at half"):format(case[1], case[2], case[2], case[3]),
		e and e.kind == case[1] and #e.pieces == case[2] and Lit(e) == case[3], e and (#e.pieces .. "/" .. Lit(e)))
end
db.cdmBothLook = "bar"
ns.CooldownBothUpdate()
local b = ns.CooldownBothOf(cd)
Check("Bar under: a timer bar on the duration", b and b.kind == "bar" and b.bar.timer ~= nil)
db.cdmBothLook = "corner"
ns.CooldownBothUpdate()
local c = ns.CooldownBothOf(cd)
Check("Corner number: 15 (half of 30)", c and c.text.text == "15" and c.text:GetAlpha() == 1, c and c.text.text)
left = 0
ns.CooldownBothUpdate()
Check("Corner number at 0: hidden by its curve", c.text:GetAlpha() == 0, c.text:GetAlpha())
left = 0.5

-- A bad look saved: Ring 8.
db.cdmBothLook, db.cdmBothPips = "nope", 5
ns.CooldownBothUpdate()
local r = ns.CooldownBothOf(cd)
Check("unknown look and count: Ring 8", r and r.kind == "ring" and #r.pieces == 8)

-- The bar's row set to Both: its spells follow.
ns.SetCooldownRow(172, "notBuff", nil)
ns.SetCooldownRow("essential", "notBuff", "both")
ns.CooldownBothUpdate()
Check("the bar's row Both: its spell follows", Shown(cd))
ns.SetCooldownRow("essential", "notBuff", nil)
ns.ApplyCooldownBoth()
Check("nothing Both: hidden", not Shown(cd))

-- The page's switch off: hidden.
ns.SetCooldownRow(172, "notBuff", "both")
ns.ApplyCooldownBoth()
db.handleCooldowns = false
ns.CooldownBothUpdate()
Check("page off: hidden", not Shown(cd))
db.handleCooldowns = true

-- A first draw in a fight, where the icon's size reads secret (nil here): the
-- size kept from before the DoT was up (game run 4: ring, edge and row drew
-- nothing, made in a fight with no size).
-- (Hidden out of the fight too: the full run's case, the bar hidden till
-- the fight, so its size read only on a walk that takes hidden icons.)
local fresh = Icon(172, false)
fresh.Icon.GetWidth = function() if fighting then return nil end return 36 end
fresh.hiddenIcon = true
icons[#icons + 1] = fresh
db.cdmBothLook, db.cdmBothPips = "row", 8
ns.CooldownBothUpdate() -- (out of a fight, the DoT down: hidden, its size kept)
Check("before the DoT: nothing drawn", not Shown(fresh))
fighting = true
fresh.hiddenIcon = false -- (the fight: the bar shows)
fresh.wasSetFromAura, fresh.auraInstanceID = true, 9
for _, look in ipairs({ "row", "edge", "ring" }) do
	db.cdmBothLook = look
	ns.CooldownBothUpdate()
	local f = ns.CooldownBothOf(fresh)
	Check(("first drawn in a fight, %s: sized from before (36)"):format(look), f and f.width == 36, f and f.width)
end
icons[#icons] = nil
fighting = false

-- Every icon's size read, Both or not, and kept per bar (qd5a0: the DoT's
-- icon took another bar's 44 where its own was 50).
dot.Icon.GetWidth = function() return 50 end
ns.CooldownBothUpdate()
local own = ns.CooldownBothWidth(dot, "EssentialCooldownViewer")
Check("an icon not set to Both: its size read too (50)", own == 50, own)
local _, other = ns.CooldownBothWidth(dot, "UtilityCooldownViewer")
Check("another bar's size kept apart (none read for Utility)", other == nil, other)

-- The preview's plain numbers.
local sample = CreateFrame("Frame")
sample.Icon = sample:CreateTexture()
db.cdmBothLook, db.cdmBothPips = "row", 8
local p = ns.CooldownBothDraw(sample, ns.CooldownBothLook(), nil, 0.75, 9)
Check("preview, plain 0.75: 6 of 8 lit", p and Lit(p) == 6, p and Lit(p))

print(fails == 0 and "ALL PASS" or (fails .. " FAIL"))
if fails > 0 then os.exit(1) end
