-- /cine debug cdmround: the Cooldown Manager's icons with Action Bar Style's
-- Shape on Round: each icon cut round and cropped (ns.CDM_TRIM), the whole
-- fight. A player's video (Forever, 2026-11-22): in a fight, Tracked Buffs
-- icons kept the game's rounded square, no crop, while the icons below them
-- were round; "intermittent, which ones". The shape is this run's only
-- (Action Bar Style's look read with Round over it, your settings untouched).
-- Steps:
--   1 round   every icon: cut round, cropped, a shot of each bar (proven)
--   2 square  Square instead: the game's own crop back (proven)
--   3 fight   Round, through one fight: every shown icon checked 4 times a
--             second; one not round is logged once (its bar, spell, made /
--             masked / cropped, the last dressing error), dressed again on the
--             spot to see why it fails, and shot. Also each bar's layouts.
--             A fight with no Tracked Buffs icon lit up SKIPs: the player's
--             case wasn't covered.
--   4 pandemic  Round, the game's refresh border (put up on a shown icon by
--             the test, out of a fight; nothing to do): its square one
--             hidden and our round glow shown (fix card
--             Tools/audits/2026-11-23-style-cdm-round-pandemic.md), a shot;
--             then Square for a moment: the game's own border back, a shot
--             to compare colors. (proven)
-- Into CinematicDB.cdmRoundTestLog. Dev copy only.
local _, ns = ...

local VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer" }
local SHORT = { EssentialCooldownViewer = "essential", UtilityCooldownViewer = "utility",
	BuffIconCooldownViewer = "buffs" }

