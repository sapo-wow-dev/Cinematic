-- Combat Text Style's sample numbers: on the preview's plate that shows
-- (Plates/PlateRowLook.lua holder.plate, Style/CombatTextPage.lua), every state
-- (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-23-ct-preview-plate.md):
--   python -I Tools/offline/run.py Tools/offline/ctpreviewplatematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/ctpreviewplatematrix.lua --base <ref>
-- The client, the game plate's copy built or not (ns.GamePlateReady: the
-- template failing, or the game's options not ready), the page's preview or
-- the welcome window's demo. Each cell: the plate the first sample number is
-- drawn on (the game's copy or the drawn plate), whether it's shown, and its
-- bottom's lift in the preview. The rule: the numbers play on the plate you
-- see, where it sits (the game's at the preview's plateLift, the drawn one at
-- 44 / 1.6, over its cast bar).
-- luacheck: ignore 111 112 113 121 122

local client = arg and arg[1] or "forever"

local function Cell(c)
	local parts = dofile("Tools/offline/gameplate_parts.lua")(function() end)
	local timers = {}
	local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function(wow)
		issecretvalue = function() return false end
		parts.Install()
		C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
		-- (Points kept, for the plate's spot: the stand-in's GetPoint reads none. The first after a clear.)
		local M = wow.Methods
		local Set, Clear = M.SetPoint, M.ClearAllPoints
		M.SetPoint = function(self, ...)
			if not rawget(self, "_pt") then rawset(self, "_pt", { ... }) end
			if Set then return Set(self, ...) end
		end
		M.ClearAllPoints = function(self)
			rawset(self, "_pt", nil)
			if Clear then return Clear(self) end
		end
		M.GetPoint = function(self)
			local pt = rawget(self, "_pt")
			if pt then return unpack(pt) end
			return "CENTER", nil, "CENTER", 0, 0
		end
	end)
	local Ready = ns.GamePlateReady
	if c.copy == "fails" then ns.GamePlateReady = function() return false end end
	local made
	local Make = ns.MakePlateRowLookPreview
	ns.MakePlateRowLookPreview = function(...) made = Make(...) return made end
	local got
	ns.CombatTextSample = function(plate) got = got or plate end
	local ok, err
	if c.where == "page" then
		ok, err = pcall(ns.CreateCombatTextStylePanel, ns.lowHealthKit)
	else
		ok, err = pcall(ns.ShowCombatTextDemo, true)
	end
	if not ok then return "error: " .. tostring(err) end
	if not made then return "no preview" end
	-- (Shown: its OnShow, the plate drawn with the copy as the game has it now, and the page's numbers start.)
	made:Show()
	local onShow = made:GetScript("OnShow")
	if onShow then onShow(made) end
	local due = timers
	timers = {}
	for i = 1, #due do pcall(due[i]) end
	ns.GamePlateReady = Ready
	if not got then return "no number" end
	local _, _, _, _, y = got:GetPoint(1)
	return ("on=%s shown=%s lift=%s"):format(got == made.gamePlate and "game" or "drawn", got:IsShown() and "yes" or "no",
		y and ("%.1f"):format(y) or "none")
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = client == "retail" and "ct-preview-plate-retail" or "ct-preview-plate",
	fixed = { client = client },
	dims = {
		{ "copy", { "built", "fails" } },
		{ "where", { "page", "demo" } },
	},
	cell = Cell,
	pins = {
		-- (No copy, or retail: the drawn plate, shown, over its cast bar.)
		{ "", "on=drawn shown=yes lift=27.5" },
		-- (Forever with the copy built: the game's plate over the picks.)
		-- (66: the stand-in's plateLift, its frames all 20 high.)
		{ "client=forever copy=built", "on=game shown=yes lift=66.0" },
	},
})
