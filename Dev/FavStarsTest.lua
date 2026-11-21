-- /cine debug favstars [words]: every settings page's Favorites star, looked
-- at as drawn. The star sits at one spot on every page, left of its "Search
-- this page" box (2026-11-20, after placing it by each title failed page
-- after page). It opens each page and hub icon in turn by itself (settings
-- closed first, CineMode off; pauses in a fight; words: only pages whose
-- names have one), a page that's off turned on first (its switch and every
-- one above it) and put back after, and for each says:
--   one star shown, left of its search box (right edge at the box's left,
--   centers level), inside its page frame
--   where it says you are (ns.FavoriteHere): that page, and its open tabs
--   everything drawn it overlaps (0 wanted), by type and text
-- PASS when all hold; FAIL otherwise, with a screenshot (one a page, a
-- second apart: two in one second save one file). Summary at the end.
-- Into CinematicDB.favStarsTestLog. Run again to stop. Dev copy only.
local _, ns = ...

local run

local function Say(text)
	local log = CinematicDB and CinematicDB.favStarsTestLog
	if log then log[#log + 1] = text end
end
local function Shot(what)
	local ok = pcall(function() Screenshot() end)
	Say(("    screenshot %s at %s%s"):format(what, date("%m%d%y_%H%M%S"), ok and "" or " (failed)"))
end

-- What a thing on the page is, in a few words.
local function Desc(object)
	if not object then return "nothing" end
	local kind = object.GetObjectType and object:GetObjectType() or "?"
	local text = object.GetText and select(2, pcall(object.GetText, object))
	if type(text) ~= "string" or text == "" then
		local label = object.text or object.Text or object.label
		text = type(label) == "table" and label.GetText and label:GetText() or nil
	end
	local name = object.GetDebugName and select(2, pcall(object.GetDebugName, object))
	name = type(name) == "string" and name:gsub("^.*%.", "") or nil
	return ("%s%s%s"):format(kind, text and text ~= "" and (" \"" .. text:sub(1, 30) .. "\"") or "",
		name and name ~= "" and (" (" .. name .. ")") or "")
end

-- A thing's box in frame's units (a scaled frame gives its place in its own
-- units: unconverted, a scaled preview's parts read as somewhere else).
local function Scale(object)
	local ok, scale = pcall(object.GetEffectiveScale, object)
	if ok and type(scale) == "number" and scale > 0 then return scale end
	local parent = object.GetParent and object:GetParent()
	return parent and Scale(parent) or 1
end
local function Box(object, frame)
	local l, r, t, b = object:GetLeft(), object:GetRight(), object:GetTop(), object:GetBottom()
	if not (l and r and t and b) then return nil end
	if object:IsObjectType("FontString") then
		local text = object:GetText()
		if not text or text == "" then return nil end
		r = math.min(r, l + (object:GetStringWidth() or 0) + 1)
	end
	local k = Scale(object) / Scale(frame)
	return l * k, r * k, t * k, b * k
end

-- Everything drawn on the star's frame that its box overlaps by more than
-- TOUCH pixels both ways (textures and text; not frames, which draw nothing
-- themselves, nor masks; not what holds the star's whole box, a background;
-- a text's box is taller than its letters, so up to TOUCH is said as
-- touching, not counted). And the star outside its frame: said first.
local TOUCH = 2
local function Overlaps(star)
	local frame = star:GetParent()
	local l, r, t, b = Box(star, frame)
	if not l then return { "the star has no place" }, {} end
	local found, touching = {}, {}
	local fl, fr, ft, fb = Box(frame, frame)
	if fl and (l < fl - 1 or r > fr + 1 or t > ft + 1 or b < fb - 1) then
		found[1] = ("OUT OF ITS FRAME (star %d,%d to %d,%d; frame %d,%d to %d,%d)"):format(l, t, r, b, fl, ft, fr, fb)
	end
	local function Look(object)
		if object == star or not object:IsVisible() or object:IsObjectType("MaskTexture") then return end
		local ol, or_, ot, ob = Box(object, frame)
		if not ol then return end
		if ol <= l and or_ >= r and ot >= t and ob <= b then return end
		local wide = math.min(r, or_) - math.max(l, ol)
		local tall = math.min(t, ot) - math.max(b, ob)
		if wide <= 0 or tall <= 0 then return end
		local line = ("%s (%.1f x %.1f px)"):format(Desc(object), wide, tall)
		if wide <= TOUCH or tall <= TOUCH then touching[#touching + 1] = line else found[#found + 1] = line end
	end
	local function Walk(each, depth)
		for _, region in ipairs({ each:GetRegions() }) do Look(region) end
		if depth >= 6 then return end
		for _, child in ipairs({ each:GetChildren() }) do
			if child ~= star and child:IsVisible() then Walk(child, depth + 1) end
		end
	end
	Walk(frame, 1)
	return found, touching
end
-- Whether the star sits left of its search box: right edge at the box's
-- drawn border (6 apart, as placed), centers level. Gives the gap and the drop.
local function BesideBox(star)
	local box = star.box
	local frame = star:GetParent()
	local l, r, t, b = Box(star, frame)
	local _, _, bt, bb = Box(box, frame)
	local bl = Box(star.edge or box, frame) -- (the box's drawn border)
	if not (l and bl) then return false, "no place" end
	local gap, drop = bl - r, math.abs((t + b) / 2 - (bt + bb) / 2)
	return gap >= 4 and gap <= 8 and drop <= 2, ("%.1f px left of the box, centers %.1f px apart"):format(gap, drop)
end

-- Why a page has no star: its search box (a hub's or its own), if any.
local function NoStarWhy(name)
	local canvas = ns.settingsCanvases and ns.settingsCanvases[name]
	if not canvas then return "no page frame of its own (shown by another page)" end
	local box = canvas.searchBox
	return box and ("its search box %s, star %s"):format(box:IsVisible() and "shown" or "hidden",
		box.favoriteStar and "made" or "never made") or "no search box of its own"
end

-- Every page by its English name: each hub's icons in order, then the
-- other pages with frames of their own.
local function Pages()
	local list, seen = {}, { Favorites = true }
	local function Add(name)
		if type(name) == "string" and not seen[name] then
			seen[name] = true
			list[#list + 1] = name
		end
	end
	for _, hub in ipairs(ns.HubNames()) do
		for _, icon in ipairs(ns.HubIcons(hub)) do Add(icon.name) end
	end
	local rest = {}
	for name in pairs(ns.settingsCanvases or {}) do rest[#rest + 1] = name end
	table.sort(rest)
	for _, name in ipairs(rest) do Add(name) end
	return list
end

-- A page turned on for its look: each switch it goes by (its own, or each
-- of its group's: ns.PageSwitchKeys) and every one above each
-- (ns.PageSwitchOf, the Style switch chain). Gives how to put it back.
-- (2026-11-20: a page off draws its off card, not its title row as in use.)
local function TurnOn(name)
	local undo = { keys = {} }
	local db = ns.GetDB and ns.GetDB()
	if not (db and ns.PageSwitchOff and ns.PageSwitchOff(name)) then return undo end
	local done = {}
	for _, own in ipairs(ns.PageSwitchKeys and ns.PageSwitchKeys(name) or {}) do
		local key = own
		for _ = 1, 12 do
			if not key or done[key] then break end
			done[key] = true
			if db[key] ~= true then
				undo.keys[#undo.keys + 1] = { key = key, was = db[key] }
				db[key] = true
			end
			key = ns.PageSwitchOf and ns.PageSwitchOf(key)
		end
	end
	if #undo.keys > 0 and ns.RefreshOptions then ns.RefreshOptions() end
	undo.on = not ns.PageSwitchOff(name)
	return undo
end
local function PutBack(_, undo)
	if not undo then return end
	local db = ns.GetDB and ns.GetDB()
	for i = #undo.keys, 1, -1 do
		local each = undo.keys[i]
		if db then db[each.key] = each.was end
	end
	if #undo.keys > 0 and ns.RefreshOptions then ns.RefreshOptions() end
end
local function Turned(undo)
	if not (undo and #undo.keys > 0) then return "" end
	local keys = {}
	for _, each in ipairs(undo.keys) do keys[#keys + 1] = each.key end
	return (" [was off: turned on %s%s]"):format(table.concat(keys, ", "), undo.on and "" or ", STILL OFF")
end

local function Finish(text)
	if not run then return end
	local this = run
	run = nil
	PutBack(this.name, this.undo)
	Say(("--- summary: %d pages, %d PASS, %d FAIL, %d with no star ---"):format(#this.pages, this.pass, this.fail,
		#this.none))
	for _, line in ipairs(this.failed) do Say("  FAIL " .. line) end
	for _, line in ipairs(this.none) do Say("  no star " .. line) end
	Say(text)
	if _G.SettingsPanel and _G.SettingsPanel:IsShown() and HideUIPanel and not InCombatLockdown() then
		pcall(HideUIPanel, _G.SettingsPanel)
	end
	ns.TestPrompt(("Favorites stars sweep %s: %d PASS, %d FAIL, %d no star. Say \"check log\"."):format(text, this.pass,
		this.fail, #this.none), 12)
end

local function Next()
	if not run then return end
	if InCombatLockdown() then
		ns.TestPrompt("Favorites stars sweep: paused for the fight.", 3)
		return C_Timer.After(1, Next)
	end
	run.i = run.i + 1
	local name = run.pages[run.i]
	if not name then return Finish("DONE") end
	ns.TestPrompt(("Favorites stars sweep: %d of %d, %s. Just watch."):format(run.i, #run.pages, name), 2)
	local fine0, undo = pcall(TurnOn, name)
	if not fine0 then Say(("%s: turning it on: error %s"):format(name, tostring(undo))) undo = nil end
	run.name, run.undo = name, undo
	local ok, err = pcall(ns.OpenOptions, name)
	if not ok then Say(("%s: OpenOptions error %s"):format(name, tostring(err))) end
	C_Timer.After(0.6, function()
		if not run then return end
		local shown = {}
		for _, star in ipairs(ns.FavoriteStars()) do
			if star:IsVisible() then shown[#shown + 1] = star end
		end
		local page = ns.ShownOptionsPage and ns.ShownOptionsPage()
		local turned = Turned(undo)
		local function Done(seconds)
			PutBack(name, undo)
			run.undo = nil
			C_Timer.After(seconds, Next)
		end
		if #shown == 0 then
			local why = ("%s (page shown %q): %s%s"):format(name, tostring(page), NoStarWhy(page or name), turned)
			run.none[#run.none + 1] = why
			Say("no star " .. why)
			return Done(0.2)
		end
		local star = shown[1]
		local over, touching = Overlaps(star)
		local beside, where = BesideBox(star)
		-- Where it says you are: the page opened (a hub icon's frame goes by
		-- the icon's name: Standard Frames is the HUD's General icon; an old
		-- name opens another page: Card Style, the Card Vision icon).
		local here = ns.FavoriteHere and ns.FavoriteHere()
		local at = here and here.page
		local canvas = ns.settingsCanvases and ns.settingsCanvases[name]
		local shownCanvas = ns.settingsCanvases and ns.settingsCanvases[page or false]
		local same = at == name or at == page
			or (canvas and ns.HubTileShowing and ns.HubTileShowing(canvas) == at)
			or (shownCanvas and ns.HubTileShowing and ns.HubTileShowing(shownCanvas) == at)
		local tabs = {}
		for _, tab in ipairs(here and here.tabs or {}) do tabs[#tabs + 1] = tostring(tab.label) end
		local fine = #shown == 1 and beside and same and #over == 0
		Say(("%s %s: %s; here %q%s; %s; overlaps %s%s"):format(fine and "PASS" or "FAIL", name,
			#shown > 1 and (#shown .. " STARS SHOWN") or "one star", tostring(at),
			#tabs > 0 and (" at " .. table.concat(tabs, " > ")) or "", where,
			#over > 0 and table.concat(over, "; ") or "nothing", turned))
		if touching and #touching > 0 then Say("    touching (box edges, not counted): " .. table.concat(touching, "; ")) end
		if fine then
			run.pass = run.pass + 1
			return Done(0.2)
		end
		run.fail = run.fail + 1
		run.failed[#run.failed + 1] = ("%s: here %q, %s, overlaps %s"):format(name, tostring(at), where,
			#over > 0 and table.concat(over, "; ") or "nothing")
		Shot(name)
		Done(1.2) -- (a second before the next screenshot)
	end)
end

function ns.FavStarsTest(words)
	if run then return Finish("stopped") end
	if not (CinematicDB and ns.FavoriteStars and ns.HubNames and ns.OpenOptions) then
		ns.Print("/cine debug favstars: the settings or Favorites aren't there.")
		return
	end
	if InCombatLockdown() then
		ns.Print("/cine debug favstars: start it out of a fight.")
		return
	end
	CinematicDB.favStarsTestLog = {}
	-- (words: only the pages whose English names have one of them, any case)
	local pages, wanted = Pages(), {}
	for word in tostring(words or ""):gmatch("%S+") do wanted[#wanted + 1] = word:lower() end
	if #wanted > 0 then
		local kept = {}
		for _, name in ipairs(pages) do
			for _, word in ipairs(wanted) do
				if name:lower():find(word, 1, true) then kept[#kept + 1] = name break end
			end
		end
		pages = kept
	end
	run = { pages = pages, i = 0, pass = 0, fail = 0, none = {}, failed = {} }
	if ns.IsCineModeOn and ns.IsCineModeOn() and Cinematic_ToggleCineMode then pcall(Cinematic_ToggleCineMode) end
	Say(("start %s: %s (game %s), %d pages"):format(date("%H:%M:%S"), ns.isRetail and "retail" or "Forever",
		tostring((select(4, GetBuildInfo()))), #run.pages))
	C_Timer.After(0.5, Next)
end
