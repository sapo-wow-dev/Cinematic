-- Gamepad XIV support checks (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/gamepadxiv.lua < /dev/null
-- A player (Discord, 2026-11-25): with Cinematic on, Gamepad XIV's hotbars
-- and Forever's showed together, and its chat box and the game's chat on top
-- of each other. A stand-in Gamepad XIV here, as v0.1.28 does it:
-- 1. Forever's gamepad bar held at alpha 0 by one SetAlpha: our fade in
--    must not put it back to full (it follows its own alpha now).
-- 2. The game's chat held at alpha 0 by a SetAlpha hook of its own: our fade
--    went past that hook with the game's method (ns.SetFrameAlpha) and the
--    chat showed. The parts it holds are left to it now, with its chat box on
--    the Chat window row as the window's panel (no line copies over it).
-- 3. Its interact prompt, inside its hotbar frame, on a row of its own: it
--    no longer takes the hotbar's alpha.
-- 4. Its Chat setting on the game's chat: the game's chat is ours as before.
-- Says PASS or FAIL per check. (Optional first argument: another .toc, to run
-- it on older code: checks 1-3 fail there.)

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local chatUI = (arg and arg[2]) or "gxiv"
local ns, wow = dofile("Tools/offline/load.lua")("forever", arg and arg[1] or "CinematicDev.toc")
ns.db.handleFrames, ns.db.handleChat, ns.db.handleGamepad = true, true, true
ns.db.chatPeekLinesOnly = true
local switch = "handleChat"
while switch do
	ns.db[switch] = true
	switch = ns.PageSwitchOf(switch)
end
ns.MarkChatHolders = function() end -- (the stand-in's chat frames: no holders to walk)

-- Alpha kept per frame (the stand-in's isn't), set straight on the frame.
local function Track(frame, start)
	rawset(frame, "_a", start or 1)
	rawset(frame, "GetAlpha", function(self) return rawget(self, "_a") end)
	rawset(frame, "SetAlpha", function(self, alpha) rawset(self, "_a", alpha) end)
	return frame
end
local function Named(kind, name, parent)
	local frame = rawget(_G, name)
	if type(frame) ~= "table" then frame = CreateFrame(kind, name, parent or UIParent) end
	return frame
end

-- Forever's gamepad bar, and the game's chat parts it holds.
local bar = Track(Named("Frame", "GamepadMainActionBarFrame"), 1)
local chat = Track(Named("ScrollingMessageFrame", "ChatFrame1"), 1)
local dock = Track(Named("Frame", "GeneralDockManager"), 1)

-- Our frame scan, with the game's frames up as before it loads.
pcall(ns.BuildManagedList)

-- The stand-in Gamepad XIV: its settings, its hotbar (a row, the set picker,
-- its interact prompt), its chat box.
rawset(_G, "GamepadXIVDB", { enabled = true, chatUI = chatUI })
local root = Track(CreateFrame("Frame", "GamepadXIVFrame", UIParent), 1)
root.sides = { L = CreateFrame("Frame", "GamepadXIVSideL", root) }
root.setPicker = CreateFrame("Frame", nil, root)
local prompt = Track(CreateFrame("Frame", nil, root), 1)
prompt:CreateTexture(nil, "ARTWORK")
rawset(prompt, "GetNumRegions", function() return 3 end)
local ignoring = false
rawset(prompt, "SetIgnoreParentAlpha", function(_, on) ignoring = on end)
rawset(prompt, "IsIgnoringParentAlpha", function() return ignoring end)
rawset(root.setPicker, "GetNumRegions", function() return 2 end)
local box = Track(CreateFrame("Frame", "GamepadXIVChatBox", UIParent), 1)
rawset(box, "IsShown", function() return true end)
local loaded = { GamepadXIV = true }
local IsLoaded = C_AddOns.IsAddOnLoaded
C_AddOns.IsAddOnLoaded = function(name) return loaded[name] or IsLoaded(name) end -- luacheck: ignore 122
-- (Its rows on the Addons page, whose switch a fresh install has off.)
ns.db.handleAddonFrames = true
-- Its setup runs as it loads (our support's with it), before its login.
wow.Fire("ADDON_LOADED", "GamepadXIV")
-- At its login: the bar at 0 by one SetAlpha, the chat at 0 behind a hook
-- that pushes anything above 0 back (LfgFilter.lua:5034-5046, 5551).
bar:SetAlpha(0)
if chatUI == "gxiv" then
	for _, frame in ipairs({ chat, dock }) do
		local set = frame.SetAlpha
		rawset(frame, "SetAlpha", function(self, alpha)
			set(self, alpha)
			if alpha > 0 then set(self, 0) end
		end)
		frame:SetAlpha(0)
	end
end
pcall(ns.BuildManagedList)
pcall(ns.BuildManagedList)

local function Entry(frame)
	for _, each in ipairs(ns.managed) do
		if each.frame == frame then return each end
	end
end
local function FadeIn(frame)
	local entry = Entry(frame)
	if not entry then return end
	ns.SetEntryAlpha(entry, 0)
	ns.SetEntryAlpha(entry, 0.5)
	ns.SetEntryAlpha(entry, 1)
	pcall(ns.UpdateFrames, false, 0.2)
	ns.SyncOwnAlphas()
end

print("Gamepad XIV's Chat setting: " .. chatUI)
-- 1. Forever's gamepad bar.
local barEntry = Entry(bar)
Check("1 Forever's gamepad bar still on the Gamepad action bars row", barEntry ~= nil)
FadeIn(bar)
Check("1 faded out and in: Forever's bar stays at its alpha 0", bar:GetAlpha() == 0, bar:GetAlpha())
local rootEntry = Entry(root)
Check("1 its hotbars fade with that row", rootEntry ~= nil and rootEntry.group == "gamepadbars",
	rootEntry and rootEntry.group)

if chatUI == "gxiv" then
	-- 2. The game's chat.
	Check("2 the game's chat window left to it", ns.IsLeftAlone("ChatFrame1") and Entry(chat) == nil)
	Check("2 its tab bar left to it", ns.IsLeftAlone("GeneralDockManager") and Entry(dock) == nil)
	FadeIn(box)
	pcall(ns.UpdateFrames, false, 0.2)
	Check("2 after our passes: the game's chat stays at 0", chat:GetAlpha() == 0, chat:GetAlpha())
	Check("2 after our passes: its tab bar stays at 0", dock:GetAlpha() == 0, dock:GetAlpha())
	local boxEntry = Entry(box)
	Check("2 its chat box on the Chat window row", boxEntry ~= nil and boxEntry.group == "chat",
		boxEntry and boxEntry.group)
	Check("2 chat isn't the game's own: no line copies over its box", ns.ChatIsDefault() == false)
	Check("2 Show just those messages stands aside", ns.ChatPeekLinesOnly() == false)
else
	-- 4. Its Chat setting on the game's chat.
	Check("4 the game's chat window is ours as before", not ns.IsLeftAlone("ChatFrame1"))
	Check("4 chat is the game's own", ns.ChatIsDefault() == true)
	Check("4 its (hidden) chat box isn't claimed", ns.ChatPeekLinesOnly() == true)
end

-- 3. Its interact prompt.
Check("3 the prompt no longer takes its hotbar's alpha", ignoring == true)
local promptEntry = Entry(prompt)
Check("3 the prompt on its own row", promptEntry ~= nil and promptEntry.group == "addon:gxivPrompt",
	promptEntry and promptEntry.group)
local pickerEntry = Entry(root.setPicker)
Check("3 the set picker isn't taken for the prompt", pickerEntry == nil)

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
