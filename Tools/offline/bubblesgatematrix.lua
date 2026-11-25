-- Chat bubbles with the switches the page is under (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-chat-bubbles-gate.md):
--   python -I Tools/offline/run.py Tools/offline/bubblesgatematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/bubblesgatematrix.lua forever --base <ref>
-- The Chat Bubbles page on with every kind off here (so it writes chatBubbles
-- and chatBubblesParty 0 over the game's 1), then nothing turned off, or the
-- page's own switch (its Changed applies the page), or Chat's Show tab, or the
-- HUD's General, turned off, then two seconds pass (the game's timers run).
-- Each cell: the game's setting (ours = still 0, game = its own 1 back) and
-- whether the page's once-a-second loop still runs.
-- The rule (page off = every setting on it off; the switch it's under is its
-- page's too): with any of them off, the game's own back and no loop.
local client = arg and arg[1] or "forever"
local cvars = {}
local tickers = {}
local loaded = false
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	GetCVar = function(name) return cvars[name] or "1" end
	SetCVar = function(name, value) cvars[name] = tostring(value) end
	C_CVar = C_CVar or {}
	C_CVar.GetCVar = GetCVar
	C_CVar.SetCVar = SetCVar
	C_Timer = {
		After = function() end,
		NewTimer = function() return { Cancel = function() end } end,
		NewTicker = function(_, fn)
			local t = { fn = fn, live = true, mine = loaded }
			t.Cancel = function() t.live = false end
			tickers[#tickers + 1] = t
			return t
		end,
	}
	-- luacheck: pop
end
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
loaded = true
local db = ns.db

-- (A second passing: the feature loops synced, then each timer started since the load.)
local function Second()
	ns.SyncFeatureLoops()
	for i = 1, #tickers do
		local t = tickers[i]
		if t.live and t.mine then pcall(t.fn) end
	end
end
local function LoopOn()
	ns.SyncFeatureLoops()
	for _, t in ipairs(tickers) do
		if t.live and t.mine then return true end
	end
	return false
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "chatbubbles-gate",
	fixed = { client = client },
	dims = {
		{ "off", { "none", "page", "show", "hud" } },
	},
	cell = function(c)
		ns.RowOnNow = function() return false end -- (every kind off here)
		db.handleFrames, db.showInChat, db.handleBubbles = true, true, true
		cvars.chatBubbles, cvars.chatBubblesParty = "1", "1"
		ns.ApplyBubbles()
		Second()
		if cvars.chatBubbles ~= "0" then return "not written: " .. tostring(cvars.chatBubbles) end
		if c.off == "page" then
			db.handleBubbles = false
			ns.ApplyBubbles() -- (the page switch's Changed)
		elseif c.off == "show" then
			db.showInChat = false
		elseif c.off == "hud" then
			db.handleFrames = false
		end
		Second()
		Second()
		local value = cvars.chatBubbles
		local out = "cvar=" .. (value == "0" and "ours" or value == "1" and "game" or tostring(value))
			.. " loop=" .. (LoopOn() and "on" or "off")
		-- (Back to all on and the game's own, for the next cell.)
		db.handleFrames, db.showInChat, db.handleBubbles = true, true, false
		ns.ApplyBubbles()
		Second()
		return out
	end,
	pins = {
		{ "", "cvar=game loop=off" },
		{ "off=none", "cvar=ours loop=on" },
	},
})
