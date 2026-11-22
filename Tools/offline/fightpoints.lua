-- Fight points test (dev tool, offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/fightpoints.lua < /dev/null
-- GitHub issue #7 (WoW Forever, EllesmereUI 9.9.1): in a fight another
-- addon's frame can give a secret anchor count (Support/EllesmereUI.lua:704,
-- "'for' limit must be a number", every scan tick, so the safety check
-- stopped Cinematic for the session), or say it isn't forbidden and still
-- refuse our code (FadeDetached.lua:155, "calling '?' on bad self" on
-- GetParent). On the stand-in game with such frames: ns.NumPoints gives 0 for
-- them, the EllesmereUI chat scan and the fade walk run with no error, and the
-- chat part anchored plainly is still found. ns.Reachable (Checks.lua): a
-- forbidden frame or a secret answer is out; in a fight a refusing frame is
-- out, probed once per fight, asked afresh in the next; out of a fight no
-- probe. Says PASS or FAIL per check.
local fight = false
local probes = 0
local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
local function Refuse()
	error("Attempt to access forbidden object from code tainted by an AddOn")
end

-- luacheck: push ignore 111 112 113 121 122 212
local ns, wow = dofile("Tools/offline/load.lua")("forever", arg and arg[1], function()
	issecretvalue = function(value) return value == SECRET end
	InCombatLockdown = function() return fight end
end)
-- luacheck: pop

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

-- ns.NumPoints on its own.
local plain = CreateFrame("Frame", nil, UIParent)
plain.GetNumPoints = function() return 2 end
local secret = CreateFrame("Frame", nil, UIParent)
secret.GetNumPoints = function() return SECRET end
local refusing = CreateFrame("Frame", nil, UIParent)
refusing.GetNumPoints = Refuse
Check("ns.NumPoints is there", type(ns.NumPoints) == "function")
if type(ns.NumPoints) == "function" then
	Check("NumPoints reads a plain count", ns.NumPoints(plain) == 2, ns.NumPoints(plain))
	Check("NumPoints gives 0 for a secret count", ns.NumPoints(secret) == 0)
	Check("NumPoints gives 0 for a refusal", ns.NumPoints(refusing) == 0)
	Check("NumPoints gives 0 for no frame", ns.NumPoints(nil) == 0)
end
secret:SetParent(nil)
refusing:SetParent(nil)
plain:SetParent(nil)

-- EllesmereUI's chat: its panel for ChatFrame1, a tab strip anchored to the
-- panel, and two unnamed UIParent children as in a fight (one with a secret
-- anchor count, one refusing GetName).
local panel = CreateFrame("Frame", nil, UIParent)
_G.EllesmereUI = _G.EllesmereUI or {}
_G.EllesmereUI._chatCFD = function(chatFrame)
	if chatFrame == _G.ChatFrame1 then return { bg = panel } end
