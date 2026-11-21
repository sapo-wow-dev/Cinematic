-- You level up card's emotes (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/youlevelemotes.lua < /dev/null
-- The card started with Cheer, Dance, Flex; then Cheer, Congratulate, Commend
-- (user, 2026-11-20); now Cheer, Victory, Flex (2026-11-21: Congratulate and
-- Commend said "everyone around you", and no emote can go to yourself).
-- Checks the new default, the updates that move a list still at either old
-- default (saved settings, profiles) but keep one a player changed, and that
-- the card's buttons play at no one (never your target). PASS or FAIL per check.

-- luacheck: push ignore 111 112 113 121 122 212
local ns = dofile("Tools/offline/load.lua")("forever", arg and arg[1])
-- luacheck: pop

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local NEW, MID, OLD = "CHEER,VICTORY,FLEX", "CHEER,CONGRATULATE,COMMEND", "CHEER,DANCE,FLEX"
Check("new default", ns.DEFAULTS.emoteVisionYouLevelEmotes == NEW, ns.DEFAULTS.emoteVisionYouLevelEmotes)

local db = ns.db
db.profiles = db.profiles or {}
-- Each old default, as if the updates had never run.
for _, from in ipairs({ OLD, MID }) do
	db.youLevelEmotesV1, db.youLevelEmotesV2 = nil, nil
	db.emoteVisionYouLevelEmotes = from
	db.profiles.CineOld = { settings = { emoteVisionYouLevelEmotes = from } }
	db.profiles.CineMine = { settings = { emoteVisionYouLevelEmotes = "CHEER,DANCE" } }
	db.profileResetPoints = { { emoteVisionYouLevelEmotes = from } }
	ns.RunMigrations()
	Check(from .. " moves", db.emoteVisionYouLevelEmotes == NEW, db.emoteVisionYouLevelEmotes)
	Check(from .. " in a profile moves", db.profiles.CineOld.settings.emoteVisionYouLevelEmotes == NEW)
	Check(from .. " in a reset point moves", db.profileResetPoints[1].emoteVisionYouLevelEmotes == NEW)
	Check("changed list stays", db.profiles.CineMine.settings.emoteVisionYouLevelEmotes == "CHEER,DANCE")
end
-- V1 already run (Cheer, Congratulate, Commend saved): V2 alone moves it.
db.youLevelEmotesV1, db.youLevelEmotesV2 = true, nil
db.emoteVisionYouLevelEmotes = MID
ns.RunMigrations()
Check("after V1: V2 moves it", db.emoteVisionYouLevelEmotes == NEW, db.emoteVisionYouLevelEmotes)
Check("update runs once", db.youLevelEmotesV2 == true)
db.emoteVisionYouLevelEmotes = MID
ns.RunMigrations()
Check("not again (a player's own pick later)", db.emoteVisionYouLevelEmotes == MID)
Check("card's buttons", table.concat(ns.EmoteVisionEmotes("YouLevel"), ",") == MID)
db.emoteVisionYouLevelEmotes = NEW
Check("card's buttons, new", table.concat(ns.EmoteVisionEmotes("YouLevel"), ",") == NEW)
db.profiles.CineOld, db.profiles.CineMine, db.profileResetPoints = nil, nil, nil

-- The card's buttons play at no one ("none"): no emote can go to yourself
-- (rule forever.emote.doemote-player-unit), and no arg would go to your target.
local moment = ns.EmoteVisionLevelMoment(42)
Check("level up card is a self one", moment.kind == "YouLevel" and moment.atSelf == true)
local played = {}
local was = _G.DoEmote
_G.DoEmote = function(token, at) played[#played + 1] = token .. "@" .. tostring(at) end
ns.EmoteVisionAnswerFor(moment, "VICTORY")
_G.DoEmote = was
Check("button plays at no one", played[1] == "VICTORY@none", played[1])

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
