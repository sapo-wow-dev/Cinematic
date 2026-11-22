-- /cine debug pagecost: what the settings pages cost in game, for deciding
-- whether more of them should be made the first time they're opened
-- (Options.lua's lazyPages). Nothing for you to do: it runs and says DONE.
-- Steps:
--   1 login    Cinematic's memory now (garbage collected first) and every
--              frame in the game; how long making the pages at login took and
--              the Lua memory it used, the heaviest by memory and by time
--              (ns.settingsPagesBuilt); frames, textures and texts under each
--              settings page, their share of the game's frames
--   2 lazy     each page still waiting to be made on first open: made now,
--              one at a time, with its time, memory and objects (out of
--              combat only)
--   3 sum      memory per object from those builds, and what the pages made
--              at login come to at that rate, against the login build's own
-- Building every page holds their memory till the next /reload. Into
-- CinematicDB.pageCostTestLog. Dev copy only.
local ADDON_NAME, ns = ...

local function MemoryKB()
	collectgarbage("collect")
	local update, get = _G.UpdateAddOnMemoryUsage, _G.GetAddOnMemoryUsage
	if update then update() end
	return get and get(ADDON_NAME) or nil
end

local function FrameCount()
	local n, frame = 0, EnumerateFrames()
	while frame do
		n = n + 1
		frame = EnumerateFrames(frame)
	end
	return n
end

-- Frames and regions (textures, texts) in a frame's tree, each once.
local function Count(frame, seen)
	if seen[frame] then return 0, 0 end
	seen[frame] = true
	local frames, regions = 1, 0
	for _, region in ipairs({ frame:GetRegions() }) do
		if not seen[region] then
			seen[region] = true
			regions = regions + 1
		end
	end
	for _, child in ipairs({ frame:GetChildren() }) do
		local f, r = Count(child, seen)
		frames, regions = frames + f, regions + r
	end
	return frames, regions
end

local function PageObjects()
	local rows, frames, regions, seen = {}, 0, 0, {}
	for name, canvas in pairs(ns.settingsCanvases or {}) do
		local f, r = Count(canvas, seen)
		rows[#rows + 1] = { name = name, f = f, r = r }
		frames, regions = frames + f, regions + r
	end
	table.sort(rows, function(a, b) return a.f + a.r > b.f + b.r end)
	return rows, frames, regions
end

local state = {}

ns.TestKit.Define({
	name = "pagecost",
	key = "pageCostTest",
	title = "Settings pages cost",
	about = "what the settings pages cost in memory, time and frames; builds every page, nothing to do",
	context = function()
		local waiting, made = 0, 0
		for _, entry in ipairs(ns.lazySettingsPages or {}) do
			if entry.made then made = made + 1 else waiting = waiting + 1 end
		end
		local loaded = ns.ModuleLoaded or function() return true end
		return ("lazy pages: %d waiting, %d made already; settings canvases: %d; Visions %s, Cameras %s"):format(
			waiting, made, (function() local n = 0 for _ in pairs(ns.settingsCanvases or {}) do n = n + 1 end return n end)(),
			loaded("visions") and "loaded" or "left out", loaded("cameras") and "loaded" or "left out")
	end,
	steps = {
		{ key = "login", title = "memory and frames as you logged in", run = function(r)
			local kb = MemoryKB()
			r:Verdict(type(kb) == "number" and kb > 0, ("Cinematic's memory read: %s KB"):format(tostring(kb)))
			local all = FrameCount()
			r:Log(("frames in the game (every addon's and the game's): %d"):format(all))
			state.kb, state.frames = kb, all
			local built = ns.settingsPagesBuilt
			r:Verdict(type(built) == "table", "the login build's numbers kept (ns.settingsPagesBuilt)")
			if type(built) == "table" then
				r:Log(("login build: %d ms, %.0f KB of Lua memory (garbage too; the collector runs inside it, so a"
					.. " lap can be negative and this undercounts: step 3's estimate is the steadier one)"):format(built.ms, built.kb))
				state.loginKB = built.kb
				local laps = {}
				for i, lap in ipairs(built.laps) do laps[i] = lap end
				table.sort(laps, function(a, b) return (a.kb or 0) > (b.kb or 0) end)
				r:Log("heaviest by memory:")
				for i = 1, math.min(15, #laps) do
					r:Log(("  %6.0f KB %4d ms  %s"):format(laps[i].kb or 0, laps[i].ms, laps[i].name))
				end
				table.sort(laps, function(a, b) return a.ms > b.ms end)
				r:Log("slowest:")
				for i = 1, math.min(10, #laps) do
					r:Log(("  %4d ms %6.0f KB  %s"):format(laps[i].ms, laps[i].kb or 0, laps[i].name))
				end
			end
			local rows, frames, regions = PageObjects()
			state.loginFrames, state.loginRegions = frames, regions
			r:Log(("settings pages: %d frames + %d regions; their frames are %.0f%% of the game's %d"):format(
				frames, regions, 100 * frames / math.max(1, all), all))
			r:Log("biggest pages (frames + regions):")
			for i = 1, math.min(20, #rows) do
				r:Log(("  %5d + %5d  %s"):format(rows[i].f, rows[i].r, rows[i].name))
			end
			r:Verdict(frames > 0, "settings page frames counted")
		end },
		{ key = "lazy", title = "every page made on first open, made now", run = function(r)
			if InCombatLockdown() then return r:Skip("in a fight: pages aren't made in fights") end
			local list = ns.lazySettingsPages or {}
			r:Verdict(#list > 0, ("%d pages made on first open (ns.lazySettingsPages)"):format(#list))
			local totalKB, totalMS, totalObjects, made = 0, 0, 0, 0
			for _, entry in ipairs(list) do
				if entry.made then
					r:Log(("  already made: %s"):format(tostring(entry.name)))
				elseif entry.canvas or entry.Make then
					local before = MemoryKB()
					local _, f0, r0 = PageObjects()
					local started = debugprofilestop()
					entry.Make("pagecost test")
					local ms = debugprofilestop() - started
					local after = MemoryKB()
					local _, f1, r1 = PageObjects()
					local objects = (f1 - f0) + (r1 - r0)
					r:Log(("  %-26s %5d ms %7.0f KB  %5d frames + %5d regions"):format(tostring(entry.name), ms,
						(after or 0) - (before or 0), f1 - f0, r1 - r0))
					totalKB, totalMS, totalObjects, made = totalKB + (after or 0) - (before or 0), totalMS + ms,
						totalObjects + objects, made + 1
					r:Sleep(0.2) -- (a frame between, not one long freeze)
				end
			end
			state.lazyKB, state.lazyObjects = totalKB, totalObjects
			r:Log(("made %d: %d ms, %.0f KB, %d objects"):format(made, totalMS, totalKB, totalObjects))
			local left = 0
			for _, entry in ipairs(list) do if not entry.made then left = left + 1 end end
			r:Verdict(left == 0, ("every page made (%d left)"):format(left))
			local kb = MemoryKB()
			r:Log(("Cinematic's memory now: %.0f KB (at the start %.0f), frames in the game %d (at the start %d)"):format(
				kb or 0, state.kb or 0, FrameCount(), state.frames or 0))
		end },
		{ key = "sum", title = "what the pages made at login come to", run = function(r)
			if not (state.lazyObjects and state.lazyObjects > 0 and state.lazyKB) then
				return r:Skip("no page built in step 2 to measure by")
			end
			local per = state.lazyKB / state.lazyObjects
			local objects = (state.loginFrames or 0) + (state.loginRegions or 0)
			r:Log(("%.2f KB per object (from step 2); the %d objects made at login come to about %.0f KB"):format(per,
				objects, per * objects))
			r:Log(("the login build's own count: %.0f KB (garbage too); Cinematic in all at login: %.0f KB"):format(
				state.loginKB or 0, state.kb or 0))
			r:Verdict(per > 0, "a memory per object worked out")
		end },
	},
})
