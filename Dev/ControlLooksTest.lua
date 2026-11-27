-- /cine debug controllooks: screenshots of every menu control as it really
-- looks, for normalizing them to one look (Tools/ui/control-map.md, the user
-- 2026-11-27: "map out all unique controls, then a test to get them"). Hands
-- off: nothing to click, nothing to answer. Each step in the HD menu look,
-- then again in SD; the look you had is put back at the end. Steps:
--   1 gallery-hd   the Control Gallery page (Dev hub), top to bottom: every
--                  control that can be made on its own (map ids B1...N1);
--                  each row's builder made it (PASS/FAIL per row)
--   2 menus-hd     each dropdown's and menu's list open, one shot each (D1-D6)
--   3 windows-hd   Cinematic's own windows, one shot each: Style Studio,
--                  Why Is It Showing?, Keyboard Map, Talent Calculator, the
--                  color picker, Find results, Rule editor, Welcome
--   4 pages-hd     the pages holding the controls only a page can make, each
--                  with every tab, top to bottom (ns.PageShots per page)
--   5-8            the same four in SD
-- About 20-30 minutes with the pages; /cine debug controllooks 1 2 3 5 6 7
-- (no pages) takes a few. Into CinematicDB.controlLooksTestLog. Dev copy only.
local _, ns = ...

