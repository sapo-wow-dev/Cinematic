-- A /cine command's error with a part left out, every state (the audit kit's
-- matrix, Tools/offline/matrix.lua; fix cards Tools/audits/2026-11-22-settings-slash-left-out.md
-- and 2026-11-23-settings-slash-unnamed-call.md):
--   python -I Tools/offline/run.py Tools/offline/slashleftoutmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/slashleftoutmatrix.lua --base <ref>
-- /cine resume with a part left out (Atmosphere, its General page's Load box)
-- or none, its code failing each way: a call into ns that isn't there (the
-- left-out part's), the same as Lua 5.1 names it in some calls (field '?'),
-- a call to a field another table lacks whose name ns has (Print), an index
-- of another table's missing field ns doesn't have (frame), a nil local, an
-- error of another kind, or no error. Each cell: what the player gets, "note"
-- (the "you've left out" line), "error" (the game's error, to the handler or
-- raised), both, or "ok". The rule: only a missing ns call is the left-out
-- part's note; every other failure is a real bug and shows as an error.
-- (bdb2e1d audit 2026-11-22: every "a nil value" was taken for the left-out
-- part. ae2cda8: field '?' said nothing.)

local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")

local KINDS = {
	missingNs = false, -- (ns.Resume itself gone)
	unnamed = function() error("Slash.lua:1129: attempt to call field '?' (a nil value)", 0) end,
	nsHasName = function() local t = {} t.Print() end,
	otherField = function() local t = {} return t.frame.x end,
	nilLocal = function() local entry = rawget(ns, "noSuchEntry") return entry.x end,
	other = function() error("Slash.lua:10: bad argument #1 to 'format' (string expected, got nil)", 0) end,
	none = function() return false end,
}

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "slash-leftout",
	fixed = { client = client },
	dims = {
		{ "leftOut", { "none", "atmosphere" } },
		{ "fails", { "missingNs", "unnamed", "nsHasName", "otherField", "nilLocal", "other", "none" } },
	},
	cell = function(c)
		local Resume, Loaded, Print, Handler = ns.Resume, ns.ModuleLoaded, ns.Print, _G.geterrorhandler
		local note, errors = false, 0
		ns.Print = function(text) if tostring(text):find("left out", 1, true) then note = true end end
		_G.geterrorhandler = function() return function() errors = errors + 1 end end
		if c.leftOut ~= "none" then ns.ModuleLoaded = function(part) return part ~= c.leftOut end end
		ns.Resume = KINDS[c.fails] or nil
		local ok = pcall(ns.HandleSlash, "resume")
		ns.Resume, ns.ModuleLoaded, ns.Print, _G.geterrorhandler = Resume, Loaded, Print, Handler
		if not ok then errors = errors + 1 end
		local shown = (note and errors > 0) and "note+error" or note and "note" or errors > 0 and "error" or "ok"
		return shown
	end,
	pins = {
		{ "", "error" },
		{ "fails=none", "ok" },
		{ "leftOut=atmosphere fails=missingNs", "note" },
		{ "leftOut=atmosphere fails=unnamed", "note" },
	},
})
