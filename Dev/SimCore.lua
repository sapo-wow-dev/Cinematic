-- The simulation recorder's core (Tools/sim-plan.md): hearing every event,
-- counting them in windows, weighing what a recording would hold, and the
-- game settings set, read back and watched. Kept free of Cinematic (it only
-- puts itself on ns) so it moves into the recorder addon as it is. The probe
-- (Dev/SimProbeTest.lua, /cine debug simprobe) drives it. Dev copy only.
local _, ns = ...

local Core = {}
ns.SimCore = Core

local select, type, tostring = select, type, tostring
local function Secret(value)
	return issecretvalue ~= nil and issecretvalue(value) or false
end
local function Clock()
	return debugprofilestop and debugprofilestop() or 0
end

-- Listening ------------------------------------------------------------------
-- mode "all": RegisterAllEvents (way A). mode "list": each name of `list`
-- registered on its own under pcall (way B); `skip(name)` true leaves one out
-- (the combat log by name on Forever: rule forever.combatlog.cleu-forbidden).
local listener = CreateFrame("Frame")
Core.listener = listener
Core.mode = nil
Core.unknown = 0 -- (way B: names the game didn't take)
Core.readCombatLog = false -- (call CombatLogGetCurrentEventInfo in its handler)
Core.onCombatLog = nil -- (function(n, info) for the first payloads: the probe logs them)

local window -- the window events count into now
local settleUntil = -1 -- (events till then count as the switch's burst)
local cvarUpdates = {} -- name (lower) -> GetTime of its last CVAR_UPDATE

local function NewWindow(name)
	return { name = name, started = GetTime(), counts = {}, burst = {}, total = 0, burstTotal = 0, bytes = 0,
		secretArgs = {}, cost = 0, combatLog = 0, combatLogSecret = 0 }
end

-- Roughly what one event takes in a recording: its time, its name, each
-- argument as text (a secret one as one mark), separators.
local function EventBytes(event, ...)
	local bytes = 8 + #event
	local secrets = 0
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		if Secret(value) then
			bytes, secrets = bytes + 2, secrets + 1
		elseif value == nil then
			bytes = bytes + 2
		else
			bytes = bytes + #tostring(value) + 1
		end
	end
	return bytes, secrets
end

local combatLogSeen = 0
listener:SetScript("OnEvent", function(_, event, ...)
	local started = Clock()
	if event == "CVAR_UPDATE" then
		local name = ...
		if type(name) == "string" then cvarUpdates[name:lower()] = GetTime() end
	end
	local w = window
	if w then
		local bytes, secrets = EventBytes(event, ...)
		if GetTime() < settleUntil then
			w.burst[event] = (w.burst[event] or 0) + 1
			w.burstTotal = w.burstTotal + 1
		else
			w.counts[event] = (w.counts[event] or 0) + 1
			w.total = w.total + 1
		end
		w.bytes = w.bytes + bytes
		if secrets > 0 then w.secretArgs[event] = (w.secretArgs[event] or 0) + 1 end
		if event == "COMBAT_LOG_EVENT_UNFILTERED" and Core.readCombatLog and CombatLogGetCurrentEventInfo then
			local info = { pcall(CombatLogGetCurrentEventInfo) }
			w.combatLog = w.combatLog + 1
			local anySecret = false
			for i = 2, #info do
				if Secret(info[i]) then anySecret = true break end
			end
			if anySecret then w.combatLogSecret = w.combatLogSecret + 1 end
			w.bytes = w.bytes + 12 * (#info - 1) -- (about a dozen bytes a field)
			combatLogSeen = combatLogSeen + 1
			if Core.onCombatLog and combatLogSeen <= 5 then Core.onCombatLog(combatLogSeen, info) end
		end
	end
	if w then w.cost = w.cost + (Clock() - started) end
end)

function Core.Listen(mode, list, skip)
	listener:UnregisterAllEvents()
	Core.mode, Core.unknown, Core.registered = mode, 0, 0
	if mode == "all" then
		listener:RegisterAllEvents()
		return true
	end
	for _, name in ipairs(list or {}) do
		if not (skip and skip(name)) then
			if pcall(listener.RegisterEvent, listener, name) then
				Core.registered = Core.registered + 1
			else
				Core.unknown = Core.unknown + 1
			end
		end
	end
	-- (CVAR_UPDATE always: the settings watch reads it.)
	pcall(listener.RegisterEvent, listener, "CVAR_UPDATE")
	return true
end

function Core.Stop()
	listener:UnregisterAllEvents()
	Core.mode = nil
	window = nil
end

-- A new counting window; gives back the one it ends (with ended and seconds).
function Core.Window(name, settle)
	local was = window
	if was then
		was.ended = GetTime()
		was.seconds = was.ended - was.started
	end
	window = name and NewWindow(name) or nil
	settleUntil = settle and GetTime() + settle or -1
	return was
end

function Core.CVarUpdatedSince(name, since)
	local at = cvarUpdates[name:lower()]
	return at ~= nil and at >= since
end

-- Game settings ---------------------------------------------------------------
local function GetValue(name)
	local get = C_CVar and C_CVar.GetCVar or GetCVar
	local ok, value = pcall(get, name)
	if ok then return value end
end
Core.Read = GetValue

-- Writes one; gives back whether the call went, its error, and what reads back.
function Core.Write(name, value)
	local set = C_CVar and C_CVar.SetCVar or SetCVar
	local ok, err = pcall(set, name, tostring(value))
	return ok, (not ok) and err or nil, GetValue(name)
end

-- Same value? (the game hands numbers back as text, "1.000" for "1")
function Core.Same(a, b)
	if a == nil or b == nil then return a == b end
	a, b = tostring(a), tostring(b)
	if a == b then return true end
	local x, y = tonumber(a), tonumber(b)
	return x ~= nil and y ~= nil and math.abs(x - y) < 1e-4
end

-- Snapshots --------------------------------------------------------------------
-- What a recording's snapshots would hold: each unit's facts as text, only
-- the ones changed since the last look counted. Gives the bytes this look adds.
local seen = {}
local READS = {
	{ "guid", UnitGUID }, { "name", UnitName }, { "level", UnitLevel },
	{ "hp", UnitHealth }, { "hpmax", UnitHealthMax }, { "combat", UnitAffectingCombat },
	{ "dead", UnitIsDeadOrGhost }, { "cast", UnitCastingInfo }, { "chan", UnitChannelInfo },
}
local function Text(value)
	if Secret(value) then return "?" end
	return tostring(value)
end
local function LookUnit(unit)
	local bytes = 0
	local was = seen[unit] or {}
	seen[unit] = was
	if not UnitExists(unit) then
		if was.guid then
			wipe(was)
			bytes = bytes + #unit + 4
		end
		return bytes
	end
	for _, read in ipairs(READS) do
		local fn = read[2]
		if fn then
			local ok, value = pcall(fn, unit)
			local text = ok and Text(value) or "!"
			if was[read[1]] ~= text then
				was[read[1]] = text
				bytes = bytes + #unit + #read[1] + #text + 3
			end
		end
	end
	if UnitReaction then
		local ok, value = pcall(UnitReaction, "player", unit)
		local text = ok and Text(value) or "!"
		if was.reaction ~= text then
			was.reaction = text
			bytes = bytes + #unit + 12
		end
	end
	return bytes
end
function Core.Snapshot()
	local started = Clock()
	local bytes, units = 0, 0
	for _, unit in ipairs({ "player", "target", "focus", "mouseover", "pet" }) do
		bytes = bytes + LookUnit(unit)
	end
	for i = 1, 40 do
		local unit = "nameplate" .. i
		if UnitExists(unit) then units = units + 1 end
		bytes = bytes + LookUnit(unit)
	end
	if window then
		window.bytes = window.bytes + bytes
		window.cost = window.cost + (Clock() - started)
	end
	return bytes, units
end
function Core.ForgetSnapshots()
	wipe(seen)
end
