-- /cine debug gamepadxiv: Gamepad XIV with ours (Support/GamepadXIV.lua).
-- Player report 2026-11-25 (Discord): with Cinematic on, its hotbars and
-- Forever's showed together, and its chat box and the game's chat on top of
-- each other. Our Gamepad action bars row put Forever's bar back to full over
-- its alpha 0, and our fade went past its hook holding the game's chat at 0.
-- Steps (hands off but for Reload clicks):
--   0 solo    Gamepad XIV alone with Cinematic (a Reload), if it isn't loaded
--   1 setup   its ready recipe (below): the gamepad UI on, Gamepad XIV on,
--             its chat box as the chat; how we hold each part
--   2 rows    the Gamepad action bars row hidden then shown, the Chat window
--             row hidden then shown, then CineMode on and off: Forever's bar
--             and the game's chat stay invisible each time, its hotbars and
--             chat box go and come back; a shot of each
--   3 peek    a chat line with the chat faded: its chat box comes up for it,
--             with no copy of the line of ours (Show just those messages)
--   4 prompt  its interact prompt on its own row: up with the hotbar row
--             hidden, hidden with its own row hidden
--   5 back    your addon list back (a Reload), if step 0 changed it
-- Into CinematicDB.gamepadXIVSupportTestLog. Dev copy only.
local _, ns = ...

