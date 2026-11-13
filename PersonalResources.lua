-- Personal Resources: your player frame and personal resource display, kept
-- up while you recover after a fight (Frames.lua's PORTRAIT_FRAMES), and
-- held back at the start of a fight until there's something to see. A fight
-- you go into with your power at rest (rage or runic power at 0, mana or
-- energy full...) brings up the bars only once it changes; the same for
-- health. Shown or not, the bars' rows on the Standard Frames page say when
-- they come up: this only holds back the fight's.
-- Health and power can be secret (WoW Forever, even out of combat), so rest
-- goes by their change events: they keep firing while either regenerates or
-- drains, and stop once it's back at rest.

local _, ns = ...
local L = ns.L

local DEFAULTS = ns.DEFAULTS
DEFAULTS.personalResources = true   -- the page's switch: off, none of the below works
DEFAULTS.fightWaitPower = true      -- the resource bar waits for your power to change at a fight's start
DEFAULTS.fightWaitHealth = false    -- ...the health bar for your health
DEFAULTS.fightWaitPortrait = false  -- ...the player frame for either
DEFAULTS.fightWaitMana = true       -- ...our mana bar for your mana
DEFAULTS.drainWhenNotEmpty = true   -- "not full" also waits for rage, runic power and the like to drain to 0
DEFAULTS.notFullAfterFight = false  -- "not full" counts only within the Calm Timer of a fight (or a fall, resurrecting)
-- Not full, by row: stays up while your health (nfHealth...) or power
-- (nfPower...) isn't full. (An addon's power bar: by addon, its support file.)
DEFAULTS.nfHealthPlayer = true      -- the player frame, health
DEFAULTS.nfPowerPlayer = true       -- ...power
DEFAULTS.nfHealthPrd = true         -- the personal health bar, health
DEFAULTS.nfPowerPrdPower = true     -- the personal power bar, power
DEFAULTS.nfPowerPrdMana = true      -- our mana bar, while mana isn't full
DEFAULTS.petWhenNotFull = false     -- the pet frame while its health isn't full
DEFAULTS.lowManaShare = 0.25        -- Low mana: under this share of mana (0: off)... (25% to start with)
DEFAULTS.lowManaPortrait = true     -- ...the player frame shows
DEFAULTS.lowManaPower = true        -- ...the personal power bar (mana your power)
DEFAULTS.lowManaMana = true         -- ...our mana bar (mana not your power)
DEFAULTS.prdMana = true             -- a mana bar of ours under them, when mana isn't your power (PersonalMana.lua)
DEFAULTS.prdManaRecent = 3          -- ...only for this many seconds after you use mana (0: always)

-- Whether the page's switch is on (PersonalMana*.lua ask too).
function ns.PersonalResourcesOn(db)
	db = db or ns.db
	return db ~= nil and db.personalResources ~= false
end

-- No change for this long: at rest. (Regeneration ticks every 2 seconds.)
local REST_WINDOW = 3

local lastChange = { health = -math.huge, power = -math.huge, mana = -math.huge }
-- In a fight: whether each is still at rest since it started (nil: not in one).
local waiting

