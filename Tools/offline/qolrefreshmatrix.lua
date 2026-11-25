-- What a profile switch and the Quality of life and Hunter page switches put
-- back at once (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-25-qol-refresh.md):
--   python -I Tools/offline/run.py Tools/offline/qolrefreshmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/qolrefreshmatrix.lua forever --base <ref>
-- The change: a profile loading (its settings changed: ns.SettingsChanged),
-- the Quality of life page's switch clicked, the Hunter page's switch clicked.
-- What's asked: Graphics+ applied again, the XP bar's "(N left)", the
-- inspect Talents buttons, the talent calculator link, the dressing room by
-- the auction house, an open vendor's Fill buttons. Each cell: refreshed (the
-- feature's refresh ran) or not.
-- The rule (page off = every setting on it off, at once): each refresh runs
-- for the switches it's under and for a profile; a switch it isn't under
-- leaves it alone. The Hunter page is only on Classic clients (no page on
-- retail).
local client = arg and arg[1] or "forever"
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db
ns.SwitchProfileLayout = function() end -- (the stand-in has no Edit Mode)

-- An open vendor, its first item's button counting its reads (the Fill buttons' pass).
local fillReads = 0
-- luacheck: push ignore 111 112 113 121 122
MERCHANT_ITEMS_PER_PAGE = 1
MerchantFrame = wow.CreateFrame("Frame", "MerchantFrame")
MerchantFrame.selectedTab = 1
MerchantFrame:Show()
local item = wow.CreateFrame("Frame", "MerchantItem1")
local button = wow.CreateFrame("Button", "MerchantItem1ItemButton", item)
rawset(button, "GetID", function() fillReads = fillReads + 1; return 1 end)
-- luacheck: pop

local WRAPPED = { graphics = "ApplyGraphicsPlus", xp = "RefreshXpLeft", talentlink = "RefreshTalentLink",
	talentcalc = "RefreshTalentCalc", ahdressup = "RefreshAhDressUp" }
local calls = {}
for item_, name in pairs(WRAPPED) do
	local fn = ns[name]
	if fn then
		ns[name] = function(...)
			calls[item_] = (calls[item_] or 0) + 1
			return fn(...)
		end
	end
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = client == "retail" and "qol-refresh-retail" or "qol-refresh", -- (each client's own cells on the card)
	fixed = { client = client },
	dims = {
		{ "via", { "profile", "qol", "hunter" } },
		{ "item", { "graphics", "xp", "talentlink", "talentcalc", "ahdressup", "fill" } },
	},
	cell = function(c)
		db.handleQuality, db.handleHunter = true, true
		for k in pairs(calls) do calls[k] = nil end
		fillReads = 0
		if c.via == "profile" then
			ns.SettingsChanged()
		elseif c.via == "qol" then
			if not ns.FlipSettingKey("handleQuality") then return "no page" end
		else
			if not ns.FlipSettingKey("handleHunter") then return "no page" end
		end
		db.handleQuality, db.handleHunter = true, true
		if c.item == "fill" then return fillReads > 0 and "refreshed" or "not" end
		return (calls[c.item] or 0) > 0 and "refreshed" or "not"
	end,
	pins = {
		{ "", "not" },
		{ "via=profile", "refreshed" },
		{ "via=qol item=xp", "refreshed" },
		{ "via=qol item=talentlink", "refreshed" },
		{ "via=qol item=talentcalc", "refreshed" },
		{ "via=qol item=ahdressup", "refreshed" },
		{ "via=hunter item=fill", "refreshed" },
		-- (No Hunter page, and no vendor Fill buttons, on retail; nor the Talents
		-- buttons, the talent calculator link or the AH dressing room there.)
		{ "client=retail item=fill", "not" },
		{ "client=retail item=talentlink", "not" },
		{ "client=retail item=talentcalc", "not" },
		{ "client=retail item=ahdressup", "not" },
		{ "client=retail via=hunter", "no page" },
	},
})
