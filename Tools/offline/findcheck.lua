-- Does /cine find <id> land on its control? Outside the game, for the
-- /support skill's find_ids.py (--check, on by default): each id is run
-- through the real ns.FindSetting, as the slash command does, its timers run,
-- and what it glowed is checked. From the repo root:
--
--   python -I Tools/offline/run.py Tools/offline/findcheck.lua <client> <toc> <id> [id...]
--
-- Prints one tab-separated line per id: "find", the id, a verdict, what
-- /cine find printed (its text and page), and what the glow sits on:
--   ok      the id's own control, its page open, everything above it shown
--   hidden  the glow's target or one of its parents is hidden (a closed
--           tab, a dropped header): the player sees nothing glow
--   noglow  the page opened but nothing glowed
--   fuzzy   the id isn't one /cine find takes: its words were searched
--           instead, and it landed on whatever matched
--   none    /cine find says nothing matches
-- (The stand-in has no layout: "ok" is shown-ness, not on-screen position.
-- The in-game proof is /cine debug findtabs <id>.)

local client, toc = arg[1] or "forever", arg[2] or "Cinematic.toc"
local ids = {}
for i = 3, #arg do ids[#ids + 1] = arg[i] end

local ns, wow = dofile("Tools/offline/load.lua")(client, toc)

-- Timers run (ShowMatch glows after C_Timer.After), anchors kept, and
-- IsVisible as the game's: shown, and every parent shown.
local queue = {}
C_Timer.After = function(_, fn) queue[#queue + 1] = fn end -- luacheck: ignore 122 (the stand-in's timer)
local function RunTimers()
	for _ = 1, 10 do
		local now = queue
		if #now == 0 then return end
		queue = {}
		for _, fn in ipairs(now) do pcall(fn) end
	end
end
local Methods = wow.Methods
local setPoint = Methods.SetPoint
Methods.SetPoint = function(self, point, relative, ...)
	self._anchors = self._anchors or {}
	if type(relative) == "table" then self._anchors[point] = relative end
	if setPoint then return setPoint(self, point, relative, ...) end
end
Methods.ClearAllPoints = function(self) self._anchors = {} end
local function Visible(frame)
	while frame do
		if frame._shown == false then return false end
		frame = frame._parent
	end
	return true
end
Methods.IsVisible = function(self) return Visible(self) end

-- The first hidden one from the frame up (nil: all shown).
local function FirstHidden(frame)
	local depth = 0
	while frame do
		if frame._shown == false then return frame, depth end
		frame, depth = frame._parent, depth + 1
	end
end

local function Describe(frame)
	if not frame then return "nothing" end
	local label = frame.searchLabel or (frame.GetText and frame:GetText()) or frame.switchPage
	if type(label) == "table" and label.GetText then label = label:GetText() end
	return ("%s%s"):format(frame._kind or "?", label and (" \"" .. tostring(label) .. "\"") or "")
end

ns.MakeLazyPages("findcheck")
for _, id in ipairs(ids) do
	local gate = ns.DEFAULTS[id] ~= nil or id:find("^row:") or id:find("^cvar:")
		or (ns.MarkRowDefault and ns.MarkRowDefault(id) ~= nil)
	local entry = ns.FindEntryOf and ns.FindEntryOf(id)
	local ok, text, page = pcall(ns.FindSetting, id)
	RunTimers()
	local verdict, target
	if not ok then
		verdict, text = "error", tostring(text)
	elseif not text then
		verdict = "none"
	elseif not (gate and entry) then
		verdict = "fuzzy"
	else
		local glow = entry.page.canvas and entry.page.canvas.searchGlow
		target = glow and glow._anchors and glow._anchors.TOP
		if not (glow and glow._shown) then
			verdict = "noglow"
		elseif not Visible(target) then
			verdict = "hidden"
		else
			verdict = "ok"
		end
		if glow then glow:Hide() end
	end
	print(("find\t%s\t%s\t%s (%s)\t%s"):format(id, verdict, tostring(text), tostring(page),
		target and (Describe(target) .. (Visible(target) and "" or
			(", hidden at " .. Describe((FirstHidden(target))) .. " " .. tostring(select(2, FirstHidden(target)))
			.. " up, " .. tostring((FirstHidden(target))._name)))) or "-"))
end
