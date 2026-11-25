-- The rule words the game announces by event (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix cards Tools/audits/2026-11-25-event-fact-*.md):
--   python -I Tools/offline/run.py Tools/offline/eventfactsmatrix.lua [forever|retail] [word] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/eventfactsmatrix.lua forever class --base <ref>
-- Frames.lua's ns.RuleFacts asked the game every word on each full working
-- out (every 0.1 s, 0.5 s idle), class and role too, which the game announces
-- by event (the 2026-11-25 audit). Each word here: a rule naming it, the
-- game's answer off or on, then nothing changed or the answer flipped with
-- the game's own event for it. Each cell: the word as a rule reads it after
-- the change (the next full working out), still right a while later, and
-- whether the game was asked again with nothing new (polled). Right: the
-- word always the game's answer, and not polled (asked again only after its
-- event). class has no event: it never changes in a session (flip = none).
-- word: one word's cells only (each fix card runs its own); none: all.

local client = arg and arg[1] or "forever"
local only = arg and arg[2]
local now = 100
-- (The game's answers, per word, and how often each was asked.)
local state, reads, counting = {}, {}, nil
local function Read(word)
	if counting == word then reads[word] = (reads[word] or 0) + 1 end
	return state[word]
end
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	GetTime = function() return now end
	InCombatLockdown = function() return false end
	UnitAffectingCombat = function() return false end
	UnitClass = function(unit)
		if unit ~= "player" then return nil end
		local warrior = Read("class")
		return warrior and "Warrior" or "Mage", warrior and "WARRIOR" or "MAGE", warrior and 1 or 8
	end
	GetSpecialization = function() Read("role") return 1 end
	GetSpecializationRole = function() return state.role and "TANK" or "DAMAGER" end
	UnitGroupRolesAssigned = function() return "NONE" end
	IsInGroup = function() return Read("group") or false end
	UnitIsPVP = function(unit) if unit == "player" then return Read("flagged") or false end return false end
	UnitIsPVPFreeForAll = function() return false end
	UnitIsAFK = function(unit) if unit == "player" then return Read("afk") or false end return false end
	IsResting = function() return Read("resting") or false end
	UnitIsDeadOrGhost = function(unit) if unit == "player" then return Read("dead") or false end return false end
	IsMounted = function() return Read("mounted") or false end
	UnitCastingInfo = function(unit) if unit == "player" and Read("casting") then return "Frostbolt" end end
	UnitChannelInfo = function() return nil end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
ns.OnTaxi = function() return false end

-- Each word: its rule word (the field read), and the game's event as the
-- answer turns on and off (unit events for the player, as the game sends them).
local WORDS = {
	{ "class", "warrior" },
	{ "role", "tank", on = { "PLAYER_SPECIALIZATION_CHANGED", "player" } },
	{ "group", "group", on = { "GROUP_ROSTER_UPDATE" } },
	{ "flagged", "flagged", on = { "UNIT_FLAGS", "player" } },
	{ "afk", "afk", on = { "PLAYER_FLAGS_CHANGED", "player" } },
	{ "resting", "resting", on = { "PLAYER_UPDATE_RESTING" } },
	{ "dead", "dead", on = { "PLAYER_DEAD" }, off = { "PLAYER_UNGHOST" } },
	{ "mounted", "mounted", on = { "PLAYER_MOUNT_DISPLAY_CHANGED" } },
	{ "casting", "casting", on = { "UNIT_SPELLCAST_START", "player" }, off = { "UNIT_SPELLCAST_STOP", "player" } },
}

local function Fire(event)
	if event then wow.Fire(event[1], event[2]) end
end
local function Facts()
	return ns.RuleFacts(false)
end
local function Word(field)
	return ((Facts()[field]) and "on" or "off")
end

local Matrix = dofile("Tools/offline/matrix.lua")
for _, w in ipairs(WORDS) do
	local word, field = w[1], w[2]
	if not only or only == word then
		Matrix.Run({
			name = "event-facts-" .. word,
			fixed = { client = client, word = word },
			dims = { { "start", { "off", "on" } }, { "change", { "none", "flip" } } },
			cell = function(c)
				for _, other in ipairs(WORDS) do state[other[1]] = false end
				-- (A rule naming it: the word read, ns.factsUsed.)
				assert(ns.CompileRule(field), "rule " .. field)
				-- The game's answer as the cell starts, its event as it came.
				state[word] = c.start == "on"
				Fire(w.on)
				if not state[word] then Fire(w.off or w.on) end
				wow.Fire("PLAYER_ENTERING_WORLD")
				now = now + 1
				Facts()
				-- Then nothing new, or the answer flipped with its event.
				if c.change == "flip" and w.on then
					state[word] = not state[word]
					if state[word] then Fire(w.on) else Fire(w.off or w.on) end
				end
				now = now + 0.6 -- (past the facts' hold, idle or not)
				local after = Word(field)
				-- A while later, nothing new: still right, and asked again or not.
				counting, reads[word] = word, 0
				for _ = 1, 3 do
					now = now + 1
					Facts()
				end
				counting = nil
				local later = Word(field)
				local want = state[word] and "on" or "off"
				return ("after=%s later=%s right=%s polled=%s"):format(after, later,
					tostring(after == want and later == want), reads[word] > 0 and "yes" or "no")
			end,
			pins = {
				-- (Right: the game's answer, asked again only after its event.)
				{ "start=off change=none", "after=off later=off right=true polled=no" },
				{ "start=on change=none", "after=on later=on right=true polled=no" },
				{ "start=off change=flip", "after=on later=on right=true polled=no" },
				{ "start=on change=flip", "after=off later=off right=true polled=no" },
				-- (class: no event, never changes in a session: flip is none.)
				{ "word=class start=off change=flip", "after=off later=off right=true polled=no" },
				{ "word=class start=on change=flip", "after=on later=on right=true polled=no" },
			},
		})
	end
end
