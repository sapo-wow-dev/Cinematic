-- Combat Text Style's Spells tab: a listed spell's kind once it's seen (the
-- audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-25-combat-text-seen-kind.md):
--   python -I Tools/offline/run.py Tools/offline/combattextseenkindmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/combattextseenkindmatrix.lua forever --base <ref>
-- A spell on the list added from the spellbook (a damage spell till seen,
-- school not known), from the spellbook and already seen once (its school
-- learned, as players who added a heal before this fix have it), as a heal
-- or as your pet's (from "Your spells that hit"), or not on the list; then
-- a hit of it seen as a damage hit, a heal or your pet's, a direct hit or a
-- tick. Each cell: its kind on the list and the heading it files under (the
-- text its look starts from).
-- The rule (2026-11-25): a spell listed as a damage spell, once seen as a
-- heal or your pet's, becomes that (under Heals, Your pet). One listed as a
-- heal or your pet's stays so; a damage sighting changes nothing.
local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local CT = ns.CombatTexts

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "combat-text-seen-kind",
	fixed = { client = client },
	dims = {
		{ "added", { "book", "bookSeen", "heal", "pet", "notListed" } },
		{ "seenAs", { "damage", "heal", "pet" } },
		{ "tick", { "no", "yes" } },
	},
	cell = function(c)
		CinematicCharDB = {} -- luacheck: ignore 111
		ns.db.combatTextSpells = {}
		local name = "Healing Wave"
		if c.added == "book" then CT.AddSpell(name, { kind = "damage", unknown = true })
		elseif c.added == "bookSeen" then CT.AddSpell(name, { kind = "damage", school = 8 })
		elseif c.added == "heal" then CT.AddSpell(name, { kind = "heal", school = 8 })
		elseif c.added == "pet" then CT.AddSpell(name, { kind = "pet", school = 8 }) end
		CT.NoteSeen({ name = name, school = 8, icon = 5, tick = c.tick == "yes" or nil }, c.seenAs)
		local info = CT.SpellInfo(name)
		if not info then return "not listed" end
		return ("kind=%s base=%s"):format(tostring(info.kind), CT.SpellBase(name))
	end,
	pins = {
		{ "", "kind=damage base=spellNature" },
		{ "seenAs=heal", "kind=heal base=heal" },
		{ "seenAs=pet", "kind=pet base=pet" },
		-- (Listed as a heal or your pet's: stays.)
		{ "added=heal", "kind=heal base=heal" },
		{ "added=pet", "kind=pet base=pet" },
		{ "added=notListed", "not listed" },
	},
})
