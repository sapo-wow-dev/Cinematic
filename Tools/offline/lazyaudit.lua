-- What making a settings page on first open would break (Tools/lazy-pages-plan.md, phase 0), on the stand-in.
--
-- 1. Per piece of the login page build (Options.lua's laps, ns.settingsLapHook) and per page already made on
--    first open (Options.lua's lazyPages): what it puts in ns and _G, the named frames it makes, and the work
--    it starts that runs during play (events, OnUpdate, hooks, timers). With each new ns key: the files
--    that read it, other than the one that set it. A key read elsewhere is what a page made later would
--    leave missing.
-- 2. With the pages made on first open still unbuilt: every frame's events and update, every Why tab and a
--    settings Refresh, once each; then the pages made and the same again. An error only while unbuilt, or an
--    ns key read while missing that a page's build then sets, is a problem.
--
--   python -I Tools/offline/run.py Tools/offline/lazyaudit.lua [forever|retail] [piece name ...]
-- With names, part 1 prints just those pieces (a lap name such as CreateExtrasPanel, or a lazy page's name).
-- Exit 1 on any part 2 problem.
-- luacheck: push ignore 111 112 113 121 122 212 431
local client = ... or "forever"
local only, write = {}, false
for i = 2, select("#", ...) do
	local each = select(i, ...)
	if each == "--write" then write = true else only[each] = true end
end
package.path = "Tools/offline/?.lua;" .. package.path
local wow = dofile("Tools/offline/wow.lua")
wow.Install(client)
local toc = "Cinematic.toc"
local addonName = "Cinematic"
local ns = {}

-- Where the code that called us lives (the first file outside the stand-in and this tool).
local function Caller()
	for level = 3, 12 do
		local info = debug.getinfo(level, "S")
		if not info then break end
		local src = info.source or ""
		if not src:find("Tools/offline", 1, true) and src:sub(1, 1) == "@" then
			return (src:sub(2):gsub("\\", "/"))
		end
	end
	return "?"
end

-- The piece being made now, and what each piece made.
local current = "(files, before the build)"
local pieces, order = {}, {}
local function Piece(name)
	if not pieces[name] then
		pieces[name] = { ns = {}, globals = {}, defaults = {}, named = {}, events = {}, updates = 0, hooks = {}, timers = 0,
			onUpdates = 0, firstFrame = #wow.frames + 1 }
		order[#order + 1] = name
	end
	return pieces[name]
end
local recording = false

for line in io.lines(toc) do
	line = line:gsub("\r", "")
	if line ~= "" and not line:find("^#") then
		local chunk, err = loadfile((line:gsub("\\", "/")))
		if not chunk and not err:find("cannot open") then error(err) end
		if chunk then pcall(chunk, addonName, ns) end
	end
end

-- ns: new keys set (and by which file), and reads of missing keys (for part 2).
local defined = {} -- key -> { piece, file }
local misses = {} -- key -> { file = true }
local missing = false -- (part 2 on: reads of missing keys noted)
setmetatable(ns, {
	__newindex = function(t, k, v)
		if recording and type(k) == "string" then
			local p = Piece(current)
			local file = Caller()
			p.ns[k] = file
			defined[k] = defined[k] or { piece = current, file = file }
		end
		rawset(t, k, v)
	end,
	__index = function(_, k)
		if missing and type(k) == "string" then
			misses[k] = misses[k] or {}
			misses[k][Caller()] = true
		end
		return nil
	end,
})
-- (LazyPageDefaults.lua put the pages' own defaults in already: taken out again here, so their builds
-- make them as they would without it, and the list can be checked against what they make.)
local listed = (ns.LAZY_PAGE_DEFAULTS or {})[client] or {}
for key in pairs(listed) do rawset(ns.DEFAULTS, key, nil) end
-- ns.DEFAULTS: new keys (a setting's default made by a page's build: missing from profiles and Reset till then).
do
	local defaults = rawget(ns, "DEFAULTS")
	if type(defaults) == "table" and getmetatable(defaults) == nil then
		setmetatable(defaults, { __newindex = function(t, k, v)
			if recording then
				local p = Piece(current)
				p.defaults[k] = Caller()
				p.defaultValues = p.defaultValues or {}
				p.defaultValues[k] = v
			end
			rawset(t, k, v)
		end })
	end
end
-- _G: new globals.
local gmeta = getmetatable(_G)
local gIndex = gmeta and gmeta.__index
setmetatable(_G, {
	__index = gIndex,
	__newindex = function(t, k, v)
		if recording and type(k) == "string" then Piece(current).globals[k] = Caller() end
		rawset(t, k, v)
	end,
})
-- Calls that start work for later.
local function Wrap(holder, key, note)
	local fn = holder[key]
	if type(fn) ~= "function" then return end
	holder[key] = function(...)
		if recording then note(Piece(current), ...) end
		return fn(...)
	end
end
-- (Hooks on game functions and on frames not the piece's own: a hook on its own control is just the page.)
Wrap(_G, "hooksecurefunc", function(p, a, b)
	if type(a) == "string" then
		p.hooks[#p.hooks + 1] = a
	elseif type(a) == "table" then
		p.tableHooks = p.tableHooks or {}
		p.tableHooks[#p.tableHooks + 1] = { a, tostring(b) }
	end
end)
if type(C_Timer) == "table" then
	Wrap(C_Timer, "NewTicker", function(p) p.timers = p.timers + 1 end)
	Wrap(C_Timer, "After", function(p) p.timers = p.timers + 1 end)
	Wrap(C_Timer, "NewTimer", function(p) p.timers = p.timers + 1 end)
end
Wrap(ns, "SetOnUpdate", function(p, _, fn) if fn then p.onUpdates = p.onUpdates + 1 end end)
Wrap(ns, "HookOnUpdate", function(p) p.onUpdates = p.onUpdates + 1 end)

-- The login build, piece by piece.
ns.settingsLapHook = function(name)
	if name == false then -- (the build starts: what came before isn't the pages')
		pieces, order, defined = {}, {}, {}
		current = "(start of the build)"
		Piece(current)
		return
	end
	local p = Piece(current)
	p.lastFrame = #wow.frames
	pieces[name] = p
	for i, each in ipairs(order) do
		if each == current then order[i] = name end
	end
	pieces[current] = nil
	current = "(between pieces)"
	Piece(current).firstFrame = #wow.frames + 1
end
recording = true
current = "(start of the build)"
Piece(current)
wow.Fire("ADDON_LOADED", addonName)
recording = false
pieces[current] = nil
for i = #order, 1, -1 do if order[i] == current then table.remove(order, i) end end
wow.Fire("PLAYER_LOGIN")

-- Frames made by a piece: names, events, scripts.
local function FramesOf(p, first, last)
	for i = first or 1, last or 0 do
		local frame = wow.frames[i]
		if frame then
			local name = rawget(frame, "_name")
			if type(name) == "string" and name ~= "" then p.named[#p.named + 1] = name end
			for event in pairs(rawget(frame, "_events") or {}) do p.events[event] = true end
			local scripts = rawget(frame, "_scripts") or {}
			if scripts.OnUpdate then p.updates = p.updates + 1 end
		end
	end
end
-- Table hooks: kept only on frames made before the piece (another page's or the game's).
local frameIndex = {}
for i, frame in ipairs(wow.frames) do frameIndex[frame] = i end
local function OwnHooks(p)
	for _, hook in ipairs(p.tableHooks or {}) do
		local at = frameIndex[hook[1]]
		local own = at and at >= (p.firstFrame or 1)
		local region = not at and rawget(hook[1], "_parent") ~= nil -- (a texture or text of the page's)
		if not own and not region then
			local name = rawget(hook[1], "_name") or (at and "frame #" .. at) or tostring(hook[1])
			p.hooks[#p.hooks + 1] = tostring(name) .. ":" .. hook[2]
		end
	end
	p.tableHooks = nil
end
for _, name in ipairs(order) do
	local p = pieces[name]
	FramesOf(p, p.firstFrame, p.lastFrame)
	OwnHooks(p)
end

-- Part 2, unbuilt: events, updates, Why tabs, Refresh.
local RUNAWAY = "ran too long"
local function Once(fn, ...)
	debug.sethook(function() error(RUNAWAY) end, "", 2000000)
	local ok, err = pcall(fn, ...)
	debug.sethook()
	return ok, err
end
local function Everything()
	local seen = {}
	local list = {}
	for _, frame in ipairs(wow.frames) do list[#list + 1] = frame end
	for _, frame in ipairs(list) do
		local scripts = rawget(frame, "_scripts") or {}
		if scripts.OnEvent then
			local events = {}
			for event in pairs(rawget(frame, "_events") or {}) do events[#events + 1] = event end
			table.sort(events)
			for _, event in ipairs(events) do
				local ok, err = Once(scripts.OnEvent, frame, event)
				if not ok then seen[tostring(err)] = true end
			end
		end
		if scripts.OnUpdate then
			local ok, err = Once(scripts.OnUpdate, frame, 0.1)
			if not ok then seen[tostring(err)] = true end
		end
	end
	for _, provider in ipairs(ns.WhyProviders and ns.WhyProviders() or {}) do
		local ok, err = Once(provider.fn)
		if not ok then seen[tostring(err)] = true end
	end
	if ns.RefreshOptions then
		local ok, err = Once(ns.RefreshOptions)
		if not ok then seen[tostring(err)] = true end
	end
	return seen
end
local waiting = {}
for _, entry in ipairs(ns.lazySettingsPages or {}) do
	if not entry.made then waiting[#waiting + 1] = entry end
end
missing = true
local unbuilt = Everything()
missing = false
-- The waiting pages made, each its own piece.
recording = true
for _, entry in ipairs(waiting) do
	current = "lazy: " .. tostring(entry.name)
	local p = Piece(current)
	p.firstFrame = #wow.frames + 1
	entry.Make("lazyaudit")
	p.lastFrame = #wow.frames
	for i = p.firstFrame, p.lastFrame do frameIndex[wow.frames[i]] = i end
	FramesOf(p, p.firstFrame, p.lastFrame)
	OwnHooks(p)
end
recording = false
local built = Everything()

-- Who reads each key: files (outside Tools/) that name ns.<key>.
local files = {}
do
	local pipe = io.popen("git ls-files \"*.lua\"")
	for path in pipe:lines() do
		if not path:find("^Tools/") and not path:find("^Locales/") then
			local f = io.open(path, "rb")
			if f then
				files[#files + 1] = { path = path, text = f:read("*a") }
				f:close()
			end
		end
	end
	pipe:close()
end
local function Readers(key, setter)
	local out = {}
	local pattern = "ns%." .. key:gsub("%p", "%%%0") .. "%f[^%w_]"
	for _, file in ipairs(files) do
		if file.path ~= setter and file.text:find(pattern) then out[#out + 1] = file.path end
	end
	return out
end

-- Part 1 report.
local function Sorted(set)
	local list = {}
	for k in pairs(set) do list[#list + 1] = k end
	table.sort(list)
	return list
end
print(("== %s: %d pieces of the login build, %d pages made on first open"):format(client, #order - #waiting,
	#waiting))
local outsideTotal, defaultsTotal, lazyDefaults = 0, 0, 0
for _, name in ipairs(order) do
	local p = pieces[name]
	if not next(only) or only[name] or only[name:gsub("^lazy: ", "")] then
		local keys = Sorted(p.ns)
		local outside = {}
		for _, key in ipairs(keys) do
			local readers = Readers(key, p.ns[key])
			if #readers > 0 then outside[#outside + 1] = ("ns.%s (set in %s; read in %s)"):format(key, p.ns[key],
				table.concat(readers, ", ")) end
		end
		outsideTotal = outsideTotal + #outside
		local globals, events, defaults = Sorted(p.globals), Sorted(p.events), Sorted(p.defaults)
		local work = #events + p.updates + #p.hooks + p.timers + p.onUpdates
		if #defaults > 0 then
			defaultsTotal = defaultsTotal + #defaults
			lazyDefaults = lazyDefaults + (name:find("^lazy: ") and #defaults or 0)
			print(("%s: %d DEFAULTS keys made by its build: %s"):format(name, #defaults, table.concat(defaults, ", ")))
		end
		if #keys + #globals + #p.named + work > 0 then
			print(("%s: %d ns keys (%d read elsewhere), %d globals, %d named frames, %d events, %d OnUpdate, %d hooks, %d timers, %d ns.SetOnUpdate")
				:format(name, #keys, #outside, #globals, #p.named, #events, p.updates, #p.hooks, p.timers, p.onUpdates))
			for _, line in ipairs(outside) do print("    " .. line) end
			if #globals > 0 then print("    globals: " .. table.concat(globals, ", ")) end
			if #events > 0 then print("    events: " .. table.concat(events, ", ")) end
			if #p.hooks > 0 then print("    hooks: " .. table.concat(p.hooks, ", ")) end
		end
	end
end
print(("ns keys set by a piece and read in another file: %d"):format(outsideTotal))
print(("DEFAULTS keys made by a page's build: %d (%d by pages made on first open)"):format(defaultsTotal, lazyDefaults))

-- Part 2 report.
local problems = 0
-- Every default a page made on first open makes: in LazyPageDefaults.lua, with its value (else profiles,
-- sharing and Reset miss it till the page is opened). --write puts this client's list there.
local made = {}
for _, name in ipairs(order) do
	if name:find("^lazy: ") then
		for key, value in pairs(pieces[name].defaultValues or {}) do made[key] = value end
	end
end
if write then
	local path = "LazyPageDefaults.lua"
	local f = assert(io.open(path, "rb"))
	local text = f:read("*a")
	f:close()
	local lines = {}
	for _, key in ipairs(Sorted(made)) do
		lines[#lines + 1] = ("\t\t[%q] = %s,"):format(key, tostring(made[key]))
	end
	local block = ("\t-- %s: start\n\t%s = {\n%s\t},\n\t-- %s: end"):format(client, client,
		#lines > 0 and (table.concat(lines, "\n") .. "\n") or "", client)
	local s, e = text:find("\t%-%- " .. client .. ": start.-\t%-%- " .. client .. ": end")
	assert(s, "no " .. client .. " block in " .. path)
	text = text:sub(1, s - 1) .. block .. text:sub(e + 1)
	f = assert(io.open(path, "wb"))
	f:write(text)
	f:close()
	print(("wrote %d defaults for %s into %s"):format(#lines, client, path))
	listed = made
end
for key, value in pairs(made) do
	if listed[key] ~= value then
		problems = problems + 1
		print(("FAIL %s = %s made by a page made on first open, not in LazyPageDefaults.lua (%s): run with --write")
			:format(key, tostring(value), listed[key] == nil and "missing" or "listed as " .. tostring(listed[key])))
	end
end
for key in pairs(listed) do
	if made[key] == nil then
		problems = problems + 1
		print(("FAIL %s is in LazyPageDefaults.lua but no page made on first open makes it: run with --write"):format(key))
	end
end
for err in pairs(unbuilt) do
	if not built[err] then
		problems = problems + 1
		print("FAIL only while unbuilt: " .. err)
	end
end
for key, by in pairs(misses) do
	local def = defined[key]
	if def and def.piece:find("^lazy: ") then
		problems = problems + 1
		print(("FAIL ns.%s read while missing (in %s), set only when %s is made"):format(key,
			table.concat(Sorted(by), ", "), def.piece:gsub("^lazy: ", "")))
	end
end
print(((problems == 0 and "PASS " or "FAIL ") .. "unbuilt run: %d problems (%d pages waiting)"):format(problems, #waiting))
os.exit(problems == 0 and 0 or 1)
-- luacheck: pop
