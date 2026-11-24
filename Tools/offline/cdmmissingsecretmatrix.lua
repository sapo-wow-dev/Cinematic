-- The Cooldown Manager's Missing reminder with the icon's cooldown ID plain or
-- secret, in a fight or not, the buff off or on you (UI/CooldownMissing.lua:
-- NamesOf, IconFor, Wanted, Bring, Visit), the audit kit's matrix
-- (Tools/offline/matrix.lua; fix card Tools/audits/2026-11-23-cdm-secret-compares.md):
--   python -I Tools/offline/run.py Tools/offline/cdmmissingsecretmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/cdmmissingsecretmatrix.lua --base <ref>
-- A tracked buff set to Missing, Hide When Inactive on; the game's SetShown
-- (its UpdateShownState) runs twice, then a pass. A secret cooldown ID is a
-- new stand-in secret on every read (comparing two errors, as in the game).
-- Each cell: whether the icon shows, whether we showed it, Shows refused.
-- The rule (release review 2026-11-23): a secret cooldown ID never errors and
-- counts as an icon in use; Show() in a fight on Forever (proven, rule
-- forever.cooldownviewer.show-hidden-buff-icon), refused on retail (not tested
-- there, ledger Tools/tests/cdm-missing-buff.md Q9).
local client = arg and arg[1] or "forever"
local fighting = false
-- luacheck: push ignore 111 112 113 121 122 212
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
	InCombatLockdown = function() return fighting end
end)
-- (A real post-hook after load, as Tools/offline/cdmmissing.lua has it.)
hooksecurefunc = function(a, b, c)
	local tbl, name, fn = a, b, c
	if type(a) == "string" then tbl, name, fn = _G, a, b end
	local orig = tbl[name]
	if type(orig) ~= "function" then return end
	tbl[name] = function(...)
		local r = { orig(...) }
		fn(...)
		return unpack(r)
	end
end
UnitAffectingCombat = function() return fighting end
C_Spell = C_Spell or {}
C_Spell.GetSpellName = function(id) return id == 687 and "Demon Skin" or nil end
local SECRET = { __eq = function() error("attempt to compare a secret value") end }
issecretvalue = function(v) return type(v) == "table" and getmetatable(v) == SECRET end
-- luacheck: pop

local db = ns.db
for _, start in ipairs({ "handleCooldowns", ns.CDM_TABS.buffs }) do
	local switch = start
	while switch do
		db[switch] = true
		switch = ns.PageSwitchOf(switch)
	end
end

local SKIN = 687
local icons = {}
ns.EachCooldownIcon = function(visit)
	for _, icon in ipairs(icons) do visit(icon, SKIN, "BuffIconCooldownViewer") end
end
ns.CooldownIconSpellOf = function() return SKIN end
local function Icon(secret, active)
	local icon = { shown = false, hideWhenInactive = true, auraInstanceID = active and 5 or nil, shows = 0 }
	if secret then
		setmetatable(icon, { __index = function(_, k)
			if k == "cooldownID" then return setmetatable({}, SECRET) end
		end })
	else
		icon.cooldownID = SKIN
	end
	function icon:IsShown() return self.shown end
	function icon:Show() self.shown = true self.shows = self.shows + 1 end
	function icon:Hide() self.shown = false end
	function icon:SetShown(shown) self.shown = shown and true or false end
	function icon:IsProtected() return false end
	function icon:IsForbidden() return false end
	return icon
end
-- (The game's UpdateShownState: shown while in use and its buff on, Hide When Inactive on.)
local function GameUpdate(icon)
	icon:SetShown(type(icon.cooldownID) ~= "nil" and icon.auraInstanceID ~= nil)
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "cdmmissing-secret-" .. client, -- (per client: the card's rows differ by client)
	fixed = { client = client },
	dims = {
		{ "id", { "plain", "secret" } },
		{ "fight", { "no", "yes" } },
		{ "buff", { "off", "on" } },
	},
	cell = function(c)
		db.cooldownBuffMode = { [SKIN] = "missing" }
		fighting = false
		local icon = Icon(c.id == "secret", c.buff == "on")
		icons = { icon }
		-- (Seen once out of a fight first, as the pass walks it.)
		local ok, err = pcall(ns.CooldownMissingPass)
		fighting = c.fight == "yes"
		local refused = ns.cooldownMissingStats.refused
		if ok then ok, err = pcall(GameUpdate, icon) end
		if ok then ok, err = pcall(GameUpdate, icon) end
		if ok then ok, err = pcall(ns.CooldownMissingPass) end
		fighting = false
		if not ok then return "error" .. (tostring(err):find("secret") and " (secret compare)" or "") end
		return ("shown=%s ours=%s refused=%d"):format(tostring(icon.shown),
			tostring(ns.CooldownMissingShownHere(icon)), ns.cooldownMissingStats.refused - refused)
	end,
	pins = {
		-- (Off you: the reminder shows, ours.)
		{ "buff=off", "shown=true ours=true refused=0" },
		-- (On you: the game's own, not ours.)
		{ "buff=on", "shown=true ours=false refused=0" },
		-- (Retail in a fight: not tested there, so not shown; refused each time.
		-- Still marked ours from before the fight: the pass after it shows it again.)
		{ "client=retail fight=yes buff=off", "shown=false ours=true refused=3" },
	},
})
