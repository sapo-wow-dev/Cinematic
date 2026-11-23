-- A built-in profile's switches the update turned off in its base, every state
-- (the audit kit's matrix, Tools/offline/matrix.lua):
--   python -I Tools/offline/run.py Tools/offline/profilekeepmatrix.lua [forever|retail] [cooldowns|keysoff] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/profilekeepmatrix.lua forever cooldowns --base <ref>
-- v2.1.24 turned off Auto-Hide UI's Cooldown Manager page (handleCooldowns:
-- fix card Tools/audits/2026-11-22-profiles-autohide-cooldowns.md, bdb2e1d),
-- and Auto-Hide UI's and Blank Slate's wheels and Keyboard Map (keysoff:
-- Tools/audits/2026-11-23-profiles-keys-off.md, ae2cda8). A saved profile
-- holds only what differs from its base, so a copy saved on v2.1.23 held
-- nothing for them (they were on there): loaded again it got the new base's off.
-- The states: the profile (the two changed, two unchanged built-ins, one of
-- your own), whether the settings come from v2.1.23 (the update not run yet)
-- or were saved after it, the saved copy (none, nothing for the key, on, off),
-- its reset point (none, nothing for the key, off), and whether you're on that
-- profile at login. Each cell: the switch now, after switching to the profile,
-- and after Reset profile. The rule: what you had stays what you had; a fresh
-- pick (or a Reset with no reset point) gets the built-in's values as they are.

