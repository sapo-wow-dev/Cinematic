-- The Style hub's Text on You (Tools/self-combat-text-plan.md, the page's
-- redesign: Tools/self-text-page-plan.md): the game's floating combat text
-- about you ("-26", "+120 [Healer]", "<2 Combo Points>", "Mana Low"), drawn
-- by us beside you, our way. The page: SelfTextPage.lua.
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
-- (ns.ShoulderYouShift, ShoulderCam.lua), eased; else the middle. Across and
-- Height move it from there.
--
-- Boards: the texts are drawn on a board, the screen's (on UIParent) or the
-- page's preview's (its own frame, smaller): the same code draws both, so
-- the preview is what a fight gives.
--
-- Each kind (a group of the game's message kinds) has its own look, each
-- part its General one's till changed: selfText_<kind><Part>.
--
-- The game's Text on Me ticks still decide which kinds it makes at all
-- (Options > Combat): a kind it's told not to show never reaches us.
-- Page off, or its Show in row off here: the game's text as it was.

local _, ns = ...
local L = ns.L
local DEFAULTS = ns.DEFAULTS

DEFAULTS.selfTextStyle = false   -- the page's Enable Page
DEFAULTS.selfTextAlways = true   -- its Show in row's Always (the rest: ROW_KEY's ticks and rule)
DEFAULTS.selfTextBy = "ours"     -- who draws your combat text: "ours", "game" (as it is) or "none"
DEFAULTS.selfTextFollow = true   -- beside you while the Shoulder Cam is over your shoulder
DEFAULTS.selfTextSide = "free"   -- "over" you, your "free" side (away from the screen's middle), "split"
DEFAULTS.selfTextMotion = "up"   -- "up", "down", "arc", "pop"
DEFAULTS.selfTextHeight = 0      -- UI units up from your spot
DEFAULTS.selfTextAcross = 0      -- UI units right from your spot
DEFAULTS.selfTextSize = 1        -- times the base size
DEFAULTS.selfTextCrit = 1.5      -- a crit's size, times a hit's
DEFAULTS.selfTextLife = 1.6      -- seconds a text shows
DEFAULTS.selfTextFade = 0.6      -- of its life, when a text starts fading
DEFAULTS.selfTextShadow = 0.9    -- the shadow's strength (its alpha)
DEFAULTS.selfTextFont = "game"   -- "game": the game's combat text font; else a Style font
DEFAULTS.selfTextEdge = "game"   -- "game" (a drop shadow, as the game's), "edge", "both", "none"
DEFAULTS.selfTextMerge = true    -- the same kind within MERGE_WINDOW: one text, "x3"
DEFAULTS.selfTextMost = 20       -- texts at once (the oldest goes first)
DEFAULTS.selfTextSticky = false  -- crits hold a moment where they popped
DEFAULTS.selfTextLook = "game"   -- the quick look last picked (the page's tiles; changing a part keeps it)

ns.SELF_TEXT_ROW = "style:selfText" -- its Show in row

-- The kinds of text, each a group. crit: it can crit (its Crit size row).
-- taken: on the taken side when Split. tick: the game's Text on Me setting
-- that decides whether it makes this kind at all (read, never set).
local GROUPS = {
	{ id = "damage", label = L["Damage taken"], taken = true, crit = true, color = { 1, 0.1, 0.1 },
		sample = "-26", critSample = "-74" },
	{ id = "miss", label = L["Misses on you"], taken = true, color = { 1, 1, 1 }, sample = "Dodge",
		tick = { "floatingCombatTextDodgeParryMiss_v2" } },
	{ id = "heal", label = L["Heals"], crit = true, color = { 0.1, 1, 0.1 }, sample = "+120", critSample = "+412" },
	{ id = "shield", label = L["Shields"], color = { 0.6, 0.85, 1 }, sample = "Absorb" },
	{ id = "power", label = L["Power gains"], color = { 0.3, 0.55, 1 }, sample = "+20 Mana",
		tick = { "floatingCombatTextEnergyGains_v2" } },
	{ id = "combo", label = L["Combo points"], color = { 1, 0.82, 0 }, sample = "<2 Combo Points>",
		tick = { "floatingCombatTextComboPoints_v2" } },
	{ id = "aura", label = L["Auras gained and lost"], color = { 1, 0.9, 0.4 }, sample = "<Demon Skin>",
		tick = { "floatingCombatTextAuras_v2" } },
	{ id = "alert", label = L["Spell alerts"], color = { 1, 0.82, 0 }, sample = "Overpower!",
		tick = { "floatingCombatTextReactives_v2" } },
	{ id = "low", label = L["Low health and mana"], taken = true, color = { 1, 0.1, 0.1 }, sample = "Mana Low",
		tick = { "floatingCombatTextLowManaHealth_v2" } },
	{ id = "combat", label = L["Entering and leaving combat"], taken = true, color = { 1, 1, 1 }, sample = "+Combat",
		tick = { "floatingCombatTextCombatState_v2" } },
	{ id = "reward", label = L["Reputation and honor"], color = { 0.5, 0.5, 1 }, sample = "+25 Stormwind",
		tick = { "floatingCombatTextRepChanges_v2", "floatingCombatTextHonorGains_v2" } },
	{ id = "other", label = L["Anything else"], color = { 1, 1, 1 }, sample = "Immune" },
}
local BY_ID = {}
-- A kind's parts: Show (on/off), Color ("game", "custom"; "off" from before
-- 2026-11-21 = hidden), R/G/B, Size (times General's), Crit (0: General's),
-- Font, Side, Motion ("general": General's), Sound ("none", or SOUNDS').
local PART_DEFAULTS = { Show = true, Color = "game", Size = 1, Crit = 0, Font = "general", Side = "general",
	Motion = "general", Sound = "none" }
ns.SELF_TEXT_PARTS = { "Show", "Color", "R", "G", "B", "Size", "Crit", "Font", "Side", "Motion", "Sound" }
for _, group in ipairs(GROUPS) do
	BY_ID[group.id] = group
	local key = "selfText_" .. group.id
	for part, value in pairs(PART_DEFAULTS) do DEFAULTS[key .. part] = value end
	DEFAULTS[key .. "R"], DEFAULTS[key .. "G"], DEFAULTS[key .. "B"] = group.color[1], group.color[2], group.color[3]
end
ns.SELF_TEXT_GROUPS = GROUPS

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

-- Sounds a kind can play as it shows (the screen's only; once per SOUND_GAP).
local SOUNDS = { tick = "IG_MAINMENU_OPTION_CHECKBOX_ON", ping = "MAP_PING", alarm = "RAID_WARNING" }
ns.SELF_TEXT_SOUNDS = SOUNDS

local BASE_SIZE = 24      -- a hit's text at Size 1 (the game's, by eye)
local CLIMB = 90          -- UI units a text moves over its life
local SIDE = 90           -- UI units from you to the side a text sits on
local GAP = 1.1           -- texts on one side kept this many lines apart
local EASE = 10           -- how fast the spot follows you (per second)
local SAME = 0.02         -- seconds: an event and a text this close are one message
local MERGE_WINDOW = 0.5  -- seconds: the same kind this close merges (Merge repeats)
local STICK = 1           -- seconds more a crit holds (Crits stay)
local SOUND_GAP = 0.3     -- seconds: one kind's sound at most this often
local POP_TIME = 0.25     -- seconds a popping crit settles in
local STICKY_LANE = 45     -- UI units a staying crit sits further out
local MIDDLE_Y = 50       -- the game's look: UI units up from the middle (where it draws its own)

local function Secret(v) return issecretvalue and issecretvalue(v) end
local function DB() return ns.db or {} end
local function Part(group, part)
	local value = DB()["selfText_" .. group .. part]
	if value == nil then value = PART_DEFAULTS[part] end
	return value
end
ns.SelfTextPart = Part

-- Its Show in row: read four times a second at most.
local row = { at = -1, on = true }
local function RowOn()
	local db = DB()
	if db.selfTextAlways ~= false then return true end
	local now = GetTime()
	if now - row.at >= 0.25 then
		row.at = now
		local ok, on = pcall(ns.RowOnNow, ns.SELF_TEXT_ROW, false, true)
		row.on = ok and on and true or false
	end
	return row.on
end
local function On() return ns.StyleOn("selfTextStyle") and RowOn() end
local function By() return On() and (DB().selfTextBy or "ours") or "game" end
ns.SelfTextBy = By

-- What's going on, for the page's chips, /cine debug and the tests. fight:
-- this fight's (or the last one's), from its start.
local stats = { copied = 0, shown = 0, dropped = 0, noEvent = 0, merged = 0, kinds = {},
	fight = { copied = 0, shown = 0, dropped = 0 } }
ns.SelfTextStats = stats

-- The game's Text on Me tick for a kind: "on", "off", or nil (no tick: it
-- always comes). Read only ([[no-mirror-blizzard-settings]]).
function ns.SelfTextGameTick(group)
	local ticks = BY_ID[group] and BY_ID[group].tick
	if not ticks then return nil end
	for _, cvar in ipairs(ticks) do
		local ok, value = pcall(GetCVar, cvar)
		if ok and value ~= nil and not Secret(value) and tostring(value) ~= "0" then return "on" end
	end
	return "off"
