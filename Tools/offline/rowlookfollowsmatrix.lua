-- Smart rows' looks after rowLookFollowsV1 (the audit kit's matrix, Tools/offline/matrix.lua;
-- fix card Tools/audits/2026-11-26-row-look-follows.md):
--   python -I Tools/offline/run.py Tools/offline/rowlookfollowsmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/rowlookfollowsmatrix.lua forever --base <ref>
-- A row (each shape: a kind's own, a Who under it, a numbered copy, a Distance, a copy of a
-- Distance; of a kind starting at "same" (Focus) or at Custom (Not your kill)) and its parent
-- row, both on the grid: each with its Plate color unset (its parent's), Custom or Gold, and
-- with a Look texture of its own or none. The migration runs; each cell: the texture the row's
-- plates and its parent's show now (ns.PlateRowLookFor), "own", "par" (the parent's) or "none"
-- (the Default row's). Right (2026-11-26): what they showed before the update, when a row's
-- Look counted only while its Plate color, its parent's where unset, was Custom: no plate changes.
-- luacheck: ignore 111 112 113 121 122 212 431
local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db

-- (shape: the row, and its parent; base: none.)
local SHAPES = {
	base = function(k) return k, nil end,
	who = function(k) return k .. "Enemy", k end,
	numbered = function(k) return k .. "2", k end,
	distance = function(k) return k .. "Past40", k end,
	distcopy = function(k) return k .. "Past402", k .. "Past40" end,
}
local function Key(kind, part) return kind == "target" and "targetArrow" .. part or kind .. "Mark" .. part end
local ALL = { "", "Enemy", "2", "Past40", "Past402" }
local COLOR = { unset = nil, custom = "custom", gold = "gold" }
local TEX = { own = "glass", par = "soft" }
local NAME = { glass = "own", soft = "par" }

local function Tex(kind)
	if not kind then return "-" end
	local look = ns.PlateRowLookFor and ns.PlateRowLookFor(kind)
	local t = look and look.texture
	return t and (NAME[t] or tostring(t)) or "none"
end

local Matrix = dofile("Tools/offline/matrix.lua")
local dims = { { "kind", { "focus", "tapped" } }, { "shape", { "base", "who", "numbered", "distance", "distcopy" } },
	{ "color", { "unset", "custom", "gold" } }, { "look", { "own", "none" } },
	{ "pcolor", { "unset", "custom", "gold" } }, { "plook", { "par", "none" } } }

-- What's right: the look before the update (pins, worked out here on their own: a row's
-- Plate color its own, else up the chain to its kind's default; its Look texture its own,
-- else its parent's, only while that color is Custom).
local function KindDefaultCustom(kind) return ns.DEFAULTS[Key(kind, "PlateColor")] == "custom" end
local function Right(c)
	local row, parent = SHAPES[c.shape](c.kind)
	local function ColorOf(id)
		if id == row and c.color ~= "unset" then return c.color end
		if id == parent and c.pcolor ~= "unset" then return c.pcolor end
		return nil
	end
	local function Custom(id)
		local up = { id }
		if id == row and parent then up[#up + 1] = parent end
		if parent and parent ~= c.kind then up[#up + 1] = c.kind end
		for _, each in ipairs(up) do
			local how = ColorOf(each)
			if how then return how == "custom" end
		end
		return KindDefaultCustom(c.kind)
	end
	local function Look(id)
		if not Custom(id) then return "none" end
		if id == row and c.look == "own" then return "own" end
		if parent and c.plook == "par" then return "par" end
		return "none"
	end
	if parent then return ("row=%s parent=%s"):format(Look(row), Look(parent)) end
	return ("row=%s parent=-"):format(Look(row))
end

local pins = {}
do
	local values = {}
	local function Walk(depth)
		if depth > #dims then
			local c, parts = {}, {}
			for i, dim in ipairs(dims) do
				c[dim[1]] = values[i]
				parts[#parts + 1] = dim[1] .. "=" .. values[i]
			end
			pins[#pins + 1] = { table.concat(parts, " "), Right(c) }
			return
		end
		for _, value in ipairs(dims[depth][2]) do
			values[depth] = value
			Walk(depth + 1)
		end
	end
	Walk(1)
end

Matrix.Run({
	name = "rowlookfollows",
	fixed = { client = client },
	dims = dims,
	cell = function(c)
		for _, kind in ipairs({ "focus", "tapped" }) do
			for _, suffix in ipairs(ALL) do
				db[Key(kind .. suffix, "PlateColor")] = nil
				db[Key(kind .. suffix, "LookTexture")] = nil
			end
		end
		local row, parent = SHAPES[c.shape](c.kind)
		db.markOrder = parent and (row .. "," .. parent) or row
		db[Key(row, "PlateColor")] = COLOR[c.color]
		if c.look == "own" then db[Key(row, "LookTexture")] = TEX.own end
		if parent then
			db[Key(parent, "PlateColor")] = COLOR[c.pcolor]
			if c.plook == "par" then db[Key(parent, "LookTexture")] = TEX.par end
		end
		db.rowLookFollowsV1 = nil
		ns.RunMigrations()
		return ("row=%s parent=%s"):format(Tex(row), Tex(parent))
	end,
	pins = pins,
})
