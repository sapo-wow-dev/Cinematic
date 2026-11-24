-- Heal Vision's Keep auras shown (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/healauras.lua < /dev/null
-- A stand-in raid-style party (CompactPartyFrame, two members, each with a
-- health bar, a background, a reachable debuff icon in .debuffFrames and a
-- forbidden one) on both clients:
--   * off (today's way): members faded whole (the frame itself at the curve's alpha);
--   * on: no member faded whole, the frame's own alpha left alone, the
--     background and health bar faded, the reachable debuff icon and the
--     forbidden one never in the parts;
--   * /cine debug healauras runs to DONE with no FAIL (the fight step waits
--     for PLAYER_REGEN_DISABLED, fired here), and the settings are put back.
-- PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212 431
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end
local function Has(log, pattern)
	for _, line in ipairs(log or {}) do
		if line:find(pattern) then return line end
	end
end

local function RunClient(client)
	print("== " .. client)
	local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
	if not ns.ApplyHealVisionFrames then
		Check("Visions loaded", false)
		return
	end
	local now = 100
	local timers, tickers = {}, {}
	GetTime = function() return now end
	C_Timer.After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end
	C_Timer.NewTicker = function(every, fn)
		local t = { every = every, next = now + every, fn = fn, Cancel = function(self) self.cancelled = true end }
		tickers[#tickers + 1] = t
		return t
	end
	local function Advance(seconds)
		local stop = now + seconds
		while now < stop do
			now = now + 0.1
			local due = {}
			for i = #timers, 1, -1 do
				if timers[i].at <= now then due[#due + 1] = table.remove(timers, i) end
			end
			for i = #due, 1, -1 do pcall(due[i].fn) end
			for _, t in ipairs(tickers) do
				if not t.cancelled and t.next <= now then
					t.next = now + t.every
					pcall(t.fn, t)
				end
			end
		end
	end
	Screenshot = function() end
	ns.IsCineModeOn = function() return false end
	ns.PadTestBox = function() end
	ns.PadTestBoxHide = function() end
	IsInGroup = function() return true end
	IsInRaid = function() return false end
	UnitExists = function() return true end
	UnitIsConnected = function() return true end
	UnitIsDeadOrGhost = function() return false end
	UnitIsUnit = function(a, b) return a == b end
	UnitInRange = function() return true, true end
	UnitHealthPercent = function() return 0 end -- (the curve's hidden end, as the game would hand it)
	UnitGroupRolesAssigned = function() return "DAMAGER" end
	local combat = false
	wow.Methods.IsIgnoringParentAlpha = function() return false end -- (the stub's answer is truthy)
	wow.Methods.SetAlpha = function(self, alpha) self._alpha = alpha end -- (the stand-in keeps no alpha)
	wow.Methods.GetAlpha = function(self) return self._alpha or 1 end
	InCombatLockdown = function() return combat end

	-- The party: two members, a reachable debuff icon and a forbidden one each.
	local holder = CreateFrame("Frame", "CompactPartyFrame", UIParent)
	holder:Show()
	local members = {}
	for i = 1, 2 do
		local member = CreateFrame("Button", "CompactPartyFrameMember" .. i, holder)
		member.unit, member.displayedUnit = "party" .. i, "party" .. i
		member:Show()
		member.background = member:CreateTexture()
		member.healthBar = CreateFrame("StatusBar", nil, member)
		local icon = CreateFrame("Button", nil, member)
		member.debuffFrames = { icon }
		local locked = CreateFrame("Frame", nil, member)
		locked.IsForbidden = function() return true end
		members[i] = { frame = member, icon = icon, locked = locked }
	end

	local function State()
		local list = ns.HealVisionMembers()
		local whole, n = 0, 0
		for _, member in pairs(list) do
			n = n + 1
			if member.whole then whole = whole + 1 end
		end
		return n, whole, list
	end
	local function InParts(member, part)
		for _, p in ipairs(member.parts) do if p == part then return true end end
		return false
	end

	-- The tick: off to start with, one of the role tabs' own settings.
	Check("tick off to start with", ns.DEFAULTS.healVisionKeepAuras == false, ns.DEFAULTS.healVisionKeepAuras)
	local roleKey = false
	for _, key in ipairs(ns.HEAL_VISION_ROLE_KEYS) do if key == "healVisionKeepAuras" then roleKey = true end end
	Check("tick is a role tab setting", roleKey)
	Check("off: not kept", ns.HealVisionKeepAuras() == false)

	-- (Heal Vision on here, healthy ones hidden: as the test sets it.)
	local db = ns.db
	local saved = {}
	local function Set(key, value)
		if saved[key] == nil then saved[key] = { db[key] } end
		db[key] = value
	end
	Set("handleHealVision", true)
	Set("healVision", true)
	Set("healVisionMinAlpha", 0)
	db.frameRules = db.frameRules or {}
	local rule = db.frameRules.healVision
	db.frameRules.healVision = "not dead" -- (as the test does: its default says dungeon or raid)

	Set("healVisionKeepAuras", false)
	ns.ApplyHealVisionFrames()
	local n, whole = State()
	Check("off: both members picked up", n == 2, n)
	Check("off: faded whole", whole == 2, whole)
	Check("off: the frame itself faded", members[1].frame:GetAlpha() == 0, members[1].frame:GetAlpha())
	local m1

	Set("healVisionKeepAuras", true)
	ns.ApplyHealVisionFrames() -- (the frame faded whole before: put back to 1 here)
	members[1].frame:SetAlpha(0.55) -- (then the game's range dimming: ours must leave it)
	ns.ApplyHealVisionFrames()
	local list
	n, whole, list = State()
	m1 = list[members[1].frame]
	Check("on: none faded whole", n == 2 and whole == 0, ("%d of %d"):format(whole, n))
	Check("on: background faded", m1 and InParts(m1, members[1].frame.background))
	Check("on: health bar faded", m1 and InParts(m1, members[1].frame.healthBar))
	Check("on: reachable debuff icon left out", m1 and not InParts(m1, members[1].icon))
	Check("on: forbidden part left out", m1 and not InParts(m1, members[1].locked))
	Check("on: the frame's own alpha left to the game", members[1].frame:GetAlpha() == 0.55,
		members[1].frame:GetAlpha())
	Check("on: background at the curve's alpha", members[1].frame.background:GetAlpha() == 0,
		members[1].frame.background:GetAlpha())
	Check("on: debuff icon at full", members[1].icon:GetAlpha() == 1, members[1].icon:GetAlpha())
	for key, value in pairs(saved) do db[key] = value[1] end
	db.frameRules.healVision = rule
	members[1].frame:SetAlpha(1)
	ns.ApplyHealVisionFrames()

	-- The in-game test, through. (The stand-in shows nothing: the page's
	-- tick counts as shown, so the test finds and clicks it.)
	wow.Methods.IsVisible = function() return true end
	ns.noRealLayout = true -- (every frame at one spot here: the kit doesn't judge overlaps)
	-- (A real click: the box flips, then its OnClick.)
	wow.Methods.SetChecked = function(self, value) self._checked = value and true or false end
	wow.Methods.GetChecked = function(self) return self._checked or false end
	wow.Methods.Click = function(self)
		self._checked = not self._checked
		local script = self:GetScript("OnClick")
		if script then script(self, "LeftButton", true) end
	end
	local before = {}
	for _, key in ipairs({ "healVision", "healVisionKeepAuras", "healVisionMinAlpha" }) do before[key] = db[key] end
	ns.HandleSlash("debug healauras")
	Advance(20)
	combat = true
	wow.Fire("PLAYER_REGEN_DISABLED")
	Advance(30)
	local log = CinematicDB.healAurasTestLog
	local done = Has(log, "DONE: ")
	Check("test finished DONE", done ~= nil, done or (log and log[#log]))
	Check("test: no FAIL", done and done:find(" 0 fail", 1, true) ~= nil, Has(log, "verdict FAIL"))
	Check("test: parts logged per member", Has(log, "region .*FADED") ~= nil)
	Check("test: the page's tick found and clicked", Has(log, "PASS parts: its click ticks it: true") ~= nil,
		Has(log, "parts: the tick") or Has(log, "its click"))
	Check("test: the aura field logged", Has(log, "debuffFrames: list of 1, 1 reachable") ~= nil)
	Check("put back the row's rule", db.frameRules.healVision == rule, db.frameRules.healVision)
	for key, value in pairs(before) do
		Check("put back " .. key, db[key] == value, tostring(db[key]) .. " vs " .. tostring(value))
	end
	combat = false
end

RunClient("forever")
RunClient("retail")
print(fails == 0 and "ALL PASS" or (fails .. " FAIL"))
if fails > 0 then os.exit(1) end
-- luacheck: pop
