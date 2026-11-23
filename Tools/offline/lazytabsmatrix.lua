-- A tab switched off, every state (the audit kit's matrix, Tools/offline/matrix.lua;
-- fix card Tools/audits/2026-11-22-settings-lazy-tabs.md):
--   python -I Tools/offline/run.py Tools/offline/lazytabsmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/lazytabsmatrix.lua --base <ref>
-- A setting under a tab: Nameplates' Enemy tab (plateOwnPartsEnemies, read as
-- it's used), Graphics+'s Sky and water tab (graphicsPlusSky, a game setting
-- written once), the Chat page's Updates tab (updateNotice: the What's new
-- line in chat at login, WhatsNew.lua). Its page made
-- (opened once) or not (login, a /reload), the page's switch, the tab's
-- switch, and how the tab got its state: saved (a login, a profile) or
-- flipped on the page (a right-click on the tab: only once the page is made).
-- Each cell: the setting's effect, "on" or "off" (Graphics+: "ours" written or
-- "game" its own). The rule (the switch tree): on only with its page, its tab
-- and its own tick all on; a flip takes effect at once.
-- (7c3e0c1 audit 2026-11-22: a tab off read on till its page was opened, and
-- Graphics+ never read its tabs, nor wrote again on a tab's flip.)

local client = arg and arg[1] or "forever"
local cvars = { skyCloudLod = "1" }
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	GetCVar = function(name) return cvars[name] end
	SetCVar = function(name, value) cvars[name] = tostring(value) end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db

-- The update notice at login (WhatsNew.lua): the frame that says it, its
-- login run again per cell (it lets go of its event after one).
local noticeRun
for _, frame in ipairs(wow.frames) do
	local script = frame:GetScript("OnEvent")
	if script and frame._events.PLAYER_ENTERING_WORLD then
		for i = 1, 30 do
			local name = debug.getupvalue(script, i)
			if not name then break end
			if name == "FeaturesSince" then
				noticeRun = function() script(frame, "PLAYER_ENTERING_WORLD", true, false) end
			end
		end
	end
end
local function NoticeShown()
	if not noticeRun then return "no notice frame" end
	local shown = false
	local Show, After = ns.ShowUpdateNotice, C_Timer.After
	ns.ShowUpdateNotice = function() shown = true end
	C_Timer.After = function(_, fn) fn() end -- luacheck: ignore 122
	db.lastFeatureDate, ns.newInstall = "2000-01-01", false
	local ok, err = pcall(noticeRun)
	ns.ShowUpdateNotice, C_Timer.After = Show, After -- luacheck: ignore 122
	if not ok then error(err, 0) end
	return shown and "on" or "off"
end

local PAGES = {
	plates = { name = "Nameplates", page = "handlePlates", tab = "tabOn:Nameplates:Enemy",
		key = "plateOwnPartsEnemies" },
	gfx = { name = "Graphics+", page = "graphicsPlus", tab = "tabOn:Graphics+/tab:2", key = "graphicsPlusSkyOn" },
	chat = { name = "Chat", page = "handleChat", tab = "tabOn:Chat/page:5", key = "updateNotice" },
}
local function Waiting(name)
	for _, entry in ipairs(ns.lazySettingsPages or {}) do
		if entry.name == name then return entry end
	end
end
local made = false
local function MakePages()
	if made then return end
	made = true
	for _, p in pairs(PAGES) do
		local entry = Waiting(p.name)
		if entry and not entry.made then entry.Make("lazytabsmatrix") end
	end
	if ns.MapTabContainers then ns.MapTabContainers() end -- (a timer in game)
end
local function Outcome(p)
	if p.key == "graphicsPlusSkyOn" then return cvars.skyCloudLod == "3" and "ours" or "game" end
	if p.key == "updateNotice" then return NoticeShown() end -- (what the player gets: the line in chat)
	return ns.Setting(p.key) and "on" or "off"
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "lazytabs-switch",
	fixed = { client = client },
	dims = {
		{ "made", { "no", "yes" } }, -- (first: a page once made stays made)
		{ "page", { "plates", "gfx", "chat" } },
		{ "pageSwitch", { "on", "off" } },
		{ "tab", { "on", "off" } },
		{ "how", { "saved", "flipped" } },
	},
	cell = function(c)
		if c.made == "yes" then MakePages() elseif c.how == "flipped" then return "n/a" end
		local p = PAGES[c.page]
		db.visualEffects, db.handleNames, db.handleFrames = true, true, true -- (the hubs above the pages)
		db.graphicsPlusSky = 3
		db[p.page], db[p.key] = c.pageSwitch == "on", true
		if c.how == "saved" then
			db[p.tab] = c.tab == "on"
			if ns.ApplyGraphicsPlus then ns.ApplyGraphicsPlus() end
		else
			-- (The tab the other way, written as it was; then its switch flipped.)
			db[p.tab] = c.tab ~= "on"
			if ns.ApplyGraphicsPlus then ns.ApplyGraphicsPlus() end
			ns.FlipSettingKey(p.tab)
			if (db[p.tab] == true) ~= (c.tab == "on") then return "no flip" end
		end
		local out = Outcome(p)
		db[p.tab], db[p.page] = true, true
		if ns.ApplyGraphicsPlus then ns.ApplyGraphicsPlus() end
		return out
	end,
	pins = {
		{ "", "off" },
		{ "page=plates pageSwitch=on tab=on", "on" },
		{ "page=chat pageSwitch=on tab=on", "on" },
		{ "page=gfx", "game" },
		{ "page=gfx pageSwitch=on tab=on", "ours" },
		-- (No page made: no tab to right-click.)
		{ "made=no how=flipped", "n/a" },
	},
})
