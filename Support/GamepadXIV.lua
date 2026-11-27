-- Cinematic: Gamepad XIV, controller play on Forever's gamepad UI. Its cross
-- hotbars stand in for Forever's gamepad action bar, and its chat box for the
-- game's chat (its Chat setting, on by default). (Notes on how it works:
-- Tools/addon-kit/addons/GamepadXIV.md.)
--
-- Forever's bar it holds at alpha 0 with one SetAlpha, not hooked, and gives
-- back at 1 in vehicles: our Gamepad action bars row wrote 1 over its 0, and
-- both bars showed. That bar follows its own alpha now, and its cross hotbars
-- fade with that row.
--
-- The game's chat it holds at alpha 0 with a SetAlpha hook of its own on each
-- part, pushing anything above 0 back to 0 (and shows it while you type in
-- it). Our fade's alpha not taking read as a do-nothing SetAlpha, so ours went
-- past its hook with the game's own (ns.SetFrameAlpha), and the game's chat
-- showed over its box. Those parts are left to it while its box is the chat;
-- its box fades with the Chat window row and is that window's panel, so a
-- message brings it up and no copy of the line is drawn over it (UI/Chat.lua).
-- Its Chat setting is read as it loads: switched later, ours follows from the
-- next /reload.
--
-- Its interact prompt sits inside its hotbar frame: a row of its own, so it
-- can stay up while the bars fade (the user's pick, 2026-11-25).
local _, ns = ...
local L = ns.L

local ADDON = "GamepadXIV"

table.insert(ns.ADDON_FRAMES, {
	key = "gxivPrompt", addon = ADDON, label = "Gamepad XIV interact prompt", short = "Gamepad XIV prompt",
	about = L["its button prompt over what you can talk to or pick up"],
	hookAlpha = true,
})

-- The game's chat parts it holds at alpha 0 while its box is the chat
-- (GamepadXIV/LfgFilter.lua:5020-5031, v0.1.28).
local function GameChatParts()
	local names = {}
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		names[#names + 1] = "ChatFrame" .. i
		names[#names + 1] = "ChatFrame" .. i .. "Tab"
		names[#names + 1] = "ChatFrame" .. i .. "EditBox"
	end
	for _, name in ipairs({ "GeneralDockManager", "ChatFrameMenuButton", "ChatFrameChannelButton",
		"ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton" }) do
		names[#names + 1] = name
	end
	return names
end
ns.GamepadXIVChatParts = GameChatParts -- (Tools/offline/gamepadxiv.lua)

-- Whether its chat box stands in for the game's chat: its Chat setting,
-- "gxiv" or "game" ("gxiv" until its defaults are filled in).
local function OwnChat()
	local db = rawget(_G, "GamepadXIVDB")
	local mode = type(db) == "table" and db.chatUI or nil
	return mode == nil or mode == "gxiv"
end
ns.GamepadXIVOwnChat = OwnChat

local function Usable(frame)
	return type(frame) == "table" and type(frame.GetObjectType) == "function" and ns.Reachable(frame)
end

local function IgnoresParentAlpha(frame)
	local ignoring = frame.IsIgnoringParentAlpha and frame:IsIgnoringParentAlpha()
	return not (issecretvalue and issecretvalue(ignoring)) and ignoring == true
end

-- Its interact prompt: the one unnamed child of its hotbar frame with art,
-- not a row's side nor the set picker (GamepadXIV/Input.lua:1598-1603,
-- Bar.lua:243-263, 486-502). Set to ignore the hotbar's alpha, so its row
-- alone fades it; it hides itself whenever its bars give way to Forever's.
local function FindPrompt(root)
	local sides, picker = rawget(root, "sides"), rawget(root, "setPicker")
	for _, child in ipairs({ root:GetChildren() }) do
		local isSide = false
		for _, side in pairs(type(sides) == "table" and sides or {}) do
			if side == child then isSide = true end
		end
		if not isSide and child ~= picker and child:GetName() == nil and child:GetNumRegions() > 0 then
			return child
		end
	end
	return nil
end

local function ScanFrames()
	local root = rawget(_G, "GamepadXIVFrame")
	if not Usable(root) then return end
	local prompt = FindPrompt(root)
	if Usable(prompt) then
		if not IgnoresParentAlpha(prompt) then prompt:SetIgnoreParentAlpha(true) end
		if ns.IsAddonFramesOn("gxivPrompt") and not ns.IsFaded(prompt) then
			ns.AddFoundFrame(prompt, "addon:gxivPrompt", true, true)
		end
	end
	-- Its outline round the party or raid member you pick (unnamed, on
	-- UIParent, over the party frames: Bar.lua:500-501): with the party.
	for _, key in ipairs({ "softBorder", "targetHighlight" }) do
		local frame = rawget(root, key)
		if Usable(frame) and not ns.IsFaded(frame) then ns.AddFoundFrame(frame, "party", true, true) end
	end
	-- Forever's pet buttons and their prompts on its gamepad bar, kept up
	-- over the hidden bar by ignoring its alpha (pet classes: Input.lua:2852-
	-- 2873), and its own key hints in those prompts (2885-2899): with the
	-- gamepad bars, its bars' stand-ins. (Forever's own: followed, not hooked.)
	local bar = rawget(_G, "GamepadMainActionBarFrame")
	local unit = type(bar) == "table" and rawget(bar, "PageUnit")
	if type(unit) == "table" then
		for _, key in ipairs({ "LeftClassAction", "RightClassAction", "LeftInputPrompt", "RightInputPrompt" }) do
			local frame = rawget(unit, key)
			if Usable(frame) then
				if not ns.IsFaded(frame) then ns.AddFoundFrame(frame, "gamepadbars", true, false) end
				if key:find("InputPrompt") then
					for _, hint in ipairs({ frame:GetChildren() }) do
						if Usable(hint) and type(rawget(hint, "text")) == "table" and IgnoresParentAlpha(hint)
							and not ns.IsFaded(hint) then
							ns.AddFoundFrame(hint, "gamepadbars", true, true)
						end
					end
				end
			end
		end
	end
	-- Its D-pad prompt under the party frames, in Forever's prompt (which it
	-- holds at alpha 0), ignoring that prompt's alpha (Input.lua:2940-2957):
	-- with the party.
	local party = rawget(_G, "CompactPartyFrame")
	if Usable(party) then
		for _, child in ipairs({ party:GetChildren() }) do
			local holder = rawget(child, "promptContainerFrame")
			if Usable(holder) then
				for _, prompt in ipairs({ holder:GetChildren() }) do
					if Usable(prompt) and type(rawget(prompt, "text")) == "table" and IgnoresParentAlpha(prompt)
						and not ns.IsFaded(prompt) then
						ns.AddFoundFrame(prompt, "party", true, true)
					end
				end
			end
		end
	end
	-- Its chat box: the main chat window's panel.
	local box, window = rawget(_G, "GamepadXIVChatBox"), rawget(_G, "ChatFrame1")
	if OwnChat() and Usable(box) and type(window) == "table" then
		ns.ClaimLinkPart(ADDON, "chatwindow", box, { window = window })
	end
end

ns.WhenAddonLoads(ADDON, function()
	-- Forever's gamepad bar: at its alpha (0 while its bars stand in).
	ns.FollowOwnAlpha({ "GamepadMainActionBarFrame" })
	-- Its cross hotbars (rows, buttons, set labels, picker, soft target name
	-- inside): with Forever's. It sets their alpha itself (0 or 1).
	ns.FadeWithRow("gamepadbars", "gamepadbars", { "GamepadXIVFrame" }, true, true)
	if OwnChat() then
		ns.LeaveAlone(GameChatParts())
		ns.FadeWithRow("chat", "chat", { "GamepadXIVChatBox" }, true, true)
	end
	-- Panels it opens on purpose or for a moment (its ring menu, roll pick,
	-- flyout and ability panels, the hint under a popup) and its windows:
	-- not HUD frames.
	ns.LeaveAlone({ "GamepadXIVRing", "GamepadXIVRollPicker", "GamepadXIVFlyoutPanel", "GamepadXIVClearPanel",
		"GamepadXIVPopupHint", "GamepadXIVConfigFrame", "GamepadXIVLfgFilterFrame", "GamepadXIVMessagesFrame",
		"GamepadXIVNewsFrame", "GamepadXIVTutorial", "GamepadXIVAssignPanel", "GamepadXIVEditor", "GamepadXIVMenu",
		"GamepadXIVSpellbookPick" })
	ns.AddScanner(ScanFrames)
end)

-- The addon kit's expectations (Tools/addon-kit/diff.py): game frames it
-- holds at alpha 0 because its own stand in, and the game code it hooks (all
-- hooksecurefunc: ours still run). Checked against v0.1.28 on Forever.
-- (Literal strings: diff.py reads these from this file's text.)
ns.AddonKitExpect("GamepadXIV", "*GamepadMainActionBarFrame", "alpha", "at alpha 0: its cross hotbars stand in")
ns.AddonKitExpect("GamepadXIV", "frame.*", "GamepadMainActionBarFrame.alpha", "at alpha 0: its cross hotbars stand in")
ns.AddonKitExpect("GamepadXIV", "touch.ChatFrame_", "alpha", "at alpha 0: its chat box stands in")
ns.AddonKitExpect("GamepadXIV", "touch.ChatFrame_Tab", "alpha", "at alpha 0: its chat box stands in")
ns.AddonKitExpect("GamepadXIV", "*GeneralDockManager", "alpha", "at alpha 0: its chat box stands in")
ns.AddonKitExpect("GamepadXIV", "frame.*", "GeneralDockManager.alpha", "at alpha 0: its chat box stands in")
-- (Its menu, channel and voice buttons at 0 too: they draw nothing either way, kit run qe788.)
ns.AddonKitExpect("GamepadXIV", "hook.ChatFrame1.AddMessage", "state", "hooksecurefunc: ours still run")
-- (Its link sharing and chat box opening: Input.lua:1168, 2365.)
ns.AddonKitExpect("GamepadXIV", "touch.ChatEdit_ActivateChat", "sameAsLogin", "hooksecurefunc: ours still run")
ns.AddonKitExpect("GamepadXIV", "touch.HandleModifiedItemClick", "sameAsLogin", "hooksecurefunc: ours still run")
ns.AddonKitExpect("GamepadXIV", "chat.linesOnly", "chatIsDefault", "false: its chat box draws the lines")
ns.AddonKitExpect("GamepadXIV", "chat.linesOnly", "linesOnly", "false: a message brings up its box, no copy")
ns.AddonKitExpect("GamepadXIV", "link.chatwindow", "*", "its chat box is the chat window's panel")
