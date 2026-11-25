-- The game's own nameplate for the previews (Nameplate Style's Look panels,
-- Combat Text Style, the Style hub's General screen): our copy of the game's
-- NamePlateUnitFrameTemplate, laid out the way the game lays out a plate,
-- with a sample unit's values and the states the game draws (your target,
-- casting, a marker...) put on it with the game's own calls. It sits in a
-- frame that stands in for a nameplate, so the code that dresses real plates
-- (PlateHealthStyle, PlateCastStyle, the row names in PlateRowLook) dresses
-- it the same way: the preview can't drift from your plates.
-- How it's built: rule forever.plate.template-copy-laid-out, read in the
-- game's own Blizzard_NamePlates (Forever's Camelot files) and proven by
-- /cine debug platematch (ledger Tools/tests/plate-preview-match.md).
-- Forever only for now: retail keeps the drawn preview until it's proven there.

local _, ns = ...
ns.Module("style", function() -- (the rest of this file: only with Style loaded, Modules.lua)

-- The sample units: { reaction, bar color as the game colors one (selection
-- colors; you: your class), level from yours, name color (nil: the game's white) }.
local REACTION_COLORS = { hostile = { 1, 0, 0 }, neutral = { 1, 1, 0 }, friendly = { 0, 1, 0 } }
local LEVEL_FROM_YOURS = { hostile = 2, neutral = 0, friendly = 5 }

-- The states, in the order they're put on (and taken off).
ns.GAME_PLATE_HEALTH = 2400 -- (the sample's health total)
ns.GAME_PLATE_STATES = { "target", "focus", "casting", "locked", "channel", "interrupted", "important", "atyou", "marker",
	"elite", "rare", "rareelite", "boss", "aggro", "gaining", "tapped", "debuffs", "buffs", "crowd", "quest" }

local function Quiet(frame, keep)
	if type(frame) ~= "table" or type(frame.UnregisterAllEvents) ~= "function" then return end
	pcall(frame.UnregisterAllEvents, frame)
	pcall(frame.SetScript, frame, "OnEvent", nil)
	if frame ~= keep then pcall(frame.SetScript, frame, "OnUpdate", nil) end
	local ok, kids = pcall(function() return { frame:GetChildren() } end)
	if ok then for _, kid in ipairs(kids) do Quiet(kid, keep) end end
end

local function Bit(which)
	local registry, constants, display = _G.CVarCallbackRegistry, _G.NamePlateConstants, Enum and Enum.NamePlateCastBarDisplay
	if not (registry and constants and display) then return true end
	return registry:GetCVarBitfieldIndex(constants.CAST_BAR_DISPLAY_CVAR, display[which]) and true or false
end

local function EmptyAuras()
	local util = _G.TableUtil
	return util.CreatePriorityTable(AuraUtil.DefaultAuraCompare, util.Constants.AssociativePriorityTable)
end

-- The copy, laid out (nil when the template or its layout fails).
local function Build(parent)
	local copy = CreateFrame("Button", nil, parent, "NamePlateUnitFrameTemplate")
	local castBar = copy.CastBarsContainer.castBar
	-- (Its OnLoad's events off at once: left on, they ran with no unit and
	-- erred on every target change. The cast bar keeps its OnUpdate: it plays
	-- a pretend cast.)
	Quiet(copy, castBar)
	copy:SetAllPoints(parent)
	-- (Its plate frame: ApplyFrameOptions hands it the click area. The game's
	-- own script plates use NamePlateScriptBaseMixin, whose calls do nothing.)
	local stand = {}
	for key, fn in pairs(_G.NamePlateScriptBaseMixin or {}) do stand[key] = fn end
	stand.ClearAllHitTestPoints = stand.ClearAllHitTestPoints or function() end
	stand.SetHitTestPoints = stand.SetHitTestPoints or function() end
	copy:SetNamePlateFrame(stand)
	copy:ApplyFrameOptions(_G.NamePlateSetupOptions, _G.NamePlateEnemyFrameOptions)
	-- (What OnUnitSet does that needs no unit; the whole calls end on a unit read.)
	castBar:SetNameTextShown(Bit("SpellName"))
	castBar:SetIconShown(Bit("SpellIcon"))
	castBar:SetTargetNameTextShown(Bit("SpellTarget"))
	castBar:SetHighlightImportantCasts(Bit("HighlightImportantCasts"))
	-- (Its setter reads the unit (PlayerIsSpellTarget): the flag the game keeps,
	-- set as the setter would. Without it, "Casting at you" never glowed: run 11.)
	castBar.highlightWhenCastTarget = Bit("HighlightWhenCastTarget")
	castBar.showShield = true -- (only its SetUnit sets it)
	local scale = copy:GetScaleData()
	for _, piece in ipairs({ copy.aggroHighlightBase, copy.aggroHighlightAdditive, copy.aggroHighlightMask }) do
		piece:SetScale(scale.aggroHighlight)
	end
	local auras = copy.AurasFrame
	-- (The loss of control slot hidden first: its refresh asks the game about
	-- the plate's unit, and there is none: confirm run 5's error.)
	if auras.LossOfControlFrame then auras.LossOfControlFrame:Hide() end
	auras.scaleFromSize = scale.aura
	auras.explicitAuraList = EmptyAuras()
	auras:UpdateAuraScale()
	auras.unitToken = "player" -- (its lists show only with a unit; no events: SetUnit isn't called)
	copy.ClassificationFrame:SetOptions(copy.optionTable)
	copy.ClassificationFrame.unitToken = "player"
	copy.RaidTargetFrame:UpdateShownState()
	copy.SoftTargetFrame.Icon:Hide()
	-- (The heal and absorb glows: the template has them shown; on a real plate
	-- the game shows them only for a unit with a shield or heals coming
	-- (CompactUnitFrame_UpdateHealPrediction). Up, a cyan tick sat at the bar's
	-- end and a red one at its start, confirm run 7.)
	for _, key in ipairs({ "myHealPrediction", "otherHealPrediction", "totalAbsorb", "totalAbsorbOverlay", "myHealAbsorb",
		"myHealAbsorbLeftShadow", "myHealAbsorbRightShadow", "overAbsorbGlow", "overHealAbsorbGlow" }) do
		local piece = copy.HealthBarsContainer.healthBar[key]
		if piece and piece.Hide then piece:Hide() end
	end
	copy:UpdateBehindCamera()
	local bar = copy.HealthBarsContainer.healthBar
	-- (A real-looking total: the game's own health text (percent, value or both,
	-- as your settings say) reads the bar.)
	bar:SetMinMaxValues(0, ns.GAME_PLATE_HEALTH)
	bar:SetValue(ns.GAME_PLATE_HEALTH * 0.72)
	bar:Show()
	copy.name:Show()
	-- (Laid out: the game anchored the health bar. Not its width: inside a
	-- preview not yet placed, every width reads 0 (confirm run, 2026-11-23,
	-- the drawn plate stood in on every page).)
	local okN, points = pcall(copy.HealthBarsContainer.GetNumPoints, copy.HealthBarsContainer)
	if not (okN and type(points) == "number" and points > 0) then return nil, "the health bar wasn't anchored" end
	return copy
end

-- A pretend cast with the game's own SimulateCast: kind "standard",
-- "uninterruptable", "channel" (drains, as a real channel) or "interrupted"
-- (cast, then the bar's own interrupt: "Interrupted" and its animation);
-- important / atYou: the cast's flags, the game shows their glows as your
-- cast bar settings say. (2026-11-23: the batch the user asked for.)
local function Cast(copy, kind, important, atYou)
	local castBar = copy.CastBarsContainer.castBar
	local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(133) or 135812
	local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(133) or "Fireball"
	castBar:SimulateCast({ barType = kind == "interrupted" and "standard" or kind, iconTexture = icon, spellName = name,
		targetName = atYou and UnitName("player") or nil, castTime = 3, isImportantSpell = important and true or false,
		isSpellTarget = atYou and true or false })
	castBar:UpdateIconShown() -- (SimulateCast leaves the icon and shield as they were)
	if kind == "channel" then
		-- (Draining from full, as the bar's own OnUpdate runs a channel.)
		castBar.casting, castBar.channeling = nil, true
		castBar.value = castBar.maxValue
		castBar:SetValue(castBar.maxValue)
	end
end
local function Interrupt(copy)
	local castBar = copy.CastBarsContainer.castBar
	if castBar.HandleInterruptOrSpellFailed then
		pcall(castBar.HandleInterruptOrSpellFailed, castBar, true, "UNIT_SPELLCAST_INTERRUPTED", nil, nil)
	end
end
-- The cast the states ask for: its kind and flags, as one key (cast again when it changes).
local function CastWanted(states)
	if not (states.casting or states.locked or states.channel or states.interrupted or states.important or states.atyou) then
		return nil
	end
	local kind = states.locked and "uninterruptable" or states.channel and "channel" or states.interrupted and "interrupted"
		or "standard"
	return kind, states.important, states.atyou
end

-- The game's own setup options complete (NamePlateDriverFrame fills them as
-- the game starts: a preview built at login before that had the level box's
-- size missing, confirm run 5).
local NEEDED = { "healthBarHeight", "castBarHeight", "insetWidth", "castBarFontHeight", "healthBarFontHeight",
	"playerLevelDiffWidth", "playerLevelDiffHeight", "levelFontHeight", "castBarToHealthBarSpacing" }
local function OptionsReady()
	local setup = _G.NamePlateSetupOptions
	if type(setup) ~= "table" then return false end
	for _, key in ipairs(NEEDED) do
		if setup[key] == nil then return false end
	end
	return true
end

-- A frame standing in for a nameplate, for the game's plate (nil on retail:
-- the caller keeps its drawn plate there). The plate itself is built the
-- first time it's wanted with the game's options complete: ns.GamePlateReady.
function ns.MakeGamePlate(parent)
	if ns.isRetail then return nil end
	local plate = CreateFrame("Frame", nil, parent)
	local okSize, w, h = pcall(C_NamePlate.GetNamePlateSize)
	if not (okSize and type(w) == "number" and w > 1) then w, h = 237.5, 85 end
	plate:SetSize(w, h)
	plate:Hide()
	plate.gamePlate = true
	plate.states = {}
	-- (A cast played again and again while casting is on.)
	ns.HookOnUpdate(plate, function(self)
		local states, copy = self.states, self.gameCopy
		local kind, important, atYou = CastWanted(states)
		if copy and kind then
			local castBar = copy.CastBarsContainer.castBar
			local now = GetTime()
			if kind == "interrupted" then
				-- (Cast, then cut off 1.2 s in, again every 3.5 s.)
				if not self.castStarted or now - self.castStarted >= 3.5 then
					Cast(copy, kind, important, atYou)
					self.castStarted, self.castCut = now, nil
					if ns.StylePlateCast then ns.StylePlateCast(self) end
				elseif not self.castCut and now - self.castStarted >= 1.2 then
					Interrupt(copy)
					self.castCut = true
				end
			elseif not (castBar.casting or castBar.channeling) then
				Cast(copy, kind, important, atYou)
				if ns.StylePlateCast then ns.StylePlateCast(self) end
			end
		end
		-- (Auras renewed before their times run out.)
		if copy and self.aurasRenewAt and ns.RenewGamePlateAuras then ns.RenewGamePlateAuras(self) end
	end)
	return plate
end

-- The game's plate in it, built now if it can be: true when it's there. false
-- while the game's options aren't complete, and for good once it failed (why:
-- in the log, once per reason): the caller shows its drawn plate.
function ns.GamePlateReady(plate)
	if not plate then return false end
	if plate.gameCopy then return true end
	if plate.failed or not OptionsReady() then return false end
	local ok, copy, why = pcall(Build, plate)
	if not (ok and copy) then
		plate.failed = true
		local reason = tostring(ok and why or copy)
		if not ns.gamePlateWhy then ns.gamePlateWhy = {} end
		if not ns.gamePlateWhy[reason] then
			ns.gamePlateWhy[reason] = true
			ns.Log("plates", "game plate copy not used: " .. reason)
		end
		return false
	end
	-- (gameCopy is ours; UnitFrame, as on a real plate, for the code that dresses plates.)
	plate.gameCopy, plate.UnitFrame = copy, copy
	return true
end

-- The sample unit: kind "hostile" / "neutral" / "friendly" / "player", its
-- name; color (optional): the bar's, over the game's; nameColor (optional).
function ns.SetGamePlateUnit(plate, kind, name, color, nameColor)
	local copy = plate and plate.gameCopy
	if not copy then return end
	local bar = copy.HealthBarsContainer.healthBar
	local mine = UnitEffectiveLevel and UnitEffectiveLevel("player") or UnitLevel("player") or 1
	local game, level, levelColor
	if kind == "player" then
		local class = select(2, UnitClass("player"))
		local classColor = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
		game = classColor and { classColor.r, classColor.g, classColor.b } or { 0, 1, 0 }
		nameColor = nameColor or game -- (friendly players' names in their class color: the game's setting)
		level = mine
	else
		game = REACTION_COLORS[kind] or REACTION_COLORS.hostile
		level = mine + (LEVEL_FROM_YOURS[kind] or 0)
	end
	color = color or game
	bar:SetStatusBarColor(color[1], color[2], color[3])
	copy.name:SetVertexColor(1, 1, 1)
	if nameColor then copy.name:SetVertexColor(nameColor[1], nameColor[2], nameColor[3]) end
	copy.name:SetText(name)
	-- (Its health text as your game settings show it: the game's own call.)
	if bar.UpdateTextDisplay then pcall(bar.UpdateTextDisplay, bar) end
	-- (The level as the game writes it: difficulty colors for what you can attack.)
	local box = copy.PlayerLevelDiffFrame
	if kind == "friendly" or kind == "player" then
		levelColor = _G.UNIT_LEVEL_NON_ATTACKABLE
	elseif box.GetDifficultyColor then
		levelColor = box:GetDifficultyColor(level - mine)
	end
	local text = levelColor and levelColor.WrapTextInColorCode and levelColor:WrapTextInColorCode(level) or tostring(level)
	box.playerLevelDiffText:SetText(text)
	box.playerLevelDiffText:Show()
	if box.highLevelTexture then box.highLevelTexture:Hide() end
	plate.kind = kind
end

-- The level box shown or not (a row's Look can hide it).
function ns.SetGamePlateLevel(plate, shown)
	local copy = plate and plate.gameCopy
	if not copy then return end
	copy.PlayerLevelDiffFrame:SetShown(shown and true or false)
	-- (The crowd control row sits right of the level box when it's shown, else
	-- right of the bar: the game places it in its layout, after the box is up.
	-- Laid out before the box showed, the row sat under it (user's screenshot,
	-- 2026-11-23). Its own call again; Forever's box hangs off TOPRIGHT, so no
	-- extra offset, as the game works it out.)
	if copy.UpdateControlAnchors then pcall(copy.UpdateControlAnchors, copy, 0) end
end

-- Your debuffs on it and a crowd control (a root), each with the time it has
-- left: the game counts down auras of a minute or less on their icons (its
-- NamePlateAuraItemMixin:SetAura). { spell, seconds left, of a duration }.
-- (2026-11-23: a real plate showed 31 and 5 on its debuffs and a root, 10, in
-- its own row right of the level box; the preview had no times and no row.)
local DEBUFFS = { { 172, 24, 30 }, { 980, 18, 24 }, { 348, 12, 21 }, { 702, 31, 60 }, { 1714, 5, 12 } }
local CROWD = { { 339, 10, 15 } }
-- The unit's own buffs (the Buffs state, 2026-11-25: the Layout tab places the
-- buff row, and nothing showed one): two, as the game's buff row holds
-- (maxAuraItemsDisplayed 2), cast by the unit, not you.
local BUFFS = { { 6673, 40, 120 }, { 1126, 25, 60 } }
local RENEW = 4 -- (the lowest time left above: renewed before it reaches it)
local function AuraList(spells, first, helpful)
	local list = EmptyAuras()
	local now = GetTime()
	for i, each in ipairs(spells) do
		local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(each[1]) or 136197
		list[first + i] = { auraInstanceID = first + i, spellId = each[1], sourceUnit = not helpful and "player" or nil,
			isHarmful = not helpful, isHelpful = helpful and true or nil,
			applications = (first == 0 and i == 1) and 3 or 1, icon = icon, duration = each[3],
			expirationTime = now + each[2] }
	end
	return list
end
local function Auras(plate, copy, debuffs, crowd, buffs)
	local auras = copy.AurasFrame
	-- (The game's shown check first: it shows the lists your aura settings
	-- want; the buff row only with the Buffs state, the loss of control slot
	-- never (NPCs never show it). Each list filled with its own: the game's
	-- explicit list would put the same auras in every row.)
	auras:UpdateShownState()
	if not buffs then auras.BuffListFrame:Hide() end
	if auras.LossOfControlFrame then auras.LossOfControlFrame:Hide() end
	auras.explicitAuraList = EmptyAuras()
	auras.auraItemFramePool:ReleaseAll()
	if debuffs then auras:RefreshList(auras.DebuffListFrame, AuraList(DEBUFFS, 0)) end
	if crowd then auras:RefreshList(auras.CrowdControlListFrame, AuraList(CROWD, 100)) end
	if buffs then auras:RefreshList(auras.BuffListFrame, AuraList(BUFFS, 200, true)) end
	plate.aurasRenewAt = (debuffs or crowd or buffs) and GetTime() + RENEW or nil
end
ns.RenewGamePlateAuras = function(plate)
	local copy = plate and plate.gameCopy
	if copy and plate.aurasRenewAt and GetTime() >= plate.aurasRenewAt then
		Auras(plate, copy, plate.states.debuffs, plate.states.crowd, plate.states.buffs)
	end
end

-- The states on: { target = true, casting = true, ... } (ns.GAME_PLATE_STATES).
function ns.SetGamePlateStates(plate, states)
	local copy = plate and plate.gameCopy
	if not copy then return end
	plate.states = states or {}
	states = plate.states
	local bar = copy.HealthBarsContainer.healthBar
	local box = copy.PlayerLevelDiffFrame
	local target, focus = states.target and true or false, (states.focus and not states.target) and true or false
	bar:SetIsTarget(target)
	bar:SetIsFocus(focus)
	if box.SetIsTarget then box:SetIsTarget(target) end
	if box.SetIsFocus then box:SetIsFocus(focus) end
	local castBar = copy.CastBarsContainer.castBar
	local kind, important, atYou = CastWanted(states)
	local castKey = kind and (kind .. tostring(important) .. tostring(atYou)) or nil
	if kind then
		if plate.castKey ~= castKey or not (castBar.casting or castBar.channeling or kind == "interrupted") then
			plate.castStarted = nil -- (an interrupted one starts over at once)
			if kind ~= "interrupted" then Cast(copy, kind, important, atYou) end
		end
	elseif castBar.casting or castBar.channeling or castBar:IsShown() then
		castBar.casting, castBar.channeling = nil, nil
		castBar:UpdateShownState(false)
	end
	plate.castKey = castKey
	local marker = states.marker and 8 or nil
	copy.RaidTargetFrame:SetRaidTargetIndex(marker)
	copy.ClassificationFrame:SetRaidTargetIndex(marker) -- (the game hides the elite icon under a marker)
	-- (Its rank: elite, rare, rare elite or a boss; the game draws its mark as
	-- your Rarity icon setting says. A boss: the skull in the level box too.)
	local rank = states.boss and "worldboss" or states.rareelite and "rareelite" or states.rare and "rare"
		or states.elite and "elite" or nil
	copy.ClassificationFrame:SetExplicitValues({ classification = rank })
	local levelBox = copy.PlayerLevelDiffFrame
	if levelBox.highLevelTexture then levelBox.highLevelTexture:SetShown(rank == "worldboss") end
	levelBox.playerLevelDiffText:SetShown(rank ~= "worldboss")
	-- (Threat, as your threat setting shows it: the glow building, the flash,
	-- or the bar in the threat color. Gaining: about to pull; aggro: on you.
	-- The game's own explicit values, as its Settings preview uses; its
	-- update ends on a unit read, so the bar's color is set here.)
	local registry, constants = _G.CVarCallbackRegistry, _G.NamePlateConstants
	local threatDisplay = Enum and Enum.NamePlateThreatDisplay
	local function ThreatBit(which)
		return registry and constants and threatDisplay
			and registry:GetCVarBitfieldIndex(constants.THREAT_DISPLAY_CVAR, threatDisplay[which]) or false
	end
	local enemy = plate.kind ~= "friendly" and plate.kind ~= "player" -- (the game shows threat on enemies only)
	local threat = enemy and (states.aggro and 3 or states.gaining and 1) or nil
	copy.explicitThreatSituation, copy.explicitAggroFlash = threat, threat == 3 or nil
	-- (Its UpdateThreatDisplay's pieces one by one: the flash's own check reads
	-- the unit when nothing's explicit, and the bar's color always does.)
	copy.displayAggroFlash = enemy and ThreatBit("Flash")
	copy.displayAggroHighlight = enemy and ThreatBit("Progressive")
	copy.displayThreatHealthBarColor = enemy and ThreatBit("HealthBarColor")
	if _G.CompactUnitFrame_UpdateAggroHighlight then pcall(_G.CompactUnitFrame_UpdateAggroHighlight, copy) end
	if threat == 3 and copy.displayAggroFlash and _G.CompactUnitFrame_UpdateAggroFlash then
		pcall(_G.CompactUnitFrame_UpdateAggroFlash, copy)
	elseif copy.aggroFlash then
		copy.aggroFlash:Hide()
	end
	local threatColor = threat and copy.displayThreatHealthBarColor
		and (threat == 3 and _G.HIGH_THREAT_COLOR or _G.GAINING_THREAT_COLOR) or nil
	if threatColor then
		bar:SetStatusBarColor(threatColor:GetRGB())
	elseif states.tapped then
		bar:SetStatusBarColor(0.9, 0.9, 0.9) -- (another's tap: the game's grey)
	end
	-- (The interact / quest icon over your soft target: Forever's quest "!",
	-- as your soft target icon settings show it.)
	local icon = copy.SoftTargetFrame.Icon
	local iconSize = registry and constants and registry:GetCVarNumberOrDefault(constants.SOFT_TARGET_NAMEPLATE_SIZE_CVAR) or 0
	local friendIcon = registry and constants and registry:GetCVarValueBool(constants.SOFT_TARGET_ICON_FRIEND_CVAR)
	if states.quest and iconSize and iconSize > 0 and friendIcon then
		local atlas = "Cursor Crosshair_Quest_64" -- (what SetUnitCursorTexture gives a quest giver: rule forever.plate.quest-cursor)
		if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
			icon:SetAtlas(atlas)
		else
			icon:SetTexture("Interface\\Cursor\\Crosshair\\Quest")
		end
		icon:Show()
	else
		icon:Hide()
	end
	-- (Off at once: the game fades it out over a while, and the next pick's
	-- preview still glowed red, confirm run 7.)
	if not threat then
		for _, anim in ipairs({ copy.AggroHighlightFadeOutAnim, copy.AggroHighlightScrollAnim }) do
			if anim and anim.Stop then anim:Stop() end
		end
		for _, piece in ipairs({ copy.aggroHighlightBase, copy.aggroHighlightAdditive, copy.aggroHighlightMask }) do
			if piece then piece:Hide() end
		end
	end
	Auras(plate, copy, states.debuffs, states.crowd, states.buffs)
	if ns.StylePlateCast then ns.StylePlateCast(plate) end
end

-- What a preview says the game's plate is doing (/cine debug and the tests).
function ns.GamePlateReport(plate)
	local copy = plate and plate.gameCopy
	if not copy then return "no game plate" end
	local on = {}
	for _, state in ipairs(ns.GAME_PLATE_STATES) do if plate.states[state] then on[#on + 1] = state end end
	local w, h = copy.HealthBarsContainer:GetSize()
	return ("game plate %s, bar %.1f x %.1f, states: %s"):format(tostring(plate.kind), w or 0, h or 0,
		#on > 0 and table.concat(on, ", ") or "none")
end
end) -- (ns.Module "style")
