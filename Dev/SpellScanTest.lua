-- /cine debug spellscan: every spell in the game read once for the shield /
-- charges ring (ledger Tools/tests/cdm-shield-strength.md): spells whose
-- description says they absorb damage, and spells with charges or stacks.
-- Hands off, out of a fight (spell data reads are plain there). Steps:
--   1 scan     every spell ID 1..MAX in batches per frame: its name, rank and
--              description; absorb / charges / stacks matches kept
--   2 retry    spells with no description yet set on a hidden tooltip (the
--              only thing that fills them, run 2), read from its lines and
--              from the API once SPELL_TEXT_UPDATE goes quiet
--   3 catalog  this class's Tracked Buffs catalog (learned and not), each
--              marked known or not, and which matches it holds
-- Into CinematicDB.spellScan (absorb, stacks, catalog lists; read offline)
-- and CinematicDB.spellScanTestLog. Dev copy only.
local _, ns = ...

local MAX_ID = 1500000
local BATCH = 6000
local waiting = {} -- (spells with a name and no description yet: step 2 asks for them)

local function Secret(value) return issecretvalue and issecretvalue(value) or false end
local function Text(fn, id)
	local ok, value = pcall(fn, id)
	if ok and type(value) == "string" and not Secret(value) then return value end
end

local STACK_WORDS = { "charge", "stack", "application" }
local function Kinds(lower)
	local absorb = lower:find("absorb", 1, true) ~= nil
	local stacks = false
	for _, word in ipairs(STACK_WORDS) do
		if lower:find(word, 1, true) then stacks = true break end
	end
	return absorb, stacks
end

local function Entry(id, name, desc)
	local rank = Text(C_Spell.GetSpellSubtext, id) or ""
	return ("%d|%s|%s|%s"):format(id, name, rank, (desc:gsub("[\r\n|]", " ")):sub(1, 220))
end

