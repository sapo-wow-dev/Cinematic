-- Audit fixes, settings and tooling (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/auditsettings.lua [forever|retail] < /dev/null
-- Audit 2026-11-22:
-- 1. The Chat page's Conversations, Game Messages and Channels tabs switched
--    off (a right-click) stopped nothing: their rows are list rows, never hung
--    under the tab's switch, and UI/Chat.lua read them raw.
-- 2. With a part left out, every /cine command error that said "a nil value"
--    was taken for that part; now only a call into a missing ns function.
-- 3. /cine debug hover: an entry with no alpha yet errored every 0.1 s.
-- 4. A slider with no value saved broke the page's Refresh.
-- PASS or FAIL per check.

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local client = arg and arg[1] or "forever"
local tickers = {}
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	UnitAffectingCombat = function() return false end
	C_Timer.NewTicker = function(_, fn)
		local t = { fn = fn, Cancel = function() end }
		tickers[#tickers + 1] = t
		return t
	end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db

-- A local function of the addon's, by name, through a public one's upvalues.
local function Upvalue(fn, name, depth)
	depth = depth or 0
	if type(fn) ~= "function" or depth > 3 then return nil end
	for i = 1, 60 do
		local key, value = debug.getupvalue(fn, i)
		if not key then break end
		if key == name then return value end
		local found = Upvalue(value, name, depth + 1)
		if found then return found end
	end
end

-- 1: the Chat page's tabs.
local IsPeekTypeOn = Upvalue(ns.ChatTestFilter, "IsPeekTypeOn")
local IsChannelPeekNow = Upvalue(ns.ChatTestFilter, "IsChannelPeekNow")
Check(client .. ": 1 the chat checks found", IsPeekTypeOn ~= nil and IsChannelPeekNow ~= nil)
if IsPeekTypeOn and IsChannelPeekNow then
	local people, game
	for _, peekType in ipairs(ns.CHAT_PEEK_TYPES) do
		if peekType.section == "game" then game = game or peekType.key else people = people or peekType.key end
	end
	db.chatPeekTypes[people], db.chatPeekTypes[game] = true, true
	db.chatPeekChannelList.Trade = true
	Check(client .. ": 1 a conversation row on with its Always", IsPeekTypeOn(people) == true, people)
	Check(client .. ": 1 a game message row on with its Always", IsPeekTypeOn(game) == true, game)
	Check(client .. ": 1 a channel on with its Always", IsChannelPeekNow("Trade") == true)
	db["tabOn:Chat/page:2"] = false
	Check(client .. ": 1 Conversations off: its row off", not IsPeekTypeOn(people))
	Check(client .. ": 1 ... the Game Messages row still on", IsPeekTypeOn(game) == true)
	db["tabOn:Chat/page:3"] = false
	Check(client .. ": 1 Game Messages off: its row off", not IsPeekTypeOn(game))
	db["tabOn:Chat/page:4"] = false
	Check(client .. ": 1 Channels off: the channel off", not IsChannelPeekNow("Trade"))
	db["tabOn:Chat/page:2"], db["tabOn:Chat/page:3"], db["tabOn:Chat/page:4"] = true, true, true
	Check(client .. ": 1 all back on with their tabs", IsPeekTypeOn(people) and IsPeekTypeOn(game)
		and IsChannelPeekNow("Trade"))
end

-- 2: what counts as a left-out part's error.
local LeftOut = ns.SlashLeftOutField
Check(client .. ": 2 the check is there", LeftOut ~= nil)
if LeftOut then
	Check(client .. ": 2 a missing ns function: a left-out part's",
		LeftOut("Slash.lua:10: attempt to call field 'NoSuchVisionThing' (a nil value)"))
	Check(client .. ": 2 one ns has: a real bug", not LeftOut("Slash.lua:10: attempt to call field 'Print' (a nil value)"))
	Check(client .. ": 2 a nil local: a real bug", not LeftOut("Slash.lua:10: attempt to index local 'entry' (a nil value)"))
	Check(client .. ": 2 another error: a real bug", not LeftOut("Slash.lua:10: bad argument #1 to 'format'"))
end

-- 3: /cine debug hover with an entry not faded yet (no alpha).
local frame = wow.CreateFrame("Frame", "AuditHoverFrame")
table.insert(ns.managed, { frame = frame, name = "AuditHoverFrame", group = "quests" })
ns.HandleSlash("debug hover quests")
local ticker = tickers[#tickers]
local ok, err = false, "no ticker"
if ticker then ok, err = pcall(ticker.fn) end
Check(client .. ": 3 hover watch tick with no alpha", ok, err)
ns.HandleSlash("debug hover quests") -- (off again)
table.remove(ns.managed)

-- 4: a slider whose setting has no value.
local slider
for _, each in ipairs(wow.frames) do
	if each._kind == "Slider" and type(rawget(each, "Refresh")) == "function"
		and type(rawget(each, "settingKey")) == "string" then
		slider = each
		break
	end
end
Check(client .. ": 4 a slider found", slider ~= nil)
if slider then
	local key = slider.settingKey
	local saved = db[key]
	db[key] = nil
	ok, err = pcall(slider.Refresh, slider)
	Check(client .. ": 4 Refresh with no value saved (" .. key .. ")", ok, err)
	db[key] = saved
end

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
