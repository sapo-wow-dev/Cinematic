-- Number boxes that show words fit them (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/boxwords.lua <forever|retail>
-- Options.lua's BoxLine capped every box at 6 letters, so Letterbox Style's
-- How long read "With t" at 0 ("With the UI"). The stand-in here keeps the
-- game's cap (SetMaxLetters cuts SetText) and measures 7 px a letter; every
-- box on every page then shows its whole text and is wide enough for it.
-- Says PASS or FAIL per check.
local client = arg and arg[1] or "forever"
local boxes = {}
local ns = dofile("Tools/offline/load.lua")(client, nil, function(wow)
	local M = wow.Methods
	function M:SetMaxLetters(n) self._maxLetters = n boxes[#boxes + 1] = self end
	local setText = M.SetText
	function M:SetText(text)
		if self._kind == "EditBox" and self._maxLetters and self._maxLetters > 0 and type(text) == "string" then
			text = text:sub(1, self._maxLetters)
		end
		setText(self, text)
	end
	function M:HasFocus() return false end
	function M:GetStringWidth() return 7 * #tostring(self._text or "") end
	local setSize = M.SetSize
	function M:SetSize(w, h, ...)
		self._w = w
		if setSize then return setSize(self, w, h, ...) end
	end
end)
local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. text)
	if not ok then failed = failed + 1 end
end

if ns.MakeLazyPages then ns.MakeLazyPages("boxwords test") end
local found
for _, box in ipairs(boxes) do
	if rawget(box, "settingKey") == "letterboxTime" then found = box end
end
Check(found ~= nil, "Letterbox Style's How long box is built")
if found then
	ns.GetDB().letterboxTime = 0
	if found.Refresh then found:Refresh() end
	local text = found:GetText()
	Check(text == ns.L["With the UI"], "at 0 it reads the whole words (" .. tostring(text) .. ")")
	Check((found._w or 0) >= 7 * #ns.L["With the UI"] + 14,
		"its box is wide enough for them (" .. tostring(found._w) .. ")")
	ns.GetDB().letterboxTime = 1.5
	if found.Refresh then found:Refresh() end
	Check(found:GetText() == "1.5 s", "at 1.5 s saved it reads 1.5 s (" .. tostring(found:GetText()) .. ")")
end
print(failed == 0 and "ALL PASS" or (failed .. " FAILED"))
os.exit(failed == 0 and 0 or 1)