ns.TestKit.Define({
	name = "spellscan",
	key = "spellScanTest",
	title = "Spell scan: shields and stacks",
	about = "reads every spell's description and keeps the ones that absorb damage or have charges / stacks; hands off",
	needs = "Out of a fight (any character; the class decides step 3's catalog)",
	steps = {
		{ key = "scan", title = "every spell read", run = function(r)
			if InCombatLockdown() then
				r:WaitFor("Leave the fight: the scan reads out of combat.", { events = { "PLAYER_REGEN_ENABLED" } })
			end
			wipe(waiting)
			local out = { absorb = {}, stacks = {}, scannedAt = date("%Y-%m-%d %H:%M"),
				client = ns.isRetail and "retail" or "forever" }
			CinematicDB.spellScan = out
			local named, highest, started = 0, 0, debugprofilestop()
			r:Prompt("Reading every spell (hands off, about a minute).", "Nothing to do.", 90)
			for first = 1, MAX_ID, BATCH do
				for id = first, math.min(first + BATCH - 1, MAX_ID) do
					local name = Text(C_Spell.GetSpellName, id)
					if name and name ~= "" then
						named, highest = named + 1, id
						local desc = Text(C_Spell.GetSpellDescription, id)
						if desc and desc ~= "" then
							local absorb, stacks = Kinds(desc:lower())
							if absorb then out.absorb[#out.absorb + 1] = Entry(id, name, desc) end
							if stacks then out.stacks[#out.stacks + 1] = Entry(id, name, desc) end
						else
							waiting[#waiting + 1] = id
						end
					end
				end
				if first % 120000 == 1 then
					r:Log(("  at %d: %d named, %d absorb, %d stacks, %d not loaded"):format(first, named, #out.absorb,
						#out.stacks, #waiting))
				end
				r:Sleep(0)
			end
			r:Log(("  scanned 1..%d in %.0f s: %d named (highest %d), %d absorb, %d stacks, %d descriptions not loaded"):format(
				MAX_ID, (debugprofilestop() - started) / 1000, named, highest, #out.absorb, #out.stacks, #waiting))
			r:Verdict(named > 1000 and highest < MAX_ID - 50000,
				("spells found (%d), the highest well under the scan's end (%d < %d)"):format(named, highest, MAX_ID))
			r:Verdict(#out.absorb > 0, "absorb matches: " .. #out.absorb)
		end },
		{ key = "retry", title = "descriptions filled through a hidden tooltip", run = function(r)
			local out = CinematicDB.spellScan
			if not out or #waiting == 0 then return r:Skip("nothing waiting") end
			-- Descriptions fill only once a spell's tooltip is shown (rule
			-- forever.spell.description-needs-tooltip): each spell set on a
			-- hidden tooltip, its lines read on the spot (way A), and the
			-- description read again once SPELL_TEXT_UPDATE goes quiet (way B).
			local tip = CreateFrame("GameTooltip", "CinematicSpellScanTip", nil, "GameTooltipTemplate")
			local function TipText(id)
				tip:SetOwner(WorldFrame, "ANCHOR_NONE")
				tip:ClearLines()
				if not pcall(tip.SetSpellByID, tip, id) then return nil end
				local parts = {}
				for i = 2, math.min(tip:NumLines() or 0, 12) do
					local line = _G["CinematicSpellScanTipTextLeft" .. i]
					local text = line and line:GetText()
					if type(text) == "string" and not Secret(text) and #text > 20 then parts[#parts + 1] = text end
				end
				return #parts > 0 and table.concat(parts, " ") or nil
			end
			local updates, lastAt = 0, GetTime()
			local listen = CreateFrame("Frame")
			listen:RegisterEvent("SPELL_TEXT_UPDATE")
			listen:SetScript("OnEvent", function() updates, lastAt = updates + 1, GetTime() end)
			r:Probe("Ice Barrier 13031 description before", C_Spell.GetSpellDescription, 13031)
			local fromTip = {}
			local started = debugprofilestop()
			for i, id in ipairs(waiting) do
				fromTip[id] = TipText(id)
				if i % 300 == 0 then
					lastAt = GetTime()
					r:Sleep(0)
				end
			end
			tip:Hide()
			local tipCount = 0
			for _ in pairs(fromTip) do tipCount = tipCount + 1 end
			r:Log(("  %d tooltips in %.0f s: %d had text at once (way A)"):format(#waiting,
				(debugprofilestop() - started) / 1000, tipCount))
			r:WaitFor(nil, { check = function() return GetTime() - lastAt > 3 and "quiet" end })
			listen:UnregisterAllEvents()
			r:Log(("  SPELL_TEXT_UPDATE: %d"):format(updates))
			r:Probe("Ice Barrier 13031 description after", C_Spell.GetSpellDescription, 13031)
			local still, added, wayB = {}, 0, 0
			for i, id in ipairs(waiting) do
				local name = Text(C_Spell.GetSpellName, id) or "?"
				local desc = Text(C_Spell.GetSpellDescription, id)
				if desc and desc ~= "" then wayB = wayB + 1 else desc = fromTip[id] end
				if desc and desc ~= "" then
					local absorb, stacks = Kinds(desc:lower())
					if absorb then out.absorb[#out.absorb + 1] = Entry(id, name, desc) added = added + 1 end
					if stacks then out.stacks[#out.stacks + 1] = Entry(id, name, desc) added = added + 1 end
				else
					still[#still + 1] = id
				end
				if i % 3000 == 0 then r:Sleep(0) end
			end
			r:Log(("  %d asked for: %d matches added; description API %d (way B), tooltip lines %d (way A); %d with no text"):format(
				#waiting, added, wayB, tipCount, #still))
			r:Verdict(#still < #waiting / 2, ("most spells read: %d of %d"):format(#waiting - #still, #waiting))
			out.stillNoText = #still
		end },
		{ key = "catalog", title = "this class's Tracked Buffs catalog", run = function(r)
			local out = CinematicDB.spellScan
			local category = Enum and Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.TrackedBuff
			local ok, set = pcall(C_CooldownViewer.GetCooldownViewerCategorySet, category, true)
			if not (ok and type(set) == "table") then return r:Skip("catalog not read: " .. tostring(set)) end
			out.catalog = {}
			local _, class = UnitClass("player")
			out.catalogClass = class
			for _, cooldownID in ipairs(set) do
				local okInfo, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
				if okInfo and type(info) == "table" then
					local id = info.spellID
					local links = {}
					if type(info.linkedSpellIDs) == "table" then
						for _, linked in ipairs(info.linkedSpellIDs) do links[#links + 1] = tostring(linked) end
					end
					out.catalog[#out.catalog + 1] = ("%s|%s|%s|known %s|linked %s"):format(tostring(cooldownID),
						tostring(id), Text(C_Spell.GetSpellName, id) or "?", tostring(info.isKnown), table.concat(links, ","))
				end
			end
			r:Log(("  %s: %d Tracked Buffs entries saved"):format(tostring(class), #out.catalog))
			r:Verdict(#out.catalog > 0, "catalog read")
		end },
	},
})
