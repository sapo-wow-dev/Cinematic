-- The drain ring's shield size and charges from a spell's text on every
-- client language (UI/CooldownRing.lua's AbsorbNumber / ChargesNumber via
-- ns.CooldownRingDescriptionSize / DescriptionCharges), the audit kit's
-- matrix (Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-23-cdm-ring-locale.md):
--   python -I Tools/offline/run.py Tools/offline/cdmringlocalematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/cdmringlocalematrix.lua --base <ref>
-- A shield's description (44, or 1234 with the language's thousands mark),
-- a buff with a number and no shield, Lightning Shield's "3 charges", in
-- English, German, French, Russian and Spanish. Each cell: the size and the
-- charges found.
-- The rule (release review 2026-11-23): every language finds the shield's
-- size and the charges, the whole number; a buff with no shield gets none;
-- English reads as before.
local client = arg and arg[1] or "forever"
local desc, locale = {}, "enUS"
-- luacheck: push ignore 111 112 113 121 122 212
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function(wow)
	InCombatLockdown = function() return false end
	GetLocale = function() return locale end
	C_Spell = C_Spell or {}
	C_Spell.GetSpellDescription = function(id) return desc[id] end
	local _ = wow
end)
-- luacheck: pop

-- (Close to each client's own words; the numbers are what counts.)
local TEXTS = {
	enUS = {
		shield = "Draws on the soul of the friendly target to shield them, absorbing 44 damage. Lasts 30 sec.",
		big = "Draws on the soul of the friendly target to shield them, absorbing 1,234 damage. Lasts 30 sec.",
		other = "Power infuses the target, increasing their Stamina by 3 for 30 min.",
		charges = "Surrounds the caster with a shield of lightning for 10 min. When a melee attack hits the caster,"
			.. " the attacker will be struck for 13 Nature damage. This expends one of the 3 charges on the shield.",
	},
	deDE = {
		shield = "Schützt das freundliche Ziel mit einem Schild, der 44 Schaden absorbiert. Hält 30 Sek. lang an.",
		big = "Schützt das freundliche Ziel mit einem Schild, der 1.234 Schaden absorbiert. Hält 30 Sek. lang an.",
		other = "Erfüllt das Ziel mit Macht und erhöht seine Ausdauer 30 Min. lang um 3.",
		charges = "Umgibt den Zaubernden 10 Min. lang mit einem Blitzschild. Trifft ein Nahkampfangriff den Zaubernden,"
			.. " erleidet der Angreifer 13 Naturschaden. Dabei wird eine der 3 Aufladungen des Schildes verbraucht.",
	},
	frFR = {
		shield = "Protège la cible alliée avec un bouclier qui absorbe 44 points de dégâts. Dure 30 s.",
		big = "Protège la cible alliée avec un bouclier qui absorbe 1\194\160234 points de dégâts. Dure 30 s.",
		other = "Augmente l'Endurance de la cible de 3 pendant 30 min.",
		charges = "Entoure le lanceur d'un bouclier de foudre pendant 10 min. Quand une attaque touche le lanceur,"
			.. " l'attaquant subit 13 points de dégâts de Nature. Consomme l'une des 3 charges du bouclier.",
	},
	ruRU = {
		shield = "Окружает дружественную цель щитом, поглощающим 44 ед. урона. Время действия – 30 сек.",
		big = "Окружает дружественную цель щитом, поглощающим 1 234 ед. урона. Время действия – 30 сек.",
		other = "Повышает выносливость цели на 3 ед. на 30 мин.",
		charges = "Окружает заклинателя щитом из молний на 10 мин. Атакующий получает 13 ед. урона от сил природы."
			.. " При этом расходуется один из 3 зарядов щита.",
	},
	esES = {
		shield = "Protege al objetivo amistoso con un escudo que absorbe 44 p. de daño. Dura 30 s.",
		big = "Protege al objetivo amistoso con un escudo que absorbe 1.234 p. de daño. Dura 30 s.",
		other = "Infunde poder al objetivo y aumenta su aguante 3 p. durante 30 min.",
		charges = "Rodea al taumaturgo con un escudo de relámpagos durante 10 min. El atacante sufre 13 p. de daño"
			.. " de Naturaleza. Consume una de las 3 cargas del escudo.",
	},
}

local Size, Charges = ns.CooldownRingDescriptionSize, ns.CooldownRingDescriptionCharges
local n = 0
local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "cdmring-locale",
	fixed = { client = client },
	dims = {
		{ "locale", { "enUS", "deDE", "frFR", "ruRU", "esES" } },
		{ "text", { "shield", "big", "other", "charges" } },
	},
	cell = function(c)
		n = n + 1
		local id = 7000 + n
		locale = c.locale
		desc[id] = TEXTS[c.locale][c.text]
		local size, charges = Size(id), Charges(id)
		return ("size=%s charges=%s"):format(tostring(size or "none"), tostring(charges or "none"))
	end,
	pins = {
		{ "text=shield", "size=44 charges=none" },
		{ "text=big", "size=1234 charges=none" },
		{ "text=other", "size=none charges=none" },
		{ "text=charges", "size=none charges=3" },
	},
})
