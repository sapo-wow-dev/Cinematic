-- A part that ignores its frame's alpha, faded with it by FadeDetached.lua,
-- handed back while it refuses addon code (a fight on WoW Forever), every
-- state (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-22-fade-detached-release.md):
--   python -I Tools/offline/run.py Tools/offline/detachedreleasematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/detachedreleasematrix.lua --base <ref>
-- A part (its own alpha 0.8) under a faded frame (0.5): taken, drawn at 0.4.
-- Then handed back as it stops ignoring its parent (unignore) or as its frame
-- comes back up (rootup), with the part reachable or refusing our code (its
-- SetAlpha errors then, as the game's forbidden objects do); then a later
-- look once it's reachable again, with its frame up, or faded again.
-- Each cell: the part's alpha right after the hand-back (release: own 0.8,
-- faded 0.4, or error) and after the later look (later). The rule: never an
-- error; its own alpha back once nothing faded holds it, as soon as it can be
-- written. (bdb2e1d: Release wrote to it refusing: an error, and its own
-- alpha lost, the part left at the faded one.)

local client = arg and arg[1] or "forever"
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
ns.db.enabled = true

local function Name(alpha)
	if math.abs(alpha - 0.8) < 0.001 then return "own" end
	if math.abs(alpha - 0.4) < 0.001 then return "faded" end
	return tostring(alpha)
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "detached-release",
	fixed = { client = client },
	dims = {
		{ "how", { "unignore", "rootup" } },
		{ "reachable", { "yes", "no" } },
		{ "later", { "rootup", "rootfaded" } },
	},
	cell = function(c)
		-- (Each cell from a clean start: an error inside Release on the old
		-- code left its busy flag set, and every later hand-back did nothing.)
		for i = 1, 40 do
			local name = debug.getupvalue(ns.OnIgnoreParentAlpha, i)
			if not name then break end
			if name == "busy" then debug.setupvalue(ns.OnIgnoreParentAlpha, i, false) end
		end
		local rootAlpha, ignoring, refusing = 0.5, true, false
		local root = wow.CreateFrame("Frame", nil, UIParent)
		rawset(root, "SetAlpha", function() end)
		rawset(root, "GetEffectiveAlpha", function() return rootAlpha end)
		rawset(root, "IsIgnoringParentAlpha", function() return false end)
		local part = wow.CreateFrame("Frame", nil, root)
		local alpha = 0.8
		rawset(part, "IsIgnoringParentAlpha", function() return ignoring end)
		rawset(part, "IsForbidden", function() return refusing end)
		rawset(part, "GetAlpha", function() return alpha end)
		rawset(part, "SetAlpha", function(_, a)
			if refusing then error("forbidden object") end
			alpha = a
		end)
		ns.SyncDetached(root)
		if Name(alpha) ~= "faded" then return "not taken: " .. Name(alpha) end
		refusing = c.reachable == "no"
		local ok
		if c.how == "unignore" then
			ignoring = false
			ok = pcall(ns.OnIgnoreParentAlpha, part, false)
		else
			rootAlpha = 1
			ok = pcall(ns.SyncDetached, root)
		end
		local release = ok and Name(alpha) or "error"
		refusing = false
		rootAlpha = c.later == "rootup" and 1 or 0.5
		if not pcall(ns.SyncDetached, root) then return ("release=%s later=error"):format(release) end
		return ("release=%s later=%s"):format(release, Name(alpha))
	end,
	pins = {
		-- (Reachable: back at once; later as its frame says.)
		{ "reachable=yes", "release=own later=own" },
		-- (Its frame faded again, still ignoring it: faded with it again.)
		{ "how=rootup later=rootfaded", "release=own later=faded" },
		-- (Refusing: kept as it was, no error; back on the later look.)
		{ "reachable=no", "release=faded later=own" },
		{ "how=rootup reachable=no later=rootfaded", "release=faded later=faded" },
	},
})
