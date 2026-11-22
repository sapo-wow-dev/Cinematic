-- The welcome window's See all shelf: every feature has an on/off switch
-- (the user's rule, 2026-11-22). On the stand-in, both clients: the window
-- opened, the shelf's tiles and Also in links read; every tile that can play
-- has a switch (ns.ShowMeCanSwitch), and each switch flips its feature over
-- and back (ns.ShowMeSwitch, then ns.ShowMeUnswitch: as it was); Fight
-- Recap's off leaves Damage Vision on; each link whose page has an Enable
-- switch flips it the same way (a page with none: listed). The Cooldown
-- Manager's Flash switch is under its page's switch.
--   python -I Tools/offline/run.py Tools/offline/shelfswitches.lua
-- Exit 1 on any problem.
-- luacheck: push ignore 111 112 113 121 122 212
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local function FindRow(frame, depth)
	-- (raw: the stand-in hands a stub back for any field it hasn't got)
	if type(frame) == "table" and type(rawget(frame, "ShelfTiles")) == "function" then return frame end
	if depth > 12 then return nil end
	for _, child in ipairs({ frame:GetChildren() }) do
		local found = FindRow(child, depth + 1)
		if found then return found end
	end
end

for _, client in ipairs({ "forever", "retail" }) do
	print("== " .. client)
	local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
	C_EditMode = C_EditMode or {}
	C_EditMode.GetLayouts = function() return { layouts = {}, activeLayout = 1 } end
	C_ChatBubbles = C_ChatBubbles or {}
	C_ChatBubbles.GetAllChatBubbles = function() return {} end
	wow.Methods.SetFrameStrata = function(self, strata) rawset(self, "_strata", strata) end
	wow.Methods.GetFrameStrata = function(self) return rawget(self, "_strata") or "MEDIUM" end
	InCombatLockdown = function() return false end

	Check(client .. ": Flash is under the Cooldown Manager page's switch",
		ns.PageSwitchOf("cooldownFlash") == "handleCooldowns", ns.PageSwitchOf("cooldownFlash"))
	Check(client .. ": Flash on by default", ns.DEFAULTS.cooldownFlash == true)

	ns.ShowWelcome()
	local window = _G.CinematicWelcome
	local row = window and FindRow(window, 0)
	Check(client .. ": the welcome window has its shelf", row ~= nil)
	if row then
		local tiles, links = row.ShelfTiles(), row.ShelfLinks or {}
		local keys = {}
		for _, b in ipairs(tiles) do keys[#keys + 1] = b.demo.key end
		print(("%d tiles, %d links"):format(#tiles, #links))
		local function States()
			local out = {}
			for _, key in ipairs(keys) do out[key] = ns.ShowMeOn(key) end
			return out
		end
		for _, b in ipairs(tiles) do
			local key = b.demo.key
			if ns.ShowMeAvailable(key) then
				local can = ns.ShowMeCanSwitch(key)
				Check(client .. ": " .. key .. " has a switch", can and b.switch ~= nil)
				-- (not Fading UI's or the Shoulder Cam's: their own runs, ShelfTest's)
				if can and key ~= "shoulder" then
					for _, first in ipairs({ true, false }) do
						local was = ns.ShowMeOn(key)
						local before = States()
						local changed = ns.ShowMeSwitch(key, not was)
						local now = ns.ShowMeOn(key)
						Check(("%s: %s switched %s"):format(client, key, was and "off" or "on"),
							changed ~= nil and now == not was, tostring(was) .. " -> " .. tostring(now))
						if key == "recap" and was then
							Check(client .. ": recap off leaves Damage Vision as it was",
								ns.ShowMeOn("damage") == before.damage)
						end
						ns.ShowMeUnswitch(changed)
						Check(("%s: %s put back"):format(client, key), ns.ShowMeOn(key) == was)
						-- (and once from the other side: on, then off)
						if first then
							local c2 = ns.ShowMeSwitch(key, not was)
							if c2 and ns.ShowMeOn(key) ~= was then
								local c3 = ns.ShowMeSwitch(key, was)
								Check(("%s: %s switched back by its switch"):format(client, key),
									ns.ShowMeOn(key) == was)
								ns.ShowMeUnswitch(c3)
							end
							ns.ShowMeUnswitch(c2)
							break
						end
					end
				end
			end
		end
		-- Fight Recap off with Damage Vision on (both off on a fresh install,
		-- so the flips above only turned them on): Damage Vision stays on.
		if ns.ShowMeAvailable("recap") then
			local c1 = ns.ShowMeSwitch("damage", true)
			local c2 = ns.ShowMeSwitch("recap", true)
			local c3 = ns.ShowMeSwitch("recap", false)
			Check(client .. ": recap off, Damage Vision still on",
				ns.ShowMeOn("damage") and not ns.ShowMeOn("recap"),
				("damage %s, recap %s"):format(tostring(ns.ShowMeOn("damage")), tostring(ns.ShowMeOn("recap"))))
			local c4 = ns.ShowMeSwitch("recap", true)
			Check(client .. ": recap back on", ns.ShowMeOn("recap") and ns.ShowMeOn("damage"))
			for _, c in ipairs({ c4, c3, c2, c1 }) do ns.ShowMeUnswitch(c) end
		end
		local plain = {}
		for _, a in ipairs(links) do
			local key = a.demo and a.demo.key
			local page = a.link.page
			if ns.HasOptionsPage and not ns.HasOptionsPage(page) then
				print("  link " .. page .. ": not on this client")
			elseif not (key and ns.ShowMeCanSwitch(key)) then
				plain[#plain + 1] = page
			else
				Check(client .. ": link " .. page .. " has a switch", a.switch ~= nil)
				local was = ns.ShowMeOn(key)
				local changed = ns.ShowMeSwitch(key, not was)
				Check(("%s: link %s switched %s (%s)"):format(client, page, was and "off" or "on",
					table.concat(ns.PageSwitchKeys(page), ", ")), ns.ShowMeOn(key) == not was)
				ns.ShowMeUnswitch(changed)
				Check(("%s: link %s put back"):format(client, page), ns.ShowMeOn(key) == was)
			end
		end
		print("  links whose page has no switch: " .. (#plain > 0 and table.concat(plain, ", ") or "none"))
	end
end

print(fails == 0 and "ALL PASS" or (fails .. " FAIL"))
os.exit(fails == 0 and 0 or 1)
-- luacheck: pop
