-- /cine debug previewmatch units [skip|stop]: the Preview Match test for the Unit
-- Frames page's preview (Tools/preview-match-plan.md, step 4). Do its
-- mock-ups look like the game's own player, target, focus, pet and target of
-- target frames (the target's and the focus's)?
-- One run, steps on screen, no time limit, CineMode off for the run, never
-- opens Settings: it makes the page's preview itself (ns.MakeUnitStylePreview)
-- in a strip at the screen's left.
--   0 the game's look goes on (the Unit Frames Style page off), out of a fight;
--   1 it waits for a target, not yourself (on Forever your own target
--     frame's places are secret, 2026-11-20), one with mana is best, a
--     focus and your pet out, the target and the focus each targeting
--     someone (their targets of target: pull the focused mob, fighting is
--     fine) (or "/cine debug previewmatch units skip");
--   2 the game's frames and the preview's mock-ups read, the screen shot;
--   3 your look (only when your page was on), once you're out of any fight:
--     the same with your settings, with what's still up;
--   then your settings back (at the next login too if a reload cuts it short).
-- Read, per frame: its parts (frame art, portrait, health and power bars,
-- name, level), each placed and sized in widths of its health bar, the bars'
-- fill art and color, the texts' font, size, justify and color. Each pair
-- compared part by part, one line per difference, scored. Also the game
-- frame's whole tree of shown art (TREE lines): what a copy of it needs.
-- Saved into CinematicDB.previewMatch["<client>-units"]; /reload, "check log";
-- python Tools/preview-match/build.py makes the side-by-side page. Dev copy.
local _, ns = ...

local MAX_LINES, TREE_LINES = 2500, 120
local SETTLE = 1.2 -- (seconds after a look changes: RefreshUnitStyle settles at 0.4)
local DRAWN = 0.5 -- (seconds from the preview's drawing to its shot: masked textures show late)
-- (Each target of target against its own mock-up: the target's, TOT, and the focus's, FOCUSTOT.)
local IDS = { "PLAYER", "TARGET", "FOCUS", "PET", "TOT", "FOCUSTOT" }
local NAMES = { PLAYER = "Player frame", TARGET = "Target frame", FOCUS = "Focus frame", PET = "Pet frame",
	TOT = "Target's target of target", FOCUSTOT = "Focus's target of target" }
local UNITS = { PLAYER = "player", TARGET = "target", FOCUS = "focus", PET = "pet", TOT = "targettarget",
	FOCUSTOT = "focustarget" }
local GAME_FRAMES = { PLAYER = "PlayerFrame", TARGET = "TargetFrame", FOCUS = "FocusFrame", PET = "PetFrame",
	TOT = "TargetFrameToT", FOCUSTOT = "FocusFrameToT" }
local ROLES = { "art", "portrait", "health", "power", "name", "level" }
-- How far apart is "different": places and sizes in widths of the health bar,
-- a bar's shape (width over height) and a font's size as a part of its own.
local PLACE_OFF, SIZE_OFF, SHAPE_OFF, FONT_OFF = 0.08, 0.2, 0.25, 0.25

local K = ns.PreviewMatchKit
local run -- { step, phase, reads, shots, events, cineWasOn }
local Missing, Ready -- (step 1, below)

local function Store()
	CinematicDB.previewMatch = CinematicDB.previewMatch or {}
	local key = K.Client() .. "-units"
	local store = CinematicDB.previewMatch[key]
	if not store then
		store = {}
		CinematicDB.previewMatch[key] = store
	end
	return store
end

local function Log(text)
	local store = Store()
	store.lines = store.lines or {}
	if #store.lines >= MAX_LINES then return end
	store.lines[#store.lines + 1] = ("%s %s %s"):format(date("%H:%M:%S"), run and run.phase or "-", text)
end

-- The game's frames and their parts (UnitStyle.lua's Parts, and the level).
local function GameFrame(id)
	local frame = _G[GAME_FRAMES[id]]
	if not frame or K.Plain(K.Call(frame, "IsForbidden")) then return nil end
	return frame
end
local function GameParts(frame, id)
	local parts = {}
	parts.health = frame.healthbar or frame.HealthBar
	parts.power = frame.manabar or frame.ManaBar
	parts.name = frame.name or frame.Name
	parts.portrait = frame.portrait or frame.Portrait
	local holder = frame.PlayerFrameContainer or frame.TargetFrameContainer or frame
	parts.art = holder.FrameTexture or frame.FrameTexture
		or (frame.GetName and frame:GetName() and (_G[frame:GetName() .. "Texture"] or _G[frame:GetName() .. "TextureFrameTexture"]))
	-- (A frame with no art by name (the pet's): its biggest piece of unit frame art.)
	if type(parts.art) ~= "table" or not parts.art.GetAtlas then
		local best, most = nil, 0
		local function Look(node, depth)
			if depth > 6 then return end
			for _, region in ipairs({ K.Call(node, "GetRegions") }) do
				local atlas = K.Call(region, "GetObjectType") == "Texture" and K.Plain(K.Call(region, "GetAtlas"))
				local w, h = K.Call(region, "GetSize")
				w, h = K.Num(w), K.Num(h)
				if type(atlas) == "string" and atlas:find("UnitFrame", 1, true) and not atlas:find("Bar", 1, true)
					and w and h and w * h > most and K.Showing(region) then
					best, most = region, w * h
				end
			end
			for _, child in ipairs({ K.Call(node, "GetChildren") }) do Look(child, depth + 1) end
		end
		Look(frame, 0)
		parts.art = best
	end
	if id == "PLAYER" then
		parts.level = _G.PlayerLevelText
	else
		local content = frame.TargetFrameContent
		local main = content and content.TargetFrameContentMain
		parts.level = (main and main.LevelText) or frame.levelText
			or (frame.GetName and frame:GetName() and _G[frame:GetName() .. "TextureFrameLevelText"])
	end
	return parts
end
-- Our mock-up's parts, as MakeUnitStylePreview builds them.
local function OurParts(unit)
	local parts = {}
	parts.health, parts.power, parts.name = unit.health, unit.power, unit.name
	parts.portrait = (unit.portrait and unit.portrait:IsShown()) and unit.portrait or unit.face
	parts.level = unit.badge and unit.badge.text
	-- (Its frame art: the game look's copy of the game's (UnitFrameCopy.lua), its drawn metal, else nothing.)
	parts.art = (unit.copy and unit.copy.on and unit.copy.art:IsShown() and unit.copy.art)
		or (unit.box and unit.box:IsShown() and unit.box.wide) or nil
	return parts
end

-- One part, placed in widths of the health bar from the health bar's middle
-- (cx right, cy down), sized the same.
local function ReadPart(region, base)
	local entry = { kind = K.Call(region, "GetObjectType") }
	local px = K.Pixels(region)
	-- (Not a number: anchors that don't resolve. Unreadable, not a place.)
	if px then for i = 1, 4 do if px[i] ~= px[i] then px = nil break end end end
	if px and base then
		local bw = base[3] - base[1]
		local bx, by = (base[1] + base[3]) / 2, (base[2] + base[4]) / 2
		entry.cx = K.Round(((px[1] + px[3]) / 2 - bx) / bw)
		entry.cy = K.Round(((px[2] + px[4]) / 2 - by) / bw)
		entry.w, entry.h = K.Round((px[3] - px[1]) / bw), K.Round((px[4] - px[2]) / bw)
		entry.shape = (px[4] - px[2]) > 0 and K.Round((px[3] - px[1]) / (px[4] - px[2]), 2) or nil
	end
	entry.px = px and { K.Round(px[1], 0), K.Round(px[2], 0), K.Round(px[3], 0), K.Round(px[4], 0) } or nil
	if entry.kind == "Texture" then
		entry.art = K.Art(region)
		local r, g, b = K.Call(region, "GetVertexColor")
		r, g, b = K.Num(r), K.Num(g), K.Num(b)
		if r then entry.color = ("%.2f,%.2f,%.2f"):format(r, g or 0, b or 0) end
		entry.layer = K.Plain(K.Call(region, "GetDrawLayer"))
	elseif entry.kind == "StatusBar" then
		local fill = K.Call(region, "GetStatusBarTexture")
		entry.art = fill and K.Art(fill)
		local r, g, b = K.Call(region, "GetStatusBarColor")
		r, g, b = K.Num(r), K.Num(g), K.Num(b)
		-- (The fill's own tint on top: retail's bars are colored atlases, white.)
		local fr, fg, fb = K.Call(fill, "GetVertexColor")
		fr, fg, fb = K.Num(fr), K.Num(fg), K.Num(fb)
		if r and fr then entry.color = ("%.2f,%.2f,%.2f"):format(r * fr, (g or 0) * (fg or 1), (b or 0) * (fb or 1)) end
	elseif entry.kind == "FontString" then
		local font, size, flags = K.Call(region, "GetFont")
		font, size = K.Plain(font), K.Num(size)
		entry.font = font and (tostring(font):match("[^\\/]+$") or tostring(font)) or nil
		entry.flags = K.Plain(flags)
		local scale = K.Num(K.Call(region, "GetEffectiveScale"))
		local _, physH = K.ScreenSize()
		if size and scale and base then
			entry.fontPx = K.Round(size * scale * physH / 768, 1)
			entry.fontW = K.Round(entry.fontPx / (base[3] - base[1]))
		end
		entry.justify = K.Plain(K.Call(region, "GetJustifyH"))
		local text = K.Plain(K.Call(region, "GetText"))
		entry.text = type(text) == "string" and text or nil
		local r, g, b = K.Call(region, "GetTextColor")
		r, g, b = K.Num(r), K.Num(g), K.Num(b)
		if r then entry.color = ("%.2f,%.2f,%.2f"):format(r, g or 0, b or 0) end
	end
	return entry
end

local function ReadFrame(parts, label)
	local read = { label = label, parts = {} }
	local base = parts.health and K.Showing(parts.health) and K.Pixels(parts.health)
	if not base or base[3] - base[1] <= 0 then
		read.unread = "health bar not on screen or its place unreadable"
		return read
	end
	local box
	for _, role in ipairs(ROLES) do
		local region = parts[role]
		if region and K.Showing(region) then
			read.parts[role] = ReadPart(region, base)
			box = K.Grow(box, read.parts[role].px)
		end
	end
	read.box = box and { K.Round(box[1], 0), K.Round(box[2], 0), K.Round(box[3], 0), K.Round(box[4], 0) } or nil
	read.barBox = { K.Round(base[1], 0), K.Round(base[2], 0), K.Round(base[3], 0), K.Round(base[4], 0) }
	return read
end

-- The game frame's tree: every shown texture and text, by its key path, art,
-- place in pixels and layer (the recipe a copy would need).
local function KeyOf(parent, child)
	for key, value in pairs(parent) do
		if value == child and type(key) == "string" then return key end
	end
	local name = K.Call(child, "GetName")
	return name and tostring(name) or "?"
end
local function Tree(id, frame)
	local count = 0
	local origin = K.Pixels(frame)
	local function Walk(node, path, depth)
		if count >= TREE_LINES or depth > 6 then return end
		for _, region in ipairs({ K.Call(node, "GetRegions") }) do
			if count >= TREE_LINES then return end
			if K.Showing(region) then
				local kind = K.Call(region, "GetObjectType")
				local px = K.Pixels(region)
				local at = (px and origin) and ("%d,%d %dx%d"):format(px[1] - origin[1], px[2] - origin[2], px[3] - px[1], px[4] - px[2]) or "?"
				local what
				if kind == "FontString" then
					local font, size = K.Call(region, "GetFont")
					what = ("%s %s"):format(tostring(K.Plain(font) and tostring(font):match("[^\\/]+$")), tostring(K.Round(K.Num(size), 1)))
				else
					local r, g, b, a = K.Call(region, "GetVertexColor")
					local left, right, top, bottom = K.Call(region, "GetTexCoord")
					what = ("%s color %s,%s,%s,%s coords %s,%s,%s,%s %s"):format(tostring(K.Art(region)),
						tostring(K.Round(K.Num(r), 2)), tostring(K.Round(K.Num(g), 2)), tostring(K.Round(K.Num(b), 2)),
						tostring(K.Round(K.Num(a), 2)), tostring(K.Round(K.Num(left), 3)), tostring(K.Round(K.Num(right), 3)),
						tostring(K.Round(K.Num(top), 3)), tostring(K.Round(K.Num(bottom), 3)),
						tostring(K.Plain(K.Call(region, "GetBlendMode"))))
				end
				local layer, sub = K.Call(region, "GetDrawLayer")
				count = count + 1
				Log(("TREE %s %s.%s %s %s at %s %s/%s"):format(id, path, KeyOf(node, region), tostring(kind), what, at,
					tostring(K.Plain(layer)), tostring(K.Plain(sub))))
			end
		end
		for _, child in ipairs({ K.Call(node, "GetChildren") }) do
			if K.Plain(K.Call(child, "IsShown")) and not K.Plain(K.Call(child, "IsForbidden")) then
				Walk(child, path .. "." .. KeyOf(node, child), depth + 1)
			end
		end
	end
	Walk(frame, id, 0)
	if count >= TREE_LINES then Log(("TREE %s: cut at %d lines"):format(id, TREE_LINES)) end
end

-- Compare: one line per difference, game first.
local function Off(a, b, off)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) > off
end
local function Compare(real, ours, id)
	local findings = { checks = 0 }
	local function Say(text) findings[#findings + 1] = text end
	if real.unread or ours.unread then
		Say("can't read: " .. tostring(real.unread or ours.unread))
		return findings
	end
	for _, role in ipairs(ROLES) do
		local g, o = real.parts[role], ours.parts[role]
		findings.checks = findings.checks + 1
		if g and not o then
			Say(("MISSING %s (%s %s) shows in game, not ours"):format(role, tostring(g.kind), tostring(g.art or g.font or "")))
		-- (A power bar only ours shows: the unit read has none, a mob without mana,
		-- 2026-11-20. The unit's, not the look's: noted, not counted.)
		elseif o and not g and role == "power" then
			findings.notes = findings.notes or {}
			table.insert(findings.notes, "power bar not compared: the unit read shows none")
		elseif o and not g then
			Say(("EXTRA %s (%s %s) shows ours, not in game"):format(role, tostring(o.kind), tostring(o.art or o.font or "")))
		elseif g and o then
			findings.checks = findings.checks + (g.kind == "FontString" and 5 or 4)
			-- (The face is the unit's own: never the same picture.)
			if role ~= "portrait" and g.art and g.art ~= o.art then
				Say(("ART %s: %s in game, %s ours"):format(role, tostring(g.art), tostring(o.art)))
			end
			-- (Another's level is colored by how hard it is for you: the unit's, not the look's.)
			-- (And another's power bar's color is its power's: our sample warrior's rage
			-- against a mana user, 2026-11-20. Yours and your pet's are compared.)
			local byUnit = (role == "level" and id ~= "PLAYER") or (role == "power" and id ~= "PLAYER" and id ~= "PET")
			if role ~= "portrait" and not byUnit and K.ColorOff(g.color, o.color) then
				Say(("COLOR %s: %s in game, %s ours"):format(role, tostring(g.color), tostring(o.color)))
			end
			-- (A text's width follows its words: its font's size says its size.)
			if g.kind ~= "FontString" then
				local shape = g.shape and o.shape and g.shape > 0 and math.abs(g.shape - o.shape) / g.shape > SHAPE_OFF
				if Off(g.w, o.w, SIZE_OFF * math.max(g.w or 0, 0.25)) or Off(g.h, o.h, SIZE_OFF * math.max(g.h or 0, 0.25)) or shape then
					Say(("SIZE %s: %sx%s health widths (%s:1) in game, %sx%s (%s:1) ours"):format(role, tostring(g.w),
						tostring(g.h), tostring(g.shape), tostring(o.w), tostring(o.h), tostring(o.shape)))
				end
			end
			-- (A text's middle moves with its words along its justify: up and down,
			-- and its side, only.)
			local across = g.kind ~= "FontString" or g.justify == "CENTER"
			if (across and Off(g.cx, o.cx, PLACE_OFF)) or Off(g.cy, o.cy, PLACE_OFF) then
				Say(("PLACE %s: middle at %s,%s health widths from the health bar's in game, %s,%s ours"):format(role,
					tostring(g.cx), tostring(g.cy), tostring(o.cx), tostring(o.cy)))
			end
			if g.kind == "FontString" then
				if g.font ~= o.font then Say(("FONT %s: %s in game, %s ours"):format(role, tostring(g.font), tostring(o.font))) end
				if g.fontW and o.fontW and g.fontW > 0 and math.abs(g.fontW - o.fontW) / g.fontW > FONT_OFF then
					Say(("FONT SIZE %s: %s health widths in game, %s ours"):format(role, tostring(g.fontW), tostring(o.fontW)))
				end
				if g.justify ~= o.justify then
					Say(("JUSTIFY %s: %s in game, %s ours"):format(role, tostring(g.justify), tostring(o.justify)))
				end
			end
		end
	end
	return findings
end

-- Quality control of the preview's layout (user 2026-11-20, a screenshot of
-- the Style General page: an empty frame under yours, the level cut to "..",
-- the focus's target of target cut off, frames on each other). Every problem
-- one line: a frame (or a part of it) past the preview's edge, where it's cut
-- off; two frames on each other (not one hung off the other, as the game
-- hangs a target of target or your pet); a text cut short; art left showing
-- with nothing of its own frame on it.
function ns.UnitPreviewLayoutCheck(holder)
	local problems = {}
	local hl, hr, ht, hb = holder:GetLeft(), holder:GetRight(), holder:GetTop(), holder:GetBottom()
	if not (hl and hr and ht and hb) then return { "the preview isn't on the screen: nothing to measure" } end
	local hs = holder:GetEffectiveScale()
	local function Rect(region)
		local l, r, t, b = region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom()
		if not (l and r and t and b) then return nil end
		local k = region:GetEffectiveScale() / hs
		return { l * k, r * k, t * k, b * k }
	end
	local boxes = {}
	for key, unit in pairs(holder.units or {}) do
		if unit:IsVisible() then
			local box = Rect(unit)
			if box then boxes[key] = box end
			local parts = { unit, unit.name, unit.health, unit.power, unit.badge and unit.badge.text or false }
			if unit.copy and unit.copy.on then
				for _, texture in ipairs(unit.copy.textures) do parts[#parts + 1] = texture end
				for _, extra in ipairs(unit.copy.extras) do parts[#parts + 1] = extra end
			end
			for _, part in ipairs(parts) do
				local rect = part and part:IsVisible() and Rect(part)
				if rect and (rect[1] < hl - 1 or rect[2] > hr + 1 or rect[3] > ht + 1 or rect[4] < hb - 1) then
					problems[#problems + 1] = ("CUT %s: %s past the preview's edge"):format(key,
						part == unit and "the frame" or tostring(part:GetObjectType()))
					break
				end
			end
			for _, text in ipairs({ unit.name, unit.badge and unit.badge.text or false }) do
				if text and text:IsVisible() and text:GetText() then
					local cut = text.IsTruncated and text:IsTruncated()
					if type(cut) ~= "boolean" then cut = false end
					local width = text:GetWidth()
					if not cut and width and width > 0 and text:GetStringWidth() > width + 1 then cut = true end
					if cut then problems[#problems + 1] = ("TEXT %s: %q cut short"):format(key, text:GetText()) end
				end
			end
		end
	end
	local keys = {}
	for key in pairs(boxes) do keys[#keys + 1] = key end
	table.sort(keys)
	for i = 1, #keys do
		for j = i + 1, #keys do
			local a, b = holder.units[keys[i]], holder.units[keys[j]]
			local hung = a.hungOn == b or b.hungOn == a
			local x, y = boxes[keys[i]], boxes[keys[j]]
			local across = math.min(x[2], y[2]) - math.max(x[1], y[1])
			local down = math.min(x[3], y[3]) - math.max(x[4], y[4])
			if not hung and across > 2 and down > 2 then
				problems[#problems + 1] = ("OVERLAP %s and %s: %.0f x %.0f on each other"):format(keys[i], keys[j], across, down)
			end
		end
	end
	return problems
end

-- Your settings: the page's switch, kept and put back (at the next login too).
local function PutBack()
	local kept = CinematicDB and CinematicDB.previewMatchUnitsKept
	local db = K.DB()
	if not (kept and db) then return false end
	db.ufStyle = kept.ufStyle
	CinematicDB.previewMatchUnitsKept = nil
	if ns.RefreshUnitStyle then pcall(ns.RefreshUnitStyle) end
	return true
end
local restore = CreateFrame("Frame")
restore:RegisterEvent("PLAYER_LOGIN")
restore:SetScript("OnEvent", function()
	C_Timer.After(1.2, function()
		if PutBack() then ns.Print("preview match: your Unit Frames Style setting put back (a reload cut the test short).") end
	end)
end)

-- The page's preview, in a strip at the screen's left, under the unit frames.
local strip, preview
local function MakePreview()
	if strip then return end
	strip = CreateFrame("Frame", nil, UIParent)
	strip:SetSize(480, 200)
	strip:SetPoint("LEFT", UIParent, "LEFT", 40, -40)
	strip:SetFrameStrata("HIGH")
	preview = ns.MakeUnitStylePreview(strip, 480)
	preview:SetAllPoints()
end

local function Shot(name)
	pcall(ns.TestPrompt, " ", 0.05)
	local stamp = date("%m%d%y_%H%M%S")
	Screenshot()
	run.shots[#run.shots + 1] = { name = name, stamp = stamp, time = time() }
	Log(("SHOT %s %s"):format(name, stamp))
	return stamp
end

local function Keep(key, read, stamp)
	read.shot = stamp
	run.reads[key] = read
	local names = {}
	for role in pairs(read.parts) do names[#names + 1] = role end
	table.sort(names)
	Log(("%s: %s, shows %s"):format(key, read.unread or "read", table.concat(names, ", ")))
	for _, role in ipairs(ROLES) do
		local part = read.parts[role]
		if part then
			Log(("  %s %s %s at %s,%s size %sx%s %s%s%s"):format(role, tostring(part.kind), tostring(part.art or part.font),
				tostring(part.cx), tostring(part.cy), tostring(part.w), tostring(part.h), tostring(part.color),
				part.fontPx and (" font " .. part.fontPx .. "px") or "", part.justify and (" " .. part.justify) or ""))
		end
	end
end

-- One look: every frame that's up read, game and ours, one screenshot.
-- (What a masked texture of ours draws: where it and each of its masks sit,
-- its alpha and art. In game 2026-11-20 every portrait and health fill of the
-- preview drew nothing, their art right and their masks in place.)
local function Masked(label, texture)
	if not texture then return end
	local function Box(region)
		local l, b, w, h = region:GetRect()
		if not l then return "no place" end
		return ("%.0f,%.0f %.0fx%.0f"):format(l * region:GetEffectiveScale(), b * region:GetEffectiveScale(),
			w * region:GetEffectiveScale(), h * region:GetEffectiveScale())
	end
	local masks = {}
	local count = texture.GetNumMaskTextures and texture:GetNumMaskTextures() or 0
	if type(count) ~= "number" then count = 0 end
	for i = 1, count do
		local mask = texture:GetMaskTexture(i)
		if mask then
			masks[#masks + 1] = ("%s %s shown %s"):format(tostring(K.Art(mask)), Box(mask), tostring(mask:IsShown()))
		end
	end
	-- (A texture's own alpha: Forever errors on a texture's GetEffectiveAlpha, 2026-11-20.)
	local alpha = K.Num(K.Call(texture, "GetAlpha")) or -1
	Log(("  MASKED %s: shown %s visible %s alpha %.2f art %s at %s; %d masks: %s"):format(label, tostring(texture:IsShown()),
		tostring(texture:IsVisible()), alpha, tostring(K.Art(texture)), Box(texture), count,
		table.concat(masks, " | ")))
end

local function ReadPhase(phase, treeToo, done)
	run.phase = phase
	-- (On screen for its shot: something put CineMode back on after a fight, and
	-- the preview wasn't in the shot of your look, 2026-11-20.)
	K.SetCine(false)
	if strip then strip:Show() end
	-- (At the Style screens' own size: every Style page's preview and the
	-- Style General page's screen are held to it.)
	if ns.StylePreviewHeight then preview:SetHeight(ns.StylePreviewHeight()) end
	preview:Refresh()
	local problems = ns.UnitPreviewLayoutCheck(preview)
	Log(("  stage scale %.3f, preview visible %s"):format(preview.units.PLAYER:GetParent():GetScale(),
		tostring(preview:IsVisible())))
	for _, key in ipairs({ "PLAYER", "PARTY" }) do
		local unit = preview.units[key]
		if unit then
			pcall(Masked, key .. " face", unit.face)
			pcall(Masked, key .. " class portrait", unit.portrait:IsShown() and unit.portrait or nil)
			pcall(Masked, key .. " health fill", unit.health:GetStatusBarTexture())
			Log(("  %s health value %s of %s"):format(key, tostring(unit.health:GetValue()), tostring(select(2, unit.health:GetMinMaxValues()))))
		end
	end
	Log(("LAYOUT %s look: %d problems at %dx%d"):format(phase, #problems, preview:GetWidth(), preview:GetHeight()))
	for _, line in ipairs(problems) do Log("  " .. line) end
	run.layout = run.layout or {}
	run.layout[phase] = problems
	-- (Shot a moment after it's drawn: a masked texture shows a frame or more
	-- after it's set up. Shot at once, every face and bar fill of the
	-- preview was blank in every run till 2026-11-20 (a probe shot 0.5 s
	-- later drew them all).)
	C_Timer.After(DRAWN, function()
		if not run then return end
		local stamp = Shot(phase)
		for _, id in ipairs(IDS) do
			local frame = GameFrame(id)
			local unit = preview.units and preview.units[id]
			if frame and K.Plain(K.Call(frame, "IsVisible")) and UnitExists(UNITS[id]) and unit then
				Keep(phase .. ":game:" .. id, ReadFrame(GameParts(frame, id), "game:" .. id), stamp)
				Keep(phase .. ":ours:" .. id, ReadFrame(OurParts(unit), "ours:" .. id), stamp)
				Log(("  ours %s: %s"):format(id, unit.copy and unit.copy.on and "the copy" or ("drawn (" .. tostring(unit.copyWhy) .. ")")))
				if treeToo then Tree(id, frame) end
			else
				Log(("%s: not up (%s), not read"):format(id, frame and "no " .. UNITS[id] or "no frame"))
			end
		end
		-- (After the shot is saved, a moment on: carried on at once, the run's end
		-- put CineMode back on in the same moment and the shot of your look had no
		-- UI in it, 2026-11-20.)
		if done then C_Timer.After(DRAWN, function() if run then done() end end) end
	end)
end

local function Finish()
	local store = Store()
	store.reads, store.shots, store.pairs = run.reads, run.shots, {}
	local summary = {}
	store.layout = run.layout
	for phase, problems in pairs(run.layout or {}) do
		summary[#summary + 1] = ("layout (%s) %s"):format(phase, #problems == 0 and "clean" or (#problems .. " problems"))
	end
	for _, phase in ipairs({ "game", "yours" }) do
		for _, id in ipairs(IDS) do
			local real, ours = run.reads[phase .. ":game:" .. id], run.reads[phase .. ":ours:" .. id]
			if real and ours then
				local name = NAMES[id] .. (phase == "yours" and " (your style)" or "")
				local entry = { name = name, real = phase .. ":game:" .. id, ours = phase .. ":ours:" .. id }
				entry.findings = Compare(real, ours, id)
				local checks = math.max(entry.findings.checks, #entry.findings, 1)
				entry.findings.checks = nil
				local notes = entry.findings.notes
				entry.findings.notes = nil
				entry.score = math.floor(100 * (checks - #entry.findings) / checks + 0.5)
				Log(("PAIR %s: score %d, %d differences"):format(name, entry.score, #entry.findings))
				for _, line in ipairs(entry.findings) do Log("  " .. line) end
				for _, line in ipairs(notes or {}) do Log("  NOTE " .. line) end
				summary[#summary + 1] = ("%s %d"):format(name, entry.score)
				store.pairs[#store.pairs + 1] = entry
			end
		end
	end
	run.events:UnregisterAllEvents()
	PutBack()
	K.SetCine(run.cineWasOn)
	if strip then strip:Hide() end
	run = nil
	ns.TestPrompt(("Preview match (unit frames) DONE: %d frames compared. /reload, then tell Claude 'check log'."):format(#summary), 30)
	ns.Print("preview match: " .. (#summary > 0 and table.concat(summary, ", ") or "nothing read"))
end

-- Fights: the frames are read fine in one (their places aren't secret), but
-- a look can't be put on or taken off them then (the game holds unit frames
-- still): read with the page switched off in a fight, our level badge stayed
-- on and was read as the game's, 2026-11-20. So the game's look goes on
-- before step 1, out of a fight, and stays through any fight; your look goes
-- back on once you're out of one, and is read then with what's still up.
local calm = CreateFrame("Frame")
local afterCalm
calm:SetScript("OnEvent", function(self)
	self:UnregisterAllEvents()
	local fn = afterCalm
	afterCalm = nil
	if fn and run then C_Timer.After(0.5, fn) end
end)
local function WhenCalm(fn, why)
	if not InCombatLockdown() then return true end
	afterCalm = fn
	calm:RegisterEvent("PLAYER_REGEN_ENABLED")
	Log("in a fight: " .. why .. " once it ends")
	ns.TestPrompt("Preview match (unit frames) 3/3: game's look read. Your own look is read once the fight ends: finish it, then stand still.", 600)
	return false
end

-- Step 3: your look, out of a fight, with what's up then.
local function ReadYours()
	if not run then return end
	if not WhenCalm(ReadYours, "your look goes back on and is read") then return end
	run.step = 3
	ns.TestPrompt("Preview match (unit frames) 3/3: hands off, reading your look.", 3)
	K.DB().ufStyle = true
	if ns.RefreshUnitStyle then pcall(ns.RefreshUnitStyle) end
	C_Timer.After(SETTLE, function()
		if not run then return end
		-- (A fight begun as it went on: dressed partly. Again after that one.)
		if not WhenCalm(ReadYours, "your look goes on again and is read") then return end
		ReadPhase("yours", false, Finish)
	end)
end

-- Step 2: every frame up (or skipped), the game's look on them since the start.
local Go
Go = function()
	if not run then return end
	run.step = 2
	ns.TestPrompt("Preview match (unit frames) 2/3: hands off, reading the game's look.", 3)
	C_Timer.After(0.3, function()
		if not run then return end
		ReadPhase("game", true, function()
			local kept = CinematicDB.previewMatchUnitsKept
			if not (kept and kept.ufStyle) then
				Log("your Unit Frames Style page is off: your look is the game's, no second read")
				Finish()
				return
			end
			ReadYours()
		end)
	end)
end

-- Step 1: every frame the run compares up: a target not you (on Forever your
-- own target frame's places are secret), a focus, your pet. Each missing one
-- named on screen; "/cine debug previewmatch units skip" goes without them.
Missing = function()
	local list = {}
	if not UnitExists("target") or UnitIsUnit("target", "player") then
		list[#list + 1] = UnitExists("target") and "a TARGET not yourself" or "a TARGET (a mob with mana is best)"
	end
	if not UnitExists("focus") then list[#list + 1] = "a FOCUS (/focus on your target)" end
	if not UnitExists("pet") then list[#list + 1] = "your PET out" end
	-- (Their targets of target: a target and a focus that are targeting someone.
	-- A fight's fine: pull the mob you've focused, it targets you or your pet.)
	if not UnitExists("targettarget") then list[#list + 1] = "your target TARGETING someone (pull it: fighting is fine)" end
	if not UnitExists("focustarget") then list[#list + 1] = "your focus TARGETING someone" end
	return list
end
Ready = function()
	if not run.lookReady then return end
	local missing = Missing()
	if #missing == 0 then
		run.step = 1.5
		C_Timer.After(0.5, function() if run then Go() end end)
		return
	end
	if UnitExists("target") and UnitIsUnit("target", "player") and not run.saidYou then
		run.saidYou = true
		Log("target is you: waiting for another (your own target frame's places are secret)")
	end
	ns.TestPrompt(("Preview match (unit frames) 1/3: the game's look is on. Waiting for %s. Or type /cine debug previewmatch units skip"):format(
		table.concat(missing, ", ")), 600)
end

local function Stop()
	if not run then return end
	run.events:UnregisterAllEvents()
	PutBack()
	K.SetCine(run.cineWasOn)
	if strip then strip:Hide() end
	run = nil
	ns.TestPrompt("Preview match (unit frames) stopped. Your settings are back.", 5)
end

-- "/cine debug previewmatch units masks": when does a masked texture stop
-- drawing? In game 2026-11-20 every masked face and bar fill of the preview
-- drew nothing once its layout pass ran (each frame moved twice, measured
-- between, then the stage sized and scaled), while the game said each was
-- shown, at full alpha, its mask on it. Shrinking alone draws fine (first
-- probe, 16:31). Each case below changes one thing after the mask is on, as
-- the preview does; one screenshot, logged; then gone. Nothing to do.
local MASK_CASES = {
	{ "as made" },
	{ "scaled after", function(_, owner) owner:SetScale(0.8) end },
	{ "moved after", function(box, owner)
		box:ClearAllPoints()
		box:SetPoint("TOP", owner, "TOP", 0, -14)
	end },
	{ "moved, measured, moved", function(box, owner)
		box:ClearAllPoints()
		box:SetPoint("TOP", owner, "TOP", 10, -4)
		local _ = box:GetLeft()
		box:ClearAllPoints()
		box:SetPoint("TOP", owner, "TOP", 0, -14)
	end },
	{ "holder sized + scaled", function(_, owner)
		owner:SetSize(90, 90)
		owner:SetScale(0.8)
	end },
	{ "mask set again", function(box, _, mask)
		mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIONAL", "CLAMPTOBLACKADDITIONAL")
		mask:ClearAllPoints()
		mask:SetAllPoints(box)
	end },
}
local function MaskProbe()
	local holder = CreateFrame("Frame", nil, UIParent)
	holder:SetSize(#MASK_CASES * 110, 140)
	holder:SetPoint("CENTER", 0, 120)
	holder:SetFrameStrata("DIALOG")
	local back = holder:CreateTexture(nil, "BACKGROUND")
	back:SetAllPoints()
	back:SetColorTexture(0.1, 0.1, 0.12, 0.95)
	for i, case in ipairs(MASK_CASES) do
		local cell = CreateFrame("Frame", nil, holder)
		cell:SetSize(100, 120)
		cell:SetPoint("TOPLEFT", (i - 1) * 110 + 5, -5)
		if cell.SetClipsChildren then cell:SetClipsChildren(true) end -- (as the preview's holder)
		local owner = CreateFrame("Frame", nil, cell) -- (the stage)
		owner:SetSize(100, 100)
		owner:SetPoint("TOP")
		local box = CreateFrame("Frame", nil, owner) -- (a unit)
		box:SetSize(64, 64)
		box:SetPoint("TOP", owner, "TOP", 0, -8)
		local face = box:CreateTexture(nil, "BACKGROUND", nil, 1)
		face:SetAllPoints()
		face:SetTexture("Interface\\Icons\\INV_Misc_Head_Orc_01")
		local mask = box:CreateMaskTexture()
		mask:SetAllPoints()
		mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIONAL", "CLAMPTOBLACKADDITIONAL")
		face:AddMaskTexture(mask)
		if case[2] then pcall(case[2], box, owner, mask) end
		local label = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetPoint("BOTTOM", 0, 2)
		label:SetText(case[1])
	end
	-- (And whole previews under them: the test's own strip never drew a masked
	-- face, even before the layout pass (14:08), while the Style General page's
	-- did. As the test makes it, in another frame layer, and fitted as the
	-- Style General page fits its screens.)
	local previews = {}
	for i, how in ipairs({ "as the test (HIGH)", "DIALOG layer", "fitted as General" }) do
		local frame = CreateFrame("Frame", nil, UIParent)
		frame:SetSize(480, 200)
		frame:SetPoint("TOP", UIParent, "CENTER", (i - 2) * 500, 30)
		frame:SetFrameStrata(i == 2 and "DIALOG" or "HIGH")
		local one = ns.MakeUnitStylePreview(frame, 480)
		one:SetAllPoints()
		if i == 3 and ns.StylePreviewHeight then
			frame:SetHeight(ns.StylePreviewHeight())
			one:Refresh()
			if ns.ApplyPreviewFit then ns.ApplyPreviewFit(one) end
		else
			one:Refresh()
		end
		local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		label:SetPoint("BOTTOM", frame, "TOP", 0, 2)
		label:SetText(how)
		previews[#previews + 1] = frame
		pcall(Masked, how .. ": PLAYER face", one.units and one.units.PLAYER and one.units.PLAYER.face)
		pcall(Masked, how .. ": PARTY face", one.units and one.units.PARTY and one.units.PARTY.face)
	end
	C_Timer.After(0.5, function()
		local stamp = date("%m%d%y_%H%M%S")
		Screenshot()
		CinematicDB.previewMatchMaskShot = stamp
		C_Timer.After(3, function() for _, frame in ipairs(previews) do frame:Hide() end end)
		ns.Print("preview match masks: shot " .. stamp .. ". /reload, then tell Claude 'check log'.")
		C_Timer.After(3, function() holder:Hide() end)
	end)
end

function ns.PreviewMatchUnits(arg)
	if arg == "masks" then
		MaskProbe()
		return
	end
	if arg == "stop" then
		Stop()
		return
	end
	if arg == "skip" then
		if run and run.step == 1 and run.lookReady then
			Log("skipped waiting for: " .. table.concat(Missing(), ", "))
			run.step = 1.5
			C_Timer.After(0.5, function() if run then Go() end end)
		end
		return
	end
	if run then
		ns.Print("preview match: already running (/cine debug previewmatch units stop to stop it)")
		return
	end
	-- (Started out of a fight: the game's look goes on first, which a fight forbids.)
	if InCombatLockdown() then
		ns.Print("preview match: start it out of a fight (fighting is fine once it's going).")
		return
	end
	if not (K and ns.MakeUnitStylePreview) then
		ns.Print("preview match: the unit frames page's preview maker is missing.")
		return
	end
	local store = Store()
	wipe(store)
	local version, build = GetBuildInfo()
	local physW, physH = K.ScreenSize()
	store.client, store.build, store.started = K.Client(), ("%s %s"):format(tostring(version), tostring(build)), date()
	store.screen = { physW, physH }
	store.uiScale = K.Round(UIParent:GetEffectiveScale(), 4)
	local db = K.DB()
	run = { step = 1, phase = "start", reads = {}, shots = {},
		cineWasOn = ns.IsCineModeOn and ns.IsCineModeOn() and true or false }
	CinematicDB.previewMatchUnitsKept = { ufStyle = db.ufStyle }
	local okTot, tot = pcall(GetCVar, "showTargetOfTarget")
	Log("the game's Target of Target setting (showTargetOfTarget): " .. tostring(okTot and tot))
	Log(("start: %s %s, screen %dx%d, UI scale %s; ufStyle=%s, Style on %s, theme layout %s"):format(store.client,
		store.build, physW, physH, tostring(store.uiScale), tostring(db.ufStyle), tostring(ns.StyleOn and ns.StyleOn("ufStyle")),
		tostring(ns.ThemeLayout and ns.ThemeLayout())))
	run.events = CreateFrame("Frame")
	run.events:SetScript("OnEvent", function() if run and run.step == 1 then Ready() end end)
	for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_PET", "UNIT_TARGET" }) do
		pcall(run.events.RegisterEvent, run.events, event)
	end
	K.SetCine(false)
	MakePreview()
	strip:Show()
	-- (The game's look on now, out of a fight, kept through the waiting.)
	db.ufStyle = false
	if ns.RefreshUnitStyle then pcall(ns.RefreshUnitStyle) end
	ns.TestPrompt("Preview match (unit frames): putting the game's look on.", 3)
	C_Timer.After(SETTLE, function()
		if not run then return end
		run.lookReady = true
		Ready()
	end)
end

-- (For the Shoulder Cam's stand-in target frame test, /cine debug shoulder
-- selfframe: Dev/ShoulderCamTest.lua reads the stand-in, which carries the
-- game's target frame part names, and the game's target frame of you, and
-- compares them. Keep these two names working, or tell that session.)
function ns.UnitMatchRead(frame, id) return ReadFrame(GameParts(frame, id), id) end
ns.UnitMatchCompare = Compare
