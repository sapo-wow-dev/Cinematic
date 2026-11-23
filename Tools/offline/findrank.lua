-- /cine find's ranking and results window (UI/Find.lua's ns.SearchRank and
-- ns.ShowFindResults, Options.lua's index), outside the game, fresh install:
--   python -I Tools/offline/run.py Tools/offline/findrank.lua [client] [toc]
-- 2026-11-23, the user: "/cine find heal vision takes me to what's new", then
-- "vision heal visions takes you to the wheel ... have it display a results
-- page like google has with multiple possible hits, ranked by importance".
-- Checks: a long list of searches and the best match each should give (typos,
-- plurals, words run together or split, other names, a page's place in the
-- menu), every synonym finding something, What's new never first, and the
-- window listing the matches. Says PASS or FAIL per check; exit 1 on a FAIL.
local client, toc = arg[1] or "forever", arg[2] or "CinematicDev.toc"
local ns = dofile("Tools/offline/load.lua")(client, toc)

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local index = ns.BuildSearchIndex()
local function Top(query)
	local results = ns.SearchRank(index, query)
	return results[1], results
end
local function Describe(entry)
	if not entry then return "nothing" end
	return entry.text .. " [" .. (entry.rank == 0 and "page" or entry.page.key or "Cinematic") .. "]"
end

-- 1. Where searches land: { typed, the best match's text, its page's key
-- (or "page": a page itself; or a list of keys, any of them) }.
local LANDS = {
	{ "heal vision", "Heal Vision", "page" }, { "vision heal visions", "Heal Vision", "page" },
	{ "heal visions", "Heal Vision", "page" }, { "visions heal", "Heal Vision", "page" },
	{ "healvision", "Heal Vision", "page" }, { "heal vison", "Heal Vision", "page" },
	{ "hael vision", "Heal Vision", "page" }, { "healing vision", "Heal Vision", "page" },
	{ "nameplates", "Nameplates", "page" }, { "nameplate", "Nameplates", "page" },
	{ "name plates", "Nameplates", "page" }, { "nameplats", "Nameplates", "page" },
	{ "nameplate style", "Nameplate Style", "page" }, { "minimap", "Minimap", "page" },
	{ "mini map", "Minimap", "page" }, { "hide minimap", "Minimap", "page" },
	{ "letterbox", "Letterbox", "page" }, { "letter box", "Letterbox", "page" },
	{ "letterbox size", "Size", { "Letterbox", "Letterbox Style" } }, { "cinematic bars", "Letterbox", "page" },
	{ "shoulder", "Shoulder Cam", "page" }, { "shoulder cam", "Shoulder Cam", "page" },
	{ "camera", "Cameras", "page" }, { "chat", "Chat", "page" }, { "chat bubbles", "Chat Bubbles", "page" },
	{ "bubbles", "Chat Bubbles", "page" }, { "action bars", "Action Bar Style", "page" },
	{ "actionbar", "Action Bar Style", "page" }, { "tooltip", "Tooltips", "page" },
	{ "cursor", "Cursor Hide", "page" }, { "hide cursor", "Cursor Hide", "page" },
	{ "mouse", "Cursor Hide", "page" }, { "cinemode", "CineMode", "page" }, { "cine mode", "CineMode", "page" },
	{ "quest tracker", "Quest Tracker", "page" }, { "quest talk", "Dialogue", "page" },
	{ "dialogue", "Dialogue", "page" }, { "music", "Music", "Audio" }, { "keybinds", "Keybinds", "page" },
	{ "keybind", "Keybinds", "page" }, { "hotkey", "Keybinds", "page" }, { "vision wheel", "Vision Wheel", "page" },
	{ "profiles", "Profiles", "page" }, { "import", "Import", "Profiles" }, { "export", "Export", "Profiles" },
	{ "cooldown manager", "Cooldown Manager", "page" }, { "cdm", "Cooldown Manager", "page" },
	{ "cooldown", "Cooldown Manager", "page" }, { "combat text", "Combat Text Style", "page" },
	{ "buffs", "Buffs/Debuffs", "page" }, { "gamepad", "Gamepad Frames", "page" },
	{ "tint", "Tint", "page" }, { "vignette", "Vignette" },
	{ "effects", "Visual Effects", "page" }, { "graphics", "Graphics Boost", "page" },
	{ "fps", "Graphics Boost", "page" }, { "emote", "Emote Vision", "page" }, { "emotes", "Emote Vision", "page" },
	{ "death", "Death Vision", "page" }, { "teleport", "Teleport Vision", "page" },
	{ "duel", "Duel Vision", "page" }, { "roll", "Roll Vision", "page" }, { "low health", "Vitals Vision", "page" },
	{ "quest vision", "Quest Vision", "page" }, { "raid frames", "Raid Frame Style", "page" },
	{ "unit frames", "Unit Frame Style", "page" }, { "language", "Language" }, { "translation", "Language" },
	{ "how do i hide the minimap", "Minimap", "page" },
}
-- (A page this client hasn't, retail's Gamepad Frames: skipped.)
local pageNames = {}
for _, entry in ipairs(index) do
	if entry.rank == 0 then pageNames[entry.text] = true end
end
for _, case in ipairs(LANDS) do
	local top = Top(case[1])
	if case[3] == "page" and not pageNames[case[2]] then
		print("SKIP " .. case[1] .. ": no " .. case[2] .. " page on " .. client)
		top = nil
	end
	local where = case[3]
	local onPage = type(where) == "table" and top and (function()
		for _, key in ipairs(where) do
			if top.page.key == key then return true end
		end
	end)()
	local ok = top and top.text == case[2] and (not where or onPage
		or (where == "page" and top.rank == 0) or (type(where) == "string" and where ~= "page" and top.page.key == where))
	if not (case[3] == "page" and not pageNames[case[2]]) then
		Check(("%s: %s"):format(case[1], case[2]), ok, Describe(top))
	end