-- The pages, as /cine debug pageshots takes their names (any page whose name
-- has the words): where each control the gallery can't make lives (the map's
-- "page" column).
local PAGES = {
	"1 1",               -- the CineMode page (the list's first): segments, pills, chips, rows
	"style general", "style themes", "tint style", "combat text style", "self text style",
	"nameplate style", "card style", "card vision", "cooldown manager", "why showing", "keybinds",
	"profiles", "mouseover groups", "cameras", "camera scripts", "triggers", "trigger priority",
	"camera settings", "shoulder cam", "game settings", "profiler", "favorites", "emote vision",
	"letterbox style", "socials", "damage vision look", "audio", "addon", "vitals vision", "heal vision",
}

local function Skin(r, skin)
	r:Keep("menuSkin", CinematicDB.menuSkin)
	CinematicDB.menuSkin = skin
	ns.ApplyMenuSkin(true)
	r:Log(("menu look: %s (ns.MenuSkin() = %s)"):format(skin, tostring(ns.MenuSkin())))
end

local function Settings() return _G.SettingsPanel or _G.InterfaceOptionsFrame end

-- The gallery, shot from its top down, a screenful at a time.
local function Gallery(r, skin)
	Skin(r, skin)
	local ok = pcall(ns.OpenOptions, "Control Gallery")
	r:Sleep(1.2)
	local g = ns.controlGallery
	if not (ok and g and g.canvas:IsVisible()) then
		r:Fail("the Control Gallery page didn't open")
		return
	end
	g.Fill()
	local made, failed = 0, 0
	for _, row in ipairs(g.rows) do
		if row.control then
			made = made + 1
		elseif not (row.studio and not (ns.Studio and ns.Studio.C)) then
			failed = failed + 1
			r:Fail(("%s %s: %s"):format(row.id, row.name, tostring(row.error or "not made")))
		end
	end
	r:Verdict(failed == 0, ("%d of %d gallery rows made by their builders (%s)"):format(made, #g.rows, skin))
	local scroll = g.scroll
	local range = scroll and scroll.GetVerticalScrollRange and scroll:GetVerticalScrollRange() or 0
	local view = scroll and scroll:GetHeight() or 400
	local step = math.max(100, view * 0.85)
	local parts = range < 4 and 1 or math.min(10, 1 + math.ceil(range / step))
	for part = 1, parts do
		if scroll then scroll:SetVerticalScroll(math.min(range, (part - 1) * step)) end
		r:Sleep(0.4)
		r:Shot(("gallery %s, part %d/%d"):format(skin, part, parts), { behind = Settings() })
	end
	if scroll then scroll:SetVerticalScroll(0) end
end

-- Each menu of the gallery open, one shot each.
local function Menus(r, skin)
	Skin(r, skin)
	pcall(ns.OpenOptions, "Control Gallery")
	r:Sleep(1)
	local g = ns.controlGallery
	if not g then
		r:Fail("no Control Gallery")
		return
	end
	g.Fill()
	for _, menu in ipairs(g.menus) do
		-- (Its row on screen first: a menu opens at its button.)
		local id = menu.label:match("^(%S+)")
		for _, row in ipairs(g.rows) do
			if row.id == id and row.frame and g.scroll then
				local top = (g.content:GetTop() or 0) - (row.frame:GetTop() or 0)
				g.scroll:SetVerticalScroll(math.max(0, math.min(g.scroll:GetVerticalScrollRange() or 0, top - 60)))
			end
		end
		r:Sleep(0.3)
		local ok, err = pcall(menu.open)
		r:Sleep(0.5)
		r:Verdict(ok, menu.label .. " opened" .. (ok and "" or (": " .. tostring(err))))
		r:Shot(("%s open, %s"):format(menu.label, skin), { behind = Settings() })
		menu.close()
		r:Sleep(0.3)
	end
	if g.scroll then g.scroll:SetVerticalScroll(0) end
end

-- What's on screen now that wasn't: the window just opened (to shoot and close).
local function Shown()
	local set = {}
	for _, child in ipairs({ UIParent:GetChildren() }) do
		if child.IsShown and child:IsShown() then set[child] = true end
	end
	return set
end
local function NewSince(before)
	local list = {}
	for _, child in ipairs({ UIParent:GetChildren() }) do
		if child.IsShown and child:IsShown() and not before[child] then list[#list + 1] = child end
	end
	return list
end

-- { name, open(), has() }: has() false (and why) skips it (a page that's off, a client without it).
local WINDOWS = {
	{ "Style Studio", function() ns.OpenStyleStudio() end, function() return ns.OpenStyleStudio ~= nil, "Style left out" end },
	{ "Why Is It Showing?", function() ns.ShowWhyWindow() end, function() return ns.ShowWhyWindow ~= nil, "not loaded" end },
	{ "Keyboard Map", function() ns.KeyboardMapOpen(true) end, function()
		return ns.KeyboardMapOpen ~= nil and ns.PageOn ~= nil and ns.PageOn("keyboardMap"),
			"its page is off (Keyboard Map, Enable Page)"
	end },
	{ "Talent Calculator", function() ns.ToggleTalentCalc() end,
		function() return ns.ToggleTalentCalc ~= nil, "not on this client" end },
	{ "Color picker", function() ns.OpenColorPicker(1, 0.82, 0, function() end) end,
		function() return ns.OpenColorPicker ~= nil, "not loaded" end },
	{ "Find results", function() ns.HandleSlash("find slider") end, function() return true end },
	{ "Rule editor", function()
		local rule = "always"
		ns.OpenRuleEditor({ label = "Control looks test", Text = function() return rule end,
			SetText = function(text) rule = text end, Close = function() end })
	end, function() return ns.OpenRuleEditor ~= nil, "not loaded" end },
	{ "Welcome", function() ns.ShowWelcome() end, function() return ns.ShowWelcome ~= nil, "not loaded" end },
}

local function Windows(r, skin)
	Skin(r, skin)
	local panel = Settings()
	if panel and panel:IsShown() then HideUIPanel(panel) end
	r:Sleep(0.6)
	for _, w in ipairs(WINDOWS) do
		local has, why = w[3]()
		if not has then
			r:Skip(w[1] .. ": " .. tostring(why))
		else
		local before = Shown()
		local ok, err = pcall(w[2])
		r:Sleep(1)
		local new = NewSince(before)
		r:Verdict(ok and #new > 0, ("%s: %s, %d new frame(s) on screen"):format(w[1],
			ok and "opened" or ("error " .. tostring(err)), #new))
		if #new > 0 then r:Shot(("%s window, %s"):format(w[1], skin), { behind = new }) end
		for _, frame in ipairs(new) do pcall(frame.Hide, frame) end
		ns.controlGallery.CloseMenus()
		r:Sleep(0.4)
		end
	end
end

-- The pages, each through ns.PageShots: every tab, top to bottom.
local function Pages(r, skin)
	Skin(r, skin)
	if not ns.PageShots then
		r:Skip("ns.PageShots isn't loaded (Style left out)")
		return
	end
	local shots = 0
	for _, words in ipairs(PAGES) do
		local db = ns.GetDB()
		local was = db.pageShots
		local ok, err = pcall(ns.PageShots, words)
		if not ok then
			r:Fail(("pages %q: %s"):format(words, tostring(err)))
		else
			local out = r:WaitFor(nil, { handsOff = true, check = function()
				local now = ns.GetDB().pageShots
				return now and now ~= was and now.done and now or nil
			end })
			local names = {}
			for _, page in ipairs(out.pages or {}) do
				names[#names + 1] = page.page .. (page.error and (" (" .. page.error .. ")") or "")
			end
			shots = shots + (out.shotCount or 0)
			r:Log(("pages %q, %s: %d shots, %s"):format(words, skin, out.shotCount or 0, table.concat(names, ", ")))
			r:Verdict((out.pageCount or 0) > 0, ("%q found %d page(s)"):format(words, out.pageCount or 0))
		end
	end
	r:Log(("%s pages: %d shots in all"):format(skin, shots))
end

ns.TestKit.Define({
	name = "controllooks",
	key = "controlLooksTest",
	title = "Control looks",
	about = "screenshots of every menu control (Control Gallery, its menus, windows, pages) in HD and SD, nothing to do",
	files = { "Dev/ControlGallery.lua", "Dev/ControlLooksTest.lua" },
	context = function()
		return ("menu look now: %s (saved %s)"):format(tostring(ns.MenuSkin()), tostring(CinematicDB.menuSkin))
	end,
	putBack = function(extra)
		if extra.menuSkin == nil then return "" end
		CinematicDB.menuSkin = extra.menuSkin ~= "<nil>" and extra.menuSkin or nil
		ns.ApplyMenuSkin(true)
		return "menu look put back: " .. tostring(CinematicDB.menuSkin or "auto")
	end,
	steps = {
		{ key = "gallery-hd", title = "Control Gallery, HD", handsOff = true, run = function(r) Gallery(r, "HD") end },
		{ key = "menus-hd", title = "its menus open, HD", handsOff = true, run = function(r) Menus(r, "HD") end },
		{ key = "windows-hd", title = "Cinematic's windows, HD", handsOff = true, run = function(r) Windows(r, "HD") end },
		{ key = "pages-hd", title = "the pages, HD", handsOff = true, run = function(r) Pages(r, "HD") end },
		{ key = "gallery-sd", title = "Control Gallery, SD", handsOff = true, run = function(r) Gallery(r, "SD") end },
		{ key = "menus-sd", title = "its menus open, SD", handsOff = true, run = function(r) Menus(r, "SD") end },
		{ key = "windows-sd", title = "Cinematic's windows, SD", handsOff = true, run = function(r) Windows(r, "SD") end },
		{ key = "pages-sd", title = "the pages, SD", handsOff = true, run = function(r) Pages(r, "SD") end },
	},
})
