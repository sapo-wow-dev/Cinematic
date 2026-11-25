-- The rules' phase 2 words (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/statewords.lua < /dev/null
-- Tools/cql-words-plan.md phase 2 (2026-11-25), Frames.lua's ns.StateWords:
-- ghost, dnd, vehicle, pet, leader, raidgroup, maxlevel, falling,
-- controlled, talking, movie, mapopen, menuopen, editmode, mouselook,
-- gamepad, sanctuary, contested, scenario. On a stand-in game, Forever then
-- retail: nothing read while no rule names a word; each word true when the
-- game says so and false when not; a secret answer false, no error;
-- controlled not on a flight path; talking by its windows and by the game's
-- gossip with them hidden (DialogueUI); gamepad as the game's event last
-- said; the aliases; the rule editor's lines.
-- luacheck: push ignore 111 112 113 121 122 212 431
local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local WORDS = { "ghost", "dnd", "vehicle", "pet", "leader", "raidgroup", "maxlevel", "falling", "controlled",
	"talking", "movie", "mapopen", "menuopen", "editmode", "mouselook", "gamepad", "sanctuary", "contested", "scenario",
	"pvpfight", "aggro", "shapeshifted", "warmode", "delve", "mythicplus", "housing" }

local function RunClient(client)
	print("== " .. client)
	local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
		issecretvalue = function(value) return value == SECRET end
	end)
	local now, combat = 100, false
	GetTime = function() return now end
	InCombatLockdown = function() return combat end
	UnitAffectingCombat = function(unit) return unit == "player" and combat end
	-- The game, as each word's call sees it ("g"), and how often it was asked.
	local g, asked = {}, 0
	local function Game(key) return function() asked = asked + 1 return g[key] end end
	UnitIsGhost = Game("ghost")
	UnitIsDND = Game("dnd")
	UnitInVehicle = Game("vehicle")
	UnitHasVehicleUI = function() return false end
	local exists = UnitExists
	UnitExists = function(unit) if unit == "pet" then asked = asked + 1 return g.pet end return exists(unit) end
	UnitIsGroupLeader = Game("leader")
	ns.InGroup = function() return g.group end
	IsInRaid = Game("raid")
	GetMaxLevelForPlayerExpansion = function() return 60 end
	UnitLevel = function(unit) if unit == "player" then return g.level or 10 end return 1 end
	IsFalling = Game("falling")
	HasFullControl = function() asked = asked + 1 if g.control == nil then return true end return g.control end
	ns.OnTaxi = function() return g.taxi end
	IsMouselooking = Game("mouselook")
	ns.MenuWindowOpen = function() return g.menu end
	ns.IsGamePadOn = function() return g.padOn end
	local pvp = function() asked = asked + 1 return g.pvp end
	if C_PvP then C_PvP.GetZonePVPInfo = pvp end
	GetZonePVPInfo = pvp
	IsInInstance = function() return g.instance ~= nil, g.instance or "none" end
	ns.CardPvpFight = function() asked = asked + 1 return g.pvpfight end
	UnitThreatSituation = function() asked = asked + 1 return g.threat end
	GetShapeshiftForm = function() asked = asked + 1 return g.form or 0 end
	UnitClass = function() return "Druid", g.class or "DRUID" end
	C_PvP = C_PvP or {}
	C_PvP.IsWarModeActive = Game("warmode")
	-- (A delve by its difficulty, 208: the game's IsDelveInProgress said yes
	-- out in Elwynn Forest on Forever, run q4a77. It says yes here too.)
	C_PartyInfo = C_PartyInfo or {}
	C_PartyInfo.IsDelveInProgress = function() return true end
	GetInstanceInfo = function() asked = asked + 1 return "x", g.instance or "none", g.delve == SECRET and SECRET or g.delve and 208 or 0 end
	C_ChallengeMode = C_ChallengeMode or {}
	C_ChallengeMode.IsChallengeModeActive = Game("mythicplus")
	C_Housing = C_Housing or {}
	C_Housing.IsInsideHouseOrPlot = Game("housing")
	local talkTypes = {}
	C_PlayerInteractionManager = { IsInteractingWithNpcOfType = function(kind) return talkTypes[kind] or false end }
	Enum.PlayerInteractionType = Enum.PlayerInteractionType or { Gossip = 3, QuestGiver = 4 }
	local frames = {}
	for _, name in ipairs({ "GossipFrame", "QuestFrame", "ItemTextFrame", "TalkingHeadFrame", "CinematicFrame",
		"MovieFrame", "WorldMapFrame", "EditModeManagerFrame" }) do
		-- (rawget: the stand-in answers a stub for any missing name.)
		frames[name] = rawget(_G, name) or CreateFrame("Frame", name, UIParent)
		frames[name]:Hide()
	end
	local function Facts() now = now + 1 return ns.RuleFactsNow() end
	local function Is(facts, on)
		local wrong = {}
		for _, word in ipairs(WORDS) do
			if (facts[word] and true or false) ~= (on[word] and true or false) then
				wrong[#wrong + 1] = word .. "=" .. tostring(facts[word])
			end
		end
		return #wrong == 0, table.concat(wrong, ", ")
	end

	-- 0. No rule names them: nothing asked, every word false.
	g = { ghost = true, dnd = true, vehicle = true, pet = true, leader = true, group = true, raid = true, level = 60,
		falling = true, control = false, mouselook = true, menu = true, padOn = true, pvp = "sanctuary",
		instance = "scenario", pvpfight = "target", threat = 3, form = 1, warmode = true, delve = true,
		mythicplus = true, housing = true }
	for _, name in ipairs({ "GossipFrame", "CinematicFrame", "WorldMapFrame", "EditModeManagerFrame" }) do
		frames[name]:Show()
	end
	asked = 0
	local ok, wrong = Is(Facts(), {})
	Check("no rule names them: every word false", ok, wrong)
	Check("no rule names them: the game not asked", asked == 0, asked .. " calls")
	-- (A rule naming each: read from then on.)
	local test, err = ns.CompileRule(table.concat(WORDS, " or "))
	Check("a rule with all nineteen compiles", test ~= nil, err)

	-- 1. All true where the game says so.
	local all = {}
	for _, word in ipairs(WORDS) do all[word] = true end
	all.contested = false -- (the zone is a sanctuary)
	all.pvpfight = false -- (out of a fight: only in one)
	ok, wrong = Is(Facts(), all)
	Check("the game says yes: each word true (sanctuary, not contested; no pvpfight out of a fight)", ok, wrong)
	-- (pvpfight: an enemy player seen before the fight, held into it with the game's answers secret.)
	combat = true
	g.pvpfight = nil
	Check("pvpfight: held into the fight from before it", Facts().pvpfight == true)
	combat = false
	Facts()
	combat = true
	Check("pvpfight: a fight with no enemy player before it: false", Facts().pvpfight == false)
	g.pvpfight = "arena"
	Check("pvpfight: an enemy player seen in the fight: true", Facts().pvpfight == true)
	combat = false
	-- (shapeshifted: forms for druids, shamans, priests and warlocks, not a warrior's stance.)
	g = { form = 2, class = "WARRIOR", control = true }
	Check("shapeshifted: a warrior's stance is not a form", Facts().shapeshifted == false)
	g = { form = 0, class = "DRUID", control = true }
	Check("shapeshifted: a druid out of form: false", Facts().shapeshifted == false)
	-- (aggro: threat 2 or 3, not 1.)
	g = { threat = 1, control = true }
	Check("aggro: threat 1 (not tanking): false", Facts().aggro == false)

	-- 2. All false where it says no.
	g = { group = false, level = 59, control = true, pvp = "contested" }
	for _, frame in pairs(frames) do frame:Hide() end
	ok, wrong = Is(Facts(), { contested = true })
	Check("the game says no: each word false (contested only)", ok, wrong)

	-- 3. One at a time: leader only in a group, controlled not on a flight path.
	g = { leader = true, group = false, control = true }
	Check("leader out of a group: false", Facts().leader == false)
	g = { control = false, taxi = true }
	Check("no control on a flight path: not controlled", Facts().controlled == false)
	g = { control = false }
	Check("no control off a flight path: controlled", Facts().controlled == true)

	-- 4. Talking: each window, and the game's gossip with them hidden.
	g = {}
	for _, name in ipairs({ "GossipFrame", "QuestFrame", "ItemTextFrame", "TalkingHeadFrame" }) do
		frames[name]:Show()
		Check("talking: " .. name .. " shown", Facts().talking == true)
		frames[name]:Hide()
	end
	talkTypes[Enum.PlayerInteractionType.Gossip] = true
	Check("talking: gossip with its window hidden (DialogueUI)", Facts().talking == true)
	talkTypes[Enum.PlayerInteractionType.Gossip] = nil
	talkTypes[Enum.PlayerInteractionType.QuestGiver] = true
	Check("talking: a quest giver with its window hidden", Facts().talking == true)
	talkTypes[Enum.PlayerInteractionType.QuestGiver] = nil
	Check("talking: nothing open, false", Facts().talking == false)

	-- 5. The gamepad: switched on counts till the game's event says; then the event.
	g = { padOn = true }
	ns.gamePadState.active = nil
	Check("gamepad: switched on, no event yet: true", Facts().gamepad == true)
	ns.gamePadState:GetScript("OnEvent")(ns.gamePadState, "GAME_PAD_ACTIVE_CHANGED", false)
	Check("gamepad: the game says not active: false", Facts().gamepad == false)
	ns.gamePadState:GetScript("OnEvent")(ns.gamePadState, "GAME_PAD_ACTIVE_CHANGED", true)
	Check("gamepad: the game says active: true", Facts().gamepad == true)
	ns.gamePadState.active = nil

	-- 6. Secret answers: false, no error.
	g = { ghost = SECRET, dnd = SECRET, vehicle = SECRET, pet = SECRET, leader = SECRET, group = true, raid = SECRET,
		falling = SECRET, control = SECRET, mouselook = SECRET, pvp = SECRET, level = SECRET, threat = SECRET,
		form = SECRET, warmode = SECRET, delve = SECRET, mythicplus = SECRET, housing = SECRET }
	local okRun, facts = pcall(Facts)
	Check("secret answers: no error", okRun, not okRun and facts or nil)
	if okRun then
		ok, wrong = Is(facts, {})
		Check("secret answers: every word false", ok, wrong)
	end

	-- 7. The aliases.
	g = { dnd = true, control = false, mouselook = true }
	frames.WorldMapFrame:Show()
	facts = Facts()
	for text, want in pairs({ busy = true, cc = true, stunned = true, map = true, mouseturning = true,
		["dialog or inraid"] = false, ["mapopen and not editmode"] = true }) do
		local t, e = ns.CompileRule(text)
		Check(("rule \"%s\" reads %s"):format(text, tostring(want)), t ~= nil and t(facts) == want, e)
	end
	frames.WorldMapFrame:Hide()

	-- 8. The rule editor (UI/RuleCatalog.lua, 2026-11-25): each word in its category.
	local where = {}
	for _, it in ipairs(ns.RuleCatalogWords("row")) do where[it.entry.w] = where[it.entry.w] or it.cat.key end
	local WANT = { ghost = "you", controlled = "you", vehicle = "you", pet = "you", dnd = "you", maxlevel = "you",
		shapeshifted = "you", leader = "place", raidgroup = "place", falling = "travel", scenario = "place",
		sanctuary = "place", contested = "place", mapopen = "doing", menuopen = "doing", editmode = "doing",
		movie = "doing", mouselook = "doing", talking = "doing", pvpfight = "fight", aggro = "fight" }
	local wrongPlace = {}
	for word, cat in pairs(WANT) do
		if where[word] ~= cat then wrongPlace[#wrongPlace + 1] = word .. " in " .. tostring(where[word]) end
	end
	table.sort(wrongPlace)
	Check("rule editor: every phase 2 word in its category", #wrongPlace == 0, table.concat(wrongPlace, ", "))
	local retailOnly = where.warmode and where.delve and where.mythicplus and where.housing
	Check("rule editor: War Mode, Delves, Mythic+ and Your house on retail only (" .. client .. ")",
		(retailOnly ~= nil) == (client == "retail"))
	Check("rule editor: Using a gamepad only where the client has gamepads",
		(where.gamepad ~= nil) == (C_GamePad ~= nil), tostring(where.gamepad))
	local red = ns.ColoredRule("nosuchword"):match("|c%x%x%x%x%x%x%x%x")
	local colored = ns.ColoredRule(table.concat(WORDS, " or "))
	Check("rule editor: none of them colored as unknown", red ~= nil and not colored:find(red, 1, true))
	local _ = wow
end

RunClient("forever")
RunClient("retail")
-- luacheck: pop
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
