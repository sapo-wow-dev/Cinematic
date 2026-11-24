-- /cine debug worldview: can an addon draw the world only between the
-- letterbox bars (a player's wish, 2026-11-24)? The game does it itself for
-- its cutscenes (Blizzard_FrameXML/Shared/CinematicFrame.lua re-anchors
-- WorldFrame between its black bars); this asks whether an addon may, and
-- what it costs. Ledger: Tools/tests/world-view.md. Steps:
--   1 read      WorldFrame protected? its points and rect, UIParent's
--   2 squeeze   our own black bars + WorldFrame between them: does it move,
--               does UIParent stay, does the game put it back (3 s), shots
--   3 animate   the bars easing in over 2 s with WorldFrame following every
--               frame: frame time against 2 s standing still, SetPoint cost
--   4 restore   WorldFrame:SetAllPoints() back to the whole screen, shot
--   5 fightstart  (you: start a fight) WorldFrame moved in the fight's first
--               event (PLAYER_REGEN_DISABLED): allowed, lockdown on yet?
--   6 infight   moved again 1 s into the fight, then put back: blocked?
--   7 after     the fight over: put back, blocked actions after the fight
-- Run 2, the built switch (Letterbox page, letterboxWorld; Letterbox.lua):
--   8 feature   the letterbox key's bars in with the switch on: the world
--               between them (their height), notch gap unchanged, shot;
--               switch off with the bars up: eased out to the whole screen;
--               on again: eased in; bars out: whole screen
--   9 apart     top and bottom bars apart (3% / 9%, unlinked): each bar
--               and the world in by its own; the Letterbox Style page's
--               Top bar, link, Bottom bar shown clear; the link clicked:
--               even again; clicked again: the bottom keeps its height
--  10 fight     (you: start a fight, then end it) the world between the
--               bars through it, the bars held (out for fights by default,
--               asked out mid-fight too), nothing blocked; out and whole after
-- A move that is blocked fails its step by itself (the kit's BLOCKED count):
-- that's an answer here, not a broken test. WorldFrame goes back to the
-- whole screen at the end, on a stop, and on any /reload (the game re-makes it).
-- Into CinematicDB.worldViewTestLog. Dev copy only.
local _, ns = ...

local BAR = 0.12 -- each bar's height, a share of the screen's

local bars -- our black bars (UIParent units)

local function Rect(frame)
	local l, b, w, h = frame:GetRect()
	if type(l) ~= "number" then return "no rect" end
	local s = frame:GetEffectiveScale()
	-- (screen pixels-ish: units times effective scale)
	return ("x %.0f y %.0f w %.0f h %.0f (scaled %.3f)"):format(l * s, b * s, w * s, h * s, s)
end

local function Points(frame)
	local out = {}
	for i = 1, frame:GetNumPoints() do
		local ok, p, rel, rp, x, y = pcall(frame.GetPoint, frame, i)
		if ok then
			out[#out + 1] = ("%s %s %s %.1f %.1f"):format(tostring(p),
				rel and (rel.GetName and rel:GetName() or "?") or "nil", tostring(rp), x or 0, y or 0)
		else
			out[#out + 1] = "err " .. tostring(p)
		end
	end
	return #out > 0 and table.concat(out, "; ") or "none"
end

local function ShowBars(share)
	if not bars then
		bars = CreateFrame("Frame", nil, UIParent)
		bars:SetAllPoints(UIParent)
		bars:SetFrameStrata("BACKGROUND")
		bars:EnableMouse(false)
		bars.top = bars:CreateTexture(nil, "ARTWORK")
		bars.top:SetColorTexture(0, 0, 0, 1)
		bars.top:SetPoint("TOPLEFT")
		bars.top:SetPoint("TOPRIGHT")
		bars.bottom = bars:CreateTexture(nil, "ARTWORK")
		bars.bottom:SetColorTexture(0, 0, 0, 1)
		bars.bottom:SetPoint("BOTTOMLEFT")
		bars.bottom:SetPoint("BOTTOMRIGHT")
	end
	local h = math.max(UIParent:GetHeight() * share, 0.01)
	bars.top:SetHeight(h)
	bars.bottom:SetHeight(h)
	bars:SetShown(share > 0)
	return h
end

-- WorldFrame between bars of this share of the screen; the offset in
-- WorldFrame's own units (its points are on the screen, relativeTo nil).
local function Squeeze(share)
	local h = UIParent:GetHeight() * share * UIParent:GetEffectiveScale() / WorldFrame:GetEffectiveScale()
	WorldFrame:ClearAllPoints()
	WorldFrame:SetPoint("TOPLEFT", nil, "TOPLEFT", 0, -h)
	WorldFrame:SetPoint("BOTTOMRIGHT", nil, "BOTTOMRIGHT", 0, h)
	return h
end

local function Full()
	WorldFrame:ClearAllPoints()
	WorldFrame:SetAllPoints()
end

-- Is WorldFrame now between bars of this share (within 2 screen units)?
-- (share: the top bar's, a share of the screen; bottomShare: the bottom's,
-- the same if not given.)
local function IsSqueezed(share, bottomShare)
	local s = WorldFrame:GetEffectiveScale()
	local top, bottom = WorldFrame:GetTop(), WorldFrame:GetBottom()
	local ui = UIParent:GetEffectiveScale()
	local screenH = UIParent:GetHeight() * ui
	if type(top) ~= "number" or type(bottom) ~= "number" then return false end
	return math.abs(bottom * s - screenH * (bottomShare or share)) < 2 and math.abs(screenH - top * s - screenH * share) < 2
end

local function IsFull()
	local s, ui = WorldFrame:GetEffectiveScale(), UIParent:GetEffectiveScale()
	local top, bottom = WorldFrame:GetTop(), WorldFrame:GetBottom()
	if type(top) ~= "number" or type(bottom) ~= "number" then return false end
	return math.abs(bottom * s) < 2 and math.abs(top * s - UIParent:GetTop() * ui) < 2
end

local function State(r, label)
	r:Log(("%s: WorldFrame %s | points %s | UIParent %s | lockdown %s"):format(label, Rect(WorldFrame),
		Points(WorldFrame), Rect(UIParent), tostring(InCombatLockdown())))
end

ns.TestKit.Define({
	name = "worldview",
	key = "worldViewTest",
	title = "World between the bars",
	about = "can an addon draw the world only between letterbox bars (WorldFrame moved), in and out of fights, and its cost; then the built switch",
	needs = "A mob or training dummy to fight (steps 5 and 9)",
	context = function()
		local w, h = GetPhysicalScreenSize()
		return ("screen %sx%s, CinematicFrame shown %s"):format(tostring(w), tostring(h),
			tostring(CinematicFrame and CinematicFrame:IsShown()))
	end,
	settings = { "letterboxWorld", "letterboxOffInCombat", "letterboxPage", "visualEffects" },
	putBack = function()
		if bars then bars:Hide() end
		if ns.worldViewKey and Cinematic_ToggleLetterbox then
			ns.worldViewKey = nil
			Cinematic_ToggleLetterbox() -- (the key's bars out)
		end
		if InCombatLockdown() then return "in a fight: WorldFrame put back after it (or at /reload)" end
		local ok, err = pcall(Full)
		return ok and "WorldFrame back to the whole screen" or ("WorldFrame put back failed: " .. tostring(err))
	end,
	steps = {
		{ key = "read", proven = "run 1 (qbd76): protected, whole screen", title = "WorldFrame as the game made it", run = function(r)
			r:Fields("WorldFrame", {
				protected = function() return WorldFrame:IsProtected() end,
				forbidden = function() return WorldFrame:IsForbidden() end,
				sameAsCUI = function() return C_UI and C_UI.GetWorldFrame and C_UI.GetWorldFrame() == WorldFrame end,
				strata = function() return WorldFrame:GetFrameStrata() end,
				scale = function() return WorldFrame:GetScale() end,
				ignoreParentScale = function() return WorldFrame:IsIgnoringParentScale() end,
			})
			State(r, "as the game made it")
			r:Verdict(IsFull(), "WorldFrame covers the whole screen before we touch it")
		end },
		{ key = "squeeze", proven = "run 1 (qbd76): moves, wider view, stays", title = "the world between our bars", run = function(r)
			r:Shot("before: the whole screen")
			ShowBars(BAR)
			local ok, h = r:Probe("Squeeze(0.12)", Squeeze, BAR)
			State(r, ("squeezed (offset %s)"):format(tostring(h)))
			r:Verdict(ok and IsSqueezed(BAR), "WorldFrame moved between the bars, out of a fight")
			r:Verdict(math.abs(UIParent:GetBottom()) < 1, "UIParent stays on the whole screen")
			r:Shot("squeezed: the world between the bars (wider view or stretched?)")
			r:Sleep(3)
			State(r, "3 s later")
			r:Verdict(IsSqueezed(BAR), "the game didn't put WorldFrame back by itself in 3 s")
			ShowBars(0)
			r:Shot("squeezed, our bars hidden: what draws in the strips the world left")
			ShowBars(BAR)
		end },
		{ key = "animate", proven = "run 1 (qbd76): 0.009 ms a call", title = "WorldFrame following the bars every frame", run = function(r)
			local rec = { still = {}, moving = {}, cost = 0, calls = 0 }
			local list, start, last = rec.still, nil, nil
			local f = CreateFrame("Frame")
			f:SetScript("OnUpdate", function()
				local now = debugprofilestop()
				if last then list[#list + 1] = now - last end
				last = now
				if list == rec.moving then
					local t = math.min((GetTime() - start) / 2, 1)
					local share = BAR * t * t * (3 - 2 * t)
					ShowBars(share)
					local before = debugprofilestop()
					if share > 0.0005 then Squeeze(share) else Full() end
					rec.cost = rec.cost + debugprofilestop() - before
					rec.calls = rec.calls + 1
				end
			end)
			Full()
			ShowBars(0)
			r:Sleep(2)
			last, start, list = nil, GetTime(), rec.moving
			r:Sleep(2.2)
			f:SetScript("OnUpdate", nil)
			local function Stats(t)
				local sum, top = 0, 0
				for _, v in ipairs(t) do sum = sum + v; if v > top then top = v end end
				return #t > 0 and sum / #t or 0, top, #t
			end
			local sa, sm, sn = Stats(rec.still)
			local ma, mm, mn = Stats(rec.moving)
			r:Log(("frame time standing: avg %.2f ms, max %.2f, %d frames | moving: avg %.2f ms, max %.2f, %d frames | Squeeze %.3f ms per call (%d calls)"):format(
				sa, sm, sn, ma, mm, mn, rec.calls > 0 and rec.cost / rec.calls or 0, rec.calls))
			State(r, "after the ease in")
			r:Verdict(IsSqueezed(BAR), "it ended between the bars")
			r:Verdict(sn > 10 and mn > 10 and ma < sa * 1.5 + 2,
				("frames while moving no slower than 1.5x standing (+2 ms): %.2f vs %.2f"):format(ma, sa))
		end },
		{ key = "restore", proven = "run 1 (qbd76): SetAllPoints puts it back", title = "the world back on the whole screen", run = function(r)
			local ok = r:Probe("Full()", Full)
			ShowBars(0)
			State(r, "put back")
			r:Verdict(ok and IsFull(), "WorldFrame back on the whole screen")
			r:Shot("put back: the whole screen again")
		end },
		{ key = "fightstart", proven = "run 1 (qbd76): lockdown off in REGEN_DISABLED, put back", title = "moved as a fight starts", run = function(r)
			ShowBars(BAR)
			Squeeze(BAR)
			-- (WaitFor resumes inside the event: the lines after it run in
			-- PLAYER_REGEN_DISABLED's own handler.)
			r:WaitFor("Start a fight: hit any mob or a training dummy (the world is squeezed on purpose)",
				{ events = { "PLAYER_REGEN_DISABLED" } })
			local lockdown = InCombatLockdown()
			local ok, err = pcall(Full)
			r:Log(("in PLAYER_REGEN_DISABLED: lockdown %s, put back ok=%s err=%s"):format(tostring(lockdown),
				tostring(ok), tostring(err)))
			r:Verdict(IsFull(), "WorldFrame put back in the fight's first event")
			State(r, "in the fight's first event")
		end },
		{ key = "infight", proven = "run 1 (qbd76): blocked in fights (the answer)", title = "moved inside a fight", run = function(r)
			r:Sleep(1)
			State(r, "1 s into the fight")
			if not InCombatLockdown() then
				r:Skip("the fight was over already: no lockdown to test")
				return
			end
			local ok, err = pcall(Squeeze, BAR)
			r:Log(("Squeeze in the fight: ok=%s err=%s"):format(tostring(ok), tostring(err)))
			r:Sleep(0.2)
			State(r, "squeezed in the fight?")
			r:Verdict(IsSqueezed(BAR), "WorldFrame moved inside a fight")
			r:Shot("in the fight, squeezed (if it moved)")
			local okBack, errBack = pcall(Full)
			r:Sleep(0.2)
			State(r, "put back in the fight?")
			r:Verdict(okBack and IsFull(), "WorldFrame put back inside a fight: " .. tostring(errBack))
		end },
		{ key = "after", proven = "run 1 (qbd76): moves again after", title = "after the fight", run = function(r)
			if InCombatLockdown() then
				r:WaitFor("End the fight (kill it or run off)", { events = { "PLAYER_REGEN_ENABLED" } })
				r:Sleep(1)
			end
			ShowBars(BAR)
			local ok = pcall(Squeeze, BAR)
			r:Sleep(0.5)
			r:Verdict(ok and IsSqueezed(BAR), "moves again after the fight")
			r:Sleep(1)
			Full()
			ShowBars(0)
			State(r, "after the fight, put back")
			r:Verdict(IsFull(), "back on the whole screen after the fight")
		end },
		{ key = "feature", proven = "run 4 (q644e): between the bars, eased flips (33/16 heights, steps <= 21 of 192), bars out", title = "the switch: the world between the letterbox bars", run = function(r)
			if not (ns.LetterboxWorldBack and ns.letterbox and Cinematic_ToggleLetterbox) then
				r:Skip("Atmosphere left out (Modules.lua): no letterbox to test")
				return
			end
			r:Set("visualEffects", true)
			r:Set("letterboxPage", true)
			r:Set("letterboxWorld", true)
			local gapBefore = ns.NotchGap()
			local function BarsIn()
				return ns.LetterboxUp() and ns.letterbox.top:GetHeight() >= ns.LetterboxHeight(ns.LetterboxLook(),
					UIParent:GetWidth(), UIParent:GetHeight()) - 0.5
			end
			ns.worldViewKey = true
			Cinematic_ToggleLetterbox()
			r:WaitFor(nil, { check = BarsIn })
			r:Sleep(0.3)
			local share = ns.letterbox.top:GetHeight() / UIParent:GetHeight()
			State(r, ("bars in (%.3f of the screen each)"):format(share))
			r:Verdict(IsSqueezed(share), "the world between the letterbox bars")
			r:Verdict(math.abs(ns.NotchGap() - gapBefore) < 0.5,
				("notch gap unchanged: %.1f vs %.1f"):format(ns.NotchGap(), gapBefore))
			r:Shot("the switch on: the world between the letterbox bars")
			-- The switch flipped with the bars up: the world eases out and in
			-- (its bottom read every frame: in-between heights, never a jump).
			local function Flip(on, done)
				local seen, frames, biggest, last = {}, 0, 0, WorldFrame:GetBottom()
				local f = CreateFrame("Frame")
				f:SetScript("OnUpdate", function()
					local b = WorldFrame:GetBottom()
					frames = frames + 1
					seen[math.floor(b * 10 + 0.5)] = true
					biggest = math.max(biggest, math.abs(b - last))
					last = b
				end)
				r:Set("letterboxWorld", on)
				ns.letterboxDirty = true
				r:WaitFor(nil, { check = done })
				r:Sleep(0.3)
				f:SetScript("OnUpdate", nil)
				local steps = 0
				for _ in pairs(seen) do steps = steps + 1 end
				local full = UIParent:GetHeight() * share * UIParent:GetEffectiveScale() / WorldFrame:GetEffectiveScale()
				r:Log(("switch %s: %d frames, %d heights, biggest step %.1f of %.1f"):format(on and "on" or "off",
					frames, steps, biggest, full))
				return steps >= 4 and biggest < full * 0.6
			end
			local eased = Flip(false, IsFull)
			r:Verdict(IsFull() and ns.LetterboxUp(), "switch off with the bars up: the world on the whole screen")
			r:Verdict(eased, "switch off: eased out over several frames")
			r:Shot("switch off: bars over the whole-screen world")
			eased = Flip(true, function() return IsSqueezed(share) end)
			r:Verdict(IsSqueezed(share), "switch on again: between the bars")
			r:Verdict(eased, "switch on: eased in over several frames")
			ns.worldViewKey = nil
			Cinematic_ToggleLetterbox()
			r:WaitFor(nil, { check = function() return not ns.LetterboxUp() end })
			r:Sleep(0.3)
			State(r, "bars out")
			r:Verdict(IsFull(), "bars out: the world on the whole screen")
		end },
		{ key = "apart", proven = "run q6656: 3%/9% apart, world in by each, page's link on/off; 11 pass", title = "top and bottom bars apart (the Letterbox Style page's link)", run = function(r)
			if not (ns.LetterboxWorldBack and ns.letterbox and Cinematic_ToggleLetterbox) then
				r:Skip("Atmosphere left out (Modules.lua): no letterbox to test")
				return
			end
			local TOP, BOTTOM = 0.03, 0.09
			r:Set("visualEffects", true)
			r:Set("letterboxPage", true)
			r:Set("letterboxWorld", true)
			r:Set("styleGeneral", true)
			r:Set("letterboxStyle", true)
			r:Set("letterboxSizeBy", "height")
			r:Set("letterboxMotion", "slide")
			r:Set("letterboxSize", TOP)
			r:Set("letterboxSizeBottom", BOTTOM)
			r:Set("letterboxLinked", false)
			local H = UIParent:GetHeight()
			local function Near(a, b) return type(a) == "number" and math.abs(a - b) < 0.5 end
			-- (A wait that gives up after seconds: the verdicts after it say what's wrong,
			-- not a step stuck for good. Run 1, qafed: stuck, the user skipped it.)
			local function Until(seconds, check)
				local deadline = GetTime() + seconds
				return r:WaitFor(nil, { check = function()
					if check() then return true end
					return GetTime() > deadline and "gave up" or nil
				end })
			end
			-- (The key flips the bars from where they are: CineMode's bars, turned
			-- off by the kit as the run starts, still on their way out would have
			-- been flipped out, not in. Run 1, qafed. So out first.)
			ns.letterboxDirty = true
			Until(5, function() return not ns.LetterboxUp() and not ns.letterbox:IsShown() end)
			local gapBefore = ns.NotchGap()
			ns.worldViewKey = true
			Cinematic_ToggleLetterbox()
			Until(8, function()
				return Near(ns.letterbox.top:GetHeight(), H * TOP) and Near(ns.letterbox.bottom:GetHeight(), H * BOTTOM)
					and IsSqueezed(TOP, BOTTOM)
			end)
			r:Sleep(0.3)
			State(r, "unlinked, 3% top 9% bottom")
			r:Log(("bars: top %.1f bottom %.1f (want %.1f, %.1f)"):format(ns.letterbox.top:GetHeight(),
				ns.letterbox.bottom:GetHeight(), H * TOP, H * BOTTOM))
			r:Verdict(Near(ns.letterbox.top:GetHeight(), H * TOP) and Near(ns.letterbox.bottom:GetHeight(), H * BOTTOM),
				"unlinked: each bar its own height")
			r:Verdict(IsSqueezed(TOP, BOTTOM), "unlinked: the world in by each bar's own height")
			r:Verdict(math.abs(ns.NotchGap() - gapBefore) < 0.5,
				("notch gap unchanged: %.1f vs %.1f"):format(ns.NotchGap(), gapBefore))
			r:Shot("unlinked: a thin top bar, a tall bottom bar, the world between")
			-- The page as shown: Top bar, the link, Bottom bar.
			local ok, err = pcall(ns.OpenOptions, "Letterbox Style")
			r:Sleep(1)
			r:Verdict(ok, "Letterbox Style opened" .. (ok and "" or (": " .. tostring(err))))
			local c = ns.letterboxSizeControls
			local panel = _G.SettingsPanel or UIParent
			if not (c and c.top and c.bottom and c.link) then
				r:Verdict(false, "the page's Top bar, link and Bottom bar built")
				return
			end
			local function Page(label)
				local clear = 0
				for name, control in pairs(c) do
					-- (Offline: no real layout to judge, shown is all.)
					local hits = not control:IsVisible() and { "not shown" }
						or ns.noRealLayout and {} or r:Overlaps(control, panel)
					if #hits == 0 then clear = clear + 1 else r:Log(("%s: %s"):format(name, table.concat(hits, ", "))) end
				end
				r:Verdict(clear == 3, ("%s: Top bar, link, Bottom bar shown, nothing over them (%d of 3)"):format(label, clear))
				local top, bottom = ns.LetterboxSizeShown()
				r:Log(("%s: boxes %q / %q (values %s / %s)"):format(label, tostring(c.top:GetText()),
					tostring(c.bottom:GetText()), tostring(top), tostring(bottom)))
				return top, bottom
			end
			local top, bottom = Page("unlinked")
			r:Verdict(top == TOP and bottom == BOTTOM, "unlinked: the boxes show each bar's own")
			r:Shot("the page unlinked: 3% and 9%", { behind = panel })
			local function ClickLink() c.link:GetScript("OnClick")(c.link, "LeftButton") end
			ClickLink()
			Until(8, function() return Near(ns.letterbox.bottom:GetHeight(), H * TOP) and IsSqueezed(TOP) end)
			r:Sleep(0.3)
			local db = ns.GetDB()
			top, bottom = Page("linked")
			r:Verdict(db.letterboxLinked == true and db.letterboxSizeBottom == TOP and top == TOP and bottom == TOP,
				"link clicked: the bottom takes the top's, both boxes the same")
			r:Verdict(IsSqueezed(TOP) and Near(ns.letterbox.bottom:GetHeight(), H * TOP),
				"linked: both bars and the world even")
			r:Shot("the page linked: both 3%", { behind = panel })
			ClickLink()
			r:Sleep(0.5)
			r:Verdict(db.letterboxLinked == false and db.letterboxSizeBottom == TOP,
				"unlinked again: the bottom keeps the height it showed")
			if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
			ns.worldViewKey = nil
			Cinematic_ToggleLetterbox()
			Until(5, function() return not ns.LetterboxUp() end)
			r:Sleep(0.3)
			r:Verdict(IsFull(), "bars out: the world on the whole screen")
		end },
		{ key = "fight", proven = "run 3 (qa8a3): bars held through the fight, asked out too; out and whole after; 0 blocked", title = "the switch through a fight: the bars held", run = function(r)
			if not (ns.LetterboxWorldBack and ns.letterbox and Cinematic_ToggleLetterbox) then
				r:Skip("Atmosphere left out (Modules.lua): no letterbox to test")
				return
			end
			r:Set("visualEffects", true)
			r:Set("letterboxPage", true)
			r:Set("letterboxWorld", true)
			r:Set("letterboxOffInCombat", true) -- (the default: bars out for fights, held here)
			ns.worldViewKey = true
			Cinematic_ToggleLetterbox()
			r:WaitFor(nil, { check = function() return ns.LetterboxUp() and ns.worldSqueeze end })
			r:Sleep(2)
			local share = ns.letterbox.top:GetHeight() / UIParent:GetHeight()
			r:Verdict(IsSqueezed(share), "between the bars before the fight")
			r:WaitFor("Start a fight: hit any mob or a training dummy, then keep fighting", { events = { "PLAYER_REGEN_DISABLED" } })
			r:Sleep(1)
			State(r, "1 s into the fight")
			r:Verdict(IsSqueezed(share) and ns.LetterboxUp(), "in the fight: bars held, the world between them")
			-- The bars asked out mid-fight (the letterbox key): held still.
			ns.worldViewKey = nil
			Cinematic_ToggleLetterbox()
			r:Sleep(2)
			if InCombatLockdown() then
				State(r, "bars asked out mid-fight")
				r:Verdict(IsSqueezed(share) and ns.LetterboxUp() and ns.letterbox.top:GetHeight() / UIParent:GetHeight() > share - 0.002,
					"bars asked out mid-fight: held, the world between them")
				r:Shot("in the fight: bars held, the world between them")
				r:WaitFor("End the fight (kill it or run off)", { events = { "PLAYER_REGEN_ENABLED" } })
			else
				r:Skip("the fight ended before the mid-fight check")
			end
			r:WaitFor(nil, { check = function() return not ns.LetterboxUp() end })
			r:Sleep(0.3)
			State(r, "after the fight")
			r:Verdict(IsFull() and not ns.LetterboxUp(), "after the fight: bars out, the world on the whole screen")
		end },
	},
})
