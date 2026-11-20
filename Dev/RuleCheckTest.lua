-- /cine debug rulecheck: one run that settles the engine rules (Tools/engine)
-- whose findings disagree or never said which client (2026-11-20). Run it on
-- each client. Steps on screen, each waiting as long as it takes (type the
-- command again to stop):
--   1 panel   on its own: a test panel lower left (text alpha, a zero-height
--             frame, Cyrillic after a font swap, the blank font), read back
--             and screenshotted
--   2 plate   stand where an enemy plate shows: every plate piece's
--             GetPoint/GetLeft (healthBar.bgTexture first)
--   3 camera  stand still: the test tilts and zooms the camera itself for
--             under a second, then SetView with blend style 1 and 0, zoom read
--             every 0.03 s and screenshots (view 4 is saved over, as the
--             Shoulder Cam map test does)
--   4 fight   fight an enemy: UNIT_COMBAT amounts and UNIT_AURA addedAuras,
--             secret or plain; then in the fight CheckInteractDistance,
--             SetUIVisibility(true) and SetCVar of a SoftTarget setting to
--             its own value, each watched for a blocked action; the plate walk
--             again
--   5 reload  out of the fight: ReloadUI() from addon code. Blocked = the run
--             ends here; reloaded = the next login logs it and ends the run.
-- A RESULT line per rule id at the end, and on screen. CineMode off for the
-- run and put back; enemy plates and blend style put back. Into
-- CinematicDB.ruleCheckLog. Dev copy only (CinematicDev.toc).
local ADDON_NAME, ns = ...

local BLANK = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Fonts\\Blank.ttf"
local CYRILLIC = "\208\159\209\128\208\184\208\178\208\181\209\130" -- "Privet" in Cyrillic
local VIEW_SLOT = 4
local HITS = 8 -- UNIT_COMBAT lines kept (and needed before the fight probes end)
local AURAS = 10 -- UNIT_AURA lines kept
local PLATE_LINES = 60
local SHOT_GAP = 1.15 -- seconds between screenshots (the game names them by the second)
local PLATES = ns.CVarSet("Rule check: enemy plates", "/cine debug rulecheck: enemy plates on for the run",
	{ values = { nameplateShowEnemies = "1" } })

local run -- { at, step, results, events, ticker, cineWas, hits, auras, blocked, probe, ... }

local function Client()
	if ns.isRetail then return "retail" end
	return ns.isClassicEra and "classic_era" or "forever"
end

