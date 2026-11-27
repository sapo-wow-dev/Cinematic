-- Style Studio frames: Range Hint, Combat Text and Text on You (the Interface
-- band's Combat group, Tools/style-studio/plan.md sections 7-8, 2026-11-25).
-- Every look setting their pages had, by its db key, in the recipes' order:
--   "range": Range Hint Style (Style/RangeHintStyle.lua): Mark, Text, Background,
--     Motion.
--   "ct": Combat Text Style (Style/CombatTextPage.lua, its texts CombatTextTexts.lua):
--     All texts, then every text of the tree as variants, each its group's till set.
--     Its Who draws stays on the page's General tab (decision 2); its miss words'
--     own words stay under the editor (a typed word: no control kind of the grammar).
--   "self": Text on You Style (Style/SelfTextPage.lua, Forever only): its Default
--     look, then each kind as a part of its own (the kinds have settings Default
--     hasn't, and the other way round). Its Show in: the page's General tab.
local ADDON_NAME, ns = ...
ns.Module("style", function()
local L = ns.L
local Studio = ns.Studio
local R = Studio.R

local function DB() return ns.GetDB() or {} end
-- A field on one key read and written as it's saved (a field, so two rows can
-- share a key: one key packing two settings).
local function Raw(key, default)
	return { get = function() return DB()[key] end, set = function(v) ns.GetDB()[key] = v end, default = default }
end

-- An edge key packing outline and shadow: "game" (a drop shadow, no outline),
-- "both", "edge" (an outline, no shadow), "none". Read and written as two
-- properties, Outline (None/Thin) and Shadow (On/None); the saved words stay.
local EDGE_OF = { game = { 0, "on" }, both = { 1, "on" }, edge = { 1, "none" }, none = { 0, "none" } }
-- (Combat Text's edge on a text under another: Reset writes FOLLOWS, which the
-- field reads as "nothing of its own". Given as the props' inherit; no field
-- ever reads back as it, so it never marks a value as following.)
local FOLLOWS = "<follows>"
local function EdgeWord(outline, shadow)
	if (tonumber(outline) or 0) > 0 then return shadow == "on" and "both" or "edge" end
	return shadow == "on" and "game" or "none"
end
-- get(): the saved edge word; put(word) (put(nil): nothing of its own); usual():
-- the word it has with nothing of its own.
-- (name: the saved key, for /cine find's id: on the Outline field only.)
local function EdgeFields(get, put, usual, name)
	local function Parts(word) return EDGE_OF[word] or EDGE_OF.game end
	return {
		get = function() return Parts(get())[1] end,
		set = function(v) if v == FOLLOWS then put(nil) else put(EdgeWord(v, Parts(get())[2])) end end,
		default = Parts(usual())[1],
		key = name,
	}, {
		get = function() return Parts(get())[2] end,
		set = function(v) if v == FOLLOWS then put(nil) else put(EdgeWord(Parts(get())[1], v)) end end,
		default = Parts(usual())[2],
	}
end

-- =====================================================================================
-- Range Hint
-- =====================================================================================
local RANGE_ART = "Interface\\AddOns\\" .. (ADDON_NAME or "Cinematic") .. "\\Textures\\RangeMark_"
local function Shape(test) return function(db) return test(db.rangeHintShape or "chevron") end end
local Marked = Shape(function(s) return s ~= "none" end)
local Lined = Shape(function(s) return s ~= "none" and s ~= "icon" end)
local Icon = Shape(function(s) return s == "icon" end)
local function Worded(db) return db.rangeHintText ~= "none" end
local function Backed(db) return db.rangeHintBack ~= nil and db.rangeHintBack ~= "none" end

local rangeStages = {}
local function RangeTest()
	local look = ns.RangeHintLook or {}
	local delay = tonumber(look.rangeHintDelay) or 0
	local hide = tonumber(look.rangeHintHideAfter) or 0
	local seconds = delay + (hide > 0 and hide or 2.6) + (tonumber(look.rangeHintFadeOut) or 0) + 0.3
	local previews = {}
	if ns.rangeHintStylePreview then previews[1] = ns.rangeHintStylePreview end
	for _, stage in ipairs(rangeStages) do previews[#previews + 1] = stage end
	for _, preview in ipairs(previews) do
		if preview.TestCycle and preview:IsVisible() then preview.TestCycle() end
	end
	-- (And the real mark on your screen, as your target out of range: its own
	-- Show after and Hide after, UI/RangeHint.lua's Demo.)
	if ns.RangeHint and ns.RangeHint.Demo then ns.RangeHint.Demo(seconds) end
end
-- (Running: the real mark's demo; Stop ends it.)
local function RangeTesting() return ns.RangeHint and ns.RangeHint.Demoing and ns.RangeHint.Demoing() or false end
local function RangeStop() if ns.RangeHint and ns.RangeHint.Demo then ns.RangeHint.Demo(0) end end

-- Its old folder tabs (Mark, Text, Background, Motion) are its parts; each tab's
-- switch ("tabOn:Range Hint Style/look:<n>", UI/RangeHint.lua's ns.RangeStyleTabOn)
-- stays, as its part's first row, its keys under it (a tab is a container):
-- off, what's on it greys and reads its default.
local RANGE_PART_TAB = { mark = 1, text = 2, back = 3, motion = 4 }
local function RangeTabKey(n) return ("tabOn:%s:%d"):format(ns.RANGE_STYLE_TABS or "Range Hint Style/look", n) end
local function RangeTabs(spec)
	local byTab = {}
	for key, tab in pairs(ns.RANGE_STYLE_TAB_OF or {}) do
		byTab[tab] = byTab[tab] or {}
		table.insert(byTab[tab], key)
	end
	for _, part in ipairs(spec.parts) do
		local n = RANGE_PART_TAB[part.id]
		if n then
			local tabKey = RangeTabKey(n)
			if ns.DEFAULTS[tabKey] == nil then ns.DEFAULTS[tabKey] = true end
			ns.SetPageMaster({ tabKey }, "rangeHintStyle")
			ns.SetPageMaster(byTab[n] or {}, tabKey)
			local function On(db) return db[tabKey] ~= false end
			for _, group in ipairs(part.groups) do
				for _, prop in ipairs(group.props) do
					local test = prop.test
					prop.test = function(db, v) return On(db) and (not test or test(db, v)) end
				end
			end
			table.insert(part.groups[1].props, 1, R.Switch(tabKey, L["Enable"],
				{ tip = L["Turns everything on this part on or off; off, it draws as it starts."] }))
		end
	end
	return spec
end

local rangeShows = {
	{ "spell", L["Spell name"], L["The spell's name, like Frostbolt."] },
	{ "words", L["Out of range"], L["The words Out of range."] },
	{ "spellrange", L["Spell and range"], L["The spell and how far it reaches, like Frostbolt (30 yd)."] },
	{ "none", L["None"], L["No words, just the mark."] },
}
-- (Too close needs the interact distance in fights: blocked on retail, so the choice isn't there.)
if not ns.isRetail then
	table.insert(rangeShows, 3, { "farclose", L["Too far / Too close"],
		L["Too far, or Too close for a spell with a minimum range, like a hunter's shots up close."] })
end
local function ShapeTile(value, text, tip)
	local entry = { value = value, text = text, tip = tip }
	if value ~= "icon" and value ~= "none" then entry.texture = RANGE_ART .. value .. "_normal" end
	return entry
end

RangeTabs(ns.StyleFrame("range", {
	label = L["Range Hint"], band = "Interface", sub = "Combat", subRank = 2, page = "Range Hint Style",
	switch = "rangeHintStyle",
	refresh = function()
		if ns.RangeHintRefresh then ns.RangeHintRefresh() end
		if ns.rangeHintStylePreview then ns.rangeHintStylePreview:Refresh() end
	end,
	preview = function(parent, width)
		local stage = ns.MakeRangeHintStylePreview(parent, width)
		rangeStages[#rangeStages + 1] = stage
		return stage
	end,
	test = RangeTest, testing = RangeTesting, stop = RangeStop,
	parts = {
		{ id = "mark", label = L["Mark"], region = function(p) return p.parts and p.parts.shape end, groups = {
			R.Group("Look",
				{ kind = "tiles", label = L["Shape"], key = "rangeHintShape", few = 6, tip = L["The mark's shape."],
					options = {
						ShapeTile("chevron", L["Chevron"], L["A V pointing down."]),
						ShapeTile("double", L["Double"], L["Two chevrons, one over the other."]),
						ShapeTile("dot", L["Dot"], L["A small round dot."]),
						ShapeTile("ring", L["Ring"], L["A thin circle."]),
						ShapeTile("bracket", L["Brackets"], L["A pair of square brackets."]),
						ShapeTile("arrow", L["Arrow"], L["An arrow pointing ahead, toward your target."]),
						ShapeTile("icon", L["Spell icon"], L["The spell's own icon."]),
						ShapeTile("none", L["None"], L["Just the words."]),
					} },
				R.Slider("rangeHintScale", L["Size"], 50, 300, 10, "%", { scale = 100, tip = L["How big the mark is."], test = Marked }),
				R.Choice("rangeHintWeight", L["Line"], { { "thin", L["Thin"] }, { "normal", L["Normal"] }, { "bold", L["Bold"] } },
					{ tip = L["How thick the mark's line is."], test = Lined }),
				R.Color("rangeHintColorBy", L["Color"], {
					{ "custom", L["Custom"], L["The color you pick below."] },
					{ "theme", L["Theme"], L["Your Style theme's accent color."] },
					{ "class", L["Class"], L["Your class's color."] },
					{ "school", L["Spell school"], L["Fire orange, frost blue and so on; a spell it doesn't know keeps your custom color."] },
				}, nil, nil, { tip = L["Where the mark's color comes from."] }),
				R.Swatch(L["Custom color"], { "rangeHintR", "rangeHintG", "rangeHintB" }, { tip = L["The mark's own color."],
					test = function(db) return db.rangeHintColorBy == "custom" or db.rangeHintColorBy == "school" end }),
				R.Slider("rangeHintAlpha", L["Opacity"], 10, 100, 5, "%", { scale = 100, tip = L["How solid the mark is once it's up."] }),
				R.Slider("rangeHintGlow", L["Glow"], 0, 100, 5, "%", { scale = 100, tip = L["A soft halo behind the mark; 0 is none."],
					test = Marked })),
			R.Group("Icon",
				R.Switch("rangeHintIconTint", L["Tint the icon"], { tip = L["The spell's icon in grey, colored like the mark."], test = Icon }),
				R.Switch("rangeHintIconRound", L["Round icon"], { tip = L["Cuts the spell's icon round."], test = Icon })),
		} },
		{ id = "text", label = L["Text"], region = function(p) return p.parts and p.parts.text end, groups = {
			R.Group("Look",
				R.Choice("rangeHintText", L["Shows"], rangeShows, { tip = L["What the words with the mark say."] })),
			R.Group("Text",
				R.Font("rangeHintFont", { first = { "game", L["The game's"] }, test = Worded,
					tip = L["The words' font; names in other alphabets keep the game's."] }),
				R.Slider("rangeHintTextSize", L["Size"], 60, 200, 5, "%", { scale = 100, tip = L["How big the words are."], test = Worded }),
				R.Color("rangeHintTextColor", L["Color"], {
					{ "custom", L["Custom"], L["The color you pick."] },
					{ "mark", L["Same as the mark"] },
					{ "white", L["White"] },
				}, { "rangeHintTextR", "rangeHintTextG", "rangeHintTextB" }, "custom", { tip = L["The words' color."], test = Worded }),
				R.Outline("rangeHintOutline", { test = Worded }),
				R.Shadow("rangeHintShadow", { game = false, test = Worded }),
				R.Choice("rangeHintCase", L["Letters"], { { "asis", L["As is"] }, { "upper", L["CAPITALS"] }, { "lower", L["lowercase"] } },
					{ tip = L["The words as they are, in capitals, or in lowercase."], test = Worded })),
			R.Group("Place",
				R.Choice("rangeHintSide", L["Side"], { { "below", L["Under"] }, { "above", L["Over"] }, { "left", L["Left"] },
					{ "right", L["Right"] } }, { tip = L["Where the words sit by the mark."],
					test = function(db) return Worded(db) and db.rangeHintShape ~= "none" end }),
				R.Slider("rangeHintGap", L["Gap"], -10, 20, 1, "px", { tip = L["Space between the mark and the words."],
					test = function(db) return Worded(db) and db.rangeHintShape ~= "none" end })),
		} },
		{ id = "back", label = L["Background"], region = function(p) return p.parts and p.parts.back and p.parts.back[2] end, groups = {
			R.Group("Border",
				R.Choice("rangeHintBorder", L["Border"], {
					{ "none", L["None"] },
					{ "thin", L["Thin"], L["A thin dark line round it."] },
					{ "mark", L["Mark's color"], L["A thin line in the mark's color."] },
				}, { tip = L["A line round the background."], test = function(db) return db.rangeHintBack ~= "pill" end })),
			R.Group("Background",
				R.Choice("rangeHintBack", L["Background"], {
					{ "none", L["None"], L["Just the mark, over the world."] },
					{ "pill", L["Soft pill"], L["A dark rounded bar behind it."] },
					{ "panel", L["Panel"], L["A flat panel in your theme's color."] },
				}, { tip = L["What's behind the mark and its words."] }),
				R.Slider("rangeHintBackAlpha", L["Opacity"], 10, 100, 5, "%", { scale = 100, tip = L["How dark it is behind the mark."],
					test = Backed }),
				R.Slider("rangeHintPad", L["Padding"], 0, 20, 1, "px", { tip = L["Space round the mark and its words."], test = Backed })),
		} },
		{ id = "motion", label = L["Motion"], groups = {
			R.Group("Motion",
				R.Slider("rangeHintFadeIn", L["Fade in"], 0, 1500, 50, "ms", { scale = 1000, tip = L["How long it takes to come up; 0 is at once."] }),
				R.Slider("rangeHintFadeOut", L["Fade out"], 0, 1500, 50, "ms", { scale = 1000, tip = L["How long it takes to go; 0 is at once."] }),
				R.Slider("rangeHintDelay", L["Show after"], 0, 1000, 50, "ms", { scale = 1000,
					tip = L["How long out of range before it shows, so it doesn't flicker at the edge."] }),
				R.Choice("rangeHintEnter", L["Comes in"], {
					{ "fade", L["Fade"], L["Just fades in."] },
					{ "rise", L["Rise"], L["Fades in, rising a little."] },
					{ "grow", L["Grow"], L["Fades in, growing a little."] },
				}, { tip = L["How it comes up."] }),
				R.Choice("rangeHintPulse", L["Pulse"], {
					{ "off", L["Off"] },
					{ "start", L["First 3 seconds"], L["Breathes gently as it comes up, then holds still."] },
					{ "always", L["Always"], L["Breathes gently the whole time it's up."] },
				}, { tip = L["Whether it breathes while it's up."] }),
				R.Slider("rangeHintHideAfter", L["Hide after"], 0, 30, 1, "s", {
					tip = L["Goes again after this long out of range, till you're back in range; 0 stays."] })),
		} },
	},
}))

-- =====================================================================================
-- Combat Text
-- =====================================================================================
local CT = ns.CombatTexts
if CT then
	-- A text's setting: All texts' by its own key; any other's a field, what
	-- applies (its own, else its group's), its own once set, its usual its default.
	local function Field(id, setting)
		if id == nil or id == "all" then return CT.Key("all", setting) end
		local field = CT.Field(id, setting)
		field.default = (CT.Usual(id, setting))
		return field
	end
	local function F(setting) return function(v) return Field(v, setting) end end
	-- (A cast's growth: only texts with a cast, spells and heals, and the groups over them.)
	local function Casts(_, v)
		if v == nil or v == "all" or v == "damage" then return true end
		local step = CT.NODE[v]
		for _ = 1, 8 do
			if not step then return false end
			if step.id == "spell" or step.id == "heal" then return true end
			step = step.parent and CT.NODE[step.parent]
		end
		return false
	end
	-- (A setting of All texts' alone: on another text, the same key, never counted as its own.)
	local function AllOnly(key)
		return function(v)
			if v == nil or v == "all" then return key end
			return { get = function() return Studio.Get(key) end, set = function(x) Studio.Put(key, x) end, default = Studio.Get(key) }
		end
	end
	-- Edge: Outline and Shadow (CombatTextTexts' Edge words).
	local function EdgeOf(id)
		local function Get()
			if id == nil or id == "all" then return DB().combatTextEdge or ns.DEFAULTS.combatTextEdge end
			return (CT.Get(id, "Edge"))
		end
		local function Put(word)
			if id == nil or id == "all" then ns.GetDB().combatTextEdge = word or ns.DEFAULTS.combatTextEdge
			else CT.Field(id, "Edge").set(word) end
		end
		local function Usual()
			if id == nil or id == "all" then return ns.DEFAULTS.combatTextEdge end
			return (CT.Usual(id, "Edge"))
		end
		return EdgeFields(Get, Put, Usual)
	end
	-- Color: its group's, or its own (the color picked by the button under it).
	local function ColorMode(id)
		if id == nil or id == "all" then
			return { get = function() return "own" end, set = function(v)
				if v == "follows" then
					local db = ns.GetDB()
					for _, c in ipairs({ "R", "G", "B" }) do db[CT.Key("all", c)] = ns.DEFAULTS[CT.Key("all", c)] end
				end
			end, default = "own" }
		end
		return {
			get = function() return DB()[CT.Key(id, "R")] ~= nil and "own" or "follows" end,
			set = function(v)
				local db = ns.GetDB()
				if v == "own" then
					local now = CT.Color(id)
					for i, c in ipairs({ "R", "G", "B" }) do db[CT.Key(id, c)] = now[i] end
				else
					for _, c in ipairs({ "R", "G", "B" }) do db[CT.Key(id, c)] = nil end
				end
			end,
			default = "follows",
		}
	end
	-- Its color's keys (the Custom swatch): All texts' by key, any other's its own
	-- keys as saved (nil while it follows its group: the swatch is hidden then).
	local colorKeys = {}
	local function ColorKeys(v)
		local id = v or "all"
		if not colorKeys[id] then
			local list = {}
			for i, c in ipairs({ "R", "G", "B" }) do
				local key = CT.Key(id, c)
				list[i] = id == "all" and key or Raw(key)
			end
			colorKeys[id] = list
		end
		return colorKeys[id]
	end

	-- The variants: the tree, each named by its path (All texts and Damage left out of it).
	local function PathLabel(node)
		local names, step = {}, node
		for _ = 1, 6 do
			if not step or step.id == "all" or step.id == "damage" then break end
			table.insert(names, 1, CT.Label(step.id))
			step = step.parent and CT.NODE[step.parent]
		end
		return #names > 0 and table.concat(names, " > ") or CT.Label(node.id)
	end
	local variants = {}
	for _, node in ipairs(CT.NODES) do variants[#variants + 1] = { id = node.id, label = PathLabel(node) } end

	-- The quick settings (the page's old Quick settings rows), as Looks: each
	-- writes many texts at once, one Undo step. A value nil: written through a
	-- clear (CLEAR saves nothing, as the old rows' nil).
	local CLEAR = "<clear>"
	local function Clear(key)
		local field = {
			get = function() local v = DB()[key] if v == nil then return CLEAR end return v end,
			set = function(v) ns.GetDB()[key] = (v ~= CLEAR) and v or nil end,
		}
		return function() return field end
	end
	local function Look(id, label, tip, build)
		local values = {}
		build(function(key, value)
			if value == nil then values[Clear(key)] = CLEAR else values[key] = value end
		end)
		return { id = id, label = label, tip = tip, values = values }
	end
	local HITS = { swing = true, swingGlance = true, ability = true, spell = true, heal = true }
	local SWINGS = { swing = true, swingCrit = true, miss = true }
	local function Shows(write, off)
		for _, node in ipairs(CT.NODES) do
			if not node.pet then write(CT.Key(node.id, "Show"), not (off and off[node.id]) and true or false) end
		end
	end
	local function Schools(write, color)
		for _, node in ipairs(CT.NODES) do
			if node.school then
				for i, c in ipairs({ "R", "G", "B" }) do write(CT.Key(node.id, c), color and node.color[i] or nil) end
			end
		end
	end
	local KIND = { Size = { "Size", "CastSize" }, Time = { "Time", "CastTime" } }
	local function Kind(write, setting, on)
		write(CT.Key("swing", KIND[setting][1]), on and 0.8 or nil)
		for _, id in ipairs({ "spell", "heal" }) do write(CT.Key(id, KIND[setting][2]), on and 0.15 or nil) end
	end
	local function Scale(write, setting, value) write(CT.Key("all", setting), value or ns.DEFAULTS[CT.Key("all", setting)]) end
	local looks = {
		Look("yellow", L["All yellow"], L["Every spell in the game's yellow."], function(w) Schools(w, false) end),
		Look("school", L["By school"], L["Each spell school in its own color: fire orange, frost blue."], function(w) Schools(w, true) end),
		Look("everything", L["Every text on"], L["Every text on."], function(w) Shows(w) end),
		Look("crits", L["Crits and misses"], L["Shows only your crits and misses, with plain hits and heals turned off."],
			function(w) Shows(w, HITS) end),
		Look("noswings", L["No swings"], L["Turns off your auto attacks, along with their crits and misses."],
			function(w) Shows(w, SWINGS) end),
		Look("gamesize", L["Game's size"], L["As big as the game's numbers."], function(w) Scale(w, "Size") Kind(w, "Size", false) end),
		Look("smaller", L["Smaller"], L["Every number is three quarters of the game's size."],
			function(w) Scale(w, "Size", 0.75) Kind(w, "Size", false) end),
		Look("sizecast", L["Size by hit kind"], L["Swings are smaller, and spells and heals get bigger the longer their cast."],
			function(w) Scale(w, "Size") Kind(w, "Size", true) end),
		Look("gametime", L["Game's duration"], L["On screen as long as the game's numbers."],
			function(w) Scale(w, "Time") Kind(w, "Time", false) end),
		Look("shorter", L["Shorter"], L["Every number stays three quarters as long as the game's."],
			function(w) Scale(w, "Time", 0.75) Kind(w, "Time", false) end),
		Look("timecast", L["Duration by hit kind"], L["Swings stay up for less time, and spells and heals stay longer the longer their cast."],
			function(w) Scale(w, "Time") Kind(w, "Time", true) end),
	}

	local MOVES = {
		{ "up", L["Up"], L["Rises, as the game's."] },
		{ "down", L["Down"], L["Falls."] },
		{ "arcleft", L["Arc left"], L["Rises, curving left."] },
		{ "arcright", L["Arc right"], L["Rises, curving right."] },
		{ "fan", L["Fan out"], L["Curves left and right in turn."] },
		{ "stay", L["Stays"], L["Stays where it starts, then fades."] },
	}
	local outlineProp = R.Outline(function(v) return (EdgeOf(v)) end, { max = 1, inherit = FOLLOWS,
		tip = L["A dark edge around the numbers."] })
	local shadowProp = R.Shadow(function(v) return select(2, EdgeOf(v)) end, { game = false, inherit = FOLLOWS,
		tip = L["The drop shadow up and to the right, as the game's."] })
	local numberStyles = {}
	for _, each in ipairs(CT.NUMBER_STYLES) do numberStyles[#numberStyles + 1] = { value = each[1], text = each[2] } end

	ns.StyleFrame("ct", {
		label = L["Combat Text"], band = "Interface", sub = "Combat", subRank = 2, page = "Combat Text Style",
		switch = "combatTextStyle",
		refresh = function() if ns.RefreshCombatTextStyle then ns.RefreshCombatTextStyle() end end,
		preview = function(parent, width)
			return ns.MakeCombatTextPreview and ns.MakeCombatTextPreview(parent, width, function()
				local win = ns.StyleStudioWindow and ns.StyleStudioWindow()
				return win and win.host and win.host.f and win.host.f.id == "ct" and win.host.variant or nil
			end)
		end,
		variants = variants,
		looks = looks,
		-- Why it isn't showing: our numbers off by an old setting (nothing on the
		-- page writes it: Core.lua's hideWorldText move), its Look tab off, or the
		-- game drawing every kind (the General tab's Who draws).
		status = function(db)
			if db.combatTextNumbers == false then
				return L["Our numbers are off, from an older setting."], "warn", L["Turn on"], function()
					Studio.Apply(Studio.frames.ct, L["Combat Text"] .. " · " .. L["Turn on"], { { "combatTextNumbers", true } })
				end
			end
			if db["tabOn:Combat Text Style/page:2"] == false then
				return L["Off: the Look tab is switched off."], "off", L["Turn on"], function()
					Studio.Apply(Studio.frames.ct, L["Combat Text"] .. " · " .. L["Turn on"], { { "tabOn:Combat Text Style/page:2", true } })
				end
			end
			if db["tabOn:Combat Text Style/page:1"] == false then
				return L["Off: the General tab is switched off."], "off", L["Turn on"], function()
					Studio.Apply(Studio.frames.ct, L["Combat Text"] .. " · " .. L["Turn on"], { { "tabOn:Combat Text Style/page:1", true } })
				end
			end
			local ours = false
			for _, key in ipairs({ "combatTextDamageBy", "combatTextHealBy", "combatTextPetBy" }) do
				local by = db[key]
				if by == nil or by == "ours" or (key == "combatTextPetBy" and by == "group") then ours = true end
			end
			if not ours then return L["The game draws every kind, or none: see Who draws on the General tab."], "warn" end
		end,
		parts = {
			{ id = "text", label = L["Text"], region = function(p) return p.plate end, groups = {
				R.Group("Look",
					R.Switch(function(v) return CT.Key(v or "all", "Show") end, L["Shown"],
						{ tip = L["Shows or hides it. Turning it off hides the texts under it too, except crits, which have their own."] })),
				R.Group("Text",
					R.Font(F("Font"), { first = { "game", L["The game's"] }, tip = L["The font for it."] }),
					R.Slider(F("Size"), L["Size"], 50, 300, 5, "%", { scale = 100, tip = L["How big it is compared to the game's."] }),
					R.Slider(F("CritScale"), L["Crit size"], 100, 300, 5, "%", { scale = 100, tip = L["How big its crits are compared to its hits."] }),
					R.Slider(F("CastSize"), L["Bigger per second of cast"], 0, 50, 5, "%", { scale = 100, shown = Casts,
						tip = L["Spells and heals only: longer casts show bigger numbers, up to 150%."] }),
					outlineProp, shadowProp),
			} },
			{ id = "color", label = L["Color"], groups = {
				R.Group("Text",
					R.Color(ColorMode, L["Color"], { { "follows", L["Its group's"], L["The color of the text it's under."] },
						{ "own", L["Custom"], L["A color of its own."] } }, ColorKeys, "own", {
						tip = L["Its color: its group's or its own."] })),
			} },
			{ id = "place", label = L["Place"], groups = {
				R.Group("Place",
					R.Choice(F("Start"), L["Starts"], { { "name", L["Over the name"], L["Where the game's hits start."] },
						{ "bar", L["Over the bar"], L["Low over the health bar, where the game's crits sit."] } },
						{ tip = L["Where on the nameplate it starts."] }),
					R.Slider(F("X"), L["Left/right"], -150, 150, 2, "px", { tip = L["Moves it left or right."] }),
					R.Slider(F("Y"), L["Down/up"], -80, 150, 2, "px", { tip = L["Moves it up or down."] })),
			} },
			{ id = "motion", label = L["Motion"], groups = {
				R.Group("Motion",
					R.Choice(F("Move"), L["Moves"], MOVES, { tip = L["Which way it goes."] }),
					R.Slider(F("Climb"), L["Climb"], 0, 300, 10, "%", { scale = 100, tip = L["How far it moves compared to the game's."] }),
					R.Slider(F("Time"), L["Time on screen"], 30, 300, 10, "%", { scale = 100, tip = L["How long it stays compared to the game's."] }),
					R.Slider(F("CastTime"), L["Longer per second of cast"], 0, 50, 5, "%", { scale = 100, shown = Casts,
						tip = L["Spells and heals only: longer casts stay longer, up to 150%."] }),
					R.Slider(F("Fade"), L["Fades from"], 10, 95, 5, "%", { scale = 100, tip = L["How far into its time on screen it starts to fade."] }),
					R.Switch(F("Pop"), L["Pops in"], { tip = L["Grows big for a moment, then settles, like the game's crits."] })),
			} },
			-- (All texts' own few: every text's at once, whichever text is shown.)
			{ id = "every", label = L["All texts"], groups = {
				R.Group("Text",
					R.Drop(AllOnly(CT.Key("all", "Numbers")), L["Number style"], numberStyles, { client = "retail",
						tip = L["How numbers are written: 22,245 as 22.2K, 22K, 22, or divided down."] }),
					R.Switch(AllOnly(CT.Key("all", "Tags")), L["Tag hits that partly landed"],
						{ tip = L["Adds (Glancing), (Blocked) or (Resisted) after the number."] })),
				R.Group("Place",
					R.Choice(AllOnly(CT.Key("all", "Together")), L["Hits landing together"], {
						{ "side", L["Side by side"], L["Side by side, as the game's."] },
						{ "stack", L["Stacked"], L["Each one a little higher than the last."] },
						{ "top", L["On top"], L["All in one spot."] },
						{ "room", L["Make room"], L["Crits and your casts show in the middle, and the rest move aside."] },
					}, { tip = L["How hits landing at once sit."] })),
				R.Group("Motion",
					R.Switch(AllOnly("combatTextKeepLast"), L["Last hit stays on screen"],
						{ tip = L["A dying mob's last number finishes above the middle of the screen."] })),
			} },
		},
	})
end

-- =====================================================================================
-- Text on You
-- =====================================================================================
local GROUPS = ns.SELF_TEXT_GROUPS
local KINDS_TAB = "tabOn:Self Text Style/page:3"
if GROUPS then
	-- (Its tab is gone from the page: its switch kept, under the page's, the kinds' keys under it.)
	if ns.DEFAULTS[KINDS_TAB] == nil then ns.DEFAULTS[KINDS_TAB] = true end
	ns.SetPageMaster({ KINDS_TAB }, "selfTextStyle")
	local kindKeys = {}
	for _, group in ipairs(GROUPS) do
		for _, part in ipairs(ns.SELF_TEXT_PARTS or {}) do kindKeys[#kindKeys + 1] = "selfText_" .. group.id .. part end
	end
	ns.SetPageMaster(kindKeys, KINDS_TAB)
	local function KindsOn(db) return db[KINDS_TAB] ~= false end
	local function Edge()
		return EdgeFields(function() return DB().selfTextEdge or ns.DEFAULTS.selfTextEdge end,
			function(word) ns.GetDB().selfTextEdge = word or ns.DEFAULTS.selfTextEdge end,
			function() return ns.DEFAULTS.selfTextEdge end, "selfTextEdge")
	end
	local edgeOutline, edgeShadow = Edge()
	local function Shadowed(db) return (db.selfTextEdge or "game") == "game" or db.selfTextEdge == "both" end
	local function Page() return ns.selfTextPage or {} end
	local looks = {}
	for _, look in ipairs(ns.SELF_TEXT_LOOKS or {}) do
		looks[#looks + 1] = { id = look.id, label = look.label, tip = L["Sets the font, edge, sizes and motion to %s's."]:format(look.label),
			apply = function() if Page().ApplyLook then Page().ApplyLook(look.id) end end }
	end
	for _, place in ipairs(ns.SELF_TEXT_POSITIONS or {}) do
		looks[#looks + 1] = { id = "place_" .. place.id, label = place.label, tip = L["Sets Side, Height and Across to %s."]:format(place.label),
			apply = function() if Page().ApplyPosition then Page().ApplyPosition(place.id) end end }
	end

	local parts = {
		{ id = "default", label = L["Default"], region = function(p) return p.cineHandle end, groups = {
			-- (The old Kinds tab's switch, a tab container's: off, every kind looks as
			-- Default. The kinds' keys stay under it, SelfTextPage.lua.)
			R.Group("Look",
				R.Switch(KINDS_TAB, L["Kinds' own looks"], { tip = L["Off, every kind looks as Default."] })),
			R.Group("Text",
				R.Font("selfTextFont", { tip = L["The text's font."] }),
				R.Slider("selfTextSize", L["Size"], 50, 300, 5, "%", { scale = 100, tip = L["How big the text is."] }),
				R.Slider("selfTextCrit", L["Crit size"], 100, 300, 10, "%", { scale = 100, tip = L["A crit's size, next to a hit's."] }),
				R.Outline(function() return edgeOutline end, { max = 1, tip = L["A thin outline around the letters."] }),
				R.Shadow(function() return edgeShadow end, { game = false, tip = L["A drop shadow, as the game's."] }),
				R.Slider("selfTextShadow", L["Shadow darkness"], 0, 100, 5, "%", { scale = 100, tip = L["How dark the shadow is."],
					test = Shadowed })),
			R.Group("Place",
				R.Choice("selfTextSide", L["Side"], {
					{ "over", L["Over you"], L["Right over you."] },
					{ "free", L["Free side"], L["On your side away from the screen's middle."] },
					{ "split", L["Split"], L["Taken on one side, gained on the other."] },
					{ "lanes", L["Lanes"], L["Heals on your left, damage on your right, the rest over you."] },
				}, { tip = L["Where it sits by you."] }),
				R.Switch("selfTextFollow", L["Follow the Shoulder Cam"], { tip = L["Sits beside you while the camera is over your shoulder."] }),
				R.Slider("selfTextAcross", L["Left/right"], -300, 300, 5, "px", { tip = L["Moves it left or right from your spot; or drag the gold mark."] }),
				R.Slider("selfTextHeight", L["Down/up"], -300, 300, 5, "px", { tip = L["Moves it up or down from your spot; or drag the gold mark."] })),
			R.Group("Motion",
				R.Choice("selfTextMotion", L["Motion"], {
					{ "up", L["Up"], L["Rises, as the game's."] },
					{ "down", L["Down"], L["Falls."] },
					{ "arc", L["Arc"], L["Curves out to the side."] },
					{ "pop", L["Pop"], L["Crits start big and settle."] },
				}, { tip = L["How each text moves."] }),
				R.Slider("selfTextLife", L["Time shown"], 0.6, 4, 0.1, "s", { tip = L["How long each text stays."] }),
				R.Slider("selfTextFade", L["Fades from"], 20, 95, 5, "%", { scale = 100, tip = L["When in its time a text starts fading."] })),
		} },
	}
	for _, group in ipairs(GROUPS) do
		local id = group.id
		local function Key(part) return "selfText_" .. id .. part end
		-- (Shown: on again brings back a color "off" from before 2026-11-21.)
		local show = {
			get = function() return DB()[Key("Show")] end,
			set = function(v)
				local db = ns.GetDB()
				db[Key("Show")] = v
				if v and db[Key("Color")] == "off" then db[Key("Color")] = "game" end
			end,
			default = ns.DEFAULTS[Key("Show")],
			key = Key("Show"), -- (its /cine find id)
		}
		-- (Crit size 0: Default's; else its own, times a hit.)
		local critFrom = {
			get = function() return (tonumber(DB()[Key("Crit")]) or 0) == 0 and "default" or "own" end,
			set = function(v)
				local db = ns.GetDB()
				if v == "default" then db[Key("Crit")] = 0
				elseif (tonumber(db[Key("Crit")]) or 0) == 0 then db[Key("Crit")] = db.selfTextCrit or ns.DEFAULTS.selfTextCrit end
			end,
			default = "default",
		}
		local looksGroup = { R.Switch(function() return show end, L["Shown"], { tip = L["Shows %s."]:format(group.label) }) }
		if group.tick then
			looksGroup[#looksGroup + 1] = R.Note(L["The game makes it only with its Text on Me tick on (Options > Combat)."])
		end
		local text = {
			R.Font(Key("Font"), { first = { "general", L["Default's"] }, tip = L["Its font."] }),
			R.Slider(Key("Size"), L["Size"], 50, 250, 5, "%", { scale = 100, tip = L["Its size, next to Default's."] }),
		}
		if group.crit then
			text[#text + 1] = R.Choice(function() return critFrom end, L["Crit size"], { { "default", L["Default's"] }, { "own", L["Custom"] } },
				{ tip = L["Its crits' size: Default's, or its own."] })
			text[#text + 1] = R.Slider(Key("Crit"), L["Its crit size"], 10, 300, 10, "%", { scale = 100,
				tip = L["Its crits' size, next to a hit's."], test = function(db) return (tonumber(db[Key("Crit")]) or 0) ~= 0 end })
		end
		parts[#parts + 1] = { id = id, label = group.label, groups = {
			{ recipe = "Look", props = looksGroup },
			R.Group("Text",
				R.Color(Key("Color"), L["Color"], { { "game", L["The game's"], L["The color the game gives it."] },
					{ "custom", L["Custom"], L["A color of its own."] } }, { Key("R"), Key("G"), Key("B") }, "custom",
					{ tip = L["Its color."] }),
				unpack(text)),
			R.Group("Place",
				R.Choice(Key("Side"), L["Side"], {
					{ "general", L["Default's"], L["As Default's Side."] },
					{ "over", L["Over you"], L["Right over you."] },
					{ "left", L["Left"], L["On your left."] },
					{ "right", L["Right"], L["On your right."] },
				}, { tip = L["Where it sits by you."] })),
			R.Group("Motion",
				R.Choice(Key("Motion"), L["Motion"], {
					{ "general", L["Default's"], L["As Default's Motion."] },
					{ "up", L["Up"], L["Rises."] }, { "down", L["Down"], L["Falls."] },
					{ "arc", L["Arc"], L["Curves out."] }, { "pop", L["Pop"], L["Crits start big."] },
				}, { tip = L["How it moves."] })),
			R.Group("Sound",
				R.Choice(Key("Sound"), L["Sound"], {
					{ "none", L["None"], L["No sound."] },
					{ "tick", L["Tick"], L["A soft tick."] },
					{ "ping", L["Ping"], L["The map's ping."] },
					{ "alarm", L["Alarm"], L["The raid warning sound."] },
				}, { tip = L["A sound as it shows."] })),
		} }
	end
	-- (The kinds grey while Kinds' own looks is off: it turns them on.)
	for i = 2, #parts do
		for _, group in ipairs(parts[i].groups) do
			for _, prop in ipairs(group.props) do
				local test = prop.test
				prop.test = function(db, v) return KindsOn(db) and (not test or test(db, v)) end
			end
		end
	end

	ns.StyleFrame("self", {
		label = L["Text on You"], band = "Interface", sub = "Combat", subRank = 2, page = "Self Text Style",
		switch = "selfTextStyle",
		-- (WoW Forever only for now: no page on retail.)
		shown = function() return not ns.isRetail end,
		refresh = function() if ns.RefreshSelfTextStyle then ns.RefreshSelfTextStyle() end end,
		preview = function(parent, width) return ns.MakeSelfTextStage and ns.MakeSelfTextStage(parent, width) end,
		looks = looks,
		status = function(db)
			if db["tabOn:Self Text Style/page:2"] == false then
				return L["Off: the Look tab is switched off."], "off", L["Turn on"], function()
					Studio.Apply(Studio.frames.self, L["Text on You"] .. " · " .. L["Turn on"], { { "tabOn:Self Text Style/page:2", true } })
				end
			end
			local by = db.selfTextBy or "ours"
			if by == "game" then return L["The game draws it: see Who draws it on the General tab."], "warn" end
			if by == "none" then return L["Off: Who draws it is None, on the General tab."], "warn" end
		end,
		parts = parts,
	})
end
end) -- (ns.Module "style")
