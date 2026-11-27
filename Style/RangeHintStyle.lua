-- The Style hub's Range Hint page (Range Hint Style, 2026-11-25): how the mark
-- under your character looks while your target is out of your spell's range
-- (UI/RangeHint.lua). Which spell, and when it shows: the Interface hub's
-- Range Hint icon (its Show and Settings tabs; this page is its Style tab).
-- Plan: Tools/range-hint-style-plan.md. The look's defaults live in
-- UI/RangeHint.lua, so the mark draws with Style left out. Page off: the
-- mark's first look (ns.StyleLook). Its look: the Style Studio's editor
-- (frame "range", Style/Studio/Frames/FloatingText.lua, 2026-11-25); its old
-- folder tabs' switches still read (ns.RangeStyleTabOn): one left off says so
-- on the editor's status line, with Turn on.
local _, ns = ...
ns.Module("style", function() -- (the rest of this file: only with Style loaded, Modules.lua)

-- Its text's font, outline and shadow can follow General's (StylePages.lua's
-- shared list): "general" picked, they're General's.
ns.SHARED_STYLE.rangeHintFont = { kind = "font", own = "game" }

local SAMPLE_SPELL = 116 -- Frostbolt, when you have no attack on your bars
local CYCLE, SHOWN = 4, 2.6 -- the preview's loop: seconds, and how long of it the mark's up

-- The preview: the Style pages' scene, a figure's two personal bars, and the
-- mark under them drawn by the mark's own code (ns.RangeHintDraw) in this
-- page's look, coming and going over and over with its own Motion.
local function MakePreview(parent, width)
	local L = ns.L
	local preview = CreateFrame("Frame", nil, parent)
	preview:SetSize(width, 170)
	ns.StyleScene(preview, 0.6)
	local caption = preview:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	caption:SetText(L["Preview"])
	caption:SetPoint("TOPLEFT", 6, -5)
	caption.searchSkip = true
	-- (Your personal bars, as in the game: the mark sits under them.)
	local bars = CreateFrame("Frame", nil, preview)
	bars:SetSize(110, 14)
	bars:SetPoint("CENTER", preview, "CENTER", 0, 30)
	local health = bars:CreateTexture(nil, "ARTWORK")
	health:SetColorTexture(0.1, 0.75, 0.15, 1)
	health:SetPoint("TOPLEFT")
	health:SetSize(110, 6)
	local mana = bars:CreateTexture(nil, "ARTWORK")
	mana:SetColorTexture(0.15, 0.35, 0.9, 1)
	mana:SetPoint("BOTTOMLEFT")
	mana:SetSize(110, 6)
	local holder = CreateFrame("Frame", nil, preview)
	holder:SetFrameLevel(preview:GetFrameLevel() + 5)
	local anchor = CreateFrame("Frame", nil, preview)
	anchor:SetSize(1, 1)
	anchor:SetPoint("TOP", bars, "BOTTOM", 0, -14)
	local parts = ns.RangeHintMakeParts(holder)
	preview.parts, preview.holder = parts, holder
	local function Spell()
		local spell = ns.RangeHint and ns.RangeHint.Chosen()
		return spell or SAMPLE_SPELL
	end
	function preview:Refresh()
		-- (Not drawn while hidden: the editor refreshes its preview as the page
		-- is built, and the spell asked then scanned your bars before they load.)
		if not self.cineShown then return end
		ns.RangeHintDraw(parts, { spell = Spell(), why = "out of range" })
	end
	local look = ns.RangeHintLook
	local started, alpha, shownAt = GetTime(), 0, nil
	-- (Test, 2026-11-25: one cycle as the real mark runs it: Show after, then
	-- up till Hide after (else a few seconds), then gone; the loop after it.)
	local testAt
	function preview.TestCycle()
		testAt, alpha = GetTime(), 0
	end
	ns.SetOnUpdate(preview, function(_, elapsed)
		local now = GetTime()
		local t = (now - started) % CYCLE
		local up = t < SHOWN
		if testAt then
			local delay = tonumber(look.rangeHintDelay) or 0
			local hide = tonumber(look.rangeHintHideAfter) or 0
			local hold = hide > 0 and hide or SHOWN
			local held = now - testAt
			up = held >= delay and held < delay + hold
			preview.testing = true
			if held > delay + hold + (tonumber(look.rangeHintFadeOut) or 0) + 0.3 then
				testAt, preview.testing, started = nil, nil, now - SHOWN -- (the loop goes on from hidden)
			end
		end
		local wanted = up and 1 or 0
		if up and alpha == 0 then shownAt = now end
		if alpha ~= wanted then
			local time = tonumber(wanted > alpha and look.rangeHintFadeIn or look.rangeHintFadeOut) or 0
			local step = time > 0 and elapsed / time or 1
			alpha = wanted > alpha and math.min(wanted, alpha + step) or math.max(wanted, alpha - step)
		end
		local enter = look.rangeHintEnter
		holder:ClearAllPoints()
		holder:SetPoint("TOP", anchor, "TOP", 0, (enter == "rise" and up) and -(1 - alpha) * 8 or 0)
		holder:SetScale((enter == "grow" and up) and (0.8 + 0.2 * alpha) or 1)
		local pulse, mode = 1, look.rangeHintPulse
		if alpha == 1 and shownAt and (mode == "always" or (mode == "start" and now - shownAt < 3)) then
			pulse = 0.7 + 0.3 * (0.5 + 0.5 * math.cos((now - shownAt) * 2 * math.pi / 1.6))
		end
		holder:SetAlpha(alpha * (tonumber(look.rangeHintAlpha) or 1) * pulse)
	end)
	preview:SetScript("OnShow", function(self) self.cineShown = true self:Refresh() end)
	return preview
end
ns.MakeRangeHintStylePreview = MakePreview

function ns.CreateRangeHintStylePanel(kit)
	local L = ns.L
	local canvas, content = kit.CreateScrollPage()
	local title = kit.Label(content, "GameFontNormalLarge", L["Range Hint Style"])
	local tabs = ns.PageTabs(content, ns.ShowInTabs("range"), ns.ShowInIndex("range", "Range Hint Style"))
	title:SetPoint("TOPLEFT", tabs, "BOTTOMLEFT", 8, -14)
	local intro = kit.PageIntro(content, title,
		L["How the mark under your character looks while your target is out of range. Pick the spell on the Range Hint icon's Settings tab."])
	local preview
	local function Changed()
		if ns.RangeHintRefresh then ns.RangeHintRefresh() end
		if preview then preview:Refresh() end
	end
	local switch = kit.PageSwitch(content, "rangeHintStyle", L["Enable Page"],
		L["Turns this page's look on or off. Off: the mark's first look."], intro, Changed)
	local stack = kit.Stack(switch, "check")

	preview = MakePreview(content, 480)
	stack:Add(preview, "label")
	ns.StylePopout(preview, kit.Tooltip) -- (StylePages.lua)
	kit.AddControl(preview)

	-- The look: the Style Studio's editor (Style/Studio/Frames/FloatingText.lua,
	-- frame "range"), 2026-11-25. Its Test plays one real cycle (Show after,
	-- Hide after too) on the preview and on your screen. Its folder tabs
	-- (Mark, Text, Background, Motion) are its parts now. (Its sound: removed
	-- 2026-11-25, the user.)
	local host = ns.StyleEditorPage(kit, content, stack, "range", { preview = preview, canvas = canvas })

	-- (For the tests: a part picked (the old folder tabs' order: Mark, Text,
	-- Background, Motion), and the preview.)
	local PARTS = { "mark", "text", "back", "motion" }
	ns.RangeStyleOpenTab = function(i) if PARTS[i] then host:Pick(PARTS[i]) end end
	ns.rangeHintStylePreview = preview
	ns.rangeHintStyleContent = content
	ns.rangeHintStyleHost = host

	canvas:SetScript("OnShow", kit.PageShown(function()
		kit.Refresh()
		preview:Refresh()
	end, content))
	canvas:Hide()
	kit.RegisterSubpage(canvas, "Range Hint Style", L["Range Hint Style"])
end
end) -- (ns.Module "style")
