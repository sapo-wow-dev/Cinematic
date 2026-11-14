-- /cine debug redbar: one run looking for a player's report (retail?): "my
-- health bar, green on the game's texture, turns dark red when I take damage".
-- Two timed steps in the big test box (Frames.lua's ns.PadTestBox), each:
-- take damage (a fall, a mob), watch the bar.
--   1 yours: your settings as they are;
--   2 bare:  the Unit Frames and Personal Resource Display style pages off
--            for the step (put back after), to tell ours from the game's.
-- Every tenth of a second, on any change, the log gets the player frame's
-- and the personal resource display's health bar: value, the bar's color,
-- and every shown texture around it (the bar's container and its children,
-- the game's loss bar too) with its atlas or file, color, alpha and width.
-- Every call that recolors or retextures the bar is logged with who made it.
-- A screenshot at each step's first damage and a second after it, and a
-- verdict per step: was a big red seen, and on which texture. Into its own
-- saved list, CinematicDB.redBarLog. Dev copy only (CinematicDev.toc).
local _, ns = ...

local SETUP, STEP = 10, 30 -- seconds
local STEPS = {
	{ key = "yours", say = "%d/%d: YOUR SETTINGS. Take some damage now: jump off something high, or let a mob hit " ..
		"you. Watch your health bar. %d sec." },
	{ key = "bare", say = "%d/%d: Cinematic's unit frame and personal display STYLE now OFF. Take damage again " ..
		"the same way. Watch your health bar. %d sec." },
}

local run -- { at, step, notes, kept, last = { [label] = signature } }
local hooked = setmetatable({}, { __mode = "k" })

local function Say(text)
	local log = CinematicDB and CinematicDB.redBarLog
	if log then log[#log + 1] = ("%.2f %s"):format(run and GetTime() - run.at or 0, text) end
end

local function Secret(value)
	return issecretvalue and issecretvalue(value)
end

local function Num(value)
	if value == nil then return "nil" end
	if Secret(value) then return "secret" end
	if type(value) == "number" then return ("%.2f"):format(value) end
	return tostring(value)
end

local function Shot(what)
	ns.PadTestBoxHide()
	local ok, err = pcall(function() Screenshot() end)
	return ok and ("screenshot %s at %s"):format(what, date("%m%d%y_%H%M%S")) or ("screenshot failed: " .. tostring(err))
end

-- The bars to watch: label -> the health StatusBar.
local function Bars()
	local bars = {}
	local player = _G.PlayerFrame
	local health = player and (player.healthbar or player.HealthBar)
	if health then bars.player = health end
	local prd = _G.PersonalResourceDisplayFrame
	if prd and not (prd.IsForbidden and prd:IsForbidden()) then
		local holder = prd.HealthBarsContainer
		local bar = holder and holder.healthBar or prd.healthbar or prd.healthBar
		if bar then bars.prd = bar end
	end
	return bars
end

local function Key(region)
	local name = region.GetDebugName and region:GetDebugName() or region:GetName()
	if type(name) ~= "string" or name == "" then name = tostring(region) end
	return (name:gsub("^PlayerFrame%.PlayerFrameContent%.PlayerFrameContentMain%.", "PF.")
		:gsub("^PersonalResourceDisplayFrame%.", "PRD."))
end

-- A texture red enough to read as "dark red": r well over g and b.
local function IsRed(r, g, b)
	return type(r) == "number" and not Secret(r) and not Secret(g) and not Secret(b)
		and r > 0.35 and g < 0.3 and b < 0.3
end
local function RedAtlas(atlas)
	return type(atlas) == "string" and not Secret(atlas) and (atlas:lower():find("red") or atlas:lower():find("loss")
		or atlas:lower():find("damage")) and true or false
end

-- Every shown texture under frame (two levels of children), one line each.
local function Textures(frame, barWidth, lines, reds, depth)
	if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end
	local okShown, shown = pcall(frame.IsVisible, frame)
	if not (okShown and shown) then return end
	for _, region in ipairs({ frame:GetRegions() }) do
		if region.GetObjectType and region:GetObjectType() == "Texture" and region:IsVisible() then
			local r, g, b, a = region:GetVertexColor()
			local atlas = region.GetAtlas and region:GetAtlas()
			local file = region:GetTexture()
			local width = region:GetWidth()
			-- (Textures have no GetEffectiveAlpha on Forever: its own times its frame's.)
			local own, framed = region:GetAlpha(), frame:GetEffectiveAlpha()
			local alpha = (type(own) == "number" and not Secret(own) and type(framed) == "number" and not Secret(framed))
				and own * framed or own
			local wide = type(width) == "number" and not Secret(width) and type(barWidth) == "number"
				and not Secret(barWidth) and barWidth > 0 and width / barWidth or nil
			lines[#lines + 1] = ("%s [%s] c %s %s %s %s a %s w %s%s"):format(Key(region),
				tostring(atlas and not Secret(atlas) and atlas or (Secret(file) and "secret" or file)), Num(r), Num(g),
				Num(b), Num(a), Num(alpha), Num(wide), region.IsDesaturated and region:IsDesaturated() and " desat" or "")
			local seen = type(alpha) == "number" and not Secret(alpha) and alpha > 0.3
			if seen and (IsRed(r, g, b) or RedAtlas(atlas)) then
				reds[#reds + 1] = { key = Key(region), wide = wide, color = ("%s %s %s"):format(Num(r), Num(g), Num(b)),
					atlas = atlas and not Secret(atlas) and atlas or nil }
			end
		end
	end
	if depth < 2 then
		for _, child in ipairs({ frame:GetChildren() }) do Textures(child, barWidth, lines, reds, depth + 1) end
	end
end

local function Hook(label, bar)
	if hooked[bar] then return end
	hooked[bar] = true
	local function Who() return (debugstack(3, 2, 0) or ""):gsub("Interface[/\\]AddOns[/\\]", ""):gsub("\n", " < ") end
	hooksecurefunc(bar, "SetStatusBarColor", function(_, r, g, b)
		if run then Say(("  %s SetStatusBarColor %s %s %s by %s"):format(label, Num(r), Num(g), Num(b), Who())) end
	end)
	hooksecurefunc(bar, "SetStatusBarTexture", function(_, texture)
		if run then Say(("  %s SetStatusBarTexture %s by %s"):format(label, Num(texture), Who())) end
	end)
	local fill = bar:GetStatusBarTexture()
	if fill and fill.SetVertexColor then
		hooksecurefunc(fill, "SetVertexColor", function(_, r, g, b)
			if run then Say(("  %s fill SetVertexColor %s %s %s by %s"):format(label, Num(r), Num(g), Num(b), Who())) end
		end)
	end
end

local function Look(label, bar, note)
	Hook(label, bar)
	local lines, reds = {}, {}
	local holder = bar:GetParent()
	local barWidth = bar:GetWidth()
	Textures(holder or bar, barWidth, lines, reds, holder and 0 or 1)
	local value, high = bar:GetValue(), select(2, bar:GetMinMaxValues())
	local r, g, b = bar:GetStatusBarColor()
	local head = ("%s value %s of %s, bar color %s %s %s, shown %s"):format(label, Num(value), Num(high), Num(r), Num(g),
		Num(b), tostring(bar:IsVisible()))
	local signature = head .. "\n" .. table.concat(lines, "\n")
	if run.last[label] ~= signature then
		run.last[label] = signature
		Say(head)
		for _, line in ipairs(lines) do Say("    " .. line) end
	end
	if note then
		for _, red in ipairs(reds) do
			local wide = red.wide or 0
			local worst = note.reds[red.key]
			if not worst or wide > (worst.wide or 0) then note.reds[red.key] = red end
		end
	end
	-- (Damage taken: the value dropping, where it's readable.)
	if note and type(value) == "number" and not Secret(value) then
		if note.lastValue and value < note.lastValue - 0.5 then note.hitAt = note.hitAt or GetTime() end
		note.lastValue = value
	end
end

local function Settings(on)
	local db = ns.db
	if on then
		db.ufStyle, db.prdStyle = run.kept.ufStyle, run.kept.prdStyle
	else
		db.ufStyle, db.prdStyle = false, false
	end
	if ns.RefreshUnitStyle then pcall(ns.RefreshUnitStyle) end
	if ns.RefreshPersonalStyle then pcall(ns.RefreshPersonalStyle) end
end

local function State()
	return ("CineMode %s, combat %s, style on %s, ufStyle %s, prdStyle %s, %s"):format(tostring(ns.lastCinematic),
		tostring(InCombatLockdown()), tostring(ns.db.styleGeneral), tostring(ns.StyleOn("ufStyle")),
		tostring(ns.StyleOn("prdStyle")), ns.UnitStyleState and ns.UnitStyleState() or "")
end

local function Verdicts()
	local lines = {}
	for index, step in ipairs(STEPS) do
		local note = run.notes[step.key]
		local text
		if not note then
			text = "not run"
		else
			local big, strips = {}, {}
			for key, red in pairs(note.reds) do
				local what = ("%s (%s%s, %d%% wide)"):format(key, red.color, red.atlas and (" " .. red.atlas) or "",
					math.floor((red.wide or 0) * 100 + 0.5))
				if (red.wide or 0) >= 0.5 then big[#big + 1] = what else strips[#strips + 1] = what end
			end
			text = (#big > 0 and "BIG RED seen: " .. table.concat(big, "; ") or "no big red")
				.. (#strips > 0 and ("; red strips: " .. table.concat(strips, "; ")) or "")
				.. (note.hitAt and "" or "; NO DAMAGE seen (health didn't drop, or it was secret)")
		end
		lines[#lines + 1] = ("step %d %s: %s"):format(index, step.key, text)
	end
	return lines
end

local function Finish(done)
	if run.ticker then run.ticker:Cancel() end
	if run.bare then Settings(true) end
	for _, line in ipairs(Verdicts()) do
		Say("verdict " .. line)
		ns.Print(line)
	end
	run = nil
	ns.PadTestBox(done and "Test done. Your settings are back as they were." or "Test stopped.",
		"Say \"check log\" (/reload first)", 1, 0.82, 0)
	C_Timer.After(15, function() if not run then ns.PadTestBoxHide() end end)
end

local function Tick()
	local now = GetTime() - run.at
	local bars = Bars()
	if now < SETUP then
		ns.PadTestBox("Go somewhere you can take damage (a ledge to jump off, or a mob). Keep CineMode OFF so your " ..
			"health bar shows. Full health is best.", ("Starts in %d"):format(math.ceil(SETUP - now)), 1, 0.82, 0)
		if run.step ~= 0 then
			run.step = 0
			Say("--- setup --- " .. State())
		end
		for label, bar in pairs(bars) do Look(label, bar) end
		return
	end
	local index = math.floor((now - SETUP) / STEP) + 1
	if index > #STEPS then
		Finish(true)
		return
	end
	local step = STEPS[index]
	local into = now - SETUP - (index - 1) * STEP
	if index ~= run.step then
		run.step = index
		run.notes[step.key] = { reds = {} }
		if step.key == "bare" then
			run.bare = true
			Settings(false)
		end
		Say(("--- step %d: %s --- %s"):format(index, step.key, State()))
	end
	local note = run.notes[step.key]
	ns.PadTestBox(step.say:format(index, #STEPS, math.ceil(STEP - into)),
		("RECORDING: %d sec left"):format(math.ceil(STEP - into)), 0.3, 1, 0.3)
	for label, bar in pairs(bars) do Look(label, bar, note) end
	if note.hitAt and not note.shotHit and GetTime() - note.hitAt >= 0.2 then
		note.shotHit = true
		Say("  " .. Shot(("step %d %s HIT"):format(index, step.key)))
	elseif note.shotHit and not note.shotAfter and GetTime() - note.hitAt >= 1.5 then
		note.shotAfter = true
		Say("  " .. Shot(("step %d %s AFTER"):format(index, step.key)))
	elseif not note.hitAt and into >= (note.blindShots or 0) * 8 + 10 and (note.blindShots or 0) < 2 then
		-- (Health secret in a fight: no drop to see, so shots on a clock.)
		note.blindShots = (note.blindShots or 0) + 1
		Say("  " .. Shot(("step %d %s at %d sec"):format(index, step.key, math.floor(into))))
	end
end

-- Typed again while running: stops.
function ns.HealthRedTest()
	if run then
		Finish(false)
		return
	end
	CinematicDB.redBarLog = {}
	run = { at = GetTime(), step = -1, notes = {}, last = {},
		kept = { ufStyle = ns.db.ufStyle, prdStyle = ns.db.prdStyle } }
	Say(("start: %s (game %s), %s"):format(ns.isRetail and "retail" or "not retail",
		tostring((select(4, GetBuildInfo()))), State()))
	run.ticker = C_Timer.NewTicker(0.1, function()
		local ok, err = pcall(Tick)
		if not ok then
			Say("error: " .. tostring(err))
			if run then Finish(false) end
		end
	end)
	ns.Print(("red health bar test: %d sec, follow the box (type it again to stop)"):format(SETUP + #STEPS * STEP))
end
