-- The Style Studio (Style/Studio/*, Tools/style-studio/plan.md) on the stand-in:
--   python -I Tools/offline/run.py Tools/offline/stylestudio.lua [forever|retail] [frameId]
-- 1. Every frame spec: its keys real (in DEFAULTS, or a field), its groups recipes, its
--    controls from the grammar, its words the grammar's (no "Dark ground", "Your own", "Play").
-- 2. The model: a setting set, its source "yours", Undo and Redo, Reset by scope and its
--    count, a look, Find.
-- 3. The hosts: every frame opened in the Studio window, each variant and part drawn; each
--    Style page built with the editor on it; Reset page puts the editor's settings back.
-- Exit 1 on any FAIL.
local client, only = ...
client = client or "forever"
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local Studio = ns.Studio
local fails, passes = 0, 0
local function Pass() passes = passes + 1 end
local function Fail(text) fails = fails + 1 print("FAIL " .. text) end
local function Check(ok, text) if ok then Pass() else Fail(text) end end

for _, w in ipairs(wow.warnings or {}) do
	if tostring(w):find("Studio") then Fail("load: " .. tostring(w)) end
end
if not Studio then print("FAIL no ns.Studio") os.exit(1) end

local KINDS = { seg = true, tiles = true, slider = true, color = true, switch = true, drop = true, button = true,
	text = true, swatch = true }
local BANNED = { ["Dark ground"] = "Background", ["Behind the bar"] = "Background", ["Your own"] = "Custom",
	["Play"] = "Test", ["Text size"] = "Size", ["Thickness"] = "Size" }
local OUTLINE_OK = { None = true, Thin = true, Thick = true, ["The game's"] = true }
local db = ns.db

local function Opts(prop)
	local o = prop.options
	if type(o) == "function" then local ok, got = pcall(o) return ok and got or {} end
	return o or {}
end
local function ValueOf(o) if o.value ~= nil then return o.value end return o[1] end

-- 1. Specs: the frames the editor still serves, on the Nameplates pages and Range Hint's
-- (and Tooltips, the button checks' own page). Every other Style page is its old page
-- again since 2026-11-25; their specs stay for the hidden window only, unchecked.
local SERVED = { plates = true, platelayout = true, names = true, range = true, tooltips = true }
local frames = {}
for _, f in ipairs(Studio.Ordered()) do if SERVED[f.id] then frames[#frames + 1] = f end end
Check(#frames > 0, "no frames registered")
for _, f in ipairs(frames) do
	if not only or f.id == only then
		local where = "frame " .. f.id
		Check(type(f.label) == "string" and f.label ~= "", where .. ": label")
		Check(f.band == "General" or f.band == "Interface" or f.band == "Visions" or f.band == "Atmosphere",
			where .. ": band " .. tostring(f.band))
		if f.switch then Check(ns.DEFAULTS[f.switch] ~= nil, where .. ": switch " .. f.switch .. " not in DEFAULTS") end
		Check(type(f.parts) == "table" and #f.parts > 0, where .. ": no parts")
		local seenKey = {}
		for _, part in ipairs(f.parts or {}) do
			local pw = where .. " part " .. tostring(part.id)
			Check(type(part.label) == "string", pw .. ": label")
			Check(#(part.groups or {}) > 0, pw .. ": no groups")
			for _, group in ipairs(part.groups or {}) do
				Check(Studio.RECIPE_RANK[group.recipe] ~= nil, pw .. ": recipe " .. tostring(group.recipe) .. " not in Studio.RECIPES")
				for _, prop in ipairs(group.props or {}) do
					local lw = pw .. " " .. tostring(prop.label or prop.kind)
					Check(KINDS[prop.kind], lw .. ": kind " .. tostring(prop.kind))
					if prop.label and BANNED[prop.label] then Fail(lw .. ": say " .. BANNED[prop.label] .. ", not " .. prop.label) end
					if prop.kind ~= "button" and prop.kind ~= "text" and prop.kind ~= "swatch" then
						for _, v in ipairs(Studio.Variants(f)) do
							local key = Studio.KeyOf(prop, v.id)
							if type(key) == "string" then
								Check(ns.DEFAULTS[key] ~= nil or prop.default ~= nil, lw .. ": key " .. key .. " not in DEFAULTS")
								local sk = key .. "|" .. tostring(v.id)
								if seenKey[sk] and seenKey[sk] ~= prop then Fail(lw .. ": key " .. key .. " on two rows") end
								seenKey[sk] = prop
							else
								Check(type(key) == "table" and type(key.get) == "function" and type(key.set) == "function",
									lw .. ": key is neither a db key nor a field")
							end
						end
					end
					for _, v in ipairs(Studio.Variants(f)) do
						for _, rk in ipairs(Studio.RGB(prop, v.id) or {}) do
							if type(rk) == "string" then
								Check(ns.DEFAULTS[rk] ~= nil, lw .. ": color key " .. rk .. " not in DEFAULTS")
							else
								Check(type(rk) == "table" and type(rk.get) == "function", lw .. ": color key neither a db key nor a field")
							end
						end
					end
					if prop.kind == "slider" then
						Check(type(prop.min) == "number" and type(prop.max) == "number" and prop.min < prop.max, lw .. ": slider range")
						Check(prop.unit ~= nil, lw .. ": slider without a unit")
					end
					if prop.kind == "seg" or prop.kind == "drop" or prop.kind == "color" then
						local opts = Opts(prop)
						Check(#opts > 0, lw .. ": no options")
						-- (The saved default is one of them: a choice the page can't show is a bug.)
						local key = Studio.KeyOf(prop, Studio.FirstVariant(f))
						local def = type(key) == "string" and (prop.default or ns.DEFAULTS[key]) or nil -- (a field: none to check)
						if def ~= nil and #opts > 0 and prop.inherit == nil then
							local found = false
							for _, o in ipairs(opts) do if ValueOf(o) == def then found = true end end
							Check(found, lw .. ": default " .. tostring(def) .. " is none of its choices")
						end
					end
					if prop.label == "Outline" then
						for _, o in ipairs(Opts(prop)) do
							local text = o.text or o[2]
							if ValueOf(o) ~= -1 and ValueOf(o) ~= "general" then
								Check(OUTLINE_OK[text], lw .. ": outline choice " .. tostring(text) .. " not None/Thin/Thick")
							end
						end
					end
				end
			end
		end
	end
end

-- 2. The model, on the first frame with a slider and a choice.
local function FirstProp(kind)
	for _, f in ipairs(frames) do
		for _, each in ipairs(Studio.Props(f)) do
			local key = Studio.KeyOf(each.prop, Studio.FirstVariant(f))
			if each.prop.kind == kind and type(key) == "string" and Studio.Shown(each.prop, db) then return f, each.prop, each.part, key end
		end
	end
end
do
	local f, prop, part, key = FirstProp("slider")
	if f then
		local before = db[key]
		local want = (prop.min + prop.max) / 2
		if want == before then want = prop.min end
		Studio.Set(f, prop, Studio.FirstVariant(f), want, part)
		Check(db[key] == want, "set: " .. key)
		Check(Studio.SourceOf(f, prop, Studio.FirstVariant(f)) == "yours", "source after set: " .. tostring(Studio.SourceOf(f, prop, Studio.FirstVariant(f))))
		Check(#Studio.ResetWrites("frame", f) >= 1, "reset count")
		Studio.Undo()
		Check(db[key] == before, "undo: " .. tostring(db[key]) .. " vs " .. tostring(before))
		Studio.Redo()
		Check(db[key] == want, "redo")
		local n = Studio.Reset("prop", f, Studio.FirstVariant(f), part.id, prop)
		Check(n >= 1 and Studio.SourceOf(f, prop, Studio.FirstVariant(f)) ~= "yours", "reset one")
		Studio.Undo()
		Check(db[key] == want, "undo reset")
		Studio.Reset("frame", f)
		Check(#Studio.ResetWrites("frame", f) == 0, "reset frame leaves nothing of yours")
		db[key] = before
	else
		Fail("no slider anywhere")
	end
	local hits = Studio.Find("outline")
	Check(#hits > 0, "find outline")
	Check(#Studio.Find("zzzz no such") == 0, "find nothing")
end

-- 2b. Pointing at a choice saves nothing (Audit 2026-11-25, Tools/audits/2026-11-25-style-editor-hover.md):
-- every field on Nameplate Style, Range Hint and the frames whose fields that card fixed (Cast bars,
-- Nameplate Style's tab; Unit, Raid frames; Personal resources), each choice hovered on each variant,
-- the settings as they were after it. (A setting read as its default when unsaved: nil and its default
-- the same.) Not yet Name Style (Letters > Its own copies the name's font to line 2) nor Nameplate
-- Layout (Forever: plateLayoutData written): open, reported with the card.
do
	local function Now(k, v) if v == nil then return ns.DEFAULTS[k] end return v end
	local function Same(a, b, depth)
		if a == b then return true end
		if type(a) ~= "table" or type(b) ~= "table" or (depth or 0) > 6 then return false end
		for k, v in pairs(a) do if not Same(v, b[k], (depth or 0) + 1) then return false end end
		for k in pairs(b) do if a[k] == nil then return false end end
		return true
	end
	local function Deep(v, depth)
		if type(v) ~= "table" or (depth or 0) > 6 then return v end
		local out = {}
		for k, x in pairs(v) do out[k] = Deep(x, (depth or 0) + 1) end
		return out
	end
	local function Copy() local out = {} for k, v in pairs(db) do out[k] = Deep(v) end return out end
	local preview = { Refresh = function() end }
	local list = {}
	for _, id in ipairs({ "plates", "range", "cast", "unit", "raid", "prd" }) do
		if Studio.frames[id] then list[#list + 1] = Studio.frames[id] end
	end
	for _, f in ipairs(list) do
		if not only or f.id == only then
			for _, v in ipairs(Studio.Variants(f)) do
				for _, each in ipairs(Studio.Props(f)) do
					local key = Studio.KeyOf(each.prop, v.id)
					if type(key) == "table" and (each.prop.kind == "seg" or each.prop.kind == "drop" or each.prop.kind == "tiles") then
						for _, o in ipairs(Opts(each.prop)) do
							local before = Copy()
							Studio.ShowFor(preview, key, ValueOf(o))
							local moved
							for k in pairs(ns.DEFAULTS) do
								if not Same(Now(k, before[k]), Now(k, db[k])) then moved = k break end
							end
							for k, value in pairs(db) do
								if moved == nil and ns.DEFAULTS[k] == nil and not Same(before[k], value) then moved = k end
							end
							Check(moved == nil, ("hover %s %s %s > %s: saved %s"):format(f.id, tostring(v.id),
								tostring(each.prop.label), tostring(ValueOf(o)), tostring(moved)))
							for k in pairs(db) do db[k] = nil end
							for k, value in pairs(before) do db[k] = value end
						end
					end
				end
			end
		end
	end
end

-- 3. Hosts: the window on every frame, every variant and part. Each opened right after a
-- frame with no variants (the in-game run qe98e: a frame drew once with the last one's
-- variant, false, and Unit, Raid and Cast errored).
local plain
for _, f in ipairs(frames) do if not f.variants then plain = f.id break end end
for _, f in ipairs(frames) do
	if not only or f.id == only then
		if plain then pcall(ns.OpenStyleStudio, plain) end
		local ok, err = pcall(ns.OpenStyleStudio, f.id)
		Check(ok, "studio " .. f.id .. ": " .. tostring(err))
		local win = ns.StyleStudioWindow()
		for _, v in ipairs(Studio.Variants(f)) do
			for _, part in ipairs(f.parts) do
				local ok2, err2 = pcall(function() win.host:Pick(part.id, v.id) end)
				Check(ok2, ("studio %s %s %s: %s"):format(f.id, tostring(v.id), part.id, tostring(err2)))
			end
		end
		local ok3, err3 = pcall(function() win.host:ResetMenu(win) end)
		Check(ok3, "reset menu " .. f.id .. ": " .. tostring(err3))
	end
end
-- (The window opens on any frame shown here: a frame hidden on this client opens none.)
if not ns.StyleStudioWindow() then pcall(ns.OpenStyleStudio) end
if ns.StyleStudioWindow() then
	local ok, err = pcall(function() ns.StyleStudioWindow().ShowChanged() end)
	Check(ok, "changed view: " .. tostring(err))
end

-- 4. Every button clicked (Dev/StyleStudioTest.lua's ns.StyleStudioButtonChecks): menus
-- open and close on their button, close as it hides, scopes confirm, Undo/Redo, pills.
if not only and ns.StyleStudioButtonChecks then
	local okB, checks = pcall(ns.StyleStudioButtonChecks, false)
	Check(okB, "button clicks ran: " .. tostring(okB or checks))
	for _, c in ipairs(okB and checks or {}) do Check(c[1], "button: " .. c[2]) end
	-- (The game's way too, real = true: it must at least run through without an error,
	-- though the stand-in's Click runs no script. Run q66f9: that path overflowed.)
	local okR, errR = pcall(ns.StyleStudioButtonChecks, true)
	Check(okR, "button clicks, the game's way, ran: " .. tostring(okR or errR))
end

-- And the pages with the editor: Nameplates, Layout, Names and Range Hint; every other
-- Style page is its old self again (the user, 2026-11-25: "i want the old pages back
-- except for nameplates"), the editor on none of them.
local EDITOR_PAGES = { plates = true, platelayout = true, names = true,
	range = ns.CreateRangeHintStylePanel ~= nil } -- (Range Hint's page: Style/RangeHintStyle.lua, when it's there)
for _, f in ipairs(Studio.Ordered()) do
	if (not only or f.id == only) and f.page then
		if EDITOR_PAGES[f.id] then
			Check(f.pageCanvas ~= nil or (ns.PageGone and ns.PageGone(f.page)),
				"page " .. f.page .. " has no editor (ns.StyleEditorPage never called)")
		else
			Check(f.pageCanvas == nil, "page " .. f.page .. " has the editor; it should be its old page")
		end
	end
end

print(("PASS stylestudio %s: %d checks"):format(client, passes))
print(("stylestudio %s: %d pass, %d fail"):format(client, passes, fails))
if fails > 0 then print(fails .. " FAILED") os.exit(1) end
print("ALL PASS")
