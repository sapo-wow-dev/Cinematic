-- Nameplate Style's Mark part on each variant, Default's and the Smart rows' (the audit
-- kit's matrix, Tools/offline/matrix.lua; fix card Tools/audits/2026-11-26-plate-mark-default.md):
--   python -I Tools/offline/run.py Tools/offline/platemarkdefaultmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/platemarkdefaultmatrix.lua forever --base <ref>
-- The editor's Mark part (Style/Studio/Frames/Nameplates.lua's markPart) was for the Smart
-- rows only (shown: not Default): a mark set on Default (othersMark*, the old drawer's Mark
-- line, a built-in profile or a shared string) showed on every plate with nothing to change
-- or remove it. The states: the variant (Default, the unit rows, Aggro on you, a row added
-- on the page: no DEFAULTS of its own), the part's field. Each cell: "no part" while the
-- variant hasn't the part; else the key(s) the field writes, and whether the plates read
-- what it wrote (ns.TargetMarkSetting, the plates' own reader: "plate=ok"); the part's tab
-- itself "shown"; Style's "none" choice, its label. The rule (audit 2026-11-26): every
-- variant has it, each field on its own row's keys (Default's othersMark<key>), Default's
-- "none" named The game's as its old drawer's OTHERS_STYLES had it.

local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local Studio = ns.Studio
local db = ns.db
local f = Studio.frames.plates

local part
for _, p in ipairs(f.parts or {}) do if p.id == "mark" then part = p end end
local props = {}
for _, group in ipairs(part.groups) do
	for _, prop in ipairs(group.props) do props[prop.label] = prop end
end
local L = ns.L
-- The part's fields: its prop's label, the plates' setting name, a value to write.
local FIELDS = {
	Style = { label = L["Mark"], name = "Style", value = "diamond" },
	Color = { label = L["Color"], name = "Color", value = "gold" },
	RGB = { label = L["Color"], name = "R", rgb = true, value = 0.25 },
	Size = { label = L["Size"], name = "Size", value = 1.55 },
	Opacity = { label = L["Opacity"], name = "Opacity", value = 0.45 },
	Moving = { label = L["Moving"], name = "Bob", value = "probe" },
}

-- The db key a key writes: a string itself; a field, the one its set changes.
local function KeyName(key)
	if type(key) == "string" then return key end
	local before = {}
	for k, v in pairs(db) do before[k] = v end
	key.set("matrix-probe")
	local found
	for k, v in pairs(db) do
		if v == "matrix-probe" and before[k] ~= "matrix-probe" then found = k end
	end
	if found then db[found] = before[found] end
	return found or "?"
