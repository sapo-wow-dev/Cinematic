-- The replay bench (Tools/sim-plan.md part 3): Cinematic run on the offline
-- stand-in (Tools/offline/wow.lua) through a scenario, frame by frame, and
-- counted: which loops run each frame and who set them, which events reach
-- which handlers, timers, reads of the game, calls into it, what's blocked,
-- and what Cinematic asked that the bench doesn't model. It counts work; it
-- doesn't time it (the stand-in isn't the game: real milliseconds come from
-- the in-game profiler).
--
-- What the game does comes from the repo's own records (Tools/sim/gamedata.lua):
-- the engine rules, each client's API docs and console settings. Every
-- behaviour below that follows one names it (RULES), and the report says
-- how far each is tested. A behaviour with no rule yet is an assumption, and
-- the report lists it with the probe that will settle it.
--
--   local Bench = dofile("Tools/sim/bench.lua")
--   local bench = Bench.New({ client = "forever" })   -- toc, fps, profile too
--   bench:Play(scenario)                               -- Tools/sim-plan.md's format
--   print(bench:Report())
-- luacheck: push ignore 111 112 113 121 122 142 143 212 431
local Bench = {}
Bench.__index = Bench

-- The behaviours that follow an engine rule (id), and the ones that are
-- assumptions for now (no rule says, or it's unknown), with what settles them.
local RULES = {
	visible = "all.frame.onupdate-visible-only",
	order = "all.frame.in-frame-order",
	cleu = "forever.combatlog.cleu-forbidden",
	softTarget = "forever.softtarget.cvars-protected-combat",
	secret = "forever.unitpower.mana-secret",
}
local ASSUMPTIONS = {
	"CVAR_UPDATE fires on an addon's own SetCVar (simprobe step 3, ledger Q4)",
	"events reach frames in the order the frames were made (no rule)",
	"a secure setting (console settings' secure flag) written in a fight is blocked, as the wiki says for SetCVar",
	"Edit Mode: two preset layouts (Modern, Classic), the first active, none saved, 5 a type at most",
	"stand-in values: every frame at 0,0 100x20 (GetRect), the minimap at zoom 0 of 5, no tracking types",
	"a frame's Is.../Has... question the stand-in has no answer for: no (a stub answered yes: a menu never closed)",
}

local SECRET = setmetatable({}, {
	__tostring = function() return "secret" end,
	-- (Arithmetic and joining on a secret error in the game: rule forever.unitpower.mana-secret.)
	__add = function() error("attempt to perform arithmetic on a secret value", 2) end,
	__sub = function() error("attempt to perform arithmetic on a secret value", 2) end,
	__mul = function() error("attempt to perform arithmetic on a secret value", 2) end,
	__div = function() error("attempt to perform arithmetic on a secret value", 2) end,
	__concat = function() error("attempt to concatenate a secret value", 2) end,
	__lt = function() error("attempt to compare a secret value", 2) end,
	__le = function() error("attempt to compare a secret value", 2) end,
})
Bench.SECRET = SECRET

local HAS_SECRETS = { forever = true, retail = true }

-- The first place in the stack that isn't the bench, the stand-in or
-- Diagnostics.lua's loop helpers: "Frames.lua:13855".
local SKIP_SOURCE = { ["wow.lua"] = true, ["bench.lua"] = true, ["Diagnostics.lua"] = true, ["load.lua"] = true }
local function Caller()
	for level = 3, 14 do
		local info = debug.getinfo(level, "Sl")
		if not info then break end
		local file = (info.source or ""):match("([^/\\@]+)$") or "?"
		if not SKIP_SOURCE[file] and info.what ~= "C" then
			local path = (info.source or ""):gsub("^@", "")
			return path .. ":" .. tostring(info.currentline)
		end
	end
	return "?"
end

local function Add(t, key, n)
	t[key] = (t[key] or 0) + (n or 1)
end

local function Top(t, n)
	local list = {}
	for k, v in pairs(t) do list[#list + 1] = { k, v } end
	table.sort(list, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return tostring(a[1]) < tostring(b[1]) end)
	local out = {}
	for i = 1, math.min(n or #list, #list) do out[i] = list[i] end
	return out, #list
end

-- Game methods counted as calls into the game (a frame's look and place).
local COUNTED_METHODS = { "SetAlpha", "Show", "Hide", "SetShown", "SetPoint", "ClearAllPoints", "SetText",
	"SetFormattedText", "SetTexture", "SetAtlas", "SetVertexColor", "SetTextColor", "SetScale", "SetSize", "SetWidth",
	"SetHeight", "SetFont", "SetDesaturated", "SetIgnoreParentAlpha" }

function Bench.New(opts)
	opts = opts or {}
	local self = setmetatable({}, Bench)
	self.client = opts.client or "forever"
	self.toc = opts.toc or "Cinematic.toc"
	self.fps = opts.fps or 60
	self.data = dofile("Tools/sim/gamedata.lua")(self.client)
	self.now = 1000
	self.timers, self.timerSeq = {}, 0
	self.state = { player = { combat = false, speed = 0, mounted = false }, units = {}, cursor = { 0, 0 } }
	self.plates = {}
	self.count = { onupdate = {}, onupdateFrames = 0, frames = 0, events = {}, handlers = {}, timersMade = {},
		timersFired = 0, calls = {}, reads = {}, blocked = {}, asked = {}, errors = {}, cineFrames = 0, stops = {},
		cineOff = {} }
	self.counting = false
	-- (A fresh install each time: a bench before this one in the same Lua
	-- left its saved settings in the globals, and the next "login" wasn't
	-- fresh. Chance and the date fixed too: the same input, the same report.)
	rawset(_G, "CinematicDB", nil)
	rawset(_G, "CinematicCharDB", nil)
	math.randomseed(1)
	self:Install()
	return self
end

-- Everything the game gives, put in place before Cinematic's files load (they
-- keep their own copies: local GetTime = GetTime).
function Bench:Install()
	local bench = self
	local data = self.data
	local count = self.count
	local frameIndex = 0
	local byEvent = {} -- event -> { frame -> true }
	local allEvents = {} -- frame -> true (RegisterAllEvents)
	local onUpdates = {} -- frame -> true
	local sorted = {} -- (cached sorted lists, dropped on a change)
	self.byEvent, self.allEvents, self.onUpdates, self.sorted = byEvent, allEvents, onUpdates, sorted

	local function Read(name, fn)
		return function(...)
			if bench.counting then Add(count.reads, name) end
			return fn(...)
		end
	end
	-- A game table modelled in part: the rest answered by the stand-in's
	-- stub, and listed as asked, not modelled ("C_EditMode.ConvertStringToLayoutInfo").
	local function Partial(name, t)
		return setmetatable(t, { __index = function(_, key)
			if bench.counting then Add(count.asked, name .. "." .. tostring(key)) end
			return bench.wow.Stub
		end })
	end
	local function Value(v)
		if v == "?" then return SECRET end
		return v
	end
	local function Unit(unit)
		return type(unit) == "string" and bench.state.units[unit] or nil
	end

	local onInstall = function(wow)
		bench.wow = wow
		local M = wow.Methods
		-- (A frame the stand-in doesn't have is its stub, whose parent was the
		-- stub again: a walk up the parents never ended. In the game it ends.)
		rawset(wow.Stub, "GetParent", function() return nil end)
		-- Frames: where each was made, in order.
		local create = _G.CreateFrame
		_G.CreateFrame = function(...)
			local frame = create(...)
			frameIndex = frameIndex + 1
			rawset(frame, "_simIndex", frameIndex)
			rawset(frame, "_simMade", Caller())
			return frame
		end
		-- Scripts: OnUpdate frames tracked.
		local setScript, hookScript = M.SetScript, M.HookScript
		M.SetScript = function(f, script, fn)
			setScript(f, script, fn)
			if script == "OnUpdate" then
				onUpdates[f] = fn and true or nil
				sorted.onUpdate = nil
			end
		end
		M.HookScript = function(f, script, fn)
			hookScript(f, script, fn)
			if script == "OnUpdate" then
				onUpdates[f] = true
				sorted.onUpdate = nil
			end
		end
		-- Events: by name, with unit filters, all events; the combat log on
		-- Forever forbidden (rule forever.combatlog.cleu-forbidden).
		local function Unregister(f, event)
			if byEvent[event] then byEvent[event][f] = nil end
			sorted[event] = nil
		end
		local function Register(f, event, filter)
			if event == "COMBAT_LOG_EVENT_UNFILTERED" and data.Rule(RULES.cleu) then
				Add(count.blocked, RULES.cleu .. " (RegisterEvent COMBAT_LOG_EVENT_UNFILTERED, " .. Caller() .. ")")
				return
			end
			if data.HasEvent(event) == false then
				error(("Attempt to register unknown event \"%s\""):format(tostring(event)), 3)
			end
			byEvent[event] = byEvent[event] or {}
			byEvent[event][f] = filter or true
			f._events[event] = filter or true
			sorted[event] = nil
		end
		M.RegisterEvent = function(f, event) Register(f, event) end
		M.RegisterUnitEvent = function(f, event, ...)
			local units = {}
			for i = 1, select("#", ...) do
				local unit = select(i, ...)
				if unit then units[unit] = true end
			end
			Register(f, event, next(units) and units or nil)
		end
		M.UnregisterEvent = function(f, event)
			f._events[event] = nil
			Unregister(f, event)
		end
		M.UnregisterAllEvents = function(f)
			for event in pairs(f._events) do Unregister(f, event) end
			f._events = {}
			allEvents[f] = nil
			sorted.all = nil
		end
		M.RegisterAllEvents = function(f)
			allEvents[f] = true
			sorted.all = nil
		end
		M.IsEventRegistered = function(f, event) return f._events[event] ~= nil or allEvents[f] == true end
		-- Calls into the game, counted while playing.
		for _, name in ipairs(COUNTED_METHODS) do
			local was = rawget(M, name)
			M[name] = function(f, ...)
				if bench.counting then Add(count.calls, name) end
				if was then return was(f, ...) end
			end
		end
		-- What Cinematic asks that the bench doesn't model: the stand-in's stub.
		local mt = getmetatable(_G)
		local index = mt.__index
		mt.__index = function(t, key)
			local v = index(t, key)
			if v == wow.Stub and bench.counting then Add(count.asked, key) end
			return v
		end

		-- (The game's stack text, for the error handlers: without it an
		-- error inside one became "error in error handling" and the real one was lost.)
		_G.debugstack = function(level) return debug.traceback("", (level or 1) + 1) end

		-- The clock and timers.
		_G.GetTime = function() return bench.now end
		_G.GetTimePreciseSec = function() return bench.now end
		_G.debugprofilestop = function() return bench.now * 1000 end
		_G.time = function() return 1764000000 + math.floor(bench.now) end
		_G.date = function(fmt, t) return os.date(fmt, t or (1764000000 + math.floor(bench.now))) end
		local function Timer(delay, fn, every, times)
			bench.timerSeq = bench.timerSeq + 1
			local t = { at = bench.now + math.max(delay or 0, 0), fn = fn, every = every, times = times,
				seq = bench.timerSeq, made = Caller() }
			function t.Cancel(timer) timer.cancelled = true end
			function t.IsCancelled(timer) return timer.cancelled == true end
			bench.timers[#bench.timers + 1] = t
			if bench.counting then Add(count.timersMade, (every and "ticker " or "timer ") .. t.made) end
			return t
		end
		_G.C_Timer = {
			After = function(delay, fn) Timer(delay, fn) end,
			NewTimer = function(delay, fn) return Timer(delay, fn) end,
			NewTicker = function(every, fn, times) return Timer(every, fn, every, times) end,
		}

		-- Game settings: a store over the console's defaults (Tools/engine/api/<client>-cvars.txt).
		local cvars = {}
		bench.cvars = cvars
		local function GetValue(name)
			if cvars[name] ~= nil then return cvars[name] end
			return data.CVarDefault(name) or "0"
		end
		local function SetValue(name, value)
			if bench.counting then Add(count.calls, "SetCVar") end
			local fight = bench.state.player.combat
			if fight and tostring(name):lower():find("^softtarget") and data.Rule(RULES.softTarget) then
				Add(count.blocked, RULES.softTarget .. " (SetCVar " .. tostring(name) .. ", " .. Caller() .. ")")
				return false
			end
			if fight and data.CVarSecure(name) then
				Add(count.blocked, "console settings: secure in a fight (SetCVar " .. tostring(name) .. ", " .. Caller() .. ")")
				return false
			end
			cvars[name] = tostring(value)
			bench:Fire("CVAR_UPDATE", name, tostring(value))
			return true
		end
		_G.GetCVar = Read("GetCVar", GetValue)
		_G.SetCVar = SetValue
		_G.GetCVarBool = Read("GetCVarBool", function(name) return GetValue(name) == "1" end)
		_G.GetCVarDefault = function(name) return data.CVarDefault(name) end
		_G.C_CVar = Partial("C_CVar", { GetCVar = _G.GetCVar, SetCVar = SetValue, GetCVarBool = _G.GetCVarBool,
			GetCVarDefault = _G.GetCVarDefault })

		-- The world: you and the units, from the scenario's snapshots.
		if HAS_SECRETS[bench.client] then
			_G.issecretvalue = function(v) return v == SECRET end
		else
			_G.issecretvalue = nil
		end
		local P = bench.state.player
		_G.InCombatLockdown = Read("InCombatLockdown", function() return P.combat end)
		_G.UnitAffectingCombat = Read("UnitAffectingCombat", function(unit)
			if unit == "player" then return P.combat end
			local u = Unit(unit)
			return u and Value(u.combat) or false
		end)
		_G.UnitExists = Read("UnitExists", function(unit)
			if unit == "player" then return true end
			local u = Unit(unit)
			return u ~= nil and u.exists == true
		end)
		local function Field(name, field, default)
			return Read(name, function(unit)
				local u = unit == "player" and P or Unit(unit)
				if not u or (unit ~= "player" and not u.exists) then return nil end
				local v = u[field]
				if v == nil then return default end
				return Value(v)
			end)
		end
		_G.UnitGUID = Field("UnitGUID", "guid", nil)
		_G.UnitName = Field("UnitName", "name", nil)
		_G.UnitHealth = Field("UnitHealth", "hp", 100)
		_G.UnitHealthMax = Field("UnitHealthMax", "hpmax", 100)
		_G.UnitPower = Field("UnitPower", "power", 100)
		_G.UnitPowerMax = Field("UnitPowerMax", "powermax", 100)
		_G.UnitLevel = Field("UnitLevel", "level", 60)
		_G.UnitIsDeadOrGhost = Field("UnitIsDeadOrGhost", "dead", false)
		_G.UnitIsDead = _G.UnitIsDeadOrGhost
		_G.UnitIsPlayer = Field("UnitIsPlayer", "isplayer", false)
		_G.UnitCastingInfo = Field("UnitCastingInfo", "cast", nil)
		_G.UnitChannelInfo = Field("UnitChannelInfo", "chan", nil)
		_G.UnitReaction = Read("UnitReaction", function(_, unit)
			local u = Unit(unit)
			return u and u.exists and Value(u.reaction) or nil
		end)
		_G.UnitIsUnit = Read("UnitIsUnit", function(a, b)
			if a == b then return true end
			local x, y = a == "player" and P or Unit(a), b == "player" and P or Unit(b)
			return x ~= nil and y ~= nil and x.guid ~= nil and x.guid == y.guid
		end)
		_G.IsMounted = Read("IsMounted", function() return P.mounted end)
		_G.GetUnitSpeed = Read("GetUnitSpeed", function() return P.speed, 7, 7, 4.7 end)
		_G.GetCursorPosition = Read("GetCursorPosition", function() return bench.state.cursor[1], bench.state.cursor[2] end)
		-- You: movement, input, the clock (the scenario's player fields).
		local function Flag(name, field)
			_G[name] = Read(name, function() return P[field] or false end)
		end
		Flag("IsMouselooking", "mouselook")
		Flag("IsFalling", "falling")
		Flag("IsFlying", "flying")
		Flag("IsSwimming", "swimming")
		Flag("IsResting", "resting")
		Flag("IsIndoors", "indoors")
		Flag("IsStealthed", "stealthed")
		_G.UnitOnTaxi = Read("UnitOnTaxi", function(unit) return unit == "player" and (P.taxi or false) or false end)
		_G.GetPlayerFacing = Read("GetPlayerFacing", function() return P.facing or 0 end)
		_G.IsMouseButtonDown = Read("IsMouseButtonDown", function() return false end)
		for _, name in ipairs({ "IsModifierKeyDown", "IsShiftKeyDown", "IsControlKeyDown", "IsAltKeyDown" }) do
			_G[name] = Read(name, function() return false end)
		end
		_G.C_PlayerInfo = Partial("C_PlayerInfo", { GetGlidingInfo = Read("C_PlayerInfo.GetGlidingInfo", function()
			return P.gliding or false, P.gliding or false, P.gliding and (P.speed or 0) or 0
		end) })
		_G.ChatEdit_GetActiveWindow = Read("ChatEdit_GetActiveWindow", function() return nil end)
		_G.GetBindingKey = Read("GetBindingKey", function() return nil end)
		_G.GetGameTime = Read("GetGameTime", function() return P.hour or 12, P.minute or 0 end)
		_G.GetFramerate = function() return bench.fps end
		for _, name in ipairs({ "GetZoneText", "GetRealZoneText", "GetSubZoneText", "GetMinimapZoneText" }) do
			local field = name == "GetSubZoneText" and "subzone" or "zone"
			_G[name] = Read(name, function() return P[field] or "" end)
		end

		-- The chat windows: each keeps its lines (a chat event adds one to
		-- the first window, as the game's default chat tab shows them all).
		_G.NUM_CHAT_WINDOWS = 10
		bench.chatFrames = {}
		for i = 1, 10 do
			local f = wow.CreateFrame("ScrollingMessageFrame", "ChatFrame" .. i, _G.UIParent)
			rawset(f, "_lines", {})
			f.GetNumMessages = function(frame) return #frame._lines end
			f.GetMessageInfo = function(frame, index) return frame._lines[index] end
			f.AddMessage = function(frame, text) table.insert(frame._lines, text) end
			if i > 1 then f:Hide() end
			bench.chatFrames[i] = f
		end
		_G.DEFAULT_CHAT_FRAME, _G.SELECTED_CHAT_FRAME = _G.ChatFrame1, _G.ChatFrame1

		-- The camera's distance: zooms move it, counted as calls into the game.
		_G.GetCameraZoom = Read("GetCameraZoom", function() return P.zoom or 15 end)
		local function Zoom(name, sign)
			_G[name] = function(amount)
				if bench.counting then Add(count.calls, name) end
				P.zoom = math.max(0, math.min(39, (P.zoom or 15) + sign * (tonumber(amount) or 1)))
			end
		end
		Zoom("CameraZoomIn", -1)
		Zoom("CameraZoomOut", 1)
		for _, name in ipairs({ "MoveViewLeftStart", "MoveViewLeftStop", "MoveViewRightStart", "MoveViewRightStop",
			"MoveViewUpStart", "MoveViewUpStop", "MoveViewDownStart", "MoveViewDownStop", "SetView", "SaveView" }) do
			_G[name] = function() if bench.counting then Add(count.calls, name) end end
		end

		-- A frame's yes/no question the stand-in can't answer: no. (The stub
		-- counts as yes: a dropdown's IsMenuOpen kept a wait going for good.)
		local no = function() return false end
		setmetatable(M, { __index = function(_, key)
			if type(key) == "string" and (key:find("^Is%u") or key:find("^Has%u")) then
				if bench.counting then Add(count.asked, "frame:" .. key) end
				return no
			end
		end })

		-- Plain values where the stand-in had none (a stub can't be compared or counted).
		M.GetRect = function() return 0, 0, 100, 20 end
		M.GetZoom = function() return 0 end
		M.GetZoomLevels = function() return 5 end
		_G.C_Minimap = Partial("C_Minimap", { GetNumTrackingTypes = function() return 0 end,
			GetTrackingInfo = function() return nil end })
		_G.Constants = Partial("Constants", { EditModeConsts = { EditModeMaxLayoutsPerType = 5 } })

		-- Edit Mode, as far as profiles read it (an assumption: no rule).
		_G.C_EditMode = Partial("C_EditMode", {
			GetLayouts = function() return { activeLayout = 1, layouts = {} } end,
			SetActiveLayout = function() end, SaveLayouts = function() end,
		})
		_G.EditModePresetLayoutManager = Partial("EditModePresetLayoutManager", {
			GetCopyOfPresetLayouts = function() return { { layoutName = "Modern" }, { layoutName = "Classic" } } end,
		})
		_G.C_NamePlate = Partial("C_NamePlate", {
			GetNamePlateForUnit = Read("C_NamePlate.GetNamePlateForUnit", function(unit) return bench.plates[unit] end),
			GetNamePlates = Read("C_NamePlate.GetNamePlates", function()
				local list = {}
				for _, plate in pairs(bench.plates) do list[#list + 1] = plate end
				table.sort(list, function(a, b) return a._simIndex < b._simIndex end)
				return list
			end),
		})
	end

	-- Hooks on Cinematic's loop helpers once Diagnostics.lua has run: each
	-- loop's frame named by who asked for it (not Diagnostics.lua itself).
	local realLoadfile = loadfile
	loadfile = function(path)
		local chunk, err = realLoadfile(path)
		if chunk and path:find("Diagnostics%.lua$") then
			return function(name, ns, ...)
				chunk(name, ns, ...)
				for _, fn in ipairs({ "SetOnUpdate", "FeatureLoop", "HookOnUpdate" }) do
					local was = ns[fn]
					ns[fn] = function(frame, ...)
						if type(frame) == "table" and rawget(frame, "_simLoop") == nil then
							rawset(frame, "_simLoop", fn .. " " .. Caller())
						end
						return was(frame, ...)
					end
				end
			end
		end
		return chunk, err
	end
	local ns, wow = dofile("Tools/offline/load.lua")(self.client, self.toc, onInstall)
	loadfile = realLoadfile
	self.ns, self.wow = ns, wow
	-- (Frames made before the counter, the stand-in's own: numbered too, in
	-- order, so every list is in one order each run.)
	for i, f in ipairs(wow.frames) do
		if rawget(f, "_simIndex") == nil then rawset(f, "_simIndex", i - #wow.frames - 1) end
	end
	-- Errors and safety stops, counted.
	local report = ns.ReportError
	ns.ReportError = function(message, ...)
		Add(count.errors, tostring(message):match("^[^\n]*"):sub(1, 160))
		return report(message, ...)
	end
	local suspend = ns.Suspend
	ns.Suspend = function(reason, ...)
		Add(count.stops, tostring(reason))
		return suspend(reason, ...)
	end
end

-- Frames in the order they were made.
local function Sorted(set)
	local list = {}
	for f in pairs(set) do list[#list + 1] = f end
	table.sort(list, function(a, b) return (rawget(a, "_simIndex") or 0) < (rawget(b, "_simIndex") or 0) end)
	return list
end

local function Visible(frame)
	while type(frame) == "table" do
		if rawget(frame, "_shown") == false then return false end
		frame = rawget(frame, "_parent")
	end
	return true
end

local function Name(frame)
	return rawget(frame, "_simLoop") or rawget(frame, "_name") or ("frame made at " .. tostring(rawget(frame, "_simMade")))
end

-- Sends an event to every frame registered for it (unit filters kept), then
-- every frame that asked for all events.
function Bench:Fire(event, ...)
	local count = self.count
	if self.counting then Add(count.events, event) end
	local list = self.sorted[event]
	if not list then
		list = Sorted(self.byEvent[event] or {})
		self.sorted[event] = list
	end
	local all = self.sorted.all
	if not all then
		all = Sorted(self.allEvents)
		self.sorted.all = all
	end
	local unit = ...
	for _, group in ipairs({ list, all }) do
		for _, f in ipairs(group) do
			local filter = group == list and f._events[event] or true
			if filter == true or (type(filter) == "table" and filter[unit]) then
				local handler = f._scripts.OnEvent
				if handler then
					if self.counting then Add(count.handlers, Name(f) .. " <- " .. event) end
					local ok, err = pcall(handler, f, event, ...)
					if not ok then Add(count.errors, ("OnEvent %s: %s"):format(event, tostring(err):sub(1, 140))) end
				end
			end
		end
	end
end

-- A nameplate comes or goes: its frame made first, as the game does.
function Bench:PlateAdded(unit)
	local u = self.state.units[unit] or {}
	self.state.units[unit] = u
	u.exists = true
	local plate = self.plates[unit]
	if not plate then
		plate = CreateFrame("Frame", nil, WorldFrame)
		plate.UnitFrame = CreateFrame("Button", nil, plate)
		plate.namePlateUnitToken = unit
		plate.UnitFrame.unit = unit
		self.plates[unit] = plate
	end
	plate:Show()
	self:Fire("NAME_PLATE_UNIT_ADDED", unit)
end
function Bench:PlateRemoved(unit)
	self:Fire("NAME_PLATE_UNIT_REMOVED", unit)
	local plate = self.plates[unit]
	if plate then plate:Hide() end
	self.plates[unit] = nil
	if self.state.units[unit] then self.state.units[unit].exists = false end
end

-- One scenario entry: { t, "e", event, args... } or { t, "s", unit, field, value }.
function Bench:Apply(entry)
	local kind = entry[2]
	if kind == "s" then
		local unit, field, value = entry[3], entry[4], entry[5]
		if unit == "player" then
			self.state.player[field] = value
		elseif unit == "cursor" then
			self.state.cursor = value
		else
			local u = self.state.units[unit] or {}
			self.state.units[unit] = u
			u[field] = value
		end
	elseif kind == "e" then
		local event = entry[3]
		if event == "NAME_PLATE_UNIT_ADDED" then
			self:PlateAdded(entry[4])
		elseif event == "NAME_PLATE_UNIT_REMOVED" then
			self:PlateRemoved(entry[4])
		else
			if event:find("^CHAT_MSG_") and self.chatFrames then
				local line = tostring(entry[4] or "")
				table.insert(self.chatFrames[1]._lines, line)
			end
			if self.data.HasEvent(event) == false then Add(self.count.errors, "scenario event this client hasn't got: " .. event) end
			self:Fire(event, unpack(entry, 4))
		end
	end
end

-- One frame: the scenario's entries due, the timers due, then every visible
-- frame's OnUpdate in the order made (rule all.frame.in-frame-order: unknown).
function Bench:Step(dt)
	self.now = self.now + dt
	local count = self.count
	local stream, i = self.stream, self.next
	while stream and stream[i] and stream[i][1] + self.start <= self.now do
		self:Apply(stream[i])
		i = i + 1
	end
	self.next = i
	local due = {}
	for k = #self.timers, 1, -1 do
		local t = self.timers[k]
		if t.cancelled then
			table.remove(self.timers, k)
		elseif t.at <= self.now then
			due[#due + 1] = t
		end
	end
	table.sort(due, function(a, b) if a.at ~= b.at then return a.at < b.at end return a.seq < b.seq end)
	for _, t in ipairs(due) do
		if not t.cancelled then
			if self.counting then count.timersFired = count.timersFired + 1 end
			local ok, err = pcall(t.fn, t)
			if not ok then Add(count.errors, ("timer %s: %s"):format(t.made, tostring(err):sub(1, 140))) end
			if t.every and not t.cancelled then
				t.times = t.times and t.times - 1
				if t.times == nil or t.times > 0 then
					t.at = t.at + math.max(t.every, dt)
				else
					t.cancelled = true
				end
			else
				t.cancelled = true
			end
		end
	end
	local list = self.sorted.onUpdate
	if not list then
		list = Sorted(self.onUpdates)
		self.sorted.onUpdate = list
	end
	local ran = 0
	for _, f in ipairs(list) do
		local fn = self.onUpdates[f] and f._scripts.OnUpdate
		if fn and Visible(f) then
			ran = ran + 1
			if self.counting then Add(count.onupdate, Name(f)) end
			local ok, err = pcall(fn, f, dt)
			if not ok then Add(count.errors, ("OnUpdate %s: %s"):format(Name(f), tostring(err):sub(1, 140))) end
		end
	end
	if self.counting then
		count.frames = count.frames + 1
		count.onupdateFrames = count.onupdateFrames + ran
		if self.ns.lastCinematic then
			count.cineFrames = count.cineFrames + 1
		else
			Add(count.cineOff, tostring(self.ns.cineOffWhy))
		end
	end
end

-- Logs in (a profile picked, as a player's first choice), settles, then
-- plays the scenario counting everything.
function Bench:Play(scenario, opts)
	opts = opts or {}
	self.scenario = scenario
	local ns = self.ns
	if ns.SetProfile then ns.SetProfile(opts.profile or ns.DEFAULT_PROFILE) end
	self.profile = ns.ActiveProfile and ns.ActiveProfile()
	local dt = 1 / self.fps
	self:Fire("PLAYER_ENTERING_WORLD", true, false)
	self:Fire("LOADING_SCREEN_DISABLED")
	for _ = 1, math.floor((opts.settle or 3) * self.fps) do self:Step(dt) end
	self.stream = scenario.stream or {}
	table.sort(self.stream, function(a, b) return a[1] < b[1] end)
	self.next, self.start = 1, self.now
	self.counting = true
	local frames = math.floor((scenario.header.length or 10) * self.fps)
	for _ = 1, frames do self:Step(dt) end
	self.counting = false
	return self.count
end

function Bench:Report()
	local c, data, h = self.count, self.data, self.scenario and self.scenario.header or {}
	local out = {}
	local function Say(fmt, ...) out[#out + 1] = select("#", ...) > 0 and fmt:format(...) or fmt end
	local seconds = c.frames / self.fps
	Say("== %s | %s | %s | profile %s | %d fps | %.0f s | %d frames", h.name or "?", self.client, self.toc,
		tostring(self.profile), self.fps, seconds, c.frames)
	if h.synthetic then Say("SYNTHETIC: made up to test the bench, not a recording of the game. Its numbers aren't findings.") end
	Say("in CineMode %d%% of the frames", c.frames > 0 and math.floor(c.cineFrames / c.frames * 100 + 0.5) or 0)
	for _, e in ipairs((Top(c.cineOff, 3))) do Say("  off %d%%: %s", math.floor(e[2] / c.frames * 100 + 0.5), e[1]) end
	Say("")
	Say("-- game data used")
	local rules = 0
	for _ in pairs(data.rules) do rules = rules + 1 end
	Say("engine rules: %d", rules)
	Say("API docs: %s", data.docs and (data.docs.count .. " functions and events") or "missing")
	Say("console settings: %s", data.cvars and (data.cvars.count .. " (" .. tostring(data.cvars.header) .. ")") or "missing")
	for _, m in ipairs(data.missing) do Say("  missing: %s", m) end
	Say("behaviours from engine rules:")
	for what, id in pairs(RULES) do
		local rule = data.rules[id]
		local here = data.Rule(id)
		Say("  %-10s %s: %s%s", what, id, rule and rule.status or "NO SUCH RULE",
			rule and not here and (" (not for " .. self.client .. ": not applied)") or "")
	end
	Say("assumptions (no rule yet):")
	for _, a in ipairs(ASSUMPTIONS) do Say("  %s", a) end
	Say("")
	Say("-- loops (OnUpdate)")
	Say("%.1f OnUpdates run a frame on average", c.frames > 0 and c.onupdateFrames / c.frames or 0)
	local top, n = Top(c.onupdate, 25)
	for _, e in ipairs(top) do Say("  %5.1f%% of frames  %s", e[2] / math.max(c.frames, 1) * 100, e[1]) end
	if n > #top then Say("  (%d more)", n - #top) end
	Say("")
	Say("-- events (sent, and handler calls)")
	local events, en = Top(c.events, 20)
	for _, e in ipairs(events) do Say("  %6.1f/s  %s", e[2] / math.max(seconds, 1e-6), e[1]) end
	if en > #events then Say("  (%d more kinds)", en - #events) end
	local handlers, hn = Top(c.handlers, 20)
	for _, e in ipairs(handlers) do Say("  %6.1f/s  %s", e[2] / math.max(seconds, 1e-6), e[1]) end
	if hn > #handlers then Say("  (%d more)", hn - #handlers) end
	Say("")
	Say("-- timers: %d fired", c.timersFired)
	local timers, tn = Top(c.timersMade, 15)
	for _, e in ipairs(timers) do Say("  %6d made  %s", e[2], e[1]) end
	if tn > #timers then Say("  (%d more)", tn - #timers) end
	Say("")
	Say("-- reads of the game (a second)")
	local reads = Top(c.reads, 20)
	for _, e in ipairs(reads) do Say("  %8.1f  %s", e[2] / math.max(seconds, 1e-6), e[1]) end
	Say("-- calls into the game (a second)")
	local calls = Top(c.calls, 20)
	for _, e in ipairs(calls) do Say("  %8.1f  %s", e[2] / math.max(seconds, 1e-6), e[1]) end
	Say("")
	Say("-- blocked")
	local blocked = Top(c.blocked)
	if #blocked == 0 then Say("  none") end
	for _, e in ipairs(blocked) do Say("  x%d %s", e[2], e[1]) end
	-- (A game frame's name or a function's: the docs say which when they're
	-- here; else by the name's ending.)
	local frames, functions = {}, {}
	for name, n in pairs(c.asked) do
		local isFunction = data.HasFunction(name)
		if isFunction == nil then
			isFunction = not (name:find("Frame%d*$") or name:find("ButtonFrame$") or name:find("Panel$")
				or name:find("Bar$") or name:find("Button%d*$") or name:find("Tooltip$") or name:find("List$")
				or name:find("Manager$") or name:find("Mixin$") or name:find("^C_"))
		end
		if isFunction then functions[name] = n else frames[name] = n end
	end
	for _, group in ipairs({ { "functions", functions }, { "game frames and tables", frames } }) do
		Say("-- asked, not modelled: %s (the stand-in's stub answered)", group[1])
		local asked, an = Top(group[2], 25)
		if #asked == 0 then Say("  none") end
		for _, e in ipairs(asked) do
			local has = data.HasFunction(e[1])
			Say("  x%-6d %s%s", e[2], e[1], has == nil and "" or (has and "  (in this client's docs)"
				or "  (NOT in this client's docs)"))
		end
		if an > #asked then Say("  (%d more)", an - #asked) end
	end
	Say("-- errors (a loop that errors on the stand-in counts wrong: fix the bench or the scenario)")
	local errors = Top(c.errors, 15)
	if #errors == 0 then Say("  none") end
	for _, e in ipairs(errors) do Say("  x%d %s", e[2], e[1]) end
	for reason, n in pairs(c.stops) do Say("  Cinematic stopped itself x%d: %s", n, reason) end
	return table.concat(out, "\n")
end

-- luacheck: pop
return Bench
