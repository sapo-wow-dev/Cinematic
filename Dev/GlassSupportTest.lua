-- /cine debug glasssupport (dev copy only): two of our chat features with
-- Glass, which keeps the game's chat windows hidden and draws their lines on
-- frames of its own (Support/Glass.lua links each as its window's panel).
-- Hands off but for Reload clicks: Glass alone with Cinematic first, your
-- addon list back last (only when Glass wasn't loaded).
--   solo/back  Glass alone for the run, then your addons back
--   1 panel   the General window's lines are on its Glass frame (its panel)
--   2 copy    the Copy chat button: with the mouse "over" that frame (its
--             IsMouseOver stood in for the step), the button shows, on the
--             Glass frame, not the hidden window (UI/ChatCopy.lua)
--   3 hold    chat scrolled up in Glass (its frame's state, set for the step)
--             holds the chat up past the peek time (ns.HoldScrolledChat)
-- Into CinematicDB.glassSupportTestLog.
local _, ns = ...

local function GeneralPanel()
	local cf = rawget(_G, "ChatFrame1")
	return cf, cf and ns.chatPeekPanels and ns.chatPeekPanels[cf]
end

local function Glassless(r)
	local IsLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
	if not IsLoaded("Glass") then r:Skip("Glass isn't loaded") return true end
end

ns.TestKit.Define({
	name = "glasssupport",
	key = "glassSupportTest",
	title = "Glass support",
	about = "Copy chat button and the scrolled-up hold on Glass's chat frames, nothing to do",
	settings = { "chatCopyButton", "handleChat" },
	context = function()
		local cf, panel = GeneralPanel()
		return ("General shown %s, panel %s"):format(tostring(cf and cf:IsShown()), tostring(panel ~= nil))
	end,
	steps = {
		-- (Glass alone with Cinematic for the run, as the addon kit does: your
		-- addon list back at the end. Two Reload clicks, only when Glass isn't
		-- loaded already.)
		{ key = "solo", title = "Glass loaded", run = function(r)
			local IsLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
			if IsLoaded("Glass") then return r:Log("Glass already loaded") end
			if not ns.SoloAddons then return r:Skip("no solo here") end
			ns.SoloAddons("Glass", true)
			CinematicDB.glassSupportSolo = true
			r:Log("solo for Glass: " .. table.concat(CinematicDB.soloAddons and CinematicDB.soloAddons.keep or {}, ", "))
			r:WaitFor("Reload, for Glass alone with Cinematic", { check = function() return false end,
				buttons = { { kind = "reload" } } })
		end },
		{ key = "panel", title = "General's lines on its Glass frame", run = function(r)
			if Glassless(r) then return end
			local giveUp = GetTime() + 10 -- (our scanner claims Glass's frames soon after login)
			r:WaitFor(nil, { handsOff = true, check = function()
				local _, panel = GeneralPanel()
				return (panel ~= nil or GetTime() > giveUp) or nil
			end })
			local cf, panel = GeneralPanel()
			r:Fields("General", {
				shown = function() return cf:IsShown() end,
				panel = function() return panel ~= nil end,
				panelShown = function() return panel and panel:IsShown() end,
				windowShown = function() return ns.ChatWindowShown(cf) end,
			})
			r:Verdict(panel ~= nil and not ns.Flag(cf:IsShown()) and ns.ChatWindowShown(cf),
				"General hidden, its lines on its Glass frame, which counts as shown")
		end },
		{ key = "copy", title = "Copy chat button on the Glass frame", run = function(r)
			if Glassless(r) then return end
			local cf, panel = GeneralPanel()
			if not panel then r:Fail("no Glass frame for General") return end
			r:Set("chatCopyButton", true)
			local had = rawget(panel, "IsMouseOver")
			panel.IsMouseOver = function() return true end
			ns.ChatCopyCheck()
			local button = ns.chatCopyButtons[cf]
			local shown = button and ns.Flag(button:IsVisible())
			local onPanel = button and button:GetParent() == panel
			r:Log(("button %s, visible %s, parent is the Glass frame %s"):format(tostring(button ~= nil),
				tostring(shown), tostring(onPanel)))
			if shown then r:Shot("Copy chat button on Glass's frame", { behind = panel }) end
			panel.IsMouseOver = had
			ns.ChatCopyCheck()
			local gone = not (button and ns.Flag(button:IsShown()))
			r:Verdict(shown and onPanel and gone,
				"shows on the Glass frame with the mouse over it, goes with the mouse off")
		end },
		{ key = "hold", title = "scrolled up in Glass holds chat up", run = function(r)
			if Glassless(r) then return end
			local cf, panel = GeneralPanel()
			local state = panel and rawget(panel, "state")
			if type(state) ~= "table" then r:Fail("no state on General's Glass frame") return end
			r:Set("handleChat", true)
			local was = state.scrollAtBottom
			local now = GetTime()
			ns.chatPeekUntil[cf] = nil
			state.scrollAtBottom = false
			ns.HoldScrolledChat(now)
			local held = ns.chatPeekUntil[cf]
			state.scrollAtBottom = true
			ns.chatPeekUntil[cf] = nil
			ns.HoldScrolledChat(now)
			local notHeld = ns.chatPeekUntil[cf]
			state.scrollAtBottom = was
			ns.chatPeekUntil[cf] = nil
			r:Log(("scrolled up: held until +%s; at the bottom: %s (Glass's own value %s)"):format(
				held and ("%.1f"):format(held - now) or "nil", tostring(notHeld), tostring(was)))
			r:Verdict(held ~= nil and held > now and notHeld == nil,
				"scrolled up holds the chat up, at the bottom doesn't")
		end },
		{ key = "back", title = "your addon list back", run = function(r)
			if not CinematicDB.glassSupportSolo then return r:Log("solo wasn't set by this test") end
			CinematicDB.glassSupportSolo = nil
			ns.SoloAddons("off", true)
			r:Log("addon list put back")
			r:WaitFor("Reload, to get your addons back", { check = function() return false end,
				buttons = { { kind = "reload" } } })
		end },
	},
})
