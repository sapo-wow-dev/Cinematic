-- Help > Game Settings: Yours set on the page, the filter, the row links
-- (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/gamesettingsedit.lua < /dev/null
-- A player asked to set the game settings right there (2026-11-20). Yours
-- on a held setting is saved to put back (not written: that would read as
-- their own change and let go early), on a free one written now, kept stays
-- kept, a fight blocks plate and name settings; a setting a HUD row sets
-- links to that row; the filter box and state menu narrow the rows; each
-- row is /cine find cvar:<name>. Says PASS or FAIL per check.

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

-- (Every setting this client has reads "1" unless set: a known one each.)
local cvars = setmetatable({ nameplateStyle = "0", ObjectSelectionCircle = "1", floatingCombatTextCombatDamage = "1" },
	{ __index = function() return "1" end })
local fight = false
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	C_CVar = {
		SetCVar = function(name, value) cvars[name] = tostring(value) end,
		GetCVar = function(name) return cvars[name] end,
		GetCVarDefault = function() return "1" end,
	}
	SetCVar = function(name, value) return C_CVar.SetCVar(name, value) end
	GetCVar = function(name) return cvars[name] end
	InCombatLockdown = function() return fight end
	hooksecurefunc = function(a, b, c)
		local tbl, name, fn = a, b, c
		if type(a) == "string" then tbl, name, fn = _G, a, b end
		local orig = tbl[name]
		if type(orig) ~= "function" then return end
		tbl[name] = function(...)
			local r = { orig(...) }
			fn(...)
			return unpack(r)
		end
	end
	debugstack = function() return "Interface/AddOns/CinematicDev/Core.lua:1: in function 'WriteCVar'" end
	-- luacheck: pop
end

local ns = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", Install)
ns.db.cvarsLeftAlone = ns.db.cvarsLeftAlone or {}
ns.db.savedCVars = ns.db.savedCVars or {}

-- 1. Held: Nameplate style picked (3), yours 0. Yours set to 5 on the page.
local STYLE = ns.CVarSet("Offline style", "gamesettingsedit.lua",
	{ secure = true, playerWins = true, values = { nameplateStyle = "3" } })
ns.ApplyCVarSet(STYLE, true)
Check("1 held: ours written", cvars.nameplateStyle == "3", cvars.nameplateStyle)
Check("1 yours saved first", ns.db.savedCVars.nameplateStyle == "0", ns.db.savedCVars.nameplateStyle)
Check("1 SetYourCVar says yes", ns.SetYourCVar("nameplateStyle", "5") == true)
Check("1 ours stays now", cvars.nameplateStyle == "3", cvars.nameplateStyle)
Check("1 yours saved as 5", ns.db.savedCVars.nameplateStyle == "5", ns.db.savedCVars.nameplateStyle)
Check("1 still held (not read as your change)", ns.IsCVarHeld("nameplateStyle"))
ns.ApplyCVarSet(STYLE, false)
Check("1 let go: yours (5) back", cvars.nameplateStyle == "5", cvars.nameplateStyle)

-- 2. Free (nothing holds it): written now.
Check("2 free: says yes", ns.SetYourCVar("floatingCombatTextCombatDamage", "0") == true)
Check("2 free: written now", cvars.floatingCombatTextCombatDamage == "0", cvars.floatingCombatTextCombatDamage)

-- 3. Kept as yours, held: written now, stays kept.
local CIRCLE = ns.CVarSet("Offline circle", "gamesettingsedit.lua",
	{ playerWins = true, values = { ObjectSelectionCircle = "0" } })
ns.ApplyCVarSet(CIRCLE, true)
Check("3 held: ours (0)", cvars.ObjectSelectionCircle == "0", cvars.ObjectSelectionCircle)
ns.KeepYourCVar("ObjectSelectionCircle")
Check("3 Keep yours: yours (1) back", cvars.ObjectSelectionCircle == "1", cvars.ObjectSelectionCircle)
ns.SetYourCVar("ObjectSelectionCircle", "0")
Check("3 kept: written now", cvars.ObjectSelectionCircle == "0", cvars.ObjectSelectionCircle)
Check("3 kept: stays kept", ns.db.cvarsLeftAlone.ObjectSelectionCircle == true)
ns.UseOurCVar("ObjectSelectionCircle")
ns.ApplyCVarSet(CIRCLE, false)

-- 4. In a fight: plate and name settings refused, others fine.
fight = true
local before = cvars.nameplateStyle
Check("4 fight: plate setting refused", ns.SetYourCVar("nameplateStyle", "1") == false)
Check("4 fight: plate setting unchanged", cvars.nameplateStyle == before, cvars.nameplateStyle)
Check("4 fight: other setting fine", ns.SetYourCVar("floatingCombatTextCombatDamage", "1") == true)
fight = false
rawset(cvars, "noSuchSetting", nil)
local realGet = GetCVar
GetCVar = function(name) if name == "noSuchSetting" then return nil end return realGet(name) end -- luacheck: ignore 111 121 122
Check("4 setting the client lacks: refused", ns.SetYourCVar("noSuchSetting", "1") == false)
GetCVar = realGet -- luacheck: ignore 111 121 122

-- 5. A HUD row sets it: the page links to the row.
local keep = ns.chardb or ns.db
keep.cvarsOurs = { UnitNameEnemyPlayerName = "1", UnitNameNPC = "0", nameplateShowEnemyMinions = "1" }
Check("5 enemy player names -> its row", ns.CVarRowOwner("UnitNameEnemyPlayerName") == "name:Enemies",
	ns.CVarRowOwner("UnitNameEnemyPlayerName"))
Check("5 all NPC names -> Neutral NPCs row", ns.CVarRowOwner("UnitNameNPC") == "name:NeutralNPCs",
	ns.CVarRowOwner("UnitNameNPC"))
Check("5 enemy minion plates -> its row", ns.CVarRowOwner("nameplateShowEnemyMinions") == "plate:EnemyMinions",
	ns.CVarRowOwner("nameplateShowEnemyMinions"))
Check("5 a name setting no row wrote: none", ns.CVarRowOwner("UnitNamePlayerGuild") == nil)

-- 6. The rows: kinds, and the filter.
ns.ApplyCVarSet(STYLE, true)
local rows = ns.GameSettingsRows()
local byCVar = {}
for _, row in ipairs(rows) do byCVar[row.cvar] = row end
Check("6 rows listed", #rows > 5, #rows)
Check("6 style row: its menu", byCVar.nameplateStyle and byCVar.nameplateStyle.kind == "style",
	byCVar.nameplateStyle and byCVar.nameplateStyle.kind)
Check("6 on/off row: a switch", byCVar.ObjectSelectionCircle and byCVar.ObjectSelectionCircle.kind == "switch",
	byCVar.ObjectSelectionCircle and byCVar.ObjectSelectionCircle.kind)
Check("6 row-set name: a link", byCVar.UnitNameEnemyPlayerName and byCVar.UnitNameEnemyPlayerName.kind == "row",
	byCVar.UnitNameEnemyPlayerName and byCVar.UnitNameEnemyPlayerName.kind)
Check("6 style row: Used for opens a setting", byCVar.nameplateStyle and byCVar.nameplateStyle.find ~= nil)
local Passes = ns.GameSettingsPasses
local enemy = byCVar.UnitNameEnemyPlayerName
Check("6 filter by name words", Passes(enemy, "enemy player") and not Passes(enemy, "guild"))
Check("6 filter by setting name", Passes(byCVar.nameplateStyle, "nameplatestyle"))
Check("6 filter by use", Passes(enemy, "cinemode"))
Check("6 state menu", Passes(byCVar.nameplateStyle, "", "ours") and not Passes(byCVar.nameplateStyle, "", "kept"))

-- 7. The page: filtered lines, Nothing found, /cine find cvar:<name>.
ns.SettingIds() -- (builds the pages)
local page = ns.GameSettingsPage
Check("7 page built", page ~= nil)
if page then
	page.SetFilter("nameplateStyle")
	local keys, headings = {}, 0
	for _, line in ipairs(page.lines) do
		if line:IsShown() then
			if line.settingKey then keys[#keys + 1] = line.settingKey else headings = headings + 1 end
		end
	end
	Check("7 filter: just the style row", #keys == 1 and keys[1] == "cvar:nameplateStyle", table.concat(keys, ","))
	Check("7 filter: its section heading", headings == 1, headings)
	page.SetFilter("zzzz")
	local shown, found = 0, false
	for _, line in ipairs(page.lines) do
		if line:IsShown() then
			shown = shown + 1
			found = found or tostring(line.heading:GetText()):find("Nothing found", 1, true) ~= nil
		end
	end
	Check("7 no match: Nothing found", shown == 1 and found, shown)
	page.SetFilter("")
	local keyed = ns.FindableIds()
	Check("7 /cine find cvar:nameplateStyle reaches it", keyed["cvar:nameplateStyle"] ~= nil)
end

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
