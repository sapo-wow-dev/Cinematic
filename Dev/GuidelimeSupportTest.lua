-- /cine debug guidelime: Guidelime's guide window, ongoing steps and arrow
-- with ours (Support/Guidelime.lua). A player's wish 2026-11-25: the arrow
-- up, the guide's objectives not. Guidelime hides its arrow when its guide
-- window is closed, so the guide must only fade (stay shown) for the arrow
-- to keep working. The addon test checks each row hides and comes back;
-- this checks what it can't see.
-- Steps:
--   0 solo    Guidelime alone with Cinematic (a Reload), if it isn't loaded
--   1 setup   its guide window found, the arrow made (a guide with a goto
--             step loaded: you load one if not)
--   2 wish    hands off: guide row hidden, arrow row shown: the guide is
--             invisible but still shown, the arrow up and still shown 3 s on
--   3 opacity hands off: the arrow's own opacity (as its slider sets it)
--             shows through with its row shown, and its row still hides it
--   4 buttons its target and quest item buttons fade with the guide
--   5 back    your addon list back (a Reload), if step 0 changed it
-- Into CinematicDB.guidelimeSupportTestLog. Dev copy only.
local _, ns = ...

local ROWS = { "addon:glGuide", "addon:glOngoing", "addon:glArrow" }

local function Guide()
	for _, frame in ipairs({ UIParent:GetChildren() }) do
		if ns.Reachable(frame) and not frame:GetName() and ns.IsGuidelimeWindow(frame) then
			return frame
		end
	end
end
local function Arrow() return _G.GuidelimeArrow end

-- Ready for a test: its guide window open, a guide loaded, its arrow up
-- (Tools/addon-kit/addons/Guidelime.md). Its window closed: the recipe opens
-- it (Guidelime.toggleMainFrame, what /lime does). Its guide is kept per
-- character, loaded once it's back after a reload; the call that loads one
-- is inside the addon (not global), so that's your clicks.
ns.TestKit.DefineAddonReady("Guidelime", {
	about = "its guide window open, a guide loaded, its arrow pointing somewhere",
	ready = function()
		if not (Guide() and ns.Flag(Guide():IsShown())) then return false, "its guide window is closed" end
		if not Arrow() then return false, "no arrow yet (saved guide: "
			.. tostring(_G.GuidelimeDataChar and _G.GuidelimeDataChar.currentGuide) .. ")" end
		return ns.Flag(Arrow():IsShown()), "the arrow is hidden (no step that goes to a place)"
	end,
	make = function(r)
		local data = _G.GuidelimeDataChar
		if data and data.mainFrameShowing == false and _G.Guidelime and _G.Guidelime.toggleMainFrame then
			r:Keep("guideWasClosed", true)
			_G.Guidelime.toggleMainFrame()
			r:Log("opened Guidelime's guide window (as /lime does)")
			r:Sleep(1)
		end
	end,
	putBack = function(extra)
		if extra.guideWasClosed and _G.GuidelimeDataChar and _G.GuidelimeDataChar.mainFrameShowing
			and _G.Guidelime and _G.Guidelime.toggleMainFrame then
			_G.Guidelime.toggleMainFrame()
			return "Guidelime's guide window closed again"
		end
	end,
	guide = {
		"In Guidelime's guide window, click the line \"Click here in order to start by loading a guide\".",
		"Pick any guide in the list and click Load guide.",
		"Already has one? Click a step that says to go to a place.",
		"No guides at all? The addon kit's run loads a test guide of its own after its Reload: Can't do it here.",
	},
})

