-- /cine debug rulewords: one run on the Show in rule words for travel and you
-- (moving, autorun, rpwalk, swimming, flying, gliding, afk, outdoors,
-- resting, stealthed, sitting, npc). Steps on screen, each waiting as long as
-- it takes; "/cine debug rulewords skip" passes a step you can't do, the
-- command alone again stops the run.
--   Part A, the player's case: the Minimap row's rule set to "not combat and
--   not autorun", and the Minimap page's own ways up (Keep open, the Reveal
--   boxes, quest givers, Questie, pings: MINIMAP_EXTRAS) off for the run, so
--   only the rule decides (all put back at the end; what holds the minimap
--   up is logged as it changes). CineMode on, the settings closed. Standing
--   still it shows; auto-run fades it (how soon after the key); stopping
--   brings it back; walking with W held keeps it; the same in a city; a
--   fight fades it.
--   Part B, the editor's dots: the test opens the Minimap row, you click its
--   Edit (the test keeps that row's editor), then close the settings: the
--   test opens the editor again on its own, its text box let go so your keys
--   move you, and again whenever it closes. Its Travel line is checked for
--   overlaps and shot, the Gliding button looked for (retail only), then each
--   word is turned on (held a second, else asked again) and off, its dot
--   timed against the word.
-- Logged every change, with seconds from the start: each word as the Minimap
-- row's rule reads it (ns.RuleFactsFor), the game's own answers behind them
-- (IsFlying, IsSwimming, UnitIsAFK, IsResting, IsStealthed, IsOutdoors,
-- IsIndoors, UnitOnTaxi, the glide, our moving / auto-run / walk follow, keys
-- held, the last emote, NPC windows shown, UnitExists("npc"); "secret" when
-- the game hides one), the editor's dots and the minimap's opacity. A RESULT
-- line per check, screenshots paced 1.5 s apart. Into CinematicDB.ruleWordsLog.
-- Dev copy only (CinematicDev.toc).
local _, ns = ...

local RULE = "not combat and not autorun"
local NEW = { "moving", "autorun", "rpwalk", "swimming", "flying", "gliding", "afk", "outdoors", "resting",
	"stealthed", "sitting", "npc" }
local CONTEXT = { "combat", "taxi", "indoors", "city", "inn", "mounted", "dead" }
local NPC_FRAMES = { "MerchantFrame", "MailFrame", "GossipFrame", "QuestFrame", "TaxiFrame", "ItemTextFrame",
	"BankFrame", "ClassTrainerFrame", "AuctionFrame", "AuctionHouseFrame", "TradeFrame" }
local DOT_LAG = 1.0 -- seconds the editor's dot may take (it refreshes every half second)
local QUICK = 0.5 -- seconds: the most auto-run may take to start the minimap's fade
local STILL = 4 -- seconds standing still / walking by hand
local MOVED = 0.05 -- opacity: a change this big counts as a fade starting
local SHOT_GAP = 1.5 -- seconds between screenshots (one file a second, see test-screenshot-pacing)

-- The Minimap page's settings that bring the minimap up apart from its row
-- (Keep open's tracking and prey, the Reveal boxes, pings): off in the run.
local MINIMAP_EXTRAS = { "minimapKeepOpen", "minimapRevealNodes", "minimapRevealTurnIns", "minimapRevealAreas",
	"minimapRevealIcons", "minimapQuestGivers", "minimapQuestie", "minimapNodesByCursor", "minimapRevealOnPing" }
local HOLD = DOT_LAG + 0.2 -- seconds a word must stay on before the step asks for it off

local run
local autoRunKeyAt = -math.huge -- (the auto-run key, from a hook made once)

local function Say(text)
	local log = CinematicDB and CinematicDB.ruleWordsLog
	if log then log[#log + 1] = ("%.2f %s"):format(run and GetTime() - run.at or 0, text) end
end

local function Secret(value)
	return issecretvalue ~= nil and issecretvalue(value)
end
-- A game call's answer as text: "secret", "none" (no such call), "error".
local function Ask(fn, ...)
	if type(fn) ~= "function" then return "none" end
	local ok, a = pcall(fn, ...)
	if not ok then return "error" end
	if Secret(a) then return "secret" end
	return tostring(a and true or false)
end

local function CineOn()
	return ns.IsCineModeOn and ns.IsCineModeOn() and true or false
end
local function SetCine(on)
	if CineOn() ~= on and _G.Cinematic_ToggleCineMode then
		_G.Cinematic_ToggleCineMode()
		Say("  CineMode turned " .. (on and "ON" or "OFF") .. " by the test")
	end
end
local function SettingsOpen()
	return ns.SettingsPanelShown and ns.SettingsPanelShown() and true or false
end
local function EditorOpen()
	local editor = _G.CinematicRuleEditor
	return editor ~= nil and editor:IsShown() and true or false
end

local function Prompt(text, sub)
	ns.PadTestBox(text, sub or "", 1, 0.82, 0)
	Say("BOX " .. text .. (sub and sub ~= "" and (" / " .. sub) or ""))
end

local function Result(key, ok, text)
	local mark = ok == nil and "" or ok and "PASS " or "FAIL "
	run.results[#run.results + 1] = mark .. key .. ": " .. text
	Say("RESULT " .. key .. ": " .. mark .. text)
end

local function Shot(label)
	run.shots[#run.shots + 1] = { label = label, at = GetTime() + 1 }
end

-- The minimap's opacity as you see it (nil: can't be read).
local function MinimapAlpha()
	local frame = _G.Minimap
	if not frame or not frame.GetEffectiveAlpha then return nil end
	local ok, alpha = pcall(frame.GetEffectiveAlpha, frame)
	if not ok or Secret(alpha) or type(alpha) ~= "number" then return nil end
	local okShown, shown = pcall(frame.IsVisible, frame)
	if okShown and not Secret(shown) and not shown then return 0 end
	return alpha
end

-- What holds the minimap up now: its rule, and the Minimap page's own ways
-- (as /cine why says them).
local function MinimapHeld(now)
	local held = {}
	local test = ns.RuleTest and ns.RuleTest("minimap")
	if test then
		local ok, on = pcall(test, ns.RuleFactsFor("minimap"))
		held[#held + 1] = "rule " .. (ok and (on and "shown" or "hidden") or "error")
	end
	if ns.IsKeepingMinimapForTracking then
		local ok, gathering, creatures = pcall(ns.IsKeepingMinimapForTracking, now)
		if not ok then held[#held + 1] = "tracking error"
		elseif gathering then held[#held + 1] = "gathering tracking" end
		if creatures then held[#held + 1] = "creature tracking" end
	end
	if ns.MinimapRevealWhy then
		local ok, revealed, names, fight, kind = pcall(ns.MinimapRevealWhy, now)
		if ok and revealed then
			held[#held + 1] = ("reveal %s (%s)%s"):format(tostring(kind), tostring(names),
				fight and ", held into the fight" or "")
		end
	end
	return table.concat(held, ", ")
end

-- The words, as the Minimap row's rule (and its editor's dots) read them.
local function Words()
	local facts = ns.RuleFactsFor and ns.RuleFactsFor("minimap") or {}
	local out = {}
	for _, word in ipairs(NEW) do out[word] = facts[word] and true or false end
	for _, word in ipairs(CONTEXT) do out[word] = facts[word] and true or false end
	return out
end

-- The game's answers behind the words.
local function Raw()
	local raw = {
		IsFlying = Ask(_G.IsFlying), IsSwimming = Ask(_G.IsSwimming), UnitIsAFK = Ask(_G.UnitIsAFK, "player"),
		IsResting = Ask(_G.IsResting), IsStealthed = Ask(_G.IsStealthed), IsOutdoors = Ask(_G.IsOutdoors),
		IsIndoors = Ask(_G.IsIndoors), UnitOnTaxi = Ask(_G.UnitOnTaxi, "player"),
		IsPlayerMoving = Ask(_G.IsPlayerMoving), npcUnit = Ask(_G.UnitExists, "npc"),
		playerMoving = tostring(ns.playerMoving and true or false), autoRunning = tostring(ns.autoRunning and true or false),
		walkMode = tostring(ns.walking and true or false),
		IsAutoRunning = ns.IsAutoRunning and tostring(ns.IsAutoRunning() and true or false) or "none",
		IsRPWalking = ns.IsRPWalking and tostring(ns.IsRPWalking() and true or false) or "none",
		IsSitting = ns.IsSitting and tostring(ns.IsSitting() and true or false) or "none",
		held = ns.HeldMovementWhat and ns.HeldMovementWhat() or "-",
		emote = ns.lastEmote and tostring(ns.lastEmote.token) .. " via " .. tostring(ns.lastEmote.via) or "-",
	}
	local glide = "none"
	if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
		local ok, gliding, canGlide = pcall(C_PlayerInfo.GetGlidingInfo)
		if not ok then glide = "error"
		elseif Secret(gliding) or Secret(canGlide) then glide = "secret"
		else glide = ("gliding %s, can %s"):format(tostring(gliding), tostring(canGlide)) end
	end
	raw.glide = glide
	local shown = {}
	for _, name in ipairs(NPC_FRAMES) do
		local frame = _G[name]
		if frame and frame.IsShown then
			local ok, on = pcall(frame.IsShown, frame)
			if ok and not Secret(on) and on then shown[#shown + 1] = name end
		end
	end
	raw.npcFrames = #shown > 0 and table.concat(shown, ",") or "-"
	return raw
end
local RAW_ORDER = { "IsFlying", "IsSwimming", "UnitIsAFK", "IsResting", "IsStealthed", "IsOutdoors", "IsIndoors",
	"UnitOnTaxi", "IsPlayerMoving", "glide", "playerMoving", "autoRunning", "walkMode", "IsAutoRunning",
	"IsRPWalking", "IsSitting", "held", "emote", "npcFrames", "npcUnit" }

-- The editor's word buttons (word -> button), found by their labels.
local function DotButtons()
	local editor = _G.CinematicRuleEditor
	if not editor or not ns.RulePieces then return {} end
	if run.dotsOf == editor and run.dotButtons then return run.dotButtons end
	local byLabel = {}
	for _, group in ipairs(ns.RulePieces()) do
		for _, piece in ipairs(group[3]) do
			if type(piece[1]) == "string" and type(piece[2]) == "string" then byLabel[piece[2]] = piece[1] end
		end
	end
	local found = {}
	local function Walk(frame, depth)
		if depth > 6 then return end
		for _, child in ipairs({ frame:GetChildren() }) do
			if child.dot and child.GetText then
				local text = tostring(child:GetText() or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
				local word = byLabel[text]
				if word then found[word] = child end
			end
			Walk(child, depth + 1)
		end
	end
	Walk(editor, 0)
	run.dotsOf, run.dotButtons = editor, found
	return found
end

-- Logs whatever changed; keeps each word's last change time and each dot's lag.
local function Watch(now)
	local words = Words()
	for word, on in pairs(words) do
		if run.words[word] ~= on then
			if run.words[word] ~= nil then Say(("word %s %s"):format(word, on and "ON" or "off")) end
			run.words[word], run.wordAt[word] = on, now
		end
	end
	local raw = Raw()
	for _, key in ipairs(RAW_ORDER) do
		if run.raw[key] ~= raw[key] then
			if run.raw[key] ~= nil then Say(("  game %s: %s"):format(key, raw[key])) end
			run.raw[key] = raw[key]
		end
	end
	local alpha = MinimapAlpha()
	local bucket = alpha and math.floor(alpha * 20 + 0.5) / 20
	if bucket ~= run.alphaLogged then
		run.alphaLogged = bucket
		Say(("  minimap opacity %s"):format(alpha and ("%.2f"):format(alpha) or "?"))
	end
	run.alpha = alpha
	local held = MinimapHeld(now)
	if held ~= run.heldLogged then
		run.heldLogged = held
		Say("  minimap: " .. (held ~= "" and held or "nothing of its own"))
	end
	local open = EditorOpen()
	if open ~= run.editorOpen then
		run.editorOpen = open
		Say("  rule editor " .. (open and "open" or "closed"))
		run.dotButtons = nil
	end
	local cine, settings = CineOn(), SettingsOpen()
	if cine ~= run.cineLogged or settings ~= run.settingsLogged then
		run.cineLogged, run.settingsLogged = cine, settings
		Say(("  CineMode %s, settings %s"):format(cine and "on" or "off", settings and "open" or "closed"))
	end
	if open then
		for word, button in pairs(DotButtons()) do
			local dot = button.dot:IsShown() and true or false
			if run.dots[word] ~= dot then
				local lag = now - (run.wordAt[word] or now)
				Say(("  dot %s %s (%s)"):format(word, dot and "ON" or "off", dot == words[word]
					and ("%.2f s after the word"):format(lag) or "the word says " .. tostring(words[word])))
				run.dots[word] = dot
				if dot == words[word] then
					run.dotLags[word] = run.dotLags[word] or {}
					table.insert(run.dotLags[word], { on = dot, lag = lag, at = now })
				end
			end
		end
	else
		run.dots = {}
	end
	return words
end

local function Fmt(t) return ("%.2f s"):format(t) end

-- Part A's measure of a fade: from fromAt, the minimap's opacity moving
-- down (fade out) or up (back), and how long till done.
local function FadeWatch(down, fromAt)
	return { down = down, from = fromAt, base = run.alpha }
end
local function FadeCheck(f, now)
	local a = run.alpha
	if not a or not f.base then return end
	if not f.startedAt and ((f.down and a <= f.base - MOVED) or (not f.down and a >= f.base + MOVED)) then
		f.startedAt = now
	end
	if not f.doneAt and ((f.down and a <= 0.05) or (not f.down and a >= 0.95)) then f.doneAt = now end
end

-- A step that turns a word on and then off (first = false: off, then on).
-- extra(step, words, now): more checks while it runs; result(step): more text.
local function Cycle(key, word, onText, offText, opts)
	opts = opts or {}
	return {
		key = key, part = "B", word = word, first = opts.first ~= false, onText = onText, offText = offText,
		extra = opts.extra, more = opts.more, sub = opts.sub,
	}
end

local function DotText(step)
	if not step.editorSeen then return nil, "dot not checked: the editor was closed" end
	local lags = run.dotLags[step.word] or {}
	local want, got = { step.first, not step.first }, {}
	local idx = 1
	for i = step.lagFrom or 1, #lags do
		if idx <= 2 and lags[i].on == want[idx] then got[idx] = lags[i].lag idx = idx + 1 end
	end
	local ok = got[1] ~= nil and got[2] ~= nil and got[1] <= DOT_LAG and got[2] <= DOT_LAG
	return ok, ("dot %s after %s, %s after %s"):format(want[1] and "on" or "off", got[1] and Fmt(got[1]) or "never",
		want[2] and "on" or "off", got[2] and Fmt(got[2]) or "never")
end

local STEPS -- (built at the start: the client's)
local Go

local function NextStep()
	run.index = run.index + 1
	local step = STEPS[run.index]
	if not step then return nil end
	Go(step)
	return step
end

Go = function(step)
	run.step, run.stepAt = step, GetTime()
	step.phase, step.t = 1, {}
	step.lagFrom = run.dotLags[step.word or ""] and #run.dotLags[step.word] + 1 or 1
	Say(("--- step %d/%d %s (CineMode %s, settings %s, editor %s) ---"):format(run.index, #STEPS, step.key,
		tostring(CineOn()), tostring(SettingsOpen()), tostring(EditorOpen())))
	if step.start then step.start(step) end
	local n = ("Rule words %d/%d: "):format(run.index, #STEPS)
	if step.word then
		Prompt(n .. step.onText, step.sub or "Or type /cine debug rulewords skip")
	elseif step.prompt then
		Prompt(n .. step.prompt, step.sub or "")
	end
end

-- One word's step, on then off.
local function RunCycle(step, words, now)
	local want = step.first
	if EditorOpen() then step.editorSeen = true end
	if step.extra then step.extra(step, words, now) end
	if step.phase == 1 then
		if words[step.word] == want then
			step.t.firstAt = now
			-- (The dot's changes from here on: this one's may just have come.)
			local lags = run.dotLags[step.word] or {}
			step.lagFrom = #lags + 1
			if #lags > 0 and lags[#lags].on == want and now - (lags[#lags].at or 0) < 0.1 then
				step.lagFrom = #lags
			end
			Say(("  %s %s"):format(step.word, want and "turned on" or "turned off"))
			step.phase = 1.5
		end
	elseif step.phase == 1.5 then
		-- (Held long enough for the dot to be read, or asked again.)
		if words[step.word] ~= want then
			Say(("  %s went back after %s: asked again"):format(step.word, Fmt(now - step.t.firstAt)))
			step.phase = 1
		elseif now - step.t.firstAt >= HOLD then
			Shot(step.key .. ": " .. step.word .. (want and " on" or " off"))
			step.phase = 2
			Prompt(("Rule words %d/%d: "):format(run.index, #STEPS) .. step.offText, "")
		end
	elseif step.phase == 2 then
		if words[step.word] ~= want then
			step.t.secondAt = now
			step.phase = 3
		end
	elseif step.phase == 3 and now - step.t.secondAt >= DOT_LAG + 0.2 then
		local dotOk, dotText = DotText(step)
		local more = step.more and step.more(step) or nil
		Result(step.key, dotOk ~= false and (step.ok == nil or step.ok), ("%s %s then %s; %s%s"):format(step.word,
			want and "on" or "off", want and "off" or "on", dotText, more and ("; " .. more) or ""))
		return true
	end
end

-- Part A: auto-run fades the minimap. tag: "" or " (city)".
local function AutoRunStep(tag)
	return {
		key = "autorun" .. (tag ~= "" and "-city" or ""), part = "A",
		prompt = "Press your auto-run key and let it run" .. tag, sub = "Keep your hands off the movement keys.",
		run = function(step, words, now)
			if step.phase == 1 then
				if ns.playerMoving and not step.t.moveAt then step.t.moveAt = now end
				if words.autorun then
					local pressed = now - autoRunKeyAt < 3 and autoRunKeyAt or step.t.moveAt or now
					step.t.pressAt, step.t.wordAt = pressed, now
					step.fade = FadeWatch(true, pressed)
					step.fade.base = step.t.alphaBefore or run.alpha
					Say(("  auto-run seen %s after the %s"):format(Fmt(now - pressed),
						now - autoRunKeyAt < 3 and "key" or "first step"))
					step.phase = 2
				else
					step.t.alphaBefore = run.alpha
				end
			elseif step.phase == 2 then
				FadeCheck(step.fade, now)
				local limit = (ns.db.fadeOutTime or 1) + 3
				if step.fade.doneAt or now - step.t.wordAt > limit then
					local f, p = step.fade, step.t.pressAt
					local start = f.startedAt and f.startedAt - p
					Result(step.key, start ~= nil and start <= QUICK, ("auto-run%s: word %s after the key, minimap fade"
						.. " started %s after, gone %s after (city %s, resting %s)"):format(tag, Fmt(step.t.wordAt - p),
						start and Fmt(start) or "never", f.doneAt and Fmt(f.doneAt - p) or "never",
						tostring(words.city), tostring(words.resting)))
					Shot(step.key .. ": minimap faded")
					return true
				end
			end
		end,
	}
end
local function StopStep(tag)
	return {
		key = "stop" .. (tag ~= "" and "-city" or ""), part = "A",
		prompt = "Stop auto-run (press it again, or S) and stand still" .. tag,
		run = function(step, words, now)
			if step.phase == 1 then
				if not words.moving and not words.autorun then
					step.t.stopAt = now
					step.fade = FadeWatch(false, now)
					step.fade.base = run.alpha
					step.phase = 2
				end
			elseif step.phase == 2 then
				FadeCheck(step.fade, now)
				local limit = (ns.db.fadeInTime or 1) + 3
				local back = (run.alpha or 0) >= 0.95
				if back or now - step.t.stopAt > limit then
					Result(step.key, back, ("stopped%s: minimap %s (started %s after, opacity %s)"):format(tag,
						back and "back" or "not back", step.fade.startedAt and Fmt(step.fade.startedAt - step.t.stopAt)
						or "at once", run.alpha and ("%.2f"):format(run.alpha) or "?"))
					return true
				end
			end
		end,
	}
end

local function BuildSteps(only)
	local steps = {}
	local function Add(step) steps[#steps + 1] = step end
	-- Part A
	Add({ key = "still", part = "A", prompt = "Stand still, hands off the keys",
		sub = ("%d seconds. (Close the settings first if they're open.)"):format(STILL),
		run = function(step, words, now)
			if SettingsOpen() or words.moving then step.t.from = nil return end
			step.t.from = step.t.from or now
			step.t.low = math.min(step.t.low or 1, run.alpha or 0)
			if now - step.t.from >= STILL then
				Result("still", (run.alpha or 0) >= 0.9, ("standing still: minimap opacity %s (lowest %.2f), autorun %s"):format(
					run.alpha and ("%.2f"):format(run.alpha) or "?", step.t.low, tostring(words.autorun)))
				return true
			end
		end })
	Add(AutoRunStep(""))
	Add(StopStep(""))
	Add({ key = "walk", part = "A", prompt = "Hold W and walk forward", sub = ("Keep holding it for %d seconds."):format(STILL),
		run = function(step, words, now)
			if not (words.moving and ns.MovingManually and ns.MovingManually()) then step.t.from = nil return end
			step.t.from = step.t.from or now
			step.t.low = math.min(step.t.low or 1, run.alpha or 0)
			if words.autorun then step.t.autorun = true end
			if now - step.t.from >= STILL then
				Result("walk", not step.t.autorun and step.t.low >= 0.9, ("walking by hand %ds: autorun %s, minimap"
					.. " lowest %.2f"):format(STILL, step.t.autorun and "turned ON" or "stayed off", step.t.low))
				return true
			end
		end })
	Add({ key = "city", part = "A", prompt = "Go to a city and stand still there",
		sub = "Or type /cine debug rulewords skip",
		run = function(step, words, now)
			if (words.city or words.resting) and not words.moving then
				step.t.from = step.t.from or now
				if now - step.t.from >= 2 then
					Say(("  in a city: city %s, resting %s"):format(tostring(words.city), tostring(words.resting)))
					return true
				end
			else
				step.t.from = nil
			end
		end })
	Add(AutoRunStep(" (city)"))
	Add(StopStep(" (city)"))
	Add({ key = "fight", part = "A", prompt = "Attack any enemy and keep fighting",
		sub = "A training dummy is fine.",
		run = function(step, words, now)
			if step.phase == 1 then
				if words.combat then
					step.t.fightAt = now
					step.fade = FadeWatch(true, now)
					step.fade.base = run.alpha
					step.phase = 2
				end
			elseif step.phase == 2 then
				FadeCheck(step.fade, now)
				if step.fade.doneAt or now - step.t.fightAt > (ns.db.fadeOutTime or 1) + 3 then
					local raw, secrets = Raw(), {}
					for _, k in ipairs(RAW_ORDER) do if raw[k] == "secret" then secrets[#secrets + 1] = k end end
					Result("fight", step.fade.doneAt ~= nil, ("in a fight: minimap %s %s; secret in the fight: %s"):format(
						step.fade.doneAt and "gone" or "still up", step.fade.doneAt and Fmt(step.fade.doneAt - step.t.fightAt)
						.. " in" or "", #secrets > 0 and table.concat(secrets, ", ") or "none"))
					step.phase = 3
					Prompt(("Rule words %d/%d: "):format(run.index, #STEPS) .. "End the fight", "Win it, or run off.")
				end
			elseif not InCombatLockdown() then -- (not words.combat: the Calm Timer counts as combat there)
				return true
			end
		end })
	-- Part B
	Add({ key = "editor", part = "B", prompt = "Click Edit (the quill) on the Minimap row",
		sub = "Then wait for the next box.",
		start = function()
			local ok, err = pcall(ns.FindSetting, "row:minimap")
			Say("  opened row:minimap " .. (ok and "ok" or ("error: " .. tostring(err))))
		end,
		run = function(step, _, now)
			if step.phase == 3 then
				-- (The settings closed: the test's own editor up, your keys free.)
				if not SettingsOpen() and EditorOpen() then
					Result("editor-alone", true, "the editor stays up with the settings closed, its text box let go")
					return true
				end
				return
			end
			if step.phase == 1 then
				if EditorOpen() and run.target then step.t.openAt, step.phase = now, 2 end
			elseif step.phase == 2 and now - step.t.openAt >= 0.6 then
				-- The Travel line: its buttons in the editor and not on each other.
				local buttons, travel = DotButtons(), nil
				for _, group in ipairs(ns.RulePieces()) do
					if group[1] == ns.L["Travel"] then travel = group end
				end
				local editor, rects, bad = _G.CinematicRuleEditor, {}, {}
				local el, er = editor:GetLeft(), editor:GetRight()
				for _, piece in ipairs(travel and travel[3] or {}) do
					local b = buttons[piece[1]]
					if b then
						local r = { piece[1], b:GetLeft(), b:GetRight(), b:GetBottom(), b:GetTop() }
						if not r[2] or not r[3] or (el and r[2] < el - 0.5) or (er and r[3] > er + 0.5) then bad[#bad + 1] = piece[1] .. " outside the editor" end
						for _, o in ipairs(rects) do
							if r[2] < o[3] - 0.5 and o[2] < r[3] - 0.5 and r[4] < o[5] - 0.5 and o[4] < r[5] - 0.5 then
								bad[#bad + 1] = piece[1] .. " on " .. o[1]
							end
						end
						rects[#rects + 1] = r
						Say(("  Travel %s: left %.0f right %.0f top %.0f"):format(piece[1], r[2] or -1, r[3] or -1, r[5] or -1))
					else
						bad[#bad + 1] = piece[1] .. " missing"
					end
				end
				Result("layout", travel ~= nil and #bad == 0, ("Travel line: %d buttons%s"):format(#rects,
					#bad > 0 and (", " .. table.concat(bad, "; ")) or ", none overlapping"))
				local hasGlide = buttons.gliding ~= nil
				Result("gliding-button", hasGlide == (ns.isRetail and true or false), ("Gliding button %s on %s"):format(
					hasGlide and "shown" or "not shown", ns.isRetail and "retail" or "Forever"))
				Shot("editor: Travel line")
				step.phase = 3
				Prompt(("Rule words %d/%d: "):format(run.index, #STEPS) .. "Close the settings (their Close button)",
					"The rule editor comes back by itself and stays up while you play. Don't click in it.")
			end
		end })
	Add(Cycle("moving", "moving", "Walk a few steps", "Stop and stand still"))
	Add(Cycle("autorun", "autorun", "Press auto-run and let it run", "Stop auto-run", {
		extra = function(step, words) if words.autorun and words.rpwalk and not ns.walking then step.ok = false end end,
		more = function(step) return step.ok == false and "rpwalk turned on while running" or "rpwalk stayed off" end }))
	Add(Cycle("rpwalk", "rpwalk", "Press your walk key, then auto-run", "Stop, then press walk again to run",
		{ sub = "The walk key is / on the number pad by default.",
		extra = function(step, words) if words.rpwalk and not words.autorun then step.ok = false end end,
		more = function(step) return step.ok == false and "autorun was off while rpwalk was on" or "autorun on with it" end }))
	Add(Cycle("swimming", "swimming", "Get into deep water and swim", "Get out of the water"))
	Add(Cycle("flying", "flying", "Fly on a flying mount, in the air", "Land",
		{ sub = "Or type /cine debug rulewords skip" }))
	Add({ key = "flightpath", part = "B", prompt = "Take a flight path", sub = "Or type /cine debug rulewords skip",
		run = function(step, words, now)
			if words.taxi then
				step.t.on = true
				step.t.flying = (step.t.flying or false) or words.flying
				step.t.moving = (step.t.moving or false) or words.moving
				step.t.autorun = (step.t.autorun or false) or words.autorun
				if not step.t.shot then step.t.shot = true Shot("flight path") end
			elseif step.t.on then
				step.t.landAt = step.t.landAt or now
				if now - step.t.landAt > 0.5 then
					Result("flightpath", not step.t.moving and not step.t.autorun, ("on a flight path: flying %s,"
						.. " moving %s, autorun %s"):format(step.t.flying and "ON" or "off", step.t.moving and "ON" or "off",
						step.t.autorun and "ON" or "off"))
					return true
				end
			end
		end })
	if ns.isRetail then
		Add(Cycle("gliding", "gliding", "Skyride: take off, glide, and press auto-run mid-glide", "Land", {
			extra = function(step, words)
				if words.gliding and words.autorun then step.t.autorunGlide = true end
			end,
			more = function(step)
				return step.t.autorunGlide and "autorun turned ON mid-glide" or "autorun stayed off mid-glide"
			end }))
	end
	Add(Cycle("afk", "afk", "Type /afk", "Type /afk again"))
	Add(Cycle("outdoors", "outdoors", "Go into a building or a cave", "Go back outside", {
		first = false,
		extra = function(step, words) if words.outdoors == words.indoors then step.t.both = true end end,
		more = function(step) return step.t.both and "indoors and outdoors were the same at some point" or nil end }))
	Add(Cycle("resting", "resting", "Go into an inn (or a city) till you're resting", "Leave it",
		{ sub = "Or type /cine debug rulewords skip" }))
	Add(Cycle("stealthed", "stealthed", "Stealth (rogue Stealth or druid Prowl)", "Leave stealth",
		{ sub = "Or type /cine debug rulewords skip" }))
	Add(Cycle("sit-emote", "sitting", "Type /sit", "Stand up (jump or move)"))
	Add(Cycle("sit-key", "sitting", "Press the sit key (X by default)", "Press it again, or jump"))
	local function NpcMore()
		return function(step) return "windows seen: " .. (step.t.frames or "none") end
	end
	local function NpcExtra(step)
		local frames = run.raw.npcFrames
		if frames and frames ~= "-" and not (step.t.frames or ""):find(frames, 1, true) then
			step.t.frames = (step.t.frames and step.t.frames .. " " or "") .. frames
		end
	end
	Add(Cycle("npc-vendor", "npc", "Open a vendor", "Close it", { extra = NpcExtra, more = NpcMore() }))
	Add(Cycle("npc-mail", "npc", "Open a mailbox", "Close it", { extra = NpcExtra, more = NpcMore() }))
	Add(Cycle("npc-quest", "npc", "Talk to a quest giver", "Close the window", { extra = NpcExtra, more = NpcMore() }))
	-- Short runs: only what the full one left. "minimap": Part A without the
	-- city. "glide" (retail): the Gliding button read off the editor's pieces
	-- (no editor to open), then a glide.
	local SHORT = { minimap = { still = true, autorun = true, stop = true, walk = true, fight = true },
		glide = { ["glide-button"] = true, gliding = true } }
	local keep = SHORT[only]
	if not keep then return steps end
	if only == "glide" then
		table.insert(steps, 1, { key = "glide-button", part = "B", prompt = "Checking the editor's Gliding button",
			run = function()
				local found = false
				for _, group in ipairs(ns.RulePieces()) do
					for _, piece in ipairs(group[3]) do
						if piece[1] == "gliding" then found = group[1] end
					end
				end
				Result("gliding-button", (found ~= false) == (ns.isRetail and true or false), ("Gliding button %s on %s"):format(
					found and ("on the " .. tostring(found) .. " line") or "not in the editor", ns.isRetail and "retail" or "Forever"))
				return true
			end })
	end
	local short, part = {}, only == "minimap" and "A" or "B"
	for _, step in ipairs(steps) do
		if keep[step.key] and step.part == part then short[#short + 1] = step end
	end
	return short
end

-- What a run changes, put back from CinematicDB.ruleWordsUndo (saved at its
-- start, so a /reload mid-run, which skips Finish, is put right at the next
-- login). Returns what it did, in words.
local NIL = "<nil>" -- (a setting that wasn't set: SavedVariables keeps no nils in a table)
function ns.RuleWordsPutBack()
	local undo, db = CinematicDB and CinematicDB.ruleWordsUndo, ns.db
	if not (undo and db) then return "nothing to put back" end
	db.frameRules = db.frameRules or {}
	local rule = undo.rule
	if rule == NIL then rule = nil end
	db.frameRules.minimap = rule
	for _, key in ipairs(MINIMAP_EXTRAS) do
		local value = undo.extras and undo.extras[key]
		if value == NIL then value = nil end
		db[key] = value
	end
	CinematicDB.ruleWordsUndo = nil
	return ("Minimap rule put back (%s), Minimap page settings put back"):format(tostring(rule))
end
-- The first run cut off by a /reload (2026-11-21, 07:58) saved no undo, and
-- the next run took its leftovers for yours: what your profile had at 07:47
-- (the minimap rule unset; Keep open and the Reveal boxes on; ping,
-- Questie and the cursor sweep unset, so on by default). /cine debug
-- rulewords restore puts these.
local RESTORE_1121 = { rule = NIL, extras = { minimapKeepOpen = true, minimapRevealNodes = true,
	minimapRevealTurnIns = true, minimapRevealAreas = true, minimapRevealIcons = true, minimapQuestGivers = true,
	minimapQuestie = NIL, minimapNodesByCursor = NIL, minimapRevealOnPing = NIL } }
function ns.RuleWordsAtLogin()
	if CinematicDB and CinematicDB.ruleWordsUndo and ns.db then
		local said = ns.RuleWordsPutBack()
		local log = CinematicDB.ruleWordsLog
		if log then log[#log + 1] = "login: the run was cut off (a /reload?): " .. said end
		ns.Print("rule words test was cut off: " .. said)
	end
end
do
	local login = CreateFrame("Frame")
	login:RegisterEvent("PLAYER_ENTERING_WORLD")
	login:SetScript("OnEvent", function(self)
		self:UnregisterAllEvents()
		ns.RuleWordsAtLogin()
	end)
end

local function Finish(done)
	if run.ticker then run.ticker:Cancel() end
	if run.origOpen then ns.OpenRuleEditor = run.origOpen end
	-- (The editor first: closing, it writes its text back to the row.)
	run.target = nil
	if EditorOpen() then _G.CinematicRuleEditor:Hide() end
	Say("  " .. ns.RuleWordsPutBack())
	SetCine(run.cineWas)
	Say(done and "done" or "stopped early")
	local lines = run.results
	run = nil
	ns.PadTestBox(done and "Rule words test DONE. /reload, then say \"check log\"." or "Rule words test stopped.",
		table.concat(lines, "\n"), 1, 1, 1)
	C_Timer.After(30, function() if not run then ns.PadTestBoxHide() end end)
end

local function Tick()
	local now = GetTime()
	local words = Watch(now)
	-- (Part A wants CineMode on, Part B off: put back if it went.)
	local step = run.step
	local wantCine = step.part == "A"
	if CineOn() ~= wantCine and now - (run.cineSetAt or 0) > 1 then
		run.cineSetAt = now
		SetCine(wantCine)
	end
	-- Part B: the editor kept up once you've opened it, its text box let go.
	if step.part == "B" and run.target and not EditorOpen() and now - (run.reopenAt or 0) > 1 then
		run.reopenAt = now
		local ok, err = pcall(run.origOpen, run.target)
		local editor = _G.CinematicRuleEditor
		local function LetGo(frame, depth)
			for _, child in ipairs({ frame:GetChildren() }) do
				if child.GetObjectType and child:GetObjectType() == "EditBox" and child.ClearFocus then child:ClearFocus() end
				if depth < 3 then LetGo(child, depth + 1) end
			end
		end
		if ok and editor then LetGo(editor, 0) end
		Say("  rule editor opened again by the test" .. (ok and "" or (": error " .. tostring(err))))
	end
	-- Screenshots, paced.
	local shot = run.shots[1]
	if shot and now >= shot.at and now - run.shotAt >= SHOT_GAP then
		table.remove(run.shots, 1)
		run.shotAt = now
		if _G.Screenshot then _G.Screenshot() end
		Say("screenshot (" .. shot.label .. ")")
	end
	if run.skip then
		run.skip = nil
		if not run.finishing then
			Result(step.key, nil, "not tested (skipped)")
			if not NextStep() then run.finishing = true end
		end
		return
	end
	if run.finishing then
		if #run.shots == 0 then Finish(true) end
		return
	end
	local finished
	if step.word then finished = RunCycle(step, words, now) else finished = step.run(step, words, now) end
	if finished and not NextStep() then
		run.finishing = true -- (the last screenshots first)
	end
end

function ns.RuleWordsTest(arg)
	ns.debugNoCopyWindow = true
	if arg == "skip" then
		if run then run.skip = true else ns.Print("rule words test: not running") end
		return
	end
	if arg == "restore" then
		if run then ns.Print("rule words test: running, type it again to stop first") return end
		CinematicDB.ruleWordsUndo = RESTORE_1121
		ns.Print("rule words test: " .. ns.RuleWordsPutBack() .. " (as they were at 07:47)")
		return
	end
	if run then
		Say("stopped: command typed again")
		Finish(false)
		return
	end
	if InCombatLockdown() then
		ns.Print("rule words test: not in a fight")
		return
	end
	if arg == "glide" and not ns.isRetail then
		ns.Print("rule words test: the glide run is for retail (skyriding)")
		return
	end
	if not (ns.RULE_WORDS and ns.RULE_WORDS.autorun and ns.RuleFactsFor) then
		ns.Print("rule words test: this copy has no autorun rule word: put the new words in first")
		return
	end
	if hooksecurefunc and _G.ToggleAutoRun and not ns.ruleWordsHooked then
		ns.ruleWordsHooked = true
		hooksecurefunc("ToggleAutoRun", function() autoRunKeyAt = GetTime() end)
	end
	CinematicDB.ruleWordsLog = {}
	run = { at = GetTime(), results = {}, shots = {}, shotAt = -math.huge, index = 0,
		words = {}, wordAt = {}, raw = {}, dots = {}, dotLags = {} }
	Say(("start: %s (game %s), version %s, CineMode %s, settings %s"):format(ns.isRetail and "retail" or "Forever",
		tostring((select(4, GetBuildInfo()))), tostring(ns.Version and ns.Version()), tostring(CineOn()),
		tostring(SettingsOpen())))
	run.cineWas = CineOn()
	local db = ns.db
	-- (A run cut off before its end, with no login since: its settings back first.)
	if CinematicDB.ruleWordsUndo then Say("  a cut-off run's settings first: " .. ns.RuleWordsPutBack()) end
	local ruleWas = db.frameRules and db.frameRules.minimap
	-- (What to put back, saved: a /reload mid-run puts it back at the next login.)
	local undo = { rule = ruleWas == nil and NIL or ruleWas, extras = {}, profile = ns.ActiveProfile and ns.ActiveProfile() }
	db.frameRules = db.frameRules or {}
	db.frameRules.minimap = RULE
	Say(("  Minimap rule set to %q (was %s); fade out %s s, fade in %s s"):format(RULE, tostring(ruleWas),
		tostring(db.fadeOutTime), tostring(db.fadeInTime)))
	local was = {}
	for _, key in ipairs(MINIMAP_EXTRAS) do
		local value = db[key]
		undo.extras[key] = value == nil and NIL or value
		was[#was + 1] = key .. "=" .. tostring(value)
		db[key] = false
	end
	CinematicDB.ruleWordsUndo = undo
	Say("  Minimap page's own ways up turned off for the run (were " .. table.concat(was, ", ") .. ")")
	-- (The Minimap row's editor target, kept from your click on its Edit.)
	run.origOpen = ns.OpenRuleEditor
	ns.OpenRuleEditor = function(target, ...)
		if run and type(target) == "table" and target.key == "minimap" and not run.target then
			run.target = target
			Say("  the Minimap row's editor kept for the run")
		end
		return run.origOpen(target, ...)
	end
	Watch(GetTime())
	local first = {}
	for _, k in ipairs(RAW_ORDER) do first[#first + 1] = k .. "=" .. tostring(run.raw[k]) end
	Say("  game at start: " .. table.concat(first, ", "))
	local on = {}
	for _, w in ipairs(NEW) do if run.words[w] then on[#on + 1] = w end end
	for _, w in ipairs(CONTEXT) do if run.words[w] then on[#on + 1] = w end end
	Say("  words on at start: " .. (#on > 0 and table.concat(on, ", ") or "none"))
	STEPS = BuildSteps(arg)
	Say("  run: " .. tostring(arg or "full") .. ", " .. #STEPS .. " steps")
	run.cineSetAt = GetTime()
	SetCine(true)
	NextStep()
	run.ticker = C_Timer.NewTicker(0.03, function()
		if not run then return end
		local ok, err = pcall(Tick)
		if not ok then
			Say("error: " .. tostring(err))
			if run then Finish(false) end
		end
	end)
	ns.TestPrompt("Rule words test: follow the box (type it again to stop)")
end
