-- /cine debug selftextpage: the Text on You page's redesign in game. A test
-- kit test (Dev/TestKit.lua), NOTHING to do ([[fewest-test-actions]]): the
-- page's preview (you from behind, a model of your character, the texts
-- drawn by the real code on its own board) is built in the middle of your
-- screen, and each step sets the looks itself, plays samples, takes a paced
-- screenshot and writes its verdict (a dev error in the step fails it):
--   1 model    your character in the preview (its model loaded), the
--              default look: the fight mix drawn
--   2 where    Split and Arc: hits on one side, heals on the other
--   3 bold     the Bold quick look: its font on the texts (read back)
--   4 kind     Damage taken its own: pink, bigger, on your left
--   5 merge    four hits in a quarter second: one text, "x4"
--   6 crits    Crits stay and Pop: a crit holds where it popped
--   7 game's   The game's look: in the middle, its font
--   8 screen   samples at your real spot on the screen
-- Then the real page (Options opened at it):
--   9 center   Follow off (as no Shoulder Cam): a hit straight over you
--  10 page    its preview: the texts' layer its size, you in it, the
--              drag mark where a text starts
--  11 docked   popped out to its window: the same at the window's size
--  12 kinds    Auras clicked: its own Look panel docked, its keys; closed again
--  13 tabs     General, Look, Kinds clicked: one page each
--  14 mark     right-click the mark: Height and Across back (left-click: kept)
--  15 off      the page off: you hidden under its off card; on: back
-- Every Text on You setting and CineMode put back at the end, after a stop,
-- and after a /reload (the kit's undo). Into CinematicDB.selfTextPageTestLog.
-- Dev copy only.
local _, ns = ...

local W, H, SCALE, OVER_X = 520, 210, 0.9, -0.1 -- (as the page's preview)
local NIL = "<nil>"
local MIX = { { "-26", "damage" }, { "+120 [Sapo]", "heal" }, { "Dodge", "miss" }, { "-74", "damage", true },
	{ "+20 Mana", "power" }, { "<2 Combo Points>", "combo" }, { "<Demon Skin>", "aura" }, { "+412", "heal", true },
	{ "Mana Low", "low" } }

local view -- the preview, for the run

-- Every Text on You setting, as it was (nil kept as NIL), for the kit's undo.
local function Kept()
	local kept = { styleGeneral = ns.db.styleGeneral == nil and NIL or ns.db.styleGeneral }
	for key in pairs(ns.DEFAULTS) do
		if type(key) == "string" and key:find("^selfText") then
			local value = ns.db[key]
			kept[key] = value == nil and NIL or value
		end
	end
	return kept
end
local function Set(values)
	for key, value in pairs(values) do ns.db[key] = value end
end
local function Defaults()
	for key, value in pairs(ns.DEFAULTS) do
		if type(key) == "string" and key:find("^selfText") then ns.db[key] = value end
	end
	ns.db.styleGeneral, ns.db.selfTextStyle, ns.db.selfTextMerge = true, true, false
	-- (Long enough to be up for the shot: the kit waits 1.5 s before it, and
	-- at the usual 1.6 s run 1's shots caught them faded or gone, 2026-11-21.)
	ns.db.selfTextLife = 4
end

-- The page's preview, in the middle of the screen.
local function Build()
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(W, H)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, -40)
	frame:SetFrameStrata("DIALOG")
	if ns.StyleScene then ns.StyleScene(frame) end
	if frame.SetClipsChildren then frame:SetClipsChildren(true) end
	local model = CreateFrame("PlayerModel", nil, frame)
	model:SetSize(260, H * 1.8)
	model:SetPoint("BOTTOM", frame, "BOTTOM", OVER_X * W, -H * 0.85)
	local unitOk = pcall(model.SetUnit, model, "player")
	pcall(model.SetFacing, model, math.pi)
	local clip = CreateFrame("ScrollFrame", nil, frame) -- (as the page: texts cut at its edges)
	clip:SetAllPoints(frame)
	clip:SetFrameLevel(frame:GetFrameLevel() + 20)
	local layer = CreateFrame("Frame", nil, clip)
	layer:SetSize(W, H)
	clip:SetScrollChild(layer)
	local board = ns.SelfTextNewBoard(layer, layer, SCALE, function() return (OVER_X * W) / SCALE end, -50)
	return { frame = frame, model = model, board = board, unitOk = unitOk }
end

-- The closest two texts on one side, in lines (their height apart / a line).
local function MinGap()
	local best = math.huge
	local live = view.board.live
	for i = 1, #live do
		for j = i + 1, #live do
			local a, b = live[i], live[j]
			if a.side == b.side then
				local ya, yb = select(5, a:GetPoint(1)), select(5, b:GetPoint(1))
				if type(ya) == "number" and type(yb) == "number" then
					best = math.min(best, math.abs(ya - yb) / math.max(1, math.min(a.line, b.line)))
				end
			end
		end
	end
	return best
end

local function Play(r, list, gap)
	for index, sample in ipairs(list) do
		ns.SelfTextSample(sample[1], sample[2], sample[3], view.board)
		if index < #list then r:Sleep(gap or 0.12) end
	end
end
local function Live() return view.board.live end
local function FontOf(text)
	local ok, file = pcall(text.GetFont, text)
	return ok and type(file) == "string" and file or "?"
end

-- The real page (steps 9 on) ------------------------------------------------------
local page -- ns.selfTextPage, once open
local function OpenPage(r)
	if ns.OpenOptions then ns.OpenOptions("Self Text Style") end
	r:Sleep(1)
	local p = ns.selfTextPage
	if not (p and p.preview and (p.preview:IsVisible() or ns.StylePreviewDebug() == p.preview)) then return nil end
	return p
end
-- A tab of the page's (General, Look, Kinds) clicked as you would.
local function FindButton(frame, text)
	for _, child in ipairs({ frame:GetChildren() }) do
		local ok, words = pcall(function() return child.GetText and child:GetText() end)
		if ok and words == text and child:IsVisible() and child:GetScript("OnClick") then return child end
		local found = FindButton(child, text)
		if found then return found end
	end
end
local TAB = { General = 1, Look = 2, Kinds = 3 }
local function ClickTab(r, name)
	-- (The page's own tab button, clicked; by its words only if it has none.)
	local tab = page and page.tabFrames and page.tabFrames[TAB[name]]
	if not tab then
		local content = page and page.hosts and page.hosts[1] and page.hosts[1]:GetParent()
		tab = content and FindButton(content, ns.L[name] or name)
	end
	if tab then tab:Click() end
	r:Sleep(0.4)
	return tab ~= nil
end
-- A frame's middle on the screen, in screen pixels (its scale taken in).
local function Middle(frame)
	local x, y = frame:GetCenter()
	local s = frame:GetEffectiveScale()
	if not (x and y and s) then return nil end
	return x * s, y * s, s
end
-- The preview laid out at its size: the texts' layer as big as it, you in
-- it (your top inside, your middle across inside), the mark where a text
-- starts (across exactly, up within the bit it climbs in a frame or two).
local function Fitted(r, where)
	local preview, board = page.preview, page.board
	local pw, ph = preview:GetWidth(), preview:GetHeight()
	local lw, lh = board.layer:GetWidth(), board.layer:GetHeight()
	local layerOk = math.abs(lw - pw) < 1 and math.abs(lh - ph) < 1
	local mx = page.model:GetCenter()
	local mTop = page.model:GetTop()
	local left, right, bottom = preview:GetLeft(), preview:GetRight(), preview:GetBottom()
	local youIn = (mx and mTop and left and right and bottom and mx > left and mx < right and mTop > bottom + ph * 0.5)
		and true or false
	ns.db.selfTextMotion = "up"
	-- (Play paused while it measures: a sample playing in the wait pushed the
	-- test's text up past it, 18 px off the mark, run 7.)
	local wasPlaying = page.view and page.view.playing
	if page.SetPlaying then page.SetPlaying(false) end
	board:Clear()
	r:Sleep(0.6) -- (your spot settled)
	local text = ns.SelfTextSample("-26", "damage", false, board)
	r:Sleep(0.03)
	page.PlaceHandle()
	local tx, ty, ts
	if text then tx, ty, ts = Middle(text) end
	local hx, hy = Middle(page.handle)
	if page.SetPlaying and wasPlaying then page.SetPlaying(true) end
	local markOk = (tx and hx and math.abs(tx - hx) < 2 * ts and math.abs(ty - hy) < 20 * ts) and true or false
	r:Log(("%s: preview %.0f x %.0f, texts' layer %.0f x %.0f, your top %s over its bottom %s, text %s,%s mark %s,%s"):format(
		where, pw, ph, lw, lh, tostring(mTop and math.floor(mTop)), tostring(bottom and math.floor(bottom)),
		tostring(tx and math.floor(tx)), tostring(ty and math.floor(ty)), tostring(hx and math.floor(hx)),
		tostring(hy and math.floor(hy))))
	return layerOk and youIn and markOk, ("%s: layer fits %s, you in it %s, the mark on the text %s"):format(
		where, tostring(layerOk), tostring(youIn), tostring(markOk))
end

-- A step: fn(r) returns pass, detail; a dev error during it fails it; the
-- board cleared after.
local function Step(key, title, fn)
	return { key = key, title = title, run = function(r)
		local errors0 = ns.TestKit.Counts()
		local pass, detail = fn(r)
		local errors = ns.TestKit.Counts() - errors0
		if errors > 0 then pass, detail = false, ("%d dev error(s) in the step; %s"):format(errors, tostring(detail)) end
		r:Verdict(pass and true or false, detail)
		if view then view.board:Clear() end
	end }
end

ns.TestKit.Define({
	name = "selftextpage",
	key = "selfTextPageTest",
	title = "Text on You preview test",
	about = "the Text on You page: its preview (model, sides, Bold, kinds, merge, crits, game's look, screen), no Shoulder Cam centered, the real page and docked, kind panels, tabs, the mark, off; nothing to do",
	settings = { "styleGeneral", "selfTextStyle", "selfTextSide", "selfTextMotion", "selfTextFont", "selfTextMerge",
		"selfTextFollow", "selfTextHeight", "selfTextAcross", "stylePreviewOut" },
	setup = function(r)
		r:Keep("selfText", Kept())
		r:Keep("previewOut", ns.db.stylePreviewOut and true or false)
		view = Build()
	end,
	putBack = function(extra)
		local n = 0
		for key, value in pairs(extra.selfText or {}) do
			if value == NIL then value = nil end
			ns.db[key] = value
			n = n + 1
		end
		if ns.RefreshSelfTextStyle then pcall(ns.RefreshSelfTextStyle) end
		return n .. " Text on You setting(s) put back"
	end,
	finish = function()
		if view then pcall(function() view.board:Clear() view.frame:Hide() end) end
		view = nil
		-- (A kind's panel shut; the preview back in its page unless it was out.)
		local open = ns.LookPanelOpen and ns.LookPanelOpen()
		if open then pcall(open.Hide, open) end
		local popped = ns.StylePreviewDebug and ns.StylePreviewDebug()
		if popped and popped.popButton and not ns.db.stylePreviewOut then pcall(popped.popButton.Click, popped.popButton) end
		page = nil
	end,
	steps = {
		Step("model", "your character and the default look", function(r)
			Defaults()
			r:Sleep(0.5)
			local okModel, fileID = r:Probe("model:GetModelFileID()", view.model.GetModelFileID, view.model)
			r:Log("model SetUnit ok " .. tostring(view.unitOk))
			Play(r, MIX)
			-- (Counted as they're up: by the shot most have run their time.)
			local up = #Live()
			-- (Each across inside the preview: run 3's free side ran past its edge.)
			local cut = 0
			for _, text in ipairs(Live()) do
				local x = select(4, text:GetPoint(1))
				local okWide, wide = pcall(text.GetStringWidth, text)
				if type(x) == "number" and okWide and type(wide) == "number" and math.abs(x) + wide / 2 > W / 2 then
					cut = cut + 1
				end
			end
			r:Shot("1 model")
			return up >= 5 and cut == 0 and okModel and type(fileID) == "number" and fileID > 0,
				("%d texts up, %d past its edges, model file %s"):format(up, cut, tostring(okModel and fileID))
		end),
		Step("where", "Split and Arc", function(r)
			Set({ selfTextSide = "split", selfTextMotion = "arc" })
			Play(r, { { "-26", "damage" }, { "+120", "heal" }, { "-31", "damage" }, { "+64", "heal" } })
			r:Sleep(0.4)
			local sides = {}
			for _, text in ipairs(Live()) do sides[text.group] = text.side end
			r:Shot("2 where")
			return sides.damage ~= nil and sides.heal ~= nil and sides.damage ~= sides.heal,
				("damage side %s, heal side %s"):format(tostring(sides.damage), tostring(sides.heal))
		end),
		Step("bold", "the Bold quick look", function(r)
			Defaults()
			local found = false
			for _, look in ipairs(ns.SELF_TEXT_LOOKS or {}) do
				if look.id == "bold" then
					found = true
					Set({ selfTextFont = look.font, selfTextEdge = look.edge, selfTextSize = look.size,
						selfTextCrit = look.crit, selfTextMotion = look.motion })
				end
			end
			Play(r, MIX)
			local font = Live()[1] and FontOf(Live()[1]) or "none"
			r:Shot("3 bold")
			-- (Not piled on each other: on one side, each a good part of a line
			-- from the next. Run 2 had Bold's Pop texts on top of each other.)
			local gap = MinGap()
			return found and font:find("Lilita", 1, true) ~= nil and gap >= 0.6,
				("Bold look found %s, font %s, closest two on a side %.2f lines apart"):format(tostring(found), font, gap)
		end),
		Step("kind", "Damage taken pink, bigger, on your left", function(r)
			Defaults()
			Set({ selfText_damageColor = "custom", selfText_damageR = 1, selfText_damageG = 0.3, selfText_damageB = 1,
				selfText_damageSize = 1.6, selfText_damageSide = "left" })
			Play(r, { { "-26", "damage" }, { "+120", "heal" }, { "-31", "damage" } })
			local pink, left
			for _, text in ipairs(Live()) do
				if text.group == "damage" then
					local ok, cr, cg, cb = pcall(text.GetTextColor, text)
					pink = ok and math.abs(cr - 1) < 0.02 and math.abs(cg - 0.3) < 0.02 and math.abs(cb - 1) < 0.02
					left = text.side == -1
				end
			end
			r:Shot("4 kind")
			return pink and left, ("pink %s, left %s"):format(tostring(pink), tostring(left))
		end),
		Step("merge", "four hits in a quarter second, one text x4", function(r)
			Defaults()
			Set({ selfTextMerge = true })
			Play(r, { { "-12", "damage" }, { "-13", "damage" }, { "-14", "damage" }, { "-15", "damage" } }, 0.07)
			local count, texts = Live()[1] and Live()[1].count or 0, #Live()
			r:Shot("5 merge")
			return texts == 1 and count == 4, ("%d texts, count %s"):format(texts, tostring(count))
		end),
		Step("crits", "Crits stay and Pop: the crit holds", function(r)
			Defaults()
			-- (The hit lasts 2.4 s, the staying crit 3.4: the shot, ~1.5 s in, has
			-- both; ~2.7 s in, the check after it, the crit alone.)
			Set({ selfTextSticky = true, selfTextMotion = "pop", selfTextLife = 2.4 })
			Play(r, { { "-74", "damage", true }, { "-20", "damage" } })
			r:Shot("6 crits")
			local crit, plain
			for _, text in ipairs(Live()) do if text.crit then crit = true else plain = true end end
			return crit and not plain, ("crit still up %s, the hit gone %s"):format(tostring(crit), tostring(not plain))
		end),
		Step("games", "the game's own look", function(r)
			Defaults()
			Set({ selfTextFont = "bebas" }) -- (ignored by the game's look)
			local g = ns.SelfTextGameSample("-26", "damage", view.board)
			local gameFont = g and FontOf(g) or "none"
			r:Shot("7 game's")
			-- (In the middle, where the game draws it: not over you. Run 2 had it
			-- over your head.)
			local x = g and select(4, g:GetPoint(1))
			return g ~= nil and g.side == 0 and not gameFont:find("Bebas", 1, true) and ns.db.selfTextFont == "bebas"
				and type(x) == "number" and math.abs(x) < 2,
				("font %s, side %s, across from the middle %s"):format(gameFont, tostring(g and g.side), tostring(x))
		end),
		Step("screen", "samples at your real spot", function(r)
			view.frame:Hide()
			Defaults()
			local screen = ns.SelfTextScreenBoard
			local before = #screen.live
			for _, sample in ipairs(MIX) do
				ns.SelfTextSample(sample[1], sample[2], sample[3])
				r:Sleep(0.15)
			end
			local onScreen = #screen.live
			r:Shot("8 screen") -- (no backdrop: behind the screen-wide layer it blacked the whole shot, run 3)
			return onScreen > before, ("%d texts up on the screen (%d before)"):format(onScreen, before)
		end),
		-- The real page (steps 9 on): what the user saw that the copy above
		-- couldn't, 2026-11-21: the texts beside the middle with no Shoulder
		-- Cam; docked bigger, the texts in a corner, the mark off them and you
		-- under the edge; the kinds' editor under the list; the model through
		-- the page's off card.
		Step("center", "no Shoulder Cam: straight over you", function(r)
			Defaults()
			local okShift, shift = r:Probe("ns.ShoulderYouShift()", function() return ns.ShoulderYouShift and ns.ShoulderYouShift() end)
			-- (Follow off: your spot the middle, as with no Shoulder Cam.)
			Set({ selfTextFollow = false })
			r:Sleep(0.6) -- (the spot eases there)
			local text = ns.SelfTextSample("-26", "damage", false)
			r:Sleep(0.05)
			local x = text and select(4, text:GetPoint(1))
			r:Shot("9 center")
			return text ~= nil and text.side == 0 and type(x) == "number" and math.abs(x) < 2,
				("side %s, across from the middle %s (the Shoulder Cam's shift %s)"):format(tostring(text and text.side),
					tostring(x), tostring(okShift and shift))
		end),
		Step("page", "the page's preview: texts, mark, you", function(r)
			Defaults()
			page = OpenPage(r)
			if not page then return false, "the page didn't open" end
			local popped = ns.StylePreviewDebug and ns.StylePreviewDebug()
			if popped == page.preview then page.preview.popButton:Click() r:Sleep(1) end
			local ok, detail = Fitted(r, "on the page")
			r:Shot("10 page", { behind = page.preview })
			return ok, detail
		end),
		Step("docked", "docked: the same, at the window's size", function(r)
			Defaults()
			page = page or OpenPage(r)
			local preview = page and page.preview
			if not (preview and preview.popButton) then return false, "no pop out button" end
			if ns.StylePreviewDebug() ~= preview then preview.popButton:Click() end
			r:Sleep(1)
			local popped = ns.StylePreviewDebug() == preview
			local ok, detail = Fitted(r, "docked")
			-- (Its window dragged bigger, as you would by its corner: the preview
			-- scales up, and its refresh runs the Style previews' fit, which moved
			-- you and the mark in the user's shot. Then the same checks.)
			local _, window = ns.StylePreviewDebug()
			local bigOk, bigDetail = false, "no window"
			if window and popped then
				local w, h = window:GetSize()
				local scale0 = preview:GetScale()
				local _, _, _, mx0, my0 = page.model:GetPoint(1)
				window.sizing = true -- (as its corner grip held: the window scales the preview only then)
				window:SetSize(w * 1.4, h * 1.4)
				r:Sleep(0.5)
				if preview.Refresh then preview:Refresh() end
				r:Sleep(0.3)
				local scale1 = preview:GetScale()
				local _, _, _, mx1, my1 = page.model:GetPoint(1)
				-- (A hair's difference after scaling: -60.7000008 and -60.7000084, run 7.)
				local still = type(mx0) == "number" and type(mx1) == "number" and math.abs(mx0 - mx1) < 0.01
					and math.abs(my0 - my1) < 0.01
				bigOk, bigDetail = Fitted(r, "docked bigger")
				r:Log(("bigger: the preview's scale %.2f -> %.2f, you placed %s,%s -> %s,%s"):format(scale0, scale1,
					tostring(mx0), tostring(my0), tostring(mx1), tostring(my1)))
				r:Shot("11 docked bigger", { behind = preview })
				-- (It may be at its largest already, docked: grown or not, all must still fit.)
				bigOk = bigOk and still and scale1 >= scale0
				bigDetail = ("%s, it grew %s, you left where the page put you %s"):format(bigDetail,
					tostring(scale1 > scale0), tostring(still))
				-- (Back to its size: as letting go of the corner does.)
				window:SetSize(w, h)
				local grip
				for _, child in ipairs({ window:GetChildren() }) do
					if child:GetScript("OnMouseUp") and child:GetNormalTexture() then grip = child end
				end
				if grip then grip:GetScript("OnMouseUp")(grip) end
			else
				r:Shot("11 docked", { behind = preview })
			end
			return popped and ok and bigOk, ("popped %s; %s; %s"):format(tostring(popped), detail, bigDetail)
		end),
		Step("kinds", "a kind's own look in a docked panel", function(r)
			Defaults()
			page = page or OpenPage(r)
			if not page then return false, "the page didn't open" end
			ClickTab(r, "Kinds")
			page.Pick("aura")
			r:Sleep(0.6)
			local look = page.kindLooks and page.kindLooks.aura
			local open = look and look.pop:IsShown()
			local docked = ns.LookPanelOpen and ns.LookPanelOpen() == (look and look.pop)
			local keyOk = look and look.key("Size") == "selfText_auraSize"
			r:Shot("12 kinds", { behind = look and look.pop })
			page.Pick("aura")
			r:Sleep(0.3)
			local closed = look and not look.pop:IsShown() and page.picked == nil
			return open and docked and keyOk and closed, ("open %s, the Look panel shown %s, its keys %s, closed again %s"):format(
				tostring(open), tostring(docked), tostring(keyOk), tostring(closed))
		end),
		Step("tabs", "General, Look, Kinds: one page each", function(r)
			Defaults()
			page = page or OpenPage(r)
			if not page then return false, "the page didn't open" end
			local results, good = {}, true
			for i, name in ipairs({ "General", "Look", "Kinds" }) do
				local clicked = ClickTab(r, name)
				local only = page.hosts[i]:IsShown()
				for j, host in ipairs(page.hosts) do if j ~= i and host:IsShown() then only = false end end
				good = good and clicked and only
				results[#results + 1] = ("%s clicked %s, only it shown %s"):format(name, tostring(clicked), tostring(only))
				if name == "Look" then r:Shot("13 tabs") end
			end
			ClickTab(r, "General")
			return good, table.concat(results, "; ")
		end),
		Step("mark", "right-click the mark: back where it starts", function(r)
			Defaults()
			page = page or OpenPage(r)
			if not page then return false, "the page didn't open" end
			Set({ selfTextHeight = 40, selfTextAcross = 30 })
			r:Sleep(0.3)
			local shown = page.handle:IsShown()
			page.handle:GetScript("OnClick")(page.handle, "LeftButton")
			local kept = ns.db.selfTextHeight == 40 and ns.db.selfTextAcross == 30
			page.handle:GetScript("OnClick")(page.handle, "RightButton")
			r:Sleep(0.3)
			local back = ns.db.selfTextHeight == ns.DEFAULTS.selfTextHeight and ns.db.selfTextAcross == ns.DEFAULTS.selfTextAcross
			local ok, detail = Fitted(r, "after the reset")
			return shown and kept and back and ok, ("shown %s, left-click kept it %s, right-click back %s; %s"):format(
				tostring(shown), tostring(kept), tostring(back), detail)
		end),
		Step("off", "the page off: its off card, you hidden", function(r)
			Defaults()
			page = page or OpenPage(r)
			if not page then return false, "the page didn't open" end
			-- (On the page: docked, the preview's window isn't under the page's
			-- off card. Run 6 left it docked from step 11 and failed here.)
			if ns.StylePreviewDebug() == page.preview then
				page.preview.popButton:Click()
				r:Sleep(1)
			end
			ns.db.selfTextStyle = false
			if ns.PaintPageSwitches then ns.PaintPageSwitches() end
			r:Sleep(0.6)
			-- (What faded: each frame over you with its alpha, to the top.)
			local chain, frame = {}, page.preview
			while frame and #chain < 12 do
				local ok, a = pcall(frame.GetAlpha, frame)
				chain[#chain + 1] = ok and type(a) == "number" and ("%.2f"):format(a) or "?"
				frame = frame:GetParent()
			end
			r:Log(("off: faded %s, alphas up from the preview %s"):format(tostring(page.ModelFaded and page.ModelFaded()),
				table.concat(chain, " ")))
			local hidden = not page.model:IsShown()
			r:Shot("14 off")
			ns.db.selfTextStyle = true
			if ns.PaintPageSwitches then ns.PaintPageSwitches() end
			r:Sleep(0.6)
			local back = page.model:IsShown()
			return hidden and back, ("you hidden while off %s, back when on %s"):format(tostring(hidden), tostring(back))
		end),
	},
})
