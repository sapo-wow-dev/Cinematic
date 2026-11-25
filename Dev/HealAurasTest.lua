-- /cine debug healauras: can Heal Vision hide a healthy member's raid-style
-- frame and still leave its debuffs and dispel glow at full? (The user,
-- 2026-11-23: hiding the frame is great, hiding a cleansable debuff is bad.)
-- The idea (Visions/HealVisionFrames.lua's KeepAuras): fade the member's
-- parts instead of the whole frame; the aura icons and the dispel glow are
-- forbidden or drawn by the game (rules forever.dispeloverlay.forbidden,
-- forever.compactpartyframe.no-aura-icons), out of our reach, so they keep
-- the frame's full alpha. One run, A/B:
--   1 group   waits for a group with raid-style frames (a follower dungeon
--             works), a shot of the game's own frames (Heal Vision off),
--             turns Heal Vision on here with healthy members hidden
--             fully (opacity 0), checks it picked the members up
--   2 whole   today's way (the frame faded whole): each member's frame,
--             parts and auras logged, a screenshot
--   3 parts   the page's tick (Unit Frames tab: Debuffs, Show while hidden)
--             found, clear of everything, a shot, clicked on; then no
--             member faded whole, the frame itself left
--             at the game's alpha (1, or its range dimming), its parts
--             faded; every child and region logged forbidden or reached,
--             faded or not, its effective alpha; a screenshot
--   4 fight   pull a mob (or Skip step): the same in a fight (auras secret,
--             debuffs likelier), two screenshots
-- Settings put back at the end (a /reload too). Into
-- CinematicDB.healAurasTestLog. Dev copy only.
local _, ns = ...

local SETTLE = 2 -- seconds for a Scan and an Update to follow a setting

local ROLES = { "TANK", "HEALER", "DAMAGER" }
local HIDE = { healVisionMinAlpha = 0, healVisionTankAlpha = 0, healVisionHealerAlpha = 0, healVisionPetAlpha = 0,
	healVisionTankBelow = 0.95, healVisionTargetAlpha = 0 }
local SETTINGS = { "handleHealVision", "healVision", "healVisionKeepAuras" }
for key in pairs(HIDE) do SETTINGS[#SETTINGS + 1] = key end
for _, role in ipairs(ROLES) do SETTINGS[#SETTINGS + 1] = "healVisionOwn_" .. role end
for _, key in pairs(ns.HEAL_VISION_TABS or {}) do SETTINGS[#SETTINGS + 1] = key end

local function Secret(value) return issecretvalue ~= nil and issecretvalue(value) == true end
local function Show(value)
	if Secret(value) then return "secret" end
	if type(value) == "number" then return ("%.2f"):format(value) end
	return tostring(value)
end
local function Ask(object, method)
	if not (object and object[method]) then return "-" end
	local ok, value = pcall(object[method], object)
	return ok and Show(value) or "error"
end
local function Reached(object) return ns.Reachable(object) and true or false end

-- The frames the members are in: raid-style party, else the raid's.
local function Holder()
	for _, name in ipairs({ "CompactPartyFrame", "CompactRaidFrameContainer" }) do
		local holder = _G[name]
		if holder and Reached(holder) then
			local ok, shown = pcall(holder.IsVisible, holder)
			if ok and not Secret(shown) and shown then return holder, name end
		end
	end
end

local function Members()
	local list = {}
	for frame, member in pairs(ns.HealVisionMembers and ns.HealVisionMembers() or {}) do
		local name = Ask(frame, "GetName")
		if name == "nil" then name = Ask(frame, "GetDebugName") end -- (retail's PartyFrame members have none)
		list[#list + 1] = { frame = frame, member = member, name = name }
	end
	table.sort(list, function(a, b) return a.name < b.name end)
	return list
end

-- A member's auras out of combat (in a fight the reads error: logged so).
local function AuraCount(unit, filter)
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return "no api" end
	local n = 0
	for i = 1, 40 do
		local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, filter)
		if not ok then return "error (secret)" end
		if Secret(data) then return "secret" end
		if type(data) ~= "table" then break end
		n = n + 1
	end
	return n
end

-- Each member: its frame, how it's faded, its auras, every part reached or not.
local function LogMembers(r, label, deep)
	local list = Members()
	r:Log(("%s: %d member frame(s)"):format(label, #list))
	local whole, keptUp = 0, 0
	for _, entry in ipairs(list) do
		local frame, member = entry.frame, entry.member
		if member.whole then whole = whole + 1 end
		-- (Secret: the game's own range dimming set it, retail run 1: still the
		-- game's, not ours. Only a plain one below 0.5 is a frame we faded.)
		local okAlpha, alpha = pcall(frame.GetAlpha, frame)
		if okAlpha and (Secret(alpha) or (type(alpha) == "number" and alpha >= 0.5)) then keptUp = keptUp + 1 end
		r:Fields(entry.name, {
			unit = function() return member.unit end,
			whole = function() return member.whole and true or false end,
			ours = function() return member.alpha end,
			frameAlpha = function() return frame:GetAlpha() end,
			effective = function() return frame:GetEffectiveAlpha() end,
			parts = function() return #member.parts end,
			health = function() return UnitHealthPercent and UnitHealthPercent(member.unit) end,
			inRange = function() return UnitInRange(member.unit) end,
			buffs = function() return AuraCount(member.unit, "HELPFUL") end,
			debuffs = function() return AuraCount(member.unit, "HARMFUL") end,
			dispellable = function() return AuraCount(member.unit, "HARMFUL|RAID") end,
		})
		if deep then
			local faded = {}
			for _, part in ipairs(member.parts) do faded[part] = true end
			local auras = ns.HealVisionAuraParts(frame)
			-- The aura fields as the game names them, reachable or not.
			for _, key in ipairs({ "debuffFrames", "dispelDebuffFrames", "buffFrames", "DispelOverlay",
				"CenterDefensiveBuff", "PrivateAuraAnchors" }) do
				local value = rawget(frame, key)
				local text = type(value)
				if type(value) == "table" and not value.GetObjectType then
					local n, open = 0, 0
					for _, icon in pairs(value) do
						n = n + 1
						if type(icon) == "table" and Reached(icon) then open = open + 1 end
					end
					text = ("list of %d, %d reachable"):format(n, open)
				elseif type(value) == "table" then
					text = Reached(value) and "reachable" or "forbidden"
				end
				r:Log(("    %s.%s: %s"):format(entry.name, key, text))
			end
			local function Line(object, kind)
				local reached = Reached(object)
				local what = reached and Ask(object, "GetObjectType") or "?"
				local field = auras[object] and (" aura:" .. auras[object]) or ""
				r:Log(("    %s %s %s%s: %s, %s, alpha %s, effective %s, ignores parent %s"):format(entry.name, kind,
					reached and (Ask(object, "GetDebugName")) or "forbidden", field, what,
					faded[object] and "FADED" or "left", reached and Ask(object, "GetAlpha") or "?",
					reached and Ask(object, "GetEffectiveAlpha") or "?",
					reached and Ask(object, "IsIgnoringParentAlpha") or "?"))
			end
			local okRegions, regions = pcall(function() return { frame:GetRegions() } end)
			for _, region in ipairs(okRegions and regions or {}) do Line(region, "region") end
			local okChildren, children = pcall(function() return { frame:GetChildren() } end)
			for _, child in ipairs(okChildren and children or {}) do Line(child, "child") end
		end
	end
	return list, whole, keptUp
end

-- A settings control by its setting's key, under root.
local function FindKey(root, key)
	local function Walk(frame, depth)
		if depth > 30 then return nil end
		if frame.settingKey == key then return frame end
		local ok, children = pcall(function() return { frame:GetChildren() } end)
		for _, child in ipairs(ok and children or {}) do
			if Reached(child) then
				local hit = Walk(child, depth + 1)
				if hit then return hit end
			end
		end
	end
	return Walk(root, 0)
end

local function Apply(r)
	if ns.ApplyHealVisionFrames then ns.ApplyHealVisionFrames() end
	r:Sleep(SETTLE)
end

local function Shot(r, label)
	local holder = Holder()
	r:Shot(label, holder and { behind = holder } or nil)
end

ns.TestKit.Define({
	name = "healauras",
	key = "healAurasTest",
	title = "Heal Vision: keep auras shown",
	about = "Heal Vision fading raid frames by parts so debuff icons and the dispel glow stay at full",
	needs = "A group with raid-style frames (a follower dungeon) and a mob to pull",
	settings = SETTINGS,
	cvars = { "useCompactPartyFrames", "raidFramesDisplayDebuffs", "raidFramesDisplayOnlyDispellableDebuffs" },
	context = function()
		local holder, name = Holder()
		return ("raid-style frames %s, group %s raid %s, role %s, visions loaded %s"):format(
			holder and name or "none shown", tostring(IsInGroup()), tostring(IsInRaid()),
			tostring(ns.PlayerRole and ns.PlayerRole()), tostring(ns.ApplyHealVisionFrames ~= nil))
	end,
	putBack = function(extra)
		if extra.rule ~= nil and ns.db then
			ns.db.frameRules = ns.db.frameRules or {}
			ns.db.frameRules.healVision = extra.rule ~= "<nil>" and extra.rule or nil
		end
		if ns.ApplyHealVisionFrames then ns.ApplyHealVisionFrames() end
		return "Unit Frames row's rule put back, Heal Vision applied again"
	end,
	steps = {
		{ key = "group", title = "a group with raid-style frames", run = function(r)
			if not ns.ApplyHealVisionFrames then
				r:Fail("Visions isn't loaded (left out on the Profiles page?): nothing to test")
				return
			end
			if not Holder() then
				r:WaitFor("Join a group with raid-style party frames (a follower dungeon works)",
					{ check = function() return Holder() and true end })
			end
			-- The game's own look first (Heal Vision off): which icons it
			-- draws at all, so one missing later is ours, not its filter
			-- (run 1: no buff icons on hidden members, unknown if drawn).
			r:Set("handleHealVision", false)
			Apply(r)
			Shot(r, "the game's own: Heal Vision off, every icon the game draws")
			r:Set("handleHealVision", true)
			r:Set("healVision", true) -- (its row's Always)
			-- (Its row's rule decides over the ticks: "(dungeon or raid) and not
			-- dead" to start with. Anywhere for the run, put back after.)
			ns.db.frameRules = ns.db.frameRules or {}
			r:Keep("rule", ns.db.frameRules.healVision)
			ns.db.frameRules.healVision = "not dead"
			r:Log("Unit Frames row's rule for the run: not dead")
			for _, key in pairs(ns.HEAL_VISION_TABS) do
				if key ~= ns.HEAL_VISION_TABS.PLATES then r:Set(key, true) end
			end
			for _, role in ipairs(ROLES) do r:Set("healVisionOwn_" .. role, false) end
			for key, value in pairs(HIDE) do r:Set(key, value) end
			r:Set("healVisionKeepAuras", false)
			Apply(r)
			r:Probe("ns.HealVisionHere", ns.HealVisionHere, ns.db)
			local list, whole = LogMembers(r, "picked up")
			r:Verdict(#list > 0, #list .. " member frame(s) under Heal Vision")
			r:Verdict(whole > 0, whole .. " faded whole (raid-style), today's way")
		end },
		{ key = "whole", title = "today's way: the frame faded whole", run = function(r)
			LogMembers(r, "whole", true)
			Shot(r, "faded whole: healthy members gone, their auras too")
		end },
		{ key = "parts", title = "Debuffs: Show while hidden, ticked on the page", run = function(r)
			-- The tick on the Heal Vision page's Unit Frames tab (Default
			-- settings): on the page, clear of everything, and its click turns
			-- it on (as shown: Tools/tests rule test-menu-as-shown).
			r:Set("healVisionKeepAuras", false)
			if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
			ns.OpenOptions("Heal Vision")
			r:Sleep(0.8)
			local canvas = ns.settingsCanvases and ns.settingsCanvases["Heal Vision"]
			local check = canvas and FindKey(canvas, "healVisionKeepAuras")
			if check and check:IsVisible() then
				local hits = r:Overlaps(check, check:GetParent())
				r:Verdict(#hits == 0, "the tick overlaps nothing: " .. (#hits > 0 and table.concat(hits, ", ") or "clear"))
				r:Verdict(not check:GetChecked(), "unticked to start (the test set it off, to click it on)")
				-- (Scrolled to it first: run 2's shot showed the page's top, the
				-- tick below Dead, out of sight.)
				local scroll = canvas.scroll
				local child = scroll and scroll.GetScrollChild and scroll:GetScrollChild()
				if child and child.GetTop and child:GetTop() and check:GetTop() then
					local range = tonumber(scroll:GetVerticalScrollRange()) or 0
					local at = math.max(0, math.min(range, child:GetTop() - check:GetTop() - 200))
					scroll:SetVerticalScroll(at)
					r:Log(("scrolled to %.0f of %.0f for the tick"):format(at, range))
					r:Sleep(0.3)
				end
				r:Shot("the Unit Frames tab: Debuffs, Show while hidden, under Ready check", { behind = check })
				if scroll and scroll.SetVerticalScroll then scroll:SetVerticalScroll(0) end
				check:Click()
				r:Sleep(0.3)
				r:Verdict(ns.db.healVisionKeepAuras == true, "its click ticks it: " .. tostring(ns.db.healVisionKeepAuras))
			else
				r:Fail(("the tick isn't shown on the page (found %s): set here instead"):format(tostring(check ~= nil)))
				r:Set("healVisionKeepAuras", true)
			end
			if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
			Apply(r)
			local list, whole, keptUp = LogMembers(r, "parts", true)
			r:Verdict(#list > 0 and whole == 0, ("%d of %d faded whole (0 wanted)"):format(whole, #list))
			r:Verdict(#list > 0 and keptUp == #list,
				("%d of %d frames left at the game's alpha (0.5 or more, or secret: its range dimming)"):format(keptUp, #list))
			Shot(r, "faded by parts: auras and dispel glow should stay on hidden members")
		end },
		{ key = "fight", title = "in a fight", run = function(r)
			if not InCombatLockdown() then
				r:WaitFor("Pull a mob (or Skip step): the frames in a fight", { events = { "PLAYER_REGEN_DISABLED" } })
			end
			r:Sleep(SETTLE)
			local list, whole = LogMembers(r, "fight")
			r:Verdict(#list > 0 and whole == 0, ("in a fight %d of %d faded whole (0 wanted)"):format(whole, #list))
			Shot(r, "in a fight, first")
			r:Sleep(3)
			LogMembers(r, "fight, later", true)
			Shot(r, "in a fight, a few seconds on")
		end },
	},
})
