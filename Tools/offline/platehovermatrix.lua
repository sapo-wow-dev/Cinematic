-- The Nameplate Style editor's hover, the fields 679e735 / a16eb17 left previewing
-- (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-26-plate-hover.md):
--   python -I Tools/offline/run.py Tools/offline/platehovermatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/platehovermatrix.lua forever --base <ref>
-- Pointing at a choice shows it on the preview for a moment (Studio.ShowFor): the
-- field's set, the preview drawn, its saved value set back. A field whose set writes
-- more than its own value left those writes saved: a Smart row's Plate color ticked
-- Bar in it; Name Style's Letters > Its own copied the name's font, outline and shadow
-- to the second line; Nameplate Layout's Center, Balance, Hang on and Side on a kind
-- (Hostile...) started its own layout (a copy of All plates') in plateLayoutData, and
-- on All plates left the part's table there. The states: the field, the variant it's
-- edited on (Default / All plates, a row or kind, an aggro row for Plate color), its
-- saved value (as it comes, or its second choice picked), the choice hovered (by its
-- place in the list, "last" the list's last). Each cell: whether any saved setting
-- changed after the hover, and what the preview drew; "hidden" where the field isn't
-- shown on that variant, "no frame" where its page isn't (Layout on retail). The rule
-- (the user 2026-11-26, as the 2026-11-25 card's): pointing at a choice never saves
-- anything; these fields aren't previewed on hover (noHover).

local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local Studio = ns.Studio
local db = ns.db

-- A frame's prop by its part and label.
local function PropOf(frameId, partId, label)
	local f = Studio.frames[frameId]
	for _, each in ipairs(f and Studio.Props(f, partId) or {}) do
		if each.prop.label == label then return f, each.prop end
	end
end

-- Each field: its frame, part and label, and the variant each "on" value edits.
local FIELDS = {
	plateColor = { frame = "plates", part = "colors", label = "Plate color",
		on = { default = "others", row = "target", aggro = "aggro" } },
	letters = { frame = "names", part = "line2", label = "Letters", on = { default = "all", row = "Enemies" } },
	center = { frame = "platelayout", part = "plate", label = "Center", on = { default = "all", row = "hostile" } },
	balance = { frame = "platelayout", part = "level", label = "Balance", on = { default = "all", row = "hostile" } },
	hang = { frame = "platelayout", part = "level", label = "Hang on", on = { default = "all", row = "hostile" } },
	side = { frame = "platelayout", part = "level", label = "Side", on = { default = "all", row = "hostile" } },
}

local function Opts(prop, variant)
	local o = prop.options
	if type(o) == "function" then local ok, got = pcall(o, variant) return ok and got or {} end
	return o or {}
end
local function ValueOf(o) if o.value ~= nil then return o.value end return o[1] end

-- The settings, deep (plateLayoutData is a table of tables), read as their defaults when unsaved.
local function Deep(v, depth)
	if type(v) ~= "table" or (depth or 0) > 8 then return v end
	local out = {}
	for k, x in pairs(v) do out[k] = Deep(x, (depth or 0) + 1) end
	return out
end
local function Same(a, b, depth)
	if a == b then return true end
	if type(a) ~= "table" or type(b) ~= "table" or (depth or 0) > 8 then return false end
	for k, v in pairs(a) do if not Same(v, b[k], (depth or 0) + 1) then return false end end
	for k in pairs(b) do if a[k] == nil then return false end end
	return true
end
local function Now(k, v) if v == nil then return ns.DEFAULTS[k] end return v end
local function Copy() local out = {} for k, v in pairs(db) do out[k] = Deep(v) end return out end
local function Moved(before)
	local n = 0
	for k in pairs(ns.DEFAULTS) do if not Same(Now(k, before[k]), Now(k, db[k])) then n = n + 1 end end
	for k, v in pairs(db) do if ns.DEFAULTS[k] == nil and not Same(before[k], v) then n = n + 1 end end
	for k in pairs(before) do if ns.DEFAULTS[k] == nil and db[k] == nil then n = n + 1 end end
	return n
end

local clean = Copy()
local CHOICE = { ["1"] = 1, ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5, ["6"] = 6, ["7"] = 7 }

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	-- (Per client: Layout's cells change on Forever only.)
	name = "plate-hover-" .. client,
	fixed = { client = client },
	dims = {
		{ "field", { "plateColor", "letters", "center", "balance", "hang", "side" } },
		{ "on", { "default", "row", "aggro" } },
		{ "saved", { "fresh", "picked" } },
		{ "hover", { "1", "2", "3", "4", "5", "6", "7", "last" } },
	},
	cell = function(c)
		local spec = FIELDS[c.field]
		local variant = spec.on[c.on]
		if variant == nil then return "n/a" end
		local f, prop = PropOf(spec.frame, spec.part, spec.label)
		if not prop then return "no field" end
		-- (Each cell from the settings as they came.)
		for k in pairs(db) do db[k] = nil end
		for k, v in pairs(clean) do db[k] = Deep(v) end
		if f.shown and not f.shown() then return "no frame" end
		if not Studio.Shown(prop, db, variant) then return "hidden" end
		local key = Studio.KeyOf(prop, variant)
		if type(key) ~= "table" then return "not a field" end
		local opts = Opts(prop, variant)
		local o = c.hover == "last" and opts[#opts] or opts[CHOICE[c.hover]]
		if o == nil then return "n/a" end
		if c.saved == "picked" then
			-- (Its second choice picked, as a click does: through its own set.)
			if not opts[2] then return "n/a" end
			key.set(ValueOf(opts[2]))
		end
		local before = Copy()
		local drawn = "none"
		local preview = { Refresh = function() drawn = tostring(key.get()) end }
		Studio.ShowFor(preview, key, ValueOf(o))
		local changed = Moved(before)
		return ("db=%s drawn=%s"):format(changed == 0 and "unchanged" or ("changed(" .. changed .. ")"), drawn)
	end,
	pins = {
		{ "", "db=unchanged drawn=none" },
		{ "on=aggro", "n/a" },
		{ "field=plateColor on=aggro", "db=unchanged drawn=none" },
		-- (Plate color is a Smart row's: not on Default's Colors.)
		{ "field=plateColor on=default", "hidden" },
		-- (Letters, Center: two and three choices.)
		{ "field=letters hover=3", "n/a" }, { "field=letters hover=4", "n/a" }, { "field=letters hover=5", "n/a" },
		{ "field=letters hover=6", "n/a" }, { "field=letters hover=7", "n/a" },
		{ "field=center hover=4", "n/a" }, { "field=center hover=5", "n/a" }, { "field=center hover=6", "n/a" },
		{ "field=center hover=7", "n/a" },
		-- (The level box's Balance: Always, While shown, Never.)
		{ "field=balance hover=4", "n/a" }, { "field=balance hover=5", "n/a" }, { "field=balance hover=6", "n/a" },
		{ "field=balance hover=7", "n/a" },
		-- (Plate color on a target row: Don't change, The game's, Default's, Mark's, Gold, One color.)
		{ "field=plateColor on=row hover=7", "n/a" },
		-- (Layout is Forever's only.)
		{ "client=retail field=center", "no frame" }, { "client=retail field=balance", "no frame" },
		{ "client=retail field=hang", "no frame" }, { "client=retail field=side", "no frame" },
		{ "client=retail field=center on=aggro", "n/a" }, { "client=retail field=balance on=aggro", "n/a" },
		{ "client=retail field=hang on=aggro", "n/a" }, { "client=retail field=side on=aggro", "n/a" },
	},
})
