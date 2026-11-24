-- The links between a frame's settings and its Style page (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/stylebacklinks.lua <forever|retail>
-- Every Style page a settings page links to (its palette, ns.StyleIcon) has
-- a gear back (ns.SettingsIcon, 2026-11-24): each page opened, its link icon
-- read (content.styleLinkIcons), where it goes checked against the table
-- below, and clicked. Says PASS or FAIL per check.
--   ... stylebacklinks.lua <client> nostyle: Style left out (Load Style
--   unticked) instead, Visions General showing no palette. Its own run: two
--   loads in one process ran it to 5 GB (2026-11-24).
local client = arg and arg[1] or "forever"
local noStyle = arg and arg[2] == "nostyle"
-- (The game's next frame: timers asked for as pages are made (at load) or
-- opened, run after. A page's header link waits for its page's name so.)
local timers = {}
local function RunTimers()
	local now = timers
	timers = {}
	for _, fn in ipairs(now) do pcall(fn) end
end
local ns, wow = dofile("Tools/offline/load.lua")(client, nil, function()
	if noStyle then CinematicDB = { loadStyle = false } end -- luacheck: ignore 111
	C_Timer.After = function(_, fn) timers[#timers + 1] = fn end -- luacheck: ignore 122
end)
RunTimers()
local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. text)
	if not ok then failed = failed + 1 end
end

