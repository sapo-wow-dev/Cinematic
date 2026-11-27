-- Nameplate Layout's Shown rows (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-26-layout-shown-rows.md):
--   python -I Tools/offline/run.py Tools/offline/layoutshownmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/layoutshownmatrix.lua forever --base <ref>
-- Each Layout part's Shown row (styleOver_platePart*) is the Style hub's Overrides tab's
-- setting, read by ns.StyleOverride: one key for every plate, used only while its own gate
-- is open (the addon on, Style and the Overrides tab on, its Nameplates tab on). 679e735 put
-- it on every Layout for kind (so it looked per-kind), greyed it by Layout's own switch
-- (plateLayout: greyed yet used, or live yet not used), and every Layout reset (part, kind,
-- page) reset it. The states: Layout for (All plates, or a kind), Layout's switch, the
-- Overrides' gate (open, its tab off, its page off, Style off, the addon off), the action:
-- the row as drawn on the Layout page (shown, greyed, the status line), or a reset (the row's
-- own, Reset's part, kind and page rows, the Reset page button) with the row set Hidden.
-- The rule (audit 2026-11-26): the row on All plates only (no kind has a key of its own),
-- greyed with a status line while the Overrides won't use it (and a line saying it's still
-- used with Layout off), and only its own row resets it from Layout.

local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local Studio = ns.Studio
local C = Studio.C
local db = ns.db

local KEY = "styleOver_platePartLevel"
local TAB = "tabOn:Style Overrides:4"
local SWITCHES = { "enabled", "styleGeneral", "handlePlateStyle", "plateLayout", "styleOverrides", TAB }

local function ShownProp(f)
	for _, each in ipairs(Studio.Props(f, "level")) do
		if Studio.KeyOf(each.prop, "all") == KEY then return each.prop end
	end
