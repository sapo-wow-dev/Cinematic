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

-- The game's settings window closed, whichever this client has (Forever:
-- InterfaceOptionsFrame; run qc7ea left it open, and the phase 2 checks read
-- it as a game window).
local function CloseSettings()
	if InCombatLockdown() then return end
	for _, name in ipairs({ "SettingsPanel", "InterfaceOptionsFrame" }) do
		local panel = _G[name]
		if panel and ns.Flag(panel:IsShown()) then HideUIPanel(panel) end
	end
end

-- The game windows shown now, by name (for the log: what menuopen sees).
local WINDOW_NAMES = { "SettingsPanel", "InterfaceOptionsFrame", "WorldMapFrame", "CharacterFrame", "GameMenuFrame",
	"SpellBookFrame", "PlayerSpellsFrame", "QuestLogFrame", "FriendsFrame", "EditModeManagerFrame", "KeyBindingFrame",
	"ContainerFrameCombinedBags", "GossipFrame", "QuestFrame", "MerchantFrame", "ItemTextFrame", "TalkingHeadFrame" }
local function WindowsUp()
	local up = {}
	for _, name in ipairs(WINDOW_NAMES) do
		local f = _G[name]
		if f then
			local shown = f:IsShown()
			if not Plain(shown) then up[#up + 1] = name .. "(secret)"
			elseif shown then up[#up + 1] = name end
		end
	end
	if ns.OurSettingsShown and ns.OurSettingsShown() then up[#up + 1] = "our settings" end
	return #up == 0 and "none" or table.concat(up, ", ")
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
	title = "Mouse over and unit rule words",
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
			proven = "run 7 (queue q504b), 2026-11-25: phase 3's longer lines", run = function(r)
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
				{ key = ROW, state = "in the rule", rule = "hovertargetingyou or targetingyou" }, -- (each line's last word)
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
			CloseSettings()
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
				CloseSettings()
			end
		end },
		{ key = "props", title = "phase 3's words: elite, rare, boss, quest, tapped, critter, targeting you",
			seconds = 20, proven = "run 7 (queue q504b), 2026-11-25: a normal humanoid, all false", run = function(r)
			-- (Tools/cql-words-plan.md phase 3, 2026-11-25: Frames.lua's
			-- ns.SetUnitProps, each against the game's own answer for your
			-- target, and your focus if you have one.)
			local fields = {}
			for _, prefix in ipairs({ "target", "focus" }) do
				for _, prop in ipairs(ns.UNIT_PROPS) do fields[#fields + 1] = ns.UnitPropField(prefix, prop) end
			end
			ns.CompileRule(table.concat(fields, " or "))
			r:WaitFor("Target any mob or NPC near you (not yourself).", { check = function()
				return ns.Flag(UnitExists("target")) and not ns.Flag(UnitIsUnit("target", "player")) or nil
			end })
			r:Sleep(0.5)
			local facts = ns.RuleFactsAll()
			local function Say(fn, ...)
				if type(fn) ~= "function" then return nil, "none" end
				local ok, a, b = pcall(fn, ...)
				if not ok then return nil, "error" end
				if not Plain(a) or not Plain(b) then return nil, "secret" end
				return a, b
			end
			for _, unit in ipairs({ "target", "focus" }) do
				if ns.Flag(UnitExists(unit)) and not ns.Flag(UnitIsUnit(unit, "player")) then
					local rank = Say(UnitClassification, unit)
					local _, ctype = Say(UnitCreatureType, unit)
					local game = {
						elite = rank == "elite" or rank == "rareelite" or rank == "worldboss",
						rare = rank == "rare" or rank == "rareelite",
						tapped = Say(UnitIsTapDenied, unit) == true,
						critter = ns.CRITTER_TYPES[ctype] == true,
						quest = Say(C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest, unit) == true
							or Say(UnitIsQuestBoss, unit) == true,
						targetingyou = Say(UnitIsUnit, unit .. "target", "player") == true,
					}
					r:Log(("%s: rank %s, creature type %s, level %s; words %s"):format(unit, tostring(rank), tostring(ctype),
						tostring(UnitLevel(unit)), table.concat((function()
							local on = {}
							for _, prop in ipairs(ns.UNIT_PROPS) do
								if facts[ns.UnitPropField(unit, prop)] then on[#on + 1] = ns.UnitPropField(unit, prop) end
							end
							return #on > 0 and on or { "none" }
						end)(), " ")))
					local wrong = {}
					for prop, want in pairs(game) do
						local field = ns.UnitPropField(unit, prop)
						if (facts[field] and true or false) ~= want then wrong[#wrong + 1] = field end
					end
					r:Verdict(#wrong == 0, ("%s: elite, rare, quest, tapped, critter, targeting you match the game%s"):format(
						unit, #wrong > 0 and (": wrong " .. table.concat(wrong, ", ")) or ""))
				end
			end
		end },
		{ key = "values", title = "phase 4's value words: zone:, aura: and the rest, where you stand", seconds = 20,
			proven = "run 2 (queue qde9b), 2026-11-25: 15/15", run = function(r)
			-- (Tools/cql-words-plan.md phase 4, 2026-11-25: RuleAxes.lua. Each
			-- axis's menu picks what's here; that word must read true here,
			-- and a made-up value false. No action.)
			CloseSettings()
			local function Pick(axis)
				local a = ns.RULE_AXES[axis]
				local ok, list = pcall(a.Pick)
				return ok and list or {}, not ok and list or nil
			end
			for _, axis in ipairs({ "zone", "subzone", "instance", "class", "race", "spec", "aura", "form", "mount",
				"targetid", "window", "camera" }) do
				local list, err = Pick(axis)
				if err then
					r:Verdict(false, axis .. ": its menu errored: " .. tostring(err))
				else
					r:Log(("%s menu: %d (%s)"):format(axis, #list, table.concat((function()
						local t = {}
						for i = 1, math.min(4, #list) do t[#t + 1] = list[i][1] .. " = " .. tostring(list[i][2]) end
						return t
					end)(), "; ")))
				end
				-- (Where the menu offers what's here: its first must read true.
				-- window, camera and class list every kind, not what's here
				-- (run q1d3a: class:warrior first, on a warlock); class: yours.)
				if axis == "class" then
					local _, file = UnitClass("player")
					list = file and { { "class:" .. file:lower(), file } } or {}
				end
				if list[1] and axis ~= "window" and axis ~= "camera" then
					local test, why = ns.CompileRule(list[1][1])
					ns.RuleFactsAll()
					local on = test and test(ns.RuleFactsAll())
					r:Verdict(on == true, ("%s: %s reads true here%s"):format(axis, list[1][1], why and (" (" .. why .. ")") or ""))
					local fake = ns.CompileRule(axis .. ":nosuchvalue987")
					r:Verdict(fake ~= nil and fake(ns.RuleFactsAll()) == false, axis .. ": a made-up value reads false")
				end
			end
			-- (A whole rule as the editor shows it: the names next to the ids.)
			local zone = Pick("zone")
			if zone[1] then
				local shown = ns.ColoredRule(zone[1][1] .. " and not combat")
				r:Log("shown: " .. shown:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
				r:Verdict(shown:find(zone[1][2], 1, true) ~= nil, "the editor shows the zone's name next to its id")
			end
			-- (The editor's Values line: open, nothing cut or covered.)
			ns.OpenOptions("Tooltips")
			r:Sleep(0.5)
			if type(ns.db.ruleEditorOpen) ~= "table" then ns.db.ruleEditorOpen = {} end
			local open = ns.db.ruleEditorOpen
			local was = open["zone:"]
			open["zone:"] = true
			local rule = zone[1] and (zone[1][1] .. " and not combat") or "class:mage"
			ns.OpenRuleEditor({ key = ROW, label = ROW, Text = function() return rule end,
				SetText = function() end, ResetToGrid = function() end, Close = function() end })
			r:Sleep(0.6)
			local editor = _G.CinematicRuleEditor
			local found
			for _, l in ipairs(editor and editor.lines or {}) do if l.key == "zone:" then found = l end end
			r:Verdict(found ~= nil, "rule editor: a Values line")
			if found then
				local look = LineLook(r, editor, found)
				r:Verdict(look.shown == look.total and look.cut == 0 and #look.covered == 0 and look.past == 0,
					("rule editor, Values line open: %d of %d shown, %d cut short, %d covered, %d past the edge"):format(
					look.shown, look.total, look.cut, #look.covered, look.past))
			end
			r:Shot("rule editor: the Values line, a zone rule", { behind = editor })
			open["zone:"] = was
			if editor then editor:Hide() end
			CloseSettings()
		end },
		{ key = "state", title = "phase 2's words: you, the zone, your screen, talking", seconds = 40,
			proven = "run 2 (queue q4a77), 2026-11-25: 32/32", run = function(r)
			-- (Tools/cql-words-plan.md phase 2, 2026-11-25: Frames.lua's
			-- ns.StateWords. Each against the game's own answer; the map and a
			-- game window opened by the test; one action: talk to an NPC.)
			CloseSettings() -- (a step before left them open: run qc7ea)
			r:Sleep(0.6)
			r:Log("windows up at the start: " .. WindowsUp())
			local words = {}
			for _, w in ipairs(ns.STATE_WORDS) do words[#words + 1] = w[1] end
			ns.CompileRule(table.concat(words, " or ")) -- (read from now: ns.factsUsed)
			local function Facts() return ns.RuleFactsAll() end
			local function Say(fn, ...)
				if type(fn) ~= "function" then return "none" end
				local ok, v = pcall(fn, ...)
				if not ok then return "error" end
				if not Plain(v) then return "secret" end
				return v
			end
			local facts = Facts()
			local line = {}
			for _, w in ipairs(words) do line[#line + 1] = w .. "=" .. tostring(facts[w]) end
			r:Log("words: " .. table.concat(line, " "))
			local pvpGet = C_PvP and C_PvP.GetZonePVPInfo or GetZonePVPInfo
			local pvp = Say(pvpGet)
			local cap = Say(GetMaxLevelForPlayerExpansion or GetMaxPlayerLevel)
			local pad = Say(C_GamePad and C_GamePad.GetActiveDeviceID)
			r:Log(("game: ghost %s, dnd %s, vehicle %s, pet %s, leader %s, raid %s, level %s of %s, falling %s,"
				.. " full control %s, zone pvp %s, instance %s, gamepad on %s, active device %s, last pad event %s"):format(
				tostring(Say(UnitIsGhost, "player")), tostring(Say(UnitIsDND, "player")),
				tostring(Say(UnitInVehicle, "player")), tostring(Say(UnitExists, "pet")),
				tostring(Say(UnitIsGroupLeader, "player")), tostring(Say(IsInRaid)), tostring(UnitLevel("player")),
				tostring(cap), tostring(Say(IsFalling)), tostring(Say(HasFullControl)), tostring(pvp),
				tostring(select(2, IsInInstance())), tostring(ns.IsGamePadOn()), tostring(pad),
				tostring(ns.gamePadState.active)))
			local function Match(word, game)
				if game == "secret" or game == "error" or game == "none" then
					return r:Log(word .. ": the game won't say (" .. game .. "), not judged")
				end
				r:Verdict((facts[word] and true or false) == (game and true or false),
					("%s matches the game (%s)"):format(word, tostring(game)))
			end
			Match("ghost", Say(UnitIsGhost, "player"))
			Match("dnd", Say(UnitIsDND, "player"))
			Match("pet", Say(UnitExists, "pet"))
			Match("raidgroup", Say(IsInRaid))
			Match("falling", Say(IsFalling))
			if type(cap) == "number" then Match("maxlevel", UnitLevel("player") >= cap) end
			local full = Say(HasFullControl)
			if type(full) == "boolean" then Match("controlled", not full and not ns.OnTaxi()) end
			Match("sanctuary", pvp == "sanctuary")
			Match("contested", pvp == "contested")
			Match("scenario", select(2, IsInInstance()) == "scenario")
			-- (Phase 2's rest: each where the client has its call.)
			local threat = Say(UnitThreatSituation, "player")
			if type(threat) == "number" or threat == nil then Match("aggro", (threat or 0) >= 2) end
			if C_PvP and C_PvP.IsWarModeActive then Match("warmode", Say(C_PvP.IsWarModeActive)) end
			if C_PartyInfo and C_PartyInfo.IsDelveInProgress then Match("delve", Say(C_PartyInfo.IsDelveInProgress)) end
			if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive then
				Match("mythicplus", Say(C_ChallengeMode.IsChallengeModeActive))
			end
			if C_Housing and C_Housing.IsInsideHouseOrPlot then Match("housing", Say(C_Housing.IsInsideHouseOrPlot)) end
			local _, class = UnitClass("player")
			local form = Say(GetShapeshiftForm)
			r:Log(("form %s (%s), threat %s, pvp fight now %s"):format(tostring(form), tostring(class), tostring(threat),
				tostring(ns.CardPvpFight and ns.CardPvpFight())))
			if type(form) == "number" then
				local formClass = class == "DRUID" or class == "SHAMAN" or class == "PRIEST" or class == "WARLOCK"
				Match("shapeshifted", formClass and form > 0)
			end
			Match("pvpfight", false) -- (out of a fight: never)
			local editMode, WorldMapFrame = _G.EditModeManagerFrame, _G.WorldMapFrame
			Match("editmode", editMode ~= nil and editMode:IsShown())
			-- (The map, opened and closed by the test: mapopen, and menuopen with it.)
			if ToggleWorldMap and WorldMapFrame and not WorldMapFrame:IsShown() then
				ToggleWorldMap()
				r:Sleep(0.6)
				facts = Facts()
				r:Log("map: windows up " .. WindowsUp())
				r:Verdict(WorldMapFrame:IsShown() and facts.mapopen == true and facts.menuopen == true,
					("map open: mapopen %s, menuopen %s"):format(tostring(facts.mapopen), tostring(facts.menuopen)))
				r:Shot("the map open (mapopen)")
				ToggleWorldMap()
				r:Sleep(0.6)
				facts = Facts()
				r:Verdict(not WorldMapFrame:IsShown() and facts.mapopen == false,
					"map closed: mapopen " .. tostring(facts.mapopen))
			end
			-- (Your character window: menuopen, not mapopen.)
			if ToggleCharacter and CharacterFrame then
				ToggleCharacter("PaperDollFrame")
				r:Sleep(0.6)
				facts = Facts()
				r:Log("character window: windows up " .. WindowsUp())
				r:Verdict(CharacterFrame:IsShown() and facts.menuopen == true and facts.mapopen == false,
					("character window: menuopen %s, mapopen %s"):format(tostring(facts.menuopen),
					tostring(facts.mapopen)))
				if CharacterFrame:IsShown() then HideUIPanel(CharacterFrame) end
				r:Sleep(0.6)
				local closed = Facts().menuopen
				r:Verdict(closed == false, "character window closed: menuopen false (windows up " .. WindowsUp() .. ")")
			end
			-- (The one action: a conversation. talking with interacting; and
			-- talking false again once it's closed. Not a vendor: a shop is
			-- interacting, not talking (run qc7ea got stuck on one). Each change
			-- logged, so a stuck wait says what it saw.)
			local talked, seen = false, nil
			local function Up(name) local f = _G[name] return tostring(f ~= nil and f:IsShown()) end
			r:WaitFor("Talk to an NPC that greets you with text (an innkeeper, a guard or a quest giver), then close it.", {
				check = function()
					local f = Facts()
					local now = ("interacting %s, talking %s; windows %s; npc unit %s"):format(tostring(f.interacting),
						tostring(f.talking), WindowsUp(), tostring(ns.Flag(UnitExists("npc"))))
					if now ~= seen then seen = now r:Log("seen: " .. now) end
					if f.talking and f.interacting and not talked then
						talked = true
						r:Log(("talking: gossip %s, quest %s, item text %s, talking head %s, npc unit %s"):format(
							Up("GossipFrame"), Up("QuestFrame"), Up("ItemTextFrame"), Up("TalkingHeadFrame"),
							tostring(ns.Flag(UnitExists("npc")))))
					end
					return (talked and not f.talking and not f.interacting) or nil
				end })
			r:Verdict(talked, "talking and interacting while you talked to the NPC, both off after")
			-- (The rule editor: the You and Screen lines, nothing cut or covered.)
			ns.OpenOptions("Tooltips")
			r:Sleep(0.5)
			if type(ns.db.ruleEditorOpen) ~= "table" then ns.db.ruleEditorOpen = {} end
			local open = ns.db.ruleEditorOpen
			local wasYou, wasScreen = open.interacting, open.mapopen
			open.interacting, open.mapopen = true, true -- (both lines opened: every word shown)
			ns.OpenRuleEditor({ key = ROW, label = ROW, Text = function() return "talking and not mapopen" end,
				SetText = function() end, ResetToGrid = function() end, Close = function() end })
			r:Sleep(0.6)
			local editor = _G.CinematicRuleEditor
			for _, l in ipairs(editor and editor.lines or {}) do
				if l.key == "interacting" or l.key == "mapopen" then
					local look = LineLook(r, editor, l)
					r:Verdict(look.shown == look.total and look.cut == 0 and #look.covered == 0 and look.past == 0,
						("rule editor, %s line open: %d of %d shown, %d cut short, %d covered, %d past the edge"):format(
						l.key, look.shown, look.total, look.cut, #look.covered, look.past))
				end
			end
			r:Shot("rule editor: the You and Screen lines open", { behind = editor })
			open.interacting, open.mapopen = wasYou, wasScreen
			if editor then editor:Hide() end
			CloseSettings()
		end },
	},
})
