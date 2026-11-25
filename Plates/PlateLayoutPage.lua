-- Nameplate Style's Layout tab: where each part of the nameplates sits
-- (PlateLayout.lua does it). The game's own plate as the preview (PlateCopy,
-- the Nameplate Style previewer): click a part on it or in the list, drag it,
-- or nudge it with the arrow keys (Shift: 5); its fields under the preview.
-- Guides as marks over and under the plate, never across it: Unit (white,
-- where the game anchors it) and, with Balanced or Custom, Plate's middle
-- (blue, the middle of what's shown), and a status line in words. The user's
-- mockup, 2026-11-25 (Tools/plate-layout-plan.md).
-- Forever only for now: no page on retail (hide-unclickable).

local _, ns = ...
ns.Module("style", function() -- (the rest of this file: only with Style loaded, Modules.lua)
local L = ns.L

-- The Layout for picks: "all", then the kinds with their names, and the
-- Unit pick the preview shows for each (PlateRowLook's SAMPLES order).
local FOR = {
	{ "all", "All plates", 1 }, { "hostile", "Hostile", 1 }, { "neutral", "Neutral", 2 },
	{ "friendly", "Friendly NPCs", 3 }, { "player", "Players", 4 },
}
local COUNT_NAMES = { always = "Always counts", shown = "Counts while shown", never = "Doesn't count" }

function ns.CreatePlateLayoutPage(kit)
	if ns.isRetail then return end
	local PARTS = ns.PLATE_LAYOUT_PARTS
	-- (One range for every way of moving: PlateLayout.lua's. Audit 2026-11-25.)
	local RANGE, Clamp = ns.PLATE_LAYOUT_RANGE, ns.PlateLayoutClamp
	local canvas, content = kit.CreateScrollPage()
	canvas:Hide() -- (at once: a build that stops partway never leaves the page up)
	local title = kit.Label(content, "GameFontNormalLarge", L["Nameplate Layout"])
	local tabs = ns.PageTabs(content, ns.ShowInTabs("plates"), ns.ShowInIndex("plates", "Nameplate Layout"))
	title:SetPoint("TOPLEFT", tabs, "BOTTOMLEFT", 8, -14)
	local intro = kit.PageIntro(content, title, L["Where each part of the nameplates sits. Click a part on the " ..
		"plate or in the list, drag it or nudge it with the arrow keys, and keep the plate balanced on its unit."])

	local editKey = "all" -- (the layout being edited: "all" or a kind)
	local selected = "level"
	local holder, overlay -- (below)
	local Redraw, RedrawOverlay -- (below)

	-- The layout shown and edited: the kind's own when it has one ticked, else
	-- All plates' (read); made when first changed (write).
	-- (A kind's own layout starts as a copy of All plates': its first change, or Own
	-- layout ticked, used to start it empty, and that kind's plates lost every other
	-- change made for all plates. Audit 2026-11-25.)
	local function Copy(value)
		if type(value) ~= "table" then return value end
		local made = {}
		for key, each in pairs(value) do made[key] = Copy(each) end
		return made
	end
	local function OwnFromAll(layout)
		if not layout or layout.own then return end
		for key in pairs(layout) do layout[key] = nil end
		for key, each in pairs(Copy(ns.PlateLayoutGet("all")) or {}) do layout[key] = each end
		if type(layout.parts) ~= "table" then layout.parts = {} end
		layout.own, layout.started = true, true
	end
	local function Editing(create)
		local layout = ns.PlateLayoutGet(editKey, create)
		if create and layout and editKey ~= "all" then OwnFromAll(layout) end
		return layout
	end
	local function Shown()
		if editKey ~= "all" then
			local own = ns.PlateLayoutGet(editKey)
			if own and own.own then return own end
		end
		return ns.PlateLayoutGet("all")
	end
	local function Part(create)
		return ns.PlateLayoutPart(Editing(create), selected, create)
	end
	local function Changed()
		ns.PlateLayoutChanged()
		if Redraw then Redraw() end
		kit.Refresh()
	end

	local switch = kit.PageSwitch(content, "plateLayout", L["Enable Page"],
		L["When on, the nameplates' parts sit where this page puts them. When off, where the game puts them."], intro,
		Changed)
	local stack = kit.Stack(switch, "check")
	-- The preview first, as every Style page's: the shared preview frame
	-- (StylePages.lua's ns.StylePopout: held at the page's top as you scroll,
	-- popped out into its own window and docked, sized to the screen's shape),
	-- the Nameplate Style previewer filling it. (The user, 2026-11-25: a stage
	-- of its own that couldn't pop out didn't fit the rest of the addon.)
	local preview = CreateFrame("Frame", nil, content)
	preview:SetSize(560, 190)
	preview.minHeight = 280 -- (the plate with its debuffs, its lists under it, the guides' strips over and under it)
	stack:Add(preview, "label")
	if preview.SetClipsChildren then preview:SetClipsChildren(true) end
	-- (Its Refresh before StylePopout: the fitter wraps it, and draws it again as it's resized.)
	preview.Refresh = function() if Redraw then Redraw() end end
	ns.StylePopout(preview, kit.Tooltip, L["Nameplate Layout"])
	-- (The editor's width: stage, rows and the parts panel line up on it. 560, as
	-- Nameplate Style's own preview: at 640 the right side ran under the page's
	-- scroll bar, run qc3be.)
	local WIDTH = 560

	-- Buttons drawn as the Look panels' segmented buttons (StylePages.lua
	-- rows.Segments: dark, a gold line under it and gold words while on), for
	-- the few here that aren't a setting's (the preview's toggles, Mirror and
	-- the resets). (The user, 2026-11-25: designs of my own didn't fit the addon.)
	local function Flat(parent, text, width, onClick)
		local button = CreateFrame("Button", nil, parent)
		button:SetSize(width, 22)
		local back = button:CreateTexture(nil, "BACKGROUND")
		back:SetAllPoints()
		local line = button:CreateTexture(nil, "ARTWORK")
		line:SetPoint("BOTTOMLEFT")
		line:SetPoint("BOTTOMRIGHT")
		line:SetHeight(2)
		line:SetColorTexture(1, 0.82, 0, 1)
		local words = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		words:SetPoint("CENTER", 0, 1)
		words:SetText(text)
		button:SetWidth(math.max(width, words:GetStringWidth() + 20))
		local glow = button:CreateTexture(nil, "HIGHLIGHT")
		glow:SetAllPoints()
		glow:SetColorTexture(1, 1, 1, 0.07)
		function button.SetOn(_, on)
			back:SetColorTexture(on and 0.2 or 0.1, on and 0.17 or 0.1, on and 0.08 or 0.12, 0.95)
			line:SetShown(on and true or false)
			if on then words:SetTextColor(1, 0.82, 0) else words:SetTextColor(0.85, 0.85, 0.85) end
		end
		button:SetOn(false)
		button:SetScript("OnClick", onClick)
		return button
	end
	local function Caption(parent, text)
		local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		label:SetText(text)
		return label
	end

	-- Row 1: Layout for (and its own layout tick), the presets at the right.
	local row1 = CreateFrame("Frame", nil, content)
	row1:SetSize(WIDTH, 28)
	stack:Add(row1, "label")
	local forLabel = Caption(row1, L["Layout for"])
	forLabel:SetPoint("LEFT", row1, "LEFT", 0, 0)
	local forDrop = kit.Dropdown(content, { noSettingId = true, get = function() return editKey end,
		set = function(value) editKey = value end }, (function()
		local list = {}
		for _, each in ipairs(FOR) do list[#list + 1] = { text = L[each[2]], value = each[1] } end
		return list
	end)(), 170, function(value)
		for _, each in ipairs(FOR) do
			if each[1] == value and holder and holder.PickSample then holder.PickSample(each[3]) end
		end
		Changed()
	end)
	forDrop:SetPoint("LEFT", forLabel, "RIGHT", 8, 0)
	kit.Tooltip(forDrop, L["Which plates this layout is for. A kind uses All plates' until you tick Own layout."])
	local own = kit.Check(content, { noSettingId = true, get = function()
		local layout = ns.PlateLayoutGet(editKey)
		return layout and layout.own and true or false
	end, set = function() end }, L["Own layout"], L["This kind's plates get a layout of their own, not All plates'."],
		function(value)
			-- (A Check's onChange saves in its place.)
			local layout = ns.PlateLayoutGet(editKey, true)
			-- (Ticked: a copy of All plates' to start from, then its own. Unticked: kept,
			-- unused, for the next tick.)
			if value and layout.started then
				layout.own = true
			elseif value then
				OwnFromAll(layout)
			else
				layout.own = nil
			end
			Changed()
		end)
	own:SetPoint("LEFT", forDrop, "RIGHT", 12, 0)
	local PRESETS = { { "game", "Game's" }, { "balanced", "Balanced" }, { "compact", "Compact" },
		{ "namein", "Name in the bar" } }
	local presetDrop = kit.Dropdown(content, { noSettingId = true, get = function() return nil end,
		set = function() end }, (function()
		local list = {}
		for _, each in ipairs(PRESETS) do list[#list + 1] = { text = L[each[2]], value = each[1] } end
		return list
	end)(), 150, function(value)
		if ns.PlateLayoutPreset then ns.PlateLayoutPreset(Editing(true), value, holder and holder.plate) end
		Changed()
	end)
	presetDrop:SetPoint("RIGHT", row1, "RIGHT", 0, 0)
	if presetDrop.SetDefaultText then presetDrop:SetDefaultText(L["Preset"]) end
	kit.Tooltip(presetDrop, L["A starting point: the game's places, balanced, compact, or the name in the bar."])

	-- Row 2: the center, the Look panels' own segmented buttons (StylePages.lua
	-- rows.Segments: its heading, joined buttons, the picked one gold): the
	-- game's bar, balanced on the unit, or shifted by hand (its two boxes
	-- beside, Custom's only).
	local styleRows = ns.StyleRows(kit, content, stack, Changed, "plateLayout")
	local lastCenter = styleRows.Segments(L["Center"], { noSettingId = true, get = function()
		local layout = Shown()
		return layout and layout.center or "bar"
	end, set = function(value)
		Editing(true).center = value ~= "bar" and value or nil
	end }, {
		{ "bar", L["Bar (the game's)"], L["The plate sits as the game puts it."] },
		{ "balanced", L["Balanced"], L["Moved so what's shown is centered on its unit."] },
		{ "custom", L["Custom"], L["Moved by your own amount."] },
	}, L["Where the plate sits on its unit."])
	local function CenterField(field)
		return { noSettingId = true, get = function()
			local layout = Shown()
			return layout and layout[field] or 0
		end, set = function(value) Editing(true)[field] = value ~= 0 and value or nil end }
	end
	local customLine = kit.BoxLine(content)
	customLine:SetPoint("LEFT", lastCenter, "RIGHT", 16, 0)
	customLine:Box(L["Shift"], CenterField("cx"), -RANGE.x, RANGE.x, 1, "%d", 1,
		L["Moves the whole plate left or right."], Changed, 40)
	customLine:Box(L["Up"], CenterField("cy"), -RANGE.y, RANGE.y, 1, "%d", 1,
		L["Moves the whole plate down or up."], Changed, 40)

	-- The previewer in the shared preview frame, as Nameplate Style's (Options.lua):
	-- filling it, its own Scene pill in place of the frame's backdrop button.
	holder = ns.MakePlateRowLookPreview(preview, WIDTH, "others")
	holder:ClearAllPoints()
	holder:SetAllPoints(preview)
	holder.zoomSkip, holder.noAutoFit = true, true
	if preview.backButton then preview.backButton:Hide() end
	preview.backButton = nil
	local game = holder.gamePlate
	overlay = CreateFrame("Frame", nil, holder)
	overlay:SetAllPoints(holder)
	overlay:SetFrameLevel(holder:GetFrameLevel() + 30)
	ns.platePreviewOverlay = overlay -- (the tests read it: /cine debug platelayout)
	-- The guides: marks off the plate, never across it (the user, 2026-11-25: lines
	-- over the bar but under the cast bar, "wtf is that"; and before that, two lines
	-- no one could name). A short tick over the plate and one under it for each:
	--   Unit (white): where the game puts the plate on its unit, always;
	--   Plate's middle (blue): the middle of what shows, only while Center is
	--   Balanced or Custom and it's off the unit, joined to Unit's tick by a thin line.
	-- A status line by the toggles says it in words: "Centered on the unit", or how
	-- far off and what centers it.
	-- The stage's strips, from its top: the toggles and status (6 to 28), the tick
	-- names (to 46), the ticks (to 58), then the plate's room; under the plate, its
	-- lower ticks (BOTTOM_STRIP over the Unit and State lists).
	local TOP, BOTTOM_STRIP, TICK = 62, 14, 10
	local NAME_Y, TICK_Y = 46, 48 -- (down from the stage's top: names' bottom, ticks' top)
	local function Mark(r, g, b)
		local mark = { color = { r, g, b } }
		mark.top = overlay:CreateTexture(nil, "OVERLAY")
		mark.bottom = overlay:CreateTexture(nil, "OVERLAY")
		for _, tick in ipairs({ mark.top, mark.bottom }) do
			tick:SetColorTexture(r, g, b, 0.95)
			tick:SetSize(2, TICK)
		end
		mark.name = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		mark.name:SetTextColor(r, g, b)
		mark.name.searchSkip = true
		return mark
	end
	local unitMark, groupMark = Mark(1, 1, 1), Mark(0.45, 0.85, 1)
	-- (The thin line joining the two top ticks: how far off, drawn.)
	local span = overlay:CreateTexture(nil, "OVERLAY")
	span:SetColorTexture(1, 0.69, 0.38, 0.85)
	span:SetHeight(1)
	local status = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	status:SetJustifyH("LEFT")
	status.searchSkip = true
	local offText = status -- (the tests read the page's readout)
	local guides = true
	local outline = {}
	for i = 1, 4 do
		outline[i] = overlay:CreateTexture(nil, "OVERLAY")
		outline[i]:SetColorTexture(1, 0.85, 0.2, 0.95)
	end
	local hits = {} -- [key] = a button over that part

	-- A part's frame on the preview's copy.
	local function Field(root, path)
		local value = root
		for name in path:gmatch("[^.]+") do
			if type(value) ~= "table" then return nil end
			value = value[name]
		end
		return value
	end
	local function CopyOf() return game and game.gameCopy end
	-- A frame's rect in the overlay's units (nil when it can't be measured).
	local function Rect(frame)
		if not (frame and frame.GetLeft) then return nil end
		local ok, l, r, b, t, eff = pcall(function()
			return frame:GetLeft(), frame:GetRight(), frame:GetBottom(), frame:GetTop(), frame:GetEffectiveScale()
		end)
		if not (ok and type(l) == "number" and type(r) == "number" and type(b) == "number" and type(t) == "number") then
			return nil
		end
		local oe = overlay:GetEffectiveScale()
		local ol, ob = overlay:GetLeft(), overlay:GetBottom()
		if not (ol and ob) then return nil end
		return l * eff / oe - ol, r * eff / oe - ol, b * eff / oe - ob, t * eff / oe - ob
	end
	local function Visible(frame)
		local ok, shown = pcall(frame.IsVisible, frame)
		return ok and shown
	end
	-- (An aura list is up the whole time, empty or not: a box over an empty one
	-- sat over nothing at the plate's top, run q93c1. Up only with an icon shown.)
	local LISTS = { debuffs = true, buffs = true, crowd = true }
	local function HasIcon(frame)
		local ok, kids = pcall(function() return { frame:GetChildren() } end)
		for _, kid in ipairs(ok and kids or {}) do
			if Visible(kid) then return true end
		end
		return false
	end

	-- (Over every frame of the plate, so nothing of ours is under one part and over
	-- another: the game's cast bar is its own frame, drawn higher than the bar.)
	local function TopLevel(frame, depth)
		local top = frame:GetFrameLevel()
		if depth < 4 then
			for _, kid in ipairs({ frame:GetChildren() }) do top = math.max(top, TopLevel(kid, depth + 1)) end
		end
		return top
	end
	RedrawOverlay = function()
		local copy = CopyOf()
		overlay:SetShown(copy ~= nil and game:IsShown())
		if not copy then return end
		local okTop, top = pcall(TopLevel, copy, 0)
		if okTop and top >= overlay:GetFrameLevel() then overlay:SetFrameLevel(math.min(top + 5, 9000)) end
		local cl, cr = Rect(copy)
		local gl, gr
		for _, part in ipairs(PARTS) do
			local frame = Field(copy, part.path)
			local hit = hits[part.key]
			local l, r, b, t
			-- (The soft target's frame is up with no icon in it: counted only with its icon
			-- shown, run q0fbf.)
			local up = frame and Visible(frame) and (not LISTS[part.key] or HasIcon(frame))
				and (part.key ~= "softTarget" or (frame.Icon and Visible(frame.Icon)))
			if up then l, r, b, t = Rect(frame) end
			if l and r - l > 1 then
				-- (The readout counts as Balanced does: a part set to Doesn't count left
				-- out. Run q2b06: it said 38 right of a balanced plate.)
				local p = ns.PlateLayoutPart(Shown(), part.key)
				if not (p and p.count == "never") then
					gl, gr = gl and math.min(gl, l) or l, gr and math.max(gr, r) or r
				end
				if not hit then
					hit = CreateFrame("Button", nil, overlay)
					hit.key = part.key
					hit:RegisterForClicks("LeftButtonUp")
					hit:SetScript("OnMouseDown", function(self) ns.PlateLayoutPageDrag(self.key) end)
					hit:SetScript("OnMouseUp", function() ns.PlateLayoutPageDrag(nil) end)
					kit.Tooltip(hit, L[part.label])
					hit:HookScript("OnEnter", function() if ns.PlateLayoutPageKeys then ns.PlateLayoutPageKeys() end end)
					hits[part.key] = hit
				end
				hit:ClearAllPoints()
				hit:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", l - 2, b - 2)
				hit:SetSize(math.max(6, r - l + 4), math.max(6, t - b + 4))
				-- (Smaller parts over bigger ones: the bar under its level box.)
				hit:SetFrameLevel(overlay:GetFrameLevel() + math.max(1, 40 - math.floor((r - l) / 8)))
				hit:Show()
				if part.key == selected then
					outline[1]:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", l - 2, t + 1)
					outline[1]:SetSize(r - l + 4, 1)
					outline[2]:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", l - 2, b - 2)
					outline[2]:SetSize(r - l + 4, 1)
					outline[3]:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", l - 2, b - 2)
					outline[3]:SetSize(1, t - b + 4)
					outline[4]:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", r + 1, b - 2)
					outline[4]:SetSize(1, t - b + 4)
				end
			elseif hit then
				hit:Hide()
			end
			if part.key == selected then
				for _, edge in ipairs(outline) do edge:SetShown(l ~= nil and r - l > 1) end
			end
		end
		-- The marks and the status.
		local height = overlay:GetHeight()
		local lift = holder.plateLift or 38
		local unitX = cl and (cl + cr) / 2
		local groupX = gl and (gl + gr) / 2
		local off = 0
		if unitX and groupX then off = (groupX - unitX) / (copy:GetEffectiveScale() / overlay:GetEffectiveScale()) end
		local together = not groupX or math.abs(off) < 0.5
		local layout = Shown()
		local center = layout and layout.center or "bar"
		local amount = math.floor(math.abs(off) + 0.5)
		local side = off > 0 and L["right"] or L["left"]
		-- (A mark: its two ticks at x, its name over the top one, to one side of the
		-- tick (away from the other mark) or centered on it.)
		local function Place(mark, x, text, nameSide)
			local on = guides and x ~= nil
			for _, piece in ipairs({ mark.top, mark.bottom, mark.name }) do
				piece:ClearAllPoints()
				piece:SetShown(on)
			end
			if not on then return end
			x = math.floor(x + 0.5)
			mark.top:SetPoint("TOPLEFT", overlay, "TOPLEFT", x - 1, -TICK_Y)
			mark.bottom:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", x - 1, lift + 2)
			mark.name:SetText(text)
			if nameSide == "left" then
				mark.name:SetPoint("BOTTOMRIGHT", overlay, "TOPLEFT", x + 1, -NAME_Y)
			elseif nameSide == "right" then
				mark.name:SetPoint("BOTTOMLEFT", overlay, "TOPLEFT", x - 1, -NAME_Y)
			else
				mark.name:SetPoint("BOTTOM", overlay, "TOPLEFT", x, -NAME_Y)
			end
		end
		-- (The middle's own mark only where it's yours to move: Balanced or Custom.)
		local showMiddle = not together and center ~= "bar"
		local right = off > 0
		Place(unitMark, unitX, L["Unit"], showMiddle and (right and "left" or "right") or "center")
		Place(groupMark, showMiddle and groupX or nil, L["Plate's middle"], right and "right" or "left")
		span:ClearAllPoints()
		span:SetShown(guides and showMiddle and unitX ~= nil)
		if guides and showMiddle and unitX then
			local a, b = math.min(unitX, groupX), math.max(unitX, groupX)
			span:SetPoint("TOPLEFT", overlay, "TOPLEFT", math.floor(a + 0.5), -TICK_Y)
			span:SetWidth(math.max(1, math.floor(b - a + 0.5)))
		end
		-- (In words, beside the toggles.)
		status:SetShown(guides and unitX ~= nil)
		if together then
			status:SetText("|cff7fd97f" .. L["Centered on the unit"] .. "|r")
		elseif center == "bar" then
			status:SetText("|cffffb060" .. L["What shows sits %d %s of the unit."]:format(amount, side) .. "|r |cffb0a890"
				.. L["Balanced centers it."] .. "|r")
		elseif center == "custom" then
			-- (What you moved it by, then where that leaves what shows: run q8f7e said
			-- "41 right" for a shift of 15, the level box's own 26 in it.)
			local cx = layout and layout.cx or 0
			local moved = cx == 0 and L["Not moved"] or L["Moved %d %s"]:format(math.abs(cx), cx > 0 and L["right"] or L["left"])
			status:SetText("|cffffd100" .. moved .. ".|r |cffb0a890" .. L["What shows sits %d %s of the unit."]:format(amount, side)
				.. "|r")
		else
			status:SetText("|cffffb060" .. L["%d %s of the unit"]:format(amount, side) .. "|r")
		end
		if height < 1 then status:Hide() end
	end

	-- The preview drawn again: the previewer's plate, then the layout on it.
	Redraw = function()
		if not holder:IsVisible() then return end
		-- (The plate as big as the frame's room allows (it's sized to the screen's
		-- shape, and smaller popped out or held at the top), as Nameplate Style's
		-- preview fits its: cast bar to name, or to the debuffs when they're up,
		-- in the middle of the room between the lists and the line names.)
		-- (The plate's tops, in its own units: its name; its debuffs; the soft target's
		-- quest icon, the highest (24 high, hung 8 under the plate frame's 85 top:
		-- run q0fbf, the Unit mark sat on it).)
		local NAME_TOP, DEBUFF_TOP, SOFT_TOP = 58.3, 89.1, 102
		local lift = holder.plateLift or 38
		local width, height = preview:GetWidth() or WIDTH, preview:GetHeight() or 250
		-- (Its room: between the top strips (toggles, names, ticks) and the lower ticks.)
		local room = height - lift - BOTTOM_STRIP - TOP
		local states = ns.PlatePreviewStates and ns.PlatePreviewStates() or {}
		local tallest = states.quest and SOFT_TOP or DEBUFF_TOP -- (the size: steady as debuffs come and go)
		local scale = math.max(0.6, math.min(1.6, (room - 8) / tallest, (width - 12) / 360))
		local top = states.quest and SOFT_TOP or states.debuffs and DEBUFF_TOP or NAME_TOP
		holder.gameShift, holder.gameScale = nil, scale
		holder.gameLift = lift + BOTTOM_STRIP + (room - top * scale) / 2
		holder:Refresh()
		local layout = Shown()
		if game and game.gameCopy then
			game.onLayoutDirty = RedrawOverlay
			ns.PlateLayoutApply(game, layout or false)
		end
		-- (Kept in view: every part shown inside the stage's room. A part moved far
		-- gets the plate drawn smaller and moved over, so it can still be seen and
		-- grabbed. Audit 2026-11-25: one dragged off the preview was lost.)
		local copy = CopyOf()
		if copy and game:IsShown() then
			local bl, br, bb, bt
			for _, part in ipairs(PARTS) do
				local frame = Field(copy, part.path)
				if frame and Visible(frame) and (not LISTS[part.key] or HasIcon(frame))
					and (part.key ~= "softTarget" or (frame.Icon and Visible(frame.Icon))) then
					local l, r, b, t = Rect(frame)
					if l and r - l > 1 then
						bl, br = bl and math.min(bl, l) or l, br and math.max(br, r) or r
						bb, bt = bb and math.min(bb, b) or b, bt and math.max(bt, t) or t
					end
				end
			end
			local left, right, low, high = 8, width - 8, lift + BOTTOM_STRIP, height - TOP
			if bl and br > bl and bt > bb and (bl < left or br > right or bb < low or bt > high) then
				local f = math.min(1, (right - left) / (br - bl), (high - low) / (bt - bb))
				-- (Scaled about the plate's anchor, its bottom middle, then moved inside.)
				local ax, ay = width / 2, holder.gameLift
				local nl, nr = ax + (bl - ax) * f, ax + (br - ax) * f
				local nb, nt = ay + (bb - ay) * f, ay + (bt - ay) * f
				local dx = nl < left and left - nl or nr > right and right - nr or 0
				local dy = nb < low and low - nb or nt > high and high - nt or 0
				local fitted = scale * f
				holder.gameScale = fitted
				holder.gameShift = -dx / fitted -- (its x offset is in the plate's own units)
				holder.gameLift = holder.gameLift + dy
				holder:Refresh()
				ns.PlateLayoutApply(game, layout or false)
			end
		end
		RedrawOverlay()
	end
	holder.onStates = Redraw

	-- Picking a part puts it on the preview (the user, 2026-11-25: Debuffs picked,
	-- no debuffs shown): the preview's state that shows it turned on, the rest
	-- kept. The elite mark takes the marker off: the game hides it under one.
	local PART_STATE = { debuffs = "debuffs", buffs = "buffs", crowd = "crowd", marker = "marker", elite = "elite",
		cast = "casting", castIcon = "casting", castText = "casting", castShield = "locked", softTarget = "quest" }
	local function ShowPart(key)
		local state = PART_STATE[key]
		local states = ns.PlatePreviewStates and ns.PlatePreviewStates()
		if not (state and states and ns.TogglePlatePreviewState) then return false end
		local changed = false
		if key == "elite" and states.marker then
			ns.TogglePlatePreviewState("marker")
			changed = true
		end
		if not states[state] then
			ns.TogglePlatePreviewState(state)
			changed = true
		end
		return changed
	end
	local function Pick(key)
		selected = key
		if ShowPart(key) then Redraw() end
		kit.Refresh()
		RedrawOverlay()
	end

	-- Dragging a part: the cursor's move in the plate's units, snapped to the
	-- game's place and the bar's middle line within 3.
	local drag
	function ns.PlateLayoutPageDrag(key)
		if not key then
			drag = nil
			overlay:SetScript("OnUpdate", nil)
			-- (Dropped: the preview fitted again, so a part moved far stays in view.)
			if Redraw then Redraw() end
			kit.Refresh()
			return
		end
		selected = key
		local p = Part(true)
		local x, y = GetCursorPosition()
		drag = { x = x, y = y, px = p.x or 0, py = p.y or 0 }
		ns.SetOnUpdate(overlay, function()
			local copy = CopyOf()
			if not (drag and copy) then return end
			local cx, cy = GetCursorPosition()
			local scale = copy:GetEffectiveScale()
			-- (Inside the range every way of moving shares: the boxes', the keys'. Audit 2026-11-25.)
			local nx = Clamp(drag.px + (cx - drag.x) / scale, RANGE.x)
			local ny = Clamp(drag.py + (cy - drag.y) / scale, RANGE.y)
			if math.abs(nx) < 3 then nx = 0 end
			if math.abs(ny) < 3 then ny = 0 end
			local part = Part(true)
			part.x, part.y = math.floor(nx + 0.5), math.floor(ny + 0.5)
			if part.x == 0 then part.x = nil end
			if part.y == 0 then part.y = nil end
			ns.PlateLayoutChanged()
			ns.PlateLayoutApply(game, Shown() or false)
			RedrawOverlay()
		end)
		RedrawOverlay()
	end
	-- The arrow keys nudge the picked part while the mouse is over the plate
	-- (1, Shift 5); other keys go on to the game. (Not in a fight: the
	-- keyboard can't be passed on there.)
	-- (Taken on as the mouse comes onto a part, let go once it's off the
	-- preview: no mouse of its own, so the preview's lists stay clickable.)
	-- (Its key script is set only while on: setting OnKeyDown turns the
	-- keyboard on by itself, and a frame left so took every key in the game,
	-- the user 2026-11-25. Every key passes on to the game unless it's an
	-- arrow; any error lets the keyboard go.)
	overlay:EnableMouse(false)
	local keys = CreateFrame("Frame", nil, holder)
	keys:SetAllPoints(holder)
	local NUDGE = { LEFT = { -1, 0 }, RIGHT = { 1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }
	local OnKey
	local function KeysOff()
		if InCombatLockdown() then return end
		pcall(keys.SetScript, keys, "OnKeyDown", nil)
		pcall(keys.EnableKeyboard, keys, false)
	end
	function ns.PlateLayoutPageKeys()
		if InCombatLockdown() or not keys.SetPropagateKeyboardInput then return end
		keys:SetPropagateKeyboardInput(true)
		keys:SetScript("OnKeyDown", OnKey)
		keys:EnableKeyboard(true)
	end
	local function OverPreview()
		local ok, over = pcall(holder.IsMouseOver, holder)
		return ok and over and holder:IsVisible()
	end
	OnKey = function(self, key)
		local step = NUDGE[key]
		if InCombatLockdown() then return end
		if not (step and OverPreview()) then
			self:SetPropagateKeyboardInput(true)
			if not OverPreview() then KeysOff() end
			return
		end
		self:SetPropagateKeyboardInput(false)
		local by = IsShiftKeyDown() and 5 or 1
		local part = Part(true)
		part.x = Clamp((part.x or 0) + step[1] * by, RANGE.x)
		part.y = Clamp((part.y or 0) + step[2] * by, RANGE.y)
		if part.x == 0 then part.x = nil end
		if part.y == 0 then part.y = nil end
		local ok = pcall(Changed)
		if not ok then KeysOff() end
	end

	-- (Two toggles in the stage's top right: every part up, and the lines.)
	local ALL_UP = { "casting", "marker", "debuffs", "buffs", "crowd", "quest" }
	local function AllUp()
		local states = ns.PlatePreviewStates and ns.PlatePreviewStates() or {}
		for _, key in ipairs(ALL_UP) do if not states[key] then return false end end
		return true
	end
	local guideBox, allBox
	guideBox = Flat(overlay, L["Guides"], 64, function()
		guides = not guides
		guideBox:SetOn(guides)
		RedrawOverlay()
	end)
	guideBox:SetOn(true)
	kit.Tooltip(guideBox, L["Marks over and under the plate. Unit (white): where the game puts the plate on its " ..
		"unit. Plate's middle (blue, with Balanced or Custom): the middle of what's showing. The line by these " ..
		"buttons says how far off it is."])
	allBox = Flat(overlay, L["All parts up"], 92, function()
		-- (On: every part up, to lay them all out; off: just the cast.)
		local states = ns.PlatePreviewStates and ns.PlatePreviewStates() or {}
		local on = not AllUp()
		for _, key in ipairs(ALL_UP) do
			if key ~= "casting" and (states[key] and true or false) ~= on and ns.TogglePlatePreviewState then
				ns.TogglePlatePreviewState(key)
			end
			if key == "casting" and not states.casting and ns.TogglePlatePreviewState then ns.TogglePlatePreviewState(key) end
		end
		Redraw()
	end)
	-- (Top left: the shared frame's pop-out and zoom buttons are its top right.)
	allBox:SetPoint("TOPLEFT", overlay, "TOPLEFT", 8, -6)
	guideBox:SetPoint("LEFT", allBox, "RIGHT", 4, 0)
	-- (The status in words after the toggles, short of the top right corner: the
	-- shared preview's pop-out and zoom buttons come up there on hover.)
	status:SetPoint("LEFT", guideBox, "RIGHT", 12, 0)
	status:SetPoint("RIGHT", overlay, "TOPRIGHT", -44, -17)
	status:SetWordWrap(false)
	kit.Tooltip(allBox, L["Shows every part on the preview at once (a cast, a marker, debuffs, crowd control, " ..
		"the soft target icon), to lay them all out. Pick what shows in the State list."])

	-- The parts panel under the stage: the list (gold dot: changed) on the
	-- left, the picked part's fields on the right, on one dark ground.
	local ROW_H = 18
	local panelH = #PARTS * ROW_H + 16
	local partsPanel = CreateFrame("Frame", nil, content)
	partsPanel:SetSize(WIDTH, panelH)
	stack:Add(partsPanel, "label")
	local ground = partsPanel:CreateTexture(nil, "BACKGROUND")
	ground:SetAllPoints()
	ground:SetColorTexture(0.02, 0.02, 0.03, 0.55)
	local divider = partsPanel:CreateTexture(nil, "BORDER")
	divider:SetColorTexture(0.35, 0.3, 0.2, 0.6)
	divider:SetWidth(1)
	divider:SetPoint("TOPLEFT", partsPanel, "TOPLEFT", 178, -8)
	divider:SetPoint("BOTTOMLEFT", partsPanel, "BOTTOMLEFT", 178, 8)
	local list = CreateFrame("Frame", nil, partsPanel)
	list:SetSize(170, #PARTS * ROW_H)
	list:SetPoint("TOPLEFT", partsPanel, "TOPLEFT", 4, -8)
	local rows = {}
	for i, part in ipairs(PARTS) do
		local row = CreateFrame("Button", nil, list)
		row:SetSize(170, ROW_H)
		row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(i - 1) * ROW_H)
		local back = row:CreateTexture(nil, "BACKGROUND")
		back:SetAllPoints()
		back:SetColorTexture(1, 0.82, 0, 0.18)
		row.back = back
		local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		text:SetPoint("LEFT", 6, 0)
		text:SetText(L[part.label])
		row.text = text
		-- (A drawn dot: the menu font has no "●", it showed a box, run qc3be.)
		local dot = row:CreateTexture(nil, "OVERLAY")
		dot:SetSize(6, 6)
		dot:SetPoint("RIGHT", -8, 0)
		dot:SetTexture("Interface\\COMMON\\Indicator-Yellow")
		dot:SetTexCoord(0.2, 0.8, 0.2, 0.8)
		row.dot = dot
		local glow = row:CreateTexture(nil, "HIGHLIGHT")
		glow:SetAllPoints()
		glow:SetColorTexture(1, 1, 1, 0.08)
		row:SetScript("OnClick", function() Pick(part.key) end)
		kit.Tooltip(row, L[part.tip])
		rows[part.key] = row
	end

	local FIELDS_X = 194
	local partTitle = kit.Label(partsPanel, "GameFontNormal", "")
	partTitle:SetPoint("TOPLEFT", partsPanel, "TOPLEFT", FIELDS_X, -10)
	partTitle.searchSkip = true
	local hangsText = kit.Label(partsPanel, "GameFontDisableSmall", "")
	hangsText:SetPoint("LEFT", partTitle, "RIGHT", 10, 0)
	hangsText.searchSkip = true
	local function PartInfo() for _, part in ipairs(PARTS) do if part.key == selected then return part end end end
	local function PartField(field, default)
		return { noSettingId = true, get = function()
			local p = ns.PlateLayoutPart(Shown(), selected)
			local value = p and p[field]
			if value == nil then return default end
			return value
		end, set = function(value)
			local p = Part(true)
			if value == default then value = nil end
			p[field] = value
		end }
	end
	-- Hang on: the game's place, another part, or the plate's middle.
	local hangDrop = kit.Dropdown(content, PartField("to", "game"), function()
		local choices = { { text = L["Where the game hangs it"], value = "game" } }
		for _, part in ipairs(PARTS) do
			if part.key ~= selected and not (ns.PlateLayoutWouldLoop and game and game.gameCopy
				and ns.PlateLayoutWouldLoop(game, selected, part.key)) then
				choices[#choices + 1] = { text = L["On: %s"]:format(L[part.label]), value = part.key }
			end
		end
		choices[#choices + 1] = { text = L["On: the plate's middle"], value = "plate" }
		return choices
	end, 190, Changed)
	hangDrop:SetPoint("TOPLEFT", partsPanel, "TOPLEFT", FIELDS_X - 2, -34)
	kit.Tooltip(hangDrop, L["What this part hangs on. Moving that part moves this one with it."])
	local sideChoices = {}
	for _, side in ipairs(ns.PLATE_LAYOUT_SIDES) do
		sideChoices[#sideChoices + 1] = { text = L[ns.PLATE_LAYOUT_SIDE_INFO[side][5]], value = side }
	end
	local sideDrop = kit.Dropdown(content, PartField("side", "right"), sideChoices, 130, Changed)
	sideDrop:SetPoint("LEFT", hangDrop, "RIGHT", 6, 0)
	kit.Tooltip(sideDrop, L["Which side of that part it sits on."])
	-- (Number boxes, not sliders: wheel or type, one line, the Nameplate Style page's W and H boxes.)
	local moveLine = kit.BoxLine(partsPanel)
	moveLine:SetPoint("TOPLEFT", partsPanel, "TOPLEFT", FIELDS_X, -72)
	moveLine:Box(L["Left / right"], PartField("x", 0), -RANGE.x, RANGE.x, 1, "%d", 1,
		L["Moves it left or right, in the plate's own units. The arrow keys over the plate do the same."], Changed, 44)
	moveLine:Box(L["Down / up"], PartField("y", 0), -RANGE.y, RANGE.y, 1, "%d", 1,
		L["Moves it down or up, in the plate's own units."], Changed, 44)
	local sizeLine = kit.BoxLine(partsPanel)
	sizeLine:SetPoint("TOPLEFT", partsPanel, "TOPLEFT", FIELDS_X, -102)
	local sizeSlider, sizeName = sizeLine:Box(L["Size"], PartField("scale", 1), 50, 200, 5, "%d%%", 100,
		L["How big it is, times the game's size."], Changed, 44)
	local gap, gapName = sizeLine:Box(L["Gap"], PartField("gap", 0), -20, 40, 1, "%d", 1,
		L["How far it sits from the part it hangs on."], Changed, 44)
	-- (A part your game's nameplate settings hide: said so, under its fields, so
	-- you don't lay out what you'll never see. The preview shows it all the same
	-- where the game would draw it.)
	local hiddenNote = partsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	hiddenNote:SetPoint("TOPLEFT", partsPanel, "TOPLEFT", FIELDS_X, -172)
	hiddenNote:SetWidth(WIDTH - FIELDS_X - 16)
	hiddenNote:SetJustifyH("LEFT")
	hiddenNote:SetTextColor(1, 0.69, 0.38)
	hiddenNote.searchSkip = true
	local function Bit(cvarKey, enumName, which)
		local registry, constants = _G.CVarCallbackRegistry, _G.NamePlateConstants
		local values = Enum and Enum[enumName]
		if not (registry and constants and values and constants[cvarKey] and values[which] ~= nil) then return nil end
		local ok, on = pcall(registry.GetCVarBitfieldIndex, registry, constants[cvarKey], values[which])
		return ok and on and true or false
	end
	-- (What your game's settings say for a part on an enemy NPC's plate: false = hidden.)
	local SETTING_OF = {
		debuffs = { "ENEMY_NPC_AURA_DISPLAY_CVAR", "NamePlateEnemyNpcAuraDisplay", "Debuffs", "debuffs" },
		buffs = { "ENEMY_NPC_AURA_DISPLAY_CVAR", "NamePlateEnemyNpcAuraDisplay", "Buffs", "buffs" },
		crowd = { "ENEMY_NPC_AURA_DISPLAY_CVAR", "NamePlateEnemyNpcAuraDisplay", "CrowdControl", "crowd control" },
		castIcon = { "CAST_BAR_DISPLAY_CVAR", "NamePlateCastBarDisplay", "SpellIcon", "the spell icon" },
		castText = { "CAST_BAR_DISPLAY_CVAR", "NamePlateCastBarDisplay", "SpellName", "the spell name" },
		elite = { "INFO_DISPLAY_CVAR", "NamePlateInfoDisplay", "RarityIcon", "the elite mark" },
	}
	local function HiddenBySettings(key)
		local each = SETTING_OF[key]
		if each then
			local on = Bit(each[1], each[2], each[3])
			if on == false then return each[4] end
			return nil
		end
		if key == "softTarget" then
			-- (As the preview's own check (PlateCopy's quest state): a size over 0 and the icon
			-- on friendly units. Run qd5a8: the friendly icon off, no icon and no note.)
			local registry, constants = _G.CVarCallbackRegistry, _G.NamePlateConstants
			local ok, size, friend = pcall(function()
				return registry:GetCVarNumberOrDefault(constants.SOFT_TARGET_NAMEPLATE_SIZE_CVAR),
					registry:GetCVarValueBool(constants.SOFT_TARGET_ICON_FRIEND_CVAR)
			end)
			if ok and ((type(size) == "number" and size <= 0) or not friend) then return "the soft target icon" end
		end
		return nil
	end
	ns.PlateLayoutHiddenBySettings = HiddenBySettings -- (the tests read it)
	local countLabel = Caption(partsPanel, L["Balance"])
	countLabel:SetPoint("TOPLEFT", partsPanel, "TOPLEFT", FIELDS_X, -140)
	local countDrop = kit.Dropdown(content, PartField("count", "always"), function()
		local part = PartInfo()
		local choices = { { text = L[COUNT_NAMES.always], value = "always" } }
		if part and part.frame then choices[#choices + 1] = { text = L[COUNT_NAMES.shown], value = "shown" } end
		choices[#choices + 1] = { text = L[COUNT_NAMES.never], value = "never" }
		return choices
	end, 170, Changed)
	countDrop:SetPoint("LEFT", countLabel, "RIGHT", 8, 0)
	kit.Tooltip(countDrop, L["Whether this part counts when Center is Balanced: always (steady), only while " ..
		"it's up (the plate moves as it comes and goes), or never."])

	local function Button(text, tip, onClick)
		local button = Flat(partsPanel, text, 92, onClick)
		kit.Tooltip(button, tip)
		return button
	end
	local mirror = Button(L["Mirror"], L["Puts it on the other side of the bar, as far out."], function()
		if ns.PlateLayoutMirror then ns.PlateLayoutMirror(Editing(true), selected, game) end
		Changed()
	end)
	mirror:SetPoint("BOTTOMLEFT", partsPanel, "BOTTOMLEFT", FIELDS_X, 10)
	local resetPart = Button(L["Reset part"], L["Puts this part back where the game puts it."], function()
		local layout = Editing(true)
		if layout.parts then layout.parts[selected] = nil end
		Changed()
	end)
	resetPart:SetPoint("LEFT", mirror, "RIGHT", 6, 0)
	local resetAll = Button(L["Reset layout"], L["Puts every part, and the center, back as the game has them."],
		function()
			local data = ns.PlateLayoutData(true)
			data[editKey] = nil
			Changed()
		end)
	resetAll:SetPoint("BOTTOMRIGHT", partsPanel, "BOTTOMRIGHT", -10, 10)

	-- The fields as the picked part has them: hidden where they can't apply.
	local refresher = CreateFrame("Frame", nil, content)
	refresher.Refresh = function()
		local part = PartInfo()
		local p = ns.PlateLayoutPart(Shown(), selected)
		partTitle:SetText(part and L[part.label] or "")
		local hangs = game and game.gameCopy and ns.PlateLayoutHangsOn and ns.PlateLayoutHangsOn(game, selected)
		local hangName = hangs == "plate" and L["the plate"] or nil
		for _, other in ipairs(PARTS) do if other.key == hangs then hangName = L[other.label] end end
		hangsText:SetText(hangName and L["Hangs on: %s"]:format(hangName) or "")
		local hiddenWhat = HiddenBySettings(selected)
		hiddenNote:SetShown(hiddenWhat ~= nil)
		if hiddenWhat then
			hiddenNote:SetText(L["Your game's nameplate settings hide %s, so it won't show on your plates. Turn it on in " ..
				"the game's Options > Nameplates."]:format(L[hiddenWhat]))
		end
		local hung = p and p.to and true or false
		hangDrop:SetShown(part and part.hang and true or false)
		sideDrop:SetShown(hung)
		gap:SetShown(hung)
		gapName:SetShown(hung)
		local sized = part and part.scale and true or false
		sizeSlider:SetShown(sized)
		sizeName:SetShown(sized)
		for key, row in pairs(rows) do
			row.back:SetShown(key == selected)
			row.dot:SetShown(ns.PlateLayoutPartMoves(ns.PlateLayoutPart(Shown(), key)))
		end
		own:SetShown(editKey ~= "all")
		local layout = Shown()
		local center = layout and layout.center or "bar"
		customLine:SetShown(center == "custom")
		guideBox:SetOn(guides)
		allBox:SetOn(AllUp())
		mirror:SetShown(part and part.key ~= "health" and part.key ~= "cast" and true or false)
	end
	kit.AddControl(refresher)

	local spacer = CreateFrame("Frame", nil, content)
	spacer:SetSize(10, 24)
	spacer:SetPoint("TOPLEFT", partsPanel, "BOTTOMLEFT", 0, 0)
	stack:Continue(spacer, "label")

	canvas:SetScript("OnShow", function(...)
		kit.PageShown(kit.Refresh, content)(...)
		if C_Timer then C_Timer.After(0, Redraw) else Redraw() end
	end)
	canvas:SetScript("OnHide", function()
		drag = nil
		overlay:SetScript("OnUpdate", nil)
		KeysOff()
	end)
	canvas:Hide()
	kit.RegisterSubpage(canvas, "Nameplate Layout", L["Nameplate Layout"])
	-- (The page's Reset page, as every page's: its settings back, and every layout
	-- with them (they're a table, not in ns.DEFAULTS).)
	kit.OnReset(content, function()
		if ns.db then ns.db.plateLayoutData = nil end
		ns.PlateLayoutChanged()
		if Redraw then Redraw() end
	end)
	ns.plateLayoutPage = { preview = preview, controls = { { forDrop, "Layout for" }, { own, "Own layout" }, { presetDrop, "Preset" },
		{ lastCenter, "Center's buttons" }, { allBox, "All parts up" },
		{ guideBox, "Guides" }, { hangDrop, "Hang on" }, { moveLine, "Left / right, Down / up" },
		{ sizeLine, "Size, Gap" }, { countDrop, "Balance" }, { mirror, "Mirror" }, { resetAll, "Reset layout" } },
		-- (Refresh: the page's controls drawn again, for a layout changed from outside it: the tests.)
		Refresh = function() kit.Refresh() end,
		holder = holder, overlay = overlay, Redraw = Redraw, Select = Pick, Edit = function(key) editKey = key kit.Refresh() Redraw() end, hits = hits, keys = keys, canvas = canvas, readout = offText,
		marks = { unit = unitMark, middle = groupMark, span = span }, plateParts = PARTS, copyOf = CopyOf }
end

-- A preset onto a layout: the game's places, balanced, the level box and
-- marker inside the bar, or the name inside it (measured on plate, the
-- preview's copy, so it fits your plate style).
function ns.PlateLayoutPreset(layout, which, plate)
	if not layout then return end
	local keepOwn, keepStarted = layout.own, layout.started
	for key in pairs(layout) do layout[key] = nil end
	layout.own, layout.started, layout.parts = keepOwn, keepStarted, {}
	if which == "balanced" then
		layout.center = "balanced"
	elseif which == "compact" then
		layout.parts.level = { to = "health", side = "inright", gap = 2, scale = 0.85 }
		layout.parts.marker = { to = "health", side = "inleft", gap = 2, scale = 0.8 }
		layout.center = "balanced"
	elseif which == "namein" then
		local copy = plate and plate.gameCopy
		local dy = -18
		if copy then
			local ok, nameY, barY = pcall(function()
				local _, ny = copy.name:GetCenter()
				local _, by = copy.HealthBarsContainer:GetCenter()
				return ny, by
			end)
			if ok and type(nameY) == "number" and type(barY) == "number" then
				dy = math.floor((barY - nameY) * copy.name:GetEffectiveScale() / copy:GetEffectiveScale() + 0.5)
			end
		end
		layout.parts.name = { y = dy }
		layout.parts.debuffs = { y = dy }
	end
end

-- Mirror: a hung part to the other side; else moved across the bar's middle
-- by its own place now (measured on the preview's copy).
function ns.PlateLayoutMirror(layout, key, plate)
	local p = ns.PlateLayoutPart(layout, key, true)
	local SWAP = { right = "left", left = "right", inleft = "inright", inright = "inleft" }
	if p.to then
		p.side = SWAP[p.side or "right"] or p.side
		p.x = p.x and -p.x or nil
		return
	end
	local copy = plate and plate.gameCopy
	local part
	for _, each in ipairs(ns.PLATE_LAYOUT_PARTS) do if each.key == key then part = each end end
	if not (copy and part) then return end
	local frame = copy
	for name in part.path:gmatch("[^.]+") do frame = frame and frame[name] end
	local ok, px, bx = pcall(function()
		local x = frame:GetCenter()
		local b = copy.HealthBarsContainer:GetCenter()
		return x * frame:GetEffectiveScale(), b * copy.HealthBarsContainer:GetEffectiveScale()
	end)
	if not (ok and type(px) == "number" and type(bx) == "number") then return end
	local off = (px - bx) / copy:GetEffectiveScale()
	local x = math.floor((p.x or 0) - 2 * off + 0.5)
	p.x = x ~= 0 and x or nil
end
end) -- (ns.Module "style")
