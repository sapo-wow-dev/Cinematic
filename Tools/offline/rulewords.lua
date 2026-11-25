-- Rule words test (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/rulewords.lua < /dev/null
-- /cine debug rulewords (Dev/RuleWordsTest.lua, dev copy) on a stand-in game
-- (Forever, then retail): the whole run played through, the game's answers
-- and our movement follow set by hand, a stand-in rule editor with its dots.
-- Checks the Minimap row's rule is set and put back, Part A's fades timed,
-- the editor's Travel line read, each word's step passed with its dots,
-- skip, the Gliding button per client, stop by typing it again. PASS or FAIL
-- per check.
-- luacheck: push ignore 111 112 113 121 122 212 431
local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local function RunClient(client)
	print("== " .. client)
	local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
		issecretvalue = function(value) return value == SECRET end
	end)
	local now, combat = 100, false
	local timers, tickers = {}, {}
	GetTime = function() return now end
	InCombatLockdown = function() return combat end
	UnitAffectingCombat = function() return combat end
	C_Timer.After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end
	C_Timer.NewTicker = function(every, fn)
		local t = { every = every, next = now + every, fn = fn, Cancel = function(self) self.cancelled = true end }
		tickers[#tickers + 1] = t
		return t
	end
	-- The game: what the words come from.
	local g = { flying = false, swimming = false, afk = false, resting = false, stealthed = false, outdoors = true,
		taxi = false, gliding = false, npc = false, place = "world" }
	IsFlying = function() return g.flying end
	IsSwimming = function() return g.swimming end
	UnitIsAFK = function() return g.afk end
	IsResting = function() return g.resting end
	IsStealthed = function() return g.stealthed end
	IsOutdoors = function() return g.outdoors end
	IsIndoors = function() return not g.outdoors end
	UnitOnTaxi = function() return g.taxi end
	UnitExists = function(unit) return unit == "npc" and g.npc or false end
	IsPlayerMoving = function() return ns.playerMoving end
	GetUnitSpeed = function() return not ns.playerMoving and 0 or ns.walking and 2.5 or 7 end
	C_PlayerInfo = C_PlayerInfo or {}
	C_PlayerInfo.GetGlidingInfo = client == "retail" and function() return g.gliding, true, g.gliding and 40 or 0 end or nil
	ns.isRetail = client == "retail"
	ns.GetPlaceType = function() return g.place end
	ns.OnTaxi = function() return g.taxi end
	local manual = false
	ns.MovingManually = function() return ns.playerMoving and manual end
	local tracking = false
	ns.IsKeepingMinimapForTracking = function() return tracking, false end
	local sitting = false
	ns.IsSitting = function() return sitting end
	-- Our travel follow: moving and the test's pretend auto-run / walk.
	local function Move(how) -- nil: stop; "hand", "run", "walk"
		ns.playerMoving = how ~= nil
		manual = how == "hand"
		ns.testTravel = (how == "run" or how == "walk") and how or nil
		ns.walking = how == "walk"
	end
	-- (The stand-in's _G answers a stub for any name: a real frame put there.)
	local merchant = CreateFrame("Frame")
	merchant:Hide()
	rawset(_G, "MerchantFrame", merchant)
	local function Merchant(on)
		if on then merchant:Show() else merchant:Hide() end
	end
	local mapAlpha = 1
	Minimap.GetEffectiveAlpha = function() return mapAlpha end
	Minimap:Show()
	local shots = 0
	Screenshot = function() shots = shots + 1 end
	local box = ""
	ns.PadTestBox = function(text, sub) box = tostring(text) .. " / " .. tostring(sub) end
	ns.PadTestBoxHide = function() end
	ns.TestPrompt = function() end
	local cine = false
	ns.IsCineModeOn = function() return cine end
	_G.Cinematic_ToggleCineMode = function() cine = not cine end
	local settings = false
	ns.SettingsPanelShown = function() return settings end
	-- The rule editor stand-in: a dotted button per word, as GridRows makes them,
	-- its dot showing the facts (as its Refresh every half second).
	local editor = CreateFrame("Frame", "CinematicRuleEditor", UIParent)
	editor:Hide()
	editor.GetLeft, editor.GetRight = function() return 0 end, function() return 600 end
	local buttons, y = {}, 0
	local x
	for _, group in ipairs(ns.RulePieces()) do
		x, y = 70, y - 24
		for _, piece in ipairs(group[3]) do
			if type(piece[1]) == "string" and ns.RULE_WORDS[piece[1]] then
				local b = CreateFrame("Button", nil, editor)
				b:SetText("|cff99ccff" .. piece[2] .. "|r")
				b.dot = b:CreateTexture()
				b.dot:Hide()
				local left, top = x, y
				b.GetLeft, b.GetRight = function() return left end, function() return left + 60 end
				b.GetTop, b.GetBottom = function() return top end, function() return top - 20 end
				x = x + 64
				if x > 520 then x, y = 70, y - 24 end
				buttons[piece[1]] = b
			end
		end
	end
	local refreshAt = 0
	ns.FindSetting = function() settings = true end
	local function Advance(seconds)
		local stop = now + seconds
		while now < stop - 1e-9 do
			now = now + 0.01
			-- (Part A: the minimap fades with its rule, a tenth of a second a step.)
			local test = ns.RuleTest("minimap")
			local facts = ns.RuleFactsFor("minimap")
			local want = (test == nil or test(facts)) and 1 or 0
			if cine and not settings then
				mapAlpha = mapAlpha + math.max(-0.1, math.min(0.1, want - mapAlpha))
			else
				mapAlpha = 1
			end
			if editor:IsShown() and now - refreshAt >= 0.5 then
				refreshAt = now
				for word, b in pairs(buttons) do b.dot:SetShown(facts[ns.RULE_WORDS[word]] and true or false) end
			end
			for _, t in ipairs(tickers) do
				if not t.cancelled and now >= t.next then
					t.next = t.next + t.every
					t.fn()
				end
			end
			for i = #timers, 1, -1 do
				if now >= timers[i].at then
					local fn = timers[i].fn
					table.remove(timers, i)
					fn()
				end
			end
		end
	end
	local function Log() return CinematicDB.ruleWordsLog or {} end
	local function Has(text)
		for _, line in ipairs(Log()) do if line:find(text, 1, true) then return line end end
	end
	local function Wait(text, max)
		for _ = 1, (max or 30) * 10 do
			if box:find(text, 1, true) then return true end
			Advance(0.1)
		end
		print("  (box is: " .. box .. ")")
		return false
	end

	CinematicDB = CinematicDB or {}
	local db = ns.db
	db.frameRules = db.frameRules or {}
	db.frameRules.minimap = nil
	db.fadeOutTime, db.fadeInTime = 1, 1
	-- (The Minimap page's own ways up, as the user's profile has them: off for the run, then back.)
	db.minimapKeepOpen, db.minimapRevealAreas, db.minimapQuestGivers, db.minimapQuestie = true, true, true, nil
	-- (The editor: opened by Edit's click, through ns.OpenRuleEditor; the
	-- settings going close it, as GridRows hooks it.)
	ns.OpenRuleEditor = function() editor:Show() end
	local function CloseSettings()
		settings = false
		editor:Hide()
	end
	Check("the command is on ns", type(ns.RuleWordsTest) == "function")
	local realTest, called = ns.RuleWordsTest, nil
	ns.RuleWordsTest = function(arg) called = arg or "run" end
	ns.HandleSlash("debug rulewords")
	Check("/cine debug rulewords starts it", called == "run")
	ns.HandleSlash("debug rulewords skip")
	Check("/cine debug rulewords skip passes skip", called == "skip")
	ns.RuleWordsTest = realTest

	ns.RuleWordsTest()
	Check("start logged", Has("start: " .. (client == "retail" and "retail" or "Forever")) ~= nil, Log()[1])
	Check("rule set on the Minimap row", db.frameRules.minimap == "not combat and not autorun")
	Check("CineMode on for Part A", cine == true)
	Check("Minimap page's ways up off for the run", db.minimapKeepOpen == false and db.minimapRevealAreas == false
		and db.minimapQuestGivers == false and db.minimapQuestie == false)
	Check("what holds the minimap logged", Has("minimap: rule shown") ~= nil, Has("minimap:"))
	Check("step 1 asks to stand still", Wait("Stand still"))
	Advance(4.5)
	Check("still: PASS", Has("RESULT still: PASS") ~= nil, Has("RESULT still"))
	Check("step 2 asks for auto-run", Wait("auto-run"))
	Advance(0.5)
	Move("run")
	Advance(2.5)
	-- (The facts are held half a second with the slow checks on, and no
	-- movement event works them out afresh: the word comes that late.)
	Check("autorun: fade timed", (Has("RESULT autorun:") or ""):find("minimap fade started 0%.[56]%d s after") ~= nil,
		Has("RESULT autorun"))
	Check("autorun word logged", Has("word autorun ON") ~= nil)
	Check("step 3 asks to stop", Wait("Stop auto-run"))
	Move(nil)
	Advance(2)
	Check("stop: minimap back", Has("RESULT stop: PASS") ~= nil, Has("RESULT stop"))
	Check("step 4 asks to walk", Wait("Hold W"))
	Move("hand")
	Advance(5.5) -- (the word comes half a second late: the facts' hold)
	Check("walk: stays up, PASS", Has("RESULT walk: PASS") ~= nil, Has("RESULT walk"))
	Move(nil)
	Check("step 5 asks for a city", Wait("Go to a city"))
	g.place, g.resting = "city", true
	Advance(4)
	Check("city reached", Has("in a city: city true") ~= nil, Has("in a city"))
	Check("city auto-run step", Wait("let it run (city)"))
	Move("run")
	Advance(2.5)
	Check("autorun in a city: timed", (Has("RESULT autorun-city:") or ""):find("city true") ~= nil, Has("RESULT autorun-city"))
	Wait("Stop auto-run")
	Move(nil)
	Advance(2)
	Check("stop in a city: PASS", Has("RESULT stop-city: PASS") ~= nil, Has("RESULT stop-city"))
	g.place, g.resting = "world", false
	Check("fight step", Wait("Attack any enemy"))
	combat = true
	wow.Fire("PLAYER_REGEN_DISABLED")
	Advance(2.5)
	Check("fight: minimap gone, PASS", Has("RESULT fight: PASS") ~= nil, Has("RESULT fight"))
	Check("fight: asks to end it", Wait("End the fight"))
	combat = false
	wow.Fire("PLAYER_REGEN_ENABLED")
	Check("editor step", Wait("Click Edit"))
	Check("Part B: CineMode off", (function() Advance(1.5) return cine == false end)())
	Check("the Minimap row opened", settings == true and Has("opened row:minimap ok") ~= nil)
	ns.OpenRuleEditor({ key = "minimap", label = "Minimap" }) -- (your click on Edit)
	Advance(1)
	Check("the row's editor kept", Has("the Minimap row's editor kept for the run") ~= nil)
	Check("layout: PASS", Has("RESULT layout: PASS") ~= nil, Has("RESULT layout"))
	Check("gliding button per client: PASS", Has("RESULT gliding-button: PASS") ~= nil, Has("RESULT gliding-button"))
	Check("Travel line positions logged", Has("Travel moving:") ~= nil)
	Check("asks to close the settings", Wait("Close the settings"))
	CloseSettings()
	Advance(1.5)
	Check("editor back on its own", editor:IsShown() and Has("rule editor opened again by the test") ~= nil)
	Check("editor-alone: PASS", Has("RESULT editor-alone: PASS") ~= nil, Has("RESULT editor-alone"))

	local function Word(text, on, off, key)
		Check(key .. " step", Wait(text))
		Advance(0.3)
		on()
		Advance(2.2) -- (the word half a second late, then held a second for the dot)
		off()
		Advance(2)
		Check(key .. ": PASS", Has("RESULT " .. key .. ": PASS") ~= nil, Has("RESULT " .. key))
	end
	-- A step too short for its dot: asked again.
	Check("moving step", Wait("Walk a few steps"))
	Move("hand")
	Advance(0.7)
	Move(nil)
	Advance(1)
	Check("too short: asked again", Has("moving went back after") ~= nil and box:find("Walk a few steps", 1, true) ~= nil,
		Has("went back"))
	-- Escape closes the editor: the test opens it again.
	editor:Hide()
	Advance(1.5)
	Check("closed editor opened again", editor:IsShown())
	Word("Walk a few steps", function() Move("hand") end, function() Move(nil) end, "moving")
	Word("Press auto-run", function() Move("run") end, function() Move(nil) end, "autorun")
	Word("walk key", function() Move("walk") end, function() Move(nil) end, "rpwalk")
	Word("swim", function() g.swimming = true end, function() g.swimming = false end, "swimming")
	Word("flying mount", function() g.flying = true end, function() g.flying = false end, "flying")
	Check("flight path step", Wait("flight path"))
	g.taxi, g.flying = true, true
	ns.playerMoving = true
	Advance(1)
	g.taxi, g.flying = false, false
	ns.playerMoving = false
	Advance(1)
	Check("flight path: flying read, moving off", Has("RESULT flightpath: PASS on a flight path: flying ON, moving off") ~= nil,
		Has("RESULT flightpath"))
	if client == "retail" then
		Word("Skyride", function() g.gliding = true end, function() g.gliding = false end, "gliding")
	end
	-- (/afk: the game sends PLAYER_FLAGS_CHANGED, which the afk word waits
	-- for since the 2026-11-25 audit, fix card 2026-11-25-event-fact-flags.md.)
	local function Flags() wow.Fire("PLAYER_FLAGS_CHANGED", "player") end
	Word("/afk", function() g.afk = true Flags() end, function() g.afk = false Flags() end, "afk")
	Word("building", function() g.outdoors = false end, function() g.outdoors = true end, "outdoors")
	-- (An inn: the game sends PLAYER_UPDATE_RESTING, which the resting word
	-- waits for since fix card 2026-11-25-event-fact-resting.md.)
	local function Resting() wow.Fire("PLAYER_UPDATE_RESTING") end
	Word("inn", function() g.resting = true Resting() end, function() g.resting = false Resting() end, "resting")
	-- Stealth: skipped.
	Check("stealth step", Wait("Stealth"))
	ns.HandleSlash("debug rulewords skip")
	Advance(0.2)
	Check("skip: not tested", Has("RESULT stealthed: not tested (skipped)") ~= nil, Has("RESULT stealthed"))
	Word("/sit", function() sitting = true end, function() sitting = false end, "sit-emote")
	Word("sit key", function() sitting = true end, function() sitting = false end, "sit-key")
	Word("vendor", function() Merchant(true) end, function() Merchant(false) end, "npc-vendor")
	Check("vendor window named", Has("windows seen: MerchantFrame") ~= nil, Has("RESULT npc-vendor"))
	Word("mailbox", function() g.npc = true end, function() g.npc = false end, "npc-mail")
	Word("quest giver", function() g.npc = true end, function() g.npc = false end, "npc-quest")
	Advance(4)
	Check("DONE box", box:find("DONE", 1, true) ~= nil, (box:match("^[^/]*")))
	Check("rule put back", db.frameRules.minimap == nil, db.frameRules.minimap)
	Check("Minimap page's ways up put back", db.minimapKeepOpen == true and db.minimapRevealAreas == true
		and db.minimapQuestGivers == true and db.minimapQuestie == nil)
	Check("editor closed at the end", not editor:IsShown())
	Check("ns.OpenRuleEditor put back", Has("rule editor opened again") ~= nil and (function()
		local before = Log()[#Log()]
		ns.OpenRuleEditor({ key = "minimap" })
		return Log()[#Log()] == before
	end)())
	editor:Hide()
	Check("screenshots paced", shots >= 10, shots)
	Check("no errors in the run", Has("error:") == nil, Has("error:"))
	Check("dots timed", Has("dot autorun ON (") ~= nil and Has("s after the word") ~= nil)
	local failed = {}
	for _, line in ipairs(Log()) do
		if line:find(": FAIL ", 1, true) and not line:find("RESULT autorun", 1, true) then failed[#failed + 1] = line end
	end
	Check("no FAIL but auto-run's timing", #failed == 0, failed[1])

	-- Typed again mid-run: stops, rule put back.
	db.frameRules.minimap = "combat"
	ns.RuleWordsTest()
	Advance(0.5)
	ns.RuleWordsTest()
	Check("stop: rule put back", db.frameRules.minimap == "combat", db.frameRules.minimap)
	Check("stop: logged", Has("stopped early") ~= nil)
	Check("stop: box", box:find("stopped", 1, true) ~= nil, box)
	db.frameRules.minimap = nil
	Advance(31)

	-- Short run: the minimap case only (5 steps, no city, no editor).
	ns.HandleSlash("debug rulewords minimap")
	Check("minimap run: 5 steps", Has("run: minimap, 5 steps") ~= nil, Has("run:"))
	Wait("Stand still")
	Advance(4.5)
	Wait("auto-run")
	Move("run")
	Advance(2.5)
	Wait("Stop auto-run")
	Move(nil)
	Advance(2)
	Wait("Hold W")
	Move("hand")
	Advance(5.5)
	Move(nil)
	Check("minimap run: no city step", Wait("Attack any enemy"))
	combat = true
	Advance(2.5)
	Wait("End the fight")
	combat = false
	Advance(4)
	Check("minimap run: DONE", box:find("DONE", 1, true) ~= nil, (box:match("^[^/]*")))
	Check("minimap run: fight PASS", Has("RESULT fight: PASS") ~= nil, Has("RESULT fight"))
	Check("minimap run: settings put back", db.minimapKeepOpen == true and db.frameRules.minimap == nil)
	Advance(31)

	-- A run cut off by a /reload: no Finish; the next login puts it back.
	db.minimapKeepOpen, db.minimapRevealAreas, db.minimapQuestie = true, true, nil
	db.frameRules.minimap = nil
	ns.RuleWordsTest("minimap")
	Check("undo saved at the start", CinematicDB.ruleWordsUndo ~= nil and db.minimapKeepOpen == false)
	local print0 = ns.Print
	ns.Print = function() end
	ns.RuleWordsAtLogin() -- (the login after the /reload: PLAYER_ENTERING_WORLD's)
	ns.Print = print0
	Check("login puts a cut-off run back", db.minimapKeepOpen == true and db.minimapRevealAreas == true
		and db.minimapQuestie == nil and db.frameRules.minimap == nil and CinematicDB.ruleWordsUndo == nil)
	Check("login logs it", Has("login: the run was cut off") ~= nil)
	ns.RuleWordsTest() -- (stops the stand-in's still running run: nothing left to put back)
	Check("stopping after: nothing to put back", Has("nothing to put back") ~= nil)
	Advance(31)

	-- restore: the 07:47 values.
	db.minimapKeepOpen, db.minimapRevealIcons, db.minimapRevealOnPing = false, false, false
	db.frameRules.minimap = "not combat and not autorun"
	ns.HandleSlash("debug rulewords restore")
	Check("restore: 07:47 values", db.minimapKeepOpen == true and db.minimapRevealIcons == true
		and db.minimapRevealOnPing == nil and db.frameRules.minimap == nil)

	-- Short run: the glide (retail only).
	local printed
	ns.Print = function(text) printed = text end
	ns.HandleSlash("debug rulewords glide")
	ns.Print = print0
	if client == "retail" then
		Check("glide run: 2 steps", Has("run: glide, 2 steps") ~= nil, Has("run:"))
		Advance(0.3)
		Check("glide run: button on the Travel line", Has("RESULT gliding-button: PASS Gliding button on the Travel line")
			~= nil, Has("RESULT gliding-button"))
		Check("glide run: asks to glide", Wait("Skyride"))
		g.gliding = true
		Move("run") -- (auto-run pressed mid-glide)
		Advance(2.2)
		g.gliding = false
		Move(nil)
		Advance(4)
		Check("glide run: gliding PASS", Has("RESULT gliding: PASS") ~= nil, Has("RESULT gliding:"))
		Check("glide run: DONE", box:find("DONE", 1, true) ~= nil, (box:match("^[^/]*")))
	else
		Check("glide run: refused on Forever", printed and printed:find("retail", 1, true) ~= nil, printed)
	end
end

RunClient("forever")
RunClient("retail")
-- luacheck: pop
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
