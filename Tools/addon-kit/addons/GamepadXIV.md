# GamepadXIV

Version read: v0.1.28 (_forever_ only, interface 16001), 2026-11-25.
Proven in game (Forever): addon kit run qe788, /cine debug gamepadxiv qdece
(34/34): Forever's bar and the game's chat held at 0 through our rows and
CineMode, its hotbars and chat box fade with ours, its prompt on its own row.

## What it is
FFXIV-style controller play on Forever's gamepad UI: cross hotbars in place of
Forever's gamepad action bar, its own chat box in place of the game's chat.
- Cross hotbars: `GamepadXIVFrame` (Bar.lua:481), rows L R WL WR (Core.lua:9),
  each `GamepadXIVSide<row>` > `GamepadXIVContent<row>` (secure) >
  `GamepadXIVBtn<row><1-8>` (Bar.lua:77, 80, 162).
- Parts inside `GamepadXIVFrame` (unnamed fields): set labels `.setText` /
  `.sides[row].label` (Bar.lua:468, 474), set picker `.setPicker` (DIALOG,
  while R1 held, Bar.lua:242-263), soft target text `.softText` / `.softHint`
  (Bar.lua:494-498), the interact prompt (Input.lua:1599).
- Selection highlights over party/raid frames: `GamepadXIVFrame.softBorder`,
  `.targetHighlight`, unnamed frames on UIParent, HIGH (Bar.lua:500-501, 672).
- Chat box: `GamepadXIVChatBox` (ChatBox.lua:2265) over ChatFrame1, lines in
  `GamepadXIVChatFeed` / `GamepadXIVChatConversation` (ChatBox.lua:2370-2371),
  `GamepadXIVChatBoxWhispers`, `GamepadXIVChatBoxInput`, `GamepadXIVChatBoxMenu`.
- Crosshair: unnamed frame on UIParent, LOW, no named owner (Crosshair.lua:167);
  shows only with a style other than "forever"/"none" while GamepadReticle shows.
- Party prompt: unnamed, inside CompactPartyFrame's prompt container,
  SetIgnoreParentAlpha (Input.lua:2947-2948).
- Minimap button `GamepadXIVMinimapButton`, a child of Minimap (Minimap.lua:202).
- Panels that pop up in play: `GamepadXIVRing` (ring menu), `GamepadXIVRollPicker`,
  `GamepadXIVFlyoutPanel`, `GamepadXIVClearPanel`, `GamepadXIVPopupHint`.
- Windows opened on purpose: `GamepadXIVConfigFrame`, `GamepadXIVLfgFilterFrame`
  (also its "Chat window"), `GamepadXIVMessagesFrame`, `GamepadXIVNewsFrame`,
  `GamepadXIVTutorial`, `GamepadXIVAssignPanel`, `GamepadXIVEditor`, `GamepadXIVMenu`.

## How a player starts it
- Needs Forever's gamepad UI on (`InputUtil.IsGamepadUIEnabled()`, Core.lua:770);
  without `GamepadActionBarBindingUtil` it prints "...stays off" and makes no
  frames (Core.lua:1070). Active = `enabled and gamepad UI and Forever's bar
  editor closed` (Input.lua:3028); `/gxiv status` says so.
- No installer. The tutorial starts by itself 4 s after entering the world if
  `GamepadXIVAccountDB.tutorialSeen` isn't set, and sets it at once
  (Tutorial.lua:17, 1816, 1857-1866). It doesn't hold the bars back.
- Slash `/gxiv` or `/fc` (Core.lua:964-1052): on, off, config, edit/move, clear,
  tutorial, reset, minimap, status, debug, changelog, lfg, messages, ...
- Addon compartment: `GamepadXIV_OnCompartmentClick` (Minimap.lua:191).
- Its `ns` isn't global: only frame names, `GamepadXIVDB` (per character),
  `GamepadXIVAccountDB`, `SlashCmdList.GAMEPADXIV`, the compartment function.

## What each part needs before it shows
- Cross hotbars: gamepad UI on and active; never hidden, only alpha 0/1
  (`ns.SetBarShown`, Bar.lua:915-918).
- Chat box: `GamepadXIVDB.chatUI == "gxiv"` (default "gxiv", Core.lua:121),
  applied at PLAYER_LOGIN and on its Chat setting (`ns.ApplyChatChoice`,
  LfgFilter.lua:5156-5223, 5551; Config.lua:319). Doesn't need the gamepad UI.
- Crosshair: `crosshairStyle` not "forever"/"none" (default "forever", Core.lua:58).
- Set picker: R1 held. Ring: its ring button. Highlights: a party or raid.

## Set up for a test
- by code: `GamepadXIVDB.enabled = true`, `GamepadXIVDB.chatUI = "gxiv"`
  (both read at login: a reload after). `SlashCmdList.GAMEPADXIV("on")` turns
  it on now.
- by hand: turn on Forever's gamepad UI (a controller plugged in, Escape >
  Options > Gamepad > Enable Gamepad UI), once. Not by code: setting
  InputDeviceInterfaceStyle from an addon is blocked (proven q6ff9; rule
  forever.gamepad.interface-style-protected).
- out of reach: its `ns` (ns.SetBarShown, ns.ApplyChatChoice, ns.OpenGamepadChat).
- Sapo-Lock already has enabled = true and chatUI = "gxiv" (2026-11-25).

## Surprises
- Gives Forever's bar back (GamepadMainActionBarFrame alpha 1, its own bars
  alpha 0) in vehicles, override and possess bars, or with itself off
  (`fc-vehicle` state driver, Input.lua:2411; Snippets.lua:441;
  `ns.ApplyForeverBarVisibility`, Input.lua:2641-2654). Otherwise holds that
  bar at alpha 0, set once per change (not hooked).
- Chat "gxiv": the game's ChatFrame1..N, their Tab and EditBox,
  GeneralDockManager, ChatFrameMenuButton, ChatFrameChannelButton and the two
  voice buttons go to alpha 0, each with a SetAlpha hook pushing any alpha
  above 0 back to 0 (LfgFilter.lua:5020-5046). While the player types in the
  game's chat box (the "/" key) they come back at 1 and its box hides (0.2 s
  check, LfgFilter.lua:5172-5196). ButtonFrame, QuickJoinToastButton and the
  combat log buttons aren't touched.
- Its chat box never sets its own alpha: `chatBoxAlpha` is the backdrop only,
  `chatFade` fades lines (ChatBox.lua:1879-1891, 1934-1937). It raises its
  strata over the game's chat every second (ChatBox.lua:2176-2211).
- Content rows' alpha and scale are set by secure code (selected 1, others
  `dimAlpha`), Snippets.lua:161-186.
- Temp CVars while active: `GamepadShowPersistentInputLegend=0`,
  `SoftTargetIconInteract=0` (Input.lua:9-10); real ones restored at logout:
  `GamePadEmulate*`, `GamePadStickAxisButtons`, camera yaw/pitch speeds while
  L1 or the ring is held (Input.lua:15-20, 1220-1263). Camera zoom with L1 +
  right stick and R3 (Input.lua:661-668, 1265-1288). Sets `alwaysCompareItems`.
