-- /cine debug auraplate: the target frame's buff row on top vs a Style
-- theme's name plate (Neon Coast, Discord report 2026-11-21: the buffs sat on
-- the plate). Ledger: Tools/tests/neon-aura-overlap.md. Steps:
--   1 setup    client, buffs on top, aura holder kind, layout calls; your
--              theme kept (put back at the end), the Unit Frames Style chain on
--   2 target   waits for a target (not you) with a buff or debuff (aura API);
--              logs what of the aura holder and its icons is readable
--   3 ontop    buffs on top: asks you to tick it in Edit Mode when the client has it
--   4 game     no theme: the row where the game puts it, no lift (shot)
--   5 neon     Neon Coast: the fix (Style/UnitAuraLift.lua) lifts the row off
--              the plate; clear of it where the row's place is readable (shot)
--   6 fight    hit a mob: still lifted after the game lays the row out again
--              in the fight (shot), then waits for the fight to end
-- Before each look: Edit Mode closed and the target still there (run 3 had
-- neither). The confirm run for the fix, run 4 (ledger says why).
-- All places in screen pixels (top * effective scale). Into
-- CinematicDB.auraPlateTestLog. Dev copy only.
local _, ns = ...

local function Readable(v)
	return v ~= nil and not (issecretvalue and issecretvalue(v))
end
local function Px(region, side)
	if not (region and region.GetTop) then return nil end
	local ok, v, scale = pcall(function()
		local value = side == "bottom" and region:GetBottom() or region:GetTop()
		return value, region:GetEffectiveScale()
	end)
	if not (ok and Readable(v) and Readable(scale)) then return nil end
	return v * scale
end
local function N(v) return v and ("%.1f"):format(v) or "nil" end