-- Each icon of a viewer: its items' .Icon textures, as Action Bar Style finds them.
local function Icons(viewer)
	local found = {}
	local function Look(frame, depth)
		local ok, kids = pcall(function() return { frame:GetChildren() } end)
		for _, kid in ipairs(ok and kids or {}) do
			local icon = kid.Icon
			if type(icon) == "table" and icon.GetObjectType and icon:GetObjectType() == "Texture" then
				found[#found + 1] = { item = kid, icon = icon }
			elseif depth < 2 then
				Look(kid, depth + 1)
			end
		end
	end
	Look(viewer, 0)
	return found
end

local lookWas
local function Shape(shape)
	if shape and not lookWas then lookWas = ns.StyleLook end
	if shape then
		ns.StyleLook = function(key, ...)
			local look = lookWas(key, ...)
			if key ~= "abStyle" or type(look) ~= "table" then return look end
			return setmetatable({ abShape = shape }, { __index = look })
		end
	elseif lookWas then
		ns.StyleLook, lookWas = lookWas, nil
	end
	if ns.RefreshCooldownShape then pcall(ns.RefreshCooldownShape) end
end

local function AnyShown()
	for _, name in ipairs(VIEWERS) do
		local viewer = _G[name]
		if viewer and viewer:IsVisible() then return true end
	end
	return false
end

local function Plain(value)
	if issecretvalue and issecretvalue(value) then return "secret" end
	return tostring(value)
end

local function Crop(icon)
	local ok, left = pcall(icon.GetTexCoord, icon)
	if not ok then return "error" end
	if issecretvalue and issecretvalue(left) then return "secret" end
	return type(left) == "number" and ("%.3f"):format(left) or "?"
end

-- Each viewer's icons read: crop (left edge) and how many sit at want.
local function ReadAll(r, want, label)
	local total, right = 0, 0
	for _, name in ipairs(VIEWERS) do
		local viewer = _G[name]
		if viewer then
			local list = Icons(viewer)
			local crops = {}
			for _, entry in ipairs(list) do
				local ok, left = pcall(entry.icon.GetTexCoord, entry.icon)
				crops[#crops + 1] = Crop(entry.icon) .. (entry.item:IsShown() and "" or "(hidden)")
				total = total + 1
				if ok and type(left) == "number" and want(left) then right = right + 1 end
			end
			r:Log(("%s %s: shown %s, %d icons, crops %s"):format(label, name, tostring(viewer:IsVisible()), #list,
				table.concat(crops, " ")))
			if viewer:IsVisible() and #list > 0 then r:Shot(label .. " " .. name, { behind = viewer }) end
		else
			r:Log(name .. ": not made (the Cooldown Manager isn't loaded)")
		end
	end
	return total, right
end

-- What one icon is: its spell and aura, if they read.
local function Describe(item)
	local spell = item.GetSpellID and select(2, pcall(item.GetSpellID, item))
	local cooldownID = item.GetCooldownID and select(2, pcall(item.GetCooldownID, item))
	local reach = item.CanBeAccessedInContext and select(2, pcall(item.CanBeAccessedInContext, item))
	return ("spell %s, cooldownID %s, aura %s, shown %s, layoutIndex %s, reachable %s"):format(Plain(spell),
		Plain(cooldownID), Plain(item.auraInstanceID ~= nil), Plain(item:IsShown()), Plain(item.layoutIndex),
		Plain(reach))
end

local layouts -- (each viewer's RefreshLayout count this run)
local hooked = false
local function HookLayouts()
	if hooked then return end
	hooked = true
	for _, name in ipairs(VIEWERS) do
		local viewer = _G[name]
		if viewer and type(viewer.RefreshLayout) == "function" then
			hooksecurefunc(viewer, "RefreshLayout", function()
				if layouts then layouts[name] = (layouts[name] or 0) + 1 end
			end)
		end
	end
end

ns.TestKit.Define({
	name = "cdmround",
	key = "cdmRoundTest",
	title = "Round Cooldown Manager icons",
	about = "Round shape: every CDM icon cut round and cropped, through one fight",
	putBack = function() Shape(nil) return "shape: your own look" end,
	steps = {
		{ key = "round", title = "Round: each icon cut and cropped",
			proven = "2026-11-23 run (14 of 14 icons cropped, log 95a9014a)", run = function(r)
			Shape("round")
			if not AnyShown() then
				r:WaitFor("Show your Cooldown Manager: hit a mob or a target dummy once.", { check = AnyShown })
			end
			r:Sleep(1)
			Shape("round") -- (icons laid out since are dressed too)
			local want = ns.CDM_TRIM or 0.07
			local total, right = ReadAll(r, function(left) return math.abs(left - want) < 0.001 end, "round")
			r:Verdict(total > 0 and right == total, ("round: %d of %d icons cut %.2f in"):format(right, total, want))
		end },
		{ key = "square", title = "Square: the game's crop back",
			proven = "2026-11-23 run (14 of 14 back, log 95a9014a)", run = function(r)
			Shape("square")
			r:Sleep(1)
			local total, right = ReadAll(r, function(left) return left < 0.05 end, "square")
			r:Verdict(total > 0 and right == total, ("square: %d of %d icons back to the game's crop"):format(right, total))
			Shape(nil)
		end },
		{ key = "fight", title = "Round through one fight",
			proven = "2026-11-23 run (3008 checks, 4 Tracked Buffs icons up, 0 not round, log 44510585)",
			run = function(r)
			if not ns.CdmIconState then return r:Fail("no ns.CdmIconState (Action Bar Style not loaded)") end
			Shape("round")
			HookLayouts()
			layouts = {}
			r:WaitFor("Fight a mob for about 20 seconds, so a Tracked Buffs icon lights up (a self-buff or a proc).",
				{ check = function() return UnitAffectingCombat("player") end })
			local started, checks, seen, bad = GetTime(), 0, {}, 0
			local buffChecks, buffIcons = 0, {} -- (the player's case: Tracked Buffs icons up in a fight)
			local stayed = {} -- (an icon still not round on a later check: dressing it again didn't take)
			while UnitAffectingCombat("player") or GetTime() - started < 3 do
				for _, name in ipairs(VIEWERS) do
					local viewer = _G[name]
					for _, entry in ipairs(viewer and viewer:IsVisible() and Icons(viewer) or {}) do
						local item = entry.item
						if item:IsVisible() then
							checks = checks + 1
							if name == "BuffIconCooldownViewer" then
								buffChecks = buffChecks + 1
								buffIcons[item] = true
							end
							local made, masked, cropped, err = ns.CdmIconState(item)
							if not (made and masked and cropped) then
								if not seen[item] then
									seen[item] = true
									bad = bad + 1
									r:Log(("NOT ROUND %s: made %s, masked %s, cropped %s, crop %s; %s; last error %s"):format(
										SHORT[name], tostring(made), tostring(masked), tostring(cropped), Crop(entry.icon),
										Describe(item), tostring(err)))
									local ok, why = pcall(ns.RefreshCooldownShape)
									local made2, masked2, cropped2, err2 = ns.CdmIconState(item)
									r:Log(("  dressed again: %s; made %s, masked %s, cropped %s; last error %s"):format(
										ok and "ran" or ("error " .. tostring(why)), tostring(made2), tostring(masked2),
										tostring(cropped2), tostring(err2)))
									if bad <= 3 then r:Shot("not round " .. SHORT[name], { behind = viewer }) end
								elseif not stayed[item] then
									stayed[item] = true
									r:Log(("  STILL NOT ROUND %s after dressing again: %s"):format(SHORT[name], Describe(item)))
								end
							end
						end
					end
				end
				if GetTime() - started > 120 then break end
				r:Sleep(0.25)
			end
			local counts = {}
			for _, name in ipairs(VIEWERS) do counts[#counts + 1] = SHORT[name] .. " " .. (layouts[name] or 0) end
			r:Log(("fight: %.0f s, %d icon checks, layouts %s"):format(GetTime() - started, checks,
				table.concat(counts, ", ")))
			layouts = nil
			local buffCount = 0
			for _ in pairs(buffIcons) do buffCount = buffCount + 1 end
			r:Log(("Tracked Buffs: %d icon(s) up, %d checks of them"):format(buffCount, buffChecks))
			r:Verdict(checks > 0 and bad == 0, ("fight: %d icon(s) seen not round in %d checks"):format(bad, checks))
			if buffChecks == 0 then
				r:Skip("no Tracked Buffs icon lit up in the fight: the player's case (buff icons square) not covered")
			end
			Shape(nil)
		end },
		{ key = "pandemic", title = "Round: the pandemic border round",
			proven = "2026-11-23 run (border hidden, red glow shown; square back, log eb08fa22)", run = function(r)
			Shape("round")
			-- (Few spells get a pandemic window (a druid's Moonfire, Rejuvenation and
			-- Rake didn't: no pandemicStartTime, run fb33a03e), so the test puts the
			-- border up itself, as the game does (the icon's own
			-- ShowPandemicStateFrame), out of a fight, and takes it down after.
			-- Not fx:IsVisible(): the Cooldown Manager's frames can answer it secret.)
			if UnitAffectingCombat("player") then
				r:WaitFor("Leave the fight for a moment.", { check = function() return not UnitAffectingCombat("player") end })
			end
			local found
			for _, name in ipairs(VIEWERS) do
				local viewer = _G[name]
				for i, entry in ipairs(viewer and Icons(viewer) or {}) do
					local item = entry.item
					if not found and type(item.ShowPandemicStateFrame) == "function" and Plain(item:IsShown()) == "true" then
						found = { item = item, viewer = viewer, name = name, index = i }
					end
				end
			end
			if not found then return r:Skip("no Cooldown Manager icon shown to put the border on") end
			local ok, err = pcall(found.item.ShowPandemicStateFrame, found.item)
			found.fx = rawget(found.item, "PandemicIcon")
			r:Log(("border put up on %s icon %d: %s, PandemicIcon %s"):format(SHORT[found.name], found.index,
				ok and "ok" or ("error " .. tostring(err)), type(found.fx)))
			if type(found.fx) ~= "table" then return r:Fail("the game made no border frame") end
			r:Sleep(0.5)
			local fx, item = found.fx, found.item
			local function Read(label)
				local border = type(fx.Border) == "table" and fx.Border.Border
				local ring = ns.CdmPandemicRing and ns.CdmPandemicRing(fx)
				local iw = item.Icon and select(2, pcall(item.Icon.GetWidth, item.Icon))
				r:Log(("%s %s (%s): border alpha %s, sweep alpha %s, glow %s size %s (icon %s)"):format(label,
					SHORT[found.name], Describe(item), border and Plain(select(2, pcall(border.GetAlpha, border))) or "none",
					fx.FX and Plain(select(2, pcall(fx.FX.GetAlpha, fx.FX))) or "none", ring and Plain(ring:IsShown()) or "none",
					ring and Plain(ring:GetWidth()) or "-", Plain(iw)))
				return border, ring
			end
			-- (An alpha as a plain number, or nil when it errors or reads secret.)
			local function Alpha(region)
				if not region then return nil end
				local ok, alpha = pcall(region.GetAlpha, region)
				if not ok or (issecretvalue and issecretvalue(alpha)) or type(alpha) ~= "number" then return nil end
				return alpha
			end
			local border, ring = Read("round")
			r:Shot("pandemic round", { behind = found.viewer })
			r:Verdict(Alpha(border) == 0 and ring ~= nil and ring:IsShown(),
				"round: the game's square border hidden, our round glow shown")
			-- (Square for a moment, still in the window: the game's own border, to compare colors.)
			Shape("square")
			r:Sleep(1.1)
			if rawget(item, "PandemicIcon") == fx then
				border, ring = Read("square")
				r:Shot("pandemic square (the game's own)", { behind = found.viewer })
				r:Verdict((Alpha(border) or 0) > 0 and not (ring and ring:IsShown()),
					"square: the game's border back, our glow hidden")
			else
				r:Skip("square: the window ended before the square shot")
			end
			pcall(found.item.HidePandemicStateFrame, found.item)
			r:Log("border taken down: PandemicIcon " .. type(rawget(found.item, "PandemicIcon")))
			Shape(nil)
		end },
	},
})
