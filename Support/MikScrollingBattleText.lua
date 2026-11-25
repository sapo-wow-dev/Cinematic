-- MikScrollingBattleText Forever: it draws your incoming damage, heals and
-- notices in its own scroll areas and hides the game's floating combat text
-- (its kinds switched off one by one, the CombatText frame hidden).
-- Text on You (Style/SelfTextStyle.lua) copies the game's text, so with both
-- on: the Addon Conflicts row. Theirs (the default): Text on You stands
-- aside. Ours or Both: Text on You draws too; MSBT draws all its text on one
-- frame (incoming and outgoing), so nothing of it is hidden: turn its
-- incoming off in its own options. Read from MSBT Forever 2.0.8 (2026-11-21):
-- MikSBT.IsModDisabled(), its text on MSBTAnimationFrame.

local _, ns = ...

-- (The addon kit, Tools/addon-kit: with it loaded, the game's CombatText frame
-- is hidden, as above. Our feature on it, Shoulder Cam's Follow floating
-- combat text, has nothing to move then: MSBT's own text isn't the game's.)
ns.AddonKitExpect("MikScrollingBattleText_Forever", "touch.CombatText", "*",
	"hidden: MSBT turns the game's floating combat text off and draws its own (run q57a1, 2026-11-25)")

ns.WhenAddonLoads("MikScrollingBattleText_Forever", function()
	ns.AddConflict({ key = "style:selftext", addon = "MikScrollingBattleText", label = "Combat text on you",
		group = "style", styleSwitch = "selfTextStyle",
		about = "Your combat text: the Style hub's Text on You page, or MSBT's Incoming area (turn that off in MSBT for Ours)",
		theirs = function()
			local msbt = _G.MikSBT
			local disabled = type(msbt) == "table" and type(msbt.IsModDisabled) == "function" and msbt.IsModDisabled()
			return not disabled
		end,
		ours = function() return ns.StyleOn("selfTextStyle") end,
		onPick = function() if ns.RefreshSelfTextStyle then ns.RefreshSelfTextStyle() end end })
end)