-- No guide to load (you have no guide packs: run q57a1, 2026-11-25, "i dont
-- have guides"): during an addon kit stage for Guidelime, a small guide of
-- the kit's own is saved as one of Guidelime's custom guides and made this
-- character's current one, as its own editor's Save does
-- (GuidelimeData.customGuides[name] = text, currentGuide = "Custom guides
-- " .. name). Done at login, while Guidelime is loaded but before it reads its
-- guides (2 s after login), so it loads it itself: one goto step a few yards
-- away, so its arrow points somewhere. Only when the character has no guide
-- of its own; taken back out at the next login with no Guidelime stage, and
-- the current guide too if it's still the kit's. English names only (its
-- "Custom guides" is translated).
local TEST_GUIDE = "1-60 Cinematic addon kit test"
local TEST_KEY = "Custom guides " .. TEST_GUIDE
local function KitWantsGuidelime()
	local plan, solo = CinematicDB and CinematicDB.addonKitPlan, CinematicDB and CinematicDB.soloAddons
	if type(plan) ~= "table" or type(solo) ~= "table" then return false end
	local inPlan, kept = false, false
	for _, name in ipairs(plan.targets or {}) do if name == "Guidelime" then inPlan = true end end
	for _, name in ipairs(solo.keep or {}) do if name == "Guidelime" then kept = true end end
	return inPlan and kept
end
local guideLogin = CreateFrame("Frame")
guideLogin:RegisterEvent("PLAYER_LOGIN")
guideLogin:SetScript("OnEvent", function()
	local IsLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or _G.IsAddOnLoaded
	if not IsLoaded("Guidelime") then return end -- (no Guidelime code or data touched without it)
	local data, char = _G.GuidelimeData, _G.GuidelimeDataChar
	if type(data) ~= "table" or type(char) ~= "table" then return end
	local added = CinematicDB and CinematicDB.guidelimeKitGuide
	if not KitWantsGuidelime() then
		-- (Taken back out once the kit's Guidelime stage is over.)
		if added then
			if type(data.customGuides) == "table" then data.customGuides[TEST_GUIDE] = nil end
			if char.currentGuide == TEST_KEY then char.currentGuide = added.was end
			CinematicDB.guidelimeKitGuide = nil
		end
		return
	end
	if added or (char.currentGuide ~= nil and char.currentGuide ~= "") then return end
	local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	local pos = mapID and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
	local info = mapID and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
	local x, y = pos and pos.x, pos and pos.y
	if not (info and info.name and type(x) == "number" and type(y) == "number") then return end
	local text = ("[N 1-60 Cinematic addon kit test]\n[D Made by Cinematic's addon kit test for its arrow. It goes again by itself.]\n"
		.. "Walk a few steps [G %.1f,%.1f %s]\n"):format(math.min(x * 100 + 3, 99), y * 100, info.name)
	data.customGuides = type(data.customGuides) == "table" and data.customGuides or {}
	data.customGuides[TEST_GUIDE] = text
	CinematicDB.guidelimeKitGuide = { was = char.currentGuide }
	char.currentGuide = TEST_KEY
	if ns.Log then ns.Log("addonkit", "Guidelime: no guide of its own, so the kit's test guide is loaded (" .. info.name .. ")") end
end)

local function Effective(frame)
	local alpha = frame:GetEffectiveAlpha()
	if issecretvalue and issecretvalue(alpha) then return nil end
	return ns.Flag(frame:IsVisible()) and alpha or 0
end

local function ForceRow(key, state)
	ns.db.frameForce[key] = state
	if ns.db.frameForceAt then ns.db.frameForceAt[key] = state and GetTime() or nil end
	ns.RefreshFrameForce()
end

local function Fields(r, label)
	r:Fields(label, {
		guideShown = function() return Guide() and Guide():IsShown() end,
		guideAlpha = function() return Guide() and Guide():GetAlpha() end,
		guideEffective = function() return Guide() and Guide():GetEffectiveAlpha() end,
		guideFaded = function() return Guide() and ns.IsFaded(Guide()) end,
		arrowShown = function() return Arrow() and Arrow():IsShown() end,
		arrowAlpha = function() return Arrow() and Arrow():GetAlpha() end,
		arrowEffective = function() return Arrow() and Arrow():GetEffectiveAlpha() end,
		arrowFaded = function() return Arrow() and ns.IsFaded(Arrow()) end,
		arrowText = function() return Arrow() and Arrow().text and Arrow().text:GetText() end,
		ongoingShown = function() return _G.GuidelimeOngoingWindow and _G.GuidelimeOngoingWindow:IsShown() end,
	})
end

ns.TestKit.Define({
	name = "guidelime",
	key = "guidelimeSupportTest",
	title = "Guidelime arrow without the guide",
	about = "Guidelime's guide fades by its row while its arrow stays up and working; the arrow's own opacity still applies",
	needs = "Guidelime on, with a guide loaded that has a step the arrow points to",
	context = function()
		return ("Guidelime up: %s, guide window: %s, arrow: %s, ongoing window: %s"):format(
			tostring(ns.AddonUp("Guidelime")), tostring(Guide() ~= nil), tostring(Arrow() ~= nil),
			tostring(_G.GuidelimeOngoingWindow ~= nil))
	end,
	putBack = function(extra)
		for _, key in ipairs(ROWS) do
			local was = extra["force:" .. key]
			if was ~= nil then ForceRow(key, was ~= "<nil>" and was or nil) end
			local on = extra["on:" .. key]
			if on ~= nil then ns.SetAddonFramesOn(key:sub(7), on ~= "<nil>" and on or nil) end
		end
		local arrow = Arrow()
		if arrow and _G.GuidelimeDataChar and type(_G.GuidelimeDataChar.arrowAlpha) == "number" then
			arrow:SetAlpha(_G.GuidelimeDataChar.arrowAlpha)
		end
		return "Guidelime rows and its arrow's opacity as they were"
	end,
	steps = {
		{ key = "solo", title = "Guidelime alone with Cinematic", run = function(r)
			if ns.AddonUp("Guidelime") then r:Log("Guidelime already loaded") return end
			if not ns.SoloAddons then r:Fail("no /cine debug solo here (dev copy only)") return end
			if type(CinematicDB.soloAddons) == "table" then ns.SoloAddons("off", true) end
			ns.SoloAddons("Guidelime", true)
			CinematicDB.guidelimeTestSolo = true
			r:Log("solo for Guidelime: " .. table.concat(CinematicDB.soloAddons and CinematicDB.soloAddons.keep or {}, ", "))
			r:WaitFor("Reload, for Guidelime alone with Cinematic",
				{ check = function() return false end, buttons = { { kind = "reload" } } })
		end },
		{ key = "setup", title = "its guide window and arrow", run = function(r)
			if not ns.AddonUp("Guidelime") then r:Fail("Guidelime isn't loaded") return end
			-- (A row ticked Always leaves its frame alone, so a forced hide can't
			-- reach it: new addon rows start so with "new rows: Always" set
			-- (addonDefaultAlways). All three on for the run, put back after.)
			for _, key in ipairs(ROWS) do
				r:Keep("force:" .. key, ns.db.frameForce[key] or "<nil>")
				local on = ns.db.addonFrames[key:sub(7)]
				if on == nil then r:Keep("on:" .. key, "<nil>") else r:Keep("on:" .. key, on) end
				r:Log(("%s: Always off before %s"):format(key, tostring(on)))
				ns.SetAddonFramesOn(key:sub(7), true)
			end
			r:AddonReady("Guidelime")
			Fields(r, "at start")
			r:Verdict(Guide() ~= nil, "its guide window found by its fields (no name of its own)")
			r:Verdict(Arrow() ~= nil and ns.Flag(Arrow():IsShown()), "its arrow is up")
		end },
		{ key = "wish", title = "guide hidden, arrow shown (hands off)", seconds = 11, run = function(r)
			if not (Guide() and Arrow()) then r:Skip("no guide window or arrow") return end
			ForceRow("addon:glGuide", "hide")
			ForceRow("addon:glOngoing", "hide")
			ForceRow("addon:glArrow", "show")
			-- (The fade takes a while: 0.07 left at 1.5 s, 2026-11-25.)
			r:Sleep(3)
			Fields(r, "guide hidden")
			local guide = Effective(Guide())
			r:Verdict(guide ~= nil and guide < 0.05, ("the guide is invisible (%s)"):format(tostring(guide)))
			r:Verdict(ns.Flag(Guide():IsShown()), "the guide is still shown (faded, not closed: Guidelime keeps the arrow)")
			local arrow = Effective(Arrow())
			r:Verdict(arrow ~= nil and arrow > 0.3, ("the arrow is up (%s)"):format(tostring(arrow)))
			r:Shot("the arrow without the guide", { behind = Arrow() })
			r:Sleep(3)
			Fields(r, "3 s on")
			r:Verdict(ns.Flag(Arrow():IsShown()) and (Effective(Arrow()) or 0) > 0.3,
				"3 s on the arrow is still up (Guidelime didn't hide it)")
		end },
		{ key = "opacity", title = "the arrow's own opacity (hands off)", seconds = 8, run = function(r)
			local arrow = Arrow()
			if not arrow then r:Skip("no arrow") return end
			-- (As its opacity slider does, Options.lua: SetAlpha on the arrow.)
			arrow:SetAlpha(0.5)
			r:Sleep(1)
			local shown = Effective(arrow)
			Fields(r, "own opacity 0.5, row shown")
			r:Verdict(shown ~= nil and math.abs(shown - 0.5) < 0.08,
				("its own 0.5 shows through (%s)"):format(tostring(shown)))
			ForceRow("addon:glArrow", "hide")
			r:Sleep(3)
			local hidden = Effective(arrow)
			r:Verdict(hidden ~= nil and hidden < 0.05, ("its row still hides it (%s)"):format(tostring(hidden)))
			ForceRow("addon:glArrow", "show")
			arrow:SetAlpha(_G.GuidelimeDataChar and _G.GuidelimeDataChar.arrowAlpha or 1)
			r:Sleep(1)
			Fields(r, "its own opacity back")
		end },
		{ key = "buttons", title = "its target and quest item buttons", run = function(r)
			local guide = Guide()
			if not guide then r:Skip("no guide window") return end
			local found = 0
			for _, base in ipairs({ "GuidelimeTargetButton", "GuidelimeUseItemButton" }) do
				for i = 1, 8 do
					local button = _G[base .. i]
					if button and ns.Flag(button:IsShown()) then
						found = found + 1
						local alpha = Effective(button)
						r:Verdict(button:GetParent() == guide and alpha ~= nil and alpha < 0.05,
							("%s%d fades with the guide (%s)"):format(base, i, tostring(alpha)))
					end
				end
			end
			if found == 0 then r:Log("no target or quest item button up on this step") end
			for _, key in ipairs(ROWS) do ForceRow(key, nil) end
			r:Sleep(1.5)
			Fields(r, "rows back to their ticks")
		end },
		{ key = "back", title = "your addon list back", run = function(r)
			if not CinematicDB.guidelimeTestSolo then r:Log("Guidelime was loaded already: list left as it was") return end
			CinematicDB.guidelimeTestSolo = nil
			ns.SoloAddons("off", true)
			r:Log("addon list put back")
			r:WaitFor("Reload, to get your addons back",
				{ check = function() return false end, buttons = { { kind = "reload" } } })
		end },
	},
})
