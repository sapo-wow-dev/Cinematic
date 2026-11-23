-- The CDM lab: the Cooldown Manager page's grid (UI/CooldownGrid.lua) drawn by
-- its own code on real layout (frames.lua), in every state worth looking at,
-- each with a look audit (text cut short, gold text, overlapping buttons,
-- square boxes). For checking the page's look without the game (the user,
-- 2026-11-22: "how can we better address these visual issues so we dont need
-- too much testing"). Writes the same JSON as dump.lua, one "theme", the
-- states as its frames. From the repo root:
--
--   python Tools/style-lab/build.py retail --cdm
--
-- (build.py runs this and writes out/cdm-lab.html.)

local F = dofile("Tools/style-lab/frames.lua")
local client, outPath = ...
client, outPath = client or "retail", outPath or "Tools/style-lab/out/cdm.json"

-- The spells the bars hold here (names and icons as the game would give them).
local SPELLS = {
	{ 1978, "Serpent Sting", 132204 }, { 3044, "Arcane Shot", 132218 }, { 2973, "Raptor Strike", 132223 },
	{ 58984, "Shadowmeld", 132089 }, { 1126, "Mark of the Wild", 136078 }, { 5487, "Bear Form", 132276 },
}
local NAME, ICON = {}, {}
for _, s in ipairs(SPELLS) do NAME[s[1]], ICON[s[1]] = s[2], s[3] end

local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function(w)
	F.Install(w)
	local M = w.Methods
	M.SetScrollChild = function(self, child)
		child:ClearAllPoints()
		child:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		self._scrollChild = child
	end
	rawset(_G, "CreateFontFamily", false)
	_G.GetBindingKey = function() return nil end
	_G.C_Spell = _G.C_Spell or {}
	_G.C_Spell.GetSpellName = function(id) return NAME[id] or ("Spell " .. tostring(id)) end
	_G.C_Spell.GetSpellTexture = function(id) return ICON[id] or 134400 end
	_G.C_Spell.GetSpellInfo = function(id) return { name = NAME[id] or "Spell", iconID = ICON[id] or 134400 } end
	_G.GetTime = function() return F.now or 0 end
	_G.InCombatLockdown = function() return false end
end)

