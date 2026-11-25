-- Cinematic: Glass Forever, a chat addon. It keeps the game's chat tabs
-- (ChatFrame1Tab...) and input boxes (ChatFrame1EditBox...) and fades them
-- itself, holding their alpha with SetAlpha hooks of its own. The Chat page
-- setting them too fought over that alpha, and they stayed invisible (issue
-- #8): with Glass loaded they're left to it. The tab bar they sit in
-- (GeneralDockManager) still fades with the chat, as without Glass: Glass
-- fades it by showing and hiding it, never by its alpha, so the tabs go
-- with the chat.
--
-- It draws each chat window's lines on a frame of its own (an unnamed scroll
-- frame inside GlassFrame, .chatFrame its window), not in the window, so
-- fading the window left them up: those fade with the Chat window row, and
-- are linked as each window's panel (FrameLinks.lua) so a message the Chat
-- page lets through still brings them up. A window dragged out of Glass's
-- dock is the game's again (its Glass frame hidden) and fades as usual. Its
-- extra windows (a chat window shown again in a window of its own) fade with
-- the Chat window row the same way, linked to the window they show.
local _, ns = ...
local L = ns.L

-- Advanced Frames page (no columns: it follows the Chat page).
table.insert(ns.ADDON_NOTES, {
	addon = "Glass", label = "Glass Forever",
	works = L["Follows the Chat page"],
	about = L["Glass's chat fades and comes up as the Chat page says."],
})

