-- /cine debug apidocs: saves the game's own API documentation (the data behind
-- /api, Blizzard_APIDocumentationGenerated) for the client you are on, as one
-- short line per function, event and table, so Tools/engine/apidocs.py can
-- read it offline and check the engine rules against it (2026-11-21). Runs on
-- its own: loads the docs, walks them a few systems per frame, saves into
-- CinematicDB.apiDocs, then asks for a reload (that's when the game writes
-- SavedVariables). After the reload: DONE on screen. Run it once per client.
-- "/cine debug apidocs clear" drops the saved copy (it is big). Dev copy only.
local _, ns = ...

local PER_FRAME = 8 -- systems walked per frame
local KNOWN = { Name = true, Type = true, Nilable = true, InnerType = true, Mixin = true, Default = true,
	Documentation = true, Arguments = true, Returns = true, Payload = true, LiteralName = true, System = true,
	Fields = true, Values = true, Functions = true, Events = true, Tables = true, Namespace = true }

local function Client()
	if ns.isRetail then return "retail" end
	return ns.isClassicEra and "classic_era" or "forever"
end

local function Scalar(v)
	local t = type(v)
	return t == "string" or t == "number" or t == "boolean"
end

-- Every field Blizzard put on an entry that isn't one of the usual ones, as
-- " {k=v,k2={a=1}}" (sorted), so new flags (secret ones above all) show up
-- without this file knowing their names.
-- (An argument's Function / Event / Table field is its parent entry: skipped.)
local PARENT = { Function = true, Event = true, Table = true }
local function Extras(entry)
	local keys = {}
	for k, v in pairs(entry) do
		if type(k) == "string" and not KNOWN[k] and type(v) ~= "function" and not (PARENT[k] and type(v) == "table") then
			keys[#keys + 1] = k
		end
	end
	if #keys == 0 then return "" end
	table.sort(keys)
	local parts = {}
	for _, k in ipairs(keys) do
		local v = entry[k]
		if Scalar(v) then
			parts[#parts + 1] = k .. "=" .. tostring(v)
		elseif type(v) == "table" then
			local inner = {}
			for k2, v2 in pairs(v) do
				if Scalar(v2) then inner[#inner + 1] = tostring(k2) .. "=" .. tostring(v2) end
			end
			table.sort(inner)
			parts[#parts + 1] = k .. "={" .. table.concat(inner, ",") .. "}"
		end
	end
	return " {" .. table.concat(parts, ",") .. "}"
end

local function Params(list)
	if type(list) ~= "table" then return "" end
	local out = {}
	for _, p in ipairs(list) do
		if type(p) == "table" then
			local s = tostring(p.Name) .. ":" .. tostring(p.Type)
			if p.InnerType then s = s .. "<" .. tostring(p.InnerType) .. ">" end
			if p.Mixin then s = s .. "(" .. tostring(p.Mixin) .. ")" end
			if p.Nilable then s = s .. "?" end
			if p.Default ~= nil then s = s .. "=" .. tostring(p.Default) end
			out[#out + 1] = s .. Extras(p)
		end
	end
	return table.concat(out, ", ")
end

local function Systems()
	local docs = _G.APIDocumentation
	local list = docs and (docs.systems or docs.Systems)
	return docs, type(list) == "table" and list or nil
end

local function LoadDocs()
	local load = (C_AddOns and C_AddOns.LoadAddOn) or _G.LoadAddOn
	local said = {}
	for _, name in ipairs({ "Blizzard_APIDocumentationGenerated", "Blizzard_APIDocumentation" }) do
		local ok, loaded, why = pcall(load, name)
		said[#said + 1] = name .. "=" .. (ok and tostring(loaded) .. (why and (" " .. tostring(why)) or "")
			or ("error " .. tostring(loaded)))
	end
	return table.concat(said, "; ")
end

-- Shape lines: the keys Blizzard uses at each level, so the reader can tell a
-- layout change from a missing client feature.
local function Keys(t)
	local keys = {}
	if type(t) == "table" then
		for k, v in pairs(t) do keys[#keys + 1] = tostring(k) .. ":" .. type(v) end
	end
	table.sort(keys)
	return table.concat(keys, ",")
end

local function Walk(system, out, count)
	local sysName = tostring(system.Name or "?")
	local prefix = system.Namespace and (system.Namespace .. ".") or ""
	for _, f in ipairs(system.Functions or {}) do
		out[#out + 1] = ("F %s %s%s(%s) -> (%s)%s"):format(sysName, prefix, tostring(f.Name), Params(f.Arguments),
			Params(f.Returns), Extras(f))
		count.F = count.F + 1
	end
	for _, e in ipairs(system.Events or {}) do
		out[#out + 1] = ("E %s %s(%s)%s"):format(sysName, tostring(e.LiteralName or e.Name), Params(e.Payload), Extras(e))
		count.E = count.E + 1
	end
	for _, t in ipairs(system.Tables or {}) do
		out[#out + 1] = ("T %s %s %s(%s)%s"):format(sysName, tostring(t.Name), tostring(t.Type),
			Params(t.Fields or t.Values), Extras(t))
		count.T = count.T + 1
	end
end

local function Done(text, sub)
	ns.PadTestBox(text, sub or "", 1, 1, 1)
	C_Timer.After(30, function() ns.PadTestBoxHide() end)
end

local running
function ns.ApiDocsDump(arg)
	if arg == "clear" then
		if CinematicDB then CinematicDB.apiDocs = nil end
		return Done("API docs copy dropped.", "It leaves SavedVariables at the next reload.")
	end
	if running then return ns.Print("API docs dump already running.") end
	local loadSaid = LoadDocs()
	local docs, systems = Systems()
	if not systems then
		CinematicDB.apiDocs = { client = Client(), build = select(4, GetBuildInfo()), at = date("%Y-%m-%d %H:%M"),
			load = loadSaid, shape = { "APIDocumentation " .. Keys(docs) }, lines = {} }
		return ns.ReloadOrAsk("API docs: none on this client (" .. loadSaid .. "). Reload to save that, then say \"check log\".")
	end
	running = true
	local version, build, _, toc = GetBuildInfo()
	local dump = { client = Client(), version = version, build = build, toc = toc, at = date("%Y-%m-%d %H:%M"),
		load = loadSaid, shape = {}, lines = {} }
	local first = systems[1]
	dump.shape[#dump.shape + 1] = "APIDocumentation " .. Keys(docs)
	dump.shape[#dump.shape + 1] = "system " .. Keys(first)
	for _, kind in ipairs({ "Functions", "Events", "Tables" }) do
		for _, s in ipairs(systems) do
			local e = s[kind] and s[kind][1]
			if e then
				dump.shape[#dump.shape + 1] = kind .. " " .. Keys(e)
				break
			end
		end
	end
	local count = { F = 0, E = 0, T = 0 }
	ns.PadTestBox("API docs dump", "Reading the game's API docs...", 1, 0.82, 0)
	local i = 1
	local ticker
	ticker = C_Timer.NewTicker(0, function()
		local ok, err = pcall(function()
			for _ = 1, PER_FRAME do
				local s = systems[i]
				if not s then break end
				if type(s) == "table" then Walk(s, dump.lines, count) end
				i = i + 1
			end
		end)
		if ok and systems[i] then
			ns.PadTestBox("API docs dump", ("System %d of %d"):format(i, #systems), 1, 0.82, 0)
			return
		end
		ticker:Cancel()
		running = nil
		if not ok then dump.error = tostring(err) end
		dump.counts = ("%d systems, %d functions, %d events, %d tables"):format(#systems, count.F, count.E, count.T)
		CinematicDB.apiDocs = dump
		CinematicDB.apiDocsReload = true
		ns.PadTestBoxHide()
		ns.ReloadOrAsk("API docs dump: " .. dump.counts .. (dump.error and (" (stopped: " .. dump.error .. ")") or "")
			.. ". Reload to save it.")
	end)
end

-- After the reload: the copy is on disk.
local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function(self)
	self:UnregisterAllEvents()
	if not (CinematicDB and CinematicDB.apiDocsReload) then return end
	CinematicDB.apiDocsReload = nil
	local d = CinematicDB.apiDocs
	C_Timer.After(3, function()
		Done("API docs dump DONE (" .. tostring(d and d.client) .. ").",
			tostring(d and d.counts) .. "\nSay \"check log\". Run it on your other clients too.")
	end)
end)