local watcher = CreateFrame("Frame")
watcher:RegisterUnitEvent("UNIT_HEALTH", "player")
watcher:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
watcher:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player") -- (a druid's form: a power of its own)
watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
watcher:SetScript("OnEvent", function(_, event, _, powerToken)
	-- (Each fight looks afresh, on the first check in it.)
	if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
		waiting = nil
		return
	end
	local kind = event == "UNIT_HEALTH" and "health" or "power"
	lastChange[kind] = GetTime()
	if waiting then
		waiting[kind] = false
	end
	-- (Mana apart, for the mana bar's row. A secret token: maybe mana.)
	if event == "UNIT_POWER_UPDATE" and (issecretvalue and issecretvalue(powerToken) or powerToken == "MANA") then
		lastChange.mana = GetTime()
		if waiting then
			waiting.mana = false
		end
	end
end)

local function RestedNow(kind, now)
	return now - lastChange[kind] >= REST_WINDOW
end

-- A row (Standard Frames' player, prd, prdpower) to hold back from the fight
-- now: its setting is on and what it shows has been at rest since the fight
-- started. Out of a fight (casting at an enemy, the pull), while it's at rest now.
local ROW_WAIT = {
	player = { "fightWaitPortrait", "health", "power" },
	prd = { "fightWaitHealth", "health" },
	prdpower = { "fightWaitPower", "power" },
	prdmana = { "fightWaitMana", "mana" },
}
function ns.FightHold(row)
	local wait = ROW_WAIT[row]
	if not wait or not ns.db[wait[1]] or not ns.PersonalResourcesOn() then
		return false
	end
	local now = GetTime()
	if InCombatLockdown() or ns.Flag(UnitAffectingCombat("player")) then
		if not waiting then
			waiting = { health = RestedNow("health", now), power = RestedNow("power", now), mana = RestedNow("mana", now) }
		end
		return waiting[wait[2]] and (not wait[3] or waiting[wait[3]])
	end
	waiting = nil
	return RestedNow(wait[2], now) and (not wait[3] or RestedNow(wait[3], now))
end

local function Readable(value)
	return type(value) == "number" and not (issecretvalue and issecretvalue(value))
end

-- Rage, runic power and the others that rest at 0 (Frames.lua's
-- EMPTY_AT_REST) not drained yet. Secret: still changing.
local function PowerDraining()
	local _, token = UnitPowerType("player")
	if type(token) ~= "string" or (issecretvalue and issecretvalue(token)) or not ns.EMPTY_AT_REST[token] then
		return false
	end
	local power = UnitPower("player")
	if Readable(power) then
		return power > 0
	end
	return not RestedNow("power", GetTime())
end

-- Mana (while it's the power you're showing, or any: with a mana bar of
-- its own) under the Low mana share. Secret: can't tell, so no.
local function LowMana(any)
	local share = ns.db.lowManaShare or 0
	local powerType = UnitPowerType("player")
	if share <= 0 or not any and (not Readable(powerType) or powerType ~= 0) then
		return false
	end
	local mana, maxMana = UnitPower("player", 0), UnitPowerMax("player", 0)
	return Readable(mana) and Readable(maxMana) and maxMana > 0 and mana / maxMana < share
end
-- A frame's row on the page's grid: player, prd (health), prdpower, prdmana,
-- or an addon's power bar ("addon").
local function RowOf(setting, entry)
	if ns.ADDON_POWER_BARS[entry.name] then return "addon" end
	return setting == "prdWhenNotFull" and entry.group or "player"
end
-- Its Not full (health, power) and Low mana settings (false: no such cell).
-- An addon's power bar: its own, by addon (ns.AddPowerBarFrame).
local ROW_KEYS = {
	player = { "nfHealthPlayer", "nfPowerPlayer", "lowManaPortrait" },
	prd = { "nfHealthPrd", false, false },
	prdpower = { false, "nfPowerPrdPower", "lowManaPower" },
	prdmana = { false, "nfPowerPrdMana", "lowManaMana" },
}
local function RowKeys(row, entry)
	if row == "addon" then
		local addon = ns.ADDON_POWER_BARS[entry.name]
		return nil, "nfPower" .. addon, "lowMana" .. addon
	end
	local keys = ROW_KEYS[row]
	if keys then return keys[1] or nil, keys[2] or nil, keys[3] or nil end
end
-- Whether Low mana is ticked for this row and can count now, and whether any
-- mana counts (not only while it's your power): the power bar while mana is
-- your power, our mana bar while it isn't (it's up).
local function LowManaApplies(db, row, lowKey, manaBar)
	if not (lowKey and db[lowKey]) or (db.lowManaShare or 0) <= 0 then return false, false end
	if row == "prdpower" and manaBar or row == "prdmana" and not manaBar then return false, false end
	return true, (row == "prdmana" or row == "player") and manaBar or false
end

-- (Now, as the frames' pass asks it: /cine debug lowmana, LowManaTest.lua.)
function ns.LowManaNow()
	return LowMana(ns.PersonalManaShown and ns.PersonalManaShown())
end

-- Mana the game won't say (WoW Forever: secret even out of a fight, tested
-- 2026-11-13): the game works it out itself, through a curve (up below the
-- Low mana share, none above), and its secret answer goes straight into the
-- frame's alpha, as Vitals Vision does with health (LowHealth.lua). nil:
-- no curve API here.
local manaCurve, manaCurveShare
local function ManaCurve(share)
	if manaCurveShare == share then return manaCurve end
	manaCurveShare, manaCurve = share, nil
	if not (C_CurveUtil and C_CurveUtil.CreateCurve and Enum.LuaCurveType and UnitPowerPercent) then
		return nil
	end
	local ok, curve = pcall(C_CurveUtil.CreateCurve)
	if ok and curve then
		curve:SetType(Enum.LuaCurveType.Linear)
		curve:AddPoint(0, 1)
		curve:AddPoint(math.max(0, share - 0.005), 1)
		curve:AddPoint(share, 0)
		curve:AddPoint(1, 0)
		manaCurve = curve
	end
	return manaCurve
end
function ns.ManaCurveReady()
	return ManaCurve(ns.db.lowManaShare or 0) ~= nil
end
local function SecretManaAlpha(frame, curve)
	frame:SetAlpha(UnitPowerPercent("player", 0, false, curve))
end
-- Whether low mana is this frame's but the mana is secret, so the game sets
-- its alpha (ns.SetLowManaSecretAlpha). As KeepYourFrameUp picks the rows.
function ns.LowManaSecret(setting, entry)
	local db = ns.db
	local share = db.lowManaShare or 0
	if share <= 0 or not setting or ns.NO_SECRET_ALPHA[entry.name] or not ns.PersonalResourcesOn(db) then
		return false
	end
	local mana = UnitPower("player", 0)
	if Readable(mana) then return false end
	local row = RowOf(setting, entry)
	local manaBar = ns.PersonalManaShown and ns.PersonalManaShown()
	local applies, any = LowManaApplies(db, row, select(3, RowKeys(row, entry)), manaBar)
	if not applies then return false end
	if not any then
		local powerType = UnitPowerType("player")
		if not Readable(powerType) or powerType ~= 0 then return false end
	end
	return ManaCurve(share) ~= nil
end
function ns.SetLowManaSecretAlpha(frame)
	local curve = ManaCurve(ns.db.lowManaShare or 0)
	if curve then
		local ok, err = pcall(SecretManaAlpha, frame, curve)
		ns.lowManaSecretError = not ok and tostring(err) or nil
	end
end

-- Mana not full, for the mana bar's row. Secret: still changing.
local function ManaRecovering()
	local mana, maxMana = UnitPower("player", 0), UnitPowerMax("player", 0)
	if Readable(mana) and Readable(maxMana) then
		return maxMana > 0 and mana < maxMana
	end
	return not RestedNow("mana", GetTime())
end

-- Your health not full. Secret: still changing.
local function HealthNotFull()
	local health, maxHealth = UnitHealth("player"), UnitHealthMax("player")
	if Readable(health) and Readable(maxHealth) then
		return maxHealth > 0 and health < maxHealth
	end
	return not RestedNow("health", GetTime())
end

-- Your power not full: our mana bar's row, your mana; rage, runic power and
-- the like (resting at 0), not drained yet (Rage counts until 0). Secret:
-- still changing.
local function PowerNotFull(db, row, manaBar)
	if row == "prdmana" then
		return manaBar and ManaRecovering() or false
	end
	local _, token = UnitPowerType("player")
	if type(token) == "string" and not (issecretvalue and issecretvalue(token)) and ns.EMPTY_AT_REST[token] then
		return db.drainWhenNotEmpty and PowerDraining() or false
	end
	local power, maxPower = UnitPower("player"), UnitPowerMax("player")
	if Readable(power) and Readable(maxPower) then
		return maxPower > 0 and power < maxPower
	end
	return not RestedNow("power", GetTime())
end

-- Whether Not full may count now: not held to after a fight (Not full: after
-- fights only), nor back at a fight's start (Wait at pull).
local function NotFullAllowed(db, row, afterFight, fighting)
	if db.notFullAfterFight and not afterFight then return false end
	return not (fighting and ns.FightHold(row))
end

-- Whether your player frame, personal resource display or pet frame stays up
-- now in CineMode, shown like a fight's frames. setting: the frame's kind
-- (Frames.lua's PORTRAIT_FRAMES; nil for the pet frame); afterFight: within
-- the Calm Timer of a fight, fall or other health loss (Life Tap), or coming
-- back to life. Each row's ticks: the page's grid (ROW_KEYS).
function ns.KeepYourFrameUp(setting, entry, afterFight, fighting)
	local db = ns.db
	if not ns.PersonalResourcesOn(db) then
		return false
	end
	if ns.PET_FRAMES[entry.name] then
		return db.petWhenNotFull and (afterFight or not db.notFullAfterFight) and ns.IsPetRecovering() or false
	end
	if not setting then
		return false
	end
	local row = RowOf(setting, entry)
	local healthKey, powerKey, lowKey = RowKeys(row, entry)
	local manaBar = ns.PersonalManaShown and ns.PersonalManaShown()
	local applies, any = LowManaApplies(db, row, lowKey, manaBar)
	if applies and LowMana(any) then
		return true
	end
	local health, power = healthKey and db[healthKey], powerKey and db[powerKey]
	if not (health or power) or not NotFullAllowed(db, row, afterFight, fighting) then
		return false
	end
	return health and HealthNotFull() or power and PowerNotFull(db, row, manaBar) or false
end

-- The same, in words, for the Why window (Why.lua): each of this page's
-- settings that can keep this frame up, and whether it is now, every one
-- that applies (overlapping too). add(state, text, settingKey): "on" keeping
-- it up, "off" ticked but not now. As KeepYourFrameUp works it out.
function ns.YourFrameWhy(setting, entry, afterFight, fighting, add)
	local db = ns.db
	local page = L["Health & Resources"]
	local pet = ns.PET_FRAMES[entry.name] or false
	if not pet and not setting then return end
	local row = pet and "petframe" or RowOf(setting, entry)
	local healthKey, powerKey, lowKey
	if pet then
		healthKey = "petWhenNotFull"
	else
		healthKey, powerKey, lowKey = RowKeys(row, entry)
	end
	local manaBar = ns.PersonalManaShown and ns.PersonalManaShown()
	local lowApplies, any = false, false
	if not pet then lowApplies, any = LowManaApplies(db, row, lowKey, manaBar) end
	local health, power = healthKey and db[healthKey], powerKey and db[powerKey]
	if not ns.PersonalResourcesOn(db) then
		if health or power or lowApplies then
			add("off", L["The %s page is off, so its settings don't keep this up"]:format(page), "personalResources")
		end
		return
	end
	if lowApplies then
		local share = ("%d%%"):format(math.floor(db.lowManaShare * 100 + 0.5))
		if LowMana(any) then
			add("on", L["Your mana is under %s (Low mana)"]:format(share), lowKey)
		else
			add("off", L["Shows whenever your mana is under %s (Low mana)"]:format(share), lowKey)
		end
	end
	if not (health or power) then return end
	local key = health and healthKey or powerKey
	if db.notFullAfterFight and not afterFight then
		add("off", L["Not full counts only after a fight, a fall, Life Tap or resurrecting (Not full: only during Calm Timer)"],
			"notFullAfterFight")
		return
	end
	if fighting and not pet and ns.FightHold(row) then
		add("off", L["Held back at the fight's start while you're at rest (Wait at pull)"], key)
		return
	end
	local shown = false
	if health then
		if pet and ns.IsPetRecovering() then
			add("on", L["Your pet's health isn't full yet (Not full: Health)"], healthKey)
			shown = true
		elseif not pet and HealthNotFull() then
			add("on", L["Your health isn't full yet (Not full: Health)"], healthKey)
			shown = true
		end
	end
	if power and PowerNotFull(db, row, manaBar) then
		add("on", row == "prdmana" and L["Your mana isn't full yet (Not full: Power)"]
			or L["Your power isn't full yet, or your rage or the like isn't drained (Not full: Power)"], powerKey)
		shown = true
	end
	if not shown then
		add("off", pet and L["Stays up while your pet's health isn't full (Not full: Health): it is"]
			or L["Stays up while what's ticked under Not full isn't full: it is"], key)
	end
end

-- The page.
function ns.CreatePersonalResourcesPanel(kit)
	local canvas, content = kit.CreateScrollPage()
	local title = kit.Label(content, "GameFontNormalLarge", L["Health & Resources"])
	title:SetPoint("TOPLEFT", 16, -16)
	local hasDisplay = _G.CinematicPersonalPower ~= nil
	local intro = kit.PageIntro(content, title,
		L["Your player frame, pet frame and personal resource display in CineMode: kept up while your health " ..
		"or power isn't full or your mana is low, and held back at the start of a fight until there's something " ..
		"to see. Hover a row or column for what it does. When they come up at all (always, in fights, in places) " ..
		"is their rows' on the HUD page."])
	-- Their look: the Style hub's Personal Resource Style page (PersonalStyle.lua).
	local styleLink = ns.StyleLink(content, title, "Personal Style", L["Opens the Personal Resource Style page: how the bars look."], kit.Tooltip)
	ns.FramesLink(content, title, "prd", styleLink)
	local switch = kit.PageSwitch(content, "personalResources", L["Enable Page"],
		L["On: your player frame, pet frame and personal resource display stay up or wait as this page says, " ..
		"and its mana bar and remaining mana text show. Off: none of it; they come up only as their HUD " ..
		"rows say."], intro, function()
		if ns.UpdatePersonalMana then ns.UpdatePersonalMana() end
		if ns.RefreshPersonalStyle then ns.RefreshPersonalStyle() end
		if ns.UpdateManaCost then ns.UpdateManaCost() end
	end)
	local stack = kit.Stack(switch, "check")
	local function Tick(key, label, tip, enabledBy)
		local check = stack:Add(kit.Check(content, key, label, tip), "check")
		if enabledBy then kit.GreyUnless(check, enabledBy) end
		return check
	end

	-- Low mana: the share the grid's Low mana column goes by.
	stack:Header(content, L["Low mana"])
	local function Percent(value) return value == 0 and L["Off"] or ("%d%%"):format(value) end
	-- (Greys just the grid's Low mana ticks: the whole menu's Refresh on every
	-- step of a drag froze the game.)
	local lowCells = {}
	local lowMana = stack:Add(kit.Slider(content, "lowManaShare", L["Below"], 0, 90, 5, Percent, 100, function()
		for _, cell in ipairs(lowCells) do cell:Refresh() end
	end), "slider")
	kit.Tooltip(lowMana, L["In CineMode, the frames ticked under Low mana below show whenever your mana is under " ..
		"this share, in a fight or not: drinking, or saving mana for the pull. Off: 0."])

	-- Keep up: a row per frame, a column per reason it stays up. A cell a
	-- frame can't have is left empty; a frame this client hasn't, no row.
	stack:Header(content, L["Keep up"])
	local function Fights(db) return db.stayInCombat end
	local function LowOn(db) return (db.lowManaShare or 0) > 0 end
	local COLUMNS = {
		{ L["Health"], L["Not full: whenever your health isn't full, in a fight or not (or only during the Calm Timer: " ..
			"the tick under this table)."], group = L["Not full"] },
		{ L["Power"], L["Not full: whenever your power isn't full (mana, energy, focus), in a fight or not; " ..
			"rage, runic power and the like until they're back to 0 (Rage counts until 0)."], group = L["Not full"] },
		{ L["Low mana"], L["Whenever your mana is under the share above, in a fight or not."] },
		{ L["Wait at pull"], L["At a fight's start, it comes up only once your health or power changes: your " ..
			"first cast, your first hit. Only while fights bring frames up (In combat on the CineMode page)."] },
		{ L["Mana text"], L["While you cast a spell that costs mana, your mana's numbers on the bar show what " ..
			"you'll have once the cast is done, paler. The amount and the percent, whichever the game shows there " ..
			"(its Status Text setting); with the game's numbers off, the amount in the middle of the bar."] },
	}
	-- (The mana text's: redrawn as it's ticked, PersonalManaCost.lua.)
	local function Redraw()
		if ns.UpdateManaCost then ns.UpdateManaCost() end
	end
	-- (Each bar by what it shows: the health bar by your health, the power
	-- and mana bars by your power.)
	local rows = {
		{ L["Player Frame"], nil, "nfHealthPlayer", "nfPowerPlayer", "lowManaPortrait", "fightWaitPortrait",
			"manaAfterPortrait" },
	}
	if _G.PetFrame then
		rows[#rows + 1] = { L["Pet Frame"], L["Not full: until your pet's health is full."], "petWhenNotFull" }
	end
	if hasDisplay then
		rows[#rows + 1] = { L["PRD: Health"], L["The game's personal resource display (PRD): its health bar."],
			"nfHealthPrd", nil, nil, "fightWaitHealth" }
		rows[#rows + 1] = { L["PRD: Power"], L["The game's personal resource display (PRD): its power bar (mana, " ..
			"rage, energy...). Low mana: while mana is your power."], nil, "nfPowerPrdPower", "lowManaPower",
			"fightWaitPower", "manaAfterDisplay" }
	end
	if ns.PERSONAL_MANA then
		rows[#rows + 1] = { L["Mana bar"], L["Ours, under the PRD's power bar, while mana isn't your power (forms, " ..
			"Shadow, Elemental). Not full: until your mana's full."], nil, "nfPowerPrdMana", "lowManaMana", "fightWaitMana" }
	end
	-- (Other addons' power bars standing in for these: their own rows, by addon.)
	for _, bar in ipairs(ns.ADDON_POWER_ROWS or {}) do
		if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(bar.addon) then
			rows[#rows + 1] = { L["Power bar (%s)"]:format(bar.addon), bar.tip,
				nil, "nfPower" .. bar.addon, "lowMana" .. bar.addon }
		end
	end
	-- (Two heading lines: a group's name over its columns, Not full's.)
	local LABEL_W, COLUMN_W, ROW_H, HEAD_H = 150, 76, 26, 40
	local grid = CreateFrame("Frame", nil, content)
	grid:SetSize(LABEL_W + #COLUMNS * COLUMN_W, HEAD_H + #rows * ROW_H)
	local groupAt = {}
	for c, column in ipairs(COLUMNS) do
		local head = CreateFrame("Frame", nil, grid)
		head:SetSize(COLUMN_W, 20)
		head:SetPoint("BOTTOMLEFT", grid, "TOPLEFT", LABEL_W + (c - 1) * COLUMN_W, -HEAD_H)
		local text = kit.Label(head, "GameFontNormalSmall", column[1])
		text:SetPoint("CENTER")
		text.searchSkip = true
		kit.Tooltip(head, column[2])
		if column.group then
			local span = groupAt[column.group]
			if not span then
				span = kit.Label(grid, "GameFontNormalSmall", column.group)
				span.searchSkip = true
				span.first = c
				groupAt[column.group] = span
			end
			span:ClearAllPoints()
			span:SetPoint("BOTTOM", grid, "TOPLEFT", LABEL_W + ((span.first - 1) + c) / 2 * COLUMN_W, -HEAD_H + 20)
		end
	end
	for r, row in ipairs(rows) do
		local y = -HEAD_H - (r - 1) * ROW_H
		local name = CreateFrame("Frame", nil, grid)
		name:SetSize(LABEL_W, ROW_H)
		name:SetPoint("TOPLEFT", 0, y)
		local text = kit.Label(name, "GameFontHighlight", row[1])
		text:SetPoint("LEFT")
		text.searchSkip = true
		if row[2] then kit.Tooltip(name, row[2]) end
		for c = 1, #COLUMNS do
			local key = row[2 + c]
			if key then
				local column = COLUMNS[c]
				local named = column.group and ("%s %s"):format(column.group, column[1]:lower()) or column[1]
				local cell = kit.Check(grid, key, "", ("%s: %s. %s"):format(row[1], named, column[2]),
					c == 5 and function(value)
						ns.GetDB()[key] = value
						Redraw()
					end or nil)
				cell:SetPoint("CENTER", grid, "TOPLEFT", LABEL_W + (c - 0.5) * COLUMN_W, y - ROW_H / 2)
				cell.searchLabel = ("%s: %s"):format(row[1], named)
				if c == 3 then
					kit.GreyUnless(cell, LowOn)
					lowCells[#lowCells + 1] = cell
				elseif c == 4 then
					kit.GreyUnless(cell, Fights)
				end
			end
		end
	end
	stack:Add(grid, "label")
	Tick("notFullAfterFight", L["Not full: only during Calm Timer"],
		L["Ticked, Not full brings frames up only after a fight, a fall, a spell that costs you health (Life " ..
		"Tap) or resurrecting, until the Calm Timer runs out: casting or drinking in town brings nothing up. " ..
		"Unticked, it works any time."])
	Tick("drainWhenNotEmpty", L["Rage counts until 0"],
		L["Rage, runic power and the other resources that drain away out of combat: Not full keeps the frames " ..
		"up until they're back to 0."])

	-- Mana under the power bar, when it isn't your power (PersonalMana.lua; its
	-- look: the Style hub's Personal Resource Style page).
	if ns.PERSONAL_MANA then
		stack:Header(content, L["Mana bar"])
		local function Update()
			if ns.UpdatePersonalMana then ns.UpdatePersonalMana() end
		end
		stack:Add(kit.Check(content, "prdMana", L["Show mana bar"],
			L["The game shows only your main power under your character: Maelstrom, Insanity, Astral Power, " ..
			"rage or energy in a form. Ticked, your mana gets a bar of its own under it. When it comes up is the " ..
			"Personal mana bar row on the HUD page."], function(value)
			ns.GetDB().prdMana = value
			if ns.RefreshPersonalStyle then ns.RefreshPersonalStyle() end -- (shown and dressed)
			kit.Refresh()
		end), "check")
		local recentLine = kit.BoxLine(content)
		stack:Add(recentLine, "label", 20)
		local recentBox = recentLine:Box(L["After using mana for"], "prdManaRecent", 0, 60, 1, "%d", 1,
			L["The mana bar shows for this many seconds after you spend mana, then fades out until you spend " ..
			"some again. 0: whenever it's up."], Update, 40, L["sec"])
		kit.GreyUnless(recentBox, function(db) return db.prdMana end)
		-- (And after the page's Reset, or a profile loaded: shown as the settings are now.)
		local updater = CreateFrame("Frame", nil, content)
		updater.Refresh = Update
		kit.AddControl(updater)
	end

	-- (And after the page's Reset, or a profile loaded: drawn as the settings are now.)
	local redrawer = CreateFrame("Frame", nil, content)
	redrawer.Refresh = Redraw -- (the grid's Mana text)
	kit.AddControl(redrawer)

	-- Addon Frame Links (last): which addon's bars they are (FrameLinks.lua).
	local links = ns.BuildLinkSection(content, stack.last, "prd")

	canvas:SetScript("OnShow", kit.PageShown(function()
		kit.Refresh()
		links.Show()
	end, content))
	canvas:Hide()
	kit.RegisterSubpage(canvas, "Personal Resources", L["Health & Resources"])
end
