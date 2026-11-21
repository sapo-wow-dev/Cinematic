-- The Text on You page in the player copy (phase 6, Tools/self-text-page-plan.md),
-- offline (Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/selftextrelease.lua forever < /dev/null
--   python -I Tools/offline/run.py Tools/offline/selftextrelease.lua retail < /dev/null
-- With Cinematic.toc (no dev files): on WoW Forever the page is built and
-- every setting on it has a /cine find id (its sliders, tiles and segments
-- had none), and the Shoulder Cam's Follow HUD drops its Floating combat
-- text row (the page's Follow says it there); on retail no page, no ids,
-- and the row stays. Says PASS or FAIL per check.
local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "Cinematic.toc")

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. client .. ": " .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local ids = {}
for _, line in ipairs(ns.SettingIds()) do
	local id, page = line:match("^(.-) | (.-) | ")
	if id then ids[id] = page end
end
local KEYS = { "selfTextStyle", "selfTextBy", "selfTextFollow", "selfTextSide", "selfTextMotion", "selfTextHeight",
	"selfTextAcross", "selfTextSize", "selfTextCrit", "selfTextLife", "selfTextFade", "selfTextShadow", "selfTextFont",
	"selfTextEdge", "selfTextMerge", "selfTextMost", "selfTextSticky", "selfText_damageShow", "selfText_healShow" }
local shown = ns.ShoulderFollowRowShown
Check("the Follow HUD's row test is there", type(shown) == "function")
if client == "retail" then
	local any
	for _, key in ipairs(KEYS) do if ids[key] then any = key end end
	Check("no Text on You ids (no page)", any == nil, any)
	Check("Follow HUD keeps Floating combat text", shown and shown("shoulderCamFollowCombatText") == true)
else
	local missing = {}
	for _, key in ipairs(KEYS) do if not ids[key] then missing[#missing + 1] = key end end
	Check("every setting has a find id", #missing == 0, table.concat(missing, ", "))
	Check("they're on the Text on You page", ids.selfTextBy and ids.selfTextBy == ids.selfTextStyle, ids.selfTextBy)
	Check("Follow HUD drops Floating combat text", shown and shown("shoulderCamFollowCombatText") == false)
	Check("Follow HUD keeps its other rows", shown and shown("shoulderCamFollowCast") == true)
end
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
