-- /cine debug stylestudio: the Style pages in game, hands off. Since 2026-11-25 every Style
-- page is its old page again but the Nameplates ones (Nameplate Style, Layout, Names) and
-- Range Hint's, which keep the editor (Style/Studio/*). Steps:
--   1 sticky    each Style hub group one run of icons; every page's preview held at the top
--               as it scrolls
--   2 pages     every Style page opened, one shot each
--   3 editors   Nameplates, Layout, Names, Range Hint: the editor shows, a part picks, no
--               Copy look / Paste / Hold to compare
--   4 model     a setting set through the editor, Undo, Redo, Reset (frame) and its count
--   5 looks     a look (Tooltips' Clean) applied as one step and undone as one
--   6 buttons   every editor button clicked, and what it does
-- Every setting it touches is put back at the end. Into CinematicDB.styleStudioTestLog.
local _, ns = ...

local TOUCHED = { "styleGeneral", "tooltipStyle", "tooltipTextSize", "tooltipEdge", "tooltipBack", "tooltipAlpha",
	"tooltipOutline", "tooltipShadow", "tooltipBar", "tooltipNames", "tooltipBarHeight", "tooltipFont",
	"tooltipBarTexture", "tooltipBarColor", "tooltipGradient", "tooltipGradDir", "tooltipBarGround" }

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
