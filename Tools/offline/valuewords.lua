-- The rules' value words (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/valuewords.lua < /dev/null
-- Tools/cql-words-plan.md phase 4 (2026-11-25), RuleAxes.lua: axis:value.
-- On a stand-in game, Forever then retail: reading them (one value, a list,
-- quoted, mistakes), each axis true where the game says so and false where
-- not, a zone's towns inside it, nothing read while no rule names the axis,
-- only the auras named looked up, an aura held through a fight where the
-- game won't say, a secret GUID false, the rows' answers worked out again
-- when a value changes, the colors and names shown, and the Values line.
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
	GetTime = function() return now end
	InCombatLockdown = function() return combat end
	UnitAffectingCombat = function(unit) return unit == "player" and combat end
	-- The game, as each axis sees it.
	local g, asked = {}, {}
	local function Ask(key) asked[key] = (asked[key] or 0) + 1 end
	local MAPS = { [1453] = { name = "Stormwind City", parentMapID = 1415 }, [1415] = { name = "Eastern Kingdoms",
		parentMapID = 947 }, [947] = { name = "Azeroth", parentMapID = 0 }, [37] = { name = "Elwynn Forest",
		parentMapID = 1415 } }
	C_Map = C_Map or {}
	C_Map.GetBestMapForUnit = function() Ask("map") return g.map end
	C_Map.GetMapInfo = function(id) return MAPS[id] end
	GetSubZoneText = function() return g.subzone or "" end
	GetInstanceInfo = function()
		return g.instanceName or "", g.instanceKind or "none", 0, "", 5, 0, false, g.instanceId or 0
	end
	GetRealZoneText = function(id) return id == 33 and "Shadowfang Keep" or "" end
	C_UnitAuras = C_UnitAuras or {}
	C_UnitAuras.GetPlayerAuraBySpellID = function(id)
		Ask("aura" .. id)
		if g.auraSecret then return nil end
		return g.auras and g.auras[id] and { spellId = id } or nil
	end
	C_UnitAuras.GetAuraDataByIndex = function(_, i, filter)
		if filter == "HELPFUL" and i == 1 then return { spellId = 465, name = "Devotion Aura" } end
	end
	C_Spell = C_Spell or {}
	C_Spell.GetSpellName = function(id) return ({ [465] = "Devotion Aura", [768] = "Cat Form" })[id] end
	GetNumShapeshiftForms = function() return 2 end
	GetShapeshiftFormInfo = function(i) return nil, g.form == i, true, ({ 5487, 768 })[i] end
	IsMounted = function() return g.mount ~= nil end
	C_MountJournal = C_MountJournal or {}
	C_MountJournal.GetMountInfoByID = function(id) return "Mount " .. id, 1, 1, g.mount == id end
	C_MountJournal.GetMountIDs = function() return { 6, 7 } end
	UnitClass = function() return "Druid", "DRUID", 11 end
	UnitRace = function() return "Night Elf", "NightElf" end
	UnitGUID = function(unit) if unit == "target" then return g.guid end end
	UnitName = function() return "Hogger" end
	-- (The interaction kinds, as the game numbers them: Forever's /api dump.)
	rawset(Enum, "PlayerInteractionType", { None = 0, TradePartner = 1, Item = 2, Gossip = 3, QuestGiver = 4,
		Merchant = 5, TaxiNode = 6, Trainer = 7, Banker = 8 })
	local merchant = 5

	local function Facts() now = now + 1 return ns.RuleFactsNow() end
	local function Reads(text, facts)
		local test, err = ns.CompileRule(text)
		if not test then return nil, err end
		return test(facts or Facts())
	end

	-- 0. Nothing read while no rule names an axis.
	g = { map = 1453 }
	asked = {}
	Facts()
	Check("no rule names zone: the map not asked", (asked.map or 0) == 0, tostring(asked.map))

	-- 1. Reading them.
	for text, ok in pairs({ ["zone:1453"] = true, ["zone:1453,37"] = true, ['subzone:"Lion\'s Pride Inn"'] = true,
		["zone:1453 and not interacting"] = true, ["(zone:37 or aura:465) and not combat"] = true,
		["zone:"] = false, ["nosuch:1"] = false, ["zone:1453 zone:37"] = false, ["ZONE:1453"] = true }) do
		local test, err = ns.CompileRule(text)
		Check(("reads \"%s\": %s"):format(text, ok and "compiles" or "an error"), (test ~= nil) == ok,
			err or "no error")
	end
	local _, why = ns.CompileRule("zone:1453 zone:37")
	Check("a value word out of place says so in words", type(why) == "string" and why:find("zone:37", 1, true) ~= nil,
		why)

	-- 2. zone: the map and every map it's inside.
	g = { map = 1453 }
	Check("zone:1453 in Stormwind: true", Reads("zone:1453") == true)
	Check("zone:1415 (Eastern Kingdoms) in Stormwind: true", Reads("zone:1415") == true)
	Check("zone:37 (Elwynn) in Stormwind: false", Reads("zone:37") == false)
	Check("zone:37,1453: either", Reads("zone:37,1453") == true)
	g = { map = SECRET }
	Check("zone with a secret map: false, no error", Reads("zone:1453") == false)

	-- 3. subzone, any case, quoted.
	g = { subzone = "Lion's Pride Inn" }
	Check('subzone:"lion\'s pride inn": true', Reads('subzone:"lion\'s pride inn"') == true)
	g = { subzone = "Goldshire" }
	Check("subzone:goldshire: true", Reads("subzone:goldshire") == true)
	Check('subzone:"Lion\'s Pride Inn" in Goldshire: false', Reads('subzone:"Lion\'s Pride Inn"') == false)

	-- 4. instance.
	g = { instanceKind = "party", instanceId = 33, instanceName = "Shadowfang Keep" }
	Check("instance:33 in it: true", Reads("instance:33") == true)
	g = {}
	Check("instance:33 out in the world: false", Reads("instance:33") == false)

	-- 5. window: as the game's events say.
	wow.Fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", merchant)
	Check("window:merchant with a vendor open: true", Reads("window:merchant") == true)
	Check("window:banker with a vendor open: false", Reads("window:banker") == false)
	wow.Fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", merchant)
	Check("window:merchant closed: false", Reads("window:merchant") == false)

	-- 6. aura: only the ids named are asked; held through a fight the game won't say.
	g = { auras = { [465] = true } }
	ns.CompileRule("aura:465")
	asked = {}
	Check("aura:465 on you: true", Reads("aura:465") == true)
	Check("aura: only the ids rules name asked (not 1)", (asked.aura1 or 0) == 0)
	Check("aura:19740 not on you: false", Reads("aura:19740") == false)
	combat = true
	g = { auraSecret = true }
	Check("aura:465 in a fight the game won't say: held true", Reads("aura:465") == true)
	combat = false
	Check("aura:465 out of the fight, gone: false", Reads("aura:465") == false)

	-- 7. form, mount, class, race, spec, camera, targetid.
	g = { form = 2, mount = 6 }
	Check("form:768 (cat) in cat form: true", Reads("form:768") == true)
	Check("form:5487 (bear) in cat form: false", Reads("form:5487") == false)
	Check("mount:6 on it: true", Reads("mount:6") == true)
	Check("mount:7 on another: false", Reads("mount:7") == false)
	Check("class:druid: true", Reads("class:druid") == true)
	Check("class:mage: false", Reads("class:mage") == false)
	Check("race:nightelf: true", Reads("race:nightelf") == true)
	ns.activeCam = "flight"
	Check("camera:flight with the Flight camera: true", Reads("camera:flight") == true)
	ns.activeCam = nil
	Check("camera:flight without: false", Reads("camera:flight") == false)
	g = { guid = "Creature-0-1-2-3-299-00001" }
	Check("targetid:299 targeting it: true", Reads("targetid:299") == true)
	g = { guid = SECRET }
	Check("targetid:299 with a secret GUID: false, no error", Reads("targetid:299") == false)

	-- 8. A value changing moves the stamp: the rows' kept answers worked out again.
	g = { map = 1453 }
	Facts()
	local gen = ns.factsGen
	g = { map = 37 }
	Facts()
	Check("the zone changing moves the facts' stamp", ns.factsGen ~= gen)

	-- 9. Shown: the names next to the ids, nothing red; an unknown axis red.
	local red = ns.ColoredRule("nosuchword"):match("|c%x%x%x%x%x%x%x%x")
	local shown = ns.ColoredRule("zone:1453,37 and aura:465 and not mage")
	Check("shown: the zone names after the ids", shown:find("Stormwind City, Elwynn Forest", 1, true) ~= nil, shown)
	Check("shown: the aura's name", shown:find("Devotion Aura", 1, true) ~= nil)
	Check("shown: nothing red", red ~= nil and not shown:find(red, 1, true))
	Check("shown: an unknown axis red", ns.ColoredRule("nosuch:1"):find(red, 1, true) ~= nil)

	-- 10. The editor's Values line: a menu per axis, made when clicked.
	local values
	for _, group in ipairs(ns.RulePieces()) do if group[1] == ns.L["Values"] then values = group end end
	Check("rule editor: a Values line", values ~= nil)
	if values then
		local menus = {}
		for _, piece in ipairs(values[3]) do menus[piece[1]] = piece end
		local missing = {}
		for _, axis in ipairs({ "zone:", "subzone:", "instance:", "window:", "aura:", "form:", "mount:", "spec:",
			"race:", "targetid:" }) do
			if not (menus[axis] and type(menus[axis].pick) == "function") then missing[#missing + 1] = axis end
		end
		Check("rule editor: a menu each", #missing == 0, table.concat(missing, ", "))
		g = { map = 1453 }
		local zones = menus["zone:"] and menus["zone:"].pick() or {}
		Check("Zone... here: Stormwind and the maps it's inside",
			#zones == 3 and zones[1][1] == "zone:1453" and zones[1][2] == "Stormwind City", #zones)
		local auras = menus["aura:"] and menus["aura:"].pick() or {}
		Check("Aura...: your buffs now", auras[1] and auras[1][1] == "aura:465", auras[1] and auras[1][1])
		local forms = menus["form:"] and menus["form:"].pick() or {}
		Check("Form...: your forms", #forms == 2 and forms[2][2] == "Cat Form")
		for word in pairs(menus) do
			local ok = pcall(menus[word].pick)
			if not ok then Check("menu " .. word .. " made without an error", false) end
		end
	end
	-- (A rule with value words isn't one the dropdowns can show: no error.)
	local okRead = pcall(ns.ReadGridRule, "zone:1453 or combat", {})
	Check("the grid's reader on a value word: no error", okRead)
end

RunClient("forever")
RunClient("retail")
-- luacheck: pop
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
