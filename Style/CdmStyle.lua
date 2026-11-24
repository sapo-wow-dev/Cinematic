-- The Style hub's Cooldown Manager page (Cooldown Manager Style, 2026-11-23):
-- how the drain ring on tracked buff icons looks (UI/CooldownRing.lua). Which
-- buffs get one, and their game timer, stay on the Cooldown Manager page's
-- Look grid (Ring, Amount, Numbers). The icons' shape: its Icons folder tab, as the
-- action buttons (Action Bar Style's) or square / round of its own. Page off: the ring keeps its defaults (ns.StyleLook). Its settings'
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
		-- (Cut round while the real icons are: the Shape tab, or Action Bar Style's.)
		icon.mask = icon:CreateMaskTexture()
		icon.mask:SetAllPoints(icon.Icon)
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
	local masked = false
	function preview:Refresh()
		local art = ns.CooldownRoundArt and ns.CooldownRoundArt() or nil
		if (art ~= nil) ~= masked then
			masked = art ~= nil
			for _, icon in ipairs(samples) do
				if masked then
					icon.mask:SetTexture(art, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
					icon.Icon:AddMaskTexture(icon.mask)
				else
					icon.Icon:RemoveMaskTexture(icon.mask)
				end
			end
		end
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
		-- (The icons' shape: Action Bar Style's pass, which waits out a fight.)
		if ns.RefreshActionBarStyle then ns.RefreshActionBarStyle() end
		if preview then preview:Refresh() end
	end
	local switch = kit.PageSwitch(content, "cdmStyle", L["Enable Page"],
		L["Turns this page's ring look on or off. Off: the ring's own look."], intro, Changed)
	local stack = kit.Stack(switch, "check")

	preview = MakePreview(content, 480)
	stack:Add(preview, "label")
	ns.StylePopout(preview, kit.Tooltip) -- (StylePages.lua)
	kit.AddControl(preview)
	-- The look in the Style pages' inline Look panel (as Action Bar Style's):
	-- a tab each for the ring, its color and the amount, pill buttons. (The
	-- plain rows before read "like dogshit", the user 2026-11-23: choices
	-- wrapping ragged, a color row on its own, bare number boxes.)
	local lookHeader = stack:Header(content, L["Look"])
	-- Folder tabs under Look, one shown at a time (the user's mockup,
	-- 2026-11-23): Drain ring (the ring's Look panel, its title the tab's) and
	-- Icons (the icons' shape, apart from the ring's: as a tab of Drain ring's or
	-- a panel stacked over it, it read as the ring's). Each tab a container: its
	-- right-click turns it off (ns.CdmStyleTabOn, UI/CooldownRing.lua).
	local hosts, _, TabsShown = ns.PageTabsBelow(content, lookHeader, {
		{ L["Drain ring"], L["How the drain ring on your tracked buffs looks."] },
		{ L["Icons"], L["The Cooldown Manager icons' shape."] },
	}, ns.CDM_STYLE_TABS)
	local function HostStack(host)
		local top = CreateFrame("Frame", nil, host)
		top:SetSize(1, 1)
		top:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
		return kit.Stack(top, "label")
	end
	local ringStack, iconStack = HostStack(hosts[1]), HostStack(hosts[2])
	local ringRows = ns.StyleRows(kit, hosts[1], ringStack, Changed, "cdmStyle")
	local iconRows = ns.StyleRows(kit, hosts[2], iconStack, Changed, "cdmStyle", nil, { pictures = true })
	-- (Round icons without round action buttons: the user's ask, 2026-11-23.)
	iconRows.Choices(L["Shape:"], "cdmIconShape", {
		{ "bars", L["Same as action bars"], L["The icons take Action Bar Style's shape."] },
		{ "square", L["Square"], L["Square icons, whatever the action buttons are."] },
		{ "round", L["Round"], L["Round icons, whatever the action buttons are."] },
	})
	ringRows.Look("", L["Drain ring"], {
		inline = true,
		noTitle = true, -- (its folder tab names it)
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
				{ "grad", L["Gradient"], L["From the full end's color to the empty end's: what's left turns toward the empty color as it drains."] },
				{ "custom", L["Custom"], L["The color you pick below."] },
				{ "white", L["White"], L["A plain white ring."] },
			})
			-- (Each color row greyed unless its pick is on.)
			local function Is(mode) return function(db) return look.On(db) and db.cdmRingColor == mode end end
			look.Color(L["Custom color"], { "cdmRingR", "cdmRingG", "cdmRingB" }, L["Click to choose the ring's color."],
				Is("custom"))
			look.Color(L["Full end"], { "cdmGradFullR", "cdmGradFullG", "cdmGradFullB" },
				L["The gradient's color where the shield is full."], Is("grad"))
			look.Color(L["Empty end"], { "cdmGradEmptyR", "cdmGradEmptyG", "cdmGradEmptyB" },
				L["The gradient's color where the shield runs out."], Is("grad"))
		end,
		amount = function(look)
			-- (From the middle, nudged: the user's pick over Middle / Bottom, 2026-11-23.)
			look.Slider("cdmAmountX", L["Left / right"], -30, 30, 1, "%d", nil,
				L["Moves the amount left or right from the icon's middle."])
			look.Slider("cdmAmountY", L["Down / up"], -30, 30, 1, "%d", nil,
				L["Moves the amount down or up from the icon's middle."])
			look.Slider("cdmAmountSize", L["Size"], 8, 20, 1, "%d", nil, L["How big the amount's text is."])
		end,
	})
	ringStack:Note(hosts[1], L["Which buffs get a ring, and the game's timer: the Cooldown Manager page, under Look."], 460)

	canvas:SetScript("OnShow", kit.PageShown(function()
		kit.Refresh()
		TabsShown()
	end, content))
	canvas:Hide()
	kit.RegisterSubpage(canvas, "Cooldown Manager Style", L["Cooldown Manager Style"])
end
end) -- (ns.Module "style")
