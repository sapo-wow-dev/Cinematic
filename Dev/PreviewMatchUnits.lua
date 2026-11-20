-- /cine debug previewmatch units [stop]: the Preview Match test for the Unit
-- Frames page's preview (Tools/preview-match-plan.md, step 4). Do its
-- mock-ups look like the game's own player, target, focus and pet frames?
-- One run, steps on screen, no time limit, CineMode off for the run, never
-- opens Settings: it makes the page's preview itself (ns.MakeUnitStylePreview)
-- in a strip at the screen's left.
--   1 you have a target, not yourself (on Forever your own target frame's
--     places are secret, 2026-11-20), one with mana is best; a focus and
--     your pet out add those frames: read at once if you have one already;
--   2 the game's look: the test turns the Unit Frames Style page off, reads
--     the game's frames and the preview's mock-ups, shoots the screen;
--   3 your look (only when your page was on): the same with your settings;
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
local IDS = { "PLAYER", "TARGET", "FOCUS", "PET" }
local NAMES = { PLAYER = "Player frame", TARGET = "Target frame", FOCUS = "Focus frame", PET = "Pet frame" }
local UNITS = { PLAYER = "player", TARGET = "target", FOCUS = "focus", PET = "pet" }
local ROLES = { "art", "portrait", "health", "power", "name", "level" }
-- How far apart is "different": places and sizes in widths of the health bar,
-- a bar's shape (width over height) and a font's size as a part of its own.
local PLACE_OFF, SIZE_OFF, SHAPE_OFF, FONT_OFF = 0.08, 0.2, 0.25, 0.25

local K = ns.PreviewMatchKit
local run -- { step, phase, reads, shots, events, cineWasOn }

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
	local frame = _G[({ PLAYER = "PlayerFrame", TARGET = "TargetFrame", FOCUS = "FocusFrame", PET = "PetFrame" })[id]]
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
			local byUnit = role == "level" and id ~= "PLAYER"
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
local function ReadPhase(phase, treeToo)
	run.phase = phase
	preview:Refresh()
	local stamp = Shot(phase)
	for _, id in ipairs(IDS) do
		local frame = GameFrame(id)
		local unit = preview.units and preview.units[id]
		if frame and K.Plain(K.Call(frame, "IsVisible")) and UnitExists(UNITS[id]) and unit then
			Keep(phase .. ":game:" .. id, ReadFrame(GameParts(frame, id), "game:" .. id), stamp)
			Keep(phase .. ":ours:" .. id, ReadFrame(OurParts(unit), "ours:" .. id), stamp)
			if treeToo then Tree(id, frame) end
		else
			Log(("%s: not up (%s), not read"):format(id, frame and "no " .. UNITS[id] or "no frame"))
		end
	end
end

local function Finish()
	local store = Store()
	store.reads, store.shots, store.pairs = run.reads, run.shots, {}
	local summary = {}
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

local function Go()
	run.step = 2
	ns.TestPrompt("Preview match (unit frames): hands off, reading the game's look.", 3)
	local db = K.DB()
	db.ufStyle = false
	if ns.RefreshUnitStyle then pcall(ns.RefreshUnitStyle) end
	C_Timer.After(SETTLE, function()
		if not run then return end
		ReadPhase("game", true)
		local kept = CinematicDB.previewMatchUnitsKept
		if not (kept and kept.ufStyle) then
			Log("your Unit Frames Style page is off: your look is the game's, no second read")
			Finish()
			return
		end
		run.step = 3
		ns.TestPrompt("Preview match (unit frames): reading your look.", 3)
		db.ufStyle = true
		if ns.RefreshUnitStyle then pcall(ns.RefreshUnitStyle) end
		C_Timer.After(SETTLE, function()
			if not run then return end
			ReadPhase("yours", false)
			Finish()
		end)
	end)
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

function ns.PreviewMatchUnits(arg)
	if arg == "stop" then
		Stop()
		return
	end
	if run then
		ns.Print("preview match: already running (/cine debug previewmatch units stop to stop it)")
		return
	end
	if InCombatLockdown() then
		ns.Print("preview match: not in a fight. Try again after it.")
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
	Log(("start: %s %s, screen %dx%d, UI scale %s; ufStyle=%s, Style on %s, theme layout %s"):format(store.client,
		store.build, physW, physH, tostring(store.uiScale), tostring(db.ufStyle), tostring(ns.StyleOn and ns.StyleOn("ufStyle")),
		tostring(ns.ThemeLayout and ns.ThemeLayout())))
	run.events = CreateFrame("Frame")
	run.events:SetScript("OnEvent", function()
		if run and run.step == 1 and UnitExists("target") and not UnitIsUnit("target", "player") then
			run.events:UnregisterEvent("PLAYER_TARGET_CHANGED")
			C_Timer.After(0.5, function() if run then Go() end end)
		end
	end)
	K.SetCine(false)
	MakePreview()
	strip:Show()
	if UnitExists("target") and not UnitIsUnit("target", "player") then
		C_Timer.After(0.5, function() if run then Go() end end)
	else
		run.events:RegisterEvent("PLAYER_TARGET_CHANGED")
		if UnitExists("target") then Log("target is you: waiting for another (your own target frame's places are secret)") end
		ns.TestPrompt("Preview match (unit frames) 1/3: TARGET someone else, an NPC or player WITH MANA is best (not yourself). A focus and your pet out add those frames.", 600)
	end
end
