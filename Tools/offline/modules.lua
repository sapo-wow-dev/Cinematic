-- Visions left out (Modules.lua, Visions General's Load Visions): its code
-- never runs, the rest of the addon works without it, and its settings stay.
-- Each client is loaded twice, in a run of its own each (nothing kept
-- between): Visions on, then off from the settings the first left, as a
-- player switching it off has them (its defaults in CinematicDB.moduleDefaults).
--
--   On:  no errors; its code ran; its defaults kept; every frame's events and
--        update fired once, the errors that gives noted (the stand-in's stubs
--        make some of their own).
--   Off: no errors; no frame, hook or timer made by any Vision's file
--        (Visions/, Vitals, Teleport, Death, Wind Guide); the same DEFAULTS
--        keys as on (profiles, sharing and Reset carry them); every Vision
--        page gone but Visions General; the vision wheel, its Wheels tab and
--        the Welcome window's Visions gone; every event and update fired once
--        with no error that on didn't have.
--
--   python -I Tools/offline/run.py Tools/offline/modules.lua
-- Exit 1 on any problem.
local LUA = os.getenv("CINE_LUA") or "lua5.1"
local phase, client, toc, tmp = ...
local TOCS = { "Cinematic.toc", "CinematicDev.toc" }

-- Values as Lua source (the settings handed from the on run to the off run).
local function Dump(value)
	if type(value) == "table" then
		local parts = {}
		for k, v in pairs(value) do
			if type(v) ~= "function" then parts[#parts + 1] = "[" .. Dump(k) .. "]=" .. Dump(v) end
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif type(value) == "string" then
		return ("%q"):format(value)
	end
	return tostring(value)
end

if not phase then
	local failed = false
	for _, eachToc in ipairs(TOCS) do
		for _, eachClient in ipairs({ "forever", "retail" }) do
			local file = os.tmpname()
			for _, eachPhase in ipairs({ "on", "off", "back" }) do
				local pipe = io.popen(("%s Tools/offline/modules.lua %s %s %s %s 2>&1"):format(LUA, eachPhase,
					eachClient, eachToc, file))
				local out = pipe:read("*a")
				pipe:close()
				io.write(out)
				if not out:find("modules " .. eachPhase .. " " .. eachClient .. " " .. eachToc .. ": ok", 1, true) then
					failed = true
				end
			end
			os.remove(file)
		end
	end
	print(failed and "modules: FAILED" or "modules: all ok")
	os.exit(failed and 1 or 0)
end

local problems = {}
local function Problem(text) problems[#problems + 1] = text end

-- What Visions files make: frames, hooks and timers, by the file that asked.
local fromVisions = {}
-- (Every Vision's code: Visions/, and in Atmosphere/ and Dev/ the ones there.)
local VISION_FILES = { "@Visions/", "Atmosphere/LowHealth", "Atmosphere/VitalsSound.lua", "Atmosphere/TeleportVision.lua",
	"Atmosphere/DeathVision.lua", "Dev/WindGuide.lua" }
local errors = {}
local function Caller()
	for level = 3, 12 do
		local info = debug.getinfo(level, "S")
		if not info then return nil end
		local source = info.source or ""
		for _, file in ipairs(VISION_FILES) do
			if source:find(file, 1, true) then return source end
		end
	end
end
-- (Off: from the on run's saved settings, as a player switching it off has
-- them: its once-only updates done, its defaults kept.)
local db
if phase == "off" or phase == "back" then
	db = (assert(loadfile(tmp))()) -- (back: the off run's, Visions switched on again)
end

local ns, wow = dofile("Tools/offline/load.lua")(client, toc, function(stand)
	rawset(_G, "CinematicDB", db)
	rawset(_G, "geterrorhandler", function()
		return function(err) errors[#errors + 1] = tostring(err) end
	end)
	local make = _G.CreateFrame
	rawset(_G, "CreateFrame", function(...)
		local source = Caller()
		if source then fromVisions[#fromVisions + 1] = "frame from " .. source end
		return make(...)
	end)
	rawset(_G, "hooksecurefunc", function()
		local source = Caller()
		if source then fromVisions[#fromVisions + 1] = "hook from " .. source end
	end)
	local after = stand.Stub
	rawset(_G, "C_Timer", { After = function()
		local source = Caller()
		if source then fromVisions[#fromVisions + 1] = "timer from " .. source end
	end, NewTicker = function() return after end, NewTimer = function() return after end })
end)

for _, w in ipairs(wow.warnings) do Problem("load: " .. w) end
for _, e in ipairs(errors) do Problem("error: " .. e) end
-- (A once-only settings update reading Visions code must wait for it: Migrations.lua.)
for _, e in ipairs(ns.migrationErrors or {}) do Problem("settings update: " .. e) end

-- Every frame's events and update, once each (stub arguments). A call that
-- runs on and on (a loop waiting on the stand-in's clock, which never moves)
-- is cut off after a while, an error of its own.
local RUNAWAY = "ran too long"
local function Once(fn, ...)
	debug.sethook(function() error(RUNAWAY) end, "", 2000000)
	local ok, err = pcall(fn, ...)
	debug.sethook()
	return ok, err
end
local function Storm()
	local seen = {}
	local list = {}
	for _, frame in ipairs(wow.frames) do list[#list + 1] = frame end
	for _, frame in ipairs(list) do
		local onEvent = frame._scripts and frame._scripts.OnEvent
		if onEvent then
			local events = {}
			for event in pairs(frame._events or {}) do events[#events + 1] = event end
			table.sort(events)
			for _, event in ipairs(events) do
				local ok, err = Once(onEvent, frame, event)
				if not ok then seen[tostring(err)] = true end
			end
		end
		local onUpdate = frame._scripts and frame._scripts.OnUpdate
		if onUpdate then
			local ok, err = Once(onUpdate, frame, 0.1)
			if not ok then seen[tostring(err)] = true end
		end
	end
	return seen
end

-- Every tab of the Why window (/cine why) filled once: errors by message.
local function WhyTabs()
	local seen, ids = {}, {}
	for _, provider in ipairs(ns.WhyProviders and ns.WhyProviders() or {}) do
		ids[provider.id] = true
		local ok, err = pcall(provider.fn)
		if not ok then seen[tostring(err)] = true end
	end
	return seen, ids
end

-- The Why window's Visions and Atmosphere tabs: Atmosphere a tab of its own
-- with its pages' rows either way, the Visions tab holding Visions only.
local function WhyVisionTabs(visionsOn)
	local tabs, ids = {}, {}
	for _, provider in ipairs(ns.WhyProviders and ns.WhyProviders() or {}) do
		local ok, sections = pcall(provider.fn)
		tabs[provider.id] = ok and type(sections) == "table" and sections or false
		if not provider.into then ids[#ids + 1] = provider.id end
	end
	local atmo = tabs.atmosphere
	if not atmo then
		Problem("no Atmosphere tab in the Why window")
	elseif #atmo ~= 1 or #(atmo[1].rows or {}) == 0 then
		Problem(("the Why window's Atmosphere tab: %d sections, %d rows"):format(#atmo, #(atmo[1] and atmo[1].rows or {})))
	end
	local vis = tabs.visions
	if not vis then
		Problem("no Visions tab in the Why window")
	elseif #vis ~= 1 then
		Problem(("the Why window's Visions tab has %d sections, not just Visions"):format(#vis))
	elseif visionsOn and #(vis[1].rows or {}) < 2 then
		Problem("the Why window's Visions tab lists no Visions")
	end
	local order = table.concat(ids, " ")
	local want = "cameras cards visions atmosphere addons"
	if order ~= want then Problem(("the Why window's tabs go %s, not %s"):format(order, want)) end
end

local visionsPages = { "Heal Vision", "Damage Vision", "Quest Vision", "Roll Vision", "Duel Vision",
	"Emote Vision", "Card Vision", "Card Styles", "Damage Vision Look", "Quest Talk Style", "Quest Item Style",
	"Roll Style", "Visions Style", "Vitals Vision", "Death Vision", "Teleport Vision", "Vitals Style" }
local keptPages = { "Visions General" }
local canvases = ns.settingsCanvases or {}

if phase == "on" then
	if not ns.ModuleLoaded("visions") then Problem("Visions didn't load") end
	if #fromVisions == 0 then Problem("no frames from Visions files: the check can't see them") end
	-- (Not written down while it's on: only as it's switched off, below.)
	if CinematicDB.moduleDefaults then Problem("Visions defaults saved while it's on") end
	WhyVisionTabs(true)
	for _, name in ipairs(visionsPages) do
		if not canvases[name] then Problem("page missing with Visions on: " .. name) end
	end
	local keys = {}
	for k in pairs(ns.DEFAULTS) do keys[#keys + 1] = k end
	-- One of its settings changed (Sleeping bag's card off), then switched
	-- off, as Visions General's Load Visions does (then a /reload: the off run).
	ns.db.cardSleepBagOn = false
	-- (The page's box itself, unticked and clicked: its popup asks to reload.)
	local box
	local function Walk(frame)
		for _, child in ipairs(rawget(frame, "_children") or {}) do
			for _, region in ipairs(rawget(child, "_regions") or {}) do
				if rawget(region, "_text") == "Load Visions" and child._kind == "CheckButton" then box = child end
			end
			Walk(child)
		end
	end
	if canvases["Visions General"] then Walk(canvases["Visions General"]) end
	local asked
	rawset(_G, "StaticPopup_Show", function(which, text) asked = which .. ": " .. tostring(text) end)
	if not box then
		Problem("no Load Visions box on Visions General")
		ns.SetModuleWanted("visions", false)
	else
		box:SetChecked(false)
		box._scripts.OnClick(box)
		if not (asked and asked:find("leave Visions out", 1, true)) then
			Problem("unticking Load Visions didn't ask to reload: " .. tostring(asked))
		end
	end
	local kept = CinematicDB.moduleDefaults and CinematicDB.moduleDefaults.visions
	if type(kept) ~= "table" or kept.cardSleepBagOn == nil then Problem("no Visions defaults kept as it's switched off") end
	if CinematicDB.loadVisions ~= false then Problem("Load Visions didn't save as off") end
	local saved = Dump(CinematicDB) -- (before the storm changes anything)
	local storm = Storm()
	for err in pairs((WhyTabs())) do storm[err] = true end
	local file = assert(io.open(tmp, "w"))
	file:write("return ", saved, ", ", Dump(keys), ", ", Dump(storm), "\n")
	file:close()
elseif phase == "off" then
	local _, onKeys, onStorm = assert(loadfile(tmp))()
	-- (Its setting kept, and in the profile as it's saved.)
	if ns.db.cardSleepBagOn ~= false then Problem("a Vision's setting lost with Visions off") end
	local settings = ns.ProfileSettings and ns.ProfileSettings(ns.ActiveProfile())
	if not settings or settings.cardSleepBagOn ~= false then Problem("a Vision's setting not in the profile with Visions off") end
	if ns.ModuleLoaded("visions") then Problem("Visions loaded while off") end
	-- (Its one frame loaded either way: the ambience volume put back after a
	-- cue cut short, Vitals Vision plays through it.)
	for _, line in ipairs(fromVisions) do
		if not line:find("frame from @Visions/CombatSoundRules.lua", 1, true) then
			Problem("made with Visions off: " .. line)
		end
	end
	local missing = 0
	for _, k in ipairs(onKeys) do
		if ns.DEFAULTS[k] == nil then
			missing = missing + 1
			if missing <= 5 then Problem("default missing with Visions off: " .. k) end
		end
	end
	if missing > 5 then Problem(("...%d defaults missing in all"):format(missing)) end
	for _, name in ipairs(visionsPages) do
		if canvases[name] then Problem("page still there with Visions off: " .. name) end
	end
	for _, name in ipairs(keptPages) do
		if not canvases[name] then Problem("page gone with Visions off: " .. name) end
	end
	for _, vision in ipairs(ns.VISION_LIST or {}) do
		Problem("vision wheel still has " .. vision.key)
	end
	for _, choice in ipairs(ns.MASTER_WHEEL_CHOICES or {}) do
		if choice.key == "vision" then Problem("the master wheel still has the Vision wheel") end
	end
	for _, key in ipairs({ "vitals", "tele", "emote", "deathVision", "cards" }) do
		if ns.ShowMeAvailable and ns.ShowMeAvailable(key) then Problem("the Welcome window still offers " .. key) end
	end
	-- Back on (then a /reload: the back run).
	ns.SetModuleWanted("visions", true)
	local saved = Dump(CinematicDB)
	for err in pairs(Storm()) do
		if not onStorm[err] then Problem("event error with Visions off: " .. err) end
	end
	local whyErrors, whyTabs = WhyTabs()
	for err in pairs(whyErrors) do
		if not onStorm[err] then Problem("Why window error with Visions off: " .. err) end
	end
	-- (Its Cards tab kept, one row saying Visions aren't loaded.)
	if not whyTabs.cards then Problem("the Why window's Cards tab gone with Visions off") end
	for _, provider in ipairs(ns.WhyProviders()) do
		if provider.id == "cards" then
			local ok, sections = pcall(provider.fn)
			local row = ok and sections and sections[1] and sections[1].rows and sections[1].rows[1]
			if not (row and row.key == "cards:loaded" and row.status == "off" and #sections == 1) then
				Problem("the Why window's Cards tab doesn't say Visions aren't loaded")
			end
		end
	end
	-- (Its Visions tab: a Visions section saying they aren't loaded, not none.)
	for _, provider in ipairs(ns.WhyProviders()) do
		if provider.id == "visions" then
			local ok, sections = pcall(provider.fn)
			local first = ok and sections and sections[1]
			local row = first and first.rows and first.rows[1]
			if not (row and row.key == "visions:loaded" and row.status == "off") then
				Problem("the Why window's Visions tab doesn't say Visions aren't loaded")
			end
		end
	end
	WhyVisionTabs(false)
	-- A command into its code (Damage Vision's report): a line saying so, no error.
	local said
	local print0 = ns.Print
	ns.Print = function(text) said = tostring(text) end
	local ok, err = pcall(ns.HandleSlash, "report")
	ns.Print = print0
	if not ok then Problem("/cine report errored with Visions off: " .. tostring(err)) end
	if not (said and said:find("needs Visions", 1, true)) then
		Problem("/cine report with Visions off didn't say Visions isn't loaded: " .. tostring(said))
	end
	local file = assert(io.open(tmp, "w"))
	file:write("return ", saved, "\n")
	file:close()
else
	-- Back on: its code runs, the setting changed before is as it was, the
	-- copy of its defaults gone from the saved settings.
	if not ns.ModuleLoaded("visions") then Problem("Visions didn't load again") end
	if ns.db.cardSleepBagOn ~= false then Problem("a Vision's setting lost after Visions off and on") end
	if CinematicDB.moduleDefaults ~= nil then Problem("the copy of Visions' defaults stayed once it's loaded") end
	for _, name in ipairs(visionsPages) do
		if not canvases[name] then Problem("page missing with Visions back on: " .. name) end
	end
end

for _, text in ipairs(problems) do print(("modules %s %s %s: %s"):format(phase, client, toc, text)) end
if #problems == 0 then print(("modules %s %s %s: ok"):format(phase, client, toc)) end
