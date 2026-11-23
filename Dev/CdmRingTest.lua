-- /cine debug cdmring: the drain ring on a shield's tracked buff icon
-- (UI/CooldownRing.lua; ledger Tools/tests/cdm-shield-strength.md). On a
-- character with a shield (Power Word: Shield). What you do: have the shield
-- in Tracked Buffs (the button opens the game's Cooldown Manager settings),
-- cast it on yourself, then attack a mob. Steps:
--   1 shield  waits for a shield icon in Tracked Buffs, then your cast
--   2 styles  its row On; Pips, Smooth, Liquid, Bar from the Style page, in
--             a few colors: pieces made and shown, a shot of each
--   3 menu    the page's Tracked Buffs tab in Look: Ring and Amount, a shot
--   charges   shaman: Lightning Shield's ring by charges, out of a fight and in one
--   noshield  any character: Ring / Amount cells only on shields; a tracked
--             buff with a Ring set not in Other
--   4 stylepage  Style > Cooldown Manager on and off (shots); off, the ring's own look
--   4 fight   Pips through a fight: the ring set on every hit (no errors,
--             blocked), shots after the first hit and when the shield breaks
-- Your ring settings are put back after. Into CinematicDB.cdmRingTestLog.
local _, ns = ...

local function Secret(value) return issecretvalue and issecretvalue(value) or false end
local function Plain(value) return type(value) == "number" and not Secret(value) and value or nil end
local function Copy(value)
	if type(value) ~= "table" then return value end
	local copy = {}
	for k, v in pairs(value) do copy[k] = Copy(v) end
	return copy
end

local WORDS = { "Shield", "Barrier", "Ward" }
local function Shieldy(name)
	for _, word in ipairs(WORDS) do if type(name) == "string" and name:find(word, 1, true) then return true end end
	return false
end

-- The shield's tracked buff icon: { item, spell, name } or nil. Only one whose
-- description gives an absorb size (run 1 took the shaman's Lightning Shield,
-- named like a shield, no absorb: no ring, as it should be).
local function ShieldIcon()
	local found
	ns.EachCooldownIcon(function(icon, id, bar)
		if found or bar ~= "BuffIconCooldownViewer" then return end
		local spell = Plain(id)
		local name = spell and C_Spell.GetSpellName(spell)
		if type(name) == "string" and not Secret(name) and Shieldy(name)
			and ns.CooldownRingSizeFor and ns.CooldownRingSizeFor(icon) then
			found = { item = icon, spell = ns.BaseSpell and ns.BaseSpell(spell) or spell, name = name }
		end
	end, true)
	return found
end

local test = {}

-- The shield's icon and spell for this run, found (waiting for you to track
-- it if it isn't) without the verdicts: the later steps call it when step 1
-- is proven and left out (run 10: styles skipped, "no shield icon").
local function FindShield(r)
	if test.item then return true end
	local found = ShieldIcon()
	if not found then
		r:WaitFor("On your priest (or mage), add your shield (Power Word: Shield) to Tracked Buffs in the game's Cooldown Manager settings.", {
			check = function() return ShieldIcon() and "tracked" end,
			buttons = { { label = "Cooldown Manager settings", fn = function()
				local settings = _G.CooldownViewerSettings
				if settings then pcall(ShowUIPanel, settings) end
			end } } })
		found = ShieldIcon()
		local settings = _G.CooldownViewerSettings
		if settings and settings:IsShown() then pcall(HideUIPanel, settings) end
	end
	if not found then return false end
	test.item, test.spell, test.name = found.item, found.spell, found.name
	return true
end

-- The shield's row On, and the Style page's look (its switch on): style and color.
local function SetRing(r, style, color, spell)
	spell = spell or test.spell
	local all = Copy(ns.db.cooldownRowSettings) or {}
	all[spell] = all[spell] or {}
	all[spell].ring = "on"
	r:Set("cooldownRowSettings", all)
	r:Set("cdmStyle", true)
	r:Set("cdmRingStyle", style)
	if color then r:Set("cdmRingColor", color) end
	ns.ApplyCooldownRing()
end

ns.TestKit.Define({
	name = "cdmring",
	key = "cdmRingTest",
	title = "Shield drain ring",
	about = "the drain ring on a shield's tracked buff: 4 styles, the menu, a fight",
	needs = "A shield spell (Power Word: Shield) in Tracked Buffs, and a mob to fight",
	settings = { "cooldownRowSettings", "cdmStyle", "cdmRingStyle", "cdmRingColor" },
	steps = {
		{ key = "shield", proven = "cdmring runs 3-7 (2026-11-23, priest): PASS, size 44 after a /reload",
			title = "your shield, tracked and cast", run = function(r)
			if not ns.PageOn("handleCooldowns") then return r:Skip("the Cooldown Manager page is off") end
			-- (Every tracked buff, what the ring reads of it: run 2's tracked
			-- Power Word: Shield wasn't taken, no size after a /reload.)
			ns.EachCooldownIcon(function(icon, id, bar)
				if bar ~= "BuffIconCooldownViewer" then return end
				local spell = Plain(id)
				local okDesc, desc = pcall(C_Spell.GetSpellDescription, spell)
				r:Log(("  tracked %s %s: description %s, ring size %s"):format(tostring(spell),
					tostring(spell and C_Spell.GetSpellName(spell)), okDesc and (desc and #tostring(desc) .. " chars" or "nil") or "error",
					tostring(ns.CooldownRingSizeFor and ns.CooldownRingSizeFor(icon))))
			end, true)
			if not FindShield(r) then return r:Fail("no shield icon tracked") end
			r:Log(("  shield icon: %s (spell %s)"):format(tostring(test.name), tostring(test.spell)))
			if type(test.item.auraInstanceID) == "nil" then
				r:WaitFor("Cast " .. test.name .. " on yourself. Then attack a mob; the test does the rest.", {
					check = function() return type(test.item.auraInstanceID) ~= "nil" and "on" end })
			end
			r:Sleep(0.3)
			local size = ns.CooldownRingSizeFor and ns.CooldownRingSizeFor(test.item)
			r:Log("  size from the description: " .. tostring(size))
			r:Verdict(Plain(size) and size > 0, "the shield's size read: " .. tostring(size))
		end },
		-- (Proven in run 4 as row styles; from the Style page now, with its colors.)
		-- (Run 7 passed 6/6; the Gradient's own ends and the bar's two-layer
		-- fill since, 2026-11-23: again.)
		{ key = "styles", proven = "cdmring run 11 (2026-11-23, priest): PASS 6/6, shots: Gradient pips and bar red to green",
			title = "the four styles, from the Style page, with its colors", run = function(r)
			if not FindShield(r) then return r:Skip("no shield icon tracked") end
			for _, pick in ipairs({ { "pips", "class" }, { "pips", "grad" }, { "smooth", "white" }, { "liquid", "class" },
				{ "bar", "class" }, { "bar", "grad" } }) do
				local style, color = pick[1], pick[2]
				if type(test.item.auraInstanceID) == "nil" then
					r:WaitFor("Your shield ran out: cast " .. test.name .. " again.", {
						check = function() return type(test.item.auraInstanceID) ~= "nil" and "on" end })
				end
				SetRing(r, style, color)
				r:Sleep(0.4)
				local ring = ns.CooldownRingOf(test.item)
				local pieces = ring and (#ring.segs > 0 and #ring.segs or (ring.bar and 1)) or 0
				r:Verdict(ring and ring.style == style and ring.holder:IsVisible() and pieces > 0,
					("%s, %s: made %s, shown %s, %s piece(s), size %s"):format(style, color, tostring(ring ~= nil),
					tostring(ring and ring.holder:IsVisible()), tostring(pieces), tostring(ring and ring.size)))
				r:Shot(style .. ", " .. color, { behind = test.item, pad = 18 })
			end
		end },
		-- (Proven in run 6 with Ring's styles; On / Off since the Style page.)
		{ key = "menu", proven = "cdmring run 7 (2026-11-23, priest): PASS, On/Off Ring + Amount columns",
			title = "the Ring and Amount columns on the page", run = function(r)
			if InCombatLockdown() then return r:Skip("in a fight: the settings stay shut") end
			local ok, err = pcall(ns.OpenOptionsAt, "Cooldown Manager")
			if not ok then return r:Fail("couldn't open the page: " .. tostring(err)) end
			r:Sleep(0.4)
			pcall(ns.CdmShowSpells, "buffs")
			r:Sleep(0.3)
			if not ns.CdmPageGrid then return r:Fail("no page grid") end
			-- (Called plainly: "a and f()" keeps the first value alone, CdmGridTest run 1.)
			local grid, _, panel = ns.CdmPageGrid()
			if not (grid and grid:IsVisible()) then
				-- (Run 2, priest: not shown once; the game's Cooldown Manager
				-- settings may have been open over it. Shut, and again.)
				local settings = _G.CooldownViewerSettings
				r:Log(("  grid not shown: made %s, page on %s, game's CDM settings open %s, options open %s"):format(
					tostring(grid ~= nil), tostring(ns.PageOn("handleCooldowns")),
					tostring(settings and settings:IsShown()), tostring(SettingsPanel and SettingsPanel:IsShown())))
				if settings and settings:IsShown() then pcall(HideUIPanel, settings) end
				r:Sleep(0.6)
				pcall(ns.OpenOptionsAt, "Cooldown Manager")
				r:Sleep(0.6)
				pcall(ns.CdmShowSpells, "buffs")
				r:Sleep(0.4)
				grid, _, panel = ns.CdmPageGrid()
			end
			if not (grid and grid:IsVisible()) then return r:Fail("the grid isn't shown") end
			local click = grid.lookSwitch and grid.lookSwitch:GetScript("OnClick")
			if click then click(grid.lookSwitch, "LeftButton") end
			r:Sleep(0.4)
			local cols, ringCol, amountCol = grid.Columns(), false, false
			for _, col in ipairs(cols) do
				if col.look == "ring" then ringCol = true end
				if col.look == "ringAmount" then amountCol = true end
			end
			r:Verdict(ringCol and amountCol, ("Tracked Buffs Look: %d columns, Ring %s, Amount %s"):format(#cols,
				tostring(ringCol), tostring(amountCol)))
			r:Shot("Tracked Buffs, Look, the Ring column", { behind = panel })
			click = grid.showsSwitch and grid.showsSwitch:GetScript("OnClick")
			if click then click(grid.showsSwitch, "LeftButton") end
			if SettingsPanel and SettingsPanel:IsShown() then pcall(HideUIPanel, SettingsPanel) end
		end },
		-- Lightning Shield (2026-11-23): a tracked buff with no absorb had a Ring
		-- to set that never drew, and its Ring listed it in Other too. Any
		-- character: each tracked buff's Ring / Amount cells shown only if the
		-- ring can draw for it; with a Ring set on each, none of them in Other.
		{ key = "noshield", proven = "cdmring q0b14 + q33f1 (2026-11-23, shaman): PASS, not in Other; Ring shown with charges",
			title ="Ring only on shields, tracked buffs not in Other", run = function(r)
			if InCombatLockdown() then return r:Skip("in a fight: the settings stay shut") end
			if not ns.PageOn("handleCooldowns") then return r:Skip("the Cooldown Manager page is off") end
			local buffs = {}
			ns.EachCooldownIcon(function(_, id, bar)
				local spell = bar == "BuffIconCooldownViewer" and Plain(id)
				if spell then buffs[#buffs + 1] = ns.BaseSpell and ns.BaseSpell(spell) or spell end
			end, true)
			if #buffs == 0 then return r:Skip("nothing in Tracked Buffs") end
			-- (A Ring on each, as the bug's setting: put back after.)
			local all = Copy(ns.db.cooldownRowSettings) or {}
			for _, spell in ipairs(buffs) do
				all[spell] = all[spell] or {}
				all[spell].ring = "on"
			end
			r:Set("cooldownRowSettings", all)
			local ok, err = pcall(ns.OpenOptionsAt, "Cooldown Manager")
			if not ok then return r:Fail("couldn't open the page: " .. tostring(err)) end
			r:Sleep(0.4)
			pcall(ns.CdmShowSpells, "other")
			r:Sleep(0.3)
			local grid, _, panel, tabs = ns.CdmPageGrid()
			if not (grid and grid:IsVisible()) then return r:Fail("the grid isn't shown") end
			local inOther = {}
			if grid.state.tab == "other" then
				for _, row in ipairs(grid.rows) do if row.key ~= nil then inOther[row.key] = true end end
			end
			local wrong = {}
			for _, spell in ipairs(buffs) do
				if inOther[spell] then wrong[#wrong + 1] = tostring(C_Spell.GetSpellName(spell) or spell) end
			end
			r:Verdict(#wrong == 0, ("Other tab %s; tracked buffs in it: %s"):format(
				tostring(tabs and tabs[5] and tabs[5]:IsShown()), #wrong == 0 and "none" or table.concat(wrong, ", ")))
			pcall(ns.CdmShowSpells, "buffs")
			r:Sleep(0.3)
			if not grid.state.look then
				local click = grid.lookSwitch and grid.lookSwitch:GetScript("OnClick")
				if click then click(grid.lookSwitch, "LeftButton") end
				r:Sleep(0.4)
			end
			local ringAt
			for j, col in ipairs(grid.Columns()) do if col.look == "ring" then ringAt = j end end
			if not ringAt then return r:Fail("no Ring column on Tracked Buffs, Look") end
			for _, row in ipairs(grid.rows) do
				if row.key ~= nil and row.key ~= "buffs" and type(row.key) == "number" then
					local fits = ns.CooldownRingFits(row.key)
					local shown = row.cells[ringAt]:IsShown() and row.cells[ringAt + 1]:IsShown()
					local hidden = not row.cells[ringAt]:IsShown() and not row.cells[ringAt + 1]:IsShown()
					r:Verdict((fits and shown) or (not fits and hidden), ("%s: absorbs %s, Ring + Amount cells %s"):format(
						tostring(C_Spell.GetSpellName(row.key) or row.key), tostring(fits), shown and "shown" or hidden and "hidden" or "half"))
				end
			end
			r:Shot("Tracked Buffs, Look: Ring only on shields", { behind = panel })
			local click = grid.showsSwitch and grid.showsSwitch:GetScript("OnClick")
			if click then click(grid.showsSwitch, "LeftButton") end
			if SettingsPanel and SettingsPanel:IsShown() then pcall(HideUIPanel, SettingsPanel) end
		end },
		-- Charges (2026-11-23): a tracked buff with charges and no absorb
		-- (Lightning Shield) drains by its charges, the game icon's aura count
		-- (icon.auraDataCached.applications). Open: does the count still reach
		-- a StatusBar in a fight (secret or not)? Logged per change.
		{ key = "charges", proven = "cdmring q33f1 (2026-11-23, shaman): PASS 4/4, count secret in the fight but drawn, shots 8 pips at 3, 3 pips at 1",
			title = "Lightning Shield: the ring drains by charges", run = function(r)
			if not ns.PageOn("handleCooldowns") then return r:Skip("the Cooldown Manager page is off") end
			local function Find()
				local found
				ns.EachCooldownIcon(function(icon, id, bar)
					if found or bar ~= "BuffIconCooldownViewer" then return end
					local spell = Plain(id)
					spell = spell and (ns.BaseSpell and ns.BaseSpell(spell) or spell)
					if spell and not (ns.CooldownRingSizeFor and ns.CooldownRingSizeFor(icon))
						and ns.CooldownRingMostCharges(icon, spell) then
						found = { icon = icon, spell = spell, name = C_Spell.GetSpellName(spell) }
					end
				end, true)
				return found
			end
			local found = Find()
			if not found then
				r:WaitFor("On your shaman, add Lightning Shield to Tracked Buffs in the game's Cooldown Manager settings.", {
					check = function() return Find() and "tracked" end,
					buttons = { { label = "Cooldown Manager settings", fn = function()
						local settings = _G.CooldownViewerSettings
						if settings then pcall(ShowUIPanel, settings) end
					end } } })
				found = Find()
				local settings = _G.CooldownViewerSettings
				if settings and settings:IsShown() then pcall(HideUIPanel, settings) end
			end
			if not found then return r:Fail("no tracked buff with charges") end
			local icon, spell = found.icon, found.spell
			local most = ns.CooldownRingMostCharges(icon, spell)
			r:Log(("  charges buff: %s (%s), most %s, description charges %s"):format(tostring(found.name), tostring(spell),
				tostring(most), tostring(ns.CooldownRingDescriptionCharges(spell))))
			r:Verdict(ns.CooldownRingFits(spell) == true, "the page offers it a Ring (fits)")
			if type(icon.auraInstanceID) == "nil" then
				r:WaitFor("Cast " .. tostring(found.name) .. " on yourself.", {
					check = function() return type(icon.auraInstanceID) ~= "nil" and "on" end })
			end
			SetRing(r, "pips", "class", spell)
			r:Sleep(0.5)
			local function Count()
				local count = ns.CooldownRingCharges(icon)
				if count == nil then return "nil" end
				return Secret(count) and "secret" or tostring(count)
			end
			local function Lit(ring)
				local n = 0
				for _, seg in ipairs(ring and ring.segs or {}) do
					local ok, value = pcall(seg.GetValue, seg)
					local okMin, low = pcall(seg.GetMinMaxValues, seg)
					-- (Above the low end: "low + 0.01" missed full pips, the bar's value
				-- a float hair under, charges run 1: 0 of 8 lit, the shot all 8.)
				if ok and okMin and Plain(value) and Plain(low) and value > low then n = n + 1 end
				end
				return n
			end
			local ring = ns.CooldownRingOf(icon)
			r:Log(("  out of a fight: count %s, auraDataCached %s"):format(Count(), type(icon.auraDataCached)))
			r:Verdict(ring and ring.holder:IsVisible() and ring.size == most,
				("out of a fight: ring shown %s, size %s (most %s), %d of %d pips lit, count %s"):format(
				tostring(ring and ring.holder:IsVisible()), tostring(ring and ring.size), tostring(most), Lit(ring),
				ring and #ring.segs or 0, Count()))
			r:Shot("charges, out of a fight", { behind = icon, pad = 18 })
			-- The fight: let a mob hit you (each melee hit uses a charge).
			r:WaitFor("Attack a mob and let it hit you; the test does the rest.", { events = { "PLAYER_REGEN_DISABLED" } })
			local stats = ns.CooldownRingStats or {}
			local before = { errors = stats.errors or 0, charges = stats.charges or 0 }
			local changes, seen = 0, {}
			local listen = CreateFrame("Frame")
			listen:RegisterUnitEvent("UNIT_AURA", "player")
			listen:SetScript("OnEvent", function() changes = changes + 1 end)
			local last = Count()
			r:Log("  fight start: count " .. last)
			local ended = r:WaitFor(nil, { check = function()
				local now = Count()
				seen[now] = true
				if now ~= last then
					last = now
					r:Log(("  count %s, ring shown %s"):format(now, tostring(ring and ring.holder:IsVisible())))
				end
				if type(icon.auraInstanceID) == "nil" then return "charges gone" end
				if not InCombatLockdown() then return "fight over" end
			end })
			listen:UnregisterAllEvents()
			local kinds = {}
			for k in pairs(seen) do kinds[#kinds + 1] = k end
			r:Log(("  fight: %d aura changes, counts seen: %s, ended: %s"):format(changes, table.concat(kinds, " "),
				tostring(ended)))
			r:Shot("charges, the fight's end", { behind = icon, pad = 18 })
			local errors = (stats.errors or 0) - before.errors
			local drawn = (stats.charges or 0) - before.charges
			r:Log(("  ring in the fight: %d charge draws, %d errors (last: %s)"):format(drawn, errors, tostring(stats.lastError)))
			r:Verdict(not seen["nil"], "the count reached the ring in the fight (never nil): " .. table.concat(kinds, " "))
			r:Verdict(errors == 0 and drawn > 0, ("drawn by charges in the fight, no errors: %d draws, %d errors"):format(
				drawn, errors))
		end },
		-- One pip per charge (2026-11-23, the user: "automatic"): Pips on a
		-- charges buff draws as many pips as it has charges (art CdmRing<n>_*,
		-- new TGAs: load after /reload). No fight needed.
		{ key = "pipcount", proven = "cdmring qa6ee (2026-11-23, shaman): PASS 2/2, shot: 3 pips + one 3",
			title ="charges: one pip per charge", run = function(r)
			local found
			ns.EachCooldownIcon(function(icon, id, bar)
				if found or bar ~= "BuffIconCooldownViewer" then return end
				local spell = Plain(id)
				spell = spell and (ns.BaseSpell and ns.BaseSpell(spell) or spell)
				if spell and not (ns.CooldownRingSizeFor and ns.CooldownRingSizeFor(icon))
					and ns.CooldownRingMostCharges(icon, spell) then found = { icon = icon, spell = spell } end
			end, true)
			if not found then return r:Skip("no tracked buff with charges (Lightning Shield)") end
			local icon = found.icon
			if type(icon.auraInstanceID) == "nil" then
				r:WaitFor("Cast Lightning Shield on yourself.", {
					check = function() return type(icon.auraInstanceID) ~= "nil" and "on" end })
			end
			SetRing(r, "pips", "class", found.spell)
			r:Sleep(0.5)
			local most = ns.CooldownRingMostCharges(icon, found.spell)
			local ring = ns.CooldownRingOf(icon)
			local count = ns.CooldownRingCharges(icon)
			r:Verdict(ring and ring.holder:IsVisible() and #ring.segs == most,
				("pips %s for %s charges at most (count now %s)"):format(tostring(ring and #ring.segs), tostring(most),
				Secret(count) and "secret" or tostring(count)))
			-- (Each pip's art loaded: a texture path set on its track.)
			local missing = 0
			for _, track in ipairs(ring and ring.tracks or {}) do
				local ok, tex = pcall(track.GetTexture, track)
				if not ok or tex == nil then missing = missing + 1 end
			end
			r:Verdict(missing == 0, "every pip's art set: " .. missing .. " missing")
			r:Shot("one pip per charge", { behind = icon, pad = 18 })
		end },
		-- One number (2026-11-23, the user: "we have double numbers"): with
		-- our charges in the ring's middle, the game's corner count is hidden;
		-- Amount set to Hide, no number at all (the user, 2026-11-23). No fight needed.
		{ key = "onenumber", proven = "cdmring q4cdb (2026-11-23, shaman): PASS 2/2, Hide = no number, found after a /reload",
			title ="charges: our number, not the game's too; Hide = none", run = function(r)
			local found
			ns.EachCooldownIcon(function(icon, id, bar)
				if found or bar ~= "BuffIconCooldownViewer" then return end
				local spell = Plain(id)
				spell = spell and (ns.BaseSpell and ns.BaseSpell(spell) or spell)
				if spell and not (ns.CooldownRingSizeFor and ns.CooldownRingSizeFor(icon))
					and ns.CooldownRingMostCharges(icon, spell) then found = { icon = icon, spell = spell } end
			end, true)
			if not found then return r:Skip("no tracked buff with charges (Lightning Shield)") end
			local icon = found.icon
			if type(icon.auraInstanceID) == "nil" then
				r:WaitFor("Cast Lightning Shield on yourself.", {
					check = function() return type(icon.auraInstanceID) ~= "nil" and "on" end })
			end
			SetRing(r, "pips", "class", found.spell)
			r:Sleep(0.5)
			local apps = icon.Applications
			local function Alpha() return apps and Plain(apps:GetAlpha()) end
			local ring = ns.CooldownRingOf(icon)
			r:Verdict(ring and ring.text:IsShown() and Alpha() == 0, ("our number shown %s, the game's corner alpha %s"):format(
				tostring(ring and ring.text:IsShown()), tostring(Alpha())))
			r:Shot("charges: one number", { behind = icon, pad = 18 })
			local all = Copy(ns.db.cooldownRowSettings) or {}
			all[found.spell] = all[found.spell] or {}
			all[found.spell].ringAmount = false
			r:Set("cooldownRowSettings", all)
			ns.ApplyCooldownRing()
			r:Sleep(0.4)
			r:Verdict(not ring.text:IsShown() and Alpha() == 0, ("Amount Hide, no number: ours hidden %s, the game's alpha %s"):format(
				tostring(not ring.text:IsShown()), tostring(Alpha())))
		end },
		-- The Style page (Style/CdmStyle.lua): opened from the Style hub, its
		-- switch on and off (rows greyed), and the ring keeping its own look off.
		-- (Run 9 passed; the Color tab's Gradient ends and the Amount tab's
		-- X / Y sliders since, 2026-11-23: again.)
		{ key = "stylepage", proven = "cdmring run 11 (2026-11-23, priest): PASS, Gradient ends + Amount X / Y on the page",
			title = "Style > Cooldown Manager", run = function(r)
			if InCombatLockdown() then return r:Skip("in a fight: the settings stay shut") end
			if not ns.CreateCdmStylePanel then return r:Skip("Style left out (Modules): no page, the ring's own look") end
			local ok, err = pcall(ns.OpenOptionsAt, "Cooldown Manager Style")
			r:Verdict(ok and SettingsPanel and SettingsPanel:IsShown(), "the page opened: " .. tostring(err or "ok"))
			r:Sleep(0.5)
			r:Set("cdmStyle", true)
			if ns.RefreshOptions then pcall(ns.RefreshOptions) end
			r:Sleep(0.3)
			r:Shot("Style > Cooldown Manager, on", { behind = SettingsPanel })
			r:Set("cdmStyle", false)
			if ns.RefreshOptions then pcall(ns.RefreshOptions) end
			ns.ApplyCooldownRing()
			r:Sleep(0.3)
			r:Shot("Style > Cooldown Manager, off (greyed)", { behind = SettingsPanel })
			local ring = test.item and ns.CooldownRingOf(test.item)
			if ring and type(test.item.auraInstanceID) ~= "nil" then
				r:Verdict(ring.style == "pips", "page off: the ring's own look (pips): " .. tostring(ring.style))
			end
			r:Set("cdmStyle", true)
			ns.ApplyCooldownRing()
			pcall(HideUIPanel, SettingsPanel)
		end },
		{ key = "fight", proven = "cdmring run 5 (2026-11-23, priest): PASS, 58 sets for 6 hits, 0 errors, shot 36 left / 7 pips",
			title = "Pips through a fight", run = function(r)
			if not FindShield(r) then return r:Skip("no shield icon tracked") end
			SetRing(r, "pips")
			if type(test.item.auraInstanceID) == "nil" and not InCombatLockdown() then
				r:WaitFor("Cast " .. test.name .. " again, then attack a mob.", {
					check = function() return type(test.item.auraInstanceID) ~= "nil" and "on" end })
			end
			if not InCombatLockdown() then
				r:WaitFor("Attack a mob with your shield up.", { events = { "PLAYER_REGEN_DISABLED" } })
			end
			local hits = 0
			local stats = ns.CooldownRingStats or {}
			local before = { updates = stats.updates or 0, shown = stats.shown or 0, errors = stats.errors or 0 }
			local listen = CreateFrame("Frame")
			listen:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
			listen:SetScript("OnEvent", function() hits = hits + 1 end)
			local woke = r:WaitFor(nil, { check = function()
				if hits > 0 then return "hit" end
				if not InCombatLockdown() then return "fight over" end
			end })
			if woke == "hit" then
				r:Sleep(0.2)
				local ring = ns.CooldownRingOf(test.item)
				r:Verdict(ring and ring.holder:IsVisible(), "in the fight, after a hit: the ring shown")
				r:Shot("fight: after the first hit", { behind = test.item, pad = 18 })
			end
			local ended = r:WaitFor(nil, { check = function()
				if type(test.item.auraInstanceID) == "nil" then return "shield gone" end
				if not InCombatLockdown() then return "fight over" end
			end })
			listen:UnregisterAllEvents()
			r:Log(("  absorb changes %d, ended: %s"):format(hits, tostring(ended)))
			if ended == "shield gone" then
				r:Sleep(0.4)
				local ring = ns.CooldownRingOf(test.item)
				r:Verdict(not (ring and ring.holder:IsVisible()), "shield gone: the ring hidden")
				r:Shot("fight: the shield gone", { behind = test.item, pad = 18 })
			end
			r:Verdict(hits > 0, "the shield took hits in the fight: " .. hits)
			-- (Run 3: the ring froze after the first hit, its lookups erroring
			-- on the fight's secret spell ID. Each update now counted.)
			local updates, shown, errors = (stats.updates or 0) - before.updates, (stats.shown or 0) - before.shown,
				(stats.errors or 0) - before.errors
			r:Log(("  ring in the fight: %d updates, %d set, %d errors (last: %s)"):format(updates, shown, errors,
				tostring(stats.lastError)))
			r:Verdict(errors == 0 and shown > hits, ("the ring set on every hit, no errors: %d set for %d hits, %d errors"):format(
				shown, hits, errors))
		end },
	},
})
