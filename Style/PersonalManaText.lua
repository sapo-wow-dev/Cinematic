-- Mana after the cast: while you cast a spell that costs mana, your mana's
-- numbers on its bar show what you'll have once the cast is done (your mana
-- less its cost), paler, then your mana again. They follow the game's own
-- words on the bar (its Status Text setting): the amount where it shows an
-- amount, the percent where it shows a percent (both, with both), each in
-- that word's place while it's faded; with none, the amount in the middle.
-- On your mana under your character and on your player frame's (the bars
-- and the cast: PersonalManaCost.lua, which calls ns.UpdateManaAfter). Off
-- to start with: the Health & Resources page's Mana text turns it on for
-- both (manaAfterCast; one per bar till 2026-11-15).
-- (The game's own bars lower their fill by the cost as a cast starts, and
-- their words with it, so there ours say what the game's do while those
-- show; on our mana bar, and with the game's words off, ours are all there is.)
-- Your mana can be secret (retail, even out of fights): then the game
-- works the sums out, through curves over your mana's share of its max
-- (0 up to the cost's share, then up to what's left at full), and its
-- answers are shown as they come. Without a curve API, or with the cost or
-- max secret too, the game's words stay.

local _, ns = ...
ns.Module("style", function() -- (the rest of this file: only with Style loaded, Modules.lua)

local DEFAULTS = ns.DEFAULTS
DEFAULTS.manaAfterCast = false      -- your mana's numbers (under your character, on your player frame) show what's left after the cast

local MANA = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
local TINT = { 0.7, 0.85, 1 } -- paler than the game's white: a guess
local KEYS = { display = "manaAfterCast", portrait = "manaAfterCast" } -- each bar's setting (one for both)

local texts = setmetatable({}, { __mode = "k" }) -- bar -> our words on it: { amount, percent }
local muted = setmetatable({}, { __mode = "k" }) -- the game's words -> true, while faded for ours
local last = "no cast yet" -- what it did at the last cast, for /cine debug plates (kept after it)
local lastPlaced = "nowhere" -- ...and where it went
local curves = {} -- "cost/max/amount|percent" -> the curve for it (a few: a spell's cost rarely changes)

local function Readable(value)
	return value ~= nil and not (issecretvalue and issecretvalue(value))
end

-- The game's words on a bar that are showing (our mana bar's copies of
-- them too): its amount and its percent, either nil. (As it names them:
-- an amount right and a percent left, with Both; else one in the middle,
-- an amount or a percent as Status Text says.)
local function GameWords(bar)
	local copies = type(bar.words) == "table" and bar.words or {}
	local function Shown(field)
		local words = bar[field] or copies[field]
		if type(words) == "table" and words.GetText and ns.Flag(words:IsShown()) then return words end
	end
	local amount, percent = Shown("RightText"), Shown("LeftText")
	local middle = Shown("TextString")
	if middle then
		local ok, mode = pcall(GetCVar, "statusTextDisplay")
		if ok and mode == "PERCENT" then percent = percent or middle else amount = amount or middle end
	end
	return amount, percent
end

-- In the game's font for its words where it has one.
local function Texts(bar)
	local made = texts[bar]
	if made then return made end
	local overlay = CreateFrame("Frame", nil, bar)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(bar:GetFrameLevel() + 3)
	local theirs = bar.TextString or bar.RightText
	local object = type(theirs) == "table" and theirs.GetFontObject and theirs:GetFontObject()
	made = {}
	for _, part in ipairs({ "amount", "percent" }) do
		local text = overlay:CreateFontString(nil, "OVERLAY")
		text:SetFontObject(object or "TextStatusBarText")
		text:SetTextColor(TINT[1], TINT[2], TINT[3])
		text:Hide()
		made[part] = text
	end
	texts[bar] = made
	return made
end

-- Where it goes: on the game's word, lined up the way it is (a text the
-- bar's width, justified right, has its middle mid-bar: by its
-- justification, then), else the bar's middle. (On the game's words
-- themselves, faded: their own points can be restricted.) Returns the side.
local function Place(text, bar, theirs)
	text:ClearAllPoints()
	local side = "CENTER"
	if theirs then
		local ok, justify = pcall(theirs.GetJustifyH, theirs)
		if ok and (justify == "LEFT" or justify == "RIGHT") then side = justify end
	end
	text:SetPoint(side, theirs or bar, side, 0, 0)
	text:SetJustifyH(side)
	return side
