-- Style Studio's recipes: the property makers every frame spec uses, so the same kind
-- of setting has the same name, the same choices in the same order, and the same
-- control on every page (plan section 4.2-4.3). Studio.R.*: each gives a property.
--   Font(key, opts)        tiles: General's first where it's shared, then every font.
--   Texture(key, opts)     tiles: a bar texture (opts.game: the game's entry's name).
--   Outline(key, opts)     segments: [General's] None, Thin, Thick (opts.max, opts.own).
--   Shadow(key, opts)      segments: [General's] The game's, On, None.
--   Border(key, opts)      Border, its Size and Color (three properties, as a list).
--   Choice(key, label, options, opts), Slider(key, label, min, max, step, unit, opts),
--   Switch(key, label, opts), Color(key, label, options, rgb, custom, opts),
--   Swatch(label, rgb, opts), Drop(key, label, options, opts), Button(label, run, opts),
--   Note(text, opts).
-- opts on any: tip, test, shown, free, inherit, default, client, syn, scale.
local _, ns = ...
ns.Module("style", function()
local L = ns.L
local Studio = ns.Studio
local R = {}
Studio.R = R

local function With(prop, opts)
	for k, v in pairs(opts or {}) do if prop[k] == nil then prop[k] = v end end
	return prop
end

-- The key a shared setting goes by for General's name (variant keys: the first's).
local function BaseKey(key)
	if type(key) == "function" then return key(nil) end
	return key
end

function R.Font(key, opts)
	opts = opts or {}
	return With({ kind = "tiles", label = opts.label or L["Font"], key = key, tip = opts.tip or L["The letters' font."],
		options = function()
			local list = {}
			if opts.first then list[1] = { value = opts.first[1], text = opts.first[2] } end
			local base = BaseKey(key)
			local general = type(base) == "string" and ns.GeneralStyleValue and ns.GeneralStyleValue(base)
			local choices = ns.StyleFontChoices()
			if general ~= nil then
				local entry = { value = "general", text = ns.SharedStyleSource(base) .. " (" .. ns.StyleFontName(general) .. ")" }
				for _, c in ipairs(choices) do if c.value == general then entry.font = c.font end end
				list[#list + 1] = entry
			end
			for _, c in ipairs(choices) do list[#list + 1] = c end
			return list
		end }, opts)
end

function R.Texture(key, opts)
	opts = opts or {}
	return With({ kind = "tiles", label = opts.label or L["Texture"], key = key, tip = opts.tip or L["The bar's fill."],
		options = function()
			-- (A bar's fill shown green on its tile, as a health bar; other pictures as they are.)
			local list = ns.StyleTextureChoices(opts.game, BaseKey(key))
			for _, choice in ipairs(list) do choice.tint = choice.tint or opts.tint or { 0.25, 0.72, 0.3 } end
			return list
		end }, opts)
end

local OUTLINE_NAMES = { [0] = "None", "Thin", "Thick" }
function R.Outline(key, opts)
	opts = opts or {}
	local max = opts.max or 2
	return With({ kind = "seg", label = L["Outline"], key = key,
		tip = opts.tip or L["A dark line around the letters."],
		options = function()
			local list = {}
			local base = BaseKey(key)
			local general = type(base) == "string" and ns.GeneralStyleValue and ns.GeneralStyleValue(base)
			if general ~= nil then
				local named = general == "game" and L["The game's"] or L[OUTLINE_NAMES[general] or "None"]
				list[1] = { -1, ns.SharedStyleSource(base), ns.SharedStyleSource(base) .. " (" .. named .. ")" }
			elseif opts.own then
				list[1] = { -1, opts.own }
			end
			local values = opts.values or { 0, 1, 2 } -- (a page storing words: opts.values = { "none", "thin", "thick" })
			for i = 0, max do list[#list + 1] = { values[i + 1], L[OUTLINE_NAMES[i]] } end
			if opts.game then table.insert(list, (list[1] and list[1][1] == -1) and 2 or 1, { opts.game, L["The game's"] }) end
			return list
		end }, opts)
end

function R.Shadow(key, opts)
	opts = opts or {}
	return With({ kind = "seg", label = L["Shadow"], key = key, tip = opts.tip or L["A soft dark shadow behind the letters."],
		options = function()
			local list = {}
			local base = BaseKey(key)
			if type(base) == "string" and ns.GeneralStyleValue and ns.GeneralStyleValue(base) ~= nil then
				list[1] = { "general", ns.SharedStyleSource(base) }
			end
			if opts.game ~= false then list[#list + 1] = { "game", L["The game's"] } end
			list[#list + 1] = { opts.on or "on", L["On"] }
			list[#list + 1] = { opts.none or "none", L["None"] }
			return list
		end }, opts)
end

-- A border: its kind, then (for Custom) its size and color. Gives three properties.
local BORDER_NAMES = { game = "The game's", none = "None", thin = "Thin", thick = "Thick", custom = "Custom",
	colored = "In its color" }
function R.Border(key, opts)
	opts = opts or {}
	local function Name(value)
		if value == "game" and type(opts.game) == "string" then return opts.game end
		if value == "colored" and type(opts.colored) == "string" then return opts.colored end
		return L[BORDER_NAMES[value] or "None"]
	end
	local function Suffix(suffix)
		if type(key) == "function" then return function(v) local k = key(v) return type(k) == "string" and (k .. suffix) or k end end
		return key .. suffix
	end
	local base = BaseKey(key)
	local test = opts.test
	local function Custom(db)
		local k = type(key) == "function" and key(nil) or key
		return (not test or test(db)) and db[k] == "custom"
	end
	local kindProp = With({ kind = "seg", label = opts.label or L["Border"], key = key,
		tip = opts.tip or L["The line around it."],
		options = function()
			local list = {}
			local general = ns.GeneralStyleValue and ns.GeneralStyleValue(base)
			if general ~= nil then list[1] = { "general", ns.SharedStyleSource(base) .. " (" .. Name(general) .. ")" } end
			if opts.game then list[#list + 1] = { "game", Name("game") } end
			for _, v in ipairs({ "none", "thin", "thick" }) do list[#list + 1] = { v, Name(v) } end
			if opts.colored then list[#list + 1] = { "colored", Name("colored") } end
			list[#list + 1] = { "custom", Name("custom") }
			return list
		end }, { test = test, shown = opts.shown, free = opts.free, inherit = opts.inherit, client = opts.client })
	local sizeProp = { kind = "slider", label = L["Size"], key = Suffix("Size"), min = 1, max = 10, step = 1, unit = "px",
		tip = L["How thick the border is, in pixels."], test = Custom, shown = opts.shown, client = opts.client }
	local colorProp = { kind = "swatch", label = L["Color"], rgb = { base .. "R", base .. "G", base .. "B" },
		setKey = key, setTo = "custom", tip = L["The border's color; picking one switches it to Custom."],
		test = test, shown = opts.shown, client = opts.client }
	return kindProp, sizeProp, colorProp
end

function R.Choice(key, label, options, opts)
	return With({ kind = "seg", label = label, key = key, options = options }, opts)
end
function R.Drop(key, label, options, opts)
	return With({ kind = "drop", label = label, key = key, options = options }, opts)
end
-- min, max, step: as shown (the old rows.Slider's way); opts.scale: shown = saved * scale
-- (100 for a 0-1 value shown as %). unit: "%", "px", "s", "x".
function R.Slider(key, label, min, max, step, unit, opts)
	local scale = opts and opts.scale or 1
	return With({ kind = "slider", label = label, key = key, min = min / scale, max = max / scale,
		step = (step or 1) / scale, unit = unit, scale = scale }, opts)
end
function R.Switch(key, label, opts)
	return With({ kind = "switch", label = label, key = key }, opts)
end
-- A color by its source (options: { value, text }), custom: the value that uses the swatch.
function R.Color(key, label, options, rgb, custom, opts)
	return With({ kind = "color", label = label or L["Color"], key = key, options = options, rgb = rgb,
		custom = custom or (rgb and "custom" or nil) }, opts)
end
function R.Swatch(label, rgb, opts)
	return With({ kind = "swatch", label = label or L["Color"], rgb = rgb }, opts)
end
function R.Button(label, run, opts)
	return With({ kind = "button", label = label, text = label, run = run, free = true }, opts)
end
function R.Note(text, opts)
	return With({ kind = "text", text = text, free = true }, opts)
end

-- A part's Shown (decision 5: what the Overrides page set): styleOver_<rowKey> = "row"
-- (follows its Interface page), "hide" or "show" (Style/StyleOverrides.lua's ns.StyleOverride).
function R.Shown(rowKey, opts)
	return With({ kind = "seg", label = L["Shown"], key = "styleOver_" .. rowKey,
		default = "row", tip = L["Whether this part shows, over what its Interface page says."],
		options = { { "row", L["As its page says"] }, { "hide", L["Hidden"] }, { "show", L["Shown"] } } }, opts)
end

-- A group: { recipe = name, props = { ... } } (Border's three spread in with R.Group).
function R.Group(recipe, ...)
	local props = {}
	for i = 1, select("#", ...) do
		local p = select(i, ...)
		if p then props[#props + 1] = p end
	end
	return { recipe = recipe, props = props }
end
end) -- (ns.Module "style")
