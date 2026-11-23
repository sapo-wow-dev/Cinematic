-- Combat text numbers' size around the game's tallest font, every state (the
-- audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-22-style-combat-text-size.md):
--   python -I Tools/offline/run.py Tools/offline/combattextsizematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/combattextsizematrix.lua --base <ref>
-- A number's size (Size x Crit size x a long cast, of 36) below, at, above and
-- far above 120, the game's tallest font; font strings with or without
-- SetTextScale; All texts' Edge (the game's shadow, or edge and shadow); a
-- tag line ("(Glancing)") or none; the picked font taken or refused (the
-- game's then); a fresh number or one reused from a far bigger one. Each
-- cell: the height each part draws at (the font, capped at 120 as the game
-- does, times the words' scale): the number, its shown copies, its tag, and
-- a crit's pop at 1.2 times.
-- The rule: every part draws at the size asked (the tag at half of it, 8 at
-- least), however big; a pop at 1.2 times that. (bdb2e1d: past 120 the font
-- stopped growing, the words weren't scaled.)

local client = arg and arg[1] or "forever"
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db
local FONT_MAX = 120

-- (SetSize and SetHeight: locals of CombatTextStyle.lua, found through ns's
-- functions' upvalues, as combattextsize.lua.)
local function Find(name)
	local seen = {}
	local function Walk(fn, depth)
		if depth > 9 or seen[fn] then return nil end
		if type(fn) == "table" then
			seen[fn] = true
			for _, value in pairs(fn) do
				local found = Walk(value, depth + 1)
				if found then return found end
			end
			return nil
		end
		if type(fn) ~= "function" then return nil end
		seen[fn] = true
		for i = 1, 80 do
			local upName, value = debug.getupvalue(fn, i)
			if not upName then break end
			if upName == name and type(value) == "function" then
				local info = debug.getinfo(value, "S")
				if info.source:find("CombatTextStyle.lua", 1, true) then return value end
			end
			local found = Walk(value, depth + 1)
			if found then return found end
		end
	end
	local found = Walk(ns.FeatureLoop, 0)
	if found then return found end
	for _, value in pairs(ns) do
		found = Walk(value, 0)
		if found then return found end
	end
	for _, frame in ipairs(wow.frames) do
		for _, script in pairs(frame._scripts or {}) do
			found = Walk(script, 0)
			if found then return found end
		end
	end
end
local SetSize, SetHeight = Find("SetSize"), Find("SetHeight")

-- A font string as the game draws it: SetFont past 120 draws at 120; the
-- words' scale (where the client has SetTextScale) on top; a text height
-- set for a moment, times the scale. refuse: the picked font file refused.
local function Text(withScale, refuse)
	local text = { font = nil, scale = 1, height = nil, shown = true }
	text.SetFont = function(self, file, size)
		if refuse and file ~= "Fonts\\FRIZQT__.TTF" then return false end
		self.font = math.min(size, FONT_MAX)
		self.height = nil
		return true
	end
	if withScale then text.SetTextScale = function(self, scale) self.scale = scale end end
	text.SetTextHeight = function(self, height) self.height = height end
	text.SetShadowOffset = function() end
	text.ClearAllPoints = function() end
	text.SetPoint = function() end
	text.SetTextColor = function() end
	text.SetShown = function(self, on) self.shown = on end
	text.IsShown = function(self) return self.shown end
	text.Drawn = function(self) return (self.height or self.font or 0) * self.scale end
	return text
end
local function Number(withScale, refuse, tag)
	local edge = Text(withScale, refuse)
	edge.angle = 0
	local number = { id = "all", text = Text(withScale, refuse), copies = { edge, Text(withScale, refuse) } }
	if tag then number.tag = Text(withScale, refuse) end
	return number
end
local function Drawn(number)
	local parts = { ("%.0f"):format(number.text:Drawn()) }
	local copies = {}
	for _, copy in ipairs(number.copies) do
		if copy.shown then copies[#copies + 1] = ("%.0f"):format(copy:Drawn()) end
	end
	parts[#parts + 1] = "copies=" .. (#copies > 0 and table.concat(copies, ",") or "none")
	parts[#parts + 1] = "tag=" .. (number.tag and ("%.0f"):format(number.tag:Drawn()) or "none")
	return table.concat(parts, " ")
end

local SIZES = { below = 36, at = 120, above = 140.4, far = 486 }
local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "combattext-size",
	fixed = { client = client },
	dims = {
		{ "size", { "below", "at", "above", "far" } },
		{ "textScale", { "has", "missing" } },
		{ "edge", { "game", "both" } },
		{ "tag", { "yes", "no" } },
		{ "font", { "taken", "refused" } },
		{ "number", { "fresh", "reused" } },
	},
	cell = function(c)
		if not (SetSize and SetHeight) then error("SetSize/SetHeight not found") end
		db.combatTextEdge = c.edge
		db.combatTextFont = c.font == "refused" and "morpheus" or "game"
		local number = Number(c.textScale == "has", c.font == "refused", c.tag == "yes")
		if c.number == "reused" then SetSize(number, SIZES.far) end
		local size = SIZES[c.size]
		SetSize(number, size)
		local out = "number=" .. Drawn(number)
		SetHeight(number, size * 1.2)
		out = out .. (" pop=%.0f"):format(number.text:Drawn())
		return out
	end,
	pins = {
		-- (Below or at 120: as asked, anywhere.)
		{ "size=below edge=game tag=yes", "number=36 copies=36 tag=18 pop=43" },
		{ "size=below edge=game tag=no", "number=36 copies=36 tag=none pop=43" },
		{ "size=below edge=both tag=yes", "number=36 copies=36,36 tag=18 pop=43" },
		{ "size=below edge=both tag=no", "number=36 copies=36,36 tag=none pop=43" },
		{ "size=at edge=game tag=yes", "number=120 copies=120 tag=60 pop=144" },
		{ "size=at edge=game tag=no", "number=120 copies=120 tag=none pop=144" },
		{ "size=at edge=both tag=yes", "number=120 copies=120,120 tag=60 pop=144" },
		{ "size=at edge=both tag=no", "number=120 copies=120,120 tag=none pop=144" },
		-- (Above: as asked, where the client can scale the words.)
		{ "size=above edge=game tag=yes", "number=140 copies=140 tag=70 pop=168" },
		{ "size=above edge=game tag=no", "number=140 copies=140 tag=none pop=168" },
		{ "size=above edge=both tag=yes", "number=140 copies=140,140 tag=70 pop=168" },
		{ "size=above edge=both tag=no", "number=140 copies=140,140 tag=none pop=168" },
		-- (Far above: the tag at half, 243, is past 120 too: as asked. The user's call.)
		{ "size=far edge=game tag=yes", "number=486 copies=486 tag=243 pop=583" },
		{ "size=far edge=game tag=no", "number=486 copies=486 tag=none pop=583" },
		{ "size=far edge=both tag=yes", "number=486 copies=486,486 tag=243 pop=583" },
		{ "size=far edge=both tag=no", "number=486 copies=486,486 tag=none pop=583" },
		-- (No SetTextScale: nothing draws past 120 but a pop's height.)
		{ "size=above textScale=missing edge=game tag=yes", "number=120 copies=120 tag=70 pop=168" },
		{ "size=above textScale=missing edge=game tag=no", "number=120 copies=120 tag=none pop=168" },
		{ "size=above textScale=missing edge=both tag=yes", "number=120 copies=120,120 tag=70 pop=168" },
		{ "size=above textScale=missing edge=both tag=no", "number=120 copies=120,120 tag=none pop=168" },
		{ "size=far textScale=missing edge=game tag=yes", "number=120 copies=120 tag=120 pop=583" },
		{ "size=far textScale=missing edge=game tag=no", "number=120 copies=120 tag=none pop=583" },
		{ "size=far textScale=missing edge=both tag=yes", "number=120 copies=120,120 tag=120 pop=583" },
		{ "size=far textScale=missing edge=both tag=no", "number=120 copies=120,120 tag=none pop=583" },
	},
})