end
local function Write(key, value)
	if type(key) == "table" then key.set(value) else db[key] = value end
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "plate-mark-default",
	fixed = { client = client },
	dims = {
		{ "variant", { "others", "target", "mouseover", "focus", "aggro", "npcEnemy" } },
		{ "field", { "part", "Style", "Color", "RGB", "Size", "Opacity", "Moving", "nonelabel" } },
	},
	cell = function(c)
		local v = c.variant
		local has = not part.shown or part.shown(v)
		if c.field == "part" then return has and "shown" or "hidden" end
		if not has then return "no part" end
		local styleProp = props[L["Mark"]]
		if c.field == "nonelabel" then
			local list = styleProp.options(v)
			for _, o in ipairs(list) do
				if (o.value or o[1]) == "none" then return o.text or o[2] end
			end
			return "no none"
		end
		local spec = FIELDS[c.field]
		local prop = props[spec.label]
		local saved = {}
		local function Keep(k) if saved[k] == nil then saved[k] = { db[k] } end end
		local styleKey = Studio.KeyOf(styleProp, v)
		local styleName = KeyName(styleKey)
		Keep(styleName)
		-- (A mark on, so the rest of the part shows: Style's "none" hides it.)
		if c.field ~= "Style" then Write(styleKey, "arrow") end
		local out
		if spec.rgb then
			local keys = Studio.RGB(prop, v)
			local names = {}
			for i, k in ipairs(keys) do names[i] = KeyName(k) Keep(names[i]) end
			out = table.concat(names, ",")
			Write(keys[1], spec.value)
		else
			local key = Studio.KeyOf(prop, v)
			out = KeyName(key)
			Keep(out)
			Write(key, spec.value)
		end
		local shown = Studio.Shown(prop, db, v)
		local read = ns.TargetMarkSetting(spec.name, v)
		for k, kept in pairs(saved) do db[k] = kept[1] end
		return ("%s%s plate=%s"):format(out, shown and "" or " (row hidden)", read == spec.value and "ok" or tostring(read))
	end,
	pins = {
		{ "field=part", "shown" },
		{ "field=nonelabel", L["None"] },
		{ "variant=others field=nonelabel", L["The game's"] },
		-- (Each field on its own row's keys; your target's are targetArrow<key>.)
		{ "variant=others field=Style", "othersMarkStyle plate=ok" },
		{ "variant=others field=Color", "othersMarkColor plate=ok" },
		{ "variant=others field=RGB", "othersMarkR,othersMarkG,othersMarkB plate=ok" },
		{ "variant=others field=Size", "othersMarkSize plate=ok" },
		{ "variant=others field=Opacity", "othersMarkOpacity plate=ok" },
		{ "variant=others field=Moving", "othersMarkBob plate=ok" },
		{ "variant=target field=Style", "targetArrowStyle plate=ok" },
		{ "variant=target field=Color", "targetArrowColor plate=ok" },
		{ "variant=target field=RGB", "targetArrowR,targetArrowG,targetArrowB plate=ok" },
		{ "variant=target field=Size", "targetArrowSize plate=ok" },
		{ "variant=target field=Opacity", "targetArrowOpacity plate=ok" },
		{ "variant=target field=Moving", "targetArrowBob plate=ok" },
		{ "variant=mouseover field=Style", "mouseoverMarkStyle plate=ok" },
		{ "variant=mouseover field=Color", "mouseoverMarkColor plate=ok" },
		{ "variant=mouseover field=RGB", "mouseoverMarkR,mouseoverMarkG,mouseoverMarkB plate=ok" },
		{ "variant=mouseover field=Size", "mouseoverMarkSize plate=ok" },
		{ "variant=mouseover field=Opacity", "mouseoverMarkOpacity plate=ok" },
		{ "variant=mouseover field=Moving", "mouseoverMarkBob plate=ok" },
		{ "variant=focus field=Style", "focusMarkStyle plate=ok" },
		{ "variant=focus field=Color", "focusMarkColor plate=ok" },
		{ "variant=focus field=RGB", "focusMarkR,focusMarkG,focusMarkB plate=ok" },
		{ "variant=focus field=Size", "focusMarkSize plate=ok" },
		{ "variant=focus field=Opacity", "focusMarkOpacity plate=ok" },
		{ "variant=focus field=Moving", "focusMarkBob plate=ok" },
		{ "variant=aggro field=Style", "aggroMarkStyle plate=ok" },
		{ "variant=aggro field=Color", "aggroMarkColor plate=ok" },
		{ "variant=aggro field=RGB", "aggroMarkR,aggroMarkG,aggroMarkB plate=ok" },
		{ "variant=aggro field=Size", "aggroMarkSize plate=ok" },
		{ "variant=aggro field=Opacity", "aggroMarkOpacity plate=ok" },
		{ "variant=aggro field=Moving", "aggroMarkBob plate=ok" },
		{ "variant=npcEnemy field=Style", "npcEnemyMarkStyle plate=ok" },
		{ "variant=npcEnemy field=Color", "npcEnemyMarkColor plate=ok" },
		{ "variant=npcEnemy field=RGB", "npcEnemyMarkR,npcEnemyMarkG,npcEnemyMarkB plate=ok" },
		{ "variant=npcEnemy field=Size", "npcEnemyMarkSize plate=ok" },
		{ "variant=npcEnemy field=Opacity", "npcEnemyMarkOpacity plate=ok" },
		{ "variant=npcEnemy field=Moving", "npcEnemyMarkBob plate=ok" },
	},
})
