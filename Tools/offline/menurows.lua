-- Menu title/divider rows our code adds, in a fight on Forever (gamepad mode
-- on or off: the game's menus always make the call)
-- (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/menurows.lua < /dev/null
-- 2026-11-23 right-clicking the target frame in a fight gave 2 "blocked (no
-- event)" lines: Emote Vision's divider + "Emote" title on the game's unit
-- menu. The game's CreateTitle/CreateDivider initializers call
-- SmartNavigation_MarkFrameIgnored -> SetSecureValue, refused in combat from
-- our code. ns.MenuTitle / ns.MenuDivider (Skin.lua) build the same rows
-- and mark them only out of a fight. Tools/errors/known.lua:
-- menu-row-smartnav-fight. PASS or FAIL per check.
-- luacheck: ignore 432 (stub methods shadow self)
local ns = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc")

local fails = 0
local function Check(name, got, want)
	local ok = got == want
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. " (" .. tostring(got) .. ")")
end

Check("helpers there", type(ns.MenuTitle) == "function" and type(ns.MenuDivider) == "function", true)
if type(ns.MenuTitle) ~= "function" then os.exit(1) end

-- A stand-in menu description: records the rows and their initializers,
-- like Blizzard_Menu's (the game's own title/divider rows say so).
local function Root()
	local root = { rows = {} }
	function root:CreateFrame()
		local row = { kind = "frame", inits = {} }
		function row:AddInitializer(f) self.inits[#self.inits + 1] = f end
		self.rows[#self.rows + 1] = row
		return row
	end
	function root:CreateTitle(text) self.rows[#self.rows + 1] = { kind = "game title", text = text } end
	function root:CreateDivider() self.rows[#self.rows + 1] = { kind = "game divider" } end
	return root
end
local function Frame()
	local frame = {}
	function frame:AttachFontString()
		local fs = {}
		function fs:SetPoint() end
		function fs:SetHeight() end
		function fs:SetTextToFit(t) self.text = t end
		function fs:SetTextColor(...) self.color = { ... } end
		return fs
	end
	function frame:AttachTexture()
		local tex = {}
		function tex:SetPoint() end
		function tex:SetTexture(t) self.file = t end
		function tex:SetHeight() end
		return tex
	end
	return frame
end
local function Run(row, frame)
	for _, init in ipairs(row.inits or {}) do init(frame) end
end

-- (rawset: the stand-in game answers every unknown global with a stub.)
rawset(_G, "MenuVariants", {
	CreateFontString = function(frame) return frame:AttachFontString() end,
	CreateDivider = function(frame)
		local d = frame:AttachTexture()
		d:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
		return d
	end,
})
rawset(_G, "NORMAL_FONT_COLOR", { GetRGBA = function() return 1, 0.82, 0, 1 end })

-- Forever (SmartNavigation_MarkFrameIgnored there): the mark is blocked in a fight (as the game's
-- SecureHelper refuses it from our code), fine out of one.
local fight, blocked, marked = false, 0, 0
rawset(_G, "InCombatLockdown", function() return fight end)
rawset(_G, "SmartNavigation_MarkFrameIgnored", function()
	if fight then blocked = blocked + 1 else marked = marked + 1 end
end)

-- The reported case: Emote Vision's divider + title, menu opened in a fight.
local root = Root()
ns.MenuDivider(root)
ns.MenuTitle(root, "Emote")
Check("Forever: both rows our own frames", root.rows[1].kind == "frame" and root.rows[2].kind == "frame", true)
fight = true
local fDiv, fTitle = Frame(), Frame()
Run(root.rows[1], fDiv)
Run(root.rows[2], fTitle)
Check("in a fight: nothing blocked (was 2)", blocked, 0)
Check("title text shown", fTitle.fontString and fTitle.fontString.text, "Emote")
Check("title in the game's title color", fTitle.fontString and fTitle.fontString.color and fTitle.fontString.color[2], 0.82)
Check("divider drawn", fDiv.divider and fDiv.divider.file, "Interface\\Common\\UI-TooltipDivider-Transparent")

-- Out of a fight: still marked, so the gamepad cursor skips them.
fight = false
Run(root.rows[1], Frame())
Run(root.rows[2], Frame())
Check("out of a fight: both marked", marked, 2)

-- No such call (retail, Classic): the game's own rows, as before.
rawset(_G, "SmartNavigation_MarkFrameIgnored", false)
local plain = Root()
ns.MenuDivider(plain)
ns.MenuTitle(plain, "Cinematic")
Check("other clients: game's divider", plain.rows[1].kind, "game divider")
Check("other clients: game's title", plain.rows[2].kind .. " " .. tostring(plain.rows[2].text), "game title Cinematic")
Check("nil root: no error", select(1, pcall(ns.MenuTitle, nil, "x")), true)

print(fails == 0 and "ALL PASS" or (fails .. " FAIL"))
os.exit(fails == 0 and 0 or 1)
