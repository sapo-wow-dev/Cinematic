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
