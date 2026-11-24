-- The drain ring on tracked buff icons (UI/CooldownRing.lua), offline (Lua 5.1
-- via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/cdmring.lua < /dev/null
-- On stand-in icons with a plain stand-in amount (the game's is secret; the
-- StatusBars do the compare): no ring set = nothing made; Pips ring on a row =
-- 8 segments whose ranges split the shield's size from its description, the
-- ones the amount passes full; Smooth = 24; Bar / Liquid one bar 0..size; the
-- buff off you or the page off hides it; the last cast rank's size wins; a
-- row following the bar's ring takes it; no description = no ring. PASS/FAIL.
-- In game: /cine debug shieldprobe (step ring).
local amount = 44

-- luacheck: push ignore 111 112 113 121 122 212
local ns, wow = dofile("Tools/offline/load.lua")("forever", arg and arg[1], function()
	UnitGetTotalAbsorbs = function() return amount end
	C_Spell = C_Spell or {}
	C_Spell.GetSpellDescription = function(id)
		if id == 17 then return "Draws on the soul of the party member to shield them, absorbing 44 damage." end
		if id == 592 then return "Draws on the soul of the party member to shield them, absorbing 86 damage." end
		if id == 588 then return "A burst of Holy energy fills the caster. 20 charges." end
		return nil
	end
end)
-- luacheck: pop

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local db = ns.db
for _, start in ipairs({ "handleCooldowns", ns.CDM_TABS.buffs }) do
	local switch = start
	while switch do
		db[switch] = true
		switch = ns.PageSwitchOf(switch)
	end
end

-- StatusBars that remember their range, and say whether they're full.
local made = 0
local Make = CreateFrame
-- luacheck: push ignore 121
CreateFrame = function(kind, ...)
	local frame = Make(kind, ...)
	if kind == "StatusBar" then
		made = made + 1
		frame.SetMinMaxValues = function(self, lo, hi) self.lo, self.hi = lo, hi end
		frame.Full = function(self) return (self._value or 0) >= self.hi end
		frame.SetStatusBarColor = function(self, r, g, b) self.r, self.g, self.b = r, g, b end
	end
	return frame
end
-- luacheck: pop

local function Icon(id, linked, on)
	local icon = Make("Frame")
	icon.Icon = icon:CreateTexture()
	icon.spell, icon.linked, icon.auraInstanceID = id, linked, on and 7 or nil
	return icon
end
local shield = Icon(17, { 17, 592 }, true)
local fire = Icon(588, { 588 }, true)
local icons = { shield, fire }
ns.EachCooldownIcon = function(visit)
	for _, icon in ipairs(icons) do visit(icon, icon.spell, "BuffIconCooldownViewer") end
end
ns.IconCooldownInfo = function(icon) return { spellID = icon.spell, linkedSpellIDs = icon.linked } end
ns.Reachable = function() return true end

local function Lit(ring)
	local n = 0
	for _, seg in ipairs(ring.segs) do if seg:Full() then n = n + 1 end end
	return n
end

-- Nothing set.
ns.ApplyCooldownRing()
Check("no ring set: nothing made", ns.CooldownRingOf(shield) == nil and made == 0, made)

-- The page's look (Style > Cooldown Manager), its switch chain on.
local function PageLook(style, color)
	local switch = "cdmStyle"
	while switch do
		db[switch] = true
		switch = ns.PageSwitchOf(switch)
	end
	db.cdmRingStyle, db.cdmRingColor = style, color or db.cdmRingColor
end
PageLook("pips", "grad")

-- The shield's row On: the page's Pips.
ns.SetCooldownRow(17, "ring", "on")
ns.ApplyCooldownRing()
local ring = ns.CooldownRingOf(shield)
Check("row On, page Pips: 8 segments", ring and #ring.segs == 8, ring and #ring.segs)
Check("Pips: size from the description (44)", ring and ring.size == 44, ring and ring.size)
Check("Pips: the segments split 0..44", ring and ring.segs[2].lo == 44 / 8 and ring.segs[8].lo == 44 * 7 / 8,
	ring and ring.segs[2].lo)
Check("full shield: all 8 lit", ring and Lit(ring) == 8, ring and Lit(ring))
Check("full shield: shown, the amount set", ring and ring.holder:IsShown() and ring.text:GetText() == 44)
Check("Green to red: the first segment red, the last green", ring and ring.segs[1].r > ring.segs[1].g
	and ring.segs[8].g > ring.segs[8].r)
amount = 26
ns.CooldownRingUpdate()
Check("26 of 44 left: 5 lit (26 > 22, not > 27.5)", Lit(ring) == 5, Lit(ring))
amount = 0
ns.CooldownRingUpdate()
Check("broken (0): none lit", Lit(ring) == 0, Lit(ring))
Check("not set: Inner Fire's row has no ring", ns.CooldownRingOf(fire) == nil)

-- Colors: White, One color.
PageLook("pips", "white")
ns.CooldownRingUpdate()
Check("White: every segment white", ring.segs[1].r > 0.9 and ring.segs[1].g > 0.9 and ring.segs[8].b > 0.9)
db.cdmRingR, db.cdmRingG, db.cdmRingB = 0.2, 0.4, 0.9
PageLook("pips", "custom")
ns.CooldownRingUpdate()
Check("One color: the swatch's", ring.segs[3].r == 0.2 and ring.segs[3].b == 0.9)

-- Gradient with ends of your own: blue empty, yellow full.
db.cdmGradEmptyR, db.cdmGradEmptyG, db.cdmGradEmptyB = 0.1, 0.3, 1
db.cdmGradFullR, db.cdmGradFullG, db.cdmGradFullB = 1, 0.9, 0.1
PageLook("pips", "grad")
ns.CooldownRingUpdate()
Check("Gradient, own ends: the first segment bluish, the last yellowish",
	ring.segs[1].b > ring.segs[1].r and ring.segs[8].r > ring.segs[8].b, ("%.2f %.2f"):format(ring.segs[1].b, ring.segs[8].r))
local r0, g0, b0 = ns.CooldownRingGradientAt(ns.CooldownRingLook(), 0)
Check("Gradient's start is the empty end's color", math.abs(r0 - 0.1) < 0.02 and math.abs(b0 - 1) < 0.02, r0 .. "," .. g0)
db.cdmGradEmptyR, db.cdmGradEmptyG, db.cdmGradEmptyB = nil, nil, nil
db.cdmGradFullR, db.cdmGradFullG, db.cdmGradFullB = nil, nil, nil
local rm, gm = ns.CooldownRingGradientAt(ns.CooldownRingLook(), 0.5)
Check("default Gradient's middle is yellowish (round the wheel, not brown)", rm > 0.6 and gm > 0.6, rm .. "," .. gm)

-- The amount nudged from the middle.
-- (The stand-in's GetPoint gives 0, 0 always: the text's SetPoint recorded.)
ring.text.SetPoint = function(self, point, _, _, x, y) self.at = { point, x, y } end
db.cdmAmountX, db.cdmAmountY = 5, -12
ns.CooldownRingUpdate()
local at = ring.text.at
Check("Amount X/Y: from the middle, offset", at and at[1] == "CENTER" and at[2] == 5 and at[3] == -12,
	at and (tostring(at[2]) .. "," .. tostring(at[3])))
db.cdmAmountX, db.cdmAmountY = nil, nil

-- A row saved with a style from before the page counts as On.
ns.SetCooldownRow(17, "ring", "smooth")
PageLook("pips")
ns.CooldownRingUpdate()
ring = ns.CooldownRingOf(shield)
Check("old row value (smooth): On, with the page's Pips", ring and ring.style == "pips" and ring.holder:IsShown())
ns.SetCooldownRow(17, "ring", "on")

-- The Amount column off: the ring stays, the number goes.
ns.SetCooldownRow(17, "ringAmount", false)
ns.CooldownRingUpdate()
Check("Amount hidden: the ring shown, no number", ring.holder:IsShown() and not ring.text:IsShown())
ns.SetCooldownRow(17, "ringAmount", nil)
ns.CooldownRingUpdate()
Check("Amount back to following (shown)", ring.text:IsShown())

-- The buff off you.
amount, shield.auraInstanceID = 44, nil
ns.CooldownRingUpdate()
Check("buff off you: hidden", not ring.holder:IsShown())
shield.auraInstanceID = 7

-- The last cast rank's size.
-- luacheck: push ignore 121
GetTime = function() return 10 end
-- luacheck: pop
wow.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 592)
Check("rank 2 cast (through the addon's event): its size (86)", ns.CooldownRingOf(shield).size == 86,
	ns.CooldownRingOf(shield).size)

-- The page's other styles.
PageLook("smooth")
ns.CooldownRingUpdate()
ring = ns.CooldownRingOf(shield)
Check("Smooth: 24 segments", ring and #ring.segs == 24, ring and #ring.segs)
PageLook("bar")
ns.CooldownRingUpdate()
ring = ns.CooldownRingOf(shield)
Check("Bar: one bar 0..size, set to the amount", ring and ring.bar and ring.bar.lo == 0 and ring.bar.hi == ring.size
	and ring.bar._value == 44)
PageLook("liquid")
ns.CooldownRingUpdate()
ring = ns.CooldownRingOf(shield)
Check("Liquid: one bar, vertical", ring and ring.bar and ring.liquid)

-- The page off: the ring keeps its own look (Pips), whatever the page says.
db.cdmStyle = false
ns.CooldownRingUpdate()
ring = ns.CooldownRingOf(shield)
Check("Style page off: the default look (Pips)", ring and ring.style == "pips" and ring.holder:IsShown(),
	ring and ring.style)
PageLook("pips")

-- The bar's row: a spell that follows takes it; no description = no ring.
ns.SetCooldownRow(17, "ring", nil)
ns.SetCooldownRow("buffs", "ring", "on")
ns.ApplyCooldownRing()
ring = ns.CooldownRingOf(shield)
Check("following the bar's On: the shield gets it", ring and ring.holder:IsShown())
Check("following, no absorb in its description: Inner Fire gets none",
	not ns.CooldownRingOf(fire) or not ns.CooldownRingOf(fire).holder:IsShown())

-- In a fight the walk's spell ID is secret (cdmring run 3: the ring froze):
-- the icon's spell and size from before are used, the amount still set.
ns.SetCooldownRow("buffs", "ring", nil)
ns.SetCooldownRow(17, "ring", "on")
ns.CooldownRingUpdate()
-- luacheck: push ignore 121 122
local realSecret = issecretvalue
issecretvalue = function(v) return v == "SECRET" end
ns.EachCooldownIcon = function(visit) visit(shield, "SECRET", "BuffIconCooldownViewer") end
ns.IconCooldownInfo = function() return { spellID = "SECRET" } end
amount = 26
-- (The icon's width is secret in a fight too: cdmring run 4, 39 errors.)
ns.CooldownRingOf(shield).holder.GetWidth = function() return "SECRET" end
local errorsBefore = ns.CooldownRingStats.errors
ns.CooldownRingUpdate()
ring = ns.CooldownRingOf(shield)
Check("fight (secret spell ID): no error", ns.CooldownRingStats.errors == errorsBefore, ns.CooldownRingStats.lastError)
-- (Its size is the rank 2 cast's, 86: 26 left lights 3 of 8.)
Check("fight: still shown, the hit taken (3 of 8 lit, size 86)", ring.holder:IsShown() and ring.size == 86
	and Lit(ring) == 3, Lit(ring) .. ", size " .. tostring(ring.size))
issecretvalue = realSecret
ns.EachCooldownIcon = function(visit)
	for _, icon in ipairs(icons) do visit(icon, icon.spell, "BuffIconCooldownViewer") end
end
ns.IconCooldownInfo = function(icon) return { spellID = icon.spell, linkedSpellIDs = icon.linked } end
-- luacheck: pop

-- The Style page's preview: three stand-in icons, rings by the same code.
if ns.MakeCdmStylePreview then
	PageLook("pips", "class")
	local preview = ns.MakeCdmStylePreview(UIParent, 480)
	preview:Refresh()
	-- (The samples sit in one group under the preview, 2026-11-23.)
	local function Samples()
		local list = {}
		for _, kid in ipairs({ preview:GetChildren() }) do
			for _, icon in ipairs({ kid:GetChildren() }) do
				if ns.CooldownRingOf(icon) then list[#list + 1] = icon end
			end
		end
		return list
	end
	local samples = Samples()
	local full = samples[1] and ns.CooldownRingOf(samples[1])
	Check("preview: three samples with rings", #samples == 3, #samples)
	Check("preview: the full sample's 8 pips lit", full and Lit(full) == 8, full and Lit(full))
	PageLook("bar")
	preview:Refresh()
	Check("preview follows the page (Bar)", samples[1] and ns.CooldownRingOf(samples[1]).style == "bar")
else
	Check("preview: Style loaded offline", false, "ns.MakeCdmStylePreview missing")
end

-- Charges (2026-11-23): Lightning Shield, "3 charges", no absorb: the ring
-- drains by the aura's count (the game icon's auraDataCached.applications),
-- whole pips per charge; one with no "N charges" takes the most seen.
do
	local describe = C_Spell.GetSpellDescription
	C_Spell.GetSpellDescription = function(id) -- luacheck: ignore 122
		if id == 324 then return "Surrounds the caster with balls of lightning. The shield has 3 charges. Lasts 10 min." end
		return describe(id)
	end
	local ls = Icon(324, { 324 }, true)
	ls.auraDataCached = { applications = 3 }
	local quiet = Icon(325, { 325 }, true) -- (no description: charges seen)
	quiet.auraDataCached = { applications = 4 }
	local plainBuff = Icon(326, { 326 }, true) -- (neither)
	plainBuff.auraDataCached = { applications = 0 }
	icons[#icons + 1], icons[#icons + 2], icons[#icons + 3] = ls, quiet, plainBuff
	PageLook("pips", "class")
	db.handleCooldowns = true
	for _, id in ipairs({ 324, 325, 326 }) do ns.SetCooldownRow(id, "ring", "on") end
	ns.ApplyCooldownRing()
	ring = ns.CooldownRingOf(ls)
	Check("charges: a ring, size 3 from the description", ring and ring.holder:IsShown() and ring.size == 3,
		ring and ring.size)
	-- (One pip per charge, 2026-11-23: Lightning Shield 3 pips, not 8.)
	Check("charges: 3 pips, one per charge", ring and #ring.segs == 3, ring and #ring.segs)
	Check("charges: 3 of 3, all lit, the number 3", ring and Lit(ring) == 3 and ring.text:GetText() == 3,
		ring and Lit(ring))
	-- (The game's corner count hidden while ours shows: "3" twice, 2026-11-23.)
	ls.Applications = CreateFrame("Frame", nil, ls)
	-- (The stand-in's GetAlpha is always 1: this one keeps it.)
	ls.Applications.SetAlpha = function(self, a) self.alpha = a end
	ls.Applications.GetAlpha = function(self) return self.alpha or 1 end
	ns.CooldownRingUpdate()
	Check("charges: the game's corner count hidden", ls.Applications:GetAlpha() == 0, ls.Applications:GetAlpha())
	ns.SetCooldownRow(324, "ringAmount", false)
	ns.CooldownRingUpdate()
	Check("Amount Hide: no number, the game's stays hidden too", ls.Applications:GetAlpha() == 0
		and not ns.CooldownRingOf(ls).text:IsShown(), ls.Applications:GetAlpha())
	ns.SetCooldownRow(324, "ringAmount", nil)
	ls.auraDataCached.applications = 2
	ns.CooldownRingUpdate()
	Check("charges: 2 left, 2 of 3 lit", Lit(ring) == 2 and ring.text:GetText() == 2, Lit(ring))
	ls.auraDataCached.applications = 1
	ns.CooldownRingUpdate()
	Check("charges: 1 left, 1 of 3 lit", Lit(ring) == 1, Lit(ring))
	PageLook("smooth")
	ns.CooldownRingUpdate()
	Check("Smooth on charges: its 24 steps still", #ns.CooldownRingOf(ls).segs == 24, #ns.CooldownRingOf(ls).segs)
	PageLook("pips")
	ns.CooldownRingUpdate()
	ring = ns.CooldownRingOf(ls)
	ls.auraInstanceID = nil
	ns.CooldownRingUpdate()
	Check("charges: the buff gone, hidden", not ring.holder:IsShown())
	Check("the ring gone: the game's count back", ls.Applications:GetAlpha() == 1, ls.Applications:GetAlpha())
	local q = ns.CooldownRingOf(quiet)
	Check("no \"N charges\": the most seen (4) is its size, 4 pips", q and q.holder:IsShown() and q.size == 4
		and #q.segs == 4, q and q.size)
	-- (The most seen kept in the saved data: after a /reload, with the buff
	-- not on you, the page still offers its Ring. cdmring q5af4.)
	Check("the most seen saved (4)", type(db.cdmRingCharges) == "table" and db.cdmRingCharges[325] == 4,
		db.cdmRingCharges and db.cdmRingCharges[325])
	db.cdmRingCharges[777] = 5 -- (as if seen before a /reload: no icon, no description)
	Check("saved count only: it fits, its most is 5", ns.CooldownRingFits(777) == true
		and ns.CooldownRingMostCharges(nil, 777) == 5)
	db.cdmRingCharges[777] = nil
	-- (After a /reload with a charge used: saved 3, first count seen 2. The
	-- ring stays 3 pips, not 2; the user 2026-11-23.)
	db.cdmRingCharges[778] = 3
	local used = Icon(778, { 778 }, true)
	used.auraDataCached = { applications = 2 }
	Check("reload, a charge used: most stays the saved 3, not the 2 seen",
		ns.CooldownRingMostCharges(used, 778) == 3, ns.CooldownRingMostCharges(used, 778))
	Check("the saved 3 not lowered", db.cdmRingCharges[778] == 3, db.cdmRingCharges[778])
	db.cdmRingCharges[778] = nil
	-- (Inner Fire, 20 charges: 20 pips; more than 20: the 8.)
	fire.auraDataCached = { applications = 20 }
	ns.SetCooldownRow(588, "ring", "on")
	ns.CooldownRingUpdate()
	local f = ns.CooldownRingOf(fire)
	Check("20 charges: 20 pips, all lit", f and #f.segs == 20 and Lit(f) == 20, f and #f.segs)
	ns.SetCooldownRow(588, "ring", nil)
	fire.auraDataCached = nil
	local p = ns.CooldownRingOf(plainBuff)
	Check("no absorb, no charges: no ring", not p or not p.holder:IsShown())
	Check("Fits: the charges buff yes, the plain one no", ns.CooldownRingFits(324) == true and ns.CooldownRingFits(326) == false)
	Check("Fits: still the shield", ns.CooldownRingFits(17) == true)
	for _, id in ipairs({ 324, 325, 326 }) do ns.SetCooldownRow(id, "ring", nil) end
	for _ = 1, 3 do table.remove(icons) end
	C_Spell.GetSpellDescription = describe -- luacheck: ignore 122
end

-- The page off.
db.handleCooldowns = false
ns.CooldownRingUpdate()
Check("page off: hidden", not ns.CooldownRingOf(shield).holder:IsShown())

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
