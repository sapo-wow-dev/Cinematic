-- /cine debug levelemote: the You level up card's emotes name no one (user,
-- 2026-11-21: "kind of silly to congratulate everyone around you"). No emote
-- can go to yourself (runs 1-2, rule forever.emote.doemote-player-unit), so
-- the card plays emotes whose line at no one names no one: Cheer, Victory,
-- Flex. One click (step 4), the rest runs itself. Steps:
--   1 moment      the card a level up makes is a self one, its emotes the
--                 new default (PASS/FAIL)
--   2 candidates  Cheer, Victory, Flex, Proud, Huzzah, Magnificent at no
--                 one: each line logged, PASS/FAIL for the card's own (no
--                 "everyone", no "around you"), the others to pick from
--   3 card        the card's buttons (its Answer): the at-no-one line, your
--                 target left alone (PASS/FAIL per emote)
--   4 click       the test kit's r:Click: an /e line sent from your click
--                 (from a step it was blocked, resume(), run 2) (PASS/FAIL)
-- Into CinematicDB.levelEmoteTestLog. Dev copy only.
local _, ns = ...

local CARD = { "CHEER", "VICTORY", "FLEX" }
local MORE = { "PROUD", "HUZZAH", "MAGNIFICENT" }

local function Clean(value)
	if issecretvalue and issecretvalue(value) then return nil end
	return value
end

-- Your own line of event (CHAT_MSG_TEXT_EMOTE) while play runs, 3 s at most;
-- with want, only a line holding it (run 3: your own "/e test" typed while
-- the click waited came first and passed for the test's line).
-- (play may wait, as r:Click does: no pcall around it.)
local function LineFor(r, play, event, want)
	local caught
	local catcher = CreateFrame("Frame")
	catcher:RegisterEvent(event or "CHAT_MSG_TEXT_EMOTE")
	catcher:SetScript("OnEvent", function(_, _, text, ...)
		if caught or Clean(select(11, ...)) ~= Clean(UnitGUID("player")) then return end
		text = Clean(text)
		if want and not (type(text) == "string" and text:find(want, 1, true)) then
			r:Log("  (another line of yours, not the test's: " .. tostring(text) .. ")")
			return
		end
		caught = text or "secret"
	end)
	local a, b = play()
	local untilAt = GetTime() + 3
	r:WaitFor(nil, { check = function() return (caught or GetTime() > untilAt) and true end })
	catcher:UnregisterAllEvents()
	r:Sleep(1.2) -- (the emote's gesture plays out)
	return caught, a, b
end

-- A line that names no one but you.
local function NamesNoOne(line)
	if type(line) ~= "string" then return false end
	local low = line:lower()
	return not (low:find("everyone", 1, true) or low:find("around you", 1, true))
end

local noneLines = {}

ns.TestKit.Define({
	name = "levelemote",
	key = "levelEmoteTest",
	title = "Level up card emotes",
	about = "the You level up card's emotes name no one (Cheer, Victory, Flex); one click",
	context = function()
		return ("card emotes: %s (default %s); target %s"):format(
			table.concat(ns.EmoteVisionEmotes("YouLevel") or {}, ","), tostring(ns.DEFAULTS.emoteVisionYouLevelEmotes),
			tostring(Clean(UnitName("target"))))
	end,
	steps = {
		{ key = "moment", title = "the level up card", run = function(r)
			local moment = ns.EmoteVisionLevelMoment(UnitLevel("player") or 1)
			r:Verdict(moment.kind == "YouLevel" and moment.atSelf == true,
				("kind %s, atSelf %s, name %s"):format(tostring(moment.kind), tostring(moment.atSelf),
				tostring(moment.name)))
			r:Verdict(ns.DEFAULTS.emoteVisionYouLevelEmotes == table.concat(CARD, ","),
				"default emotes " .. tostring(ns.DEFAULTS.emoteVisionYouLevelEmotes))
			local yours = table.concat(ns.EmoteVisionEmotes("YouLevel") or {}, ",")
			r:Log(("your card's emotes: %s (moved by the update: %s)"):format(yours,
				tostring(ns.db.youLevelEmotesV2)))
		end },
		{ key = "candidates", title = "the emotes at no one", run = function(r)
			local all = {}
			for _, token in ipairs(CARD) do all[#all + 1] = { token, true } end
			for _, token in ipairs(MORE) do all[#all + 1] = { token, false } end
			for _, each in ipairs(all) do
				local token, onCard = each[1], each[2]
				local line = LineFor(r, function() pcall(DoEmote, token, "none") end)
				noneLines[token] = line
				local text = ("%s at no one: %s"):format(token, tostring(line))
				if onCard then r:Verdict(NamesNoOne(line), text)
				-- (No line in 3 s: Huzzah, Magnificent in run 3, no text emote.)
				else r:Log(text .. (line == nil and " (no line)" or NamesNoOne(line) and " (names no one)"
					or " (NAMES OTHERS)")) end
			end
		end },
		{ key = "card", title = "the card's buttons", run = function(r)
			local target = Clean(UnitGUID("target"))
			for _, token in ipairs(CARD) do
				local moment = ns.EmoteVisionLevelMoment(UnitLevel("player") or 1)
				local line = LineFor(r, function() ns.EmoteVisionAnswerFor(moment, token) end)
				r:Verdict(line ~= nil and line == noneLines[token] and NamesNoOne(line),
					("%s from the card: %s (at no one: %s)"):format(token, tostring(line), tostring(noneLines[token])))
			end
			r:Verdict(Clean(UnitGUID("target")) == target, "your target left alone: " .. tostring(Clean(UnitName("target"))))
		end },
		{ key = "click", title = "a call from your click (r:Click)", run = function(r)
			local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
			local line, ok, err = LineFor(r, function()
				return r:Click("Click Send /e line", function() send("cheers at themself.", "EMOTE") end,
					"Send /e line")
			end, "CHAT_MSG_EMOTE", "themself")
			r:Verdict(ok and line ~= nil, ("/e line from your click: sent %s %s, back: %s"):format(tostring(ok),
				tostring(err), tostring(line)))
		end },
	},
})
