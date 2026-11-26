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
	local holder, overlay, partsPanel -- (below)
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
	-- What the stage puts on its plate: the layout shown, while the page's switch is on.
	local function StageLayout()
		if not (ns.StyleOn and ns.StyleOn("plateLayout")) then return false end
		return Shown() or false
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
	-- (The mock's chrome (Tools/style-studio/page-mock.html, 2026-11-25): its title and On
	-- switch over the page, so this page's own out of sight, the intro the title's tooltip.)
	ns.MockPageHeader(content, "Nameplate Layout", title, intro, switch)
	local stack = kit.Stack(switch, "check")
	-- The preview first, as every Style page's: the shared preview frame
	-- (StylePages.lua's ns.StylePopout: held at the page's top as you scroll,
	-- popped out into its own window and docked, sized to the screen's shape),
	-- the Nameplate Style previewer filling it. (The user, 2026-11-25: a stage
	-- of its own that couldn't pop out didn't fit the rest of the addon.)
	local preview = CreateFrame("Frame", nil, content)
	preview:SetSize(560, 190)
	preview.minHeight = 280 -- (the plate with its debuffs, its lists under it, the guides' strips over and under it)
	-- (Beside the settings, as the mock's: the stage Nameplate Style's width (268: a wider
	-- one and the settings ran past the page's edge, run q496d), the editor on its right.)
	preview.fixedWidth = 268
	stack:Add(preview, "label")
	if preview.SetClipsChildren then preview:SetClipsChildren(true) end
	-- (Its Refresh before StylePopout: the fitter wraps it, and draws it again as it's resized.)
	preview.Refresh = function() if Redraw then Redraw() end end
	ns.StylePopout(preview, kit.Tooltip, L["Nameplate Layout"])
	-- (The editor's width: stage, rows and the parts panel line up on it. 560, as
	-- Nameplate Style's own preview: at 640 the right side ran under the page's
	-- scroll bar, run qc3be.)
	local WIDTH = 268 -- (the mock's stage, 2026-11-25: the settings beside it)

	-- The stage's two toggles: the Style Studio's buttons (2026-11-25: every button
	-- looks like a button), lit while on.
	local function Flat(parent, text, _, onClick)
		local button = ns.Studio.C.Button(parent, text)
		function button.SetOn(self, on) self:Paint(on and "on" or nil) end
		button:SetScript("OnClick", onClick)
		return button
	end

	-- Layout for: the editor's Applies to (its variants, Style/Studio/Frames/Nameplates.lua),
	-- the preview's unit with it (the Unit list hidden here: the two disagreed). Own
	-- layout under the preview, for a kind.
	local function Edit(key)
		editKey = key
		for _, each in ipairs(FOR) do
			if each[1] == key and holder and holder.PickSample then holder.PickSample(each[3]) end
		end
		if holder and holder.LayoutBottomRow then holder.LayoutBottomRow() end
	end
	local row1 = CreateFrame("Frame", nil, content)
	row1:SetSize(WIDTH, 28)
	stack:Add(row1, "label")
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
	own:SetPoint("LEFT", row1, "LEFT", 0, 0)
	-- (The center (Bar / Balanced / Custom and its shift) and the presets: the editor's
	-- Plate part and Looks since 2026-11-25; a preset is one Undo step there.)

	-- The previewer in the shared preview frame, as Nameplate Style's (Options.lua):
	-- filling it, its own Scene button in place of the frame's backdrop button.
	holder = ns.MakePlateRowLookPreview(preview, WIDTH, "others")
	holder:ClearAllPoints()
	holder:SetAllPoints(preview)
	holder.zoomSkip, holder.noAutoFit = true, true
	holder.plainStage = true -- (the mock's plain black stage, no Scene)
	if holder.sceneButton then holder.sceneButton:Hide() end
	-- (Its bottom row, the user 2026-11-25: "not in the bottom left nice and neat",
	-- Scene "randomly offset". The Unit list only with All plates: a single kind's
	-- layout shows that kind (Edit picks it), the two never disagreeing. State at the
	-- bottom left when it's alone; Scene at the bottom right, level with State (the
	-- previewer keeps 90 for zoom buttons this page hasn't got).)
	local unitDrop, stateDrop, sceneButton = holder.unitDropdown, holder.stateDropdown, holder.sceneButton
	local function BottomRow()
		local withUnit = unitDrop ~= nil and editKey == "all"
		if unitDrop then
			if withUnit then unitDrop:ShowForKind() else unitDrop:Hide() end
		end
		if stateDrop then
			stateDrop:ClearAllPoints()
			if withUnit then
				stateDrop:SetPoint("LEFT", unitDrop, "RIGHT", 6, 0)
			else
				stateDrop:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 6, 6)
			end
		end
		if sceneButton and sceneButton:IsShown() then
			local level = stateDrop or unitDrop
			sceneButton:ClearAllPoints()
			if level then
				sceneButton:SetPoint("RIGHT", holder, "RIGHT", -8, 0)
				sceneButton:SetPoint("TOP", level, "TOP", 0, -math.floor(((level:GetHeight() or 0) - (sceneButton:GetHeight() or 0)) / 2 + 0.5))
			else
				sceneButton:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -8, 6)
			end
		end
	end
	if unitDrop then
		unitDrop.ShowForKind = unitDrop.Show
		unitDrop.Show = function(self) if editKey == "all" then self:ShowForKind() end end
	end
	holder.LayoutBottomRow = BottomRow -- (Edit calls it as Layout for changes)
	BottomRow()
	preview.layoutStage = true -- (the Studio's hotspots stay off it: its own hits pick and drag)
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
		-- (The page's own size, not the small one: "the unit line is so small no one
		-- would know what it is", the user 2026-11-25.)
		mark.name = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
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
		Place(unitMark, unitX, L["Unit's middle"], showMiddle and (right and "left" or "right") or "center")
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
		-- (Only with the page's switch on, 2026-11-25: off, the stage showed a layout your
		-- plates didn't have. The editor's status line says it's off, with Turn on.)
		local layout = StageLayout()
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
		local states = ns.PlatePreviewStates and ns.PlatePreviewStates(holder)
		if not (state and states and ns.TogglePlatePreviewState) then return false end
		local changed = false
		if key == "elite" and states.marker then
			ns.TogglePlatePreviewState("marker", holder)
			changed = true
		end
		if not states[state] then
			ns.TogglePlatePreviewState(state, holder)
			changed = true
		end
		return changed
	end
	local editor -- (below: the Style Studio's editor, its part the one picked here)
	local function Pick(key, clicked)
		selected = key
		if editor and editor.partId ~= key then
			editor.partId = key
			editor:Redraw()
		end
		if ShowPart(key) then Redraw() end
		kit.Refresh()
		RedrawOverlay()
		-- (Picked with a click in the list: the arrows nudge it, while the mouse stays on
		-- the preview or the panel. Not when picked by code: a test's, the page's own.)
		if clicked and ns.PlateLayoutPageKeys then ns.PlateLayoutPageKeys() end
	end

	-- Dragging a part: the cursor's move in the plate's units, snapped to the
	-- game's place, and its left, middle or right to the bar's left, middle or
	-- right (a thin gold line shows the one it lined up on). Audit 2026-11-25.
	local drag
	local snapLine = overlay:CreateTexture(nil, "OVERLAY")
	snapLine:SetColorTexture(1, 0.82, 0, 0.9)
	snapLine:SetWidth(1)
	snapLine:Hide()
	local function ScreenEdges(frame)
		local ok, l, r, eff = pcall(function() return frame:GetLeft(), frame:GetRight(), frame:GetEffectiveScale() end)
		if ok and type(l) == "number" and type(r) == "number" then return l * eff, r * eff end
	end
	function ns.PlateLayoutPageDrag(key)
		if not key then
			local was = drag
			drag = nil
			snapLine:Hide()
			overlay:SetScript("OnUpdate", nil)
			-- (Dropped: one Undo step in the Style Studio's history, 2026-11-25.)
			if was and ns.PlateLayoutRecord then
				ns.PlateLayoutRecord(was.kind, was.key, { x = was.px ~= 0 and was.px or nil, y = was.py ~= 0 and was.py or nil })
			end
			-- (Dropped: the preview fitted again, so a part moved far stays in view.)
			if Redraw then Redraw() end
			kit.Refresh()
			return
		end
		selected = key
		if editor and editor.partId ~= key then
			editor.partId = key
			editor:Redraw()
		end
		local p = Part(true)
		local x, y = GetCursorPosition()
		drag = { x = x, y = y, px = p.x or 0, py = p.y or 0, key = key, kind = editKey }
		-- (Its edges and the bar's as it's picked up, on the screen.)
		local copy0 = CopyOf()
		if copy0 then
			local frame
			for _, part in ipairs(PARTS) do if part.key == key then frame = Field(copy0, part.path) end end
			drag.left, drag.right = ScreenEdges(frame or copy0)
			drag.barLeft, drag.barRight = ScreenEdges(copy0.HealthBarsContainer)
		end
		ns.SetOnUpdate(overlay, function()
			local copy = CopyOf()
			if not (drag and copy) then return end
			local cx, cy = GetCursorPosition()
			local scale = copy:GetEffectiveScale()
			-- (Snapped on the screen, then back in the plate's units: the bar itself
			-- doesn't snap to its own edges, it moves the plate.)
			local move = cx - drag.x
			local line
			if key ~= "health" and drag.left and drag.barLeft and ns.PlateLayoutSnap then
				move, line = ns.PlateLayoutSnap(move, drag.left, drag.right, drag.barLeft, drag.barRight, 4)
			end
			-- (Inside the range every way of moving shares: the boxes', the keys'. Audit 2026-11-25.)
			local nx = Clamp(drag.px + move / scale, RANGE.x)
			local ny = Clamp(drag.py + (cy - drag.y) / scale, RANGE.y)
			if math.abs(nx) < 3 then nx, line = 0, nil end
			if math.abs(ny) < 3 then ny = 0 end
			snapLine:ClearAllPoints()
			snapLine:SetShown(line ~= nil)
			if line then
				local oe = overlay:GetEffectiveScale()
				snapLine:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", line / oe - (overlay:GetLeft() or 0),
					holder.plateLift or 38)
				snapLine:SetHeight(math.max(10, overlay:GetHeight() - (holder.plateLift or 38) - 50))
			end
			local part = Part(true)
			part.x, part.y = math.floor(nx + 0.5), math.floor(ny + 0.5)
			if part.x == 0 then part.x = nil end
			if part.y == 0 then part.y = nil end
			ns.PlateLayoutChanged()
			ns.PlateLayoutApply(game, StageLayout())
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
	-- (Over the preview, or over the parts panel, its list and fields: the arrows nudge
	-- the picked part from either. Only the preview's before, and the keys stopped as
	-- the mouse went to the fields. Audit 2026-11-25.)
	local function OverPreview()
		for _, area in ipairs({ holder, partsPanel }) do
			local ok, over = pcall(area.IsMouseOver, area)
			if ok and over and area:IsVisible() then return true end
		end
		return false
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
		local before = { x = part.x, y = part.y }
		part.x = Clamp((part.x or 0) + step[1] * by, RANGE.x)
		part.y = Clamp((part.y or 0) + step[2] * by, RANGE.y)
		if part.x == 0 then part.x = nil end
		if part.y == 0 then part.y = nil end
		-- (Each nudge one Undo step in the Style Studio's history, 2026-11-25.)
		local ok = pcall(function()
			if ns.PlateLayoutRecord then ns.PlateLayoutRecord(editKey, selected, before) end
			Changed()
		end)
		if not ok then KeysOff() end
	end

	-- (Two toggles in the stage's top right: every part up, and the lines.)
	local ALL_UP = { "casting", "marker", "debuffs", "buffs", "crowd", "quest" }
	local function AllUp()
		local states = ns.PlatePreviewStates and ns.PlatePreviewStates(holder) or {}
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
		local states = ns.PlatePreviewStates and ns.PlatePreviewStates(holder) or {}
		local on = not AllUp()
		for _, key in ipairs(ALL_UP) do
			if key ~= "casting" and (states[key] and true or false) ~= on and ns.TogglePlatePreviewState then
				ns.TogglePlatePreviewState(key, holder)
			end
			if key == "casting" and not states.casting and ns.TogglePlatePreviewState then ns.TogglePlatePreviewState(key, holder) end
		end
		Redraw()
	end)
	-- (The mock, 2026-11-25: no All parts up (the State list ticks what shows); Guides and
	-- the status over the stage.)
	allBox:Hide()
	allBox.Show = allBox.Hide
	-- (Top right: at the bottom it sat on the State list, run qb407. Left of the pop-out
	-- button there (the shared frame's, on hover): over it they overlapped, the user 2026-11-25.)
	guideBox:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -36, -6)
	status:SetPoint("TOPLEFT", overlay, "TOPLEFT", 8, -11)
	status:SetPoint("RIGHT", guideBox, "LEFT", -8, 0)
	-- (Two lines where it needs them: on one it was cut ("What shows sits 19 right of the
	-- uni..."), the user 2026-11-25: "things are getting cutoff".)
	status:SetWordWrap(true)
	if status.SetMaxLines then status:SetMaxLines(2) end
	kit.Tooltip(allBox, L["Shows every part on the preview at once (a cast, a marker, debuffs, crowd control, " ..
		"the soft target icon), to lay them all out. Pick what shows in the State list."])

	-- (The parts list and the picked part's fields under the stage: the Style Studio's
	-- editor since 2026-11-25 (Style/Studio/Frames/Nameplates.lua's "platelayout"): its
	-- parts, each its Place (Hang on, Side, Left/right, Down/up, Size, Gap, Balance,
	-- Mirror), Reset by scope and Undo. A part your game's settings hide: a note there.)
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
	-- The editor (Style/Studio/Frames/Nameplates.lua): its variant is Layout for, its
	-- part the one picked on the stage (and back), its Looks the presets.
	editor = ns.StyleEditorPage(kit, content, stack, "platelayout", { preview = preview, canvas = canvas, variant = editKey,
		side = true })
	partsPanel = editor.holder -- (the arrow keys nudge with the mouse over it too)
	editor.partId = selected
	local pickEditor = editor.Pick
	function editor.Pick(self, partId, variant)
		if variant ~= nil and variant ~= editKey then Edit(variant) end
		-- (Smart marks: not a part of the plate, no nudging it on the stage)
		if partId and partId ~= selected and partId ~= "plate" and partId ~= "smartMarks" then
			selected = partId
			if ShowPart(partId) then Redraw() end
		end
		pickEditor(self, partId, variant)
		Redraw()
	end

	-- The stage's toggles and Own layout as the page has them.
	local refresher = CreateFrame("Frame", nil, content)
	refresher.Refresh = function()
		own:SetShown(editKey ~= "all")
		guideBox:SetOn(guides)
		allBox:SetOn(AllUp())
	end
	kit.AddControl(refresher)

	local spacer = CreateFrame("Frame", nil, content)
	spacer:SetSize(10, 24)
	spacer:SetPoint("TOPLEFT", editor.holder, "BOTTOMLEFT", 0, 0)
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
	-- (The controls the tests check for overlaps: the page's own, then each row the editor
	-- draws now, by its control. Not the editor's holder: a tall container, it always sits
	-- under the preview held at the view's top as the page scrolls; run q7ba3.)
	local controls = {}
	local function ListControls()
		for i = #controls, 1, -1 do controls[i] = nil end
		controls[1], controls[2] = { own, "Own layout" }, { guideBox, "Guides" }
		for _, row in ipairs(editor.body and editor.body.shownRows or {}) do
			if row.control then controls[#controls + 1] = { row.control, "Editor: " .. (row.prop.label or row.prop.kind) } end
		end
	end
	ListControls()
	hooksecurefunc(editor, "Redraw", ListControls)
	ns.plateLayoutPage = { preview = preview, partsPanel = partsPanel, editor = editor, controls = controls,
		-- (Refresh: the page's controls drawn again, for a layout changed from outside it: the tests.)
		Refresh = function() kit.Refresh() end,
		holder = holder, overlay = overlay, Redraw = Redraw, Select = Pick,
		Edit = function(key)
			Edit(key)
			editor.variant = key
			editor:Redraw()
			kit.Refresh()
			Redraw()
		end, hits = hits, keys = keys, canvas = canvas, readout = offText,
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
