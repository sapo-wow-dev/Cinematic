-- /cine debug mousewords: the rules' Mouse over words (Frames.lua's
-- ns.HoverWords, 2026-11-24: a player wished for tooltips only on corpses,
-- or only over unit frames). One action: put the mouse on a unit out in the
-- world, then onto your own portrait when the box says. Out of combat.
-- (Named mousewords: /cine debug hover... is the older hover watch.)
--   1 editor  the rule editor opened on the Tooltips row (its Tooltip line
--             too) and on the Minimap row, each line capped at two rows
--             (2026-11-24): the Target and Mouse over lines closed (two
--             rows, a +N counting what's behind it), opened (Fewer, every
--             word), and closed with a word behind the +N in the rule (it
--             shows); in each: none cut short or covered, nothing past the
--             editor's right edge, the editor on screen; a shot each
--   2 world   the Tooltips page on, CineMode on, the Tooltips row's rule
--             "hoverdead or hoverframe" (the player's case), Hide when still
--             off. Waits for the GAME's mouseover on a unit in the world:
--             the words against the game's own answers (dead, kind, you),
--             hoverframe false; the row off for a living one (its tooltip
--             hidden), on for a corpse; shot
--   3 frame   waits for the mouse on your player frame: hover, hoverself,
--             hoverfriendly and hoverframe on in the frame it came (no lag),
--             the kind words off; the row on, the tooltip shown; shot
-- Everything changed is put back at the end. Into CinematicDB.mouseWordsTestLog.
-- Dev copy only.
local _, ns = ...

local WORDS = { "hover", "hoverself", "hoverdead", "hoverenemy", "hoverfriendly", "hoverenemyplayer",
	"hoverhostilenpc", "hoverneutralplayer", "hoverneutralnpc", "hoverfriendlyplayer", "hoverfriendlynpc",
	"hoverframe" }
local KIND_WORD = { TargetEnemyPlayer = "hoverenemyplayer", TargetEnemyNPC = "hoverhostilenpc",
	TargetNeutralPlayer = "hoverneutralplayer", TargetNeutralNPC = "hoverneutralnpc",
	TargetFriendlyPlayer = "hoverfriendlyplayer", TargetFriendlyNPC = "hoverfriendlynpc" }
local RULE = "hoverdead or hoverframe"
local ROW = "tooltip:All"

local function Plain(value)
	return not (issecretvalue and issecretvalue(value))
end

-- The words as the rows read them now, one line.
local function WordsLine(facts)
	local on = {}
	for _, word in ipairs(WORDS) do
		if facts[word] then on[#on + 1] = word end
	end
	return #on == 0 and "none" or table.concat(on, " ")
end

-- The unit under the mouse as the game says it (for the log).
local function GameLine()
	local name = UnitName("mouseover")
	local dead = UnitIsDeadOrGhost("mouseover")
	local focus = ns.MouseFocus()
	local focusName = focus and focus.GetName and focus:GetName()
	return ("mouseover %s, dead %s, you %s, attackable %s, kind %s, under the mouse %s"):format(
		Plain(name) and tostring(name) or "secret", Plain(dead) and tostring(dead) or "secret",
		tostring(ns.Flag(UnitIsUnit("mouseover", "player"))), tostring(ns.IsEnemyUnit("mouseover")),
		tostring(ns.TargetNameRow and ns.TargetNameRow("mouseover")),
		focus == nil and "nothing" or (Plain(focusName) and tostring(focusName or "(no name)") or "secret"))
end

-- Whether the frame under the mouse is out in the world (WorldFrame or on
-- it; nothing read counts as the world, as ns.HoverWords has it).
local function InWorld()
	local f = ns.MouseFocus()
	if f == nil then return true end
	for _ = 1, 8 do
		if f == nil then return false end
		if f == WorldFrame then return true end
		local ok, parent = pcall(UIParent.GetParent, f)
		f = ok and Plain(parent) and parent or nil
	end
	return false
end

-- One editor line as drawn (editor.lines, UI/GridRows.lua; key: its first
-- word): rows its shown buttons take, how many shown, its +N's text,
-- buttons cut short or covered, and the widest right edge past the editor's.
local function LineLook(r, editor, line)
	local tops, rows, shown, cut, covered, past = {}, 0, 0, 0, {}, 0
	local right = editor:GetRight()
	local function Note(button, name)
		if not button:IsVisible() then return end
		local top = button:GetTop()
		top = top and math.floor(top + 0.5)
		if top and not tops[top] then tops[top], rows = true, rows + 1 end
		local text = button.GetFontString and button:GetFontString()
		if text and text:IsTruncated() == true then cut = cut + 1 end
		local hits = r:Overlaps(button, editor)
		if #hits > 0 then covered[#covered + 1] = name .. " (" .. table.concat(hits, ", ") .. ")" end
		local edge = button:GetRight()
		if not ns.noRealLayout and edge and right and edge > right - 6 then past = past + 1 end
	end
	for _, piece in ipairs(line.pieces) do
		if piece.button:IsVisible() then shown = shown + 1 end
		Note(piece.button, tostring(piece.field))
	end
	local more = ""
	if line.more and line.more:IsVisible() then
		Note(line.more, "+N")
		more = tostring(line.more:GetText() or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	end
	return { rows = rows, shown = shown, total = #line.pieces, hidden = #(line.hidden or {}), more = more,
		cut = cut, covered = covered, past = past }
end

ns.TestKit.Define({
	name = "mousewords",
	key = "mouseWordsTest",
	title = "Mouse over rule words",
	about = "the rules' Mouse over words: the editor's line, a unit in the world, then your portrait",
	needs = "A unit in view to mouse over (any NPC or player), out of combat",
	settings = { "handleTooltips", "tooltipStillMode" },
	cineMode = true,
	context = function()
		return ("Tooltips page %s, Tooltips row rule %q, Hide when still %s"):format(tostring(ns.db.handleTooltips),
			tostring(ns.db.frameRules and ns.db.frameRules[ROW] or ""), tostring(ns.db.tooltipStillMode))
	end,
	putBack = function(extra)
		local said = {}
		if extra.openKept and type(ns.db.ruleEditorOpen) == "table" then
			ns.db.ruleEditorOpen.enemy = extra.openEnemy or nil
			ns.db.ruleEditorOpen.hover = extra.openHover or nil
			said[#said + 1] = "the editor's Target and Mouse over lines open as they were"
		end
		if extra.ruleKept then
			ns.db.frameRules = ns.db.frameRules or {}
			local was = extra.ruleWas
			ns.db.frameRules[ROW] = was ~= "<none>" and was or nil
			said[#said + 1] = "Tooltips row rule back to " .. tostring(was)
		end
		if extra.cineTurnedOn and ns.IsCineModeOn and ns.IsCineModeOn() and Cinematic_ToggleCineMode then
			pcall(Cinematic_ToggleCineMode)
			said[#said + 1] = "CineMode off again"
		end
		return #said > 0 and table.concat(said, "; ") or "nothing of its own"
	end,
	steps = {
		{ key = "editor", title = "the rule editor: lines capped at two rows, +N and Fewer", seconds = 12,
			proven = "run 5 (queue q52b5), 2026-11-25: 26/26, the unit words' lines", run = function(r)
			ns.OpenOptions("Tooltips")
			r:Sleep(0.5)
			if type(ns.db.ruleEditorOpen) ~= "table" then ns.db.ruleEditorOpen = {} end
			local open = ns.db.ruleEditorOpen
			r:Keep("openKept", true)
			r:Keep("openEnemy", open.enemy or false)
			r:Keep("openHover", open.hover or false)
			-- (The Tooltips row in each state; the Minimap row closed: no Tooltip line.)
			local CASES = {
				{ key = ROW, state = "closed" }, { key = ROW, state = "open" },
				{ key = ROW, state = "in the rule", rule = "hoverneutral or neutral" }, -- (each line's last word)
				{ key = "minimap", state = "closed" },
			}
			local fitsClosed = {} -- (line key -> nothing behind a +N when closed: the first closed case)
			for _, case in ipairs(CASES) do
				local isOpen = case.state == "open" or nil
				open.enemy, open.hover = isOpen, isOpen
				local rule = case.rule or ""
				ns.OpenRuleEditor({ key = case.key, label = case.key, Text = function() return rule end,
					SetText = function() end, ResetToGrid = function() end, Close = function() end })
				r:Sleep(0.6)
				local editor = _G.CinematicRuleEditor
				if not (editor and editor:IsShown() and editor.lines) then
					return r:Fail("the rule editor didn't open on " .. case.key)
				end
				local where = case.key .. ", " .. case.state
				for _, line in ipairs(editor.lines) do
					if line.key == "enemy" or line.key == "hover" then
						local look = LineLook(r, editor, line)
						r:Log(("%s, %s line: %d rows, %d of %d shown, %d behind %q"):format(where, line.key, look.rows,
							look.shown, look.total, look.hidden, look.more))
						-- (A line that fits in its two rows closed has no +N, nor Fewer
						-- open: the Mouse over line since its ten words, 2026-11-25.)
						local fits = fitsClosed[line.key]
						if case.state == "open" then
							r:Verdict(look.shown == look.total and look.more == (fits and "" or ns.L["Fewer"]),
								("%s, %s: every word shown, %s (%d of %d, %q)"):format(where, line.key,
								fits and "no Fewer (it fits closed)" or "Fewer", look.shown, look.total, look.more))
						else
							if case.state == "closed" and fits == nil then fitsClosed[line.key] = look.hidden == 0 end
							-- (Nothing left behind it: no +N.)
							local counted = look.hidden > 0 and look.more == "+" .. look.hidden
								or (look.hidden == 0 and look.more == "")
							r:Verdict(counted and look.shown + look.hidden == look.total,
								("%s, %s: +N counts what's behind it (%q, %d shown + %d)"):format(where, line.key,
								look.more, look.shown, look.hidden))
							if case.rule then
								local last = line.pieces[#line.pieces]
								r:Verdict(last.button:IsVisible(), ("%s, %s: %s in the rule, shown"):format(where,
									line.key, tostring(last.field)))
							elseif not ns.noRealLayout then
								r:Verdict(look.rows == 2, ("%s, %s: two rows (%d)"):format(where, line.key, look.rows))
							end
						end
						r:Verdict(look.cut == 0 and #look.covered == 0 and look.past == 0,
							("%s, %s: %d cut short, %d covered, %d past the right edge%s"):format(where, line.key,
							look.cut, #look.covered, look.past,
							#look.covered > 0 and (": " .. table.concat(look.covered, "; ")) or ""))
					end
				end
				local bottom, top = editor:GetBottom(), editor:GetTop()
				if not ns.noRealLayout then
					r:Verdict(bottom ~= nil and bottom >= 0 and top ~= nil and top <= UIParent:GetTop() + 1,
						("%s: the editor on screen (bottom %s, top %s, height %s)"):format(where, tostring(bottom),
						tostring(top), tostring(editor:GetHeight())))
				end
				r:Shot("rule editor: " .. where, { behind = editor })
				editor:Hide()
			end
			open.enemy, open.hover = nil, nil
			if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
		end },
		{ key = "world", title = "a unit out in the world", proven = "run 2 (queue qf726), 2026-11-24: 4/4",
			run = function(r)
			ns.db.frameRules = ns.db.frameRules or {}
			-- (Kept once: a rerun keeps the first value.)
			local was = ns.db.frameRules[ROW]
			r:Keep("ruleWas", was == nil and "<none>" or was)
			r:Keep("ruleKept", true)
			ns.db.frameRules[ROW] = RULE
			ns.CompileRule(RULE) -- (its mouse words read from now, ns.hoverState.used, not at the first tooltip)
			r:Set("handleTooltips", true)
			r:Set("tooltipStillMode", "off")
			if not (ns.IsCineModeOn and ns.IsCineModeOn()) and Cinematic_ToggleCineMode then
				r:Keep("cineTurnedOn", true)
				Cinematic_ToggleCineMode()
			end
			r:Sleep(1)
			-- (Read in the check itself, the game and the words in the same
			-- moment, once a unit has stayed under the mouse 0.5 s: run 1 read
			-- 0.4 s after the wait, and the mouse had left by then.)
			local heldSince, read
			local function InWorldUnit()
				return ns.Flag(UnitExists("mouseover")) and not ns.Flag(UnitIsUnit("mouseover", "player")) and InWorld()
			end
			r:WaitFor("Put the mouse on any NPC or player out in the world (a corpse is fine too) and hold it there.",
				{ check = function()
					if not InWorldUnit() then heldSince = nil return nil end
					heldSince = heldSince or GetTime()
					if GetTime() - heldSince < 0.5 then return nil end
					local facts = ns.RuleFactsNow()
					local copy = {}
					for _, word in ipairs(WORDS) do copy[word] = facts[word] end
					read = { game = GameLine(), facts = copy, dead = UnitIsDeadOrGhost("mouseover"),
						kind = ns.TargetNameRow and ns.TargetNameRow("mouseover"),
						on = ns.RowOnNow(ROW, ns.db.tooltipAlways, true) }
					return true
				end })
			r:Log("game: " .. read.game)
			local facts = read.facts
			r:Log("words: " .. WordsLine(facts))
			local dead, kind = read.dead, read.kind
			r:Verdict(facts.hover == true and facts.hoverframe == false and facts.hoverself == false,
				"hover on, hoverframe and hoverself off")
			if Plain(dead) then
				r:Verdict(facts.hoverdead == (dead and true or false), ("hoverdead matches the game (%s)"):format(tostring(dead)))
			end
			local wrongKind = {}
			for row, word in pairs(KIND_WORD) do
				if (facts[word] and true or false) ~= (kind == row) then wrongKind[#wrongKind + 1] = word end
			end
			r:Verdict(#wrongKind == 0, ("the kind words match the game (%s)%s"):format(tostring(kind),
				#wrongKind > 0 and (": wrong " .. table.concat(wrongKind, ", ")) or ""))
			local on = read.on
			local last = ns.lastTooltipWhy
			r:Log(("Tooltips row %s; tooltip shown %s, last decided %s (hide %s, why %s)"):format(tostring(on),
				tostring(GameTooltip:IsShown()), tostring(last and last.name), tostring(last and last.hide),
				tostring(last and last.why)))
			r:Verdict(on == (facts.hoverdead and true or false), ("Tooltips row \"%s\": %s here"):format(RULE,
				on and "on" or "off"))
			r:Shot("a unit in the world under the mouse")
		end },
		{ key = "frame", title = "your own portrait", proven = "run 2 (queue qf726), 2026-11-24: 4/4", run = function(r)
			if not (ns.db.frameRules and ns.db.frameRules[ROW] == RULE) then
				return r:Skip("step 2 sets the Tooltips row's rule: run it first")
			end
			-- (The words read as the game's mouseover changes: in the same frame.)
			local seenAt, wordsAt
			local watch = CreateFrame("Frame")
			watch:SetScript("OnUpdate", function()
				local now = GetTime()
				if not seenAt and ns.Flag(UnitIsUnit("mouseover", "player")) and not InWorld() then seenAt = now end
				if seenAt and not wordsAt then
					local facts = ns.RuleFactsNow()
					if facts.hoverself and facts.hoverframe then wordsAt = now end
				end
			end)
			r:WaitFor("Now move the mouse onto your own portrait (your player frame).",
				{ check = function() return wordsAt ~= nil or nil end })
			watch:SetScript("OnUpdate", nil)
			r:Sleep(0.5)
			r:Log("game: " .. GameLine())
			local facts = ns.RuleFactsNow()
			r:Log("words: " .. WordsLine(facts))
			r:Verdict(wordsAt ~= nil and seenAt ~= nil and wordsAt - seenAt < 0.05,
				("the words came with the mouse (%.3f s after)"):format((wordsAt or 0) - (seenAt or 0)))
			r:Verdict(facts.hover and facts.hoverself and facts.hoverfriendly and facts.hoverframe and true or false,
				"hover, hoverself, hoverfriendly, hoverframe on")
			local kinds = {}
			for _, word in pairs(KIND_WORD) do if facts[word] then kinds[#kinds + 1] = word end end
			r:Verdict(#kinds == 0 and not facts.hoverenemy and not facts.hoverdead,
				"no kind word, not hoverenemy or hoverdead" .. (#kinds > 0 and (": " .. table.concat(kinds, ", ")) or ""))
			local on = ns.RowOnNow(ROW, ns.db.tooltipAlways, true)
			local last = ns.lastTooltipWhy
			r:Verdict(on == true, "Tooltips row on over your portrait")
			r:Log(("tooltip shown %s, last decided %s (hide %s, why %s)"):format(tostring(GameTooltip:IsShown()),
				tostring(last and last.name), tostring(last and last.hide), tostring(last and last.why)))
			-- (Shoulder Cam's self-target stand-in, CinematicShoulderSelfButton,
			-- sits over your portrait with no tooltip of its own: run 1. Then no
			-- tooltip is the stand-in's, not the rule's.)
			local standIn = _G.CinematicShoulderSelfButton
			if standIn and ns.MouseFocus() == standIn then
				r:Log("the mouse is on Shoulder Cam's self-target stand-in (no tooltip of its own): tooltip not judged")
			else
				r:Verdict(GameTooltip:IsShown() and (GameTooltip:GetAlpha() or 0) > 0.5,
					("your tooltip shows (alpha %.2f)"):format(GameTooltip:GetAlpha() or 0))
			end
			r:Shot("your portrait under the mouse", { behind = GameTooltip })
		end },
		{ key = "units", title = "the unit words on your target and focus", seconds = 20,
			proven = "run 1 (queue q68c0), 2026-11-25: 7/7", run = function(r)
			-- (Tools/cql-words-plan.md phase 1, 2026-11-25: hostile, neutral,
			-- player, npc for your target, and the focus words. Each against
			-- the game's own answers, not ns.TargetNameRow, which makes them.)
			ns.CompileRule("focus or focushostile") -- (the focus words read from now: ns.focusState.used)
			local function Game(unit)
				local dead = UnitIsDeadOrGhost(unit)
				local attack, isPlayer = UnitCanAttack("player", unit), UnitIsPlayer(unit)
				local friend, reaction = UnitIsFriend("player", unit), UnitReaction(unit, "player")
				for _, v in ipairs({ dead, attack, isPlayer, friend, reaction }) do
					if not Plain(v) then return nil end
				end
				local enemy = not dead and (attack or (isPlayer and not friend))
				local neutral = enemy and (isPlayer and not attack or not isPlayer and reaction == 4) or false
				return { hostile = enemy and not neutral or false, neutral = neutral, player = isPlayer and true or false,
					npc = not isPlayer, dead = dead and true or false }, ("dead %s, attackable %s, player %s, friend %s,"
					.. " reaction %s"):format(tostring(dead), tostring(attack), tostring(isPlayer), tostring(friend),
					tostring(reaction))
			end
			if _G.FocusFrame == nil then
				r:Log("this client has no focus frame: the focus words left out")
			else
				r:WaitFor("Target any NPC or player near you, then type /focus", { check = function()
					return ns.Flag(UnitExists("focus")) and ns.Flag(UnitExists("target"))
						and not ns.Flag(UnitIsUnit("target", "player")) or nil
				end })
			end
			r:Sleep(0.5)
			local facts = ns.RuleFactsNow()
			local PAIRS = { enemyplayer = "hostile and player", hostilenpc = "hostile and npc",
				neutralplayer = "neutral and player", neutralnpc = "neutral and npc",
				friendlyplayer = "not hostile and not neutral and player",
				friendlynpc = "not hostile and not neutral and npc" }
			for _, who in ipairs({ { unit = "target", prefix = "" }, { unit = "focus", prefix = "focus" } }) do
				if ns.Flag(UnitExists(who.unit)) and not ns.Flag(UnitIsUnit(who.unit, "player")) then
					local want, line = Game(who.unit)
					r:Log(who.unit .. ": " .. (line or "secret") .. "; words " .. table.concat((function()
						local on = {}
						for _, atom in ipairs(ns.UNIT_ATOMS) do
							if facts[who.prefix .. atom] then on[#on + 1] = who.prefix .. atom end
						end
						return on
					end)(), " "))
					if want then
						local wrong = {}
						for _, atom in ipairs(ns.UNIT_ATOMS) do
							if (facts[who.prefix .. atom] and true or false) ~= want[atom] then
								wrong[#wrong + 1] = who.prefix .. atom
							end
						end
						r:Verdict(#wrong == 0, ("%s: hostile, neutral, player, npc match the game%s"):format(who.unit,
							#wrong > 0 and (": wrong " .. table.concat(wrong, ", ")) or ""))
					end
				end
			end
			-- (Your target: each old kind word equals its atoms joined with and.)
			local odd = {}
			for old, text in pairs(PAIRS) do
				local a, b = ns.CompileRule(old), ns.CompileRule(text)
				if not (a and b) or a(facts) ~= b(facts) then odd[#odd + 1] = old end
			end
			r:Verdict(#odd == 0, "target: the old kind words equal their atoms" .. (#odd > 0 and (": " .. table.concat(odd,
				", ")) or ""))
			if _G.FocusFrame ~= nil then
				local dead = UnitIsDeadOrGhost("focus")
				r:Verdict(facts.focus == true and (not Plain(dead) or facts.focusdead == (dead and true or false)),
					("focus on, focusdead matches the game (%s)"):format(Plain(dead) and tostring(dead) or "secret"))
				local near = CheckInteractDistance and select(2, pcall(CheckInteractDistance, "focus", 4))
				if type(near) == "boolean" and Plain(near) then
					r:Verdict(facts.focusnear28 == near, ("focusnear28 matches the game's 28 yards (%s)"):format(tostring(near)))
				end
				-- (The rule editor's Focus line: on screen, nothing cut or covered.)
				ns.OpenOptions("Tooltips")
				r:Sleep(0.5)
				local rule = "focushostile and focusplayer"
				ns.OpenRuleEditor({ key = ROW, label = ROW, Text = function() return rule end,
					SetText = function() end, ResetToGrid = function() end, Close = function() end })
				r:Sleep(0.6)
				local editor = _G.CinematicRuleEditor
				local found
				for _, line in ipairs(editor and editor.lines or {}) do
					if line.key == "focus" then found = line end
				end
				r:Verdict(found ~= nil, "rule editor: a Focus line")
				if found then
					local look = LineLook(r, editor, found)
					r:Verdict(look.cut == 0 and #look.covered == 0 and look.past == 0,
						("rule editor: Focus line %d of %d shown, %d cut short, %d covered, %d past the edge"):format(
						look.shown, look.total, look.cut, #look.covered, look.past))
				end
				r:Shot("rule editor: the Focus line", { behind = editor })
				if editor then editor:Hide() end
				if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
			end
		end },
	},
})
