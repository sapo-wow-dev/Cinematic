-- /cine debug bartaint: which game fields an addon wrote (issecurevariable) on
-- the action bars and on what the spellbook's OnShow reads before it shows
-- every bar's grid (Blizzard_PlayerSpellsFrame.lua:42-53). Opened in a fight
-- (2026-11-24), every MultiBar's SetFrameStrata, buttons' SetShown and
-- HideBase/ShowBase was blocked as CinematicDev's, from the first bar on: the
-- run was tainted before MultiActionBar_ShowAllGrids, so a field it read (or a
-- global it called) was ours. Nothing to do: it scans, logs each tainted
-- field with who wrote it, and fails on any written by Cinematic.
local _, ns = ...
if not (ns.TestKit and ns.BarTaintScan) then return end

-- (The scan: Dev/BarTaintCatch.lua, shared with the dev copy's catch on the
-- first blocked bar call.)
local function Scan(depth) return ns.BarTaintScan(depth) end

-- A field we taint on purpose, on a table of ours: proves the scan sees taint.
local control = {}
local function Control(r)
	control.mine = true
	local ok, secure, who = pcall(issecurevariable, control, "mine")
	r:Log(("control: a field we wrote reads secure=%s by %s (ok %s)"):format(tostring(secure), tostring(who), tostring(ok)))
	return ok and secure == false
end

