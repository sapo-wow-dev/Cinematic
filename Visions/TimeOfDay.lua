-- The time of day (Card Vision): its title under the zone name at login, and
-- the Last time line under it (Recap.lua); its card as it changes in play;
-- the Under attack card. Out of Atmosphere/Tint.lua (2026-11-22): Visions,
-- left out with them (Modules.lua), and loaded with Atmosphere left out. The
-- clock comes from the tint's (its Local time or game time, a previewed hour):
-- ns.TintParts, loaded either way.
local _, ns = ...
ns.Module("visions", function() -- (the rest of this file: only with Visions loaded, Modules.lua)
local L = ns.L
local T = ns.TintParts
local GetClockTime = T.GetClockTime

-- (The hour shown: a previewed one, else the clock.)
local function TimeOfDayColor()
	return nil, nil, T.Hour()
end

-- The Cards page's font (its Time of day's: the Default style's unless it
-- has its own) for text at size pixels (flags: its outline), every
-- alphabet's letters drawn, with its outline and shadow; false if it's all
-- the game's, left for the caller to set.
local function StoryFont(text, object, size, flags)
	local look = ns.CardLook and ns.CardLook("time")
	local file = look and ns.StyleFontFile and ns.StyleFontFile(look.combatFont)
	local outline = look and tonumber(look.combatOutline) or -1
	local shadow = look and look.combatShadow
	-- (An outline in a color: copies behind the text, ns.SetTextRim.)
	local or_, og, ob = look and look.combatOutlineR or 0, look and look.combatOutlineG or 0, look and look.combatOutlineB or 0
	local rimmed = outline > 0 and or_ + og + ob > 0
	if not file and (outline >= 0 or (shadow and shadow ~= "game")) and object then
		file = object:GetFont() -- (the game's font, outlined or shadowed)
	end
	if not (file and size and ns.SetPlateNameFont) then
		text.cineShadow = nil -- (the caller's font object brings its own back)
		if ns.SetTextRim then ns.SetTextRim(text, 0) end
		return false
	end
	if text.SetTextScale then text:SetTextScale(1) end
	if rimmed then
		flags = ""
	elseif outline >= 0 and ns.OutlinedFlags then
		flags = ns.OutlinedFlags(flags or "", outline)
	end
	ns.SetPlateNameFont(text, object, file, size, 1, flags or "")
	if ns.SetTextRim then ns.SetTextRim(text, rimmed and outline or 0, or_, og, ob) end
	if ns.SetTextShadow then ns.SetTextShadow(text, shadow) end
	return true
end

-- Time-of-day title: a line such as "Dusk" under the game's own zone name
-- when you log in or reload. It's a child of the zone text frame, so it fades
-- in and out with it, and is cleared once the zone text hides. Under it on a
-- real login, smaller and dimmer, the Cards page's Last time line (Recap.lua),
-- in the title's place if the title is off.
local TIME_TITLES = {
	{ 5, "Dawn" }, { 8, "Morning" }, { 12, "Midday" }, { 14, "Afternoon" },
	{ 17, "Evening" }, { 19, "Dusk" }, { 21, "Night" },
}
local timeTitle
local RECAP_SCALE = 0.5 -- the Last time line's size, of the subzone font's (the title's: 0.75)
-- Soft grey, dim: a footnote beside the zone's own colors. Dimmed by color,
-- not alpha, which would fade its black outline too.
local RECAP_COLOR = { 0.7, 0.67, 0.61 }
local RECAP_GAP = 6 -- under the title

local function TimeTitleAt(hour)
	local title = "Night" -- before dawn
	for _, entry in ipairs(TIME_TITLES) do
		if hour >= entry[1] then
			title = entry[2]
		end
	end
	return title
end

-- The zone title's lines, top to bottom: zone name, PvP status ("Alliance
-- Territory"), arena/sanctuary note, subzone. They don't all appear at once.
local ZONE_LINES = { "ZoneTextString", "PVPInfoTextString", "PVPArenaTextString", "SubZoneTextString" }

-- Below the lowest zone line on screen, centred, in the zone name's colour.
-- Run every frame while the zone title shows, as its lines arrive and recolour.
local function PlaceTimeTitle()
	local lowest, lowestScale
	for _, name in ipairs(ZONE_LINES) do
		local line = _G[name]
		if line and ns.Flag(line:IsVisible()) and (line:GetText() or "") ~= "" then
			local bottom = line:GetBottom()
			if bottom and (not lowest or bottom * line:GetEffectiveScale() < lowest * lowestScale) then
				lowest, lowestScale = bottom, line:GetEffectiveScale()
			end
		end
	end
	if not lowest then
		return
	end
	if not timeTitle.sized then
		local font, size, flags = (SubZoneTextString or ZoneTextString):GetFont()
		local object = _G.SubZoneTextFont or GameFontNormalLarge
		if size and StoryFont(timeTitle.text, object, math.floor(size * 0.75 + 0.5), flags) then
			StoryFont(timeTitle.recap, object, math.floor(size * RECAP_SCALE + 0.5), flags)
			timeTitle.sized = "the Cards page's font"
		elseif font and size and ns.SetPlateNameFont then
			-- The game's font at a real size, its outline full width (scaled
			-- text thins it). A family, so Russian letters aren't boxes. An
			-- outline is the same pixels at any size, so the half-size line
			-- takes the next thinner one to look as heavy as the zone name's.
			local thinner = (flags or ""):gsub("THICKOUTLINE", "OUTLINE")
			for line, scale in pairs({ [timeTitle.text] = 0.75, [timeTitle.recap] = RECAP_SCALE }) do
				if line.SetTextScale then line:SetTextScale(1) end
				ns.SetPlateNameFont(line, object, font, size, scale, line == timeTitle.recap and thinner or flags)
				line:SetShadowOffset(object:GetShadowOffset())
				line:SetShadowColor(object:GetShadowColor())
			end
			timeTitle.sized = "game font, own size"
		elseif timeTitle.text.SetTextScale then
			-- (Back to the game's font, if the Cards page's was on it.)
			timeTitle.text:SetFontObject(object)
			timeTitle.recap:SetFontObject(object)
			timeTitle.text:SetText(timeTitle.text:GetText())
			timeTitle.recap:SetText(timeTitle.recap:GetText())
			-- Scaled rather than set by file, which would keep only the Latin
			-- letters (a Russian title on an English client showed boxes).
			timeTitle.text:SetTextScale(0.75)
			timeTitle.recap:SetTextScale(RECAP_SCALE)
			timeTitle.sized = "game font, scaled"
		elseif font then
			timeTitle.text:SetFont(font, math.floor(size * 0.75 + 0.5), flags)
			timeTitle.recap:SetFont(font, math.floor(size * RECAP_SCALE + 0.5), flags)
			timeTitle.sized = "game font file"
		end
	end
	timeTitle.text:SetTextColor(ZoneTextString:GetTextColor())
	timeTitle.recap:SetTextColor(RECAP_COLOR[1], RECAP_COLOR[2], RECAP_COLOR[3]) -- (a new font can reset it)
	-- Centred on the screen, a little below the lowest line (converted to this
	-- text's own scale).
	local y = lowest * lowestScale / timeTitle.text:GetEffectiveScale() - 12
	if timeTitle.y ~= y then
		timeTitle.y = y
		timeTitle.text:ClearAllPoints()
		timeTitle.text:SetPoint("TOP", UIParent, "BOTTOM", 0, y)
	end
	-- The Last time line under the title, or in its place.
	local underTitle = (timeTitle.text:GetText() or "") ~= ""
	if timeTitle.recapUnder ~= underTitle or not underTitle and timeTitle.recapY ~= y then
		timeTitle.recapUnder, timeTitle.recapY = underTitle, y
		timeTitle.recap:ClearAllPoints()
		if underTitle then
			timeTitle.recap:SetPoint("TOP", timeTitle.text, "BOTTOM", 0, -RECAP_GAP)
		else
			timeTitle.recap:SetPoint("TOP", UIParent, "BOTTOM", 0, y)
		end
	end
end

-- For /cine recaptest: how the zone lines and ours are drawn (font, size,
-- outline, shadow, scale), to compare their look.
function ns.TimeTitleFontReport()
	local lines = { "  sized by: " .. tostring(timeTitle and timeTitle.sized) }
	local function Describe(label, text)
		if not text then
			lines[#lines + 1] = ("  %s: none"):format(label)
			return
		end
		local font, size, flags = text:GetFont()
		local sx, sy = text:GetShadowOffset()
		local _, _, _, sa = text:GetShadowColor()
		local object = text:GetFontObject()
		lines[#lines + 1] = ("  %s: %s %s [%s] shadow %s,%s a%s, scale %s, alpha %s, object %s"):format(label,
			tostring(font), tostring(size and math.floor(size * 10 + 0.5) / 10), tostring(flags), tostring(sx),
			tostring(sy), tostring(sa and math.floor(sa * 100 + 0.5) / 100),
			tostring(text.GetTextScale and text:GetTextScale()), tostring(text:GetAlpha()),
			tostring(object and object.GetName and object:GetName() or object))
	end
	Describe("zone", ZoneTextString)
	Describe("subzone", SubZoneTextString)
	Describe("time title", timeTitle and timeTitle.text)
	Describe("last time", timeTitle and timeTitle.recap)
	return lines
end

-- showTime: the time of day's name; recap: the Last time line, or nil.
function ns.ShowTimeOfDayTitle(showTime, recap)
	if not (ZoneTextFrame and ZoneTextString) then
		return
	end
	if not timeTitle then
		timeTitle = CreateFrame("Frame", nil, ZoneTextFrame)
		timeTitle:SetAllPoints(UIParent)
		timeTitle.text = timeTitle:CreateFontString(nil, "OVERLAY")
		-- A font before any text (SetText errors without one); PlaceTimeTitle
		-- then sizes it to match the zone text.
		timeTitle.text:SetFontObject(_G.SubZoneTextFont or GameFontNormalLarge)
		timeTitle.text:SetShadowOffset(1, -1)
		timeTitle.recap = timeTitle:CreateFontString(nil, "OVERLAY")
		timeTitle.recap:SetFontObject(_G.SubZoneTextFont or GameFontNormalLarge)
		timeTitle.recap:SetShadowOffset(1, -1)
		if ns.WhyRegister then
			ns.WhyRegister(timeTitle.text, L["Time of day"], "Card Vision", { L["The Card Vision page's time of day at login, under the zone's name"] })
		end
		if ns.WhyRegister then
			ns.WhyRegister(timeTitle.recap, L["Last time"], "Card Vision", { L["The Card Vision page's Last time line: what you did last session, as you log in"] })
		end
		timeTitle.recap:SetTextColor(RECAP_COLOR[1], RECAP_COLOR[2], RECAP_COLOR[3])
		local function Clear()
			timeTitle.text:SetText("")
			timeTitle.recap:SetText("")
		end
		ZoneTextFrame:HookScript("OnHide", Clear)
		-- Never in a fight: the Last time line goes as one starts.
		timeTitle:RegisterEvent("PLAYER_REGEN_DISABLED")
		timeTitle:SetScript("OnEvent", function() timeTitle.recap:SetText("") end)
		timeTitle.Clear = Clear
		-- Only runs while the zone title shows (this frame is its child).
		ns.SetOnUpdate(timeTitle, function()
			if (timeTitle.text:GetText() or "") ~= "" or (timeTitle.recap:GetText() or "") ~= "" then
				PlaceTimeTitle()
			end
		end)
	end
	local _, _, hour = TimeOfDayColor()
	timeTitle.text:SetText(showTime and L[TimeTitleAt(hour)] or "")
	timeTitle.recap:SetText(recap or "")
	timeTitle.sized = nil -- (sized again: the Cards page's font may have changed)
	PlaceTimeTitle()
	-- If the zone name never showed, don't leave the title waiting for the
	-- next zone change.
	C_Timer.After(10, function()
		if not ns.Flag(ZoneTextFrame:IsShown()) then
			timeTitle.Clear()
		end
	end)
end

-- When the time of day changes during play (Evening to Dusk, say): the Time
-- of day event's card (Cards.lua), with its sound (its rules on the Sounds
-- tab: CombatSoundRules.lua).
local CHANGE_CHECK = 15 -- seconds between checks
local lastTitle

-- The time of day's card (title: its English name), its sound with it.
local function TimeCard(title)
	return { name = L[title], sound = function() ns.PlayTimeCueSound(title) end }
end

-- A warning from the game ("Dun Algaz is under attack!", Chat.lua): the Under
-- attack event's card (its sound: your faction's city bell, to start with).
-- force: a test's.
function ns.ShowAlertTitle(text, force)
	if ns.Cards then ns.Cards.Fire("attack", { name = text }, force) end
end

ns.CardSamples = ns.CardSamples or {} -- (the cards' samples: Cards.lua's Test; Death's in DeathVision.lua)
ns.CardSamples.time = function()
	return TimeCard(TimeTitleAt((GetClockTime())))
end
ns.CardSamples.attack = function()
	local place = GetMinimapZoneText and GetMinimapZoneText() or ""
	return { name = L["%s is under attack!"]:format(place ~= "" and place or (GetRealZoneText() or "")) }
end

-- /cine timetest: show it now (the current time of day, or a given name).
function ns.TestTimeChangeTitle(text)
	if ns.Cards then ns.Cards.Fire("time", TimeCard(text or TimeTitleAt((GetClockTime()))), true) end
end

-- The time of day's title now, in your language.
function ns.TimeTitleNow()
	return L[TimeTitleAt((GetClockTime()))]
end

C_Timer.NewTicker(CHANGE_CHECK, ns.Profiled("Time of day check", function()
	if not ns.db then
		return
	end
	local hour = GetClockTime()
	local title = TimeTitleAt(hour)
	if lastTitle and title ~= lastTitle and ns.Setting("timeOfDayChange")
		and not InCombatLockdown() and not (ZoneTextFrame and ns.Flag(ZoneTextFrame:IsShown())) then
		if ns.Cards then ns.Cards.Fire("time", TimeCard(title)) end
	end
	lastTitle = title
end))
end)
