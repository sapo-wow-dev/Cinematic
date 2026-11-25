-- /cine debug ctspells: Combat Text Style's Spells tab (Style/CombatTextSpells.lua,
-- the Combat Text by Spell plan, 2026-11-25) in one fight. The one thing
-- to do: fight a mob for about 20 seconds with two or three of your spells
-- (a DoT too, if you have one). Steps:
--   1 setup    Combat Text Style on with our numbers (put back at the end),
--              the Spells tab's list emptied for the run (yours put back)
--   2 fight    each spell of yours the first time it hits is added to the
--              list with a test color of its own: every later hit of it must
--              be drawn in that color (PASS/FAIL per spell). Logs each cast's
--              spell ID plain or secret in the fight (retail: untested, the
--              plan's one open question), the ticks matched to a DoT, and the
--              hits no spell was found for (their school's look)
--   3 page     the page on its Spells tab: a line per spell, nothing over
--              anything (r:Overlaps), a spell's Look panel, the Add list
--              (the spells you hit with at its top), a shot of each
-- Into CinematicDB.ctSpellsTestLog. Dev copy only.
local _, ns = ...

-- (Test colors, one per spell in turn: none any school's.)
local COLORS = { { 0.1, 1, 1 }, { 1, 0.1, 0.6 }, { 1, 1, 1 }, { 0.3, 0.3, 1 }, { 0.6, 1, 0.1 }, { 1, 0.55, 0.55 } }
local FIGHT_FOR = 20 -- (seconds after the first spell's hit)

local state -- (the fight's: spells added, drawn hits, casts, the old recorder)

local function Near(a, b) return math.abs((tonumber(a) or -1) - (tonumber(b) or -2)) < 0.02 end

ns.TestKit.Define({
	name = "ctspells",
	key = "ctSpellsTest",
	title = "Combat Text by Spell",
	about = "each spell of yours in a color of its own, matched from your casts; the Spells tab",
	needs = "A mob to fight, with two or three of your spells (a DoT too, if you have one)",
	settings = { "combatTextStyle", "styleGeneral", "combatTextNumbers", "combatTextDamageBy", "combatTextHealBy",
		"combatTextSpells", "tabOn:Combat Text Style/page:3" },
	context = function()
		local CT = ns.CombatTexts
		return ("spells on the list: %s; hit with on this character: %s"):format(
			CT and tostring(CT.SpellCount()) or "no Style module",
			CT and tostring((function() local n = 0 for _ in pairs(CT.Seen()) do n = n + 1 end return n end)()) or "?")
	end,
	putBack = function()
		if state and state.watch then state.watch:UnregisterAllEvents() end
		if state then ns.combatTextRecord = state.oldRecord end
		state = nil
		if ns.RefreshCombatTextStyle then ns.RefreshCombatTextStyle() end
		return "recorder and cast watch put back"
	end,
	steps = {
		{ key = "setup", title = "the page on, the list empty", run = function(r)
			local CT = ns.CombatTexts
			if not (CT and CT.AddSpell and ns.BuildCombatTextSpells) then
				return r:Fail("the Spells tab's code isn't loaded (the Style module off, or a file missing from the .toc)")
			end
			r:Set("styleGeneral", true)
			r:Set("combatTextStyle", true)
			r:Set("combatTextNumbers", true)
			r:Set("combatTextDamageBy", "ours")
			r:Set("combatTextHealBy", "ours")
			r:Set("tabOn:Combat Text Style/page:3", true)
			r:Set("combatTextSpells", {})
			ns.RefreshCombatTextStyle()
			r:Verdict(CT.SpellsOn() and CT.SpellCount() == 0, "Spells tab on, its list empty for the run")
		end },
		{ key = "fight", title = "your spells, each in its own color", run = function(r)
			local CT = ns.CombatTexts
			state = { spells = {}, order = {}, ids = {}, plain = 0, secret = 0, outPlain = 0, ticks = {}, none = 0, oldRecord = ns.combatTextRecord }
			-- (Each cast's spell ID, plain or secret, in the fight and out.)
			state.watch = CreateFrame("Frame")
			pcall(state.watch.RegisterUnitEvent, state.watch, "UNIT_SPELLCAST_SUCCEEDED", "player")
			state.watch:SetScript("OnEvent", function(_, _, _, _, spell)
				local fighting = InCombatLockdown and InCombatLockdown()
				local secret = issecretvalue and issecretvalue(spell)
				if secret then state.secret = state.secret + 1
				elseif fighting then state.plain = state.plain + 1
				else state.outPlain = state.outPlain + 1 end
				local name = not secret and ns.CombatTextSpellNameOf and ns.CombatTextSpellNameOf(spell)
				if name then state.ids[name] = spell end
			end)
			-- (The drawing's own record: a DRAWN line, then its spell's.)
			local last
			ns.combatTextRecord = function(text)
				text = tostring(text)
				if state.oldRecord then pcall(state.oldRecord, text) end
				local r1, g1, b1 = text:match("^DRAWN .- color=([%d%.]+),([%d%.]+),([%d%.]+)")
				if r1 then last = { tonumber(r1), tonumber(g1), tonumber(b1) } return end
				if text:find("^cast: none waiting") or text:find("^tick: no spell") then state.none = state.none + 1 end
				-- ("spell <name>[ (tick)]: <how>": the name may have a colon, the how never.)
				local body, how = text:match("^spell (.+): ([^:]+)$")
				if not body or not last then return end
				local isTick = body:sub(-7) == " (tick)"
				local name = isTick and body:sub(1, -8) or body
				local spell = state.spells[name]
				if not spell then
					-- (Its first hit: on the list now, in its test color.)
					local color = COLORS[(#state.order % #COLORS) + 1]
					spell = { color = color, hits = 0, right = 0, wrong = {}, first = GetTime() }
					state.spells[name] = spell
					state.order[#state.order + 1] = name
					CT.AddSpell(name)
					local id = CT.SpellId(name)
					for i, part in ipairs({ "R", "G", "B" }) do ns.db[CT.Key(id, part)] = color[i] end
					state.first = state.first or GetTime()
				else
					spell.hits = spell.hits + 1
					if how:find("its own look", 1, true) and Near(last[1], spell.color[1]) and Near(last[2], spell.color[2])
						and Near(last[3], spell.color[3]) then
						spell.right = spell.right + 1
					elseif #spell.wrong < 4 then
						spell.wrong[#spell.wrong + 1] = ("%.2f,%.2f,%.2f (%s)"):format(last[1], last[2], last[3], how)
					end
				end
				if isTick then state.ticks[name] = (state.ticks[name] or 0) + 1 end
				last = nil
			end
			r:WaitFor("Fight a mob now with two or three of your spells (a DoT too, if you have one). "
				.. "Each spell's numbers turn a color of their own after its first hit. The test goes on by itself "
				.. "20 seconds after your first spell lands.", {
				check = function()
					if not state.first then return false end
					local later = 0
					for _, spell in pairs(state.spells) do later = later + spell.hits end
					return GetTime() - state.first >= FIGHT_FOR and later >= 3 and "fought"
				end,
				-- (No Done button: run q62d6 ended on it after 1.9 s, before any hit.
				-- It goes on by itself 20 s after your first spell's hit.)
			})
			ns.combatTextRecord = state.oldRecord
			state.watch:UnregisterAllEvents()
			r:Log(("cast spell IDs: %d plain in fights, %d plain out of fights, %d secret"):format(state.plain, state.outPlain, state.secret))
			r:Verdict(state.secret == 0, "your casts' spell IDs plain (the matching needs them)")
			r:Verdict(#state.order > 0, ("%d spell(s) of yours matched to their hits: %s"):format(#state.order,
				table.concat(state.order, ", ")))
			for _, name in ipairs(state.order) do
				local spell = state.spells[name]
				if spell.hits == 0 then
					r:Skip(name .. ": only one hit, nothing to compare after it was added")
				else
					r:Verdict(spell.right == spell.hits, ("%s: %d of %d later hits in its own color%s"):format(name, spell.right,
						spell.hits, #spell.wrong > 0 and (", others: " .. table.concat(spell.wrong, "; ")) or ""))
				end
			end
			local ticked = {}
			for name, n in pairs(state.ticks) do ticked[#ticked + 1] = name .. " x" .. n end
			r:Log("ticks matched to their spell: " .. (#ticked > 0 and table.concat(ticked, ", ") or "none (no DoT, or retail)"))
			r:Log(("hits of yours no spell was found for (their school's look): %d"):format(state.none))
			-- (Each spell's school as learned against the one its description names:
			-- run q0530 learned Corruption as Fire, an Immolate tick taken first.)
			local wrong, read = {}, 0
			for _, name in ipairs(state.order) do
				local id = state.ids and state.ids[name]
				local named = id and ns.CombatTextSpellMatch.TextSchool(id) or 0
				if named > 0 then
					read = read + 1
					local base = CT.SpellBase(name)
					if base ~= "spell" and base ~= CT.SCHOOL_NODE[named] and base ~= "heal" and base ~= "pet" then
						wrong[#wrong + 1] = ("%s learned %s, its description says %s"):format(name, base, CT.SCHOOL_NODE[named] or named)
					end
				end
			end
			r:Log(("descriptions naming a school: %d of %d spells"):format(read, #state.order))
			r:Verdict(#wrong == 0, "every spell under the school its description names: " .. (#wrong > 0 and table.concat(wrong, "; ") or "yes"))
			r:Log("each spell's school as learned: " .. (function()
				local parts = {}
				for _, name in ipairs(state.order) do parts[#parts + 1] = name .. " " .. CT.SpellBase(name) end
				return table.concat(parts, ", ")
			end)())
		end },
		{ key = "page", title = "the Spells tab", run = function(r)
			local CT = ns.CombatTexts
			-- (The game's settings can't open in a fight: run q1b8f opened them mid-fight,
			-- and the page waited for the fight's end. Wait for it first.)
			if InCombatLockdown and InCombatLockdown() then
				r:WaitFor("Finish the fight: the Spells tab opens once you're out of it.", {
					handsOff = true, check = function() return not InCombatLockdown() and "out of the fight" end })
			end
			if CT.SpellCount() == 0 then
				CT.AddSpell("Test spell", { school = 4 })
				r:Log("no spell came from the fight: a stand-in added to show the tab")
			end
			ns.OpenOptions("Combat Text Style")
			r:Sleep(0.5)
			local tab = ns.combatTextSpellsTab
			if not tab then return r:Fail("the Spells tab wasn't built") end
			local host = tab.box:GetParent()
			if host and host.openSection then host.openSection() end
			r:Sleep(0.5)
			tab.Layout()
			local shown = 0
			for _, row in ipairs(tab.lines) do if row:IsShown() and row.name then shown = shown + 1 end end
			r:Verdict(tab.box:IsVisible() and shown == CT.SpellCount(), ("the tab shows, %d line(s) for %d spell(s)"):format(
				shown, CT.SpellCount()))
			-- (Against the page's content: the tab's host is a 1x1 anchor, run q62d6 read
			-- everything as past its edge.)
			local page = tab.box:GetParent() and tab.box:GetParent():GetParent()
			local hits = r:Overlaps(tab.tools, page)
			for _, row in ipairs(tab.lines) do
				if row:IsShown() then
					for _, hit in ipairs(r:Overlaps(row, tab.box)) do hits[#hits + 1] = hit end
				end
			end
			r:Verdict(#hits == 0, "nothing over anything: " .. (#hits > 0 and table.concat(hits, "; ") or "none"))
			r:Shot("the Spells tab", { behind = tab.box:GetParent() })
			local first = tab.lines[1] and tab.lines[1].name
			if first and ns.combatTextSpellLook then
				ns.combatTextSpellLook(first)
				r:Sleep(0.5)
				r:Shot(first .. "'s Look panel")
			end
			tab.add:Click()
			r:Sleep(0.5)
			local pick = ns.combatTextSpellPick
			r:Verdict(pick and pick:IsShown(), "the Add list opens")
			r:Shot("the Add list", { behind = pick })
			if pick then pick:Hide() end
		end },
	},
})
