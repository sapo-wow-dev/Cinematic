-- Style Studio frames: the Visions band's World and RP looks (Tools/style-studio/plan.md
-- section 7): Quest (Quest Talk Style, Style/QuestTalkStyle.lua), Quest Item Button
-- (Quest Item Style, Style/QuestItemStyle.lua), Roll (Roll Style, Style/RollStyle.lua)
-- and Cards (Card Styles, Visions/CardsPage.lua: the card types as variants). Every look
-- setting each page had, by its db key, in the recipes' order.
local _, ns = ...
ns.Module("style", function()
local L = ns.L
local Studio = ns.Studio
local R = Studio.R

-- A button to another page (a status line's).
local function Open(page)
	return function() if ns.OpenOptions then ns.OpenOptions(page) end end
end
-- A preview's i-th frame (the parts' hotspots, on previews made in the Visions' files).
local function Child(frame, i)
	if not (frame and frame.GetChildren) then return nil end
	return (select(i, frame:GetChildren()))
end

-- Quest (Quest Talk Style) ---------------------------------------------------------------
local function QuestPanels(db) return db.questTalkStyle ~= "none" end
-- (The list's height on the screen: a change drops the spot it was dragged to, so the
-- box decides again, as the page's box did.)
local questListY = {
	get = function() local db = ns.GetDB() return db and db.questTalkListY end,
	set = function(value)
		local db = ns.GetDB()
		if not db then return end
		db.questTalkListY = value
		db.questTalkSpot = nil
	end,
	default = ns.DEFAULTS.questTalkListY,
}

ns.StyleFrame("quest", {
	label = L["Quest"], band = "Visions", sub = "World", subRank = 2, page = "Quest Talk Style", switch = "questTalkStyled",
	refresh = function() if ns.RefreshQuestTalkStyle then ns.RefreshQuestTalkStyle() end end,
	preview = function(parent, width) return ns.MakeQuestTalkPreview(parent, width) end,
	status = function(db)
		if not db.questTalk then
			return L["Custom dialogue frames are off on the Vision tab: the game's windows show."], "warn", L["Open"],
				Open("Quest Vision")
		end
	end,
	parts = {
		{ id = "panels", label = L["Panels"], region = function(p) return Child(p, 1) end, groups = {
			R.Group("Look",
				R.Switch("questTalkPortrait", L["Portrait"], { tip = L["Shows the NPC's round portrait on the bubble's top left corner."] })),
			R.Group("Background",
				R.Choice("questTalkStyle", L["Panels"], {
					{ "parchment", L["Parchment"], L["Like the quest window's page."] },
					{ "bubble", L["Chat bubble"], L["The game's own chat bubble."] },
					{ "dark", L["Dark"] },
					{ "none", L["None"], L["Just the words, with no bubble. An outline makes them easier to read."] },
				}, { tip = L["What's behind the words."] }),
				R.Slider("questTalkAlpha", L["Opacity"], 20, 100, 5, "%", { scale = 100, tip = L["How see-through the panels are."],
					test = QuestPanels }),
				R.Switch("questTalkCardSame", L["Card matches"], { tip = L["Gives the quest card and reply list the bubble's look."] })),
		} },
		{ id = "words", label = L["Words"], region = function(p) return Child(p, 2) end, groups = {
			R.Group("Text",
				R.Font("questTalkFont", { tip = L["The font for the words."] }),
				R.Slider("questTalkTextSize", L["Size"], 70, 150, 5, "%", { scale = 100,
					tip = L["How big the words are, next to their usual size."] }),
				R.Color("questTalkTextColor", L["Color"], { { "game", L["The game's"] }, { "custom", L["Custom"] } },
					{ "questTalkTextR", "questTalkTextG", "questTalkTextB" }, "custom",
					{ tip = L["The bubble's text in a color of your own. The quest card keeps its own color."] }),
				R.Outline("questTalkOutline", { tip = L["A black border around the letters, for light text with no panel behind it."] }),
				R.Shadow("questTalkShadow"),
				R.Slider("questTalkNumberAlpha", L["Numbers"], 10, 100, 5, "%", { scale = 100,
					tip = L["How faded the page count (2 / 3) and the numbers by the replies and buttons are."] })),
		} },
		{ id = "layout", label = L["Layout"], groups = {
			R.Group("Place",
				R.Slider("questTalkScale", L["Size"], 70, 150, 5, "%", { scale = 100,
					tip = L["The size of the bubble and the reply list. Their text grows with them."] }),
				R.Slider("questTalkLines", L["Bubble height"], 3, 15, 1, L["lines"], { tip = L["How many lines of words the bubble holds."] }),
				R.Drop("questTalkCardSide", L["Quest card"], {
					{ "below", L["Below"] }, { "side", L["Side"] }, { "right", L["Right"] }, { "left", L["Left"] },
					{ "separate", L["Separate"] },
				}, { tip = L["Where the quest card goes next to the bubble."] }),
				R.Slider(questListY, L["List height"], 20, 80, 1, "%", { scale = 100,
					tip = L["How far up the screen the list of replies starts."],
					test = function(db) return db.questTalkCardSide == "separate" end })),
		} },
	},
})

-- Quest Item Button (Quest Item Style) ---------------------------------------------------
local function Glowing(db) return db.questItemGlow ~= "none" end
local function ItemOutlined(db)
	local value = db.questItemOutline
	if value == -1 then value = ns.GeneralStyleValue("questItemOutline") end
	return (tonumber(value) or 0) > 0
end

ns.StyleFrame("qitem", {
	label = L["Quest Item Button"], band = "Visions", sub = "World", subRank = 2, page = "Quest Item Style",
	switch = "questItemStyle",
	refresh = function() if ns.RefreshQuestItemStyle then ns.RefreshQuestItemStyle() end end,
	preview = function(parent, width) return ns.MakeQuestItemPreview(parent, width) end,
	status = function(db)
		if not db.questItemButton then
			return L["The quest item button is off on the Vision tab."], "warn", L["Open"], Open("Quest Vision")
		end
	end,
	parts = {
		{ id = "button", label = L["Button"], region = function(p) return p.ready end, groups = {
			R.Group("Look",
				R.Slider("questItemSize", L["Size"], 32, 80, 2, "px", { tip = L["The button's width and height."] }),
				R.Choice("questItemShape", L["Shape"], { { "square", L["Square"] }, { "round", L["Round"] } }),
				R.Switch("questItemZoom", L["Zoom icon"], { tip = L["Icons have their own dark border. Zooming in a little cuts it off."] })),
			R.Group("Border", R.Border("questItemFrame", { game = true,
				tip = L["The frame around the button: the game's or one of ours."] })),
		} },
		{ id = "glow", label = L["Ready glow"], region = function(p) return p.ready end, groups = {
			R.Group("Look",
				R.Choice("questItemGlow", L["Glow"], { { "none", L["None"] }, { "soft", L["Soft"], L["A soft halo round it."] },
					{ "edge", L["An edge"], L["A ring of color round it."] } }),
				R.Color("questItemGlowColor", L["Color"], { { "gold", L["Gold"] }, { "custom", L["Custom"] } },
					{ "questItemGlowR", "questItemGlowG", "questItemGlowB" }, "custom", { tip = L["Pick the glow's color."], test = Glowing }),
				R.Note(L["Ready: it's up (you're near the quest's area) and not cooling down."])),
		} },
		{ id = "cooldown", label = L["Cooldown"], region = function(p) return p.cooling end, groups = {
			R.Group("Look",
				R.Choice("questItemCooldown", L["Shown as"], { { "sweep", L["The game's"], L["The game's sweep."] },
					{ "fill", L["Dark fill"], L["A dark fill over the icon, going down as the cooldown runs out."] } }),
				R.Switch("questItemNumbers", L["Seconds left"], { tip = L["The seconds left in the middle of the button while it cools down."] })),
		} },
		{ id = "text", label = L["Text"], region = function(p) return p.cooling end, groups = {
			R.Group("Look",
				R.Switch("questItemKey", L["Key binding"], { tip = L["Shows the key you've bound to it in its top corner."] })),
			R.Group("Text",
				R.Font("questItemFont"),
				R.Color("questItemTextColor", L["Color"], { { "game", L["The game's"] }, { "custom", L["Custom"] } },
					{ "questItemTextR", "questItemTextG", "questItemTextB" }, "custom", { tip = L["Its numbers in a color of your own."] }),
				R.Outline("questItemOutline", { tip = L["A black border around its numbers."] }),
				R.Swatch(L["Outline color"], { "questItemOutlineR", "questItemOutlineG", "questItemOutlineB" },
					{ tip = L["Pick the outline's color."], test = ItemOutlined }),
				R.Shadow("questItemShadow")),
		} },
	},
})

-- Roll (Roll Style): only where the game has a loot history (its page isn't built without).
local function RollPanels(db) return db.rollPanel ~= "none" end
local function RollWords(db) return db.rollPicks == "words" end
local function RollMarked(db) return db.rollWinner ~= "plain" end
local function RollCard(p, i)
	local card = Child(p, i or 1)
	return card
end

ns.StyleFrame("roll", {
	label = L["Roll"], band = "Visions", sub = "World", subRank = 2, page = "Roll Style", switch = "rollStyle",
	shown = function() return ns.hasRollWindow and true or false end,
	refresh = function() if ns.RefreshRollStyle then ns.RefreshRollStyle() end end,
	preview = function(parent, width) return ns.MakeRollPreview(parent, width) end,
	-- (The real window with made-up drops, as the Roll Vision page's test.)
	test = function()
		local db = ns.GetDB()
		if db and db.rollWindow and ns.TestRollWindow then ns.TestRollWindow() end
	end,
	status = function(db)
		if not db.rollWindow then
			return L["Roll Vision is off: no roll window shows."], "warn", L["Open"], Open("Roll Vision")
		end
	end,
	parts = {
		{ id = "cards", label = L["Cards"], region = function(p) return RollCard(p) end, groups = {
			R.Group("Look",
				R.Choice("rollDensity", L["Rows"], { { "roomy", L["Roomy"] }, { "compact", L["Compact"] } })),
			R.Group("Background",
				R.Choice("rollPanel", L["Panel"], {
					{ "rounded", L["The game's frame"], L["A dark panel in the rounded edge of the game's roll frames, in the item's quality color."] },
					{ "flat", L["Flat"], L["A dark panel with a thin line around it, in the item's quality color."] },
					{ "none", L["None"], L["Just the text, over the world."] },
				}, { tip = L["What's behind each card."] }),
				R.Slider("rollAlpha", L["Opacity"], 20, 100, 5, "%", { scale = 100, tip = L["How see-through the cards are."],
					test = RollPanels })),
		} },
		{ id = "text", label = L["Text"], region = function(p) local c = RollCard(p) return c and c.item end, groups = {
			R.Group("Text",
				R.Font("rollFont", { tip = L["Names in Russian, Korean or Chinese keep the game's font, so their letters show."] }),
				R.Slider("rollTextSize", L["Size"], 70, 140, 5, "%", { scale = 100, tip = L["How big the text is, next to its usual size."] }),
				R.Outline("rollOutline", { tip = L["A black border around the letters: easier to read with no panel behind them."] }),
				R.Shadow("rollShadow")),
		} },
		{ id = "time", label = L["Time left"], region = function(p) local c = RollCard(p, 2) return c and c.track end, groups = {
			R.Group("Bar",
				R.Texture("rollBarTexture", { tip = L["The bar's fill, including textures other addons share."] }),
				R.Color("rollBarColor", L["Color"], { { "quality", L["The item's quality"] }, { "gold", L["Gold"] }, { "custom", L["Custom"] } },
					{ "rollBarR", "rollBarG", "rollBarB" }, "custom", { tip = L["Pick the bar's color."] }),
				R.Slider("rollBarGround", L["Background"], 0, 100, 5, "%", { scale = 100, tip = L["How dark it is behind the bar."] }),
				R.Slider("rollBarHeight", L["Height"], 2, 10, 1, "px", { tip = L["How tall the bar for the time left is."] })),
		} },
		{ id = "picks", label = L["Picks"], region = function(p) local c = RollCard(p) return c and c.rows and c.rows[2] end, groups = {
			R.Group("Look",
				R.Choice("rollPicks", L["Shown as"], { { "icons", L["Icons"], L["The game's dice and coin before each name."] },
					{ "words", L["Words"], L["Need, Greed or Transmog after each name, in their colors."] } }),
				R.Switch("rollNumbers", L["Numbers"], { tip = L["Shows each player's roll number once the game reveals the rolls."] })),
			R.Group("Text",
				R.Swatch(L["Need"], { "rollNeedR", "rollNeedG", "rollNeedB" }, { tip = L["Pick Need's color."], test = RollWords }),
				R.Swatch(L["Greed"], { "rollGreedR", "rollGreedG", "rollGreedB" }, { tip = L["Pick Greed's color."], test = RollWords }),
				R.Swatch(L["Transmog"], { "rollTransmogR", "rollTransmogG", "rollTransmogB" },
					{ tip = L["Pick Transmog's color."], test = RollWords })),
		} },
		{ id = "winner", label = L["Winner"], region = function(p) local c = RollCard(p) return c and c.rows and c.rows[1] end, groups = {
			R.Group("Look",
				R.Choice("rollWinner", L["Winner's row"], {
					{ "lit", L["Lit"], L["A glow along the row, a crown and the number in its color."] },
					{ "crown", L["A crown"], L["A crown and the number in its color."] },
					{ "plain", L["Just at the top"] },
				}),
				R.Color("rollWinnerColor", L["Color"], { { "gold", L["Gold"] }, { "custom", L["Custom"] } },
					{ "rollWinnerR", "rollWinnerG", "rollWinnerB" }, "custom", { tip = L["Pick the winner's color."], test = RollMarked })),
		} },
	},
})

-- Cards (Card Styles): the card types as variants. Only with Visions loaded (Cards.lua).
if not (ns.CARD_STYLES and ns.CardStyleKey and ns.CardStyleRaw) then return end
local FIRST = ns.CARD_STYLES[1].id
-- (A test reads the card type it's drawn for: fn(db, variant); none given, the tab's.)
local function Shown() return ns.CardTypeShown and ns.CardTypeShown() or FIRST end
local function Raw(style, name) return ns.CardStyleRaw(style or Shown(), name) end

-- A card type's setting as a field: what it shows (yours, else as the type comes),
-- and set; the value it comes with saved as "default" (not yours), as the Card Types
-- tab's dots counted.
local fields = {}
local function Field(name, style)
	local id = name .. ":" .. style
	if not fields[id] then
		local key = ns.CardStyleKey(name, style)
		local shipped = ns.CardStyleRaw(style, name, true)
		fields[id] = {
			get = function() return ns.CardStyleRaw(style, name) end,
			set = function(value)
				local db = ns.GetDB()
				if not db then return end
				if value == nil or value == shipped then value = "default" end
				db[key] = value
			end,
			default = shipped,
		}
	end
	return fields[id]
end
-- A property's key: the variant's field. (No variant: the first type's db key, which
-- the recipes read for General's entry: the card types share General's font,
-- outline and shadow, Cards.lua's SHARED_STYLE.)
local function Key(name)
	return function(style)
		if style == nil then return ns.CardStyleKey(name, FIRST) end
		return Field(name, style)
	end
end
-- A color of the type's own: "As it comes" (each channel "default") or "Custom" (the
-- channels its own: Custom copies what shows, its swatch picks).
local chips = {}
local function ChipKey(names)
	return function(style)
		style = style or FIRST
		local id = table.concat(names, ",") .. ":" .. style
		if not chips[id] then
			chips[id] = {
				get = function()
					for _, name in ipairs(names) do
						if ns.CardStyleIsOwn(style, name) then return "own" end
					end
					return "default"
				end,
				set = function(value)
					local db = ns.GetDB()
					if not db then return end
					for _, name in ipairs(names) do
						db[ns.CardStyleKey(name, style)] = value == "own" and ns.CardStyleRaw(style, name) or "default"
					end
				end,
				default = "default",
			}
		end
		return chips[id]
	end
end

local function On(db) return ns.StyleOn(nil, db) end
local function Gate(test)
	return function(db, v) return On(db) and (not test or test(db, v)) and true or false end
end
local function Banner(_, v) return Raw(v, "Style") == "banner" end
local function BarUp(db, v)
	local place = Raw(v, "Place")
	return not Banner(db, v) and (place == "top" or place == "bottom")
end

-- A color's three channels on the type drawn: its swatch's keys.
local function ChannelKeys(names)
	return function(style)
		style = style or FIRST
		return { Field(names[1], style), Field(names[2], style), Field(names[3], style) }
	end
end
-- A color of the type's own: As it comes, or Custom with its swatch (Custom copies what
-- shows; picking writes the type's three channels).
local function TypeColor(names, label, tip, test)
	return R.Color(ChipKey(names), label, { { "default", L["As it comes"] }, { "own", L["Custom"] } },
		ChannelKeys(names), "own", { tip = tip, test = Gate(test) })
end
local function Outlined(_, v)
	local value = Raw(v, "Outline")
	if value == -1 then value = ns.GeneralStyleValue(ns.CardStyleKey("Outline", v or Shown())) end
	return (tonumber(value) or 0) > 0
end
local function Pulsing(_, v) return (tonumber(Raw(v, "Pulse")) or 0) > 0 end

local variants = {}
for i, style in ipairs(ns.CARD_STYLES) do variants[i] = { id = style.id, label = L[style.name] } end
-- (Which type the Studio window shows, while it's on Cards; else the tab's.)
local function StudioStyle()
	local win = ns.StyleStudioWindow and ns.StyleStudioWindow()
	local host = win and win.host
	if host and host.f and host.f.id == "cards" and host.variant then return host.variant end
	return Shown()
end

ns.StyleFrame("cards", {
	label = L["Card Types"], band = "Visions", sub = "RP", subRank = 3, page = "Card Styles",
	-- (No switch of its own: `cards` is Card Vision's, every card on or off. Greyed with
	-- Enable Style, each setting's test.)
	variants = variants,
	independent = true, -- (each type as it comes: none follows another)
	preview = function(parent, width)
		if ns.MakeCardTypePreview then return ns.MakeCardTypePreview(parent, width, StudioStyle) end
	end,
	test = function() if ns.TestCardType then ns.TestCardType(StudioStyle()) end end,
	status = function(db)
		if not On(db) then
			return L["Off: %s. Nothing here shows in the game."]:format(L["Enable Style"]), "off", L["Turn on"], function()
				Studio.Apply(Studio.frames.cards, L["Card Types"] .. " · " .. L["Turn on"], { { "styleGeneral", true } })
			end
		end
		if not db.cards then
			return L["Card Vision is off: no card shows."], "warn", L["Open"], Open("Card Vision")
		end
	end,
	parts = {
		{ id = "card", label = L["Card"], groups = {
			R.Group("Look",
				R.Choice(Key("Style"), L["Style"], {
					{ "title", L["Title"], L["Big words in the middle of the screen, the rest under them."] },
					{ "subtitle", L["Subtitle"], L["A small line low on the screen, where a movie's subtitles go."] },
					{ "chapter", L["Chapter"], L["The words over a line that draws out, as a new scene starts."] },
					{ "banner", L["Banner"], L["Big words across the middle of the screen on a dark band."] },
				}, { test = Gate() }),
				R.Choice(Key("Anim"), L["Animation"], {
					{ "fade", L["Fade"], L["The card fades in and out."] },
					{ "reveal", L["Reveal"], L["The words open out from their middle."] },
					{ "track", L["Tracking"], L["The letters start spread apart and close up, like a movie title."] },
					{ "type", L["Type"], L["The words appear a letter at a time, as if typed."] },
					{ "slam", L["Slam"], L["The words start big and slam down to size."] },
				}, { test = Gate() })),
			R.Group("Place",
				R.Choice(Key("Place"), L["Place"], {
					{ "screen", L["Screen"], L["In the middle of the screen, or low on it for a subtitle."] },
					{ "top", L["Top bar"], L["Top letterbox bar"] },
					{ "bottom", L["Bottom bar"], L["Bottom letterbox bar"] },
					{ "third", L["Lower third"], L["Low on the left of the screen, like a name caption in a movie, its line fading out to the right."] },
				}, { test = Gate(function(db, v) return not Banner(db, v) end) }),
				R.Slider(Key("OffsetX"), L["Move across"], -50, 50, 0.5, "%", { scale = 100,
					tip = L["Moves the card right. Below 0 moves it left."], test = Gate() }),
				R.Slider(Key("OffsetY"), L["Move up"], -50, 50, 0.5, "%", { scale = 100,
					tip = L["Moves the card up. Below 0 moves it down."], test = Gate() }),
				R.Choice(Key("Align"), L["Align"], { { "left", L["Left"] }, { "center", L["Center"] }, { "right", L["Right"] } },
					{ tip = L["Where the words sit in the letterbox bar."], test = Gate(BarUp) }),
				R.Slider(Key("BarScale"), L["Bar scale"], 20, 100, 1, "%", { scale = 100,
					tip = L["The words' size compared to the letterbox bar."], test = Gate(BarUp) }),
				R.Drop(Key("BarFallback"), L["No letterbox"], {
					{ "bar", L["Its own bar"], L["A bar as tall as your letterbox's comes in for the card."] },
					{ "third", L["Lower third"], L["The card shows in the lower third."] },
					{ "screen", L["Screen center"], L["The card shows in the middle of the screen."] },
					{ "none", L["Don't show"], L["The card shows only while a letterbox is up."] },
				}, { tip = L["Where the card shows while no letterbox is up."], test = Gate(BarUp) })),
			R.Group("Motion",
				R.Slider(Key("Hold"), L["Stays"], 0.5, 12, 0.5, "s",
					{ tip = L["How long the card stays between fading in and out. With Typewriter, this starts once it's done typing."], test = Gate() }),
				R.Slider(Key("Pulse"), L["Edge pulse"], 0, 100, 1, "%", { scale = 100,
					tip = L["How strongly the screen edges flash as the card shows. Set to 0 for no flash."], test = Gate() }),
				TypeColor({ "PulseR", "PulseG", "PulseB" }, L["Pulse color"], L["Pick the pulse's color."], Pulsing)),
		} },
		{ id = "words", label = L["Words"], groups = {
			R.Group("Text",
				R.Font(Key("Font"), { tip = L["Words in Russian, Korean or Chinese keep the game's font, so their letters show."], test = Gate() }),
				R.Slider(Key("Size"), L["Size"], 14, 1000, 1, "px", { tip = L["How tall the words are."],
					test = Gate(function(db, v) return not BarUp(db, v) end) }),
				TypeColor({ "R", "G", "B" }, L["Color"], L["The words' color. The small lines with them use a lighter shade."]),
				R.Outline(Key("Outline"), { tip = L["A border around the letters."], test = Gate() }),
				TypeColor({ "OutlineR", "OutlineG", "OutlineB" }, L["Outline color"], L["Pick the outline's color."], Outlined),
				R.Shadow(Key("Shadow"), { test = Gate() }),
				R.Switch(Key("Caps"), L["Capitals"], { tip = L["Shows the words in capital letters."], test = Gate() }),
				R.Switch(Key("Stack"), L["Word per line"], { tip = L["Puts each word on a line of its own."], test = Gate() })),
		} },
		{ id = "small", label = L["Small lines"], groups = {
			R.Group("Text",
				R.Font(Key("SmallFont"), { first = { "same", L["Same as the words"] },
					tip = L["The small lines' font, over and under the words."], test = Gate() }),
				R.Slider(Key("SmallSize"), L["Size"], 50, 250, 5, "%", { scale = 100, tip = L["Makes the small lines bigger or smaller."],
					test = Gate() }),
				R.Color(Key("SmallColor"), L["Color"], { { "auto", L["Automatic"], L["Picks a matching color automatically."] },
					{ "custom", L["Custom"], L["A color of your own, for both lines."] } },
					ChannelKeys({ "SmallR", "SmallG", "SmallB" }), "custom",
					{ tip = L["The small lines' color."], test = Gate() })),
		} },
		{ id = "icon", label = L["Icon"], groups = {
			R.Group("Icon",
				R.Switch(Key("IconShow"), L["Icon"], { tip = L["Shows an icon before the words."], test = Gate() })),
		} },
	},
})
end) -- (ns.Module "style")
