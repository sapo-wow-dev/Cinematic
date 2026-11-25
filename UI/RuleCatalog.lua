-- The CQL rule editor's words, by category (2026-11-25, Tools/rule-editor-redesign-plan.md).
-- One list the editor (UI/RuleEditor.lua) draws from, and ns.RulePieces (UI/GridRows.lua)
-- flattens for the words' colors and the tests. Made when first asked, once the language
-- is known; each client's words only (a word the game can't read here is left out: it still
-- reads, typed, and keeps its color through colorOnly).
--
-- A category: { key, name, sub (one line under its name), color, sections = { { name, words } },
-- only (contexts it shows in: nil = all), units (the Units pane: words per unit, see UNIT_SECTIONS) }.
-- A word: { w = word, l = label, t = tip line (nil: none), only = { context = true },
-- pick = axis (a menu of values, RuleAxes.lua), find = "more words search finds it by" }.
-- Contexts (target.context, or worked out from target.key by ns.RuleEditorContext):
-- "row" (a Show in row), "tooltip" (the Tooltips row), "edge" (a fight's start or end: the
-- Cards' fight rows, combat sounds), "trigger", "cdm", "sound".
local _, ns = ...
local L = ns.L

local EDGE, TOOLTIP = { edge = true }, { tooltip = true }

-- The unit words, written once for target, mouse and focus. { prop, label, tip, find }:
-- prop through ns.UnitPropField for elite and the rest, and the bare spellings below.
local UNIT_SECTIONS = {
	-- (Your target's Anything, Enemy and Friendly read as the grid's Target dropdown names
	-- them: TARGET_LABELS below, 2026-11-25.)
	{ "Who", {
		{ "", "Anything", "Anything there at all." },
		{ "self", "You", "It's you." },
		{ "enemy", "Enemy", "One you can attack, alive." },
		{ "friendly", "Friendly", "One you can't attack, the dead too." },
		{ "dead", "Dead", "Dead: a corpse to loot or skin.", "corpse loot skin" } } },
	{ "Kind", {
		{ "npc", "Any NPC", "An NPC, whatever it thinks of you." },
		{ "player", "Any player", "A player character." },
		{ "hostile", "Hostile", "A unit you can attack, red to you.", "red" },
		{ "neutral", "Neutral", "A yellow NPC, or an enemy player you can't attack yet.", "yellow" } } },
	{ "Distance" }, -- (each unit's own: UNITS[unit].distance)
	{ "Rank", {
		{ "elite", "Elite", "Elite, rare elite or a world boss." },
		{ "rare", "Rare", "Rare or rare elite." },
		{ "boss", "Boss", "A world boss, or a dungeon or raid boss. Boss fight is the fight itself." },
		{ "critter", "Critter", "A critter, totem or pet.", "totem" } } },
	{ "More", {
		{ "quest", "Quest mob", "Needed for one of your quests." },
		{ "tapped", "Tapped by others", "Tagged by someone else: no loot or credit for you.", "tagged" },
		{ "targetingyou", "Targeting you", "Its target is you.", "aggro" } } },
}
-- Your target's words keep the spellings they had before the others got prefixes.
local TARGET_BARE = { [""] = "target", self = "targetself", dead = "targetdead", enemy = "enemy", friendly = "friendly",
	npc = "npc", player = "player", hostile = "hostile", neutral = "neutral" }
-- One name per thing (2026-11-25, the user: "the show in row says location but our cql says
-- place"): words the grids' dropdowns also offer take the grids' names (UI/GridRows.lua's
-- MENU_NAMES, Frames.lua's ns.PLACE_SHOW), and the categories the grids' headings.
local TARGET_LABELS = { [""] = "Anything targeted", enemy = "Enemy targeted", friendly = "Friend targeted" }
local UNITS = {
	{ key = "target", label = "Target", sub = "Your target.",
		distance = { { "near", "Near (11 yards)", "Up close, about 11 yards.", "yards close" },
			{ "near28", "Near (28 yards)", "About 28 yards.", "yards" },
			{ "noplate", "Plate off screen", "Its nameplate isn't up: behind you, off the side or far." } },
		only = { { "targetid:", "This NPC...", "Picks the NPC you have targeted: true when you target that NPC again.",
			"npc id", pick = "targetid" } } },
	{ key = "hover", label = "Mouse", sub = "The unit under your mouse.",
		only = { { "hoverframe", "On a unit frame", "The mouse on a unit frame, not out in the world.", "portrait" } } },
	{ key = "focus", label = "Focus", sub = "Your focus.",
		distance = { { "focusnear", "Near (11 yards)", "Your focus up close, about 11 yards.", "yards close" },
			{ "focusnear28", "Near (28 yards)", "Your focus about 28 yards away.", "yards" } } },
}
-- (Target: the bare words, else targetelite... and targetingyou, as Frames.lua's
-- ns.UnitPropField spells them; the mouse's and focus's: hover..., focus....)
function ns.UnitWord(unit, prop)
	if unit == "target" then
		return TARGET_BARE[prop] or (prop == "targetingyou" and "targetingyou") or ("target" .. prop)
	end
	return unit .. prop
end

-- A word entry from { word, label, tip, find, only=, pick= }.
local function W(t)
	return { w = t[1], l = L[t[2]], t = t[3] and t[3] ~= "" and L[t[3]] or nil, find = t[4], only = t.only, pick = t.pick }
end
local function Words(list)
	local out = {}
	for _, t in ipairs(list) do
		if t.client == nil or t.client() then out[#out + 1] = W(t) end
	end
	return out
end
local function Retail() return ns.isRetail and true or false end
local function Weather() return C_Weather ~= nil and C_Weather.GetCurrentWeather ~= nil end

local catalog
function ns.RuleCatalog()
	if catalog then return catalog end
	-- (This client's classes, by the game's names for them.)
	local classes = {}
	for id = 1, (GetNumClasses and GetNumClasses() or 0) do
		local name, file = GetClassInfo(id)
		if name and file and ns.RULE_WORDS[file:lower()] then classes[#classes + 1] = { w = file:lower(), l = name } end
	end
	local cameras = {}
	for _, cam in ipairs(ns.RuleCameraList and ns.RuleCameraList() or {}) do cameras[#cameras + 1] = cam end
	local units = {}
	for _, unit in ipairs(UNITS) do
		if unit.key ~= "focus" or _G.FocusFrame ~= nil then
			local sections = {}
			for _, sec in ipairs(UNIT_SECTIONS) do
				local list = {}
				for _, t in ipairs(sec[2] or unit.distance or {}) do
					local word = sec[2] and ns.UnitWord(unit.key, t[1]) or t[1]
					local label = unit.key == "target" and sec[2] and TARGET_LABELS[t[1]] or t[2]
					list[#list + 1] = { w = word, l = L[label], t = L[t[3]], find = t[4], named = label ~= t[2] or nil }
				end
				if #list > 0 then sections[#sections + 1] = { name = L[sec[1]], words = list } end
			end
			if unit.only then
				local list = {}
				for _, t in ipairs(unit.only) do
					list[#list + 1] = { w = t[1], l = L[t[2]], t = L[t[3]], find = t[4], pick = t.pick }
				end
				sections[#sections + 1] = { name = L["Other"], words = list } -- (this unit's own: This NPC..., On a unit frame)
			end
			units[#units + 1] = { key = unit.key, label = L[unit.label], sub = L[unit.sub], sections = sections }
		end
	end
	catalog = {
		{ key = "fight", name = L["Combat"], sub = L["Fights and what's in them."], color = { 1, 0.45, 0.4 },
			sections = { { words = Words({
				{ "combat", "In combat", "You're in a fight.", "fighting" },
				{ "calm", "Calm Timer", "Just after a fight, till the Calm Timer runs out." },
				{ "nocombat", "Out of combat", "No fight, and the Calm Timer run out.", "peace" },
				{ "boss", "Boss fight", "An encounter, boss frames, or a boss targeted.", "encounter" },
				{ "pvpfight", "PvP fight", "In a battleground or arena, or with an enemy player in the fight." },
				{ "aggro", "Aggro on you", "A mob is attacking you. Where the game hides threat, false.", "threat tanking" },
				{ "entering", "Entering combat", "The moment a fight starts.", "start", only = EDGE },
				{ "leaving", "Leaving combat", "The moment a fight ends.", "end", only = EDGE },
			}) } } },
		{ key = "units", name = L["Units"], sub = L["Your target, the mouse, your focus."], color = { 1, 0.65, 0.25 },
			units = units, colorOnly = { "enemyplayer", "hostilenpc", "neutralplayer", "neutralnpc", "friendlyplayer",
				"friendlynpc", "hoverenemyplayer", "hoverhostilenpc", "hoverneutralplayer", "hoverneutralnpc",
				"hoverfriendlyplayer", "hoverfriendlynpc" } },
		{ key = "dist", name = L["Distance"], sub = L["How far, by your spells and the elites near you."],
			color = { 0.45, 0.9, 0.9 }, sections = {
				{ name = L["Spell range"], words = (function()
					local list = {}
					for _, band in ipairs(ns.RANGE_BANDS or {}) do
						list[#list + 1] = { w = band.field, l = (L["Within %s*"]):format(band.label),
							t = L["True while your target is in reach of this spell, however close."], find = "range yards",
							range = true }
					end
					return list
				end)() },
				{ name = L["Elites"], words = Words({
					{ "elite11", "Elite near (11 yards)", "An elite mob within 11 yards.", "yards" },
					{ "elite28", "Elite near (28 yards)", "An elite mob within 28 yards.", "yards" },
					{ "elite40", "Elite near (40 yards)", "An elite mob within 40 yards.", "yards" } }) } } },
		-- (Location, as the grids' heading; Grouped and the rest here too, as the grids' Location
		-- dropdown has Grouped.)
		{ key = "place", name = L["Location"], sub = L["Where you are, and who with."], color = { 0.45, 0.75, 1 },
			colorOnly = { "warmode", "delve", "mythicplus", "housing" }, sections = {
				{ name = L["Kind"], words = Words({
					{ "world", "Open world" }, { "city", "Cities", "Capital cities." }, { "inn", "Inns" },
					{ "bg", "BGs & arenas", nil, "pvp battleground arena" },
					{ "battleground", "Battlegrounds", client = Retail }, { "arena", "Arenas", client = Retail },
					{ "instance", "Instances", "Dungeons, scenarios and raids." }, { "dungeon", "Dungeons" },
					{ "raid", "Raids" },
					{ "scenario", "Scenarios" }, { "sanctuary", "Sanctuary", "A zone where no one can fight." },
					{ "contested", "Contested zone" },
					{ "warmode", "War Mode", client = Retail }, { "delve", "Delves", client = Retail },
					{ "mythicplus", "Mythic+", nil, "keystone", client = Retail },
					{ "housing", "Your house", nil, "plot", client = Retail } }) },
				{ name = L["Inside"], words = Words({
					{ "indoors", "Indoors", "Inside a building or cave." }, { "outdoors", "Outdoors" } }) },
				{ name = L["Group"], words = Words({
					{ "group", "Grouped", "In a party or raid.", "party" }, { "raidgroup", "In a raid group" },
					{ "leader", "Group leader" } }) },
				{ name = L["This place"], words = Words({
					{ "zone:", "Zone...", "Picks the zone you're in, or one it's inside: true there, its towns too.",
						"map", pick = "zone" },
					{ "subzone:", "Subzone...", "Picks the spot you're in by its name, in your game's language.",
						"area", pick = "subzone" },
					{ "instance:", "Instance...", "Picks the dungeon, raid or battleground you're in.", "dungeon id",
						pick = "instance" } }) } } },
		{ key = "you", name = L["You"], sub = L["Your character, now."], color = { 0.8, 0.6, 1 }, sections = {
			{ name = L["State"], words = Words({
				{ "dead", "Dead", "Dead, or a ghost." }, { "ghost", "Ghost", "A ghost after releasing." },
				{ "casting", "Casting", "Casting or channeling.", "channel" },
				{ "controlled", "Lost control", "Stunned, feared, charmed and the like.", "stun stunned cc fear" },
				{ "stealthed", "Stealthed", nil, "stealth" }, { "mounted", "Mounted", nil, "mount" },
				{ "vehicle", "In a vehicle" },
				{ "shapeshifted", "In a form", "A druid's, shaman's, priest's or warlock's form; not a stance.", "form" },
				{ "sitting", "Sit", "Sitting or lying down.", "sit" },
				{ "resting", "Resting", "In an inn or a city.", "rest" },
				{ "pet", "Pet out" }, { "maxlevel", "Max level", nil, "level cap" } }) },
			{ name = L["Flags"], words = Words({
				{ "afk", "AFK", nil, "away" }, { "dnd", "Busy (DND)", nil, "busy" },
				{ "flagged", "PvP flagged", nil, "pvp" } }) },
			{ name = L["You have"], words = Words({
				{ "aura:", "Aura...", "Picks a buff or debuff on you now: true while you have it.", "buff debuff",
					pick = "aura" },
				{ "form:", "Form...", "Picks one of your forms or stances.", "stance", pick = "form" },
				{ "mount:", "Mount...", "Picks the mount you're on now.", nil, pick = "mount" } }) } } },
		{ key = "doing", name = L["Doing"], sub = L["NPCs, game windows, your screen."], color = { 0.75, 0.8, 0.95 },
			sections = {
				{ name = L["With NPCs"], words = Words({
					{ "interacting", "Interacting", "An NPC's or a service window open, the mailbox and a trade too.",
						"vendor npc window" },
					{ "talking", "Talking", "Gossip, quest text, a book or a talking head.", "dialog gossip quest" },
					{ "window:", "Window...", "Picks a kind of NPC window: true while one is open.",
						"vendor bank trainer mailbox", pick = "window" } }) },
				{ name = L["Screen"], words = Words({
					{ "mapopen", "Map open", nil, "map" },
					{ "menuopen", "Game window open", "Spellbook, map, character, settings and the like.", "menu" },
					{ "editmode", "Edit Mode" }, { "movie", "Movie playing", "A game cinematic or movie.", "cinematic" },
					{ "mouselook", "Turning with the mouse", "A mouse button held to turn.", "mouse camera" },
					{ "gamepad", "Using a gamepad", nil, "controller", client = function() return C_GamePad ~= nil end } }) } } },
		{ key = "travel", name = L["Travel"], sub = L["How you're moving."], color = { 0.6, 0.85, 1 },
			sections = { { words = Words({
				{ "moving", "Moving" }, { "autorun", "Auto-run" }, { "rpwalk", "RP Walk", nil, "walk" },
				{ "swimming", "Swimming", nil, "swim" }, { "underwater", "Under water", nil, "submerged" },
				{ "flying", "Flying", nil, "fly" }, { "gliding", "Gliding", nil, "skyriding", client = Retail },
				{ "fast", "Moving fast", "Faster than a 60% mount.", "speed" }, { "falling", "Falling", nil, "jump" },
				{ "taxi", "On a flight path", nil, "flight taxi" } }) } } },
		{ key = "world", name = L["World"], sub = L["The weather and the time of day."], color = { 0.55, 0.9, 0.7 },
			sections = {
				{ name = L["Weather"], words = Words({
					{ "rain", "Rain", client = Weather }, { "snow", "Snow", client = Weather },
					{ "sandstorm", "Sandstorm", client = Weather }, { "storm", "Storm (heavy rain)", nil, "thunder",
						client = Weather }, { "weather", "Any weather", client = Weather } }) },
				{ name = L["Time"], words = Words({
					{ "dawn", "Dawn", nil, "morning" }, { "day", "Day" }, { "dusk", "Dusk", nil, "evening" },
					{ "night", "Night" } }) } } },
		{ key = "camera", name = L["Camera"], sub = L["Cinematic's own camera modes."], color = { 0.95, 0.75, 0.45 },
			sections = { { words = { { w = "camera", l = L["In a camera mode"], t = L["Any Cinematic camera running."] },
				{ w = "camera:", l = L["Which camera..."], t = L["Picks one camera: true while that one's running."],
					pick = "camera", cameras = cameras } } } } },
		{ key = "char", name = L["Character"], sub = L["Your class, role, spec and race."], color = { 0.85, 0.75, 0.6 },
			sections = {
				{ name = L["Class"], words = classes },
				{ name = L["Role"], words = Words({
					{ "tank", "Tank" }, { "healer", "Healer", nil, "heal" }, { "damage", "Damage", nil, "dps" } }) },
				{ name = L["More"], words = Words({
					{ "spec:", "Spec...", "Picks one of your specs.", "specialization", pick = "spec" },
					{ "race:", "Race...", "Picks your race.", nil, pick = "race" } }) } } },
		{ key = "tip", name = L["Tooltip"], sub = L["The tooltip being shown."], color = { 0.95, 0.95, 0.6 }, only = TOOLTIP,
			sections = { { words = Words({
				{ "tipenemy", "Enemy" }, { "tipfriendly", "Friendly" }, { "tipgather", "Gatherable", nil, "herb ore" },
				{ "tipquest", "Quest objective" }, { "tipother", "Anything else" } }) } } },
	}
	return catalog
end

-- Every word the catalog offers in a context: { entry, cat, unit, sec } each, in the
-- catalog's order (a unit's words once per unit). Kept per context: asked twice a
-- second while the editor's open.
local wordsByContext = {}
function ns.RuleCatalogWords(context)
	context = context or "row"
	if wordsByContext[context] then return wordsByContext[context] end
	local out = {}
	wordsByContext[context] = out
	local function Shows(only) return only == nil or only[context or "row"] end
	for _, cat in ipairs(ns.RuleCatalog()) do
		if Shows(cat.only) then
			if cat.units then
				for _, unit in ipairs(cat.units) do
					for _, sec in ipairs(unit.sections) do
						for _, e in ipairs(sec.words) do out[#out + 1] = { entry = e, cat = cat, unit = unit, sec = sec } end
					end
				end
			else
				for _, sec in ipairs(cat.sections) do
					for _, e in ipairs(sec.words) do
						if Shows(e.only) then out[#out + 1] = { entry = e, cat = cat, sec = sec } end
					end
				end
			end
		end
	end
	return out
end

-- The context a rule's editor opens in: the target's own, else by its key.
function ns.RuleEditorContext(target)
	if target and target.context then return target.context end
	local key = target and target.key
	if type(key) ~= "string" then return "row" end
	if key:find("^tooltip:") then return "tooltip" end
	if key:find("^card:combat") then return "edge" end
	if key == "cdm" then return "cdm" end
	return "row"
end
