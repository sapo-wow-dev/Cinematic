-- /cine debug shieldprobe: can a shield's tracked-buff icon (Power Word:
-- Shield, Ice Barrier...) show how much it can still absorb, colored green to
-- red, instead of the seconds left? (Discord #requests, Forever, 2026-11-23;
-- ledger Tools/tests/cdm-shield-strength.md.) One thing to do: cast your
-- shield on yourself, then attack a mob. Steps:
--   1 cast   waits for your shield; out of a fight: the absorb read
--            (UnitGetTotalAbsorbs), the heal prediction calculator, the
--            tracked-buff icons (which one lit up), the aura's points, the
--            spell's description; then our number drawn on the icon, colored
--            by a curve, the game's timer hidden, a shot
--   2 fight  waits for the fight; every absorb change: the read (secret?),
--            our number set from it, the curve's color tried on it; shots at
--            the first hit on the shield and when it breaks (or the fight ends)
--   3 after  out of the fight again: reads, the game's timer put back
-- Into CinematicDB.shieldProbeTestLog. Dev copy only.
local _, ns = ...

local VIEWERS = { "BuffIconCooldownViewer", "BuffBarCooldownViewer" }

local function Secret(value) return issecretvalue and issecretvalue(value) or false end
local function Plain(value) return type(value) == "number" and not Secret(value) and value or nil end