local function Report(r, list, label)
	local keys, ours = {}, 0
	for path, who in pairs(list) do
		keys[#keys + 1] = path
		if who:find("^Cinematic") then ours = ours + 1 end
	end
	table.sort(keys)
	r:Log(("%s: %d tainted field(s), %d by Cinematic"):format(label, #keys, ours))
	for i = 1, math.min(#keys, 80) do r:Log(("    %s  (by %s)"):format(keys[i], list[keys[i]])) end
	r:Verdict(ours == 0, label .. ": no bar, spellbook or micro button field written by Cinematic")
end

ns.TestKit.Define({
	name = "bartaint", key = "barTaintTest", title = "Action bars: fields we tainted",
	about = "opening the spellbook in a fight blocked every action bar call as ours: which bar or spellbook field we wrote",
	settings = {},
	cineMode = true, -- (left on: the bars fade in CineMode, which may be what taints them)
	steps = {
		{ key = "scan", title = "scan the bars, spellbook and micro buttons (nothing to do)", proven = "qeab4 2026-11-24 1/1", run = function(r)
			r:Fields("state", {
				combat = function() return InCombatLockdown() end,
				spellsLoaded = function() return PlayerSpellsFrame ~= nil end,
				abStyle = function() return ns.StyleOn and ns.StyleOn("abStyle") end,
			})
			local list = Scan()
			if not list then return r:Skip("no issecurevariable on this client") end
			Report(r, list, "before the spellbook")
		end },
		-- (Run 1, 2026-11-24: 0 tainted right after a /reload, the spellbook not
		-- loaded yet: the field is written later. So: open it as you did in the
		-- fight, and scan again, its window walked deeper.)
		{ key = "book", title = "open the spellbook as you did in the fight (your one action)", proven = "q6dca 2026-11-24 1/1", run = function(r)
			r:WaitFor("Open the spellbook the way you did in the fight (its key, or the menu button). Out of a fight is fine.",
				{ check = function() return PlayerSpellsFrame and PlayerSpellsFrame:IsShown() end })
			r:Sleep(0.5)
			r:Shot("spellbook open")
			-- (Left open: closing it from our code would be ours, not the game's.)
			Report(r, Scan(3), "with the spellbook open")
		end },
		-- (Run 2: 0 tainted with the spellbook open too. Yet at 18:53 the game's
		-- own ACTIONBAR_SLOT_CHANGED handler, which starts clean, was blocked on
		-- MultiBarBottomLeft x3: in that session a field it reads was ours, and
		-- a /reload cleared it. So: play as usual, and the moment the game
		-- blocks an action bar call, scan then, while the taint is there.)
		-- (Run 4, qee69: the watch logged the spellbook opened through our Menu
		-- Wheel (SecureHandlers > SecureTemplates click > the micro button's
		-- Click > TogglePlayerSpellsFrame), out of a fight, so nothing blocked.
		-- Here: the same in a fight, counting the blocked bar calls. Blocked =
		-- the wheel's path is the tainted one; none = it's ruled out.)
		-- (Run 5, qc754: the wheel's spellbook in a fight blocked nothing. The
		-- saved 18:48 stack went deeper: the micro button's click > ShowUIPanel
		-- > its center branch > SetUIPanel > Show, which reads the window
		-- manager's slots. Our Menu Wheel's Game Menu slot runs CloseAllWindows,
		-- HideUIPanel and ShowUIPanel(GameMenuFrame) from our code: if that
		-- leaves FramePositionDelegate's slots ours, the next window shown
		-- there runs tainted. Here: open and close the Game Menu that way, scan.)
		{ key = "gamemenu", title = "open the Game Menu from the Menu Wheel, then close it (your one action)", run = function(r)
			-- (Run 6, q69e3: 0, but closed slots weren't checked (nil = gone from
			-- pairs) and no control showed the scan sees taint at all.)
			r:Verdict(Control(r), "control: the scan sees a field we wrote as tainted")
			local before = Scan(1)
			local n = 0
			for path, who in pairs(before or {}) do
				n = n + 1
				r:Log(("    at the start: %s (by %s)"):format(path, who))
			end
			r:Log(("at the start: %d tainted"):format(n))
			r:WaitFor("Open the Game Menu from Cinematic's Menu Wheel (its gear slot), then close it with Escape.",
				{ check = function()
					r.sawMenu = r.sawMenu or (GameMenuFrame and GameMenuFrame:IsShown())
					return r.sawMenu and not GameMenuFrame:IsShown()
				end })
			r:Sleep(0.5)
			local list = Scan(1)
			for path in pairs(before or {}) do list[path] = nil end
			Report(r, list, "after the wheel's Game Menu (new since the step began)")
		end },
		{ key = "wheel", title = "in a fight, open the spellbook from the Menu Wheel (your one action)",
			proven = "qc754 2026-11-24 1/1", run = function(r)
			local blocked, seen = 0, {}
			local counter = CreateFrame("Frame")
			counter:RegisterEvent("ADDON_ACTION_BLOCKED")
			counter:SetScript("OnEvent", function(_, _, addon, fn)
				if type(fn) == "string" and (fn:find("MultiBar") or fn:find("ActionButton")) then
					blocked = blocked + 1
					if #seen < 5 then seen[#seen + 1] = tostring(addon) .. " " .. fn end
				end
			end)
			local book = _G.PlayerSpellsFrame
			if book and book:IsShown() then
				r:WaitFor("Close the spellbook first.", { check = function() return not book:IsShown() end })
			end
			local shownBy
			if book then
				book:HookScript("OnShow", function()
					if not shownBy then shownBy = (debugstack(2, 12, 0) or "?"):gsub("\n$", "") end
				end)
			end
			r:WaitFor("Get in a fight, then open the spellbook from Cinematic's Menu Wheel (not its key).",
				{ check = function()
					local b = _G.PlayerSpellsFrame
					return b and b:IsShown() and InCombatLockdown()
				end })
			r:Sleep(1)
			counter:UnregisterAllEvents()
			r:Log("opened in a fight, by:\n" .. tostring(shownBy or "(not caught: the window loaded during the step)"))
			r:Log(("%d action bar call(s) blocked as an addon's"):format(blocked))
			for _, line in ipairs(seen) do r:Log("    " .. line) end
			r:Shot("spellbook open in a fight")
			r:Verdict(blocked == 0, "the spellbook opened from the Menu Wheel in a fight blocks no action bar call")
		end },
		{ key = "watch", title = "play till an action bar call is blocked (fights, spellbook; any length)",
			proven = "left out: qee69 2026-11-24 found the wheel path", run = function(r)
			local base = Scan(3)
			local n = 0
			for _ in pairs(base or {}) do n = n + 1 end
			r:Log(("watch: %d tainted field(s) at the start"):format(n))
			-- (The user didn't open the spellbook at 18:48, yet its OnShow ran: so
			-- log who shows it, each time, with the stack and the fight state.)
			local function HookBook()
				local book = _G.PlayerSpellsFrame
				if not book or r.bookHooked then return end
				r.bookHooked = true
				book:HookScript("OnShow", function()
					if r.stopped then return end
					r:Log(("spellbook shown: combat %s, lockdown %s, by:\n%s"):format(
						tostring(ns.Flag(UnitAffectingCombat("player"))), tostring(InCombatLockdown()),
						(debugstack(2, 20, 0) or "?"):gsub("\n$", "")))
				end)
				r:Log("watch: hooked the spellbook's OnShow")
			end
			HookBook()
			if not r.bookHooked then
				local loader = CreateFrame("Frame")
				loader:RegisterEvent("ADDON_LOADED")
				loader:SetScript("OnEvent", function(self, _, name)
					if name ~= "Blizzard_PlayerSpells" then return end
					self:UnregisterAllEvents()
					r:Log(("Blizzard_PlayerSpells loaded: combat %s, by:\n%s"):format(tostring(InCombatLockdown()),
						(debugstack(2, 20, 0) or "?"):gsub("\n$", "")))
					HookBook()
				end)
			end
			r:WaitFor("Play as usual (fights, level ups, drag spells). The test logs who opens the spellbook and scans the moment the game blocks an action bar call.",
				{ events = { "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }, filter = function(_, addon, fn)
					r:Log(("blocked: %s %s"):format(tostring(addon), tostring(fn)))
					return type(fn) == "string" and (fn:find("MultiBar") or fn:find("ActionButton")
						or fn:find("MainActionBar") or fn:find("MainMenuBar")) ~= nil
				end })
			local list = Scan(3)
			for path in pairs(base or {}) do list[path] = nil end -- (new since the start only)
			Report(r, list, "the moment a bar call was blocked (new since the start)")
			r:Fields("then", {
				combat = function() return InCombatLockdown() end,
				book = function() return PlayerSpellsFrame and PlayerSpellsFrame:IsShown() end,
				cineMode = function() return ns.IsCineModeOn() end,
			})
		end },
	},
})