local ADDON = "GamepadXIV"
-- (The game's, made before any addon loads.)
local ChatFrame1, ChatFrame1EditBox, GeneralDockManager = _G.ChatFrame1, _G.ChatFrame1EditBox, _G.GeneralDockManager

local function DB() return rawget(_G, "GamepadXIVDB") end
local function Root() return rawget(_G, "GamepadXIVFrame") end
local function Box() return rawget(_G, "GamepadXIVChatBox") end
local function Bar() return rawget(_G, "GamepadMainActionBarFrame") end
local function Driver() return rawget(_G, "GamepadXIVDriver") end

local function GamepadUI()
	local input = rawget(_G, "InputUtil")
	return type(input) == "table" and type(input.IsGamepadUIEnabled) == "function" and input.IsGamepadUIEnabled() == true
end

-- Its bars in use: on, and not giving way to Forever's (a vehicle, its editor).
local function Active()
	local driver = Driver()
	return type(driver) == "table" and driver:GetAttribute("fc-yield") == 0
end

local function Effective(frame)
	if type(frame) ~= "table" then return nil end
	local alpha = frame:GetEffectiveAlpha()
	if issecretvalue and issecretvalue(alpha) then return nil end
	return ns.Flag(frame:IsVisible()) and alpha or 0
end

-- Seen on screen (nil: secret, not judged).
local function Drawn(frame)
	local alpha = Effective(frame)
	if alpha == nil then return nil end
	return alpha > 0.05
end

-- Its interact prompt: found the way the support file does.
local function Prompt()
	local root = Root()
	if type(root) ~= "table" then return nil end
	local picker = rawget(root, "setPicker")
	for _, child in ipairs({ root:GetChildren() }) do
		if child:GetName() == nil and child ~= picker and child:GetNumRegions() > 0 then return child end
	end
end

ns.TestKit.DefineAddonReady(ADDON, {
	about = "the gamepad UI on, Gamepad XIV on with its hotbars in use, its chat box as the chat",
	ready = function()
		if type(DB()) ~= "table" then return false, "Gamepad XIV's settings aren't loaded" end
		if not GamepadUI() then return false, "the gamepad UI is off" end
		if type(Root()) ~= "table" then return false, "its hotbars aren't made (it stays off without the gamepad UI at login: Reload)" end
		if DB().enabled == false then return false, "Gamepad XIV is turned off (/gxiv on)" end
		if not ns.GamepadXIVOwnChat() then return false, "its Chat setting is the game's chat" end
		if not Active() then return false, "its hotbars give way to Forever's now (a vehicle, or Forever's bar editor open)" end
		local box = Box()
		if not (type(box) == "table" and ns.Flag(box:IsShown())) then return false, "its chat box isn't up" end
		return true
	end,
	make = function(r)
		local db = DB()
		if type(db) ~= "table" then return end
		-- (Its tutorial would take the face buttons 4 seconds after a login.)
		local account = rawget(_G, "GamepadXIVAccountDB")
		if type(account) == "table" and not account.tutorialSeen then
			r:Keep("gxiv:tutorialSeen", "<nil>")
			account.tutorialSeen = true
		end
		-- (The gamepad UI is yours to turn on: setting its CVar from addon code
		-- is blocked, run q6ff9. The guide's first lines.)
		local reload = false
		if db.chatUI ~= nil and db.chatUI ~= "gxiv" then
			r:Keep("gxiv:chatUI", db.chatUI)
			db.chatUI = "gxiv"
			reload = true
		end
		if db.enabled == false then
			r:Keep("gxiv:enabled", false)
			db.enabled = true
			local slash = SlashCmdList and SlashCmdList.GAMEPADXIV
			if type(slash) == "function" then pcall(slash, "on") end
		end
		if type(Root()) ~= "table" then reload = true end
		if reload then
			r:WaitFor("Reload, for Gamepad XIV's chat box and hotbars", { check = function() return false end,
				buttons = { { kind = "reload" } } })
		end
		r:Sleep(1)
	end,
	putBack = function(extra)
		local said = {}
		local db, account = DB(), rawget(_G, "GamepadXIVAccountDB")
		if extra["gxiv:tutorialSeen"] and type(account) == "table" then
			account.tutorialSeen = nil
			said[#said + 1] = "tutorial flag"
		end
		if extra["gxiv:chatUI"] and type(db) == "table" then
			db.chatUI = extra["gxiv:chatUI"]
			said[#said + 1] = "Chat setting (from the next Reload)"
		end
		if extra["gxiv:enabled"] == false and type(db) == "table" then
			local slash = SlashCmdList and SlashCmdList.GAMEPADXIV
			if type(slash) == "function" then pcall(slash, "off") else db.enabled = false end
			said[#said + 1] = "turned off again"
		end
		if #said == 0 then return nil end
		return "Gamepad XIV put back: " .. table.concat(said, ", ")
	end,
	guide = {
		"Plug in your controller and press a button on it.",
		"Press Escape, click Options, then Gamepad: tick Enable Gamepad UI.",
		"Type /gxiv on",
	},
})

local function Fields(r, label)
	r:Fields(label, {
		barAlpha = function() return Bar():GetAlpha() end,
		barDrawn = function() return Drawn(Bar()) end,
		barFaded = function() return ns.IsFaded(Bar()) end,
		hotbarAlpha = function() return Effective(Root()) end,
		chat1Alpha = function() return ChatFrame1:GetAlpha() end,
		chat1Drawn = function() return Drawn(ChatFrame1) end,
		chat1LeftAlone = function() return ns.IsLeftAlone("ChatFrame1") end,
		dockDrawn = function() return Drawn(GeneralDockManager) end,
		boxAlpha = function() return Effective(Box()) end,
		chatIsDefault = function() return ns.ChatIsDefault() end,
		active = function() return Active() end,
		cineMode = function() return ns.IsCineModeOn and ns.IsCineModeOn() end,
		-- (The icons left at the bottom middle with the gamepad bars row
		-- hidden, run q6ef6: the Cooldown Manager's, its own row?)
		cdmDrawn = function() return Drawn(rawget(_G, "EssentialCooldownViewer")) end,
		cdmFaded = function()
			local viewer = rawget(_G, "EssentialCooldownViewer")
			return viewer and ns.IsFaded(viewer)
		end,
		petButtonDrawn = function()
			local unit = Bar() and rawget(Bar(), "PageUnit")
			return unit and rawget(unit, "LeftClassAction") and Drawn(unit.LeftClassAction)
		end,
	})
end

local function Force(key, state)
	ns.db.frameForce[key] = state
	if ns.db.frameForceAt then ns.db.frameForceAt[key] = state and GetTime() or nil end
	ns.RefreshFrameForce()
end

-- What must hold at every step: Forever's bar (while its own stand in) and
-- the game's chat (while you aren't typing in it) unseen.
local function GameHidden(r, label)
	if Active() then
		r:Verdict(Drawn(Bar()) == false, label .. ": Forever's gamepad bar stays invisible (its hotbars stand in)")
	end
	local typing = ChatFrame1EditBox and ns.Flag(ChatFrame1EditBox:HasFocus())
	if not typing then
		r:Verdict(Drawn(ChatFrame1) == false and Drawn(GeneralDockManager) == false,
			label .. ": the game's chat window and tabs stay invisible (its chat box stands in)")
	end
end

local function Check(r, label, hotbarUp, boxUp)
	r:Sleep(1.5)
	Fields(r, label)
	GameHidden(r, label)
	local hotbar, box = Effective(Root()), Effective(Box())
	if hotbarUp ~= nil and hotbar ~= nil and Active() then
		r:Verdict((hotbar > 0.3) == hotbarUp, ("%s: its hotbars %s (%.2f)"):format(label, hotbarUp and "up" or "hidden", hotbar))
	end
	if boxUp ~= nil and box ~= nil then
		r:Verdict((box > 0.3) == boxUp, ("%s: its chat box %s (%.2f)"):format(label, boxUp and "up" or "hidden", box))
	end
	r:Shot(label .. ": one hotbar set (its) or none, one chat (its box) or none")
end

ns.TestKit.Define({
	name = "gamepadxiv",
	key = "gamepadXIVSupportTest",
	title = "Gamepad XIV hotbars and chat",
	about = "Forever's gamepad bar and the game's chat stay hidden under Gamepad XIV's while our rows and CineMode fade",
	needs = "Gamepad XIV, the gamepad UI (your controller)",
	cineMode = true,
	settings = { "handleChat", "chatPeek", "chatPeekLinesOnly" },
	context = function()
		return ("Gamepad XIV up: %s, gamepad UI: %s, its bars in use: %s, its chat: %s"):format(
			tostring(ns.AddonUp(ADDON)), tostring(GamepadUI()), tostring(Active()), tostring(ns.GamepadXIVOwnChat
				and ns.GamepadXIVOwnChat()))
	end,
	putBack = function(extra)
		local row = extra["gxiv:promptRow"]
		if row ~= nil then
			if row == "<nil>" then row = nil end
			ns.db.addonFrames.gxivPrompt = row
			if ns.BuildManagedList then pcall(ns.BuildManagedList) end
		end
		for _, key in ipairs({ "gamepadbars", "chat", "addon:gxivPrompt" }) do
			local was = extra["force:" .. key]
			if was ~= nil then Force(key, was ~= "<nil>" and was or nil) end
		end
		if ns.IsCineModeOn and Cinematic_ToggleCineMode and extra.cineWas ~= nil
			and (ns.IsCineModeOn() and true or false) ~= extra.cineWas then
			Cinematic_ToggleCineMode()
		end
		return "rows and CineMode as they were"
	end,
	steps = {
		{ key = "solo", title = "Gamepad XIV alone with Cinematic", run = function(r)
			if ns.AddonUp(ADDON) then r:Log("Gamepad XIV already loaded") return end
			if not ns.SoloAddons then r:Fail("no /cine debug solo here (dev copy only)") return end
			if type(CinematicDB.soloAddons) == "table" then ns.SoloAddons("off", true) end
			ns.SoloAddons(ADDON, true)
			CinematicDB.gamepadXIVTestSolo = true
			r:Log("solo for Gamepad XIV: " .. table.concat(CinematicDB.soloAddons and CinematicDB.soloAddons.keep or {}, ", "))
			r:WaitFor("Reload, for Gamepad XIV alone with Cinematic",
				{ check = function() return false end, buttons = { { kind = "reload" } } })
		end },
		{ key = "setup", title = "Gamepad XIV set up, how we hold its parts", run = function(r)
			if not ns.AddonUp(ADDON) then r:Fail("Gamepad XIV isn't loaded") return end
			r:AddonReady(ADDON)
			for _, key in ipairs({ "gamepadbars", "chat", "addon:gxivPrompt" }) do
				r:Keep("force:" .. key, ns.db.frameForce[key] or "<nil>")
			end
			r:Keep("cineWas", ns.IsCineModeOn and ns.IsCineModeOn() and true or false)
			r:Sleep(2) -- (our scanner finds its frames)
			Fields(r, "at start")
			r:Verdict(ns.IsFaded(Root()), "its hotbars are faded by us (Gamepad action bars row)")
			r:Verdict(ns.IsFaded(Box()), "its chat box is faded by us (Chat window row)")
			r:Verdict(ns.IsLeftAlone("ChatFrame1") and ns.IsLeftAlone("GeneralDockManager") and not ns.IsFaded(ChatFrame1),
				"the game's chat window and tab bar are left to it")
			r:Verdict(ns.ChatIsDefault() == false, "chat isn't the game's own (no line copies over its box)")
			GameHidden(r, "at start")
		end },
		{ key = "rows", title = "the rows hidden, shown; CineMode on, off (hands off)", seconds = 20, run = function(r)
			if type(Root()) ~= "table" then r:Skip("no Gamepad XIV hotbars") return end
			if ns.IsCineModeOn and ns.IsCineModeOn() then Cinematic_ToggleCineMode() end
			Force("gamepadbars", "hide")
			Check(r, "Gamepad action bars row hidden", false, nil)
			Force("gamepadbars", "show")
			Check(r, "Gamepad action bars row shown", true, nil)
			Force("gamepadbars", nil)
			Force("chat", "hide")
			Check(r, "Chat window row hidden", nil, false)
			Force("chat", "show")
			Check(r, "Chat window row shown", nil, true)
			Force("chat", nil)
			if Cinematic_ToggleCineMode then
				Cinematic_ToggleCineMode()
				Check(r, "CineMode on", nil, nil)
				Cinematic_ToggleCineMode()
				Check(r, "CineMode off again", true, true)
			end
		end },
		{ key = "peek", title = "a chat line brings up its chat box (hands off)", seconds = 8, run = function(r)
			if type(Box()) ~= "table" then r:Skip("no Gamepad XIV chat box") return end
			r:Set("handleChat", true)
			r:Set("chatPeek", true)
			r:Set("chatPeekLinesOnly", true)
			Force("chat", "hide")
			r:Sleep(1.5)
			Force("chat", nil)
			if not (ns.IsCineModeOn and ns.IsCineModeOn()) and Cinematic_ToggleCineMode then Cinematic_ToggleCineMode() end
			r:Sleep(1.5)
			local before = Effective(Box())
			-- (A line in its box, and the peek a chat line makes: UI/Chat.lua.)
			ChatFrame1:AddMessage("Cinematic test: a chat line for Gamepad XIV's box", 1, 0.8, 0)
			r:Verdict(ns.ChatWindowShown(ChatFrame1), "the main chat window counts as up: its box is its panel")
			ns.PeekChat(ChatFrame1, 5)
			r:Sleep(1)
			Fields(r, "after a line")
			local after = Effective(Box())
			r:Log(("its chat box %s before the line, %s after"):format(tostring(before), tostring(after)))
			r:Verdict(after ~= nil and after > 0.3, "its chat box comes up for the line")
			r:Verdict(ns.ChatPeekLinesOnly() == false, "Show just those messages stands aside (its box draws the line)")
			GameHidden(r, "after a line")
			r:Shot("a line: its chat box up, no copy of the line of ours")
			if ns.IsCineModeOn and ns.IsCineModeOn() then Cinematic_ToggleCineMode() end
		end },
		{ key = "prompt", title = "its interact prompt on its own row (hands off)", seconds = 8, run = function(r)
			local prompt = Prompt()
			if not prompt then r:Skip("its interact prompt isn't made") return end
			local ignoring = prompt:IsIgnoringParentAlpha()
			r:Verdict(ignoring == true, "the prompt no longer follows its hotbar frame's alpha")
			-- (It shows only next to something you can use, and it hides itself
			-- again within 0.15 s: read by its own alpha, which our fade sets and
			-- which is all that counts now that the hotbar's doesn't reach it.)
			local function Own()
				local alpha = prompt:GetAlpha()
				if issecretvalue and issecretvalue(alpha) then return nil end
				return alpha
			end
			-- (Its row on, for the step: off, we leave it be, up whatever the
			-- bars do. Off on a profile from before, as other addons' new rows.)
			local was = ns.db.addonFrames.gxivPrompt
			r:Keep("gxiv:promptRow", was == nil and "<nil>" or was)
			ns.db.addonFrames.gxivPrompt = true
			if ns.BuildManagedList then pcall(ns.BuildManagedList) end
			r:Sleep(1)
			r:Verdict(ns.IsFaded(prompt), "with its row on, the prompt is faded by us")
			Force("gamepadbars", "hide")
			Force("addon:gxivPrompt", "show")
			r:Sleep(1.5)
			local up, hotbar = Own(), Effective(Root())
			r:Log(("prompt alpha %s, its hotbars %s"):format(tostring(up), tostring(hotbar)))
			r:Verdict(up ~= nil and up > 0.3, "up with the hotbars hidden")
			Force("addon:gxivPrompt", "hide")
			r:Sleep(1.5)
			local down = Own()
			r:Verdict(down ~= nil and down < 0.05, "hidden with its own row hidden (" .. tostring(down) .. ")")
			Force("addon:gxivPrompt", nil)
			Force("gamepadbars", nil)
		end },
		{ key = "back", title = "your addon list back", run = function(r)
			if not CinematicDB.gamepadXIVTestSolo then r:Log("Gamepad XIV was loaded already: list left as it was") return end
			CinematicDB.gamepadXIVTestSolo = nil
			ns.SoloAddons("off", true)
			r:Log("addon list put back")
			r:WaitFor("Reload, to get your addons back",
				{ check = function() return false end, buttons = { { kind = "reload" } } })
		end },
		{ key = "done", title = "done", run = function(r)
			r:Log("addons now: " .. (ns.AddonUp(ADDON) and "Gamepad XIV still loaded" or "your list"))
		end },
	},
})
