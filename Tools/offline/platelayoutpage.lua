-- Nameplate Style's Layout tab (Plates/PlateLayoutPage.lua) built with the
-- whole addon on the stand-in (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/platelayoutpage.lua < /dev/null
-- The page builds with no error and is hidden once built; its arrow-key frame
-- has no key script and no keyboard till the mouse comes onto a part, every
-- key but an arrow passes on to the game, and it lets the keyboard go once
-- the mouse is off the preview. (2026-11-25, the first build: the page
-- stopped partway, its key frame stayed up with the keyboard on, and every
-- key in the game went to it.) Retail: no page. PASS or FAIL per check.
-- luacheck: ignore 111 112 113 121 122 212 431
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local calls = {}
local parts = dofile("Tools/offline/gameplate_parts.lua")(function(text) calls[#calls + 1] = text end)
local errors = {}
local function Load(client)
	return dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
		issecretvalue = function() return false end
		parts.Install()
	end)
end

local ns = Load("forever")
-- (Errors the addon caught and reported while building: none wanted.)
local logged = ns.ReportError
local page = ns.plateLayoutPage
Check("the Layout page is built (Forever)", page ~= nil)
if page then
	Check("built in full: its Reset layout and parts list there", page.hits ~= nil and page.keys ~= nil)
	Check("hidden once built", page.canvas and not page.canvas:IsShown())
	local keys = page.keys
	Check("its key frame has no key script at rest", keys:GetScript("OnKeyDown") == nil)
	-- (The mouse onto a part: the keys on, passed on to the game.)
	local propagate
	keys.SetPropagateKeyboardInput = function(_, on) propagate = on end
	local keyboard
	keys.EnableKeyboard = function(_, on) keyboard = on end
	ns.PlateLayoutPageKeys()
	local onKey = keys:GetScript("OnKeyDown")
	Check("the mouse on a part: a key script, the keyboard on", onKey ~= nil and keyboard == true)
	Check("...every key passed on to start with", propagate == true)
	-- (A key with the mouse off the preview: passed on, and the keyboard let go.)
	page.holder.IsMouseOver = function() return false end
	page.holder.IsVisible = function() return true end
	if onKey then onKey(keys, "W") end
	Check("a key off the preview: passed on", propagate == true)
	Check("...and the keyboard let go, its script gone", keyboard == false and keys:GetScript("OnKeyDown") == nil)
	-- (On the preview: W passes on, an arrow nudges the part and is kept.)
	ns.PlateLayoutPageKeys()
	onKey = keys:GetScript("OnKeyDown")
	page.holder.IsMouseOver = function() return true end
	if onKey then onKey(keys, "W") end
	Check("W over the preview: passed on to the game", propagate == true and keyboard == true)
	ns.db.plateLayoutData = nil
	page.Select("level")
	IsShiftKeyDown = function() return false end
	if onKey then onKey(keys, "RIGHT") end
	local layout = ns.PlateLayoutGet("all")
	local p = layout and layout.parts and layout.parts.level
	Check("the right arrow: the level box 1 right, the key kept", p and p.x == 1 and propagate == false, p and p.x)
	ns.db.plateLayoutData = nil
	ns.PlateLayoutChanged()
end
Check("no error reported while building", logged == ns.ReportError and #errors == 0)

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
