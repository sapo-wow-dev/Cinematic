-- BattleText Forever's ready recipe (Support/BattleTextForever.lua): no test
-- of its own yet. Its four text areas (BattleTextForeverIncoming, Outgoing,
-- Healing, Notifications) are made at login and stay shown; only their lines
-- come and go, as you hit, get hit, heal or loot
-- (Tools/addon-kit/addons/BattleTextForever.md). Dev copy only.
local _, ns = ...

local function BT()
	local bt = rawget(_G, "BattleTextForever")
	return type(bt) == "table" and bt or nil
end

-- Ready: its areas made and the addon on (its live settings: the shared ones
-- or this character's own). Turned off, the recipe turns it on as /btf on
-- does, shows its sample lines (as /btf test does) so every area has text
-- for a moment, and turns it off again after.
ns.TestKit.DefineAddonReady("BattleTextForever", {
	about = "turned on, its four text areas made (lines show as you hit, get hit, heal or loot)",
	ready = function()
		local bt = BT()
		if not (bt and bt.built and type(bt.db) == "table") then return false, "it hasn't set up yet (after login)" end
		if not rawget(_G, "BattleTextForeverIncoming") then return false, "its text areas aren't made" end
		return bt.db.enabled ~= false, "it's turned off (/btf off)"
	end,
	make = function(r)
		local bt = BT()
		if not (bt and type(bt.db) == "table") then return end
		if bt.db.enabled == false then
			r:Keep("battleTextForeverWasOff", true)
			bt.db.enabled = true
			if type(bt.ApplySettings) == "function" then pcall(bt.ApplySettings, bt) end
			r:Log("turned BattleText Forever on (as /btf on does)")
		end
		if type(bt.Test) == "function" and pcall(bt.Test, bt) then
			r:Log("BattleText Forever's sample lines on (as /btf test does)")
		end
	end,
	putBack = function(extra)
		local bt = BT()
		if extra.battleTextForeverWasOff and bt and type(bt.db) == "table" then
			bt.db.enabled = false
			if type(bt.ApplySettings) == "function" then pcall(bt.ApplySettings, bt) end
			return "BattleText Forever turned off again"
		end
	end,
})
