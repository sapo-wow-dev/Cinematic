-- /cine debug stylestudio: the Style pages in game, hands off. Since 2026-11-25 every Style
-- page is its old page again but the Nameplates ones (Nameplate Style, Layout, Names) and
-- Range Hint's, which keep the editor (Style/Studio/*). Steps:
--   1 sticky    each Style hub group one run of icons; every page's preview held at the top
--               as it scrolls
--   2 pages     every Style page opened, one shot each
--   castpreview Unit Frames > Cast Bars' preview in the game's look and a theme's: the
--               target's alone, every part inside, its bar off its buffs; a shot each
--   3 editors   Nameplates, Layout, Names, Range Hint: the editor shows, a part picks, no
--               Copy look / Paste / Hold to compare
--   4 model     a setting set through the editor, Undo, Redo, Reset (frame) and its count
--   5 looks     a look (Tooltips' Clean) applied as one step and undone as one
--   6 buttons   every editor button clicked, and what it does
-- Every setting it touches is put back at the end. Into CinematicDB.styleStudioTestLog.
local _, ns = ...

local TOUCHED = { "styleGeneral", "tooltipStyle", "tooltipTextSize", "tooltipEdge", "tooltipBack", "tooltipAlpha",
	"tooltipOutline", "tooltipShadow", "tooltipBar", "tooltipNames", "tooltipBarHeight", "tooltipFont",
	"tooltipBarTexture", "tooltipBarColor", "tooltipGradient", "tooltipGradDir", "tooltipBarGround",
	"unitCastStyle", "ufStyle", "ufShape" }

-- Every button clicked as you would (:Click()), and what it should do checked: the user,
-- 2026-11-25: "you also need to test buttons ... clicking [Looks] again doesnt close it,
-- going to a new tab still shows it". Gives { { ok, text } }. Run by the in-game step
-- "buttons" and offline (Tools/offline/stylestudio.lua). real: a real client (mouse checks).
function ns.StyleStudioButtonChecks(real)
	local out = {}
	local function Check(ok, text) out[#out + 1] = { ok and true or false, text } end
	-- (A click: the game's own :Click() in game; offline the button's OnClick, as the
	-- stand-in's Click runs no script.)
	local function Press(b)
		if not b then return end
		if real then b:Click() return end
		local fn = b.GetScript and b:GetScript("OnClick")
		if fn then fn(b, "LeftButton", false) end
	end
	local Studio = ns.Studio
	local list = function() return _G.CinematicStudioList end
	-- (A frame's tick: the game runs the menu's own check each frame; offline, one run here.)
	local function Tick()
		local l = list()
		local fn = l and l:IsShown() and l:GetScript("OnUpdate")
		if fn then fn(l, 0.02) end
	end
	local function ListShown() Tick() local l = list() return l and l:IsShown() and true or false end
	local function Row(i) local l = list() return l and l.rows and l.rows[i] end
	local db = ns.GetDB()
	-- The window, on Tooltips (it has looks of its own).
	ns.OpenStyleStudio("tooltips")
	local win = ns.StyleStudioWindow()
	local B = win.buttons
	Check(B.looks:IsShown(), "Tooltips: Looks shown (it has looks)")
	-- Looks: opens, the same button closes it, a click elsewhere closes it.
	Press(B.looks)
	Check(ListShown(), "Looks: a click opens its menu")
	Press(B.looks)
	Check(not ListShown(), "Looks: a second click closes it")
	Press(B.looks)
	if real then
		local l = list()
		local onEvent = l and l:GetScript("OnEvent")
		-- (A click elsewhere: the game's GLOBAL_MOUSE_DOWN with the mouse off the list and its button.)
		if onEvent and not l:IsMouseOver() and not B.looks:IsMouseOver() then
			onEvent(l, "GLOBAL_MOUSE_DOWN", "LeftButton")
			Check(not ListShown(), "Looks: a click elsewhere closes it")
		end
	end
	if not ListShown() then Press(B.looks) end
	-- A look picked: one step, Undo puts it back.
	local steps = #Studio.hist
	local before = db.tooltipEdge
	local row = Row(2) -- (1: Theme's; 2: the first of Tooltips' own)
	if row then Press(row) end
	Check(not ListShown() and #Studio.hist == steps + 1, "Looks: picking one closes the menu and makes one step")
	Press(B.undo)
	Check(db.tooltipEdge == before, "Undo: puts the look back (" .. tostring(db.tooltipEdge) .. ")")
	Press(B.redo)
	Press(B.undo)
	-- The menu goes with its button: another frame (no looks: Looks hidden) closes it.
	Press(B.looks)
	ns.OpenStyleStudio("action")
	Check(not B.looks:IsShown(), "Action bars: no looks of its own, no Looks button")
	Check(not ListShown(), "Looks: its menu closed as its button went")
	ns.OpenStyleStudio("tooltips")
	-- Reset: the scopes, then the confirm, then reset; Undo back.
	local f = Studio.frames.tooltips
	local prop, part
	for _, each in ipairs(Studio.Props(f)) do if each.prop.key == "tooltipBarHeight" then prop, part = each.prop, each.part end end
	Studio.Set(f, prop, nil, 11, part)
	Press(B.reset)
	Check(ListShown(), "Reset: a click opens the scopes")
	Press(B.reset)
	Check(not ListShown(), "Reset: a second click closes them")
	Press(B.reset)
	local frameRow
	local l = list()
	for _, r in ipairs(l and l.rows or {}) do if r:IsShown() and r.value == "frame" then frameRow = r end end
	if frameRow then Press(frameRow) end
	Check(ListShown(), "Reset: a scope asks to confirm")
	local yes = Row(1)
	if yes and yes.value == "yes" then Press(yes) end
	Check(db.tooltipBarHeight ~= 11, "Reset: confirmed, the frame's settings back (bar height " .. tostring(db.tooltipBarHeight) .. ")")
	Press(B.undo)
	Check(db.tooltipBarHeight == 11, "Undo: the reset undone")
	-- The row's own x.
	ns.OpenStyleStudio("tooltips", nil, part.id)
	local prow = win.body.rows[prop]
	if prow and prow.reset:IsShown() then Press(prow.reset) end
	Check(db.tooltipBarHeight ~= 11 and Studio.SourceOf(f, prop, nil) ~= "yours", "Row x: that setting back")
	-- The Part dropdown: each part picked from its list (the user 2026-11-25: dropdowns,
	-- not rows of pills). Its list opened, then each row pressed.
	local function PickEach(drop, read, what)
		local picked, total = 0, 0
		for i = 1, #(drop.options or {}) do
			Press(drop)
			local r = Row(i)
			if r then
				total = total + 1
				local want = r.value
				Press(r)
				if read() == want then picked = picked + 1 else Check(false, what .. " " .. tostring(want)) end
			end
		end
		return picked, total
	end
	local pickRow = win.body.pickRow
	Check(pickRow and pickRow.partDrop:IsShown(), "Part dropdown shown")
	local picked = pickRow and PickEach(pickRow.partDrop, function() return win.body.part and win.body.part.id end, "Part") or 0
	Check(picked >= 3, picked .. " parts each picked from the Part dropdown")
	-- The variants dropdown (Raid frames).
	ns.OpenStyleStudio("raid")
	pickRow = win.body.pickRow
	Check(pickRow and pickRow.variantDrop:IsShown(), "Applies to dropdown shown")
	local vpicked = pickRow and PickEach(pickRow.variantDrop, function() return win.host.variant end, "Variant") or 0
	Check(vpicked >= 3, vpicked .. " variants each picked from the Applies to dropdown")
	-- Copy look, then Paste where it fits.
	Press(B.copy)
	Check(Studio.lookClip ~= nil, "Copy look: copied (" .. tostring(Studio.lookClip and Studio.lookClip.from) .. ")")
	-- Pop out / Dock: its words follow.
	local was = B.pop.text:GetText()
	Press(B.pop)
	local now = B.pop.text:GetText()
	Press(B.pop)
	Check(was ~= now and B.pop.text:GetText() == was, ("Pop out: %s -> %s -> %s"):format(tostring(was), tostring(now), tostring(B.pop.text:GetText())))
	-- 2x: twice the size, then back.
	ns.OpenStyleStudio("plates")
	local slot = win.slots.plates
	local s0 = slot and slot.preview and slot.preview:GetScale()
	Press(B.zoom)
	local s1 = slot and slot.preview and slot.preview:GetScale()
	Press(B.zoom)
	if real then
		Check(s0 and s1 and math.abs(s1 - 2 * s0) < 0.01 and math.abs(slot.preview:GetScale() - s0) < 0.01,
			("2x: %s -> %s -> back"):format(tostring(s0), tostring(s1)))
	else -- (the stand-in keeps no scale: the toggle itself)
		Press(B.zoom)
		local on = win.zoomed
		Press(B.zoom)
		Check(on == true and not win.zoomed, "2x: on, then off")
	end
	-- Rail: a frame's line opens it.
	local opened
	for _, b in ipairs(win.railItems) do
		if b:IsShown() and b.frameId == "tooltips" then Press(b) opened = win.host.f and win.host.f.id end
	end
	Check(opened == "tooltips", "Rail: Tooltips' line opens it (" .. tostring(opened) .. ")")
	-- Find: typing lists, Enter on a hit opens it; the list goes.
	win.find:SetText("outline")
	-- (Typing, as a player's keys do: OnTextChanged with userInput. SetText alone didn't
	-- list in game, run q3c49 (the stand-in fires nothing at all).)
	local typed = win.find:GetScript("OnTextChanged")
	if typed and not ListShown() then typed(win.find, true) end
	Check(ListShown(), "Find: typing lists the settings")
	local hit = Row(1)
	if hit then Press(hit) end
	Check(not ListShown() and win.host.f ~= nil, "Find: a hit opens its frame (" .. tostring(win.host.f and win.host.f.id) .. ")")
	-- The page column: its Looks closes as its page hides (a tab changed).
	local box = CreateFrame("Frame", nil, UIParent)
	box:SetSize(500, 400)
	box:SetPoint("CENTER")
	local content = CreateFrame("Frame", nil, box)
	content:SetAllPoints()
	local anchor = CreateFrame("Frame", nil, content)
	anchor:SetSize(1, 1)
	anchor:SetPoint("TOPLEFT")
	local kit = ns.lowHealthKit
	-- (A test page of its own: the Tooltips frame's page is the old page, no editor, and
	-- stays so once this is done: its pageCanvas put back.)
	local tipFrame = Studio.frames.tooltips
	local hadCanvas = tipFrame and tipFrame.pageCanvas
	local ok, host = pcall(ns.StyleEditorPage, kit, content, kit.Stack(anchor, "label"), "tooltips",
		{ preview = ns.MakeTooltipPreview(content, 480), canvas = content, ownReset = true })
	if tipFrame then tipFrame.pageCanvas = hadCanvas end
	Check(ok and host, "Page column: built (" .. tostring(ok and "ok" or host) .. ")")
	if ok and host then
		host:Redraw()
		Check(host.looksB:IsShown(), "Page: Looks shown")
		Press(host.looksB)
		Check(ListShown(), "Page: Looks opens")
		Press(host.looksB)
		Check(not ListShown(), "Page: a second click closes it")
		Press(host.looksB)
		content:Hide() -- (as the page's tab is changed)
		-- (In game only: the stand-in's IsVisible doesn't look at a frame's parents.)
		if real then
			Check(not ListShown(), "Page: its menu closed as the tab changed")
		elseif list() then
			list():Hide()
		end
		content:Show()
		Press(host.resetB)
		Check(ListShown(), "Page: Reset opens")
		Press(host.resetB)
		Check(not ListShown(), "Page: Reset closes on a second click")
		Press(host.undoB)
		Press(host.redoB)
		Check(true, "Page: Undo and Redo clicked without an error")
	end
	box:Hide()
	-- The rail and the settings column: more than fits shows its signs, and the last line
	-- comes fully into view at the bottom (the user, 2026-11-25: "Combat" cut in half).
	if real then
		ns.OpenStyleStudio("names")
		for _, each in ipairs({ { win.rail, "rail" }, { win.insp, "settings column" } }) do
			local scroll, name = each[1], each[2]
			if scroll and scroll.UpdateSigns then
				scroll.UpdateSigns()
				local child = scroll:GetScrollChild()
				local full, view = tonumber(child and child:GetHeight()) or 0, tonumber(scroll:GetHeight()) or 0
				local more = full > view + 2
				Check(not more or scroll.hasMore, name .. ": more than fits, and its scroll bar shows")
				if more then
					scroll:SetVerticalScroll(math.max(0, full - view))
					scroll.UpdateSigns()
					local lowest
					for _, kid in ipairs({ child:GetChildren() }) do
						if kid:IsShown() and kid:GetBottom() and (not lowest or kid:GetBottom() < lowest:GetBottom()) then lowest = kid end
					end
					Check(lowest and lowest:GetBottom() >= scroll:GetBottom() - 0.5,
						name .. ": scrolled down, its last line is whole in view")
					scroll:SetVerticalScroll(0)
				end
			end
		end
	end
	-- Done closes the window.
	Press(B.done)
	Check(not win:IsShown(), "Done: closes the Studio")
	return out
end

ns.TestKit.Define({
	name = "stylestudio",
	key = "styleStudioTest",
	title = "Style Studio",
	about = "the Style Studio window on every frame: parts, Undo, Reset, a look, Find; hands off",
	settings = TOUCHED,
	context = function()
		local n = ns.Studio and #ns.Studio.Ordered() or 0
		return ("style studio: %d frames, Enable Style %s"):format(n, tostring(ns.db and ns.db.styleGeneral))
	end,
	steps = {
		-- (The look review after the revert to the old look, the user 2026-11-25: every Style
		-- page as a player opens it, one shot each. The Studio window has no links now.)
		-- (Every page's preview held at its top as you scroll: ns.StylePopout was dropped
		-- from 15 pages with the editor and put back, the user 2026-11-25, "the preivewer
		-- doesnt minimize when scrolling".)
		{ key = "sticky", title = "every page's preview held at the top as you scroll", handsOff = true,
			run = function(r)
			local Studio = ns.Studio
			-- (Each Style hub group one unbroken run of icons: Range Hint Style's Info icon
			-- among Combat's split Combat in two bands drawn over each other, 2026-11-25.)
			local done, last = {}, nil
			for _, icon in ipairs(ns.HubIcons and ns.HubIcons("Style") or {}) do
				local group = icon.band .. "/" .. tostring(icon.sub)
				if group ~= last then
					r:Verdict(not done[group], ("hub group %s in one run (%s)"):format(group, icon.name))
					done[group], last = true, group
				end
			end
			r:Set("styleGeneral", true)
			r:Set("stylePreviewOut", nil)
			r:Set("stylePreviewFolded", nil)
			local seen, shot = {}, false
			for _, f in ipairs(Studio.Ordered()) do
				local page = f.page
				if not page and f.pages then for id in pairs(f.pages) do page = page or id end end
				if page and not seen[page] then
					seen[page] = true
					r:Probe("open " .. page, ns.OpenOptions, page)
					r:Sleep(0.3)
					local preview
					for _, each in ipairs(ns.STYLE_PREVIEWS or {}) do
						if each:IsVisible() and each.pin then preview = each end
					end
					if not preview then
						r:Log(page .. ": no preview showing (its page off, or none)")
					else
						local scroll = preview.pin.scroll
						local range = scroll:GetVerticalScrollRange() or 0
						scroll:SetVerticalScroll(math.min(range, 400))
						r:Sleep(0.4)
						r:Verdict(range < 60 or preview.pin.target == true,
							("%s: preview held at the top, scrolled %d of %d"):format(page, math.min(range, 400), range))
						if not shot and range >= 60 then r:Shot(page .. " scrolled") shot = true end
						scroll:SetVerticalScroll(0)
						r:Sleep(0.2)
					end
				end
			end
		end },
		{ key = "pages", title = "every Style page opens, one shot each", handsOff = true, run = function(r)
			local Studio = ns.Studio
			r:Set("styleGeneral", true)
			local seen = {}
			for _, f in ipairs(Studio.Ordered()) do
				local page = f.page
				if not page and f.pages then for id in pairs(f.pages) do page = page or id end end
				if page and not seen[page] then
					seen[page] = true
					local ok, err = r:Probe("open " .. page, ns.OpenOptions, page)
					r:Verdict(ok, ("%s: page opened%s"):format(page, ok and "" or (" - " .. tostring(err))))
					r:Sleep(0.3)
					r:Shot(page)
				end
			end
		end },
		-- (Unit Frames > Cast Bars' preview, the user 2026-11-25: the target's frame ran into
		-- the boss's, then bars sat on auras; now the target's alone, its bar where the game
		-- hangs it. Each look: every drawn part inside, the bar clear of its buffs.)
		{ key = "castpreview", title = "Cast Bars' preview: the target's alone, nothing on anything",
			handsOff = true, run = function(r)
			r:Set("styleGeneral", true)
			r:Set("unitCastStyle", true)
			local ok, err = r:Probe("open Unit Cast Style", ns.OpenOptions, "Unit Cast Style")
			r:Verdict(ok, "Cast Bars page opened" .. (ok and "" or (" - " .. tostring(err))))
			r:Sleep(0.5)
			local preview = ns.castPreviews and ns.castPreviews["Unit Cast Style"]
			r:Verdict(preview and preview:IsVisible(), "its preview on screen")
			if not (preview and preview:IsVisible()) then return end
			local function Box(f)
				local k = f:GetEffectiveScale()
				local left, right, top, bottom = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
				if not (left and right and top and bottom) then return nil end
				return left * k, right * k, top * k, bottom * k
			end
			local function Inside(a, b)
				local al, ar, at, ab = Box(a)
				local bl, br, bt, bb = Box(b)
				if not (al and bl) then return true end
				return al >= bl - 2 and ar <= br + 2 and at <= bt + 2 and ab >= bb - 2
			end
			local function Apart(a, b)
				local al, ar, at, ab = Box(a)
				local bl, br, bt, bb = Box(b)
				if not (al and bl) then return true end
				return ar <= bl + 1 or br <= al + 1 or ab >= bt - 1 or bb >= at - 1
			end
			local function Drawn(plate, bar)
				local unit = plate.unitFrame.unit
				local list = { bar, plate.unitFrame.tot, unit, unit.dragon }
				for _, aura in ipairs(unit.auras or {}) do list[#list + 1] = aura end
				local shown = {}
				for _, part in pairs(list) do
					if part and part:IsShown() and part:GetLeft() then shown[#shown + 1] = part end
				end
				return shown
			end
			for _, look in ipairs({ "game", "theme" }) do
				r:Set("ufStyle", look == "theme")
				r:Set("ufShape", look == "theme" and "circle" or "game")
				ns.RefreshUnitStyle()
				preview:Refresh()
				r:Sleep(0.6)
				local plates, samples = preview.plates, preview.samples
				local outside, over = {}, 0
				for i, plate in ipairs(plates) do
					for j, part in ipairs(Drawn(plate, samples[i])) do
						if not (Inside(part, plate) and Inside(part, preview)) then
							outside[#outside + 1] = ("sample %d part %d"):format(i, j)
						end
					end
				end
				if #plates == 2 then
					for _, a in ipairs(Drawn(plates[1], samples[1])) do
						for _, b in ipairs(Drawn(plates[2], samples[2])) do
							if not Apart(a, b) then over = over + 1 end
						end
					end
				end
				r:Verdict(#outside == 0, ("%s look: every drawn part inside its sample and the preview%s"):format(look,
					#outside == 0 and "" or (" - out: " .. table.concat(outside, ", "))))
				-- (The target's alone for now, user 2026-11-25.)
				r:Verdict(#plates == 1 and over == 0, ("%s look: the target's sample alone (%d)"):format(look, #plates))
				for i, plate in ipairs(plates) do
					local l, rr, t, b = Box(plate)
					if l then r:Log(("%s look: sample %d at %d..%d x %d..%d, scale %.2f"):format(look, i, l, rr, b, t,
						plate:GetScale())) end
				end
				-- (Inside each sample too: the target's cast bar off its buffs, the boss's
				-- off nothing but its own frame. Theme look 2026-11-25: Drain Life on Thrall.)
				local target = plates[1] and plates[1].unitFrame
				local onBuffs = 0
				for _, aura in ipairs(target and target.unit.auras or {}) do
					if aura:IsShown() and not Apart(aura, samples[1]) then onBuffs = onBuffs + 1 end
				end
				r:Verdict(onBuffs == 0, ("%s look: the target's cast bar clear of its buffs (%d on it)"):format(look, onBuffs))
				r:Verdict(not (target and target.tot and target.tot:IsShown()), look .. " look: the target with no target of target")
				local point, relative, relativePoint, x, y = samples[1]:GetPoint(1)
				r:Log(("%s look: target bar %s>%s %.1f,%.1f on %s"):format(look, tostring(point), tostring(relativePoint),
					x or 0, y or 0, relative == (target and target.unit) and "its frame" or "an aura or its bars"))
				r:Shot("Cast Bars preview, " .. look .. " look", { behind = preview })
			end
		end },
		-- (The editor's pages since the old pages came back, the user 2026-11-25: "i want the
		-- old pages back except for nameplates". Each opens with its editor, a part picked.)
		{ key = "editors", title = "the editor on Nameplates, Layout, Names and Range Hint", handsOff = true,
			run = function(r)
			local Studio = ns.Studio
			for _, each in ipairs({ { "Nameplate Style", "plates" }, { "Nameplate Layout", "platelayout" },
				{ "Name Style", "names" }, { "Range Hint Style", "range" } }) do
				local page, id = each[1], each[2]
				local f = Studio.frames[id]
				if not (f and f.pageCanvas) then
					r:Log(page .. ": no page on this client")
				else
					r:Probe("open " .. page, ns.OpenOptions, page)
					r:Sleep(0.3)
					local host
					for h in pairs(ns.StylePageHosts and ns.StylePageHosts() or {}) do
						if h.f == f and h:IsVisible() then host = h end
					end
					r:Verdict(host ~= nil, page .. ": its editor shows")
					if host then
						local parts = f.parts or {}
						local last = parts[#parts]
						if last then
							local ok = pcall(host.Pick, host, last.id)
							r:Verdict(ok and host.partId == last.id, ("%s: part %s picked"):format(page, last.id))
						end
						r:Verdict(not (host.copyB or host.pasteB or host.compareB),
							page .. ": no Copy look, Paste or Hold to compare")
						r:Shot(page .. " editor")
						if parts[1] then pcall(host.Pick, host, parts[1].id) end
					end
				end
			end
		end },
		-- (The mock built, 2026-11-25 (Tools/style-studio/page-mock.html): Nameplate Style's
		-- preview beside the settings, parts as tabs (Bar, Colors, Name), pickers, no Looks or
		-- Reset; Default's colors per kind of unit reach the preview; a Smart row's Colors;
		-- Layout's parts with Shown; the Show in row on the Nameplates page's Style tab.)
		{ key = "mockplates", title = "Nameplate Style as the mock: side preview, tabs, colors per kind", handsOff = true,
			run = function(r)
			local Studio = ns.Studio
			local f = Studio.frames.plates
			-- (Still while nothing changes, the user 2026-11-25: "the preview shakes". Its height,
			-- its top and its plate's place sampled 15 times a tenth of a second apart.)
			local function Steady(label, frame, plateOf)
				if not frame then return end
				local seen = { h = {}, t = {}, px = {}, py = {} }
				for _ = 1, 15 do
					local okH, h = pcall(frame.GetHeight, frame)
					local okT, t = pcall(frame.GetTop, frame)
					if okH and h then seen.h[#seen.h + 1] = h end
					if okT and t then seen.t[#seen.t + 1] = t end
					local plate = plateOf and plateOf()
					if plate then
						local okP, l, b = pcall(function() return plate:GetLeft(), plate:GetBottom() end)
						if okP and l then seen.px[#seen.px + 1] = l * plate:GetEffectiveScale() end
						if okP and b then seen.py[#seen.py + 1] = b * plate:GetEffectiveScale() end
					end
					r:Sleep(0.1)
				end
				local words, still = {}, true
				for _, k in ipairs({ "h", "t", "px", "py" }) do
					local lo, hi = math.huge, -math.huge
					for _, v in ipairs(seen[k]) do lo, hi = math.min(lo, v), math.max(hi, v) end
					if #seen[k] > 0 then
						words[#words + 1] = ("%s %.1f-%.1f"):format(k, lo, hi)
						if hi - lo > 0.5 then still = false end
					end
				end
				r:Verdict(still, label .. ": the preview holds still (" .. table.concat(words, ", ") .. ")")
			end
			local function GamePlateOf(holder)
				return function()
					local game = holder and holder.gamePlate
					return game and game.gameCopy and game.gameCopy.HealthBarsContainer
				end
			end
			r:Set("styleGeneral", true)
			r:Set("handlePlateStyle", true)
			r:Set("plateKindColor_hostileNpcs", "game")
			r:Probe("open Nameplate Style", ns.OpenOptions, "Nameplate Style")
			r:Sleep(0.5)
			local host
			for h in pairs(ns.StylePageHosts and ns.StylePageHosts() or {}) do
				if h.f == f and h:IsVisible() then host = h end
			end
			r:Verdict(host ~= nil, "its editor shows")
			if not host then return end
			local preview = host.preview
			-- (Docked to start: popping out is kept account-wide, and a window left out from play put
			-- every place check off, run q4a79. Put back as it was at the end.)
			local wasOut = ns.StylePreviewIsPopped and ns.StylePreviewIsPopped(preview)
			if wasOut and preview.popButton then
				preview.popButton:Click()
				r:Sleep(0.6)
			end
			local pl, hl = preview and preview:GetRight(), host.holder:GetLeft()
			r:Verdict(pl and hl and hl >= pl - 1, ("the settings right of the preview (preview right %s, settings left %s)"):format(
				tostring(pl and math.floor(pl)), tostring(hl and math.floor(hl))))
			-- (Nothing past the page's right edge: 452 wide ran under it, dropdown arrows and swatches
			-- cut, run q496d's shot.)
			local hr, pr = host.holder:GetRight(), host.holder:GetParent() and host.holder:GetParent():GetRight()
			local canvas = f.pageCanvas
			local cr = canvas and canvas.GetRight and canvas:GetRight()
			local edge = cr or pr
			r:Verdict(hr and edge and hr <= edge + 1, ("the settings inside the page (right %s, page right %s)"):format(
				tostring(hr and math.floor(hr)), tostring(edge and math.floor(edge))))
			local ids = {}
			for _, p in ipairs(f.parts) do ids[#ids + 1] = p.id end
			-- (Mark: a Smart row's only, hidden on Default.)
			r:Verdict(table.concat(ids, ",") == "mark,bar,colors,name", "parts: " .. table.concat(ids, ","))
			local tabs = 0
			for _, t in ipairs(host.body.tabs or {}) do if t:IsShown() then tabs = tabs + 1 end end
			r:Verdict(tabs == 3, ("the parts as %d tabs"):format(tabs))
			r:Verdict(not host.looksB:IsShown() and not host.resetB:IsShown(), "no Looks or Reset")
			-- (The parts as folder tabs: the user 2026-11-25 "more of a folder tab style".)
			local pickedTab
			for _, t in ipairs(host.body.tabs or {}) do if t:IsShown() and t.partId == host.partId then pickedTab = t end end
			r:Verdict(pickedTab and pickedTab.bg and pickedTab.edges and host.body.tabBase and host.body.tabBase:IsShown(),
				"the parts as folder tabs over a line")
			-- (no box behind the tabs: the settings' box starts at their line, the user 2026-11-25)
			local bt, lt = host.box and host.box:GetTop(), host.body.tabBase and host.body.tabBase:GetTop()
			r:Verdict(bt and lt and math.abs(bt - lt) < 1.5, ("the settings' box starts at the tabs' line (%s, %s)"):format(
				tostring(bt and math.floor(bt)), tostring(lt and math.floor(lt))))
			-- (The mock's chrome: the title and its On switch over the page, no Reset page.)
			-- (The page's content: the holder sits in one of its part hosts, run qb407.)
			local function PageOf(frame, field)
				for _ = 1, 8 do
					if not frame then return nil end
					if frame[field] then return frame end
					frame = frame:GetParent()
				end
			end
			local content = PageOf(host.holder, "mockHead")
			local head = content and content.mockHead
			r:Verdict(head and head:IsVisible() and head.title:GetText() == ns.L["Nameplate Style"]
				and head.switch:IsVisible(), "the mock's title and On switch: " .. tostring(head and head.title:GetText()))
			-- (Folder tabs over a framed panel round the whole page, as the Nameplates page's
			-- sections, the user 2026-11-25: "like the screenshot".)
			local tabPanel = content and content.pageTabs and content.pageTabs.panel
			local ph = tabPanel and tabPanel:GetHeight() or 0
			r:Verdict(ph > 300 and head and head:GetTop() and tabPanel:GetTop() and head:GetTop() <= tabPanel:GetTop(),
				("the page in the tabs' framed panel (%d tall), the title inside it"):format(math.floor(ph)))
			local pr2 = tabPanel and tabPanel:GetRight()
			local hr2 = host.holder:GetRight()
			r:Verdict(pr2 and hr2 and hr2 <= pr2 - 6, ("the settings clear of the panel's right edge (%s, %s)"):format(
				tostring(hr2 and math.floor(hr2)), tostring(pr2 and math.floor(pr2))))
			-- (Nothing showing behind the tabs, the user 2026-11-25: "tabs ... look broken" (bits of
			-- hidden text and a box outline peeked out round them). Every shown frame and region of
			-- the page in the tab row's strip, not the tabs themselves, is named.)
			local tabFrames = content and content.pageTabs and content.pageTabs.frames or {}
			local isTab = {}
			for _, t in ipairs(tabFrames) do
				isTab[t] = true
				for _, kid in ipairs({ t:GetChildren() }) do isTab[kid] = true end
				for _, reg in ipairs({ t:GetRegions() }) do isTab[reg] = true end
			end
			local t1 = tabFrames[1]
			-- (In screen units: frames scaled differently (the preview's plate) compared as drawn.)
			local function Box(o)
				local okB, l, b, w, h = pcall(function() return o:GetLeft(), o:GetBottom(), o:GetWidth(), o:GetHeight() end)
				local okS, sc = pcall(o.GetEffectiveScale, o)
				if not (okB and l and b and w and h and okS and sc) then return nil end
				return l * sc, b * sc, (l + w) * sc, (b + h) * sc
			end
			local tl, tb, tt, tr
			if t1 then tl, tb, _, tt = Box(t1) end -- (not "t1 and Box(t1)": that keeps one value)
			if tabFrames[#tabFrames] then _, _, tr = Box(tabFrames[#tabFrames]) end
			local under = {}
			local seen = {}
			local function Walk(frame, depth)
				if depth > 9 or seen[frame] or isTab[frame] or frame == tabPanel then return end
				seen[frame] = true
				local objs = { frame }
				for _, reg in ipairs({ frame:GetRegions() }) do objs[#objs + 1] = reg end
				for _, o in ipairs(objs) do
					local okV, vis = pcall(o.IsVisible, o)
					local okA, alpha = pcall(o.GetEffectiveAlpha, o)
					if not isTab[o] and okV and vis and (not okA or alpha > 0.05) then
						local l, b, rr, t = Box(o)
						-- (its middle in the tab row's strip, left of the tabs' end; not a page-sized frame)
						if l and tl and tr and (t - b) < 60 and (rr - l) < 400 and (b + t) / 2 > tb and (b + t) / 2 < tt + 4
							and l < tr + 60 and rr > tl then
							local words = o.GetText and o:GetText()
							under[#under + 1] = ("%s %s %q at %d-%d x %d-%d (parent %s)"):format(o:GetObjectType(),
								tostring(o:GetName()), tostring(words), math.floor(l), math.floor(rr), math.floor(b), math.floor(t),
								tostring(o.GetParent and o:GetParent() and o:GetParent():GetObjectType()))
						end
					end
				end
				for _, kid in ipairs({ frame:GetChildren() }) do Walk(kid, depth + 1) end
			end
			local root = canvas
			for _ = 1, 3 do if root and root:GetParent() then root = root:GetParent() end end
			if root then Walk(root, 0) end
			-- (and the world doesn't show through them: nameplates behind the window did)
			r:Verdict(canvas and canvas.mockSolid and canvas.mockSolid:IsVisible() and tabPanel and tabPanel.mockSolid
				and tabPanel.mockSolid:IsVisible(), "solid under the tabs and the panel: no world through them")
			r:Verdict(#under == 0, "nothing behind the tabs: " .. (#under > 0 and table.concat(under, "; ") or "none"))
			-- (The settings on a box of their own, a shade off the panel: the user 2026-11-25.)
			r:Verdict(host.box and host.box:IsVisible() and host.box:GetRight() <= (tabPanel and tabPanel:GetRight() or 0) - 1,
				"the settings on a box of their own, inside the panel")
			-- (Reset page there, as every page's: the user 2026-11-25 "RESET PAGE MISSING".)
			local hubReset
			for _, f2 in ipairs({ canvas and canvas:GetParent() or false }) do
				for _ = 1, 4 do
					if not f2 then break end
					for _, kid in ipairs({ f2:GetChildren() }) do
						if kid.GetText and kid:GetText() == ns.L["Reset page"] and kid:IsVisible() then hubReset = kid end
					end
					f2 = f2:GetParent()
				end
			end
			r:Verdict(hubReset ~= nil, "Reset page shown")
			local lp = preview and preview.lookPreview
			r:Verdict(not (lp and lp.sceneButton and lp.sceneButton:IsShown()), "no Scene button on the stage")
			-- (Not black: every preview's backdrop, the user 2026-11-25 "black background....")
			r:Verdict(lp and lp.styleScene and lp.styleScene:IsShown(), "the stage on every preview's backdrop, not black")
			Steady("Default", preview, GamePlateOf(preview and preview.lookPreview))
			-- (Aggro ticked: what shows, by your threat setting's bits, the user 2026-11-25 "aggro not
			-- doing anything".)
			local lpv = preview and preview.lookPreview
			local gcopy = lpv and lpv.gamePlate and lpv.gamePlate.gameCopy
			if gcopy and ns.TogglePlatePreviewState then
				local hb = gcopy.HealthBarsContainer.healthBar
				local r0, g0, b0 = hb:GetStatusBarColor()
				if not ns.PlatePreviewStates(lpv).aggro then ns.TogglePlatePreviewState("aggro", lpv) end
				preview:Refresh()
				r:Sleep(0.6)
				local r1, g1, b1 = hb:GetStatusBarColor()
				local registry, constants = _G.CVarCallbackRegistry, _G.NamePlateConstants
				local td = Enum and Enum.NamePlateThreatDisplay
				local function Bit(w)
					local ok, on = pcall(function() return registry:GetCVarBitfieldIndex(constants.THREAT_DISPLAY_CVAR, td[w]) end)
					return ok and tostring(on) or "?"
				end
				local glow = gcopy.aggroHighlight and gcopy.aggroHighlight:IsVisible()
				local flash = gcopy.aggroFlash and gcopy.aggroFlash:IsVisible()
				r:Log(("aggro: threat bits flash %s progressive %s bar %s; glow %s flash %s; bar %.2f,%.2f,%.2f -> %.2f,%.2f,%.2f")
					:format(Bit("Flash"), Bit("Progressive"), Bit("HealthBarColor"), tostring(glow), tostring(flash),
					r0, g0, b0, r1, g1, b1))
				local changed = glow or flash or math.abs(r1 - r0) + math.abs(g1 - g0) + math.abs(b1 - b0) > 0.05
				-- (Your threat display all off: the game shows nothing for aggro, nor does the preview,
				-- run q4a79.)
				if Bit("Flash") == "false" and Bit("Progressive") == "false" and Bit("HealthBarColor") == "false" then
					r:Skip("your threat display is off: the game shows nothing for aggro (nothing changed: " .. tostring(not changed) .. ")")
				else
					r:Verdict(changed, "Default: Aggro ticked shows on the preview's plate (see the aggro line)")
				end
				r:Shot("Nameplate Style, Aggro ticked")
				ns.TogglePlatePreviewState("aggro", lpv)
				preview:Refresh()
				r:Sleep(0.3)
			end
			-- (Popped out: the plate fits the window, nothing off its top, the user 2026-11-25.)
			if preview and preview.popButton then
				if not ns.StylePreviewIsPopped(preview) then preview.popButton:Click() end
				r:Sleep(0.8)
				r:Verdict(ns.StylePreviewIsPopped(preview), "Default: the preview popped out for the check")
				local copy2 = lpv and lpv.gamePlate and lpv.gamePlate.gameCopy
				-- (its highest part: the name, or its debuffs over it when they show)
				local nameTop
				for _, part in ipairs({ copy2 and copy2.name or false, copy2 and copy2.AurasFrame and copy2.AurasFrame.DebuffListFrame or false }) do
					if part and part:IsVisible() and part:GetTop() then
						local t = part:GetTop() * part:GetEffectiveScale()
						nameTop = nameTop and math.max(nameTop, t) or t
					end
				end
				local pTop = preview:GetTop() and preview:GetTop() * preview:GetEffectiveScale()
				r:Verdict(nameTop and pTop and nameTop <= pTop - 2, ("Default popped out: the plate inside the window (name top %s, window top %s)")
					:format(tostring(nameTop and math.floor(nameTop)), tostring(pTop and math.floor(pTop))))
				r:Shot("Nameplate Style, popped out")
				if ns.StylePreviewIsPopped(preview) then preview.popButton:Click() end
				r:Sleep(0.6)
			end
			-- (The Theme list opened: each option's picture drawn without an error, the user's log
			-- 2026-11-26 "SetAtlas(): Usage" from its Fill.)
			for _, row in ipairs(host.body.shownRows or {}) do
				if row:IsShown() and row.prop.label == ns.L["Theme"] and row.control and row.control.Click then
					row.control:Click()
					r:Sleep(0.4)
					r:Shot("Nameplate Style, the Theme list open")
					row.control:Click()
					r:Sleep(0.2)
					break
				end
			end
			r:Shot("Nameplate Style, Bar")
			host:Pick("colors", Studio.FirstVariant(f))
			r:Sleep(0.3)
			local rows = 0
			for _, row in ipairs(host.body.shownRows or {}) do if row:IsShown() then rows = rows + 1 end end
			r:Verdict(rows == 12, ("Default's Colors: a line and a Fade per kind (%d rows)"):format(rows))
			-- (A kind's color reaches the preview: Hostile NPCs in pure blue, the preview's first sample.)
			local prop
			for _, each in ipairs(Studio.Props(f, "colors")) do
				if each.prop.key == "plateKindColor_hostileNpcs" then prop = each.prop end
			end
			if prop then
				r:Set("plateKindColor_hostileNpcsR", 0) r:Set("plateKindColor_hostileNpcsG", 0) r:Set("plateKindColor_hostileNpcsB", 1)
				Studio.Set(f, prop, Studio.FirstVariant(f), "custom")
				r:Sleep(0.4)
				local inner = preview and preview.lookPreview
				-- (The previewer's game plate: its UnitFrame on the plate itself, or on its copy.)
				local plate = inner and inner.gamePlate
				local uf = plate and (plate.UnitFrame or (plate.gameCopy and plate.gameCopy.UnitFrame))
				local bar = uf and uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar
				local cr, cg, cb
				if bar then cr, cg, cb = bar:GetStatusBarColor() end
				r:Verdict(cb and cb > 0.8 and cr < 0.2, ("Hostile NPCs blue on the preview's plate (%s, %s, %s)"):format(
					tostring(cr), tostring(cg), tostring(cb)))
				r:Shot("Nameplate Style, Colors: Hostile NPCs blue")
				-- (Another player to preview the player colors on: Enemy player, a Warrior, Class showing
				-- the Warrior's color, the user 2026-11-26 "theres no class option to preview those colors".)
				if inner and inner.PickSample then
					r:Set("plateKindColor_enemyPlayers", "class")
					inner.PickSample(4)
					preview:Refresh()
					r:Sleep(0.4)
					local er, eg, eb
					if bar then er, eg, eb = bar:GetStatusBarColor() end -- (not "bar and ...": one value)
					local w = RAID_CLASS_COLORS and RAID_CLASS_COLORS.WARRIOR
					r:Verdict(w and er and math.abs(er - w.r) < 0.05 and math.abs(eg - w.g) < 0.05 and math.abs(eb - w.b) < 0.05,
						("Enemy player, Class: the Warrior's color on the preview (%s, %s, %s)"):format(tostring(er), tostring(eg), tostring(eb)))
					r:Shot("Nameplate Style, Enemy player in Class")
					inner.PickSample(1)
					preview:Refresh()
					r:Sleep(0.2)
				end
				Studio.Undo()
				r:Verdict(ns.db.plateKindColor_hostileNpcs ~= "custom", "one Undo: back to the game's")
			else
				r:Verdict(false, "no Hostile NPCs color line")
			end
			-- (A Smart row: its Plate color and Fade, every setting Default's till set.)
			local variants = ns.PlateStudioVariants and ns.PlateStudioVariants() or {}
			if variants[2] then
				host:Pick("colors", variants[2].id)
				r:Sleep(0.3)
				local labels = {}
				for _, row in ipairs(host.body.shownRows or {}) do
					if row:IsShown() then labels[#labels + 1] = row.prop.label or "?" end
				end
				r:Verdict(labels[1] == ns.L["Plate color"], "a row's Colors: " .. table.concat(labels, ", "))
				r:Shot("Nameplate Style, a Smart row's Colors")
				host:Pick("bar", Studio.FirstVariant(f))
				-- (Back on the short Bar part after the tall Colors: the panel hugs it again, no
				-- empty space under it, the user 2026-11-25 "lot of empty space".)
				r:Sleep(0.4)
				local dPanel = content and content.pageTabs and content.pageTabs.panel
				local dBox = host.box or host.holder
				local gap = dPanel and dBox:GetBottom() and dPanel:GetBottom() and (dBox:GetBottom() - dPanel:GetBottom())
				r:Verdict(gap and gap >= 4 and gap <= 40, ("Default: the panel hugs the settings after a tall part (%s under the box)"):format(
					tostring(gap and math.floor(gap))))
			end
			-- (Layout: each part's Shown.)
			local lf = Studio.frames.platelayout
			if lf and lf.pageCanvas then
				r:Probe("open Nameplate Layout", ns.OpenOptions, "Nameplate Layout")
				r:Sleep(0.4)
				local shown
				for _, each in ipairs(Studio.Props(lf, "level")) do if each.prop.label == ns.L["Shown"] then shown = true end end
				r:Verdict(shown, "Layout: the level box's Shown is here")
				-- (Smart's marks' two raises: Layout's Smart marks part, the user 2026-11-25.)
				local raises = {}
				for _, each in ipairs(Studio.Props(lf, "smartMarks")) do
					if type(each.prop.key) == "string" then raises[#raises + 1] = each.prop.key end
				end
				r:Verdict(table.concat(raises, ",") == "targetArrowY,targetArrowBareY",
					"Layout: a Smart marks part with the two raises: " .. table.concat(raises, ","))
				-- (At your profile's values, as Reset page leaves them: not marked edited, the user
				-- 2026-11-26 "after a reset smart marks looks like its been edited".)
				local base = ns.ProfileBase and ns.ProfileBase() or ns.DEFAULTS
				r:Set("targetArrowY", base.targetArrowY)
				r:Set("targetArrowBareY", base.targetArrowBareY)
				local edited = #Studio.Changed(lf, "all", "smartMarks")
				r:Verdict(edited == 0, ("Layout: Smart marks at your profile's values isn't marked edited (%d, raise %s)")
					:format(edited, tostring(base.targetArrowY)))
				local page = ns.plateLayoutPage
				local lprev, led = page and page.preview, page and page.editor
				local lr, ll = lprev and lprev:GetRight(), led and led.holder:GetLeft()
				r:Verdict(lr and ll and ll >= lr - 1, ("Layout: the settings right of the stage (%s, %s)"):format(
					tostring(lr and math.floor(lr)), tostring(ll and math.floor(ll))))
				local lcanvas = page and page.canvas
				local lhr, lcr = led and led.holder:GetRight(), lcanvas and lcanvas:GetRight()
				r:Verdict(lhr and lcr and lhr <= lcr + 1, ("Layout: the settings inside the page (%s, %s)"):format(
					tostring(lhr and math.floor(lhr)), tostring(lcr and math.floor(lcr))))
				-- (No choices stacked down the page: one line each, a picker where they don't fit, the
				-- user 2026-11-25 on Balance; Mirror a plain button.)
				local tall = {}
				for _, row in ipairs(led and led.body.shownRows or {}) do
					if row:IsShown() and row.control and row.control:GetHeight() > 24 then tall[#tall + 1] = row.prop.label or "?" end
				end
				r:Verdict(#tall == 0, "Layout: every setting on one line" .. (#tall > 0 and (": " .. table.concat(tall, ", ")) or ""))
				local lhead = led and PageOf(led.holder, "mockHead") and PageOf(led.holder, "mockHead").mockHead
				local ltabs = 0
				for _, t in ipairs(led and led.body.tabs or {}) do if t:IsShown() then ltabs = ltabs + 1 end end
				r:Verdict(ltabs == 0 and led.body.pickRow and led.body.pickRow.partDrop:IsShown(),
					("Layout: ten parts in a Part picker, no tabs past the edge (%d tabs)"):format(ltabs))
				r:Verdict(lhead and lhead:IsVisible() and lhead.title:GetText() == ns.L["Nameplate Layout"],
					"Layout: the mock's title: " .. tostring(lhead and lhead.title:GetText()))
				local readout = page and page.readout
				r:Verdict(not (readout and readout.IsTruncated and readout:IsTruncated()),
					"Layout: the stage's line whole, not cut: " .. tostring(readout and readout:GetText()))
				-- (Guides clear of the pop-out button at the stage's top right, the user 2026-11-25.)
				local gb = page and page.controls and page.controls[2] and page.controls[2][1]
				local pop = lprev and lprev.popButton
				local gr, pl2 = gb and gb:GetRight(), pop and pop:GetLeft()
				r:Verdict(gr and pl2 and gr <= pl2 - 2, ("Layout: Guides clear of the pop-out button (%s, %s)"):format(
					tostring(gr and math.floor(gr)), tostring(pl2 and math.floor(pl2))))
				-- (Default's and Layout's previews alike: one height, one Preview list, the plate the
				-- same size, the user 2026-11-25 "why arent they the same size and why dont they use
				-- the 1 dropdown?")
				local dh, lh = preview and preview:GetHeight(), lprev and lprev:GetHeight()
				-- (with the same parts up on both: more parts up on Layout's fit a smaller plate, run q7c9a)
				local dpv, lpv2 = preview and preview.lookPreview, page and page.holder
				if dpv and lpv2 and ns.PlatePreviewStates and ns.TogglePlatePreviewState then
					local want, have = ns.PlatePreviewStates(dpv), ns.PlatePreviewStates(lpv2)
					for _, key in ipairs({ "casting", "marker", "debuffs", "buffs", "crowd", "quest", "elite", "target" }) do
						if (want[key] or false) ~= (have[key] or false) then ns.TogglePlatePreviewState(key, lpv2) end
					end
					if page.Redraw then page.Redraw() end
					r:Sleep(0.3)
				end
				local ds = preview and preview.lookPreview and preview.lookPreview.gameScale
				local ls = page and page.holder and page.holder.gameScale
				r:Log("  Default's plate: " .. tostring(dpv and dpv.fitWhy) .. "; Layout's: " .. tostring(lpv2 and lpv2.fitWhy))
				-- (a pixel of rounding allowed, run qbed7: 230 / 229)
				r:Verdict(dh and lh and math.abs(dh - lh) <= 1.5 and lh >= 220, ("Default and Layout: one stage height (%s, %s)"):format(
					tostring(dh and math.floor(dh)), tostring(lh and math.floor(lh))))
				r:Verdict(page and page.holder and page.holder.oneList and not page.holder.stateDropdown,
					"Layout: the one Preview list, as Default's")
				r:Verdict(ds and ls and math.abs(ds - ls) < 0.02, ("Default and Layout: the plate the same size (%s, %s)"):format(
					tostring(ds), tostring(ls)))
				-- (A part set Hidden goes from the preview too, and comes back: the user 2026-11-25, "i set
				-- level box to hidden and its still there?")
				local lcopy = page and page.holder and page.holder.gamePlate and page.holder.gamePlate.gameCopy
				local lbox = lcopy and lcopy.PlayerLevelDiffFrame
				if lbox then
					r:Set("styleOver_platePartLevel", "hide")
					if page.Redraw then page.Redraw() end
					r:Sleep(0.3)
					local gone = lbox:GetEffectiveAlpha() < 0.05
					r:Shot("Nameplate Layout, level box Hidden")
					r:Set("styleOver_platePartLevel", "row")
					if page.Redraw then page.Redraw() end
					r:Sleep(0.3)
					local back = lbox:GetEffectiveAlpha() > 0.9
					r:Verdict(gone and back, ("Layout: the level box Hidden leaves the preview, and comes back (%s, %s)")
						:format(tostring(gone), tostring(back)))
				end
				-- (Mirror: a switch that shows it, and twice is back exactly, the user 2026-11-26.)
				if ns.PlateLayoutMirror and page and page.holder and page.holder.gamePlate then
					r:Set("plateLayoutData", { all = { parts = { level = { x = 3 } } } })
					ns.PlateLayoutChanged()
					if page.Redraw then page.Redraw() end
					r:Sleep(0.3)
					local lay = ns.PlateLayoutEditing("all", true)
					ns.PlateLayoutMirror(lay, "level", page.holder.gamePlate)
					local mid = ns.PlateLayoutPart(lay, "level")
					local midX, midOn = mid and mid.x, mid and mid.mirrored
					ns.PlateLayoutChanged()
					if page.Redraw then page.Redraw() end
					r:Sleep(0.3)
					ns.PlateLayoutMirror(lay, "level", page.holder.gamePlate)
					local back = ns.PlateLayoutPart(lay, "level")
					-- (pointing at Mirrored changes nothing: no hover preview on it, the user 2026-11-26)
					local mprop
					for _, each in ipairs(Studio.Props(lf, "level")) do if each.prop.label == ns.L["Mirror"] then mprop = each.prop end end
					local mkey = mprop and Studio.KeyOf(mprop, "all")
					if mkey and Studio.ShowFor then
						Studio.ShowFor(lprev, mkey, "on")
						local still = ns.PlateLayoutPart(lay, "level")
						r:Verdict(still and still.x == 3 and not still.mirrored, ("Layout: pointing at Mirrored leaves it (x %s, mirrored %s)")
							:format(tostring(still and still.x), tostring(still and still.mirrored)))
					end
					r:Verdict(midOn and midX ~= 3 and back and back.x == 3 and not back.mirrored,
						("Layout: Mirror moves it (3 -> %s, mirrored %s) and back exactly (%s)"):format(tostring(midX),
						tostring(midOn), tostring(back and back.x)))
					ns.PlateLayoutChanged()
					if page.Redraw then page.Redraw() end
				end
				-- (Guides just over the Preview list, at its left, the user 2026-11-25.)
				local ud = page and page.holder and page.holder.unitDropdown
				local gl2, gb2, ul, ut = gb and gb:GetLeft(), gb and gb:GetBottom(), ud and ud:GetLeft(), ud and ud:GetTop()
				r:Verdict(gl2 and ul and math.abs(gl2 - ul) <= 2 and gb2 and ut and gb2 >= ut and gb2 - ut <= 6,
					("Layout: Guides over the Preview list, at its left (left %s / %s, bottom %s over %s)"):format(
					tostring(gl2 and math.floor(gl2)), tostring(ul and math.floor(ul)), tostring(gb2 and math.floor(gb2)), tostring(ut and math.floor(ut))))
				Steady("Layout", lprev, GamePlateOf(page and page.holder))
				-- (Layout off: its card inside the tabs' framed panel, clear of its edges, the user
				-- 2026-11-25 "no fit".)
				r:Set("plateLayout", false)
				if ns.PaintPageSwitches then ns.PaintPageSwitches() end
				r:Sleep(0.3)
				local box = ns.offCardLoad and ns.offCardLoad:GetParent()
				local card = box and box:GetParent()
				local lpanel = led and led.holder:GetParent().pageTabs and led.holder:GetParent().pageTabs.panel
				local cl, pl = card and card:IsVisible() and box:GetLeft(), lpanel and lpanel:GetLeft()
				local ct, pt = box and box:GetTop(), lpanel and lpanel:GetTop()
				r:Verdict(cl and pl and cl >= pl + 5 and ct and pt and ct <= pt - 5,
					("Layout off: its card inside the panel (left %s in %s, top %s under %s)"):format(tostring(cl and math.floor(cl)),
					tostring(pl and math.floor(pl)), tostring(ct and math.floor(ct)), tostring(pt and math.floor(pt))))
				r:Shot("Nameplate Layout, off")
				r:Set("plateLayout", true)
				if ns.PaintPageSwitches then ns.PaintPageSwitches() end
				r:Sleep(0.2)
				r:Shot("Nameplate Layout")
			end
			-- (Smart: no page preview, a row's drawer with its own preview and its settings.)
			r:Probe("open Smart", ns.OpenOptions, "Nameplate Marks")
			r:Sleep(0.4)
			local grid = content and PageOf(content, "markGrid") and PageOf(content, "markGrid").markGrid
			r:Verdict(not (preview and preview:IsVisible()), "Smart: no page preview over the rows")
			local first = ns.TargetMarkOrder and ns.TargetMarkOrder()[1]
			if grid and grid.Open and first then
				grid.Open(first)
				r:Sleep(0.6)
				-- (Nothing cut off, the user 2026-11-25: the row's plate inside its stage, level box too.)
				local drawerLook
				for _, child in ipairs({ grid:GetChildren() }) do
					if child:IsShown() and child.rowPreview then drawerLook = child.rowPreview end
				end
				local copy = drawerLook and drawerLook.gamePlate and drawerLook.gamePlate.gameCopy
				local lvl = copy and copy.PlayerLevelDiffFrame
				local lr, sr = lvl and lvl:IsVisible() and lvl:GetRight(), drawerLook and drawerLook:GetRight()
				r:Verdict(drawerLook ~= nil and (not lr or (sr and lr * lvl:GetEffectiveScale() <= sr * drawerLook:GetEffectiveScale() + 1)),
					("Smart: the row's plate inside its stage (level box right %s, stage right %s)"):format(
					tostring(lr and math.floor(lr * lvl:GetEffectiveScale())), tostring(sr and math.floor(sr * drawerLook:GetEffectiveScale()))))
				-- (Its preview smaller than the tabs' and inside its drawer, the user 2026-11-25: "smarty
				-- dropdown previewer is too big", it ran over the rows under it.)
				local dr = drawerLook and drawerLook:GetParent()
				local lb, db2 = drawerLook and drawerLook:GetBottom(), dr and dr:GetBottom()
				r:Verdict(drawerLook and drawerLook:GetHeight() <= 160 and lb and db2 and lb >= db2,
					("Smart row: its preview %s tall, inside its drawer (bottom %s over %s)"):format(
					tostring(drawerLook and math.floor(drawerLook:GetHeight())), tostring(lb and math.floor(lb)), tostring(db2 and math.floor(db2))))
				-- (Each row's grip to drag it, level with its tick box; no arrows.)
				local level, gripped = true, 0
				for _, grip in ipairs(grid.grips or {}) do
					if grip:IsVisible() then
						gripped = gripped + 1
						local _, gy = grip:GetCenter()
						local _, ry = grip:GetParent():GetCenter()
						if gy and ry and math.abs(gy - ry) > 1 then level = false end
					end
				end
				r:Verdict(gripped >= 2 and level, ("Smart: %d rows with a grip, each level with its row"):format(gripped))
				-- (Its settings boxed all round, the user 2026-11-26 "finish this rectangle"; its preview
				-- out in a window and back, "need to be able to popout the smart preivewer".)
				local rowEd = dr and dr.rowEditor
				r:Verdict(rowEd and rowEd.box and rowEd.box:IsVisible(), "Smart row: its settings in a box of their own")
				if drawerLook and drawerLook.popButton then
					drawerLook.popButton:Click()
					r:Sleep(0.4)
					local out = drawerLook:GetParent() ~= dr and drawerLook:IsVisible()
					-- (docked beside the settings window to start with, the user 2026-11-26)
					local win = _G.CinematicRowPreviewWindow
					local sw = SettingsPanel
					local wl, wr, sl, sr = win and win:GetLeft(), win and win:GetRight(), sw and sw:GetLeft(), sw and sw:GetRight()
					r:Verdict(win and win.docked and wl and sr and (math.abs(wl - sr) <= 8 or math.abs(wr - sl) <= 8),
						("Smart row: its window docked beside the settings (%s..%s by %s..%s)"):format(tostring(wl and math.floor(wl)),
						tostring(wr and math.floor(wr)), tostring(sl and math.floor(sl)), tostring(sr and math.floor(sr))))
					r:Shot("Smart row, its preview popped out")
					drawerLook.popButton:Click()
					r:Sleep(0.3)
					r:Verdict(out and drawerLook:GetParent() == dr, ("Smart row: its preview pops out and back (%s)"):format(tostring(out)))
				else
					r:Verdict(false, "Smart row: no pop-out button on its preview")
				end
				Steady("Smart row", drawerLook, GamePlateOf(drawerLook))
				r:Shot("Smart Style, a row open")
			else
				r:Verdict(false, "Smart: no row to open")
			end
			-- (Cast Bars: the cast editor beside one plate casting, Bar · Colors · Spell name · Icon.)
			r:Probe("open Cast Bars", ns.OpenOptions, "Cast Bar Style")
			r:Sleep(0.5)
			local castHost
			for h in pairs(ns.StylePageHosts and ns.StylePageHosts() or {}) do
				if h.f == Studio.frames.cast and h:IsVisible() then castHost = h end
			end
			r:Verdict(castHost ~= nil, "Cast Bars: its editor shows")
			if castHost then
				local cp = castHost.preview
				-- (The preview's spot in the page: the preview itself pins to the top as the page scrolls.)
				local cspot = cp and (cp.stackSpot or cp)
				local cpr, chl = cspot and cspot:GetRight(), castHost.holder:GetLeft()
				r:Verdict(cpr and chl and chl >= cpr - 1, ("Cast Bars: the settings right of the stage (%s, %s)"):format(
					tostring(cpr and math.floor(cpr)), tostring(chl and math.floor(chl))))
				local ctabs = {}
				for _, t in ipairs(castHost.body.tabs or {}) do if t:IsShown() then ctabs[#ctabs + 1] = t.text and t.text:GetText() or "?" end end
				r:Verdict(#ctabs == 4, "Cast Bars: the parts as tabs: " .. table.concat(ctabs, ", "))
				-- (The game's own plate on its stage, casting, its health and cast bars even: the user
				-- 2026-11-25, "not even bars" on the drawn one.)
				local clp = cp and cp.lookPreview
				local ccopy = clp and clp.gamePlate and clp.gamePlate.gameCopy
				local hb = ccopy and ccopy.HealthBarsContainer and ccopy.HealthBarsContainer.healthBar
				local cb = ccopy and ccopy.CastBarsContainer and ccopy.CastBarsContainer.castBar
				r:Verdict(cb ~= nil and cb:IsVisible() and cp.samples and cp.samples[1] == cb,
					"Cast Bars: the game's plate on the stage, casting, the editor on its cast bar")
				local hl, hr = hb and hb:GetLeft(), hb and hb:GetRight()
				local bl, br = cb and cb:GetLeft(), cb and cb:GetRight()
				r:Verdict(hl and bl and math.abs(hl - bl) < 2 and math.abs(hr - br) < 2,
					("Cast Bars: health and cast bars even (%s-%s, %s-%s)"):format(tostring(hl and math.floor(hl)),
					tostring(hr and math.floor(hr)), tostring(bl and math.floor(bl)), tostring(br and math.floor(br))))
				-- (No Look from: every setting open, each its own or Default's, the user 2026-11-26 "it
				-- locks everything".)
				castHost:Pick("bar", "PLATE")
				r:Sleep(0.2)
				local lookFrom, greyed = false, 0
				for _, row in ipairs(castHost.body.shownRows or {}) do
					if row:IsShown() and row.prop.label == ns.L["Look from"] then lookFrom = true end
					if row:IsShown() and row.control and row.control.IsEnabled and not row.control:IsEnabled() then greyed = greyed + 1 end
				end
				r:Verdict(not lookFrom and greyed == 0, ("Cast Bars: no Look from, nothing greyed (%d greyed)"):format(greyed))
				-- (Its settings inside the tabs' framed panel, to their last row: they ran past its
				-- bottom, the user 2026-11-25.)
				local cpanel = castHost.holder:GetParent().pageTabs and castHost.holder:GetParent().pageTabs.panel
				-- (its box, 8 under the column, and a margin under that)
				local box2 = castHost.box or castHost.holder
				local hb2, pb2 = box2:GetBottom(), cpanel and cpanel:GetBottom()
				r:Verdict(hb2 and pb2 and hb2 >= pb2 + 4, ("Cast Bars: the settings end inside the panel (%s over %s)"):format(
					tostring(hb2 and math.floor(hb2)), tostring(pb2 and math.floor(pb2))))
				-- (Again after a part picked and back, as a player does: the Bar part the tallest.)
				castHost:Pick("colors", "PLATE")
				r:Sleep(0.3)
				castHost:Pick("bar", "PLATE")
				r:Sleep(0.3)
				local hb3, pb3 = box2:GetBottom(), cpanel and cpanel:GetBottom()
				r:Verdict(hb3 and pb3 and hb3 >= pb3 + 4, ("Cast Bars: still inside the panel after Colors and back (%s over %s)"):format(
					tostring(hb3 and math.floor(hb3)), tostring(pb3 and math.floor(pb3))))
				r:Verdict(cp and cp.backButton == nil and preview and preview.backButton == nil,
					"no scene button on the Default or Cast Bars stage (the user 2026-11-25)")
				-- (Scrolled to the bottom, the preview pinned at the top: the panel still past the
				-- settings' last row; the pin shortened the page, the user 2026-11-25 "why no fix?")
				local cscroll = cp and cp.pin and cp.pin.scroll
				local canvasC = castHost.holder:GetParent():GetParent()
				cscroll = cscroll or (canvasC and canvasC.GetVerticalScrollRange and canvasC)
				if cscroll and cscroll.GetVerticalScrollRange then
					cscroll:SetVerticalScroll(cscroll:GetVerticalScrollRange())
					r:Sleep(0.6)
					local hb4, pb4 = box2:GetBottom(), cpanel and cpanel:GetBottom()
					r:Verdict(hb4 and pb4 and hb4 >= pb4 + 4, ("Cast Bars: scrolled down, still inside the panel (%s over %s)"):format(
						tostring(hb4 and math.floor(hb4)), tostring(pb4 and math.floor(pb4))))
					r:Shot("Cast Bars, scrolled down")
					cscroll:SetVerticalScroll(0)
					r:Sleep(0.4)
				else
					r:Verdict(false, "Cast Bars: no scroll frame to scroll")
				end
				-- (Turned off, then back on from outside the title's switch: the switch says On again,
				-- the user 2026-11-25 "turning a tab back on doesnt show it on".)
				local chead = PageOf(castHost.holder, "mockHead") and PageOf(castHost.holder, "mockHead").mockHead
				if chead and ns.FlipPageSwitch then
					ns.FlipPageSwitch("Cast Bar Style")
					r:Sleep(0.3)
					ns.FlipPageSwitch("Cast Bar Style")
					if ns.PaintPageSwitches then ns.PaintPageSwitches() end
					r:Sleep(0.3)
					local on = not ns.PageSwitchOff("Cast Bar Style")
					r:Verdict(on and chead.switch.on == true, ("Cast Bars: off and back on, its switch on again (%s, page %s)")
						:format(tostring(chead.switch.on), on and "on" or "off"))
				end
				Steady("Cast Bars", cp, GamePlateOf(clp))
				r:Shot("Cast Bars")
			end
			-- (The Show in row: the Nameplates page's Style tab.)
			r:Probe("open Nameplates", ns.OpenOptions, "Nameplates")
			r:Sleep(0.4)
			r:Shot("Nameplates page (Show): its tabs")
		end },
		{ key = "model", title = "set, Undo, Redo, Reset", handsOff = true,
			proven = "stylestudio runs q66f9, q3c49 (2026-11-25)", run = function(r)
			local Studio = ns.Studio
			local f = Studio.frames.tooltips
			r:Set("tooltipStyle", true)
			local prop, part
			for _, each in ipairs(Studio.Props(f)) do
				if each.prop.key == "tooltipTextSize" then prop, part = each.prop, each.part end
			end
			local before = ns.db.tooltipTextSize
			Studio.Set(f, prop, nil, 1.3, part)
			r:Verdict(ns.db.tooltipTextSize == 1.3 and Studio.SourceOf(f, prop, nil) == "yours", "set 130%: yours")
			Studio.Undo()
			r:Verdict(ns.db.tooltipTextSize == before, "undo: back to " .. tostring(before))
			Studio.Redo()
			r:Verdict(ns.db.tooltipTextSize == 1.3, "redo: 130% again")
			local n = #Studio.ResetWrites("frame", f)
			local done = Studio.Reset("frame", f)
			r:Verdict(n >= 1 and done == n and #Studio.ResetWrites("frame", f) == 0, ("reset frame: %d counted, %d reset"):format(n, done))
		end },
		{ key = "looks", title = "a look as one step", handsOff = true,
			proven = "stylestudio runs q66f9, q3c49 (2026-11-25)", run = function(r)
			local Studio = ns.Studio
			local f = Studio.frames.tooltips
			local look
			for _, each in ipairs(f.looks or {}) do if each.id == "clean" then look = each end end
			if not look then r:Skip("no Clean look") return end
			local was = {}
			for key in pairs(look.values) do was[key] = ns.db[key] end
			local steps = #Studio.hist
			Studio.ApplyLook(f, look, nil)
			local all = true
			for key, value in pairs(look.values) do if ns.db[key] ~= value then all = false end end
			r:Verdict(all and #Studio.hist == steps + 1, "Clean applied in one step")
			Studio.Undo()
			local back = true
			for key, value in pairs(was) do if ns.db[key] ~= value then back = false end end
			r:Verdict(back, "one Undo puts every one back")
		end },
		{ key = "buttons", title = "every button clicked, and what it does", handsOff = true, run = function(r)
			r:Set("tooltipStyle", true)
			local ok, checks = pcall(ns.StyleStudioButtonChecks, true)
			r:Verdict(ok, "the clicks ran: " .. (ok and "yes" or tostring(checks)))
			for _, c in ipairs(ok and checks or {}) do r:Verdict(c[1], c[2]) end
			ns.OpenStyleStudio("tooltips")
			r:Shot("after the clicks", { behind = ns.StyleStudioWindow() })
			ns.StyleStudioWindow():Hide()
		end },
	},
})
