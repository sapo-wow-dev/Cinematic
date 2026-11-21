-- The Style hub's Text on You page (Tools/self-combat-text-plan.md): the
-- game's floating combat text about you ("-26", "+120 [Healer]", "<2 Combo
-- Points>", "Mana Low"), drawn by us beside you, our way.
--
-- How (proved by /cine debug selftext, Forever 2026-11-20): the game keeps
-- deciding what shows and its words. Its CombatText frame is hidden (alpha
-- 0; with its own setting off it draws nothing, so there'd be nothing to
-- copy) and each message it puts on one of its texts (SetText) is copied
-- into a text of ours: the words are secret, but SetText takes them. The
-- event of the same instant (COMBAT_TEXT_UPDATE, its kind plain) says what
-- it is, for each kind's look; a message with none (Low Mana, Low Health)
-- is told by what else happened then. Its color: the game's (read off its
-- text, plain), or the kind's own.
--
-- Where: your spot on the screen. With Follow the Shoulder Cam on and the
-- camera over your shoulder, across by where it puts you
-- (ns.ShoulderYouShift, ShoulderCam.lua), eased; else the middle.
--
-- The game's Text on Me ticks still decide which kinds it makes at all
-- (Options > Combat): a kind it's told not to show never reaches us.
-- Page off: the game's text as it was.

local _, ns = ...
local L = ns.L
local DEFAULTS = ns.DEFAULTS

