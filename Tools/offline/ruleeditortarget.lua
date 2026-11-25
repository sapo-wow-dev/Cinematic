-- The rule editor opened with only what it needs (offline, Lua 5.1 via
-- Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/ruleeditortarget.lua < /dev/null
-- 2026-11-23 a stand-in target without SetText (Dev/AtmosphereTest.lua) made
-- typing raise "GridRows.lua:404: attempt to call a nil value" in Changed().
-- The editor needs label, Text and Close only; SetText and ResetToGrid are
-- called when there. Tools/errors/known.lua: rule-editor-optional-callback.
-- Types into the real editor and clicks Reset to grid, both clients, with a
-- bare target and a full one. PASS or FAIL per check.
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

-- The editor's EditBox (its only one), found among its frames.
local function FindBox(frame)
	for _, child in ipairs({ frame:GetChildren() }) do
		if child:GetObjectType() == "EditBox" then return child end
		local found = FindBox(child)
		if found then return found end
	end
end
-- Its Reset to grid button: the button whose OnClick calls ResetToGrid.
local function FindReset(frame)
	for _, child in ipairs({ frame:GetChildren() }) do
		if child.GetText and child:GetText() == "Reset to grid" then return child end
		local found = FindReset(child)
		if found then return found end
	end
end

-- (The old editor's +N line checks went with it, 2026-11-25: the new editor's
-- design is checked in Tools/offline/ruleeditor.lua.)

for _, client in ipairs({ "forever", "retail" }) do
	print("== " .. client)
	local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
	local bare = { label = "Bare", Text = function() return "combat" end, Close = function() end }
	local ok, err = pcall(ns.OpenRuleEditor, bare)
	Check("opens with label, Text and Close only", ok, err)
	local editor = _G.CinematicRuleEditor
	local box = editor and FindBox(editor)
	Check("editor and its box there", box ~= nil)
	if box then
		box:SetText("combat and resting")
		ok, err = pcall(box:GetScript("OnTextChanged"), box, true)
		Check("typing with no SetText", ok, err)
		local reset = FindReset(editor)
		Check("Reset to grid button there", reset ~= nil)
		if reset then
			ok, err = pcall(reset:GetScript("OnClick"), reset)
			Check("Reset to grid with no ResetToGrid", ok, err)
		end
		-- A full target still gets each call.
		local got = {}
		ns.OpenRuleEditor({ label = "Full", Text = function() return "" end,
			SetText = function(text) got.set = text end, ResetToGrid = function() got.reset = true end,
			Close = function() got.close = true end })
		box:SetText("flying")
		box:GetScript("OnTextChanged")(box, true)
		Check("full target's SetText gets the typing", got.set == "flying", got.set)
		if reset then reset:GetScript("OnClick")(reset) end
		Check("full target's ResetToGrid called", got.reset == true)
	end
end

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
