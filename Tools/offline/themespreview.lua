-- The Themes page's rotating preview (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/themespreview.lua <forever|retail> < /dev/null
-- Style > Themes has General's rotating preview of its own (user 2026-11-20),
-- on the style lab's real-layout stand-in (Tools/style-lab/frames.lua):
--   the page has it, and it's its own, not General's;
--   it sits under the page's intro, over the theme picker (the Theme header
--   under it, nothing on it), as wide as General's;
--   a theme picked draws it again, General's too.
-- Says PASS or FAIL per check; exits 1 on any FAIL.
local F = dofile("Tools/style-lab/frames.lua")
local client = ... or "forever"

-- luacheck: push ignore 111 112 113 121 122 212
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function(w)
	F.Install(w)
	rawset(_G, "CreateFontFamily", false)
end)
-- luacheck: pop

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print(("%s %s: %s%s"):format(ok and "PASS" or "FAIL", client, name, detail and (" (" .. tostring(detail) .. ")") or ""))
end

if ns.MakeLazyPages then ns.MakeLazyPages("themespreview test") end
ns.OpenOptions("Style Themes")
if ns.ShowHubPage then ns.ShowHubPage("Style Themes") end

local preview = ns.themesStylePreview
Check("the Themes page has a rotating preview", preview ~= nil)
if not preview then os.exit(1) end
Check("its own, not General's", preview ~= ns.generalStylePreview)
Check("as wide as General's", ns.generalStylePreview == nil
	or math.abs(preview:GetWidth() - ns.generalStylePreview:GetWidth()) < 1,
	("%s vs %s"):format(tostring(preview:GetWidth()), tostring(ns.generalStylePreview and ns.generalStylePreview:GetWidth())))

-- (The page shown, as the settings window shows it: every frame up to the screen.)
local up = preview
while up and up ~= UIParent do
	up:Show()
	-- (One with no place of its own, the settings window's here: put on the screen.)
	if up:GetNumPoints() == 0 and up:GetParent() then
		up:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
		if (up:GetWidth() or 0) <= 0 then up:SetSize(800, 2000) end
	end
	up = up:GetParent()
end

-- (Room under the Themes row, as the page's sections have: its name sat right on
-- the tabs' line, user 2026-11-20. And 16 in from the page's left, as before.)
local content = preview:GetParent()
local line = content.pageTabs and content.pageTabs.panel
if line and line.GetBottom then
	local gap = line:GetBottom() - preview:GetTop()
	Check("room under the Themes row", gap >= 12 and gap <= 20, gap)
end
Check("16 in from the page's left", math.abs(preview:GetLeft() - content:GetLeft() - 16) < 1,
	preview:GetLeft() - content:GetLeft())

-- (Over the theme picker: the Theme header's top under the preview's bottom.)
local header
local function Find(frame)
	for _, region in ipairs({ frame:GetRegions() }) do
		if region.GetText and region:GetText() == ns.L["Theme"] then header = header or region end
	end
	for _, child in ipairs({ frame:GetChildren() }) do Find(child) end
end
Find(preview:GetParent())
Check("the Theme header is there", header ~= nil)
if header then
	local bottom, top = preview:GetBottom(), header:GetTop()
	Check("the preview over the theme picker, nothing on it", bottom and top and top <= bottom + 0.5,
		("preview bottom %s, header top %s"):format(tostring(bottom), tostring(top)))
end

-- (A theme picked draws both previews again.)
local drawn = { mine = 0, general = 0 }
local own, general = preview.Refresh, ns.generalStylePreview and ns.generalStylePreview.Refresh
preview.Refresh = function(self, ...) drawn.mine = drawn.mine + 1 return own(self, ...) end
if general then
	ns.generalStylePreview.Refresh = function(self, ...) drawn.general = drawn.general + 1 return general(self, ...) end
end
local db = ns.GetDB()
local themes = ns.StyleThemeList and ns.StyleThemeList() or {}
local pick = themes[2] and (themes[2].id or themes[2].key or themes[2][1]) or "slate"
if ns.ApplyStyleTheme then pcall(ns.ApplyStyleTheme, pick) end
db.styleTheme = db.styleTheme or pick
-- (The page's own Changed runs on a pick: a settings refresh draws it as the picker does.)
local ok, err = pcall(function() if ns.RefreshStylePreviews then ns.RefreshStylePreviews() end end)
Check("no error refreshing", ok, err)
preview:Refresh()
Check("it draws (no error)", drawn.mine >= 1)

if fails > 0 then
	print(("%d FAIL"):format(fails))
	os.exit(1)
end
print("all PASS")
