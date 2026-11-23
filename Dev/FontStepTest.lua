-- /cine debug fontstep: does text drawn 0.1 font size bigger look bigger?
-- (The user, 2026-11-23, after the namescale smooth A/B looked "same": "can
-- we set font sizes in .1 increments". Rule all.fontstring.scale-steps-by-
-- font-size says letters draw at whole sizes; untested for a plain SetFont.)
-- Nothing to do: it draws one grid in the middle of the screen, white on
-- black, and takes one screenshot. Columns: three ways to size text, each
-- at two sizes (7 like a far name, 12 like a near one); rows: every 0.1 from
-- the size to the size + 1.
--   font   FontString:SetFont(file, size)         (what names use now)
--   text   SetFont(file, base) + SetTextScale(size / base)
--   frame  SetFont(file, base) on a frame SetScale(size / base)
-- Each cell's place on screen in pixels is logged ("cell" lines), with the
-- game's own reads (GetStringWidth/Height, GetFont size, GetTextScale).
-- The verdict comes from the picture: Tools/tests/fontstep_measure.py reads
-- the cells off the screenshot (ink width, height and amount) and says, per
-- column, whether each 0.1 step drew bigger or the text only jumps at whole
-- sizes. Into CinematicDB.fontStepTestLog. Dev copy only.
local _, ns = ...

local TEXT = "Stormwind City Guard Stormwind City"
local BASES = { 7, 12 }
local WAYS = { "font", "text", "frame" }
local STEPS = 10 -- 0.0 to 1.0 in 0.1
-- (UI units at scale 1, where the screen is 768 high: 3 columns of 270 and
-- 22 rows of 30 fit any screen. Six columns side by side overflowed 3440 px.)
local CELL_W, CELL_H, GAP = 260, 26, 10

local grid

local function FontFile()
	local object = _G.SystemFont_NamePlate or _G.GameFontNormal
	local file = object and object:GetFont()
	return file or "Fonts\\FRIZQT__.TTF"
end

local function Num(value)
	if value == nil then return "nil" end
	if issecretvalue and issecretvalue(value) then return "secret" end
	if type(value) == "number" then return ("%.3f"):format(value) end
	return tostring(value)
end

-- One cell: a black-backed box, the text left-aligned in it, sized one way.
local function Cell(parent, way, base, size, x, y, file)
	local cell = CreateFrame("Frame", nil, parent)
	cell:SetSize(CELL_W, CELL_H)
	cell:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	local host = cell
	if way == "frame" then
		host = CreateFrame("Frame", nil, cell)
		local scale = size / base
		host:SetScale(scale)
		host:SetSize(CELL_W / scale, CELL_H / scale)
		host:SetPoint("TOPLEFT", cell, "TOPLEFT", 0, 0)
	end
	local text = host:CreateFontString(nil, "OVERLAY")
	text:SetFont(file, way == "font" and size or base, "")
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowOffset(0, 0)
	text:SetPoint("LEFT", host, "LEFT", 4, 0)
	text:SetText(TEXT)
	if way == "text" and text.SetTextScale then text:SetTextScale(size / base) end
	cell.text = text
	return cell
end

ns.TestKit.Define({
	name = "fontstep",
	key = "fontStepTest",
	title = "Font size steps",
	about = "one grid of text at every 0.1 font size, three ways, one screenshot: nothing to do",
	context = function()
		local w, h = GetPhysicalScreenSize()
		return ("screen %sx%s px, UIParent scale %s, font %s"):format(Num(w), Num(h),
			Num(UIParent:GetEffectiveScale()), FontFile())
	end,
	steps = {
		{ key = "grid", title = "the grid, one screenshot", run = function(r)
			local file = FontFile()
			local _, physH = GetPhysicalScreenSize()
			local pxPerUnit = (physH or 768) / 768
			grid = grid or CreateFrame("Frame", nil, UIParent)
			grid:SetFrameStrata("FULLSCREEN_DIALOG")
			grid:SetScale(1 / UIParent:GetEffectiveScale()) -- (cells in units at scale 1)
			grid:SetSize(#WAYS * (CELL_W + GAP) + GAP, #BASES * ((STEPS + 1) * (CELL_H + 4) + GAP) + GAP)
			grid:ClearAllPoints()
			grid:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
			local back = grid.back or grid:CreateTexture(nil, "BACKGROUND")
			grid.back = back
			back:SetAllPoints()
			back:SetColorTexture(0, 0, 0, 1)
			for _, child in ipairs({ grid:GetChildren() }) do child:Hide() end
			for block, base in ipairs(BASES) do
				for column, way in ipairs(WAYS) do
					local reads = {}
					for step = 0, STEPS do
						local size = base + step / 10
						local cellY = GAP + (block - 1) * ((STEPS + 1) * (CELL_H + 4) + GAP) + step * (CELL_H + 4)
						local cell = Cell(grid, way, base, size, GAP + (column - 1) * (CELL_W + GAP), cellY, file)
						local text = cell.text
						local okW, width = pcall(text.GetStringWidth, text)
						local okH, height = pcall(text.GetStringHeight, text)
						local _, fontSize = text:GetFont()
						local textScale = text.GetTextScale and text:GetTextScale() or nil
						reads[#reads + 1] = ("%.1f:w%s h%s f%s t%s"):format(size, Num(okW and width), Num(okH and height),
							Num(fontSize), Num(textScale))
						-- (The cell's box in screen pixels, from the top left.)
						local s = cell:GetEffectiveScale()
						local left, top, right, bottom = cell:GetLeft(), cell:GetTop(), cell:GetRight(), cell:GetBottom()
						if left and top then
							r:Log(("cell %s %d %.1f px %.1f %.1f %.1f %.1f"):format(way, base, size, left * s * pxPerUnit,
								(physH or 768) - top * s * pxPerUnit, right * s * pxPerUnit, (physH or 768) - bottom * s * pxPerUnit))
						end
					end
					r:Log(("reads %s %d: %s"):format(way, base, table.concat(reads, " ")))
				end
			end
			grid:Show()
			-- (The grid on screen whole: a cell off the edge can't be measured.)
			local w, h = GetPhysicalScreenSize()
			local s = grid:GetEffectiveScale() * (h or 768) / 768
			local gl, gt, gr, gb = grid:GetLeft(), grid:GetTop(), grid:GetRight(), grid:GetBottom()
			if gl and w and h then
				r:Verdict(gl * s >= 0 and gr * s <= w and gb * s >= 0 and gt * s <= h,
					("grid on screen: %.0f to %.0f px across of %s, %.0f to %.0f up of %s"):format(gl * s, gr * s, Num(w),
						gb * s, gt * s, Num(h)))
			end
			r:Shot("the grid", { behind = grid, pad = 4, color = { 0, 0, 0, 1 } })
			grid:Hide()
			-- (The game's own reads: whether its numbers move each 0.1. What's
			-- drawn is the screenshot's to say: fontstep_measure.py.)
			r:Verdict(true, "grid drawn and shot: run Tools/tests/fontstep_measure.py on it for the verdict")
		end },
	},
})
