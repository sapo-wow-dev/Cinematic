-- The raid frames' hooks with Raid Style and Interface Recolor off (the audit
-- kit's matrix, Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-raid-style-hooks.md):
--   python -I Tools/offline/run.py Tools/offline/raidhooksmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/raidhooksmatrix.lua forever --base <ref>
-- The game updates a party frame three times (CompactUnitFrame_UpdateName,
-- each hooked by Style/RaidStyle.lua). Enable Style, Raid Style and Interface
-- Recolor each on or off; the frame fresh, or dressed once with all on first.
-- Each cell: how many of the three updates ran our restyle (its name dressed).
-- The rule (page off = no cost): with neither page on, none, but one to put a
-- dressed frame back.
local client = arg and arg[1] or "forever"
local hooks = {}
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	for _, name in ipairs({ "DefaultCompactUnitFrameSetup", "DefaultCompactMiniFrameSetup", "CompactUnitFrame_UpdateAll",
		"CompactUnitFrame_UpdateHealthColor", "CompactUnitFrame_UpdateName" }) do
		_G[name] = function() end
	end
	hooksecurefunc = function(a, b, c)
		if type(a) == "string" then
			hooks[a] = hooks[a] or {}
			table.insert(hooks[a], b)
		elseif type(a) == "table" and type(b) == "string" and type(c) == "function" then
			local old = a[b]
			a[b] = function(...)
				local r = { old(...) }
				c(...)
				return unpack(r)
			end
		end
	end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db

local frame = wow.CreateFrame("Button", "CompactPartyFrameMember1")
frame.unit, frame.displayedUnit = "party1", "party1"
frame.healthBar = wow.CreateFrame("StatusBar", nil, frame)
frame.name = frame:CreateFontString()
frame.background = frame:CreateTexture()
local work = 0
local DressName = ns.UnitStyleDressName
ns.UnitStyleDressName = function(...)
	work = work + 1
	return DressName(...)
end
local function Update()
	for _, fn in ipairs(hooks.CompactUnitFrame_UpdateName or {}) do pcall(fn, frame) end
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "raid-style-hooks",
	fixed = { client = client },
	dims = {
		{ "general", { "on", "off" } },
		{ "raid", { "on", "off" } },
		{ "recolor", { "on", "off" } },
		{ "before", { "fresh", "dressed" } },
	},
	cell = function(c)
		if not hooks.CompactUnitFrame_UpdateName then return "no hook" end
		-- (Each cell from a frame put back: all off, updated till it's left be.)
		db.styleGeneral, db.rfStyle, db.irStyle = true, false, false
		for _ = 1, 3 do Update() end
		if c.before == "dressed" then
			db.rfStyle, db.irStyle = true, true
			Update()
		end
		db.styleGeneral, db.rfStyle, db.irStyle = c.general == "on", c.raid == "on", c.recolor == "on"
		work = 0
		for _ = 1, 3 do Update() end
		return ("restyled=%d"):format(work)
	end,
	pins = {
		{ "", "restyled=0" },
		{ "before=dressed", "restyled=1" },
		{ "general=on raid=on", "restyled=3" },
		{ "general=on recolor=on", "restyled=3" },
	},
})
