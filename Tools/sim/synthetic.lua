-- Made-up scenarios for testing the replay bench itself (Tools/sim/bench.lua),
-- until real recordings exist (Tools/sim-plan.md part 1). Each says
-- synthetic = true, and the bench's report says its numbers aren't findings.
--   local Synthetic = dofile("Tools/sim/synthetic.lua")
--   local scenario = Synthetic.city({ length = 30, plates = 20, chat = 2 })
local Synthetic = {}

local function Header(name, length)
	return { name = name, length = length, synthetic = true }
end

-- Standing still, nothing happening.
function Synthetic.idle(opts)
	opts = opts or {}
	return { header = Header("idle (synthetic)", opts.length or 20), stream = {} }
end

-- A city: plates coming and going around you, chat lines.
function Synthetic.city(opts)
	opts = opts or {}
	local length, plates, chat = opts.length or 30, opts.plates or 20, opts.chat or 2
	local stream = {}
	local rng = 7
	local function Random()
		rng = (rng * 1103515245 + 12345) % 2147483648
		return rng / 2147483648
	end
	for i = 1, plates do
		local unit = "nameplate" .. i
		local t = (i - 1) * 0.05
		stream[#stream + 1] = { t, "s", unit, "guid", "Creature-" .. i }
		stream[#stream + 1] = { t, "s", unit, "name", "Unit" .. i }
		stream[#stream + 1] = { t, "s", unit, "reaction", (i % 3 == 0) and 2 or 5 }
		stream[#stream + 1] = { t, "s", unit, "isplayer", i % 2 == 0 }
		stream[#stream + 1] = { t + 0.001, "e", "NAME_PLATE_UNIT_ADDED", unit }
	end
	-- Plates leaving and coming back (people walking by).
	local t = 2
	while t < length do
		local unit = "nameplate" .. (1 + math.floor(Random() * plates))
		stream[#stream + 1] = { t, "e", "NAME_PLATE_UNIT_REMOVED", unit }
		stream[#stream + 1] = { t + 0.5 + Random(), "e", "NAME_PLATE_UNIT_ADDED", unit }
		t = t + 0.4 + Random() * 0.4
	end
	local step = chat > 0 and 1 / chat or length + 1
	t = 0.3
	while t < length do
		stream[#stream + 1] = { t, "e", "CHAT_MSG_CHANNEL", "xxxx xxxxx", "Player" .. math.floor(t * 7) % 40,
			"", "2. Trade", "", "", 0, 2, "Trade", 0, 0, "", 0 }
		t = t + step
	end
	return { header = Header("city (synthetic)", length), stream = stream }
end

-- A fight with one mob: in at 2 s, its health falling (secret on clients
-- with secret values, as rule forever.unithealth.group-secret's kind),
-- auras, out at the end.
function Synthetic.fight(opts)
	opts = opts or {}
	local length = opts.length or 20
	local stream = {
		{ 0, "s", "target", "exists", true }, { 0, "s", "target", "guid", "Creature-99" },
		{ 0, "s", "target", "name", "Mob" }, { 0, "s", "target", "reaction", 2 },
		{ 0.1, "e", "PLAYER_TARGET_CHANGED" },
		{ 2, "s", "player", "combat", true }, { 2, "s", "target", "combat", true },
		{ 2, "e", "PLAYER_REGEN_DISABLED" },
	}
	local t = 2.2
	while t < length - 2 do
		stream[#stream + 1] = { t, "s", "target", "hp", opts.plainHealth and math.floor(100 - t * 4) or "?" }
		stream[#stream + 1] = { t, "e", "UNIT_HEALTH", "target" }
		stream[#stream + 1] = { t + 0.05, "e", "UNIT_AURA", "target" }
		stream[#stream + 1] = { t + 0.1, "e", "UNIT_POWER_UPDATE", "player", "MANA" }
		t = t + 0.25
	end
	stream[#stream + 1] = { length - 2, "s", "player", "combat", false }
	stream[#stream + 1] = { length - 2, "s", "target", "dead", true }
	stream[#stream + 1] = { length - 2, "e", "PLAYER_REGEN_ENABLED" }
	return { header = Header("fight (synthetic)", length), stream = stream }
end

return Synthetic
