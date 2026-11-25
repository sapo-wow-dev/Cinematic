-- The addon kit's probes and their runner (Tools/addon-kit-plan.md, parts B
-- and D). Dev copy only.
--
-- A probe reads how one of our features behaves on the game frame it uses,
-- as the player has it: it sets the feature's state, reads what happens,
-- and records it as fields (strings). It never judges. Judging comes from
-- the diff: the same probes run with no other addon (the baseline,
-- Tools/addon-kit/baseline-<client>.txt) and with one addon alone, and
-- every field that differs is either declared in that addon's Support file
-- (ns.AddonKitExpect, AddonSupport.lua) or a FAIL
-- (Tools/addon-kit/diff.py).
--
--   ns.AddonKit.Probe({
--     id = "chat.linesOnly",            -- area.name, stable: baselines key on it
--     v = 1,                            -- bump when what it records changes (the baseline goes stale)
--     touches = { "ChatFrame#" },       -- its touch points (Tools/addon-kit/touchpoints.txt)
--     settings = { "chatPeekLinesOnly" },
--     about = "...",
--     run = function(r) r:With("chatPeekLinesOnly", true) r:Set("linesOnly", ns.ChatPeekLinesOnly()) end,
--   })
--   ns.AddonKit.Run(label) -> lines   -- every probe, into CinematicDB.addonKitLog
--
-- The log, one line each (the same lines offline, Tools/addon-kit/kitrun.lua):
--   H format=1 client=<c> build=<n> label=<l> addons=<name,name...>
--   P <probe>\t<touch point>,<touch point>...  (what it probes: touchpoints.py's coverage)
--   O <probe>                                   (owned: its fields are the addons' own rows, Conflicts...:
--                                                one the baseline lacks is the addon's, not a difference)
--   R <probe>\t<field>\t<value>\tv<n>
--   E <probe>\t<error>
--   D <n> probes, <n> errors
local _, ns = ...

local FORMAT = 1
local kit = { probes = {}, byId = {} }
ns.AddonKit = kit

function kit.Probe(spec)
	assert(type(spec.id) == "string" and spec.id:match("^[%w_]+%.[%w_.]+$"), "addon kit probe: id is area.name")
	assert(type(spec.v) == "number", "addon kit probe " .. spec.id .. ": v (its version) is a number")
	assert(type(spec.run) == "function", "addon kit probe " .. spec.id .. ": run is a function")
	-- (touches: its touch points; may be empty only for a generated probe
	-- whose touch point no name says, a link part's.)
	assert(type(spec.touches) == "table" and (#spec.touches > 0 or spec.generated),
		"addon kit probe " .. spec.id .. ": touches lists its touch points")
	assert(not kit.byId[spec.id], "addon kit probe " .. spec.id .. ": made twice")
	kit.probes[#kit.probes + 1] = spec
	kit.byId[spec.id] = spec
	return spec
end

-- A value as a field: the same text for the same value on every run.
local function Text(value)
	if issecretvalue and issecretvalue(value) then return "secret" end
	local kind = type(value)
	if kind == "nil" then return "nil" end
	if kind == "boolean" then return value and "true" or "false" end
	if kind == "number" then
		if value == math.floor(value) then return ("%d"):format(value) end
		return ("%.3f"):format(value)
	end
	if kind == "string" then return (value:gsub("[\t\r\n]", " ")) end
	return kind
end
kit.Text = Text

-- The addons loaded now, but Cinematic's own copies.
local function Loaded()
	if kit.loadedOverride then return kit.loadedOverride end
	local out = {}
	local GetNum = C_AddOns and C_AddOns.GetNumAddOns or _G.GetNumAddOns
	local GetInfo = C_AddOns and C_AddOns.GetAddOnInfo or _G.GetAddOnInfo
	local IsLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or _G.IsAddOnLoaded
	local ok, count = pcall(GetNum)
	for i = 1, (ok and type(count) == "number" and count or 0) do
		local name = GetInfo(i)
		if type(name) == "string" and not name:find("^Cinematic") and IsLoaded(name) then out[#out + 1] = name end
	end
	table.sort(out)
	return out
end
kit.Loaded = Loaded

-- One probe's run: its fields, its settings put back after.
local Run = {}
Run.__index = Run
function Run:Set(field, value)
	assert(type(field) == "string" and field:match("^[%w_.:]+$"), "addon kit: a field is a plain name")
	self.fields[#self.fields + 1] = { field, Text(value) }
end
-- A setting for this probe's run, put back as it was after.
function Run:With(key, value)
	if self.saved[key] == nil then self.saved[key] = { ns.db[key] } end
	ns.db[key] = value
end
function Run:PutBack()
	for key, was in pairs(self.saved) do ns.db[key] = was[1] end
end

function kit.Run(label)
	if kit.MakeGenerated then kit.MakeGenerated() end
	local _, _, _, build = GetBuildInfo()
	local lines = {}
	lines[1] = ("H format=%d client=%s build=%s label=%s addons=%s"):format(FORMAT,
		ns.isRetail and "retail" or "forever", tostring(build), (tostring(label or "run"):gsub("%s", "_")),
		table.concat(Loaded(), ","))
	local errors = 0
	local order = {}
	for _, probe in ipairs(kit.probes) do order[#order + 1] = probe end
	table.sort(order, function(a, b) return a.id < b.id end)
	for _, probe in ipairs(order) do
		lines[#lines + 1] = ("P %s\t%s"):format(probe.id, table.concat(probe.touches, ","))
		if probe.owned then lines[#lines + 1] = "O " .. probe.id end
		local r = setmetatable({ fields = {}, saved = {} }, Run)
		local ok, err = pcall(probe.run, r)
		r:PutBack()
		if ok then
			for _, pair in ipairs(r.fields) do
				lines[#lines + 1] = ("R %s\t%s\t%s\tv%d"):format(probe.id, pair[1], pair[2], probe.v)
			end
		else
			errors = errors + 1
			lines[#lines + 1] = ("E %s\t%s"):format(probe.id, Text(tostring(err)))
		end
	end
	lines[#lines + 1] = ("D %d probes, %d errors"):format(#order, errors)
	if type(CinematicDB) == "table" then CinematicDB.addonKitLog = lines end
	return lines
end
