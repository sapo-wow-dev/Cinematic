-- The previews' game plate (Plates/PlateCopy.lua) on the stand-in (offline,
-- Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/gameplate.lua < /dev/null
-- Forever: Nameplate Style's preview and General's screen build the game's
-- plate (a stand-in of NamePlateUnitFrameTemplate with its parts), put the
-- sample unit and states on it with the game's calls, dress it through the
-- real plates' code (ns.StylePlateBar, ns.StylePlateCast, the name look), and
-- the state pills toggle as agreed (target / focus one or the other, can't
-- interrupt turns casting on). A template that fails: the drawn plate, no
-- error. Retail: the drawn plate. PASS or FAIL per check.
-- luacheck: ignore 111 112 113 121 122 212 431
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local calls = {}
local function Note(text) calls[#calls + 1] = text end
local parts = dofile("Tools/offline/gameplate_parts.lua")(Note)

local function Load(client)
	local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
		issecretvalue = function() return false end
		parts.Install()
	end)
	return ns, wow
end

-- Forever --------------------------------------------------------------------
local ns, wow = Load("forever")
local styled = {}
local barStyle, castStyle = ns.StylePlateBar, ns.StylePlateCast
ns.StylePlateBar = function(plate, look, theme) styled[#styled + 1] = { "bar", plate, look, theme }
	return barStyle(plate, look, theme) end
ns.StylePlateCast = function(plate) styled[#styled + 1] = { "cast", plate }; return castStyle(plate) end

local holder = ns.MakePlateRowLookPreview(UIParent, 480, "others")
local game = holder.gamePlate
Check("Nameplate Style's preview has the game's plate", game ~= nil and game.UnitFrame ~= nil)
Check("the preview's plate is it (Combat Text draws on holder.plate)", holder.plate == game)
Check("not built till it's first drawn", game and game.gameCopy == nil)
Check("sized as the game sizes plates", game and game:GetWidth() ~= nil)
-- (The stand-in's frames all read 20 high: the lift is checked, the height in game.)
Check("a plate lift over the unit and state pills", holder.plateLift and holder.plateLift >= 50, holder.plateLift)
-- (The picks: two dropdowns, Unit and State, among the page's pieces (the user, 2026-11-23: no rows of pills).)
local inPieces = 0
for _, piece in ipairs(holder.pagePieces) do
	if piece == holder.unitDropdown or piece == holder.stateDropdown then inPieces = inPieces + 1 end
end
Check("a Unit and a State dropdown, among the page's pieces", holder.unitDropdown ~= nil and holder.stateDropdown ~= nil
	and inPieces == 2, inPieces)

local ok, err = pcall(holder.Refresh, holder)
Check("Refresh draws without an error", ok, err)
Check("built on its first draw, laid out by the game's ApplyFrameOptions with its options", game.gameCopy ~= nil
	and calls[1] == "layout true", calls[1])
Check("the heal and absorb glows hidden (run 7: a cyan tick at the bar's end)", game.gameCopy
	and not game.gameCopy.HealthBarsContainer.healthBar.overAbsorbGlow:IsShown()
	and not game.gameCopy.HealthBarsContainer.healthBar.overHealAbsorbGlow:IsShown())
Check("the loss of control slot hidden before the aura size is set (run 5's error)", game.gameCopy
	and not game.gameCopy.AurasFrame.LossOfControlFrame:IsShown())
Check("starts casting (the default state)", game.states.casting == true and table.concat(calls, "|"):find("cast standard", 1, true))
local function Click(key) holder.ToggleState(key) end -- (what the State dropdown's ticks call)
local function Styled(kind)
	for i = #styled, 1, -1 do if styled[i][1] == kind and styled[i][2] == game then return true end end
end
Check("its bar dressed through the real plates' code", Styled("bar"))
Check("its cast bar dressed through the real plates' code", Styled("cast"))

Click("target")
Check("Target on", game.states.target == true)
Click("focus")
Check("Focus on takes Target off", game.states.focus == true and game.states.target == nil)
Click("locked")
Check("Can't interrupt turns Casting on and casts the locked kind", game.states.locked == true and game.states.casting == true
	and calls[#calls] ~= nil and table.concat(calls, "|"):find("cast uninterruptable", 1, true))
Click("casting")
Check("Casting off takes Can't interrupt off", game.states.casting == nil and game.states.locked == nil)
Click("marker")
Check("Marker puts the game's skull on", table.concat(calls, "|"):find("marker 8", 1, true))
Click("elite")
Check("Elite asks the game for its elite mark", table.concat(calls, "|"):find("class elite", 1, true))
Click("aggro")
Check("Aggro shows the game's glow", table.concat(calls, "|"):find("aggro true", 1, true))
Click("aggro")
Check("Aggro off: its glow gone at once (run 7: it faded into the next pick)", not game.gameCopy.aggroHighlightBase:IsShown()
	and not game.gameCopy.aggroHighlightAdditive:IsShown())
Click("aggro")
Click("debuffs")
Check("Debuffs fill the game's debuff list, each with its time left", table.concat(calls, "|"):find("list debuffs 5, 5 timed", 1, true))
Check("Debuffs only: the crowd control row left empty", not table.concat(calls, "|"):find("list crowd", 1, true))
Click("crowd")
Check("Crowd control fills the game's own row, with its time left", table.concat(calls, "|"):find("list crowd 1, 1 timed", 1, true))
-- (Renewed before the times run out: a renew due, the lists filled again.)
local renewBefore = #calls
game.aurasRenewAt = 0
ns.RenewGamePlateAuras(game)
local renewed = false
for i = renewBefore + 1, #calls do if calls[i]:find("list debuffs 5, 5 timed", 1, true) then renewed = true end end
Check("the auras renewed before their times run out", renewed and game.aurasRenewAt and game.aurasRenewAt > 0)
Click("crowd")
-- The batch (2026-11-23): each new part with the game's own call, as your settings show it (here every option on).
local function Called(text, from)
	for i = from or 1, #calls do if calls[i]:find(text, 1, true) then return true end end
	return false
end
local function Only(key)
	for _, state in ipairs(ns.GAME_PLATE_STATES) do if game.states[state] then Click(state) end end
	if game.states.casting then Click("casting") end
	if key then Click(key) end
end
local copy = game.gameCopy
local mark = #calls
holder.PickSample(1)
Check("health text: the game's own call, as your settings show it", Called("health text", mark))
Check("the crowd control row placed again with the level box up (a root sat under the box, the user's shot)",
	Called("control anchors, level box true", mark))
local castBar = copy.CastBarsContainer.castBar
mark = #calls
Only("channel")
Check("Channeling: a channel, draining from full", Called("cast channel", mark) and castBar.channeling == true
	and castBar.casting == nil and game.states.casting == true)
mark = #calls
Only("important")
Check("Important cast: the cast flagged important (the game's glow as your settings say)", Called("cast standard important", mark))
mark = #calls
Only("atyou")
Check("Casting at you: the cast on you, your name as its target", Called("cast standard atyou on", mark))
Only("locked")
Click("channel")
Check("one cast kind at a time: Channeling takes Can't interrupt off", game.states.channel and not game.states.locked)
-- (Interrupted: cast, then cut off by the bar's own interrupt 1.2 s in.)
local realTime, now = GetTime, 1000
GetTime = function() return now end
Only("interrupted")
local tick = game:GetScript("OnUpdate")
mark = #calls
if tick then tick(game, 0.1) end
now = now + 1.3
if tick then tick(game, 0.1) end
Check("Interrupted: cast, then the bar's own interrupt", Called("cast standard", mark) and Called("interrupted UNIT_SPELLCAST_INTERRUPTED", mark))
GetTime = realTime
for _, rank in ipairs({ { "rare", "rare" }, { "rareelite", "rareelite" }, { "boss", "worldboss" } }) do
	mark = #calls
	Only(rank[1])
	Check(rank[1] .. ": the game's mark for it", Called("class " .. rank[2], mark))
end
Check("Boss: a skull in the level box, no number", copy.PlayerLevelDiffFrame.highLevelTexture:IsShown()
	and not copy.PlayerLevelDiffFrame.playerLevelDiffText:IsShown())
Only("elite")
Check("one rank at a time, and the skull gone off a boss", game.states.elite and not game.states.boss
	and not copy.PlayerLevelDiffFrame.highLevelTexture:IsShown())
Only("aggro")
local r, g = copy.HealthBarsContainer.healthBar:GetStatusBarColor()
Check("Aggro: the glow, the flash and the bar in the threat color (every threat option on)", copy.aggroHighlight:IsShown()
	and copy.aggroFlash:IsShown() and r == 1 and g == 0, tostring(r) .. "," .. tostring(g))
Only("gaining")
r, g = copy.HealthBarsContainer.healthBar:GetStatusBarColor()
Check("Pulling threat: the glow in the gaining color, no flash", copy.aggroHighlight:IsShown() and not copy.aggroFlash:IsShown()
	and g == 0.6, tostring(r) .. "," .. tostring(g))
holder.PickSample(3)
Check("no threat looks on a friendly unit, as the game", not copy.aggroHighlight:IsShown())
holder.PickSample(1)
Only("tapped")
r, g = copy.HealthBarsContainer.healthBar:GetStatusBarColor()
Check("Tapped: the game's grey bar", r == 0.9 and g == 0.9, tostring(r))
Only("quest")
Check("Quest giver: the soft target's quest icon over it", copy.SoftTargetFrame.Icon:IsShown())
Only(nil)
Check("off again: no icon, no threat, no flash", not copy.SoftTargetFrame.Icon:IsShown() and not copy.aggroHighlight:IsShown()
	and not copy.aggroFlash:IsShown())
-- (The picks as the checks above left them, for the next panel's check below.)
Click("focus")
Click("debuffs")

Check("the name and level set", game.UnitFrame.name:GetText() ~= nil
	and game.UnitFrame.PlayerLevelDiffFrame.playerLevelDiffText:GetText() ~= nil)

-- (The stand-in's frames keep no width: the dropdowns keep theirs, to check their sizing.)
local makeDropdown = ns.MenuDropdown
ns.MenuDropdown = function(parent)
	local ok, drop = makeDropdown(parent)
	if ok and drop then
		drop.SetWidth = function(self, w) self._w = w end
		drop.GetWidth = function(self) return self._w or 0 end
		drop.SetupMenu = function(self, generate) self._generate = generate end -- (its list, built on demand below)
	end
	return ok, drop
end
-- Narrow: the Scene pick gets a row of its own over the unit picks (run 6: at 300 wide they met).
local narrow = ns.MakePlateRowLookPreview(UIParent, 300, "others")
local wide = ns.MakePlateRowLookPreview(UIParent, 2000, "others")
Check("narrow: the plate lifted a row more for the Scene pick", narrow.plateLift and wide.plateLift
	and narrow.plateLift > wide.plateLift, tostring(narrow.plateLift) .. " vs " .. tostring(wide.plateLift))
Check("narrow: the State dropdown squeezed to the room (run 8: it reached past the edge at 300)",
	narrow.unitDropdown:GetWidth() + 6 + narrow.stateDropdown:GetWidth() <= 300 - 12,
	tostring(narrow.unitDropdown:GetWidth()) .. " + " .. tostring(narrow.stateDropdown:GetWidth()))

-- A second preview keeps the picks (as the unit pick is kept).
local second = ns.MakePlateRowLookPreview(UIParent, 480, "target")
second:Refresh()
Check("the picks kept for the next panel", second.gamePlate.states.debuffs == true and second.gamePlate.states.focus == true)

-- General's screen.
local general = ns.MakeGeneralPlatePreview(UIParent, 480)
local okG, errG = pcall(general.Refresh, general)
Check("General's screen draws the game's plate", okG and Styled("bar"), errG)

-- Nameplate Style's own page (2026-11-23): the Look panel's previewer in its
-- preview, one big game plate with its Unit and State lists (the user: "the
-- same previewer in both"), the Theme list and Customize on one row.
local pageEntry
for _, entry in ipairs(ns.lazySettingsPages or {}) do
	if entry.name == "Nameplate Style" then pageEntry = entry end
end
Check("Nameplate Style's page waits to be made", pageEntry ~= nil)
local okMake, errMake = pcall(pageEntry and pageEntry.Make or error, "test")
Check("the page builds without an error", okMake, errMake)
local pagePreview, pageContent
for _, frame in ipairs(wow.frames or {}) do
	if rawget(frame, "lookPreview") ~= nil and rawget(frame, "Hover") then pagePreview = frame end
	if rawget(frame, "plateEditor") ~= nil then pageContent = frame end -- (the Style Studio's editor, 2026-11-25)
end
Check("the page's preview found, holding the Look panel's previewer", pagePreview ~= nil)
local inner = pagePreview.lookPreview
-- (One Preview list since 2026-11-25, the mock: the unit first, then every state, in one dropdown.)
Check("the previewer has its one Preview list (unit and states)", inner.unitDropdown ~= nil and inner.stateDropdown == nil
	and inner.oneList == true and inner.unitDropdown:GetParent() == inner)
local okR2, errR2 = pcall(pagePreview.Refresh, pagePreview)
Check("the page's preview draws without an error", okR2, errR2)
Check("the page's preview on the game's plate", pagePreview.gameMode == true and inner:IsShown())
Check("one plate, bigger, centered on its bar (not moved left)", inner.gamePlate:IsShown()
	and (inner.gameScale or 0) > 0 and not inner.gameShift, tostring(inner.gameScale))
Check("no drawn plates over it, no Scene button on its Unit list", pagePreview.backButton == nil)
-- (2026-11-25 the mock, the user: "visually not good", a small plate low in a tall empty stage.
-- Was: kept 210 tall (minHeight) and what shows in the middle of that room, 54.49 / 63.73.
-- Now: the plate as big as the 268-wide stage allows with its level box (scale 0.91), the stage only as tall as what shows.)
for _, withDebuffs in ipairs({ false, true }) do
	if (ns.PlatePreviewStates().debuffs and true or false) ~= withDebuffs then inner.ToggleState("debuffs") end
	-- (at the page's size: the stand-in lays nothing out, its frames 100 x 20)
	ns.PlatePreviewFit(inner, 268, 210, inner.plateLift or 38)
	local s = inner.gameScale or 0
	local lift = inner.plateLift or 38
	local fit = inner.fitHeight
	Check(("the plate as big as the stage allows (debuffs %s)"):format(withDebuffs and "on" or "off"), s >= 0.9,
		tostring(s))
	-- (Later the same day: one height on every tab, room kept for debuffs, the user "the
	-- previewer needs to be taller" and "why arent they the same size".)
	Check(("the stage the tabs' one height (debuffs %s)"):format(withDebuffs and "on" or "off"),
		fit ~= nil and fit == ns.PLATE_STAGE_H, tostring(fit))
	-- (and what shows inside it: its bottom over the Preview list, its top under the stage's)
	local _, nameTop = ns.PlatePreviewSpan(inner, inner.gamePlate.gameCopy.name)
	local top = nameTop and (inner.gameLift or 0) + nameTop * s
	Check(("what shows inside the stage (debuffs %s)"):format(withDebuffs and "on" or "off"),
		top ~= nil and (inner.gameLift or 0) >= lift - 1 and top <= (fit or 0) + 1,
		tostring(inner.gameLift) .. " .. " .. tostring(top) .. " in " .. tostring(fit))
end
inner.ToggleState("debuffs")
local before = #styled
pcall(pagePreview.Pick, pagePreview, "others")
local dressed = 0
for i = before + 1, #styled do if styled[i][1] == "bar" then dressed = dressed + 1 end end
Check("a row picked: the plate dressed through the real plates' code, as that row", dressed >= 1
	and inner.kind == "others", dressed)
-- (A theme pointed at in the Theme list: on the previewer, not saved.)
local themeBefore = ns.db.plateTheme
pagePreview.hoverTheme = "game"
pcall(pagePreview.Refresh, pagePreview)
local hovered = false
for i = before + 1, #styled do if styled[i][1] == "bar" and styled[i][4] == "game" then hovered = true end end
Check("a theme pointed at: the previewer shows it, the saved theme left alone", hovered and inner.hoverTheme == "game"
	and ns.db.plateTheme == themeBefore)
pagePreview.hoverTheme = nil
-- (The Theme list and Customize became the Style Studio's editor, 2026-11-25: its
-- Plate part's Theme tiles. These checks read the editor now.)
Check("the editor on the page, on the Nameplates frame", pageContent and pageContent.plateEditor ~= nil
	and pageContent.plateEditor.f == ns.Studio.frames.plates)

-- The Theme tiles: Follow main theme first, The game's second, then every theme; a
-- pick saved and the plates refreshed; pointing at one shows it, unsaved.
local Studio = ns.Studio
local themeProp
for _, each in ipairs(Studio.Props(Studio.frames.plates, "bar")) do
	if each.prop.label == ns.L["Theme"] then themeProp = each end
end
local entries = themeProp and themeProp.prop.options() or {}
Check("the Theme tiles: Follow main theme, The game's, then every theme", #entries == #ns.PlateThemeList() + 1
	and entries[1].text == ns.L["Follow main theme"] and entries[2].value == "game",
	#entries .. " of " .. (#ns.PlateThemeList() + 1))
local refreshed = 0
local realRefresh = ns.RefreshPlateHealthStyle
ns.RefreshPlateHealthStyle = function() refreshed = refreshed + 1; if realRefresh then realRefresh() end end
local seen
local realBar = ns.StylePlateBar
ns.StylePlateBar = function(...) seen = ns.db.plateTheme return realBar(...) end
Studio.ShowFor(pagePreview, "plateTheme", "game")
ns.StylePlateBar = realBar
Check("pointing at a theme shows it on the preview, not saved", seen == "game" and ns.db.plateTheme == themeBefore,
	tostring(seen))
if themeProp and entries[3] then Studio.Set(Studio.frames.plates, themeProp.prop, "others", entries[3].value, themeProp.part) end
Check("a theme picked: saved, the plates refreshed", ns.db.plateTheme ~= nil and ns.db.plateTheme ~= "main"
	and ns.db.plateTheme ~= "game" and refreshed >= 1, tostring(ns.db.plateTheme) .. ", " .. refreshed)
Studio.Undo()
Check("Undo puts the theme back", ns.db.plateTheme == themeBefore, tostring(ns.db.plateTheme))
ns.RefreshPlateHealthStyle = realRefresh
ns.db.plateTheme = themeBefore

-- The debuffs kept over the name (2026-11-25, the in-game shot: they sat on it), by
-- their measured places (PlateRowLook.lua's PlatePreviewFit). As the game lays them
-- out (debuffs over the name), nothing moves; overlapping, they're lifted clear.
do
	local copy = inner.gamePlate and inner.gamePlate.gameCopy
	local debuffList = copy and copy.AurasFrame and copy.AurasFrame.DebuffListFrame
	if not (ns.PlatePreviewStates(inner).debuffs) then inner.ToggleState("debuffs") end
	local function Stub(frame, bottom, top)
		rawset(frame, "GetBottom", function() return bottom end)
		rawset(frame, "GetTop", function() return top end)
		rawset(frame, "GetEffectiveScale", function() return 1 end)
	end
	local plateFrame = inner.gamePlate
	local saved = {}
	for _, f in ipairs({ plateFrame, copy.name, debuffList }) do
		saved[f] = { rawget(f, "GetBottom"), rawget(f, "GetTop"), rawget(f, "GetEffectiveScale") }
	end
	rawset(debuffList, "IsVisible", function() return true end)
	local kid = CreateFrame("Frame", nil, debuffList)
	kid:Show()
	for _, case in ipairs({ { "the game's layout", 62, 82, false }, { "overlapping the name", 50, 70, true } }) do
		Stub(plateFrame, 0, 85)
		Stub(copy.name, 48, 60)
		Stub(debuffList, case[2], case[3])
		ns.PlatePreviewFit(inner, 560, 210, inner.plateLift or 38)
		local lifted = inner.debuffLift or 0
		local _, nameTop = ns.PlatePreviewSpan(inner, copy.name)
		local debuffBottom = ns.PlatePreviewSpan(inner, debuffList)
		Check(("debuffs above the name's top (%s)"):format(case[1]), nameTop and debuffBottom
			and debuffBottom + lifted > nameTop and ((lifted > 0) == case[4]),
			tostring(debuffBottom) .. " + " .. tostring(lifted) .. " vs " .. tostring(nameTop))
		local laid = inner.previewLayout
		Check(("the lift put on the preview's layout (%s)"):format(case[1]), not case[4]
			or (laid and laid.parts and laid.parts.debuffs and laid.parts.debuffs.y == lifted), tostring(laid))
	end
	for f, s in pairs(saved) do rawset(f, "GetBottom", s[1]) rawset(f, "GetTop", s[2]) rawset(f, "GetEffectiveScale", s[3]) end
	rawset(debuffList, "IsVisible", nil)
	kid:Hide()
	inner.ToggleState("debuffs")
end

-- A template that fails: the drawn plate, nothing broken.
parts.works = false
local drawn = ns.MakePlateRowLookPreview(UIParent, 480, "others")
local okD, errD = pcall(drawn.Refresh, drawn)
Check("no template parts: the drawn plate, no error", drawn.gamePlate.gameCopy == nil and okD, errD)
parts.works = true

-- A layout that anchors nothing: the drawn plate, and why in the log (once).
parts.anchors = false
local unanchored = ns.MakePlateRowLookPreview(UIParent, 480, "others")
unanchored:Refresh()
local said = 0
for _, line in ipairs(CinematicDB.log or {}) do
	if tostring(line):find("game plate copy not used: the health bar wasn't anchored", 1, true) then said = said + 1 end
end
Check("a layout that anchors nothing: the drawn plate, the reason logged", unanchored.gamePlate.gameCopy == nil
	and said >= 1, said)
parts.anchors = true

-- The game's options not filled in yet (a preview drawn at login): the drawn
-- plate, then the game's once they are (run 5).
local width = _G.NamePlateSetupOptions.playerLevelDiffWidth
_G.NamePlateSetupOptions.playerLevelDiffWidth = nil
local early = ns.MakePlateRowLookPreview(UIParent, 480, "others")
early:Refresh()
Check("options not ready: no copy yet, the drawn plate shown", early.gamePlate.gameCopy == nil
	and not early.gamePlate:IsShown())
_G.NamePlateSetupOptions.playerLevelDiffWidth = width
early:Refresh()
Check("options ready: built on the next draw, shown", early.gamePlate.gameCopy ~= nil and early.gamePlate:IsShown())

-- Retail ---------------------------------------------------------------------
calls = {}
local rns = Load("retail")
local retail = rns.MakePlateRowLookPreview(UIParent, 480, "others")
Check("retail keeps the drawn preview (not proven there yet)", retail.gamePlate == nil and #calls == 0)
Check("retail: the Unit dropdown, no State one (no game plate to show states on)", retail.unitDropdown ~= nil
	and retail.stateDropdown == nil)
local okR, errR = pcall(retail.Refresh, retail)
Check("retail's preview draws", okR, errR)

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
os.exit(fails == 0 and 0 or 1)
