-- The dev copy's catch for action bar calls blocked as ours (2026-11-24): the
-- first time in a session the game blocks one (ADDON_ACTION_BLOCKED or
-- _FORBIDDEN on a MultiBar, action button, main bar or the window manager's
-- bar layout), it scans which game fields an addon wrote (issecurevariable)
-- on the bars, the spellbook, the micro buttons and the window manager, there
-- and then while the taint is still there, and logs each with who wrote it
-- under the "bartaint" category of /cine log. The 18:48 case (every bar
-- blocked as the spellbook opened in a fight, then slot changes at 18:50 and
-- 18:53) didn't come back in 7 test runs and a /reload cleared it: this
-- catches the next one as it happens. Known error: bar-calls-blocked-tainted.
-- Also ns.BarTaintScan for /cine debug bartaint (BarTaintTest.lua).
-- Dev copy only (CinematicDev.toc).
local _, ns = ...

-- { root, depth }: a frame's own fields (depth 1), its tables one deeper.
local ROOTS = {
	{ "MainActionBar", 3 }, { "MainMenuBar", 3 }, { "MultiBarBottomLeft", 3 }, { "MultiBarBottomRight", 3 },
	{ "MultiBarRight", 3 }, { "MultiBarLeft", 3 }, { "MultiBar5", 3 }, { "MultiBar6", 3 }, { "MultiBar7", 3 },
	{ "StanceBar", 2 }, { "PetActionBar", 2 }, { "PossessActionBar", 2 },
	{ "PlayerSpellsFrame", 1 }, { "PlayerSpellsMicroButton", 1 }, { "SpellbookMicroButton", 1 },
	{ "TalentMicroButton", 1 }, { "ProfessionMicroButton", 1 }, { "MicroMenu", 1 }, { "MicroMenuContainer", 1 },
	{ "EditModeManagerFrame", 1 }, { "PlayerSpellsUtil", 1 }, { "EventRegistry", 1 },
	-- (The window manager: 18:48's stack opened the spellbook through
	-- ShowUIPanel's center branch, which reads its slots (center, left...).)
	{ "FramePositionDelegate", 1 }, { "UIPanelWindows", 2 },
}
local SPELLS_ROOT = 13 -- (PlayerSpellsFrame: walked deeper once it's loaded)
-- Globals the spellbook's OnShow and the grid code call or read.
local GLOBALS = { "MultiActionBar_ShowAllGrids", "MultiActionBar_HideAllGrids", "GetMultiActionBars",
	"UpdateMicroButtons", "ACTION_BUTTON_SHOW_GRID_REASON_SPELLCOLLECTION", "ACTION_BUTTON_SHOW_GRID_REASON_EVENT",
	"KeybindFrames_InQuickKeybindMode", "InputUtil", "FrameUtil", "PlaySound", "SOUNDKIT", "ShowUIPanel",
	"HideUIPanel", "ToggleFrame", "PlayerSpellsFrame_LoadUI", "bit", "tInvert", "GetCursorInfo", "issecure",
	"UnitAffectingCombat", "ipairs", "pairs", "table" }
-- Named slots, set or not: a slot set to nil is gone from pairs (a closed
-- window's is). The window manager's places; the micro buttons' alert fields
-- their click reads (MainMenuBarMicroButtons.lua:949-957).
local SLOTS = {
	FramePositionDelegate = { "left", "center", "right", "doublewide", "fullscreen" },
	PlayerSpellsMicroButton = { "suggestedTab", "jumpToSpellID", "spellbookOnly", "talentsOnly" },
	TalentMicroButton = { "suggestedTab", "jumpToSpellID", "spellbookOnly", "talentsOnly" },
	SpellbookMicroButton = { "suggestedTab", "jumpToSpellID", "spellbookOnly", "talentsOnly" },
}

-- { ["path.key"] = who } for every field an addon wrote, or nil with no
-- issecurevariable on this client.
function ns.BarTaintScan(spellsDepth)
	if type(issecurevariable) ~= "function" then return nil end
	local list, seen = {}, {}
	local function Walk(t, path, depth)
		if seen[t] or depth < 1 then return end
		seen[t] = true
		pcall(function()
			for key, value in pairs(t) do
				local name = path .. (type(key) == "string" and ("." .. key) or ("[" .. tostring(key) .. "]"))
				if type(key) == "string" then
					local ok, secure, who = pcall(issecurevariable, t, key)
					if ok and not secure then list[name] = tostring(who or "?") end
				end
				if type(value) == "table" and not (issecretvalue and issecretvalue(value)) then
					Walk(value, name, depth - 1)
				end
			end
		end)
	end
	for _, name in ipairs(GLOBALS) do
		local ok, secure, who = pcall(issecurevariable, name)
		if ok and not secure then list["_G." .. name] = tostring(who or "?") end
	end
	-- (The bar list the grid code walks: GetMultiActionBars' entries.)
	local GetBars = _G.GetMultiActionBars
	if type(GetBars) == "function" then
		local ok, entries = pcall(GetBars)
		if ok and type(entries) == "table" then Walk(entries, "GetMultiActionBars()", 2) end
	end
	for i, root in ipairs(ROOTS) do
		local ok, secure, who = pcall(issecurevariable, root[1])
		if ok and not secure then list["_G." .. root[1]] = tostring(who or "?") end
		local t = _G[root[1]]
		if type(t) == "table" then Walk(t, root[1], i == SPELLS_ROOT and (spellsDepth or 1) or root[2]) end
	end
	for root, keys in pairs(SLOTS) do
		local t = _G[root]
		if type(t) == "table" then
			for _, key in ipairs(keys) do
				local ok, secure, who = pcall(issecurevariable, t, key)
				if ok and not secure then list[root .. "." .. key .. " (slot)"] = tostring(who or "?") end
			end
		end
	end
	return list
end

-- The blocked calls this catches: the bars', their buttons', and the window
-- manager's bar layout (EditMode's SetPointBase on MultiBarLeft at 18:48).
local function BarCall(fn)
	return type(fn) == "string" and (fn:find("MultiBar") or fn:find("ActionButton") or fn:find("MainActionBar")
		or fn:find("MainMenuBar") or fn:find("StanceBar") or fn:find("PetActionBar")) ~= nil
end
ns.BarTaintCall = BarCall

local SHOW_MAX = 40
local caught = false
-- (On the first blocked bar call of the session: the scan, into the log.)
function ns.BarTaintCatch(addon, fn)
	if caught or not BarCall(fn) then return false end
	caught = true
	local list = ns.BarTaintScan(3)
	if not list then
		ns.Log("bartaint", ("blocked %s (by %s): no issecurevariable on this client, no scan"):format(fn, tostring(addon)))
		return true
	end
	local keys, ours = {}, 0
	for path, who in pairs(list) do
		keys[#keys + 1] = path
		if who:find("^Cinematic") then ours = ours + 1 end
	end
	table.sort(keys)
	local book = _G.PlayerSpellsFrame
	ns.Log("bartaint", ("first blocked bar call this session: %s (by %s); in a fight %s, lockdown %s, spellbook %s,"
		.. " CineMode %s: %d tainted field(s), %d by Cinematic"):format(fn, tostring(addon),
		tostring(ns.Flag and ns.Flag(UnitAffectingCombat("player")) or false), tostring(InCombatLockdown()),
		book and (book:IsShown() and "open" or "closed") or "not loaded",
		tostring(ns.IsCineModeOn and ns.IsCineModeOn() or false), #keys, ours))
	for i = 1, math.min(#keys, SHOW_MAX) do
		ns.Log("bartaint", ("  %s (by %s)"):format(keys[i], list[keys[i]]))
	end
	if #keys > SHOW_MAX then ns.Log("bartaint", ("  ... and %d more"):format(#keys - SHOW_MAX)) end
	return true
end
function ns.BarTaintCaught() return caught end

local catcher = CreateFrame("Frame")
catcher:RegisterEvent("ADDON_ACTION_BLOCKED")
catcher:RegisterEvent("ADDON_ACTION_FORBIDDEN")
catcher:SetScript("OnEvent", function(_, _, addon, fn)
	if caught then return catcher:UnregisterAllEvents() end -- (once a session: the rest of a burst costs nothing)
	pcall(ns.BarTaintCatch, addon, fn)
end)
