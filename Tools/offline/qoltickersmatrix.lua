-- Two timers that ran for good (the audit kit's matrix, Tools/offline/matrix.lua;
-- fix card Tools/audits/2026-11-25-qol-tickers.md):
--   python -I Tools/offline/run.py Tools/offline/qoltickersmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/qoltickersmatrix.lua forever --base <ref>
-- reload-key: the Reload button and key (QoL/Reload.lua). Show a Reload button
-- ticked or not, its page on or off, the Keybinds tab with the Reload key on
-- or off. After a second (the change seen), two more pass. Each cell: whether
-- the button shows, and how often the key's binding was read in those two
-- seconds (Forever: the key is ours there; retail has no key of ours).
-- conflict-holds: an Addon Conflicts row that hides a frame, its pick Theirs
-- or Ours, its addon's version on or off. Each cell: whether its frame is
-- held hidden, and whether the holds were looked at in two seconds.
-- The rule: no work while nothing can change: the button and key looked at
-- as their settings change, the holds only while a row can hold.
local client = arg and arg[1] or "forever"
local tickers = {}
local loaded = false
local bindingReads = 0
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	C_Timer = {
		After = function(_, fn) if loaded then pcall(fn) end end,
		NewTimer = function() return { Cancel = function() end } end,
		NewTicker = function(_, fn)
			local t = { fn = fn, live = true, mine = loaded }
			t.Cancel = function() t.live = false end
			tickers[#tickers + 1] = t
			return t
		end,
	}
	GetBindingKey = function(action)
		if action == "CINEMATIC_RELOAD" then bindingReads = bindingReads + 1; return "F5" end
	end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
loaded = true
local db = ns.db
-- (The timers made at the load: the old Reload one among them. Each from then on too.)
for _, t in ipairs(tickers) do t.mine = true end

local function Second()
	ns.SyncFeatureLoops()
	for i = 1, #tickers do
		local t = tickers[i]
		if t.live and t.mine and t.fn ~= nil then
			pcall(t.fn)
			pcall(t.fn) -- (twice a second for the half-second ones: close enough for a count)
		end
	end
end

local holdsLooked = 0
local update = ns.UpdateConflictHolds
ns.UpdateConflictHolds = function(...)
	holdsLooked = holdsLooked + 1
	return update(...)
end
local theirsOn = false
local theirFrame = wow.CreateFrame("Frame", "CinematicTestTheirFrame", UIParent)
local theirAlpha = 1
rawset(theirFrame, "SetAlpha", function(_, a) theirAlpha = a end)
rawset(theirFrame, "GetAlpha", function() return theirAlpha end)
local row = ns.AddConflict({ addon = "TestAddon", key = "testHold", label = "Test", group = "frames",
	theirs = function() return theirsOn end, hide = { "CinematicTestTheirFrame" } })

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = client == "retail" and "reload-key-retail" or "reload-key", -- (no key of ours on retail)
	fixed = { client = client },
	dims = {
		{ "tick", { "on", "off" } },
		{ "page", { "on", "off" } },
		{ "keytab", { "on", "off" } },
	},
	cell = function(c)
		local tabKey = ns.KeybindTabKey and ns.KeybindTabKey("CINEMATIC_RELOAD")
		db.handleQuality, db.reloadButton = c.page == "on", c.tick == "on"
		if tabKey then db[tabKey] = c.keytab == "on" end
		Second()
		bindingReads = 0
		Second()
		Second()
		local shown = _G.CinematicReloadButton and _G.CinematicReloadButton:IsShown()
		local out = ("button=%s reads=%s"):format(shown and "shown" or "hidden", bindingReads > 0 and "yes" or "no")
		if tabKey then db[tabKey] = true end
		return out
	end,
	pins = {
		{ "", "button=hidden reads=no" },
		{ "tick=on page=on", "button=shown reads=no" },
	},
})
Matrix.Run({
	name = "conflict-holds",
	fixed = { client = client },
	dims = {
		{ "pick", { "theirs", "ours" } },
		{ "addon", { "on", "off" } },
	},
	cell = function(c)
		db.conflictPicks = db.conflictPicks or {}
		db.conflictPicks[row.id] = c.pick
		theirsOn = c.addon == "on"
		Second()
		holdsLooked = 0
		Second()
		Second()
		local out = ("held=%s looked=%s"):format(theirFrame:GetAlpha() == 0 and "yes" or "no",
			holdsLooked > 0 and "yes" or "no")
		-- (Let go for the next cell.)
		db.conflictPicks[row.id] = "theirs"
		theirsOn = false
		update()
		Second()
		return out
	end,
	pins = {
		{ "pick=theirs", "held=no looked=no" },
		{ "pick=ours addon=on", "held=yes looked=yes" },
		{ "pick=ours addon=off", "held=no looked=yes" },
	},
})