-- Every active tracked-buff item: { item, viewer }.
local function Items()
	local found = {}
	for _, name in ipairs(VIEWERS) do
		local viewer = _G[name]
		local pool = viewer and viewer.itemFramePool
		if type(pool) == "table" and type(pool.EnumerateActive) == "function" then
			for item in pool:EnumerateActive() do found[#found + 1] = { item = item, viewer = name } end
		end
	end
	return found
end

local function Lit(item) return type(item.auraInstanceID) ~= "nil" end

local function SpellOf(item)
	local info = ns.IconCooldownInfo and ns.IconCooldownInfo(item)
	local id = type(info) == "table" and Plain(info.spellID) or nil
	local name = id and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
	return id, (type(name) == "string" and not Secret(name)) and name or nil, info
end

local SHIELD_WORDS = { "Shield", "Barrier", "Ward" }
local function ShieldName(name)
	if not name then return false end
	for _, word in ipairs(SHIELD_WORDS) do if name:find(word, 1, true) then return true end end
	return false
end

-- The first number in a spell's description ("absorbing 571 damage").
local function DescriptionNumber(id)
	if not (id and C_Spell and C_Spell.GetSpellDescription) then return nil, "no id" end
	local ok, text = pcall(C_Spell.GetSpellDescription, id)
	if not ok then return nil, "error " .. tostring(text) end
	if Secret(text) then return nil, "secret" end
	if type(text) ~= "string" then return nil, type(text) end
	local number = text:match("[Aa]bsorb%a*%s+(%d[%d,]*)") or text:match("(%d[%d,]*)%s+damage")
	return number and tonumber((number:gsub(",", ""))), text:sub(1, 90)
end

-- The run's own state (made fresh each run).
local S

local function Label(item)
	if S.label then return S.label end
	local holder
	if item then
		local art = type(item.Icon) == "table" and item.Icon.GetObjectType and item.Icon or item
		holder = CreateFrame("Frame", nil, item)
		holder:SetAllPoints(art)
		holder:SetFrameLevel(item:GetFrameLevel() + 10)
	else
		-- (No shield icon tracked: a stand-in square over your character, so
		-- the number and its color are still tried on the secret read.)
		holder = CreateFrame("Frame", nil, UIParent)
		holder:SetSize(48, 48)
		holder:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
		local back = holder:CreateTexture(nil, "BACKGROUND")
		back:SetAllPoints()
		back:SetColorTexture(0.1, 0.2, 0.4, 0.9)
	end
	local text = holder:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	text:SetFont((text:GetFont()), 15, "OUTLINE")
	text:SetPoint("CENTER", 0, 0)
	S.holder, S.label = holder, text
	return text
end

-- The curve: red at 0, yellow halfway, green at the shield's starting size.
local function MakeCurve(top)
	local ok, curve = pcall(function()
		local c = C_CurveUtil.CreateColorCurve()
		c:AddPoint(0, CreateColor(1, 0.15, 0.15, 1))
		c:AddPoint(top / 2, CreateColor(1, 0.85, 0.1, 1))
		c:AddPoint(top, CreateColor(0.2, 1, 0.3, 1))
		return c
	end)
	return ok and curve or nil, not ok and tostring(curve) or nil
end

-- Our number from a read, colored by the curve when it can be (returns what happened).
local function Paint(amount)
	local text = S.label
	if not text then return "no label" end
	local okText, errText = pcall(text.SetText, text, amount)
	local colored = "no curve"
	if S.curve then
		local okColor, err = pcall(function()
			local color = S.curve:Evaluate(amount)
			text:SetTextColor(color:GetRGBA())
		end)
		colored = okColor and "curve ok" or ("curve error: " .. tostring(err))
		if not okColor then pcall(text.SetTextColor, text, 1, 1, 1) end
	end
	text:Show()
	return ("text %s, %s"):format(okText and "set" or ("error: " .. tostring(errText)), colored)
end

local function ReadAll(r, tag)
	r:Probe(tag .. " UnitGetTotalAbsorbs(player)", UnitGetTotalAbsorbs, "player")
	if CreateUnitHealPredictionCalculator and UnitGetDetailedHealPrediction then
		local ok, calc = pcall(CreateUnitHealPredictionCalculator)
		if ok and calc then
			pcall(UnitGetDetailedHealPrediction, "player", nil, calc)
			r:Fields(tag .. " heal prediction calculator", {
				damageAbsorbs = function() return calc:GetDamageAbsorbs() end,
				maxDamageAbsorbs = function() return calc:GetMaximumDamageAbsorbs() end,
				totalDamageAbsorbs = function() return calc:GetTotalDamageAbsorbs() end,
				clampMode = function() return calc:GetDamageAbsorbClampMode() end,
				maxHealth = function() return calc:GetMaximumHealth() end,
			})
		else
			r:Log(tag .. " heal prediction calculator: not made (" .. tostring(calc) .. ")")
		end
	end
	if S.item then
		local item = S.item
		r:Fields(tag .. " shield icon", {
			auraInstanceID = function() return item.auraInstanceID end,
			lit = function() return Lit(item) end,
			shown = function() return item:IsShown() end,
		})
		local id = Plain(item.auraInstanceID)
		if id then
			local ok, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "player", id)
			if ok and type(aura) == "table" and not Secret(aura) then
				local points = aura.points
				local list = {}
				if type(points) == "table" and not Secret(points) then
					for i, p in ipairs(points) do list[#list + 1] = ns.TestKit.Shown(p) if i >= 4 then break end end
				end
				r:Log(("  %s aura: spell %s, points %s%s, duration %s"):format(tag, ns.TestKit.Shown(aura.spellId),
					type(points) == "table" and not Secret(points) and "{" .. table.concat(list, ", ") .. "}" or ns.TestKit.Shown(points),
					"", ns.TestKit.Shown(aura.duration)))
			else
				r:Log(("  %s aura by instance: ok=%s %s"):format(tag, tostring(ok), ns.TestKit.Shown(aura)))
			end
		end
		local number, text = DescriptionNumber(S.spellID)
		r:Log(("  %s description: number %s (%s)"):format(tag, tostring(number), tostring(text)))
	end
end

-- Every absorb change while the run is going.
local watcher = CreateFrame("Frame")
watcher:SetScript("OnEvent", function(_, event, unit, ...)
	if not S or unit ~= "player" then return end
	local fight = InCombatLockdown() and "fight" or "calm"
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		local id = Plain(select(2, ...)) -- (castGUID, spellID)
		local name = id and C_Spell.GetSpellName(id)
		if type(name) == "string" and not Secret(name) and ShieldName(name) then S.castID, S.castName = id, name end
	elseif event == "UNIT_ABSORB_AMOUNT_CHANGED" then
		S.events[fight] = (S.events[fight] or 0) + 1
		local ok, amount = pcall(UnitGetTotalAbsorbs, "player")
		local secret = ok and Secret(amount)
		if ok then S.secret[fight] = (S.secret[fight] or 0) + (secret and 1 or 0) end
		local zero = ok and not secret and amount == 0
		local how = ok and Paint(amount) or "read error"
		if S.label and zero then S.label:SetText("") end
		S.changes = S.changes + 1
		if S.changes <= 30 then
			S.lines[#S.lines + 1] = ("%.1f %s: absorb %s, arg unit %s, %s"):format(GetTime() - S.started, fight,
				ok and (secret and "secret" or tostring(amount)) or "error", Secret(unit) and "secret" or "plain", how)
		end
	end
end)

ns.TestKit.Define({
	name = "shieldprobe",
	key = "shieldProbeTest",
	title = "Shield strength probe",
	about = "a shield's tracked-buff icon showing what it can still absorb: cast your shield, then attack a mob",
	needs = "A character with a shield spell (Power Word: Shield) in Tracked Buffs, and a mob to fight",
	context = function()
		return ("UnitGetTotalAbsorbs %s, color curves %s, calculator %s"):format(tostring(UnitGetTotalAbsorbs ~= nil),
			tostring(C_CurveUtil and C_CurveUtil.CreateColorCurve ~= nil), tostring(CreateUnitHealPredictionCalculator ~= nil))
	end,
	steps = {
		{ key = "cast", title = "your shield, out of a fight", run = function(r)
			S = { events = {}, secret = {}, lines = {}, changes = 0, started = GetTime() }
			pcall(watcher.RegisterUnitEvent, watcher, "UNIT_ABSORB_AMOUNT_CHANGED", "player")
			pcall(watcher.RegisterUnitEvent, watcher, "UNIT_SPELLCAST_SUCCEEDED", "player")
			-- Can a shield be tracked at all? The game's Tracked Buffs catalog
			-- (learned and not), shields in it, and which are shown now.
			local category = Enum and Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.TrackedBuff
			local okSet, set = pcall(C_CooldownViewer.GetCooldownViewerCategorySet, category, true)
			local inCatalog = {}
			if okSet and type(set) == "table" and not Secret(set) then
				for _, cooldownID in ipairs(set) do
					local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
					local id = ok and type(info) == "table" and Plain(info.spellID) or nil
					local name = id and C_Spell.GetSpellName(id)
					if type(name) == "string" and not Secret(name) and ShieldName(name) then
						inCatalog[#inCatalog + 1] = ("%s %d (cooldown %d, known %s)"):format(name, id, cooldownID,
							tostring(info.isKnown))
					end
				end
				r:Log(("  Tracked Buffs catalog: %d entries; shields: %s"):format(#set,
					#inCatalog > 0 and table.concat(inCatalog, "; ") or "none"))
			else
				r:Log(("  Tracked Buffs catalog: category %s, read ok=%s %s"):format(tostring(category), tostring(okSet),
					ns.TestKit.Shown(set)))
			end
			local before = {}
			local items = Items()
			local tracked = false
			for _, entry in ipairs(items) do
				local id, name, info = SpellOf(entry.item)
				before[entry.item] = Lit(entry.item)
				tracked = tracked or ShieldName(name)
				r:Log(("  tracked %s: cooldownID %s, info %s, spell %s %s, lit %s"):format(entry.viewer,
					ns.TestKit.Shown(entry.item.cooldownID), type(info), tostring(id), tostring(name), tostring(Lit(entry.item))))
			end
			r:Log(("  %d tracked-buff items, a shield among them: %s"):format(#items, tostring(tracked)))
			r:Probe({ label = "before UnitGetTotalAbsorbs(player)", rule = "forever.absorbs.secret-out-of-combat" },
				UnitGetTotalAbsorbs, "player")
			r:Log("  a shield icon shown in Tracked Buffs before the cast: " .. tostring(tracked))
			local woke = r:WaitFor("Cast your shield (Power Word: Shield) on yourself, then attack a mob. The test does the rest.",
				{ events = { "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_SPELLCAST_SUCCEEDED" }, filter = function(event, unit, _, spellID)
					if unit ~= "player" then return false end
					if event == "UNIT_ABSORB_AMOUNT_CHANGED" then return true end
					local id = Plain(spellID)
					local name = id and C_Spell.GetSpellName(id)
					return type(name) == "string" and not Secret(name) and ShieldName(name)
				end })
			r:Log("  woke by " .. tostring(woke))
			r:Sleep(0.6) -- (the icon picks the aura up a moment after)
			-- The shield's icon: one that lit up since, else one named like a shield.
			for _, entry in ipairs(Items()) do
				local id, name = SpellOf(entry.item)
				if Lit(entry.item) and not before[entry.item] then
					S.item, S.spellID, S.name = entry.item, id, name
					r:Log(("  lit up since the cast: %s spell %s %s"):format(entry.viewer, tostring(id), tostring(name)))
				end
			end
			if not S.item then
				for _, entry in ipairs(Items()) do
					local id, name = SpellOf(entry.item)
					if ShieldName(name) then S.item, S.spellID, S.name = entry.item, id, name end
				end
			end
			r:Log(("  the shield's tracked-buff icon: %s; your shield cast: %s %s"):format(tostring(S.name),
				tostring(S.castName), tostring(S.castID)))
			S.spellID = S.spellID or S.castID
			r:Log("  fight at the reads: " .. tostring(InCombatLockdown()))
			local okRead, amount = pcall(UnitGetTotalAbsorbs, "player")
			S.top = okRead and Plain(amount) and amount > 0 and amount or nil
			ReadAll(r, "calm")
			if not S.top then
				local number = DescriptionNumber(S.spellID)
				S.top = number
				r:Log("  starting size from the description: " .. tostring(number))
			end
			S.top = S.top or (Plain(UnitHealthMax("player")) or 100)
			local err
			S.curve, err = MakeCurve(S.top)
			r:Log(("  curve 0..%s: %s"):format(tostring(S.top), S.curve and "made" or ("failed " .. tostring(err))))
			Label(S.item)
			r:Log("  our number, calm: " .. (okRead and Paint(amount) or "read error"))
			if not S.item then
				r:Shot("calm: our number on a stand-in square (no shield icon tracked)", { behind = S.holder })
				r:Skip("no shield icon in Tracked Buffs: the number and color are tried on a stand-in square")
				return
			end
			local cooldown = S.item.GetCooldownFrame and S.item:GetCooldownFrame()
			S.cooldown = cooldown
			local okWas, was = pcall(function() return cooldown:GetHideCountdownNumbers() end)
			S.timerWasHidden = okWas and was == true
			r:Log("  the game's timer hidden before: " .. ns.TestKit.Shown(was))
			r:Keep("timerWasHidden", S.timerWasHidden)
			local okHide, hideErr = pcall(function() cooldown:SetHideCountdownNumbers(true) end)
			r:Verdict(okHide, "the game's timer hidden: " .. tostring(hideErr or "ok"))
			r:Shot("calm: our number on the shield icon, timer hidden", { behind = S.item })
		end },
		{ key = "fight", title = "the shield in a fight", run = function(r)
			if not InCombatLockdown() then
				r:WaitFor("Now attack a mob with your shield up.", { events = { "PLAYER_REGEN_DISABLED" } })
			end
			r:Sleep(0.3)
			ReadAll(r, "fight start")
			local firstHit = S.events.fight or 0
			local woke = r:WaitFor(nil, { check = function()
				if (S.events.fight or 0) > firstHit then return "absorb changed" end
				if not InCombatLockdown() then return "fight over" end
			end })
			if woke == "absorb changed" then
				r:Sleep(0.2)
				r:Shot("fight: the shield took a hit, our number after it", { behind = S.item or S.holder })
				ReadAll(r, "fight hit")
			end
			-- Till the shield breaks (its icon goes off) or the fight ends.
			local ended = r:WaitFor(nil, { check = function()
				if S.item and not Lit(S.item) then return "shield gone" end
				if not InCombatLockdown() then return "fight over" end
			end })
			r:Log("  waited till: " .. tostring(ended))
			if ended == "shield gone" then
				r:Shot("fight: the shield gone (icon off)", { behind = S.item })
				ReadAll(r, "fight broken")
			end
			for _, line in ipairs(S.lines) do r:Log("  change " .. line) end
			r:Log(("  absorb changes: calm %d (secret %d), fight %d (secret %d)"):format(S.events.calm or 0,
				S.secret.calm or 0, S.events.fight or 0, S.secret.fight or 0))
			r:Verdict((S.events.fight or 0) > 0, "UNIT_ABSORB_AMOUNT_CHANGED fired in the fight")
			-- The two open facts, from every change in the fight (Paint's results).
			local set, colored, refused = 0, 0, 0
			for _, line in ipairs(S.lines) do
				if line:find(" fight:", 1, true) then
					if line:find("text set", 1, true) then set = set + 1 end
					if line:find("curve ok", 1, true) then colored = colored + 1 end
					if line:find("curve error", 1, true) then refused = refused + 1 end
				end
			end
			r:Verdict(set > 0, ("SetText took the secret absorb in the fight: %d of %d changes (the shot shows if it drew)"):format(
				set, S.events.fight or 0))
			r:Log(("  curve color on the secret absorb in the fight: %d took it, %d refused"):format(colored, refused))
			if colored + refused == 0 then r:Skip("no curve tried in the fight") end
		end },
		{ key = "after", title = "after the fight", run = function(r)
			if InCombatLockdown() then
				r:WaitFor(nil, { events = { "PLAYER_REGEN_ENABLED" } })
			end
			r:Sleep(1)
			ReadAll(r, "after")
			if S.cooldown then
				local ok, err = pcall(function() S.cooldown:SetHideCountdownNumbers(S.timerWasHidden) end)
				r:Verdict(ok, "the game's timer put back: " .. tostring(err or "ok"))
			end
			if S.label then S.label:Hide() end
			watcher:UnregisterAllEvents()
		end },
	},
	putBack = function(extra)
		watcher:UnregisterAllEvents()
		if S and S.cooldown then
			pcall(function() S.cooldown:SetHideCountdownNumbers(extra.timerWasHidden == true) end)
		end
		if S and S.holder then S.holder:Hide() end
		return "timer shown, our number hidden"
	end,
})
