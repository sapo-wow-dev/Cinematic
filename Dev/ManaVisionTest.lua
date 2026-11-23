-- /cine debug manavision: Vitals Vision's low mana (Atmosphere/ManaVision.lua).
-- One real action: cast any spell that costs mana. Steps:
--   1 pages   the Vitals Vision page's Health and Mana tabs, the Mana tab off
--             then on, and the Style page's Mana tab: each opened, its
--             controls clear of the rest (r:Overlaps), a shot behind the panel
--   2 test    the page's Test: the screen drains on its own (plain alpha),
--             then clears
--   3 real    Starts at 99%, so one spell shows it: the game's alpha from your
--             real (secret on Forever) mana through the curve, no error
-- Settings put back at the end. Into CinematicDB.manaVisionTestLog. Dev copy only.
local _, ns = ...

local function Tab() return ns.VITALS_MANA_TAB end

-- A page's canvas, opened, and the section (tab body) a control sits in.
local function Open(r, page)
	if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
	ns.OpenOptions(page)
	r:Sleep(0.8)
end
local function SectionOf(control)
	local frame = control
	for _ = 1, 8 do
		if not frame then return nil end
		if frame.openSection then return frame end
		frame = frame:GetParent()
	end
end
local function ShowSection(r, control)
	local section = SectionOf(control)
	if section then
		section.openSection()
		r:Sleep(0.4)
	end
	return section
