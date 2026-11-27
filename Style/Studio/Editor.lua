-- Style Studio: the one editor every Style page uses (Tools/style-studio/plan.md, 2026-11-25).
-- This file is the model: frames (one per Style page, or one for pages that are
-- variants of one thing), their variants, parts and properties; where each value
-- comes from; one Undo history; Reset by scope; the Find index. Controls.lua draws
-- the controls, Studio.lua the two hosts (the Studio window, the compact page).
--
-- A frame, registered with ns.StyleFrame(id, spec):
--   label, band ("Interface"/"Visions"/"Atmosphere"), sub, page (the Style page id
--   it opens from; pages = { id = variant } when several pages are its variants),
--   switch (the page's Enable key), refresh() (after any change: the runtime's),
--   preview(parent, width) -> a frame with :Refresh() (the stage), test() (Test),
--   status() -> text, kind ("warn"/"off"), action label, action fn (why it isn't
--   showing), shown() (false: not on this client), looks = { { id, label, values =
--   { key = value } or apply = fn(variant) } },
--   variants = { { id, label } ... } (first = the one the others follow),
--   parts = { { id, label, region = fn(preview) -> region, groups = { { recipe, props } } } }.
-- A property: { kind = "seg"|"tiles"|"slider"|"color"|"switch"|"drop"|"button"|"text",
--   label, key (a db key, a field { get, set }, or fn(variant) -> either), tip,
--   options = { { value, text, tip } } or fn() (seg, drop, tiles; tiles: { value, text,
--   font = file, texture = path, atlas }), min, max, step, unit ("%", "px", "s", "x"),
--   scale (shown = value * scale), rgb = { r, g, b keys } or fn(variant) -> them (color: the
--   Custom swatch; each a db key or a field),
--   custom = the mode value that uses the swatch, test = fn(db) (grey unless),
--   shown = fn(db) (hidden unless), default (for a field), inherit = the value meaning
--   "follows the first variant", run = fn (button), syn = extra words for Find }.
local _, ns = ...
ns.Module("style", function() -- (only with Style loaded, Modules.lua)
local L = ns.L

local Studio = {}
ns.Studio = Studio

-- The recipes' order: a part's groups always show in this order, under these names.
Studio.RECIPES = { "Look", "Text", "Bar", "Icon", "Border", "Background", "Place", "Motion", "Sound" }
local RECIPE_RANK = {}
for i, name in ipairs(Studio.RECIPES) do RECIPE_RANK[name] = i end
Studio.RECIPE_RANK = RECIPE_RANK
-- The words the grammar keeps to (one name per thing): an offline check reads these.
Studio.WORDS = { outline = { "None", "Thin", "Thick" }, game = "The game's", custom = "Custom", test = "Test",
	background = "Background", follows = "Follows %s" }

local frames, order = {}, {}
Studio.frames, Studio.order = frames, order
local BAND_RANK = { General = 0, Interface = 1, Visions = 2, Atmosphere = 3 }

function ns.StyleFrame(id, spec)
	spec.id = id
	if not frames[id] then order[#order + 1] = id end
	frames[id] = spec
	for _, part in ipairs(spec.parts or {}) do
		table.sort(part.groups, function(a, b)
			return (RECIPE_RANK[a.recipe] or 99) < (RECIPE_RANK[b.recipe] or 99)
		end)
	end
	Studio.indexDirty = true
	return spec
end

-- The frames in the rail's order: band, then sub, then as registered.
function Studio.Ordered()
	local list = {}
	for i, id in ipairs(order) do
		local f = frames[id]
		if not f.shown or f.shown() then list[#list + 1] = { f = f, i = i } end
	end
	-- (Groups in the Style hub's order, then each frame's rank in its group: sorting by
	-- the frame's rank alone mixed Combat's frames into Info's, run qd398.)
	local SUB_RANK = { Combat = 1, Nameplates = 2, Info = 3, World = 4, RP = 5, Effects = 6 }
	table.sort(list, function(a, b)
		local ra, rb = BAND_RANK[a.f.band] or 9, BAND_RANK[b.f.band] or 9
		if ra ~= rb then return ra < rb end
		local ga = a.f.sub and (SUB_RANK[a.f.sub] or 8) or 0
		local gb = b.f.sub and (SUB_RANK[b.f.sub] or 8) or 0
		if ga ~= gb then return ga < gb end
		local sa, sb = a.f.subRank or 0, b.f.subRank or 0
		if sa ~= sb then return sa < sb end
		return a.i < b.i
	end)
	for i, each in ipairs(list) do list[i] = each.f end
	return list
end

-- The frame a Style page opens: { frame, variant } (nil: not on the editor).
function Studio.FrameOfPage(pageId)
	for _, id in ipairs(order) do
		local f = frames[id]
		if f.page == pageId then return f, nil end
		if f.pages and f.pages[pageId] ~= nil then return f, f.pages[pageId] end
	end
end

-- Variants ----------------------------------------------------------------------------
function Studio.Variants(f)
	return f.variants or { { id = false, label = f.label } }
end
function Studio.FirstVariant(f)
	return Studio.Variants(f)[1].id
end

-- A property's key for a variant: a db key (string) or a field { get, set }.
function Studio.KeyOf(prop, variant)
	local key = prop.key
	if type(key) == "function" then return key(variant) end
	return key
end
-- (A field that errors, say read before the settings exist, reads as nil: one bad
-- field never stops a page, or the pages after it, from being made.)
local function Get(key)
	if key == nil then return nil end
	if type(key) == "table" then
		if not ns.GetDB() then return nil end
		local ok, value = pcall(key.get)
		if ok then return value end
		return nil
	end
	return ns.StyleKeyGet(key)
end
local function Put(key, value)
	if key == nil then return end
	ns.StyleKeyPut(key, value)
end
Studio.Get, Studio.Put = Get, Put

-- The value a key starts at: the field's own default, the DEFAULTS one.
-- (A key's default: your profile's value, what Reset page puts back, not the addon's own: after a
-- reset, Smart marks (-10, the Cinema and Shoulder Cam profiles' raise) showed as edited, the user
-- 2026-11-26.)
local function ProfileDefault(k)
	local base = ns.ProfileBase and ns.ProfileBase()
	if base and base[k] ~= nil then return base[k] end
	return ns.DEFAULTS[k]
end
Studio.ProfileDefault = ProfileDefault
function Studio.DefaultOf(prop, key)
	if prop.default ~= nil then
		if type(prop.default) == "function" then return prop.default(key) end
		return prop.default
	end
	if type(key) == "string" then return ProfileDefault(key) end
	if type(key) == "table" and key.default ~= nil then return key.default end
	return nil
end

-- What the main theme writes for a key, while a theme is picked (nil: none).
local function ThemeValue(key)
	if type(key) ~= "string" or not ns.ThemeSetting then return nil end
	local theme = ns.ActiveStyleTheme and ns.ActiveStyleTheme()
	if not theme then return nil end
	return ns.ThemeSetting(key)
end

-- A color's three swatch keys for a variant (prop.rgb: a list, or fn(variant) -> list;
-- each a db key or a field), their values (r, g, b) and each one's default.
function Studio.RGB(prop, variant)
	if prop.rgbOf then return prop.rgbOf(variant) end
	local rgb = prop.rgb
	if type(rgb) == "function" then return rgb(variant) end
	return rgb
end
function Studio.RGBValues(prop, variant)
	local keys = Studio.RGB(prop, variant)
	if not keys then return 1, 1, 1 end
	return Get(keys[1]) or 1, Get(keys[2]) or 1, Get(keys[3]) or 1
end
local function KeyDefault(k)
	if type(k) == "string" then return ProfileDefault(k) end
	if type(k) == "table" then return k.default end
end
Studio.KeyDefault = KeyDefault

-- Where a property's value comes from now: "game", "theme", "general",
-- "follows", "yours"; and the value.
function Studio.SourceOf(f, prop, variant)
	if prop.kind == "button" or prop.kind == "text" then return nil end
	-- (prop.noReset: a choice of the page's own, like a tab's switch or a theme pick: never
	-- "yours", so Reset and Changed leave it; Undo still has it.)
	if prop.noReset then return "game", Get(Studio.KeyOf(prop, variant)) end
	if prop.kind == "swatch" then
		-- (A color with no choice of its own: its swatch's keys alone.)
		for _, rk in ipairs(Studio.RGB(prop, variant) or {}) do
			if Get(rk) ~= nil and Get(rk) ~= KeyDefault(rk) then return "yours", nil end
		end
		return "game", nil
	end
	local key = Studio.KeyOf(prop, variant)
	local value = Get(key)
	if prop.inherit ~= nil and variant ~= Studio.FirstVariant(f) and value == prop.inherit then return "follows", value end
	if ns.IsGeneralStyle and ns.IsGeneralStyle(value) then return "general", value end
	local themed = ThemeValue(key)
	-- (A field: its own word for what the theme gives it, prop.theme().)
	if themed == nil and prop.theme and ns.ActiveStyleTheme and ns.ActiveStyleTheme() then themed = prop.theme() end
	if themed ~= nil and themed == value then return "theme", value end
	local default = Studio.DefaultOf(prop, key)
	if value == nil or value == default then
		-- (A color: the swatch's keys count too, while its mode is Custom.)
		if prop.rgb and prop.custom ~= nil and value == prop.custom then
			for _, rk in ipairs(Studio.RGB(prop, variant) or {}) do
				if Get(rk) ~= KeyDefault(rk) then return "yours", value end
			end
		end
		return "game", value
	end
	return "yours", value
end

-- What Reset gives a property: the first variant's (its inherit value), the
-- theme's, else its default.
function Studio.ResetValue(f, prop, variant)
	local key = Studio.KeyOf(prop, variant)
	if prop.inherit ~= nil and variant ~= Studio.FirstVariant(f) then return prop.inherit end
	local themed = ThemeValue(key)
	if themed ~= nil then return themed end
	return Studio.DefaultOf(prop, key)
end

-- Every property of a frame's part (or all parts), with its part and group.
function Studio.Props(f, partId)
	local list = {}
	for _, part in ipairs(f.parts or {}) do
		if not partId or part.id == partId then
			for _, group in ipairs(part.groups) do
				for _, prop in ipairs(group.props) do
					list[#list + 1] = { prop = prop, part = part, group = group }
				end
			end
		end
	end
	return list
end

-- Whether a property applies here (hidden ones don't count anywhere).
-- (prop.shown(db, variant) and prop.test(db, variant): the variant asked about, nil for
-- "any".)
function Studio.Shown(prop, db, variant)
	db = db or ns.GetDB() or {}
	if prop.client == "retail" and not ns.isRetail then return false end
	if prop.client == "forever" and ns.isRetail then return false end
	if prop.shown and not prop.shown(db, variant) then return false end
	return true
end

-- The settings of yours on a frame (one variant, one part, or all): { { prop, part, variant } }.
function Studio.Changed(f, variant, partId)
	local out = {}
	local db = ns.GetDB() or {}
	local variants = Studio.Variants(f)
	for _, v in ipairs(variants) do
		if variant == nil or v.id == variant then
			for _, each in ipairs(Studio.Props(f, partId)) do
				if Studio.Shown(each.prop, db, v.id) and Studio.SourceOf(f, each.prop, v.id) == "yours" then
					out[#out + 1] = { prop = each.prop, part = each.part, variant = v.id }
				end
			end
		end
	end
	return out
end

-- How many settings of yours a frame has, counted once and again only after a change:
-- the rail asked every frame on every draw (all their variants: Names 23 rows), and a
-- test picking every part held the game for a minute, run q3c49.
local changedCount = {}
function Studio.ChangedCount(f)
	local n = changedCount[f.id]
	if n == nil then
		n = #Studio.Changed(f)
		changedCount[f.id] = n
	end
	return n
end
function Studio.ForgetCounts() for k in pairs(changedCount) do changedCount[k] = nil end end
-- The open frame counted fresh (one frame: cheap), its saved count put right: a frame's
-- variants can come later (Nameplates' Smart rows, made with their page), run q101f's
-- footer said 1 while its list said 8.
function Studio.CountNow(f)
	local n = #Studio.Changed(f)
	changedCount[f.id] = n
	return n
end

-- History -----------------------------------------------------------------------------
-- One for the whole session: each step { desc, changes = { { key, before, after } } }.
local hist, fut = {}, {}
Studio.hist, Studio.fut = hist, fut
local listeners = {}
function Studio.OnChange(fn) listeners[#listeners + 1] = fn end
local function Notify(f)
	Studio.ForgetCounts() -- (a change: counted again as they're next asked)
	for _, fn in ipairs(listeners) do ns.Guard(fn, f) end
end
Studio.Notify = Notify

local function Refresh(f)
	if f and f.refresh then ns.Guard(f.refresh) end
	if ns.lowHealthKit and ns.lowHealthKit.Refresh then ns.Guard(ns.lowHealthKit.Refresh) end
end
Studio.RefreshFrame = Refresh

local function Same(a, b)
	if a == b then return true end
	return false
end

-- Changes { { key, value } } as one step named desc, on frame f.
function Studio.Apply(f, desc, writes)
	local step = { desc = desc, f = f and f.id, changes = {} }
	for _, w in ipairs(writes) do
		local before = Get(w[1])
		if not Same(before, w[2]) then
			step.changes[#step.changes + 1] = { key = w[1], before = before, after = w[2] }
			Put(w[1], w[2])
			if type(w[1]) == "string" and ns.lowHealthKit and ns.lowHealthKit.RecordKey and f and f.pageCanvas then
				-- (Counted on its page, for Reset page: StylePages' RecordKey.)
				ns.lowHealthKit.RecordKey(f.pageCanvas, w[1])
			end
		end
	end
	if #step.changes == 0 then return false end
	hist[#hist + 1] = step
	if #hist > 200 then table.remove(hist, 1) end
	for i = #fut, 1, -1 do fut[i] = nil end
	Refresh(f)
	Notify(f)
	return true
end

-- One property set: its key, and its swatch's keys for a color picked by swatch.
function Studio.Set(f, prop, variant, value, part)
	local key = Studio.KeyOf(prop, variant)
	local desc = Studio.Describe(f, prop, variant, part, value)
	return Studio.Apply(f, desc, { { key, value } })
end

function Studio.Describe(f, prop, variant, part, value)
	local where = {}
	if f.variants and variant ~= nil then
		for _, v in ipairs(f.variants) do if v.id == variant then where[#where + 1] = v.label end end
	end
	if part and #f.parts > 1 then where[#where + 1] = part.label end
	where[#where + 1] = prop.label
	local shown = value
	if type(value) == "boolean" then shown = value and L["On"] or L["Off"] end
	if prop.options then
		local options = type(prop.options) == "function" and prop.options() or prop.options
		for _, o in ipairs(options) do
			local v = o.value ~= nil and o.value or o[1]
			if v == value then shown = o.text or o[2] end
		end
	end
	return table.concat(where, " · ") .. (shown ~= nil and (" > " .. tostring(shown)) or "")
end

local function Replay(step, which)
	local f = step.f and frames[step.f]
	for i = (which == "before" and #step.changes or 1), (which == "before" and 1 or #step.changes),
		(which == "before" and -1 or 1) do
		local c = step.changes[i]
		Put(c.key, c[which])
	end
	Refresh(f)
	Notify(f)
end
function Studio.Undo()
	local step = table.remove(hist)
	if not step then return nil end
	Replay(step, "before")
	fut[#fut + 1] = step
	return step.desc
end
function Studio.Redo()
	local step = table.remove(fut)
	if not step then return nil end
	Replay(step, "after")
	hist[#hist + 1] = step
	return step.desc
end
-- (Audit 2026-11-25: other settings loaded under the editor (a profile switched, loaded or
-- reset: Profiles.lua's SettingsChanged; yours put back over a style demo) start a new
-- history: Undo wrote the profile left's value into the new one.)
function Studio.ClearHistory()
	if #hist == 0 and #fut == 0 then return end
	for i = #hist, 1, -1 do hist[i] = nil end
	for i = #fut, 1, -1 do fut[i] = nil end
	Notify(nil)
end
function Studio.CanUndo() return hist[#hist] and hist[#hist].desc end
function Studio.CanRedo() return fut[#fut] and fut[#fut].desc end

-- Reset by scope: "prop" (one), "part", "variant", "frame", "all". Gives the
-- writes it would make (to count them first) or makes them (apply = true).
function Studio.ResetWrites(scope, f, variant, partId, prop)
	local writes = {}
	local function Add(frame, p, v)
		if p.kind == "swatch" then
			if Studio.SourceOf(frame, p, v) == "yours" then
				for _, rk in ipairs(Studio.RGB(p, v) or {}) do writes[#writes + 1] = { rk, KeyDefault(rk) } end
			end
			return
		end
		local key = Studio.KeyOf(p, v)
		if key == nil or p.kind == "button" or p.kind == "text" then return end
		if Studio.SourceOf(frame, p, v) ~= "yours" then return end
		writes[#writes + 1] = { key, Studio.ResetValue(frame, p, v) }
		for _, rk in ipairs(Studio.RGB(p, v) or {}) do writes[#writes + 1] = { rk, KeyDefault(rk) } end
	end
	local db = ns.GetDB() or {}
	local list = scope == "all" and Studio.Ordered() or { f }
	for _, frame in ipairs(list) do
		for _, v in ipairs(Studio.Variants(frame)) do
			if scope == "all" or scope == "frame" or v.id == variant then
				for _, each in ipairs(Studio.Props(frame, (scope == "part" or scope == "prop") and partId or nil)) do
					if (scope ~= "prop" or each.prop == prop) and Studio.Shown(each.prop, db, v.id) then Add(frame, each.prop, v.id) end
				end
			end
		end
	end
	return writes
end
function Studio.Reset(scope, f, variant, partId, prop, desc)
	local writes = Studio.ResetWrites(scope, f, variant, partId, prop)
	if #writes == 0 then return 0 end
	if scope == "all" then
		-- (Each frame's runtime refreshed: one step.)
		Studio.Apply(f, desc or L["Reset everything in Style"], writes)
		for _, frame in ipairs(Studio.Ordered()) do Refresh(frame) end
	else
		Studio.Apply(f, desc or L["Reset"], writes)
	end
	return #writes
end

-- A look (the Looks strip): its values on a variant, as one step.
function Studio.ApplyLook(f, look, variant)
	if InCombatLockdown and InCombatLockdown() == true then return false end
	if look.apply then
		-- (A look that writes through its own code: its keys counted before and after.)
		local keys = {}
		for _, each in ipairs(Studio.Props(f)) do
			local key = Studio.KeyOf(each.prop, variant)
			if key ~= nil then keys[#keys + 1] = key end
			for _, rk in ipairs(Studio.RGB(each.prop, variant) or {}) do keys[#keys + 1] = rk end
		end
		local before = {}
		for i, key in ipairs(keys) do before[i] = Get(key) end
		look.apply(variant)
		local step = { desc = f.label .. " · " .. look.label, f = f.id, changes = {} }
		for i, key in ipairs(keys) do
			local now = Get(key)
			if now ~= before[i] then step.changes[#step.changes + 1] = { key = key, before = before[i], after = now } end
		end
		if #step.changes > 0 then
			hist[#hist + 1] = step
			for i = #fut, 1, -1 do fut[i] = nil end
		end
		Refresh(f)
		Notify(f)
		return true
	end
	local writes = {}
	for key, value in pairs(look.values or {}) do
		local k = type(key) == "function" and key(variant) or key
		writes[#writes + 1] = { k, value }
	end
	if look.reset then -- (the theme's look: every setting of this variant back first)
		for _, w in ipairs(Studio.ResetWrites("variant", f, variant)) do table.insert(writes, 1, w) end
	end
	return Studio.Apply(f, f.label .. " · " .. look.label, writes)
end

-- The look a preview shows for a moment (hover: never saved). Writes the value,
-- has the preview draw it, puts the saved one back.
-- (A field: its own set, then its saved value set back; a field marked noHover skipped.)
function Studio.ShowFor(preview, key, value)
	if not (preview and preview.Refresh) then return end
	if type(key) == "table" then
		if key.noHover or not (key.get and key.set) then return end
		local saved = key.get()
		if not pcall(key.set, value) then return end
		ns.Guard(preview.Refresh, preview)
		pcall(key.set, saved)
		return
	end
	if type(key) ~= "string" then return end
	local db = ns.GetDB()
	if not db then return end
	local saved = db[key]
	db[key] = value
	ns.Guard(preview.Refresh, preview)
	db[key] = saved
end

-- Find --------------------------------------------------------------------------------
-- Every property by its label, recipe, part, frame and synonyms.
local SYNONYMS = {
	Size = "scale bigger smaller", Opacity = "see-through transparency alpha fade", Outline = "edge stroke",
	Border = "edge frame line thickness", Color = "colour tint", Font = "typeface letters", Texture = "fill art statusbar",
	Background = "behind dark ground backdrop panel", Height = "tall thickness", Width = "wide long",
	Shadow = "drop shadow", Spark = "glow edge", Gradient = "fade shade", Shape = "mask round square",
}
local index
function Studio.Index()
	if index and not Studio.indexDirty then return index end
	index = {}
	local db = ns.GetDB() or {}
	for _, f in ipairs(Studio.Ordered()) do
		for _, each in ipairs(Studio.Props(f)) do
			local prop = each.prop
			if prop.label and Studio.Shown(prop, db, Studio.FirstVariant(f)) then
				local words = { prop.label, each.group.recipe, each.part.label, f.label, prop.syn or "", SYNONYMS[prop.label] or "" }
				index[#index + 1] = { f = f, part = each.part, prop = prop, group = each.group,
					hay = table.concat(words, " "):lower() }
			end
		end
	end
	Studio.indexDirty = false
	return index
end
function Studio.Find(text, limit)
	text = (text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then return {} end
	local words = {}
	for w in text:gmatch("%S+") do words[#words + 1] = w end
	local hits = {}
	for _, entry in ipairs(Studio.Index()) do
		local all = true
		for _, w in ipairs(words) do
			if not entry.hay:find(w, 1, true) then all = false break end
		end
		if all then hits[#hits + 1] = entry end
	end
	table.sort(hits, function(a, b)
		local sa = a.prop.label:lower():sub(1, #text) == text and 0 or 1
		local sb = b.prop.label:lower():sub(1, #text) == text and 0 or 1
		if sa ~= sb then return sa < sb end
		return false
	end)
	if limit and #hits > limit then
		for i = #hits, limit + 1, -1 do hits[i] = nil end
	end
	return hits
end

-- Whether a frame's look is live in the game now, and if not why: text, kind, action label, action.
function Studio.Status(f)
	local db = ns.GetDB() or {}
	if f.switch and not ns.StyleOn(f.switch, db) then
		local chain = {}
		if not db.styleGeneral then chain[#chain + 1] = L["Enable Style"] end
		if not db[f.switch] then chain[#chain + 1] = f.label end
		if #chain == 0 then chain[1] = L["a switch above it"] end
		return L["Off: %s. Nothing here shows in the game."]:format(table.concat(chain, " > ")), "off", L["Turn on"],
			function()
				local writes = {}
				if not db.styleGeneral then writes[#writes + 1] = { "styleGeneral", true } end
				if not db[f.switch] then writes[#writes + 1] = { f.switch, true } end
				-- (Every switch it's under, too: ns.PageSwitchOf's chain.)
				local at, guard = f.switch, 0
				while ns.PageSwitchOf and ns.PageSwitchOf(at) and guard < 8 do
					at, guard = ns.PageSwitchOf(at), guard + 1
					if db[at] == false then writes[#writes + 1] = { at, true } end
				end
				Studio.Apply(f, f.label .. " · " .. L["Turn on"], writes)
			end
	end
	if f.status then
		local text, kind, label, fn = f.status(db)
		if text then return text, kind or "warn", label, fn end
	end
	return nil
end
end) -- (ns.Module "style")
