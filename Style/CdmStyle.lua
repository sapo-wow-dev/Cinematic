-- The Style hub's Cooldown Manager page (Cooldown Manager Style, 2026-11-23):
-- how the drain ring on tracked buff icons looks (UI/CooldownRing.lua). Which
-- buffs get one, and their game timer, stay on the Cooldown Manager page's
-- Look grid (Ring, Amount, Numbers). The icons' round shape stays Action Bar
-- Style's. Page off: the ring keeps its defaults (ns.StyleLook). Its settings'
-- defaults live in UI/CooldownRing.lua, so the ring works with Style left out.
local _, ns = ...
ns.Module("style", function() -- (the rest of this file: only with Style loaded, Modules.lua)

local SAMPLE_ICON = "Interface\\Icons\\Spell_Holy_PowerWordShield"
local SAMPLE_SIZE = 44 -- the sample shield's size
local ICON = 44 -- the sample icons' size, pixels
local DRAIN = 6 -- seconds the third sample takes to drain, over and over

-- The preview: three tracked buff icons with the ring drawn by the ring's own
-- code (UI/CooldownRing.lua's ns.CooldownRingDraw) in this page's look: full,
-- after a few hits, and one draining over and over. Over the Style pages' scene.
local function MakePreview(parent, width)
	local L = ns.L
	local preview = CreateFrame("Frame", nil, parent)
	preview:SetSize(width, 150)
	ns.StyleScene(preview, 0.6) -- (StylePages.lua)
	local caption = preview:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	caption:SetText(L["Preview"])
	caption:SetPoint("TOPLEFT", 6, -5)
	caption.searchSkip = true
	-- (The three in one group, centered, placed once: the preview's fit zooms
	-- its children, and icons placed on it one by one, moved again as it
	-- resized, slid off its left edge, blown up, the user's shot 2026-11-23.)
	local SPACING = 120
	local group = CreateFrame("Frame", nil, preview)
	group:SetSize(SPACING * 3, ICON + 56)
	group:SetPoint("CENTER", preview, "CENTER", 0, 0)
	local samples = {}
	for i, label in ipairs({ L["Full"], L["After a few hits"], L["Draining"] }) do
		local icon = CreateFrame("Frame", nil, group)
		icon:SetSize(ICON, ICON)
		icon:SetPoint("TOP", group, "TOPLEFT", SPACING * (i - 0.5), -8)
		icon.Icon = icon:CreateTexture(nil, "ARTWORK")
		icon.Icon:SetAllPoints()
		icon.Icon:SetTexture(SAMPLE_ICON)
		icon.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		local name = group:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		name:SetText(label)
		name:SetPoint("TOP", icon, "BOTTOM", 0, -14)
		name.searchSkip = true
		samples[i] = icon
	end
	local started = GetTime()
	local function Draining()
		local t = ((GetTime() - started) % (DRAIN + 1)) / DRAIN
		return math.max(0, math.floor(SAMPLE_SIZE * (1 - math.min(t, 1)) + 0.5))
	end
	function preview:Refresh()
		if not ns.CooldownRingDraw then return end
		local look = ns.CooldownRingLook()
		ns.CooldownRingDraw(samples[1], look, SAMPLE_SIZE, SAMPLE_SIZE)
		ns.CooldownRingDraw(samples[2], look, SAMPLE_SIZE, 26)
		ns.CooldownRingDraw(samples[3], look, SAMPLE_SIZE, Draining())
	end
	local since = 0
	ns.SetOnUpdate(preview, function(_, elapsed)
		since = since + elapsed
		if since < 0.1 then return end
		since = 0
		if ns.CooldownRingDraw then
			ns.CooldownRingDraw(samples[3], ns.CooldownRingLook(), SAMPLE_SIZE, Draining())
		end
	end)
	preview:SetScript("OnShow", preview.Refresh)
	return preview
end
ns.MakeCdmStylePreview = MakePreview

function ns.CreateCdmStylePanel(kit)
	local L = ns.L
	local canvas, content = kit.CreateScrollPage()
	local title = kit.Label(content, "GameFontNormalLarge", L["Cooldown Manager Style"])
	local tabs = ns.PageTabs(content, ns.ShowInTabs("cdm"), ns.ShowInIndex("cdm", "Cooldown Manager Style"))
	title:SetPoint("TOPLEFT", tabs, "BOTTOMLEFT", 8, -14)
	local intro = kit.PageIntro(content, title,
		L["How the drain ring on your tracked buffs looks. Pick which buffs get one on the Cooldown Manager page, under Look."])
	local preview -- (below: drawn again as each setting changes)
	local function Changed()
		if ns.ApplyCooldownRing then ns.ApplyCooldownRing() end
		if preview then preview:Refresh() end
	end
	local switch = kit.PageSwitch(content, "cdmStyle", L["Enable Page"],
		L["Turns this page's ring look on or off. Off: the ring's own look."], intro, Changed)
	local stack = kit.Stack(switch, "check")
	local rows = ns.StyleRows(kit, content, stack, Changed, "cdmStyle")

	preview = MakePreview(content, 480)
	stack:Add(preview, "label")
	ns.StylePopout(preview, kit.Tooltip) -- (StylePages.lua)
	kit.AddControl(preview)
	-- The look in the Style pages' inline Look panel (as Action Bar Style's):
	-- a tab each for the ring, its color and the amount, pill buttons. (The
	-- plain rows before read "like dogshit", the user 2026-11-23: choices
	-- wrapping ragged, a color row on its own, bare number boxes.)
	stack:Header(content, L["Look"])
	rows.Look("", L["Drain ring"], {
		inline = true,
		tabs = { default = function(key) return ns.DEFAULTS[key] end, source = ns.PageLookSource,
			copyKind = "cdmRing", copyName = L["Drain ring"] },
		groups = { { "Ring", { { "ring", "Ring" } } }, { "Color", { { "color", "Color" } } },
			{ "Amount", { { "amount", "Amount" } } } },
		ring = function(look)
			look.Choices(L["Style:"], "cdmRingStyle", {
				{ "pips", L["Pips"], L["Eight chunky segments round the icon."] },
				{ "smooth", L["Smooth"], L["One thin ring round the icon."] },
				{ "liquid", L["Liquid"], L["The icon empties from the top down."] },
				{ "bar", L["Bar under"], L["A thin bar under the icon."] },
			})
			look.Slider("cdmRingScale", L["Size"], 110, 180, 5, "%d%%", 100, L["How big the ring is next to the icon."],
				function(db) return look.On(db) and (db.cdmRingStyle == "pips" or db.cdmRingStyle == "smooth") end)
			look.Slider("cdmRingTrack", L["Empty part"], 0, 90, 5, "%d%%", 100,
				L["How dark the spent part shows. 0: hidden."])
		end,
		color = function(look)
			look.Choices(L["Color:"], "cdmRingColor", {
				{ "class", L["Class"], L["The ring in your class's color."] },
				{ "grad", L["Green to red"], L["Green at the full end to red at the empty end: what's left reddens as it drains."] },
				{ "custom", L["Custom"], L["The color you pick below."] },
				{ "white", L["White"], L["A plain white ring."] },
			})
			look.Color(L["Custom color"], { "cdmRingR", "cdmRingG", "cdmRingB" }, L["Click to choose the ring's color."],
				function(db) return look.On(db) and db.cdmRingColor == "custom" end)
		end,
		amount = function(look)
			look.Choices(L["Place:"], "cdmAmountPlace", {
				{ "middle", L["Middle"], L["In the middle of the icon."] },
				{ "bottom", L["Bottom"], L["At the bottom of the icon."] },
			})
			look.Slider("cdmAmountSize", L["Size"], 8, 20, 1, "%d", nil, L["How big the amount's text is."])
		end,
	})
	stack:Note(content, L["Which buffs get a ring, and the game's timer: the Cooldown Manager page, under Look. " ..
		"Round icons: Action Bar Style."], 460)

	canvas:SetScript("OnShow", kit.PageShown(function() kit.Refresh() end, content))
	canvas:Hide()
	kit.RegisterSubpage(canvas, "Cooldown Manager Style", L["Cooldown Manager Style"])
end
end) -- (ns.Module "style")
