-- The old tests (written before the test kit) on the kit's log rules, with
-- their steps left exactly as tested (dev copy only). At login each one's
-- start function (ns.<fn>, which Slash.lua calls) gets a thin wrapper:
--   * a test with its own log (CinematicDB.<x>Log): on a fresh start (its
--     log made again or emptied) the run before is kept in <x>PrevLog and
--     the kit's context lines (client, build, zone, combat, group, addons,
--     UI scale) go on the new log;
--   * a test writing into the main log (ns.Log("<category>", ...)): its
--     lines are copied into CinematicDB.<cmd>KitLog as well, which keeps them
--     whole (the main log is trimmed) and gives it a previous run and an
--     archive like the rest; the context lines start it, once a session;
--   * at /reload or logout, every old test started that session gets one
--     closing line: the dev errors and blocked actions since it started.
-- /cine debug kit lists them under the kit's own tests. A test is rewritten
-- onto the kit (Dev/TestKit.lua) the next time it needs real work; then its
-- line here goes.
local _, ns = ...

-- cmd: what follows /cine debug; fn: ns.<fn>, its start; log or category:
-- where it writes (none: listed only).
local OLD = {
	{ cmd = "followtest", fn = "FollowHudTest", file = "FollowHudTest.lua", log = "followTestLog" },
	{ cmd = "previewmatch", fn = "PreviewMatch", file = "PreviewMatch.lua" },
	{ cmd = "loose", fn = "LoosePartsSurvey", file = "LoosePartsSurvey.lua", category = "loose" },
	{ cmd = "petplate", fn = "PetPlateTest", file = "PetPlateTest.lua", log = "petPlateLog" },
	{ cmd = "templates", fn = "TemplateProbe", file = "TemplateProbe.lua" },
	{ cmd = "previewwatch", fn = "PreviewWatch", file = "PreviewWatch.lua", log = "previewWatchLog" },
	{ cmd = "sweep", fn = "SettingsSweep", file = "Sweep.lua", log = "sweepLog" },
	{ cmd = "deathtest", fn = "DeathVisionTest", file = "DeathVisionTest.lua", log = "deathTestLog" },
	{ cmd = "resettest", fn = "ResetTest", file = "ResetTest.lua", log = "resetTestLog" },
	{ cmd = "addontest", fn = "AddonTest", file = "AddonTest.lua", log = "addonTestLog" },
	{ cmd = "euicast", fn = "EuiCastTest", file = "EuiCastTest.lua", log = "euiCastTestLog" },
	{ cmd = "euiswing", fn = "EuiSwingTest", file = "EuiSwingTest.lua", log = "euiSwingTestLog" },
	{ cmd = "euicd", fn = "EuiCooldownTest", file = "EuiCooldownTest.lua", log = "euiCdTestLog" },
	{ cmd = "portal", fn = "ScoutPortal", file = "PortalScout.lua", category = "portal" },
	{ cmd = "screenfx", fn = "ScoutScreenEffects", file = "ScreenEffectScout.lua" },
	{ cmd = "chatreveal", fn = "ChatRevealTest", file = "ChatRevealTest.lua", category = "chatreveal" },
	{ cmd = "chattab", fn = "ChatTabTest", file = "ChatTabTest.lua", category = "chattab" },
	{ cmd = "chatdefault", fn = "ChatDefaultTest", file = "ChatDefaultTest.lua", category = "chatdefault" },
	{ cmd = "tintlayer", fn = "TintLayerTest", file = "TintLayerTest.lua", category = "tintlayer" },
	{ cmd = "shoulder", fn = "ShoulderTest", file = "ShoulderCamTest.lua", category = "shoulder" },
	{ cmd = "dueltarget", fn = "DuelTargetTest", file = "DuelTargetTest.lua", log = "duelTargetLog" },
	{ cmd = "mappin", fn = "MapPinTest", file = "MapPinTest.lua", log = "mapPinLog" },
	{ cmd = "peekdebuffs", fn = "BuffPeekDebuffTest", file = "BuffPeekDebuffTest.lua", log = "peekDebuffLog" },
	{ cmd = "bufftest", fn = "BuffFadeTest", file = "BuffFadeTest.lua", log = "buffTestLog" },
	{ cmd = "spokentest", fn = "SpokenTest", file = "SpokenTest.lua", log = "spokenTestLog" },
	{ cmd = "lowmana", fn = "LowManaTest", file = "LowManaTest.lua", category = "lowmana" },
	{ cmd = "fadedemo", fn = "FadeDemoTest", file = "FadeDemoTest.lua", category = "fadedemo" },
	{ cmd = "shelf", fn = "ShelfTest", file = "ShelfTest.lua", category = "shelftest" },
	{ cmd = "whysecret", fn = "WhySecretTest", file = "WhyTest.lua", log = "whySecretTestLog" },
	{ cmd = "whytest", fn = "WhyTest", file = "WhyTest.lua", category = "whytest" },
	{ cmd = "hrtest", fn = "ThresholdTest", file = "ThresholdTest.lua", category = "hrtest" },
	{ cmd = "partyflicker", fn = "PartyFlickerTest", file = "PartyFlickerTest.lua", category = "partyflicker" },
	{ cmd = "flickertest", fn = "FlickerTest", file = "FlickerTest.lua", category = "flickertest" },
	{ cmd = "namestest", fn = "NamesTest", file = "NamesTest.lua", log = "namesTestLog" },
	{ cmd = "mythemes", fn = "MyThemesTest", file = "MyThemesTest.lua", log = "myThemesLog" },
	{ cmd = "release", fn = "StyleSixTest", file = "StyleSixTest.lua", log = "styleSixLog" },
	{ cmd = "plateflicker", fn = "PlateFlickerTest", file = "PlateFlickerTest.lua", log = "plateFlickerLog" },
	{ cmd = "numbers", fn = "NumberStyleTest", file = "NumberStyleTest.lua", category = "numbers" },
	{ cmd = "cursortest", fn = "CursorMethodTest", file = "CursorReplaceTest.lua", category = "cursortest" },
	{ cmd = "cursortest", fn = "CursorReplaceTest", file = "CursorReplaceTest.lua", category = "cursortest" },
	{ cmd = "whosehit", fn = "WhoseHitTest", file = "WhoseHitTest.lua", log = "combatTextLog" },
	{ cmd = "deadmob", fn = "CorpseTest", file = "CorpseTest.lua", log = "corpseLog" },
	{ cmd = "pace", fn = "PaceTest", file = "PaceTest.lua", log = "paceLog" },
	{ cmd = "rulewords", fn = "RuleWordsTest", file = "RuleWordsTest.lua", log = "ruleWordsLog" },
	{ cmd = "rulecheck", fn = "RuleCheckTest", file = "RuleCheckTest.lua", log = "ruleCheckLog" },
	{ cmd = "apidocs", fn = "ApiDocsDump", file = "ApiDocsDump.lua" },
	{ cmd = "totemhit", fn = "TotemHitTest", file = "TotemHitTest.lua", log = "combatTextLog" },
	{ cmd = "pagestate", fn = "PageStateDebug", file = "PageStateDebug.lua", log = "pageStateLog" },
	{ cmd = "checks", fn = "ChecksProbe", file = "ChecksProbe.lua" },
	{ cmd = "cttest", fn = "CombatTextTest", file = "CombatTextTest.lua", log = "combatTextTestLog" },
	{ cmd = "xprelog", fn = "XpRelogTest", file = "XpRelogTest.lua", log = "xpRelogTestLog" },
	{ cmd = "blockedline", fn = "BlockedLineTest", file = "BlockedLineTest.lua", log = "blockedLineTestLog" },
	{ cmd = "secreterror", fn = "SecretErrorTest", file = "SecretErrorTest.lua", log = "secretErrorTestLog" },
	{ cmd = "detached", fn = "DetachedFadeTest", file = "DetachedFadeTest.lua", log = "detachedFadeLog" },
	{ cmd = "linecolors", fn = "LineColorProbe", file = "LineColorProbe.lua", log = "lineColorLog" },
	{ cmd = "selftextstyle", fn = "SelfTextStyleTest", file = "SelfTextStyleTest.lua", log = "selfTextStyleLog" },
	{ cmd = "selftextall", fn = "SelfTextCatalog", file = "SelfTextCatalog.lua", log = "selfTextAllLog" },
	{ cmd = "selftext", fn = "SelfTextProbe", file = "SelfTextProbe.lua", log = "selfTextLog" },
	{ cmd = "ctkeep", fn = "CombatTextKeepTest", file = "CombatTextKeepTest.lua", log = "combatTextKeepLog" },
	{ cmd = "gsedit", fn = "GameSettingsEditTest", file = "GameSettingsEditTest.lua", log = "gsEditLog" },
	{ cmd = "fightopen", fn = "FightOpenTest", file = "BlockedLineTest.lua", log = "fightOpenTestLog" },
	{ cmd = "taintopen", fn = "TaintOpenTest", file = "BlockedLineTest.lua", log = "taintOpenTestLog" },
	{ cmd = "reloadpaths", fn = "ReloadPathsTest", file = "ReloadPathsTest.lua", log = "reloadPathsLog" },
	{ cmd = "addonlist", fn = "AddonListAllTest", file = "AddonListAllTest.lua", log = "addonListLog" },
	{ cmd = "reloadcover", fn = "ReloadCoverTest", file = "ReloadCoverTest.lua", log = "reloadCoverLog" },
	{ cmd = "favstars", fn = "FavStarsTest", file = "FavStarsTest.lua", log = "favStarsTestLog" },
	{ cmd = "favorites", fn = "FavoritesTest", file = "FavoritesTest.lua", log = "favoritesTestLog" },
	{ cmd = "favlines", fn = "FavLinesTest", file = "FavLinesTest.lua", log = "favLinesTestLog" },
	{ cmd = "lookdock", fn = "LookDockTest", file = "LookDockTest.lua", log = "lookDockTestLog" },
	{ cmd = "gradtest", fn = "GradientTest", file = "GradientTest.lua", log = "gradientTestLog" },
	{ cmd = "ufdrift", fn = "UnitDriftTest", file = "UnitDriftTest.lua", log = "ufDriftLog" },
	{ cmd = "questfocus", fn = "QuestFocusTest", file = "QuestFocusTest.lua", log = "questFocusLog" },
	{ cmd = "dimname", fn = "DimNameTest", file = "DimNameTest.lua", log = "dimNameLog" },
	{ cmd = "emotefit", fn = "EmoteFitTest", file = "EmoteFitTest.lua", log = "emoteFitLog" },
	{ cmd = "keysbars", fn = "KeysBarsTest", file = "KeysBarsTest.lua", log = "keysBarsLog" },
	{ cmd = "turnlag", fn = "TurnLagTest", file = "TurnLagTest.lua", log = "turnLagLog" },
	{ cmd = "platecost", fn = "PlateCostTest", file = "PlateCostTest.lua", log = "plateCostLog" },
	{ cmd = "friendplates", fn = "FriendPlatesTest", file = "FriendPlatesTest.lua", log = "friendPlatesLog" },
	{ cmd = "offhold", fn = "OffscreenHoldTest", file = "OffscreenHoldTest.lua", log = "offHoldLog" },
	{ cmd = "offscreen", fn = "OffscreenProbe", file = "OffscreenProbe.lua", log = "offscreenProbeLog" },
	{ cmd = "officon", fn = "OffscreenIconTest", file = "OffscreenIconTest.lua", log = "offIconLog" },
	{ cmd = "hvicons", fn = "HealIconsCastTest", file = "HealIconsCastTest.lua", log = "hvIconsLog" },
	{ cmd = "hvplates", fn = "HealPlatesTest", file = "HealPlatesTest.lua", log = "healPlatesLog" },
	{ cmd = "npcnames", fn = "NpcNamesTest", file = "NpcNamesTest.lua", log = "npcNamesLog" },
	{ cmd = "namescale", fn = "NameScaleTest", file = "NameScaleTest.lua", log = "nameScaleLog" },
	{ cmd = "npctitle", fn = "NpcTitleTest", file = "NpcTitleTest.lua", log = "npcTitleLog" },
	{ cmd = "themeart", fn = "ThemeArtTest", file = "ThemeArtTest.lua", log = "themeArtLog" },
	{ cmd = "findtabs", fn = "FindTabsTest", file = "FindTabsTest.lua", log = "findTabsLog" },
	{ cmd = "cvartrace", fn = "CVarTraceTest", file = "CVarTraceTest.lua", log = "cvarTraceLog" },
	{ cmd = "dotnumbers", fn = "DotNumbersTest", file = "DotNumbersTest.lua", log = "dotNumbersLog" },
	{ cmd = "cdmlines", fn = "CdmLinesTest", file = "CdmLinesTest.lua", log = "cdmLinesLog" },
	{ cmd = "anytime", fn = "ReadyAnyTimeTest", file = "ReadyAnyTimeTest.lua", log = "anyTimeLog" },
	{ cmd = "stylerevamp", fn = "StyleRevampTest", file = "StyleRevampTest.lua", log = "styleRevampLog" },
	{ cmd = "aggro", fn = "AggroTest", file = "AggroTest.lua", category = "aggro" },
}
ns.TestKitOld = OLD -- (Tools/offline/testkitwrap.lua)

