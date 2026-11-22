-- The share window: a text to copy (a scene, a shot, a theme, a Vitals theme),
-- or a box to paste one into, with what it holds shown before it's added. Out
-- of Camera/CameraTriggerEditor.lua (2026-11-21), so it loads with Cameras left
-- out too (Modules.lua): Style Themes and Vitals Vision share through it. The
-- scenes' and shots' own reading (ns.ReadCameraShare...) is asked only on their
-- pages' import.
local _, ns = ...
local L = ns.L

-- The share window: a trigger's or shot's text to copy, or a box to paste
-- one into, with what it holds shown before it's added.
local window
local WHY = {
	newer = "This is from a newer Cinematic: update it to add this one.",
	other = "That isn't a scene or shot: profiles go on the Profiles page, wheels on Your wheels.",
	broken = "That isn't the whole thing. Copy it again, all of it.",
	full = "No room for it: delete a scene or shot first.",
}
local function Window()
	if window then return window end
	window = CreateFrame("Frame", "CinematicCameraShareWindow", UIParent,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	window:SetSize(480, 300)
	window:SetPoint("CENTER")
	window:SetFrameStrata("DIALOG")
	window:SetToplevel(true)
	window:EnableMouse(true)
	if window.SetBackdrop then
		window:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 24,
			insets = { left = 6, right = 6, top = 6, bottom = 6 } })
	end
	if ns.SkinWindow then ns.SkinWindow(window) end
	tinsert(UISpecialFrames, "CinematicCameraShareWindow")
	ns.DockBeside(window, "cameraShare"):SetPoint("TOPRIGHT", -14, -14)
	window:Hide()

	window.title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	window.title:SetPoint("TOPLEFT", 18, -16)
	window.title:SetPoint("RIGHT", -90, 0) -- (clear of Pop out)
	window.title:SetJustifyH("LEFT")
	window.hint = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	window.hint:SetPoint("TOPLEFT", window.title, "BOTTOMLEFT", 0, -6)
	window.hint:SetPoint("RIGHT", -18, 0)
	window.hint:SetJustifyH("LEFT")

	local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
	if ns.SkinScroll then ns.SkinScroll(scroll) end
	scroll:SetPoint("TOPLEFT", 18, -70)
	scroll:SetPoint("RIGHT", -40, 0)
	scroll:SetHeight(80)
	local box = CreateFrame("EditBox", nil, scroll)
	box:SetMultiLine(true)
	box:SetMaxLetters(0)
	box:SetAutoFocus(false)
	box:SetFontObject(ChatFontNormal)
	box:SetWidth(420)
	scroll:SetScrollChild(box)
	box:SetScript("OnEscapePressed", function() window:Hide() end)
	window.box = box

	window.review = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	window.review:SetPoint("TOPLEFT", scroll, "BOTTOMLEFT", 0, -10)
	window.review:SetPoint("RIGHT", -18, 0)
	window.review:SetJustifyH("LEFT")
	window.review:SetSpacing(3)

	local close = ns.PanelButton(window)
	close:SetSize(90, 22)
	close:SetPoint("BOTTOMRIGHT", -16, 14)
	close:SetText(CLOSE or L["Close"])
	close:SetScript("OnClick", function() window:Hide() end)
	local action = ns.PanelButton(window)
	action:SetSize(110, 22)
	action:SetPoint("RIGHT", close, "LEFT", -8, 0)
	window.action = action

	box:SetScript("OnTextChanged", function(self, userInput)
		if window.mode == "export" then
			if userInput then
				self:SetText(window.text)
				self:HighlightText()
			end
			return
		end
		-- (Another page's thing to import: its reader, ns.ShowShareImport.)
		local reader = window.reader
		if reader then
			local info, why = reader.read(self:GetText())
			window.info = info
			action:SetEnabled(info ~= nil)
			window.review:SetText(info and reader.describe(info) or why or "")
			return
		end
		local info, why = ns.ReadCameraShare(self:GetText())
		window.info = info
		action:SetEnabled(info ~= nil)
		if not info then
			window.review:SetText(why and WHY[why] and L[WHY[why]] or "")
			return
		end
		local function Safe(text) return (tostring(text or ""):gsub("|", "||")) end
		local lines = {}
		if info.kind == "shot" then
			lines[1] = ("|cffffd100%s|r %s"):format(L["Shot:"], Safe(info.name or ""))
			lines[2] = (L["Camera: %s"]):format(ns.CAMERA_NAMES[info.base] or info.base)
		else
			lines[1] = ("|cffffd100%s|r %s"):format(L["Scene:"], Safe(info.name or ns.DescribeTriggerSource(info.source)))
			local starts = {}
			for _, source in ipairs(info.triggers or { info.source }) do starts[#starts + 1] = ns.DescribeTriggerSource(source) end
			lines[2] = (L["Triggers: %s"]):format(Safe(table.concat(starts, ", ")))
			lines[3] = (L["Camera: %s"]):format(info.shot and (L["%s (a shot of its own, added too)"]):format(
				Safe(info.shot.name or ns.CAMERA_NAMES[info.shot.base])) or ns.CAMERA_NAMES[info.camera] or info.camera)
		end
		window.review:SetText(table.concat(lines, "\n"))
	end)
	action:SetScript("OnClick", function()
		if window.mode == "export" then
			box:SetFocus()
			box:HighlightText()
			return
		end
		if not window.info then return end
		if window.reader then
			local done, why = window.reader.add(window.info)
			if done then window:Hide() else window.review:SetText(why or "") end
			return
		end
		local id, why = ns.AddCameraShare(window.info)
		if not id then
			window.review:SetText(L[WHY[why or "full"]])
			return
		end
		window:Hide()
		if window.onAdded then window.onAdded(id, window.info.kind) end
	end)
	return window
end

function ns.ShowCameraShare(text, title)
	local w = Window()
	w.mode, w.text, w.info = "export", text, nil
	w.title:SetText(title)
	w.hint:SetText(L["Press Ctrl+C to copy this, then paste it wherever your friend will see it."])
	w.review:SetText("")
	w.action:SetText(L["Select all"])
	w.action:SetEnabled(true)
	w:Show()
	w.box:SetText(text)
	w.box:SetFocus()
	w.box:HighlightText()
end

-- onAdded(id, kind): what was added ("trigger" or "shot").
function ns.ShowCameraImport(onAdded)
	local w = Window()
	w.mode, w.text, w.info, w.onAdded, w.reader = "import", nil, nil, onAdded, nil
	w.title:SetText(L["Import a scene or shot"])
	w.hint:SetText(L["Paste the text a friend sent (Ctrl+V). What it holds shows below before you add it."])
	w.review:SetText("")
	w.action:SetText(L["Add it"])
	w.action:SetEnabled(false)
	w:Show()
	w.box:SetText("")
	w.box:SetFocus()
end

-- The same window for another page's shared thing. reader: read(text) ->
-- info or nil and why (text); describe(info) -> what it holds (text);
-- add(info) -> true, or nil and why.
function ns.ShowShareImport(title, reader)
	local w = Window()
	w.mode, w.text, w.info, w.onAdded, w.reader = "import", nil, nil, nil, reader
	w.title:SetText(title)
	w.hint:SetText(L["Paste the text a friend sent (Ctrl+V). What it holds shows below before you add it."])
	w.review:SetText("")
	w.action:SetText(L["Add it"])
	w.action:SetEnabled(false)
	w:Show()
	w.box:SetText("")
	w.box:SetFocus()
end
