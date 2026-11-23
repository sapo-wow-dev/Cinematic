-- The game's nameplate template on the stand-in (offline helper, Lua 5.1):
-- dofile it with a note function; it gives Parts(copy) (the template's parts,
-- recording the game's calls into note) and Install(), which makes
-- CreateFrame give NamePlateUnitFrameTemplate those parts and sets the game's
-- globals Plates/PlateCopy.lua reads (NamePlateSetupOptions...). Used by
-- Tools/offline/gameplate.lua and Tools/offline/platematch.lua.
--   local parts = dofile("Tools/offline/gameplate_parts.lua")(function(text) ... end)
-- luacheck: ignore 111 112 113 121 122 212 431
return function(Note)
	local M = { works = true }
	function M.Parts(copy)
		local function Sub(kind, parent) return CreateFrame(kind, nil, parent) end
		copy.HealthBarsContainer = Sub("Frame", copy)
		local bar = Sub("StatusBar", copy.HealthBarsContainer)
		copy.HealthBarsContainer.healthBar = bar
		bar.bgTexture, bar.deselectedOverlay, bar.selectedBorder = bar:CreateTexture(), bar:CreateTexture(), bar:CreateTexture()
		bar.selectedBorder:Hide()
		-- (Its fill: a texture whose atlas or file is what was set last, as the game's.)
		local fill = bar:CreateTexture()
		fill.GetAtlas = function(self) return self._atlas end
		fill.GetTexture = function(self) return self._file or self._atlas end
		bar.GetStatusBarTexture = function() return fill end
		bar.SetStatusBarTexture = function(_, texture)
			if type(texture) == "string" and not texture:find("\\", 1, true) then fill._atlas, fill._file = texture, nil
			else fill._atlas, fill._file = nil, texture end
		end
		bar.SetIsTarget = function(self, on) Note("target " .. tostring(on)); self.isTarget = on
			self.selectedBorder:SetShown(on or self.isFocus); self.deselectedOverlay:SetShown(not (on or self.isFocus)) end
		bar.SetIsFocus = function(self, on) Note("focus " .. tostring(on)); self.isFocus = on
			self.selectedBorder:SetShown(on or self.isTarget) end
		copy.name = copy:CreateFontString(nil, "OVERLAY")
		copy.CastBarsContainer = Sub("Frame", copy)
		local cast = Sub("StatusBar", copy.CastBarsContainer)
		copy.CastBarsContainer.castBar = cast
		cast.Icon, cast.BorderShield = cast:CreateTexture(), cast:CreateTexture()
		cast.Text = cast:CreateFontString()
		cast.ImportantCastIndicator, cast.CastTargetIndicator = cast:CreateTexture(), cast:CreateTexture()
		cast:Hide()
		cast.SimulateCast = function(self, data)
			Note("cast " .. data.barType .. (data.isImportantSpell and " important" or "") .. (data.isSpellTarget and " atyou" or "")
				.. (data.targetName and (" on " .. data.targetName) or ""))
			self.casting, self.maxValue = true, data.castTime
			self:Show()
			self.locked = data.barType == "uninterruptable"
			self.Text:SetText(data.spellName)
			self.ImportantCastIndicator:SetShown(data.isImportantSpell and true or false)
			self.CastTargetIndicator:SetShown(data.isSpellTarget and true or false)
		end
		-- (The bar's own interrupt: "Interrupted", the cast over.)
		cast.HandleInterruptOrSpellFailed = function(self, _, event)
			Note("interrupted " .. tostring(event))
			self.casting = nil
			self.Text:SetText(_G.INTERRUPTED)
		end
		cast.UpdateIconShown = function(self) self.Icon:SetShown(not self.locked); self.BorderShield:SetShown(self.locked) end
		cast.UpdateShownState = function(self, on) self:SetShown(on) end
		copy.RaidTargetFrame = Sub("Frame", copy)
		copy.RaidTargetFrame.SetRaidTargetIndex = function(self, i) Note("marker " .. tostring(i)); self:SetShown(i ~= nil) end
		copy.RaidTargetFrame.UpdateShownState = function(self) self:Hide() end
		copy.ClassificationFrame = Sub("Frame", copy)
		copy.ClassificationFrame:Hide()
		copy.ClassificationFrame.SetExplicitValues = function(self, v) Note("class " .. tostring(v.classification))
			self:SetShown(v.classification ~= nil and not self.marked) end
		copy.ClassificationFrame.SetRaidTargetIndex = function(self, i) self.marked = i ~= nil end
		copy.aggroHighlight, copy.aggroHighlightBase = copy:CreateTexture(), copy:CreateTexture()
		copy.aggroFlash = copy:CreateTexture()
		copy.aggroFlash:Hide()
		copy.aggroHighlightAdditive, copy.aggroHighlightMask = copy:CreateTexture(), copy:CreateTexture()
		-- (The heal and absorb glows, shown as the template has them.)
		for _, key in ipairs({ "myHealPrediction", "otherHealPrediction", "totalAbsorb", "totalAbsorbOverlay", "myHealAbsorb",
			"myHealAbsorbLeftShadow", "myHealAbsorbRightShadow", "overAbsorbGlow", "overHealAbsorbGlow" }) do
			bar[key] = bar:CreateTexture()
		end
		copy.aggroHighlightBase:Hide()
		copy.UpdateAggroHighlight = function(self) Note("aggro " .. tostring(self.aggroHighlight:IsShown()))
			self.aggroHighlightBase:SetShown(self.aggroHighlight:IsShown()) end
		copy.AurasFrame = Sub("Frame", copy)
		copy.AurasFrame.DebuffListFrame = Sub("Frame", copy.AurasFrame)
		copy.AurasFrame.BuffListFrame, copy.AurasFrame.CrowdControlListFrame = Sub("Frame", copy.AurasFrame),
			Sub("Frame", copy.AurasFrame)
		copy.AurasFrame.RefreshExplicitAuras = function(self) Note("auras " .. #(self.explicitAuraList or {})) end
		-- (Each list filled on its own, as the game's RefreshList; each aura's time left noted.)
		copy.AurasFrame.auraItemFramePool = { ReleaseAll = function() Note("auras released") end }
		copy.AurasFrame.RefreshList = function(self, listFrame, auraList)
			local which = listFrame == self.DebuffListFrame and "debuffs" or listFrame == self.CrowdControlListFrame and "crowd"
				or "other"
			local count, timed = 0, 0
			for _, aura in pairs(auraList) do
				if type(aura) == "table" then
					count = count + 1
					if aura.duration > 0 and aura.expirationTime > GetTime() then timed = timed + 1 end
				end
			end
			Note(("list %s %d, %d timed"):format(which, count, timed))
			-- (An icon per aura in the list, its cooldown set from its times, as SetAura does.)
			for _, aura in pairs(auraList) do
				if type(aura) == "table" then
					local item = Sub("Frame", listFrame)
					item.Cooldown = Sub("Cooldown", item)
					local start, duration = aura.expirationTime - aura.duration, aura.duration
					item.Cooldown.GetCooldownTimes = function() return start * 1000, duration * 1000 end
				end
			end
		end
		-- (Its loss of control slot asks the game about the unit when shown: with none, the game errs, run 5.)
		copy.AurasFrame.LossOfControlFrame = Sub("Frame", copy.AurasFrame)
		copy.AurasFrame.UpdateAuraScale = function(self)
			if self.LossOfControlFrame:IsShown() and not self.unitToken then
				error("bad argument #1 to '?' (Usage: local event = C_LossOfControl.GetActiveLossOfControlDataByUnit(unitToken, index))")
			end
		end
		copy.SoftTargetFrame = Sub("Frame", copy)
		copy.SoftTargetFrame.Icon = copy.SoftTargetFrame:CreateTexture()
		copy.behindCameraIcon = copy:CreateTexture()
		copy.UpdateBehindCamera = function(self) self.behindCameraIcon:Hide() end
		local level = Sub("Frame", copy)
		copy.PlayerLevelDiffFrame = level
		level.playerLevelDiffText = level:CreateFontString()
		level.highLevelTexture = level:CreateTexture()
		level.highLevelTexture:Hide()
		level.GetDifficultyColor = function() return { WrapTextInColorCode = function(_, t) return "|cff00ff00" .. t .. "|r" end } end
		-- (The game's layout anchors the health bar (UpdateAnchors); M.anchors = false: a layout that doesn't.)
		copy.HealthBarsContainer.GetNumPoints = function(self) return self.anchored and 2 or 0 end
		copy.ApplyFrameOptions = function(self, setup) Note("layout " .. tostring(setup == _G.NamePlateSetupOptions))
			self.optionTable = {}
			self.HealthBarsContainer.anchored = M.anchors ~= false end
		-- (As in game inside a preview not yet placed: widths read 0, confirm run 2026-11-23.)
		bar.GetWidth = function() return 0 end
		-- (Its health text, the game's: as your settings say.)
		bar.UpdateTextDisplay = function() Note("health text") end
		bar.SetStatusBarColor = function(self, r, g, b) self._color = { r, g, b } end
		bar.GetStatusBarColor = function(self) local c = self._color or { 1, 1, 1 } return c[1], c[2], c[3], 1 end
		copy.GetScaleData = function() return { aggroHighlight = 1, aura = 1 } end
		-- (The crowd control row placed by the level box, as the game's UpdateControlAnchors.)
		copy.UpdateControlAnchors = function(self) Note("control anchors, level box " .. tostring(self.PlayerLevelDiffFrame:IsShown())) end
		-- (The sizes the game lays them out at, run 3: the stand-in's frames all read 100 x 20.)
		local function Size(region, w, h) region.GetSize = function() return w, h end end
		Size(copy.HealthBarsContainer, 207.5, 15.83)
		Size(bar, 207.5, 15.83)
		Size(bar.bgTexture, 215, 25)
		Size(bar.deselectedOverlay, 207.5, 17.5)
		Size(bar.selectedBorder, 218.33, 25)
		Size(copy.CastBarsContainer, 207.5, 20)
	end
	function M.Install()
		_G.NamePlateSetupOptions = { healthBarHeight = 16.25, castBarHeight = 7.5, insetWidth = 15, castBarFontHeight = 12.5,
			healthBarFontHeight = 17.5, playerLevelDiffWidth = 35, playerLevelDiffHeight = 20.83, levelFontHeight = 12.5,
			castBarToHealthBarSpacing = 2.5 }
		_G.NamePlateEnemyFrameOptions = {}
		_G.NamePlateScriptBaseMixin = { SetHitTestPoints = function() end, ClearAllHitTestPoints = function() end }
		_G.TableUtil = { CreatePriorityTable = function() return {} end, Constants = {} }
		_G.AuraUtil = { DefaultAuraCompare = function() end }
		C_NamePlate = C_NamePlate or {}
		C_NamePlate.GetNamePlateSize = function() return 237.5, 85 end
		-- (Every option bit on: the game's threat looks, cast glows, the soft target icon.)
		_G.CVarCallbackRegistry = { GetCVarBitfieldIndex = function() return true end,
			GetCVarNumberOrDefault = function() return 1 end, GetCVarValueBool = function() return true end }
		_G.NamePlateConstants = { THREAT_DISPLAY_CVAR = "nameplateThreatDisplay", CAST_BAR_DISPLAY_CVAR = "nameplateCastBarDisplay",
			SOFT_TARGET_NAMEPLATE_SIZE_CVAR = "SoftTargetNameplateSize", SOFT_TARGET_ICON_FRIEND_CVAR = "SoftTargetIconFriend" }
		Enum = Enum or {}
		Enum.NamePlateThreatDisplay = { Progressive = 1, Flash = 2, HealthBarColor = 3 }
		Enum.NamePlateCastBarDisplay = { SpellName = 1, SpellIcon = 2, SpellTarget = 3, HighlightImportantCasts = 4,
			HighlightWhenCastTarget = 5 }
		local function Color(r, g, b) return { GetRGB = function() return r, g, b end } end
		_G.HIGH_THREAT_COLOR, _G.GAINING_THREAT_COLOR = Color(1, 0, 0), Color(1, 0.6, 0)
		_G.INTERRUPTED = "Interrupted"
		-- (The game's threat pieces, as CompactUnitFrame has them: explicit values win.)
		_G.CompactUnitFrame_UpdateAggroHighlight = function(frame)
			frame.aggroHighlight:SetShown(frame.displayAggroHighlight and frame.explicitThreatSituation ~= nil or false)
			if frame.UpdateAggroHighlight then frame:UpdateAggroHighlight() end
		end
		_G.CompactUnitFrame_UpdateAggroFlash = function(frame) frame.aggroFlash:SetShown(frame.explicitAggroFlash and true or false) end
		local real = CreateFrame
		CreateFrame = function(kind, name, parent, template)
			local frame = real(kind, name, parent, template)
			if template == "NamePlateUnitFrameTemplate" and M.works then M.Parts(frame) end
			return frame
		end
	end
	return M
end
