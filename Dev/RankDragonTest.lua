-- /cine debug rankdragon: the elite, rare and boss dragon round a Style
-- theme's portrait (Style/UnitStyle.lua PlaceRank; Discord report 2026-11-23:
-- the rare's silver dragon small and off to the side under a petal portrait).
-- Ledger: Tools/tests/rank-dragon.md. One action: target anything. Steps:
--   1 setup    your theme kept (put back at the end), the Unit Frames Style
--              chain on, a target (anything); the dragon's state kept
--   2 game     no theme: each dragon placed as the game places it; its offset
--              from the portrait's middle logged as the reference (shot each)
--   3 glade    Moonlit Glade (petal, the report's look): each dragon on the
--              portrait's middle, the game's offset grown with the shape (shot each)
--   4 hearth   Hearthside (circle): the same (shot each)
--   5 cathedral Cathedral (arch): the same (shot each)
--   6 slate    Slate (slab: no dragon kept): back on the game's spot, hidden
--   7 back     no theme again: the game's spot and size
-- At the end your theme and the dragon as the game had it are put back.
-- Into CinematicDB.rankDragonTestLog. Dev copy only.
local _, ns = ...

local function Readable(v)
	return v ~= nil and not (issecretvalue and issecretvalue(v))
end
local function N(v) return type(v) == "number" and ("%.1f"):format(v) or tostring(v) end

-- Each dragon as the client's GetBossPortraitFrameData gives it: Forever loads
-- Camelot/TargetFrameUtils.lua, retail Mainline's (rule ui-frames, the target's art).
local DRAGONS = ns.isRetail and {
	{ "rare", "ui-hud-unitframe-target-portraiton-boss-rare-silver", -11, -8 },
	{ "boss", "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged", 8, -8 },
	{ "elite", "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold", -11, -8 },
} or {
	{ "rare", "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Silver-Winged", 8, -7 },
	{ "boss", "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged", 11, -4 },
	{ "elite", "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold", 0, 1 },
}

local function Parts()
	local frame = _G.TargetFrame
	local holder = frame and frame.TargetFrameContainer
	return frame, holder, holder and holder.BossPortraitFrameTexture, frame and (frame.portrait or frame.Portrait)
end

-- What the game had on the dragon before the test, put back after it.
local saved
local function SaveRank(rank)
	local spot = rank:GetNumPoints() > 0 and { rank:GetPoint(1) } or nil
	saved = { atlas = rank:GetAtlas(), shown = rank:IsShown(), spot = spot, w = rank:GetWidth(), h = rank:GetHeight() }
end
local function RestoreRank()
	local _, _, rank = Parts()
	if not (rank and saved) then return "nothing kept" end
	if saved.atlas then rank:SetAtlas(saved.atlas, true) else rank:SetSize(saved.w, saved.h) end
	if saved.spot then
		rank:SetPoint(saved.spot[1], saved.spot[2], saved.spot[3], saved.spot[4], saved.spot[5])
	end
	rank:SetShown(saved.shown)
	return ("dragon back: %s, %s"):format(tostring(saved.atlas), saved.shown and "shown" or "hidden")
end

-- As TargetFrameMixin:CheckClassification places it.
local function GamePlaces(d)
	local _, holder, rank = Parts()
	rank:SetAtlas(d[2], true)
	rank:SetPoint("TOPRIGHT", holder, "TOPRIGHT", d[3], d[4])
	rank:Show()
end
local function AtlasWide(atlas)
	local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
	return info and info.width, info and info.height
end

-- The dragon's middle from the portrait's middle (frame units, both in the container).
local function Measure(r, label)
	local _, _, rank, portrait = Parts()
	local rx, ry = rank:GetCenter()
	local px, py = portrait:GetCenter()
	if not (Readable(rx) and Readable(ry) and Readable(px) and Readable(py)) then
		r:Log(label .. ": places secret")
		return nil
	end
	local p, rel, rp = rank:GetPoint(1)
	local on = rel == portrait and "portrait" or (rel == select(2, Parts()) and "container") or tostring(rel)
	local m = { dx = rx - px, dy = ry - py, w = rank:GetWidth(), h = rank:GetHeight(), pw = portrait:GetWidth(),
		alpha = rank:GetAlpha(), on = on, points = rank:GetNumPoints() }
	r:Log(("%s: dragon %sx%s, middle %s,%s off the portrait's (portrait %s wide); anchored %s %s on %s, %d point(s);"
		.. " alpha %s"):format(label, N(m.w), N(m.h), N(m.dx), N(m.dy), N(m.pw), tostring(p), tostring(rp), on,
		m.points, N(m.alpha)))
	return m
end

local reference = {} -- dragon -> the game look's measure
local function Theme(r, key)
	local ok = ns.ApplyStyleTheme(key, true)
	r:Log(("theme %s applied: %s, target shape %s"):format(key, tostring(ok),
		tostring(ns.UnitFrameLook and (ns.UnitFrameLook("target") or {}).ufShape)))
	r:Sleep(1)
end
local function Ready() return UnitExists("target") and _G.TargetFrame:IsShown() end
local function Settled(r)
	if not Ready() then r:WaitFor("Target anything again (you, a mob, a player).", { check = Ready }) end
	r:Prompt("Nothing to do: the test does this one.")
end

