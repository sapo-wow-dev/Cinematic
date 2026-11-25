-- /cine debug gating: the 2026-11-25 gating audit's fixes in the real game
-- (Tools/audits/2026-11-25-gating-findings.md and its fix cards). Each switch
-- the fixes cover is turned off by the test, a moment passes, and the real game
-- is read: no update loop from that feature's files running (the loops'
-- audit, as /cine debug loadparts reads it), the game settings it holds let
-- go (yours back), its frames and looks put back; then on again. Hands off but
-- one click: the Reload near the end (Visions, Cameras, Style and Atmosphere
-- left out for one reload; they load again from your next /reload). What needs
-- a state the test can't make (a fight, a boss, a death, rain, a roll, a
-- flight, a Classic Era hunter...) is a SKIP "needs <state>". Steps:
--   1 gates      every switch in the tree off for a moment: everything under it
--                reads off by ns.MasterOff, ns.PageOn, ns.PageSetting,
--                ns.Setting and ns.StyleOn alike; Enable Style off: the ten
--                Style page keys (C9) off by all of them; the tree's shape kept
--   2 hud        chat bubbles' settings let go with Chat's Show or the HUD off
--                (C12), tooltips' fade off with Mouseover's Show off (C13),
--                Gamepad and Cooldown Manager tabs (C7, C8), Hover Groups and
--                Minimap gates, the error text's alpha left alone (E5), the
--                frame scan with the HUD off (D5)
--   3 cine       in CineMode (cameras off for it): the Nameplates and Names
--                tabs off leave plates and names to the game (C1; two shots),
--                Chat's Conversations tab off and typing (C6), plate parts
--                resting with the page off (D15)
--   4 style      Enable Style off: no Style loop, no game setting held, plate
--                theme extras gone (C10), two shots; Text on You and Combat
--                Text Style General tabs (C3, C4); Bubble Style's tab (C2)
--   5 atmosphere the letterbox key with its page off (E1), the bad weather
--                view distance's preview ending (D15), music and weather
--                density let go, the death song (E2), the atmosphere loops
--   6 visions    every Vision page off: their loops rest (D16, D19, D20, D22)
--   7 cameras    Enable Cameras off: no camera loop (D3, D7, D9, D12, D15),
--                Mouse Turn's tab (C18), the fishing watch (D11)
--   8 qol        XP "left" text with the page off (C17), the wheels' key tab,
--                Campfire (D1) and Hunter (D4) watches
--   9 alloff     every page and part switch off at once: nothing of theirs
--                runs; then all back
--  10 out        Load Visions, Cameras, Style and Atmosphere unticked, the
--                Quality of life page off for the login: you click Reload
--  11 leftout    after it: the parts rows with Style out (A1), the Fishing page
--                gone (cameras-out-pages), the effects key (toggle-effects),
--                Shoulder Cam's settings given back (B2), the Why window's
--                Cards tab (C21), the tree's shape (F2), chat history kept (B3);
--                then the parts ticked back on (loaded at your next /reload)
-- Into CinematicDB.gatingTestLog; ledger Tools/tests/gating.md. Dev copy only.
local _, ns = ...
local L = ns.L

local PARTS = { "visions", "cameras", "style", "atmosphere" }
local VISION_PAGES = { "handleHealVision", "questVision", "rollWindow", "duelPlates", "damageVision", "emoteVision",
	"cards", "lowHealth", "teleportVision", "deathScreen" }
-- (C9: the Style page keys that had no master in the switch tree. The
-- finding's targetArrowStyle and questTalkStyle are values, not switches:
-- Quest Talk's is questTalkStyled, the card says; Text on You's joined them.)
local STYLE_KEYS = { "tintStyle", "weatherStyle", "letterboxStyle", "questItemStyle", "rollStyle", "lowHealthStyle",
	"emoteStyle", "damageVisionLook", "questTalkStyled", "selfTextStyle" }