DEFAULTS.selfTextStyle = false   -- the page's Enable Page
DEFAULTS.selfTextBy = "ours"     -- who draws your combat text: "ours", "game" (as it is) or "none"
DEFAULTS.selfTextFollow = true   -- beside you while the Shoulder Cam is over your shoulder
DEFAULTS.selfTextSide = "free"   -- "over" you, your "free" side (away from the screen's middle), "split"
DEFAULTS.selfTextMotion = "up"   -- "up", "down", "arc", "pop"
DEFAULTS.selfTextHeight = 0      -- UI units up from your spot
DEFAULTS.selfTextSize = 1        -- times the base size
DEFAULTS.selfTextCrit = 1.5      -- a crit's size, times a hit's
DEFAULTS.selfTextLife = 1.6      -- seconds a text shows
DEFAULTS.selfTextFont = "game"   -- "game": the game's combat text font; else a Style font
DEFAULTS.selfTextEdge = "game"   -- "game" (a drop shadow, as the game's), "edge", "both", "none"

-- The kinds of text, each a group with its own color and on/off:
-- selfText_<id>Color "game" (the game's color), "custom" (its R, G, B) or
-- "off" (not shown). taken: on the taken side when Split.
local GROUPS = {
	{ id = "damage", label = L["Damage taken"], taken = true, color = { 1, 0.1, 0.1 } },
	{ id = "miss", label = L["Misses on you"], taken = true, color = { 1, 1, 1 } },
	{ id = "heal", label = L["Heals"], color = { 0.1, 1, 0.1 } },
	{ id = "shield", label = L["Shields"], color = { 0.6, 0.85, 1 } },
	{ id = "power", label = L["Power gains"], color = { 0.3, 0.55, 1 } },
	{ id = "combo", label = L["Combo points"], color = { 1, 0.82, 0 } },
	{ id = "aura", label = L["Auras gained and lost"], color = { 1, 0.9, 0.4 } },
	{ id = "alert", label = L["Spell alerts"], color = { 1, 0.82, 0 } },
	{ id = "low", label = L["Low health and mana"], taken = true, color = { 1, 0.1, 0.1 } },
	{ id = "combat", label = L["Entering and leaving combat"], taken = true, color = { 1, 1, 1 } },
	{ id = "reward", label = L["Reputation and honor"], color = { 0.5, 0.5, 1 } },
	{ id = "other", label = L["Anything else"], color = { 1, 1, 1 } },
}
local BY_ID = {}
for _, group in ipairs(GROUPS) do
	BY_ID[group.id] = group
	DEFAULTS["selfText_" .. group.id .. "Color"] = "game"
	DEFAULTS["selfText_" .. group.id .. "R"] = group.color[1]
	DEFAULTS["selfText_" .. group.id .. "G"] = group.color[2]
	DEFAULTS["selfText_" .. group.id .. "B"] = group.color[3]
end

-- The game's message kinds (COMBAT_TEXT_UPDATE), by group.
local KIND = {}
for group, kinds in pairs({
	damage = { "DAMAGE", "DAMAGE_CRIT", "SPLIT_DAMAGE", "SPELL_DAMAGE", "SPELL_DAMAGE_CRIT", "PERIODIC_DAMAGE",
		"DAMAGE_SHIELD" },
	miss = { "MISS", "DODGE", "PARRY", "BLOCK", "DEFLECT", "EVADE", "IMMUNE", "REFLECT", "RESIST", "ABSORB",
		"SPELL_MISS", "SPELL_DODGE", "SPELL_PARRY", "SPELL_BLOCK", "SPELL_DEFLECT", "SPELL_EVADE", "SPELL_IMMUNE",
		"SPELL_REFLECT", "SPELL_RESIST", "SPELL_ABSORB", "PROC_RESISTED" },
	heal = { "HEAL", "HEAL_CRIT", "PERIODIC_HEAL", "PERIODIC_HEAL_CRIT" },
	shield = { "ABSORB_ADDED", "HEAL_ABSORB", "HEAL_CRIT_ABSORB", "PERIODIC_HEAL_ABSORB" },
	power = { "ENERGIZE", "PERIODIC_ENERGIZE", "RUNE" },
	combo = { "COMBO_POINTS" },
	aura = { "SPELL_AURA_START", "SPELL_AURA_END", "SPELL_AURA_START_HARMFUL", "SPELL_AURA_END_HARMFUL" },
	alert = { "SPELL_ACTIVE", "SPELL_CAST" },
	combat = { "ENTERING_COMBAT", "LEAVING_COMBAT" },
	reward = { "FACTION", "HONOR_GAINED" },
}) do
	for _, kind in ipairs(kinds) do KIND[kind] = group end
end

local BASE_SIZE = 24      -- a hit's text at Size 1 (the game's, by eye)
local CLIMB = 90          -- UI units a text moves over its life
local SIDE = 90           -- UI units from you to the side a text sits on
local GAP = 1.1           -- texts on one side kept this many lines apart
local FADE_FROM = 0.6     -- of its life, when it starts fading
local MAX_LIVE = 30       -- texts at once; the oldest goes first
local EASE = 10           -- how fast the spot follows you (per second)
local SAME = 0.02         -- seconds: an event and a text this close are one message

local function Secret(v) return issecretvalue and issecretvalue(v) end
local function DB() return ns.db or {} end
local function On() return ns.StyleOn("selfTextStyle") end
local function By() return On() and (DB().selfTextBy or "ours") or "game" end

-- What's going on, for /cine debug selftext state and the test.
local stats = { copied = 0, shown = 0, dropped = 0, noEvent = 0, kinds = {} }
ns.SelfTextStats = stats

-- Our texts ------------------------------------------------------------------
local layer = CreateFrame("Frame", "CinematicSelfText", UIParent)
layer:SetAllPoints(UIParent)
layer:SetFrameStrata("HIGH")
layer:Hide()
local pool, live = {}, {}
local spot = { x = 0 } -- (eased)

local function FontFile()
	local value = DB().selfTextFont
	if value and value ~= "game" then
		local file = ns.StyleFontFile and ns.StyleFontFile(value)
		if file then return file end
	end
	local font = _G.CombatTextFont
	local ok, file = pcall(function() return font and font:GetFont() end)
	if ok and type(file) == "string" and not Secret(file) then return file end
	return "Fonts\\FRIZQT__.TTF"
end
local function Edge(fs, size)
	local edge = DB().selfTextEdge or "game"
	local flags = (edge == "edge" or edge == "both") and "OUTLINE" or ""
	fs:SetFont(FontFile(), size, flags)
	if edge == "game" or edge == "both" then
		fs:SetShadowColor(0, 0, 0, 1)
		fs:SetShadowOffset(math.max(1, size / 16), -math.max(1, size / 16))
	else
		fs:SetShadowOffset(0, 0)
	end
end

-- Which side a group goes: +1 right, -1 left (from your spot), 0 over you.
local function SideOf(group)
	local side = DB().selfTextSide or "free"
	if side == "over" then return 0 end
	local away = spot.x < -1 and -1 or 1 -- (away from the screen's middle; in it: right)
	if side == "split" and not BY_ID[group].taken then return -away end
	return away
end

local function Retire(index)
	local text = table.remove(live, index)
	text:Hide()
	text.born = nil
	pool[#pool + 1] = text
end

-- One text: words (secret or not), its group, crit, a color.
local function Show(words, group, crit, r, g, b)
	if #live >= MAX_LIVE then Retire(1) end
	local text = table.remove(pool) or layer:CreateFontString(nil, "OVERLAY")
	local size = BASE_SIZE * (DB().selfTextSize or 1) * (crit and (DB().selfTextCrit or 1.5) or 1)
	Edge(text, math.min(120, size)) -- (SetFont's top, Forever)
	-- (Blanked before its words: a text that held secret words stays secret
	-- till then, MSBT Forever's finding, read 2026-11-21. After its font: a
	-- new text has none, and SetText with no font errors "Font not set",
	-- Forever 2026-11-21, the page's Test.)
	text:SetText("")
	text:SetTextColor(r, g, b)
	text:SetText(words)
	text.group, text.crit, text.side = group, crit, SideOf(group)
	text.born, text.push = GetTime(), 0
	text.line = size * GAP
	-- (Room for it: the texts already on its side pushed along, as the game's.)
	for _, other in ipairs(live) do
		if other.side == text.side then other.push = other.push + text.line end
	end
	live[#live + 1] = text
	text:SetAlpha(1)
	text:Show()
	layer:Show()
	stats.shown = stats.shown + 1
end

-- A text's place at t (0..1 of its life).
local function Place(text, t, baseX, baseY)
	local motion = DB().selfTextMotion or "up"
	local x = baseX + text.side * SIDE
	local along = t * CLIMB + text.push
	local y
	if motion == "down" then
		y = baseY - along
	elseif motion == "arc" then
		local dir = text.side ~= 0 and text.side or 1
		x = x + dir * math.sin(t * math.pi / 2) * 60
		y = baseY + math.sin(t * math.pi) * 50 + text.push
	elseif motion == "pop" then
		y = baseY + along * 0.5
	else
		y = baseY + along
	end
	text:ClearAllPoints()
	text:SetPoint("CENTER", UIParent, "CENTER", x, y)
	-- (Pop: a crit starts twice its size and settles in a quarter second.)
	if motion == "pop" and text.crit and text.SetTextScale then
		local grow = t * (DB().selfTextLife or 1.6)
		text:SetTextScale(grow < 0.25 and (2 - grow / 0.25) or 1)
	elseif text.SetTextScale then
		text:SetTextScale(1)
	end
end

ns.SetOnUpdate(layer, function(_, elapsed)
	local db = DB()
	local want = 0
	if db.selfTextFollow ~= false and ns.ShoulderYouShift then want = ns.ShoulderYouShift() or 0 end
	spot.x = spot.x + (want - spot.x) * math.min(1, (elapsed or 0) * EASE)
	local life = math.max(0.3, db.selfTextLife or 1.6)
	local now = GetTime()
	for index = #live, 1, -1 do
		local text = live[index]
		local t = (now - text.born) / life
		if t >= 1 then
			Retire(index)
		else
			Place(text, t, spot.x, db.selfTextHeight or 0)
			text:SetAlpha(t < FADE_FROM and 1 or (1 - t) / (1 - FADE_FROM))
		end
	end
	if #live == 0 then layer:Hide() end
end)

-- Copying the game's -----------------------------------------------------------
-- Each message the game draws, waiting a frame for its event and color:
-- { at, words, region, kind, with }.
local waiting = {}
local context = {} -- { at, what }: your power's type, your health, a fight starting or ending

local function Classify(message)
	-- (A kind that came before its text sits in the context: given to it here.)
	if not message.kind then
		for _, ctx in ipairs(context) do
			local early = ctx.what:match("^kind:(.+)$")
			if early and math.abs(ctx.at - message.at) <= SAME then
				message.kind = early
				break
			end
		end
	end
	local kind = message.kind
	if kind then
		stats.kinds[kind] = (stats.kinds[kind] or 0) + 1
		local group = KIND[kind] or "other"
		-- (Combo points come as ENERGIZE: told by your power's type then.)
		if group == "power" and message.with and message.with.COMBO_POINTS then group = "combo" end
		return group, kind:find("_CRIT$") ~= nil
	end
	stats.noEvent = stats.noEvent + 1
	local with = message.with or {}
	if with.fight then return "combat", false end
	if with.health or with.power then return "low", false end
	return "other", false
end

local function ColorOf(group, region)
	local db = DB()
	local mode = db["selfText_" .. group .. "Color"] or "game"
	if mode == "custom" then
		return db["selfText_" .. group .. "R"] or 1, db["selfText_" .. group .. "G"] or 1, db["selfText_" .. group .. "B"] or 1
	end
	local ok, r, g, b = pcall(region.GetTextColor, region)
	if ok and not (Secret(r) or Secret(g) or Secret(b)) and type(r) == "number" then return r, g, b end
	local own = BY_ID[group].color
	return own[1], own[2], own[3]
end

local function Settle()
	local now = GetTime()
	for index = #waiting, 1, -1 do
		local message = waiting[index]
		if now > message.at then
			table.remove(waiting, index)
			-- (What else came in its instant.)
			message.with = {}
			for _, ctx in ipairs(context) do
				if math.abs(ctx.at - message.at) <= SAME then message.with[ctx.what] = true end
			end
			local group, crit = Classify(message)
			if (DB()["selfText_" .. group .. "Color"] or "game") == "off" or By() ~= "ours" then
				stats.dropped = stats.dropped + 1
			else
				local words = message.words
				if words == nil then
					local ok, got = pcall(message.region.GetText, message.region)
					words = ok and got or nil
				end
				if words ~= nil then Show(words, group, crit, ColorOf(group, message.region)) end
			end
		end
	end
	for index = #context, 1, -1 do
		if now - context[index].at > 1 then table.remove(context, index) end
	end
end
local settler = CreateFrame("Frame")
settler:Hide()
ns.SetOnUpdate(settler, function(self)
	Settle()
	if #waiting == 0 then self:Hide() end
end)

local hooked = {}
local function Copied(region, words)
	if By() == "game" then return end
	stats.copied = stats.copied + 1
	waiting[#waiting + 1] = { at = GetTime(), words = words, region = region }
	settler:Show()
end
local function HookTexts()
	local frame = _G.CombatText
	if type(frame) ~= "table" or not frame.GetRegions then return 0 end
	local count = 0
	for _, region in ipairs({ frame:GetRegions() }) do
		if region.GetObjectType and region:GetObjectType() == "FontString" then
			count = count + 1
			if not hooked[region] then
				hooked[region] = true
				hooksecurefunc(region, "SetText", Copied)
			end
		end
	end
	return count
end

-- The game's frame hidden while ours draw (or none): alpha 0, put back as
-- it was. Kept at 0 if the game sets it again.
local hidden = { on = false, was = nil, hooked = false }
local function HideGame(want)
	local frame = _G.CombatText
	if type(frame) ~= "table" then return end
	if want and not hidden.on then
		hidden.was = frame:GetAlpha()
		hidden.on = true
		frame:SetAlpha(0)
		if not hidden.hooked then
			hidden.hooked = true
			hooksecurefunc(frame, "SetAlpha", function(self, alpha)
				if hidden.on and not hidden.busy and alpha ~= 0 then
					hidden.busy = true
					self:SetAlpha(0)
					hidden.busy = false
				end
			end)
		end
	elseif not want and hidden.on then
		hidden.on = false
		hidden.busy = true
		frame:SetAlpha(hidden.was or 1)
		hidden.busy = false
	end
end

local watcher = CreateFrame("Frame")
local function Mark(what)
	context[#context + 1] = { at = GetTime(), what = what }
end
watcher:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" or event == "PLAYER_ENTERING_WORLD" then
		ns.Guard(ns.RefreshSelfTextStyle)
		return
	end
	if By() == "game" then return end
	if event == "COMBAT_TEXT_UPDATE" then
		local kind = ...
		if Secret(kind) or type(kind) ~= "string" then return end
		-- (The game's handler ran first: its text is waiting, from this instant.)
		local now = GetTime()
		for index = #waiting, 1, -1 do
			local message = waiting[index]
			if not message.kind and math.abs(message.at - now) <= SAME then
				message.kind = kind
				return
			end
		end
		-- (None yet: the text comes after; kept as context for it.)
		Mark("kind:" .. kind)
	elseif event == "UNIT_POWER_UPDATE" then
		local _, power = ...
		Mark(not Secret(power) and power == "COMBO_POINTS" and "COMBO_POINTS" or "power")
	elseif event == "UNIT_HEALTH" then
		Mark("health")
	else -- PLAYER_REGEN_DISABLED / ENABLED
		Mark("fight")
	end
end)
watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")

-- (Settings changed elsewhere, a profile, Style's own switch: caught up
-- within two seconds.)
C_Timer.NewTicker(2, function() ns.Guard(ns.RefreshSelfTextStyle) end)

-- The game's floating combat text kept on while ours copies it: with it off
-- the game draws nothing to copy (/cine debug selftext, step off), and an
-- addon like BattleText Forever turns it off. The one game setting this page
-- needs ([[no-mirror-blizzard-settings]]'s exception); let go when off, and
-- at logout.
local GAME_TEXT_ON = ns.CVarSet("Floating combat text on", "Text on You (copies the game's text)",
	{ playerWins = true, keep = true, values = { enableFloatingCombatText = "1" } })
ns.SELF_TEXT_GAME_ON = GAME_TEXT_ON
local letGo = CreateFrame("Frame")
letGo:RegisterEvent("PLAYER_LOGOUT")
letGo:SetScript("OnEvent", function() pcall(ns.ApplyCVarSet, GAME_TEXT_ON, false) end)

function ns.RefreshSelfTextStyle()
	local by = By()
	local active = by ~= "game"
	ns.ApplyCVarSet(GAME_TEXT_ON, by == "ours")
	if active then HookTexts() end
	HideGame(active)
	if active then
		watcher:RegisterEvent("COMBAT_TEXT_UPDATE")
		watcher:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
		watcher:RegisterUnitEvent("UNIT_HEALTH", "player")
		watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
		watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
	else
		watcher:UnregisterEvent("COMBAT_TEXT_UPDATE")
		watcher:UnregisterEvent("UNIT_POWER_UPDATE")
		watcher:UnregisterEvent("UNIT_HEALTH")
		watcher:UnregisterEvent("PLAYER_REGEN_DISABLED")
		watcher:UnregisterEvent("PLAYER_REGEN_ENABLED")
	end
	if by ~= "ours" then
		for index = #live, 1, -1 do Retire(index) end
		wipe(waiting)
	end
end

-- A sample on the screen, as a message of that group would show (the page's
-- Test, the in-game test): plain words.
function ns.SelfTextSample(words, group, crit)
	group = BY_ID[group] and group or "other"
	local own = BY_ID[group].color
	local db = DB()
	local r, g, b = own[1], own[2], own[3]
	if db["selfText_" .. group .. "Color"] == "custom" then
		r, g, b = db["selfText_" .. group .. "R"] or r, db["selfText_" .. group .. "G"] or g, db["selfText_" .. group .. "B"] or b
	end
	Show(words, group, crit, r, g, b)
end

-- For tests: how it stands.
function ns.SelfTextState()
	return {
		on = On(), by = By(), hidden = hidden.on, hooked = HookTexts(), live = #live, waiting = #waiting,
		spot = spot.x, stats = stats,
	}
end
ns.SELF_TEXT_GROUPS = GROUPS
ns.selfTextFrames = { layer, settler } -- (the offline test runs just these)

-- The page -----------------------------------------------------------------------
local SAMPLES = {
	{ "-26", "damage" }, { "+120 [Sapo]", "heal" }, { "Dodge", "miss" }, { "-74", "damage", true },
	{ "+20 Mana", "power" }, { "<2 Combo Points>", "combo" }, { "<Ice Barrier>", "aura" }, { "Overpower!", "alert" },
	{ "+412", "heal", true }, { "Mana Low", "low" },
}

function ns.CreateSelfTextStylePanel(kit)
	local canvas, content = kit.CreateScrollPage()
	local title = kit.Label(content, "GameFontNormalLarge", L["Text on You Style"])
	title:SetPoint("TOPLEFT", 16, -16)
	local intro = kit.PageIntro(content, title,
		L["Your floating combat text, drawn beside you, with its own look for each kind."])
	local function Changed() ns.RefreshSelfTextStyle() end
	local switch = kit.PageSwitch(content, "selfTextStyle", L["Enable Page"],
		L["Turns this page's combat text on or off."], intro, Changed)
	local stack = kit.Stack(switch, "check")
	local rows = ns.StyleRows(kit, content, stack, Changed, "selfTextStyle")
	local function Ours() return rows.On(ns.GetDB() or {}) and (ns.GetDB().selfTextBy or "ours") == "ours" end

	stack:Note(content, L["Which kinds the game makes still follows its own Text on Me settings (Options > Combat)."], 520)
	-- (Test: samples of each kind at your spot, as they'd show.)
	local test = ns.PanelButton(content)
	test:SetSize(90, 22)
	test:SetText(L["Test"])
	stack:Add(test, "label")
	kit.Tooltip(test, L["Shows a sample of each kind where yours show."])
	test:SetScript("OnClick", function()
		for index, sample in ipairs(SAMPLES) do
			C_Timer.After((index - 1) * 0.35, function() ns.SelfTextSample(sample[1], sample[2], sample[3]) end)
		end
	end)
	test.Refresh = function(self) self:SetEnabled(Ours() and true or false) end
	kit.AddControl(test)

	stack:Header(content, L["General"])
	rows.Choices(L["Who draws it:"], "selfTextBy", {
		{ "ours", L["Ours"], L["Ours, with this page's look and place."] },
		{ "game", L["The game's"], L["The game's own, as it normally is."] },
		{ "none", L["None"], L["No combat text about you."] },
	})
	local follow = stack:Add(kit.Check(content, "selfTextFollow", L["Follow the Shoulder Cam"],
		L["Sits beside you while the camera is over your shoulder."]), "check")
	kit.GreyUnless(follow, Ours)
	rows.Choices(L["Side:"], "selfTextSide", {
		{ "over", L["Over you"], L["Right over you."] },
		{ "free", L["Free side"], L["On your side away from the screen's middle."] },
		{ "split", L["Split"], L["Taken on one side, gained on the other."] },
	}, Ours)
	rows.Choices(L["Motion:"], "selfTextMotion", {
		{ "up", L["Up"], L["Rises, as the game's."] },
		{ "down", L["Down"], L["Falls."] },
		{ "arc", L["Arc"], L["Curves out to the side."] },
		{ "pop", L["Pop"], L["Crits start big and settle."] },
	}, Ours)
	rows.Slider("selfTextHeight", L["Height"], -300, 300, 5, "%d", nil, L["Moves it up or down from your spot."], Ours)
	rows.Slider("selfTextLife", L["Time shown"], 0.6, 4, 0.1, "%.1f sec", nil, L["How long each text stays."], Ours)

	stack:Header(content, L["Look"])
	rows.Font("selfTextFont", L["The text's font."], Ours, { "game", L["The game's"] })
	rows.Choices(L["Edge:"], "selfTextEdge", {
		{ "game", L["Shadow"], L["A drop shadow, as the game's."] },
		{ "edge", L["Outline"], L["A thin outline."] },
		{ "both", L["Both"], L["An outline and a shadow."] },
		{ "none", L["None"], L["No edge."] },
	}, Ours)
	rows.Slider("selfTextSize", L["Size"], 0.5, 3, 0.05, "%.2f", nil, L["How big the text is."], Ours)
	rows.Slider("selfTextCrit", L["Crit size"], 1, 3, 0.1, "%.1f", nil, L["A crit's size, times a hit's."], Ours)

	stack:Header(content, L["Kinds"])
	stack:Note(content, L["Each kind in the game's color, a color of its own, or hidden."], 520)
	for _, group in ipairs(GROUPS) do
		local key = "selfText_" .. group.id .. "Color"
		local last = rows.Choices(group.label, key, {
			{ "game", L["Game's color"], L["The color the game gives it."] },
			{ "custom", L["Own"], L["A color of its own: click the swatch."] },
			{ "off", L["Hidden"], L["Not shown."] },
		}, Ours)
		if last then
			rows.Swatch(last, key, { "selfText_" .. group.id .. "R", "selfText_" .. group.id .. "G",
				"selfText_" .. group.id .. "B" }, L["Its own color."], Ours)
		end
	end

	canvas:SetScript("OnShow", kit.PageShown(function() kit.Refresh() end, content))
	canvas:Hide()
	kit.RegisterSubpage(canvas, "Self Text Style", L["Text on You Style"])
end
