-- ElvUI's ready recipe: how a test sets ElvUI up itself so every frame
-- Support/ElvUI.lua covers can show (Tools/addon-kit/addons/ElvUI.md).
-- No test of its own yet: the addon kit and /cine debug addontest call
-- r:AddonReady("ElvUI") before they check its frames.
-- What it does: skips its install window the way its X button does, turns
-- on its parts that are off by default (action bars 2 and 6-10, 13-15 on
-- retail, the micro bar, the top panel, the reputation bar, the player plate
-- at its static spot), and puts each back as it was after the test. The
-- rest (a target, a fight, a pet, a group) the test itself or you make.
-- Dev copy only.
local _, ns = ...

local KEEP = "elvui:" -- (our keys in the run's undo, apart from other recipes')
local NIL = "<nil>"   -- (the test kit's saved stand-in for nil)

local function Elv()
	local engine = _G.ElvUI
	local E = type(engine) == "table" and engine[1]
	return type(E) == "table" and type(E.db) == "table" and type(E.private) == "table" and E or nil
end

-- A method of one of its modules, in a pcall: true when it ran.
local function Call(module, method, ...)
	if type(module) == "table" and type(module[method]) == "function" then
		return (pcall(module[method], module, ...))
	end
	return false
end

-- Its bars 13-15 stand in for retail's bars 6-8 only.
local BARS = { 2, 6, 7, 8, 9, 10 }
if ns.isRetail then
	for _, n in ipairs({ 13, 14, 15 }) do BARS[#BARS + 1] = n end
end

-- Its switches that are off by default: where each lives in its profile
-- (E.db), its field, and the call its own options make to apply it.
-- secure = only out of fights.
local SWITCHES = {}
for _, n in ipairs(BARS) do
	local bar = "bar" .. n
	SWITCHES[#SWITCHES + 1] = { key = bar, label = "action bar " .. n, secure = true, frame = "ElvUI_Bar" .. n,
		where = function(E) return E.db.actionbar and E.db.actionbar[bar] end, field = "enabled",
		apply = function(E) return Call(E.ActionBars, "PositionAndSizeBar", bar) end }
end
SWITCHES[#SWITCHES + 1] = { key = "microbar", label = "micro bar", secure = true,
	where = function(E) return E.db.actionbar and E.db.actionbar.microbar end, field = "enabled",
	apply = function(E) return Call(E.ActionBars, "UpdateMicroButtons") end }
SWITCHES[#SWITCHES + 1] = { key = "topPanel", label = "top panel", frame = "ElvUI_TopPanel",
	where = function(E) return E.db.general end, field = "topPanel",
	apply = function(E) return Call(E.Layout, "UpdateTopPanel") end }
SWITCHES[#SWITCHES + 1] = { key = "reputation", label = "reputation bar",
	where = function(E) return E.db.databars and E.db.databars.reputation end, field = "enable",
	apply = function(E)
		local ok = Call(E.DataBars, "ReputationBar_Toggle")
		Call(E.DataBars, "UpdateAll")
		return ok
	end }
SWITCHES[#SWITCHES + 1] = { key = "playerPlate", label = "player plate (static spot)", secure = true,
	where = function(E)
		local units = E.db.nameplates and E.db.nameplates.units
		return E.private.nameplates and E.private.nameplates.enable and units and units.PLAYER
	end, field = "useStaticPosition",
	apply = function(E) return Call(E.NamePlates, "ConfigureAll") end }

-- Its modules that hold the covered frames (E.private, per character; a
-- change needs a reload: that's your clicks).
local MODULES = { actionbar = "ActionBars", unitframe = "UnitFrames", nameplates = "Nameplates" }

local function InstallerOpen(E)
	return not E.private.install_complete
		or (type(E.InstallFrame) == "table" and ns.Flag(E.InstallFrame:IsShown()))
end

ns.TestKit.DefineAddonReady("ElvUI", {
	about = "its install window done, its action bars 2 and 6-10, micro bar and top panel on",
	ready = function()
		local E = Elv()
		if not E then return false, "ElvUI isn't set up yet (no ElvUI global with its settings)" end
		if InstallerOpen(E) then return false, "its install window is still open" end
		for part, label in pairs(MODULES) do
			if not (E.private[part] and E.private[part].enable) then
				return false, "its " .. label .. " are off (its options, then a reload)"
			end
		end
		for _, switch in ipairs(SWITCHES) do
			local t = switch.where(E)
			-- (The reputation bar and player plate also wait for a faction
			-- or a fight: on is enough. Its nameplates off: no player plate.)
			if t and t[switch.field] ~= true then return false, "its " .. switch.label .. " is off" end
			local frame = switch.frame and _G[switch.frame]
			if t and type(frame) == "table" and not ns.Flag(frame:IsShown()) then
				return false, "its " .. switch.label .. " is on but hidden"
			end
		end
		return true
	end,
	make = function(r)
		local E = Elv()
		if not E then return end
		if InstallerOpen(E) and type(E.SetupComplete) == "function" then
			local was = E.private.install_complete
			r:Keep(KEEP .. "install", was == nil and NIL or was)
			-- (What its X button does: saved done, the window hidden, no reload.)
			pcall(E.SetupComplete, E)
			if type(E.InstallFrame) == "table" then pcall(E.InstallFrame.Hide, E.InstallFrame) end
			r:Log("skipped ElvUI's install window (as its X button does)")
		end
		if InCombatLockdown() then
			r:WaitFor("Leave the fight: ElvUI's bars can't be turned on in one.",
				{ check = function() return not InCombatLockdown() end })
		end
		for _, switch in ipairs(SWITCHES) do
			local t = switch.where(E)
			if type(t) == "table" and t[switch.field] ~= true
				and not (switch.secure and InCombatLockdown()) then
				local was = t[switch.field]
				r:Keep(KEEP .. switch.key, was == nil and NIL or was)
				t[switch.field] = true
				local ok = switch.apply(E)
				r:Log(("turned on ElvUI's %s%s"):format(switch.label, ok and "" or " (its update call failed)"))
			end
		end
		r:Sleep(1)
	end,
	putBack = function(extra)
		local E = Elv()
		if not E then return "ElvUI not there: nothing put back" end
		local said, waiting = {}, {}
		for _, switch in ipairs(SWITCHES) do
			local was = extra[KEEP .. switch.key]
			local t = was ~= nil and switch.where(E)
			if type(t) == "table" then
				if switch.secure and InCombatLockdown() then
					waiting[#waiting + 1] = switch.label
				else
					if was == NIL then was = nil end
					t[switch.field] = was
					switch.apply(E)
					said[#said + 1] = switch.label
				end
			end
		end
		local install = extra[KEEP .. "install"]
		if install ~= nil then
			-- (Empty again: its install window comes back at the next login,
			-- as it would have.)
			if install == NIL then install = nil end
			E.private.install_complete = install
			said[#said + 1] = "install window flag"
		end
		local text = #said > 0 and ("ElvUI put back: " .. table.concat(said, ", ")) or "ElvUI: nothing to put back"
		if #waiting > 0 then text = text .. "; in a fight, left on: " .. table.concat(waiting, ", ") end
		return text
	end,
	guide = {
		"ElvUI Installation window still open? Click the X at its top right.",
		"Type /ec to open ElvUI's options.",
		"Click ActionBars on its left and tick Enable at the top, if it's unticked.",
		"Click UnitFrames on its left and tick Enable at the top, if it's unticked.",
		"Click Nameplates on its left and tick Enable at the top, if it's unticked.",
		"Close its options, then click Accept in its box \"One or more of the changes you have made require a ReloadUI.\"",
	},
})
