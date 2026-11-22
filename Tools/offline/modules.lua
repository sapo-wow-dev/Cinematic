-- A part left out (Modules.lua: Visions General's Load Visions, Camera >
-- General's Load Cameras): its code never runs, the rest of the addon works
-- without it, and its settings stay. Each part (and both together) on each
-- client and copy: on, then off from the settings the on run left, as a player
-- switching it off has them (its defaults in CinematicDB.moduleDefaults),
-- then back on. Each a run of its own (nothing kept between).
--
--   On:   no errors; its code ran; its pages there; a setting of its changed,
--         then its page's Load box unticked (asks to reload); every frame's
--         events and update and every Why tab once, the errors that gives
--         noted (the stand-in's stubs make some of their own).
--   Off:  no errors; no frame, hook or timer made by its files; the same
--         DEFAULTS keys as on (profiles, sharing and Reset carry them); the
--         setting kept, in the profile too; its pages gone but its General;
--         its wheel, demos and Why tab rows as left out; a command into its
--         code says so; every event, update and Why tab with no error on
--         didn't have.
--   Back: loaded again, the setting as changed, the copy of its defaults gone.
--
--   python -I Tools/offline/run.py Tools/offline/modules.lua
-- Exit 1 on any problem.
local LUA = os.getenv("CINE_LUA") or "lua5.1"
local phase, client, toc, tmp, partArg = ...
local TOCS = { "Cinematic.toc", "CinematicDev.toc" }

-- Each part: its files, pages, Load box and what shows it's left out.
local SPECS = {
	visions = {
		label = "Visions",
		-- (Every Vision's code: Visions/, and in Atmosphere/ and Dev/ the ones there.)
		files = { "@Visions/", "Atmosphere/LowHealth", "Atmosphere/VitalsSound.lua", "Atmosphere/TeleportVision.lua",
			"Atmosphere/DeathVision.lua", "Dev/WindGuide.lua" },
		-- (Its one frame loaded either way: the ambience volume put back after a
		-- cue cut short.)
		allowed = { "frame from @Visions/CombatSoundRules.lua" },
		pages = { "Heal Vision", "Damage Vision", "Quest Vision", "Roll Vision", "Duel Vision", "Emote Vision",
			"Card Vision", "Card Styles", "Damage Vision Look", "Quest Talk Style", "Quest Item Style", "Roll Style",
			"Visions Style", "Vitals Vision", "Death Vision", "Teleport Vision", "Vitals Style" },
		general = "Visions General", box = "Load Visions", ask = "leave Visions out",
		setting = { "cardSleepBagOn", false },
		why = { tab = "visions", row = "visions:loaded" },
		demos = { "vitals", "tele", "emote", "deathVision", "cards" },
		master = "vision",
		slash = { "report", "you've left out" },
	},
	cameras = {
		label = "Cameras",
		files = { "@Camera/" },
		allowed = {},
		pages = { "Scenes", "Triggers", "Trigger Priority", "Trigger Log", "Trigger Settings", "Camera Scripts",
			"My Shots", "Shoulder Cam", "Skyriding Cam", "Camera Settings" },
		general = "Cameras", box = "Load Cameras", ask = "leave the cameras out",
		setting = { "walkCine", true },
		why = { tab = "cameras", row = "cameras:loaded" },
		demos = { "camera", "cameraLook", "shoulder", "afk", "flight" },
		master = "camera",
		slash = { "flyby", "Cameras aren't loaded" },
	},
}
local ORDER = { "visions", "cameras", "both" }

-- Values as Lua source (the settings handed from one run to the next).
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

-- A global a part's file defines (a key binding's Cinematic_...), read by
-- another file as it loads: that file now gets nothing (the part's code runs
-- later), with the part loaded too. (MarkerWheel.lua wrapped
-- Cinematic_CameraWheel so, 2026-11-22: lost with Cameras on, an error off.)
local function GlobalsReadAtLoad()
	local bad = {}
	local files, gated = {}, {}
	for line in io.lines("CinematicDev.toc") do
		line = line:gsub("\r", "")
		if line:find("%.lua$") and not line:find("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
	end
	local text = {}
	for _, path in ipairs(files) do
		local f = io.open(path, "r")
		if f then
			text[path] = f:read("*a")
			f:close()
			if text[path]:find('ns.Module("', 1, true) then gated[path] = true end
		end
	end
	local globals = {}
	for path in pairs(gated) do
		for name in text[path]:gmatch("\n%s*function (Cinematic_[%w_]+)%s*%(") do globals[name] = path end
		for name in text[path]:gmatch("\n%s*(Cinematic_[%w_]+)%s*=[^=]") do globals[name] = path end
	end
	for _, path in ipairs(files) do
		if text[path] and not gated[path] then
			local n = 0
			for line in (text[path] .. "\n"):gmatch("([^\n]*)\n") do
				n = n + 1
				if not line:find("^%s") and not line:find("^%-%-") then
					for name, from in pairs(globals) do
						if line:find(name, 1, true) then
							bad[#bad + 1] = ("%s:%d reads %s (%s's) as it loads"):format(path, n, name, from)
						end
					end
				end
			end
		end
	end
	return bad
end

if not phase then
	local failed = false
	for _, line in ipairs(GlobalsReadAtLoad()) do
		print("modules: " .. line)
		failed = true
	end
	for _, part in ipairs(ORDER) do
		for _, eachToc in ipairs(TOCS) do
			for _, eachClient in ipairs({ "forever", "retail" }) do
				local file = os.tmpname()
				for _, eachPhase in ipairs({ "on", "off", "back" }) do
					local pipe = io.popen(("%s Tools/offline/modules.lua %s %s %s %s %s 2>&1"):format(LUA, eachPhase,
						eachClient, eachToc, file, part))
					local out = pipe:read("*a")
					pipe:close()
					io.write(out)
					if not out:find(("modules %s %s %s %s: ok"):format(part, eachPhase, eachClient, eachToc), 1, true) then
						failed = true
					end
				end
				os.remove(file)
			end
		end
	end
	print(failed and "modules: FAILED" or "modules: all ok")
	os.exit(failed and 1 or 0)
end

local parts = partArg == "both" and { "visions", "cameras" } or { partArg }

local problems = {}
local function Problem(text) problems[#problems + 1] = text end

-- What a part's files make: frames, hooks and timers, by the file that asked.
local made = {}
local errors = {}
local function Caller()
	for level = 3, 12 do
		local info = debug.getinfo(level, "S")
		if not info then return nil end
		local source = info.source or ""
		for _, part in ipairs(parts) do
			for _, file in ipairs(SPECS[part].files) do
				if source:find(file, 1, true) then return source end
			end
		end
	end
end
-- (Off and back: from the last run's saved settings.)
local db
if phase == "off" or phase == "back" then
	db = (assert(loadfile(tmp))())
end

local ns, wow = dofile("Tools/offline/load.lua")(client, toc, function(stand)
	rawset(_G, "CinematicDB", db)
	rawset(_G, "geterrorhandler", function()
		return function(err) errors[#errors + 1] = tostring(err) end
	end)
	local make = _G.CreateFrame
	rawset(_G, "CreateFrame", function(...)
		local source = Caller()
		if source then made[#made + 1] = "frame from " .. source end
		return make(...)
	end)
	rawset(_G, "hooksecurefunc", function()
		local source = Caller()
		if source then made[#made + 1] = "hook from " .. source end
	end)
	local after = stand.Stub
	rawset(_G, "C_Timer", { After = function()
		local source = Caller()
		if source then made[#made + 1] = "timer from " .. source end
	end, NewTicker = function() return after end, NewTimer = function() return after end })
end)

for _, w in ipairs(wow.warnings) do Problem("load: " .. w) end
for _, e in ipairs(errors) do Problem("error: " .. e) end
-- (A once-only settings update reading a part's code must wait for it: Migrations.lua.)
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

-- Every tab of the Why window (/cine why) filled once: errors by message,
-- and each tab's sections.
local function WhyTabs()
	local seen, tabs = {}, {}
	for _, provider in ipairs(ns.WhyProviders and ns.WhyProviders() or {}) do
		local ok, sections = pcall(provider.fn)
		if not ok then seen[tostring(sections)] = true end
		tabs[provider.id] = ok and type(sections) == "table" and sections or false
	end
	return seen, tabs
end

-- The Why window's Visions and Atmosphere tabs: Atmosphere a tab of its own
-- with its pages' rows either way, the Visions tab holding Visions only.
local function WhyVisionTabs(visionsOn)
	local _, tabs = WhyTabs()
	local ids = {}
	for _, provider in ipairs(ns.WhyProviders and ns.WhyProviders() or {}) do
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

-- A part's General page's Load box, found by its label.
local canvases = ns.settingsCanvases or {}
local function Box(spec)
	local box
	local function Walk(frame)
		for _, child in ipairs(rawget(frame, "_children") or {}) do
			for _, region in ipairs(rawget(child, "_regions") or {}) do
				if rawget(region, "_text") == spec.box and child._kind == "CheckButton" then box = child end
			end
			Walk(child)
		end
	end
	if canvases[spec.general] then Walk(canvases[spec.general]) end
	return box
end

if phase == "on" then
	local keys = {}
	for k in pairs(ns.DEFAULTS) do keys[#keys + 1] = k end
	if partArg == "visions" then WhyVisionTabs(true) end
	local asked
	rawset(_G, "StaticPopup_Show", function(which, text) asked = which .. ": " .. tostring(text) end)
	-- (Not written down while they're on: only as each is switched off, below.)
	if CinematicDB.moduleDefaults then Problem("defaults saved while the parts are on") end
	for _, part in ipairs(parts) do
		local spec = SPECS[part]
		if not ns.ModuleLoaded(part) then Problem(spec.label .. " didn't load") end
		local found = 0
		for _, name in ipairs(spec.pages) do
			if canvases[name] then found = found + 1 end
		end
		if found < 3 then Problem(("only %d of %s' pages there with it on"):format(found, spec.label)) end
		-- One of its settings changed, then its page's box unticked (then a
		-- /reload: the off run).
		ns.db[spec.setting[1]] = spec.setting[2]
		local box = Box(spec)
		if not box then
			Problem(("no %s box on %s"):format(spec.box, spec.general))
			ns.SetModuleWanted(part, false)
		else
			box:SetChecked(false)
			box._scripts.OnClick(box)
			if not (asked and asked:find(spec.ask, 1, true)) then
				Problem(("unticking %s didn't ask to reload: %s"):format(spec.box, tostring(asked)))
			end
		end
		local kept = CinematicDB.moduleDefaults and CinematicDB.moduleDefaults[part]
		if type(kept) ~= "table" or kept[spec.setting[1]] == nil then
			Problem(("no %s defaults kept as it's switched off"):format(spec.label))
		end
		if CinematicDB[ns.MODULE_KEYS[part]] ~= false then Problem(spec.box .. " didn't save as off") end
	end
	if #made == 0 then Problem("no frames from the part's files: the check can't see them") end
	local saved = Dump(CinematicDB) -- (before the storm changes anything)
	local storm = Storm()
	for err in pairs((WhyTabs())) do storm[err] = true end
	local file = assert(io.open(tmp, "w"))
	file:write("return ", saved, ", ", Dump(keys), ", ", Dump(storm), "\n")
	file:close()
elseif phase == "off" then
	local _, onKeys, onStorm = assert(loadfile(tmp))()
	local allowed = {}
	for _, part in ipairs(parts) do
		for _, line in ipairs(SPECS[part].allowed) do allowed[#allowed + 1] = line end
	end
	for _, line in ipairs(made) do
		local ok = false
		for _, each in ipairs(allowed) do
			if line:find(each, 1, true) then ok = true end
		end
		if not ok then Problem("made while left out: " .. line) end
	end
	local missing = 0
	for _, k in ipairs(onKeys) do
		if ns.DEFAULTS[k] == nil then
			missing = missing + 1
			if missing <= 5 then Problem("default missing while left out: " .. k) end
		end
	end
	if missing > 5 then Problem(("...%d defaults missing in all"):format(missing)) end
	local _, whyTabs = WhyTabs()
	local settings = ns.ProfileSettings and ns.ProfileSettings(ns.ActiveProfile())
	for _, part in ipairs(parts) do
		local spec = SPECS[part]
		local key, value = spec.setting[1], spec.setting[2]
		if ns.db[key] ~= value then Problem(("%s' setting %s lost while left out"):format(spec.label, key)) end
		if not settings or settings[key] ~= value then Problem(("%s' setting %s not in the profile"):format(spec.label, key)) end
		if ns.ModuleLoaded(part) then Problem(spec.label .. " loaded while off") end
		for _, name in ipairs(spec.pages) do
			if canvases[name] then Problem(("%s page still there while left out: %s"):format(spec.label, name)) end
		end
		if not canvases[spec.general] then Problem(spec.general .. " gone while left out") end
		if not Box(spec) then Problem(("no %s box on %s while left out"):format(spec.box, spec.general)) end
		for _, choice in ipairs(ns.MASTER_WHEEL_CHOICES or {}) do
			if choice.key == spec.master then Problem("the master wheel still has the " .. spec.master .. " wheel") end
		end
		for _, demo in ipairs(spec.demos) do
			if ns.ShowMeAvailable and ns.ShowMeAvailable(demo) then Problem("the Welcome window still offers " .. demo) end
		end
		-- (Its Why tab: one row saying it isn't loaded.)
		local tab = whyTabs[spec.why.tab]
		local row = tab and tab[1] and tab[1].rows and tab[1].rows[1]
		if not (row and row.key == spec.why.row and row.status == "off") then
			Problem(("the Why window's %s tab doesn't say %s aren't loaded"):format(spec.why.tab, spec.label))
		end
		-- A command into its code: a line saying so, no error.
		local said
		local print0 = ns.Print
		ns.Print = function(text) said = tostring(text) end
		local ok, err = pcall(ns.HandleSlash, spec.slash[1])
		ns.Print = print0
		if not ok then Problem(("/cine %s errored while left out: %s"):format(spec.slash[1], tostring(err))) end
		if not (said and said:find(spec.slash[2], 1, true)) then
			Problem(("/cine %s while left out didn't say so: %s"):format(spec.slash[1], tostring(said)))
		end
	end
	if partArg == "visions" then
		for _, vision in ipairs(ns.VISION_LIST or {}) do Problem("vision wheel still has " .. vision.key) end
		-- (Its Cards tab kept, one row saying Visions aren't loaded.)
		local cards = whyTabs.cards
		local row = cards and cards[1] and cards[1].rows and cards[1].rows[1]
		if not (row and row.key == "cards:loaded" and row.status == "off" and #cards == 1) then
			Problem("the Why window's Cards tab doesn't say Visions aren't loaded")
		end
		WhyVisionTabs(false)
	end
	-- Back on (then a /reload: the back run).
	for _, part in ipairs(parts) do ns.SetModuleWanted(part, true) end
	local saved = Dump(CinematicDB)
	for err in pairs(Storm()) do
		if not onStorm[err] then Problem("event error while left out: " .. err) end
	end
	for err in pairs((WhyTabs())) do
		if not onStorm[err] then Problem("Why window error while left out: " .. err) end
	end
	local file = assert(io.open(tmp, "w"))
	file:write("return ", saved, "\n")
	file:close()
else
	-- Back on: its code runs, the setting changed before is as it was, the
	-- copy of its defaults gone from the saved settings.
	for _, part in ipairs(parts) do
		local spec = SPECS[part]
		if not ns.ModuleLoaded(part) then Problem(spec.label .. " didn't load again") end
		if ns.db[spec.setting[1]] ~= spec.setting[2] then Problem(spec.label .. "' setting lost after off and on") end
		local found = 0
		for _, name in ipairs(spec.pages) do
			if canvases[name] then found = found + 1 end
		end
		if found < 3 then Problem(("only %d of %s' pages back"):format(found, spec.label)) end
	end
	if CinematicDB.moduleDefaults ~= nil then Problem("the copy of the defaults stayed once loaded") end
end

local tag = ("modules %s %s %s %s"):format(partArg, phase, client, toc)
for _, text in ipairs(problems) do print(tag .. ": " .. text) end
if #problems == 0 then print(tag .. ": ok") end