-- Style left out: Visions General shows no palette to a Visions Style page
-- that isn't there (the release review, 2026-11-24: made a frame after the
-- page showed, its own OnShow check missed it).
if noStyle then
	Check(not ns.ModuleLoaded("style"), "Style left out: it didn't load")
	if ns.MakeLazyPages then ns.MakeLazyPages("stylebacklinks test") end
	ns.OpenOptions("Visions General")
	RunTimers()
	local canvas = ns.settingsCanvases and ns.settingsCanvases["Visions General"]
	local shown = 0
	for _, icon in ipairs(canvas and canvas.content.styleLinkIcons or {}) do
		if icon:IsShown() then shown = shown + 1 end
	end
	Check(canvas ~= nil and shown == 0, ("Style left out: Visions General shows no palette (%d shown)"):format(shown))
	-- (Every page built with Style left out, no Lua error: Card Types called
	-- Style's jumbotron, an error since v2.1.30.)
	local errors = {}
	for _, line in ipairs(CinematicDB.log or {}) do
		local text = tostring(type(line) == "table" and (line.text or line[2]) or line)
		if text:find("ERROR") then errors[#errors + 1] = text:sub(1, 200) end
	end
	Check(#errors == 0, ("Style left out: every page built, no Lua error (%d%s)"):format(#errors,
		errors[1] and (": " .. errors[1]) or ""))
	print(failed == 0 and "ALL PASS" or (failed .. " FAILED"))
	if failed > 0 then os.exit(1) end
	return
end

-- Style page = where its gear goes back to.
local BACK = {
	["Unit Style"] = "HUD:units", ["Unit Cast Style"] = "HUD:units", ["Player Cast Style"] = "HUD:units",
	["Personal Style"] = "HUD:prd", ["Raid Style"] = "HUD:party", ["Action Style"] = "HUD:bars",
	["Cooldown Manager Style"] = "HUD:cdm", ["Minimap Style"] = "HUD:minimap",
	["Bubble Style"] = "Chat bubbles", ["Tooltip Style"] = "Tooltips",
	["Nameplate Style"] = "Nameplates", ["Nameplate Marks"] = "Nameplates", ["Cast Bar Style"] = "Nameplates",
	["Name Style"] = "Nameplate Names",
	["Letterbox Style"] = "Letterbox", ["Tint Style"] = "Tint", ["Weather Style"] = "Weather",
	["Vitals Style"] = "Vitals Vision", ["Roll Style"] = "Roll Vision",
	["Quest Talk Style"] = "Quest Vision", ["Quest Item Style"] = "Quest Vision",
	["Damage Vision Look"] = "Damage Vision", ["Emote Vision Style"] = "Emote Vision",
	["Card Styles"] = "Card Vision", ["Visions Style"] = "Visions General",
}
-- Those going to a HUD icon with sub-tabs: the one each opens at.
local SECTION = { ["Unit Style"] = "units", ["Unit Cast Style"] = "units", ["Player Cast Style"] = "playercast" }
-- Style pages with no settings page to go back to: no gear.
local NONE = { "Combat Text Style", "Self Text Style", "Style General", "Style Themes", "Style Overrides",
	"Interface Recolor" }
-- Settings pages with a palette by their switch or tabs = its Style page
-- (the other way; a page under HUD:… has its palettes by its headings).
local FORWARD = {
	["Letterbox"] = "Letterbox Style", ["Tint"] = "Tint Style", ["Weather"] = "Weather Style",
	["Vitals Vision"] = "Vitals Style", ["Roll Vision"] = "Roll Style", ["Quest Vision"] = "Quest Talk Style",
	["Damage Vision"] = "Damage Vision Look", ["Emote Vision"] = "Emote Vision Style", ["Card Vision"] = "Card Styles",
	["Visions General"] = "Visions Style", ["Nameplates"] = "Nameplate Style", ["Nameplate Names"] = "Name Style",
	["Chat bubbles"] = "Bubble Style", ["Tooltips"] = "Tooltip Style", ["Minimap"] = "Minimap Style",
}

local function Open(name)
	if ns.MakeLazyPages then ns.MakeLazyPages("stylebacklinks test") end
	ns.OpenOptions(name)
	if ns.ShowHubPage then ns.ShowHubPage(name) end
	RunTimers() -- (a header link made the next frame)
	local canvas = ns.settingsCanvases and ns.settingsCanvases[name]
	return canvas and canvas.content
end
-- Its link of that kind (a page with two tab lines has two: Nameplates).
local function LinkOf(content, kind, page)
	for _, icon in ipairs(content and content.styleLinkIcons or {}) do
		if icon.linkKind == kind and (not page or icon.linkPage == page) then return icon end
	end
end
local function Sorted(map)
	local names = {}
	for name in pairs(map) do names[#names + 1] = name end
	table.sort(names)
	return names
end

local opened, missing = 0, {}
local function LinkCheck(page, kind, want)
	if not (ns.settingsCanvases and ns.settingsCanvases[page]) then
		missing[#missing + 1] = page -- (not on this client)
		return
	end
	local content = Open(page)
	opened = opened + 1
	local icon = LinkOf(content, kind, want)
	local any = content and content.styleLinkIcons and content.styleLinkIcons[1]
	Check(icon ~= nil, ("%s: a %s link to %s (first link: %s to %s)"):format(page, kind, want,
		tostring(any and any.linkKind), tostring(any and any.linkPage)))
	if icon and ns.PageMade(want) then
		-- (A HUD sub-tab: another picked first, so a gear going by the last
		-- one picked lands wrong. The user, 2026-11-24: Your Cast Bar's opened
		-- Unit frames.)
		local section = kind == "settings" and SECTION[page]
		if section and ns.OpenFramesSection then
			ns.OpenFramesSection(section == "highlight" and "units" or "highlight")
		end
		local ok, err = pcall(icon:GetScript("OnClick"), icon, "LeftButton")
		Check(ok, page .. ": its link opens " .. want .. (ok and "" or (" (" .. tostring(err) .. ")")))
		if section then
			local now = ns.FramesSectionOpen and ns.FramesSectionOpen()
			Check(now == section, ("%s: at the %s sub-tab (%s)"):format(page, section, tostring(now)))
		end
	end
end

for _, page in ipairs(Sorted(BACK)) do LinkCheck(page, "settings", BACK[page]) end
for _, page in ipairs(Sorted(FORWARD)) do LinkCheck(page, "style", FORWARD[page]) end
for _, page in ipairs(NONE) do
	if ns.settingsCanvases and ns.settingsCanvases[page] then
		local content = Open(page)
		Check(LinkOf(content, "settings") == nil, page .. ": no gear (nowhere to go back to)")
	end
end
-- Visions General's Load Visions box past its palette, not on it (the
-- in-game run's one fail, 2026-11-24: placed by the switch, under the palette).
do
	local content = Open("Visions General")
	local canvas = ns.settingsCanvases and ns.settingsCanvases["Visions General"]
	local palette = LinkOf(content, "style", "Visions Style")
	local load = canvas and canvas.loadVisionsBox
	-- (The stand-in keeps no points: where it's put, caught as the page shows again.)
	local to
	if load then
		local SetPoint = load.SetPoint
		load.SetPoint = function(self, point, rel, ...)
			if point == "LEFT" then to = rel end
			return SetPoint(self, point, rel, ...)
		end
		local OnShow = content:GetScript("OnShow")
		if OnShow then pcall(OnShow, content) end
		load.SetPoint = nil
	end
	Check(palette ~= nil and to == palette, "Visions General: Load Visions goes right of the palette (" ..
		tostring(to and (to == palette and "palette" or to == content.pageSwitch and "switch" or "other")) .. ")")
end
-- Every Style hub page is in one of the lists: a new one says where it goes back to.
-- (Its icons, and each icon's tabs.)
local stylePages = {}
for _, icon in ipairs(ns.HubIcons("Style")) do
	if not icon.dev then
		stylePages[#stylePages + 1] = icon.name
		for _, tab in ipairs(ns.HubTabsOf("Style", icon.name)) do stylePages[#stylePages + 1] = tab[2] end
	end
end
Check(#stylePages >= 20, ("the Style hub's pages read (%d)"):format(#stylePages))
for _, page in ipairs(stylePages) do
	local known = BACK[page] ~= nil
	for _, none in ipairs(NONE) do known = known or none == page end
	Check(known, page .. " is in this test's lists")
end

if #missing > 0 then print("SKIP not on " .. client .. ": " .. table.concat(missing, ", ")) end
for _, text in ipairs(wow.warnings or {}) do print("WARN " .. text) end
Check(opened >= 30, ("opened %d pages"):format(opened))
print(failed == 0 and "ALL PASS" or (failed .. " FAILED"))
if failed > 0 then os.exit(1) end
