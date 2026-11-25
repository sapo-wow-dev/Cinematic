-- The Visions' and Atmosphere's Style pages go off with Enable Style (the audit
-- kit's matrix, Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-style-page-gate.md):
--   python -I Tools/offline/run.py Tools/offline/stylepagegatematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/stylepagegatematrix.lua forever --base <ref>
-- Every part loaded, or Style or Visions left out; Enable Style on or off;
-- each Style hub page's switch (on itself). Each cell: "on" or "off" when the
-- four gates (ns.Setting, ns.PageOn, not ns.MasterOff, ns.StyleOn) agree, else
-- what each said. And what the player gets: the Tint Style page's own zone
-- tint ("yours" or "plain") and the Emote Vision Style page's card size
-- ("yours" or "default"). The rule: Style left out or Enable Style off, every
-- Style page reads off and its looks are the defaults'.
-- (Each load its own process, as partrowsmatrix.lua: one per load, cached.)
local LUA = os.getenv("CINE_LUA") or "lua5.1"
local client, load = ...
client = client or "forever"
local KEYS = { "ufStyle", "selfTextStyle", "damageVisionLook", "lowHealthStyle", "questTalkStyled", "questItemStyle",
	"rollStyle", "emoteStyle", "tintStyle", "letterboxStyle", "weatherStyle", "tintLook", "emoteLook" }
local LOADS = { all = nil, style = "loadStyle", visions = "loadVisions" }

if load then
	-- One load: every key, Enable Style on and off.
	local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
		if LOADS[load] then CinematicDB = { [LOADS[load]] = false } end -- luacheck: ignore 111
	end)
	local db = ns.db
	local function B(v) return v and "on" or "off" end
	for _, style in ipairs({ "on", "off" }) do
		for _, key in ipairs(KEYS) do
			db.styleGeneral = style == "on"
			local ok, out = pcall(function()
				if key == "tintLook" then
					if not ns.GetZoneTintInfo then return "n/a" end
					db.zoneTints = { ["Elwynn Forest"] = "none" }
					local _, _, yours = ns.GetZoneTintInfo("Elwynn Forest")
					db.zoneTints = nil
					return yours and "yours" or "plain"
				elseif key == "emoteLook" then
					if not ns.EmoteOpt then return "n/a" end
					local was = db.emoteVisionScale
					db.emoteVisionScale = 2
					local got = ns.EmoteOpt("emoteVisionScale")
					db.emoteVisionScale = was
					return got == 2 and "yours" or "default"
				end
				db[key] = true
				local s, p, m, y = B(ns.Setting(key)), B(ns.PageOn(key)), B(not ns.MasterOff(key, db)), B(ns.StyleOn(key, db))
				if s == p and p == m and m == y then return s end
				return ("Setting=%s PageOn=%s held=%s StyleOn=%s"):format(s, p, m == "off" and "yes" or "no", y)
			end)
			print(("R %s %s %s"):format(style, key, ok and out or ("error " .. tostring(out):sub(1, 80))))
		end
	end
	return
end

local cache = {}
local function Run(name)
	if not cache[name] then
		local pipe = io.popen(("%s Tools/offline/stylepagegatematrix.lua %s %s 2>&1"):format(LUA, client, name))
		local out = pipe:read("*a")
		pipe:close()
		local got = {}
		for style, key, result in out:gmatch("R (%S+) (%S+) ([^\r\n]*)") do got[style .. " " .. key] = result end
		got.raw = out:sub(-200)
		cache[name] = got
	end
	return cache[name]
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "style-page-gate",
	fixed = { client = client },
	dims = {
		{ "load", { "all", "style", "visions" } }, -- (all loaded, or that part left out)
		{ "enableStyle", { "on", "off" } },
		{ "key", KEYS },
	},
	cell = function(c)
		local got = Run(c.load)
		return got[c.enableStyle .. " " .. c.key] or ("no result: " .. got.raw)
	end,
	pins = {
		{ "", "off" }, -- (Enable Style off or Style left out: every Style page off)
		{ "load=all enableStyle=on", "on" },
		{ "load=visions enableStyle=on", "on" },
		{ "key=tintLook", "plain" },
		{ "load=all enableStyle=on key=tintLook", "yours" },
		{ "load=visions enableStyle=on key=tintLook", "yours" },
		{ "key=emoteLook", "default" },
		{ "load=all enableStyle=on key=emoteLook", "yours" },
		{ "load=visions key=emoteLook", "n/a" }, -- (Emote Vision isn't there)
	},
})