-- JSON, as dump.lua writes it.
local function Json(value, out)
	local kind = type(value)
	if kind == "nil" then
		out[#out + 1] = "null"
	elseif kind == "boolean" then
		out[#out + 1] = tostring(value)
	elseif kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then value = 0 end
		out[#out + 1] = ("%.3f"):format(value):gsub("0+$", ""):gsub("%.$", "")
	elseif kind == "string" then
		out[#out + 1] = '"' .. value:gsub('[%c"\\]', function(c)
			local named = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\t"] = "\\t", ["\r"] = "\\r" }
			return named[c] or ("\\u%04x"):format(c:byte())
		end) .. '"'
	elseif kind == "table" then
		if value[1] ~= nil or next(value) == nil then
			out[#out + 1] = "["
			for i, each in ipairs(value) do
				if i > 1 then out[#out + 1] = "," end
				Json(each, out)
			end
			out[#out + 1] = "]"
		else
			out[#out + 1] = "{"
			local first = true
			for k, each in pairs(value) do
				if type(k) == "string" and type(each) ~= "function" and not (type(each) == "table" and rawget(each, "_kind")) then
					if not first then out[#out + 1] = "," end
					first = false
					Json(k, out)
					out[#out + 1] = ":"
					Json(each, out)
				end
			end
			out[#out + 1] = "}"
		end
	else
		out[#out + 1] = "null"
	end
end

-- The page on, its bars' tabs on.
local db = ns.db
for _, start in ipairs({ "handleCooldowns", ns.CDM_TABS.essential, ns.CDM_TABS.utility, ns.CDM_TABS.buffs }) do
	local switch = start
	while switch do
		db[switch] = true
		switch = ns.PageSwitchOf(switch)
	end
end
ns.RuleFactsNow = function() return { dungeon = true, combat = true, nocombat = false, calm = false } end
local ESSENTIAL = { 1978, 3044, 2973, 58984 }
ns.CooldownManagerSpells = function()
	local list = {}
	for _, id in ipairs(ESSENTIAL) do list[#list + 1] = { id = id, group = "essential" } end
	list[#list + 1] = { id = 1126, group = "buffs" }
	list[#list + 1] = { id = 5487, group = "buffs" }
	return list
end

local canvas
for _, frame in ipairs(wow.frames) do
	if rawget(frame, "pageName") == "Cooldown Manager" then canvas = frame end
end
assert(canvas, "no Cooldown Manager page")
canvas:SetParent(UIParent)
canvas:ClearAllPoints()
canvas:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
canvas:SetSize(660, 1500)
if canvas.content then canvas.content:SetWidth(640) end
canvas:Show()
local function Shown(frame)
	local fn = frame._scripts and frame._scripts.OnShow
	if fn and frame:IsVisible() then pcall(fn, frame) end
	local refresh = rawget(frame, "Refresh")
	if type(refresh) == "function" and frame:IsVisible() then pcall(refresh, frame) end
	for _, child in ipairs(frame._children or {}) do
		if child._scripts then Shown(child) end
	end
end
Shown(canvas)
if ns.ApplyMenuSkin then ns.ApplyMenuSkin(true) end

local grid, _, panel = ns.CdmPageGrid()
assert(grid and panel, "no grid")
-- (What's drawn: the CDM tab, holding the panel, its bar tabs and the grid.)
local host = grid._parent
if os.getenv("CDM_DEBUG") then
	ns.CdmShowSpells("essential")
	local p, chain = panel, {}
	while p do chain[#chain + 1] = ("%s shown=%s"):format(tostring(rawget(p, "pageName") or p._kind), tostring(rawget(p, "_shown"))) p = rawget(p, "_parent") end
	print("panel chain: " .. table.concat(chain, " < "))
	print("rows", #grid.rows, "grid shown", tostring(rawget(grid, "_shown")), "tab", tostring(grid.state.tab))
end
local function Click(frame, mouse) frame._scripts.OnClick(frame, mouse or "LeftButton") end
local function RowOf(key)
	for _, row in ipairs(grid.rows) do
		if row.key == key then return row end
	end
end

-- Settings back to none, a bar shown.
local function Reset(tab)
	db.cooldownPlaceGroups = {}
	for _, name in ipairs({ "cooldownSpellCells", "cooldownBuffCells", "cooldownGroupCells", "cooldownReadyOnly",
		"cooldownRechargeOnly", "cooldownProcOnly", "cooldownAlwaysShow", "cooldownNeverShow", "cooldownBuffMode",
		"cooldownFlashReady", "cooldownRowSettings", "cooldownGroupDefaults", "cooldownEarlyOn", "cooldownReadyEarly",
		"cooldownNeedsPower", "cooldownReadyAnyTime" }) do
		db[name] = {}
	end
	wipe(grid.state.selected)
	grid.state.open, grid.state.editing, grid.state.look, grid.state.sure = nil, nil, false, nil
	grid.state.selecting = nil
	ns.CdmShowSpells(tab or "essential")
end
local function Scene(id, name, places, combat)
	local list = db.cooldownPlaceGroups
	list[#list + 1] = { id = id, name = name, places = places, combat = combat or "any" }
end
local DUNGEON = function() Scene(1, "Dungeon fights", { dungeon = true, raid = true }, "in") end
local TOWN = function() Scene(2, "Town", { city = true, inn = true }, "out") end
local PVP = function() Scene(3, "PvP", { bg = true }) end
local function Cell(kind, key, id, mode) ns.SetCooldownCell(kind, key, id, mode) end
local function Own(id, mode) ns.CooldownSetOtherwise("spell", id, "essential", mode) end

-- Each state: what it sets up.
local STATES = {
	{ id = "s1", name = "1 No scenes, two spells set", set = function()
		Reset()
		Own(3044, "never")
		Own(2973, "proc")
	end },
	{ id = "s2", name = "2 One new scene, its editor open", set = function()
		Reset()
		Click(grid.plus.IsShown and grid.addCard.button or grid.plus)
	end },
	{ id = "s3", name = "3 Three scenes, every choice", set = function()
		Reset()
		DUNGEON() TOWN() PVP()
		Cell("spell", 1978, 1, "ready")
		Cell("spell", 3044, 1, "recharge")
		Cell("spell", 2973, 1, "proc")
		Cell("spell", 58984, 2, "never")
		Cell("group", "essential", 2, "never")
		Own(2973, "never")
	end },
	{ id = "s4", name = "4 Five scenes: one never used, one with no places", set = function()
		Reset()
		DUNGEON() TOWN() PVP()
		Scene(4, "Raid bosses", { raid = true }, "in")
		Scene(5, "Scene 5", {})
		Cell("spell", 1978, 1, "ready")
		Cell("spell", 1978, 4, "never")
		Cell("group", "essential", 2, "never")
	end },
	{ id = "s5", name = "5 Pop-up, When ready picked", set = function()
		Reset()
		DUNGEON() TOWN() PVP()
		Cell("spell", 1978, 1, "ready")
		ns.CdmShowSpells("essential")
		Click(RowOf(1978).cells[1])
	end },
	{ id = "s6", name = "6 Pop-up at the right edge (Otherwise)", set = function()
		Reset()
		DUNGEON() TOWN() PVP()
		ns.CdmShowSpells("essential")
		Click(RowOf(1978).cells[4])
	end },
	{ id = "s7", name = "7 Editor on a scene with towns", set = function()
		Reset()
		DUNGEON() TOWN()
		grid.state.editing = 2
	end },
	{ id = "s8", name = "8 Delete asked (Sure?)", set = function()
		Reset()
		DUNGEON() TOWN()
		grid.state.editing = 2
		grid.state.sure = 2
	end },
	{ id = "s9", name = "9 Two rows ticked", set = function()
		Reset()
		DUNGEON() TOWN()
		grid.state.selected[3044] = true
		grid.state.selected[2973] = true
	end },
	{ id = "s10", name = "10 One row ticked (Copy row)", set = function()
		Reset()
		DUNGEON()
		grid.state.selected[3044] = true
	end },
	{ id = "s11", name = "11 Look, a few changed", set = function()
		Reset()
		ns.SetCooldownRow(1978, "keybinds", true)
		db.cooldownFlashReady[3044] = true
		grid.state.look = true
	end },
	{ id = "s12", name = "12 Buffs bar, a scene", set = function()
		Reset("buffs")
		DUNGEON()
		Cell("buff", 1126, 1, "combat")
		Cell("buff", 5487, 1, "hidden")
	end },
	{ id = "s14", name = "14 Previewing a dungeon fight", set = function()
		Reset()
		DUNGEON() TOWN() PVP()
		Cell("spell", 1978, 1, "ready")
		Cell("spell", 3044, 1, "never")
		Cell("group", "essential", 2, "never")
		Own(2973, "proc")
		ns.SetCooldownPreview("dungeon", "in")
	end },
	{ id = "s15", name = "15 The preview picker open", set = function()
		Reset()
		DUNGEON() TOWN()
		ns.CdmShowSpells("essential")
		Click(grid.previewButton)
	end },
	{ id = "s16", name = "16 Select on, one ticked", set = function()
		Reset()
		DUNGEON()
		grid.state.selecting = true
		grid.state.selected[3044] = true
	end },
	{ id = "s17", name = "17 Nine scenes (an old profile)", set = function()
		Reset()
		for i = 1, 9 do Scene(i, "Scene " .. i, { dungeon = true }, i % 2 == 0 and "out" or "in") end
		Cell("spell", 1978, 1, "ready")
		Cell("spell", 3044, 2, "never")
	end },
	-- (A player's shot, 2026-11-23: nine scenes from the old lines, no names of
	-- their own (their places and rules are the names), covering every place:
	-- names cut to "gr...", "Cit...", and the warning line on the headings.)
	{ id = "s19", name = "19 Nine unnamed scenes, Everywhere else never applies", set = function()
		Reset()
		local list = db.cooldownPlaceGroups
		list[#list + 1] = { id = 1, name = "", cql = "group and combat" }
		list[#list + 1] = { id = 2, name = "", cql = "group and nocombat" }
		Scene(3, "", { world = true }, "in")
		Scene(4, "", { city = true }, "any")
		Scene(5, "", { city = true }, "out")
		Scene(6, "", { inn = true, bg = true }, "any")
		Scene(7, "", { dungeon = true }, "in")
		Scene(8, "", { dungeon = true, raid = true }, "out")
		Scene(9, "", { world = true, dungeon = true, raid = true, bg = true }, "any")
		Cell("spell", 1978, 1, "ready")
	end },
	-- (Five scenes, none where you are: Everywhere else in use, its dot by its
	-- name. The user's shot cut it to "Everywh...", 2026-11-22; no state had it.)
	{ id = "s18", name = "18 Five scenes, Everywhere else in use", set = function()
		Reset()
		TOWN() PVP()
		Scene(4, "Raid bosses", { raid = true }, "in")
		Scene(5, "Scene 5", {})
		Scene(6, "Scene 6", {})
		Cell("spell", 1978, 2, "proc")
	end },
	{ id = "s13", name = "13 Page switched off", dim = true, set = function()
		Reset()
		DUNGEON()
		Cell("spell", 1978, 1, "ready")
		db.handleCooldowns = false
	end },
}
-- The look audit: text cut short (its width over its room), gold text,
-- shown buttons overlapping each other on one parent, square boxes (a
-- framed EditBox other than the name box, a checkbox shown by itself).
local function Audit()
	local found = {}
	local function Note(text) found[#found + 1] = text end
	local boxes, texts = {}, {}
	local function Walk(frame, depth, inGrid, popup)
		if depth > 14 or not F.Visible(frame) then return end
		inGrid = inGrid or frame == grid
		popup = popup or rawget(frame, "cdmPopup") or false
		for _, region in ipairs(frame._regions or {}) do
			if region._kind == "FontString" and F.Visible(region) then
				local text = region._text
				if type(text) == "string" and text ~= "" then
					local sw, w = region:GetStringWidth(), region:GetWidth()
					if rawget(region, "_wrap") == false and w and w > 4 and sw > w + 2 then Note("cut: " .. text) end
					-- (Wrapping text: one word wider than its room is cut in game all
					-- the same. "Everywhere" beside a dot came out "Everywh...", the
					-- lab drew two lines, 2026-11-22.)
					if rawget(region, "_wrap") ~= false and w and w > 4 then
						for word in text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gmatch("%S+") do
							rawset(region, "_text", word)
							local ww = region:GetStringWidth()
							rawset(region, "_text", text)
							if ww > w then Note(("word too wide: %s (%d > %d)"):format(word, ww, w)) break end
						end
					end
					-- (Words past the edge of the frame they're in: "When ready, for
					-- this spell everywhere:" ran out of its pop-up, 2026-11-22.)
					local fl, _, fw = frame:GetRect()
					local tl, _, rw = region:GetRect()
					if fl and tl and fw and fw > 20 and frame ~= host then
						local justify = rawget(region, "_justH") or "LEFT"
						local x0 = justify == "CENTER" and tl + (rw - math.min(sw, rw)) / 2 or justify == "RIGHT" and tl + rw - sw or tl
						local x1 = x0 + ((rawget(region, "_wrap") == false or not (rw and rw > 4)) and sw or math.min(sw, rw))
						if x1 > fl + fw + 1 or x0 < fl - 1 then Note("spills out of its box: " .. text) end
					end
					local r, g, b = region:GetTextColor()
					-- (Gold only in the grid: the page title and the bar tabs are the game's own.)
					if inGrid and r and r > 0.95 and g > 0.75 and g < 0.88 and b < 0.15 then Note("gold: " .. text) end
					-- (Text on text: "Scene 1" and "pick places" lay on each other, run 19.)
					local l, bt, tw, th = region:GetRect()
					if l and tw and tw > 0 then
						local sw = region:GetStringWidth()
						local justify = rawget(region, "_justH") or "LEFT"
						local x0 = justify == "CENTER" and l + (tw - sw) / 2 or justify == "RIGHT" and l + tw - sw or l
						local lines = math.max(1, math.floor((region:GetStringHeight() or th) / math.max(th, 1) + 0.5))
						texts[#texts + 1] = { text, x0, bt + th / 2 - (region:GetStringHeight() or th) / 2, math.min(sw, tw),
							region:GetStringHeight() or th, lines, popup }
					end
				end
			end
		end
		if frame._kind == "Button" and frame ~= grid and not rawget(frame, "cdmCatcher") and frame:GetWidth() > 4 then
			local left, bottom, width, height = frame:GetRect()
			if left then boxes[#boxes + 1] = { frame, left, bottom, width, height } end
		end
		for _, child in ipairs(frame._children or {}) do Walk(child, depth + 1, inGrid, popup) end
	end
	Walk(host, 0, false)
	for i = 1, #texts do
		for j = i + 1, #texts do
			local a, c = texts[i], texts[j]
			-- (A pop-up covers what's under it: only its own words count against each other.)
			if a[7] == c[7] and a[2] < c[2] + c[4] - 1 and c[2] < a[2] + a[4] - 1 and a[3] < c[3] + c[5] - 2 and c[3] < a[3] + a[5] - 2 then
				Note(("text on text: %s / %s"):format(a[1], c[1]))
			end
		end
	end
	for i = 1, #boxes do
		for j = i + 1, #boxes do
			local a, c = boxes[i], boxes[j]
			if a[1]._parent == c[1]._parent and a[2] < c[2] + c[4] - 1 and c[2] < a[2] + a[4] - 1
				and a[3] < c[3] + c[5] - 1 and c[3] < a[3] + a[5] - 1 then
				Note(("overlap: %s / %s"):format(tostring(a[1].text and a[1].text._text or "?"),
					tostring(c[1].text and c[1].text._text or "?")))
			end
		end
	end
	return found
end

local result = { frames = {}, themes = { { key = "game", name = "Cooldown Manager" } }, shots = { game = {} } }
local report = {}
for _, state in ipairs(STATES) do
	db.handleCooldowns = true
	ns.SetCooldownPreview(nil)
	if grid.previewMenu then grid.previewMenu:Hide() end
	local ok, err = pcall(state.set)
	if not ok then wow.Warn(state.id .. ": " .. tostring(err)) end
	pcall(grid.Changed)
	Shown(host)
	if os.getenv("CDM_DEBUG") then
		print(state.id, "grid h", grid:GetHeight(), "panel h", panel:GetHeight(), "chooser", grid.chooser:IsShown(), grid.chooser:GetHeight())
	end
	local issues = Audit()
	local items = F.Dump(host)
	-- Contrast (2026-11-22: red "Never" on a blue preview band passed every
	-- check): each text's color against what's drawn behind its middle, the
	-- page's dark ground under all, by the WCAG ratio. Below 3 is flagged.
	local function Lum(c)
		local function ch(v) v = math.max(0, math.min(1, v)) return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
		return 0.2126 * ch(c[1]) + 0.7152 * ch(c[2]) + 0.0722 * ch(c[3])
	end
	local function Over(top, a, under)
		return { top[1] * a + under[1] * (1 - a), top[2] * a + under[2] * (1 - a), top[3] * a + under[3] * (1 - a) }
	end
	if not state.dim then
		for i, item in ipairs(items) do
			if item.k == "text" and item.text:find("%w") then
				local cx, cy = item.x + item.w / 2, item.y + item.h / 2
				local bg = { 0.09, 0.09, 0.095 }
				for j = 1, i - 1 do
					local under = items[j]
					if under.k == "tex" and cx >= under.x and cx <= under.x + under.w and cy >= under.y and cy <= under.y + under.h then
						local c, a
						if under.color and not under.grad then
							c, a = under.color, (under.color[4] or 1)
						elseif under.vc and under.file and (under.file:find("WHITE8X8") or under.file:find("CdmDisc")) then
							c, a = under.vc, (under.vc[4] or 1)
						end
						if c then bg = Over(c, a * (under.a or 1), bg) end
					end
				end
				local tc = item.color or { 1, 1, 1, 1 }
				local text = Over(tc, (tc[4] or 1) * (item.a or 1), bg)
				local l1, l2 = Lum(text), Lum(bg)
				local ratio = (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05)
				if ratio < 3 then issues[#issues + 1] = ("contrast %.1f: %s"):format(ratio, item.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
			end
		end
	end
	-- (Its size from what it drew: the tab frame itself is 1 px.)
	local w, h = 0, 0
	for _, item in ipairs(items) do
		w, h = math.max(w, item.x + item.w), math.max(h, item.y + item.h)
	end
	w, h = math.ceil(w) + 4, math.ceil(h) + 4
	local summary = #issues == 0 and "audit clean" or table.concat(issues, "; ")
	result.frames[#result.frames + 1] = { id = state.id, name = state.name, group = "Cooldown Manager", page = summary }
	result.shots.game[state.id] = { w = w, h = h, items = items }
	report[#report + 1] = ("%s: %s"):format(state.name, summary)
end
db.handleCooldowns = true
result.warnings = wow.warnings

local out = {}
Json(result, out)
local file = assert(io.open(outPath, "w"))
file:write(table.concat(out))
file:close()
for _, line in ipairs(report) do print(line) end
print(("%d states, %d warnings"):format(#STATES, #wow.warnings))
for i = 1, math.min(#wow.warnings, 20) do print(wow.warnings[i]) end
