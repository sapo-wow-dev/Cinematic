-- The rules' value words (2026-11-25, Tools/cql-words-plan.md phase 4):
-- axis:value, one word for an axis with many values instead of a word each.
-- "zone:1453" (Stormwind City), "aura:465,19740" (either buff on you),
-- "subzone:"Lion's Pride Inn"" (quoted with spaces), "window:merchant".
-- Values are ids where the game has them, so a rule reads the same in every
-- language; the editor shows the name next to each (ns.ColoredRule). A value
-- this client doesn't know just reads false. Frames.lua's ns.CompileRule
-- reads the words; ns.AxisWords fills facts.axes each full working out, only
-- for the axes a rule names (and only the values named, where the lookup
-- costs: aura, mount).
local _, ns = ...
local L = ns.L

-- Each axis: read(set, wanted, prev) puts the values true now into set
-- (wanted: value -> true, the ones rules name; prev: last time's set),
-- Name(value) for the editor (nil: none known), Pick() a menu of
-- { word, label } (where you are, what you have), label.
local axes = {}
ns.RULE_AXES = axes
ns.axisWanted = {} -- (axis -> value -> true: named by a compiled rule)

local function Plain(value)
	return value ~= nil and not (issecretvalue and issecretvalue(value))
end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
	if not ok then return nil end
	return a, b, c, d, e, f, g, h
end
local function SpellName(id)
	id = tonumber(id)
	if not id then return nil end
	local name = C_Spell and C_Spell.GetSpellName and Call(C_Spell.GetSpellName, id)
	if not Plain(name) and GetSpellInfo then name = (Call(GetSpellInfo, id)) end
	return Plain(name) and name or nil
end

-- zone: a uiMapID, true on that map or one inside it (a zone holds its towns).
local mapChain, mapChainFor = {}, nil
local function MapChain()
	local id = C_Map and C_Map.GetBestMapForUnit and Call(C_Map.GetBestMapForUnit, "player")
	if not Plain(id) then return {} end
	if id ~= mapChainFor then
		mapChain, mapChainFor = {}, id
		local seen = 0
		while id and id > 0 and seen < 12 do
			mapChain[#mapChain + 1] = id
			local info = Call(C_Map.GetMapInfo, id)
			id = info and Plain(info.parentMapID) and info.parentMapID or nil
			seen = seen + 1
		end
	end
	return mapChain
end
local function MapName(id)
	local info = C_Map and C_Map.GetMapInfo and Call(C_Map.GetMapInfo, tonumber(id))
	return info and Plain(info.name) and info.name or nil
end
axes.zone = {
	label = "Zone",
	read = function(set) for _, id in ipairs(MapChain()) do set[tostring(id)] = true end end,
	Name = MapName,
	Pick = function()
		local list = {}
		for _, id in ipairs(MapChain()) do list[#list + 1] = { "zone:" .. id, MapName(id) or tostring(id) } end
		return list
	end,
}

-- subzone: the text the game shows, in the language it was written in.
local function Subzone()
	local text = GetSubZoneText and Call(GetSubZoneText)
	return Plain(text) and text ~= "" and text or nil
end
axes.subzone = {
	label = "Subzone",
	read = function(set) local text = Subzone() if text then set[text:lower()] = true end end,
	Pick = function()
		local text = Subzone()
		return text and { { ('subzone:"%s"'):format(text), text } } or {}
	end,
}

-- instance: the instance's id (dungeon, raid, battleground, delve...).
local function InstanceHere()
	local name, kind, _, _, _, _, _, id = Call(GetInstanceInfo)
	if Plain(kind) and kind ~= "none" and Plain(id) and type(id) == "number" then return id, Plain(name) and name or nil end
end
local instanceNames = {}
axes.instance = {
	label = "Instance",
	read = function(set) local id = InstanceHere() if id then set[tostring(id)] = true end end,
	Name = function(value)
		return instanceNames[value] or (GetRealZoneText and Plain(Call(GetRealZoneText, tonumber(value)))
			and Call(GetRealZoneText, tonumber(value))) or nil
	end,
	Pick = function()
		local id, name = InstanceHere()
		if not id then return {} end
		instanceNames[tostring(id)] = name
		return { { "instance:" .. id, name or tostring(id) } }
	end,
}

-- window: an NPC's or a service window open, by the game's interaction kind
-- (PLAYER_INTERACTION_MANAGER_FRAME_SHOW / _HIDE), lower case: merchant...
local windowNames, windowsOpen = {}, {}
-- (Made at the first event: the game's numbers, kind -> lower-case name.)
local function WindowName(kind)
	if not next(windowNames) and type(Enum) == "table" and type(Enum.PlayerInteractionType) == "table" then
		for name, value in pairs(Enum.PlayerInteractionType) do windowNames[value] = name:lower() end
	end
	return windowNames[kind]
end
do
	local watch = CreateFrame("Frame")
	pcall(watch.RegisterEvent, watch, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
	pcall(watch.RegisterEvent, watch, "PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
	watch:SetScript("OnEvent", function(_, event, kind)
		local name = WindowName(kind)
		if name then windowsOpen[name] = event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" or nil end
	end)
end
local WINDOW_PICKS = { { "merchant", "Vendor" }, { "gossip", "Gossip" }, { "questgiver", "Quest giver" },
	{ "banker", "Bank" }, { "trainer", "Trainer" }, { "taxinode", "Flight master" },
	{ "mailinfo", "Mailbox" }, { "auctioneer", "Auction house" }, { "tradepartner", "Trade" },
	{ "guildbanker", "Guild bank" }, { "transmogrifier", "Transmog" }, { "barbershop", "Barber" } }
axes.window = {
	label = "Window",
	read = function(set) for name in pairs(windowsOpen) do set[name] = true end end,
	Name = function(value)
		for _, pick in ipairs(WINDOW_PICKS) do if pick[1] == value then return L[pick[2]] end end
	end,
	Pick = function()
		local list = {}
		for _, pick in ipairs(WINDOW_PICKS) do
			list[#list + 1] = { "window:" .. pick[1], L[pick[2]] .. (windowsOpen[pick[1]] and (" (" .. L["open now"] .. ")") or "") }
		end
		return list
	end,
}

-- aura: a buff or debuff on you, by spell id; only the ids rules name are
-- looked up. In a fight where the game won't say (Forever: memory
-- forever-fight-aura-apis), each keeps what it was before the fight.
axes.aura = {
	label = "Aura",
	read = function(set, wanted, prev)
		local get = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
		local fight = InCombatLockdown() or ns.Flag(UnitAffectingCombat("player"))
		for value in pairs(wanted or {}) do
			local id = tonumber(value)
			local ok, aura = false, nil
			if id and get then ok, aura = pcall(get, id) end
			if ok and Plain(aura) and aura ~= nil then
				set[value] = true
			elseif fight and (not ok or aura == nil) and prev and prev[value] then
				set[value] = true -- (held: the game may just not be saying)
			end
		end
	end,
	Name = SpellName,
	Pick = function()
		local list = {}
		local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
		for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
			for i = 1, 40 do
				local aura = get and Call(get, "player", i, filter)
				if not aura then break end
				local id, name = aura.spellId, aura.name
				if Plain(id) and Plain(name) then list[#list + 1] = { "aura:" .. id, name } end
			end
		end
		return list
	end,
}

-- form: your shapeshift form or stance, by its spell id.
local function Forms()
	local list = {}
	for i = 1, (GetNumShapeshiftForms and Call(GetNumShapeshiftForms) or 0) do
		local _, active, _, spellID = Call(GetShapeshiftFormInfo, i)
		if Plain(spellID) then list[#list + 1] = { id = spellID, active = Plain(active) and active } end
	end
	return list
end
axes.form = {
	label = "Form",
	read = function(set) for _, form in ipairs(Forms()) do if form.active then set[tostring(form.id)] = true end end end,
	Name = SpellName,
	Pick = function()
		local list = {}
		for _, form in ipairs(Forms()) do list[#list + 1] = { "form:" .. form.id, SpellName(form.id) or tostring(form.id) } end
		return list
	end,
}

-- mount: the mount you're on, by its mount id; only the ids rules name.
local function MountInfo(id)
	local name, _, _, active = Call(C_MountJournal and C_MountJournal.GetMountInfoByID, tonumber(id))
	return Plain(name) and name or nil, Plain(active) and active or false
end
axes.mount = {
	label = "Mount",
	read = function(set, wanted)
		if not ns.Flag(IsMounted()) then return end
		for value in pairs(wanted or {}) do
			local _, active = MountInfo(value)
			if active then set[value] = true end
		end
	end,
	Name = function(value) return (MountInfo(value)) end,
	Pick = function()
		local ids = C_MountJournal and C_MountJournal.GetMountIDs and Call(C_MountJournal.GetMountIDs) or {}
		for _, id in ipairs(ids) do
			local name, active = MountInfo(id)
			if active then return { { "mount:" .. id, name or tostring(id) } } end
		end
		return {}
	end,
}

-- class, race (their file names, lower case) and spec (its id).
local CLASS_NAMES = _G.LOCALIZED_CLASS_NAMES_MALE or {}
axes.class = {
	label = "Class",
	read = function(set) local _, file = UnitClass("player") if file then set[file:lower()] = true end end,
	Name = function(value) return CLASS_NAMES[value:upper()] end,
	Pick = function()
		local list = {}
		for id = 1, (GetNumClasses and GetNumClasses() or 0) do
			local name, file = GetClassInfo(id)
			if name and file then list[#list + 1] = { "class:" .. file:lower(), name } end
		end
		return list
	end,
}
axes.race = {
	label = "Race",
	read = function(set) local _, file = UnitRace("player") if file then set[file:lower()] = true end end,
	Pick = function()
		local name, file = UnitRace("player")
		return file and { { "race:" .. file:lower(), name or file } } or {}
	end,
}
local function SpecHere()
	local index = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization)
	index = index and Call(index)
	local info = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo
	if Plain(index) and index and info then
		local id = Call(info, index)
		if Plain(id) and type(id) == "number" then return id end
	end
end
axes.spec = {
	label = "Spec",
	read = function(set) local id = SpecHere() if id then set[tostring(id)] = true end end,
	Name = function(value)
		local _, name = Call(GetSpecializationInfoByID, tonumber(value))
		return Plain(name) and name or nil
	end,
	Pick = function()
		local list = {}
		local count = (C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID
			and Call(C_SpecializationInfo.GetNumSpecializationsForClassID, select(3, UnitClass("player"))))
			or (GetNumSpecializations and Call(GetNumSpecializations)) or 0
		local info = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo
		for i = 1, count do
			local id, name = Call(info, i)
			if Plain(id) and Plain(name) then list[#list + 1] = { "spec:" .. id, name } end
		end
		return list
	end,
}

-- camera: a Cinematic camera running, by its key (flight, idle, chatcam, script).
axes.camera = {
	label = "Camera",
	read = function(set)
		if ns.activeCam then set[tostring(ns.activeCam):lower()] = true end
		local scripted = ns.PlayingCameraKey and ns.PlayingCameraKey()
		if scripted then set[tostring(scripted):lower()] = true end
		if ns.PlayingCameraScript and ns.PlayingCameraScript() ~= nil then set.script = true end
	end,
	Pick = function()
		local list = {}
		for _, cam in ipairs(ns.RULE_CAMERAS or {}) do
			local key = cam[2] or cam[1]:gsub("^cam_", "")
			list[#list + 1] = { "camera:" .. key, key }
		end
		return list
	end,
}

-- targetid: your target's NPC id (from its GUID; secret in instances: false there).
local function TargetNpcId()
	local guid = UnitGUID("target")
	if not Plain(guid) or type(guid) ~= "string" then return nil end
	local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
	if kind == "Creature" or kind == "Vehicle" then return id end
end
axes.targetid = {
	label = "Target NPC",
	read = function(set) local id = TargetNpcId() if id then set[id] = true end end,
	Name = function(value)
		if TargetNpcId() == value then local name = UnitName("target") return Plain(name) and name or nil end
	end,
	Pick = function()
		local id = TargetNpcId()
		local name = UnitName("target")
		return id and { { "targetid:" .. id, (Plain(name) and name or id) } } or {}
	end,
}

-- Each full working out of ns.RuleFacts: the axes a rule names (want:
-- its Want, by "axis:<name>"), others empty. facts.axisSig changes with
-- any of them, so the rows' kept answers are worked out again.
local sets, sigParts = {}, {}
function ns.AxisWords(facts, want)
	facts.axes = facts.axes or {}
	wipe(sigParts)
	for name, axis in pairs(axes) do
		local prev = sets[name]
		local set = {}
		if want("axis:" .. name) then axis.read(set, ns.axisWanted[name], prev) end
		sets[name], facts.axes[name] = set, set
		for value in pairs(set) do sigParts[#sigParts + 1] = name .. ":" .. value end
	end
	table.sort(sigParts)
	facts.axisSig = table.concat(sigParts, " ")
end

-- The words of a rule's axis token (Frames.lua's Tokens): its values marked
-- wanted. Gives a test of the facts, or nil and why not.
function ns.AxisTest(axisName, values)
	local axis = axes[axisName]
	if not axis then return nil, ("\"%s\" isn't a word it knows"):format(axisName .. ":") end
	if #values == 0 then return nil, ("%s: needs a value after it"):format(axisName) end
	ns.axisWanted[axisName] = ns.axisWanted[axisName] or {}
	for _, value in ipairs(values) do ns.axisWanted[axisName][value] = true end
	return function(f)
		local set = f.axes and f.axes[axisName]
		if not set then return false end
		for _, value in ipairs(values) do
			if set[value] then return true end
		end
		return false
	end
end

-- A value's name for showing (nil: none known).
function ns.AxisValueName(axisName, value)
	local axis = axes[axisName]
	if not (axis and axis.Name) then return nil end
	local ok, name = pcall(axis.Name, value)
	return ok and name or nil
end
