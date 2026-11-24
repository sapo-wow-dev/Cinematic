-- The drain ring's shield size from a spell's text (UI/CooldownRing.lua's
-- DescriptionSize), every state (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-23-cdm-ring-size-miss.md):
--   python -I Tools/offline/run.py Tools/offline/cdmringsizematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/cdmringsizematrix.lua --base <ref>
-- A spell's description with an "absorb N" or none, its tooltip with one or
-- none, in a fight or not, asked twice: 2 seconds apart (the ring's ticks and
-- hits) or 15. Each cell: the size found and how often the hidden tooltip was
-- built.
-- The rule (release review 2026-11-23, the user's OK to fix): a found size is
-- kept; a tooltip with none is built again only after 10 seconds (the text
-- can come late), not on every tick; never in a fight.
local client = arg and arg[1] or "forever"
local now, desc, tipText, fight = 100, {}, {}, false
local scans = 0
-- luacheck: push ignore 111 112 113 121 122 212
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function(wow)
	GetTime = function() return now end
	InCombatLockdown = function() return fight end
	C_Spell = C_Spell or {}
	C_Spell.GetSpellDescription = function(id) return desc[id] end
	local Make = CreateFrame
	CreateFrame = function(kind, name, ...)
		local frame = Make(kind == "GameTooltip" and "Frame" or kind, name, ...)
		if kind == "GameTooltip" then
			local line = UIParent:CreateFontString()
			_G[name .. "TextLeft2"] = line
			frame.SetOwner = function() end
			frame.ClearLines = function() line:SetText("") end
			frame.NumLines = function() return 2 end
			frame.SetSpellByID = function(_, id)
				scans = scans + 1
				line:SetText(tipText[id] or "")
			end
		end
		return frame
	end
	local _ = wow
end)
-- luacheck: pop

local Size = ns.CooldownRingDescriptionSize
local n = 0
local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "cdmring-size",
	fixed = { client = client },
	dims = {
		{ "desc", { "number", "none" } },
		{ "tip", { "number", "none" } },
		{ "fight", { "yes", "no" } },
		{ "again", { "within", "after" } },
	},
	cell = function(c)
		n = n + 1
		local id = 5000 + n
		desc[id] = c.desc == "number" and "Absorbing 44 damage." or "Grants armor."
		tipText[id] = c.tip == "number" and "Absorbs 60 damage." or "Grants armor."
		fight = c.fight == "yes"
		scans = 0
		now = now + 100
		local first = Size(id)
		now = now + (c.again == "within" and 2 or 15)
		local second = Size(id)
		return ("size=%s,%s scans=%d"):format(tostring(first or "none"), tostring(second or "none"), scans)
	end,
	pins = {
		-- (In a fight with no description: none, no tooltip.)
		{ "desc=none fight=yes", "size=none,none scans=0" },
		-- (The description's number: kept, no tooltip.)
		{ "desc=number", "size=44,44 scans=0" },
		-- (The tooltip's number: once, then kept.)
		{ "desc=none tip=number fight=no", "size=60,60 scans=1" },
		-- (No number anywhere: tried again only after 10 seconds.)
		{ "desc=none tip=none fight=no again=within", "size=none,none scans=1" },
		{ "desc=none tip=none fight=no again=after", "size=none,none scans=2" },
	},
})