end

-- An amount of mana in words, shortened as the game's (12.3K) and a whole
-- number under 1000, secret or not. A curve's answer (a secret amount
-- after a cast) is a float, 338.00003051758, and the game's own shortening
-- leaves anything under 1000 as it is (the player's screenshot 2026-11-21,
-- max mana over 1000): so its rules plus one under them, from 1 up whole
-- (divide by 1, no decimals; cuts the fraction off). The game takes rules
-- of ours on a secret amount in this form ({ config = ... }, tested by
-- /cine debug numbers on both clients). nil stays nil.
local WHOLE_RULES = {
	{ 10000000000, "B", 1000000000, 1 }, { 1000000000, "B", 100000000, 10 },
	{ 10000000, "M", 1000000, 1 }, { 1000000, "M", 100000, 10 },
	{ 10000, "K", 1000, 1 }, { 1000, "K", 100, 10 },
	{ 1, "", 1, 1 },
}
local wholeOptions -- the game's options for them, made once (false: it can't)
function ns.WholeManaWords(amount)
	if amount == nil then return nil end
	local abbreviate = _G.AbbreviateNumbers
	if Readable(amount) then
		amount = math.floor(amount + 0.5)
		return abbreviate and abbreviate(amount) or tostring(amount)
	end
	if wholeOptions == nil then
		wholeOptions = false
		if _G.CreateAbbreviateConfig then
			local data = {}
			for i, rule in ipairs(WHOLE_RULES) do
				data[i] = { breakpoint = rule[1], abbreviation = rule[2], significandDivisor = rule[3],
					fractionDivisor = rule[4], abbreviationIsGlobal = false }
			end
			local ok, config = pcall(_G.CreateAbbreviateConfig, data)
			if ok and config then wholeOptions = { config = config } end
		end
	end
	if abbreviate and wholeOptions then
		local ok, words = pcall(abbreviate, amount, wholeOptions)
		if ok and words ~= nil then return words end
	end
	-- (No rules of ours: the game's formatting rounds it, a secret string.)
	local ok, words = pcall(string.format, "%.0f", amount)
	if ok then return words end
	return abbreviate and abbreviate(amount) or tostring(amount)
end
ns.WHOLE_MANA_RULES = WHOLE_RULES

-- Mana less cost, worked out by the game from your secret mana: as an
-- amount, or as a percent of the max (nil: it can't be).
local function SecretAfter(cost, asPercent)
	local maxMana = UnitPowerMax("player", MANA)
	local percentOf = _G.UnitPowerPercent
	if not (percentOf and C_CurveUtil and C_CurveUtil.CreateCurve and Enum.LuaCurveType
		and Readable(cost) and Readable(maxMana) and maxMana > 0) then return end
	local key = cost .. "/" .. maxMana .. (asPercent and "/percent" or "/amount")
	local curve = curves[key]
	if not curve then
		local ok, made = pcall(C_CurveUtil.CreateCurve)
		if not (ok and made) then return end
		made:SetType(Enum.LuaCurveType.Linear)
		local share = math.min(1, cost / maxMana)
		local step = 1 / maxMana -- one point of mana
		made:AddPoint(0, 0)
		if asPercent then
			if share > 0 and share < 1 then made:AddPoint(share, 0) end
			made:AddPoint(1, (1 - share) * 100)
		else
			-- (Half a point up from 1 on: the whole-number words cut the
			-- fraction off, so that rounds to the nearest, 337.9999 is 338.
			-- Flat 0 till half a point past the cost, so a mana a hair
			-- over the cost, by the game's float sums, still says 0.)
			if share + step < 1 then
				made:AddPoint(share + step / 2, 0)
				made:AddPoint(share + step, 1.5)
			end
			made:AddPoint(1, math.max(0, maxMana - cost) + (share < 1 and 0.5 or 0))
		end
		curve = made
		curves[key] = curve
	end
	local ok, after = pcall(percentOf, "player", MANA, false, curve)
	if ok and type(after) == "number" then return after end
end

-- The words after the cast: the amount (shortened, as the game's) and the
-- percent, either nil where it can't be worked out.
local function AfterWords(cost)
	local mana, maxMana = UnitPower("player", MANA), UnitPowerMax("player", MANA)
	local amount, percent, fromCurve
	if Readable(mana) and Readable(cost) then
		amount = math.max(0, mana - cost)
		if Readable(maxMana) and maxMana > 0 then percent = amount / maxMana * 100 end
		last = ("%s left of %s"):format(tostring(amount), tostring(mana))
	else
		amount, percent = SecretAfter(cost), SecretAfter(cost, true)
		fromCurve = true
		last = amount == nil and "mana secret, no curve for it: the game's words"
			or Readable(amount) and ("%s left (by curve)"):format(tostring(amount))
			or "worked out by the game's curves (secret)"
	end
	-- (A whole number, never a fraction: ns.WholeManaWords. A curve's
	-- answer is already half a point up, SecretAfter: cut, not rounded.)
	if Readable(amount) then
		amount = fromCurve and math.floor(amount) or math.floor(amount + 0.5)
	end
	local okAmount, amountWords = pcall(ns.WholeManaWords, amount)
	local okPercent, percentWords = pcall(function()
		return percent ~= nil and ("%d%%"):format(percent) or nil
	end)
	if not (okAmount and okPercent) then last = last .. ", some words failed" end
	return okAmount and amountWords or nil, okPercent and percentWords or nil
end

ns.ManaAfterWords = AfterWords -- (for Tools/offline/wholemana.lua)

-- For the cast going on (cost: its mana cost, nil while none), on the bars
-- your mana is on now (by where).
function ns.UpdateManaAfter(cost, bars)
	local db = ns.GetDB()
	-- (The bars it's on for.)
	local wanted = {}
	for where, key in pairs(KEYS) do
		local bar = bars and bars[where]
		if bar and cost and db and db[key] and ns.PersonalResourcesOn(db, "prdmana") then wanted[#wanted + 1] = bar end
	end
	local on = #wanted > 0
	local amountWords, percentWords
	if on then amountWords, percentWords = AfterWords(cost) end
	local shown, mute, placed = {}, {}, {}
	-- (One of ours on one of the game's words, or the bar's middle.)
	local function Put(text, words, theirs, bar)
		if not words then return end
		local side = Place(text, bar, theirs)
		pcall(text.SetText, text, words)
		text:Show()
		shown[text] = true
		if theirs then mute[theirs] = true end
		return side
	end
	for _, bar in ipairs(wanted) do
		local amount, percent = GameWords(bar)
		local ours = Texts(bar)
		local where = {}
		if amount or not percent then
			local side = Put(ours.amount, amountWords, amount, bar)
			if side then where[#where + 1] = "amount " .. (amount and "on the game's, " or "alone, ") .. side:lower() end
		end
		if percent then
			local side = Put(ours.percent, percentWords, percent, bar)
			if side then where[#where + 1] = "percent on the game's, " .. side:lower() end
		end
		placed[#placed + 1] = ("%s: %s"):format(ns.DescribeManaBar and ns.DescribeManaBar(bar) or "a bar",
			#where > 0 and table.concat(where, " and ") or "nothing")
	end
	if on then lastPlaced = #placed > 0 and table.concat(placed, "; ") or "nowhere" end
	for _, made in pairs(texts) do
		for _, text in pairs(made) do
			if not shown[text] then text:Hide() end
		end
	end
	for words in pairs(mute) do
		muted[words] = true
		words:SetAlpha(0)
	end
	for words in pairs(muted) do
		if not mute[words] then
			muted[words] = nil
			words:SetAlpha(1)
		end
	end
end

-- For /cine debug plates.
function ns.DescribeManaText()
	local mana = UnitPower("player", MANA)
	local db = ns.GetDB()
	local ok, mode = pcall(GetCVar, "statusTextDisplay")
	local function On(key) return db and db[key] and "on" or "off" end
	return ("mana after cast (Mana text) %s; Status Text %s; last cast: %s, shown on %s; "
		.. "mana now %s"):format(On(KEYS.display), ok and tostring(mode) or "?", last, lastPlaced,
		Readable(mana) and tostring(mana) or "secret")
end
end) -- (ns.Module "style")
