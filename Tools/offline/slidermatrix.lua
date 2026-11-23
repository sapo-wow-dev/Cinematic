-- A settings slider shown with what's saved, every state (the audit kit's
-- matrix, Tools/offline/matrix.lua; fix card Tools/audits/2026-11-22-settings-slider-no-value.md):
--   python -I Tools/offline/run.py Tools/offline/slidermatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/slidermatrix.lua --base <ref>
-- A page's slider (its Refresh, as the page runs it on open and after a
-- profile) with its setting saved as a number, a number in text, nothing (a
-- setting added since, a profile without it), other text or a tick (a broken
-- profile), its setting with a default or none. Each cell: what the slider
-- shows, "saved", "default", "least" (its lowest) or "error" (the page's
-- Refresh breaks). The rule: a number shows; anything else shows the default,
-- else the lowest; never an error.
-- (bdb2e1d audit 2026-11-22: no value saved errored, breaking the page.)

local client = arg and arg[1] or "forever"
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	local Create = CreateFrame
	CreateFrame = function(kind, ...)
		local frame = Create(kind, ...)
		if kind == "Slider" then
			rawset(frame, "SetMinMaxValues", function(self, low, high) self._low, self._high = low, high end)
		end
		return frame
	end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db

-- A slider whose setting has a number default, its shown values apart.
local slider, key, default
for _, each in ipairs(wow.frames) do
	local k = each._kind == "Slider" and type(rawget(each, "Refresh")) == "function" and rawget(each, "settingKey")
	if type(k) == "string" and type(ns.DEFAULTS[k]) == "number" and each._low then
		local saved = db[k]
		db[k] = ns.DEFAULTS[k]
		local ok = pcall(each.Refresh, each)
		local shown = each:GetValue()
		db[k] = saved
		if ok and shown ~= each._low then
			slider, key, default = each, k, ns.DEFAULTS[k]
			break
		end
	end
end
local other = default and default * 2 + 3 --(a saved number neither the default nor the lowest)
local function Shown(value)
	local saved = db[key]
	db[key] = value
	local ok = pcall(slider.Refresh, slider)
	local shown = slider:GetValue()
	db[key] = saved
	return ok and shown or nil
end
local refSaved, refDefault = slider and Shown(other), slider and Shown(default)

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "slider-refresh",
	fixed = { client = client },
	dims = {
		{ "saved", { "number", "numberText", "nothing", "text", "tick" } },
		{ "default", { "has", "none" } },
	},
	cell = function(c)
		if not slider then return "no slider" end
		local value = ({ number = other, numberText = tostring(other), text = "abc", tick = true })[c.saved]
		local keep, saved = ns.DEFAULTS[key], db[key]
		if c.default == "none" then ns.DEFAULTS[key] = nil end
		db[key] = value
		slider:SetValue(-12345)
		local ok = pcall(slider.Refresh, slider)
		local shown = slider:GetValue()
		ns.DEFAULTS[key], db[key] = keep, saved
		if not ok then return "error" end
		if shown == refSaved then return "saved" end
		if shown == refDefault then return "default" end
		if shown == slider._low then return "least" end
		return "other " .. tostring(shown)
	end,
	pins = {
		{ "default=has", "default" },
		{ "default=none", "least" },
		{ "saved=number", "saved" },
		{ "saved=numberText", "saved" },
	},
})