-- Glass shows and hides the tab bar with alpha animations (0 to 1 to show it
-- for a party or guild line, 1 to 0 to hide it), and an animation's alpha
-- wins over the frame's own while it plays: the bar flashed up through our
-- fade for a second. While the Chat page has it faded, its show animation
-- stops at once (the bar stays at our alpha), and its hide hides it at once.
-- (Glass's own animations, made once its chat is set up: hooked when found.)
local function OurDockAlpha(dock)
	for _, entry in ipairs(ns.managed) do
		if entry.frame == dock then return entry.alpha or 1 end
	end
	return 1
end

local dockHooked = false
local function HookDockFades()
	local dock = _G.GeneralDockManager
	if dockHooked or type(dock) ~= "table" or type(dock.showAg) ~= "table" or type(dock.hideAg) ~= "table"
		or type(dock.QuickHide) ~= "function" then
		return
	end
	dockHooked = true
	hooksecurefunc(dock.showAg, "Play", function(group)
		if OurDockAlpha(dock) < 0.99 then group:Stop() end
	end)
	hooksecurefunc(dock.hideAg, "Play", function(group)
		if OurDockAlpha(dock) < 0.99 then
			group:Stop()
			pcall(dock.QuickHide, dock)
		end
	end)
end

local function FindLines()
	HookDockFades()
	local container = _G.GlassFrame
	if type(container) ~= "table" or not container.GetChildren then return end
	for _, frame in ipairs({ container:GetChildren() }) do
		local window = frame.chatFrame
		-- (Not the game's input boxes Glass moves in here: they carry a
		-- .chatFrame too, and linked as a window's panel they hid with the
		-- input, so a line no longer brought chat up. Tested 2026-11-21.)
		if type(window) == "table" and ns.Reachable(frame)
			and not (frame.GetObjectType and frame:GetObjectType() == "EditBox")
			and type(window.GetName) == "function" and (window:GetName() or ""):match("^ChatFrame%d+$") then
			if not ns.IsFaded(frame) then
				ns.AddFoundFrame(frame, "chat", true, true)
			end
			ns.ClaimLinkPart("Glass", "chatwindow", frame, { window = window })
		end
	end
	-- Its extra windows (a chat window shown a second time, in a window of
	-- its own: none till a player adds one in its options) are unnamed
	-- frames on UIParent, not in GlassFrame, so they stayed up while the chat
	-- faded. Reached through its global addon object: each view's .frame
	-- draws the lines of .source, a game chat window. (Glass 2.2.0,
	-- Components/ExtraWindow.lua:267-289, Modules/ExtraWindows.lua.)
	local glass = _G.Glass
	if type(glass) ~= "table" or type(glass.GetModule) ~= "function" then return end
	local ok, extra = pcall(glass.GetModule, glass, "ExtraWindows", true)
	if not ok or type(extra) ~= "table" or type(extra.views) ~= "table" then return end
	for _, view in pairs(extra.views) do
		local frame = type(view) == "table" and not view.released and view.frame
		local window = type(view) == "table" and view.source
		if type(frame) == "table" and ns.Reachable(frame) then
			if not ns.IsFaded(frame) then ns.AddFoundFrame(frame, "chat", true, true) end
			if type(window) == "table" and type(window.GetName) == "function"
				and (window:GetName() or ""):match("^ChatFrame%d+$") then
				ns.ClaimLinkPart("Glass", "chatwindow", frame, { window = window })
			end
		end
	end
end

ns.WhenAddonLoads("Glass", function()
	local names = {}
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		names[#names + 1] = "ChatFrame" .. i .. "Tab"
		names[#names + 1] = "ChatFrame" .. i .. "EditBox"
	end
	ns.LeaveAlone(names)
	ns.AddScanner(FindLines)
end)

-- The addon kit's expectations (Tools/addon-kit/diff.py), checked against
-- Glass 2.2.0 on Forever (run q9ef0, 2026-11-25). Its three hooks on game code
-- we hook too put its own function in place after ours, and all three call
-- ours through: SetItemRef with hooksecurefunc (and its link clicks call the
-- global SetItemRef), ChatFrame1.AddMessage with an AceHook prehook that
-- always calls the old one, FCF_OpenTemporaryWindow with a raw hook that
-- calls the old one first. Our copy of chat lines, our links and the slash
-- completion's whisper windows still run.
ns.AddonKitExpect("Glass", "hook.SetItemRef", "state", "its hooksecurefunc: ours still runs")
ns.AddonKitExpect("Glass", "touch.SetItemRef", "sameAsLogin", "its hooksecurefunc: ours still runs")
ns.AddonKitExpect("Glass", "hook.ChatFrame1.AddMessage", "state", "its prehook calls ours through")
ns.AddonKitExpect("Glass", "hook.FCF_OpenTemporaryWindow", "state", "its raw hook calls ours first")
ns.AddonKitExpect("Glass", "touch.FCF_OpenTemporaryWindow", "sameAsLogin", "its raw hook calls ours first")
-- It claims the chat: the game's windows sit hidden in GlassFrame and their
-- lines draw on its frames (linked as their panels, above), so a message
-- brings up its frame rather than our copy of the line (UI/Chat.lua).
ns.AddonKitExpect("Glass", "chat.linesOnly", "chatIsDefault", "false: its frames draw the lines")
ns.AddonKitExpect("Glass", "chat.linesOnly", "linesOnly", "false: a message brings up its frame, no copy")
ns.AddonKitExpect("Glass", "link.chatwindow", "*", "its line frames are the windows' panels")
ns.AddonKitExpect("Glass", "touch.ChatFrame_", "*", "hidden in GlassFrame: its frames draw the lines")
-- Its tabs: it fades them itself (left alone, above).
ns.AddonKitExpect("Glass", "touch.ChatFrame_Tab", "alpha", "its own tab fade")
-- Its dock: the menu button sits on the tab bar, the channel button hidden.
ns.AddonKitExpect("Glass", "*.chatmenu", "*", "moved to its tab bar: fades with it")
ns.AddonKitExpect("Glass", "touch.ChatFrameMenuButton", "parent", "moved to its tab bar: fades with it")
ns.AddonKitExpect("Glass", "*.chatchannels", "*", "hidden by its dock")
ns.AddonKitExpect("Glass", "touch.ChatFrameChannelButton", "*", "hidden by its dock")
