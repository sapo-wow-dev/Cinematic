-- What the replay bench (Tools/sim/bench.lua) knows about the game, per
-- client, from the repo's own records of it, never from guesses:
--   * the engine rules (Tools/engine/rules.lua): what the game does, tested;
--     the bench's behaviours each name the rule they follow, and say how far
--     it's tested (tested / inferred / unknown) in the report;
--   * the game's API docs (Tools/engine/api/<client>.txt, Tools/engine/apidocs.py):
--     which functions and events this client has, each event's payload, the
--     secret flags; git-ignored (Blizzard's data), so on the user's PC only;
--   * the console's settings (Tools/engine/api/<client>-cvars.txt,
--     Tools/engine/cvars.py from /cine debug simprobe step 1): every setting's
--     default and flags (secure ones are blocked in a fight); git-ignored too.
-- A missing file isn't an error: what it would have given is said to be
-- missing in the report, and the bench does without.
--   local data = dofile("Tools/sim/gamedata.lua")("forever")
local function ReadLines(path)
	local f = io.open(path, "r")
	if not f then return nil end
	local lines = {}
	for line in f:lines() do lines[#lines + 1] = (line:gsub("\r$", "")) end
	f:close()
	return lines
end

-- "F Unit UnitPower(unit:UnitToken, type:number?) -> (power:number {SecretReturns=true})"
-- "E Unit UNIT_POWER_UPDATE(unitTarget:UnitToken)"
local function ParseDocs(lines)
	local docs = { functions = {}, events = {}, count = 0 }
	for _, line in ipairs(lines) do
		local kind, name, args = line:match("^([FE]) %S+ ([^%s(]+)%((.-)%)")
		if kind == "F" then
			docs.functions[name] = {
				line = line,
				secretReturns = line:find("SecretReturns", 1, true) ~= nil,
				secretArguments = line:find("SecretArguments", 1, true) ~= nil,
			}
			docs.count = docs.count + 1
		elseif kind == "E" then
			local payload = {}
			for arg in (args .. ","):gmatch("%s*([^:,]+):[^,]*,") do payload[#payload + 1] = arg end
			docs.events[name] = { line = line, payload = payload, synchronous = line:find("SynchronousEvent", 1, true) ~= nil }
			docs.count = docs.count + 1
		end
	end
	return docs
end

-- "cvar<TAB>name<TAB>value<TAB>default<TAB>flags<TAB>help"
local function ParseCVars(lines)
	local cvars = { settings = {}, count = 0, header = nil }
	for _, line in ipairs(lines) do
		if line:find("^# client ") then
			cvars.header = line:sub(3)
		else
			local kind, name, value, default, flags = line:match("^(%a+)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)")
			if kind == "cvar" then
				local set = {}
				for flag in flags:gmatch("[^,]+") do set[flag] = true end
				cvars.settings[name] = { value = value, default = default, flags = set }
				cvars.count = cvars.count + 1
			end
		end
	end
	return cvars
end

return function(client)
	local data = { client = client, missing = {} }

	-- The engine rules, by id; Rule(id) only when it covers this client.
	local ok, rules = pcall(dofile, "Tools/engine/rules.lua")
	data.rules = {}
	if ok and type(rules) == "table" then
		for _, rule in ipairs(rules) do data.rules[rule.id] = rule end
	else
		data.missing[#data.missing + 1] = "engine rules (Tools/engine/rules.lua): " .. tostring(rules)
	end
	function data.Rule(id)
		local rule = data.rules[id]
		if not rule then return nil end
		for _, c in ipairs(rule.clients or {}) do
			if c == client then return rule end
		end
		return nil
	end

	local docLines = ReadLines("Tools/engine/api/" .. client .. ".txt")
	if docLines then
		data.docs = ParseDocs(docLines)
	else
		data.missing[#data.missing + 1] = ("API docs (Tools/engine/api/%s.txt: python -I Tools/engine/apidocs.py on the PC "
			.. "with the game's code export): which functions and events this client has"):format(client)
	end
	local cvarLines = ReadLines("Tools/engine/api/" .. client .. "-cvars.txt")
	if cvarLines then
		data.cvars = ParseCVars(cvarLines)
	else
		data.missing[#data.missing + 1] = ("console settings (Tools/engine/api/%s-cvars.txt: /cine debug simprobe 1, "
			.. "/reload, python -I Tools/engine/cvars.py): defaults, which are secure"):format(client)
	end

	-- Does this client have it? true / false, or nil with no docs to say.
	function data.HasFunction(name)
		if not data.docs then return nil end
		return data.docs.functions[name] ~= nil
	end
	function data.HasEvent(name)
		if not data.docs then return nil end
		return data.docs.events[name] ~= nil
	end
	-- A setting's default (nil: unknown) and whether it's secure (nil: unknown).
	function data.CVarDefault(name)
		local s = data.cvars and data.cvars.settings[name]
		return s and s.default
	end
	function data.CVarSecure(name)
		if not data.cvars then return nil end
		local s = data.cvars.settings[name]
		return s and s.flags.secure or false
	end
	return data
end
