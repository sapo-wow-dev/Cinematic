-- Cinematic: ClassicUI Forever, the original Classic look on WoW Forever. It
-- moves the game's action buttons out of their bars into frames of its own
-- (one unnamed holder on UIParent a bar, a slot a button) and sets each
-- holder's alpha from its bar's, but only when its own fading changes. So
-- with the bars faded the holders stayed at 0: the buttons never showed, and
-- hovering them didn't bring the bar up (their bar doesn't hold them now:
-- Frames.lua's ns.FocusOnBarButton). Tested 2026-11-12, /cine debug bartest.
--
-- Its bar art (ForeverClassicUIBar) fades with the Action bar art row, its
-- quest watch (ForeverClassicUIQuestWatch) with the Quest tracker row.
-- Here each holder follows its bar's alpha as Cinematic fades the bar, times
-- ClassicUI's own fade for it (read off the holder, as the last bar alpha
-- times its fade).
local _, ns = ...

local BARS = { "MainActionBar", "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight",
	"MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7", "StanceBar", "PetActionBar" }

local function Secret(value)
	return issecretvalue ~= nil and issecretvalue(value)
end

-- The bar's holder: its first button's slot's parent, on UIParent; nil while
-- its buttons are still its own.
local function HolderOf(bar)
	local buttons = bar.actionButtons
	local button = type(buttons) == "table" and buttons[1]
	local slot = button and button:GetParent()
	local holder = slot and slot ~= bar and slot:GetParent()
	if not holder or holder == bar or holder:GetParent() ~= UIParent then return nil end
	return holder
end

local last = setmetatable({}, { __mode = "k" }) -- bar -> { alpha = its last, fade = ClassicUI's }
local function Follow(bar, alpha)
	if Secret(alpha) or type(alpha) ~= "number" then return end
	local holder = HolderOf(bar)
	if not holder then return end
	local state = last[bar]
	if not state then
		state = { alpha = nil, fade = 1 } -- (the first time: no bar alpha of ours to read its fade by)
		last[bar] = state
	end
	-- (ClassicUI's own fade: what it last set, over the bar alpha it read.)
	local now = holder:GetAlpha()
	if not Secret(now) and state.alpha and state.alpha > 0.01 then
		state.fade = math.max(0, math.min(1, now / state.alpha))
	end
	state.alpha = alpha
	holder:SetAlpha(alpha * state.fade)
end

ns.WhenAddonLoads("ClassicUIForever", function()
	-- Its bar art (the slots' backgrounds, end caps, page arrows, and the
	-- micro menu and bags it moves onto it) fades with the Action bar art
	-- row, coming up with the main bar as the game's art does.
	ns.FadeWithRows({ { "art", "barart", "ForeverClassicUIBar" } })
	-- Its Classic quest watch, standing in for the game's quest tracker,
	-- fades with the Quest tracker row. (It leaves its own alpha alone.)
	ns.FadeWithRow("quests", "quests", { "ForeverClassicUIQuestWatch" })
	for _, name in ipairs(BARS) do
		local bar = _G[name]
		if type(bar) == "table" and bar.SetAlpha then
			hooksecurefunc(bar, "SetAlpha", Follow)
		end
	end
	ns.Log("support", "ClassicUI Forever: its action button holders follow their bars' alpha")
end)
