-- Where each search lands, /cine find's ranking (UI/Find.lua's ns.SearchRank)
-- over the fresh install's index (the audit kit's matrix, Tools/offline/matrix.lua;
-- fix card Tools/audits/2026-11-23-find-hide-minimap.md):
--   python -I Tools/offline/run.py Tools/offline/findrankmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/findrankmatrix.lua forever --base <ref>
-- One cell a search: every one Tools/offline/findrank.lua pins (where it lands,
-- not What's new, each synonym) and Dev/FindResultsTest.lua's. Outcome: the
-- best match's text [its page's key], "(page)" when it's the page itself.
-- (Words in a cell's key are joined by "_": a key's pairs split on spaces.)
-- 70613ac (Style > Minimap) put the Minimap Style page's "Hide" header first
-- for "hide minimap" and "how do i hide the minimap": the Minimap page is
-- what hides the minimap.

local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local index = ns.BuildSearchIndex()

local QUERIES = {
	-- findrank.lua 1, where searches land
	"heal vision", "vision heal visions", "heal visions", "visions heal", "healvision", "heal vison",
	"hael vision", "healing vision", "nameplates", "nameplate", "name plates", "nameplats",
	"nameplate style", "minimap", "mini map", "hide minimap", "letterbox", "letter box", "letterbox size",
	"cinematic bars", "shoulder", "shoulder cam", "camera", "chat", "chat bubbles", "bubbles",
	"action bars", "actionbar", "tooltip", "cursor", "hide cursor", "mouse", "cinemode", "cine mode",
	"quest tracker", "quest talk", "dialogue", "music", "keybinds", "keybind", "hotkey", "vision wheel",
	"profiles", "import", "export", "cooldown manager", "cdm", "cooldown", "combat text", "buffs",
	"gamepad", "tint", "vignette", "effects", "graphics", "fps", "emote", "emotes", "death", "teleport",
	"duel", "roll", "low health", "quest vision", "raid frames", "unit frames", "language", "translation",
	"how do i hide the minimap",
	-- findrank.lua 2, never What's new
	"hide nameplates", "minimap fade", "chat font", "hide tooltip", "nameplate size", "zone card", "mana",
	"nameplate color", "tooltips in combat",
	-- findrank.lua 4 and 5b
	"heal", "visions", "card",
}
-- findrank.lua 3: every synonym (but taxi: other uncommitted work changed
-- where it lands on Forever while this was made, Not on flights [Card
-- Settings] vs HEAD's Flight masters [Name Style]; findrank.lua still checks it)
local have = { taxi = true }
for _, query in ipairs(QUERIES) do have[query] = true end
local synonyms = {}
for typed in pairs(ns.SEARCH_SYNONYMS or {}) do
	if not have[typed] then synonyms[#synonyms + 1] = typed end
end
table.sort(synonyms)
for _, typed in ipairs(synonyms) do QUERIES[#QUERIES + 1] = typed end
local keys = {}
for i, query in ipairs(QUERIES) do keys[i] = (query:gsub(" ", "_")) end

-- What each search must give. findrank.lua's own lands as it says; the rest
-- (not What's new, the synonyms) as they land today, which findrank.lua
-- accepts (some weak: mana and mp the Cooldown Manager, exp Experimental, rep
-- Repeats, hide tooltip Keybinds' Show hidden tooltips: the user's call).
local PINS = {
	{ "query=heal_vision", "Heal Vision [Heal Vision] (page)" },
	{ "query=vision_heal_visions", "Heal Vision [Heal Vision] (page)" },
	{ "query=heal_visions", "Heal Vision [Heal Vision] (page)" },
	{ "query=visions_heal", "Heal Vision [Heal Vision] (page)" },
	{ "query=healvision", "Heal Vision [Heal Vision] (page)" },
	{ "query=heal_vison", "Heal Vision [Heal Vision] (page)" },
	{ "query=hael_vision", "Heal Vision [Heal Vision] (page)" },
	{ "query=healing_vision", "Heal Vision [Heal Vision] (page)" },
	{ "query=nameplates", "Nameplates [Nameplates] (page)" },
	{ "query=nameplate", "Nameplates [Nameplates] (page)" },
	{ "query=name_plates", "Nameplates [Nameplates] (page)" },
	{ "query=nameplats", "Nameplates [Nameplates] (page)" },
	{ "query=nameplate_style", "Nameplate Style [Nameplate Style] (page)" },
	{ "query=minimap", "Minimap [Minimap] (page)" },
	{ "query=mini_map", "Minimap [Minimap] (page)" },
	{ "query=hide_minimap", "Minimap [Minimap] (page)" },
	{ "query=letterbox", "Letterbox [Letterbox] (page)" },
	{ "query=letter_box", "Letterbox [Letterbox] (page)" },
	{ "query=letterbox_size", "Size [Letterbox Style]" },
	{ "query=cinematic_bars", "Letterbox [Letterbox] (page)" },
	{ "query=shoulder", "Shoulder Cam [Shoulder Cam] (page)" },
	{ "query=shoulder_cam", "Shoulder Cam [Shoulder Cam] (page)" },
	{ "query=camera", "Cameras [Cameras] (page)" },
	{ "query=chat", "Chat [Chat] (page)" },
	{ "query=chat_bubbles", "Chat Bubbles [Chat bubbles] (page)" },
	{ "query=bubbles", "Chat Bubbles [Chat bubbles] (page)" },
	{ "query=action_bars", "Action Bar Style [Action Style] (page)" },
	{ "query=actionbar", "Action Bar Style [Action Style] (page)" },
	{ "query=tooltip", "Tooltips [Tooltips] (page)" },
	{ "query=cursor", "Cursor Hide [Cursor Hide] (page)" },
	{ "query=hide_cursor", "Cursor Hide [Cursor Hide] (page)" },
	{ "query=mouse", "Cursor Hide [Cursor Hide] (page)" },
	{ "query=cinemode", "CineMode [CineMode] (page)" },
	{ "query=cine_mode", "CineMode [CineMode] (page)" },
	{ "query=quest_tracker", "Quest Tracker [Quest tracker] (page)" },
	{ "query=quest_talk", "Dialogue [Quest Talk Style] (page)" },
	{ "query=dialogue", "Dialogue [Quest Talk Style] (page)" },
	{ "query=music", "Music [Audio]" },
	{ "query=keybinds", "Keybinds [Keybinds] (page)" },
	{ "query=keybind", "Keybinds [Keybinds] (page)" },
	{ "query=hotkey", "Keybinds [Keybinds] (page)" },
	{ "query=vision_wheel", "Vision Wheel [Vision wheel] (page)" },
	{ "query=profiles", "Profiles [Profiles] (page)" },
	{ "query=import", "Import [Profiles]" },
	{ "query=export", "Export [Profiles]" },
	{ "query=cooldown_manager", "Cooldown Manager [Cooldown Manager] (page)" },
	{ "query=cdm", "Cooldown Manager [Cooldown Manager] (page)" },
	{ "query=cooldown", "Cooldown Manager [Cooldown Manager] (page)" },
	{ "query=combat_text", "Combat Text Style [Combat Text Style] (page)" },
	{ "query=buffs", "Buffs/Debuffs [Buffs/debuffs] (page)" },
	{ "query=gamepad", "Gamepad Frames [Gamepad] (page)" },
	{ "query=tint", "Tint [Tint] (page)" },
	{ "query=vignette", "Vignette [Effects]" },
	{ "query=effects", "Visual Effects [Effects] (page)" },
	{ "query=graphics", "Graphics Boost [Graphics+] (page)" },
	{ "query=fps", "Graphics Boost [Graphics+] (page)" },
	{ "query=emote", "Emote Vision [Emote Vision] (page)" },
	{ "query=emotes", "Emote Vision [Emote Vision] (page)" },
	{ "query=death", "Death Vision [Death Vision] (page)" },
	{ "query=teleport", "Teleport Vision [Teleport Vision] (page)" },
	{ "query=duel", "Duel Vision [Duel Vision] (page)" },
	{ "query=roll", "Roll Vision [Roll Style] (page)" },
	{ "query=low_health", "Vitals Vision [Vitals Vision] (page)" },
	{ "query=quest_vision", "Quest Vision [Quest Vision] (page)" },
	{ "query=raid_frames", "Raid Frame Style [Raid Style] (page)" },
	{ "query=unit_frames", "Unit Frame Style [Unit Style] (page)" },
	{ "query=language", "Language [CineMode]" },
	{ "query=translation", "Language [CineMode]" },
	{ "query=how_do_i_hide_the_minimap", "Minimap [Minimap] (page)" },
	{ "query=hide_nameplates", "Nameplates [Nameplates] (page)" },
	{ "query=minimap_fade", "Minimap [Minimap] (page)" },
	{ "query=chat_font", "Font [Bubble Style]" },
	{ "query=hide_tooltip", "Show hidden tooltips [Keybinds]" },
	{ "query=nameplate_size", "Size [Plate Icons]" },
	{ "query=zone_card", "Zone [Card Settings]" },
	{ "query=mana", "Cooldown Manager [Cooldown Manager] (page)" },
	{ "query=nameplate_color", "Nameplates [Nameplates] (page)" },
	{ "query=tooltips_in_combat", "Combat [Tooltips]" },
	{ "query=heal", "Heal Vision [Heal Vision] (page)" },
	{ "query=visions", "General [Visions General] (page)" },
	{ "query=card", "Card Vision [Card Vision] (page)" },
	{ "query=aura", "Buffs/Debuffs [Buffs/debuffs] (page)" },
	{ "query=auras", "Buffs/Debuffs [Buffs/debuffs] (page)" },
	{ "query=binding", "Keybinds [Keybinds] (page)" },
	{ "query=bindings", "Keybinds [Keybinds] (page)" },
	{ "query=black_bars", "Letterbox [Letterbox] (page)" },
	{ "query=blur", "Depth of field: three strengths [Demo Commands]" },
	{ "query=controller", "Gamepad Frames [Gamepad] (page)" },
	{ "query=damage_numbers", "Combat Text Style [Combat Text Style] (page)" },
	{ "query=dof", "Depth of field: three strengths [Demo Commands]" },
	{ "query=exp", "Experimental [Cursor Hide]" },
	{ "query=floating_text", "Combat Text Style [Combat Text Style] (page)" },
	{ "query=hotkeys", "Keybinds [Keybinds] (page)" },
	{ "query=hp", "Health & Resources [Personal Resources] (page)" },
	{ "query=key_bind", "Keybinds [Keybinds] (page)" },
	{ "query=key_binds", "Keybinds [Keybinds] (page)" },
	{ "query=locale", "Language [CineMode]" },
	{ "query=mp", "Cooldown Manager [Cooldown Manager] (page)" },
	{ "query=performance", "Graphics Boost [Graphics+] (page)" },
	{ "query=plate", "Nameplates [Nameplates] (page)" },
	{ "query=plates", "Nameplates [Nameplates] (page)" },
	{ "query=red_screen", "Vitals Vision [Vitals Style] (page)" },
	{ "query=rep", "Repeats: [Emote Vision Settings]" },
	{ "query=scrolling_text", "Combat Text Style [Combat Text Style] (page)" },
	{ "query=tracker", "Quest Tracker [Quest tracker] (page)" },
	{ "query=xp", "Experience [Chat]" },
	-- (Retail: no Gamepad Frames page, its own rows.)
	{ "client=retail query=gamepad", "Gamepad action bars [Mouseover groups]" },
	{ "client=retail query=controller", "Game's window with a controller [Quest Vision]" },
	{ "client=retail query=xp", "XP bars [Mouseover groups]" },
}

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "findrank-top",
	fixed = { client = client },
	dims = { { "query", keys } },
	cell = function(c)
		local top = ns.SearchRank(index, (c.query:gsub("_", " ")))[1]
		if not top then return "nothing" end
		return ("%s [%s]%s"):format(top.text, tostring(top.page.key), top.rank == 0 and " (page)" or "")
	end,
	pins = PINS,
})
