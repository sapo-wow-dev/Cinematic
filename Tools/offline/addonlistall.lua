-- The game's AddOns window on All (QoL/AddonListAll.lua), offline (Lua 5.1
-- via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/addonlistall.lua < /dev/null
-- On a stand-in AddOns window (the game's AddonList, its OkayButton and
-- Dropdown, AddonList_ClearCharacterDropdown / _Update / _Hide), per client
-- and copy: the player copy leaves it on your character, the dev copy puts it
-- on All once a load; the player copy does too with the setting ticked, not
-- with the Quality of life page off. Forever: the secure Reload lies over
-- Reload UI and its click closes the window saving; off for fights; none on
-- retail. Each run its own Lua (run.py's CINE_LUA). Says PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 143
local client, toc = arg and arg[1], arg and arg[2]

if not client then
	local LUA = os.getenv("CINE_LUA") or "lua5.1"
	local failed = 0
	for _, run in ipairs({ { "forever", "Cinematic.toc" }, { "forever", "CinematicDev.toc" },
		{ "retail", "Cinematic.toc" }, { "retail", "CinematicDev.toc" } }) do
		print(("== %s %s"):format(run[1], run[2]))
		local pipe = io.popen(("%s Tools/offline/addonlistall.lua %s %s"):format(LUA, run[1], run[2]))
		local out = pipe:read("*a")
		pipe:close()
		io.write(out)
		if not out:find("ALL PASS") then failed = failed + 1 end
	end
	print(failed == 0 and "ALL PASS" or (failed .. " RUNS FAILED"))
	if failed > 0 then os.exit(1) end
	return
end

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail ~= nil and (" (" .. tostring(detail) .. ")") or ""))
end

-- The stand-in window, made before the addon loads (as Blizzard_AddOnList is).
local list, character, updates, generated, savedOnHide
local ns, wow = dofile("Tools/offline/load.lua")(client, toc, function()
	RELOADUI, OKAY, ALL = "Reload UI", "Okay", "All"
	list = CreateFrame("Frame", "AddonList")
	list.OkayButton = CreateFrame("Button", nil, list)
	list.OkayButton:Show()
	local okText = OKAY
	list.OkayButton.SetText = function(_, text) okText = text end
	list.OkayButton.GetText = function() return okText end
	list.Dropdown = CreateFrame("Frame", nil, list)
	generated = 0
	list.Dropdown.GenerateMenu = function() generated = generated + 1 end
	character, updates = "Player-1", 0
	AddonList_ClearCharacterDropdown = function() character = "All" end
	AddonList_Update = function() updates = updates + 1 end
	AddonList_Hide = function(save)
		savedOnHide = save
		list:Hide()
	end
end)
-- luacheck: pop

local function Open()
	list:Show()
	local fn = list:GetScript("OnShow")
	if fn then fn(list) end
end
local function Close()
	list:Hide()
	local fn = list:GetScript("OnHide")
	if fn then fn(list) end
end

local dev = toc == "CinematicDev.toc"
-- (The Quality of life page's switch: off on a fresh offline install, as
-- every helper on it; on here, as most players have it.)
ns.db.handleQuality = true
local forever = client ~= "retail"
Check("hooked the window", ns.AddonListAllState().hooked == true)

-- Opened as installed: the dev copy on All, the player copy as the game left it.
Open()
Check(dev and "dev copy: on All" or "player copy: still your character",
	character == (dev and "All" or "Player-1"), character)
Check("dropdown made again and list updated only when put on All",
	(generated == 1 and updates == 1) == dev, ("%d menus, %d updates"):format(generated, updates))
Close()

-- Your own pick after that stays (once a load).
character = "Player-1"
Open()
Check("your pick stays when opened again", character == "Player-1", character)
Close()

-- The player copy, ticked: next load (restart) puts it on All.
ns.db.addonListAll = true
ns.AddonListAllRestart()
Open()
Check("setting ticked: on All", character == "All", character)
Close()

-- The Quality of life page off: left alone.
character = "Player-1"
ns.db.handleQuality = false
ns.AddonListAllRestart()
Open()
Check("Quality of life page off: left alone", character == "Player-1", character)
Close()
ns.db.handleQuality = true

-- Forever: Reload UI covered while it shows; none on retail.
ns.AddonListAllRestart()
Open()
Check("put on All for the cover checks", ns.AddonListAllState().cleared == true)
local function Cover() return ns.AddonListAllState().cover end
Check("no cover while it says Okay", not (Cover() and Cover():IsShown()))
list.OkayButton:SetText(RELOADUI)
-- (The ticker's work, which the stand-in's timers don't run: a tick changed.)
ns.AddonListAllRestart() -- (keeps nothing shown; then opened again)
Open()
if forever then
	local cover = Cover()
	Check("Forever: cover over Reload UI", cover ~= nil and cover:IsShown())
	Check("Forever: cover is the secure Reload", cover and cover:GetName() == "CinematicAddonListReload",
		cover and cover:GetName())
	Check("Forever: cover on the button", cover and cover.target == list.OkayButton)
	-- Its click: the window closes saving the ticks, then the macro reloads.
	savedOnHide = nil
	local pre = cover and cover:GetScript("PreClick")
	if pre then pre(cover) end
	Check("Forever: click closes the window saving", savedOnHide == true and not list:IsShown(), savedOnHide)
	Close()
	Check("Forever: cover off once the window's closed", not cover:IsShown())
	-- A fight starting with it up: off before the lockdown.
	Open()
	Check("Forever: cover up again", cover:IsShown())
	wow.Fire("PLAYER_REGEN_DISABLED")
	Check("Forever: cover off when a fight starts", not cover:IsShown())
else
	Check("retail: no cover (ReloadUI isn't blocked)", not (Cover() and Cover():IsShown()))
end
Close()

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
