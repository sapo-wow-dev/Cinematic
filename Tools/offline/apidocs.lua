-- /cine debug apidocs offline (Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/apidocs.lua
-- Runs Dev/ApiDocsDump.lua against a made-up APIDocumentation and checks the
-- lines it saves are the ones Tools/engine/apidocs.py reads (its --selftest
-- uses the same UnitPower line). Says PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local loaded, reloadText = {}, nil
CinematicDB = {}
GetBuildInfo = function() return "12.1.5", "69594", "Aug 28 2026", 120105 end
date = os.date
C_AddOns = { LoadAddOn = function(name) loaded[#loaded + 1] = name return true end }
local function Frame()
	return { RegisterEvent = function() end, UnregisterAllEvents = function() end, SetScript = function() end }
end
CreateFrame = Frame
C_Timer = {
	After = function() end,
	-- (Like the game: the first tick comes on a later frame, after NewTicker returned.)
	NewTicker = function(_, fn)
		local t = { off = false, fn = fn }
		function t.Cancel() t.off = true end
		TICKERS[#TICKERS + 1] = t
		return t
	end,
}
TICKERS = {}
local function RunFrames()
	for _ = 1, 100 do
		for _, t in ipairs(TICKERS) do
			if not t.off then t.fn() end
		end
	end
end
APIDocumentation = { systems = {
	{ Name = "Unit", Functions = {
		{ Name = "UnitPower", Type = "Function",
			-- (Like the game: each argument points back at its function.)
			Arguments = { { Name = "unit", Type = "UnitToken", Function = { Name = "UnitPower" } },
				{ Name = "type", Type = "number", Nilable = true } },
			Returns = { { Name = "power", Type = "number", SecretReturns = true } } },
	}, Events = {
		{ Name = "UnitPowerUpdate", LiteralName = "UNIT_POWER_UPDATE", Payload = { { Name = "unitTarget", Type = "UnitToken" } } },
	} },
	{ Name = "Spell", Namespace = "C_Spell", Functions = {
		{ Name = "GetSpellInfo", Arguments = {}, Returns = {}, SecretArguments = "AllowedWhenUntainted",
			Fn = function() end, Extra = { a = 1 } },
	}, Tables = {
		{ Name = "SpellInfo", Type = "Structure", Fields = { { Name = "name", Type = "cstring" } } },
	} },
} }
-- luacheck: pop

local ns = {
	isRetail = true,
	PadTestBox = function() end, PadTestBoxHide = function() end, Print = print,
	ReloadOrAsk = function(text) reloadText = text end,
}
assert(loadfile("Dev/ApiDocsDump.lua"))("Cinematic", ns)
ns.ApiDocsDump()
RunFrames()

local d = CinematicDB.apiDocs
Check("docs addons loaded", loaded[1] == "Blizzard_APIDocumentationGenerated", table.concat(loaded, ","))
Check("dump saved", d and d.client == "retail" and d.build == "69594", d and d.client)
local lines = {}
for _, l in ipairs(d and d.lines or {}) do lines[l] = true end
local want = {
	"F Unit UnitPower(unit:UnitToken, type:number?) -> (power:number {SecretReturns=true})",
	"E Unit UNIT_POWER_UPDATE(unitTarget:UnitToken)",
	"F Spell C_Spell.GetSpellInfo() -> () {Extra={a=1},SecretArguments=AllowedWhenUntainted}",
	"T Spell SpellInfo Structure(name:cstring)",
}
for _, w in ipairs(want) do Check("line " .. w, lines[w]) end
Check("four lines", d and #d.lines == 4, d and #d.lines)
Check("counts", d and d.counts == "2 systems, 2 functions, 1 events, 1 tables", d and d.counts)
Check("asks for a reload", reloadText and reloadText:find("Reload to save it"), reloadText)
Check("reload flag set", CinematicDB.apiDocsReload == true)
ns.ApiDocsDump("clear")
Check("clear drops it", CinematicDB.apiDocs == nil)

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