local Kit = ns.TestKit
local started = {} -- [entry] = { at, errors, blocked }: started this session
local mirrored = {} -- [category] = entry
local wrapped = 0

local function Pack(...) return { n = select("#", ...), ... } end
local function Stamp(text) return date("%H:%M:%S") .. " " .. text end
local function PrevKey(key) return (key:gsub("Log$", "PrevLog")) end
local function MirrorKey(entry) return entry.cmd .. "KitLog" end

local function Context(log, entry)
	if type(log) ~= "table" then return end
	log[#log + 1] = Stamp(("kit: /cine debug %s (%s, an old test wrapped by Dev/TestKitWrap.lua)"):format(
		entry.cmd, entry.file))
	for _, line in ipairs(Kit.ContextLines({})) do log[#log + 1] = Stamp("kit " .. line) end
end

local function Started(entry)
	if not started[entry] then
		local errors, blocked = Kit.Counts()
		started[entry] = { at = date("%H:%M:%S"), errors = errors, blocked = blocked }
	end
end

-- A test with its own log: started fresh when its list is new or emptied.
local function OwnLog(entry, orig)
	return function(...)
		local before = CinematicDB and CinematicDB[entry.log]
		local count = type(before) == "table" and #before or 0
		local call = {}
		entry.call = call
		local function Check()
			if entry.call ~= call or call.done or not CinematicDB then return end
			local now = CinematicDB[entry.log]
			if type(now) ~= "table" then return end
			-- (A stop typed mid-run adds to the same list: not a start.)
			if now == before and #now >= count then return end
			call.done = true
			if now ~= before and type(before) == "table" and count > 0 then CinematicDB[PrevKey(entry.log)] = before end
			Context(now, entry)
			started[entry] = nil
			Started(entry)
		end
		local results = Pack(orig(...))
		Check()
		C_Timer.After(0.5, Check)
		C_Timer.After(2, Check)
		return unpack(results, 1, results.n)
	end
end

-- A test writing into the main log: copied into <cmd>KitLog, fresh each session.
local function MainLog(entry, orig)
	return function(...)
		if CinematicDB then
			local key = MirrorKey(entry)
			if not started[entry] then
				if type(CinematicDB[key]) == "table" and #CinematicDB[key] > 0 then
					CinematicDB[key:gsub("KitLog$", "KitPrevLog")] = CinematicDB[key]
				end
				CinematicDB[key] = {}
				Context(CinematicDB[key], entry)
				Started(entry)
			else
				local log = CinematicDB[key]
				if log then log[#log + 1] = Stamp(("kit: /cine debug %s typed again"):format(entry.cmd)) end
			end
		end
		return orig(...)
	end
end

-- One old test wrapped (Tools/offline/testkitwrap.lua drives stand-ins
-- through it). Returns true when it was.
function Kit.WrapOld(entry)
	local orig = ns[entry.fn]
	if type(orig) ~= "function" or not (entry.log or entry.category) then return false end
	ns[entry.fn] = entry.log and OwnLog(entry, orig) or MainLog(entry, orig)
	wrapped = wrapped + 1
	if entry.category then mirrored[entry.category] = mirrored[entry.category] or entry end
	return true
end

local function Wrap()
	for _, entry in ipairs(OLD) do Kit.WrapOld(entry) end
	-- The main log's lines of a started category copied into its KitLog.
	local base = ns.Log
	if type(base) == "function" then
		ns.Log = function(category, text, ...)
			local entry = mirrored[category]
			if entry and started[entry] and CinematicDB then
				local log = CinematicDB[MirrorKey(entry)]
				if log then pcall(function() log[#log + 1] = Stamp(category .. ": " .. tostring(text)) end) end
			end
			return base(category, text, ...)
		end
	end
end

-- One closing line per old test started this session, as the game saves.
local function Close()
	if not CinematicDB then return end
	local errors, blocked = Kit.Counts()
	for entry, at in pairs(started) do
		local log = CinematicDB[entry.log or MirrorKey(entry)]
		if type(log) == "table" then
			log[#log + 1] = Stamp(("kit at /reload: errors +%d, blocked +%d since /cine debug %s at %s"):format(
				errors - at.errors, blocked - at.blocked, entry.cmd, at.at))
		end
	end
end

-- How many were wrapped at login, and the listed ones with a log whose start
-- function wasn't there (renamed or removed: fix the list).
function Kit.WrapState()
	local missing = {}
	for _, entry in ipairs(OLD) do
		if (entry.log or entry.category) and type(ns[entry.fn]) ~= "function" then missing[#missing + 1] = entry.cmd end
	end
	return wrapped, missing
end

Kit.CloseOld = Close -- (Tools/offline/testkit.lua: a /reload's closing lines)

function Kit.ListWrapped()
	print(("old tests (%d wrapped: context lines, the run before kept, totals at /reload; rewritten onto the kit when next worked on):"):format(wrapped))
	for _, entry in ipairs(OLD) do
		print(("  %s - %s, log %s"):format(entry.cmd, entry.file,
			entry.log or (entry.category and (MirrorKey(entry) .. " (copied from the main log's " .. entry.category .. " lines)"))
			or "none of its own"))
	end
end

do
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("PLAYER_LOGIN")
	frame:RegisterEvent("PLAYER_LOGOUT")
	frame:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_LOGIN" then Wrap() else Close() end
	end)
end
