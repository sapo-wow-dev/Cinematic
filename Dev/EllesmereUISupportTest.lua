-- EllesmereUI's ready recipe: what a test needs of it so the frames our rows
-- cover (Support/EllesmereUI.lua) can show. How it works, with file:line:
-- Tools/addon-kit/addons/EllesmereUI.md. It's a whole-UI suite, one addon
-- per part, all keeping their settings in EllesmereUIDB (most per profile in
-- EllesmereUIDB.profiles[active].addons.<part>, WoW Forever Essentials'
-- account-wide in EllesmereUIDB.<feature>). Its first-run windows must be
-- done, then the recipe turns on its displays that are off by default, each
-- through the call its own options use, no reload, and puts them back after.
-- Parts that wait for a state (a fight, a target, a flight, a group, a class
-- or a key) are turned on where that's cheap, but not waited for.
-- Dev copy only. (Code read, not yet proven by a run.)
local _, ns = ...

local NIL = "<nil>" -- (how r:Keep hands back a value that was nil)
local function Was(v) if v == NIL then return nil end return v end

local function EUI() return type(_G.EllesmereUI) == "table" and _G.EllesmereUI or nil end
local function SV() return type(_G.EllesmereUIDB) == "table" and _G.EllesmereUIDB or nil end
local function Loaded(addon)
	return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(addon) and true or false
end
local function Forever() local eui = EUI() return eui and eui.IS_FOREVER == true end
local function Shown(name) local f = _G[name] return f and f.IsShown and ns.Flag(f:IsShown()) or false end
local function Call(fn, ...) if type(fn) == "function" then pcall(fn, ...) end end
local function ModuleNS(part) local eui = EUI() return eui and type(eui._ModuleNS) == "table" and eui._ModuleNS[part] end

