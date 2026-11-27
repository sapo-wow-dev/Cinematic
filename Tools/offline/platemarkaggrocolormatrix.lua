-- Nameplate Style's Mark part: each row's mark Color choices (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-26-plate-mark-aggro-color.md):
--   python -I Tools/offline/run.py Tools/offline/platemarkaggrocolormatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/platemarkaggrocolormatrix.lua forever --base <ref>
-- An Aggro on you row's mark could be your target's look and color (aggroMarkStyle and
-- aggroMarkColor "same": PlateParts' ArrowSetting then reads your target's Style, or its
-- Color and R, G, B). Its drawer before 679e735 offered Your target's for both (AGGRO_STYLES,
-- AGGRO_COLORS); the editor's Mark (style) kept it, its Color lost it. The states: the row
-- (Default, the unit rows, the Aggro rows: Aggro on you, one Distance's, a second one, and the
-- other aggro kinds, which ArrowSetting doesn't read "same" for). Each cell: the Color
-- choices' values in order, and for a row offered "same", whether picking it gives the
-- plate your target's color (same=target's). The rule (audit 2026-11-26): every row whose
-- base is aggro (the rows ArrowSetting reads "same" for) offers it first, as before.

local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local Studio = ns.Studio
local db = ns.db
local L = ns.L
local f = Studio.frames.plates

local colorProp
for _, p in ipairs(f.parts or {}) do
	if p.id == "mark" then
		for _, group in ipairs(p.groups) do
			for _, prop in ipairs(group.props) do
				if prop.kind == "color" and prop.label == L["Color"] then colorProp = prop end
			end
		end
	end
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "plate-mark-aggro-color",
	fixed = { client = client },
	dims = {
		{ "row", { "others", "target", "mouseover", "focus", "aggro", "aggroIn28", "aggro2", "aggroother",
			"aggrohealer", "npcEnemy" } },
	},
	cell = function(c)
		local v = c.row
		local opts = colorProp.options
		local list = type(opts) == "function" and opts(v) or opts
		local values = {}
		local same = false
		for _, o in ipairs(list) do
			local value = o.value ~= nil and o.value or o[1]
			values[#values + 1] = value
			if value == "same" then same = true end
		end
		local out = table.concat(values, ",")
		if same then
			-- (Picked: the plate's mark in your target's color, its own R, G, B left.)
			local key = Studio.KeyOf(colorProp, v)
			local name = type(key) == "string" and key or nil
			local kept = { color = name and db[name], r = db.targetArrowR, tc = db.targetArrowColor }
			if name then db[name] = "same" else key.set("same") end
			db.targetArrowColor, db.targetArrowR = "custom", 0.123
			local how, r = ns.TargetMarkSetting("Color", v), ns.TargetMarkSetting("R", v)
			if name then db[name] = kept.color else key.set(nil) end
			db.targetArrowColor, db.targetArrowR = kept.tc, kept.r
			out = out .. ((how == "custom" and r == 0.123) and " same=target's" or " same=own")
		end
		return out
	end,
	pins = {
		{ "", "gold,reaction,class,custom" },
		{ "row=aggro", "same,gold,reaction,class,custom same=target's" },
		{ "row=aggroIn28", "same,gold,reaction,class,custom same=target's" },
		{ "row=aggro2", "same,gold,reaction,class,custom same=target's" },
	},
})
