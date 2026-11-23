-- A pooled chat bubble kept on screen, every state (the audit kit's matrix, Tools/offline/matrix.lua;
-- fix card Tools/audits/2026-11-22-addons-bubble-hooks.md):
--   python -I Tools/offline/run.py Tools/offline/bubblehookmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/bubblehookmatrix.lua forever --base <ref>
-- The game reuses its bubbles. One first used anchored on its text (retail's
-- way), or hidden off the screen for our off-screen bubble, or new, is then
-- placed by the game near the top of the screen, and again for its next line.
-- The Chat Bubbles page's Keep bubbles on screen (bubblesOffTop) on, off, or
-- turned off after those lines. Each cell: where the bubble ends up: just
-- under the top line (kept on screen, from the game's last place), at the
-- game's own place, or somewhere else (a stale place: the game's earlier one).
-- The rule: from the game's latest place, always; lifted under the line only
-- with the page on. (bdb2e1d^: a bubble first seen text-anchored or hidden
-- had no SetPoint hook, so its saved place went stale.)

local client = arg and arg[1] or "forever"
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	hooksecurefunc = function(a, b, c)
		local tbl, name, fn = a, b, c
		if type(a) == "string" then tbl, name, fn = _G, a, b end
		local orig = tbl[name]
		rawset(tbl, name, function(...)
			local r = { orig(...) }
			fn(...)
			return unpack(r)
		end)
	end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db

local function Local(name)
	local seen = {}
	local function Walk(fn, depth)
		if type(fn) ~= "function" or seen[fn] or depth > 4 then return end
		seen[fn] = true
		for i = 1, 60 do
			local upName, value = debug.getupvalue(fn, i)
			if not upName then break end
			if upName == name and type(value) == "function" then return value end
			local found = Walk(value, depth + 1)
			if found then return found end
		end
	end
	for _, value in pairs(ns) do
		local found = Walk(value, 0)
		if found then return found end
	end
end
local Lift = Local("Lift")

-- The top line: UIParent 20 high here, its top tenth kept clear.
local LINE = 20 * 0.9
local BASE = 100 -- (the bubble's top with its point at 0)

-- A game bubble: its inside frame keeps its points, its top follows its first point.
local function NewBubble(text)
	local bubble = wow.CreateFrame("Frame", nil, WorldFrame)
	local inside = wow.CreateFrame("Frame", nil, bubble)
	local words = inside:CreateFontString()
	words:SetText(text)
	inside.String = words
	local points = {}
	rawset(inside, "SetPoint", function(_, point, to, rel, x, y)
		points[#points + 1] = { point, to, rel, x or 0, y or 0 }
	end)
	rawset(inside, "ClearAllPoints", function() for i = #points, 1, -1 do points[i] = nil end end)
	rawset(inside, "GetNumPoints", function() return #points end)
	rawset(inside, "GetPoint", function(_, i)
		local p = points[i or 1]
		if p then return unpack(p) end
	end)
	rawset(inside, "GetTop", function()
		local p = points[1]
		return BASE + (p and p[5] or 0)
	end)
	return bubble, inside, words
end

-- The game placing it: on the bubble, its top up by y.
local function GamePlaces(bubble, inside, y)
	inside:ClearAllPoints()
	inside:SetPoint("CENTER", bubble, "CENTER", 0, y)
end

local Matrix = dofile("Tools/offline/matrix.lua")
local n = 0
Matrix.Run({
	name = "bubble-hook",
	fixed = { client = client },
	dims = {
		{ "first", { "new", "text", "hidden" } },
		{ "page", { "on", "off", "offLater" } },
	},
	cell = function(c)
		if not Lift then return "Lift not found" end
		n = n + 1
		local said = "Line " .. n
		db.handleBubbles, db.bubblesOffTop = true, c.page ~= "off"
		local bubble, inside, words = NewBubble(said)
		if c.first == "text" then
			-- (Retail's way: its inside hangs off its text.)
			inside:SetPoint("TOP", words, "TOP", 0, 0)
			pcall(Lift, inside)
		elseif c.first == "hidden" then
			local bubbles = C_ChatBubbles
			C_ChatBubbles = { GetAllChatBubbles = function() return { bubble } end } -- luacheck: ignore 111 121
			pcall(ns.HideOffScreenBubble, said)
			C_ChatBubbles = bubbles -- luacheck: ignore 111 121
			-- (Gone, then reused: its OnHide gives it back.)
			local onHide = bubble:GetScript("OnHide")
			if onHide then pcall(onHide, bubble) end
		end
		-- (Reused for a line near the top, then the next line a bit higher.)
		GamePlaces(bubble, inside, 10)
		pcall(Lift, inside)
		GamePlaces(bubble, inside, 40)
		if c.page == "offLater" then db.bubblesOffTop = false end
		pcall(Lift, inside)
		local top = inside:GetTop()
		if math.abs(top - LINE) < 0.01 then return "spot=under the line" end
		if math.abs(top - (BASE + 40)) < 0.01 then return "spot=game's" end
		return ("spot=stale (top %.0f)"):format(top)
	end,
	pins = {
		{ "", "spot=under the line" },
		{ "page=off", "spot=game's" },
		{ "page=offLater", "spot=game's" },
	},
})
