-- /cine debug platematch: the nameplate previews built on the game's own
-- plate (Plates/PlateCopy.lua), the confirm run (ledger:
-- Tools/tests/plate-preview-match.md; runs 1-3 probed the game's plate and
-- proved the recipe). One thing to do: target any mob. Steps:
--   1 templates  (proven in run 1) the client's plate templates
--   2 preview    Nameplate Style's preview made as its Look panels make it:
--                the game's plate in it, nothing up at rest (run 3's marker
--                sheet), its sizes the real plate's, each sample unit (shot),
--                each state alone through the State dropdown's ticks (shot:
--                target, focus, casting, can't interrupt, marker, elite, aggro,
--                debuffs), the State dropdown open (shot), the picks laid out
--                at 480, 380 and 300 wide
--   3 page       Combat Text Style opened (its preview is on the page), page
--                switch on and off: the preview shown, r:Overlaps on its two
--                dropdowns and Scene, a shot each
--   4 stylepage  Nameplate Style's own page opened, switch on and off: four
--                game plates in its preview, each state on them (a shot each),
--                a theme pointed at (not saved, shot), the Theme list and
--                Customize right under the preview covering nothing,
--                Customize opening the Look panel; off: the off card
--   5 compare    target any mob: every readable size against the real plate,
--                then one texture put on both through the same code
--                (ns.StylePlateBar): the same fill; the real plate put back
-- Into CinematicDB.plateMatchTestLog. Dev copy only.
local _, ns = ...

local TEMPLATES = { "NamePlateUnitFrameTemplate", "BaseNamePlateUnitFrameTemplate", "NamePlatePreviewTemplate",
	"NameplateAuraItemTemplate", "NamePlateAuraListTemplate", "NamePlateFullBorderTemplate",
	"NamePlateSecondaryBarBorderTemplate", "NamePlateCastingBarTemplate" }
local CVARS = { "nameplateShowAll", "nameplateShowEnemies", "nameplateShowFriends", "nameplateShowFriendlyNPCs",
	"nameplateStyle", "nameplateSize", "nameplateGlobalScale", "nameplateSelectedScale", "nameplateLargerScale",
	"NamePlateHorizontalScale", "NamePlateVerticalScale", "nameplateResourceOnTarget", "nameplateShowDebuffsOnFriendly",
	"nameplateAuraScale", "nameplateMotion", "nameplateShowSelf", "nameplateShowOnlyNames", "nameplateUseClassColorForFriendlyPlayerUnitNames" }
local WALK_LINES, COPY_LINES = 140, 260
local copies = {} -- (our template copies, hidden at the end)

-- Reads -------------------------------------------------------------------------

local function S(value)
	if issecretvalue and issecretvalue(value) then return "secret" end
	if type(value) == "number" then
		if value == math.floor(value) then return tostring(value) end
		return ("%.2f"):format(value)
	end
	if type(value) == "table" then return "table" end
	return tostring(value)
end

-- obj:method(...) in a pcall: "err" when it errors, the values joined by ",".
local function R(obj, method, ...)
	local fn = obj and obj[method]
	if type(fn) ~= "function" then return nil end
	local out = { pcall(fn, obj, ...) }
	if not out[1] then return "err" end
	if #out < 2 then return "nil" end
	local parts = {}
	for i = 2, #out do parts[#parts + 1] = S(out[i]) end
	return table.concat(parts, ",")
end

local function Secret(value) return issecretvalue and issecretvalue(value) or false end

local function KeyIn(parent, child)
	local ok, name = pcall(function()
		for k, v in pairs(parent) do
			if v == child and type(k) == "string" then return k end
		end
	end)
	return ok and name or nil
end

local function TypeOf(obj) local ok, t = pcall(obj.GetObjectType, obj); return ok and S(t) or "?" end

