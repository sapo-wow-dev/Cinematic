-- The addon kit's probes (Dev/AddonKit.lua): each reads how one of our
-- features behaves on the game frame it uses. Dev copy only. One area per
-- block; step 4 of Tools/addon-kit-plan.md fills the rest in.
local _, ns = ...
local Probe = ns.AddonKit.Probe

-- Every page switch above a setting on, for the probe's run (the switch tree:
-- a page off turns all of it off).
local function SwitchesOn(r, switch)
	while switch do
		r:With(switch, true)
		switch = ns.PageSwitchOf(switch)
	end
end

local function Call(object, method, ...)
	if type(object) ~= "table" then return nil end
	local fn = object[method]
	if type(fn) ~= "function" then return nil end
	local ok, a = pcall(fn, object, ...)
	if not ok then return "error" end
	return a
end
local function Round(value)
	if type(value) ~= "number" or (issecretvalue and issecretvalue(value)) then return value end
	return math.floor(value * 100 + 0.5) / 100
end
local function Family(name) return (name:gsub("%d+", "#")) end

-- Generated probes ------------------------------------------------------------
-- Made from the code's own lists when the probes run, so a row, link part,
-- hook or conflict added later is probed with nothing written here (part G).

-- Every game frame a Standard Frames row fades (ns.COMBAT_SHOW): there, up,
-- seen, its alpha with CineMode off, its parent, refusing addon code. An
-- addon that hides, replaces or reparents one shows here, and its Support
-- file says so (ns.AddonKitExpect(addon, "frame.<row>", "<Frame>.shown", ...),
-- or "frame.*" for a whole UI).
local function FrameProbes()
	local done = {}
	for _, item in ipairs(ns.COMBAT_SHOW or {}) do
		local names = {}
		for _, name in ipairs(item.frames or {}) do
			if type(name) == "string" and not name:find("^Cinematic") then names[#names + 1] = name end
		end
		if item.key and #names > 0 and not done[item.key] then
			done[item.key] = true
			local touches, seen = {}, {}
			for _, name in ipairs(names) do
				local family = Family(name)
				if not seen[family] then seen[family] = true touches[#touches + 1] = family end
			end
			Probe({
				id = "frame." .. item.key:gsub("[^%w_]", "_"), v = 1, generated = true, touches = touches,
				about = "the game frames the " .. item.key .. " row fades: there, up, seen, alpha, parent",
				run = function(r)
					for _, name in ipairs(names) do
						local frame = _G[name]
						local exists = type(frame) == "table" and Call(frame, "GetObjectType") ~= nil
						r:Set(name .. ".exists", exists)
						if exists then
							r:Set(name .. ".shown", Call(frame, "IsShown"))
							r:Set(name .. ".visible", Call(frame, "IsVisible"))
							r:Set(name .. ".alpha", Round(Call(frame, "GetAlpha")))
							r:Set(name .. ".forbidden", Call(frame, "IsForbidden"))
							local parent = Call(frame, "GetParent")
							r:Set(name .. ".parent", type(parent) == "table" and (Call(parent, "GetName") or "unnamed") or "none")
						end
					end
				end,
			})
		end
	end
end

-- Each frame link part (UI/FrameLinks.lua): whose frame it uses and why.
local function LinkProbes()
	for _, group in ipairs(ns.LINK_GROUPS or {}) do
		for _, part in ipairs(group.parts or {}) do
			Probe({
				id = "link." .. part.key, v = 1, generated = true, touches = {},
				about = "frame link " .. part.key .. ": the game's own frame, or which addon's",
				run = function(r)
					local who, why = ns.LinkResolve(part.key)
					r:Set("owner", who or "game")
					r:Set("why", why or "none")
				end,
			})
		end
	end
end

-- Each game function and method our code hooks (Dev/AddonKitTouches.lua, made
-- by touchpoints.py --update): still the one we hooked, as at login. An addon
-- that puts its own in its place after our hook silently drops our hook.
local hookSnapshot
local function HookTarget(hook)
	local target = _G[hook.target]
	if hook.method then
		if type(target) ~= "table" then return nil end
		return target[hook.method]
	end
	return target
end
local function HookProbes()
	for _, hook in ipairs(ns.AddonKit.HOOKS or {}) do
		local id = "hook." .. (hook.target .. (hook.method and ("." .. hook.method) or "")):gsub("[^%w_.]", "_")
		if not ns.AddonKit.byId[id] then
			Probe({
				id = id, v = 1, generated = true, touches = { hook.point },
				about = "our hook on " .. hook.target .. (hook.method and (":" .. hook.method) or "") .. " still in place",
				run = function(r)
					local now = HookTarget(hook)
					local was = hookSnapshot and hookSnapshot[hook]
					r:Set("state", now == nil and "gone" or (was == nil and "new") or (now == was and "same") or "replaced")
				end,
			})
		end
	end
end
-- Every touch point (Dev/AddonKitTouches.lua): a frame's state, or a function
-- or table still the same one as at login. A family (ChatFrame#) on its
-- members 1-20: how many there are, and the first one's state.
local touchSnapshot = {}
local function Member(point, i) return _G[(point:gsub("#", tostring(i)))] end
local function TouchProbes()
	for _, point in ipairs(ns.AddonKit.TOUCHES or {}) do
		Probe({
			id = "touch." .. point:gsub("[^%w_]", "_"), v = 1, generated = true, touches = { point },
			about = "touch point " .. point .. ": the frame's state, or the global the same as at login",
			run = function(r)
				local family = point:find("#") ~= nil
				local first = family and Member(point, 1) or _G[point]
				if family then
					local n = 0
					for i = 1, 20 do if Member(point, i) ~= nil then n = n + 1 end end
					r:Set("members", n)
				end
				local kind = type(first)
				local isFrame = kind == "table" and Call(first, "GetObjectType") ~= nil
				r:Set("kind", isFrame and "frame" or kind)
				if isFrame then
					r:Set("shown", Call(first, "IsShown"))
					r:Set("visible", Call(first, "IsVisible"))
					r:Set("alpha", Round(Call(first, "GetAlpha")))
					r:Set("forbidden", Call(first, "IsForbidden"))
					local parent = Call(first, "GetParent")
					r:Set("parent", type(parent) == "table" and (Call(parent, "GetName") or "unnamed") or "none")
				end
				if not isFrame and first ~= nil then
					local was = touchSnapshot[point]
					r:Set("sameAsLogin", was == nil and "new" or (was == first and "same") or "replaced")
				end
			end,
		})
	end
end
local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function()
	hookSnapshot = {}
	for _, hook in ipairs(ns.AddonKit.HOOKS or {}) do hookSnapshot[hook] = HookTarget(hook) end
	for _, point in ipairs(ns.AddonKit.TOUCHES or {}) do
		local first = point:find("#") and Member(point, 1) or _G[point]
		if first ~= nil then touchSnapshot[point] = first end
	end
end)

-- The addons' own rows: each Addon Conflicts row (theirs on, the pick) and
-- each feature that stands aside for an addon. Owned: rows the baseline
-- lacks are the addon's own, not differences.
Probe({
	id = "addons.conflicts", v = 1, owned = true, touches = { "UIParent" },
	about = "every Addon Conflicts row: is theirs on, and what's picked",
	run = function(r)
		for _, row in ipairs(ns.CONFLICTS or {}) do
			r:Set(row.id:gsub("[^%w_.:]", "_") .. ".theirs", ns.ConflictTheirsOn(row))
			r:Set(row.id:gsub("[^%w_.:]", "_") .. ".pick", (ns.ConflictPick(row)))
		end
	end,
})
Probe({
	id = "addons.yields", v = 1, owned = true, touches = { "UIParent" },
	about = "every feature that can stand aside for an addon: does it now, and for whom",
	run = function(r)
		local features = {}
		for feature in pairs(ns.FEATURE_YIELDS or {}) do features[#features + 1] = feature end
		table.sort(features)
		for _, feature in ipairs(features) do
			r:Set(feature:gsub("[^%w_.:]", "_"), ns.FeatureYieldedTo(feature) or "ours")
		end
	end,
})

-- (Made once everything has loaded: rows, parts and hooks are all known then.)
function ns.AddonKit.MakeGenerated()
	if ns.AddonKit.generatedMade then return end
	ns.AddonKit.generatedMade = true
	FrameProbes()
	LinkProbes()
	HookProbes()
	TouchProbes()
end

-- Chat ------------------------------------------------------------------------

-- Show just those messages: our copy of a new line, drawn where the game's
-- chat window sits. With another addon's chat window over it the copy lands
-- under theirs, two lines a message (DaylightUI, 2979131; EllesmereUI,
-- 0bd9803): with any chat addon, a message brings up its window instead.
Probe({
	id = "chat.linesOnly", v = 1,
	touches = { "ChatFrame#" }, settings = { "chatPeekLinesOnly" },
	about = "Show just those messages: copies drawn (game's chat) or the window brought up (another chat addon)",
	run = function(r)
		SwitchesOn(r, "handleChat")
		r:With("chatPeekLinesOnly", true)
		r:Set("chatIsDefault", ns.ChatIsDefault())
		r:Set("linesOnly", ns.ChatPeekLinesOnly())
		r:With("chatPeekLinesOnly", false)
		r:Set("linesOnlyWhenOff", ns.ChatPeekLinesOnly())
	end,
})
