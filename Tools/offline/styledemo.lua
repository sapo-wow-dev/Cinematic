-- The welcome shelf's Style demos (Style/StyleDemos.lua, Profiles/ShowMe.lua):
-- on the stand-in, both clients. Each kind puts a theme on and every setting
-- a theme pick writes comes back as it was after; frames and plates reach
-- only their parts meanwhile; a /reload mid-demo (PLAYER_LOGIN) puts yours
-- back; a fight refuses one; Style left out, no tile offers them.
--   python -I Tools/offline/run.py Tools/offline/styledemo.lua
-- luacheck: push ignore 111 112 113 121 122 212
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

for _, client in ipairs({ "forever", "retail" }) do
	print("== " .. client)
	-- (Real layout, Tools/style-lab/frames.lua: the boards measured.)
	local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function(w)
		dofile("Tools/style-lab/frames.lua").Install(w)
		rawset(_G, "CreateFontFamily", false)
	end)
	local fight = false
	InCombatLockdown = function() return fight end
	local db = ns.GetDB()
	for _, key in ipairs({ "styleThemes", "unitStyle", "plateStyle" }) do
		Check(client .. ": " .. key .. " can play", ns.ShowMeAvailable(key))
		Check(client .. ": " .. key .. " has a switch", ns.ShowMeCanSwitch(key))
	end
	-- Every setting a pick writes, as it is now.
	local function Snap()
		local out = {}
		for key, value in pairs(ns.StyleSnapshot()) do out[key] = value end
		for _, part in ipairs(ns.THEME_PARTS) do out["styleThemeReach" .. part] = tostring(db["styleThemeReach" .. part]) end
		return out
	end
	local function Same(a, b)
		local diff = {}
		for key, value in pairs(a) do
			if b[key] ~= value then diff[#diff + 1] = key .. " " .. tostring(value) .. " -> " .. tostring(b[key]) end
		end
		for key in pairs(b) do if a[key] == nil then diff[#diff + 1] = key .. " new" end end
		table.sort(diff)
		return #diff == 0, table.concat(diff, ", ", 1, math.min(#diff, 6))
	end
	local before = Snap()
	local themeBefore = db.styleTheme
	for _, kind in ipairs({ "themes", "frames", "plates" }) do
		local ok = ns.StyleDemo(kind)
		Check(client .. ": " .. kind .. " starts", ok)
		Check(client .. ": " .. kind .. ": a theme on", db.styleTheme ~= themeBefore and db.styleTheme ~= nil, db.styleTheme)
		Check(client .. ": " .. kind .. ": yours kept meanwhile", type(db.styleDemoRestore) == "table")
		if kind == "frames" then
			Check(client .. ": frames: only Frames reached", db.styleThemeReachFrames == true and db.styleThemeReachPlates == false,
				tostring(db.styleThemeReachFrames) .. " " .. tostring(db.styleThemeReachPlates))
		elseif kind == "plates" then
			Check(client .. ": plates: only plates reached", db.styleThemeReachPlates == true and db.styleThemeReachFrames == false,
				tostring(db.styleThemeReachPlates) .. " " .. tostring(db.styleThemeReachFrames))

		end
		Check(client .. ": " .. kind .. ": running", ns.StyleDemoRunning())
		local up, count = ns.StyleDemoBoardShown()
		Check(client .. ": " .. kind .. ": its board up", up and count == (kind == "themes" and 2 or 1), tostring(up) .. " " .. tostring(count))
		-- Cut to what it shows: the plate's panel short, the frames' panel
		-- just round their stage at full size (no dark space round them).
		local board = ns.StyleDemoBoard and ns.StyleDemoBoard()
		local tight, why = board ~= nil, "no board"
		for _, preview in ipairs(board and board.previews or {}) do
			local stage = preview.stage
			if stage then
				local w, h = stage:GetSize()
				local pw, ph = preview:GetSize()
				if math.abs(pw - (w + 4)) > 0.5 or math.abs(ph - (h + 18)) > 0.5 or (stage:GetScale() or 1) < 0.999 then
					tight, why = false, ("frames panel %d x %d round a stage %d x %d at %.2f"):format(pw, ph, w, h, stage:GetScale() or 1)
				end
			elseif preview:GetHeight() > 130 then
				tight, why = false, "plate panel " .. preview:GetHeight() .. " high"
			end
		end
		if board then
			local bw = 0
			for i, preview in ipairs(board.previews) do bw = bw + preview:GetWidth() + (i > 1 and 12 or 0) end
			if math.abs(board:GetWidth() - bw) > 0.5 then tight, why = false, ("board %d wide, previews %d"):format(board:GetWidth(), bw) end
		end
		Check(client .. ": " .. kind .. ": its board cut to what it shows", tight, not tight and why or nil)
		ns.StyleDemo(nil)
		local same, diff = Same(before, Snap())
		Check(client .. ": " .. kind .. ": yours back after", same, diff)
		Check(client .. ": " .. kind .. ": nothing kept after", db.styleDemoRestore == nil)
		Check(client .. ": " .. kind .. ": no preview plate after", not ns.StyleDemoBoardShown())
	end
	-- Through ShowMe, as the tile plays it, and Stop.
	Check(client .. ": the Themes tile plays", ns.ShowMe("styleThemes", nil, true))
	Check(client .. ": ShowMe running it", ns.ShowMeRunning("styleThemes"))
	ns.StopShowMe()
	local same, diff = Same(before, Snap())
	Check(client .. ": Stop: yours back", same, diff)
	-- A /reload mid-demo: kept, put back at login.
	ns.StyleDemo("themes")
	local kept = db.styleDemoRestore
	-- (the reload: the demo's own state gone, its saved copy left)
	ns.StyleDemo(nil)
	db.styleDemoRestore = kept
	ns.ApplyStyleTheme("forge", true)
	wow.Fire("PLAYER_LOGIN")
	same, diff = Same(before, Snap())
	Check(client .. ": reload mid-demo: yours back at login", same and db.styleDemoRestore == nil, diff)
	-- In a fight: refused, nothing changed.
	fight = true
	Check(client .. ": in a fight: refused", ns.StyleDemo("themes") == false)
	fight = false
	same, diff = Same(before, Snap())
	Check(client .. ": in a fight: nothing changed", same, diff)
	-- A profile picked mid-demo (the welcome window's cards): the profile left
	-- keeps its own look, not the demo's, and the new one isn't given the old
	-- one's when the demo would have ended; nor after a fight that cut one off.
	-- (Audit 2026-11-22.)
	ns.SwitchProfileLayout = function() end -- (the stand-in has no Edit Mode)
	db.profileChosen = true
	local from = ns.ActiveProfile()
	local to = from == "Balanced" and "Auto-Hide UI" or "Balanced"
	ns.StyleDemo("themes")
	local demoTheme = db.styleTheme
	ns.SetProfile(to)
	Check(client .. ": profile picked mid-demo: the demo ends", not ns.StyleDemoRunning() and db.styleDemoRestore == nil)
	local left = db.profiles[from] or {}
	Check(client .. ": the profile left keeps its own theme", left.styleTheme ~= demoTheme or demoTheme == themeBefore,
		tostring(left.styleTheme) .. " demo " .. tostring(demoTheme))
	local loaded = db.styleTheme
	ns.StyleDemo("themes")
	fight = true
	ns.StyleDemo(nil) -- (a fight cut it off: put back once it ends)
	fight = false
	db.profiles[from] = db.profiles[from] or {}
	db.profiles[from].styleTheme = "forge" -- (a look of its own: told apart from the one put back)
	ns.SetProfile(from)
	local fromTheme = db.styleTheme
	wow.Fire("PLAYER_REGEN_ENABLED")
	Check(client .. ": after a fight: the new profile's look kept", db.styleTheme == fromTheme and db.styleDemoRestore == nil,
		tostring(db.styleTheme) .. " / " .. tostring(fromTheme) .. " (other " .. tostring(loaded) .. ")")
end

-- Style left out: no demo offered.
print("== style left out")
local ns = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", function()
	rawset(_G, "CinematicDB", { loadStyle = false })
end)
for _, key in ipairs({ "styleThemes", "unitStyle", "plateStyle" }) do
	Check("style out: " .. key .. " not offered", not ns.ShowMeAvailable(key))
end
print(fails == 0 and "ALL PASS" or (fails .. " FAIL"))
if fails > 0 then os.exit(1) end
-- luacheck: pop
