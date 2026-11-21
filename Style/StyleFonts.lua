-- The fonts text can take on the Style pages, and their files: the game's,
-- ours (Fonts/) and any shared through LibSharedMedia. Out of
-- Visions/QuestItemButton.lua (2026-11-21), where the quest item button's
-- numbers were the first to pick one, so they load with Visions left out
-- (Modules.lua): every Style page's font dropdown uses them.
local ADDON_NAME, ns = ...
local L = ns.L

-- The fonts text can take (game: the action buttons' own).
ns.QUEST_ITEM_FONTS = {
	{ "game", "The game's" },
	{ "friz", "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
	{ "arial", "Arial Narrow", "Fonts\\ARIALN.TTF" },
	{ "morpheus", "Morpheus", "Fonts\\MORPHEUS.TTF" },
	{ "skurri", "Skurri", "Fonts\\SKURRI.TTF" },
}
-- Our own, for the style themes: open fonts, unchanged, each under the SIL Open
-- Font License (Fonts/Licenses, which must ship with them).
for _, font in ipairs({
	{ "marcellus", "Marcellus", "Marcellus-Regular" },
	{ "almendra", "Almendra", "Almendra-Bold" },
	{ "philosopher", "Philosopher", "Philosopher-Regular" },
	{ "cinzel", "Cinzel Decorative", "CinzelDecorative-Regular" },
	{ "germania", "Germania One", "GermaniaOne-Regular" },
	{ "barlow", "Barlow Condensed", "BarlowCondensed-Medium" },
	{ "bebas", "Bebas Neue", "BebasNeue-Regular" },
	{ "rajdhani", "Rajdhani", "Rajdhani-SemiBold" },
	{ "outfit", "Outfit", "Outfit-Medium" },
	{ "outfitbold", "Outfit Bold", "Outfit-Bold" },
	{ "lilita", "Lilita One", "LilitaOne-Regular" },
	{ "titan", "Titan One", "TitanOne-Regular" },
	{ "archivoblack", "Archivo Black", "ArchivoBlack-Regular" },
	{ "damion", "Damion", "Damion-Regular" },
}) do
	ns.QUEST_ITEM_FONTS[#ns.QUEST_ITEM_FONTS + 1] = { font[1], font[2],
		"Interface\\AddOns\\" .. ADDON_NAME .. "\\Fonts\\" .. font[3] .. ".ttf", own = true }
end
local FONT_FILES, OWN_FONTS = {}, {}
for _, font in ipairs(ns.QUEST_ITEM_FONTS) do
	FONT_FILES[font[1]] = font[3]
	OWN_FONTS[font[1]] = font.own
end
ns.OnLanguage(function() ns.QUEST_ITEM_FONTS[1][2] = L["The game's"] end)

-- Fonts other addons share through LibSharedMedia (none of theirs bundled)
-- come after these, as "lsm:<its name>".
local function SharedMedia()
	local stub = _G.LibStub
	return stub and stub("LibSharedMedia-3.0", true)
end

-- Whether a font file has small letters: a font with only capitals (some
-- shared ones) draws every small letter as the same box. So: a-z all one
-- width while A-Z aren't (a fixed-width font has both even), it's capitals
-- only. Cached per file. (Widths kept for /cine debug fonts; refusals
-- counted there too.)
local LOWER, UPPER = "abcdefghijklmnopqrstuvwxyz", "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
local readable, measured, tries, probe = {}, {}, {}, nil
local function Widths(letters)
	local widths, even = {}, true
	for letter in letters:gmatch(".") do
		probe:SetText(letter)
		widths[#widths + 1] = probe:GetStringWidth()
		if math.abs(widths[#widths] - widths[1]) > 0.5 then even = false end
	end
	return widths, even
end
local function Probe()
	if not probe then
		-- (Shown, see-through: the game may not load a font for hidden text.)
		local holder = CreateFrame("Frame", nil, UIParent)
		holder:SetSize(1, 1)
		holder:SetPoint("BOTTOMLEFT")
		holder:SetAlpha(0)
		probe = holder:CreateFontString(nil, "ARTWORK")
		probe:SetPoint("BOTTOMLEFT")
	end
	return probe
end

-- Whether one of our own fonts is there: the game errors on a file it can't
-- find (a new font needs the game restarted), which would stop a page being
-- made. One that isn't: as if it weren't picked, the game's font showing.
local ownLoads = {}
local function OwnLoads(path)
	if ownLoads[path] == nil then
		ownLoads[path] = pcall(Probe().SetFont, Probe(), path, 20, "")
	end
	return ownLoads[path]
end

local function Readable(path)
	if readable[path] ~= nil then return readable[path] end
	Probe()
	local ok, set = pcall(probe.SetFont, probe, path, 20, "")
	if not ok or set == false then
		-- (Refused: not loaded yet, or not there. Kept, uncached, so it's
		-- measured again when next asked; a missing file just shows the
		-- game's font.)
		tries[path] = (tries[path] or 0) + 1
		measured[path] = ("refused %d times, kept"):format(tries[path])
		return true
	end
	local lower, lowerEven = Widths(LOWER)
	local upper, upperEven = Widths(UPPER)
	probe:SetText("")
	readable[path] = not (lowerEven and not upperEven)
	measured[path] = ("a i m %.1f %.1f %.1f, A I M %.1f %.1f %.1f"):format(lower[1], lower[9], lower[13],
		upper[1], upper[9], upper[13])
	return readable[path]
end

-- A shared font's file, whether or not it's readable (nil: no longer there).
local function SharedFile(value)
	local name = type(value) == "string" and value:match("^lsm:(.+)")
	local media = name and SharedMedia()
	if media then
		local ok, path = pcall(media.Fetch, media, "font", name, true)
		if ok and path then return path end
	end
end

-- A font value's file (nil: the game's, or a shared one no longer there or
-- with no small letters).
function ns.StyleFontFile(value)
	if OWN_FONTS[value] then
		return OwnLoads(FONT_FILES[value]) and FONT_FILES[value] or nil
	end
	if FONT_FILES[value] then return FONT_FILES[value] end
	local path = SharedFile(value)
	if path and Readable(path) then return path end
end

-- /cine debug fonts: every font shared through LibSharedMedia, its file, and
-- whether it has small letters (left out of the lists if not).
function ns.ReportStyleFonts()
	local media = SharedMedia()
	if not (media and media.List) then
		ns.Print("Fonts: no LibSharedMedia addon loaded, so only our five.")
		return
	end
	local ok, names = pcall(media.List, media, "font")
	names = ok and names or {}
	-- (All measured again, then again when listed, once the files the game
	-- hadn't loaded have had time to.)
	wipe(readable)
	wipe(tries)
	for _, name in ipairs(names) do
		local path = SharedFile("lsm:" .. name)
		if path then Readable(path) end
	end
	ns.Print("Fonts: measuring, the list in 4 seconds...")
	C_Timer.After(4, function()
		local left = 0
		for _, name in ipairs(names) do
			local path = SharedFile("lsm:" .. name)
			local good = path and Readable(path)
			if not good then left = left + 1 end
			ns.Print(("  %s%s|r %s - %s (%s)"):format(good and "|cff80ff80" or "|cffff6060", name,
				good and "kept" or "LEFT OUT", tostring(path), path and measured[path] or "no file"))
		end
		ns.Print(("Fonts: %d shared, %d left out (no small letters: a-z all one width, A-Z not). Refused: the " ..
			"game wouldn't set it on our measuring text (asked once now, again 4 seconds later)."):format(#names, left))
	end)
end

-- A font value's name, as the lists show it.
function ns.StyleFontName(value)
	for _, info in ipairs(ns.QUEST_ITEM_FONTS) do
		if info[1] == value then return info[2] end
	end
	return type(value) == "string" and value:match("^lsm:(.+)") or tostring(value)
end

-- The list, for a dropdown: { value, text, font } each, ours first, then
-- the shared ones (sorted; any with a file of ours left out). font: its file,
-- to draw the name in (not where the language needs the game's: the pages
-- keep it there).
local ROMAN = not ({ ruRU = true, koKR = true, zhCN = true, zhTW = true })[GetLocale and GetLocale() or ""]
function ns.StyleFontChoices()
	local list, known = {}, {}
	for _, info in ipairs(ns.QUEST_ITEM_FONTS) do
		list[#list + 1] = { value = info[1], text = info[2], font = ROMAN and ns.StyleFontFile(info[1]) or nil }
		if info[3] then known[info[3]:lower()] = true end
	end
	local media = SharedMedia()
	if media and media.List then
		local ok, names = pcall(media.List, media, "font")
		local shared = {}
		for _, name in ipairs(ok and names or {}) do
			local path = ns.StyleFontFile("lsm:" .. name) -- (nil for one with no small letters: left out)
			if path and not known[path:lower()] then
				shared[#shared + 1] = { value = "lsm:" .. name, text = name, font = ROMAN and path or nil }
			end
		end
		table.sort(shared, function(a, b) return a.text:lower() < b.text:lower() end)
		for _, choice in ipairs(shared) do list[#list + 1] = choice end
	end
	return list
end
