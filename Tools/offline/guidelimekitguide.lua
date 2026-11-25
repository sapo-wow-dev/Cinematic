-- The addon kit's Guidelime test guide (Dev/GuidelimeSupportTest.lua), offline:
--   python -I Tools/offline/run.py Tools/offline/guidelimekitguide.lua < /dev/null
-- With no guide packs the Guidelime stage asked the player to load a guide
-- they didn't have (run q57a1, 2026-11-25). Now, at login during a kit stage
-- for Guidelime, with no guide of the character's own, a small custom guide
-- is saved the way Guidelime's editor saves one and made current; taken back
-- out at the next login with no Guidelime stage. Never without Guidelime
-- loaded, never over a guide of the character's own. PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail ~= nil and (" (" .. tostring(detail) .. ")") or ""))
end

local _, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc")
local loaded = false
C_AddOns.IsAddOnLoaded = function(name) return name == "Guidelime" and loaded end
C_Map = {
	GetBestMapForUnit = function() return 1429 end,
	GetPlayerMapPosition = function() return { x = 0.42, y = 0.655 } end,
	GetMapInfo = function() return { name = "Elwynn Forest" } end,
}

-- Its PLAYER_LOGIN handler: the one from Dev/GuidelimeSupportTest.lua.
local handler
for _, frame in ipairs(wow.frames) do
	local fn = frame._events.PLAYER_LOGIN and frame._scripts.OnEvent
	if fn and (debug.getinfo(fn, "S").source or ""):find("GuidelimeSupportTest") then handler = fn end
end
Check("its login check is there", handler ~= nil)
if not handler then os.exit(1) end
local function Login() handler(nil, "PLAYER_LOGIN") end

local KEY = "Custom guides 1-60 Cinematic addon kit test"
local function KitStage()
	CinematicDB.addonKitPlan = { targets = { "none", "Guidelime" }, at = "2026-11-25 13:34:26" }
	CinematicDB.soloAddons = { keep = { "CinematicDev", "Guidelime", "Questie" } }
end
local function NoStage() CinematicDB.addonKitPlan, CinematicDB.soloAddons = nil, nil end

-- 1 Guidelime not loaded: nothing touched.
GuidelimeData, GuidelimeDataChar = { }, { }
KitStage()
Login()
Check("Guidelime not loaded: none of its data touched", GuidelimeData.customGuides == nil and GuidelimeDataChar.currentGuide == nil)

-- 2 loaded, a kit stage for it, no guide of its own: the test guide, current.
loaded = true
Login()
local text = GuidelimeData.customGuides and GuidelimeData.customGuides["1-60 Cinematic addon kit test"]
Check("a kit stage, no guide of its own: the test guide saved as a custom guide", type(text) == "string", text)
Check("with a goto step a few yards off, in its zone", text and text:find("%[G 45%.0,65%.5 Elwynn Forest%]") ~= nil, text)
Check("and made the character's current guide, as its editor's Save does", GuidelimeDataChar.currentGuide == KEY,
	GuidelimeDataChar.currentGuide)

-- 3 the next login, still the stage: left as it is (not added twice).
Login()
Check("the same stage's next login: left as it is", GuidelimeDataChar.currentGuide == KEY)

-- 4 the stage over: taken back out, the current guide back to none.
NoStage()
Login()
Check("the stage over: the test guide taken out", GuidelimeData.customGuides["1-60 Cinematic addon kit test"] == nil)
Check("and the character's guide back to what it was (none)", GuidelimeDataChar.currentGuide == nil,
	GuidelimeDataChar.currentGuide)
Check("and the kit's note of it gone", CinematicDB.guidelimeKitGuide == nil)

-- 5 a guide of the character's own: never replaced.
GuidelimeData, GuidelimeDataChar = { customGuides = {} }, { currentGuide = "Sage 1-6 Elwynn" }
KitStage()
Login()
Check("a guide of its own: never replaced", GuidelimeDataChar.currentGuide == "Sage 1-6 Elwynn"
	and next(GuidelimeData.customGuides) == nil)

print(fails == 0 and "guidelimekitguide: all passed" or ("guidelimekitguide: %d FAIL"):format(fails))
os.exit(fails == 0 and 0 or 1)
-- luacheck: pop
