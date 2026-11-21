-- /cine debug selftextall check (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/selftextall.lua < /dev/null
-- The combat text catalog (Dev/SelfTextCatalog.lua) on a stand-in of the
-- game's CombatText: the command starts it, every "Text on Me" setting goes
-- on and CineMode off, a message's kind, info shape, color and hit are put
-- together, a color with no event is "no event", a kind not on the list is
-- NEW, first ones get a screenshot, the box counts and says what to try,
-- typed again it writes the summary and puts everything back, and a second
-- run keeps the first run's kinds.
-- luacheck: push ignore 111 112 113 121 122 212 213
local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc")

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local now = 100
GetTime = function() return now end
local timers, ticker = {}, nil
C_Timer.After = function(seconds, fn) timers[#timers + 1] = { at = now + seconds, fn = fn } end
C_Timer.NewTicker = function(_, fn) ticker = { fn = fn, Cancel = function(self) self.cancelled = true end } return ticker end
local cvars = { enableFloatingCombatText = "1", floatingCombatTextAuras_v2 = "0", floatingCombatTextCombatState_v2 = "0",
	floatingCombatTextEnergyGains_v2 = "1" }
GetCVar = function(name) return cvars[name] end
SetCVar = function(name, value) cvars[name] = tostring(value) end
hooksecurefunc = function(obj, name, fn)
	if type(obj) == "string" then obj, name, fn = _G, obj, name end
	local old = obj[name]
	obj[name] = function(...)
		local a, b, c, d = old(...)
		fn(...)
		return a, b, c, d
	end
end
local shots = 0
Screenshot = function() shots = shots + 1 end
-- (Secret values: a table marked as such.)
local SECRET = {}
local function S(v) local t = { v = v } SECRET[t] = true return t end
issecretvalue = function(v) return SECRET[v] == true end
local info = {}
C_CombatText = { GetCurrentEventInfo = function() return unpack(info) end }
local cine = true
ns.IsCineModeOn = function() return cine end
_G.Cinematic_ToggleCineMode = function() cine = not cine end
local box = ""
ns.PadTestBox = function(text, sub) box = tostring(text) .. " | " .. tostring(sub) end
ns.PadTestBoxHide = function() end
UnitClass = function() return "Warrior", "WARRIOR" end

local ct = CreateFrame("Frame")
_G.CombatText = ct
local text = ct:CreateFontString()
text._color = { 1, 1, 1 }
text.SetTextColor = function(self, r, g, b) self._color = { r, g, b } end
text.GetTextColor = function(self) return unpack(self._color) end
-- luacheck: pop

local function Tick(seconds)
	for _ = 1, math.floor((seconds or 0.1) / 0.1 + 0.5) do
		now = now + 0.1
		for i = #timers, 1, -1 do
			if timers[i].at <= now then table.remove(timers, i).fn() end
		end
		if ticker and not ticker.cancelled then ticker.fn() end
	end
end
local function Has(want)
	for _, line in ipairs(CinematicDB.selfTextAllLog or {}) do if line:find(want, 1, true) then return line end end
end
-- A message as the game sends it: its event, its hit on you, its text
-- drawn in a color (none: not drawn), what else came in that instant.
local function Message(kind, values, action, color, power)
	info = values or {}
	if action then wow.Fire("UNIT_COMBAT", "player", action, "", S(12), 1) end
	if power then wow.Fire("UNIT_POWER_UPDATE", "player", power) end
	if kind then wow.Fire("COMBAT_TEXT_UPDATE", kind) end
	if color then
		text:SetTextColor(color[1], color[2], color[3])
		text:SetText(S("-12"))
	end
	Tick(0.5)
end

Check("the command is on ns", type(ns.SelfTextCatalog) == "function")
local real, called = ns.SelfTextCatalog, nil
ns.SelfTextCatalog = function() called = true end
ns.HandleSlash("debug selftextall")
Check("/cine debug selftextall starts it", called == true)
ns.SelfTextCatalog = real

-- (The first probe's log, as run 1 left it.)
CinematicDB.selfTextLog = { "15:02:40 3.3   COMBAT_TEXT_UPDATE ENERGIZE | info secret, secret, nil, nil, nil, nil, nil",
	"15:02:46 9.0   COMBAT_TEXT_UPDATE DAMAGE | info secret, nil, nil, nil, nil, nil, nil" }
ns.SelfTextCatalog()
Check("first probe's kinds taken in", Has("from the first probe's log: ENERGIZE DAMAGE") ~= nil)
Check("their shape", CinematicDB.selfTextCatalog.ENERGIZE.shapes["secret ?, secret ?"] == true)
Check("groups seen before logged", Has("groups seen before 2 of 12") ~= nil)
Check("box skips groups already had", box:find("Try next: Spells on you", 1, true) ~= nil, box)
Check("box: groups left", box:find("still none: Missed you", 1, true) ~= nil, box)
CinematicDB.selfTextCatalog.ENERGIZE, CinematicDB.selfTextCatalog.DAMAGE = nil, nil
ns.SelfTextCatalog()
CinematicDB.selfTextLog = nil
CinematicDB.selfTextCatalog = {}
shots = 0
ns.SelfTextCatalog()
Check("CineMode off", cine == false)
Check("Text on Me settings on", cvars.floatingCombatTextAuras_v2 == "1" and cvars.floatingCombatTextCombatState_v2 == "1")
Check("a missing setting left alone", cvars.floatingCombatTextHonorGains_v2 == nil)
Check("turned-on list logged", Has("turned on for the run: floatingCombatTextAuras_v2 floatingCombatTextCombatState_v2") ~= nil)
Check("box: first hint is hits", box:find("Hits on you: let a mob hit you", 1, true) ~= nil, box)
Message("DAMAGE", { S(12) }, "WOUND", { 1, 0.1, 0.1 })
Check("DAMAGE put together", Has("DAMAGE #1: info secret table | drawn yes, color 1.00 0.10 0.10 | your hit WOUND  | with nothing") ~= nil)
Tick(0.3)
Check("first one screenshot", shots == 1, shots)
Message("DAMAGE", { S(9) }, "WOUND", { 1, 0.1, 0.1 })
Check("second one: no new screenshot", shots == 1, shots)
Message("SPELL_AURA_START", { S("Ice Barrier"), nil, 5 }, nil, { 1, 1, 0 })
Check("aura shape, trailing nils trimmed", Has("SPELL_AURA_START #1: info secret table, nil, plain number 5.00 | drawn yes, color 1.00 1.00 0.00 | your hit none") ~= nil)
Message(nil, nil, nil, { 1, 0.1, 0.1 })
Check("color with no event", Has("no event #1: info - | drawn yes, color 1.00 0.10 0.10") ~= nil)
Message("SHINY_NEW_THING", {}, nil, nil)
Check("event with nothing drawn", Has("SHINY_NEW_THING #1: info nil | drawn NO, color -") ~= nil)
Message("ENERGIZE", { S(1), S("COMBO_POINTS") }, nil, { 1, 1, 0 }, "COMBO_POINTS")
Check("power type with it", Has("ENERGIZE #1: info secret table, secret table | drawn yes, color 1.00 1.00 0.00 | your hit none | with power COMBO_POINTS") ~= nil)
wow.Fire("PLAYER_REGEN_ENABLED")
text:SetTextColor(0.1, 1, 0.1)
text:SetText(S("-Combat"))
Tick(0.5)
Check("no-event text with fight end", Has("no event #2: info - | drawn yes, color 0.10 1.00 0.10 | your hit none | with fight end") ~= nil)
Check("new kind flagged", Has("NEW kind: SHINY_NEW_THING") ~= nil)
Check("box counts", box:find("+1 new", 1, true) ~= nil, box)
Message("DAMAGE_CRIT", { S(30) }, "WOUND", { 1, 0.1, 0.1 })
Message("SPLIT_DAMAGE", { S(3) })
Check("box moves on to the next group", box:find("Try next: Spells on you", 1, true) ~= nil, box)
Check("box counts groups", box:find("4 of 12 groups", 1, true) ~= nil, box)
ns.SelfTextCatalog()
Check("summary: missing listed", Has("Spells on you: missing SPELL_DAMAGE, SPELL_DAMAGE_CRIT, PERIODIC_DAMAGE, DAMAGE_SHIELD") ~= nil)
Check("summary: seen with its look", Has("DAMAGE x2 [info secret table | drawn 2 yes 0 no | color 1.00 0.10 0.10 | hit WOUND  | with none]") ~= nil)
Check("summary: group marks", Has("[done] Hits on you") ~= nil and Has("[NONE] Heals") ~= nil)
Check("summary: group total", Has("seen 4 of 12 groups, 6 of") ~= nil)
Check("summary: new", Has("NEW SHINY_NEW_THING x1") ~= nil)
Check("done box", box:find("catalog done: 6 of", 1, true) ~= nil, box)
Check("settings put back", cvars.floatingCombatTextAuras_v2 == "0" and cvars.floatingCombatTextCombatState_v2 == "0"
	and cvars.floatingCombatTextEnergyGains_v2 == "1")
Check("CineMode put back", cine == true)
Check("ticker stopped", ticker.cancelled == true)
Check("nothing errored", not Has("error"))
Message("HEAL", { S(5) }, "HEAL", { 0.1, 1, 0.1 })
Check("nothing recorded after", CinematicDB.selfTextCatalog.HEAL == nil)

Check("kept changes cleared at the end", CinematicDB.selfTextAllKept == nil)

-- Ended by a /reload: the summary written and everything put back.
ns.SelfTextCatalog()
Check("changes saved as it starts", CinematicDB.selfTextAllKept and CinematicDB.selfTextAllKept.cvars.floatingCombatTextAuras_v2 == "0")
wow.Fire("PLAYER_LOGOUT")
Check("logout: ended", Has("ended by a /reload or logout: settings put back") ~= nil and Has("=== summary") ~= nil)
Check("logout: settings put back", cvars.floatingCombatTextAuras_v2 == "0" and cine == true and CinematicDB.selfTextAllKept == nil)

-- A crash mid-run: put back at the next login.
ns.SelfTextCatalog()
local stuck = CinematicDB.selfTextAllKept
ticker.cancelled = true
-- (As the game starts again: the saved changes, the run gone.)
CinematicDB.selfTextAllKept = stuck
wow.Fire("PLAYER_LOGIN")
Check("crash: put back at login", cvars.floatingCombatTextAuras_v2 == "0" and CinematicDB.selfTextAllKept == nil
	and Has("unfinished run: settings put back at login") ~= nil)
ns.SelfTextCatalog() -- (the old run object still there in this stand-in: ends it)

-- The first run, ended by a /reload before changes were saved: its list put back to 0.
cvars.floatingCombatTextAuras_v2, cvars.floatingCombatTextCombatState_v2 = "1", "1"
CinematicDB.selfTextAllLog = { "15:28:13 0.0 turned on for the run: floatingCombatTextAuras_v2 floatingCombatTextCombatState_v2",
	"15:29:19 65.7 screenshot first no event at 112026_152919" }
wow.Fire("PLAYER_LOGIN")
Check("old run: put back to 0", cvars.floatingCombatTextAuras_v2 == "0" and cvars.floatingCombatTextCombatState_v2 == "0")
Check("old run: logged once", Has("unfinished first run: put back to 0") ~= nil)
cvars.floatingCombatTextAuras_v2 = "1"
wow.Fire("PLAYER_LOGIN")
Check("old run: not again", cvars.floatingCombatTextAuras_v2 == "1")
cvars.floatingCombatTextAuras_v2 = "0"

-- A second run keeps the first's kinds.
ns.SelfTextCatalog()
Check("second run starts with them", Has("kinds seen before 6 of") ~= nil)
ns.SelfTextCatalog()

for _, warning in ipairs(wow.warnings) do
	if warning:find("SelfText", 1, true) then Check("load: " .. warning, false) end
end
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
