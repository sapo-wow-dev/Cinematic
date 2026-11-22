-- The quest tracker walk's probe (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/questwalkprobe.lua <forever|retail>
-- ns.QuestFocusTick walked the game's tracker on half the frames passes in a
-- fight run, 60% of the pass's targets (Tools/perf/ledger.md 2026-11-22).
-- While profiling it counts why each walk ran and times it ("quest focus:
-- game's tracker"), and ns.FadeRelative counts, for the walk's parts, whether
-- the game had changed a part's alpha since, it was set, or was already so:
-- the next recording says whether walking every pass ever changes a thing.
-- Checked here: the three counts, the reason and the part, and nothing
-- counted while not profiling. PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122
local client = arg and arg[1] or "forever"
package.path = "Tools/offline/?.lua;" .. package.path
local wow = dofile("Tools/offline/wow.lua")
wow.Install(client)
debugprofilestop = function() return os.clock() * 1000 end
local ns = {}
for line in io.lines("Cinematic.toc") do
	line = line:gsub("\r", "")
	if line ~= "" and not line:find("^#") then
		local chunk = loadfile((line:gsub("\\", "/")))
		if chunk then
			local ok, err = pcall(chunk, "Cinematic", ns)
			if not ok then wow.Warn(line .. ": " .. tostring(err)) end
		end
	end
end
wow.Fire("ADDON_LOADED", "Cinematic")
wow.Fire("PLAYER_LOGIN")
-- luacheck: pop

local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. text)
	if not ok then failed = failed + 1 end
end
Check(ns.FadeRelative and ns.QuestFocusTick and ns.StartProfile and ns.ProfileAdd, "the probe's functions found")
if not (ns.FadeRelative and ns.QuestFocusTick) then return print("1 FAILED") end

local function Part()
	local p = { a = 1 }
	p.GetAlpha = function(self) return self.a end
	p.SetAlpha = function(self, a) self.a = a end
	return p
end
local function Counts()
	local out = {}
	for _, line in ipairs(ns.lastProfile and ns.lastProfile.lines or {}) do
		local name, n = line:match("^count (.+): ([%d.]+) a frame")
		if name then out[name] = tonumber(n) end
	end
	return out
end

-- Not profiling: nothing counted (and the fade works as ever).
local counted = 0
local ProfileCount = ns.ProfileCount
ns.ProfileCount = function(...) counted = counted + 1 return ProfileCount(...) end
local part = Part()
ns.fadeRelativeTag = "probe"
ns.FadeRelative(part, 0.5)
ns.fadeRelativeTag = nil
Check(counted == 0 and math.abs(part.a - 0.5) < 0.001, ("not profiling: faded (%.2f), nothing counted (%d)"):format(
	part.a, counted))

-- Profiling: FadeRelative's three answers, for a tagged caller only.
ns.StartProfile(30, true, false)
local run = ns.Profiled("probe run", function()
	local p = Part()
	ns.fadeRelativeTag = "probe"
	ns.FadeRelative(p, 0.5)   -- set
	ns.FadeRelative(p, 0.5)   -- already so
	p:SetAlpha(1)             -- the game sets its own
	ns.FadeRelative(p, 0.5)   -- the game changed it, then set
	ns.fadeRelativeTag = nil
	ns.FadeRelative(Part(), 0.5) -- untagged: not counted
	-- The quest walk: held open (others held up), on a stand-in tracker.
	ns.questFocusOthersUp = true
	pcall(ns.QuestFocusTick, { frame = CreateFrame("Frame"), alpha = 1 }, false, 0.1, false)
	ns.questFocusOthersUp = nil
end)
run()
ns.StopProfile()
local c = Counts()
Check((c["probe: set"] or 0) > 0 and (c["probe: already so"] or 0) > 0 and (c["probe: the game changed it"] or 0) > 0,
	("tagged fades counted: set %s, already so %s, the game changed it %s"):format(tostring(c["probe: set"]),
	tostring(c["probe: already so"]), tostring(c["probe: the game changed it"])))
Check(c["probe: set"] == c["probe: already so"] * 2,
	"each counted once a call (2 set, 1 already so), the untagged one not at all")
Check((c["quest focus walks: others held up"] or 0) > 0, "the walk's reason counted (others held up)")
local listed = false
for _, row in ipairs(ns.lastProfile and ns.lastProfile.sections or {}) do
	for _, child in ipairs(row.children or {}) do
		if child.name == "quest focus: game's tracker" then listed = true end
	end
end
Check(listed, "the walk timed as a part (quest focus: game's tracker)")
Check(ns.fadeRelativeTag == nil, "the tag cleared after the walk")

print(failed == 0 and "ALL PASSED" or (failed .. " FAILED"))