end
-- What the status line says, in short.
local function StatusTag(body)
	if not (body.status and body.status:IsShown()) then return "none" end
	local text = body.status.text:GetText() or ""
	local tags = {}
	if text:find("Nothing here shows", 1, true) then tags[#tags + 1] = "layout-off" end
	if text:find("which is off", 1, true) then tags[#tags + 1] = "overrides-off" end
	if text:find("Nameplate Layout off too", 1, true) then tags[#tags + 1] = "still-used" end
	if #tags == 0 then tags[1] = "other" end
	return table.concat(tags, "+")
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "layout-shown-" .. client, -- (Layout is Forever's only: retail's cells stay as they are)
	fixed = { client = client },
	dims = {
		{ "variant", { "all", "hostile" } },
		{ "layout", { "on", "off" } },
		{ "gate", { "open", "taboff", "pageoff", "styleoff", "addonoff" } },
		{ "action", { "row", "reset:row", "reset:part", "reset:variant", "reset:page", "resetpage" } },
	},
	cell = function(c)
		local f = Studio.frames.platelayout
		local page = ns.plateLayoutPage
		if not (f and page and page.editor) then return "not-on-client" end
		local prop = ShownProp(f)
		if not prop then return "no-prop" end
		local was = {}
		for _, k in ipairs(SWITCHES) do was[k] = db[k] end
		local wasKey = db[KEY]
		db.enabled, db.styleGeneral, db.handlePlateStyle, db.styleOverrides, db[TAB] = true, true, true, true, true
		db.plateLayout = c.layout == "on"
		if c.gate == "taboff" then db[TAB] = false
		elseif c.gate == "pageoff" then db.styleOverrides = false
		elseif c.gate == "styleoff" then db.styleGeneral = false
		elseif c.gate == "addonoff" then db.enabled = false end
		db[KEY] = c.action == "row" and "row" or "hide"
		local editor = page.editor
		local out
		local ok, err = pcall(function()
			editor:Pick("level", c.variant)
			local body = editor.body
			local row = body.rows[prop]
			local drawn = false
			for _, r in ipairs(body.shownRows or {}) do if r == row then drawn = true end end
			if c.action == "row" then
				if not drawn then
					out = ("shown=no status=%s"):format(StatusTag(body))
					return
				end
				local enabled
				rawset(row.control, "SetEnabled", function(_, on) enabled = on end)
				row:Update()
				out = ("shown=yes greyed=%s status=%s"):format(enabled == false and "yes" or "no", StatusTag(body))
				return
			end
			if c.action == "reset:row" then
				-- (The row's own Reset, offered only while it's yours: Studio.lua's row.reset.)
				if not drawn then out = "no-row" return end
				if Studio.SourceOf(f, prop, editor.variant) ~= "yours" then out = "not-offered" return end
				Studio.Reset("prop", f, editor.variant, "level", prop)
			elseif c.action == "resetpage" then
				local data
				local show = _G.StaticPopup_Show
				rawset(_G, "StaticPopup_Show", function(_, _, _, d) data = d end)
				local click = page.canvas.resetButton and page.canvas.resetButton:GetScript("OnClick")
				if click then click(page.canvas.resetButton) end
				rawset(_G, "StaticPopup_Show", show)
				if not data then out = "no-reset-page" return end
				StaticPopupDialogs.CINEMATIC_RESET_PAGE.OnAccept(nil, data)
			else
				-- Reset ▾ (the page's host: This part, This variant, Everything on this page), then Yes.
				local want = c.action:match("^reset:(.+)$")
				local open, step, found = C.OpenList, 0, false
				C.OpenList = function(_, list, _, onPick)
					step = step + 1
					if step == 1 then
						-- (Its page row: "page", "This frame" before the reset-scope fix, the same scope.)
						for _, o in ipairs(list) do
							if not found and (o[1] == want or (want == "page" and o[1] == "frame")) then
								found = true
								onPick(o[1])
							end
						end
					elseif step == 2 then
						onPick("yes")
					end
				end
				local okMenu, errMenu = pcall(editor.ResetMenu, editor, CreateFrame("Frame"))
				C.OpenList = open
				if not okMenu then error(errMenu) end
				if not found then out = "no-scope" return end
			end
			out = db[KEY] == "hide" and "kept" or "reset"
		end)
		while Studio.Undo() do end
		for _, k in ipairs(SWITCHES) do db[k] = was[k] end
		db[KEY] = wasKey
		pcall(editor.Pick, editor, "level", "all")
		if not ok then return "error: " .. tostring(err) end
		return out
	end,
	pins = {
		{ "client=retail", "not-on-client" },
		-- The row: on All plates only, live by the Overrides' own gate, a line saying why not.
		{ "client=forever action=row variant=hostile layout=on", "shown=no status=none" },
		{ "client=forever action=row variant=hostile layout=off", "shown=no status=layout-off" },
		{ "client=forever action=row variant=all layout=on", "shown=yes greyed=yes status=overrides-off" },
		{ "client=forever action=row variant=all layout=on gate=open", "shown=yes greyed=no status=none" },
		{ "client=forever action=row variant=all layout=off", "shown=yes greyed=yes status=layout-off+overrides-off" },
		{ "client=forever action=row variant=all layout=off gate=open", "shown=yes greyed=no status=layout-off+still-used" },
		-- (Style off: Layout's switch is under it, so Layout reads off as well.)
		{ "client=forever action=row variant=all gate=styleoff", "shown=yes greyed=yes status=layout-off+overrides-off" },
		{ "client=forever action=row variant=hostile gate=styleoff", "shown=no status=layout-off" },
		-- Resets from Layout: only the row's own; none on a kind (no row there).
		{ "client=forever action=reset:row variant=all", "reset" },
		{ "client=forever action=reset:row variant=hostile", "no-row" },
		{ "client=forever action=reset:part", "kept" },
		{ "client=forever action=reset:variant", "kept" },
		{ "client=forever action=reset:page", "kept" },
		{ "client=forever action=resetpage", "kept" },
	},
})
