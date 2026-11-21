-- /cine debug previewmatch units [skip|stop]: the Preview Match test for the Unit
-- Frames page's preview (Tools/preview-match-plan.md, step 4). Do its
-- mock-ups look like the game's own player, target, focus, pet and target of
-- target frames (the target's and the focus's)?
-- One run, steps on screen, no time limit, CineMode off for the run, never
-- opens Settings: it makes the page's preview itself (ns.MakeUnitStylePreview)
-- in a strip at the screen's left.
--   1 in your look as it is (nothing changed), two goals, any order, each
--     kept once met (or "/cine debug previewmatch units skip"):
--     FRAMES: a target, not yourself (on Forever your own target frame's
--       places are secret, 2026-11-20), a focus, your pet out, the target
--       and the focus each targeting someone (pull the focused mob: fighting
--       is fine): the game's frames and the preview's read then, a shot;
--     BUFFS: a target with a buff, out of a fight (a buff's place is secret
--       in one on Forever): where the game puts it measured;
--   2 the game's look (only when your page was on), once you're out of any
--     fight: the same, with what's still up;
--   3 every built-in theme on the real frames, out of a fight, one after
--     another (a player as target and focus, your pet): each read, compared
--     and shot; your theme put back ("units nothemes" goes without);
--   then your settings back (at the next login too if a reload cuts it short).
-- Read, per frame: its parts (frame art, portrait, health and power bars,
-- name, level), each placed and sized in widths of its health bar, the bars'
-- fill art and color, the texts' font, size, justify and color. Each pair
-- compared part by part, one line per difference, scored. Also the game
-- frame's whole tree of shown art (TREE lines): what a copy of it needs.
-- Saved into CinematicDB.previewMatch["<client>-units"]; /reload, "check log";
-- python Tools/preview-match/build.py makes the side-by-side page. Dev copy.
local _, ns = ...

