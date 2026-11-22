-- /cine debug profileparts: picking Auto-Hide UI or Blank Slate leaves
-- Visions and Cameras out (their Load boxes unticked) and asks to reload with
-- the Load boxes' own Reload box (ns.AskModulesReload, Modules.lua: same box,
-- same words, where the game puts its boxes); another built-in ticks them
-- back (ns.ProfilePartsPicked, Profiles/Profiles.lua). Through the real
-- Reload UI button both ways: your two clicks (three if they start left out).
-- (Run 1, 2026-11-22: the box had a spot of its own, under the welcome window:
-- "look at where we display it for others", so it's the shared box now. Run 2:
-- both were already left out, the pick changed nothing, no box came, and it
-- waited on one: now loaded first, and never a wait with no box.) Steps:
--   1 ready    any left out at the start: all ticked, the box says load
--              them; you click Reload UI (none: no reload)
--   (Run 4, 2026-11-22: "make the windows popout at the same location": the
--   boxes all open at the game's spot. Moving the window under each box was
--   wrong: "the cine welcome windows moves down each time a popup shows".
--   Now the window stays put and the box draws over it (the window one layer
--   under the game's boxes). Steps 2 and 4 put the window high, as a drag
--   would, so the box lands on it.)
--   2 pick     the welcome window open, Auto-Hide UI's card clicked: both
--              wanted out; the box up, the Load boxes' one, its words, the
--              game's spot and layer (as the game's other boxes), clear of
--              the window (shot); you click Reload UI in it
--   3 leftout  after that reload: neither loaded, the copy of their defaults
--              kept, still Auto-Hide UI; Balanced's card: both wanted, the
--              box says load them (shot); you click Reload UI again
--   4 back     after it: both loaded, the copy gone, on Balanced; then
--              /cine profile blank slate (the box, no welcome window) and
--              /cine profile balanced (no box: nothing to reload)
-- Your profile and both Load boxes put back at the end. (Stopped while
-- they're out: wanted again, from your next /reload.)
-- Into CinematicDB.profilePartsTestLog. Dev copy only.
local _, ns = ...

-- (Style too since 2026-11-22, where the copy has it: Modules.lua's parts.)
local PARTS = {}
for _, part in ipairs({ "visions", "cameras", "style" }) do
	if ns.MODULE_KEYS and ns.MODULE_KEYS[part] then PARTS[#PARTS + 1] = part end
end
local LOAD_WORDS = { visions = "load Visions", cameras = "load the cameras", style = "load Style" }
local LEAVE_WORDS = { visions = "leave Visions out", cameras = "leave the cameras out", style = "leave Style out" }
local function Words(lead, kind)
	local list = lead and { lead } or {}
	for _, part in ipairs(PARTS) do list[#list + 1] = (kind == "load" and LOAD_WORDS or LEAVE_WORDS)[part] end
	return list
end
local TOUCHED = { "Auto-Hide UI", "Balanced", "Blank Slate" }

local function Copy(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in pairs(t) do out[k] = Copy(v) end
	return out
end

local function Data()
	CinematicDB.profilePartsTestData = CinematicDB.profilePartsTestData or {}
	return CinematicDB.profilePartsTestData
end

local function Popup(which)
	return StaticPopup_FindVisible and StaticPopup_FindVisible(which or ns.MODULES_RELOAD_POPUP)
end

local function PopupText(popup)
	local t = popup and (popup.text or popup.Text or (popup:GetName() and _G[popup:GetName() .. "Text"]))
	local text = t and t.GetText and t:GetText()
	return type(text) == "string" and text or ""
end

-- The frame's edges in screen pixels (scales apart); nil if not placed.
local function Edges(frame)
	if not frame then return nil end
	local s = frame:GetEffectiveScale()
	local l, b, w, h = frame:GetRect()
	if not (l and b and w and h) then return nil end
	return { left = l * s, bottom = b * s, right = (l + w) * s, top = (b + h) * s }
end

local function Overlaps(a, b)
	return a and b and a.left < b.right and b.left < a.right and a.bottom < b.top and b.bottom < a.top
end

local function Cards()
	local list, byName = ns.WelcomeCards and ns.WelcomeCards() or {}, {}
	for i, level in ipairs(ns.WELCOME_LEVELS or {}) do byName[level.profile] = list[i] end
	return byName
end

-- The welcome window high, as if you'd dragged it up: right where the
-- game's boxes open. Its top (screen pixels).
local function WindowHigh()
	local welcome = rawget(_G, "CinematicWelcome")
	if not welcome then return nil end
	welcome:ClearAllPoints()
	welcome:SetPoint("TOP", UIParent, "TOP", 0, -60)
	local e = Edges(welcome)
	return e and e.top
end

-- The window stays where it was while the box is up, and the box draws over
-- it (a higher layer).
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6,
	FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local function CheckStill(r, what, popup, highTop)
	local welcome = rawget(_G, "CinematicWelcome")
	local box, win = Edges(popup), Edges(welcome)
	local boxLayer, winLayer = popup:GetFrameStrata(), welcome and welcome:GetFrameStrata()
	r:Fields(what .. " window", {
		top = function() return win and math.floor(win.top + 0.5) end,
		was = function() return highTop and math.floor(highTop + 0.5) end,
		boxBottom = function() return box and math.floor(box.bottom + 0.5) end,
		layers = function() return ("box %s, window %s"):format(tostring(boxLayer), tostring(winLayer)) end,
	})
	if not (win and highTop) then
		r:Log(what .. ": the window's place unreadable (offline): not checked")
	else
		r:Verdict(math.abs(win.top - highTop) < 2,
			("%s: the welcome window stayed put (top %.0f, was %.0f)"):format(what, win.top, highTop))
	end
	r:Verdict((STRATA[boxLayer] or 0) > (STRATA[winLayer] or 0),
		("%s: the box draws over the window (box %s, window %s)"):format(what, tostring(boxLayer), tostring(winLayer)))
end

local function Wanted(r, want, what)
	for _, part in ipairs(PARTS) do
		local key = ns.MODULE_KEYS[part]
		r:Verdict(ns.ModuleWanted(part) == want, ("%s: %s %s (CinematicDB.%s = %s, loaded %s)"):format(what, part,
			want and "wanted" or "left out", key, tostring(CinematicDB[key]), tostring(ns.ModuleLoaded(part))))
	end
end

local function Loaded(r, want, what)
	for _, part in ipairs(PARTS) do
		r:Verdict(ns.ModuleLoaded(part) == want, ("%s: %s %s"):format(what, part, want and "loaded" or "not loaded"))
	end
end

-- The box: the Load boxes' (one name), its words, the game's own spot and
-- layer: where the game's first box sits (StaticPopup1, its strata as made),
-- and, with the welcome window open, not on it.
local function CheckBox(r, what, words)
	local popup = Popup()
	local text = PopupText(popup)
	local edges = Edges(popup)
	r:Fields(what .. " box", {
		found = function() return popup ~= nil end,
		name = function() return popup and popup:GetName() end,
		strata = function() return popup and popup:GetFrameStrata() end,
		at = function() return edges and ("%.0f,%.0f-%.0f,%.0f"):format(edges.left, edges.bottom, edges.right, edges.top) end,
		point = function()
			if not popup then return nil end
			local p, rel, rp, x, y = popup:GetPoint(1)
			return ("%s %s %s %s %s"):format(tostring(p), rel and rel.GetName and rel:GetName() or tostring(rel),
				tostring(rp), tostring(x), tostring(y))
		end,
		text = function() return text end,
		cover = function() local c = ns.ReloadCover and ns.ReloadCover() return c and c:IsVisible() end,
		others = function()
			local n = 0
			for i = 1, (_G.STATICPOPUP_NUMDIALOGS or 4) do
				local d = _G["StaticPopup" .. i]
				if d and d:IsShown() and d ~= popup then n = n + 1 end
			end
			return n
		end,
	})
	r:Verdict(popup ~= nil, what .. ": the Load boxes' Reload box is up (" .. tostring(ns.MODULES_RELOAD_POPUP) .. ")")
	if not popup then return nil end
	local ok = true
	for _, word in ipairs(words) do
		if not text:find(word, 1, true) then ok = false end
	end
	r:Verdict(ok, ("%s: says %s: %s"):format(what, table.concat(words, " + "), text))
	r:Verdict(popup:GetFrameStrata() == "DIALOG", what .. ": the game's layer for its boxes: " .. tostring(popup:GetFrameStrata()))
	-- (The game's spot: the first of its boxes, top middle, as the Edit Mode
	-- box in the user's screenshot.)
	-- (Under another of the game's boxes when one's up first: the game stacks
	-- them, run 4 had a group invite.)
	local p, rel = popup:GetPoint(1)
	local relName = rel and rel.GetName and rel:GetName() or ""
	r:Verdict(p == "TOP" and (rel == UIParent or rel == nil or relName:find("^StaticPopup%d") ~= nil),
		("%s: at the game's spot (top middle, or under its box before: %s), not moved"):format(what, relName))
	local welcome = rawget(_G, "CinematicWelcome")
	if welcome and welcome:IsShown() then
		local win = Edges(welcome)
		r:Log(("%s: box %.0f-%.0f, window %.0f-%.0f high, on it %s (fine: the box draws over it)"):format(
			what, edges and edges.bottom or -1, edges and edges.top or -1, win and win.bottom or -1, win and win.top or -1,
			tostring(Overlaps(edges, win))))
	end
	return popup
end

-- You click Reload UI in the box (the real button: on Forever the secure one
-- over it): the run picks up at the next step after the reload.
local function ClickReload(r, popup)
	if not (popup and popup:IsShown()) then
		r:Fail("no Reload box up: no reload to click, the rest can't run")
		return
	end
	r:SaveResume()
	Data().reloadAsked = time()
	r:WaitFor("Click Reload UI in the game's box.", { check = function() return false end })
	-- (Never here: the reload ends the run's session. Still waiting: no reload.)
	r:Fail("no reload: " .. tostring(popup and popup:IsShown()))
end

ns.TestKit.Define({
	name = "profileparts",
	key = "profilePartsTest",
	title = "Profiles leave out Visions, Cameras and Style",
	about = "Auto-Hide UI leaves Visions + Cameras out, Balanced loads them: two clicks on Reload UI",
	settings = { "fadeUI" },
	context = function()
		local each = {}
		for _, part in ipairs(PARTS) do
			each[#each + 1] = ("%s loaded %s wanted %s"):format(part, tostring(ns.ModuleLoaded(part)), tostring(ns.ModuleWanted(part)))
		end
		return ("profile %s; %s; defaults copy %s"):format(tostring(ns.ActiveProfile and ns.ActiveProfile()),
			table.concat(each, "; "), tostring(CinematicDB.moduleDefaults ~= nil))
	end,
	putBack = function(extra)
		if StaticPopup_Hide then StaticPopup_Hide(ns.MODULES_RELOAD_POPUP) end
		local welcome = rawget(_G, "CinematicWelcome")
		if welcome and welcome:IsShown() then welcome:Hide() end
		local said = {}
		if type(extra.profile) == "string" and ns.ActiveProfile() ~= extra.profile and not InCombatLockdown() then
			ns.SetProfile(extra.profile)
			said[#said + 1] = "profile " .. extra.profile
		end
		for _, name in ipairs(TOUCHED) do
			local saved = extra["saved:" .. name]
			if saved ~= nil and ns.db.profiles then ns.db.profiles[name] = saved ~= false and Copy(saved) or nil end
		end
		local reload = false
		for _, part in ipairs(PARTS) do
			local was = extra["wanted:" .. part]
			if was ~= nil and ns.ModuleWanted(part) ~= was then
				ns.SetModuleWanted(part, was)
				said[#said + 1] = ("%s %s"):format(part, was and "wanted" or "left out")
			end
			if ns.ModuleWanted(part) ~= ns.ModuleLoaded(part) then reload = true end
		end
		ns.db.fadeUI = false
		CinematicDB.profilePartsTestData = nil
		if reload then said[#said + 1] = "takes your next /reload" end
		return #said > 0 and ("put back: " .. table.concat(said, ", ")) or "profile and Load boxes as they were"
	end,
	steps = {
		{ key = "ready", title = "all loaded to start", run = function(r)
			r:Keep("profile", ns.ActiveProfile())
			for _, part in ipairs(PARTS) do r:Keep("wanted:" .. part, ns.ModuleWanted(part)) end
			for _, name in ipairs(TOUCHED) do
				local saved = ns.db.profiles and ns.db.profiles[name]
				r:Keep("saved:" .. name, saved and Copy(saved) or false)
			end
			CinematicDB.profilePartsTestData = nil
			local out = {}
			for _, part in ipairs(PARTS) do
				if not ns.ModuleLoaded(part) then out[#out + 1] = part end
			end
			if #out == 0 then
				r:Pass("all loaded already: no reload first")
				return
			end
			r:Log("left out at the start: " .. table.concat(out, ", ") .. "; all ticked, a reload first")
			for _, part in ipairs(PARTS) do ns.SetModuleWanted(part, true) end
			ns.AskModulesReload()
			local words = {}
			for _, part in ipairs(out) do words[#words + 1] = LOAD_WORDS[part] end
			local popup = CheckBox(r, "Loading them", words)
			ClickReload(r, popup)
		end },
		{ key = "pick", title = "Auto-Hide UI on the welcome window", run = function(r)
			if not ns.ProfileChosen() then
				r:Fail("no profile picked yet on this character: the first pick asks about game settings first")
				return
			end
			Loaded(r, true, "to start")
			r:Verdict(CinematicDB.moduleDefaults == nil, "no copy of their defaults while they're loaded")
			ns.ShowWelcome()
			r:Sleep(0.5)
			local cards = Cards()
			-- (Already on Auto-Hide UI: Balanced first, so the click picks it.)
			if ns.ActiveProfile() == "Auto-Hide UI" and cards.Balanced then
				cards.Balanced:Click()
				r:Sleep(0.3)
			end
			if not cards["Auto-Hide UI"] then
				r:Fail("no Auto-Hide UI card on the welcome window")
				return
			end
			local highTop = WindowHigh()
			r:Log(("the welcome window put high (as a drag would): top %.0f"):format(highTop or -1))
			cards["Auto-Hide UI"]:Click()
			ns.db.fadeUI = false
			r:Sleep(0.5)
			r:Verdict(ns.ActiveProfile() == "Auto-Hide UI", "Auto-Hide UI picked: " .. tostring(ns.ActiveProfile()))
			Wanted(r, false, "Auto-Hide UI")
			local copied = type(CinematicDB.moduleDefaults) == "table"
			for _, part in ipairs(PARTS) do copied = copied and CinematicDB.moduleDefaults[part] ~= nil end
			r:Verdict(copied, "every part's defaults copied as they're switched off")
			local popup = CheckBox(r, "Auto-Hide UI", Words("Auto-Hide UI: ", "leave"))
			if popup then CheckStill(r, "Auto-Hide UI", popup, highTop) end
			if popup then r:Shot("the box with the welcome window", { behind = { popup, rawget(_G, "CinematicWelcome") } }) end
			ClickReload(r, popup)
		end },
		{ key = "leftout", title = "left out, then Balanced", run = function(r)
			r:Log(("reloaded %s s after the box"):format(tostring(Data().reloadAsked and (time() - Data().reloadAsked))))
			Loaded(r, false, "after Reload UI")
			Wanted(r, false, "after Reload UI")
			r:Verdict(ns.ActiveProfile() == "Auto-Hide UI", "still Auto-Hide UI: " .. tostring(ns.ActiveProfile()))
			local kept = type(CinematicDB.moduleDefaults) == "table"
			for _, part in ipairs(PARTS) do kept = kept and CinematicDB.moduleDefaults[part] ~= nil end
			r:Verdict(kept, "their defaults' copy kept while they're out")
			r:Verdict(not ns.settingsCanvases or ns.settingsCanvases["Roll Vision"] == nil, "Visions' pages gone")
			r:Verdict(not ns.settingsCanvases or ns.settingsCanvases["Scenes"] == nil, "Cameras' pages gone")
			ns.ShowWelcome()
			r:Sleep(0.5)
			local cards = Cards()
			if not cards.Balanced then
				r:Fail("no Balanced card on the welcome window")
				return
			end
			cards.Balanced:Click()
			ns.db.fadeUI = false
			r:Sleep(0.5)
			r:Verdict(ns.ActiveProfile() == "Balanced", "Balanced picked: " .. tostring(ns.ActiveProfile()))
			Wanted(r, true, "Balanced")
			local popup = CheckBox(r, "Balanced", Words("Balanced: ", "load"))
			if popup then r:Shot("the box saying load them", { behind = { popup, rawget(_G, "CinematicWelcome") } }) end
			ClickReload(r, popup)
		end },
		{ key = "back", title = "both back; /cine profile", run = function(r)
			r:Log(("reloaded %s s after the box"):format(tostring(Data().reloadAsked and (time() - Data().reloadAsked))))
			Loaded(r, true, "after Reload UI")
			r:Verdict(CinematicDB.moduleDefaults == nil, "the copy of their defaults gone once loaded")
			r:Verdict(ns.ActiveProfile() == "Balanced", "still Balanced: " .. tostring(ns.ActiveProfile()))
			r:Verdict(ns.settingsCanvases and ns.settingsCanvases["Roll Vision"] ~= nil and ns.settingsCanvases["Scenes"] ~= nil
				and true or false, "their pages back")
			local welcome = rawget(_G, "CinematicWelcome")
			if welcome and welcome:IsShown() then welcome:Hide() end
			ns.HandleSlash("profile blank slate")
			ns.db.fadeUI = false
			r:Sleep(0.5)
			r:Verdict(ns.ActiveProfile() == "Blank Slate", "Blank Slate picked: " .. tostring(ns.ActiveProfile()))
			Wanted(r, false, "Blank Slate")
			local popup = CheckBox(r, "Blank Slate", Words("Blank Slate: ", "leave"))
			if popup then r:Shot("the box, no welcome window", { behind = popup }) end
			ns.HandleSlash("profile balanced")
			ns.db.fadeUI = false
			r:Sleep(0.5)
			Wanted(r, true, "Balanced again")
			r:Verdict(Popup() == nil, "Balanced again: nothing to reload, the box gone")
			-- Another of our boxes (Edit Mode's, never clicked: hidden by the test)
			-- with the window high: moved under it, then back to that spot.
			ns.ShowWelcome()
			r:Sleep(0.5)
			local highTop = WindowHigh()
			r:Sleep(0.2)
			StaticPopup_Show("CINEMATIC_LAYOUT_RELOAD")
			r:Sleep(0.5)
			local editBox = Popup("CINEMATIC_LAYOUT_RELOAD")
			r:Verdict(editBox ~= nil, "the Edit Mode box is up")
			if editBox then
				CheckStill(r, "Edit Mode box", editBox, highTop)
				r:Shot("the Edit Mode box over the window, which stayed put", { behind = { editBox, rawget(_G, "CinematicWelcome") } })
				StaticPopup_Hide("CINEMATIC_LAYOUT_RELOAD")
			end
			r:Sleep(0.5)
			welcome = rawget(_G, "CinematicWelcome")
			local e = Edges(welcome)
			r:Verdict(e and highTop and math.abs(e.top - highTop) < 2 or false,
				("box gone: the window still where it was (top %.0f, was %.0f)"):format(e and e.top or -1, highTop or -1))
			if welcome then welcome:Hide() end
		end },
	},
})
