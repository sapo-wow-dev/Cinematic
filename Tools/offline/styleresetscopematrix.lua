-- The style editor's Reset menu, its widest scope (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-26-style-reset-scope.md):
--   python -I Tools/offline/run.py Tools/offline/styleresetscopematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/styleresetscopematrix.lua forever --base <ref>
-- Reset > "Everything in Style" on a Style page (Name Style, Nameplate Style, Nameplate
-- Layout, Cast bars, Range Hint) went over every Style frame: one pick on the Names page
-- reset Tooltips, Minimap, Combat Text and the rest. The states: the host (a page's editor,
-- ns.StyleEditorPage with its page's own options, or the Studio window), its frame, and the
-- one setting of yours (on this page's variant, on another variant of the frame, on
-- Tooltips, on another editor page). Each cell: Reset's rows, its widest row's words,
-- whether that row counted the setting, and the setting after picking it and Yes. The rule
-- (the user, 2026-11-26): on a page the widest is the page's own (every variant its editor
-- shows; Cast bars' own variant only, as its Reset page), nothing on another page changes;
-- the Studio window keeps Everything in Style.

local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local Studio = ns.Studio
local C = Studio.C
local db = ns.db
-- (Nameplate Style's rows as its page makes them: Options.lua calls it before its editor.)
if ns.PlateStudioVariants then ns.PlateStudioVariants() end

-- Each page's editor as its page makes it (Options.lua, PlateLayoutPage.lua,
-- PlateCastStyle.lua, RangeHintStyle.lua).
local PAGE_OPTS = {
	names = {},
	range = {},
	plates = { only = true },
	platelayout = {},
	cast = { variant = "PLATE", only = true, pickers = true },
}
local OTHER_PAGE = { names = "range", range = "names", plates = "names", platelayout = "names", cast = "names" }

local function Clean()
	for _ = 1, 3 do
		for _, w in ipairs(Studio.ResetWrites("all")) do pcall(Studio.Put, w[1], w[2]) end
	end
end
-- One setting of yours on frame f's variant v: a slider or switch (a db key or a field),
-- a value its default isn't.
local function MakeYours(f, v)
	for _, each in ipairs(Studio.Props(f)) do
		local p = each.prop
		local key = (p.kind == "slider" or p.kind == "switch") and not p.noReset and Studio.KeyOf(p, v)
		if key and (type(key) == "string" or type(key) == "table") and Studio.Shown(p, db, v) then
			local was = Studio.Get(key)
			local tries = {}
			if type(was) == "number" then tries = { was + 0.13, was - 0.13 }
			elseif type(was) == "boolean" then tries = { not was }
			elseif was == nil then tries = { 0.37, true } end
			for _, value in ipairs(tries) do
				pcall(Studio.Put, key, value)
				if Studio.Get(key) == value and Studio.SourceOf(f, p, v) == "yours" then return key, value end
			end
			pcall(Studio.Put, key, was)
		end
	end
end

local function Host(kind, f)
	if kind == "window" then
		local ok = pcall(ns.OpenStyleStudio, f.id)
		local win = ok and ns.StyleStudioWindow()
		return win and win.host
	end
	local content = CreateFrame("Frame")
	local opts = {}
	for k, v in pairs(PAGE_OPTS[f.id]) do opts[k] = v end
	opts.canvas = f.pageCanvas or content
	local keep = f.pageCanvas
	local ok, host = pcall(ns.StyleEditorPage, {}, content, { Add = function() end }, f.id, opts)
	f.pageCanvas = keep
	return ok and host or nil
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = client == "retail" and "style-reset-scope-retail" or "style-reset-scope", -- (no Layout page on retail)
	fixed = { client = client },
	dims = {
		{ "host", { "page", "window" } },
		{ "frame", { "names", "range", "plates", "platelayout", "cast" } },
		{ "yours", { "here", "row", "tooltips", "otherpage" } },
	},
	cell = function(c)
		local f = Studio.frames[c.frame]
		if not f then return "no-frame" end
		if f.shown and not f.shown() then return "not-on-client" end -- (Nameplate Layout on retail)
		Clean()
		local host = Host(c.host, f)
		if not host then return "no-host" end
		if host.f ~= f then return "window-on-other" end
		-- The setting of yours.
		local tf, tv
		if c.yours == "here" then
			tf, tv = f, host.variant
		elseif c.yours == "row" then
			tf = f
			-- (Not the frame's first either where it can: Cast bars follows Unit frames' bar.)
			for _, v in ipairs(Studio.Variants(f)) do
				if v.id ~= host.variant and v.id ~= Studio.FirstVariant(f) and tv == nil then tv = v.id end
			end
			for _, v in ipairs(Studio.Variants(f)) do if v.id ~= host.variant and tv == nil then tv = v.id end end
			if tv == nil then return "no-row" end
		else
			tf = Studio.frames[c.yours == "tooltips" and "tooltips" or OTHER_PAGE[c.frame]]
			if not tf then return "no-other-frame" end
			tv = Studio.FirstVariant(tf)
		end
		local key, value = MakeYours(tf, tv)
		if not key then return "no-setting" end
		-- Reset ▾: its rows; the widest picked, then Yes.
		local open, rows, widest = C.OpenList, {}, nil
		local step = 0
		C.OpenList = function(_, list, _, onPick)
			step = step + 1
			if step == 1 then
				for _, o in ipairs(list) do rows[#rows + 1] = o[1] end
				widest = list[#list]
				onPick(widest[1])
			elseif step == 2 then
				onPick("yes")
			end
		end
		local ok, err = pcall(host.ResetMenu, host, CreateFrame("Frame"))
		C.OpenList = open
		if not ok then return "error: " .. tostring(err) end
		local after = Studio.Get(key) == value and "kept" or "reset"
		while Studio.Undo() do end
		Clean()
		return ("rows=%s widest=%q counted=%s setting=%s"):format(table.concat(rows, ","),
			widest and widest.name or "?", widest and widest.n > 0 and "yes" or "no", after)
	end,
	pins = {
		-- The Studio window: every Style frame, as before.
		{ "host=window", "rows=part,frame,all widest=\"Everything in Style\" counted=yes setting=reset" },
		{ "host=window frame=names", "rows=part,variant,frame,all widest=\"Everything in Style\" counted=yes setting=reset" },
		{ "host=window frame=plates", "rows=part,variant,frame,all widest=\"Everything in Style\" counted=yes setting=reset" },
		{ "host=window frame=platelayout", "rows=part,variant,frame,all widest=\"Everything in Style\" counted=yes setting=reset" },
		{ "host=window frame=cast", "rows=part,variant,frame,all widest=\"Everything in Style\" counted=yes setting=reset" },
		{ "host=window frame=range yours=row", "no-row" },
		-- A page: its own frame, every variant its editor shows; nothing on another page.
		{ "host=page", "rows=part,page widest=\"Everything on this page\" counted=no setting=kept" },
		{ "host=page yours=here", "rows=part,page widest=\"Everything on this page\" counted=yes setting=reset" },
		{ "host=page frame=names", "rows=part,variant,page widest=\"Everything on this page\" counted=no setting=kept" },
		{ "host=page frame=names yours=here", "rows=part,variant,page widest=\"Everything on this page\" counted=yes setting=reset" },
		{ "host=page frame=names yours=row", "rows=part,variant,page widest=\"Everything on this page\" counted=yes setting=reset" },
		{ "host=page frame=plates", "rows=part,variant,page widest=\"Everything on this page\" counted=no setting=kept" },
		{ "host=page frame=plates yours=here", "rows=part,variant,page widest=\"Everything on this page\" counted=yes setting=reset" },
		{ "host=page frame=plates yours=row", "rows=part,variant,page widest=\"Everything on this page\" counted=yes setting=reset" },
		{ "host=page frame=platelayout", "rows=part,variant,page widest=\"Everything on this page\" counted=no setting=kept" },
		{ "host=page frame=platelayout yours=here", "rows=part,variant,page widest=\"Everything on this page\" counted=yes setting=reset" },
		{ "host=page frame=platelayout yours=row", "rows=part,variant,page widest=\"Everything on this page\" counted=yes setting=reset" },
		-- (Cast bars: the cast frame is on several pages; this one is its Plates variant, as its
		-- Reset page. Another variant is another page's.)
		{ "host=page frame=cast yours=row", "rows=part,page widest=\"Everything on this page\" counted=no setting=kept" },
		{ "host=page frame=range yours=row", "no-row" },
		{ "client=retail frame=platelayout", "not-on-client" },
	},
})