-- One piece's look on one line.
local function Look(obj, paths)
	local t = TypeOf(obj)
	local bits = { t }
	bits[#bits + 1] = "shown=" .. (R(obj, "IsShown") or "-") .. "/" .. (R(obj, "IsVisible") or "-")
	bits[#bits + 1] = "a=" .. (R(obj, "GetAlpha") or "-")
	bits[#bits + 1] = "size=" .. (R(obj, "GetSize") or "-")
	if obj.GetEffectiveScale and t ~= "Texture" and t ~= "FontString" and t ~= "MaskTexture" then
		bits[#bits + 1] = "scale=" .. (R(obj, "GetScale") or "-") .. "/eff " .. (R(obj, "GetEffectiveScale") or "-")
	end
	-- (Its points, with the frame each is on named by its path where we walked it.)
	local okN, n = pcall(obj.GetNumPoints, obj)
	if okN and not Secret(n) and type(n) == "number" then
		local pts = {}
		for i = 1, math.min(n, 4) do
			local ok, p, rel, rp, x, y = pcall(obj.GetPoint, obj, i)
			if not ok then pts[#pts + 1] = "err"; break end
			local relName = Secret(rel) and "secret" or (rel and (paths[rel] or (pcall(rel.GetDebugName, rel) and rel:GetDebugName()) or "?") or "nil")
			pts[#pts + 1] = ("%s>%s.%s %s,%s"):format(S(p), relName, S(rp), S(x), S(y))
		end
		bits[#bits + 1] = "pts=[" .. table.concat(pts, "; ") .. "]"
	elseif not okN then
		bits[#bits + 1] = "pts=err"
	end
	if t == "Texture" or t == "MaskTexture" then
		bits[#bits + 1] = "atlas=" .. (R(obj, "GetAtlas") or "-")
		bits[#bits + 1] = "tex=" .. (R(obj, "GetTexture") or "-")
		bits[#bits + 1] = "tc=" .. (R(obj, "GetTexCoord") or "-")
		if t == "Texture" then
			bits[#bits + 1] = "col=" .. (R(obj, "GetVertexColor") or "-")
			bits[#bits + 1] = "blend=" .. (R(obj, "GetBlendMode") or "-")
			bits[#bits + 1] = "desat=" .. (R(obj, "IsDesaturated") or "-")
			bits[#bits + 1] = "layer=" .. (R(obj, "GetDrawLayer") or "-")
		end
	elseif t == "FontString" then
		bits[#bits + 1] = "font=" .. (R(obj, "GetFont") or "-")
		bits[#bits + 1] = "text=" .. (R(obj, "GetText") or "-")
		bits[#bits + 1] = "col=" .. (R(obj, "GetTextColor") or "-")
		bits[#bits + 1] = "shadow=" .. (R(obj, "GetShadowOffset") or "-") .. "/" .. (R(obj, "GetShadowColor") or "-")
		bits[#bits + 1] = "justify=" .. (R(obj, "GetJustifyH") or "-")
		bits[#bits + 1] = "layer=" .. (R(obj, "GetDrawLayer") or "-")
	elseif t == "StatusBar" then
		local okF, fill = pcall(obj.GetStatusBarTexture, obj)
		if okF and fill and not Secret(fill) then
			bits[#bits + 1] = "FILL atlas=" .. (R(fill, "GetAtlas") or "-") .. " tex=" .. (R(fill, "GetTexture") or "-")
				.. " tc=" .. (R(fill, "GetTexCoord") or "-") .. " desat=" .. (R(fill, "IsDesaturated") or "-")
				.. " layer=" .. (R(fill, "GetDrawLayer") or "-")
		else
			bits[#bits + 1] = "FILL " .. (okF and S(fill) or "err")
		end
		bits[#bits + 1] = "barcol=" .. (R(obj, "GetStatusBarColor") or "-")
		bits[#bits + 1] = "minmax=" .. (R(obj, "GetMinMaxValues") or "-") .. " v=" .. (R(obj, "GetValue") or "-")
		bits[#bits + 1] = "orient=" .. (R(obj, "GetOrientation") or "-") .. " rev=" .. (R(obj, "GetReverseFill") or "-")
	end
	if t ~= "Texture" and t ~= "FontString" and t ~= "MaskTexture" then
		bits[#bits + 1] = "strata=" .. (R(obj, "GetFrameStrata") or "-") .. "/" .. (R(obj, "GetFrameLevel") or "-")
	end
	return table.concat(bits, " ")
end

local function Kids(obj)
	local out = {}
	for _, getter in ipairs({ "GetChildren", "GetRegions" }) do
		if type(obj[getter]) == "function" then
			local ok, list = pcall(function() return { obj[getter](obj) } end)
			if ok then for _, kid in ipairs(list) do out[#out + 1] = kid end end
		end
	end
	return out
end

local function IsShownPlain(obj)
	if type(obj) ~= "table" or not obj.IsShown then return "none" end
	local ok, shown = pcall(obj.IsShown, obj)
	if not ok then return "err" end
	if Secret(shown) then return "secret" end
	return shown and true or false
end

-- The whole tree of obj: a line per shown piece (all = hidden ones too, in
-- full), the hidden ones by name on one line. seen[path] = true for each
-- shown piece. Returns the line count.
local function Walk(r, obj, root, opts)
	opts = opts or {}
	local cap, lines, hidden, paths = opts.cap or WALK_LINES, 0, {}, {}
	paths[obj] = root
	local visited = {} -- (a piece can be both a child and a key of its parent: once)
	local function Visit(node, path, depth)
		if lines >= cap or visited[node] then return end
		visited[node] = true
		local shown = IsShownPlain(node)
		if shown == false and not opts.all then
			hidden[#hidden + 1] = path
		else
			lines = lines + 1
			r:Log(("    %s %s"):format(path, Look(node, paths)))
			if opts.seen and shown ~= false then opts.seen[path] = (opts.seen[path] or 0) + 1 end
		end
		if depth >= (opts.depth or 5) then return end
		local kids = Kids(node)
		for i, kid in ipairs(kids) do
			local name = KeyIn(node, kid) or ((pcall(kid.GetName, kid) and kid:GetName()) or ("#" .. i))
			paths[kid] = path .. "." .. tostring(name)
		end
		for _, kid in ipairs(kids) do Visit(kid, paths[kid], depth + 1) end
	end
	Visit(obj, root, 0)
	if #hidden > 0 then r:Log(("    hidden (%d): %s"):format(#hidden, table.concat(hidden, ", "))) end
	if lines >= cap then r:Log(("    (cut at %d lines)"):format(cap)) end
	return lines
end

-- Path to a piece of a plate ("HealthBarsContainer.healthBar.bgTexture").
local function Piece(root, path)
	local node = root
	for part in path:gmatch("[^%.]+") do
		if type(node) ~= "table" then return nil end
		node = node[part]
	end
	return node
end

-- The pieces we compare with a live plate (sizes and fonts read plain there
-- out of a fight; places don't: rule forever.plate.getpoint-restricted).
local COMPARE = { "HealthBarsContainer", "HealthBarsContainer.healthBar", "HealthBarsContainer.healthBar.bgTexture",
	"HealthBarsContainer.healthBar.deselectedOverlay", "HealthBarsContainer.healthBar.selectedBorder", "CastBarsContainer",
	"name", "RaidTargetFrame", "ClassificationFrame", "SoftTargetFrame" }

local function SizeOf(obj)
	if not obj then return nil end
	local ok, w, h = pcall(obj.GetSize, obj)
	if not ok or Secret(w) or Secret(h) or type(w) ~= "number" then return nil end
	return w, h
end

-- The shipped preview (Plates/PlateCopy.lua through ns.MakePlateRowLookPreview)
-- ------------------------------------------------------------------------------

local preview -- (made once for the run, top middle of the screen)

-- The unit pills and the state pills of a preview (its page pieces).
-- The picks under a preview: its Unit and State dropdowns and the Scene pick
-- (the controls to check for room), from its page pieces.
local function PicksOf(holder)
	local list = {}
	for i, piece in ipairs(holder.pagePieces or {}) do
		if i > 1 then list[#list + 1] = piece end -- (1: the "not saved" tag)
	end
	return list
end

-- Only this state on (nil: none), through what the State dropdown's ticks call.
local function OnlyState(holder, key)
	local plate = holder.gamePlate
	for _, state in ipairs(ns.GAME_PLATE_STATES) do
		if plate.states[state] then holder.ToggleState(state) end
	end
	if plate.states.casting then holder.ToggleState("casting") end
	if key then holder.ToggleState(key) end
end

local function MakePreview()
	if preview then return preview end
	local holder = ns.MakePlateRowLookPreview(UIParent, 480, "others")
	holder:SetFrameStrata("HIGH")
	-- (Left of the middle, clear of the test's box at the top (run 6's shots
	-- showed the box over it) and of your target's plate in the middle.)
	holder:SetPoint("CENTER", UIParent, "CENTER", -560, 120)
	holder:Show()
	preview = holder
	copies[#copies + 1] = holder
	return holder
end

-- The pills inside the preview and clear of each other, at a width.
local function PillLayout(r, width)
	local holder = ns.MakePlateRowLookPreview(UIParent, width, "others")
	holder:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -20)
	holder:Show()
	local boxes, outside, overlaps = {}, 0, 0
	for _, piece in ipairs(holder.pagePieces or {}) do
		if piece.GetLeft and piece:IsShown() and piece.GetObjectType and piece:GetObjectType() ~= "FontString" then
			local l, b, w, h = piece:GetRect()
			local hl, hb, hw, hh = holder:GetRect()
			if l and b and w and h and hl and hb and hw and hh then
				boxes[#boxes + 1] = { l, b, l + w, b + h }
				if l < hl - 0.5 or l + w > hl + hw + 0.5 or b < hb - 0.5 or b + h > hb + hh + 0.5 then outside = outside + 1 end
			end
		end
	end
	for i = 1, #boxes do
		for j = i + 1, #boxes do
			local a, c = boxes[i], boxes[j]
			if a[1] < c[3] - 0.5 and c[1] < a[3] - 0.5 and a[2] < c[4] - 0.5 and c[2] < a[4] - 0.5 then overlaps = overlaps + 1 end
		end
	end
	r:Log(("  LAYOUT width %d: %d picks, %d outside the preview, %d overlapping, height %.1f, lift %s"):format(width, #boxes,
		outside, overlaps, holder:GetHeight(), tostring(holder.plateLift)))
	holder:Hide()
	if #boxes == 0 then return nil end -- (no places read: not a pass)
	return outside == 0 and overlaps == 0
end

-- Each state's piece that shows it on the game's plate.
local STATE_PIECE = {
	target = "HealthBarsContainer.healthBar.selectedBorder", focus = "HealthBarsContainer.healthBar.selectedBorder",
	casting = "CastBarsContainer.castBar.Icon", locked = "CastBarsContainer.castBar.BorderShield",
	channel = "CastBarsContainer.castBar", interrupted = "CastBarsContainer.castBar",
	important = "CastBarsContainer.castBar.ImportantCastIndicator", atyou = "CastBarsContainer.castBar.CastTargetIndicator",
	marker = "RaidTargetFrame", elite = "ClassificationFrame", rare = "ClassificationFrame",
	rareelite = "ClassificationFrame", boss = "PlayerLevelDiffFrame.highLevelTexture",
	aggro = "aggroHighlightBase", gaining = "aggroHighlightBase", tapped = "HealthBarsContainer.healthBar",
	debuffs = "AurasFrame.DebuffListFrame",
	crowd = "AurasFrame.CrowdControlListFrame", -- (right of the level box: a real plate's root, 2026-11-23)
	quest = "SoftTargetFrame.Icon",
}
-- Whether a state shows as the game would draw it with your settings (some
-- parts only show when your settings ask for them: then, shown or not, it's
-- right when it matches). Gives right, what was expected, what was seen.
local function Bit(cvar, enum, which)
	local registry, constants = _G.CVarCallbackRegistry, _G.NamePlateConstants
	local values = Enum and Enum[enum]
	if not (registry and constants and values and constants[cvar]) then return nil end
	return registry:GetCVarBitfieldIndex(constants[cvar], values[which]) and true or false
end
local function StateShows(copy, state)
	local piece = Piece(copy, STATE_PIECE[state])
	local shown = piece and IsShownPlain(piece) == true or false
	local castBar = copy.CastBarsContainer.castBar
	local want, seen = true, shown
	if state == "channel" then
		seen = shown and castBar.channeling == true
	elseif state == "interrupted" then
		local okT, text = pcall(castBar.Text.GetText, castBar.Text)
		seen = okT and text == _G.INTERRUPTED
	elseif state == "important" then
		want = Bit("CAST_BAR_DISPLAY_CVAR", "NamePlateCastBarDisplay", "HighlightImportantCasts")
	elseif state == "atyou" then
		want = Bit("CAST_BAR_DISPLAY_CVAR", "NamePlateCastBarDisplay", "HighlightWhenCastTarget")
	elseif state == "elite" or state == "rare" or state == "rareelite" then
		want = Bit("INFO_DISPLAY_CVAR", "NamePlateInfoDisplay", "RarityIcon")
	elseif state == "aggro" or state == "gaining" then
		-- (The glow with Progressive on; else the bar in the threat color with Health Bar Color on.)
		want = copy.displayAggroHighlight and true or false
		if not want and copy.displayThreatHealthBarColor then
			local r, g = copy.HealthBarsContainer.healthBar:GetStatusBarColor()
			want, seen = true, (state == "aggro" and r > 0.99 and g < 0.01) or (state == "gaining" and r > 0.99 and g > 0.3)
		end
	elseif state == "tapped" then
		local r, g, b = copy.HealthBarsContainer.healthBar:GetStatusBarColor()
		-- (Colors come back as single floats: 0.9 reads 0.8999..., run 11.)
		local function Near(x, want) return type(x) == "number" and math.abs(x - want) < 0.01 end
		seen = Near(r, 0.9) and Near(g, 0.9) and Near(b, 0.9)
	elseif state == "quest" then
		local registry, constants = _G.CVarCallbackRegistry, _G.NamePlateConstants
		want = registry and constants and (registry:GetCVarNumberOrDefault(constants.SOFT_TARGET_NAMEPLATE_SIZE_CVAR) or 0) > 0
			and registry:GetCVarValueBool(constants.SOFT_TARGET_ICON_FRIEND_CVAR) and true or false
	end
	if want == nil then want = true end
	return (want and seen) or (not want and not seen), want, seen
end

-- The debuff row's top inside the preview's (run 12: the page's upper row's
-- icons ran past its top, the user). nil when places can't be read.
local function DebuffsInside(copy, frame)
	if ns.noRealLayout then return nil end -- (offline: every frame at one spot, nothing to judge)
	local list = copy.AurasFrame.DebuffListFrame
	local okL, top = pcall(list.GetTop, list)
	local okF, frameTop = pcall(frame.GetTop, frame)
	if not (okL and okF and type(top) == "number" and type(frameTop) == "number") then return nil end
	local scale = list:GetEffectiveScale() / frame:GetEffectiveScale()
	return top * scale <= frameTop + 0.5, top * scale, frameTop
end
-- The crowd control icon's right edge inside the preview's (run 14: the page's
-- right column's ran past its right edge, the user). nil when unread.
local function CrowdInside(copy, frame)
	if ns.noRealLayout then return nil end
	local list = copy.AurasFrame.CrowdControlListFrame
	local okL, right = pcall(list.GetRight, list)
	local okF, frameRight = pcall(frame.GetRight, frame)
	if not (okL and okF and type(right) == "number" and type(frameRight) == "number") then return nil end
	local scale = list:GetEffectiveScale() / frame:GetEffectiveScale()
	return right * scale <= frameRight + 0.5, right * scale, frameRight
end

-- An interrupted cast shows "Interrupted" a moment, then the game fades it
-- (run 11's shot came after the fade): wait for the plate's next cast, so the
-- shot (taken 1.5 s on) lands just after its cut at 1.2 s.
local function AwaitNextCast(r, plate)
	if not plate then return end
	local started = plate.castStarted
	r:WaitFor(nil, { check = function() return plate.castStarted ~= started and plate.castStarted and "cast" end })
end

-- A frame with a game plate preview under root (the Combat Text page's).
local function FindPreview(root, depth)
	if type(root) ~= "table" or depth > 12 then return nil end
	if rawget(root, "gamePlate") then return root end
	local ok, kids = pcall(function() return { root:GetChildren() } end)
	if not ok then return nil end
	for _, kid in ipairs(kids) do
		local found = FindPreview(kid, depth + 1)
		if found then return found end
	end
end

-- A frame under root with a field set (rawget: not a method).
local function FindWith(root, field, depth)
	depth = depth or 0
	if type(root) ~= "table" or depth > 14 then return nil end
	if rawget(root, field) ~= nil then return root end
	local ok, kids = pcall(function() return { root:GetChildren() } end)
	if not ok then return nil end
	for _, kid in ipairs(kids) do
		local found = FindWith(kid, field, depth + 1)
		if found then return found end
	end
end

-- The test ----------------------------------------------------------------------

ns.TestKit.Define({
	name = "platematch",
	key = "plateMatchTest",
	title = "Nameplate preview match",
	about = "the nameplate previews built on the game's own plate: every sample and state, the page, a real plate",
	cvars = CVARS,
	settings = { "combatTextStyle", "handlePlateStyle" },
	context = function()
		local ok, w, h = pcall(C_NamePlate.GetNamePlateSize)
		local setup = _G.NamePlateSetupOptions
		return ("plate size %s x %s; setup options %s (health %s, cast %s, inset %s, classic %s); Style loaded %s"):format(
			ok and S(w) or "err", ok and S(h) or "err", setup and "there" or "missing", setup and S(setup.healthBarHeight) or "-",
			setup and S(setup.castBarHeight) or "-", setup and S(setup.insetWidth) or "-",
			setup and S(setup.useClassicHealthBar) or "-", tostring(ns.ModuleLoaded and ns.ModuleLoaded("style")))
	end,
	putBack = function()
		for _, copy in ipairs(copies) do pcall(copy.Hide, copy) end
		return "our previews hidden"
	end,
	steps = {
		{ key = "templates", title = "the client's nameplate templates",
			proven = "platematch run 1 (2026-11-23): 21 nameplate templates listed, all 8 asked known", run = function(r)
			local xml = _G.C_XMLUtil
			local found = 0
			for _, name in ipairs(TEMPLATES) do
				local ok, info = pcall(xml.GetTemplateInfo, name)
				if ok and type(info) == "table" then found = found + 1 end
			end
			r:Verdict(found > 0, found .. " of " .. #TEMPLATES .. " plate templates known to this client")
		end },
		{ key = "preview", title = "Nameplate Style's preview on the game's plate: every sample and state",
			proven = "platematch runs 13-14 (2026-11-23): all 4 samples and 19 states as your settings draw them, debuffs inside, picks clear at 480/380/300",
			run = function(r)
			if not (ns.MakePlateRowLookPreview and ns.MakeGamePlate) then return r:Skip("Style isn't loaded") end
			if InCombatLockdown() then
				r:WaitFor("Leave the fight first.", { check = function() return not InCombatLockdown() and "out" end })
			end
			local holder = MakePreview()
			holder:Refresh()
			local plate = holder.gamePlate
			if not (plate and plate.gameCopy) then
				-- (Why, from the main log: run 4 and 5 said it there and the test didn't look.)
				local why = "none logged"
				for _, line in ipairs(CinematicDB.log or {}) do
					if tostring(line):find("game plate copy not used", 1, true) then why = tostring(line) end
				end
				return r:Fail("the preview built the game's plate; why not: " .. why)
			end
			r:Pass("the preview built the game's plate")
			r:Log("  " .. ns.GamePlateReport(plate))
			local copy = plate.UnitFrame
			-- (At rest: no marker sheet, soft-target icon or behind-camera icon: run 3's marker sheet.)
			for _, path in ipairs({ "RaidTargetFrame", "SoftTargetFrame.Icon", "behindCameraIcon" }) do
				r:Verdict(IsShownPlain(Piece(copy, path)) == false, path .. " hidden at rest")
			end
			-- (The sizes run 3 read off a real plate.)
			for _, want in ipairs({ { "HealthBarsContainer", 207.5, 15.83 }, { "HealthBarsContainer.healthBar.bgTexture", 215, 25 },
				{ "CastBarsContainer", 207.5, 20 } }) do
				local w, h = SizeOf(Piece(copy, want[1]))
				r:Verdict(w and math.abs(w - want[2]) <= 0.5 and math.abs(h - want[3]) <= 0.5,
					("%s %s x %s (a real plate's: %s x %s)"):format(want[1], S(w), S(h), want[2], want[3]))
			end
			Walk(r, copy, "P", { cap = COPY_LINES })
			-- Each sample unit.
			r:Verdict(holder.unitDropdown ~= nil and holder.stateDropdown ~= nil and holder.stateDropdown:IsShown(),
				"the Unit and State dropdowns under the plate (no rows of pills)")
			OnlyState(holder, nil)
			for i = 1, 4 do
				holder.PickSample(i) -- (what the Unit dropdown's choices call)
				local okC, cr, cg, cb = pcall(copy.HealthBarsContainer.healthBar.GetStatusBarColor, copy.HealthBarsContainer.healthBar)
				r:Log(("  SAMPLE %d %s: name %s, bar %s,%s,%s, level %s"):format(i, tostring(plate.kind), S(copy.name:GetText()),
					okC and S(cr) or "err", okC and S(cg) or "-", okC and S(cb) or "-",
					S(copy.PlayerLevelDiffFrame.playerLevelDiffText:GetText())))
				r:Verdict(copy.PlayerLevelDiffFrame:IsShown(), ("sample %s: the level box shown (Forever's, on NPCs too)"):format(
					tostring(plate.kind)))
				r:Shot("preview sample " .. tostring(plate.kind), { behind = holder })
			end
			holder.PickSample(1)
			-- Each state alone.
			local paths = {}
			for _, state in ipairs(ns.GAME_PLATE_STATES) do
				OnlyState(holder, state)
				local piece = Piece(copy, STATE_PIECE[state])
				if state == "interrupted" then r:Sleep(1.5) end -- (cut off 1.2 s into its cast)
				r:Log(("  STATE %s: G.%s %s"):format(state, STATE_PIECE[state], piece and Look(piece, paths) or "none"))
				local right, want, seen = StateShows(copy, state)
				r:Verdict(right, ("state %s: %s (your settings: %s, seen: %s)"):format(state, STATE_PIECE[state],
					want and "shown" or "not shown", tostring(seen)))
				if state == "debuffs" then
					r:Verdict(not copy.AurasFrame.BuffListFrame:IsShown(), "debuffs only: the buff list left out")
					local inside, top, frameTop = DebuffsInside(copy, holder)
					if inside == nil then r:Skip("debuff row's place not read") else
						r:Verdict(inside, ("the debuff row inside the preview (top %.0f, preview %.0f)"):format(top, frameTop))
					end
				end
				-- (Their times counting down, as a real plate's: an icon in the list with a cooldown going.)
				if state == "debuffs" or state == "crowd" then
					local timed = 0
					local ok, kids = pcall(function() return { piece:GetChildren() } end)
					for _, item in ipairs(ok and kids or {}) do
						local cd = item.Cooldown
						local okC, _, duration = pcall(function() return cd:GetCooldownTimes() end)
						if okC and type(duration) == "number" and duration > 0 and item:IsShown() then timed = timed + 1 end
					end
					r:Verdict(timed > 0, ("%s: %d icon(s) with their time counting down"):format(state, timed))
				end
				if state == "interrupted" then AwaitNextCast(r, plate) end
				r:Shot("preview state " .. state, { behind = holder })
			end
			OnlyState(holder, "casting")
			-- The State dropdown open, as you'd see it (its ticks, the menu over the page).
			local drop = holder.stateDropdown
			if drop and drop.OpenMenu then
				OnlyState(holder, "target")
				holder.ToggleState("debuffs")
				pcall(drop.OpenMenu, drop)
				r:Sleep(0.3)
				r:Verdict(drop.IsMenuOpen and drop:IsMenuOpen() or false, "the State dropdown opens")
				r:Shot("the State dropdown open (Target and Debuffs ticked)", { behind = holder })
				if drop.CloseMenu then pcall(drop.CloseMenu, drop) end
				OnlyState(holder, "casting")
			end
			-- The picks' layout at the widths the panels give it.
			for _, width in ipairs({ 480, 380, 300 }) do
				local fits = PillLayout(r, width)
				if fits == nil then
					r:Skip(("no pick places read at %d wide"):format(width))
				else
					r:Verdict(fits, ("picks inside the preview and clear of each other at %d wide"):format(width))
				end
			end
		end },
		{ key = "page", title = "Combat Text Style's page with the new preview",
			proven = "platematch runs 10-14 (2026-11-23): the preview on with nothing covered, the off card with the switch off",
			run = function(r)
			-- (Run 7 passed its checks, but its shots were taken with our preview over the window and the
			-- off state not redrawn: not proven till the shots are clean.)
			if not ns.OpenOptions then return r:Skip("no settings") end
			-- (The test's own preview away first: it sat over the settings window, run 7.)
			if preview then preview:Hide() end
			for _, on in ipairs({ true, false }) do
				-- (Closed, set, opened again: set while it's open, the page didn't redraw, run 7's
				-- "off" shot showed it on.)
				if _G.SettingsPanel and _G.SettingsPanel:IsShown() then pcall(HideUIPanel, _G.SettingsPanel) end
				r:Sleep(0.5)
				r:Set("combatTextStyle", on)
				pcall(ns.OpenOptions, "Combat Text Style")
				r:Sleep(1)
				local panel = _G.SettingsPanel
				local found = panel and FindPreview(panel, 0)
				-- (Off: the game's off card over the page, its settings behind it; run 8 passed "the preview on
				-- the page" with the switch off, the preview hidden under the card.)
				local card = ns.PageOffCardWanted and ns.PageOffCardWanted("Combat Text Style")
				if on then
					r:Verdict(found ~= nil and found:IsVisible() and not card, "page switch on: the preview on the page, no off card")
				else
					r:Verdict(card == true, "page switch off: the off card shows in its place")
				end
				if found and on then
					-- (An off card depends on the Style switches above the page: logged, the shot shows it.)
					r:Log(("  off card wanted: %s"):format(tostring(ns.PageOffCardWanted and ns.PageOffCardWanted("Combat Text Style"))))
					local canvas = found:GetParent()
					local covered, failed = 0, nil
					local list = {}
					for _, pick in ipairs(PicksOf(found)) do
						if pick:IsShown() then list[#list + 1] = { pick, pick == found.unitDropdown and "Unit dropdown"
							or pick == found.stateDropdown and "State dropdown" or "Scene" } end
					end
					for _, each in ipairs(list) do
						-- (No "also" list: it takes label frames, not words; run 6 passed words and the kit erred.)
						local okO, hits = pcall(r.Overlaps, r, each[1], canvas)
						if not okO then failed = tostring(hits) break end
						if #hits > 0 then r:Log(("  %s covers: %s"):format(each[2], table.concat(hits, ", "))) end
						covered = covered + #hits
					end
					if ns.noRealLayout then
						r:Skip("no real layout to measure (offline)")
					elseif failed then
						r:Skip("couldn't measure the page: " .. failed)
					else
						r:Verdict(covered == 0, ("page switch %s: the picks cover nothing on the page (%d)"):format(tostring(on), covered))
					end
				end
				-- (The switch as the page shows it, so the shot can't claim a state the page didn't draw.)
				local switch = ns.StyleOn and ns.StyleOn("combatTextStyle") or nil
				r:Log(("  page switch drawn for %s; the setting %s, StyleOn %s"):format(on and "on" or "off",
					tostring(ns.db.combatTextStyle), tostring(switch)))
				r:Shot(("Combat Text Style, page switch %s"):format(on and "on" or "off"), { behind = panel })
			end
			pcall(HideUIPanel, _G.SettingsPanel)
		end },
		{ key = "stylepage", title = "Nameplate Style's own page: one big game plate, the Theme list and Customize", run = function(r)
			if not ns.OpenOptions then return r:Skip("no settings") end
			if preview then preview:Hide() end
			if InCombatLockdown() then
				r:WaitFor("Leave the fight first.", { check = function() return not InCombatLockdown() and "out" end })
			end
			-- (Switch off: proven runs 11-14; full runs it again.)
			for _, on in ipairs(r:Proven("Nameplate Style's off card (runs 11-14)") and { true } or { true, false }) do
				-- (Closed, set, opened again: the page draws its switch's state, run 7's lesson.)
				if _G.SettingsPanel and _G.SettingsPanel:IsShown() then pcall(HideUIPanel, _G.SettingsPanel) end
				r:Sleep(0.5)
				r:Set("handlePlateStyle", on)
				pcall(ns.OpenOptions, "Nameplate Style")
				r:Sleep(1)
				local panel = _G.SettingsPanel
				local card = ns.PageOffCardWanted and ns.PageOffCardWanted("Nameplate Style")
				if not on then
					r:Verdict(card == true, "page switch off: the off card shows in its place")
					r:Shot("Nameplate Style, switch off", { behind = panel })
				else
					-- (By its previewer: the Look panel's, one big game plate with its
					-- Unit and State lists, the user 2026-11-23: "the same previewer in both".)
					local page = panel and FindWith(panel, "lookPreview")
					local content = panel and FindWith(panel, "plateThemeDropdown")
					r:Verdict(page ~= nil and page:IsVisible() and not card, "page switch on: the preview on the page, no off card")
					local inner = page and page.lookPreview
					if inner then
						page:Refresh()
						r:Verdict(page.gameMode == true and inner:IsShown(), "the preview on the game's plate (" .. tostring(page.gameMode) .. ")")
						local game = inner.gamePlate
						local copy = game and game.gameCopy
						r:Log(("  page preview %s x %s, plate scale %s"):format(S(page:GetWidth()), S(page:GetHeight()),
							S(game and game:GetScale())))
						r:Verdict(copy ~= nil and game:IsShown() and (ns.noRealLayout or (inner.gameScale or 0) > 1),
							("one game plate, drawn bigger (scale %s)"):format(S(inner.gameScale)))
						-- (Its lists inside it, covering nothing.)
						local covered = 0
						for _, each in ipairs({ { inner.unitDropdown, "Unit list" }, { inner.stateDropdown, "State list" } }) do
							r:Verdict(each[1] ~= nil and each[1]:IsVisible(), each[2] .. " shown on the preview")
							local okO, hits = pcall(r.Overlaps, r, each[1], page)
							if okO and #hits > 0 then r:Log(("  %s covers: %s"):format(each[2], table.concat(hits, ", "))) end
							covered = covered + (okO and #hits or 0)
						end
						if ns.noRealLayout then r:Skip("no real layout to measure (offline)") else
							r:Verdict(covered == 0, ("the Unit and State lists inside the preview, covering nothing (%d)"):format(covered))
						end
						-- (Each unit with what reaches past a plate on: the debuffs over it,
						-- crowd control right of its level box, the cast under it.)
						local states = ns.PlatePreviewStates()
						local function Only(list)
							for _, other in ipairs(ns.GAME_PLATE_STATES) do
								if states[other] then ns.TogglePlatePreviewState(other) end
							end
							for _, key in ipairs(list) do ns.TogglePlatePreviewState(key) end
						end
						Only({ "casting", "debuffs", "crowd" })
						for i, unit in ipairs({ "Hostile", "Neutral", "Friendly", "Player" }) do
							inner.PickSample(i)
							page:Refresh()
							r:Sleep(0.3)
							local inD, top, frameTop = DebuffsInside(copy, page)
							local inC, right, frameRight = CrowdInside(copy, page)
							if inD == nil or inC == nil then r:Skip(unit .. ": places not read") else
								r:Verdict(inD and inC, ("%s: debuffs and crowd control inside (top %.0f of %.0f, right %.0f of %.0f)"):format(
									unit, top, frameTop, right, frameRight))
							end
							r:Shot("Nameplate Style, " .. unit .. ": casting, debuffs, crowd control", { behind = panel })
						end
						inner.PickSample(1)
						-- (Each state: the previewer's own, proven in the preview step; full runs them here too.)
						if not r:Proven("each state on the page's plate: the same previewer as the preview step's") then
							for _, state in ipairs(copy and ns.GAME_PLATE_STATES or {}) do
								Only({ state })
								page:Refresh()
								if state == "interrupted" then r:Sleep(1.5) end
								local right, want, seen = StateShows(copy, state)
								r:Verdict(right, ("page state %s: as your settings draw it (%s, seen %s)"):format(state,
									want and "shown" or "not shown", tostring(seen)))
								if state == "interrupted" then AwaitNextCast(r, game) end
								r:Shot("Nameplate Style state " .. state, { behind = panel })
							end
						end
						Only({ "casting" })
						page:Refresh()
						-- (A theme pointed at in the Theme list: on the previewer, not saved.)
						local saved = ns.db.plateTheme
						page.hoverTheme = "game"
						page:Refresh()
						r:Verdict(ns.db.plateTheme == saved and inner.hoverTheme == "game",
							"a theme pointed at: on the previewer, the saved one left alone")
						r:Shot("Nameplate Style, The game's theme pointed at (not saved)", { behind = panel })
						page.hoverTheme = nil
						page:Refresh()
					end
					if content then
						local drop, customize = content.plateThemeDropdown, content.plateCustomize
						r:Verdict(drop ~= nil and drop:IsVisible() and customize ~= nil and customize:IsVisible(),
							"the Theme list and Customize shown")
						-- (Up front: right under the preview, not under a wall of tiles.)
						local dropTop, previewBottom = drop and drop:GetTop(), page and page:GetBottom()
						r:Log(("  theme row top %s, preview bottom %s"):format(S(dropTop), S(previewBottom)))
						r:Verdict(dropTop and previewBottom and previewBottom - dropTop < 80 or false,
							"the Theme list right under the preview")
						local covered = 0
						for _, each in ipairs({ { drop, "Theme list" }, { customize, "Customize" } }) do
							local okO, hits = pcall(r.Overlaps, r, each[1], content)
							if okO and #hits > 0 then r:Log(("  %s covers: %s"):format(each[2], table.concat(hits, ", "))) end
							covered = covered + (okO and #hits or 0)
						end
						if ns.noRealLayout then
							r:Skip("no real layout to measure (offline)")
						else
							r:Verdict(covered == 0, ("the Theme list and Customize cover nothing (%d)"):format(covered))
						end
						-- (Customize: the Default row's Look panel.)
						if customize and not r:Proven("Customize opens the Look panel (runs 11-14)") then
							customize:GetScript("OnClick")(customize, "LeftButton")
							r:Sleep(0.5)
							local open = ns.LookPanelOpen and ns.LookPanelOpen()
							r:Verdict(open ~= nil, "Customize opens the Look panel")
							r:Shot("Nameplate Style, Customize opened", { behind = panel })
							if open then open:Hide() end
						end
					else
						r:Fail("the Theme list's row on the page")
					end
				end
			end
			pcall(HideUIPanel, _G.SettingsPanel)
		end },
		{ key = "compare", title = "the preview's plate next to a real one, dressed by the same code",
			proven = "platematch run 6 (2026-11-23): 9 of 9 readable sizes the same, one texture the same fill on both, the real plate put back",
			run = function(r)
			local holder = MakePreview()
			local plate = holder.gamePlate
			if not (plate and plate.gameCopy) then return r:Fail("no game plate to compare") end
			OnlyState(holder, "target")
			local live = r:WaitFor("Target any mob with a nameplate (no need to fight it).", { check = function()
				if InCombatLockdown() then return nil end
				local p = UnitExists("target") and C_NamePlate.GetNamePlateForUnit("target")
				return p and p.UnitFrame and p
			end })
			local copy = plate.UnitFrame
			-- (Sizes: a piece unreadable on the real plate isn't counted, the name's.)
			local same, total = 0, 0
			for _, path in ipairs(COMPARE) do
				local ow, oh = SizeOf(Piece(copy, path))
				local lw, lh = SizeOf(Piece(live.UnitFrame, path))
				local match = ow and lw and math.abs(ow - lw) <= 0.5 and math.abs(oh - lh) <= 0.5
				if lw then total = total + 1 end
				if match then same = same + 1 end
				r:Log(("  SIZE %s: ours %s x %s, the game's %s x %s %s"):format(path, S(ow), S(oh), S(lw), S(lh),
					match and "same" or (lw and "DIFFERENT" or "(not readable on the real plate)")))
			end
			r:Verdict(same == total, ("%d of %d pieces the same size as the real plate's"):format(same, total))
			-- (The same look through the same code on both: their fills the same.)
			local texture
			for _, choice in ipairs(ns.StyleTextureChoices and ns.StyleTextureChoices(nil, "LookTexture") or {}) do
				if choice.value ~= "game" and choice.value ~= "general" and choice.value ~= "default" then texture = choice.value break end
			end
			if not (texture and ns.StylePlateBar) then return r:Skip("no texture to try") end
			local look = { texture = texture }
			ns.StylePlateBar(plate, look)
			ns.StylePlateBar(live, look)
			local function Fill(bar)
				local fill = bar:GetStatusBarTexture()
				return fill and (S(fill:GetAtlas()) .. "/" .. S(fill:GetTexture())) or "none"
			end
			local ours, theirs = Fill(copy.HealthBarsContainer.healthBar), Fill(live.UnitFrame.HealthBarsContainer.healthBar)
			r:Log(("  FILL %s: ours %s, the real plate's %s"):format(texture, ours, theirs))
			r:Verdict(ours == theirs, "the same look gives the same fill on the preview and a real plate")
			r:Shot("the preview (top) and your target's plate, both in " .. texture, { behind = holder })
			ns.StylePlateBar(live, nil)
			ns.StylePlateBar(plate, nil)
			local back = Fill(live.UnitFrame.HealthBarsContainer.healthBar)
			r:Log("  the real plate's fill put back: " .. back)
			r:Verdict(back:find("UI-HUD-CoolDownManager-Bar", 1, true) ~= nil, "the real plate's own fill back")
			holder:Hide()
		end },
	},
})
