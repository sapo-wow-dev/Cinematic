-- Style Studio frames: the Visions band (Tools/style-studio/plan.md section 7):
--   visions  All Visions   Visions Style (Style/VisionsStyle.lua): the look they
--            share, and which Visions follow it.
--   damage   Damage        Damage Vision Look (Visions/DamageVision.lua): where the
--            game has its damage meter.
--   vitals   Vitals        Vitals Style (Atmosphere/LowHealth.lua): its themes stay
--            above the editor; the old tabs are its parts.
--   emote    Emote         Emote Vision Style (Visions/EmoteVision.lua).
-- Every look setting the pages had, by its db key (or field), in the recipes' order.
-- (The Vision files load after this one: their lists and previews are read as
-- they're asked for, never here.)
local _, ns = ...
ns.Module("style", function()
local L = ns.L
local Studio = ns.Studio
local R = Studio.R

local function VisionsLoaded() return not ns.ModuleLoaded or ns.ModuleLoaded("visions") end
-- A value something else owns (a Vitals theme's field, a part's tab switch,
-- which Visions follow): never "yours" (prop.noReset), so Reset leaves it be;
-- Undo still puts it back.
local function Kept(prop)
	prop.noReset = true
	return prop
end
-- A color of fields (a theme's): a swatch on its three fields, kept as Kept's.
local function FieldColor(_, label, keys, tip, test)
	return Kept(R.Swatch(label, keys, { tip = tip, test = test }))
end
local function Named(group, label) group.label = label return group end

-- All Visions -----------------------------------------------------------------------
-- Which Visions follow Visions Style: a choice each (its shared settings on
-- "general"/its defaults, or its own). Its own picked again puts back the
-- values it had (this session), else starts from what it shows now.
local followKept = {}
local function FollowField(prefix)
	return { noSettingId = true,
		get = function()
			return #ns.VisionOwnKinds(ns.VisionStyleKeysOf(prefix)) == 0 and "follows" or "own"
		end,
		set = function(value)
			local db = ns.GetDB()
			if not db then return end
			local keys = ns.VisionStyleKeysOf(prefix)
			if value == "follows" then
				local kept = {}
				for _, key in ipairs(keys) do kept[key] = db[key] db[key] = ns.DEFAULTS[key] end
				followKept[prefix] = kept
				return
			end
			local kept = followKept[prefix]
			for _, key in ipairs(keys) do
				if kept and kept[key] ~= nil then
					db[key] = kept[key]
				elseif ns.IsGeneralStyle(db[key]) or db[key] == "default" then
					local now = ns.GeneralStyleValue(key)
					if now ~= nil then db[key] = now end
				end
			end
		end,
	}
end
local function VisionShown(prefix)
	return function()
		local keys = ns.VisionStyleKeysOf and ns.VisionStyleKeysOf(prefix) or {}
		-- (Only the ones this client has: one it lacks never set its defaults.)
		return #keys > 0 and ns.DEFAULTS[keys[1]] ~= nil
	end
end
local function FollowProps()
	local props = {}
	for _, vision in ipairs(ns.VISIONS_SHARING or {}) do
		local name, page, prefix = L[vision[1]], vision[2], vision[3]
		props[#props + 1] = Kept(R.Choice(FollowField(prefix), name, {
			{ "follows", L["Visions Style"], L["Its font, outline, shadow, texture and border as this page says."] },
			{ "own", L["Its own"], L["It keeps its own; picking this again puts back what it had."] },
		}, { shown = VisionShown(prefix), free = true,
			tip = L["Whether it follows this page or keeps its own look."] }))
		-- (Its page, not the Studio window: its links hidden, the user, 2026-11-25.)
		props[#props + 1] = R.Button(L["Edit %s"]:format(name), function()
			if ns.OpenOptions then ns.OpenOptions(page) end
		end, { shown = VisionShown(prefix), tip = L["Opens its look."] })
	end
	return props
end
-- (General's Outline on "The game's": named so, not None.)
local function VisionOutline()
	local prop = R.Outline("visionStyleOutline", { tip = L["A dark line around the letters, on every Vision that follows this page."] })
	local options = prop.options
	prop.options = function()
		local list = options()
		if list[1] and list[1][1] == -1 and ns.GeneralStyleValue("visionStyleOutline") == "game" then
			list[1][3] = ns.SharedStyleSource("visionStyleOutline") .. " (" .. L["The game's"] .. ")"
		end
		return list
	end
	return prop
end

ns.StyleFrame("visions", {
	label = L["All Visions"], band = "Visions", subRank = 0, page = "Visions Style", switch = "visionsStyle",
	shown = VisionsLoaded,
	refresh = function() if ns.RefreshVisionsStyle then ns.RefreshVisionsStyle() end end,
	-- (The Studio's stage: the Damage and Emote cards, which follow it.)
	preview = function(parent, width)
		local holder = CreateFrame("Frame", nil, parent)
		holder:SetSize(width, 262)
		local damage = ns.MakeDamageVisionPreview and ns.MakeDamageVisionPreview(holder, width)
		local emote = ns.MakeEmoteVisionPreview and ns.MakeEmoteVisionPreview(holder, width)
		if damage then damage:SetPoint("TOP") end
		if emote then emote:SetPoint("TOP", 0, damage and -132 or 0) end
		function holder:Refresh()
			if damage then damage:Refresh() end
			if emote then emote:Refresh() end
		end
		return holder
	end,
	parts = {
		{ id = "look", label = L["Shared look"], groups = {
			R.Group("Text",
				R.Font("visionStyleFont", { tip = L["The font for every Vision that follows this page."] }),
				R.Slider("visionStyleTextSize", L["Size"], 70, 150, 5, "%", { scale = 100,
					tip = L["Makes every Vision's text bigger or smaller, on top of each one's own size."] }),
				VisionOutline(),
				R.Shadow("visionStyleShadow", { tip = L["A dark shadow behind the letters, on every Vision that follows this page."] })),
			R.Group("Bar", R.Texture("visionStyleTexture", { game = L["The game's"],
				tip = L["The bar fill for every Vision that follows this page."] })),
			R.Group("Border", R.Border("visionStyleBorder", { game = true,
				tip = L["The border for every Vision part that follows this page."] })),
		} },
		{ id = "follows", label = L["Follows"], groups = {
			Named(R.Group("Look", unpack(FollowProps())), "Which Visions follow it"),
		} },
	},
})

-- Damage ----------------------------------------------------------------------------
local function DamageMeter() return ns.DamageVisionMeter and ns.DamageVisionMeter.HasMeter() end
local function Own(db) return db.damageVisionSpot ~= "meter" end
ns.StyleFrame("damage", {
	label = L["Damage"], band = "Visions", sub = "Combat", subRank = 1, page = "Damage Vision Look", switch = "damageVisionLook",
	-- (Only where the game has its damage meter: C_DamageMeter, retail.)
	shown = function() return VisionsLoaded() and DamageMeter() and ns.MakeDamageVisionPreview ~= nil end,
	refresh = function() if ns.RefreshDamageVision then ns.RefreshDamageVision() end end,
	preview = function(parent, width) return ns.MakeDamageVisionPreview(parent, width) end,
	-- (Test: a made-up 25-second fight on your screen; Stop while it runs.)
	test = function() if ns.TestDamageVision then ns.TestDamageVision() end end,
	testing = function() return ns.DamageVisionTesting and ns.DamageVisionTesting() or false end,
	stop = function() if ns.StopDamageVisionTest then ns.StopDamageVisionTest() end end,
	parts = {
		{ id = "bars", label = L["Bars"], region = function(p) return p.rows and p.rows[1] end, groups = {
			R.Group("Bar",
				R.Texture("damageVisionTexture", { game = L["Cinematic's"], tip = L["The bars' fill."] }),
				R.Color("damageVisionColors", L["Colors"], {
					{ "status", L["Behind and ahead"], L["Amber while you're behind, teal once you lead."] },
					{ "class", L["Your class"], L["Your class's color, whether you lead or chase."] },
					{ "custom", L["Custom"], L["Your two colors: this one while you're behind, the next once you lead."] },
				}, { "damageVisionChaseR", "damageVisionChaseG", "damageVisionChaseB" }, "custom",
					{ tip = L["The bar's color while you're behind, and once you lead."] }),
				R.Swatch(L["Once you lead"], { "damageVisionLeadR", "damageVisionLeadG", "damageVisionLeadB" },
					{ setKey = "damageVisionColors", setTo = "custom", tip = L["The bar's color once you lead; picking one switches it to Custom."] }),
				R.Slider("damageVisionBarHeight", L["Height"], 4, 32, 1, "px",
					{ tip = L["How tall the bar is (the race track's line is half that, the ladder's rows a little more)."] }),
				R.Slider("damageVisionWidth", L["Width"], 120, 500, 10, "px", { tip = L["How wide it is."] }),
				R.Switch("damageVisionSmooth", L["Smooth"], { tip = L["The bars glide to each new value instead of jumping."] }),
				R.Switch("damageVisionSpark", L["Spark"], { tip = L["Adds a bright spark at the edge of the filled part."] })),
			R.Group("Border",
				R.Choice("damageVisionBorder", L["Border"], { { "none", L["None"] }, { "thin", L["Thin"] }, { "thick", L["Thick"] } },
					{ tip = L["The line around the bars."] }),
				R.Swatch(L["Color"], { "damageVisionBorderR", "damageVisionBorderG", "damageVisionBorderB" },
					{ tip = L["The border's color."], test = function(db) return db.damageVisionBorder ~= "none" end })),
		} },
		{ id = "words", label = L["Words"], region = function(p) return p.place end, groups = {
			R.Group("Text",
				R.Font("damageVisionFont"),
				R.Slider("damageVisionTextSize", L["Size"], 70, 160, 5, "%", { scale = 100,
					tip = L["The words' size compared to their normal size."] }),
				R.Color("damageVisionTextColor", L["Color"], { { "gold", L["Gold"] }, { "white", L["White"] },
					{ "custom", L["Custom"] } }, { "damageVisionTextR", "damageVisionTextG", "damageVisionTextB" }, "custom",
					{ tip = L["The color of your place."] }),
				R.Outline("damageVisionOutline"),
				R.Shadow("damageVisionShadow")),
		} },
		{ id = "seethrough", label = L["See-through"], groups = {
			R.Group("Background",
				R.Slider("damageVisionOpacity", L["Opacity"], 20, 100, 5, "%", { scale = 100, tip = L["How see-through the whole of it is."] }),
				R.Slider("damageVisionTrack", L["Background"], 0, 100, 5, "%", { scale = 100, tip = L["How dark the empty part of the bar is."] }),
				R.Slider("damageVisionPanel", L["Panel"], 0, 100, 5, "%", { scale = 100,
					tip = L["How dark the panel behind it is. Set to 0 for no panel."] })),
		} },
		{ id = "position", label = L["Position"], groups = {
			R.Group("Place",
				R.Slider("damageVisionSize", L["Scale"], 50, 200, 10, "%", { scale = 100, tip = L["Everything at once, bars and words."] }),
				R.Choice("damageVisionSpot", L["Sits"], {
					{ "own", L["Where you put it"], L["At the X and Y below (or where you drag it with Move)."] },
					{ "meter", L["Over the damage meter"], L["Sits over the game's damage meter window."] },
				}),
				R.Slider("damageVisionX", L["Left/right"], -2000, 2000, 1, "px",
					{ tip = L["How far right and up from the screen's middle it sits."], test = Own }),
				R.Slider("damageVisionY", L["Down/up"], -1200, 1200, 1, "px",
					{ tip = L["How far right and up from the screen's middle it sits."], test = Own }),
				R.Button(L["Move"], function() ns.MoveDamageVision("display") end,
					{ tip = L["Drag the box to move it; right-click to reset."], test = Own })),
		} },
	},
})

-- Vitals ----------------------------------------------------------------------------
-- (Its fields and lists: LowHealth.lua's ns.VitalsStudioKit, there with Visions loaded.)
local K = ns.VitalsStudioKit and ns.VitalsStudioKit()
if K then
	local T = ns.VITALS_TABS
	local function On(db) return ns.StyleOn("lowHealthStyle", db) end
	-- A part's switch (its old tab's: a container, off with the Vision's), and its rows' test.
	local function TabOn(tab) return function(db) return db[tab] ~= false and not ns.MasterOff(tab, db) end end
	local function Tab(tab)
		return Kept(R.Switch(tab, L["On"], { free = true, tip = L["Off, everything in this part is off."] }))
	end
	local function And(a, b) return function(db) return a(db) and b(db) end end
	local function Pct(key, label, min, max, step, tip, test)
		return R.Slider(key, label, min, max, step, "%", { scale = 100, tip = tip, test = test })
	end
	local function ThemePct(key, label, min, max, step, tip, test)
		return Kept(R.Slider(key, label, min, max, step, "%", { scale = 100, tip = tip, test = test }))
	end
	local function Ticked(key) return function(db) return db[key] and true or false end end

	local general, blizzard, cinematic, swirl = TabOn(T.general), TabOn(T.blizzard), TabOn(T.cinematic), TabOn(T.swirl)
	local function Themed(tab) return And(tab, K.Themed) end
	local beating = And(general, Ticked("lowHealthPulse"))
	local flashing = And(general, Ticked("lowHealthFlash"))

	-- Sparks: four rows of five; swirls: MAX_SWIRLS of five.
	local sparkProps = {
		R.Switch("lowHealthSparks", L["Sparks"], { tip = L["The theme's sparks and the haze drifting over the edges."], test = cinematic }),
	}
	for i = 1, 4 do
		local used = And(cinematic, K.SparkUsed(i))
		sparkProps[#sparkProps + 1] = Kept(R.Drop(K.SparkKind(i), L["Spark %d"]:format(i), K.SPARK_CHOICES,
			{ tip = L["The sparks that float over the edges."], test = And(cinematic, K.SparkOpen(i)) }))
		sparkProps[#sparkProps + 1] = FieldColor("vitals", L["Spark %d color"]:format(i), K.SparkColor(i), L["Their color."],
			And(On, used))
		sparkProps[#sparkProps + 1] = Kept(R.Slider(K.SparkAmount(i), L["Amount"], 0, 120, 5, L["a minute"],
			{ tip = L["How many appear per minute at full strength. A big hit adds a few more."], test = used }))
		sparkProps[#sparkProps + 1] = ThemePct(K.SparkSize(i), L["Size"], 20, 300, 10, L["How big they are compared to normal."], used)
		sparkProps[#sparkProps + 1] = Kept(R.Drop(K.SparkFrom(i), L["Starts from"], K.FROM_CHOICES,
			{ tip = L["Which edge they start from."], test = used }))
	end
	sparkProps[#sparkProps + 1] = R.Switch("lowHealthHeat", L["Rising heat"],
		{ tip = L["Wisps of heat rise from the bottom of the screen as you weaken."], test = cinematic })

	local swirlProps = {}
	for i = 1, K.MAX_SWIRLS do
		local used = And(swirl, K.SwirlUsed(i))
		swirlProps[#swirlProps + 1] = Kept(R.Drop(K.SwirlKind(i), L["Swirl %d"]:format(i), K.SWIRL_CHOICES,
			{ tip = L["The kind of swirl."], test = And(swirl, K.SwirlOpen(i)) }))
		swirlProps[#swirlProps + 1] = FieldColor("vitals", L["Swirl %d color"]:format(i), K.SwirlColor(i), L["Its color."], And(On, used))
		swirlProps[#swirlProps + 1] = ThemePct(K.SwirlPart(i, "alpha"), L["Opacity"], 0, 100, 5, L["How strong it is at full."], used)
		swirlProps[#swirlProps + 1] = Kept(R.Slider(K.SwirlPart(i, "spin"), L["Speed"], -30, 30, 1, "",
			{ tip = L["How fast the swirl turns; below 0 turns the other way."], test = used }))
		swirlProps[#swirlProps + 1] = ThemePct(K.SwirlPart(i, "reach"), L["Reach"], 0, 100, 5,
			L["How far in its clear middle closes at full."], used)
	end
	-- (The portal: the dev copy's only; its numbers change the theme until /reload.)
	local function Dev() return ns.isDev and true or false end
	local portal = And(swirl, K.HasPortal)
	local portalGroup = Named(R.Group("Place",
		Kept(R.Slider(K.PortalField("out", K.PORTAL_OUT), L["Start distance"], -20, 10, 0.5, "",
			{ shown = Dev, test = portal, tip = L["Where it sits as the edges start to close in; bigger brings it nearer."] })),
		Kept(R.Slider(K.PortalField("distance", K.PORTAL_FULL), L["Full distance"], -20, 10, 0.5, "",
			{ shown = Dev, test = portal, tip = L["Where it sits at full strength; its rim should frame the screen."] })),
		Kept(R.Slider(K.PortalField("scale", 1), L["Size"], 0.2, 4, 0.1, "x",
			{ shown = Dev, test = portal, tip = L["The portal model's size, until /reload."] })),
		Pct("lowHealthPortalAlpha", L["Opacity"], 0, 100, 1,
			L["The theme's portal, its rim closing in around the screen as you weaken (no theme has one now)."], swirl)),
		"Theme's portal (dev copy)")
	portalGroup.props[4].shown = Dev

	local parts = {
		{ id = "general", label = L["General"], groups = {
			R.Group("Look", Tab(T.general),
				Pct("lowHealthStrength", L["Strength"], 0, 100, 5, L["How strong the whole effect is."], general),
				Pct("lowHealthReachAll", L["Reach"], 0, 100, 5, L["How far in from the edges the whole effect comes."], general),
				Pct("lowHealthBrightness", L["Brightness"], 0, 100, 5, L["How bright the art's colors are."], general)),
			Named(R.Group("Background",
				Pct("lowHealthReach", L["Shadow reach, top and bottom"], 10, 50, 1,
					L["How much of the screen's height the dark top and bottom edges cover at full."], general),
				Pct("lowHealthReachSides", L["Shadow reach, sides"], 10, 50, 1,
					L["How much of the screen's width the dark left and right edges cover at full."], general),
				Pct("lowHealthDark", L["Darkness"], 0, 100, 5, L["How dark the edges are at full."], general),
				Pct("lowHealthRed", L["Shadow tint"], 0, 100, 5, L["Black at 0%, the theme's color at 100%."], general),
				FieldColor("vitals", L["Shadow color"], K.ColorKeys("shadow"), L["The dark edges' color, at full Shadow tint."],
					Themed(general)),
				FieldColor("vitals", L["Flash color"], K.ColorKeys("flash"),
					L["The color of a big hit's flash, and the color the world fades to."], Themed(general))),
				"Shadow"),
			Named(R.Group("Motion",
				R.Switch("lowHealthPulse", L["Heartbeat"], { tip = L["The edges throb with a heartbeat, quicker as you weaken."], test = general }),
				Pct("lowHealthPulseAmount", L["Throb"], 0, 60, 5,
					L["How much further in each beat pushes the edges (some themes throb more or less)."], beating),
				R.Slider("lowHealthBpmSlow", L["Beats as they start"], 30, 120, 5, L["a minute"],
					{ tip = L["Beats a minute as the edges start to close in."], test = beating }),
				R.Slider("lowHealthBpmFast", L["Beats at full"], 60, 200, 5, L["a minute"], { tip = L["Beats a minute at full."], test = beating }),
				ThemePct(K.Field("bpm", 1), L["Theme's speed"], 30, 200, 5,
					L["This theme's heartbeat speed, next to the beats above; a creeping theme beats slower."], And(beating, K.Themed)),
				ThemePct(K.Field("pulse", 1), L["Theme's throb"], 0, 300, 10, L["How much this theme throbs, next to Throb above."],
					And(beating, K.Themed)),
				R.Switch("lowHealthFlash", L["Flash on big hits"], { tip = L["The edges flash when a big hit lands."], test = general }),
				Pct("lowHealthFlashDark", L["Flash darkness"], 0, 100, 5, L["How much darker the edges get in a flash, on top of Darkness."], flashing),
				Pct("lowHealthFlashTint", L["Flash tint"], 0, 100, 5, L["How much a flash tints the edges."], flashing),
				R.Slider("lowHealthFlashTime", L["Flash fade"], 0.1, 3, 0.1, "s", { tip = L["Seconds a flash takes to fade."], test = flashing })),
				"Heartbeat and hits"),
		} },
		{ id = "blizzard", label = L["Blizzard art"], groups = {
			R.Group("Look", Tab(T.blizzard),
				Pct("lowHealthGameAlpha", L["Opacity"], 0, 100, 1, L["The game's own screen effects closing in at the edges."], blizzard),
				Pct("lowHealthGameReach", L["Reach, top and bottom"], 0, 100, 5,
					L["How far in it comes from the top and bottom of the screen at full."], blizzard),
				Pct("lowHealthGameReachSides", L["Reach, sides"], 0, 100, 5, L["How far in it comes from the left and right sides."], blizzard),
				R.Choice("lowHealthGameColors", L["Colors"], { { "auto", L["The pattern's own choice"] },
					{ "theme", L["The theme's color"] }, { "own", L["Its own colors"] } },
					{ tip = L["Tint the effect to your theme or keep its own colors."], test = blizzard })),
			Named(R.Group("Background",
				{ kind = "tiles", label = L["Pattern"], key = "lowHealthGamePattern", options = K.PatternChoices,
					tip = L["Which of the game's effects shows."], test = blizzard },
				R.Drop("lowHealthGameMask", L["Edge"], K.MaskChoices, { tip = L["What shape cuts the effect to the screen's edges."], test = blizzard }),
				{ kind = "tiles", label = L["Second pattern"], key = "lowHealthGamePattern2", options = K.Pattern2Choices,
					tip = L["A second game effect over the first."], test = blizzard }),
				"Pattern"),
			R.Group("Motion",
				R.Switch("lowHealthRipple", L["Ripple wave"], { tip = L["A wave of the game's art creeps in on each heartbeat."], test = blizzard }),
				R.Switch("lowHealthGameDrift", L["Drift"], { tip = L["The game's effects slide slowly under their edge."], test = blizzard })),
		} },
		{ id = "cinematic", label = L["Cinematic art"], groups = {
			R.Group("Look", Tab(T.cinematic),
				Kept(R.Drop(K.Field("edge", "none"), L["Edge"], K.EdgeChoices,
					{ tip = L["The theme's art that spreads in from the edges."], test = Themed(cinematic) })),
				FieldColor("vitals", L["Art color"], K.ColorKeys("body"), L["The art's color."], Themed(cinematic)),
				FieldColor("vitals", L["Glow color"], K.ColorKeys("glow"),
					L["The glow around the art, added as light. This is Glow's only color."], Themed(cinematic)),
				ThemePct(K.Field("glowAlpha", 1), L["Glow strength"], 0, 100, 5, L["How strong the glow is compared to the art."],
					Themed(cinematic)),
				Pct("lowHealthBloodAlpha", L["Opacity"], 0, 100, 1,
					L["The theme's art (blood, smoke, a glow) that spreads in from the edges as they close in."], cinematic),
				Pct("lowHealthBloodReach", L["Reach, top and bottom"], 0, 100, 5,
					L["How far in it comes from the top and bottom of the screen at full."], cinematic),
				Pct("lowHealthBloodReachSides", L["Reach, sides"], 0, 100, 5, L["How far in it comes from the left and right sides."], cinematic)),
			Named(R.Group("Motion", unpack(sparkProps)), "Theme's sparks"),
		} },
		{ id = "swirl", label = L["Swirl"], groups = {
			R.Group("Look", Tab(T.swirl),
				Pct("lowHealthSwirlAlpha", L["Opacity"], 0, 100, 1, L["A swirl that turns over the screen as you weaken."], swirl)),
			Named(R.Group("Motion", unpack(swirlProps)), "Theme's swirl"),
			portalGroup,
		} },
	}
	-- Game effect: retail only (Classic hasn't its files).
	if ns.isRetail and ns.SCREEN_EFFECT_PICKS then
		local effect = TabOn(T.effect)
		local has = And(effect, K.HasEffect)
		parts[#parts + 1] = { id = "effect", label = L["Game effect"], groups = {
			R.Group("Look", Tab(T.effect),
				R.Note(L["One of the game's own moving full-screen effects, closing in as you weaken over everything else."]),
				Kept(R.Drop(K.EffectKind, L["Theme's game effect"], K.EffectChoices,
					{ tip = L["One of the game's full-screen effects closing in as you weaken."], test = Themed(effect) })),
				ThemePct(K.EffectPart("alpha", 1), L["Opacity"], 0, 100, 5, L["How strong it is at full, times the art's opacity."], has),
				ThemePct(K.EffectPart("reach", 0.5), L["Reach"], 0, 100, 5,
					L["Where its edge sits: 50 is the game's, higher further in, lower past the screen."], has)),
		} }
	end
	-- Mana: low mana's look (ManaVision.lua), under the Vision tab's Mana.
	if ns.ManaVisionStyleRows then
		local mana = TabOn(T.mana)
		parts[#parts + 1] = { id = "mana", label = L["Mana"], groups = {
			R.Group("Look", Tab(T.mana),
				R.Choice("lowManaVisionLook", L["Look"], {
					{ "drain", L["Drained"], L["Gray-blue: the world's color drains away."] },
					{ "cold", L["Cold"], L["A cold, deep blue."] },
					{ "dusk", L["Dusk"], L["A dim, gray-violet dusk."] },
				}, { test = mana }),
				Pct("lowManaVisionStrength", L["Strength"], 10, 100, 5, L["How strong the veil and the edges are when your mana is out."], mana)),
			Named(R.Group("Background",
				R.Switch("lowManaVisionEdges", L["Dark edges"], { tip = L["Dark edges close in as your mana runs out."], test = mana }),
				Pct("lowManaVisionReach", L["Reach"], 10, 50, 1, L["How far in from the screen's edges they come."],
					And(mana, Ticked("lowManaVisionEdges")))),
				"Dark edges"),
		} }
	end

	-- Each part's settings hung under its tab's switch, as ns.MapTabContainers
	-- did for the old folder tabs (a tab off: its settings read off, ns.MasterOff
	-- and ns.StyleLook), but for one under another tree's switch: left as it is.
	local TAB_OF = { general = T.general, blizzard = T.blizzard, cinematic = T.cinematic, swirl = T.swirl,
		effect = T.effect, mana = T.mana }
	for _, part in ipairs(parts) do
		local tab = TAB_OF[part.id]
		local above, step = {}, ns.PageSwitchOf(tab)
		for _ = 1, 10 do
			if not step then break end
			above[step] = true
			step = ns.PageSwitchOf(step)
		end
		for _, group in ipairs(part.groups) do
			for _, prop in ipairs(group.props) do
				local key = prop.key
				if type(key) == "string" and key ~= tab and (not prop.shown or prop.shown()) then
					local now = ns.PageSwitchOf(key)
					if now == nil or above[now] then ns.SetPageMaster({ key }, tab) end
				end
			end
		end
	end

	ns.StyleFrame("vitals", {
		label = L["Vitals"], band = "Visions", sub = "Combat", subRank = 1, page = "Vitals Style", switch = "lowHealthStyle",
		shown = VisionsLoaded,
		refresh = function() if ns.RefreshLowHealth then ns.RefreshLowHealth() end end,
		preview = function(parent, width) return ns.MakeVitalsPreview(parent, width) end,
		parts = parts,
	})
end

-- Emote -----------------------------------------------------------------------------
local function OwnSpot(db) return db.emoteVisionSpot == "own" end
ns.StyleFrame("emote", {
	label = L["Emote"], band = "Visions", sub = "RP", subRank = 3, page = "Emote Vision Style", switch = "emoteStyle",
	shown = function() return VisionsLoaded() and ns.MakeEmoteVisionPreview ~= nil end,
	refresh = function() if ns.RefreshEmoteVision then ns.RefreshEmoteVision() end end,
	preview = function(parent, width) return ns.MakeEmoteVisionPreview(parent, width) end,
	-- (Test: the next moment's pretend card, one a click: nothing keeps running.)
	test = function() if ns.TestEmoteVision then ns.TestEmoteVision() end end,
	parts = {
		{ id = "style", label = L["Style"], groups = {
			R.Group("Look", { kind = "tiles", label = L["Style"], key = "emoteVisionLook", few = 4,
				options = function() return ns.EmoteLookChoices and ns.EmoteLookChoices() or {} end,
				tip = L["The card's style: its panel, face and emotes."] }),
		} },
		{ id = "frame", label = L["Frame"], region = function(p) return p.card end, groups = {
			Named(R.Group("Icon", R.Switch("emoteVisionPortrait", L["Their face"],
				{ tip = L["Their portrait on the card (their class's icon when they're out of sight)."] })), "Face"),
			R.Group("Border", R.Border("emoteBorder", { game = true, tip = L["The line around the card, in the Classic style."] })),
		} },
		{ id = "words", label = L["Words"], region = function(p) return p.words end, groups = {
			R.Group("Text",
				R.Font("emoteFont"),
				R.Slider("emoteTextSize", L["Size"], 70, 150, 5, "%", { scale = 100, tip = L["The words' size compared to their normal size."] }),
				R.Outline("emoteOutline"),
				R.Shadow("emoteShadow")),
		} },
		{ id = "position", label = L["Position"], groups = {
			R.Group("Place",
				R.Slider("emoteVisionScale", L["Scale"], 50, 150, 5, "%", { scale = 100, tip = L["The whole card at once."] }),
				R.Choice("emoteVisionSpot", L["Sits"], {
					{ "speech", L["Above speech"], L["Just above the lines from behind you."] },
					{ "own", L["Where you put it"], L["At the X and Y below (or where you drag it with Move)."] },
				}),
				R.Slider("emoteVisionX", L["Left/right"], -2000, 2000, 1, "px", { tip = L["How far right and up the card sits."], test = OwnSpot }),
				R.Slider("emoteVisionY", L["Down/up"], 0, 1600, 1, "px", { tip = L["How far right and up the card sits."], test = OwnSpot }),
				R.Button(L["Move"], function() ns.MoveEmoteVision() end, { tip = L["Lets you drag the card; click Done when finished."] })),
		} },
	},
})
end) -- (ns.Module "style")