local function Say(text)
	local log = CinematicDB and CinematicDB.ruleCheckLog
	if log then log[#log + 1] = ("%s %.2f %s"):format(date("%H:%M:%S"), run and GetTime() - run.at or 0, text) end
end

local function Secret(value) return ns.Check.Secret(value) end
local function Show(value)
	if Secret(value) then return "<secret>" end
	return tostring(value)
end

local function Result(id, text)
	if run then run.results[#run.results + 1] = id .. ": " .. text end
	Say("RESULT " .. id .. ": " .. text)
end

local function Prompt(text, sub)
	ns.PadTestBox(text, sub or "", 1, 0.82, 0)
end

local function Shot(what)
	if ns.PadTestBoxHide then ns.PadTestBoxHide() end
	local ok = pcall(function() Screenshot() end)
	Say(ok and ("  screenshot (%s) at %s"):format(what, date("%m%d%y_%H%M%S")) or "  screenshot failed: " .. what)
end

local function CineOn() return ns.IsCineModeOn and ns.IsCineModeOn() and true or false end
local function SetCine(on)
	if CineOn() ~= on and _G.Cinematic_ToggleCineMode then
		_G.Cinematic_ToggleCineMode()
		Say("  CineMode turned " .. (on and "ON" or "OFF") .. " by the test")
	end
end

-- fn() in a pcall, with every ADDON_ACTION_BLOCKED in the next second put
-- down to it; then done(ok, first return, blocked names).
local function Probe(label, fn, done)
	run.probe = { label = label, blocked = {} }
	local ok, a = pcall(fn)
	Say(("  probe %s: %s %s"):format(label, ok and "ran" or "error", ok and Show(a) or tostring(a)))
	C_Timer.After(1, function()
		if not run then return end
		local blocked = run.probe and run.probe.blocked or {}
		run.probe = nil
		Say(("  probe %s: blocked actions %s"):format(label, #blocked > 0 and table.concat(blocked, ", ") or "none"))
		done(ok, a, blocked)
	end)
end

-- Step 1: the panel ---------------------------------------------------------

local function Font(fs)
	local ok, file, size = pcall(fs.GetFont, fs)
	return ok and (tostring(file) .. " " .. tostring(size)) or "error"
end

local function Panel()
	local p = CreateFrame("Frame", nil, UIParent)
	p:SetSize(420, 260)
	p:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 40, 160)
	p:SetFrameStrata("DIALOG")
	local bg = p:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.85)
	run.panel = p
	local function Label(y, text, font)
		local fs = p:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
		fs:SetPoint("TOPLEFT", 12, y)
		fs:SetText(text)
		return fs
	end
	Label(-8, "Rule check panel (screenshot)", "GameFontNormal")

	-- Text color alpha vs SetAlpha: one value or two?
	local dim = Label(-34, "A: alpha 0.16 only")
	dim:SetTextColor(1, 1, 1, 0.16)
	local both = Label(-56, "B: alpha 0.16, then SetAlpha(1)")
	both:SetTextColor(1, 1, 1, 0.16)
	both:SetAlpha(1)
	local r, g, b, a = both:GetTextColor()
	Say(("  color alpha: A text alpha %s alpha %s; B text color %s,%s,%s,%s alpha %s, vertex alpha %s"):format(
		Show(select(4, dim:GetTextColor())), Show(dim:GetAlpha()), Show(r), Show(g), Show(b), Show(a),
		Show(both:GetAlpha()), Show(select(4, both:GetVertexColor()))))
	run.found.alphaB = a

	-- A frame with a width and no height: are its children drawn?
	local zero = CreateFrame("Frame", nil, p)
	zero:SetPoint("TOPLEFT", 12, -84)
	zero:SetWidth(300)
	zero:SetHeight(0)
	local zt = zero:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	zt:SetPoint("TOPLEFT")
	zt:SetText("C: child of a zero-height frame")
	local ztex = zero:CreateTexture(nil, "ARTWORK")
	ztex:SetPoint("TOPLEFT", 0, -16)
	ztex:SetSize(60, 10)
	ztex:SetColorTexture(0, 1, 0, 1)
	local ref = CreateFrame("Frame", nil, p)
	ref:SetPoint("TOPLEFT", 220, -100)
	ref:SetSize(150, 30)
	local rt = ref:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	rt:SetPoint("TOPLEFT")
	rt:SetText("D: same, height 30")
	Say(("  zero height: frame %sx%s, child text shown %s visible %s, green box visible %s; reference visible %s"):format(
		Show(zero:GetWidth()), Show(zero:GetHeight()), Show(zt:IsShown()), Show(zt:IsVisible()), Show(ztex:IsVisible()),
		Show(rt:IsVisible())))

	-- Cyrillic: text set, then the font object swapped (boxes?), and the
	-- other order for reference.
	local after = Label(-140, "E: " .. CYRILLIC, "GameFontNormal")
	local beforeFile = Font(after)
	after:SetFontObject("GameFontHighlightLarge")
	local afterFile = Font(after)
	local first = p:CreateFontString(nil, "OVERLAY")
	first:SetPoint("TOPLEFT", 220, -140)
	first:SetFontObject("GameFontHighlightLarge")
	first:SetText("F: " .. CYRILLIC)
	Say(("  cyrillic: E (text, then font object) font %s -> %s; F (font object, then text) font %s"):format(
		beforeFile, afterFile, Font(first)))

	-- The blank font (glyphs that are specks): taken?
	local blank = Label(-180, "G: blank font")
	local took = blank:SetFont(BLANK, 14, "")
	Say(("  blank font: SetFont returned %s, font now %s"):format(Show(took), Font(blank)))
	run.found.blank = took
	Label(-220, "Expect: A dim; B ?; C ? (green box under it); E ? F readable")
end

-- Step 2 / 4: the plate walk ------------------------------------------------

local function PieceName(parent, child)
	local ok, name = pcall(function()
		for k, v in pairs(parent) do
			if v == child and type(k) == "string" then return k end
		end
	end)
	return ok and name or nil
end

local function Read(obj, method)
	local fn = obj[method]
	if type(fn) ~= "function" then return "none" end
	local ok, a, b, c, d, e = pcall(fn, obj, 1)
	if not ok then return "error" end
	if method == "GetPoint" then
		if a == nil then return "no points" end
		return ("%s %s %s %s,%s"):format(Show(a), Secret(b) and "<secret>" or (b and (pcall(b.GetDebugName, b) and
			b:GetDebugName() or "frame") or "nil"), Show(c), Show(d), Show(e))
	end
	return Show(a)
end

local function WalkPlate(plate, label)
	local lines, readable, errors = 0, {}, 0
	local function Walk(obj, path, depth)
		if lines >= PLATE_LINES then return end
		lines = lines + 1
		local point, left = Read(obj, "GetPoint"), Read(obj, "GetLeft")
		Say(("  %s %s: point %s, left %s"):format(label, path, point, left))
		if point == "error" then errors = errors + 1 elseif point ~= "none" then readable[#readable + 1] = path end
		if depth >= 3 then return end
		for _, getter in ipairs({ "GetChildren", "GetRegions" }) do
			local ok, kids = pcall(function() return { obj[getter](obj) } end)
			if ok and obj[getter] then
				for i, kid in ipairs(kids) do
					Walk(kid, path .. "." .. (PieceName(obj, kid) or (getter == "GetChildren" and "child" or "region") .. i),
						depth + 1)
				end
			end
		end
	end
	local uf = plate.UnitFrame
	local bgTex = uf and uf.healthBar and uf.healthBar.bgTexture
	local bg = bgTex and Read(bgTex, "GetPoint") or "no healthBar.bgTexture"
	Say(("  %s healthBar.bgTexture: point %s"):format(label, bg))
	Walk(plate, "plate", 0)
	Say(("  %s: %d pieces, %d with a readable point, %d errors; readable: %s"):format(label, lines, #readable, errors,
		table.concat(readable, ", ")))
	return bg, #readable, errors
end

local function APlate(unit)
	local get = C_NamePlate and C_NamePlate.GetNamePlateForUnit
	if unit and get then
		local ok, plate = pcall(get, unit)
		if ok and plate then return plate end
	end
	local plates = C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates() or {}
	return plates[1]
end

-- Step 3: the camera ---------------------------------------------------------

local function ZoomSampler(label, seconds)
	local samples, t0 = {}, GetTime()
	local ticker
	ticker = C_Timer.NewTicker(0.03, function()
		local ok, z = pcall(GetCameraZoom)
		samples[#samples + 1] = ("%.2f=%s"):format(GetTime() - t0, ok and Show(z) or "error")
		if GetTime() - t0 >= seconds then
			ticker:Cancel()
			Say(("  zoom %s: %s"):format(label, table.concat(samples, " ")))
		end
	end)
end

-- One trial: tilt down and zoom out, then SetView(VIEW_SLOT) under the blend
-- style; next() after its shots.
local function ViewTrial(style, nextStep)
	Say(("  view trial: blend style %s, zoom before %s"):format(style, Show(GetCameraZoom())))
	MoveViewDownStart()
	CameraZoomOut(6)
	C_Timer.After(0.4, function()
		MoveViewDownStop()
		C_Timer.After(1.2, function()
			if not run then return end
			-- (Shots at least 1.1 s apart: the game names them by the second, so
			-- two in one second overwrite each other; 2026-11-20 run lost 4.)
			Shot("blend " .. style .. ": moved, before SetView")
			C_Timer.After(SHOT_GAP, function()
				if not run then return end
				SetCVar("cameraViewBlendStyle", style)
				ZoomSampler("after SetView, blend " .. style, 1.6)
				SetView(VIEW_SLOT)
				C_Timer.After(0.15, function() Shot("blend " .. style .. ": 0.15 s after SetView") end)
				C_Timer.After(0.15 + SHOT_GAP, function()
					Shot("blend " .. style .. ": " .. (0.15 + SHOT_GAP) .. " s after SetView")
				end)
				C_Timer.After(2.5, function() if run then nextStep() end end)
			end)
		end)
	end)
end

local function Camera(done)
	run.blendWas = GetCVar("cameraViewBlendStyle")
	Say(("  camera: blend style %s, zoom %s, view %d saved over"):format(tostring(run.blendWas),
		Show(GetCameraZoom()), VIEW_SLOT))
	pcall(_G.SaveView, VIEW_SLOT)
	Shot("tilt: before")
	-- Tilt sign: a short MoveViewDown, shots before and after (I read them).
	C_Timer.After(SHOT_GAP, function()
	if not run then return end
	MoveViewDownStart()
	C_Timer.After(0.3, function()
		MoveViewDownStop()
		C_Timer.After(0.3, function()
			if not run then return end
			Shot("tilt: after MoveViewDown 0.3 s")
			-- (Style 1 brings a view back; 0 did nothing at all, 2026-11-20, so the
			-- trials are 1 and 2, and the view is put back under 1 at the end.)
			SetCVar("cameraViewBlendStyle", "1")
			SetView(VIEW_SLOT)
			C_Timer.After(1.5, function()
				if not run then return end
				ViewTrial("1", function()
					ViewTrial("2", function()
						SetCVar("cameraViewBlendStyle", "1")
						SetView(VIEW_SLOT)
						C_Timer.After(1.5, function()
							if not run then return end
							SetCVar("cameraViewBlendStyle", run.blendWas or "1")
							Say("  view put back; blend style put back: " .. tostring(GetCVar("cameraViewBlendStyle")))
							done()
						end)
					end)
				end)
			end)
		end)
	end)
	end)
end

-- Ending -------------------------------------------------------------------

local function Restore()
	if run.ticker then run.ticker:Cancel() end
	run.events:UnregisterAllEvents()
	run.events:SetScript("OnEvent", nil)
	if run.panel then run.panel:Hide() end
	if run.blendWas then SetCVar("cameraViewBlendStyle", run.blendWas) end
	ns.ApplyCVarSet(PLATES, false)
	if run.cineWas then SetCine(true) end
end

local function DoneBox(lines, reloaded)
	ns.PadTestBox("Rule check DONE." .. (reloaded and " Say \"check log\"." or " /reload, then say \"check log\"."),
		table.concat(lines, "\n"), 1, 1, 1)
	C_Timer.After(40, function() if not run then ns.PadTestBoxHide() end end)
end

local function Stop()
	Say("stopped early")
	Restore()
	run = nil
	ns.PadTestBox("Rule check stopped.", "", 1, 1, 1)
	C_Timer.After(10, function() if not run then ns.PadTestBoxHide() end end)
end

local function Results()
	local c, f = Client(), run.found
	Result(c .. ".fontstring.color-alpha-is-alpha", ("B's text alpha after SetAlpha(1) read %s (0.16 = two values"
		.. ", 1 = one; the screenshot says what drew)"):format(Show(f.alphaB)))
	Result(c .. ".font.setfont-rejects-empty-glyphs", "SetFont(Blank.ttf) returned " .. Show(f.blank))
	Result(c .. ".plate.bgtexture-getpoint", f.plate and ("out of fights bgTexture %s; %d pieces readable, %d errors")
		:format(f.plate[1], f.plate[2], f.plate[3]) or "no plate walked")
	Result(c .. ".plate.getpoint-in-fight", f.platefight and ("bgTexture %s; %d pieces readable, %d errors")
		:format(f.platefight[1], f.platefight[2], f.platefight[3]) or "no plate walked in the fight")
	Result(c .. ".unit_combat.amount", ("%d of %d amounts secret"):format(f.secretHits or 0, run.hits))
	Result(c .. ".unit_aura.addedauras", ("added auras in fights: on you %d secret, %d plain; on others %d secret,"
		.. " %d plain"):format(f.secretplayer or 0, f.plainplayer or 0, f.secretother or 0, f.plainother or 0))
	for _, key in ipairs({ "interact", "uivis", "softcvar" }) do
		local p = f[key]
		Result(c .. ".probe." .. key, p or "not run (no fight)")
	end
end

-- Reload: the last step, run after everything else is put back.
local function TryReload()
	local lines = run.results
	CinematicDB.ruleCheckReload = { at = time(), client = Client() }
	Say("reload: calling ReloadUI() from addon code")
	run.probe = { label = "ReloadUI", blocked = {} }
	local ok, err = pcall(ReloadUI)
	Say("  ReloadUI pcall: " .. (ok and "ran" or tostring(err)))
	C_Timer.After(2, function()
		local blocked = run and run.probe and run.probe.blocked or {}
		CinematicDB.ruleCheckReload = nil
		lines[#lines + 1] = ""
		local text = ("ReloadUI from addon code did not reload; blocked %s"):format(#blocked > 0
			and table.concat(blocked, ", ") or "none heard")
		Say("RESULT " .. Client() .. ".reloadui.addon-code: " .. text)
		lines[#lines + 1] = "reload: " .. text
		if run then
			run.events:UnregisterAllEvents()
			run = nil
		end
		Say("done")
		DoneBox(lines, false)
	end)
end

local function Finish()
	Results()
	Restore()
	Say("settings put back; reload step next")
	Prompt("5/5: Last: the test calls ReloadUI() itself in 3 s.", "If the UI reloads, the run ends on its own")
	local events = run.events
	-- (Kept listening for the blocked action alone.)
	events:RegisterEvent("ADDON_ACTION_BLOCKED")
	events:RegisterEvent("ADDON_ACTION_FORBIDDEN")
	events:SetScript("OnEvent", function(_, event, addon, fn)
		if run and run.probe then run.probe.blocked[#run.probe.blocked + 1] = event .. " " .. tostring(fn) end
		Say(("  %s %s %s"):format(event, tostring(addon), tostring(fn)))
	end)
	C_Timer.After(3, function() if run then TryReload() end end)
end

-- Steps ----------------------------------------------------------------------

local function Go(step)
	run.step, run.stepAt = step, GetTime()
	Say(("--- step %s (fight %s) ---"):format(step, tostring(InCombatLockdown())))
end

local function FightProbes()
	run.probing = true
	local f = run.found
	Probe("CheckInteractDistance target 3", function() return CheckInteractDistance("target", 3) end,
		function(ok, a, blocked)
			f.interact = (ok and "answered " .. Show(a) or "error") .. (#blocked > 0 and ", blocked" or ", not blocked")
			Probe("SetUIVisibility(true)", function() SetUIVisibility(true) end, function(ok2, _, blocked2)
				f.uivis = (ok2 and "ran" or "error") .. (#blocked2 > 0 and ", blocked " .. blocked2[1] or ", not blocked")
				local cvar = "SoftTargetEnemy"
				Probe("SetCVar " .. cvar .. " to its own value", function() return SetCVar(cvar, GetCVar(cvar)) end,
					function(ok3, a3, blocked3)
						f.softcvar = (ok3 and "ran " .. Show(a3) or "error")
							.. (#blocked3 > 0 and ", blocked " .. blocked3[1] or ", not blocked")
						local plate = APlate("target")
						if plate then
							local bg, n, errors = WalkPlate(plate, "fight plate")
							f.platefight = { bg, n, errors }
						end
						run.probed = true
					end)
			end)
		end)
end

local function Tick()
	if CineOn() then SetCine(false) end
	local step = run.step
	if step == "plate" then
		local plate = APlate()
		if not plate then
			Prompt("2/5: Stand where an enemy's nameplate shows.", "Waiting for a nameplate")
			return
		end
		local bg, n, errors = WalkPlate(plate, "plate")
		run.found.plate = { bg, n, errors }
		Go("camera")
		Prompt("3/5: Stand still in the open (no trees or roof above). The camera moves by itself for a few seconds.",
			"Don't touch the mouse")
		Camera(function() if run then Go("fight") end end)
	elseif step == "fight" then
		if not InCombatLockdown() then
			Prompt("4/5: Attack an enemy and keep fighting.", ("Hits heard %d, auras %d"):format(run.hits, run.auraLines))
			return
		end
		if not run.probing then FightProbes() end
		if run.probed and run.hits >= HITS then
			Go("end")
			Prompt("4/5: Done in the fight. Finish it.", "Waiting for the fight to end")
		else
			Prompt("4/5: Keep fighting.", ("Hits heard %d of %d, probes %s"):format(run.hits, HITS,
				run.probed and "done" or "running"))
		end
	elseif step == "end" then
		if InCombatLockdown() then
			Prompt("4/5: Done in the fight. Finish it.", "Waiting for the fight to end")
			return
		end
		Go("reload")
		Finish()
	end
end

local function OnEvent(_, event, ...)
	local f = run.found
	if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
		local addon, fn = ...
		Say(("  %s %s %s"):format(event, tostring(addon), tostring(fn)))
		if run.probe then run.probe.blocked[#run.probe.blocked + 1] = event .. " " .. tostring(fn) end
	elseif event == "UNIT_COMBAT" then
		local unit, action, flag, amount, school = ...
		if not InCombatLockdown() then return end
		run.hits = run.hits + 1
		if Secret(amount) then f.secretHits = (f.secretHits or 0) + 1 end
		if run.hits <= HITS * 2 then
			Say(("  UNIT_COMBAT %s %s %s amount %s school %s"):format(Show(unit), Show(action), Show(flag), Show(amount),
				Show(school)))
		end
	elseif event == "UNIT_AURA" then
		-- (Any unit: yours, and your target's and the plates' that your own
		-- attacks change, so the fight needs no buff or debuff on you; the
		-- 2026-11-20 Forever runs heard none on you.)
		local unit, info = ...
		if not InCombatLockdown() or Secret(unit) or type(unit) ~= "string" then return end
		local who = unit == "player" and "player" or "other"
		local ok, added = pcall(function() return info and info.addedAuras end)
		local secret = not ok or Secret(info) or Secret(added)
		if not (secret or added) then return end
		local key = (secret and "secret" or "plain") .. who
		f[key] = (f[key] or 0) + 1
		if run.auraLines < AURAS and (secret or added) then
			run.auraLines = run.auraLines + 1
			local first = ""
			if not secret and type(added) == "table" and added[1] then
				local ok2, id = pcall(function() return added[1].auraInstanceID end)
				first = (", first auraInstanceID %s"):format(ok2 and Show(id) or "error")
			end
			Say(("  UNIT_AURA %s: info %s, addedAuras %s%s"):format(unit, Secret(info) and "<secret>" or type(info),
				ok and (Secret(added) and "<secret>" or (type(added) == "table" and #added .. " auras" or tostring(added)))
				or "error on read", first))
		end
	end
end

function ns.RuleCheckTest()
	ns.debugNoCopyWindow = true
	if run then
		Stop()
		return
	end
	if InCombatLockdown() then
		ns.Print("rule check: not in a fight")
		return
	end
	CinematicDB.ruleCheckLog = {}
	run = { at = GetTime(), results = {}, found = {}, hits = 0, auraLines = 0 }
	Say(("start: %s (game %s, build %s), version %s, CineMode %s, blend style %s, enemy plates %s"):format(Client(),
		tostring((select(4, GetBuildInfo()))), tostring((select(2, GetBuildInfo()))),
		tostring(C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")),
		tostring(CineOn()), tostring(GetCVar("cameraViewBlendStyle")), tostring(GetCVar("nameplateShowEnemies"))))
	run.cineWas = CineOn()
	SetCine(false)
	ns.ApplyCVarSet(PLATES, true)
	run.events = CreateFrame("Frame")
	local registered = {}
	for _, event in ipairs({ "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "UNIT_COMBAT", "UNIT_AURA" }) do
		registered[#registered + 1] = event .. "=" .. tostring(ns.Check.RegisterEvent(run.events, event))
	end
	Say("events: " .. table.concat(registered, ", "))
	run.events:SetScript("OnEvent", function(...)
		if not run then return end
		local ok, err = pcall(OnEvent, ...)
		if not ok then Say("event error: " .. tostring(err)) end
	end)
	ns.TestPrompt("Rule check: follow the box (type it again to stop)")
	Go("panel")
	Prompt("1/5: Nothing to do: reading a test panel.", "Screenshot in a second")
	local ok, err = pcall(Panel)
	if not ok then Say("panel error: " .. tostring(err)) end
	C_Timer.After(1, function()
		if not run then return end
		Shot("panel")
		C_Timer.After(0.5, function()
			if not run then return end
			if run.panel then run.panel:Hide() end
			Go("plate")
			run.ticker = C_Timer.NewTicker(0.25, function()
				if not run then return end
				local ok2, err2 = pcall(Tick)
				if not ok2 then
					Say("error: " .. tostring(err2))
					if run then Stop() end
				end
			end)
		end)
	end)
end

-- A reload that went through: the next login logs it and shows DONE.
local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function(self)
	self:UnregisterAllEvents()
	local pending = CinematicDB and CinematicDB.ruleCheckReload
	if not pending then return end
	CinematicDB.ruleCheckReload = nil
	Say(("RESULT %s.reloadui.addon-code: ReloadUI() from addon code reloaded the UI (%d s after the call)"):format(
		tostring(pending.client), time() - (pending.at or time())))
	Say("done")
	C_Timer.After(3, function() DoneBox({ "ReloadUI from addon code reloaded the UI" }, true) end)
end)
