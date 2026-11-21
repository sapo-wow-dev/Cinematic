-- /cine debug selftextpage (Dev/SelfTextPageTest.lua, a test kit test), offline
-- (Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/selftextpagetest.lua < /dev/null
-- The in-game preview test on the stand-in, through the kit: the command
-- starts it, CineMode goes off, its 8 steps run by themselves with real
-- verdicts (each can fail: checked by breaking one), 8 screenshots, your
-- settings and CineMode back at the end, after a stop, and after a /reload.
-- Says PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212 213
local now = 100
local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", function()
	GetTime = function() return now end
end)
local M = wow.Methods
function M:SetFont(file, size, flags) self._font = { file, size, flags } return true end
function M:GetFont() return self._font and self._font[1], self._font and self._font[2] end
function M:SetTextColor(r, g, b) self._color = { r, g, b } end
-- (Places kept, as the game does: the test reads them back for its spacing and middle checks.)
function M:SetPoint(point, rel, relPoint, x, y) self._point = { point, rel, relPoint, x or 0, y or 0 } end
function M:ClearAllPoints() self._point = nil end
function M:GetStringWidth() return 8 * #tostring(self._text or "") end
function M:GetPoint() if self._point then return unpack(self._point) end return "CENTER", nil, "CENTER", 0, 0 end
function M:GetTextColor() return unpack(self._color or { 1, 1, 1 }) end
function M:SetFormattedText(fmt, ...) self._text = fmt:format(tostring((...)), select(2, ...)) end
-- (A click runs its OnClick; alpha kept: the off card fades the page to 0.)
function M:Click(button) local fn = self._scripts.OnClick if fn then fn(self, button or "LeftButton") end end
-- (Show and Hide fire OnShow and OnHide on a change, as the game does: the Look
-- panels note which one is open there.)
function M:Show() if not self._shown then self._shown = true local fn = self._scripts.OnShow if fn then fn(self) end end end
function M:Hide() if self._shown then self._shown = false local fn = self._scripts.OnHide if fn then fn(self) end end end
function M:SetShown(on) if on then self:Show() else self:Hide() end end
function M:SetAlpha(a) self._alpha = a end
function M:GetAlpha() return self._alpha or 1 end
-- (Sizes kept: the stand-in says 100 x 20 for every frame, so a texts' layer
-- left at its first size matched its preview anyway.)
function M:SetSize(w, h) self._w, self._h = w, h end
function M:SetWidth(w) self._w = w end
function M:SetHeight(h) self._h = h end
function M:GetWidth() return self._w or 100 end
function M:GetHeight() return self._h or 20 end
function M:GetSize() return self:GetWidth(), self:GetHeight() end
function M:SetScale(k) self._scale = k end
function M:GetScale() return self._scale or 1 end
-- (A frame sized fires OnSizeChanged, as the game does: the docked window scales its preview there.)
local setSize = M.SetSize
function M:SetSize(w, h) setSize(self, w, h) local fn = self._scripts.OnSizeChanged if fn then fn(self, w, h) end end
local modelFile = 12345
M.GetModelFileID = function() return modelFile end
local timers, tickers = {}, {}
C_Timer.After = function(seconds, fn) timers[#timers + 1] = { at = now + seconds, fn = fn } end
C_Timer.NewTicker = function(every, fn)
	local t = { every = every, next = now + every, fn = fn, Cancel = function(self) self.cancelled = true end }
	tickers[#tickers + 1] = t
	return t
end
local shots = 0
Screenshot = function() shots = shots + 1 end
local cine = true
ns.IsCineModeOn = function() return cine end
_G.Cinematic_ToggleCineMode = function() cine = not cine end
ns.PadTestBox = function() end
ns.PadTestBoxHide = function() end
-- luacheck: pop

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end
local function Tick(seconds)
	for _ = 1, math.floor(seconds / 0.1 + 0.5) do
		now = now + 0.1
		local due = {}
		for i = #timers, 1, -1 do if timers[i].at <= now then due[#due + 1] = table.remove(timers, i) end end
		for i = #due, 1, -1 do due[i].fn() end
		-- (The boards' update loops, as the game runs them each frame.)
		for _, frame in ipairs(wow.frames) do
			local update = frame._scripts.OnUpdate
			if update and frame._shown and frame._isBoard then pcall(update, frame, 0.1) end
		end
		for _, t in ipairs(tickers) do
			if not t.cancelled and t.next <= now then t.next = now + t.every t.fn(t) end
		end
	end
end
-- (Mark the boards' layers: the screen's, and the preview's when it's made.)
_G.CinematicSelfText._isBoard = true
local realNewBoard = ns.SelfTextNewBoard
ns.SelfTextNewBoard = function(layer, ...)
	layer._isBoard = true
	return realNewBoard(layer, ...)
end
-- (The page's model watch runs each frame too: it hides you under the off card.)
if ns.selfTextPage and ns.selfTextPage.modelWatch then ns.selfTextPage.modelWatch._isBoard = true end
-- (The off card, as the hub draws it: the page's topmost frame faded to 0
-- while its switch is off. Off the hub, offline, nothing faded it.)
local realPaint = ns.PaintPageSwitches
ns.PaintPageSwitches = function(...)
	if realPaint then realPaint(...) end
	local page = ns.selfTextPage
	local top = page and page.preview
	while top and top:GetParent() do top = top:GetParent() end
	if top then top:SetAlpha(ns.db.selfTextStyle and 1 or 0) end
end
local function Has(want)
	for _, line in ipairs(CinematicDB.selfTextPageTestLog or {}) do if line:find(want, 1, true) then return line end end
end

local db = ns.db
db.selfTextStyle, db.selfTextSide, db.selfText_damageSize = false, "over", 1.3
ns.HandleSlash("debug selftextpage")
Check("/cine debug selftextpage starts the kit test", ns.TestKit.Running() ~= nil)
Check("CineMode off", cine == false)
local undo = CinematicDB.selfTextPageTestUndo
Check("settings kept for a reload", undo and undo.extra and undo.extra.selfText
	and undo.extra.selfText.selfTextSide == "over")
Tick(90)
for _, step in ipairs({ "model", "where", "bold", "kind", "merge", "crits", "games", "screen", "center", "page", "docked",
	"kinds", "tabs", "mark", "off" }) do
	Check("verdict " .. step .. ": PASS", Has("verdict PASS " .. step .. ":") ~= nil, Has(" " .. step .. ":"))
end
Check("DONE: 15 pass, 0 fail", Has("DONE: 15 pass, 0 fail") ~= nil, Has("DONE"))
Check("settings back", db.selfTextStyle == false and db.selfTextSide == "over" and db.selfText_damageSize == 1.3
	and CinematicDB.selfTextPageTestUndo == nil)
Check("CineMode back", cine == true)
Check("14 screenshots", shots == 14, shots)

-- A step that can't pass fails: no model loaded.
modelFile = 0
ns.HandleSlash("debug selftextpage")
Tick(90)
Check("no model: step 1 FAILs", Has("verdict FAIL model:") ~= nil, Has(" model:"))
modelFile = 12345

-- Stopped mid-run: all back.
db.selfTextSide = "split"
ns.HandleSlash("debug selftextpage")
Tick(2)
Check("mid-run: its own settings", db.selfTextStyle == true)
ns.HandleSlash("debug selftextpage")
Check("stopped: settings back", db.selfTextStyle == false and db.selfTextSide == "split" and cine == true)

-- A /reload mid-run: put back at the next login.
ns.HandleSlash("debug selftextpage")
Tick(2)
ns.TestKit.Running().stopped = true -- (the reload: nothing more runs)
Check("cut-off run left its undo", CinematicDB.selfTextPageTestUndo ~= nil)
cine = false
wow.Fire("PLAYER_ENTERING_WORLD")
Check("after a /reload: put back at login", db.selfTextStyle == false and db.selfTextSide == "split"
	and CinematicDB.selfTextPageTestUndo == nil and cine == true)
Check("no Lua error in the test", not Has("Lua error"), Has("Lua error"))

for _, warning in ipairs(wow.warnings) do
	if warning:find("SelfText", 1, true) then Check("load: " .. warning, false) end
end
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
