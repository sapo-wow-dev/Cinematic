-- Known errors and don'ts: every error traced to its root, and the rule for
-- our code that keeps it from coming back. Format and workflow: README.md.
-- Check after editing: python -I Tools/errors/errors.py selftest
return {
  -- Menus -----------------------------------------------------------------
  {
    id = "menu-row-smartnav-fight",
    status = "fixed",
    title = "A menu opened in a fight: one blocked line per title/divider row our code added (Forever, gamepad mode on or off)",
    match = {
      all = { "SmartNavigation_MarkFrameIgnored", "SetSecureValue" },
      any = { "MenuTemplates.lua" },
    },
    why = {
      call = "SetAttribute(\"setkeyvalue\") from SmartNavigation_MarkFrameIgnored -> SecureHelper:SetSecureValue; its validate (issecure() or no combat restriction) fails, so DisplayInterfaceActionBlockedMessage",
      caller = "Emote Vision's Menu.ModifyMenu hook on MENU_UNIT_TARGET (AddSection: root:CreateDivider + root:CreateTitle(\"Emote\")); x2 = the divider + the title",
      path = "right-clicking the target frame in a fight opens the game's unit menu; our hook adds the Emote section; the game runs each row's initializer, and the title/divider initializers we created run under our taint",
      rule = "Forever's Blizzard_Menu (MenuTemplates CreateTitle/CreateDivider/CreateSpacer) always marks those rows, gamepad mode on or off (Blizzard_GamepadSmartNavigation always loads; most other game gamepad calls are behind InputUtil.IsGamepadUIEnabled(), these are not), with SmartNavigation_MarkFrameIgnored; from insecure code that goes through SetAttribute, refused in combat. Buttons only read SmartNavigation, so they're fine",
      pattern = "any root:CreateTitle / CreateDivider / CreateSpacer from our code (27 places, our own dropdowns too) on a menu that can open in a fight",
    },
    dont = "Don't call root:CreateTitle / CreateDivider / CreateSpacer: use ns.MenuTitle(root, text) / ns.MenuDivider(root) (Skin.lua), which build the same row with our own initializer and mark it only out of a fight.",
    check = { pattern = [[:Create(Title|Divider|Spacer)\(]], allow = { "Skin.lua" } },
    fix = "2026-11-23: ns.MenuTitle / ns.MenuDivider (Skin.lua); every call site moved. With SmartNavigation_MarkFrameIgnored (Forever) the row is root:CreateFrame() + our initializer (MenuVariants font string / divider, mark skipped in a fight); else the game's own row (retail unchanged). Tools/offline/menurows.lua",
    engine = { "forever.menu.title-divider-smartnav-combat" },
    seen = { "2026-11-23" },
    example = [[blocked (no event): Interface action failed line, (in combat)
[Blizzard_GamepadSmartNavigation/SecureHelper.lua]:156: in function 'SetSecureValue'
[Blizzard_GamepadSmartNavigation/Utility.lua]:50: in function 'SmartNavigation_MarkFrameIgnored'
[Blizzard_Menu/MenuTemplates.lua]:299: in function 'initializer'
[Blizzard_Menu/Menu.lua]:1034: in function <Blizzard_Menu/Menu.lua:1031>
[Blizzard_UnitPopupShared/UnitPopupShared.lua]:109: in function <.../AddOns/Blizzard_UnitPopupShared/UnitPopupShared.lua:22>
[Blizzard_UnitFrame/Mainline/TargetFrame.lua]:674: in function <...e/AddOns/Blizzard_UnitFrame/Mainline/TargetFrame.lua:624>]],
    source = "pasted 2026-11-23 (right-click target frame in a fight, Forever)",
  },
  -- Settings window -------------------------------------------------------
  {
    id = "settings-pick-in-fight-gamepad",
    status = "accepted",
    title = "Settings opened from our code in a fight: one blocked line per list row (gamepad UI)",
    match = {
      all = { "SmartNavigation", "SetSecureValue" },
      any = { "PickSettingsCategory", "OpenOptions", "OpenSettingsCategory" },
    },
    why = {
      call = "SetAttribute via SmartNavigation_SetCustomCursorAnchorPointForFrame -> SetSecureValue, blocked in combat",
      caller = "ns.PickSettingsCategory's fight branch (SettingsPanel:Show + SelectCategory), from ns.OpenOptions / the settings key",
      path = "players want the settings to open in fights (user decision 2026-11-20); OpenToCategory's ShowUIPanel is blocked then, so the panel is shown and the page picked directly",
      rule = "SelectCategory redraws the left list; every row's Init sets the gamepad cursor anchor with SetAttribute, blocked in combat under our taint",
      pattern = "opening Settings from addon code in a fight; and (2026-11-22) quieting it by a flag that only one caller set",
    },
    dont = "Don't open or pick a Settings page from our code in a fight except through ns.PickSettingsCategory, which marks the fight so the blocks stay out of the dev box; never quiet a known block by a flag a caller must remember to set: match its stack.",
    check = { pattern = [[:SelectCategory\(]], allow = { "Options.lua", "Dev/" } },
    fix = "accepted: the yellow lines are harmless (gamepad cursor not set on those rows). 2026-11-22: ns.QuietSettingsBlock also matches the stack itself (PickSettingsCategory + SetSecureValue), and PickSettingsCategory sets the fight flag for every caller",
    engine = { "forever.settings.smartnavigation-setsecurevalue-combat" },
    seen = { "2026-11-20", "2026-11-22" },
    example = [[blocked (no event): Interface action failed line, (in combat)
[Blizzard_GamepadSmartNavigation/SecureHelper.lua]:156: in function 'SetSecureValue'
[Blizzard_GamepadSmartNavigation/Utility.lua]:180: in function 'SmartNavigation_SetCustomCursorAnchorPointForFrame'
[Blizzard_Settings_Shared/Blizzard_CategoryList.lua]:106: in function 'Init'
[CinematicDev/Options.lua]:20578: in function 'PickSettingsCategory'
[CinematicDev/Options.lua]:20607: in function 'OpenOptions']],
    source = "memory: settings-open-gamepad-blocked-line",
  },
  {
    id = "settings-open-focus-line",
    status = "accepted",
    title = "One \"Interface action failed\" line when our code opens Settings (gamepad focus, no event)",
    match = { all = { "EnterFocusGroup" } },
    why = {
      call = "DisplayInterfaceActionBlockedMessage from SmartNavigation:EnterFocusGroup's EnsureIsSecure",
      caller = "Settings.OpenToCategory from ns.PickSettingsCategory (any open from our code)",
      path = "the settings key, /cine, the minimap button and Reload.lua's restore all open Settings from addon code",
      rule = "ActivateCategory -> FocusContainer -> EnterFocusGroup needs secure execution; only when not IsInFocusGroup(), so intermittent; no ADDON_ACTION_BLOCKED event; printed once a session",
      pattern = "opening Settings from addon code (unavoidable for a settings key)",
    },
    dont = "Don't trace blocked lines with event watchers alone: hook DisplayInterfaceActionBlockedMessage + chat AddMessage with debugstack (Dev/ErrorWindow.lua does).",
    fix = "accepted 2026-11-18: harmless, gamepad focus just isn't put on the page",
    engine = { "forever.settings.smartnavigation-blocked-line" },
    seen = { "2026-11-18", "2026-11-19" },
    example = [[blocked (no event): Interface action failed line, (out of combat)
[Blizzard_GamepadSmartNavigation/SmartNavigation.lua]:84: in function 'EnterFocusGroup'
[Blizzard_Settings_Shared/Blizzard_SettingsPanel.lua]:900: in function 'FocusContainer']],
    source = "memory: settings-open-gamepad-blocked-line",
  },
  {
    id = "settings-list-tainted-escape-options",
    status = "fixed",
    title = "Escape > Options in a fight: every settings row blocked (left list tainted by an earlier open of ours)",
    match = {
      -- (Rows: SmartNavigation_SetButtonFrame; left list lines:
      -- SetCustomCursorAnchorPointForFrame. The game's open comes from the
      -- Game Menu; 2026-11-22's stack had only the second, and matched nothing.)
      all = { "SmartNavigation", "SetSecureValue" },
      any = { "SmartNavigation_SetButtonFrame", "GameMenuFrame" },
      none = { "PickSettingsCategory", "OpenOptions", "OpenSettingsCategory" },
    },
    why = {
      call = "SetSecureValue from every settings row's SmartNavigation_SetButtonFrame and list line's SetCustomCursorAnchorPointForFrame (1756 lines)",
      caller = "none in the stack: the game's own Escape > Options; ours came earlier in the session",
      path = "our SelectCategory of an AddOns-tab page switched the list's category set (Game -> AddOns) and rebuilt it under our taint; out of a fight that's now OpenToCategory (clean), but IN a fight ns.PickSettingsCategory still calls SelectCategory (players want settings in fights, 2026-11-20)",
      rule = "SetCategorySet + CreateCategories from addon code leave the list's fields written by us till /reload; the game's later rebuild reads them tainted",
      pattern = "calling SettingsPanel:SelectCategory from our code, in or out of a fight",
    },
    dont = "Don't call SettingsPanel:SelectCategory from our code; pick pages with Settings.OpenToCategory, only in ns.PickSettingsCategory. In a fight with the gamepad UI, open the window with no pick and pick once the fight ends.",
    check = { pattern = [[Settings\.OpenToCategory\(]], allow = { "Options.lua", "Dev/" } },
    fix = "2026-11-20: ns.PickSettingsCategory = OpenToCategory out of combat (/cine debug taintopen 7 PASS). 2026-11-22 /cine debug fightopen step 3 FAIL: an in-fight open of ours, then Escape > Options in a new fight = dev box +1756 (players: yellow line once a session, the game prints it once). 2026-11-22 user picked: with the gamepad UI, ns.OpenOptions in a fight = panel:Show() with no pick, our page picked by OpenToCategory at PLAYER_REGEN_ENABLED if still open (Tools/offline/quietblock.lua); /cine debug fightopen 4/4 PASS in game 2026-11-22: Escape > Options in a later fight 0 blocked, Card Vision picked after the fight",
    engine = { "forever.settings.addon-categoryset-taints-list", "forever.settings.show-in-fight-no-pick-clean" },
    seen = { "2026-11-20", "2026-11-22" },
    example = [[blocked (no event): Interface action failed line, (in combat)
[Blizzard_GamepadSmartNavigation/SecureHelper.lua]:156: in function 'SetSecureValue'
[Blizzard_GamepadSmartNavigation/Utility.lua]:120: in function 'SmartNavigation_SetButtonFrame']],
    source = "memory: settings-open-gamepad-blocked-line",
  },
  {
    id = "settings-social-oauth",
    status = "accepted",
    title = "Settings > Social: \"has been blocked\" popup for IsUserOAuthed after our code opened Settings",
    match = { all = { "IsUserOAuthed" } },
    why = {
      call = "IsUserOAuthed() in Blizzard_SettingsDefinitions_Frame/Social.lua",
      caller = "none in the stack; any earlier Settings open from our code this session",
      path = "opening Settings from code writes the category list's current category tainted",
      rule = "every later page change reads it first, so the taint lasts till /reload",
      pattern = "opening Settings from addon code (unavoidable for a settings key)",
    },
    dont = "Don't re-investigate: no taint-free open exists (timers, hooks, secure-call helpers, nil all keep the taint).",
    fix = "accepted 2026-11-11: harmless, Social's rows blank that session",
    engine = { "forever.settings.open-from-code-taints-social" },
    seen = { "2026-11-11" },
    example = [[forbidden: CinematicDev: IsUserOAuthed() (out of combat)
[Blizzard_SettingsDefinitions_Frame/Social.lua]:40: in function <...>]],
    source = "memory: settings-open-taint",
  },
  {
    id = "settings-close-game-menu",
    status = "fixed",
    title = "Closing Settings from our code: blocked popup (ToggleGameMenu)",
    match = { all = { "ToggleGameMenu" } },
    why = {
      call = "ToggleGameMenu, protected for addons",
      caller = "our SettingsPanel:Close() (Toggle settings key)",
      path = "the key closes the window it opened",
      rule = "Close() without true goes back to the Game Menu (TransitionBackOpeningPanel -> ToggleGameMenu)",
      pattern = "SettingsPanel:Close() with no argument",
    },
    dont = "Always close Settings from our code with SettingsPanel:Close(true).",
    check = { pattern = [[SettingsPanel:Close\(\s*\)]] },
    fix = "2026-11-06: Close(true)",
    seen = { "2026-11-06" },
    example = [[blocked: CinematicDev: ToggleGameMenu() (out of combat)]],
    source = "memory: settings-close-game-menu",
  },

  -- Blocked game functions ------------------------------------------------
  {
    id = "quit-from-addon",
    status = "fixed",
    title = "Quit/Logout from our popup button: forbidden",
    match = { any = { "Quit()", "ForceQuit()", "Logout()" }, all = { "forbidden" } },
    why = {
      call = "Quit (OnAccept of our popup)",
      caller = "CINEMATIC_WORLD_TEXT_RESTART's Exit game button",
      path = "a setting that needs a restart offered to quit for the player",
      rule = "Quit, ForceQuit and Logout are the game's alone; addon code calling them is forbidden",
      pattern = "a popup button wired to a game exit function",
    },
    dont = "Never call Quit, ForceQuit or Logout; tell the player to restart instead.",
    check = { pattern = [[(?<![\w.:])(Quit|ForceQuit|Logout)\(]] },
    fix = "2026-11-10: the popup has only a Close button",
    seen = { "2026-11-10" },
    example = [[forbidden: CinematicDev: OnAccept() Quit() (out of combat)]],
    source = "memory: quit-forbidden",
  },
  {
    id = "reloadui-blocked-forever",
    status = "fixed",
    title = "ReloadUI from our code: blocked on Forever (UNKNOWN() via C_UI.Reload)",
    match = { any = { "C_UI.Reload", "ReloadUI" } },
    why = {
      call = "C_UI.Reload (ADDON_ACTION_BLOCKED UNKNOWN())",
      caller = "ReloadUI() in our code, from a timer or a plain button's OnClick",
      path = "settings that need a reload reloaded for the player",
      rule = "Forever blocks ReloadUI from addon code, even from a click; a secure /reload macro button works",
      pattern = "calling ReloadUI directly",
    },
    dont = "Never call ReloadUI directly: ns.Reload(), a cineReload popup button, or ns.ReloadOrAsk(text).",
    check = { pattern = [[(?<![\w.:])ReloadUI\(]], allow = { "QoL/Reload.lua", "Dev/" } },
    fix = "2026-11-20: QoL/Reload.lua (secure macro cover on Forever)",
    engine = { "forever.reloadui.blocked" },
    seen = { "2026-11-20" },
    example = [[blocked: CinematicDev: UNKNOWN() (out of combat)
[C]: in function 'C_UI.Reload']],
    source = "memory: reload-blocked-forever",
  },
  {
    id = "setuivisibility-in-fight",
    status = "fixed",
    title = "Hiding the UI in a fight: SetUIVisibility blocked",
    match = { all = { "SetUIVisibility" } },
    why = {
      call = "SetUIVisibility, blocked in combat for addons",
      caller = "HideUI.lua (CineShot key)",
      path = "CineShot hides the UI for a screenshot",
      rule = "a key binding doesn't make it safe; a blocked show can leave the UI hidden",
      pattern = "SetUIVisibility with no InCombatLockdown() check",
    },
    dont = "Never call SetUIVisibility in a fight: refuse it, and wait for PLAYER_REGEN_ENABLED to bring the UI back.",
    fix = "HideUI.lua refuses in fights, BringBack waits for the fight's end",
    seen = { "2026-11" },
    example = [[blocked: CinematicDev: action SetUIVisibility() (in combat)]],
    source = "memory: setuivisibility-blocked",
  },

  -- Taint -------------------------------------------------------------------
  {
    id = "bag-globals-taint",
    status = "fixed",
    title = "Bag item right-click forbidden (UseContainerItem) after we wrote a bag global",
    match = { all = { "UseContainerItem" } },
    why = {
      call = "UseContainerItem, protected on Forever",
      caller = "none in the stack: the game's own click; CombineBags.lua had written ENDING_BAG_INDEX",
      path = "widening the combined backpack to profession bags",
      rule = "the game reads that global in its click path; written by us it taints every bag click till /reload",
      pattern = "writing a Blizzard global or replacing a method on a game frame",
    },
    dont = "Never write Blizzard globals or replace methods on game frames; only hooksecurefunc.",
    check = { pattern = [[(?<![\w.])ENDING_BAG_INDEX\s*=(?!=)]] },
    fix = "2026-11-10: CombineBags removed",
    seen = { "2026-11-10" },
    example = [[forbidden: CinematicDev: UseContainerItem() (out of combat)]],
    source = "memory: combine-bags-taint",
  },
  {
    id = "test-global-swap-taint",
    status = "fixed",
    title = "CompactUnitFrame errors on secret health after a test swapped the game's unit functions",
    match = { all = { "CompactUnitFrame", "tainted by CinematicDev" }, any = { "maxHealth", "UpdateHealPrediction" } },
    why = {
      call = "CompactUnitFrame_UpdateHealPrediction compares secret maxHealth under our taint (x1322)",
      caller = "none in the stack: the game's raid/party frame update; Dev/PvpCardTest.lua had set _G.UnitExists, UnitGUID, UnitIsPlayer, UnitCanAttack, UnitIsUnit, IsInInstance for one call and put them back",
      path = "a test pretending a duel by making the game's unit reads say your target is an enemy player",
      rule = "a global written by addon code stays tainted till /reload, even written back to the same function; every game frame calling it then runs tainted and secret values error",
      pattern = "writing a Blizzard global for a moment (pretend/stub in a game test)",
    },
    dont = "Never write a game global from in-game code, not even for a moment: hand pretend reads in as an argument (ns.CardPvpFight(reads)). Stubbing globals is for the offline stand-in only.",
    check = { pattern = [[_G(\.(Unit\w+|IsInInstance|GetInstanceInfo|C_\w+)|\[\w+\])\s*=(?!=)]], allow = { "Tools/" } },
    fix = "2026-11-23: CombatVision.lua's PvP check takes a reads table; the test hands it pretend ones",
    seen = { "2026-11-23" },
    example = [[error (Blizzard_UnitFrame, tainted by CinematicDev)
...ddOns/Blizzard_UnitFrame/Shared/CompactUnitFrame.lua:1205: attempt to compare local 'maxHealth' (a secret number value, while execution tainted by 'CinematicDev')
[Blizzard_UnitFrame/Shared/CompactUnitFrame.lua]:1205: in function 'CompactUnitFrame_UpdateHealPrediction']],
    source = "/cine debug pvpcard run 3",
  },
  {
    id = "edit-mode-refresh-taints",
    status = "fixed",
    title = "Edit Mode errors on secret values after our code refreshed its layouts",
    match = { any = { "UpdateLayoutInfo", "ForceTaint_Strong" } },
    why = {
      call = "CompactUnitFrame_UpdateHealthColor compares a secret number (RefreshPartyFrames)",
      caller = "EditModeManagerFrame:UpdateLayoutInfo from our code",
      path = "making Edit Mode re-read a layout we saved",
      rule = "the manager's layout data turns insecure; its party refresh then touches secrets",
      pattern = "calling Edit Mode's manager methods from our code",
    },
    dont = "Never refresh Edit Mode's layout list from our code; a new layout waits for /reload.",
    check = { pattern = [[UpdateLayoutInfo\(]] },
    fix = "2026-10-22: reload prompt kept (ns.RegenerateLayout)",
    seen = { "2026-10-22" },
    example = [[Blizzard_UnitFrame/CompactUnitFrame.lua:400: attempt to compare (a secret number value, while execution tainted by ForceTaint_Strong)]],
    source = "memory: edit-mode-refresh-taints",
  },
  {
    id = "game-unit-template-copy",
    status = "fixed",
    title = "Unit frame made from a game template errors on secret health (Forever)",
    match = { all = { "secret", "Blizzard_UnitFrame/UnitFrame.lua" } },
    why = {
      call = "compares on secret maxHealth/currValue in UnitFrame.lua / TextStatusBar.lua",
      caller = "CreateFrame(..., \"TargetFrameTemplate\") + OnLoad(\"player\") (the self-target stand-in)",
      path = "copying the game's look by using its template",
      rule = "a game template's code runs tainted by us, and tainted code can't compare secrets",
      pattern = "building our frames from the game's unit frame templates",
    },
    dont = "Never make our frames from game unit frame templates; draw our own (atlases + StatusBar:SetValue, no compares).",
    check = { pattern = [["(Target|Focus|Player|Party|Boss|Arena)FrameTemplate"]], allow = { "Dev/" } },
    fix = "2026-11-20: the stand-in draws its own frame",
    seen = { "2026-11-20" },
    example = [[Interface/AddOns/Blizzard_UnitFrame/UnitFrame.lua:250: attempt to compare local 'maxHealth' (a secret number value, while execution tainted by 'CinematicDev')]],
    source = "memory: template-copy-taints",
  },
  {
    id = "game-nameplate-template-events",
    status = "fixed",
    title = "A nameplate made from the game's template errors on every target change (Forever)",
    match = { all = { "UnitWidgetSet", "CompactUnitFrame.lua" } },
    why = {
      call = "UnitWidgetSet(frame.unit) with frame.unit nil, in CompactUnitFrame_UpdateWidgetSet (CompactUnitFrame.lua:1557), from CompactUnitFrame_OnEvent's PLAYER_TARGET_CHANGED / PLAYER_SOFT_ENEMY_CHANGED / PLAYER_SOFT_FRIEND_CHANGED branch (:83) via NamePlateUnitFrameMixin:OnEvent (Blizzard_NamePlateUnitFrame.lua:108)",
      caller = "our own CreateFrame(\"Button\", nil, parent, \"NamePlateUnitFrameTemplate\") copies (the plate preview's game plate; /cine debug platematch run 1's hidden A/B copies)",
      path = "building the preview's plate from the game's own template so it matches a real plate",
      rule = "the template's OnLoad registers the plate's events, and a copy never gets a unit (the mixin has no SetUnit): every target, soft-target or mouse-click target change runs the unit code on nil (engine rule forever.plate.unitframe-template-copy)",
      pattern = "a game unit-frame template made and left with the events its OnLoad registered",
    },
    dont = "Never leave a frame made from a game nameplate or compact unit frame template with its events: UnregisterAllEvents and OnEvent nil on it and every child right after CreateFrame (Plates/PlateCopy.lua Quiet), keeping only the OnUpdate you play on purpose.",
    check = { pattern = [["(Base)?NamePlateUnitFrameTemplate"|"CompactUnitFrameTemplate"]], allow = { "Plates/PlateCopy.lua", "Dev/" } },
    fix = "2026-11-23: Plates/PlateCopy.lua Build quiets the copy and its children at once (the cast bar keeps its OnUpdate); offline proof Tools/offline/platecopyevents.lua",
    seen = { "2026-11-23" },
    example = [[...ddOns/Blizzard_UnitFrame/Shared/CompactUnitFrame.lua:1557: bad argument #1 to 'UnitWidgetSet' (Usage: local uiWidgetSet = UnitWidgetSet(unit)) [Blizzard_UnitFrame/Shared/CompactUnitFrame.lua]:83: in function 'CompactUnitFrame_OnEvent' [Blizzard_NamePlates/Blizzard_NamePlateUnitFrame.lua]:108 [C]: in function 'CameraOrSelectOrMoveStop']],
    source = "Tools/engine/rules forever.plate.unitframe-template-copy; Tools/tests/plate-preview-match.md",
  },
  {
    id = "secure-anchor-insecure",
    status = "fixed",
    title = "A secure frame anchored to an insecure one: SetPoint refused (Forever)",
    match = { all = { "Cannot anchor protected frames to regions" } },
    why = {
      call = "SetPoint on a SecureActionButtonTemplate button",
      caller = "the reload cover over StaticPopup buttons (QoL/Reload.lua)",
      path = "putting a secure button over a game frame's button",
      rule = "Forever refuses anchoring a protected frame to an insecure region",
      pattern = "SetPoint of a secure overlay onto the frame it covers",
    },
    dont = "Never anchor a secure overlay to the frame it covers: place it by screen rect from UIParent (re-place from a ticker).",
    fix = "2026-11-20: placed by screen rect (/cine debug reloadcover 4/4)",
    seen = { "2026-11-20" },
    example = [[Action[SetPoint] failed because[Cannot anchor protected frames to regions]: attempted from: CinematicDev]],
    source = "memory: secure-anchor-insecure-forever",
  },
  {
    id = "chat-send-secret",
    status = "accepted",
    title = "SendChatMessage with a secret number in the text",
    match = { all = { "Secret values are only allowed during untainted execution", "SendChatMessage" } },
    why = {
      call = "SendChatMessage",
      caller = "a chat line built from UnitPower/UnitHealth",
      path = "a mana or health message for the party",
      rule = "chat refuses secret values from tainted code; Forever's mana is secret out of combat too",
      pattern = "putting a unit's power or health into a chat or ping message",
    },
    dont = "Never send secret numbers in chat or pings; fixed text only.",
    fix = "accepted: no feature sends them",
    engine = { "forever.sendchatmessage.secret-arg" },
    seen = { "2026-11-13" },
    example = [[bad argument #1 to 'SendChatMessage' (Secret values are only allowed during untainted execution for this argument)]],
    source = "memory: chat-secret-blocked",
  },

  -- Calls and drawing ----------------------------------------------------------
  {
    id = "timer-game-function-callback",
    status = "fixed",
    title = "C_Timer.After refuses a game function as its callback (Forever)",
    match = { all = { "Usage: C_Timer.After(seconds, callback)" } },
    why = {
      call = "C_Timer.After(0, Screenshot)",
      caller = "CineShot's key",
      path = "taking the shot a frame later",
      rule = "Forever's timer refused the game's own function as a callback (reason not read)",
      pattern = "passing a game API function straight to a timer",
    },
    dont = "Pass timers a function of ours (function() Screenshot() end), never a game function.",
    check = { pattern = [[C_Timer\.(After|NewTimer|NewTicker)\([^,]+,\s*(Screenshot|ReloadUI|ToggleFrame|ShowUIPanel|HideUIPanel)\s*\)]] },
    fix = "2026-11-06: wrapped",
    seen = { "2026-11-06" },
    example = [[bad argument #2 to '?' (Usage: C_Timer.After(seconds, callback))]],
    source = "memory: timer-game-function-callback",
  },
  {
    id = "settexture-filter-crash",
    status = "fixed",
    title = "Game crash (ACCESS_VIOLATION) from SetTexture with a filter mode (retail)",
    match = { all = { "ACCESS_VIOLATION" } },
    note = "a crash report (Errors/*.txt), not a Lua error; its Lua stack lands on random later calls",
    why = {
      call = "Texture:SetTexture(art, nil, nil, \"TRILINEAR\")",
      caller = "PlateCastStyle.lua's preview, while Options built its pages",
      path = "a smoother icon",
      rule = "retail crashed natively on the filter argument",
      pattern = "passing a filter mode (4th argument) to SetTexture",
    },
    dont = "Never pass a filter mode (TRILINEAR, LINEAR, NEAREST) to SetTexture; wrap modes (CLAMP, REPEAT) are fine and used widely. A crash with a random stack = suspect an earlier native call, bisect by last edits.",
    check = { pattern = [[SetTexture\([^)]*"(TRILINEAR|LINEAR|NEAREST)"]] },
    fix = "2026-10-29: plain SetTexture",
    seen = { "2026-10-29" },
    example = [[ERROR #132 (0x85100084) Fatal exception! ACCESS_VIOLATION]],
    source = "memory: settexture-filter-crash",
  },
  {
    id = "points-count-secret",
    status = "fixed",
    title = "'for' limit must be a number: a loop over another addon's GetNumPoints in a fight (Forever)",
    match = { all = { "'for' limit must be a number" } },
    why = {
      call = "for i = 1, frame:GetNumPoints() do, with a secret count",
      caller = "Support/EllesmereUI.lua's IsAnchoredTo, from the chat scanner FindChat (each scan tick)",
      path = "it reads the anchors of every unnamed UIParent child to find EllesmereUI's chat parts, in fights too",
      rule = "on WoW Forever another addon's frame can give a secret GetNumPoints in a fight; a for loop can't take a secret limit",
      pattern = "looping over a raw GetNumPoints() count; it errored every tick, so the safety check stopped Cinematic for the session",
    },
    dont = "Never read frame:GetNumPoints() directly (a loop limit, a compare, tonumber, a format): use ns.NumPoints(frame) (0 when the count is secret or refused).",
    check = { pattern = [[:GetNumPoints\(\)]], allow = { "Dev/", "Tools/" } },
    fix = "2026-11-22: ns.NumPoints (Core.lua) in every such loop (issue #7); then every other raw read too (compares, tonumber, debug prints), and the check widened from loops to any :GetNumPoints() call",
    engine = { "forever.frame.numpoints-secret-in-fight" },
    seen = { "2026-11-22" },
    example = [[Interface/AddOns/Cinematic/Support/EllesmereUI.lua:704: 'for' limit must be a number
[Cinematic/Support/EllesmereUI.lua]:704: in function <Cinematic/Support/EllesmereUI.lua:703>
[Cinematic/Support/EllesmereUI.lua]:758: in function '?']],
    source = "GitHub issue #7 (EllesmereUI 9.9.1, Forever)",
  },
  {
    id = "region-refuses-tainted-code",
    status = "fixed",
    title = "calling '?' on bad self (forbidden object from tainted code) on a part that isn't IsForbidden (Forever fight)",
    match = { all = { "on bad self", "Attempt to access forbidden object" } },
    why = {
      call = "region:GetParent() (and IsShown, GetText before d88eb23)",
      caller = "FadeDetached.lua's Detached, from Walk / ns.SyncDetached while fading a root",
      path = "fading the UI walks every part under a faded frame (EllesmereUI's chat dock here) to find the detached ones",
      rule = "in a fight on WoW Forever a region can say IsForbidden() false and still refuse tainted code",
      pattern = "trusting IsForbidden() alone before calling methods on other addons' or the game's parts",
    },
    dont = "Never guard with IsForbidden() alone: use ns.Reachable(frame) (Checks.lua), which also skips a frame that refuses our code in a fight (CanBeAccessedInContext() false).",
    check = { pattern = [[:IsForbidden\(\)]], allow = { "Checks.lua", "Dev/", "Tools/", "Libs/" } },
    fix = "2026-11-22: ns.Reachable (Checks.lua: not forbidden, a secret answer counts as forbidden, and in a fight CanBeAccessedInContext() asked once per frame, kept till the fight ends; a GetParent probe where a client has no such check) in place of every IsForbidden() guard, 144 in 48 files (issue #7). Earlier: d88eb23 for IsShown/GetText in Frames.lua",
    engine = { "forever.frame.not-forbidden-still-refuses" },
    seen = { "2026-11-11", "2026-11-22" },
    example = [[Interface/AddOns/Cinematic/FadeDetached.lua:155: calling '?' on bad self (Attempt to access forbidden object from code tainted by an AddOn - Usage: local parent = self:GetParent())
[C]: in function '?'
[Cinematic/FadeDetached.lua]:155: in function <Cinematic/FadeDetached.lua:154>]],
    source = "GitHub issue #7 (EllesmereUI 9.9.1, Forever)",
  },
  {
    id = "taintlog-hook-nil-call",
    status = "accepted",
    title = "\"attempt to call a nil value\" at [C] in a function we hook, while taintLog is on",
    match = { all = { "attempt to call a nil value", "[C]: in function 'UpdateHappiness'" }, any = {} },
    note = "only counts with /console taintLog 2 on; seen on UpdateHappiness, SetUnit, CheckLevel. Ask whether taintLog is on",
    why = {
      call = "a hooksecurefunc'd game function",
      caller = "none of ours in the stack",
      path = "taintLog 2 was on to trace a taint",
      rule = "with taintLog 2 hooked functions can error at [C]; gone with taintLog 0",
      pattern = "none in our code",
    },
    dont = "Don't rewrite hooks for these: ask whether taintLog is on first.",
    fix = "accepted 2026-10-20",
    seen = { "2026-10-20" },
    example = [[attempt to call a nil value
[C]: in function 'UpdateHappiness']],
    source = "memory: taintlog-hook-errors",
  },

  -- Lua 5.1 ------------------------------------------------------------------
  {
    id = "lua-local-cap",
    status = "fixed",
    title = "A file won't load: more than 200 local variables in its main chunk",
    match = { all = { "more than 200 local variables" } },
    note = "knock-on errors follow (Frames.lua not loading = Core/Options error on ns.PLACE_SHOW nil)",
    why = {
      call = "loading the file (Lua 5.1)",
      caller = "a new top-level local in a file at the cap (Frames.lua, Camera.lua)",
      path = "adding a helper",
      rule = "Lua allows 200 live locals per main chunk; luacheck doesn't check it",
      pattern = "adding top-level locals to a big file",
    },
    dont = "Add no top-level local to a big file: put helpers in a do block or on a table. Checked by the offline load (pre-commit).",
    fix = "v1.8.26; the pre-commit offline check loads every file in Lua 5.1",
    seen = { "2026-10-14", "2026-10-15", "2026-10-20" },
    example = [[Frames.lua:9000: main function has more than 200 local variables]],
    source = "memory: lua-local-cap",
  },
  {
    id = "lua51-ambiguous-call",
    status = "fixed",
    title = "A file won't load: ambiguous syntax (a line starting with \"(\")",
    match = { all = { "ambiguous syntax" } },
    why = {
      call = "loading the file (Lua 5.1)",
      caller = "an assignment right above a (function() ... end)() block",
      path = "adding a line above such a block",
      rule = "Lua 5.1 reads a line starting with ( after an expression as a call; newer Lua (and luacheck) allow it",
      pattern = "a statement ending in an expression right before a (-led line",
    },
    dont = "Never put an assignment or call right before a line starting with (; end it with ; or move it. Checked by the offline load (pre-commit).",
    fix = "2026-10-19; the pre-commit offline check loads every file in Lua 5.1",
    seen = { "2026-10-19" },
    example = [[Frames.lua:120: ambiguous syntax (function call x new statement) near '(']],
    source = "memory: lua51-ambiguous-call",
  },
  {
    id = "lua-multireturn-arg",
    status = "fixed",
    title = "A call's second return value lands in the next argument (next(f()), tonumber(f()))",
    match = { any = { "invalid key to 'next'", "bad argument #2 to 'tonumber'" } },
    why = {
      call = "next(t, k) / tonumber(v, base) given a function's results straight in",
      caller = "Dev/ShelfTest.lua's everyswitch step: next(row.Switches()); earlier PlateParts' tonumber(ns.NameLookValue(...))",
      path = "checking a returned table is empty (or a returned value is a number) in one expression",
      rule = "in Lua a call as the last argument expands to all its returns: row.Switches() gives mine, undo, so undo went in as next's key (not a key of mine: error); a second return went in as tonumber's base",
      pattern = "a function call passed as the last argument to next or tonumber, where the callee returns more than one value; luacheck can't see return counts",
    },
    dont = "Never pass a call straight into next( or tonumber(: put its result in a local first, or wrap it, next((f())) / tonumber((f())). The check covers next(; tonumber( calls are too many to flag, so keep helpers fed to it single-return (return (f())).",
    check = { pattern = [[\bnext\(\s*[A-Za-z_][A-Za-z0-9_.:]*\([^()]*\)\s*\)]] },
    fix = "2026-11-22: ShelfTest keeps Switches()'s first in a local; the other next(f()) lines wrapped; this check stops new ones at commit",
    engine = { "all.lua.tonumber-multireturn" },
    seen = { "2026-11-14", "2026-11-22" },
    example = [[invalid key to 'next'
[C]: in function 'next'
[CinematicDev/Dev/ShelfTest.lua]:954: in function <CinematicDev/Dev/ShelfTest.lua:952>]],
    source = "memory: lua-multireturn-traps",
  },
  {
    id = "lua-local-before-defined",
    status = "fixed",
    title = "attempt to call a nil value: a local function called above its own local line",
    match = { all = { "attempt to call a nil value" }, any = { "in function 'Columns'" } },
    why = {
      call = "Columns() inside grid.SubLine (UI/CooldownGrid.lua), drawing the CDM page's Buffs tab",
      caller = "grid.SubLine, written above `local function Columns` in a mid-edit copy of the file the game loaded at login",
      path = "a parallel session adding the Missing reminder's sub line saved the file half-done; the game read it before the next save moved SubLine under Columns",
      rule = "Lua binds a name at compile time: read above its `local` line it's a global (nil), even if the local exists by the time the code runs",
      pattern = "a function using a local helper declared further down the file; luacheck (W113) catches it unless the name is also a known global",
    },
    dont = "Never call a local above its `local` line: declare it first (or `local X` up top, assigned later). Checked at commit by luacheck plus Tools/errors/forwardlocal.py for names that are also globals; a line that means the real global gets -- dont-ok: lua-local-before-defined.",
    fix = "2026-11-23: CooldownGrid.lua already saved with SubLine under Columns; repo scanned, no other cases (4 deliberate global reads marked); forwardlocal.py in the pre-commit hook",
    seen = { "2026-11-23" },
    example = [[Interface/AddOns/CinematicDev/UI/CooldownGrid.lua:629: attempt to call a nil value
[C]: in function 'Columns'
[CinematicDev/UI/CooldownGrid.lua]:629: in function 'SubLine'
[CinematicDev/UI/CooldownGrid.lua]:2313: in function <CinematicDev/UI/CooldownGrid.lua:1973>
[CinematicDev/Options.lua]:16847: in function <CinematicDev/Options.lua:16799>]],
  },

  -- Rule editor ----------------------------------------------------------------
  {
    id = "rule-editor-optional-callback",
    status = "fixed",
    title = "Rule editor: attempt to call a nil value in SetText as you type (a target without SetText)",
    match = { all = { "attempt to call a nil value", "GridRows.lua" }, any = { "in function 'SetText'", "in function 'ResetToGrid'" } },
    why = {
      call = "target.SetText(box:GetText()) in the editor's Changed() (UI/GridRows.lua), from the box's OnTextChanged with userInput",
      caller = "ns.OpenRuleEditor's target table: Dev/AtmosphereTest.lua's stand-in Haze row had label, Text and Close but no SetText (patched by its session a minute later)",
      path = "the editor's comment listed SetText and ResetToGrid as fields every target has, and called them unchecked; any caller that leaves one out (rows that save only on Close, a test stand-in) errors on the first key typed, or on Reset to grid",
      rule = "Lua: calling a missing table field is calling nil; the game's trace names it as \"[C]: in function '<field>'\"",
      pattern = "a callback table handed to a shared window, its optional fields called without a check",
    },
    dont = "Don't call a rule editor target's SetText / ResetToGrid unchecked: `if target and target.SetText then`. Only label, Text and Close are needed.",
    check = { pattern = [[^(?!.*target\.(SetText|ResetToGrid) then).*\btarget\.(SetText|ResetToGrid)\(]] },
    fix = "2026-11-23: GridRows.lua calls SetText and ResetToGrid only when there; header comment says only label, Text and Close are needed. Tools/offline/ruleeditortarget.lua",
    seen = { "2026-11-23" },
    example = [[Interface/AddOns/CinematicDev/UI/GridRows.lua:404: attempt to call a nil value
[C]: in function 'SetText'
[CinematicDev/UI/GridRows.lua]:404: in function <CinematicDev/UI/GridRows.lua:403>
[CinematicDev/UI/GridRows.lua]:409: in function <CinematicDev/UI/GridRows.lua:407>]],
    source = "pasted 2026-11-23 (Atmosphere test, Haze row's editor)",
  },

  -- Reload ---------------------------------------------------------------------
  {
    id = "reload-restore-in-fight",
    status = "fixed",
    title = "A reload in a fight: the bags (and windows) reopened from our code got a blocked line (Forever, gamepad off too)",
    match = { all = { "SecureHelper.lua", "Reload.lua" }, any = { "OpenBackpack", "OpenAllBags", "ShowUIPanel", "FrameShown" } },
    why = {
      call = "SmartNavigationSecureHelper's \"invoke\" of GamepadFrameControlsManagerMixin.FrameShown (SecureHelper:WrapFunction); its validate IsSecureOrOutOfCombatRestriction (issecure() or not C_RestrictedActions.IsAddOnRestrictionActive(Combat)) fails, so DisplayInterfaceActionBlockedMessage",
      caller = "QoL/Reload.lua Restore -> Try(\"bags\", OpenAllBags), 0.5 s after PLAYER_ENTERING_WORLD (isReload)",
      path = "Keep windows open across a reload: the player reloaded in a fight (or the fight was still on 0.5 s after), so the restore ran under the combat restriction; OpenAllBags -> OpenBackpack -> ContainerFrame_OnShow fires EventRegistry ContainerFrame.OpenBag, which FrameControlsManager turns into FrameShown under our taint",
      rule = "Forever's Blizzard_GamepadSharedUtility FrameControlsManager hears every bag opened (ContainerFrame.OpenBag) and every UI panel (UIParentPanelManager.ShowUIPanel), gamepad mode on or off (Init, not behind IsGamepadUIEnabled); FrameShown goes through SecureHelper, refused from addon code under the combat restriction: one line, no event",
      pattern = "our code opening bags or ShowUIPanel windows with no fight check (a restore, a timer, an event)",
    },
    dont = "Don't open bags or UI panels from our code in a fight: wait for PLAYER_REGEN_ENABLED (and C_RestrictedActions combat restriction off), as Reload.lua's FightLocked / afterFight does.",
    check = { pattern = [[(?<![\w"'.:])(OpenAllBags|OpenBackpack|ToggleAllBags|ToggleBackpack|OpenBag|ToggleBag)\b(?!["'])]], allow = { "QoL/Reload.lua", "Dev/" } },
    fix = "2026-11-23: Reload.lua Restore checks FightLocked() (combat restriction or InCombatLockdown); in a fight the windows, bags and game settings page wait for PLAYER_REGEN_ENABLED (afterFight), Cinematic's settings page opens at once (ns.OpenOptions' own fight path). Tools/offline/reload.lua",
    engine = { "forever.bags-panels.smartnav-frameshown-combat" },
    seen = { "2026-11-23" },
    example = [[blocked (no event)  (Blizzard_GamepadSmartNavigation)
  Interface action failed line, (in combat)
[C]: in function 'DisplayInterfaceActionBlockedMessage'
[Blizzard_GamepadSmartNavigation/SecureHelper.lua]:124: in function <...Ons/Blizzard_GamepadSmartNavigation/SecureHelper.lua:47>
[C]: in function 'SetAttribute'
[Blizzard_GamepadSmartNavigation/SecureHelper.lua]:182: in function 'FrameShown'
[Blizzard_GamepadSharedUtility/FrameControlsManager.lua]:218: in function <...izzard_GamepadSharedUtility/FrameControlsManager.lua:217>
[Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua]:814: in function 'ContainerFrame_OnShow'
[Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua]:384: in function 'OpenBackpack'
[C]: in function 'pcall'
[CinematicDev/QoL/Reload.lua]:77: in function <CinematicDev/QoL/Reload.lua:76>
[CinematicDev/QoL/Reload.lua]:104: in function <CinematicDev/QoL/Reload.lua:84>]],
    source = "pasted 2026-11-23 (after a /reload in a fight, Forever)",
  },

  -- Action bars --------------------------------------------------------------
  {
    id = "bar-calls-blocked-tainted",
    status = "open",
    title = "Every action bar's own calls blocked as CinematicDev's in a fight: the spellbook's grid (18:48), then slot changes (Forever)",
    match = { all = { "Blizzard_ActionBar/Shared/ActionBar.lua" }, any = { "UpdateShownButtons", "SetShowGrid", "UpdateVisibility", "UpdateFrameStrata" } },
    why = {
      call = "the bars' protected calls from Blizzard's own code: SetFrameStrata, buttons' and containers' SetShown, HideBase/ShowBase, and Edit Mode's SetPoint/SetScale of MultiBarLeft/Right, all blocked as an addon's in a fight",
      caller = "unknown: no Cinematic frame in any stack. 18:48 = the spellbook micro button's own click (MainMenuBarMicroButtons.lua:957) > TogglePlayerSpellsFrame > ShowUIPanel's center branch (UIParentPanelManager.lua:294) > SetUIPanel > Show > PlayerSpellsFrame OnShow > MultiActionBar_ShowAllGrids, already tainted at the first bar's SetFrameStrata. 18:50/18:53 = ACTIONBAR_SLOT_CHANGED > UpdateAction > MultiBarBottomLeft:UpdateShownButtons, an event handler that starts clean: a field it reads on that bar was ours then",
      path = "unknown: something earlier in that session (18:25 login, a fight from 18:47:47, Ghost Wolf, the auto-run camera) left a value the window manager, the micro button or the bar reads written by our code; a /reload cleared it",
      rule = "a read of a tainted value taints the rest of the run, and a field written in a tainted run stays tainted (each later read taints again) till a /reload",
      pattern = "unknown. Ruled out by /cine debug bartaint, each with 0 fields of ours and 0 bar calls blocked (control proves the scan sees ours): a fresh session; the spellbook opened by its key or out of a fight; from the Menu Wheel in a fight (its first load too); the wheel's Game Menu slot (CloseAllWindows/HideUIPanel/ShowUIPanel from our code), window manager slots checked by name",
    },
    dont = "Not known yet. The dev copy logs the next one as it happens: Dev/BarTaintCatch.lua scans the first blocked bar call of a session and writes every tainted field with its writer under the bartaint category of /cine log. Read those lines first.",
    fix = "open 2026-11-24: diagnosis only. Dev/BarTaintCatch.lua (auto scan, Tools/offline/bartaintcatch.lua), Dev/BarTaintTest.lua (/cine debug bartaint).",
    seen = { "2026-11-24" },
    example = [[blocked  (Blizzard_ActionBar)
  CinematicDev: MultiBarBottomLeft:SetFrameStrata() (in combat)
[C]: in function 'SetFrameStrata'
[Blizzard_ActionBar/Shared/ActionBar.lua]:199: in function 'UpdateFrameStrata'
[Blizzard_ActionBar/Shared/ActionBar.lua]:169: in function 'SetShowGrid'
[Blizzard_ActionBar/Shared/MultiActionBars.lua]:108: in function 'MultiActionBar_ShowAllGrids'
[Blizzard_PlayerSpells/Blizzard_PlayerSpellsFrame.lua]:53: in function <...Blizzard_PlayerSpells/Blizzard_PlayerSpellsFrame.lua:42>]],
    source = "pasted 2026-11-24 18:48-18:53 (Forever, a fight, spellbook not opened by hand)",
  },
}
