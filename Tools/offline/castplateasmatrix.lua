-- The target's cast bar in the nameplates' game look (Cast Bars > Target:
-- "Look like" the nameplates', plateCastGameAs_TARGET), every state (the audit
-- kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-23-cast-plate-look-live.md):
--   python -I Tools/offline/run.py Tools/offline/castplateasmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/castplateasmatrix.lua --base <ref>
-- The real bar (the game's TargetFrameSpellBar, restyled) and a page preview's
-- sample, under each nameplateStyle CVar value (0 Modern .. 6 Classic) and
-- each nameplateSize (1-5). Each cell: our icon's size, where our icon sits
-- and where our spell name sits.
-- The rule (the user, 2026-11-23, "previews only"): the real bar keeps the
-- v2.1.27 layout by client (icon 12; Forever's icon and name in the bar,
-- retail's under it), whatever your nameplate settings; only the previews lay
-- them out as your nameplates do (ns.PlateCastLayout, 8d185cd).
local F = dofile("Tools/style-lab/frames.lua")
local client = arg and arg[1] or "forever"

-- luacheck: push ignore 111 112 113 121 122 212
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function(w)
	F.Install(w)
	rawset(_G, "CreateFontFamily", false)
end)
local cvars = {}
local getCVar = GetCVar
rawset(_G, "GetCVar", function(name) if cvars[name] then return cvars[name] end return getCVar(name) end)
-- luacheck: pop

local db = ns.GetDB()
for _, key in ipairs({ "unitCastStyle", "plateCastStyle" }) do
	local switch = key
	while switch do
		db[switch] = true
		switch = ns.PageSwitchOf(switch)
	end
end
db.plateCastOn_TARGET, db.plateCastFrame_TARGET, db.plateCastGameAs_TARGET = true, false, true

-- (The real target bar: a bar with the game's parts, by the name the addon
-- finds the target's by.)
local live = ns.MakeCastLookSample(UIParent, "unit", 1, nil)
rawset(_G, "TargetFrameSpellBar", live)

local function Where(region, bar, icon)
	if not region or region:GetNumPoints() == 0 then return "none" end
	local point, relative, relativePoint, x, y = region:GetPoint(1)
	local name = relative == bar and "bar" or (relative == icon and "icon" or "?")
	return ("%s>%s.%s %g,%g"):format(tostring(point), name, tostring(relativePoint), x or 0, y or 0)
end

local STYLES = { "0", "1", "2", "3", "4", "5", "6" }
local SIZES = { "1", "2", "3", "4", "5" }
local Matrix = dofile("Tools/offline/matrix.lua")

-- What's right, cell by cell (pins built from the rule above).
local pins = {}
-- The real bar: v2.1.27's layout by client, every style and size.
if client == "retail" then
	pins[#pins + 1] = { "bar=live", "icon=12 at=TOPLEFT>bar.BOTTOMLEFT 0,-1 name=LEFT>icon.RIGHT 2,0" }
else
	pins[#pins + 1] = { "bar=live", "icon=12 at=LEFT>bar.LEFT 0,0 name=LEFT>icon.RIGHT 2,0" }
end
-- A preview: as your nameplates lay it out (rules all.plate.castbar-layout-by-style
-- and all.plate.castbar-sizes; 8d185cd, OK'd by the user 2026-11-23).
do
	local scales = { 0.8, 1, 1.25, 1.4, 1.6 } -- (vertical, the icon's)
	local hscales = { 0.75, 1, 1.25, 1.4, 1.6 }
	local base = client == "retail" and 12 or 10
	for _, style in ipairs(STYLES) do
		for i, size in ipairs(SIZES) do
			local icon = base * scales[i]
			local at, name
			if style == "6" then
				local h = i == 1 and 0.8 or hscales[i]
				at = ("CENTER>bar.LEFT %g,0"):format(-9.25 * h)
				name = "LEFT>bar.LEFT 2,0"
			elseif style == "2" or style == "4" then
				at, name = "LEFT>bar.LEFT 0,0", "LEFT>icon.RIGHT 2,0"
			else
				at, name = "TOPLEFT>bar.BOTTOMLEFT 0,0", "LEFT>icon.RIGHT 2,0"
			end
			pins[#pins + 1] = { ("bar=preview style=%s size=%s"):format(style, size),
				("icon=%g at=%s name=%s"):format(icon, at, name) }
		end
	end
end

Matrix.Run({
	name = "cast-plate-look",
	fixed = { client = client },
	dims = {
		{ "bar", { "live", "preview" } },
		{ "style", STYLES },
		{ "size", SIZES },
	},
	cell = function(c)
		cvars.nameplateStyle, cvars.nameplateSize = c.style, c.size
		local bar
		if c.bar == "live" then
			bar = live
			ns.RefreshPlateCastStyle()
		else
			bar = ns.MakeCastLookSample(UIParent, "unit", 1, "TARGET")
			bar:Refresh()
		end
		local copy, copyIcon = bar.cinematicAsText, bar.cinematicAsIcon
		if not (copy and copyIcon) then return "no look" end
		return ("icon=%g at=%s name=%s"):format(copyIcon:GetWidth(), Where(copyIcon, bar, copyIcon),
			Where(copy, bar, copyIcon))
	end,
	pins = pins,
})
