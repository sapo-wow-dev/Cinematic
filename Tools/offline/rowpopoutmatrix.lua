-- A Smart row's preview popped out, then closed (the audit kit's matrix, Tools/offline/matrix.lua;
-- fix card Tools/audits/2026-11-26-row-popout-close.md):
--   python -I Tools/offline/run.py Tools/offline/rowpopoutmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/rowpopoutmatrix.lua forever --base <ref>
-- A row's preview on its page in the settings, popped out (ns.PopPreviewOut: its window,
-- CinematicRowPreviewWindow), docked or undocked; then closed one way: the settings closed,
-- Escape (the game's CloseSpecialWindows: every UISpecialFrames window shown), the window's
-- x, or its pop-out button again; then the settings opened again or not. Each cell: the
-- window shown or hidden, the preview on its page or in the window, and whether it's drawn
-- (visible: its plate updating). Right (2026-11-26): every way puts it back and hides the
-- window; Escape closes it as other windows; nothing drawn while the settings are closed.
-- luacheck: ignore 111 112 113 121 122 212 431
local client = arg and arg[1] or "forever"
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function(w)
	UISpecialFrames = {}
	w.CreateFrame("Frame", "SettingsPanel", UIParent)
end)

-- (The stand-in's frames as the game's: hiding one runs its OnHide and its shown
-- children's; visible only with every parent shown.)
local M = wow.Methods
local function FireHide(frame)
	local fn = frame._scripts and frame._scripts.OnHide
	if fn then fn(frame) end
	for _, child in ipairs(frame._children or {}) do
		if child._shown then FireHide(child) end
	end
end
function M:IsVisible()
	local f = self
	while type(f) == "table" and rawget(f, "_shown") ~= nil do
		if not f._shown then return false end
		f = f._parent
	end
	return true
end
function M:Hide()
	if not self._shown then return end
	local was = self:IsVisible()
	self._shown = false
	if was then FireHide(self) end
end
function M:Show() self._shown = true end
function M:SetShown(on) if on then self:Show() else self:Hide() end end

local settings = SettingsPanel
local page = CreateFrame("Frame", nil, settings)
local preview = CreateFrame("Frame", nil, page)
preview.Refresh = function() end

-- (rawget: the stand-in answers an unknown global with a stub, its own parent and held.)
local function Window() return rawget(_G, "CinematicRowPreviewWindow") end
local function CloseButton(win)
	for _, child in ipairs({ win:GetChildren() }) do
		if child ~= win.dock and child ~= preview and child._kind == "Button" and child:GetScript("OnClick") then
			return child
		end
	end
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "rowpopout",
	fixed = { client = client },
	dims = { { "dock", { "docked", "undocked" } }, { "close", { "settings", "escape", "x", "again" } },
		{ "reopen", { "no", "yes" } } },
	cell = function(c)
		if not ns.PopPreviewOut then error("no row pop-out in this code (ns.PopPreviewOut)") end
		settings:Show()
		page:Show()
		-- (back on its page from the last cell)
		local win = Window()
		if win and win.held then ns.PopPreviewOut(win.held) end
		if win then win:Hide() end
		ns.PopPreviewOut(preview, "Row")
		win = Window()
		if not (win and preview:GetParent() == win) then return "not popped out" end
		if (c.dock == "undocked") == (win.docked and true or false) then win.dock:GetScript("OnClick")(win.dock) end
		if c.close == "settings" then
			settings:Hide()
		elseif c.close == "escape" then
			for _, name in ipairs(UISpecialFrames) do
				local f = _G[name]
				if type(f) == "table" and f.IsShown and f:IsShown() then f:Hide() end
			end
		elseif c.close == "x" then
			local x = CloseButton(win)
			if not x then return "no x" end
			x:GetScript("OnClick")(x)
		else
			ns.PopPreviewOut(preview)
		end
		if c.reopen == "yes" then settings:Show() end
		return ("window=%s preview=%s drawn=%s"):format(win:IsShown() and "shown" or "hidden",
			preview:GetParent() == page and "page" or (preview:GetParent() == win and "window" or "?"),
			preview:IsVisible() and "yes" or "no")
	end,
	pins = {
		-- What's right (2026-11-26): every way puts it back on its page and hides the window;
		-- drawn only with the settings (its page) up.
		{ "", "window=hidden preview=page drawn=yes" },
		{ "close=settings reopen=no", "window=hidden preview=page drawn=no" },
	},
})
