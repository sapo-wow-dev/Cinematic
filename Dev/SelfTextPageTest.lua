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
	about = "the Text on You page's preview: model, sides, Bold, kinds, merge, crits, game's look, screen; nothing to do",
	settings = { "styleGeneral", "selfTextStyle", "selfTextSide", "selfTextMotion", "selfTextFont", "selfTextMerge" },
	setup = function(r)
		r:Keep("selfText", Kept())
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
	},
})
