-- /cine debug keybindswitch: the Keybinds page's tabs show no On switch past
-- their first row's "?" (it sat right of Toggle CineMode, 2026-11-22: each
-- tab's switch took the row's "?" for a page title's). Nothing to do: it
-- opens Keybinds, each tab in turn, and says DONE. Steps:
--   1 tabs   each tab picked: no tab switch made or shown on it, its tab
--            still a container (its tabOn key saved), a shot a tab (PASS/FAIL)
-- Into CinematicDB.keybindSwitchTestLog. Dev copy only.
local _, ns = ...

-- Every switch toggle under frame (a header switch: .knob and .key).
local function Switches(frame, found)
	found = found or {}
	for _, child in ipairs({ frame:GetChildren() }) do
		if child.knob and type(child.key) == "string" then found[#found + 1] = child end
		Switches(child, found)
	end
	return found
end

ns.TestKit.Define({
	name = "keybindswitch",
	key = "keybindSwitchTest",
	title = "Keybinds tabs: no stray On switch",
	about = "each Keybinds tab opened: no On switch past its first row, nothing to do",
	steps = {
		{ key = "tabs", title = "each Keybinds tab opened", run = function(r)
			if not ns.OpenOptions then return r:Fail("no ns.OpenOptions") end
			pcall(ns.OpenOptions, "Keybinds")
			r:Sleep(1)
			local sections = ns.keybindSections
			if not (sections and sections[1]) then return r:Fail("Keybinds' tabs weren't made (ns.keybindSections)") end
			for _, section in ipairs(sections) do
				section.body.openSection()
				r:Sleep(0.6)
				local shown, made = 0, 0
				for _, toggle in ipairs(Switches(section.body)) do
					made = made + 1
					if toggle:IsVisible() then shown = shown + 1 end
				end
				local key = ("tabOn:Keybinds:%d"):format(section.index)
				r:Verdict(section.body:IsVisible() and made == 0,
					("%s: shown %s, switches on it %d made, %d shown (0 wanted)"):format(section.tab,
					tostring(section.body:IsVisible()), made, shown))
				r:Verdict(ns.db[key] ~= nil, ("%s: still a container, %s = %s"):format(section.tab, key, tostring(ns.db[key])))
				r:Shot(section.tab .. " tab", { behind = SettingsPanel })
			end
			if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
		end },
	},
})