local client = arg and arg[1] or "forever"
local which = arg and arg[2] or "cooldowns"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db
ns.SwitchProfileLayout = function() end -- (the stand-in has no Edit Mode)
-- (What a switch refreshes after it loads: not what this reads, and most of
-- each cell's time.)
for _, name in ipairs({ "RefreshOptions", "BuildManagedList", "RestartTimers", "RefreshTint", "ApplyBubbles",
	"ApplyUnitFrameParts", "RefreshActionBarStyle", "RefreshMinimapStyle", "RefreshQuestTrackerStyle",
	"RefreshInterfaceRecolor", "ApplyShoulderCam", "ApplyWheelSwitches", "ApplyFrameLinks",
	-- (And in a load: other addons' rows and the backup a Reset keeps; neither touches these keys.)
	"SplitAddonRows", "BackupProfile" }) do
	if ns[name] then ns[name] = function() end end
end
db.profiles = db.profiles or {}
db.profileResetPoints = db.profileResetPoints or {}

-- (keysoff: one wheel and the Keyboard Map, each in every cell; the update
-- goes over its list key by key, the other six wheels as the Master wheel.)
local KEYS, FLAG = { "handleCooldowns" }, "autoHideCooldownsV1"
if which == "keysoff" then KEYS, FLAG = { "wheelMasterOn", "keyboardMap" }, "profileKeysOffV1" end
-- Each built-in's value on v2.1.23 (its base then: read from v2.1.23's code on
-- both clients) and what a profile of your own starts from (the defaults).
local OLD = {
	["Auto-Hide UI"] = { handleCooldowns = true, wheelMasterOn = true, keyboardMap = true },
	["Blank Slate"] = { handleCooldowns = false, wheelMasterOn = true, keyboardMap = true },
	Subtle = { handleCooldowns = false, wheelMasterOn = true, keyboardMap = true },
	Balanced = { handleCooldowns = true, wheelMasterOn = true, keyboardMap = true },
	Mine = { handleCooldowns = true, wheelMasterOn = true, keyboardMap = true },
}
-- (Cell keys are words without spaces: the profile's name from its id.)
local NAMES = { AutoHideUI = "Auto-Hide UI", BlankSlate = "Blank Slate" }
local function NewBase(name, key)
	if name == "Mine" then return ns.DEFAULTS[key] end
	return ns.ProfileBase(name)[key]
end
local function Word(value) return value == true and "on" or value == false and "off" or tostring(value) end
-- A saved copy or reset point: none, nothing for the keys, or each on or off.
local function Stored(kind)
	if kind == "none" then return nil end
	local t = {}
	for _, key in ipairs(KEYS) do
		if kind == "on" then t[key] = true elseif kind == "off" then t[key] = false end
	end
	return t
end
-- What you had for a key: your saved change, else the base of the version
-- it was saved on (v2.1.23's, or today's for one saved after the update).
local function Had(c, kind, key)
	if kind == "on" then return true elseif kind == "off" then return false end
	local name = NAMES[c.profile] or c.profile
	if c.from == "v2.1.23" then return OLD[name][key] end
	return NewBase(name, key)
end

local Matrix = dofile("Tools/offline/matrix.lua")
local dims = {
	{ "profile", { "AutoHideUI", "BlankSlate", "Subtle", "Balanced", "Mine" } },
	{ "from", { "v2.1.23", "after" } },
	{ "saved", { "none", "blank", "on", "off" } },
	{ "point", { "none", "blank", "off" } },
	{ "live", { "it", "other" } },
}

-- What's right, per key: the value you had; never saved (a fresh pick) or a
-- Reset with no reset point: today's base.
local function Right(c)
	if c.profile == "Mine" and c.saved == "none" then return "no profile" end
	local out = {}
	for _, key in ipairs(KEYS) do
		local now, load = "-"
		-- (No "x and NewBase() or Had()": a base's off would fall through to Had.)
		if c.live == "it" then
			now = Had(c, c.saved, key)
			load = now
		elseif c.saved == "none" then
			load = NewBase(NAMES[c.profile] or c.profile, key)
		else
			load = Had(c, c.saved, key)
		end
		local reset
		if c.point == "none" then
			reset = NewBase(NAMES[c.profile] or c.profile, key)
		else
			reset = Had(c, c.point, key)
		end
		out[#out + 1] = ("%snow=%s load=%s reset=%s"):format(#KEYS > 1 and (key .. ":") or "", Word(now), Word(load),
			Word(reset))
	end
	return table.concat(out, " ")
end

local pins = {}
do
	-- (Every cell's own pin, worked out by Right.)
	local values = {}
	local function Walk(depth)
		if depth > #dims then
			local c, parts = { client = client }, {}
			for i, dim in ipairs(dims) do
				c[dim[1]] = values[i]
				parts[#parts + 1] = dim[1] .. "=" .. values[i]
			end
			pins[#pins + 1] = { table.concat(parts, " "), Right(c) }
			return
		end
		for _, value in ipairs(dims[depth][2]) do
			values[depth] = value
			Walk(depth + 1)
		end
	end
	Walk(1)
end

local function Read()
	local out = {}
	for _, key in ipairs(KEYS) do out[key] = Word(db[key]) end
	return out
end

Matrix.Run({
	name = "profilekeep-" .. which,
	fixed = { client = client },
	dims = dims,
	cell = function(c)
		local name = NAMES[c.profile] or c.profile
		local other = name == "Balanced" and "Cinema" or "Balanced"
		if name == "Mine" and c.saved == "none" then return "no profile" end
		-- (On another profile: as a switch leaves it, without loading it.)
		db.liveProfile, db.profile = other, other
		db.profiles[name] = Stored(c.saved)
		db.profileResetPoints[name] = Stored(c.point)
		local now
		if c.live == "it" then
			-- (On it at the last logout: the live switches are what you had then.)
			if not ns.SetProfile(name) then return "can't switch" end
			for _, key in ipairs(KEYS) do db[key] = Had(c, c.saved, key) end
			db.profiles[name] = Stored(c.saved)
		end
		db[FLAG] = c.from ~= "v2.1.23" or nil
		ns.RunMigrations()
		if c.live == "it" then
			now = Read()
			if not ns.SetProfile(other) then return "can't switch away" end
		end
		if not ns.SetProfile(name) then return "can't switch" end
		local load = Read()
		ns.ResetProfile()
		local reset = Read()
		local out = {}
		for _, key in ipairs(KEYS) do
			out[#out + 1] = ("%snow=%s load=%s reset=%s"):format(#KEYS > 1 and (key .. ":") or "",
				now and now[key] or "-", load[key], reset[key])
		end
		return table.concat(out, " ")
	end,
	pins = pins,
})
