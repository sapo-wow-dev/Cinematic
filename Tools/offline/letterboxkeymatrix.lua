-- The letterbox bars that come in whatever CineMode's rows say, against the
-- Letterbox page and Visual Effects (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-letterbox-key-page.md):
--   python -I Tools/offline/run.py Tools/offline/letterboxkeymatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/letterboxkeymatrix.lua forever --base <ref>
-- What brings them in: the letterbox key, a place new to you (Show bars on
-- discovering a new place), or Chat Cam's Ultra immersive through a talk;
-- then the Letterbox page on or off, Enable Visual Effects on or off, and
-- CineMode on or off (the Letterbox's own row off: none of CineMode's bars).
-- Each cell: whether the bars come up, and for the key what it says in chat.
-- The rule (page off = every setting on it off, the user 2026-11-25): none of
-- these with the page or Visual Effects off; the key then says why.
local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db
-- (The stand-in's screen is 100 x 20: bars under a pixel tall. A real one's.)
UIParent.GetWidth = function() return 1920 end -- luacheck: ignore 122
UIParent.GetHeight = function() return 1080 end -- luacheck: ignore 122

local said
local print_ = ns.Print
ns.Print = function(text) said = tostring(text) end

local function Tick(cine, seconds)
	for _ = 1, seconds * 10 do
		local wanted = ns.LetterboxExtra(false, false, cine)
		ns.UpdateLetterbox(wanted, 0.1)
	end
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "letterbox-key-page",
	fixed = { client = client },
	dims = {
		{ "source", { "key", "discover", "immersive" } },
		{ "page", { "on", "off" } },
		{ "effects", { "on", "off" } },
		{ "cine", { "on", "off" } },
	},
	cell = function(c)
		if not (ns.LetterboxExtra and ns.UpdateLetterbox) then return "no letterbox" end
		local cine = c.cine == "on"
		db.enabled, db.letterbox, db.letterboxOffInCombat = true, false, false
		db.letterboxPage, db.visualEffects = true, true
		local immersive = ns.ChatCamImmersive
		ns.ChatCamImmersive = function() return false end
		Tick(cine, 1)
		db.letterboxPage = c.page == "on"
		db.visualEffects = c.effects == "on"
		said = nil
		if c.source == "key" then
			Cinematic_ToggleLetterbox()
		elseif c.source == "discover" then
			db.letterboxOnDiscover = true
			ns.LetterboxOnDiscover()
		else
			ns.ChatCamImmersive = function() return true end
		end
		ns.letterboxDirty = true
		Tick(cine, 3)
		local up = ns.LetterboxUp()
		local words = ""
		if c.source == "key" then
			words = said == nil and " said=nothing" or said:find("letterbox bars on", 1, true) and " said=on"
				or said:find("page is off", 1, true) and " said=pageOff"
				or said:find("Visual Effects", 1, true) and " said=effectsOff" or (" said=" .. said)
		end
		-- (Put back: the key's pick gone (CineMode flipped), the place's time up, the talk over.)
		db.letterboxPage, db.visualEffects = true, true
		ns.ChatCamImmersive = function() return false end
		ns.LetterboxExtra(false, false, not cine)
		if c.source == "discover" then ns.LetterboxOnDiscover() db.letterboxDiscoverTime = 8 end
		db.letterboxOnDiscover = false
		Tick(cine, 3)
		ns.ChatCamImmersive = immersive
		return (up and "bars=up" or "bars=down") .. words
	end,
	pins = {
		{ "", "bars=down" },
		{ "source=key page=on effects=on", "bars=up said=on" },
		{ "source=discover page=on effects=on", "bars=up" },
		{ "source=immersive page=on effects=on", "bars=up" },
		-- (The key with its page off: no bars, and why.)
		{ "source=key page=off", "bars=down said=pageOff" },
		{ "source=key effects=off", "bars=down said=effectsOff" },
	},
})
ns.Print = print_
