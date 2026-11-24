-- /cine debug wholemana: mana words are whole numbers, never 338.00003051758
-- (a player's screenshot 2026-11-21: the mana left after a cast, secret, with
-- max mana over 1000, showed every decimal). A test kit test (Dev/TestKit.lua),
-- one action: cast a mana spell once (step 4), as a class with mana. Steps:
--   1 read    your mana and max: secret or plain (mana secret on Forever even
--             out of fights; max readable), INFO/SKIP with no mana
--   2 plain   ns.WholeManaWords on plain floats (338.00003, 6337.9, 23456.7,
--             0.4): the game's AbbreviateNumbers with our rules gives
--             338, 6.3K, 23K, 0 (PASS/FAIL each)
--   3 drawn   (at full mana) a panel mid-screen: the mana left after a cast costing a tenth,
--             a third and all but 338 of your max (the player's number), our
--             way and the old way (the game's shortening of the raw curve
--             answer), plus your mana now; a screenshot. A secret answer
--             can't be read back: the shot is the verdict (ours whole, the
--             old way may show decimals); plain ones get PASS/FAIL. Costs
--             37, 123, a tenth, a third, a half, all but 338
--   4 spent   ONE action: cast any spell that costs mana; then the same
--             panel and shot with your mana part spent (run 1, full mana:
--             both columns were whole, the curve's end point is exact; the
--             player's mana was part spent, mid-curve)
-- Into CinematicDB.wholeManaTestLog. Dev copy only.
local _, ns = ...

local MANA = Enum and Enum.PowerType and Enum.PowerType.Mana or 0

local function Secret(value) return issecretvalue and issecretvalue(value) and true or false end

local panel
local function Panel(rows)
	if not panel then
		panel = CreateFrame("Frame", nil, UIParent)
		panel:SetPoint("CENTER", 0, 140)
		panel:SetFrameStrata("FULLSCREEN_DIALOG")
		local back = panel:CreateTexture(nil, "BACKGROUND")
		back:SetAllPoints()
		back:SetColorTexture(0, 0, 0, 0.85)
		panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		panel.title:SetPoint("TOP", 0, -10)
		panel.rows = {}
	end
	panel:SetSize(520, 50 + rows * 30)
	for i = #panel.rows + 1, rows do
		local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		label:SetPoint("TOPLEFT", 16, -16 - i * 30)
		local ours = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
		ours:SetPoint("LEFT", label, "LEFT", 250, 0)
		local old = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
		old:SetTextColor(0.55, 0.55, 0.55)
		old:SetPoint("LEFT", label, "LEFT", 370, 0)
		panel.rows[i] = { label = label, ours = ours, old = old }
	end
	return panel
end

-- The old way's words for a cast's cost: the raw curve answer, shortened by
-- the game as before the fix (nil when there's no curve answer).
local function OldWords(cost)
	local maxMana = UnitPowerMax("player", MANA)
	if not (UnitPowerPercent and C_CurveUtil and C_CurveUtil.CreateCurve and Enum.LuaCurveType) then return end
	local ok, curve = pcall(C_CurveUtil.CreateCurve)
	if not (ok and curve) then return end
	curve:SetType(Enum.LuaCurveType.Linear)
	local share = math.min(1, cost / maxMana)
	curve:AddPoint(0, 0)
	if share > 0 and share < 1 then curve:AddPoint(share, 0) end
	curve:AddPoint(1, math.max(0, maxMana - cost))
	local fine, after = pcall(UnitPowerPercent, "player", MANA, false, curve)
	if not (fine and type(after) == "number") then return end
	local done, words = pcall(AbbreviateNumbers, after)
	return done and words or nil
end

-- The panel for now: the mana left after casts of a few costs (odd ones, so
-- a curve's float sums show: run 1), ours and the old way, your mana now, a shot.
local function Draw(r, label)
	local maxMana = UnitPowerMax("player", MANA)
	if Secret(maxMana) or type(maxMana) ~= "number" or maxMana <= 0 then r:Skip("no mana") return end
	local costs = {
		{ "37", 37 }, { "123", 123 },
		{ "a tenth", math.floor(maxMana / 10) },
		{ "a third", math.floor(maxMana / 3) },
		{ "a half", math.floor(maxMana / 2) },
		{ "all but 338", math.max(0, maxMana - 338) },
	}
	local p = Panel(#costs + 1)
	p.title:SetText(("%s, max %d: middle column whole, never a decimal"):format(label, maxMana))
	for i, cost in ipairs(costs) do
		local row = p.rows[i]
		row.label:SetText(("cast costing %s (%d)"):format(cost[1], cost[2]))
		local ok, words = pcall(ns.ManaAfterWords, cost[2])
		local old = OldWords(cost[2])
		local drew = ok and words ~= nil and pcall(row.ours.SetText, row.ours, words)
		if not drew then row.ours:SetText("|cffff5555none|r") end
		pcall(row.old.SetText, row.old, old or "-")
		if ok and words ~= nil and not Secret(words) then
			r:Verdict(not tostring(words):find("%.%d*$") or tostring(words):find("[KMB]$"),
				("%s, %s: %s (plain, whole wanted)"):format(label, cost[1], tostring(words)))
		else
			r:Log(("%s, %s: ours %s, secret %s, drawn %s, old way %s"):format(label, cost[1],
				ok and "ran" or ("error " .. tostring(words)), tostring(Secret(words)), tostring(drew),
				old == nil and "none" or Secret(old) and "secret" or tostring(old)))
		end
	end
	local row = p.rows[#costs + 1]
	row.label:SetText("your mana now")
	local mana = UnitPower("player", MANA)
	local ok, words = pcall(ns.WholeManaWords, mana)
	if not (ok and words ~= nil and pcall(row.ours.SetText, row.ours, words)) then row.ours:SetText("|cffff5555none|r") end
	local fine, old = pcall(AbbreviateNumbers, mana)
	pcall(row.old.SetText, row.old, fine and old or "-")
	r:Log(("%s, mana now: ours %s, secret %s"):format(label, ok and "ran" or ("error " .. tostring(words)), tostring(Secret(mana))))
	p:Show()
	r:Sleep(1)
	r:Shot("mana words, " .. label, { behind = p })
	p:Hide()
	r:Log("verdict by the shot (" .. label .. "): the middle column has no decimals (the right one is the old way)")
end

ns.TestKit.Define({
	name = "wholemana",
	key = "wholeManaTest",
	title = "Whole mana test",
	about = "mana words (after a cast, remaining) are whole numbers on your real mana, nothing to do",
	needs = "A class with mana and a spell that costs it",
	context = function()
		local ok, maxMana = pcall(UnitPowerMax, "player", MANA)
		return ("max mana %s, CreateAbbreviateConfig %s, UnitPowerPercent %s, Mana text %s"):format(
			ok and tostring(maxMana) or "?", type(_G.CreateAbbreviateConfig), type(_G.UnitPowerPercent),
			tostring(ns.db and ns.db.manaAfterCast))
	end,
	steps = {
		{ key = "read", title = "your mana read", seconds = 1, run = function(r)
			r:Probe("UnitPower(player, mana)", UnitPower, "player", MANA)
			local _, maxMana = r:Probe("UnitPowerMax(player, mana)", UnitPowerMax, "player", MANA)
			if Secret(maxMana) or type(maxMana) ~= "number" or maxMana <= 0 then
				r:Skip("no readable max mana here: play a class with mana")
				return
			end
			r:Verdict(type(ns.WholeManaWords) == "function" and type(ns.ManaAfterWords) == "function",
				"the whole-number words and the after-cast words are there")
		end },
		{ key = "plain", title = "plain floats written whole", seconds = 1, run = function(r)
			if not ns.WholeManaWords then r:Fail("no ns.WholeManaWords") return end
			for _, case in ipairs({ { 338.00003051758, "338" }, { 6337.9, "6.3K" }, { 23456.7, "23K" }, { 0.4, "0" } }) do
				local ok, words = pcall(ns.WholeManaWords, case[1])
				r:Verdict(ok and words == case[2], ("%s -> %s (wanted %s)"):format(tostring(case[1]),
					ok and tostring(words) or ("error " .. tostring(words)), case[2]))
			end
		end },
		{ key = "drawn", title = "your mana after a cast, drawn", seconds = 4, run = function(r)
			Draw(r, "full mana")
		end },
		-- (Run 1, 2026-11-21: at full mana both columns were whole. The curve
		-- answer at full mana is its end point, exact; the player's was part
		-- spent, a point mid-curve, where the float sums leave a tail.)
		{ key = "spent", title = "after a spell, drawn again", run = function(r)
			r:WaitFor("Cast any spell that costs mana, once", { events = { "UNIT_SPELLCAST_SUCCEEDED" },
				filter = function(_, unit) return unit == "player" end })
			r:Sleep(1) -- (the mana spent shows up a moment later)
			Draw(r, "mana spent")
		end },
	},
})
