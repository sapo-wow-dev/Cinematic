-- State matrix for an offline test (the audit kit, .claude/skills/audit):
-- every combination of the states a behavior depends on (card up or not,
-- a setting on or off, CineMode, the client...), one CELL line each, so
-- Tools/audit.py can run the same test on the old code and the new and list
-- every cell whose outcome changed. A fix that changes a cell its fix card
-- doesn't declare fails there: the neighbor it broke.
--
--   local Matrix = dofile("Tools/offline/matrix.lua")
--   Matrix.Run({
--     name = "zonecard-gameline",                 -- stable id, cards name it
--     fixed = { client = client },                -- printed in every cell
--     dims = { { "card", { "up", "gone" } }, { "gap", { "within", "after" } } },
--     cell = function(c) ... return "shown" end,  -- c.card, c.gap...: one outcome (a string)
--     pins = {                                    -- what each cell must give NOW
--       { "card=up", "hidden" },                  -- pairs a cell must have (all of them)
--       { "card=gone gap=within", "shown" },      -- later pins win over earlier ones
--       { "", "hidden" },                         -- "" = every cell
--     },
--   })
--
-- The cell function must only use what the OLD code has too (game frames'
-- alpha, saved settings, ns calls that existed): it runs on both. A cell that
-- errors prints "error: ...". Pins make it a plain PASS/FAIL test as well:
-- every cell must match a pin (an unpinned cell FAILs: every state's outcome
-- is stated), so Tools/prerelease.py can list it in OFFLINE_TESTS.
-- Set MATRIX_NOPINS=1 (audit.py does on the old code) to print cells only.

local Matrix = {}

local function Key(fixed, dims, values)
	local parts = {}
	local names = {}
	for name in pairs(fixed or {}) do names[#names + 1] = name end
	table.sort(names)
	for _, name in ipairs(names) do parts[#parts + 1] = name .. "=" .. tostring(fixed[name]) end
	for i, dim in ipairs(dims) do parts[#parts + 1] = dim[1] .. "=" .. tostring(values[i]) end
	return table.concat(parts, " ")
end

-- Whether a cell's key has every name=value pair of a pin's pattern.
local function Matches(key, pattern)
	local have = {}
	for pair in key:gmatch("%S+") do have[pair] = true end
	for pair in pattern:gmatch("%S+") do
		if not have[pair] then return false end
	end
	return true
end
Matrix.Matches = Matches

local function Clean(text)
	return (tostring(text):gsub("[\r\n]+", " "):gsub("%s+$", ""))
end

function Matrix.Run(spec)
	assert(type(spec.name) == "string" and spec.name:match("^[%w%-_]+$"), "matrix: name is a plain id")
	assert(type(spec.cell) == "function", "matrix: cell is a function")
	local dims = spec.dims or {}
	local values, cells = {}, {}
	local function Walk(depth)
		if depth > #dims then
			local c = {}
			for name, value in pairs(spec.fixed or {}) do c[name] = value end
			for i, dim in ipairs(dims) do c[dim[1]] = values[i] end
			local key = Key(spec.fixed, dims, values)
			local ok, outcome = pcall(spec.cell, c)
			outcome = ok and Clean(outcome) or ("error: " .. Clean(outcome):sub(1, 160))
			cells[#cells + 1] = { key = key, outcome = outcome }
			print(("CELL %s | %s: %s"):format(spec.name, key, outcome))
			return
		end
		for _, value in ipairs(dims[depth][2]) do
			values[depth] = value
			Walk(depth + 1)
		end
	end
	Walk(1)
	print(("MATRIX %s: %d cells"):format(spec.name, #cells))
	if os.getenv("MATRIX_NOPINS") == "1" or not spec.pins then return cells end
	local fails = 0
	for _, cell in ipairs(cells) do
		local want
		for _, pin in ipairs(spec.pins) do
			if Matches(cell.key, pin[1]) then want = pin[2] end
		end
		local ok = want ~= nil and cell.outcome == want
		if not ok then fails = fails + 1 end
		print(("%s %s | %s: %s%s"):format(ok and "PASS" or "FAIL", spec.name, cell.key, cell.outcome,
			want == nil and " (no pin states this cell)" or (ok and "" or (" (pinned: " .. want .. ")"))))
	end
	cells.fails = fails
	return cells
end

return Matrix
