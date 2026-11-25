-- Names while talking to an NPC (2026-11-24), offline (Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/talknames.lua
-- On both clients:
--   words      npc: any NPC targeted (hostile, neutral or friendly), not a
--              player or you; interacting: an NPC window open or the game's
--              "npc" unit there (DialogueUI's hidden window), the mailbox too
--   migration  a saved rule's npc becomes interacting (rows, triggers,
--              Cooldown Manager groups, combat sound lists), once; other
--              words (friendlynpc, npcs) untouched; saved profiles, backups
--              and strings shared from before too (no npcWord), new ones kept
--   editor     Any NPC on the Target line, Interacting first on You
--   all names  the All names row: Always to start (no change); a rule
--              saying no turns every other names row off, itself not gated
--   target     your target's name: a Target names rule decides it both
--              ways (a vendor's title gone with it); no rule: as before;
--              an NPC not targeted keeps its title
-- PASS or FAIL lines.
-- luacheck: push ignore 111 112 113 121 122 143 212
local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. text)
	if not ok then failed = failed + 1 end
end

local function Upvalue(fn, name)
	for i = 1, 300 do
		local n, v = debug.getupvalue(fn, i)
		if not n then return nil end
		if n == name then return v, i end
	end
end
local function SetUpvalue(fn, name, value)
	local _, at = Upvalue(fn, name)
	if at then debug.setupvalue(fn, at, value) end
	return at ~= nil
end

local function RunClient(client)
	print("== " .. client)
	local ns = dofile("Tools/offline/load.lua")(client, "Cinematic.toc")
	local clock = 1000
	GetTime = function() return clock end
	local function Tick() clock = clock + 1 end
	InCombatLockdown = function() return false end
	UnitAffectingCombat = function() return false end

	-- Words ---------------------------------------------------------------
	local g = { targetRow = nil, npcUnit = false, window = false }
	ns.HasTarget = function() return g.targetRow ~= nil end
	ns.TargetNameRow = function(unit) return unit == "target" and g.targetRow or nil end
	ns.NPCWindowOpen = function() return g.window end
	local realExists = UnitExists
	UnitExists = function(unit)
		if unit == "npc" then return g.npcUnit end
		if unit == "target" then return g.targetRow ~= nil end
		return realExists and realExists(unit)
	end
	UnitIsUnit = function() return false end
	UnitIsDeadOrGhost = function() return false end
	local function Facts()
		Tick()
		-- (Every word, named by a rule or not: only rules' words are read otherwise, ns.factsUsed.)
		return ns.RuleFactsAll(false)
	end
	for _, row in ipairs({ "TargetEnemyNPC", "TargetNeutralNPC", "TargetFriendlyNPC" }) do
		g.targetRow = row
		Check(Facts().npc == true, "npc on with " .. row)
	end
	for _, row in ipairs({ "TargetEnemyPlayer", "TargetFriendlyPlayer" }) do
		g.targetRow = row
		Check(Facts().npc == false, "npc off with " .. row)
	end
	g.targetRow = nil
	Check(Facts().npc == false, "npc off with nothing targeted")
	Check(Facts().interacting == false, "interacting off: no window, no npc unit")
	g.window = true
	Check(Facts().interacting == true, "interacting on: a window open (vendor, mailbox)")
	g.window, g.npcUnit = false, true
	Check(Facts().interacting == true, "interacting on: the npc unit alone (DialogueUI's hidden window)")
	g.targetRow = "TargetFriendlyNPC"
	local test = ns.CompileRule("interacting and npc")
	Check(test ~= nil and test(Facts()) == true, "interacting and npc: talking to a targeted NPC")
	g.npcUnit, g.window = false, true
	g.targetRow = "TargetFriendlyPlayer"
	Check(test(Facts()) == false, "interacting and npc: off at a mailbox with a player targeted")
	g.window, g.targetRow = false, nil
	Check(ns.RULE_WORDS.interact == "interacting" and ns.RULE_WORDS.anynpc == "npc", "aliases: interact, anynpc")

	-- Migration -----------------------------------------------------------
	local t = {
		frameRules = { a = "not npc", b = "friendlynpc or npcs", c = "NPC and combat", d = "(npc)" },
		cameraRows = { ["x.cond"] = "npc or combat", ["x.name"] = "npc" },
		cooldownPlaceGroups = { { cql = "not npc" } },
		combatSounds = "in#npc#1@50;out##2@100",
		cardDuelSounds = "start#not npc and boss#3@100",
		plainText = "npc",
	}
	ns.NpcRuleToInteracting(t)
	Check(t.frameRules.a == "not interacting" and t.frameRules.c == "interacting and combat"
		and t.frameRules.d == "(interacting)", "migration: rows' npc becomes interacting")
	Check(t.frameRules.b == "friendlynpc or npcs", "migration: friendlynpc and npcs untouched")
	Check(t.cameraRows["x.cond"] == "interacting or combat" and t.cameraRows["x.name"] == "npc",
		"migration: a trigger's condition, not its other fields")
	Check(t.cooldownPlaceGroups[1].cql == "not interacting", "migration: Cooldown Manager groups")
	Check(t.combatSounds == "in#interacting#1@50;out##2@100" and t.cardDuelSounds == "start#not interacting and boss#3@100",
		"migration: combat sound lists")
	Check(t.plainText == "npc", "migration: other text settings untouched")
	Check(ns.db.ruleNpcInteractingV1 == true, "migration: marked done at login")
	-- (Release review, 2026-11-24: backups, a deleted profile's, and strings
	-- shared from before keep their npc's old meaning: interacting.)
	ns.db.profiles.OldSaved = { settings = { frameRules = { a = "npc or combat" } } }
	ns.db.profileBackups = { Old = { { time = 1, settings = { frameRules = { a = "not npc" } } } } }
	ns.db.deletedProfiles = { Gone = { backups = { { time = 1, settings = { frameRules = { a = "npc" } } } } } }
	ns.db.ruleNpcInteractingV1 = nil
	ns.RunMigrations()
	Check(ns.db.profileBackups.Old[1].settings.frameRules.a == "not interacting"
		and ns.db.deletedProfiles.Gone.backups[1].settings.frameRules.a == "interacting",
		"migration: backups and a deleted profile's backups")
	Check(ns.db.profiles.OldSaved.settings.frameRules.a == "interacting or combat", "migration: a saved profile's rules")
	ns.db.profiles.OldSaved, ns.db.profileBackups, ns.db.deletedProfiles = nil, {}, {}
	local oldShare = ns.PackShared("CINE", 1, { format = 1, version = "v2.1.33", name = "Old",
		settings = { frameRules = { [ns.NameRuleKey("YourTarget")] = "not npc" } } })
	local read = ns.ReadSharedProfile(oldShare)
	Check(read and read.settings.frameRules[ns.NameRuleKey("YourTarget")] == "not interacting",
		"migration: a profile string from before (no npcWord)")
	local newShare = ns.PackShared("CINE", 1, { format = 1, version = "v2.1.34", name = "New", npcWord = "target",
		settings = { frameRules = { [ns.NameRuleKey("YourTarget")] = "not npc" } } })
	read = ns.ReadSharedProfile(newShare)
	Check(read and read.settings.frameRules[ns.NameRuleKey("YourTarget")] == "not npc",
		"migration: a profile string from now keeps npc")
	local function CamShare(mark)
		return ns.PackCameraShare({ kind = "trigger", name = "T", npcWord = mark,
			triggers = { t1 = "event:X" }, defs = { t1 = { name = "T", cond = "npc and combat" } } })
	end
	local cam = ns.ReadCameraShare(CamShare(nil))
	Check(cam and cam.defs[1] and cam.defs[1].cond == "interacting and combat", "migration: a camera trigger string from before")
	cam = ns.ReadCameraShare(CamShare("target"))
	Check(cam and cam.defs[1] and cam.defs[1].cond == "npc and combat", "migration: a camera trigger string from now keeps npc")
	local ruleKey = "effect:inn"
	local wasSettings = ns.ProfileForSharing
	ns.ProfileForSharing = function() return { frameRules = { [ruleKey] = "not npc" } } end
	local ok, export = pcall(ns.ExportProfile, ns.ActiveProfile())
	ns.ProfileForSharing = wasSettings
	local back = ok and export and ns.ReadSharedProfile(export)
	Check(back and type(back.settings.frameRules) == "table" and back.settings.frameRules[ruleKey] == "not npc",
		"migration: our own export reads back with npc kept", not ok and export or nil)

	-- Editor --------------------------------------------------------------
	local target, you
	for _, group in ipairs(ns.RulePieces()) do
		for i, piece in ipairs(group[3]) do
			if piece[1] == "npc" then target = group[1] end
			if piece[1] == "interacting" then you = { group[1], i } end
		end
	end
	Check(target == ns.L["Target"], "editor: Any NPC on the Target line (" .. tostring(target) .. ")")
	Check(you and you[1] == ns.L["You"] and you[2] == 1, "editor: Interacting first on the You line")

	-- All names -----------------------------------------------------------
	local NameKeptHere = Upvalue(ns.DescribePlateNameKept, "NameKeptHere")
	Check(type(NameKeptHere) == "function", "all names: NameKeptHere read")
	if not NameKeptHere then return end
	ns.db.frameRules = ns.db.frameRules or {}
	ns.db.frameRules["name:AllNames"] = nil
	Check(ns.DEFAULTS.nameAlwaysAllNames == true, "all names: Always to start")
	Tick()
	Check(NameKeptHere("ServiceNPCs", false) == true, "all names Always: Service NPCs as before (up)")
	Check(NameKeptHere("Friends", false) == false, "all names Always: Friendly players as before (down)")
	ns.db.frameRules["name:AllNames"] = "not interacting"
	g.window = true
	Tick()
	ns.RuleFacts(false)
	Tick()
	Check(NameKeptHere("AllNames", false) == false, "all names \"not interacting\": off while talking")
	local up = {}
	for _, key in ipairs({ "ServiceNPCs", "YourTarget", "YourMouseover", "GroupMembers", "Guild", "InteractiveNPCs" }) do
		ns.db["nameAlways" .. key] = true
		if NameKeptHere(key, false) then up[#up + 1] = key end
	end
	Check(#up == 0, "all names off: every other row off, Always ticked or not" .. (#up > 0 and (" (" ..
		table.concat(up, ", ") .. " up)") or ""))
	g.window = false
	Tick()
	ns.RuleFacts(false)
	Tick()
	Check(NameKeptHere("ServiceNPCs", false) == true, "all names: the talk over, Service NPCs back")
	for _, key in ipairs({ "YourTarget", "YourMouseover", "GroupMembers", "Guild", "InteractiveNPCs" }) do
		ns.db["nameAlways" .. key] = nil
	end
	ns.db.frameRules["name:AllNames"] = nil

	-- Target names rule decides -----------------------------------------
	local PlateAlphas = Upvalue(ns.DescribePlateNameKept, "PlateAlphas")
	local nameLevel = Upvalue(ns.DescribePlateNameKept, "nameLevel") or Upvalue(PlateAlphas or print, "nameLevel")
	Check(PlateAlphas ~= nil and nameLevel ~= nil, "target: PlateAlphas and the names' levels read")
	if not (PlateAlphas and nameLevel) then return end
	local targeted = true
	SetUpvalue(PlateAlphas, "platesForced", true)
	SetUpvalue(PlateAlphas, "PlateAlpha", function() return 0 end)
	SetUpvalue(PlateAlphas, "PlateKind", function() return "FriendlyNPCs" end)
	SetUpvalue(PlateAlphas, "IsTarget", function() return targeted end)
	SetUpvalue(PlateAlphas, "PersonalPlate", function() return nil end)
	SetUpvalue(PlateAlphas, "AlwaysShownTarget", function() return false end)
	ns.PlateServiceMatch = function() return true, false end
	ns.TargetNameRow = function() return "TargetFriendlyNPC" end
	ns.HasTarget = function() return true end
	ns.db.nameServiceShow = "title"
	local plate = CreateFrame("Frame")
	plate.UnitFrame = CreateFrame("Frame")
	local function Name()
		local alpha, _, name, _, text = PlateAlphas("nameplate1", plate)
		return alpha * name, text
	end
	nameLevel.FriendlyNPCs, nameLevel.ServiceNPCs, nameLevel.YourTarget, nameLevel.YourMouseover = 0, 1, 0, 0
	ns.db.frameRules["name:YourTarget"] = nil
	local level, text = Name()
	Check(level > 0.99 and text < 0.01, ("no Target rule: a targeted vendor's title shows as before (%s, text %s)")
		:format(level, text))
	ns.db.frameRules["name:YourTarget"] = "not interacting"
	nameLevel.YourTarget = 0
	level = Name()
	Check(level < 0.01, ("Target rule says no: its name and title gone (%s)"):format(level))
	nameLevel.YourTarget = 1
	level, text = Name()
	Check(level > 0.99 and text > 0.99, ("Target rule says yes: its name, no title in its place (%s, text %s)")
		:format(level, text))
	targeted = false
	nameLevel.YourTarget = 0
	level, text = Name()
	Check(level > 0.99 and text < 0.01, "an NPC not targeted: its title kept by Service NPCs")
	ns.db.frameRules["name:YourTarget"] = nil
end

RunClient("forever")
RunClient("retail")
-- luacheck: pop
print(failed == 0 and "ALL PASS" or (failed .. " FAILED"))
if failed > 0 then os.exit(1) end
