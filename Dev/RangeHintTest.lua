-- /cine debug rangehint: Range Hint (UI/RangeHint.lua), a mark under your
-- character while your target is out of your spell's range. One real action:
-- pull a mob (target it and start a fight). The test first opens the Range
-- Hint icon's two tabs (Show, Settings: shown, nothing over them, a shot
-- each); then Edit Mode, hands off (the sample mark, a drag saved and the
-- mark moved, right-click back); then, in the fight, reads the game's own range answer for the spell
-- it picked (plain or secret, in a fight: untested on Forever before this),
-- makes the mark show and hide with a stand-in answer, and shoots it.
local _, ns = ...
if not ns.TestKit then return end

local function Plain(value) return not (issecretvalue and issecretvalue(value)) end

local function Page(r, page, label, controls)
	local ok, err = pcall(ns.OpenOptions, page)
	r:Sleep(1)
	r:Verdict(ok, label .. " opened" .. (ok and "" or (": " .. tostring(err))))
	local panel = _G.SettingsPanel or UIParent
	for name, control in pairs(controls or {}) do
		if control and control:IsVisible() then
			local hits = r:Overlaps(control, panel)
			r:Verdict(#hits == 0, ("%s shown, nothing over it%s"):format(name,
				#hits > 0 and (": " .. table.concat(hits, ", ")) or ""))
		else
			r:Verdict(false, name .. " shown")
		end
	end
	r:Shot(label, { behind = panel })
end

local function State(r, label)
	local st = ns.RangeHint and ns.RangeHint.State() or {}
	r:Fields(label, {
		out = function() return st.out end, why = function() return st.why end,
		spell = function() return st.spell end, name = function() return st.name end,
		alpha = function() return st.alpha end, watching = function() return st.watching end,
		visible = function() return _G.CinematicRangeHint and _G.CinematicRangeHint:IsVisible() end,
		inCombat = function() return InCombatLockdown() end,
	})
	return st
end

ns.TestKit.Define({
	name = "rangehint", key = "rangeHintTest", title = "Range Hint",
	about = "A mark under your character while your target is out of your spell's range (UI/RangeHint.lua)",
	settings = { "handleRangeHint", "showInRange" },
	needs = "a mob to fight nearby",
	steps = {
		{ key = "page", title = "the Range Hint icon's Show and Settings tabs", proven = "qeb71 2026-11-25 5/5",
			run = function(r)
			r:Verdict(ns.DEFAULTS.showInRange == false, "off by default (its icon's switch)")
			r:Set("showInRange", true)
			r:Set("handleRangeHint", true)
			r:Set("showInRange", true)
			Page(r, "HUD:rangehint", "Range Hint > Show")
			-- (The Settings tab: its Spell dropdown, the only control past the switch.)
			pcall(ns.OpenOptions, "Range hint")
			r:Sleep(0.5)
			local dropdown
			local panel = _G.SettingsPanel
			if panel then
				local function Find(frame, depth)
					if dropdown or depth > 12 then return end
					for _, child in ipairs({ frame:GetChildren() }) do
						if child.sweepGet and child:IsVisible() then
							local okKey, value = pcall(child.sweepGet)
							if okKey and (value == "auto" or type(value) == "number") then dropdown = child end
						end
						Find(child, depth + 1)
					end
				end
				Find(panel, 0)
			end
			Page(r, "Range hint", "Range Hint > Settings", { ["Spell dropdown"] = dropdown })
			local choices = ns.RangeHintChoices()
			r:Log(("spell list (%d):"):format(#choices))
			for i = 1, math.min(#choices, 12) do r:Log("    " .. tostring(choices[i].text)) end
			r:Verdict(#choices >= 2, "the list has Auto and at least one attack from your bars")
			if _G.SettingsPanel and _G.SettingsPanel:IsShown() then HideUIPanel(_G.SettingsPanel) end
		end },
		-- Edit Mode, hands off: our own enter and exit (the real Edit Mode opened
		-- from addon code can taint it: rule forever.editmode.updatelayoutinfo-taints),
		-- a drag dropped on screen, then a right-click.
		{ key = "editmode", title = "Edit Mode: sample, drag, right-click reset", proven = "qafa5 2026-11-25 12/12",
			run = function(r)
			local RH = ns.RangeHint
			r:Set("rangeHintX", ns.DEFAULTS.rangeHintX)
			r:Set("rangeHintY", ns.DEFAULTS.rangeHintY)
			r:Set("handleRangeHint", false)
			RH.EditEnter()
			r:Verdict(not (RH.Mover() and RH.Mover():IsShown()), "page off: no Edit Mode box")
			RH.EditExit()
			r:Set("showInRange", true)
			r:Set("handleRangeHint", true)
			RH.EditEnter()
			r:Sleep(1)
			local mover = RH.Mover()
			local st = State(r, "in Edit Mode")
			r:Verdict(mover and mover:IsVisible(), "its box is shown")
			r:Verdict(st.out and st.why == "edit mode" and st.alpha == 1, "the mark shows as a sample")
			local function Near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 2 end
			local fx, fy = RH.frame:GetCenter()
			local mx, my = mover:GetCenter()
			r:Verdict(Near(fx, mx) and Near(fy, my), ("the box sits on the mark (%s,%s / %s,%s)"):format(
				tostring(fx), tostring(fy), tostring(mx), tostring(my)))
			-- (Its first spot clear of the bars: at 0.3 it sat on the personal
			-- resource bars, the spell's name hidden, run qeb71.)
			local function Rect(f)
				local l, rt, t, b = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
				if not (l and rt and t and b) or not Plain(l) or not Plain(t) then return nil end
				local s = f:GetEffectiveScale()
				return l * s, rt * s, t * s, b * s
			end
			-- (Faded bars count: the swing timer's sits there at alpha 0 till you
			-- attack, then shows over the mark, run qc733.)
			local bars = {}
			local f = EnumerateFrames and EnumerateFrames()
			while f do
				local okKind, isBar = pcall(f.IsObjectType, f, "StatusBar")
				local okShown, shown = pcall(f.IsVisible, f)
				if okKind and isBar and okShown and shown == true then
					local okRect, l, rt, t, b = pcall(Rect, f)
					if okRect and l then
						local okName, name = pcall(f.GetDebugName, f)
						bars[#bars + 1] = { name = okName and tostring(name) or "?", l = l, r = rt, t = t, b = b }
					end
				end
				f = EnumerateFrames(f)
			end
			local function Over()
				local ml, mr, mt, mb = Rect(RH.frame)
				local hits = {}
				for _, bar in ipairs(bars) do
					if ml and bar.l < mr and bar.r > ml and bar.t > mb and bar.b < mt then hits[#hits + 1] = bar end
				end
				return hits, ml ~= nil
			end
			local over, placed = Over()
			for _, bar in ipairs(over) do
				r:Log(("  over the mark: %s, left %d right %d top %d bottom %d (screen px)"):format(bar.name,
					bar.l, bar.r, bar.t, bar.b))
			end
			r:Verdict(placed and #over == 0, ("its first spot is clear of every bar there, shown or faded%s"):format(
				#over > 0 and (": " .. over[1].name) or ""))
			-- The highest spot under the bars that's clear (the mark's middle, a
			-- share of the screen), for its first spot.
			local db = ns.GetDB()
			local clear
			for y = 25, 8, -1 do
				db.rangeHintY = y / 100
				RH.EditEnter() -- (places it)
				if #Over() == 0 then clear = y / 100; break end
			end
			db.rangeHintY = ns.DEFAULTS.rangeHintY
			RH.EditEnter()
			r:Log("highest clear spot at or under 0.25: " .. tostring(clear))
			r:Shot("Range Hint in Edit Mode", { behind = mover })
			-- A drag: the box put down at a quarter across, three quarters up.
			local w, h = UIParent:GetWidth(), UIParent:GetHeight()
			mover:ClearAllPoints()
			mover:SetPoint("CENTER", UIParent, "BOTTOMLEFT", 0.25 * w, 0.75 * h)
			local dx, dy = mover:GetCenter()
			r:Log(("box put down: center %s, %s, size %s x %s"):format(tostring(dx), tostring(dy),
				tostring(mover:GetWidth()), tostring(mover:GetHeight())))
			mover:GetScript("OnDragStop")(mover)
			r:Sleep(0.3)
			r:Verdict(math.abs((db.rangeHintX or 0) - 0.25) < 0.01 and math.abs((db.rangeHintY or 0) - 0.75) < 0.01,
				("the drag saved the spot: %s, %s"):format(tostring(db.rangeHintX), tostring(db.rangeHintY)))
			fx, fy = RH.frame:GetCenter()
			local scale = RH.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
			r:Verdict(Near(fx * scale, 0.25 * w) and Near(fy * scale, 0.75 * h), ("the mark moved there (%s, %s)"):format(
				tostring(fx), tostring(fy)))
			mx, my = mover:GetCenter()
			r:Verdict(Near(fx, mx) and Near(fy, my), "the box snapped back onto the mark")
			r:Shot("Range Hint dragged up and left", { behind = mover })
			-- Right-click: back to its first spot.
			mover.draggedAt = nil
			mover:GetScript("OnClick")(mover, "RightButton")
			r:Sleep(0.3)
			r:Verdict(db.rangeHintX == ns.DEFAULTS.rangeHintX and db.rangeHintY == ns.DEFAULTS.rangeHintY,
				"right-click put it back")
			fx, fy = RH.frame:GetCenter()
			r:Verdict(Near(fx * scale, ns.DEFAULTS.rangeHintX * w) and Near(fy * scale, ns.DEFAULTS.rangeHintY * h),
				"the mark is back at its first spot")
			RH.EditExit()
			r:Sleep(1)
			st = State(r, "after Edit Mode")
			r:Verdict(not mover:IsShown(), "leaving Edit Mode hides the box")
			r:Verdict(st.why ~= "edit mode" and (st.out or st.alpha == 0), "the sample is gone")
		end },
		-- Range Hint Style (Style/RangeHintStyle.lua), hands off: the page in
		-- each state (on, off, each folder tab), its preview playing, then every
		-- look on the real mark (the Test demo: no target needed).
		{ key = "stylepage", title = "Range Hint Style page: each tab, page off, preview",
			proven = "qe5d8 2026-11-25 9/9", run = function(r)
			-- (Its page comes with the Style Studio: a build without it skips this.)
			if not ns.CreateRangeHintStylePanel then return r:Skip("no Range Hint Style page in this build") end
			r:Set("styleGeneral", true)
			r:Set("rangeHintStyle", true)
			r:Set("showInRange", true)
			r:Set("handleRangeHint", true)
			-- (This page's own controls only, those in the scrolled view: run
			-- q84e2 walked the whole window, the hub's icons scrolled out of
			-- view too, and named none of what it hit.)
			local function Controls(label)
				local panel = _G.SettingsPanel
				local content = ns.rangeHintStyleContent
				if not (panel and content) then return r:Verdict(false, label .. ": no page") end
				local view = content:GetParent()
				local vt, vb = view and view:GetTop(), view and view:GetBottom()
				local checked, hits = 0, {}
				local function Name(child)
					local ok, words = pcall(function() return child.GetText and child:GetText() end)
					return ok and words and tostring(words) or (child.searchLabel or child:GetDebugName() or "?")
				end
				local function Walk(frame, depth)
					if depth > 14 then return end
					for _, child in ipairs({ frame:GetChildren() }) do
						local ok, kind = pcall(child.GetObjectType, child)
						local top, bottom = child:GetTop(), child:GetBottom()
						local inView = top and bottom and (not vt or (bottom >= vb and top <= vt))
						if ok and (kind == "Button" or kind == "CheckButton" or kind == "Slider")
							and child:IsVisible() and inView then
							checked = checked + 1
							for _, hit in ipairs(r:Overlaps(child, view or panel)) do
								hits[#hits + 1] = Name(child) .. " over " .. hit
							end
						end
						Walk(child, depth + 1)
					end
				end
				Walk(content, 0)
				r:Verdict(checked > 0 and #hits == 0, ("%s: %d controls, nothing over another%s"):format(label,
					checked, #hits > 0 and (": " .. table.concat(hits, "; ", 1, math.min(#hits, 4))) or ""))
			end
			local ok, err = pcall(ns.OpenOptions, "Range Hint Style")
			r:Sleep(1)
			r:Verdict(ok, "Range Hint Style opened" .. (ok and "" or (": " .. tostring(err))))
			local names = { "Mark", "Text", "Background", "Motion" }
			for i, name in ipairs(names) do
				if ns.RangeStyleOpenTab then ns.RangeStyleOpenTab(i) end
				r:Sleep(1)
				Controls("tab " .. name)
				r:Shot("Range Hint Style, " .. name .. " tab", { behind = _G.SettingsPanel })
			end
			-- The preview plays: the mark comes and goes over its 4 s loop.
			local preview = ns.rangeHintStylePreview
			local lo, hi = 1, 0
			for _ = 1, 25 do
				local a = preview and preview.holder and preview.holder:GetAlpha() or 0
				lo, hi = math.min(lo, a), math.max(hi, a)
				r:Sleep(0.2)
			end
			r:Verdict(preview and preview:IsVisible() and hi > 0.9 and lo < 0.1,
				("the preview's mark comes and goes (alpha %.2f to %.2f)"):format(lo, hi))
			-- Page off: its rows greyed, the mark back to its first look.
			r:Set("rangeHintStyle", false)
			if ns.RangeStyleOpenTab then ns.RangeStyleOpenTab(1) end
			r:Sleep(1)
			r:Verdict(ns.RangeHintLook.rangeHintShape == "chevron", "page off: the first look")
			r:Shot("Range Hint Style, page off", { behind = _G.SettingsPanel })
			r:Set("rangeHintStyle", true)
			-- The Range Hint icon's own Style tab opens the same page.
			ok = pcall(ns.OpenOptions, "Range hint")
			r:Sleep(0.5)
			r:Verdict(ok and #ns.ShowInTabs("range") == 3, "the Range Hint icon has its Style tab")
			if _G.SettingsPanel and _G.SettingsPanel:IsShown() then HideUIPanel(_G.SettingsPanel) end
		end },
		{ key = "looks", title = "every look on the real mark (Test demo)",
			proven = "qe5d8 2026-11-25 13/13 (ten looks checked by eye)", run = function(r)
			local RH = ns.RangeHint
			r:Set("styleGeneral", true)
			r:Set("rangeHintStyle", true)
			r:Set("showInRange", true)
			r:Set("handleRangeHint", true)
			-- (At its first spot: run q84e2's shots had it at a spot saved from
			-- an older default, 0.3, behind the personal bars.)
			r:Set("rangeHintX", ns.DEFAULTS.rangeHintX)
			r:Set("rangeHintY", ns.DEFAULTS.rangeHintY)
			if ns.RangeHintRefresh then ns.RangeHintRefresh() end
			local spell = RH.Chosen()
			r:Log(("spell %s, school in the list: %s"):format(tostring(spell),
				tostring(spell and ns.RANGE_SPELL_SCHOOL[spell])))
			local function Show(label, changes)
				for key, value in pairs(changes) do r:Set(key, value) end
				RH.Demo(3)
				r:Sleep(1)
				local p = RH.parts
				local tex = p.shape:IsShown() and p.shape:GetTexture()
				local w, h = RH.frame:GetSize()
				r:Log(("%s: shape %s, words %q, size %dx%d, alpha %.2f"):format(label, tostring(tex),
					tostring(p.text:GetText()), w or 0, h or 0, RH.mark and RH.mark:GetAlpha() or -1))
				r:Verdict(RH.State().why == "test" and (not p.shape:IsShown() or tex ~= nil),
					label .. ": up, its art loaded")
				r:Shot("Range Hint: " .. label)
			end
			Show("chevron (first look)", {})
			Show("double, bold, glow", { rangeHintShape = "double", rangeHintWeight = "bold", rangeHintGlow = 0.7 })
			Show("dot, thin", { rangeHintShape = "dot", rangeHintWeight = "thin", rangeHintGlow = 0 })
			Show("ring, school color", { rangeHintShape = "ring", rangeHintWeight = "normal", rangeHintColorBy = "school" })
			Show("brackets, class color", { rangeHintShape = "bracket", rangeHintColorBy = "class" })
			Show("arrow, theme color", { rangeHintShape = "arrow", rangeHintColorBy = "theme" })
			Show("spell icon, round", { rangeHintShape = "icon", rangeHintIconRound = true, rangeHintColorBy = "custom" })
			Show("words only, capitals, outline", { rangeHintShape = "none", rangeHintText = "words",
				rangeHintCase = "upper", rangeHintOutline = 1 })
			Show("spell and range on the right, pill", { rangeHintShape = "chevron", rangeHintText = "spellrange",
				rangeHintSide = "right", rangeHintCase = "asis", rangeHintOutline = 0, rangeHintBack = "pill" })
			Show("panel with a line, big", { rangeHintSide = "below", rangeHintText = "spell", rangeHintBack = "panel",
				rangeHintBorder = "mark", rangeHintScale = 2, rangeHintTextSize = 1.5 })
			RH.Demo(0)
		end },
		-- Each part's Enable off on the real mark (the Studio editor's Enable
		-- writes this switch, "tabOn:Range Hint Style/look:<n>"): that part
		-- gone, not back to its default. Run qfbef never switched one off,
		-- and Text off still showed the spell's name (the user, 2026-11-25).
		-- Off by default in every profile, and nothing of it runs while off
		-- (the user, 2026-11-25): no watching on a new target, no Test, no
		-- Edit Mode box, no Shoulder Cam follow; one switch turns it on.
		-- Hands off.
		{ key = "offgate", title = "off by default; nothing runs while it's off",
			proven = "q97a5 2026-11-25 9/9", run = function(r)
			local RH = ns.RangeHint
			r:Verdict(ns.DEFAULTS.showInRange == false and ns.DEFAULTS.handleRangeHint == true,
				"off to start with: its icon's switch off, the page under it on (one switch turns it on)")
			-- (No built-in profile turns it on: Tools/offline/rangehint.lua reads
			-- every profile's settings, check.lua's profile-settings files.)
			r:Set("showInRange", false)
			r:Verdict(not ns.RangeHintOn(), "its switch off: off")
			if ns.RangeHintRefresh then ns.RangeHintRefresh() end
			r:Sleep(0.3)
			r:Verdict(not RH.State().watching, "off: not watching (no per-frame work)")
			RH.Demo(3)
			r:Sleep(0.5)
			r:Verdict(not RH.Demoing() and not RH.State().watching and RH.mark:GetAlpha() == 0, "off: the Test shows nothing")
			RH.EditEnter()
			r:Verdict(not (RH.Mover() and RH.Mover():IsShown()), "off: no Edit Mode box")
			RH.EditExit()
			-- (A new target with it off: still nothing watching.)
			if ns.RangeHintRefresh then ns.RangeHintRefresh() end
			r:Sleep(0.3)
			r:Verdict(not RH.State().watching, "off: a new target starts nothing")
			if ns.db.shoulderCam and ns.db.shoulderCamFrames and math.abs(ns.ShoulderYouShift and ns.ShoulderYouShift() or 0) > 5 then
				r:Sleep(1)
				local x = RH.frame:GetCenter()
				local scale = RH.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
				local home = (tonumber(ns.db.rangeHintX) or ns.DEFAULTS.rangeHintX) * UIParent:GetWidth()
				r:Verdict(x and math.abs(x * scale - home) < 2, "off: Shoulder Cam doesn't slide it")
			end
			r:Set("showInRange", true)
			r:Verdict(ns.RangeHintOn(), "its one switch on: on")
			RH.Demo(2)
			r:Sleep(1)
			r:Verdict(RH.State().watching and RH.Demoing(), "on: the Test runs")
			RH.Demo(0)
		end },
		{ key = "partsoff", title = "each part's Enable off: that part gone on the real mark",
			proven = "q5496 2026-11-25 8/8 (Text off while up)", run = function(r)
			local RH = ns.RangeHint
			r:Set("styleGeneral", true)
			r:Set("rangeHintStyle", true)
			r:Set("showInRange", true)
			r:Set("handleRangeHint", true)
			r:Set("rangeHintX", ns.DEFAULTS.rangeHintX)
			r:Set("rangeHintY", ns.DEFAULTS.rangeHintY)
			r:Set("rangeHintText", "spell")
			r:Set("rangeHintShape", "chevron")
			r:Set("rangeHintBack", "pill")
			local function Part(n) return ("tabOn:%s:%d"):format(ns.RANGE_STYLE_TABS, n) end
			local function Up(label)
				RH.Demo(3)
				r:Sleep(1)
				local p = RH.parts
				local st = {
					shape = p.shape:IsShown(), words = p.text:IsShown() and (p.text:GetText() or "") ~= "",
					back = p.back[1]:IsShown(), text = p.text:GetText(),
				}
				r:Log(("%s: shape %s, words %s (%q), back %s"):format(label, tostring(st.shape), tostring(st.words),
					tostring(st.text), tostring(st.back)))
				return st
			end
			local st = Up("all parts on")
			r:Verdict(st.shape and st.words and st.back, "all on: mark, words and pill")
			r:Set(Part(2), false)
			st = Up("Text off")
			r:Verdict(st.shape and not st.words, "Text off: no words, the mark still up")
			r:Shot("Range Hint with Text off")
			r:Set(Part(2), true)
			r:Set(Part(1), false)
			st = Up("Mark off")
			r:Verdict(not st.shape and st.words, "Mark off: no shape, the words still up")
			r:Shot("Range Hint with Mark off")
			r:Set(Part(1), true)
			r:Set(Part(3), false)
			st = Up("Background off")
			r:Verdict(st.shape and st.words and not st.back, "Background off: nothing behind it")
			r:Set(Part(3), true)
			-- (The page off wins: the first look.)
			r:Set(Part(2), false)
			r:Set("rangeHintStyle", false)
			st = Up("page off, Text off")
			r:Verdict(st.shape and st.words, "page off: the first look, words and all")
			r:Set("rangeHintStyle", true)
			r:Set(Part(2), true)
			-- Changed while it's up, with no refresh called (as the Style
			-- Studio editor changes it): drawn within a quarter second.
			RH.Demo(4)
			r:Sleep(1)
			r:Verdict(RH.parts.text:IsShown(), "(up with its words)")
			ns.db[Part(2)] = false
			r:Sleep(0.4)
			r:Verdict(not RH.parts.text:IsShown(), "Text switched off while it's up: the words go at once")
			ns.db[Part(2)] = nil
			r:Sleep(0.4)
			r:Verdict(RH.parts.text:IsShown(), "and come back switched on")
			RH.Demo(0)
		end },
		-- Shoulder Cam: the mark is one of Frames follow you's (the user,
		-- 2026-11-25: "need to add it as part of the shoulder cam"). Hands off,
		-- with the camera over your shoulder: the mark slides over with you.
		{ key = "shoulder", title = "Shoulder Cam: the mark slides over with you",
			proven = "q946a 2026-11-25 3/3 (moved -180, shift -180)", run = function(r)
			local RH = ns.RangeHint
			r:Verdict(ns.DEFAULTS.shoulderCamFollowRangeHint == true,
				"Range hint is one of Shoulder Cam's Frames follow you, ticked to start with")
			local shift = ns.ShoulderYouShift and ns.ShoulderYouShift() or 0
			if not (ns.db.shoulderCam and ns.db.shoulderCamFrames and math.abs(shift) > 5) then
				return r:Skip(("Shoulder Cam not over your shoulder now (on %s, frames %s, shift %.0f)"):format(
					tostring(ns.db.shoulderCam), tostring(ns.db.shoulderCamFrames), shift))
			end
			r:Set("showInRange", true)
			r:Set("handleRangeHint", true)
			r:Set("shoulderCamFollowRangeHint", true)
			r:Set("rangeHintX", ns.DEFAULTS.rangeHintX)
			r:Set("rangeHintY", ns.DEFAULTS.rangeHintY)
			if ns.RangeHintRefresh then ns.RangeHintRefresh() end
			RH.Demo(4)
			r:Sleep(1.5)
			local w = UIParent:GetWidth()
			local x = RH.frame:GetCenter()
			local scale = RH.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
			local moved = x and (x * scale - ns.DEFAULTS.rangeHintX * w)
			shift = ns.ShoulderYouShift()
			r:Log(("mark center %s, home %.0f, moved %s, Shoulder Cam's shift %.0f"):format(tostring(x),
				ns.DEFAULTS.rangeHintX * w, tostring(moved), shift))
			r:Verdict(moved and math.abs(moved - shift) < 12, "the mark slid over with you, as far as the other frames")
			r:Shot("Range Hint following you over the shoulder")
			-- Off: back to its spot.
			r:Set("shoulderCamFollowRangeHint", false)
			r:Sleep(1)
			x = RH.frame:GetCenter()
			r:Verdict(x and math.abs(x * scale - ns.DEFAULTS.rangeHintX * w) < 2, "unticked: back on its spot")
			RH.Demo(0)
		end },
		-- Shoulder Cam's own height per frame: ±300 (±100 before, the user,
		-- 2026-11-25: Range hint at +100 still sat low). Hands off; the lift
		-- itself needs the camera over your shoulder.
		{ key = "shoulderheight", title = "Follow HUD heights reach ±300, and +250 lifts the mark",
			proven = "q3202 2026-11-25 (span 600 read as 0..600; lifted 250)", run = function(r)
			local RH = ns.RangeHint
			r:Set("showInRange", true)
			r:Set("handleRangeHint", true)
			local ok = pcall(ns.OpenOptions, "Shoulder Cam")
			r:Sleep(1)
			r:Verdict(ok, "Shoulder Cam page opened")
			local slider
			local function Walk(frame, depth)
				if slider or depth > 18 then return end
				for _, child in ipairs({ frame:GetChildren() }) do
					if child.settingKey == "shoulderCamFollowRangeHintHeight" then slider = child return end
					Walk(child, depth + 1)
				end
			end
			if _G.SettingsPanel then Walk(_G.SettingsPanel, 0) end
			local lo, hi
			if slider then lo, hi = slider:GetMinMaxValues() end -- (not "slider and ...": that keeps one value)
			-- (Options.lua's Slider shifts a range below 0 up by its minimum: -300..300 reads 0..600, run q3202.)
			if lo == 0 and hi == 600 then lo, hi = -300, 300 end
			r:Verdict(lo == -300 and hi == 300, ("Range hint's own height goes -300 to +300 (%s to %s)"):format(
				tostring(lo), tostring(hi)))
			if _G.SettingsPanel and _G.SettingsPanel:IsShown() then HideUIPanel(_G.SettingsPanel) end
			local shift = ns.ShoulderYouShift and ns.ShoulderYouShift() or 0
			if not (ns.db.shoulderCam and ns.db.shoulderCamFrames and math.abs(shift) > 5) then
				return r:Skip("Shoulder Cam not over your shoulder now: the lift isn't measured")
			end
			r:Set("shoulderCamFollowRangeHint", true)
			r:Set("shoulderCamFramesHeight", 0)
			r:Set("shoulderCamFollowRangeHintHeight", 0)
			RH.Demo(5)
			r:Sleep(1.5)
			local _, y0 = RH.frame:GetCenter()
			r:Set("shoulderCamFollowRangeHintHeight", 250)
			r:Sleep(1.5)
			local _, y1 = RH.frame:GetCenter()
			local scale = RH.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
			local lifted = y0 and y1 and (y1 - y0) * scale
			r:Log(("mark middle %s -> %s, lifted %s"):format(tostring(y0), tostring(y1), tostring(lifted)))
			r:Verdict(lifted and math.abs(lifted - 250) < 12, "+250 lifts the mark 250 over your shoulder")
			r:Shot("Range Hint lifted +250 over the shoulder")
			RH.Demo(0)
		end },
		-- Its Interface hub icon in the Info band, not Combat (the user,
		-- 2026-11-25). Hands off.
		{ key = "infoband", title = "Range Hint's icon is in the Interface hub's Info band",
			proven = "q3202 2026-11-25 2/2", run = function(r)
			local ok = pcall(ns.OpenOptions, "HUD:rangehint")
			r:Sleep(1)
			r:Verdict(ok, "Range Hint opened")
			local band
			for _, entry in ipairs(ns.HubOverview and ns.HubOverview("UI Manager") or {}) do
				if entry.name == "HUD:rangehint" then band = entry.band end
			end
			r:Verdict(band == "Info", "in the Info band: " .. tostring(band))
			r:Shot("Interface hub, Range Hint in Info", { behind = _G.SettingsPanel })
			if _G.SettingsPanel and _G.SettingsPanel:IsShown() then HideUIPanel(_G.SettingsPanel) end
		end },
		-- Dev copy only (the user, 2026-11-25): its icons carry the red X, and
		-- the Style hub's Info band isn't led by it (shut, a band shows only
		-- its first icon: Range Hint Style fronted Info, red X and all, the
		-- user's screenshot). Hands off.
		{ key = "devonly", title = "dev only: red X on its icons; the Style hub's Info band led by its own first page",
			proven = "q1425 2026-11-25 5/5", run = function(r)
			r:Verdict(ns.isDev, "(the dev copy)")
			local ok = pcall(ns.OpenOptions, "HUD:rangehint")
			r:Sleep(1)
			r:Verdict(ok, "Range Hint opened")
			local hud
			for _, entry in ipairs(ns.HubOverview and ns.HubOverview("UI Manager") or {}) do
				if entry.name == "HUD:rangehint" then hud = entry end
			end
			r:Verdict(hud and hud.dev, "its Interface icon has the red X")
			r:Shot("Interface hub: Range Hint with its red X", { behind = _G.SettingsPanel })
			pcall(ns.OpenOptions, "Style General")
			r:Sleep(1)
			-- (The hub's icons left to right: Range Hint Style after every other
			-- Info page, so never the one a shut Info band shows.)
			local at, rangeDev = {}, nil
			for i, entry in ipairs(ns.HubOverview and ns.HubOverview("Style") or {}) do
				at[entry.name] = i
				if entry.name == "Range Hint Style" then rangeDev = entry.dev end
			end
			r:Verdict(rangeDev, "Range Hint Style has the red X")
			local behind = at["Range Hint Style"]
			local others = { "Bubble Style", "Tooltip Style", "Minimap Style" }
			local ahead = true
			for _, name in ipairs(others) do
				if not (behind and at[name] and at[name] < behind) then ahead = false end
			end
			r:Log(("Style hub order: Bubble %s, Tooltip %s, Minimap %s, Range Hint %s"):format(tostring(at[others[1]]),
				tostring(at[others[2]]), tostring(at[others[3]]), tostring(behind)))
			r:Verdict(ahead, "Range Hint Style comes after the other Info pages: it never leads the Info band")
			r:Shot("Style hub, Info band shut", { behind = _G.SettingsPanel })
			if _G.SettingsPanel and _G.SettingsPanel:IsShown() then HideUIPanel(_G.SettingsPanel) end
		end },
		-- The Show tab (the HUD's Range Hint section): a palette by its switch
		-- opening Range Hint Style (the user, 2026-11-25), and no sound left
		-- anywhere (removed the same day). Hands off.
		{ key = "showlink", title = "Show tab's Style palette opens Range Hint Style; no sound",
			proven = "q946a 2026-11-25 5/5", run = function(r)
			if not ns.CreateRangeHintStylePanel then return r:Skip("no Range Hint Style page in this build") end
			r:Set("showInRange", true)
			r:Set("handleRangeHint", true)
			local ok = pcall(ns.OpenOptions, "HUD:rangehint")
			r:Sleep(1)
			r:Verdict(ok, "Range Hint > Show opened")
			local palette
			local function Walk(frame, depth)
				if palette or depth > 16 then return end
				for _, child in ipairs({ frame:GetChildren() }) do
					if child.linkKind == "style" and child:IsVisible() then palette = child return end
					Walk(child, depth + 1)
				end
			end
			if _G.SettingsPanel then Walk(_G.SettingsPanel, 0) end
			r:Verdict(palette ~= nil, "a Style palette shows on the Show tab")
			if palette then
				local hits = r:Overlaps(palette, _G.SettingsPanel)
				r:Verdict(#hits == 0, "nothing over it" .. (#hits > 0 and (": " .. table.concat(hits, "; ")) or ""))
				r:Shot("Range Hint > Show with its Style palette", { behind = _G.SettingsPanel })
				palette:Click()
				r:Sleep(1)
				r:Verdict(ns.rangeHintStyleContent and ns.rangeHintStyleContent:IsVisible(),
					"clicking it opens Range Hint Style")
			end
			r:Verdict(ns.RangeHintCue == nil and ns.DEFAULTS.rangeHintSound == nil, "no sound left in Range Hint")
			if _G.SettingsPanel and _G.SettingsPanel:IsShown() then HideUIPanel(_G.SettingsPanel) end
		end },
		{ key = "fight", title = "pull a mob (your one action)", proven = "qeb71 2026-11-25 7/7 (Forever: 30/30 plain in a fight)",
			run = function(r)
			r:Set("showInRange", true)
			r:Set("handleRangeHint", true)
			r:Set("showInRange", true)
			r:WaitFor("Target a mob and start a fight with it", {
				check = function() return UnitExists("target") and InCombatLockdown() end,
			})
			local spell = ns.RangeHint.Chosen()
			r:Log(("spell asked: %s (%s)"):format(tostring(spell),
				tostring(spell and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spell))))
			-- The game's own answer in the fight, ten times a second for 3 s.
			local plain, secret, none, yes, no = 0, 0, 0, 0, 0
			for _ = 1, 30 do
				local raw
				if C_Spell and C_Spell.IsSpellInRange and spell then
					local ok, value = pcall(C_Spell.IsSpellInRange, spell, "target")
					raw = ok and value or "error"
				end
				if raw == nil then none = none + 1
				elseif not Plain(raw) then secret = secret + 1
				else
					plain = plain + 1
					if raw == true then yes = yes + 1 elseif raw == false then no = no + 1 end
				end
				r:Sleep(0.1)
			end
			r:Log(("in a fight %s: %d plain (%d in range, %d out), %d secret, %d no answer"):format(
				tostring(InCombatLockdown()), plain, yes, no, secret, none))
			r:Verdict(secret == 0, "the spell range answer is never secret in a fight")
			r:Verdict(plain > 0, "the game answers in or out of range in a fight")
			State(r, "with the game's answer")
			-- The mark with a stand-in answer: out of range, then in.
			ns.RangeHint.Fake(false)
			r:Sleep(1)
			local st = State(r, "out of range (stand-in)")
			r:Verdict(st.out and st.alpha == 1, "out of range: the mark is up")
			r:Verdict(st.name and st.name ~= "", "it says the spell's name: " .. tostring(st.name))
			r:Verdict(_G.CinematicRangeHint:IsVisible(), "its frame is on screen")
			r:Shot("Range Hint mark under the character")
			ns.RangeHint.Fake(true)
			r:Sleep(1)
			st = State(r, "in range (stand-in)")
			r:Verdict(not st.out and st.alpha == 0, "in range: the mark is gone")
			ns.RangeHint.Fake(nil)
			r:Sleep(0.3)
			State(r, "the game's answer again")
		end },
	},
	finish = function()
		if ns.RangeHint then
			ns.RangeHint.Fake(nil)
			if ns.RangeHint.Mover() and ns.RangeHint.Mover():IsShown() then ns.RangeHint.EditExit() end
		end
	end,
})