-- The target frame's aura frames: Forever's one container, retail's pool, or
-- the numbered globals; and which kind it was.
local function AuraFrames(frame)
	local list = {}
	local ok, container = pcall(function() return frame.GetAuraContainer and frame:GetAuraContainer() end)
	if ok and type(container) == "table" and container.GetTop then
		list[1] = container
		return list, "container"
	end
	local pools = frame.auraPools
	if pools and pools.EnumerateActive then
		for aura in pools:EnumerateActive() do
			if aura:IsShown() then list[#list + 1] = aura end
		end
		return list, "pools"
	end
	local name = frame:GetName()
	for _, kind in ipairs({ "Buff", "Debuff" }) do
		for i = 1, 40 do
			local aura = _G[name .. kind .. i]
			if not aura then break end
			if aura:IsShown() then list[#list + 1] = aura end
		end
	end
	return list, "globals"
end

-- The icons inside Forever's container (its shown children), for the row's real bottom.
local function Icons(list, kind)
	if kind ~= "container" then return list end
	local icons = {}
	for _, child in ipairs({ list[1]:GetChildren() }) do
		local ok, shown = pcall(child.IsShown, child)
		if ok and Readable(shown) and shown then icons[#icons + 1] = child end
	end
	return #icons > 0 and icons or list
end

local function ThemePlate(frame)
	for _, part in ipairs(ns.UnitThemeArt and ns.UnitThemeArt(frame) or {}) do
		if part.cell then return part end
	end
end

local function GameArt(frame)
	local holder = frame.TargetFrameContainer
	return (holder and holder.FrameTexture) or _G.TargetFrameTextureFrameTexture or _G.TargetFrameTexture
end
-- (The name text: the frame art's rect is the whole frame box, so the game's
-- own gap is measured from the name's top, the highest drawn thing under the row.)
local function NameText(frame)
	local content = frame.TargetFrameContent
	local main = content and content.TargetFrameContentMain
	return (main and main.Name) or frame.name or _G.TargetFrameTextureFrameName
end

-- One measure: the row's bottom and top, the plate's top (its frame and its
-- highest shown region), the game art's top, the overlap.
local function Measure(r, label)
	local frame = _G.TargetFrame
	local list, kind = AuraFrames(frame)
	local icons = Icons(list, kind)
	local low, high, secret = nil, nil, 0
	for _, aura in ipairs(icons) do
		local b, t = Px(aura, "bottom"), Px(aura, "top")
		if b and t then
			low = low and math.min(low, b) or b
			high = high and math.max(high, t) or t
		else
			secret = secret + 1
		end
	end
	-- (No icon readable: the container's own place, Forever's one holder.)
	local from = "icons"
	if not low and kind == "container" then
		low, high, from = Px(list[1], "bottom"), Px(list[1], "top"), "container rect"
	end
	local plate = ThemePlate(frame)
	local plateShown = plate and plate:IsShown() or false
	local plateTop, regionTop, regionWho = plateShown and Px(plate, "top") or nil, nil, nil
	if plateShown then
		for i, region in ipairs({ plate:GetRegions() }) do
			local t = region:IsShown() and Px(region, "top")
			if t and (not regionTop or t > regionTop) then regionTop, regionWho = t, i end
		end
	end
	local top = regionTop or plateTop
	local art = GameArt(frame)
	local artShown = false
	if art then
		local ok, shown, alpha = pcall(function() return art:IsShown(), art:GetAlpha() end)
		artShown = ok and Readable(shown) and shown and Readable(alpha) and alpha > 0 or false
	end
	local result = { low = low, high = high, plateTop = top, artTop = artShown and Px(art, "top") or nil,
		frameTop = Px(frame, "top"), nameTop = Px(NameText(frame), "top"), kind = kind, count = #icons,
		stripTop = ns.UnitNameStrip and Px(ns.UnitNameStrip(frame), "top") or nil }
	result.overlap = (top and low) and (top - low) or nil
	result.gameGap = (result.nameTop and low) and (low - result.nameTop) or nil
	r:Log(("measure %s: holder %s, %d aura frame(s), %d unreadable; row (%s) bottom %s top %s | plate %s frame top %s,"
		.. " highest region %s (#%s) | game art %s top %s | name top %s | TargetFrame top %s | overlap %s"
		.. " (plate top - row bottom) | name gap %s (row bottom - name top) | strip top %s | buffs on top %s | in a fight %s"):format(
		label, kind, #icons, secret, from, N(low), N(high), plateShown and "shown" or "none", N(plateTop), N(regionTop),
		tostring(regionWho), artShown and "shown" or "hidden", N(result.artTop), N(result.nameTop), N(result.frameTop),
		N(result.overlap), N(result.gameGap), N(result.stripTop), tostring(frame.buffsOnTop), tostring(InCombatLockdown())))
	return result
end

local function Theme(r, key)
	local ok = ns.ApplyStyleTheme(key, true)
	r:Log(("theme %s applied: %s"):format(key, tostring(ok)))
	r:Sleep(1) -- (a frame or two for the look to settle)
	return ok
end

-- The target (not you) with a buff or debuff, by the aura API: a secret
-- answer counts as one (Forever's icon places are secret, run 1 hung on them).
local function HasAura()
	local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
	if not get then return #AuraFrames(_G.TargetFrame) > 0 end
	for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
		local ok, data = pcall(get, "target", 1, filter)
		if ok and data ~= nil then return true end
	end
	return false
end
local function Ready()
	if not UnitExists("target") or UnitIsUnit("target", "player") then return false end
	return HasAura()
end
local function EditModeOpen()
	local edit = _G.EditModeManagerFrame
	return edit and edit:IsShown() or false
end
-- (Before each look: Edit Mode closed and the target there, run 3 lost both.)
local function Settled(r, what)
	if EditModeOpen() then
		r:WaitFor("Close Edit Mode to go on.", { check = function() return not EditModeOpen() end })
	end
	if not Ready() then
		r:WaitFor("Target someone (not you) with a buff or debuff again" .. (what and (" " .. what) or "") .. ".",
			{ check = Ready })
	end
	r:Prompt("Nothing to do: the test does this one.")
	r:Sleep(0.5)
end

-- The fix's lift (Style/UnitAuraLift.lua): applied now and what it'd want.
local function LiftLine(r, label)
	local now, need = 0, nil
	if ns.UnitAuraLiftNow then now, need = ns.UnitAuraLiftNow(_G.TargetFrame) end
	r:Log(("lift %s: on the row %s, wanted %s (frame units)"):format(label, N(now), N(need)))
	return now, need
end

ns.TestKit.Define({
	name = "auraplate",
	key = "auraPlateTest",
	title = "Buffs over the name plate",
	about = "confirm: target frame buffs on top lifted off a Style theme's name plate (Neon Coast)",
	settings = { "styleGeneral", "ufStyle" },
	cvars = { "uiScale", "useUiScale" },
	context = function()
		local frame = _G.TargetFrame
		return ("TargetFrame scale %s, effective %s; buffsOnTop %s; UpdateAuras %s, UpdateAuraPositions %s,"
			.. " TargetFrame_UpdateAuras %s, GetAuraContainer %s; theme %s"):format(
			tostring(frame:GetScale()), tostring(frame:GetEffectiveScale()), tostring(frame.buffsOnTop),
			tostring(frame.UpdateAuras ~= nil), tostring(frame.UpdateAuraPositions ~= nil),
			tostring(_G.TargetFrame_UpdateAuras ~= nil), tostring(frame.GetAuraContainer ~= nil),
			tostring(ns.db.styleTheme))
	end,
	putBack = function(extra)
		local kept = extra.themeKept
		if type(kept) ~= "table" then return "no theme to put back" end
		if InCombatLockdown() then return "in a fight: theme not put back, /cine debug auraplate restore after it" end
		ns.RestoreStyleSnapshot(kept)
		return "your theme back to " .. tostring(kept.styleTheme)
	end,
	steps = {
		{ key = "setup", title = "client, aura holder, your theme kept", run = function(r)
			if InCombatLockdown() then
				r:WaitFor("Leave the fight first (a theme can't change in one)", { events = { "PLAYER_REGEN_ENABLED" } })
			end
			r:Keep("themeKept", ns.StyleSnapshot())
			r:Log("your theme kept: " .. tostring(ns.db.styleTheme))
			-- (Style switch chain: Unit Frames Style and every switch over it on.)
			local key = "ufStyle"
			while key do
				if not ns.db[key] then r:Set(key, true) end
				key = ns.PageSwitchOf(key)
			end
			r:Verdict(ns.StyleOn("ufStyle"), "Unit Frames Style on with its chain")
			local _, kind = AuraFrames(_G.TargetFrame)
			r:Log("aura holder kind: " .. kind)
		end },
		{ key = "target", title = "a target with a buff or debuff", run = function(r)
			if not Ready() then
				r:WaitFor("Target a mob or player (not you) with a buff or debuff showing on your target frame.",
					{ check = Ready })
			end
			r:Fields("target", { name = function() return UnitName("target") end,
				reaction = function() return UnitReaction("target", "player") end,
				buffsOnTop = function() return _G.TargetFrame.buffsOnTop end })
			-- (What of the aura holder can be read: its place, each child's shown and place.)
			local list, kind = AuraFrames(_G.TargetFrame)
			r:Log(("holder %s, %d frame(s)"):format(kind, #list))
			for i, holder in ipairs(list) do
				if i > 8 then break end
				r:Fields("holder " .. i, { type = function() return holder:GetObjectType() end,
					name = function() return holder:GetName() end, shown = function() return holder:IsShown() end,
					bottom = function() return Px(holder, "bottom") end, top = function() return Px(holder, "top") end,
					rawBottom = function() return holder:GetBottom() end, children = function() return holder:GetNumChildren() end,
					point = function() local p, rel, rp, x, y = holder:GetPoint(1)
						return ("%s %s %s %s %s"):format(tostring(p), tostring(rel and rel.GetName and rel:GetName() or rel),
							tostring(rp), tostring(x), tostring(y)) end })
				if kind == "container" then
					for c, child in ipairs({ holder:GetChildren() }) do
						if c > 8 then break end
						r:Fields(("child %d"):format(c), { type = function() return child:GetObjectType() end,
							shown = function() return child:IsShown() end,
							bottom = function() return Px(child, "bottom") end, top = function() return Px(child, "top") end,
							rawBottom = function() return child:GetBottom() end,
							size = function() return child:GetWidth() end })
					end
				end
			end
		end },
		{ key = "ontop", title = "buffs on top", run = function(r)
			local frame = _G.TargetFrame
			local setting = Enum and Enum.EditModeUnitFrameSetting and Enum.EditModeUnitFrameSetting.BuffsOnTop
			r:Log(("buffsOnTop %s; Edit Mode's Buffs on Top setting %s"):format(tostring(frame.buffsOnTop), tostring(setting)))
			if frame.buffsOnTop == true then return r:Pass("buffs already on top") end
			if not setting then
				return r:Skip("this client's Edit Mode has no Buffs on Top: measured with the buffs under the frame")
			end
			-- (Only Edit Mode can flip it: rule forever.targetframe.buffsontop-addon-taint.
			-- The button opens it with your click, nothing tainted.)
			r:WaitFor("Turn on Buffs on Top: press Open Edit Mode, click your Target Frame, tick Buffs on Top, then close"
				.. " Edit Mode. (Untick it after the test if you don't want it.)",
				{ check = function() return frame.buffsOnTop == true end, buttons = { { kind = "editmode" } } })
			if EditModeOpen() then
				r:WaitFor("Now close Edit Mode.", { check = function() return not EditModeOpen() end })
			end
			r:Sleep(0.5)
			r:Verdict(frame.buffsOnTop == true, "buffs on top now")
		end },
		{ key = "game", title = "no theme: the game's own look", run = function(r)
			Settled(r)
			Theme(r, "game")
			Measure(r, "game")
			local now = LiftLine(r, "game")
			r:Verdict(math.abs(now) < 0.01, "no theme: the game's row left where the game puts it")
			r:Shot("game look")
		end },
		{ key = "neon", title = "Neon Coast: the row lifted off the plate", run = function(r)
			Settled(r)
			Theme(r, "neon")
			local look = Measure(r, "neon")
			local now = LiftLine(r, "neon")
			r:Verdict(now > 0 and now <= 20, ("Neon with buffs on top: the row lifted %s units (0 to 20)"):format(N(now)))
			if look.overlap then
				r:Verdict(look.overlap <= 0 and look.overlap > -12,
					("row clear of the plate, not far off: plate top - row bottom %s px (0 to -12)"):format(N(look.overlap)))
			else
				r:Log("row place secret here: the screenshot shows whether it's clear")
			end
			r:Shot("neon look")
		end },
		{ key = "fight", title = "the same in a fight", run = function(r)
			r:WaitFor("Hit a mob once to start a fight (keep it or someone with a buff targeted).",
				{ events = { "PLAYER_REGEN_DISABLED" } })
			-- (Its auras change in the fight: the game lays the row out again.)
			local from = GetTime()
			r:WaitFor(nil, { events = { "UNIT_AURA" }, filter = function(_, unit) return unit == "target" end,
				check = function() return GetTime() - from >= 6 and "6 s, no aura change" end })
			r:Sleep(0.5)
			Measure(r, "in a fight")
			-- (A lift only where the plate reaches over the game's strip: a target with
			-- no power bar has a lower plate and needs none, run 4's chicken.)
			local now, need = LiftLine(r, "in a fight")
			r:Verdict(need and math.abs(now - need) < 0.01 and now <= 20,
				("in a fight: the row's lift %s, as the plate wants %s (0 if it's under the game's strip)"):format(N(now), N(need)))
			r:Shot("in a fight")
			r:WaitFor("Finish the fight (or run off). Your theme goes back after it."
				.. " Untick Buffs On Top in Edit Mode afterwards if you don't want it.",
				{ events = { "PLAYER_REGEN_ENABLED" } })
			Measure(r, "after the fight")
			LiftLine(r, "after the fight")
		end },
	},
})
