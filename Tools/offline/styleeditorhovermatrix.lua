-- The style editor's hover, every field that writes more than its own key
-- (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-25-style-editor-hover.md):
--   python -I Tools/offline/run.py Tools/offline/styleeditorhovermatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/styleeditorhovermatrix.lua forever --base <ref>
-- Hovering a choice shows it on the preview for a moment (Studio.ShowFor): the
-- value set, the preview drawn, the saved one set back. A field whose set does
-- more than its key (Cast bars' Look from copies Default's settings the first
-- time "Its own look" is picked; Width in fills an empty pixel width) left
-- those writes behind: hovering "Its own look" on the Cast bars tab started the
-- bars' own copy for real. The states: the field, its saved value (the first
-- or second choice), the choice hovered. Each cell: whether any saved setting
-- changed after the hover, and what the preview drew. The rule (Audit
-- 2026-11-25): a hover never leaves a saved setting changed; those fields
-- aren't previewed on hover (noHover); a plain key still is.

local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local Studio = ns.Studio
local db = ns.db

-- The field a frame's prop gives on a variant: by its label, a field (a table) only.
local function FieldOf(frameId, label, variant)
	local f = Studio.frames[frameId]
	for _, each in ipairs(f and Studio.Props(f) or {}) do
		if each.prop.label == label then
			local key = Studio.KeyOf(each.prop, variant)
			if type(key) == "table" then return key end
		end
	end
end

-- Each field: how to find it, its choices, how its saved value is put (straight into
-- the settings, never through its own set).
local FIELDS = {
	cast = { key = function() return FieldOf("cast", "Look from", "PLATE") end, values = { "default", "own", "other" },
		put = function(value)
			db.plateCastOwn_PLATE = value == "own"
			db.plateCastGameAs_PLATE = value == "other"
			db.plateCastStarted_PLATE = value == "own" or nil
			-- (Default's border a size of yours: what "Its own look" copies the first time.)
			db.plateCastBorderSize, db.plateCastBorderSize_PLATE = 3, nil
		end },
	unit = { key = function() return FieldOf("unit", "Look from", "PLAYER") end, values = { "default", "own" },
		put = function(value) db.ufOwn_PLAYER = value == "own" db.ufStarted_PLAYER = value == "own" or nil end },
	raid = { key = function() return FieldOf("raid", "Look from", "RAID") end, values = { "default", "own" },
		put = function(value) db.rfOwn_RAID = value == "own" db.rfStarted_RAID = value == "own" or nil end },
	castWidth = { key = function() return FieldOf("cast", "Width in", "PLAYER") end, values = { "pct", "px" },
		put = function(value) db.plateCastPlayerWidthUnit = value db.plateCastPlayerWidthPx = 0 end },
	prdWidth = { key = function() return FieldOf("prd", "Width in") end, values = { "pct", "px" },
		put = function(value) db.prdHealthWidthUnit = value db.prdHealthWidthPx = 0 end },
	-- (A plain key, for the other side: still drawn on hover.)
	plain = { key = function() return "plateCastSpark" end, values = { true, false },
		put = function(value) db.plateCastSpark = value end },
}
local CHOICE = { first = 1, second = 2, third = 3 }

local function Copy()
	local out = {}
	for k, v in pairs(db) do out[k] = v end
	return out
end
local function Diff(a, b)
	local n = 0
	for k, v in pairs(a) do if b[k] ~= v then n = n + 1 end end
	for k, v in pairs(b) do if a[k] == nil and v ~= nil then n = n + 1 end end
	return n
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "style-editor-hover",
	fixed = { client = client },
	dims = {
		{ "field", { "cast", "unit", "raid", "castWidth", "prdWidth", "plain" } },
		{ "saved", { "first", "second" } },
		{ "hover", { "first", "second", "third" } },
	},
	cell = function(c)
		local spec = FIELDS[c.field]
		local hover = spec.values[CHOICE[c.hover]]
		if hover == nil then return "n/a" end
		local key = spec.key()
		if key == nil then return "no field" end
		spec.put(spec.values[CHOICE[c.saved]])
		local before = Copy()
		local drawn = "none"
		local preview = { Refresh = function()
			local now = type(key) == "table" and key.get() or db[key]
			drawn = tostring(now)
		end }
		Studio.ShowFor(preview, key, hover)
		local changed = Diff(before, db)
		-- (Put back whole for the next cell: a leak here is the bug itself.)
		for k in pairs(db) do db[k] = nil end
		for k, v in pairs(before) do db[k] = v end
		return ("db=%s drawn=%s"):format(changed == 0 and "unchanged" or ("changed(" .. changed .. ")"), drawn)
	end,
	pins = {
		{ "", "db=unchanged drawn=none" },
		{ "hover=third", "n/a" },
		{ "field=cast hover=third", "db=unchanged drawn=none" },
		-- (A plain key: drawn as hovered, nothing saved.)
		{ "field=plain hover=first", "db=unchanged drawn=true" },
		{ "field=plain hover=second", "db=unchanged drawn=false" },
		{ "field=plain hover=third", "n/a" },
	},
})
