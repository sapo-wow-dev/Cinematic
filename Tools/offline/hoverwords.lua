-- The mouse words (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/hoverwords.lua < /dev/null
-- Frames.lua's ns.HoverWords (2026-11-24, a player's wish: tooltips only on
-- corpses, or only over unit frames): the Target words again for the unit
-- under the mouse, on every row's rule. On a stand-in game (Forever, then
-- retail): nothing under the mouse, a hostile NPC in the world, you on your
-- player frame, a corpse, a party member's frame, secret reads in a fight,
-- a unit changed in the same frame (the game's UPDATE_MOUSEOVER_UNIT wakes
-- it at once), the mouse leaving with no event (the next frame sees it), a
-- mob dying under a still mouse (the next full working out), the aliases,
-- the rule editor's Mouse over line, and a Tooltips row rule read by
-- ns.RowOnNow. PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212 431
local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local WORDS = { "hover", "hoverself", "hoverdead", "hoverenemy", "hoverfriendly", "hoverenemyplayer",
	"hoverhostilenpc", "hoverneutralplayer", "hoverneutralnpc", "hoverfriendlyplayer", "hoverfriendlynpc",
	"hoverframe" }

local function RunClient(client)
	print("== " .. client)
	local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
		issecretvalue = function(value) return value == SECRET end
	end)
	local now, combat = 100, false
	GetTime = function() return now end
	InCombatLockdown = function() return combat end
	UnitAffectingCombat = function(unit) return unit == "player" and combat end
	-- The game: the unit under the mouse ("mo", nil for none) and the frame.
	local mo, focus
	local PlayerFrame = CreateFrame("Frame", "PlayerFrame", UIParent)
	local partyRow = CreateFrame("Button", nil, CreateFrame("Frame", "CompactPartyFrame", UIParent))
	local onPlate = CreateFrame("Frame", nil, CreateFrame("Frame", nil, WorldFrame))
	local function Read(field, unit)
		if unit ~= "mouseover" or not mo then return nil end
		return mo[field]
	end
	UnitExists = function(unit)
		if unit == "mouseover" then return mo ~= nil end
		return unit == "player"
	end
	UnitGUID = function(unit) return Read("guid", unit) end
	UnitIsDeadOrGhost = function(unit) return Read("dead", unit) or false end
	UnitIsUnit = function(a, b) return a == "mouseover" and b == "player" and mo ~= nil and mo.me or false end
	UnitIsPlayer = function(unit) return Read("player", unit) or false end
	UnitCanAttack = function(_, unit) local v = Read("attack", unit) return v == nil and false or v end
	UnitIsFriend = function(_, unit) local v = Read("friend", unit) return v == nil and true or v end
	UnitReaction = function(unit) return Read("reaction", unit) or 5 end
	-- (Retail's list; Forever's one frame. The stand-in answers a stub for
	-- any missing name, so both are set, as each client has it.)
	if client == "retail" then
		GetMouseFoci = function() return { focus } end
	else
		rawset(_G, "GetMouseFoci", false)
		GetMouseFocus = function() return focus end
	end
	local function Facts() return ns.RuleFactsNow() end
	local function Is(facts, on)
		local wrong = {}
		for _, word in ipairs(WORDS) do
			if (facts[word] and true or false) ~= (on[word] and true or false) then
				wrong[#wrong + 1] = word .. "=" .. tostring(facts[word])
			end
		end
		return #wrong == 0, table.concat(wrong, ", ")
	end
	local function Step(seconds) now = now + (seconds or 0.02) end

	-- 1. Nothing under the mouse.
	mo, focus = nil, WorldFrame
	Step(1)
	local ok, wrong = Is(Facts(), {})
	Check("nothing under the mouse: every mouse word false", ok, wrong)

	-- 2. A hostile NPC out in the world (the game's event first, as it sends).
	mo, focus = { guid = "Creature-1", attack = true, reaction = 2 }, WorldFrame
	wow.Fire("UPDATE_MOUSEOVER_UNIT")
	local gen = ns.factsGen
	ok, wrong = Is(Facts(), { hover = true, hoverenemy = true, hoverhostilenpc = true })
	Check("hostile NPC in the world: hover, hoverenemy, hoverhostilenpc", ok, wrong)
	Check("hostile NPC: the stamp moved (rows read again)", ns.factsGen ~= gen)

	-- 3. Another unit in the same frame, with the event: seen at once.
	mo = { guid = "Creature-2", attack = false, friend = true, reaction = 5 }
	wow.Fire("UPDATE_MOUSEOVER_UNIT")
	ok, wrong = Is(Facts(), { hover = true, hoverfriendly = true, hoverfriendlynpc = true })
	Check("a friendly NPC in the same frame, after the event: seen at once", ok, wrong)

	-- 4. The mouse leaves (the game sends nothing): the next frame sees it.
	mo = nil
	Check("mouse off, same frame, no event: not read twice a frame", Facts().hover == true)
	Step()
	gen = ns.factsGen
	ok, wrong = Is(Facts(), {})
	Check("mouse off, next frame: every word false", ok, wrong)
	Check("mouse off: the stamp moved", ns.factsGen ~= gen)

	-- 5. You, on your player frame.
	mo, focus = { guid = "Player-1", me = true, player = true }, PlayerFrame
	wow.Fire("UPDATE_MOUSEOVER_UNIT")
	Step()
	ok, wrong = Is(Facts(), { hover = true, hoverself = true, hoverfriendly = true, hoverframe = true })
	Check("your player frame: hover, hoverself, hoverfriendly, hoverframe (no kind word)", ok, wrong)

	-- 6. A party member's frame (a button inside it) vs a plate in the world.
	mo, focus = { guid = "Player-2", player = true }, partyRow
	Step()
	ok, wrong = Is(Facts(), { hover = true, hoverfriendly = true, hoverfriendlyplayer = true, hoverframe = true })
	Check("a party frame's button: hoverframe, hoverfriendlyplayer", ok, wrong)
	focus = onPlate
	Step()
	Check("the same unit on something inside WorldFrame: not hoverframe", Facts().hoverframe == false)

	-- 7. A corpse in the world.
	mo, focus = { guid = "Creature-3", dead = true, attack = true, reaction = 2 }, WorldFrame
	Step()
	ok, wrong = Is(Facts(), { hover = true, hoverdead = true, hoverfriendly = true, hoverfriendlynpc = true })
	Check("a corpse: hoverdead, hoverfriendly, hoverfriendlynpc, not hoverenemy", ok, wrong)

	-- 8. A mob dying under a still mouse: the next full working out sees it.
	mo = { guid = "Creature-4", attack = true, reaction = 2 }
	Step(1)
	Check("alive under the mouse: hoverenemy", Facts().hoverenemy == true)
	mo.dead = true
	Step()
	local held = Facts().hoverdead
	Step(0.6)
	Check("it dies, same unit and frame: hoverdead within the hold", Facts().hoverdead == true,
		"next frame " .. tostring(held))

	-- 9. A fight: the game's answers secret. No error; what it won't say reads false.
	combat = true
	mo = { guid = SECRET, attack = SECRET, friend = SECRET, player = SECRET, reaction = SECRET }
	wow.Fire("UPDATE_MOUSEOVER_UNIT")
	Step()
	local okRun, facts = pcall(Facts)
	Check("secret reads: no error", okRun, not okRun and facts or nil)
	if okRun then
		ok, wrong = Is(facts, { hover = true })
		Check("secret reads: hover only", ok, wrong)
	end
	Step()
	okRun = pcall(Facts)
	Check("secret GUID: read again the next frame without an error", okRun)
	combat = false

	-- 10. The words in a rule, aliases too.
	mo, focus = { guid = "Creature-5", dead = true }, WorldFrame
	Step(1)
	facts = Facts()
	for text, want in pairs({ ["hoverdead"] = true, ["mouseoverdead"] = true, ["hovercorpse"] = true,
		["hoverframe"] = false, ["mouseover and not hoverframe"] = true, ["hoverdead or hoverframe"] = true }) do
		local test, err = ns.CompileRule(text)
		Check(("rule \"%s\" reads %s"):format(text, tostring(want)), test ~= nil and test(facts) == want, err)
	end

	-- 11. The rule editor: a Mouse over line with the twelve words, no near or range.
	local line
	for _, group in ipairs(ns.RulePieces()) do
		if group[1] == ns.L["Mouse over"] then line = group end
	end
	Check("rule editor: a Mouse over line", line ~= nil)
	if line then
		local have, odd = {}, {}
		for _, piece in ipairs(line[3]) do
			have[piece[1]] = true
			if not ns.RULE_WORDS[piece[1]] or piece[1]:find("near") or piece[1]:find("range") then
				odd[#odd + 1] = piece[1]
			end
		end
		local missing = {}
		for _, word in ipairs(WORDS) do if not have[word] then missing[#missing + 1] = word end end
		Check("rule editor: all twelve words on it", #missing == 0, table.concat(missing, ", "))
		Check("rule editor: nothing else (no near or range)", #odd == 0, table.concat(odd, ", "))
	end

	-- 12. The player's case: the Tooltips row's rule, read as Effects reads it.
	ns.db.frameRules = ns.db.frameRules or {}
	local before = ns.db.frameRules["tooltip:All"]
	ns.db.frameRules["tooltip:All"] = "hoverdead or hoverframe"
	mo, focus = { guid = "Creature-6", attack = true, reaction = 2 }, WorldFrame
	wow.Fire("UPDATE_MOUSEOVER_UNIT")
	Step(1)
	Check("Tooltips rule: a living mob in the world, off", ns.RowOnNow("tooltip:All", false, true) == false)
	mo = { guid = "Creature-7", dead = true }
	wow.Fire("UPDATE_MOUSEOVER_UNIT")
	Step()
	Check("Tooltips rule: a corpse, on", ns.RowOnNow("tooltip:All", false, true) == true)
	mo, focus = { guid = "Player-1", me = true, player = true }, PlayerFrame
	wow.Fire("UPDATE_MOUSEOVER_UNIT")
	Step()
	Check("Tooltips rule: your player frame, on", ns.RowOnNow("tooltip:All", false, true) == true)
	ns.db.frameRules["tooltip:All"] = before

	-- 13. The kit test (/cine debug mousewords, Dev/MouseWordsTest.lua) played
	-- through: a corpse in the world, then your portrait. Its own frames'
	-- OnUpdate run as the game would (only frames made from here on).
	local timers, tickers = {}, {}
	C_Timer.After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end
	C_Timer.NewTicker = function(every, fn)
		local t = { every = every, next = now + every, fn = fn, Cancel = function(self) self.cancelled = true end }
		tickers[#tickers + 1] = t
		return t
	end
	local firstNew = #wow.frames + 1
	local function Advance(seconds)
		local stop = now + seconds
		while now < stop do
			now = now + 0.02
			local due = {}
			for i = #timers, 1, -1 do
				if timers[i].at <= now then due[#due + 1] = table.remove(timers, i) end
			end
			for i = #due, 1, -1 do due[i].fn() end
			for _, t in ipairs(tickers) do
				if not t.cancelled and t.next <= now then
					t.next = now + t.every
					t.fn(t)
				end
			end
			for i = firstNew, #wow.frames do
				local f = wow.frames[i]
				local onUpdate = f._scripts and f._scripts.OnUpdate
				if onUpdate then onUpdate(f, 0.02) end
			end
		end
	end
	ns.noRealLayout = true -- (the stand-in places every frame alike: r:Overlaps can't judge them)
	local cine = false
	ns.IsCineModeOn = function() return cine end
	_G.Cinematic_ToggleCineMode = function() cine = not cine end
	ns.PadTestBox, ns.PadTestBoxHide, ns.TestPrompt = function() end, function() end, function() end
	Screenshot = function() end
	ns.db.frameRules["tooltip:All"] = "enemy" -- (the player's own, to be put back)
	ns.db.handleTooltips, ns.db.tooltipStillMode = false, "hide"
	GameTooltip:Show()
	GameTooltip.GetAlpha = function() return 1 end
	mo, focus = nil, WorldFrame
	CinematicDB.mouseWordsTestLog = nil
	ns.HandleSlash("debug mousewords full") -- (full: its steps are proven, a plain run leaves them out)
	Advance(25) -- (the editor step: four cases, a paced shot each)
	mo, focus = { guid = "Creature-8", dead = true, name = "Kobold" }, WorldFrame
	wow.Fire("UPDATE_MOUSEOVER_UNIT")
	Advance(2)
	Check("kit: Tooltips row rule set for the run", ns.db.frameRules["tooltip:All"] == "hoverdead or hoverframe",
		ns.db.frameRules["tooltip:All"])
	mo, focus = { guid = "Player-1", me = true, player = true }, PlayerFrame
	wow.Fire("UPDATE_MOUSEOVER_UNIT")
	Advance(12)
	local log = CinematicDB.mouseWordsTestLog or {}
	local done, bad = nil, {}
	for _, line in ipairs(log) do
		if line:find("DONE: ", 1, true) then done = line end
		if line:find("FAIL", 1, true) or line:find("error", 1, true) and not line:find("errors %+0") then
			bad[#bad + 1] = line
		end
	end
	Check("kit: finished DONE", done ~= nil, done or log[#log])
	Check("kit: 0 fail", done and done:find(" 0 fail", 1, true) ~= nil, done)
	if #bad > 0 then for i = 1, math.min(6, #bad) do print("    " .. bad[i]) end end
	Check("kit: the Tooltips row rule put back", ns.db.frameRules["tooltip:All"] == "enemy",
		ns.db.frameRules["tooltip:All"])
	Check("kit: settings put back", ns.db.handleTooltips == false and ns.db.tooltipStillMode == "hide",
		tostring(ns.db.handleTooltips) .. " " .. tostring(ns.db.tooltipStillMode))
	Check("kit: CineMode off again", cine == false)
end

RunClient("forever")
RunClient("retail")
-- luacheck: pop
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
