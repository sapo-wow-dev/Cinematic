-- Texture wrap modes the game knows (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/wrapmode.lua < /dev/null
-- Audit 2026-11-22: masks were set with "CLAMPTOBLACKADDITIONAL", a mode the
-- game hasn't got (its list: CLAMP, CLAMPTOBLACK, CLAMPTOBLACKADDITIVE,
-- CLAMPTOWHITE, REPEAT, MIRROR; Blizzard's code and every other installed
-- addon use CLAMPTOBLACKADDITIVE), taken since 2026-10-14 as whatever it falls
-- back to. Every SetTexture wrap mode in the addon's own .lua files is one of
-- the game's. PASS or FAIL per file.

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local KNOWN = { CLAMP = true, CLAMPTOBLACK = true, CLAMPTOBLACKADDITIVE = true, CLAMPTOWHITE = true, REPEAT = true,
	MIRROR = true }
local pipe = io.popen("git ls-files --cached --others --exclude-standard \"*.lua\"")
local checked = 0
for path in pipe:lines() do
	if not path:find("^Tools/") then
		local f = io.open(path, "rb")
		local text = f and f:read("*a") or ""
		if f then f:close() end
		local bad = {}
		-- (Any all-caps word starting CLAMP, MIRROR or REPEAT in quotes: a wrap mode.)
		for word in text:gmatch("\"(CLAMP[%u]*)\"") do
			if not KNOWN[word] then bad[#bad + 1] = word end
		end
		checked = checked + 1
		if #bad > 0 then Check(path .. ": wrap modes the game knows", false, table.concat(bad, ", ")) end
	end
end
pipe:close()
Check(("every wrap mode in %d files"):format(checked), fails == 0)
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