end
if not _G.ChatFrame1 then CreateFrame("Frame", "ChatFrame1", UIParent) end
local strip = CreateFrame("Frame", nil, UIParent)
-- (The stand-in's SetAlpha and IsForbidden are callable stubs, not functions: the scan wants real ones.)
for _, part in ipairs({ panel, strip }) do
	part.SetAlpha = function(self, a) self._alpha = a end
	part.IsForbidden = function() return false end
end
strip.GetNumPoints = function() return 1 end
strip.GetPoint = function() return "BOTTOM", panel, "TOP", 0, 0 end
local secretKid = CreateFrame("Frame", nil, UIParent)
secretKid.GetNumPoints = function() return SECRET end
secretKid.SetAlpha = function() end
secretKid.IsForbidden = function() return false end
local refuseKid = CreateFrame("Frame", nil, UIParent)
-- (Not forbidden, yet every read refuses: how a restricted object acts.)
refuseKid.IsForbidden = function() return false end
refuseKid.SetAlpha = function() end
for _, method in ipairs({ "GetName", "GetParent", "GetNumPoints", "GetPoint", "IsShown", "IsVisible",
	"GetRegions", "GetChildren", "GetAlpha", "GetObjectType", "GetDebugName" }) do
	refuseKid[method] = Refuse
end

-- (What the scan finds, whether or not the stand-in's Chat page then fades it.)
local found = {}
local addFound = ns.AddFoundFrame
ns.AddFoundFrame = function(frame, ...)
	found[frame] = true
	return addFound(frame, ...)
end
local anchorReads = 0
local secretCount = secretKid.GetNumPoints
secretKid.GetNumPoints = function(...) anchorReads = anchorReads + 1 return secretCount(...) end
wow.Fire("ADDON_LOADED", "EllesmereUIChat")
fight = true -- (the refusals come in fights)
wow.Fire("PLAYER_REGEN_DISABLED")
local scanned, err = xpcall(ns.BuildManagedList, debug.traceback)
Check("the chat scan runs with a secret and a refusing frame", scanned, err)
Check("the scan read the secret frame's anchors", anchorReads > 0, anchorReads)
Check("the chat panel is still found", found[panel])
Check("the tab strip anchored to it is still found", found[strip])
Check("the secret frame is left out", not found[secretKid])
Check("the refusing frame is left out", not found[refuseKid])

-- The fade walk: a faded root with a part that says it isn't forbidden and
-- refuses GetParent, and a plain part under it.
local root = CreateFrame("Frame", nil, UIParent)
root._alpha = 1
root.SetAlpha = function(self, a) self._alpha = a end
root.GetEffectiveAlpha = function(self) return self._alpha end
root.IsIgnoringParentAlpha = function() return false end
root.IsForbidden = function() return false end
local bad = CreateFrame("Frame", nil, root)
bad.IsForbidden = function() return false end
bad.SetAlpha = function() end
bad.IsIgnoringParentAlpha = function() return true end
bad.GetParent = Refuse
local inner = CreateFrame("Frame", nil, bad)
inner.IsIgnoringParentAlpha = function() return true end
inner.IsForbidden = function() return false end
inner.SetAlpha = function() end
root:SetAlpha(0)
local walked, walkErr = xpcall(function() ns.SyncDetached(root) end, debug.traceback)
Check("the fade walk runs over a part that refuses our code", walked, walkErr)

-- ns.Reachable on its own.
local function Widget(forbidden)
	local frame = CreateFrame("Frame", nil, UIParent)
	frame.IsForbidden = function() return forbidden end
	return frame
end
Check("ns.Reachable is there", type(ns.Reachable) == "function")
if type(ns.Reachable) == "function" then
	fight = false
	wow.Fire("PLAYER_REGEN_ENABLED")
	Check("a plain frame is reachable", ns.Reachable(Widget(false)))
	Check("a forbidden frame isn't", not ns.Reachable(Widget(true)))
	Check("a secret IsForbidden answer counts as forbidden", not ns.Reachable(Widget(SECRET)))
	Check("not a table isn't", not ns.Reachable(nil) and not ns.Reachable("x"))
	local shy = Widget(false)
	local refusing = false
	shy.GetParent = function(self)
		probes = probes + 1
		if refusing then Refuse() end
		return UIParent
	end
	refusing = true
	Check("out of a fight: no probe", ns.Reachable(shy) and probes == 0, probes)
	fight = true
	wow.Fire("PLAYER_REGEN_DISABLED")
	Check("in a fight: a refusing frame isn't reachable", not ns.Reachable(shy))
	Check("probed once, then remembered", not ns.Reachable(shy) and probes == 1, probes)
	refusing = false
	fight = false
	wow.Fire("PLAYER_REGEN_ENABLED")
	fight = true
	wow.Fire("PLAYER_REGEN_DISABLED")
	Check("the next fight asks afresh", ns.Reachable(shy) and probes == 2, probes)
end

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