local MAX_LINES, TREE_LINES = 4000, 120 -- (4000: the themes step, 16 looks, 2026-11-21)
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
-- (power2: the player frame's third bar, under a class resource: retail's Elemental mana.)
-- (totHealth, aura1, levelBack: where its target of target, first buff and
-- level circle sit, user 2026-11-20 "dont guess any more": checked in each look.)
local ROLES = { "art", "portrait", "health", "power", "power2", "name", "level", "levelBack", "aura1", "totHealth" }
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
	-- (The art shown: the player's taller class resource one on retail, 2026-11-20.)
	for _, key in ipairs({ "FrameTexture", "AlternatePowerFrameTexture", "VehicleFrameTexture" }) do
		local texture = holder[key]
		if type(texture) == "table" and texture.IsVisible and texture:IsVisible() then
			parts.art = texture
			break
		end
	end
	parts.art = parts.art or holder.FrameTexture or frame.FrameTexture
		or (frame.GetName and frame:GetName() and (_G[frame:GetName() .. "Texture"] or _G[frame:GetName() .. "TextureFrameTexture"]))
	if id == "PLAYER" then
		local content = frame.PlayerFrameContent
		local main = type(content) == "table" and content.PlayerFrameContentMain
		local area = type(main) == "table" and main.AlternatePowerBarArea
		parts.power2 = (type(area) == "table" and area.AlternatePowerBar) or _G.AlternatePowerBar
	end
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
	-- (Its level circle, first buff and target of target's health bar.)
	local content = frame.PlayerFrameContent or frame.TargetFrameContent
	local main = type(content) == "table" and (content.PlayerFrameContentMain or content.TargetFrameContentMain)
	parts.levelBack = type(main) == "table" and main.LevelBackgroundCircle or nil
	-- (A skull in its place for a boss or a unit far over yours: the level then.)
	local context = type(content) == "table" and content.TargetFrameContentContextual
	local skull = (type(context) == "table" and context.HighLevelTexture) or (type(main) == "table" and main.HighLevelTexture)
	if type(skull) == "table" and skull.IsVisible and skull:IsVisible() and not (parts.level and parts.level:IsVisible()) then
		parts.level = skull
	end
	local tot = frame.totFrame or (frame.GetName and frame:GetName() and _G[frame:GetName() .. "ToT"])
	if type(tot) == "table" and tot.IsVisible and tot:IsVisible() then parts.totHealth = tot.HealthBar or tot.healthbar end
	local first, firstL, firstT
	local function Consider(button)
		if type(button) ~= "table" or not (button.IsVisible and button:IsVisible()) then return end
		local l, t = K.Num(K.Call(button, "GetLeft")), K.Num(K.Call(button, "GetTop"))
		if l and t and (not first or t > firstT + 1 or (math.abs(t - firstT) <= 1 and l < firstL)) then
			first, firstL, firstT = button, l, t
		end
	end
	local pools = frame.auraPools
	if type(pools) == "table" and type(pools.EnumerateActive) == "function" then
		local ok, each = pcall(pools.EnumerateActive, pools)
		if ok and each then for button in each do Consider(button) end end
	end
	local name = frame.GetName and frame:GetName()
	if name then for i = 1, 4 do Consider(_G[name .. "Buff" .. i]) Consider(_G[name .. "Debuff" .. i]) end end
	-- (By what they are, whatever this client names them: UnitFrameCopy.lua's finder.)
	if not first and ns.UnitFirstAura then first = ns.UnitFirstAura(frame) end
	parts.aura1 = first
	return parts
end
-- Our mock-up's parts, as MakeUnitStylePreview builds them.
local function OurParts(unit)
	local parts = {}
	parts.health, parts.power, parts.name = unit.health, unit.power, unit.name
	parts.power2 = unit.copy and unit.copy.on and unit.copy.power2 or nil
	parts.portrait = (unit.portrait and unit.portrait:IsShown()) and unit.portrait or unit.face
	parts.level = (unit.skull and unit.skull:IsShown() and unit.skull)
		or (unit.badge and unit.badge:IsShown() and unit.badge.text:IsShown() and unit.badge.text) or nil
	-- (A theme's drawn badge wears the game's circle on its ring (MeasuredLevel): that
	-- read, not the badge's frame, which has no art: "nil ours" in 12 themes, 2026-11-21.)
	local badge = unit.badge
	local ring = badge and badge:IsShown() and badge.ring and badge.ring.gameCircle and badge.ring:IsShown() and badge.ring
	parts.levelBack = (unit.copy and unit.copy.on and unit.copy.circle) or ring
		or (badge and badge:IsShown() and (badge.ring:IsShown() or badge.back:IsShown()) and badge) or nil
	parts.aura1 = unit.auras and unit.auras[1]
	-- (Its target of target: the preview's hung off it, TOT under the target, FOCUSTOT under the focus.)
	local peers = unit.peers or {}
	local tot = (unit.id == "TARGET" and peers.TOT) or (unit.id == "FOCUS" and peers.FOCUSTOT) or nil
	parts.totHealth = tot and tot:IsVisible() and tot.health or nil
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
		-- (aura1 by its own rule below: the game's buffs unreadable on Forever,
		-- ours counted EXTRA on the target frame of you, 2026-11-21.)
		elseif o and not g and role == "totHealth" then
			-- (Its target of target gone (the mob dead by the game's read, 2026-11-21): the unit's state.)
			findings.notes = findings.notes or {}
			table.insert(findings.notes, "target of target not compared: none up on the unit read")
		elseif o and not g and role ~= "aura1" then
			Say(("EXTRA %s (%s %s) shows ours, not in game"):format(role, tostring(o.kind), tostring(o.art or o.font or "")))
		elseif role == "aura1" and (g == nil) ~= (o == nil) then
			-- (A buff on one and none on the other: the unit's state then, not the look.)
			findings.notes = findings.notes or {}
			table.insert(findings.notes, g and "a buff on the unit read, none in ours" or "no buff on the unit read: its row not compared")
		elseif g and o and role == "level" and g.kind ~= o.kind then
			-- (A skull on one, a number on the other: the unit's level, not the look's.)
			findings.notes = findings.notes or {}
			table.insert(findings.notes, ("level a %s in game, a %s ours: the unit's level"):format(
				g.kind == "FontString" and "number" or "skull", o.kind == "FontString" and "number" or "skull"))
		elseif g and o then
			findings.checks = findings.checks + (g.kind == "FontString" and 5 or 4)
			-- (The face is the unit's own: never the same picture.)
			-- (A class power's own art (Maelstrom, retail 2026-11-20) is the spec's: the
			-- sample's bar is mana's. Noted, not counted.)
			-- (So is another unit's power bar art: a warrior's rage, retail 2026-11-20.)
			local classPower = role == "power" and type(g.art) == "string"
				and (not g.art:find("UnitFrame", 1, true) or (id ~= "PLAYER" and id ~= "PET"))
			if classPower and g.art ~= o.art then
				findings.notes = findings.notes or {}
				table.insert(findings.notes, ("power bar art %s in game is its class power's"):format(g.art))
			end
			if role ~= "portrait" and not classPower and g.art and g.art ~= o.art then
				Say(("ART %s: %s in game, %s ours"):format(role, tostring(g.art), tostring(o.art)))
			end
			-- (Another's level is colored by how hard it is for you: the unit's, not the look's.)
			-- (And another's power bar's color is its power's: our sample warrior's rage
			-- against a mana user, 2026-11-20. Yours and your pet's are compared.)
			local byUnit = (role == "level" and id ~= "PLAYER") or (role == "power" and id ~= "PLAYER" and id ~= "PET")
			-- (A health bar colored by class or by how much health is left: the
			-- unit's, our sample's class and health against yours, 2026-11-21.)
			if role == "health" and o.colorBy and K.ColorOff(g.color, o.color) then
				byUnit = true
				findings.notes = findings.notes or {}
				table.insert(findings.notes, ("health colored by %s: the unit's, not the look's"):format(o.colorBy))
			end
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
			-- (Its other parts: the buffs row, the boss dragon. UnitFrameParts.lua.)
			for _, aura in ipairs(unit.auras or {}) do parts[#parts + 1] = aura end
			if unit.dragon then parts[#parts + 1] = unit.dragon end
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
	-- (A frame's buffs on another frame, the one hung off it too: a theme's
	-- target of target lay under the target's buffs, 2026-11-20.)
	for key, unit in pairs(holder.units or {}) do
		for _, aura in ipairs(unit.auras or {}) do
			local box = aura:IsVisible() and Rect(aura)
			if box then
				for other, otherBox in pairs(boxes) do
					if other ~= key then
						local across = math.min(box[2], otherBox[2]) - math.max(box[1], otherBox[1])
						local down = math.min(box[3], otherBox[3]) - math.max(box[4], otherBox[4])
						if across > 1 and down > 1 then
							problems[#problems + 1] = ("OVERLAP %s's buffs on %s"):format(key, other)
						end
					end
				end
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
	-- (Your theme, as the themes step found it: never in a fight, the game holds
	-- the frames still then. Kept for the next try.)
	if kept.theme then
		if InCombatLockdown() or not ns.RestoreStyleSnapshot then return false end
		pcall(ns.RestoreStyleSnapshot, kept.theme)
	end
	db.ufStyle = kept.ufStyle
	CinematicDB.previewMatchUnitsKept = nil
	if ns.RefreshUnitStyle then pcall(ns.RefreshUnitStyle) end
	return true
end
local restore = CreateFrame("Frame")
restore:RegisterEvent("PLAYER_LOGIN")
restore:SetScript("OnEvent", function()
	C_Timer.After(1.2, function()
		if PutBack() then ns.Print("preview match: your Unit Frames Style setting and theme put back (a reload cut the test short).") end
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

local function Keep(key, read, stamp, quiet)
	read.shot = stamp
	run.reads[key] = read
	local names = {}
	for role in pairs(read.parts) do names[#names + 1] = role end
	table.sort(names)
	Log(("%s: %s, shows %s"):format(key, read.unread or "read", table.concat(names, ", ")))
	-- (Quiet: the themes step, 17 looks: their differences say it in PAIR lines.)
	if quiet then return end
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

local function ReadPhase(phase, treeToo, done, quiet)
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
	for _, key in ipairs(quiet and {} or { "PLAYER", "PARTY" }) do
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
	-- (Read at once, the screenshot a moment later: a masked texture shows a
	-- frame or more after it's set up (shot at once, every face and bar fill
	-- of the preview was blank till 2026-11-20). Read with the shot, the focus's
	-- target had gone in that half second, 2026-11-21: not read.)
	local keys = {}
	local function Kept(key, read)
		Keep(key, read, nil, quiet)
		keys[#keys + 1] = key
	end
	do
		-- (The target's target of target while it's hidden: its place readable?
		-- Then it could be worked out for every look, as the buffs are.)
		local tot = _G.TargetFrameToT
		if tot and not run.totProbed and not K.Plain(K.Call(tot, "IsShown")) then
			run.totProbed = true
			local l, b, w, h = K.Call(tot, "GetRect")
			local function V(v) return issecretvalue and issecretvalue(v) and "secret" or tostring(K.Round(K.Num(v), 1)) end
			Log(("TOTPROBE hidden target of target: rect %s,%s,%s,%s; points %s; point 1 %s"):format(V(l), V(b), V(w), V(h),
				V(K.Call(tot, "GetNumPoints")), tostring((K.Call(tot, "GetPoint", 1)))))
		end
		for _, id in ipairs(IDS) do
			local frame = GameFrame(id)
			local unit = preview.units and preview.units[id]
			local gameParts = frame and GameParts(frame, id)
			local health = gameParts and gameParts.health
			if frame and K.Plain(K.Call(frame, "IsVisible")) and health and not K.Showing(health) then
				-- (Faded out: a HUD rule of yours hides it now, retail 2026-11-20.)
				Log(("%s: shown but faded out (alpha %s): a HUD rule hides it now, not compared"):format(id,
					tostring(K.Round(K.Num(K.Call(frame, "GetEffectiveAlpha")), 2))))
			elseif frame and K.Plain(K.Call(frame, "IsVisible")) and UnitExists(UNITS[id]) and unit then
				Kept(phase .. ":game:" .. id, ReadFrame(gameParts, "game:" .. id))
				-- (How its name was read for the copy: its place, its anchor, or why neither.)
				local recipe = ns.UnitFrameRecipe and ns.UnitFrameRecipe(unit.id)
				local entry = recipe and recipe.name
				local why = gameParts.name and ns.UnitFrameTextWhy and ns.UnitFrameTextWhy[gameParts.name]
				if not quiet then
					Log(("  recipe %s name: %s%s"):format(id, entry == nil and "none" or entry.hidden and "hidden"
						or entry.anchor and ("on its anchor " .. tostring(entry.anchor.point) .. ", " .. tostring(entry.justify))
						or entry.onBar and ("its side only, on the health bar's top edge, " .. tostring(entry.justify))
						or ("placed, " .. tostring(entry.justify)), why and (" (" .. why .. ")") or ""))
				end
				local ours = ReadFrame(OurParts(unit), "ours:" .. id)
				local mode = ns.StyleOn and ns.StyleOn("ufStyle") and ns.StyleLook and ns.StyleLook("ufStyle").ufHealthColor
				if ours.parts.health and (mode == "class" or mode == "health") then ours.parts.health.colorBy = mode end
				Kept(phase .. ":ours:" .. id, ours)
				Log(("  ours %s: %s"):format(id, unit.copy and unit.copy.on and "the copy" or ("drawn (" .. tostring(unit.copyWhy) .. ")")))
				if treeToo then Tree(id, frame) end
			else
				if not quiet then Log(("%s: not up (%s), not read"):format(id, frame and "no " .. UNITS[id] or "no frame")) end
			end
		end
	end
	C_Timer.After(DRAWN, function()
		if not run then return end
		local stamp = Shot(phase)
		for _, key in ipairs(keys) do if run.reads[key] then run.reads[key].shot = stamp end end
		-- (After the shot is saved, a moment on: carried on at once, the run's end
		-- put CineMode back on in the same moment and the shot of your look had no
		-- UI in it, 2026-11-20.)
		if done then C_Timer.After(DRAWN, function() if run then done() end end) end
	end)
end

-- (A theme's name in the player's language, by its key.)
local function ThemeName(key)
	local theme = ns.StyleThemeByKey and ns.StyleThemeByKey(key)
	local ok, name = pcall(function() return theme and ns.StyleThemeName and ns.StyleThemeName(theme) end)
	return ok and type(name) == "string" and name or tostring(key)
end

local function Finish()
	local store = Store()
	store.reads, store.shots, store.pairs = run.reads, run.shots, {}
	local summary = {}
	store.layout = run.layout
	for phase, problems in pairs(run.layout or {}) do
		summary[#summary + 1] = ("layout (%s) %s"):format(phase, #problems == 0 and "clean" or (#problems .. " problems"))
	end
	local phases = { "game", "yours" }
	for _, key in ipairs(run.themes or {}) do phases[#phases + 1] = "theme:" .. key end
	for _, phase in ipairs(phases) do
		for _, id in ipairs(IDS) do
			local real, ours = run.reads[phase .. ":game:" .. id], run.reads[phase .. ":ours:" .. id]
			if real and ours then
				local theme = phase:match("^theme:(.+)$")
				local name = NAMES[id] .. (phase == "yours" and " (your style)"
					or theme and (" (theme " .. ThemeName(theme) .. ")") or "")
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
	-- (What each look has measured for the preview to place its parts by, and
	-- what's still not: one line per frame.)
	local client = ns.isRetail and "retail" or "classic"
	local hangs = ns.db and ns.db.unitFrameHangs and ns.db.unitFrameHangs[client] or {}
	for look, frames in pairs(hangs) do
		for id, parts in pairs(frames) do
			local names = {}
			for part in pairs(parts) do names[#names + 1] = part end
			table.sort(names)
			Log(("HANGS %s look, %s: %s"):format(look, id, table.concat(names, ", ")))
		end
	end
	Log(("BUFFS %s"):format(tostring(run.auraDone)))
	run.events:UnregisterAllEvents()
	-- (Your look back on out of a fight only: in one the game holds the frames still.)
	if InCombatLockdown() then
		local later = CreateFrame("Frame")
		later:RegisterEvent("PLAYER_REGEN_ENABLED")
		later:SetScript("OnEvent", function(self)
			self:UnregisterAllEvents()
			PutBack()
		end)
	else
		PutBack()
	end
	K.SetCine(run.cineWasOn)
	if strip then strip:Hide() end
	local buffs = (run.auraDone == "skipped" and " Buffs skipped, not measured.")
		or (run.auraDone == "unreadable" and " Buffs: their place unreadable, probed.") or ""
	run = nil
	ns.TestPrompt(("Preview match (unit frames) DONE: %d frames compared.%s /reload, then tell Claude 'check log'."):format(#summary, buffs), 30)
	ns.Print("preview match: " .. (#summary > 0 and table.concat(summary, ", ") or "nothing read"))
end

-- Fights: the frames are read fine in one (their places aren't secret), but
-- a look can't be put on or taken off them then (the game holds unit frames
-- still), and a buff's place is secret in one on Forever (2026-11-21). A
-- target of target, though, only shows in one: the mob you pulled. So step 1
-- has two goals, met in any order, each kept once met:
--   FRAMES: every frame compared up at once (a fight's fine): the look that's
--     on (yours, never changed at the start) read right then;
--   BUFFS: where the game puts the target's first buff, measured in that look,
--     out of a fight: any target with one (a player near you), before or after.
-- Then the other look (the game's) once you're out of any fight, with what's
-- still up: it scored 100 on every frame by 2026-11-20. Before 2026-11-21 the
-- game's look went on first and yours was read after the fight, its mob dead
-- and its frames gone: what yours needed measured never was.
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
	ns.TestPrompt(("Preview match (unit frames): in a fight. %s: finish it, then stand still."):format(why), 600)
	return false
end

-- What's measured off the live frames in the look on now (UnitFrameCopy.lua's
-- ns.UnitHangs, which the preview places its parts by): each part logged once.
local function Measure()
	if not (ns.UnitHangs and ns.UnitLookKey) then return end
	run.measured = run.measured or {}
	for _, id in ipairs({ "PLAYER", "TARGET", "FOCUS" }) do
		local look = ns.UnitLookKey(id)
		local ok, hangs = pcall(ns.UnitHangs, id, look)
		if not ok then
			if not run.measured["error " .. id] then
				run.measured["error " .. id] = true
				Log(("MEASURE %s errored: %s"):format(id, tostring(hangs)))
			end
		elseif type(hangs) == "table" then
			for part, spot in pairs(hangs) do
				local key = look .. " " .. id .. " " .. part
				if not run.measured[key] then
					run.measured[key] = true
					if type(spot) == "table" then
						Log(("MEASURED %s look, %s %s: %s,%s%s"):format(look, id, part, tostring(spot.x), tostring(spot.y or spot.h),
							spot.workedOut and " (worked out)" or ""))
					else
						Log(("MEASURED %s look, %s %s: %s"):format(look, id, part, tostring(spot)))
					end
				end
			end
		end
	end
end
local function AuraKnown()
	if not (ns.UnitHangs and ns.UnitLookKey) then return true end
	local ok, hangs = pcall(ns.UnitHangs, "TARGET", ns.UnitLookKey("TARGET"))
	return ok and type(hangs) == "table" and hangs.aura ~= nil, ok and type(hangs) == "table" and hangs.aura
end
-- (The game says your target has an aura: out of a fight only, read safely.)
local function TargetHasAura()
	local ok, has = pcall(function()
		local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
		if get then return get("target", 1, "HELPFUL") ~= nil or get("target", 1, "HARMFUL") ~= nil end
		return (UnitBuff and UnitBuff("target", 1) ~= nil) or (UnitDebuff and UnitDebuff("target", 1) ~= nil)
	end)
	return ok and has == true
end
-- (Your target has an aura by the game, but no buff button's place was read
-- (Forever, 2026-11-21: the buffs sit in TargetFrameContentContextual.Auras,
-- whose size read as nothing, and the scan found none). Every call that could
-- place them, on that container and everything in it, logged as a value,
-- "secret" or the error: what's readable, to measure by. Also any small
-- square frame on screen under the target frame, whoever's child it is.)
local function ProbeAuras()
	local lines = 0
	local function Say(text)
		if lines >= 160 then return end
		lines = lines + 1
		Log("AURAPROBE " .. text)
	end
	local function Val(v)
		if issecretvalue and issecretvalue(v) then return "secret" end
		if type(v) == "number" then return tostring(K.Round(v, 2)) end
		if type(v) == "table" then
			local ok, name = pcall(function() return v.GetName and v:GetName() end)
			return "<" .. tostring(ok and name or "frame") .. ">"
		end
		return tostring(v)
	end
	local function Try(node, method, ...)
		if type(node) ~= "table" or type(node[method]) ~= "function" then return "none" end
		local out = { pcall(node[method], node, ...) }
		if not out[1] then return "ERR " .. tostring(out[2]):sub(1, 80) end
		local parts = {}
		for i = 2, #out do parts[#parts + 1] = Val(out[i]) end
		if #out == 1 then return "-" end
		return table.concat(parts, ",")
	end
	local function Describe(node, path)
		Say(("%s: %s forbidden %s shown %s visible %s size %s rect %s scale %s alpha %s"):format(path,
			Try(node, "GetObjectType"), Try(node, "IsForbidden"), Try(node, "IsShown"), Try(node, "IsVisible"),
			Try(node, "GetSize"), Try(node, "GetRect"), Try(node, "GetEffectiveScale"), Try(node, "GetAlpha")))
		-- (Its anchors tried whatever their count says: a secret count skipped
		-- them all, 2026-11-21.)
		Say(("%s points %s: 1 %s | 2 %s"):format(path, Try(node, "GetNumPoints"), Try(node, "GetPoint", 1), Try(node, "GetPoint", 2)))
		local keys = {}
		for key, value in pairs(node) do
			if type(key) == "string" and type(value) == "table" and #keys < 12 then keys[#keys + 1] = key end
		end
		if #keys > 0 then Say(path .. " keys: " .. table.concat(keys, " ")) end
		local okR, regions = pcall(function() return { node:GetRegions() } end)
		Say(("%s: %s regions"):format(path, okR and tostring(#regions) or ("ERR " .. tostring(regions):sub(1, 80))))
		for i, region in ipairs(okR and regions or {}) do
			if i > 6 then break end
			Say(("%s region %d: %s file %s atlas %s size %s shown %s"):format(path, i, Try(region, "GetObjectType"),
				Try(region, "GetTexture"), Try(region, "GetAtlas"), Try(region, "GetSize"), Try(region, "IsShown")))
		end
	end
	local function Walk(node, path, depth)
		Describe(node, path)
		if depth >= 3 then return end
		local okC, children = pcall(function() return { node:GetChildren() } end)
		if not okC then
			Say(path .. " children: ERR " .. tostring(children):sub(1, 80))
			return
		end
		Say(("%s: %d children"):format(path, #children))
		for i, child in ipairs(children) do
			if i > 8 then break end
			local key
			for k, v in pairs(node) do if v == child and type(k) == "string" then key = k break end end
			Walk(child, path .. "." .. tostring(key or i), depth + 1)
		end
	end
	local frame = _G.TargetFrame
	if not frame then
		Say("no TargetFrame")
		return
	end
	-- (What the game says the target has.)
	local helpful, harmful = 0, 0
	local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
	for i = 1, 40 do
		local okH, h = pcall(function() return get and get("target", i, "HELPFUL") ~= nil end)
		local okD, d = pcall(function() return get and get("target", i, "HARMFUL") ~= nil end)
		if okH and h then helpful = helpful + 1 end
		if okD and d then harmful = harmful + 1 end
	end
	Say(("the game: target %s, %d buffs, %d debuffs; issecretvalue %s; in a fight %s"):format(
		tostring(UnitName("target")), helpful, harmful, tostring(issecretvalue ~= nil), tostring(InCombatLockdown())))
	Describe(frame, "TargetFrame")
	for _, key in ipairs({ "auraPools", "buffPool", "debuffPool", "Auras", "auraFrames", "buffFrames" }) do
		if frame[key] ~= nil then Say(("TargetFrame.%s is a %s"):format(key, type(frame[key]))) end
	end
	local content = frame.TargetFrameContent
	local context = type(content) == "table" and content.TargetFrameContentContextual
	local auras = type(context) == "table" and context.Auras
	if type(auras) == "table" then
		Walk(auras, "Auras", 0)
	else
		Say("no TargetFrameContent.TargetFrameContentContextual.Auras")
	end
	for i = 1, 3 do
		for _, kind in ipairs({ "Buff", "Debuff" }) do
			local named = _G["TargetFrame" .. kind .. i]
			if named then Describe(named, "TargetFrame" .. kind .. i) end
		end
	end
	-- (Any small square frame shown under the target frame on screen.)
	local fl, fb, fw = K.Num(K.Call(frame, "GetLeft")), K.Num(K.Call(frame, "GetBottom")), K.Num(K.Call(frame, "GetWidth"))
	local found = 0
	if fl and fb and fw and EnumerateFrames then
		local okE = pcall(function()
			local f, seen = EnumerateFrames(), 0
			-- (Bounded: a frame list that never ends (the offline stand-in's) can't hang it.)
			while f and found < 8 and seen < 20000 do
				seen = seen + 1
				local w, h = K.Num(K.Call(f, "GetWidth")), K.Num(K.Call(f, "GetHeight"))
				local l, t = K.Num(K.Call(f, "GetLeft")), K.Num(K.Call(f, "GetTop"))
				if w and h and l and t and w >= 10 and w <= 40 and math.abs(w - h) <= 2 and K.Plain(K.Call(f, "IsVisible"))
					and l >= fl - 20 and l <= fl + fw + 20 and t <= fb + 40 and t >= fb - 120 then
					found = found + 1
					local parent = K.Call(f, "GetParent")
					Say(("on screen under it: %s parent %s at %s,%s size %sx%s"):format(Val(f), Val(parent), Val(l), Val(t), Val(w), Val(h)))
				end
				f = EnumerateFrames(f)
			end
		end)
		if not okE then Say("frame scan errored") end
	end
	Say(("frames found on screen under it: %d"):format(found))
end

-- Step 3: every theme on the real frames, out of a fight, one after another:
-- each one's game frames and the preview's read and compared, one shot each.
-- Needs a target (not you), a focus and your pet (a player near you is fine
-- for both: no fight). Their targets of target only if they're up. Your
-- theme back after (at the next login too, CinematicDB.previewMatchUnitsKept).
local Themes
local function ThemeMissing()
	local list = {}
	if not UnitExists("target") or UnitIsUnit("target", "player") then
		list[#list + 1] = "a TARGET not yourself (a player near you)"
	end
	if not UnitExists("focus") or UnitIsUnit("focus", "player") then list[#list + 1] = "a FOCUS (/focus on your target)" end
	if not UnitExists("pet") then list[#list + 1] = "your PET out" end
	return list
end
local function ThemesDone()
	local kept = CinematicDB.previewMatchUnitsKept
	if kept and kept.theme and ns.RestoreStyleSnapshot then
		pcall(ns.RestoreStyleSnapshot, kept.theme)
		kept.theme = nil
		Log("themes: your theme put back")
	end
	if ns.RefreshUnitStyle then pcall(ns.RefreshUnitStyle) end
	C_Timer.After(SETTLE, function() if run then Finish() end end)
end
Themes = function()
	if not run then return end
	run.step = 3
	if run.skipThemes then
		Log(("themes: skipped at %d of %d"):format(run.themeAt or 1, #run.themes))
		ThemesDone()
		return
	end
	if not WhenCalm(Themes, "the themes go on") then return end
	local missing = ThemeMissing()
	if #missing > 0 then
		local text = ("Preview match (unit frames) 3/3, themes: out of a fight, waiting for %s. Or type /cine debug previewmatch units skip")
			:format(table.concat(missing, ", "))
		if text ~= run.themePrompted then
			run.themePrompted = text
			ns.TestPrompt(text, 600)
			Log("themes: waiting for " .. table.concat(missing, ", "))
		end
		local mine = run
		C_Timer.After(1, function() if run == mine and run.step == 3 then Themes() end end)
		return
	end
	run.themePrompted = nil
	local at = run.themeAt or 1
	local key = run.themes[at]
	if not key then
		ThemesDone()
		return
	end
	ns.TestPrompt(("Preview match (unit frames) 3/3, themes: hands off, %d of %d: %s."):format(at, #run.themes, ThemeName(key)), 3)
	local db = K.DB()
	db.ufStyle = true
	local ok = ns.ApplyStyleTheme and ns.ApplyStyleTheme(key, true)
	if not ok then
		Log(("themes: %s not put on (%s)"):format(key, tostring(ok)))
		run.themeAt = at + 1
		C_Timer.After(0.2, Themes)
		return
	end
	if ns.RefreshUnitStyle then pcall(ns.RefreshUnitStyle) end
	C_Timer.After(SETTLE, function()
		if not run then return end
		-- (A fight begun as it went on: this one again after it.)
		if not WhenCalm(Themes, "this theme goes on again") then return end
		Log(("themes: %s on, look %s"):format(key, tostring(ns.UnitLookKey and ns.UnitLookKey("TARGET"))))
		Measure()
		ReadPhase("theme:" .. key, false, function()
			run.themeAt = at + 1
			Themes()
		end, true)
	end)
end
local function AfterGame()
	if run and run.themes and #run.themes > 0 then Themes() else Finish() end
end

-- Step 2: the game's look, out of a fight, with what's up then.
local Second
Second = function()
	if not run then return end
	run.step = 2 -- (step 1's checks stop: a fight's end brings this back)
	if not WhenCalm(Second, "the game's look goes on and is read") then return end
	ns.TestPrompt("Preview match (unit frames) 2/3: hands off, reading the game's look.", 3)
	K.DB().ufStyle = false
	if ns.RefreshUnitStyle then pcall(ns.RefreshUnitStyle) end
	C_Timer.After(SETTLE, function()
		if not run then return end
		-- (A fight begun as it went on: dressed partly. Again after that one.)
		if not WhenCalm(Second, "the game's look goes on again and is read") then return end
		Measure()
		ReadPhase("game", true, AfterGame)
	end)
end

-- Step 1's FRAMES: a target not you (on Forever your own target frame's
-- places are secret), a focus, your pet, the target's and the focus's targets.
Missing = function()
	local list = {}
	if not UnitExists("target") or UnitIsUnit("target", "player") then
		list[#list + 1] = UnitExists("target") and "a TARGET not yourself" or "a TARGET (a mob with mana is best)"
	end
	if not UnitExists("focus") then list[#list + 1] = "a FOCUS (/focus on your target)" end
	if not UnitExists("pet") then list[#list + 1] = "your PET out (summoning it in the fight is fine)" end
	-- (Their targets of target: a target and a focus that are targeting someone.
	-- A fight's fine: pull the mob you've focused, it targets you or your pet.)
	if not UnitExists("targettarget") then list[#list + 1] = "your target TARGETING someone (pull it: fighting is fine)" end
	if not UnitExists("focustarget") then list[#list + 1] = "your focus TARGETING someone" end
	return list
end
local function Prompt(frames)
	local parts = {}
	if not run.framesRead then parts[#parts + 1] = "FRAMES: " .. table.concat(frames, ", ") end
	if not run.auraDone then
		parts[#parts + 1] = InCombatLockdown()
			and "BUFFS: after this fight, target anyone but you with a buff (a player near you): their place can't be read in a fight"
			or "BUFFS: out of a fight, target anyone but you with a buff on their frame (a player near you)"
	end
	local text = ("Preview match (unit frames) 1/3: waiting for %s. Each is kept once met. Or type /cine debug previewmatch units skip")
		:format(table.concat(parts, " | "))
	if text ~= run.prompted then
		run.prompted = text
		ns.TestPrompt(text, 600)
		Log("waiting for: " .. table.concat(parts, " | "))
	end
end
Ready = function()
	if not run or run.step ~= 1 then return end
	Measure()
	if run.framesRead == "reading" then return end
	local frames = Missing()
	if not run.framesRead and (#frames == 0 or run.skipFrames) then
		if #frames > 0 then Log("skipped waiting for: " .. table.concat(frames, ", ")) end
		run.framesRead = "reading"
		ns.TestPrompt("Preview match (unit frames) 1/3: hands off, reading your look.", 3)
		ReadPhase(run.first, run.first == "game", function()
			run.framesRead = true
			run.prompted = nil
			Ready()
		end)
		return
	end
	if not run.auraDone then
		local known, spot = AuraKnown()
		if known then
			run.auraDone = spot and spot.workedOut and "worked out" or "measured"
			Log(spot and spot.workedOut
				and ("BUFFS: the target's first buff worked out in this look (its place secret here): %s,%s%s"):format(
					tostring(spot.x), tostring(spot.y), spot.up and ", Buffs On Top" or "")
				or "BUFFS: the target's first buff measured in this look")
		elseif run.skipAura then
			run.auraDone = "skipped"
			Log("BUFFS: skipped, not measured")
		elseif not InCombatLockdown() and UnitExists("target") and not UnitIsUnit("target", "player") and TargetHasAura() then
			-- (3 checks on, out of a fight, the game saying it's there: its place is
			-- unreadable on this client. Probed, logged, and not waited for: a
			-- wait for it never ended, 2026-11-21.)
			run.auraSeen = (run.auraSeen or 0) + 1
			if run.auraSeen == 3 then
				pcall(ProbeAuras)
				run.auraDone = "unreadable"
				Log("BUFFS: your target has some, but this client doesn't say where: probed (AURAPROBE lines), not waited for")
			end
		end
	end
	if run.framesRead == true and run.auraDone then
		if run.first == "game" then
			Log("your Unit Frames Style page is off: your look is the game's, no second read")
			AfterGame()
		else
			Second()
		end
		return
	end
	Prompt(frames)
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
	-- (On its own: target anyone with a buff, out of a fight. A few seconds.)
	-- (It waits for that target: run at once, it probed no target at all, 2026-11-21.)
	if arg == "auras" then
		Store().lines = {}
		local token = {}
		ns.previewMatchAuraProbe = token
		-- (CineMode off for it: it hides the frames the shot is of. Back on after.)
		local cineWasOn = ns.IsCineModeOn and ns.IsCineModeOn() and true or false
		K.SetCine(false)
		local said
		local function Wait()
			if ns.previewMatchAuraProbe ~= token then return end
			local ready = not InCombatLockdown() and UnitExists("target") and not UnitIsUnit("target", "player")
				and TargetHasAura()
			if not ready then
				local text = InCombatLockdown() and "Buffs probe: waiting for the fight to end."
					or "Buffs probe: target anyone but you who has a buff (a player near you), out of a fight."
				if text ~= said then
					said = text
					ns.TestPrompt(text, 600)
				end
				C_Timer.After(0.5, Wait)
				return
			end
			-- (A moment on: its buff buttons are drawn after the target changes.)
			C_Timer.After(0.5, function()
				if ns.previewMatchAuraProbe ~= token then return end
				ns.previewMatchAuraProbe = nil
				pcall(ProbeAuras)
				-- (And a screenshot, the target frame's place in it logged in screen
				-- pixels from the top-left: its buff icons found in the picture if
				-- nothing above places them.)
				pcall(ns.TestPrompt, " ", 0.05)
				local frame = _G.TargetFrame
				local physW, physH = K.ScreenSize()
				local scale = K.Num(K.Call(frame, "GetEffectiveScale"))
				local l, b, w, h = K.Call(frame, "GetRect")
				l, b, w, h = K.Num(l), K.Num(b), K.Num(w), K.Num(h)
				local uiH = K.Num(K.Call(UIParent, "GetHeight"))
				local uiScale = K.Num(K.Call(UIParent, "GetEffectiveScale"))
				if l and scale and uiH and uiScale then
					local px = physH / (uiH * uiScale)
					Log(("AURAPROBE shot: screen %dx%d, target frame at %d,%d size %dx%d px (top-left)"):format(physW, physH,
						K.Round(l * scale * px, 0), K.Round(physH - (b + h) * scale * px, 0), K.Round(w * scale * px, 0),
						K.Round(h * scale * px, 0)))
				end
				C_Timer.After(0.3, function()
					local stamp = date("%m%d%y_%H%M%S")
					Screenshot()
					Log("AURAPROBE SHOT " .. stamp)
					C_Timer.After(1, function()
						K.SetCine(cineWasOn)
						ns.TestPrompt("Buffs probe DONE. /reload, then tell Claude 'check log'.", 15)
					end)
				end)
			end)
		end
		Wait()
		return
	end
	if arg == "skip" then
		-- (Goes without whatever step 1 still waits for.)
		if run and run.step == 1 then
			run.skipFrames, run.skipAura = true, true
			Ready()
		elseif run and run.step == 3 then
			run.skipThemes = true
			Themes()
		end
		return
	end
	if run then
		ns.Print("preview match: already running (/cine debug previewmatch units stop to stop it)")
		return
	end
	-- (Started out of a fight: the game's look goes on at its end, which a fight forbids.)
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
	-- (Your look first, as it is: nothing changed till step 2.)
	run.first = (db.ufStyle and ns.StyleOn and ns.StyleOn("ufStyle")) and "yours" or "game"
	CinematicDB.previewMatchUnitsKept = { ufStyle = db.ufStyle }
	-- (The themes, step 3: each built-in one but the game's. Your theme kept, as a
	-- pick's Undo keeps it, put back after.)
	run.themes = {}
	if arg ~= "nothemes" and ns.StyleThemeList and ns.ApplyStyleTheme and ns.StyleSnapshot then
		for _, theme in ipairs(ns.StyleThemeList()) do
			if theme.key ~= "game" then run.themes[#run.themes + 1] = theme.key end
		end
		CinematicDB.previewMatchUnitsKept.theme = ns.StyleSnapshot()
	end
	Log(("themes to read: %d (your theme %s, themes reach the frames: %s)"):format(#run.themes, tostring(db.styleTheme),
		tostring(db.styleThemeReachFrames ~= false)))
	local okTot, tot = pcall(GetCVar, "showTargetOfTarget")
	Log("the game's Target of Target setting (showTargetOfTarget): " .. tostring(okTot and tot))
	Log(("start: %s %s, screen %dx%d, UI scale %s; ufStyle=%s, Style on %s, theme layout %s, look %s; read first: %s"):format(
		store.client, store.build, physW, physH, tostring(store.uiScale), tostring(db.ufStyle),
		tostring(ns.StyleOn and ns.StyleOn("ufStyle")), tostring(ns.ThemeLayout and ns.ThemeLayout()),
		tostring(ns.UnitLookKey and ns.UnitLookKey("TARGET")), run.first))
	run.events = CreateFrame("Frame")
	run.events:SetScript("OnEvent", function() if run and run.step == 1 then Ready() end end)
	for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_PET", "UNIT_TARGET", "UNIT_AURA",
		"PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED" }) do
		pcall(run.events.RegisterEvent, run.events, event)
	end
	K.SetCine(false)
	MakePreview()
	strip:Show()
	preview:Refresh()
	-- (And once a second: an event comes before the game's frame shows what it
	-- says (its buff buttons drawn after UNIT_AURA), and no other may follow.)
	local mine = run
	local function Tick()
		if run ~= mine or run.step ~= 1 then return end
		Ready()
		C_Timer.After(1, Tick)
	end
	Ready()
	C_Timer.After(1, Tick)
end

-- (For the Shoulder Cam's stand-in target frame test, /cine debug shoulder
-- selfframe: Dev/ShoulderCamTest.lua reads the stand-in, which carries the
-- game's target frame part names, and the game's target frame of you, and
-- compares them. Keep these two names working, or tell that session.)
function ns.UnitMatchRead(frame, id) return ReadFrame(GameParts(frame, id), id) end
ns.UnitMatchCompare = Compare