local function ThemeStep(key, name)
	return { key = key, title = name .. ": the dragon round the portrait", run = function(r)
		Settled(r)
		if InCombatLockdown() then
			r:WaitFor("Leave the fight first (a theme can't change in one)", { events = { "PLAYER_REGEN_ENABLED" } })
		end
		Theme(r, key)
		local frame = Parts()
		for _, d in ipairs(DRAGONS) do
			GamePlaces(d)
			r:Sleep(0.3)
			local m = Measure(r, name .. " " .. d[1])
			local ref = reference[d[1]]
			local aw = AtlasWide(d[2])
			if m and ref and aw then
				local k = m.w / aw
				r:Verdict(m.on == "portrait" and m.points == 1, d[1] .. ": hung on the portrait, one point")
				r:Verdict(k > 1 and m.w >= ref.w * (m.pw / ref.pw) - 0.5,
					("%s: grown with the portrait: x%.3f (portrait x%.3f)"):format(d[1], k, m.pw / ref.pw))
				r:Verdict(math.abs(m.dx - ref.dx * k) < 0.5 and math.abs(m.dy - ref.dy * k) < 0.5,
					("%s: as far off the portrait's middle as the game's, grown: %s,%s vs %s,%s"):format(d[1],
						N(m.dx), N(m.dy), N(ref.dx * k), N(ref.dy * k)))
			else
				r:Fail(d[1] .. ": couldn't measure (no game reference or atlas size)")
			end
			r:Shot(name .. " " .. d[1], { behind = frame })
		end
	end }
end

ns.TestKit.Define({
	name = "rankdragon",
	key = "rankDragonTest",
	title = "Elite and rare dragon on a theme's portrait",
	about = "the elite, rare and boss dragon sits round a Style theme's portrait and grows with it",
	needs = "Any target, out of a fight",
	settings = { "styleGeneral", "ufStyle" },
	cvars = { "uiScale", "useUiScale" },
	context = function()
		local frame, _, rank, portrait = Parts()
		return ("TargetFrame scale %s; portrait %s; dragon %s; theme %s"):format(tostring(frame and frame:GetScale()),
			tostring(portrait and portrait:GetWidth()), tostring(rank and rank:GetAtlas()), tostring(ns.db.styleTheme))
	end,
	putBack = function(extra)
		local kept = extra.themeKept
		if InCombatLockdown() then return "in a fight: not put back, /cine debug rankdragon restore after it" end
		local line = "no theme kept"
		if type(kept) == "table" then
			ns.RestoreStyleSnapshot(kept)
			line = "your theme back to " .. tostring(kept.styleTheme)
		end
		return line .. "; " .. RestoreRank()
	end,
	steps = {
		{ key = "setup", title = "your theme kept, a target", run = function(r)
			if InCombatLockdown() then
				r:WaitFor("Leave the fight first (a theme can't change in one)", { events = { "PLAYER_REGEN_ENABLED" } })
			end
			r:Keep("themeKept", ns.StyleSnapshot())
			r:Log("your theme kept: " .. tostring(ns.db.styleTheme))
			local key = "ufStyle"
			while key do
				if not ns.db[key] then r:Set(key, true) end
				key = ns.PageSwitchOf(key)
			end
			r:Verdict(ns.StyleOn("ufStyle"), "Unit Frames Style on with its chain")
			if not Ready() then
				r:WaitFor("Target anything (you, a mob, a player): the test shows each dragon on your target frame.",
					{ check = Ready })
			end
			local _, _, rank, portrait = Parts()
			r:Verdict(rank ~= nil and portrait ~= nil, "the target frame has the dragon and the portrait")
			SaveRank(rank)
			r:Log(("dragon as the game had it: %s, %s"):format(tostring(saved.atlas), saved.shown and "shown" or "hidden"))
			for _, d in ipairs(DRAGONS) do
				local w, h = AtlasWide(d[2])
				r:Log(("%s atlas %s: %sx%s"):format(d[1], d[2], N(w), N(h)))
			end
		end },
		{ key = "game", title = "no theme: the game's spot, the reference", run = function(r)
			Settled(r)
			Theme(r, "game")
			local frame = Parts()
			for _, d in ipairs(DRAGONS) do
				GamePlaces(d)
				r:Sleep(0.3)
				local m = Measure(r, "game " .. d[1])
				reference[d[1]] = m
				local aw = AtlasWide(d[2])
				r:Verdict(m and m.on == "container" and aw and math.abs(m.w - aw) < 0.5,
					d[1] .. ": on the container at atlas size, as the game has it")
				r:Shot("game " .. d[1], { behind = frame })
			end
		end },
		ThemeStep("glade", "Moonlit Glade"),
		ThemeStep("hearth", "Hearthside"),
		ThemeStep("cathedral", "Cathedral"),
		{ key = "slate", title = "Slate (slab): the dragon not kept", run = function(r)
			Settled(r)
			Theme(r, "slate")
			GamePlaces(DRAGONS[1])
			r:Sleep(0.3)
			local m = Measure(r, "slate rare")
			local ref = reference.rare
			r:Verdict(m and ref and m.on == "container" and math.abs(m.dx - ref.dx) < 0.5 and math.abs(m.dy - ref.dy) < 0.5,
				"slab: the game's spot")
			r:Verdict(m and m.alpha < 0.01, "slab: hidden with the frame art")
		end },
		{ key = "back", title = "no theme again: the game's spot and size", run = function(r)
			Settled(r)
			Theme(r, "game")
			GamePlaces(DRAGONS[1])
			r:Sleep(0.3)
			local m = Measure(r, "back rare")
			local ref = reference.rare
			r:Verdict(m and ref and m.on == "container" and math.abs(m.dx - ref.dx) < 0.5 and math.abs(m.dy - ref.dy) < 0.5
				and math.abs(m.w - ref.w) < 0.5, "back on the game's spot at its size")
			r:Verdict(m and m.alpha > 0.99, "shown again")
			r:Shot("back to the game's look", { behind = Parts() })
		end },
	},
})