end
-- (Against the page's canvas: a tab's body is a 1x1 anchor, so its parent
-- made run 1 say "past the edge by 263 px".)
local function CheckClear(r, label, control, page)
	if not (control and control:IsVisible()) then
		r:Fail(label .. ": not shown on the page")
		return
	end
	local canvas = ns.settingsCanvases and ns.settingsCanvases[page]
	local hits = r:Overlaps(control, canvas or SettingsPanel)
	r:Verdict(#hits == 0, label .. " overlaps nothing: " .. (#hits > 0 and table.concat(hits, ", ") or "clear"))
end

local function LogState(r, label)
	local s = ns.ManaVisionState()
	r:Fields(label, {
		shown = function() return s.shown end, mode = function() return s.mode end,
		alpha = function() return s.alpha end, on = function() return s.on end,
		hasMana = function() return s.hasMana end, curve = function() return s.curve end,
		manaSecret = function() return s.manaSecret end, maxSecret = function() return s.maxSecret end,
		strength = function() return s.strength end, edgeAlpha = function() return s.edgeAlpha end,
		error = function() return s.error end, level = function() return s.level end,
	})
	return s
end

-- A page scrolled so a control sits near its top (run 1's shot had the
-- Style tab's preview below the fold).
local function ScrollTo(r, page, control)
	local canvas = ns.settingsCanvases and ns.settingsCanvases[page]
	local scroll = canvas and canvas.scroll
	local child = scroll and scroll.GetScrollChild and scroll:GetScrollChild()
	if child and child.GetTop and child:GetTop() and control:GetTop() then
		local range = tonumber(scroll:GetVerticalScrollRange()) or 0
		local at = math.max(0, math.min(range, child:GetTop() - control:GetTop() - 120))
		scroll:SetVerticalScroll(at)
		r:Log(("scrolled to %.0f of %.0f"):format(at, range))
		r:Sleep(0.3)
	end
end

ns.TestKit.Define({
	name = "manavision",
	key = "manaVisionTest",
	title = "Vitals Vision: low mana",
	about = "the screen draining as your mana runs out: the pages' tabs, the Test, and your real mana through the curve",
	needs = "A character that uses mana",
	settings = { "lowHealth", "tabOn:VitalsVision:mana", "tabOn:VitalsVision:health", "tabOn:Vitals:mana",
		"lowManaAlways", "lowManaVisionStart", "lowManaVisionFull", "lowManaVisionStrength", "lowManaVisionEdges" },
	context = function()
		local max = UnitPowerMax("player", 0)
		return ("mana max %s, power type %s, curve API %s, ManaVision loaded %s"):format(
			tostring(issecretvalue and issecretvalue(max) and "secret" or max), tostring((UnitPowerType("player"))),
			tostring(C_CurveUtil and C_CurveUtil.CreateCurve and UnitPowerPercent and true or false),
			tostring(ns.ManaVisionState ~= nil))
	end,
	putBack = function()
		if ns.StopManaVisionTest then ns.StopManaVisionTest() end
		if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
		return "mana test stopped, settings closed"
	end,
	steps = {
		{ key = "pages", title = "the Health and Mana tabs, and Style's Mana tab", run = function(r)
			if not ns.ManaVisionState then
				r:Fail("Visions isn't loaded (left out on the Profiles page?): nothing to test")
				return
			end
			r:Set("lowHealth", true)
			r:Set("tabOn:VitalsVision:health", true)
			r:Set(Tab(), true)
			if not r:Proven("manavision run 1 (q422e, Forever): Vision tab's Health and Mana tabs, Test button clear, greyed off, shots") then
				r:Set(Tab(), false)
				Open(r, "Vitals Vision")
				local button = ns.manaVisionTestButton
				local section = ShowSection(r, button)
				r:Verdict(section ~= nil, "the Test button is on a tab of its own")
				CheckClear(r, "Mana tab's Test button", button, "Vitals Vision")
				r:Shot("Vitals Vision, Mana tab off (greyed)", { behind = SettingsPanel })
				r:Set(Tab(), true)
				if ns.RefreshOptions then ns.RefreshOptions() end
				r:Sleep(0.4)
				r:Shot("Vitals Vision, Mana tab on", { behind = SettingsPanel })
			end
			Open(r, "Vitals Style")
			local preview = ns.manaVisionPreview
			ShowSection(r, preview)
			ScrollTo(r, "Vitals Style", preview)
			CheckClear(r, "Style's Mana preview", preview, "Vitals Style")
			r:Shot("Vitals Style, Mana tab: look and its preview", { behind = SettingsPanel })
			if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
		end },
		{ key = "test", title = "the page's Test", run = function(r)
			if not ns.TestManaVision then r:Skip("not loaded") return end
			ns.TestManaVision()
			r:Sleep(5)
			local s = LogState(r, "test, 5 s in")
			r:Verdict(s.shown and s.mode == "test", "the test shows it: " .. tostring(s.mode))
			r:Verdict(type(s.level) == "number" and s.level > 0.3, "drained part way or more: " .. tostring(s.level))
			r:Shot("the test: mana near empty, the screen drained")
			-- Run 1: the overlay's GetAlpha read secret in the test's plain
			-- mode. Settled here on a fresh frame: a secret SetAlpha, then a
			-- plain one, then GetAlpha.
			if not r:Proven("manavision run 2 (q3a4b): GetAlpha stays secret after a curve SetAlpha (rule forever.alpha.secret-sticks)") then
				local probe = CreateFrame("Frame")
				local curve = ns.ManaVisionCurve and ns.ManaVisionCurve()
				r:Probe("fresh frame GetAlpha", function() return probe:GetAlpha() end)
				if curve then
					pcall(function() probe:SetAlpha(UnitPowerPercent("player", 0, false, curve)) end)
					r:Probe({ label = "after a curve SetAlpha", rule = "forever.alpha.secret-sticks" },
						function() return probe:GetAlpha() end)
					probe:SetAlpha(0.5)
					r:Probe("then SetAlpha(0.5)", function() return probe:GetAlpha() end)
				end
			end
			r:Sleep(6)
			LogState(r, "test, after")
			r:Verdict(ns.ManaVisionTestLeft() == nil, "the test ended")
		end },
		{ key = "real", title = "your real mana through the curve", run = function(r)
			if not ns.ManaVisionHasMana or not ns.ManaVisionHasMana() then
				r:Skip("this character doesn't use mana")
				return
			end
			r:Set("lowHealth", true)
			r:Set(Tab(), true)
			r:Set("lowManaAlways", true)
			r:Set("lowManaVisionStart", 0.99)
			-- (Full 90%: one spell shows it plainly. Run 2's Full 0 left one
			-- spell at about 1% drained: right, but nothing to see in the shot.)
			r:Set("lowManaVisionFull", 0.9)
			if ns.RefreshManaVision then ns.RefreshManaVision() end
			r:Sleep(0.5)
			LogState(r, "before the spell")
			r:WaitFor("Cast any spell that costs mana", {
				events = { "UNIT_POWER_UPDATE" },
				filter = function(_, unit) return unit == "player" end,
			})
			r:Sleep(1)
			local s = LogState(r, "after the spell")
			r:Verdict(s.shown and s.mode == "game", "shown on your mana: " .. tostring(s.mode))
			r:Verdict(s.curve, "the curve API is there")
			r:Verdict(s.error == nil, "the game took the curve's alpha: " .. tostring(s.error))
			r:Shot("your mana, a spell down: clearly drained (Starts 99%, Full 90%)")
		end },
	},
})
