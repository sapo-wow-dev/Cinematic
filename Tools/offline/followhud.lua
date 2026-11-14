-- Follow HUD test (dev tool, offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/followhud.lua < /dev/null
-- FollowHud.lua on a stand-in Edit Mode with a layout of the player's own
-- ("Mine"): set up, set up again with other pieces, a setting changed by the
-- player, then undo. Says PASS or FAIL per check.
local function Deep(v) if type(v) ~= "table" then return v end local o = {} for k, x in pairs(v) do o[k] = Deep(x) end return o end
local PRD = 30
local saved = { activeLayout = 3, layouts = {
	{ layoutName = "Mine", layoutType = 1, systems = {
		{ system = 3, systemIndex = 5, isInDefaultPosition = false, settings = { { setting = 1, value = 7 } },
			anchorInfo = { point = "LEFT", relativeTo = "UIParent", relativePoint = "LEFT", offsetX = 10, offsetY = 0 } },
		{ system = PRD, isInDefaultPosition = true, settings = { { setting = 12, value = 3 }, { setting = 9, value = 5 } },
			anchorInfo = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", offsetX = 0, offsetY = 0 } },
		{ system = 1, isInDefaultPosition = true, settings = { { setting = 0, value = 4 } }, anchorInfo = {} },
	} },
} }
local modern = { layoutName = "Modern", systems = {} }
for _, s in ipairs({ { 20, 1 }, { 20, 2 }, { 20, 3 }, { 29, 1 }, { 29, 2 }, { 29, 3 }, { 3, 1 }, { 3, 2 } }) do
	modern.systems[#modern.systems + 1] = { system = s[1], systemIndex = s[2], isInDefaultPosition = true, settings = { { setting = 3, value = 0 }, { setting = 4, value = 10 } }, anchorInfo = {} }
end
local reloads = 0
-- luacheck: push ignore 111 112 113 121 122 212
local ns = dofile("Tools/offline/load.lua")("forever", nil, function()
	Enum.EditModeSystem = { UnitFrame = 3, CastBar = 1, PersonalResourceDisplay = PRD }
	Enum.EditModeUnitFrameSystemIndices = { Player = 1, Target = 2, Party = 4, Raid = 5 }
	Enum.EditModeLayoutType = { Account = 1 }
	Enum.EditModeUnitFrameSetting = { UseRaidStylePartyFrames = 4 }
	C_EditMode = {
		GetLayouts = function() return Deep(saved) end,
		SaveLayouts = function(info) saved = Deep(info) end,
		SetActiveLayout = function(i) saved.activeLayout = i end,
	}
	EditModePresetLayoutManager = { GetCopyOfPresetLayouts = function() return { Deep(modern), { layoutName = "Classic", systems = {} } } end }
	Constants.EditModeConsts = { EditModeMaxLayoutsPerType = 5 }
	GetActionBarToggles = function() return false, false, false, false end
	SetActionBarToggles = function() end
	StaticPopup_Show = function(name) if name == "CINEMATIC_LAYOUT_RELOAD" then reloads = reloads + 1 end end
end)
-- luacheck: pop
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end
local db = ns.db
db.profileChosen = true
db.offUntilPicked = nil
db.prdOn = false
db.combatShow = db.combatShow or {}
db.combatShow.prd = false
db.combatShow.target = true
db.enemyShow = db.enemyShow or {}
db.enemyShow.prd = false
db.shoulderCamFrames = false
db.ufStyle = true -- (a style setting: must stay)
local layoutBefore = db.editModeLayout
local function Find(layoutName)
	for _, l in ipairs(saved.layouts) do if l.layoutName == layoutName then return l end end
end
local function Sys(layout, system, index)
	for _, s in ipairs(layout.systems) do if s.system == system and s.systemIndex == index then return s end end
end
local function Setting(s, which) for _, x in ipairs(s.settings or {}) do if x.setting == which then return x.value end end end

local ok, reason = ns.FollowHudSetUp()
Check("set up", ok, reason)
Check("prdOn on", db.prdOn == true)
Check("PRD up in fights", db.combatShow.prd == true and db.combatShow.prdpower == true)
Check("PRD up with an enemy", db.enemyShow.prd == true)
Check("frames follow you on", db.shoulderCamFrames == true)
Check("other rows left", db.combatShow.target == true)
Check("style left", db.ufStyle == true)
Check("portrait piece off: player row untouched", db.combatShow.player == nil or db.combatShow.player == ns.ProfileBase().combatShow.player, db.combatShow.player)
Check("profile layout is Follow HUD", db.editModeLayout == "Follow HUD", db.editModeLayout)
Check("made on Mine", ns.chardb.followHudBase == "Mine", ns.chardb.followHudBase)
Check("back to Mine after", ns.chardb.layoutOwn == "Mine", ns.chardb.layoutOwn)
local hud = Find("Follow HUD")
Check("layout saved", hud ~= nil)
if hud then
	Check("on it", ns.ActiveLayoutName() == "Follow HUD", ns.ActiveLayoutName())
	local raid = Sys(hud, 3, 5)
	Check("raid frames as yours", raid and Setting(raid, 1) == 7 and raid.anchorInfo.offsetX == 10)
	local prd = Sys(hud, PRD, nil)
	Check("PRD moved to the bottom middle", prd and prd.anchorInfo.point == "BOTTOM" and prd.anchorInfo.offsetY == 330)
	Check("PRD sized", prd and Setting(prd, 12) == 9 and Setting(prd, 9) == 1, prd and Setting(prd, 12))
	local swing = Sys(hud, 29, 1)
	Check("swing timer added from Modern and sized", swing and Setting(swing, 3) == 19)
	Check("portraits not moved (piece off)", not Sys(hud, 3, 1) or Sys(hud, 3, 1).isInDefaultPosition == true)
	Check("Mine untouched", Find("Mine") and Sys(Find("Mine"), PRD, nil).anchorInfo.point == "CENTER")
end
Check("reload offered", reloads >= 1, reloads)
Check("saved in the profile", db.profiles[ns.ActiveProfile()].followHud ~= nil)

-- set up again (portraits on): undo still goes back to before the first
local picks = ns.FollowHudDefaultPicks()
picks.portraits, picks.frames = true, false
ok = ns.FollowHudSetUp(picks)
Check("set up again", ok)
Check("frames piece off now: back as it was", db.shoulderCamFrames == false)
hud = Find("Follow HUD")
Check("portraits moved now", hud and Sys(hud, 3, 1) and Sys(hud, 3, 1).anchorInfo.offsetX == -300)
Check("still made on Mine", ns.chardb.followHudBase == "Mine")

-- the player changes one of its settings, then takes it off
db.enemyShow.prd = "custom"
local _, _, kept = ns.FollowHudUndo()
Check("undo: waits for the fade to switch", ns.layoutFadeUntil ~= nil)
if ns.layoutFadeUntil then ns.FinishLayoutFade() end
Check("undo: prdOn back", db.prdOn == false)
Check("undo: fights row back", db.combatShow.prd == false and db.combatShow.prdpower == ns.ProfileBase().combatShow.prdpower or db.combatShow.prdpower == nil, db.combatShow.prdpower)
Check("undo: your change kept", db.enemyShow.prd == "custom" and kept == 1, kept)
Check("undo: layout setting back", db.editModeLayout == layoutBefore, db.editModeLayout)
Check("undo: on Mine again", ns.ActiveLayoutName() == "Mine", ns.ActiveLayoutName())
Check("undo: nothing kept", db.followHud == nil)
Check("style still left", db.ufStyle == true)
print(fails == 0 and "ALL PASS" or (fails .. " FAIL"))