local NAME_TABS = { "Names", "NamesPlayers", "NamesService", "NamesTarget", "NamesExtras" }
local NIL = "<nil>" -- (the kit's undo mark for a setting that was unset)

local function Data()
	CinematicDB.gatingTestData = CinematicDB.gatingTestData or {}
	return CinematicDB.gatingTestData
end

local function Secret(v) return issecretvalue ~= nil and issecretvalue(v) end
local function Try(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok and not Secret(a) then return a, b end
end

-- Everything that reads settings once picks the change up, as a profile
-- switch does (Profiles.lua's ns.SettingsChanged), a tab's own hooks run as
-- its right-click does (Options.lua's ns.tabSwitchHooks), the feature loops
-- look again at once instead of within the second.
local function TabHooks(key, value)
	for prefix, fn in pairs(ns.tabSwitchHooks or {}) do
		if key:sub(1, #prefix) == prefix then pcall(fn, value) end
	end
end
local function Refresh()
	if ns.SettingsChanged then pcall(ns.SettingsChanged) end
	if ns.SyncFeatureLoops then pcall(ns.SyncFeatureLoops) end
end

-- Settings changed (r:Set, so put back at the end), picked up once, then a
-- wait for the passes that run once a second or two.
local function Apply(r, changes, wait)
	for _, change in ipairs(changes) do
		r:Set(change[1], change[2])
		TabHooks(change[1], change[2])
	end
	Refresh()
	if wait and wait > 0 then r:Sleep(wait) end
end

-- The setting as it was before the run (the kit's undo), to put a step's
-- changes back before the next step.
local function Before(r, key)
	local undo = CinematicDB[r.def.key .. "Undo"]
	local value = undo and undo.settings and undo.settings[key]
	if value == NIL then return nil end
	if value == nil then return ns.db[key] end
	return value
end
local function PutBackKeys(r, keys, wait)
	local changes = {}
	for _, key in ipairs(keys) do changes[#changes + 1] = { key, Before(r, key) } end
	Apply(r, changes, wait)
end

-- Every update loop that ran for seconds (Diagnostics.lua's ns.loopAudit):
-- label ("File.lua:line", hooks marked "(hook)") -> { calls, ms }.
local function Loops(r, seconds)
	if ns.loopAudit then r:Log("loops: another measure going, none read") return {} end
	ns.loopAudit = {}
	r:Sleep(seconds)
	local audit = ns.loopAudit or {}
	ns.loopAudit = nil
	return audit
end
local function FileOf(label) return type(label) == "string" and label:match("([%w_]+%.lua)") or nil end
-- The running loops of these files (name -> true, or { from, to } lines), hooks
-- on the game's frames apart (they can't be taken off; they return at once).
local function Running(audit, files)
	local list = {}
	for label, row in pairs(audit) do
		local file = FileOf(label)
		local want = file and files[file]
		if want and not label:find("(hook)", 1, true) then
			local line = tonumber(label:match("%.lua:(%d+)"))
			if want == true or (type(want) == "table" and line and line >= want[1] and line <= want[2]) then
				list[#list + 1] = ("%s x%d"):format(label, row.calls or 0)
			end
		end
	end
	table.sort(list)
	return list
end
local function AllLabels(audit)
	local list = {}
	for label, row in pairs(audit) do list[#list + 1] = ("%s x%d"):format(label, row.calls or 0) end
	table.sort(list)
	return #list > 0 and table.concat(list, ", ") or "none"
end
local function Joined(list) return #list > 0 and table.concat(list, ", ") or "none" end
local function PartFiles(part)
	local set = {}
	for file in pairs(ns.ModuleFiles and ns.ModuleFiles(part) or {}) do set[file] = true end
	return set
end

-- The game settings Cinematic holds now whose set's name or reason has the
-- words (ns.cvarSets), and whether one is saved as held (savedCVars).
local function ActiveSets(pattern)
	local list = {}
	for _, set in ipairs(ns.cvarSets or {}) do
		if set.active and (tostring(set.label):find(pattern) or tostring(set.why):find(pattern)) then
			list[#list + 1] = tostring(set.label)
		end
	end
	return list
end
local function Saved(cvar) return ns.db.savedCVars and ns.db.savedCVars[cvar] end

-- What a command or key into code said (ns.Print), and whether it errored.
local function Said(fn, ...)
	local said
	local print0 = ns.Print
	ns.Print = function(text) said = tostring(text) end
	local ok, err = pcall(fn, ...)
	ns.Print = print0
	return ok, said or (not ok and tostring(err)) or nil
end

local function CineOn(r, want)
	if not (ns.IsCineModeOn and Cinematic_ToggleCineMode) then return false end
	r.cineAllowed = want or nil
	if ns.IsCineModeOn() ~= want then pcall(Cinematic_ToggleCineMode) end
	return ns.IsCineModeOn() == want
end

-- Nameplates up now: { plate, unit, kind, alpha } (kind as Effects.lua's
-- PlateKind sorts them, friendly ones only: what a town has).
local function Plates()
	local list = {}
	local get = C_NamePlate and C_NamePlate.GetNamePlates
	local ok, plates = pcall(get or function() return {} end)
	for _, plate in ipairs(ok and type(plates) == "table" and plates or {}) do
		local unit = plate.namePlateUnitToken
		local frame = plate.UnitFrame
		if unit and frame and (not ns.Reachable or ns.Reachable(frame)) then
			local friend, player = Try(UnitIsFriend, "player", unit), Try(UnitIsPlayer, unit)
			local controlled = Try(UnitPlayerControlled, unit)
			local kind = friend and (player and "Friends" or (not controlled and "FriendlyNPCs")) or nil
			local alpha = Try(function() return math.min(frame:GetAlpha(), plate:GetAlpha()) end)
			list[#list + 1] = { plate = plate, unit = unit, kind = kind, alpha = alpha }
		end
	end
	return list
end

-- Font strings on the XP bar (QoL/XpLeft.lua's frames) that end in "(N left)".
local XP_FRAMES = { "StatusTrackingBarManager", "MainStatusTrackingBarContainer", "MainMenuExpBar",
	"MainMenuBarOverlayFrame", "MainMenuBarExpText" }
local function XpLeftShown()
	local suffix = L["(%s left)"]:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0"):gsub("%%%%s", "[%%d%%p ]+") .. "$"
	local found, seen = 0, {}
	local function Walk(object, depth)
		if not object or seen[object] or depth > 4 then return end
		seen[object] = true
		if not object.GetObjectType then return end
		local okType, kind = pcall(object.GetObjectType, object)
		if not okType then return end
		if kind == "FontString" then
			local text = Try(object.GetText, object)
			if type(text) == "string" and text:find(suffix) then found = found + 1 end
			return
		end
		for _, region in ipairs({ Try(function() return object:GetRegions() end) }) do Walk(region, depth + 1) end
		for _, child in ipairs({ Try(function() return object:GetChildren() end) }) do Walk(child, depth + 1) end
	end
	for _, name in ipairs(XP_FRAMES) do pcall(Walk, _G[name], 0) end
	return found
end

-- A Lua error entry naming these words (the red window's, ns.DevErrorEntries).
local function ErrorsNaming(words)
	local n = 0
	for _, entry in ipairs(ns.DevErrorEntries and ns.DevErrorEntries() or {}) do
		if tostring(entry.message):find(words, 1, true) or tostring(entry.stack):find(words, 1, true) then
			n = n + (entry.count or 1)
		end
	end
	return n
end

-- Every setting with a switch over it, and the chain of switches up (10 steps).
local function Tree()
	local keys, seen = {}, {}
	local function Add(key)
		if type(key) == "string" and not seen[key] then
			seen[key] = true
			local up, steps, chain = ns.PageSwitchOf(key), 0, {}
			while up and steps < 10 do
				chain[#chain + 1] = up
				up, steps = ns.PageSwitchOf(up), steps + 1
			end
			if #chain > 0 then keys[#keys + 1] = { key = key, chain = chain } end
		end
	end
	for key in pairs(ns.DEFAULTS or {}) do Add(key) end
	for key in pairs(ns.db or {}) do Add(key) end
	return keys
end

ns.TestKit.Define({
	name = "gating",
	key = "gatingTest",
	title = "Gating audit fixes",
	about = "the 2026-11-25 gating fixes in game: every switch off, nothing of it runs or shows; one Reload click",
	needs = "Out of combat, anywhere (a town with NPCs is best: their plates are read)",
	-- (Leaves Visions, Cameras, Style, Atmosphere wanted but not loaded till
	-- a reload: the queue runs it last, Q.Order.)
	leavesPartsOut = true,
	settings = { "styleGeneral", "visualEffects", "cameraModes", "handleFrames", "handlePlates", "handleNames",
		"handleQuality", "handleBubbles", "handleTooltips", "mouseover", "showInChat", "handleCooldowns" },
	cvars = { "chatBubbles", "chatBubblesParty", "farclip", "horizonStart", "Sound_MusicVolume", "weatherDensity",
		"enableFloatingCombatText", "test_cameraOverShoulder", "CameraKeepCharacterCentered" },
	-- (The fixes' files, from the cards' Code lines: their errors are this test's.)
	files = { "Core.lua", "Frames.lua", "Effects.lua", "Graphics.lua", "Options.lua", "Modules.lua", "Conflicts.lua",
		"UI/Bubbles.lua", "UI/Chat.lua", "UI/ChatCopy.lua", "UI/TooltipParts.lua", "UI/CooldownRing.lua",
		"UI/CooldownStacks.lua", "UI/CooldownGrid.lua", "UI/NodeSweep.lua", "UI/WhyFeatures.lua",
		"Support/QuestieMinimap.lua", "Support/DaylightUI.lua", "Plates/PlateParts.lua", "Plates/PlateThemes.lua",
		"Plates/PlateGuild.lua", "Style/StylePages.lua", "Style/SelfTextStyle.lua", "Style/CombatTextStyle.lua",
		"Style/CombatTextPage.lua", "Style/RaidStyle.lua", "Style/UnitStyle.lua", "Style/ActionBarStyle.lua",
		"Style/TooltipStyle.lua", "Style/UnitAuraLift.lua", "Style/MinimapStyle.lua", "Style/MirrorTimerStyle.lua",
		"Atmosphere/Tint.lua", "Atmosphere/Letterbox.lua", "Atmosphere/Music.lua", "Atmosphere/Focus.lua",
		"Atmosphere/WeatherFX.lua", "Atmosphere/LowHealth.lua", "Visions/EmoteVision.lua", "Visions/QuestTalk.lua",
		"Visions/QuestMobs.lua", "Visions/QuestItemButton.lua", "Visions/SleepingBag.lua", "Visions/CardMoments.lua",
		"Visions/CombatVision.lua", "Visions/Recap.lua", "Visions/DamageVision.lua", "Visions/RollWindow.lua",
		"Camera/Camera.lua", "Camera/CameraRows.lua", "Camera/CameraScripts.lua", "Camera/ChatCam.lua",
		"Camera/CustomTriggers.lua", "Camera/QuestCam.lua", "Camera/ShoulderCam.lua", "Camera/SkyrideCam.lua",
		"Camera/Triggers.lua", "Camera/ZoomGuard.lua", "QoL/Campfire.lua", "QoL/CenterPanels.lua", "QoL/Hunter.lua",
		"QoL/HunterAmmo.lua", "QoL/MarkerWheel.lua", "QoL/Reload.lua", "Profiles/Profiles.lua", "Dev/MouseTurn.lua" },
	context = function()
		local parts = {}
		for _, part in ipairs(PARTS) do
			parts[#parts + 1] = ("%s %s"):format(part, ns.ModuleLoaded(part) and "loaded"
				or (ns.ModuleWanted(part) and "not loaded" or "left out"))
		end
		local off, all = 0, 0
		if ns.FeatureLoopsOff then off, all = ns.FeatureLoopsOff() end
		return ("parts: %s; feature loops off %d of %d; plates up %d; class %s; pole %s"):format(table.concat(parts, ", "),
			off, all, #Plates(), tostring(select(2, UnitClass("player"))),
			tostring(Try(function() return GetInventoryItemID("player", 16) end)))
	end,
	-- (Stopped in the CineMode step: CineMode off again first; the kit puts it
	-- back on after, if it was on at the start.)
	finish = function(run) if run.cineAllowed then CineOn(run, false) end end,
	-- (The Load boxes on again, from the next /reload; everything that reads
	-- settings once given the put-back ones, as a profile switch does.)
	putBack = function(extra)
		local said = {}
		if extra.partsOut then
			local back = {}
			for _, part in ipairs(PARTS) do
				if ns.ModuleWanted and not ns.ModuleWanted(part) then
					ns.SetModuleWanted(part, true)
					back[#back + 1] = part
				end
			end
			if #back > 0 then said[#said + 1] = "Load " .. table.concat(back, ", ") .. " on again (from the next /reload)" end
		end
		if extra.errorsAlpha and _G.UIErrorsFrame then pcall(_G.UIErrorsFrame.SetAlpha, _G.UIErrorsFrame, 1) end
		Refresh()
		CinematicDB.gatingTestData = nil
		said[#said + 1] = "settings applied as a profile switch does"
		return table.concat(said, "; ")
	end,
	steps = {
		-- 1 ---------------------------------------------------------------
		{ key = "gates", title = "every switch off: everything under it reads off", run = function(r)
			if not (ns.PageSwitchOf and ns.MasterOff and ns.PageOn and ns.Setting and ns.PageSetting) then
				return r:Skip("the gate functions aren't there")
			end
			local tree = Tree()
			-- (The tree's shape as it is with every part loaded: step 11 compares.
			-- Tab switches' keys apart: their pages hang theirs as they're built.)
			local data = Data()
			data.tree = {}
			for _, each in ipairs(tree) do
				if not each.key:find("^tabOn:") and not each.chain[1]:find("^tabOn:") then
					data.tree[each.key] = each.chain[1]
				end
			end
			local under = {}
			for _, each in ipairs(tree) do
				for _, master in ipairs(each.chain) do
					under[master] = under[master] or {}
					table.insert(under[master], each.key)
				end
			end
			local masters, wrong, checked = {}, {}, 0
			for master in pairs(under) do masters[#masters + 1] = master end
			table.sort(masters)
			local db = ns.db
			for i, master in ipairs(masters) do
				-- (Off for a moment, read, put back in the same frame: nothing runs between.)
				local was = db[master]
				local ok, err = pcall(function()
					db[master] = false
					for _, key in ipairs(under[master]) do
						if db[key] ~= false and db[key] ~= nil then
							checked = checked + 1
							local masterOff, pageOn = ns.MasterOff(key), ns.PageOn(key)
							local setting, pageSetting = ns.Setting(key), ns.PageSetting(key)
							local styleOn = ns.StyleOn and ns.StyleOn(key) or false
							if not masterOff or pageOn or setting or pageSetting or styleOn then
								wrong[#wrong + 1] = ("%s under %s: MasterOff %s PageOn %s Setting %s PageSetting %s StyleOn %s")
									:format(key, master, tostring(masterOff), tostring(pageOn), tostring(setting),
									tostring(pageSetting), tostring(styleOn))
							end
						end
					end
				end)
				db[master] = was
				if not ok then wrong[#wrong + 1] = master .. ": " .. tostring(err) end
				if i % 40 == 0 then r:Sleep(0) end
			end
			r:Log(("%d switches with settings under them, %d settings read off with one switch off"):format(#masters, checked))
			for i = 1, math.min(12, #wrong) do r:Log("  disagree: " .. wrong[i]) end
			r:Verdict(#wrong == 0 and checked > 0, ("every gate agrees a setting under an off switch is off: %d disagree"):format(#wrong))
			-- C9: the ten Style page keys under Enable Style.
			local loose = {}
			local was = db.styleGeneral
			pcall(function()
				db.styleGeneral = false
				for _, key in ipairs(STYLE_KEYS) do
					local chained = false
					local up, steps = ns.PageSwitchOf(key), 0
					while up and steps < 10 do
						if up == "styleGeneral" then chained = true end
						up, steps = ns.PageSwitchOf(up), steps + 1
					end
					if not chained or not ns.MasterOff(key) or ns.PageOn(key) or ns.Setting(key)
						or (ns.StyleOn and ns.StyleOn(key)) then
						loose[#loose + 1] = key .. (chained and "" or " (not under Enable Style)")
					end
				end
			end)
			db.styleGeneral = was
			r:Verdict(#loose == 0, "C9: Enable Style off, the ten Style page keys read off by all: " .. Joined(loose))
			-- Tab switches the pages made: counted, and their settings under them.
			local tabs, empty = 0, {}
			for _, each in ipairs(ns.tabContainers or {}) do
				tabs = tabs + 1
				if not under[each.key] then empty[#empty + 1] = each.key end
			end
			r:Log(("tab switches made: %d; with no setting under them (tabs of one list, a preview): %s"):format(tabs,
				Joined(empty)))
		end },
		-- 2 ---------------------------------------------------------------
		{ key = "hud", title = "HUD: bubbles, tooltips, gamepad, CDM, minimap, errors", run = function(r)
			-- C12: Chat Bubbles' game settings let go with Chat's Show tab or the HUD off.
			if ns.ApplyBubbles and GetCVar("chatBubbles") ~= nil then
				Apply(r, { { "handleBubbles", true }, { "showInChat", true }, { "handleFrames", true } }, 2.5)
				local yours = Saved("chatBubbles")
				r:Verdict(yours ~= nil, ("on: the page holds chatBubbles (yours saved: %s, now %s)"):format(tostring(yours),
					tostring(GetCVar("chatBubbles"))))
				for _, off in ipairs({ "showInChat", "handleFrames" }) do
					Apply(r, { { off, false } }, 2.5)
					local audit = Loops(r, 2.2)
					-- (The page's own loop only: its settings ticker, Bubbles.lua ~1015. The
					-- bubble watcher further down, ~1057-1062, is also Bubble Style's, a
					-- Style page of its own, and runs as people talk: run 3 saw it x15.)
					local running = Running(audit, { ["Bubbles.lua"] = { 990, 1030 } })
					r:Verdict(Saved("chatBubbles") == nil and Saved("chatBubblesParty") == nil
						and (yours == nil or GetCVar("chatBubbles") == yours) and #running == 0,
						("%s off: chatBubbles %s (yours %s), still saved %s, the page's loop: %s"):format(off,
						tostring(GetCVar("chatBubbles")), tostring(yours), tostring(Saved("chatBubbles")), Joined(running)))
					Apply(r, { { off, true } }, 2.5)
					r:Verdict(Saved("chatBubbles") ~= nil, off .. " on again: the page holds chatBubbles again")
				end
				r:Skip("C12 speech from behind you with Chat's Show off: needs someone talking behind you")
				PutBackKeys(r, { "handleBubbles", "showInChat", "handleFrames" }, 2.5)
			else
				r:Skip("no chat bubbles here")
			end
			-- C13: tooltips don't fade with Mouseover's Show off.
			local tip = _G.GameTooltip
			if ns.noRealLayout then
				r:Skip("C13 the tooltip's fade: offline, the stand-in's frames keep no alpha")
			elseif tip and tip.SetOwner then
				local function Shown()
					tip:Hide()
					r:Sleep(1.2) -- (past the tooltip's keep-up time)
					tip:SetOwner(UIParent, "ANCHOR_NONE")
					tip:ClearAllPoints()
					tip:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
					tip:SetText("Gating test")
					tip:Show()
					r:Sleep(0.25)
					local alpha = Try(tip.GetAlpha, tip)
					tip:Hide()
					return alpha
				end
				Apply(r, { { "handleTooltips", true }, { "mouseover", true }, { "tooltipFadeTime", 2 } }, 0.5)
				local on = Shown()
				Apply(r, { { "mouseover", false } }, 0.5)
				local off = Shown()
				r:Verdict(type(on) == "number" and on < 0.9, ("Mouseover's Show on: the tooltip fades in (alpha %s at 0.25 s)"):format(
					tostring(on)))
				r:Verdict(type(off) == "number" and off >= 0.99, ("C13 Mouseover's Show off: no fade (alpha %s at 0.25 s)"):format(
					tostring(off)))
				PutBackKeys(r, { "handleTooltips", "mouseover", "tooltipFadeTime" }, 0.3)
			else
				r:Skip("no GameTooltip here")
			end
			-- C7: Gamepad's Show and Settings tabs.
			if ns.GroupHandled then
				local SHOW, SETTINGS = "tabOn:Gamepad/tab:1", "tabOn:Gamepad/tab:2"
				Apply(r, { { "handleGamepad", true }, { SHOW, true }, { SETTINGS, true } }, 0.3)
				local on, revealOn = ns.GroupHandled("gamepadbars"), ns.PageOn(SETTINGS)
				Apply(r, { { SHOW, false }, { SETTINGS, false } }, 0.3)
				local off, revealOff = ns.GroupHandled("gamepadbars"), ns.PageOn(SETTINGS)
				r:Verdict(on == true and off == false and revealOn and not revealOff,
					("C7 Gamepad: bars handled %s -> %s with Show off; press reveal %s -> %s with Settings off"):format(
					tostring(on), tostring(off), tostring(revealOn), tostring(revealOff)))
				r:Skip("C7 the real GamepadMainActionBarFrame let go on a live flip: needs the gamepad UI in CineMode")
				PutBackKeys(r, { "handleGamepad", SHOW, SETTINGS }, 0.3)
			end
			-- C8 / D13: a Cooldown Manager bar's tab and the page.
			if ns.CooldownGroupCentered and ns.CDM_TABS then
				local tab = ns.CDM_TABS.essential
				Apply(r, { { "handleCooldowns", true }, { tab, true } }, 0.3)
				local on, modeOn = ns.CooldownGroupCentered("essential"), ns.CooldownSpellMode(0, "essential")
				Apply(r, { { tab, false } }, 0.3)
				local off, modeOff = ns.CooldownGroupCentered("essential"), ns.CooldownSpellMode(0, "essential")
				r:Verdict(off == false and modeOff == "always", ("C8 Essential tab off: centered %s -> %s, mode %s -> %s"):format(
					tostring(on), tostring(off), tostring(modeOn), tostring(modeOff)))
				Apply(r, { { tab, true }, { "handleCooldowns", false } }, 1.5)
				local running = Running(Loops(r, 2), { ["CooldownRing.lua"] = true, ["CooldownStacks.lua"] = true })
				r:Verdict(#running == 0, "D13 page off: no ring or stacks loop: " .. Joined(running))
				r:Skip("C8 icons sliding back on a tab flip, stacks with Bars on and Buffs off: needs a look at your bars (a shot run) and a mage")
				PutBackKeys(r, { "handleCooldowns", tab }, 0.3)
			end
			-- Hover Groups (E3), Minimap's Show (minimap-gate), the frame scan (D5).
			Apply(r, { { "mouseover", false } }, 0.2)
			r:Verdict(not ns.PageOn("mouseover") and not ns.PageOn("handleTooltips"),
				"Hover Groups' page off: its groups and the tooltips under it read off")
			r:Skip("E3 the Death Cam's kept groups with the page off: needs a death")
			PutBackKeys(r, { "mouseover" }, 0.2)
			if ns.QuestieMinimapOn and ns.QuestieLoaded and ns.QuestieLoaded() then
				Apply(r, { { "handleMinimap", true }, { "showInMinimap", false } }, 0.3)
				r:Verdict(ns.QuestieMinimapOn() == false, "Minimap's Show off: Questie's pins left to Questie")
				PutBackKeys(r, { "handleMinimap", "showInMinimap" }, 0.3)
			else
				r:Skip("minimap-gate Questie's pins: needs Questie loaded")
			end
			if ns.AnyFramePageOn and ns.HANDLE_SWITCHES then
				Apply(r, { { "handleFrames", false } }, 0.2)
				local kept = {}
				for _, key in ipairs(ns.HANDLE_SWITCHES) do
					if ns.db[key] and ns.PageOn(key) then kept[#kept + 1] = key end
				end
				r:Verdict(ns.AnyFramePageOn() == (#kept > 0 or ns.frameForceOn and true or false),
					("D5 HUD off: the frame scan wanted %s (pages still on by their own tree: %s)"):format(
					tostring(ns.AnyFramePageOn()), Joined(kept)))
				PutBackKeys(r, { "handleFrames" }, 0.2)
			end
			-- E5: the error text's alpha left alone with both hide boxes off.
			local errors = _G.UIErrorsFrame
			if ns.noRealLayout then
				r:Skip("E5 the error text's alpha: offline, the stand-in's frames keep no alpha")
			elseif errors and ns.UpdateCVars then
				-- (ns.UpdateCVars waits between passes with nothing changed: run 1's
				-- calls all returned early, so the alpha never moved. Its wait cleared first.)
				local function UpdateNow()
					if ns.cvarsSeen then ns.cvarsSeen.at = -math.huge end
					return pcall(ns.UpdateCVars, false)
				end
				r:Keep("errorsAlpha", true)
				Apply(r, { { "hideErrorsInCombat", false }, { "hideErrorsOutOfCombat", false } }, 0.2)
				UpdateNow()
				errors:SetAlpha(0.5) -- (as another addon hiding it would)
				UpdateNow()
				r:Sleep(1)
				local kept = Try(errors.GetAlpha, errors)
				-- (Both boxes: the pass picks In combat's during the Calm Timer after a
				-- fight too (ns.FightLingering), and run 8's probe showed the pass ran with
				-- Out of combat's ticked yet nothing hidden: a fight just over, in Elwynn.)
				Apply(r, { { "hideErrorsInCombat", true }, { "hideErrorsOutOfCombat", true } }, 0.2)
				local passOk, passErr = UpdateNow()
				local hidden = Try(errors.GetAlpha, errors)
				-- (Run 7: hidden stayed 0.5 as in run 1, after runs 3-6 passed. Why, if so.)
				r:Log(("probe E5 ticked: the pass ran %s%s; hide setting %s, Quality of life %s, enabled %s, fight %s, by us %s")
					:format(tostring(passOk), passOk and "" or (" (" .. tostring(passErr) .. ")"),
					tostring(ns.Setting("hideErrorsOutOfCombat")), tostring(ns.db.handleQuality), tostring(ns.db.enabled),
					tostring(InCombatLockdown()), tostring(ns.errorsHiddenByUs))
					.. (" Calm Timer %s"):format(tostring(ns.FightLingering and ns.FightLingering() or false)))
				Apply(r, { { "hideErrorsInCombat", false }, { "hideErrorsOutOfCombat", false } }, 0.2)
				UpdateNow()
				local back = Try(errors.GetAlpha, errors)
				r:Verdict(kept and math.abs(kept - 0.5) < 0.01 and hidden == 0 and back == 1,
					("E5 both boxes off: another addon's 0.5 kept (%s); ticked, hidden (%s); unticked, ours back to 1 (%s)"):format(
					tostring(kept), tostring(hidden), tostring(back)))
				errors:SetAlpha(1)
				PutBackKeys(r, { "hideErrorsInCombat", "hideErrorsOutOfCombat" }, 0.2)
				UpdateNow()
				r:Skip("E5 the real error frame in a fight: needs a fight")
			end
		end },
		-- 3 ---------------------------------------------------------------
		{ key = "cine", title = "in CineMode: plates, names and typing with their tabs off", run = function(r)
			-- (Cameras off first: CineMode starts no scene camera for the test.)
			-- (And the Nameplates and Names pages on, so their tabs have rows to switch off.)
			Apply(r, { { "cameraModes", false }, { "handlePlates", true }, { "handleNames", true } }, 0.5)
			if not CineOn(r, true) then
				r:Skip("CineMode didn't come on: the plates and names in CineMode aren't read")
				PutBackKeys(r, { "cameraModes", "handlePlates", "handleNames" }, 0.3)
				return
			end
			r:Sleep(3)
			-- C1: the Names tabs off: no names set of ours held.
			local names = {}
			for _, tab in ipairs(NAME_TABS) do names[#names + 1] = { "tabOn:Nameplates:" .. tab, false } end
			local heldBefore = ActiveSets("^Names:")
			Apply(r, names, 2.5)
			-- (Interactive NPCs' names stay off wherever CineMode keeps every
			-- plate on: the plates' doing, not a row's, the card says.)
			local heldOff = {}
			for _, label in ipairs(ActiveSets("^Names:")) do
				if label ~= "Names: interactive NPCs" then heldOff[#heldOff + 1] = label end
			end
			r:Verdict(#heldOff == 0, ("C1 every Names tab off: names left to the game (ours held: %s; with them on: %s)"):format(
				Joined(heldOff), Joined(heldBefore)))
			local tabsOn = {}
			for _, tab in ipairs(NAME_TABS) do tabsOn[#tabsOn + 1] = "tabOn:Nameplates:" .. tab end
			PutBackKeys(r, tabsOn, 2)
			-- C1: the Enemy and Friendly tabs off: plates as the game shows them.
			local before = Plates()
			local function Fronts(list)
				local frames = {}
				for i = 1, math.min(8, #list) do frames[i] = list[i].plate end
				return frames
			end
			if #before == 0 then
				r:Skip("C1 plates' alphas: needs nameplates near you (a town's NPCs)")
			else
				Apply(r, { { "tabOn:Nameplates:Enemy", false }, { "tabOn:Nameplates:Friendly", false } }, 2.5)
				local wrong, read = {}, 0
				for _, p in ipairs(Plates()) do
					if p.kind and type(p.alpha) == "number" and ns.plates and ns.plates.OwnKindShown then
						read = read + 1
						local own = ns.plates.OwnKindShown(p.kind)
						if (own and p.alpha < 0.95) or (not own and p.alpha > 0.05) then
							wrong[#wrong + 1] = ("%s %s alpha %.2f (your setting shows it: %s)"):format(p.kind,
								tostring(p.unit), p.alpha, tostring(own))
						end
					end
				end
				if read > 0 then
					r:Verdict(#wrong == 0, ("C1 Enemy and Friendly off: %d friendly plates as your game settings show them; wrong: %s")
						:format(read, Joined(wrong)))
				else
					r:Skip("C1 plates' alphas: needs friendly plates near you")
				end
				r:Shot("plates, Enemy and Friendly tabs off (the game's look)", { behind = Fronts(Plates()) })
				PutBackKeys(r, { "tabOn:Nameplates:Enemy", "tabOn:Nameplates:Friendly" }, 2.5)
				local alphas = {}
				for _, p in ipairs(Plates()) do alphas[#alphas + 1] = ("%s %s"):format(tostring(p.kind), tostring(p.alpha)) end
				r:Log("tabs on again, plates: " .. Joined(alphas))
				r:Shot("plates, tabs on again (your rows)", { behind = Fronts(Plates()) })
			end
			r:Skip("C1 real plates' alphas in a fight, forced plates with your own enemy plates off: needs a fight")
			-- D15: plate parts rest with the Nameplates page off.
			-- (The target marks are Nameplate Style's Smart page's, not this page's: their
			-- When loop runs with Nameplates off while they're wanted, so Smart off too.)
			-- (3 s: the marks fade out over the fade time, 1.5 s, and a loop is asked
			-- once a second whether it's still wanted: run 2 caught its last pass.)
			Apply(r, { { "handlePlates", false }, { "plateMarks", false } }, 3)
			local running = Running(Loops(r, 2), { ["PlateParts.lua"] = true })
			r:Verdict(#running == 0, "plate-parts-idle Nameplates off: no plate parts loop: " .. Joined(running))
			Apply(r, { { "handlePlates", true } }, 1)
			PutBackKeys(r, { "plateMarks" }, 0.5)
			-- C6: Chat's Conversations tab off: typing doesn't bring the windows up.
			local chat, open = _G.ChatFrame1, _G.ChatFrame_OpenChat
			local function Close()
				local box = _G.ChatEdit_GetActiveWindow and _G.ChatEdit_GetActiveWindow()
				if box and _G.ChatEdit_DeactivateChat then pcall(_G.ChatEdit_DeactivateChat, box) end
			end
			if chat and open then
				local TAB = "tabOn:Chat/page:2"
				Apply(r, { { "handleFrames", true }, { "handleChat", true }, { TAB, false }, { "chatShowWhileTyping", true } }, 2)
				-- (A chat line coming in peeks the window up whatever the typing does:
				-- run 4, in Elwynn, saw it at 0.64. Lines counted while typing; with one,
				-- tried again, up to 3 times, after the peek has gone.)
				local lines = 0
				local counter = CreateFrame("Frame")
				for _, event in ipairs({ "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE",
					"CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_MONSTER_EMOTE", "CHAT_MSG_CHANNEL",
					"CHAT_MSG_WHISPER", "CHAT_MSG_GUILD", "CHAT_MSG_PARTY", "CHAT_MSG_SYSTEM", "CHAT_MSG_LOOT" }) do
					pcall(counter.RegisterEvent, counter, event)
				end
				counter:SetScript("OnEvent", function() lines = lines + 1 end)
				local idle, off
				for try = 1, 3 do
					idle = Try(chat.GetAlpha, chat)
					lines = 0
					pcall(open, "")
					r:Sleep(1.5)
					off = Try(chat.GetAlpha, chat)
					Close()
					if lines == 0 then break end
					r:Log(("C6 try %d: %d chat line(s) came in while typing (chat %s): again"):format(try, lines, tostring(off)))
					r:Sleep(4) -- (the peek gone)
				end
				counter:UnregisterAllEvents()
				counter:SetScript("OnEvent", nil)
				Apply(r, { { TAB, true } }, 0.2)
				pcall(open, "")
				r:Sleep(1.5)
				local on = Try(chat.GetAlpha, chat)
				Close()
				if lines > 0 then
					r:Skip(("C6 typing with the tab off: chat lines kept coming in (%d in the last try): needs a quiet spot"):format(lines))
				elseif type(idle) ~= "number" or idle >= 0.99 then
					r:Skip(("C6 typing with the tab off: your Chat row shows the chat in CineMode (alpha %s), nothing to tell apart")
						:format(tostring(idle)))
				else
					r:Verdict(type(off) == "number" and off <= idle + 0.05 and type(on) == "number" and on >= 0.99,
						("C6 Conversations off: typing leaves the chat at %s (idle %s); on: up to %s"):format(tostring(off),
						tostring(idle), tostring(on)))
				end
				PutBackKeys(r, { "handleFrames", "handleChat", TAB, "chatShowWhileTyping" }, 0.5)
			else
				r:Skip("C6: no chat window or ChatFrame_OpenChat here")
			end
			CineOn(r, false)
			PutBackKeys(r, { "cameraModes", "handlePlates", "handleNames" }, 0.5)
		end },
		-- 4 ---------------------------------------------------------------
		{ key = "style", title = "Style: Enable Style, Text on You, Combat Text, Bubble Style tabs", run = function(r)
			if not ns.ModuleLoaded("style") then return r:Skip("Style isn't loaded") end
			local frames = {}
			for _, name in ipairs({ "PlayerFrame", "MainMenuBar", "MainActionBar" }) do
				local frame = _G[name]
				if frame and frame.IsVisible and frame:IsVisible() then frames[#frames + 1] = frame end
			end
			-- Enable Style off: no Style loop, no game setting held for a Style page.
			Apply(r, { { "styleGeneral", false } }, 3)
			-- (Nameplate Layout's flush too: run 2 saw it x8 here, its hidden level
			-- boxes kept from before Style went off; 11e50fe: none with Style off.)
			local styleFiles = PartFiles("style")
			local running = Running(Loops(r, 4.5), styleFiles)
			r:Verdict(#running == 0, "Enable Style off: no loop of Style's files: " .. Joined(running))
			local held = ActiveSets("Combat Text Style")
			if ns.SELF_TEXT_GAME_ON and ns.SELF_TEXT_GAME_ON.active then held[#held + 1] = "Text on You's floating text" end
			r:Verdict(#held == 0, "Enable Style off: no game setting held for a Style page: " .. Joined(held))
			if ns.PlateThemeExtras then
				local shape, ground = ns.PlateThemeExtras("Enemies")
				r:Verdict(shape == nil and ground == nil, ("C10 the plate theme's shape and ground gone: %s, %s"):format(
					tostring(shape), tostring(ground)))
			end
			r:Shot("Enable Style off: the game's look", { behind = frames })
			PutBackKeys(r, { "styleGeneral" }, 3)
			r:Shot("Enable Style back on: your look", { behind = frames })
			-- C3: Text on You's General tab off lets the game's floating text go.
			if ns.SELF_TEXT_GAME_ON then
				local TAB = "tabOn:Self Text Style/page:1"
				Apply(r, { { "styleGeneral", true }, { "selfTextStyle", true }, { TAB, true } }, 2.5)
				local on = ns.SELF_TEXT_GAME_ON.active and true or false
				Apply(r, { { TAB, false } }, 2.5)
				local off = ns.SELF_TEXT_GAME_ON.active and true or false
				r:Verdict(not off, ("C3 Text on You's General tab off: the game's floating text let go (held %s -> %s, now %s)"):format(
					tostring(on), tostring(off), tostring(GetCVar("enableFloatingCombatText"))))
				PutBackKeys(r, { "styleGeneral", "selfTextStyle", TAB }, 2.5)
			end
			-- C4: Combat Text Style's General tab off: the game's numbers back.
			do
				local TAB = "tabOn:Combat Text Style/page:1"
				Apply(r, { { "styleGeneral", true }, { "combatTextStyle", true }, { TAB, true } }, 3)
				local on = ActiveSets("Combat Text Style")
				Apply(r, { { TAB, false } }, 3)
				local off = ActiveSets("Combat Text Style")
				r:Verdict(#off == 0, ("C4 Combat Text Style's General tab off: none of the game's number settings held (on: %s; off: %s)")
					:format(Joined(on), Joined(off)))
				r:Skip("C4 the game's world text font at the next login with the tab off: needs a login with it off")
				PutBackKeys(r, { "styleGeneral", "combatTextStyle", TAB }, 3)
			end
			-- C2: a Style page's tab off gives its look back (Bubble Style's Bubbles tab).
			if ns.StyleLook then
				local TAB = "tabOn:Bubble Style/page:1"
				local built = ns.settingsCanvases and ns.settingsCanvases["Bubble Style"] ~= nil
				Apply(r, { { "styleGeneral", true }, { "bubblesStyle", true }, { "bubblesBack", "dark" }, { TAB, true } }, 0.2)
				local on = ns.StyleLook("bubblesStyle").bubblesBack
				Apply(r, { { TAB, false } }, 0.2)
				local off = ns.StyleLook("bubblesStyle").bubblesBack
				if not built then
					r:Log(("Bubble Style not built yet (made on first open): tab off reads %s (F3: tabs map their rows as the page is made)")
						:format(tostring(off)))
					for _, entry in ipairs(ns.lazySettingsPages or {}) do
						if not entry.made and entry.Make and (entry.name == "Bubble Style"
							or entry.name == L["Chat Bubble Style"]) then
							pcall(entry.Make, "gating test")
						end
					end
					r:Sleep(0.3)
					off = ns.StyleLook("bubblesStyle").bubblesBack
				end
				r:Verdict(on == "dark" and off == ns.DEFAULTS.bubblesBack, ("C2 Bubble Style's Bubbles tab off: the look's background %s -> %s (default %s)")
					:format(tostring(on), tostring(off), tostring(ns.DEFAULTS.bubblesBack)))
				r:Skip("C2 bubbles redrawn live on the tab's right-click: needs a bubble on screen")
				PutBackKeys(r, { "styleGeneral", "bubblesStyle", "bubblesBack", TAB }, 0.3)
			end
			r:Skip("D2 raid frames put back on Raid Style's flip in a fight: needs a raid and a fight")
			r:Skip("style-page-watchers unit frames put back in a fight, Round glow's casts: needs a fight and casts")
			r:Skip("style-hooks-rest a held plate lift, the minimap ring's copy as its tint comes back: needs a look (a shot run)")
			r:Skip("C11 a plate's title line redrawn on Name Style's flip: needs a titled NPC's plate up")
		end },
		-- 5 ---------------------------------------------------------------
		{ key = "atmosphere", title = "Atmosphere: letterbox key, view distance, music, weather, loops", run = function(r)
			if not ns.ModuleLoaded("atmosphere") then return r:Skip("Atmosphere isn't loaded") end
			-- E1: the letterbox key with its page off.
			if Cinematic_ToggleLetterbox and ns.LetterboxExtra then
				Apply(r, { { "visualEffects", true }, { "letterboxPage", false } }, 0.3)
				local ok, said = Said(Cinematic_ToggleLetterbox)
				local extra = Try(ns.LetterboxExtra, false, false, false)
				r:Verdict(ok and said == L["letterbox bars: the Letterbox page is off"] and extra == false,
					("E1 page off: the key says %q, no bars (%s)"):format(tostring(said), tostring(extra)))
				Apply(r, { { "letterboxPage", true } }, 0.3)
				local ok2, said2 = Said(Cinematic_ToggleLetterbox)
				local extra2 = Try(ns.LetterboxExtra, false, false, false)
				local ok3, said3 = Said(Cinematic_ToggleLetterbox)
				local extra3 = Try(ns.LetterboxExtra, false, false, false)
				-- (The key flips the bars from what they are now: run 1 had them wanted
				-- already, so the first press took them off. Either way round, two presses flip.)
				r:Verdict(ok2 and ok3 and extra2 ~= nil and extra3 ~= nil and extra2 ~= extra3 and said2 ~= said3,
					("page on: the key %q (bars %s), again %q (bars %s)")
					:format(tostring(said2), tostring(extra2), tostring(said3), tostring(extra3)))
				r:Skip("E1 Ultra immersive with the page off: needs Chat Cam's Ultra immersive in a talk")
				PutBackKeys(r, { "visualEffects", "letterboxPage" }, 0.3)
			end
			-- D15 / atmosphere-idle-cost: the bad weather view distance's Preview, in and out, then its loop rests.
			if ns.PreviewRainView and GetCVar("farclip") ~= nil then
				Apply(r, { { "weatherPage", true }, { "rainViewScale", 1 } }, 0.3)
				local yours = GetCVar("farclip")
				ns.PreviewRainView(3)
				r:Sleep(1)
				local inNow = GetCVar("farclip")
				r:Sleep(4)
				local backNow = GetCVar("farclip")
				r:Sleep(1.5)
				local running = Running(Loops(r, 2.2), { ["Graphics.lua"] = { 370, 410 } })
				r:Verdict((tonumber(yours) or 0) <= 400 or tonumber(inNow) < tonumber(yours),
					("Preview: the view distance in (farclip %s -> %s)"):format(tostring(yours), tostring(inNow)))
				r:Verdict(backNow == yours and Saved("farclip") == nil and #running == 0,
					("Preview over: farclip back %s (yours %s), still saved %s; its loop: %s"):format(tostring(backNow),
					tostring(yours), tostring(Saved("farclip")), Joined(running)))
				r:Skip("C15 the view easing out as the Weather page goes off mid-rain: needs rain in CineMode")
				PutBackKeys(r, { "weatherPage", "rainViewScale" }, 1)
			end
			-- E2: the death song off with the Audio page.
			if ns.SetDeathSong then
				local logged
				local log0 = ns.DeathTestLog
				ns.DeathTestLog = function(text) logged = logged or text end
				Apply(r, { { "musicInCinematic", false } }, 0.2)
				pcall(ns.SetDeathSong, true)
				pcall(ns.SetDeathSong, false) -- (same frame: nothing plays)
				ns.DeathTestLog = log0
				r:Verdict(type(logged) == "string" and logged:find("death song: nil", 1, true) ~= nil,
					"E2 Audio page off: no death song picked: " .. tostring(logged))
				r:Skip("E2 dying with the page off and music on: needs a death")
				PutBackKeys(r, { "musicInCinematic" }, 0.2)
			end
			-- Visual Effects off: its loops rest, music and weather density let go.
			Apply(r, { { "visualEffects", false } }, 2.5)
			local running = Running(Loops(r, 2.5), { ["Focus.lua"] = true, ["WeatherFX.lua"] = true,
				["Graphics.lua"] = { 370, 410 } })
			r:Verdict(#running == 0, "Visual Effects off: no haze, weather or view distance loop: " .. Joined(running))
			r:Verdict(Saved("weatherDensity") == nil, "Visual Effects off: weather density not held: " ..
				tostring(Saved("weatherDensity")))
			r:Log(("music volume %s, held as yours: %s; Atmosphere's loops still up: %s"):format(
				tostring(GetCVar("Sound_MusicVolume")), tostring(Saved("Sound_MusicVolume")),
				Joined(Running(Loops(r, 1), PartFiles("atmosphere")))))
			PutBackKeys(r, { "visualEffects" }, 1)
			r:Skip("C16 frost, lens rain and lightning after a safety stop: needs rain or snow")
			r:Skip("D14 the haze loop where its Show in row says no: needs a camera mode in CineMode")
			r:Skip("B1 Graphics+ after Load Atmosphere unticked, Later, then a fight: needs a fight before the reload")
			r:Skip("style-page-gate the tint's live change on Enable Style's flip: needs CineMode with your own tint")
		end },
		-- 6 ---------------------------------------------------------------
		{ key = "visions", title = "Visions: every Vision page off, their loops rest", run = function(r)
			if not ns.ModuleLoaded("visions") then return r:Skip("Visions isn't loaded") end
			local changes = {}
			for _, key in ipairs(VISION_PAGES) do changes[#changes + 1] = { key, false } end
			Apply(r, changes, 2.5)
			local audit = Loops(r, 3)
			local running = Running(audit, { ["QuestTalk.lua"] = true, ["QuestItemButton.lua"] = true,
				["QuestMobs.lua"] = true, ["SleepingBag.lua"] = true, ["DamageVision.lua"] = true, ["RollWindow.lua"] = true,
				["EmoteVision.lua"] = true })
			r:Verdict(#running == 0, "every Vision off: no Quest Talk, quest item, quest mob, sleeping bag, damage, roll or emote loop: "
				.. Joined(running))
			r:Log("Visions' loops still up: " .. Joined(Running(audit, PartFiles("visions"))))
			r:Verdict(not ns.Setting("questVision") and not ns.Setting("emoteVision") and not ns.Setting("cards"),
				"Quest, Emote and Card Vision read off")
			PutBackKeys(r, VISION_PAGES, 2)
			r:Log("back on, Visions' loops: " .. Joined(Running(Loops(r, 2), PartFiles("visions"))))
			r:Skip("C19 the boss kill and wipe sounds with the Boss Sounds tab off: needs a boss")
			r:Skip("C20 the Last time line and the time of day at login with their tabs off: needs a login with them off")
			r:Skip("D18 health events not waking Vitals while it can't show: needs damage taken")
			r:Skip("D17 Eyes/Stalked stopping live, a resurrection offered while off: needs an emote watch and a death")
			r:Skip("D19 a quest item NPC losing its \"!\": needs an item quest")
			r:Skip("D22 another addon's roll frames, Damage Vision at a fight's end: needs a loot roll and a fight")
			r:Skip("D20 a stay in the sleeping bag with its row flipped: needs the bag (Forever)")
			r:Skip("D21 the explore count right after Discovered on: needs a zone change")
			r:Skip("D16 a quest talk right after CineMode comes on: needs a quest NPC")
		end },
		-- 7 ---------------------------------------------------------------
		{ key = "cameras", title = "Cameras: Enable Cameras off, Mouse Turn's tab, the fishing watch", run = function(r)
			if not ns.ModuleLoaded("cameras") then return r:Skip("Cameras isn't loaded") end
			local CAMERA_LOOPS = { ["CustomTriggers.lua"] = true, ["CameraScripts.lua"] = true, ["ZoomGuard.lua"] = true,
				["SkyrideCam.lua"] = true, ["QuestCam.lua"] = true, ["ChatCam.lua"] = true, ["Triggers.lua"] = true }
			Apply(r, { { "cameraModes", false } }, 2.5)
			local audit = Loops(r, 3)
			local running = Running(audit, CAMERA_LOOPS)
			r:Verdict(#running == 0, "Enable Cameras off: no trigger, script, zoom guard, Skyriding, Quest Cam or Chat Cam loop: "
				.. Joined(running))
			r:Log("Cameras' loops still up: " .. Joined(Running(audit, PartFiles("cameras"))))
			-- (Run 6: the scripts' watcher stayed on the whole sample; what held it.)
			if ns.CameraWatcherWhy then r:Log("probe camera watcher kept on by: " .. tostring(ns.CameraWatcherWhy())) end
			r:Verdict(ns.IsCameraOffHere and ns.IsCameraOffHere("idle") and true or false,
				"the AFK camera is off: " .. tostring(ns.CameraOffWhy and ns.CameraOffWhy("idle")))
			PutBackKeys(r, { "cameraModes" }, 1)
			-- C18: Mouse Turn's tab (dev copy).
			if ns.ModuleLoaded("cameras") then
				local TAB = "tabOn:Camera Settings:Mouse Turn"
				Apply(r, { { TAB, false } }, 1.5)
				local turning = Running(Loops(r, 2), { ["MouseTurn.lua"] = true })
				r:Verdict(#turning == 0, "C18 Mouse Turn's tab off: no turn speed loop: " .. Joined(turning))
				PutBackKeys(r, { TAB }, 0.5)
			end
			-- D11: the fishing watch with the Fishing page off.
			local item = Try(function() return GetInventoryItemID("player", 16) end)
			local classID, subclassID
			if item and C_Item and C_Item.GetItemInfoInstant then
				local got = { pcall(C_Item.GetItemInfoInstant, item) }
				if got[1] then classID, subclassID = got[7], got[8] end
			end
			if classID == 2 and subclassID == 20 then
				Apply(r, { { "handleFishing", false } }, 1.5)
				local fishing = Running(Loops(r, 2), { ["Camera.lua"] = { 1000, 1080 } })
				r:Verdict(#fishing == 0, "D11 Fishing page off, a pole on: no cast watch: " .. Joined(fishing))
				PutBackKeys(r, { "handleFishing" }, 0.5)
			else
				r:Skip("D11 the fishing watch with the page off: needs a fishing pole on")
			end
			r:Skip("C14 your own scenes' scripts and the camera wheel with Enable Cameras off: needs a key press (not asked: it would move the camera)")
			r:Skip("C5 a built-in trigger with its Starts tab off: needs a scene firing")
			r:Skip("D9 an NPC's line with Chat Cam off, a script's talk stop rule: needs an NPC talking")
			r:Skip("D12 the player copy's quest camera, gossip windows: needs a quest NPC")
			r:Skip("cameras-shoulder-allow-tab a flight path or a death with the tab off: needs a flight or a death")
			r:Skip("cameras-small-loops the zoom guard tripping, a Skyriding take-off: needs a zoom fight and skyriding")
			r:Skip("D7 your triggers' game events, a script scene ending as its page goes off: needs a trigger firing")
			r:Skip("qol-campfire-loop a cozy camera seeing a tent: needs a tent and Stand still set to cozy")
		end },
		-- 8 ---------------------------------------------------------------
		{ key = "qol", title = "Quality of life: XP text, wheel keys, Campfire and Hunter watches", run = function(r)
			-- C17: the XP bar's "(N left)" goes with the page.
			if ns.RefreshXpLeft then
				Apply(r, { { "handleQuality", true }, { "xpLeft", true } }, 1)
				local on = XpLeftShown()
				Apply(r, { { "handleQuality", false } }, 1)
				local off = XpLeftShown()
				if on == 0 then
					r:Skip("C17 the XP text: needs XP to earn and the bar's words shown (none with \"left\" seen)")
				else
					r:Verdict(off == 0, ("C17 Quality of life off: the XP bar's \"left\" words gone (%d -> %d)"):format(on, off))
				end
				PutBackKeys(r, { "handleQuality", "xpLeft" }, 1)
			end
			-- wheel-key-tab: the Wheels' key tab off: the menu wheel's key off.
			local wheel = _G.CinematicMenuWheel
			local key = ns.KeybindTabKey and ns.KeybindTabKey("CLICK CinematicMenuWheelButton:LeftButton")
			if ns.noRealLayout then
				r:Skip("wheel-key-tab: offline, the stand-in's frames keep no attributes")
			elseif wheel and key and ns.ApplyWheelSwitches and not InCombatLockdown() then
				Apply(r, { { key, true } }, 0.2)
				pcall(ns.ApplyWheelSwitches)
				local on = wheel:GetAttribute("cineoff")
				Apply(r, { { key, false } }, 0.2)
				pcall(ns.ApplyWheelSwitches)
				local off = wheel:GetAttribute("cineoff")
				r:Verdict(off and true or false, ("%s off: the menu wheel's key off (cineoff %s -> %s)"):format(key, tostring(on),
					tostring(off)))
				PutBackKeys(r, { key }, 0.2)
				pcall(ns.ApplyWheelSwitches)
			else
				r:Skip("wheel-key-tab: no menu wheel key tab here")
			end
			-- D1: the Campfire watch with nothing wanting it.
			if ns.ModuleLoaded("cameras") then
				Apply(r, { { "cameraModes", false } }, 2)
				local campfire = Running(Loops(r, 2), { ["Campfire.lua"] = true })
				local button = ns.CampfireButtonOn and ns.CampfireButtonOn()
				if button then
					r:Skip("D1 the Campfire watch: your sit button is on (it wants the watch)")
				else
					r:Verdict(#campfire == 0, "D1 Enable Cameras off, no sit button: no Campfire watch: " .. Joined(campfire))
				end
				PutBackKeys(r, { "cameraModes" }, 0.5)
			end
			-- D4: the hunter's right-click pull watch (Classic Era hunters).
			if select(2, UnitClass("player")) == "HUNTER" and not ns.isRetail then
				Apply(r, { { "handleHunter", false } }, 2)
				local hunter = Running(Loops(r, 2), { ["Hunter.lua"] = true })
				r:Verdict(#hunter == 0, "D4 Hunter page off: no right-click pull watch: " .. Joined(hunter))
				PutBackKeys(r, { "handleHunter" }, 0.5)
			else
				r:Skip("D4 the hunter's pull watch: needs a Classic Era hunter")
			end
			local audit = Loops(r, 2)
			r:Log("Reload key and Addon Conflicts loops now: " .. Joined(Running(audit, { ["Reload.lua"] = true,
				["Conflicts.lua"] = true })))
			r:Skip("D8 drag strips and rearranging with the page off: needs a window opened")
			r:Skip("qol-refresh the vendor's Fill buttons with the Hunter page off: needs a vendor open")
			r:Skip("qol-tickers the secure Reload key after a fight: needs a fight")
		end },
		-- 9 ---------------------------------------------------------------
		{ key = "alloff", title = "every page and part switch off at once", run = function(r)
			local keys = { "styleGeneral", "visualEffects", "cameraModes", "handleFrames", "handleAddonFrames", "handleGamepad",
				"handlePlates", "handleNames", "handleQuality", "handleHunter", "handleFishing", "handleBubbles",
				"handleTooltips", "mouseover" }
			for _, key in ipairs(VISION_PAGES) do keys[#keys + 1] = key end
			local changes = {}
			for _, key in ipairs(keys) do changes[#changes + 1] = { key, false } end
			Apply(r, changes, 4)
			local audit = Loops(r, 4)
			local files = { ["Bubbles.lua"] = true, ["Campfire.lua"] = true, ["Hunter.lua"] = true, ["PlateParts.lua"] = true,
				["CooldownRing.lua"] = true, ["CooldownStacks.lua"] = true }
			for _, part in ipairs(PARTS) do
				if ns.ModuleLoaded(part) then for file in pairs(PartFiles(part)) do files[file] = true end end
			end
			local running = Running(audit, files)
			local off, all = 0, 0
			if ns.FeatureLoopsOff then off, all = ns.FeatureLoopsOff() end
			r:Log(("all off: feature loops off %d of %d; every loop running: %s"):format(off, all, AllLabels(audit)))
			r:Verdict(#running == 0, "every switch off: no loop of the parts or the gated pages: " .. Joined(running))
			-- (Run 3: the Plate parts keeper ran on here, what it held unknown and not
			-- seen offline. Every held part, its alpha and its plate (or none): the probe.)
			if ns.platePartsKept and ns.platePartsKept.Describe then
				local ok, count, list = pcall(ns.platePartsKept.Describe)
				r:Log(("probe plate parts held with every switch off: %s %s"):format(tostring(ok and count or count),
					tostring(ok and list or "")))
			end
			PutBackKeys(r, keys, 3)
			local back = Loops(r, 2)
			if ns.FeatureLoopsOff then off, all = ns.FeatureLoopsOff() end
			r:Log(("all back: feature loops off %d of %d; running: %s"):format(off, all, AllLabels(back)))
		end },
		-- 10 --------------------------------------------------------------
		{ key = "out", title = "Load Visions, Cameras, Style and Atmosphere unticked: one Reload", run = function(r)
			local data = Data()
			-- (What the reload must keep or give back.)
			data.shoulder = {}
			for cvar, value in pairs(ns.db.shoulderCamYours or {}) do data.shoulder[cvar] = value end
			local lines = 0
			for _, window in pairs(ns.chardb and ns.chardb.chatHistory or {}) do
				if type(window) == "table" then lines = lines + #window end
			end
			data.history = lines
			data.historyOn = ns.Setting("chatHistory") and true or false
			-- (B3: the Quality of life page off for one login keeps the history.)
			r:Set("handleQuality", false)
			local out = {}
			for _, part in ipairs(PARTS) do
				if ns.ModuleLoaded(part) then
					ns.SetModuleWanted(part, false)
					out[#out + 1] = part
				end
			end
			r:Keep("partsOut", true)
			if ns.MODULES_RELOAD_POPUP and _G.StaticPopup_Hide then _G.StaticPopup_Hide(ns.MODULES_RELOAD_POPUP) end
			r:Log(("left out at the reload: %s; Shoulder Cam holding %d of your settings; %d chat lines saved (history %s)")
				:format(Joined(out), (function() local n = 0 for _ in pairs(data.shoulder) do n = n + 1 end return n end)(),
				lines, tostring(data.historyOn)))
			r:WaitFor("Click Reload: the parts are left out for one reload (they load again at your next /reload).",
				{ check = function() return false end, buttons = { { kind = "reload" } } })
		end },
		-- 11 --------------------------------------------------------------
		{ key = "leftout", title = "with the parts left out", run = function(r)
			local data = Data()
			local out = {}
			for _, part in ipairs(PARTS) do if not ns.ModuleLoaded(part) then out[part] = true end end
			if not next(out) then
				r:Skip("every part still loaded: the reload didn't leave them out (step 10 first)")
			else
				-- A1: the parts rows with Style left out.
				if out.style then
					local before = ErrorsNaming("StyleOverrideText")
					r:Verdict(type(ns.StyleOverrideText) == "function", "A1 ns.StyleOverrideText there as a stand-in")
					for _, page in ipairs({ "Standard Frames", "Nameplates" }) do
						if ns.OpenOptions then pcall(ns.OpenOptions, page) end
						r:Sleep(1)
					end
					if ns.RefreshOptions then pcall(ns.RefreshOptions) end
					r:Sleep(0.5)
					r:Verdict(ErrorsNaming("StyleOverrideText") == 0, ("A1 Standard Frames and Nameplates opened: no StyleOverrideText error (%d before, %d now)")
						:format(before, ErrorsNaming("StyleOverrideText")))
					r:Verdict(ns.StyleOn and ns.StyleOn("tintStyle") == false and ns.MasterOff("tintStyle")
						and not ns.PageOn("tintStyle"), "gate-machinery Style out: Tint Style reads off by every gate")
				end
				-- cameras-out-pages / B2: Cameras left out.
				if out.cameras then
					r:Verdict(ns.settingsCanvases and ns.settingsCanvases["Fishing"] == nil, "cameras-out-pages: no Fishing page")
					r:Verdict(ns.MasterOff("cameraModes") and not ns.Setting("cameraModes") and not ns.PageOn("cameraModes"),
						"gate-machinery Cameras out: Enable Cameras reads off by every gate")
					if next(data.shoulder or {}) then
						local wrong = {}
						for cvar, value in pairs(data.shoulder) do
							local now = GetCVar(cvar)
							if now ~= nil and tostring(now) ~= tostring(value) and tonumber(now) ~= tonumber(value) then
								wrong[#wrong + 1] = ("%s %s (yours %s)"):format(cvar, tostring(now), tostring(value))
							end
						end
						r:Verdict(#wrong == 0, "B2 Shoulder Cam's settings given back at the logout: " .. Joined(wrong))
					else
						r:Skip("B2 Shoulder Cam giving your settings back: needs Shoulder Cam on (holding them) before the reload")
					end
				end
				-- toggle-effects-left-out: the key with Atmosphere out.
				if out.atmosphere and Cinematic_ToggleVisualEffects then
					local was = ns.db.visualEffects
					local ok, said = Said(Cinematic_ToggleVisualEffects)
					r:Verdict(ok and ns.db.visualEffects == was and said == ns.ModuleLeftOutLine("atmosphere"),
						("toggle-effects-left-out: the key says %q, nothing changed"):format(tostring(said)))
				end
				-- C21: the Why window's Cards tab with Visions out.
				if out.visions then
					local found
					for _, provider in ipairs(ns.WhyProviders and ns.WhyProviders() or {}) do
						if provider.id == "cards" then found = provider end
					end
					if found then
						local ok, sections = pcall(found.fn)
						r:Verdict(ok and type(sections) == "table", "C21 the Why window's Cards tab with Visions out: " ..
							(ok and "made" or tostring(sections)))
					else
						r:Pass("C21 the Why window's Cards tab isn't offered with Visions out")
					end
				end
				-- F2 / gate-tree-shape: the tree as it was with every part loaded.
				if data.tree then
					local moved = {}
					for key, master in pairs(data.tree) do
						local now = ns.PageSwitchOf(key)
						if now ~= master then moved[#moved + 1] = ("%s: %s -> %s"):format(key, master, tostring(now)) end
					end
					table.sort(moved)
					for i = 1, math.min(15, #moved) do r:Log("  moved: " .. moved[i]) end
					r:Verdict(#moved == 0, ("gate-tree-shape: the tree's switches the same with the parts out: %d moved"):format(#moved))
				else
					r:Skip("gate-tree-shape: no tree from step 1 (run the whole test)")
				end
			end
			-- B3: chat history kept through a login with the page off.
			if data.historyOn and (data.history or 0) > 0 then
				local lines = 0
				for _, window in pairs(ns.chardb and ns.chardb.chatHistory or {}) do
					if type(window) == "table" then lines = lines + #window end
				end
				r:Verdict(lines >= data.history, ("B3 Quality of life off for a login: chat history kept (%d lines, %d before)")
					:format(lines, data.history))
			else
				r:Skip("B3 chat history through a login with the page off: needs Keep chat history on with lines saved")
			end
			-- (Ticked back on: they load again from your next /reload.)
			for _, part in ipairs(PARTS) do
				if not ns.ModuleWanted(part) then ns.SetModuleWanted(part, true) end
			end
			if ns.MODULES_RELOAD_POPUP and _G.StaticPopup_Hide then _G.StaticPopup_Hide(ns.MODULES_RELOAD_POPUP) end
			r:Log("Load boxes ticked back on: the parts load again from your next /reload")
			r:Skip("time-title-test /cine timetest with Visions out: a dev command, proven offline")
			r:Skip("B1 Graphics+ after Later and a fight: needs a fight before the reload")
		end },
	},
})
