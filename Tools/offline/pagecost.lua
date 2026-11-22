-- What the settings pages cost at login, on the stand-in (load.lua): per
-- page, the frames, textures and font strings made under it at login, and
-- for pages made the first time they're opened (Options.lua's lazyPages),
-- what opening them adds. With the Lua memory the build took (stand-in
-- frames are small tables: only the share is telling, not the KB).
--
--   python -I Tools/offline/run.py Tools/offline/pagecost.lua [forever|retail] [Cinematic.toc]
local client, toc = ...
client = client or "forever"
package.path = "Tools/offline/?.lua;" .. package.path
local wow = dofile("Tools/offline/wow.lua")
wow.Install(client)
toc = toc or "Cinematic.toc"
local addonName = toc:match("([^/]+)%.toc$")
local ns = {}

local function KB()
	collectgarbage("collect")
	collectgarbage("collect")
	return collectgarbage("count")
end

local base = KB()
for line in io.lines(toc) do
	line = line:gsub("\r", "")
	if line ~= "" and not line:find("^#") then
		local chunk, err = loadfile((line:gsub("\\", "/")))
		if not chunk and not err:find("cannot open") then error(err) end
		if chunk then pcall(chunk, addonName, ns) end
	end
end
local afterFiles = KB()
local framesBefore = #wow.frames
wow.Fire("ADDON_LOADED", addonName)
local afterLoaded = KB()
wow.Fire("PLAYER_LOGIN")
local afterLogin = KB()

-- Objects in a frame's tree (frames, textures, font strings).
local function Count(frame, seen)
	if seen[frame] then return 0, 0 end
	seen[frame] = true
	local frames, regions = 1, 0
	for _, r in ipairs(rawget(frame, "_regions") or {}) do
		if not seen[r] then seen[r] = true regions = regions + 1 end
	end
	for _, child in ipairs(rawget(frame, "_children") or {}) do
		if rawget(child, "_children") then
			local f, r = Count(child, seen)
			frames, regions = frames + f, regions + r
		end
	end
	return frames, regions
end

local canvases = ns.settingsCanvases or {}
local names = {}
for name in pairs(canvases) do names[#names + 1] = name end
table.sort(names)

local rows, totalF, totalR = {}, 0, 0
local seen = {}
for _, name in ipairs(names) do
	local f, r = Count(canvases[name], seen)
	rows[#rows + 1] = { name = name, f = f, r = r }
	totalF, totalR = totalF + f, totalR + r
end

-- Every object the addon made, for the share.
local allF, allR = 0, 0
local all = {}
for _, frame in ipairs(wow.frames) do
	if not rawget(frame, "_parent") or not all[frame] then
		local f, r = Count(frame, all)
		allF, allR = allF + f, allR + r
	end
end

-- Pages made when first opened: open each (its OnShow makes it), with the memory that took.
local lazy = {}
for _, row in ipairs(rows) do
	local canvas = canvases[row.name]
	local onShow = canvas.GetScript and canvas:GetScript("OnShow")
	if onShow then
		local before = KB()
		local ok = pcall(onShow, canvas)
		local f, r = Count(canvas, {})
		if ok and f + r > row.f + row.r + 20 then
			lazy[#lazy + 1] = { name = row.name, f = f - row.f, r = r - row.r, kb = KB() - before }
		end
	end
end

print(("client %s, %s: %d settings canvases"):format(client, toc, #names))
print(("Lua memory: files %.0f KB, ADDON_LOADED +%.0f KB, PLAYER_LOGIN +%.0f KB"):format(afterFiles - base,
	afterLoaded - afterFiles, afterLogin - afterLoaded))
print(("objects at login: %d frames + %d regions in all; settings pages %d frames + %d regions (%.0f%%)"):format(
	allF, allR, totalF, totalR, 100 * (totalF + totalR) / math.max(1, allF + allR)))
table.sort(rows, function(a, b) return a.f + a.r > b.f + b.r end)
print("biggest pages at login (frames + regions):")
for i = 1, math.min(25, #rows) do
	print(("  %-28s %5d + %5d"):format(rows[i].name, rows[i].f, rows[i].r))
end
print("made when first opened (what opening adds):")
for _, row in ipairs(lazy) do
	print(("  %-28s %5d + %5d  %.0f KB"):format(row.name, row.f, row.r, row.kb))
end
print(("frames made before ADDON_LOADED: %d, after login: %d"):format(framesBefore, #wow.frames))
