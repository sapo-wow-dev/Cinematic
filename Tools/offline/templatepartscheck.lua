-- The game's templates on the stand-in (Tools/offline/templateparts.lua), offline (Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/templatepartscheck.lua < /dev/null
-- 1. A hand-made recipe: parts by key with atlas, size, layer, font, hidden;
--    $parent names and anchors made relative to real frames; a child frame
--    with its own parts; key values; a comma list of templates; Stop.
-- 2. The game's own recipes, when Tools/engine/templates.py has made them
--    from the client's code export (else SKIP, so it runs in CI too):
--    TargetSpellBarTemplate's parts, and the addon's own cast bar samples
--    (ns.MakeCastLookSample: player, unit, plate) each built from its game
--    template, not the drawn fallback, on each client that has recipes.
-- luacheck: push ignore 111 112 113 121 122 212 431
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail ~= nil and (" (" .. tostring(detail) .. ")") or ""))
end

package.path = "Tools/offline/?.lua;" .. package.path
local wow = dofile("Tools/offline/wow.lua")
wow.Install("forever")
local parts = dofile("Tools/offline/templateparts.lua")

-- 1. By hand.
local n = parts.Use({
	BarTemplate = { name = "BarTemplate", kind = "StatusBar", size = { 150, 10 },
		keyValues = { kind = { value = "small", type = "string" }, rows = { value = "3", type = "number" } },
		parts = {
			{ kind = "Texture", key = "Icon", layer = "ARTWORK", sub = 4, size = { 16, 16 }, atlas = "icon-atlas",
				points = { { point = "RIGHT", rel = "$parent", relPoint = "LEFT", x = -5, y = 0 } } },
			{ kind = "FontString", key = "Text", name = "$parentText", layer = "OVERLAY", font = "GameFontHighlightSmall",
				points = { { point = "LEFT", rel = "$parent.Icon", relPoint = "RIGHT", x = 2, y = 0 } } },
			{ kind = "Texture", key = "Shield", hidden = true, file = "Interface\\Shield" },
		},
		children = {
			{ kind = "Frame", parentKey = "Holder", name = "$parentHolder", size = { 10, 4 },
				points = { { point = "TOP", rel = "$parent.Icon", relPoint = "BOTTOM", x = 0, y = -1 } },
				parts = { { kind = "Texture", key = "Spark", atlas = "spark" } } },
		} },
	GlowTemplate = { name = "GlowTemplate", kind = "Frame", parts = { { kind = "Texture", key = "Glow", atlas = "glow" } } },
})
Check("recipes taken", n == 2, n)
local bar = CreateFrame("StatusBar", "TestBar", UIParent, "BarTemplate, GlowTemplate")
local icon, text = rawget(bar, "Icon"), rawget(bar, "Text")
Check("Icon is a real texture part", icon and icon:GetObjectType() == "Texture" and icon._part.atlas == "icon-atlas"
	and icon._part.size[1] == 16, icon and icon._part and icon._part.atlas)
Check("Text is a font string with the template's font", text and text:GetObjectType() == "FontString"
	and text._part.font == "GameFontHighlightSmall")
Check("$parentText is a global named for the frame", _G.TestBarText == text)
Check("anchor to $parent is the frame", icon and icon._partPoints[1][2] == bar and icon._partPoints[1][3] == "LEFT"
	and icon._partPoints[1][4] == -5)
Check("anchor to $parent.Icon is the Icon part", text and text._partPoints[1][2] == icon)
Check("hidden part made hidden", rawget(bar, "Shield") and not bar.Shield:IsShown())
local holder = rawget(bar, "Holder")
Check("child frame by its key, with its own part", holder and holder:GetParent() == bar and rawget(holder, "Spark")
	and holder.Spark._part.atlas == "spark" and _G.TestBarHolder == holder)
Check("child anchored to its parent's part", holder and holder._partPoints[1][2] == icon)
Check("key values set, typed", bar.kind == "small" and bar.rows == 3, tostring(bar.kind) .. " " .. tostring(bar.rows))
Check("both templates of a comma list", rawget(bar, "Glow") and table.concat(bar._templates, ",") == "BarTemplate,GlowTemplate",
	bar._templates and table.concat(bar._templates, ","))
local plain = CreateFrame("Frame", nil, UIParent, "NotKnownTemplate")
Check("an unknown template: the plain stand-in frame", rawget(plain, "Icon") == nil and rawget(plain, "_templates") == nil)
parts.Stop()
local after = CreateFrame("StatusBar", nil, UIParent, "BarTemplate")
Check("Stop: CreateFrame as it was", rawget(after, "Icon") == nil)

-- 2. The game's own recipes, per client.
for _, client in ipairs({ "forever", "retail" }) do
	local count, why = parts.Use(client)
	if not count then
		print("SKIP " .. client .. ": " .. tostring(why))
	else
		local spell = CreateFrame("StatusBar", "TestSpellBar_" .. client, UIParent, "TargetSpellBarTemplate")
		local got = {}
		for _, key in ipairs({ "Icon", "Spark", "Text", "TextBorder", "BorderShield", "Border" }) do
			if rawget(spell, key) then got[#got + 1] = key end
		end
		Check(client .. ": TargetSpellBarTemplate has its parts", #got == 6, table.concat(got, ","))
		Check(client .. ": the spark's atlas from the game's XML", rawget(spell, "Spark") and spell.Spark._part.atlas ~= nil,
			rawget(spell, "Spark") and spell.Spark._part.atlas)
		parts.Stop()

		-- The addon's own cast bar sample, built on the game's template now.
		local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function() parts.Use(client) end)
		-- (Each kind's own template, Style/PlateCastStyle.lua SAMPLE_KINDS.)
		for kind, template in pairs({ player = "CastingBarFrameTemplate", unit = "SmallCastingBarFrameTemplate",
			plate = "NamePlateCastingBarTemplate" }) do
			local ok, sample = pcall(ns.MakeCastLookSample, UIParent, kind)
			local made = ok and type(sample) == "table" and rawget(sample, "_templates")
			Check(("%s: the addon's %s cast sample is the game's %s, not the drawn fallback"):format(client, kind, template),
				made and made[#made] == template and rawget(sample.Icon, "_part") ~= nil,
				ok and (made and table.concat(made, ",") or "no template parts") or tostring(sample))
		end
		parts.Stop()
	end
end

print(fails == 0 and "all passed" or (fails .. " failed"))
if fails > 0 then os.exit(1) end
-- luacheck: pop
