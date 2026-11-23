-- /cine debug cdmring: the drain ring on a shield's tracked buff icon
-- (UI/CooldownRing.lua; ledger Tools/tests/cdm-shield-strength.md). On a
-- character with a shield (Power Word: Shield). What you do: have the shield
-- in Tracked Buffs (the button opens the game's Cooldown Manager settings),
-- cast it on yourself, then attack a mob. Steps:
--   1 shield  waits for a shield icon in Tracked Buffs, then your cast
--   2 styles  its row On; Pips, Smooth, Liquid, Bar from the Style page, in
--             a few colors: pieces made and shown, a shot of each
--   3 menu    the page's Tracked Buffs tab in Look: Ring and Amount, a shot
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

-- The shield's row On, and the Style page's look (its switch on): style and color.
local function SetRing(r, style, color)
	local all = Copy(ns.db.cooldownRowSettings) or {}
	all[test.spell] = all[test.spell] or {}
	all[test.spell].ring = "on"
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
			local found = ShieldIcon()
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
			test.item, test.spell, test.name = found.item, found.spell, found.name
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
		{ key = "styles", proven = "cdmring run 7 (2026-11-23, priest): PASS 6/6 styles + colors from the page",
			title = "the four styles, from the Style page, with its colors", run = function(r)
			if not test.item then return r:Skip("no shield icon (step 1)") end
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
		-- The Style page (Style/CdmStyle.lua): opened from the Style hub, its
		-- switch on and off (rows greyed), and the ring keeping its own look off.
		{ key = "stylepage", proven = "cdmring run 9 (2026-11-23, priest): PASS, Look panel (tabs, pills, slider), preview centered",
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
			if not test.item then return r:Skip("no shield icon (step 1)") end
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