end

-- 2. Never What's new first, for words that are on real settings too.
local NEWS = { ["New features"] = true, ["All changes"] = true }
for _, words in ipairs({ "hide nameplates", "minimap fade", "chat font", "hide tooltip", "nameplate size",
	"zone card", "mana", "heal vision", "nameplate color", "tooltips in combat" }) do
	local top = Top(words)
	Check(words .. ": not What's new", top and not NEWS[top.page.key], Describe(top))
end

-- 3. Every other name for a thing finds something, and not What's new.
for typed in pairs(ns.SEARCH_SYNONYMS) do
	local top = Top(typed)
	Check("synonym " .. typed .. ": finds something", top ~= nil and not NEWS[top.page.key], Describe(top))
end

-- 4. More than one match to pick from, best first.
do
	local _, all = Top("heal")
	Check("heal: many matches", #all >= 5, #all)
	local sorted = true
	for i = 2, #all do
		if all[i].score > all[i - 1].score then sorted = false end
	end
	Check("matches best first", sorted)
end

-- 5. /cine find <words>: the window lists them, the best marked; an id still
-- goes straight to its control, no window; nonsense says nothing's found.
do
	local text, page, results = ns.FindSetting("vision heal visions")
	Check("/cine find words: best returned", text == "Heal Vision" and page == "page",
		tostring(text) .. " " .. tostring(page))
	local rows, count = ns.FindResultsShown()
	Check("/cine find words: window shown", rows ~= nil)
	Check("/cine find words: rows listed", rows and #rows >= 3, rows and #rows)
	Check("/cine find words: best marked", rows and rows[1] and rows[1].kind:find("Best match", 1, true) ~= nil,
		rows and rows[1] and rows[1].kind)
	Check("/cine find words: its place shown", rows and rows[2] and rows[2].where ~= "",
		rows and rows[2] and rows[2].where)
	Check("/cine find words: the count", results and count and count:find(tostring(#results), 1, true) ~= nil, count)
	_G.CinematicFindWindow:Hide()
	text = ns.FindSetting("handleHealVision")
	Check("/cine find an id: straight to it", text ~= nil and not ns.FindResultsShown(), tostring(text))
	ns.FindSetting("zzqqxx")
	local _, none = ns.FindResultsShown()
	Check("/cine find nonsense: says nothing found", none and none:find("Nothing", 1, true) ~= nil, none)
	_G.CinematicFindWindow:Hide()
end

-- 5b. The window's look (the user, 2026-11-23: three "Card Vision" lines,
-- "Page" on every line, no scroll bar, a dull best): every page its own
-- title, a section's other pages folded under its first, keys and a bar.
do
	local titles, same = {}, {}
	for _, entry in ipairs(index) do
		if entry.rank == 0 and entry.title then
			if titles[entry.title] and titles[entry.title] ~= entry.page then same[#same + 1] = entry.title end
			titles[entry.title] = entry.page
		end
	end
	Check("every page its own title", #same == 0, table.concat(same, ", "))
	local top = Top("visions")
	Check("visions: Visions: General first", top and top.title == "Visions: General", top and top.title)
	top = Top("card")
	Check("card: Card Vision first", top and top.title == "Card Vision", top and top.title)

	ns.FindSetting("visions")
	local rows, count, window = ns.FindResultsShown()
	local function Plain(text) return ((text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
	Check("count names the pages", count and count:find("pages", 1, true) ~= nil, count)
	Check("best tinted, only it", rows[1].best and not rows[2].best)
	Check("a page line says no \"Page\"", rows[2] and not Plain(rows[3].kind):find("Page", 1, true), Plain(rows[3].kind))
	Check("every line an icon (its page's)", rows[1].entry.path and rows[1].entry.path.icon ~= nil)
	local fold = rows[2].item
	Check("the section's other pages folded right under its first", fold and fold.members ~= nil
		and fold.section == (rows[1].entry.path.crumbs[1]), Plain(rows[2].label))
	local before = #window.items
	ns.FindResultsKeys.Open(2)
	Check("a click on the fold opens it", #window.items == before + #fold.members, #window.items .. " vs " .. before)
	rows = ns.FindResultsShown()
	Check("its pages listed under it", rows[3].item.inner == true, Plain(rows[3].label))
	ns.FindResultsKeys.Open(2)
	Check("a second click folds it", #window.items == before)
	Check("a scroll bar with more than fits", window.bar:IsShown())
	window.box:GetScript("OnArrowPressed")(window.box, "DOWN")
	window.box:GetScript("OnArrowPressed")(window.box, "DOWN")
	rows = ns.FindResultsShown()
	Check("Down twice picks the third line", window.selected == 3 and rows[3].picked and not rows[1].picked, window.selected)
	window.box:GetScript("OnArrowPressed")(window.box, "UP")
	Check("Up picks the one above", window.selected == 2, window.selected)
	for _ = 1, 15 do window.box:GetScript("OnArrowPressed")(window.box, "DOWN") end
	Check("the picked line kept in view", window.selected > 9 and window.offset > 0, window.selected .. "/" .. window.offset)
	window:Hide()
end

-- 6. The Heal Vision page gone (a left-out part, or not made, as in the
-- user's game, 2026-11-23): still not What's new.
do
	local kept = {}
	for _, entry in ipairs(index) do
		if entry.page.key ~= "Heal Vision" then kept[#kept + 1] = entry end
	end
	local top = ns.SearchRank(kept, "heal vision")[1]
	Check("no Heal Vision page: finds something, not What's new", top and not NEWS[top.page.key], Describe(top))
end

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
