-- /cine find and the settings search: every match ranked by how well it fits
-- (ns.SearchRank), and the results window listing them to pick from
-- (ns.ShowFindResults), like a web search's page. 2026-11-23, the user:
-- "/cine find vision heal visions takes you to the wheel" - every word had to
-- be in one label, as typed, and the first such text won (a long tooltip
-- often). Now each word is matched on its own (whole, plural, a word's start,
-- a typo, words run together, a few other names for things: black bars is
-- the letterbox), on the control's label, its tooltip and its page's place in
-- the menu (letterbox size: the Letterbox page's Size), and what it is counts
-- (a page or a switch before a note; What's new last). Tools/offline/findrank.lua
-- checks where a long list of searches lands.
local _, ns = ...
local L = ns.L

-- Names that say nothing alone: a page's title gets its section's before
-- them (Visions: General), and then they don't count against it being
-- "just the words" (visions: Visions: General first).
local GENERIC = { general = true, settings = true }

-- Words that say nothing about where (how do I hide the minimap).
local STOP = { a = true, an = true, the = true, of = true, to = true, ["for"] = true, ["in"] = true,
	on = true, at = true, by = true, is = true, it = true, my = true, me = true, i = true, how = true,
	["do"] = true, can = true, with = true, ["and"] = true, ["or"] = true, from = true, this = true,
	that = true, when = true, what = true, where = true, your = true, you = true }

-- Other names for things, as typed (lower case) to the words the settings use.
local SYNONYMS = {
	["black bars"] = { "letterbox" }, ["cinematic bars"] = { "letterbox" }, ["taxi"] = { "flight" },
	["hotkey"] = { "keybind" }, ["hotkeys"] = { "keybinds" }, ["key bind"] = { "keybind" },
	["key binds"] = { "keybinds" }, ["binding"] = { "keybind" }, ["bindings"] = { "keybinds" },
	["cdm"] = { "cooldown manager" }, ["controller"] = { "gamepad" }, ["mouse"] = { "cursor" },
	["fps"] = { "graphics" }, ["performance"] = { "graphics" },
	["floating text"] = { "combat text" }, ["damage numbers"] = { "combat text" },
	["scrolling text"] = { "combat text" }, ["xp"] = { "experience" }, ["exp"] = { "experience" },
	["rep"] = { "reputation" }, ["hp"] = { "health" }, ["mp"] = { "mana" },
	["dof"] = { "depth of field" }, ["blur"] = { "depth of field" },
	["translation"] = { "language" }, ["locale"] = { "language" },
	["plates"] = { "nameplates" }, ["plate"] = { "nameplate" }, ["tracker"] = { "quest tracker" },
	["auras"] = { "buffs" }, ["aura"] = { "buff" }, ["red screen"] = { "vitals" },
	["low health"] = { "vitals vision" },
}
ns.SEARCH_SYNONYMS = SYNONYMS -- (the offline check: each one finds something)

-- What a match's place is worth: a page itself, a control's label, a long
-- text (a note, a paragraph), a tooltip; per word, as well as it matched.
local FIELD = { [0] = 10, [1] = 10, [2] = 10, [3] = 4 }
local TIP, PATH, MISSING = 2, 6, 6
local KINDS = { CheckButton = "Switch", Slider = "Slider", EditBox = "Box", Button = "Button" }

local function Tokens(text, list)
	list = list or {}
	if type(text) ~= "string" then return list end
	for word in text:lower():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gmatch("[^%s%p]+") do
		list[#list + 1] = word
	end
	return list
end

-- A word without its ending (nameplates, vision's): for plurals and the like.
local function Stem(word)
	local n = #word
	if n > 4 and word:sub(-3) == "ies" then return word:sub(1, -4) .. "y" end
	if n > 5 and word:sub(-3) == "ing" then return word:sub(1, -4) end
	if n > 4 and word:sub(-2) == "es" and word:sub(-3, -3):find("[sxzh]") then return word:sub(1, -3) end
	if n > 3 and word:sub(-1) == "s" and word:sub(-2, -2) ~= "s" then return word:sub(1, -2) end
	if n > 4 and word:sub(-2) == "ed" then return word:sub(1, -3) end
	return word
end

-- Letters changed, added, dropped or swapped between a and b, up to most
-- (more: most + 1).
local function Distance(a, b, most)
	local la, lb = #a, #b
	if math.abs(la - lb) > most then return most + 1 end
	local prev2, prev = nil, {}
	for j = 0, lb do prev[j] = j end
	for i = 1, la do
		local row = { [0] = i }
		local low = i
		local ca = a:byte(i)
		for j = 1, lb do
			local cost = ca == b:byte(j) and 0 or 1
			local v = math.min(prev[j] + 1, row[j - 1] + 1, prev[j - 1] + cost)
			if prev2 and i > 1 and j > 1 and ca == b:byte(j - 1) and a:byte(i - 1) == b:byte(j) then
				v = math.min(v, prev2[j - 2] + 1)
			end
			row[j] = v
			if v < low then low = v end
		end
		if low > most then return most + 1 end
		prev2, prev = prev, row
	end
	return prev[lb]
end

-- How well a typed word fits one of the text's words: 1 the same, 0.95 a
-- plural or other ending, 0.75 its start, 0.6 a typo, 0.4 inside it, 0 not.
-- (sw, st: their stems, when known.)
local function Fit(word, token, sw, st)
	if word == token then return 1 end
	sw, st = sw or Stem(word), st or Stem(token)
	if sw == st then return 0.95 end
	local n = #word
	if n >= 3 and token:sub(1, n) == word then return 0.75 end
	-- (A typo: from 5 letters, one change, from 8 two, starting as typed
	-- or with its first two swapped; at 4, two letters swapped only: zone
	-- isn't none, size isn't side.)
	local m = #token
	if n >= 4 and m >= 4 and (word:byte(1) == token:byte(1)
		or word:byte(1) == token:byte(2) and word:byte(2) == token:byte(1)) then
		if n >= 5 then
			local most = n >= 8 and 2 or 1
			if Distance(sw, st, most) <= most then return 0.6 end
		elseif n == m then
			local diff = {}
			for i = 1, n do
				if word:byte(i) ~= token:byte(i) then diff[#diff + 1] = i end
			end
			if #diff == 2 and diff[2] == diff[1] + 1 and word:byte(diff[1]) == token:byte(diff[2])
				and word:byte(diff[2]) == token:byte(diff[1]) then
				return 0.6
			end
		end
	end
	if n >= 4 and token:find(word, 1, true) then return 0.4 end
	return 0
end

-- The words of each entry and page, once per index: a text's words and each
-- two run together (heal vision: healvision), so either way of typing fits.
local function WordList(text)
	local list = Tokens(text)
	local count = #list
	for i = 1, count - 1 do list[#list + 1] = list[i] .. list[i + 1] end
	list.count = count -- (its own words: the run-together ones after)
	return list
end
-- A page's title in the results: its name, unless another page has it too
-- (a tab's page takes its page's: Card Vision's Settings tab, the Style
-- hub's Card Types), then the name its menu line or icon shows; a name that
-- says nothing alone (General, Settings) after its section's: Visions:
-- General.
local function PageTitle(entry, path, nameCount)
	local crumbs = path.crumbs or {}
	local title = entry.text
	if (nameCount[entry.text] or 0) > 1 and crumbs[#crumbs] then title = crumbs[#crumbs] end
	if GENERIC[title:lower()] and #crumbs >= 2 and crumbs[#crumbs - 1] ~= title then
		return crumbs[#crumbs - 1] .. ": " .. title, { [title:lower()] = true }
	end
	return title, nil
end
local function Prepare(index)
	if index.prepared then return end
	index.prepared = true
	local vocab, pages, nameCount, counted = {}, {}, {}, {}
	local function Add(list)
		for _, token in ipairs(list) do
			if not vocab[token] then vocab[token] = Stem(token) end
		end
	end
	for _, entry in ipairs(index) do
		if entry.rank == 0 and not counted[entry.page] then
			counted[entry.page] = true
			nameCount[entry.text] = (nameCount[entry.text] or 0) + 1
		end
	end
	-- Pages' titles; one still the same as another's (Atmosphere's Letterbox
	-- and Style's) after its section's: Style: Letterbox.
	local titles = {}
	for _, entry in ipairs(index) do
		if entry.rank == 0 then
			local path = ns.PagePath and ns.PagePath(entry.page.key) or { crumbs = {} }
			entry.title, entry.skipWords = PageTitle(entry, path, nameCount)
			titles[entry.title] = (titles[entry.title] or 0) + 1
		end
	end
	for _, entry in ipairs(index) do
		if entry.rank == 0 and titles[entry.title] > 1 then
			local crumbs = (ns.PagePath and ns.PagePath(entry.page.key) or { crumbs = {} }).crumbs
			if crumbs[1] and crumbs[1] ~= entry.title then
				entry.skipWords = entry.skipWords or {}
				for _, token in ipairs(Tokens(crumbs[1])) do entry.skipWords[token] = true end
				entry.title = crumbs[1] .. ": " .. entry.title
			end
		end
	end
	for _, entry in ipairs(index) do
		entry.words = WordList(entry.rank == 0 and entry.title or entry.text)
		-- (A page itself: its title's words; its English name and its icon's
		-- fit too, Quest Talk Style's shown as Dialogue; its title alone counts
		-- as "just that", so Cameras before Camera Scripts.)
		if entry.rank == 0 then
			-- (skipWords, set above: a word in the title that isn't the page's
			-- own name, not counted against it being "just the words".)
			entry.otherNames = WordList(entry.text .. " " .. (entry.page.key or "") .. " "
				.. (ns.PageLabel and ns.PageLabel(entry.page.key or "Cinematic") or ""))
			Add(entry.otherNames)
		end
		entry.tipWords = entry.tip and WordList(entry.tip) or nil
		local page = entry.page
		if not pages[page] then
			local path = ns.PagePath and ns.PagePath(page.key) or { words = {}, crumbs = {} }
			local list = {}
			for _, text in ipairs(path.words) do
				for _, token in ipairs(WordList(text)) do list[#list + 1] = token end
			end
			for _, token in ipairs(WordList(page.name)) do list[#list + 1] = token end
			pages[page] = { words = list, path = path }
			Add(list)
		end
		entry.pathWords, entry.path = pages[page].words, pages[page].path
		Add(entry.words)
		if entry.tipWords then Add(entry.tipWords) end
	end
	index.vocab = vocab
end

-- The typed words' fit against every word the settings use, once a search.
local function Fits(index, words)
	local fits = index.fits or {}
	index.fits = fits -- (the same word typed again, as you go: done once)
	for _, word in ipairs(words) do
		if not fits[word] then
			local each, stem = {}, Stem(word)
			for token, tokenStem in pairs(index.vocab) do
				local fit = Fit(word, token, stem, tokenStem)
				if fit > 0 then each[token] = fit end
			end
			fits[word] = each
		end
	end
	return fits
end

-- The typed words, and other ways to read them (a synonym in place of what
-- it names, two words run together): { words, worth } each.
local function Readings(query)
	local words = {}
	for _, word in ipairs(Tokens(query)) do
		if not STOP[word] then words[#words + 1] = word end
	end
	if #words == 0 then words = Tokens(query) end
	local readings = { { words = words, worth = 1 } }
	local function Swap(from, to, count, worth)
		local list = {}
		for i = 1, from - 1 do list[#list + 1] = words[i] end
		for _, word in ipairs(to) do list[#list + 1] = word end
		for i = from + count, #words do list[#list + 1] = words[i] end
		readings[#readings + 1] = { words = list, worth = worth }
	end
	for i = 1, #words do
		for count = 2, 1, -1 do
			if i + count - 1 <= #words then
				local phrase = table.concat(words, " ", i, i + count - 1)
				for _, other in ipairs(SYNONYMS[phrase] or {}) do
					if #readings < 8 then Swap(i, Tokens(other), count, 0.9) end
				end
			end
		end
		-- (Run together, worth more: name plates is Nameplates, not a page
		-- with name in one name and plates in another.)
		if i < #words and #readings < 8 then Swap(i, { words[i] .. words[i + 1] }, 2, 1.25) end
	end
	return readings
end

-- One word's best fit in a list of the text's words (and which one).
local function Best(fit, list)
	local best, at = 0, nil
	if not list then return 0 end
	for i, token in ipairs(list) do
		local value = fit[token]
		if value and value > best then best, at = value, i end
	end
	return best, at
end

-- An entry's score for one reading (nil: it doesn't fit), and the typed
-- words its label has.
local function Score(entry, reading, fits)
	local words = reading.words
	local total, matched, own, labelHit = 0, 0, false, false
	local covered = {}
	local hits = {}
	for _, word in ipairs(words) do
		local fit = fits[word]
		local label, at = Best(fit, entry.words)
		if entry.otherNames then
			local other = Best(fit, entry.otherNames)
			if other > label then label, at = other, nil end
		end
		local tip = Best(fit, entry.tipWords)
		local path = Best(fit, entry.pathWords)
		local value = math.max(label * (FIELD[entry.rank] or 4), tip * TIP, path * PATH)
		if value > 0 then
			total, matched = total + value, matched + 1
			if label >= 0.6 or tip >= 0.6 then own = true end
			if label >= 0.6 then
				labelHit = true
				hits[#hits + 1] = word
				if at then
					local list, count = entry.words, entry.words.count
					if at > count then -- (two run together: both)
						covered[list[at - count]], covered[list[at - count + 1]] = true, true
					else
						covered[list[at]] = true
					end
				end
			end
		else
			total = total - MISSING
		end
	end
	-- (Its own text has a word, and at least half of them are found.)
	if not own or matched * 2 < #words then return nil end
	-- (Every word found: worth most when they're in its label, not its tooltip.)
	if matched == #words then total = total + 4 + 4 * #hits / #words end
	-- (A label that's just the words before a long one that has them too.)
	local size, kept, counted = 0, 0, {}
	for i = 1, entry.words.count do
		local token = entry.words[i]
		if not STOP[token] and not (entry.skipWords and entry.skipWords[token]) and not counted[token] then
			counted[token] = true
			size = size + 1
			if covered[token] then kept = kept + 1 end
		end
	end
	if size > 0 then total = total + 6 * kept / size end
	-- What it is: a page, a control, a long text; a tooltip's word only;
	-- inside a tab or section that isn't open; a dev page; What's new.
	if entry.rank == 0 then total = total + 8
	elseif entry.rank == 1 then total = total + 2
	elseif entry.rank == 3 then total = total - 3 end
	if not labelHit then total = total - 2 end
	if entry.buried then total = total - 1 end
	if entry.path and entry.path.dev then total = total - 15 end
	if entry.news then total = total - 25 end
	return total * reading.worth, hits
end

-- Every entry of index that fits query, best first, each with .score and
-- .hits (the typed words in its label). (Its own fields set: the search box
-- and the results window share the entries.)
function ns.SearchRank(index, query)
	if type(query) ~= "string" or not index then return {} end
	Prepare(index)
	local readings = Readings(query)
	local all = {}
	for _, reading in ipairs(readings) do
		for _, word in ipairs(reading.words) do all[#all + 1] = word end
	end
	local fits = Fits(index, all)
	local matches = {}
	for _, entry in ipairs(index) do
		local best, bestHits = nil, nil
		for _, reading in ipairs(readings) do
			local score, hits = Score(entry, reading, fits)
			if score and (not best or score > best) then best, bestHits = score, hits end
		end
		if best and best > 0 then
			entry.score, entry.hits = best, bestHits
			matches[#matches + 1] = entry
		end
	end
	table.sort(matches, function(a, b)
		if a.score ~= b.score then return a.score > b.score end
		if a.rank ~= b.rank then return a.rank < b.rank end
		return a.order < b.order
	end)
	return matches
end

-- What a match is, for its line: Page, Switch, Slider, ...
function ns.SearchKind(entry)
	if entry.rank == 0 then return L["Page"] end
	if entry.rank == 3 then return L["Note"] end
	return entry.kind and KINDS[entry.kind] and L[KINDS[entry.kind]] or L["Setting"]
end

-- ---------------------------------------------------------------------------
-- The results window: one line a match (its page's icon, its name with the
-- typed words picked out, what it is, its place in the menu and what it
-- does), the best tinted; a section's other pages folded into one line
-- (Visions: 6 more pages) that opens on a click; a scroll bar; Up and Down
-- pick a line, Enter opens it. (The user, 2026-11-23, of the first look:
-- three "Card Vision" lines, "Page" on every line, no way to see more.)

local ROWS, ROW_H, TOP = 9, 46, 94
local window

-- text with the typed words picked out (gold), the rest white.
local function Marked(text, hits)
	if #text > 90 then text = text:sub(1, 87) .. "..." end
	local out = text:gsub("[^%s%p]+", function(word)
		local lower = word:lower()
		-- (A word's start only when it's most of it: heal isn't picked out in
		-- health.)
		for _, hit in ipairs(hits or {}) do
			local fit = Fit(hit, lower)
			if fit >= 0.95 or fit == 0.6 or fit == 0.75 and #hit >= #lower * 0.7 then
				return "|cffffd100" .. word .. "|r"
			end
		end
	end)
	return out
end

-- One line of text from a long one (an intro, a tooltip), cut to fit.
local function Snippet(text, most)
	if type(text) ~= "string" then return nil end
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%s+", " "):match("^%s*(.-)%s*$")
	if text == "" then return nil end
	if #text > most then text = text:sub(1, most - 3) .. "..." end
	return text
end

-- The lines to show: each match, but a section's pages after its first
-- folded into one line right under that first (opened: listed under it).
local function Items(results, opened)
	local items, folds = {}, {}
	for _, entry in ipairs(results) do
		local crumbs = entry.path and entry.path.crumbs or {}
		local section = entry.rank == 0 and #crumbs >= 2 and crumbs[1] or nil
		if not section then
			items[#items + 1] = { entry = entry }
		elseif not folds[section] then
			folds[section] = { section = section, members = {} }
			items[#items + 1] = { entry = entry, leads = folds[section] }
		else
			local members = folds[section].members
			members[#members + 1] = entry
		end
	end
	local list = {}
	for _, item in ipairs(items) do
		list[#list + 1] = item
		local fold = item.leads
		if fold and #fold.members == 1 then
			list[#list + 1] = { entry = fold.members[1] }
		elseif fold and #fold.members > 1 then
			list[#list + 1] = fold
			if opened[fold.section] then
				for _, entry in ipairs(fold.members) do list[#list + 1] = { entry = entry, inner = true } end
			end
		end
	end
	return list
end

local function Rebuild()
	window.items = Items(window.results or {}, window.opened)
end

-- One line's look for item (a match, or a section's folded pages).
local function DrawRow(row, item, index)
	local entry = item.entry or item.members[1]
	local path = entry.path or {}
	local crumbs = path.crumbs or {}
	local faint = entry.rank ~= 0 or item.members ~= nil
	-- (A page with no menu icon of its own, Keybinds or Profiles: Cinematic's.)
	row.icon:SetTexture(path.icon or "Interface\\Icons\\INV_Misc_Spyglass_03")
	row.icon:SetDesaturated(faint)
	row.icon:SetAlpha(faint and 0.55 or 1)
	row.icon:ClearAllPoints()
	row.icon:SetPoint("LEFT", item.inner and 22 or 6, 0)
	local kind, where, about = ""
	if item.members then
		local names = {}
		for n, member in ipairs(item.members) do
			if n > 4 then
				names[#names + 1] = "..."
				break
			end
			names[#names + 1] = member.title or member.text
		end
		row.label:SetText("|cffd0d0d0" .. L["%s: %d more pages"]:format(item.section, #item.members) .. "|r")
		kind = window.opened[item.section] and L["Hide"] or L["Show"]
		where = table.concat(names, ", ")
	elseif entry.rank == 0 then
		-- (A page: its place above it, and what it's for: its intro.)
		row.label:SetText(Marked(entry.title or entry.text, entry.hits))
		-- (Above it, less what its title already says: Visions: General.)
		local above, prefix = {}, entry.title and entry.title:match("^(.-): ")
		for n = 1, #crumbs - 1 do
			if crumbs[n] ~= prefix then above[#above + 1] = crumbs[n] end
		end
		where = table.concat(above, " > ")
		local content = entry.page.canvas and entry.page.canvas.content
		about = Snippet(content and content.introText, 90)
	else
		row.label:SetText(Marked(entry.title or entry.text, entry.hits))
		where = table.concat(crumbs, " > ")
		if where == "" then where = entry.page.name or "Cinematic" end
		about = Snippet(entry.tipText, 80)
		kind = ns.SearchKind(entry)
		local value = entry.settingKey and ns.db and ns.db[entry.settingKey]
		if type(value) == "boolean" then
			kind = kind .. "  " .. (value and ("|cff40ff40" .. L["On"] .. "|r") or ("|cff808080" .. L["Off"] .. "|r"))
		end
	end
	if index == 1 then kind = "|cffffd100" .. L["Best match"] .. "|r" .. (kind ~= "" and ("  " .. kind) or "") end
	row.kind:SetText(kind)
	local line = where ~= "" and ("|cff9a9a9a" .. where .. "|r") or ""
	-- (Brighter on the best's gold tint: grey on it was hard to read.)
	if about then
		line = line .. (line ~= "" and "   " or "") .. (index == 1 and "|cffb0b0b0" or "|cff707070") .. about .. "|r"
	end
	row.where:SetText(line)
	row.best:SetShown(index == 1)
	row.picked:SetShown(index == window.selected)
end

local function Draw()
	local items, offset = window.items or {}, window.offset
	window.drawing = true
	for i = 1, ROWS do
		local row, item = window.rows[i], items[offset + i]
		row.item, row.index = item, offset + i
		row.entry = item and item.entry
		if item then
			DrawRow(row, item, offset + i)
			row:Show()
		else
			row:Hide()
		end
	end
	-- The count: matches and how many are pages.
	local results = window.results or {}
	local pages = 0
	for _, entry in ipairs(results) do
		if entry.rank == 0 then pages = pages + 1 end
	end
	if #results == 0 then
		window.count:SetText(L["Nothing found. Try fewer or other words."])
	else
		window.count:SetText(L["%d matches, %d pages"]:format(#results, pages) ..
			"   |cff808080" .. L["Up and Down pick, Enter opens"] .. "|r")
	end
	-- The scroll bar: there only with more than fits, its thumb the part shown.
	local most = math.max(0, #items - ROWS)
	local bar = window.bar
	bar:SetShown(most > 0)
	if most > 0 then
		bar:SetMinMaxValues(0, most)
		bar:SetValue(offset)
		bar.thumb:SetHeight(math.max(24, (bar:GetHeight() or 0) * ROWS / #items))
	end
	window.drawing = nil
end

-- The picked line kept in view.
local function Pick(index)
	local count = window.items and #window.items or 0
	if count == 0 then return end
	index = math.max(1, math.min(index, count))
	window.selected = index
	if index <= window.offset then window.offset = index - 1 end
	if index > window.offset + ROWS then window.offset = index - ROWS end
	Draw()
end

-- The words in the box, ranked again (as typed: a moment after the last key).
local function Search()
	local query = (window.box:GetText() or ""):gsub("|+", " "):match("^%s*(.-)%s*$")
	window.offset, window.selected, window.query = 0, 1, query
	if query == "" then
		window.results = {}
	else
		window.index = window.index or (ns.BuildSearchIndex and ns.BuildSearchIndex())
		window.results = ns.SearchRank(window.index, query)
	end
	window.opened = {}
	Rebuild()
	Draw()
end

-- (Opening the settings hides every UISpecialFrames window, this one too:
-- engine rule all.settings.open-closes-special-frames. Shown again, it
-- docks beside them, its matches still listed to try the next.)
local function Open(item)
	if not item then return end
	if item.members then -- (a folded section: opened or closed)
		window.opened[item.section] = not window.opened[item.section] or nil
		Rebuild()
		Draw()
		return
	end
	ns.ShowSearchMatch(item.entry)
	if window:IsShown() then window:Hide() end
	window:Show()
	Draw()
end

local function MakeRow(i)
	local row = CreateFrame("Button", nil, window)
	row:SetHeight(ROW_H - 4)
	row:SetPoint("TOPLEFT", 14, -TOP - (i - 1) * ROW_H)
	row:SetPoint("RIGHT", -26, 0)
	row.best = row:CreateTexture(nil, "BACKGROUND")
	row.best:SetAllPoints()
	row.best:SetColorTexture(1, 0.82, 0, 0.08)
	row.picked = row:CreateTexture(nil, "BORDER")
	row.picked:SetAllPoints()
	row.picked:SetColorTexture(1, 1, 1, 0.1)
	local hl = row:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.06)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(30, 30)
	row.icon:SetPoint("LEFT", 6, 0)
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.label:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 1)
	row.label:SetPoint("RIGHT", -130, 0)
	row.label:SetJustifyH("LEFT")
	row.label:SetWordWrap(false)
	row.kind = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.kind:SetPoint("TOPRIGHT", -6, -6)
	row.kind:SetJustifyH("RIGHT")
	row.where = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.where:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -5)
	row.where:SetPoint("RIGHT", -6, 0)
	row.where:SetJustifyH("LEFT")
	row.where:SetWordWrap(false)
	row:SetScript("OnClick", function(self)
		window.selected = self.index
		Open(self.item)
	end)
	return row
end

local function MakeScrollBar()
	local bar = CreateFrame("Slider", nil, window)
	bar:SetOrientation("VERTICAL")
	bar:SetPoint("TOPRIGHT", -12, -TOP)
	bar:SetPoint("BOTTOMRIGHT", -12, 14)
	bar:SetWidth(6)
	local track = bar:CreateTexture(nil, "BACKGROUND")
	track:SetAllPoints()
	track:SetColorTexture(1, 1, 1, 0.06)
	local thumb = bar:CreateTexture(nil, "OVERLAY")
	thumb:SetColorTexture(1, 0.82, 0, 0.5)
	thumb:SetSize(6, 40)
	bar:SetThumbTexture(thumb)
	bar.thumb = thumb
	bar:SetValueStep(1)
	if bar.SetObeyStepOnDrag then bar:SetObeyStepOnDrag(true) end
	bar:SetScript("OnValueChanged", function(_, value)
		if window.drawing then return end
		window.offset = math.floor(value + 0.5)
		Draw()
	end)
	return bar
end

local function Window()
	if window then return window end
	window = CreateFrame("Frame", "CinematicFindWindow", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	window:SetSize(580, TOP + ROWS * ROW_H + 10)
	window:SetPoint("CENTER")
	window:SetFrameStrata("DIALOG")
	window:SetToplevel(true)
	window:EnableMouse(true)
	if window.SetBackdrop then
		window:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 24,
			insets = { left = 6, right = 6, top = 6, bottom = 6 } })
	end
	if ns.SkinWindow then ns.SkinWindow(window) end
	tinsert(UISpecialFrames, "CinematicFindWindow")
	ns.DockBeside(window, "find")
	window:Hide()
	window.opened = {}
	local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -4, -4)
	if ns.SkinClose then ns.SkinClose(close) end

	local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 18, -16)
	title:SetText(L["Search Cinematic"])

	local ok, box = pcall(CreateFrame, "EditBox", nil, window, "SearchBoxTemplate")
	if not ok or not box then box = ns.SkinEditBox(CreateFrame("EditBox", nil, window, "InputBoxTemplate")) end
	box:SetSize(420, 22)
	box:SetPoint("TOPLEFT", 22, -44)
	box:SetAutoFocus(false)
	if box.SetAltArrowKeyMode then box:SetAltArrowKeyMode(false) end -- (Up and Down come to it)
	window.box = box
	local typed = 0
	box:HookScript("OnTextChanged", function(_, userInput)
		if not userInput then return end
		typed = typed + 1
		local mine = typed
		C_Timer.After(0.25, function()
			if mine == typed and window:IsShown() then Search() end
		end)
	end)
	box:HookScript("OnArrowPressed", function(_, key)
		if key == "UP" then Pick((window.selected or 1) - 1)
		elseif key == "DOWN" then Pick((window.selected or 0) + 1) end
	end)
	box:HookScript("OnTabPressed", function() Pick((window.selected or 0) + 1) end)
	box:HookScript("OnEnterPressed", function(self)
		-- (New words: ranked first, then the best opened; the same: the picked one.)
		local query = (self:GetText() or ""):gsub("|+", " "):match("^%s*(.-)%s*$")
		if query ~= window.query then Search() end
		local item = window.items and window.items[window.selected or 1]
		if not (item and item.members) then self:ClearFocus() end
		Open(item)
	end)
	box:HookScript("OnEscapePressed", function() window:Hide() end)

	window.count = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	window.count:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -4, -8)

	window.rows = {}
	for i = 1, ROWS do window.rows[i] = MakeRow(i) end
	window.bar = MakeScrollBar()

	window.offset = 0
	window:EnableMouseWheel(true)
	window:SetScript("OnMouseWheel", function(_, delta)
		local count = window.items and #window.items or 0
		window.offset = math.max(0, math.min(window.offset - delta, count - ROWS))
		Draw()
	end)
	window:HookScript("OnHide", function() window.index = nil end)
	return window
end

-- The results window for query, its matches (ranked: ns.SearchRank) listed.
function ns.ShowFindResults(query, results)
	Window()
	query = type(query) == "string" and query:gsub("|+", " "):match("^%s*(.-)%s*$") or ""
	window.box:SetText(query)
	window.results, window.offset, window.selected, window.query = results or {}, 0, 1, query
	window.opened = {}
	Rebuild()
	window:Show()
	Draw()
end
-- (The dev copy's /cine debug findresults and the offline check: what it
-- shows, and the window's own key and click handling.)
function ns.FindResultsShown()
	if not (window and window:IsShown()) then return nil end
	local lines = {}
	for i = 1, ROWS do
		local row = window.rows[i]
		if row:IsShown() then
			-- (An empty text reads nil in the game: "" here. Run 5 stopped on it.)
			lines[#lines + 1] = { label = row.label:GetText() or "", kind = row.kind:GetText() or "",
				where = row.where:GetText() or "",
				entry = row.entry, item = row.item, row = row, picked = row.picked:IsShown(), best = row.best:IsShown() }
		end
	end
	return lines, window.count:GetText(), window
end
ns.FindResultsKeys = {
	Pick = function(index) Pick(index) end,
	Open = function(index) Open(window.items and window.items[index]) end,
}