end

-- Boards -----------------------------------------------------------------------
-- board: { layer (its frame), anchor (the frame the texts' places are from),
-- scale (UI units to the board's), live, pool, you (fn: your spot across, in
-- UI units, from the anchor's middle), preview (no sounds, no stats) }.
local boards = {}
local function NewBoard(layer, anchor, scale, you, preview)
	local board = { layer = layer, anchor = anchor or layer, scale = scale or 1, live = {}, pool = {}, you = you,
		preview = preview }
	boards[#boards + 1] = board
	return board
end

local function FontFile(font)
	local value = font or DB().selfTextFont
	if value and value ~= "game" then
		local file = ns.StyleFontFile and ns.StyleFontFile(value)
		if file then return file end
	end
	local object = _G.CombatTextFont
	local ok, file = pcall(function() return object and object:GetFont() end)
	if ok and type(file) == "string" and not Secret(file) then return file end
	return "Fonts\\FRIZQT__.TTF"
end
ns.SelfTextFontFile = FontFile
local function Edge(fs, size, font)
	local db = DB()
	local edge = db.selfTextEdge or "game"
	local flags = (edge == "edge" or edge == "both") and "OUTLINE" or ""
	fs:SetFont(FontFile(font), size, flags)
	if edge == "game" or edge == "both" then
		fs:SetShadowColor(0, 0, 0, math.max(0, math.min(1, db.selfTextShadow or 0.9)))
		fs:SetShadowOffset(math.max(1, size / 16), -math.max(1, size / 16))
	else
		fs:SetShadowOffset(0, 0)
	end
end

-- Which side a text goes: +1 right, -1 left (from your spot), 0 over you.
local SideOf
ns.SELF_TEXT_SIDE = 90 -- (SIDE, for the page's drag mark)
function ns.SelfTextSideOf(group, youX) return SideOf(group, youX) end
SideOf = function(group, youX)
	local own = Part(group, "Side")
	if own == "over" then return 0 end
	if own == "left" then return -1 end
	if own == "right" then return 1 end
	local side = DB().selfTextSide or "free"
	if side == "over" then return 0 end
	-- (Away from the screen's middle. In it (no Shoulder Cam, or Follow off):
	-- over you, there's no free side; it sat 90 to your right and read off
	-- center, the user 2026-11-21. Split keeps its two sides there: right and left.)
	local x = youX or 0
	local away = x < -1 and -1 or x > 1 and 1 or 0
	if side == "split" then
		local out = away ~= 0 and away or 1
		return BY_ID[group].taken and out or -out
	end
	return away
end

local function Retire(board, index)
	local text = table.remove(board.live, index)
	text:Hide()
	text.born, text.words, text.count = nil, nil, nil
	board.pool[#board.pool + 1] = text
end
local function Clear(board)
	for index = #board.live, 1, -1 do Retire(board, index) end
end

local soundAt = {}
local function Sound(group)
	local sound = Part(group, "Sound")
	local name = SOUNDS[sound]
	local kit = name and _G.SOUNDKIT and _G.SOUNDKIT[name]
	if not kit then return end
	local now = GetTime()
	if soundAt[group] and now - soundAt[group] < SOUND_GAP then return end
	soundAt[group] = now
	pcall(PlaySound, kit, "Master")
end

-- One text on a board: words (secret or not), its group, crit, a color.
-- Gives the text (nil: merged into one already up).
local function Show(board, words, group, crit, r, g, b)
	local db = DB()
	-- (Merge repeats: the same kind, not a crit, just shown: that one counts
	-- it, "x3". The words can't be added up (secret), so it shows the latest.)
	if db.selfTextMerge ~= false and not crit then
		local now = GetTime()
		-- (ns.selfTextMergeWindow: the fight test's own, a run only: real hits
		-- come seconds apart, /cine debug selftextmerge.)
		local window = ns.selfTextMergeWindow or MERGE_WINDOW
		for index = #board.live, 1, -1 do
			local text = board.live[index]
			if text.group == group and not text.crit and text.born and now - text.born <= window then
				local count = (text.count or 1) + 1
				local ok = pcall(text.SetFormattedText, text, "%s x%d", words, count)
				if ok then
					text.count, text.words = count, words
					if not board.preview then
						stats.merged = stats.merged + 1
						if Secret(words) then stats.mergedSecret = (stats.mergedSecret or 0) + 1 end
						stats.lastMerged = text
					end
					return nil
				end
				break
			end
		end
	end
	local most = math.max(1, math.floor(tonumber(db.selfTextMost) or 20))
	while #board.live >= most do Retire(board, 1) end
	local text = table.remove(board.pool) or board.layer:CreateFontString(nil, "OVERLAY")
	local critSize = Part(group, "Crit")
	if not critSize or critSize == 0 then critSize = db.selfTextCrit or 1.5 end
	local size = BASE_SIZE * (db.selfTextSize or 1) * (Part(group, "Size") or 1) * (crit and critSize or 1) * board.scale
	local font = Part(group, "Font")
	Edge(text, math.max(4, math.min(120, size)), font ~= "general" and font or nil) -- (SetFont's top, Forever)
	-- (Blanked before its words: a text that held secret words stays secret
	-- till then, MSBT Forever's finding, read 2026-11-21. After its font: a
	-- new text has none, and SetText with no font errors "Font not set",
	-- Forever 2026-11-21, the page's Test.)
	text:SetText("")
	text:SetTextColor(r, g, b)
	text:SetText(words)
	local motion = Part(group, "Motion")
	text.motion = motion ~= "general" and motion or (db.selfTextMotion or "up")
	-- (A board not drawn yet: where you are now, so its first text picks the right side.)
	if board.youX == nil and board.you then board.youX = board.you() or 0 end
	text.group, text.crit, text.side = group, crit, SideOf(group, board.youX or 0)
	text.born, text.push, text.words, text.count, text.middle = GetTime(), 0, words, 1, nil
	text.sticky = crit and db.selfTextSticky and true or false
	text.line = size * GAP
	-- (Room for it: the texts already on its side pushed along, as the game's.)
	for _, other in ipairs(board.live) do
		if other.side == text.side then other.push = other.push + text.line end
	end
	board.live[#board.live + 1] = text
	text:SetAlpha(1)
	text:Show()
	board.layer:Show()
	if not board.preview then
		stats.shown = stats.shown + 1
		stats.fight.shown = stats.fight.shown + 1
		Sound(group)
	end
	return text
end

-- A text's place at t (0..1 of its life), in UI units from your spot.
local function Offset(text, t)
	local x = text.side * SIDE
	-- (A staying crit: a lane out of the way, so the hits after it climb past,
	-- not through it: run 3's "-74" and "-20" on top of each other.)
	if text.sticky then x = x + (text.side ~= 0 and text.side or 1) * STICKY_LANE end
	local along = t * CLIMB + text.push
	-- (Crits stay: barely move till their last third.)
	if text.sticky then along = text.push + t * CLIMB * math.max(0, (t - 0.66) / 0.34) end
	local motion = text.motion
	if motion == "down" then
		return x, -along
	elseif motion == "arc" then
		local dir = text.side ~= 0 and text.side or 1
		return x + dir * math.sin(t * math.pi / 2) * 60, math.sin(t * math.pi) * 50 + text.push
	elseif motion == "pop" then
		-- (Half the climb, the room between texts whole: halving that too piled
		-- Bold's texts on each other, /cine debug selftextpage run 2.)
		return x, (along - text.push) * 0.5 + text.push
	end
	return x, along
end

local function Update(board, elapsed)
	local db = DB()
	local you = board.you and board.you() or 0
	board.youX = (board.youX or you) + (you - (board.youX or you)) * math.min(1, (elapsed or 0) * EASE)
	local baseX = board.youX + (db.selfTextAcross or 0)
	local baseY = db.selfTextHeight or 0
	local life = math.max(0.3, db.selfTextLife or 1.6)
	local fade = math.max(0.05, math.min(0.98, db.selfTextFade or 0.6))
	local now = GetTime()
	for index = #board.live, 1, -1 do
		local text = board.live[index]
		local own = text.sticky and life + STICK or life
		local t = (now - text.born) / own
		if t >= 1 then
			Retire(board, index)
		else
			local dx, dy = Offset(text, t)
			-- (The game's look: where the game draws it, the middle, whatever
			-- your spot, Across and Height.)
			local x, y = baseX + dx, baseY + dy + (board.lift or 0)
			-- (A board's own middle spot: the preview frames you big, its middle
			-- is your chest; the game draws above your head.)
			if text.middle then x, y = dx, (board.middleY or MIDDLE_Y) + dy end
			text:ClearAllPoints()
			text:SetPoint("CENTER", board.anchor, "CENTER", x * board.scale, y * board.scale)
			text:SetAlpha(t < fade and 1 or (1 - t) / (1 - fade))
			-- (Pop: a crit starts twice its size and settles.)
			if text.SetTextScale then
				local grow = t * own
				text:SetTextScale(text.motion == "pop" and text.crit and grow < POP_TIME and (2 - grow / POP_TIME) or 1)
			end
		end
	end
	if #board.live == 0 then board.layer:Hide() end
end

-- The screen's board, your spot following the Shoulder Cam.
local layer = CreateFrame("Frame", "CinematicSelfText", UIParent)
layer:SetAllPoints(UIParent)
layer:SetFrameStrata("HIGH")
layer:Hide()
local screen = NewBoard(layer, UIParent, 1, function()
	if DB().selfTextFollow ~= false and ns.ShoulderYouShift then return ns.ShoulderYouShift() or 0 end
	return 0
end)
ns.SetOnUpdate(layer, function(_, elapsed) Update(screen, elapsed) end)

-- The page's preview's board: texts on layer, placed from anchor, scale UI
-- units to it, you() your spot across (UI units), lift (UI units) where
-- they start from its middle. Its own update loop.
function ns.SelfTextNewBoard(previewLayer, anchor, scale, you, lift)
	local board = NewBoard(previewLayer, anchor, scale, you, true)
	board.lift = lift
	ns.SetOnUpdate(previewLayer, function(_, elapsed) Update(board, elapsed) end)
	board.Clear = Clear
	return board
end

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

-- A kind's color: its own, or the game's (off its text; nil: its usual).
local function ColorOf(group, region)
	if Part(group, "Color") == "custom" then
		return Part(group, "R") or 1, Part(group, "G") or 1, Part(group, "B") or 1
	end
	if region then
		local ok, r, g, b = pcall(region.GetTextColor, region)
		if ok and not (Secret(r) or Secret(g) or Secret(b)) and type(r) == "number" then return r, g, b end
	end
	local own = BY_ID[group].color
	return own[1], own[2], own[3]
end
ns.SelfTextColorOf = ColorOf
-- Whether a kind shows (its switch; "off" its color before 2026-11-21).
local function Shows(group)
	return Part(group, "Show") ~= false and Part(group, "Color") ~= "off"
end
ns.SelfTextShows = Shows

local function Drop()
	stats.dropped = stats.dropped + 1
	stats.fight.dropped = stats.fight.dropped + 1
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
			if not Shows(group) or By() ~= "ours" then
				Drop()
			else
				local words = message.words
				if words == nil then
					local ok, got = pcall(message.region.GetText, message.region)
					words = ok and got or nil
				end
				if words ~= nil then Show(screen, words, group, crit, ColorOf(group, message.region)) else Drop() end
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
	stats.fight.copied = stats.fight.copied + 1
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
		-- (A new fight: its own counts, for the page's Last fight chip.)
		if event == "PLAYER_REGEN_DISABLED" then stats.fight = { copied = 0, shown = 0, dropped = 0 } end
		Mark("fight")
	end
end)
watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")

-- (Settings changed elsewhere, a profile, Style's own switch, its Show in
-- row: caught up within two seconds.)
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
		Clear(screen)
		wipe(waiting)
	end
end

-- A sample, as a message of that kind would show: on the screen, or on a
-- preview's board (board). Plain words; its color as its look says.
-- Gives the text (nil: merged, or its kind is off).
function ns.SelfTextSample(words, group, crit, board)
	group = BY_ID[group] and group or "other"
	if not Shows(group) then return nil end
	return Show(board or screen, words, group, crit, ColorOf(group, nil))
end
-- The game's own look, as it'd draw it (the preview's The game's): its
-- middle, its font and color, no look of ours.
function ns.SelfTextGameSample(words, group, board)
	group = BY_ID[group] and group or "other"
	local own = BY_ID[group].color
	local saved = {}
	local db = DB()
	for _, key in ipairs({ "selfTextSize", "selfTextFont", "selfTextEdge", "selfTextMotion", "selfTextMerge" }) do
		saved[key] = db[key]
	end
	db.selfTextSize, db.selfTextFont, db.selfTextEdge, db.selfTextMotion, db.selfTextMerge = 1, "game", "game", "up", false
	local text = Show(board or screen, words, group, false, own[1], own[2], own[3])
	for key, value in pairs(saved) do db[key] = value end
	if text then text.side, text.motion, text.middle = 0, "up", true end
	return text
end

-- For the page and tests: how it stands.
function ns.SelfTextState()
	return {
		on = On(), by = By(), hidden = hidden.on, hooked = HookTexts(), live = #screen.live, waiting = #waiting,
		spot = screen.youX or 0, stats = stats, rowOn = RowOn(),
	}
end
ns.selfTextFrames = { layer, settler } -- (the offline test runs just these)
ns.SelfTextScreenBoard = screen