-- Tables its settings sit in (each nil till that part has set up).
local function Cursor() return _G._ECL_AceDB and _G._ECL_AceDB.profile end -- (QoL's cursor table)
local function ResourceBars() return _G._ERB_AceDB and _G._ERB_AceDB.profile end
local function ActionBar(key)
	local eui = EUI()
	local lite = eui and eui.Lite
	local eab = lite and type(lite.GetAddon) == "function" and lite.GetAddon("EllesmereUIActionBars", true)
	local bars = eab and eab.db and eab.db.profile and eab.db.profile.bars
	return bars and bars[key]
end
local function QoLProfile()
	local sv = SV()
	local prof = sv and sv.profiles and sv.profiles[sv.activeProfile or "Default"]
	return prof and prof.addons and prof.addons.EllesmereUIQoL
end
local function Meters()
	local sv = SV()
	local prof = sv and sv.profiles and sv.profiles[sv.activeProfile or "Default"]
	local dm = prof and prof.addons and prof.addons.EllesmereUIDamageMeters
	return dm and dm.dm
end
local function Feature(key) -- (Forever Essentials': made when first written)
	local sv = SV()
	if not sv then return nil end
	if type(sv[key]) ~= "table" then sv[key] = {} end
	return sv[key]
end
local function Sub(get, key) -- (a sub-table, made when missing)
	return function()
		local t = get()
		if not t then return nil end
		if type(t[key]) ~= "table" then t[key] = {} end
		return t[key]
	end
end
local function Extras() -- (Secondary Stats, FPS, Target Distance: QoLExtrasSet's table)
	local eui = EUI()
	if eui and type(eui.QoLExtrasGet) == "function" then eui.QoLExtrasGet("showFPS") end -- (makes it)
	return QoLProfile()
end

-- Its displays a test turns on: the part it's in, the table and values its
-- own options set, the call they make after, and a frame that shows once
-- it's on (none: it waits for a state). forever / retail: one client only.
local SWITCHES = {
	{ name = "Secondary Stats", part = "EllesmereUIQoL", get = Extras, set = { showSecondaryStats = true },
		apply = function() Call(EUI()._applySecondaryStats) end, frame = "EUI_SecondaryStats" },
	-- (Drawn inside Secondary Stats when attached to it: kept apart.)
	{ name = "FPS Counter", part = "EllesmereUIQoL", get = Extras, set = { showFPS = true, fpsAttachToStats = false },
		apply = function() Call(EUI()._applyFPSDisplay) end, frame = "EUI_FPSCounter" },
	{ name = "Character Crosshair", part = "EllesmereUIQoL", get = Cursor, set = { crosshairSize = "Normal" },
		apply = function() Call(EUI()._applyCrosshair) end, frame = "EUI_CharacterCrosshair" },
	{ name = "Target Distance", part = "EllesmereUIQoL", get = Extras, set = { targetDistanceEnabled = true },
		apply = function() Call(EUI()._applyTargetDistance) end }, -- (needs a target)
	{ name = "Self Combat Text", part = "EllesmereUIQoL", get = Sub(QoLProfile, "selfCombatText"), set = { enabled = true },
		apply = function() Call(EUI()._applySelfCombatText) end }, -- (text on hits)
	{ name = "Cursor Trail", part = "EllesmereUIQoL", get = Cursor, set = { trail = true },
		apply = function() Call(_G._ECL_ApplyTrail) end }, -- (while the mouse moves)
	{ name = "GCD Circle", part = "EllesmereUIQoL", get = Sub(Cursor, "gcd"), set = { enabled = true },
		apply = function() Call(_G._ECL_ApplyGCDCircle) end }, -- (after a cast)
	{ name = "Cast Bar Circle", part = "EllesmereUIQoL", get = Sub(Cursor, "castCircle"), set = { enabled = true },
		apply = function() Call(_G._ECL_ApplyCastCircle) end }, -- (while casting)
	{ name = "GCD Bar", part = "EllesmereUIResourceBars", get = Sub(ResourceBars, "gcdBar"),
		set = { enabled = true, alwaysShow = true }, apply = function() Call(_G._ERB_Apply) end },
	{ name = "Action Bar 9", part = "EllesmereUIActionBars", get = function() return ActionBar("Bar9") end,
		set = { barVisibility = "always", alwaysHidden = false }, outOfFights = true,
		apply = function() Call(_G._EAB_Apply) end, frame = "EABBar_Bar9" },
	{ name = "Action Bar 10", part = "EllesmereUIActionBars", get = function() return ActionBar("Bar10") end,
		set = { barVisibility = "always", alwaysHidden = false }, outOfFights = true,
		apply = function() Call(_G._EAB_Apply) end, frame = "EABBar_Bar10" },
	{ name = "Spell History", part = "EllesmereUIDamageMeters", get = Sub(Meters, "spellHistory"),
		set = { barEnabled = true, iconEnabled = true },
		apply = function() local dm = ModuleNS("EllesmereUIDamageMeters") Call(dm and dm.ApplySpellHistory) end,
		frame = "EllesmereUIDMBarHistory" },
	{ name = "Combat Timer", part = "EllesmereUIDamageMeters", get = Meters, set = { standaloneTimer = true },
		apply = function() Call(_G._EDM_Apply) end }, -- (in fights)
	{ name = "AFK Screen", part = "EllesmereUI", get = SV, set = { partyModeAfk = true },
		apply = function() Call(_G.EllesmereUI_UpdateAfkScreen) end }, -- (while /afk)
	{ name = "Threat Meter", part = "EllesmereUIForeverEssentials", forever = true,
		get = function() return Feature("threatMeter") end, set = { enabled = true },
		apply = function() local t = EUI()._ThreatMeter Call(t and t.Apply) end }, -- (a fight)
	{ name = "Junk List", part = "EllesmereUIForeverEssentials", forever = true,
		get = function() return Feature("junkList") end, set = { enabled = true },
		apply = function() local t = EUI()._JunkItems Call(t and t.Apply) end, frame = "EllesmereUIJunkList" },
	{ name = "Loot Feed", part = "EllesmereUIForeverEssentials", forever = true,
		get = function() return Feature("lootFeed") end, set = { enabled = true },
		apply = function() local t = EUI()._LootFeed if t then Call(t.Apply) Call(t.Preview) end end },
	{ name = "Active Form", part = "EllesmereUIForeverEssentials", forever = true,
		get = function() return Feature("activeForm") end, set = { enabled = true },
		apply = function() local t = EUI()._ActiveForm Call(t and t.Apply) end }, -- (warrior, druid, paladin, hunter)
}

local function Applies(sw)
	if not Loaded(sw.part) then return false end
	if sw.forever and not Forever() then return false end
	return true
end
local function IsOn(sw)
	local t = sw.get()
	if not t then return true end -- (that part never set up: nothing to turn on)
	for key, value in pairs(sw.set) do
		if t[key] ~= value then return false end
	end
	return true
end

-- Ready for a test: its first-run windows done and its displays that are off
-- by default turned on (and shown where they don't wait for a state).
-- Tools/addon-kit/addons/EllesmereUI.md.
ns.TestKit.DefineAddonReady("EllesmereUI", {
	about = "its first-run windows done, its displays that are off by default on",
	ready = function()
		local sv = SV()
		if not (EUI() and sv) then return false, "its saved settings aren't loaded yet" end
		if not sv.firstInstallPopupShown then return false, "its FIRST TIME SETUP window isn't done" end
		if sv.styleChoicePending then return false, "its CHOOSE YOUR LOOK window isn't done" end
		local off = {}
		for _, sw in ipairs(SWITCHES) do
			if Applies(sw) and (not IsOn(sw) or (sw.frame and not Shown(sw.frame))) then
				off[#off + 1] = sw.name
			end
		end
		if Loaded("EllesmereUIQoL") and not Shown("EllesmereUIRaidToolsGroup") then off[#off + 1] = "Raid Tools" end
		if #off > 0 then return false, "not on yet: " .. table.concat(off, ", ") end
		return true
	end,
	make = function(r)
		local sv = SV()
		if not (EUI() and sv) then return end
		-- Its look picker comes up at login only: with it not up, its flag
		-- alone says it's due, and clearing it is what closing it does.
		if sv.styleChoicePending and not Shown("EUIStyleChoiceDimmer") then
			r:Keep("styleChoicePending", sv.styleChoicePending)
			sv.styleChoicePending = nil
			r:Log("cleared EllesmereUI's look picker flag (it wasn't up)")
		end
		local fight = InCombatLockdown()
		for i, sw in ipairs(SWITCHES) do
			local t = Applies(sw) and not (fight and sw.outOfFights) and sw.get()
			if t and not IsOn(sw) then
				for key, value in pairs(sw.set) do
					r:Keep(("sw%d.%s"):format(i, key), t[key])
					t[key] = value
				end
				pcall(sw.apply)
				r:Log("turned on EllesmereUI's " .. sw.name)
			end
		end
		-- Raid Tools: its own settings preview (all windows open, no group
		-- needed). Secure windows: out of fights only.
		if Loaded("EllesmereUIQoL") and not fight and type(_G._EUI_RaidTools_Preview) == "function"
			and not Shown("EllesmereUIRaidToolsGroup") then
			r:Keep("raidToolsPreview", true)
			pcall(_G._EUI_RaidTools_Preview, true)
			r:Log("opened EllesmereUI's Raid Tools preview")
		end
		r:Sleep(1)
	end,
	putBack = function(extra)
		local said = {}
		local sv = SV()
		if sv and extra.styleChoicePending ~= nil then
			sv.styleChoicePending = Was(extra.styleChoicePending)
			said[#said + 1] = "look picker flag"
		end
		for i, sw in ipairs(SWITCHES) do
			local changed = false
			for key in pairs(sw.set) do
				local kept = extra[("sw%d.%s"):format(i, key)]
				if kept ~= nil then
					local ok, t = pcall(sw.get)
					if ok and t then t[key] = Was(kept) changed = true end
				end
			end
			if changed then
				if not (sw.outOfFights and InCombatLockdown()) then pcall(sw.apply) end
				said[#said + 1] = sw.name
			end
		end
		if extra.raidToolsPreview and type(_G._EUI_RaidTools_Preview) == "function" then
			pcall(_G._EUI_RaidTools_Preview, false)
			said[#said + 1] = "Raid Tools preview"
		end
		if #said == 0 then return nil end
		return "EllesmereUI put back: " .. table.concat(said, ", ")
	end,
	guide = {
		"If EllesmereUI's \"Welcome to EllesmereUI\" window is up, click Reload UI, then start the test again.",
		"If its \"How should EllesmereUI look?\" window is up, click the card marked In Use (or press Escape).",
		"In a fight? Leave it first: its action bars and Raid Tools only change out of fights.",
	},
})
