# Glass

Version read: 2.2.0 (_forever_; CurseForge lists it for retail and the Classic flavors too), 2026-11-25. The demo mode, social button, extra windows and the `Glass` global below: code read, not yet proven by a run of the recipe.

## What it is
A chat addon: a cleaner chat with lines that slide in and fade by themselves.
- Its chat: GlassFrame, holding one frame per chat window that draws that
  window's lines (SlidingMessageFrame). The game's windows sit in it, hidden
  (Components/SlidingMessageFrame.lua:103, :266).
- Its tab bar: the game's GeneralDockManager and tabs (ChatFrame1Tab...),
  restyled, shown and hidden with alpha animations (Components/ChatDock.lua).
- Its input: the game's edit boxes, moved into GlassFrame.
- Its dock buttons: the game's ChatFrameMenuButton on the tab bar (shown by
  default), ChatFrameChannelButton hidden by default (init.lua:67-68,
  Components/ChatDock.lua:31-32).
- Its social button: the game's own, kept on screen while `showSocialButton`
  is on (on by default, init.lua:69, Components/SocialButton.lua:11-23, :101).
- Extra windows: chat windows of its own, unnamed frames on UIParent
  (Components/ExtraWindow.lua:289), only once a player adds one in its options
  (`profile.extraWindows`, empty by default, init.lua:51; Modules/ExtraWindows.lua:89).
  Support/Glass.lua only looks inside GlassFrame, so these aren't covered.

## How a player starts it
Nothing to do: it takes over the chat at login. `/glass` (Modules/Config.lua:457)
opens its options (`/glass lock` / `unlock` to move it). It's also under the
game's AddOns settings ("Glass"). Its saved table is GlassDB (AceDB profiles).
It sets the game's Chat Style to Classic if it isn't (Modules/UIManager.lua:104).

## What each part needs before it shows
- Its line frames: made at login for each chat window. A whisper window gets one
  when it first opens (FCF_OpenTemporaryWindow raw hook, UIManager.lua:114).
- Lines show as they arrive and fade after a while, unless the mouse is
  over them or you've scrolled up (Components/SlidingMessageFrame.lua:160-200).

## Set up for a test
- by code: nothing needed; General's frame is ns.chatPeekPanels[ChatFrame1]
  once our scanner has claimed it (Support/Glass.lua), a moment after login.
- by code: its frame's scroll position reads from `<frame>.state.scrollAtBottom`
  (SlidingMessageFrame.lua:387, :417).
- by code: lines on screen without anyone talking -> its demo mode,
  `Glass:GetModule("Demo"):SetActive(true)` (what `/glass demo` does,
  Modules/Config.lua:472; Modules/Demo.lua:72): 60 sample lines, then one every
  2.5 s, in place of the real chat till `SetActive(false)` or a reload. Saves
  nothing. The recipe doesn't use it (real chat is enough to be ready).
- by code: its addon object is the global `Glass` (init.lua:12, `_G[AddonName] = Core`),
  so its modules are reachable with `Glass:GetModule(name)`; `Glass.db.profile`
  is its live profile.
- by hand: nothing.

## Surprises
- Its hooks on game code we hook too (SetItemRef with hooksecurefunc,
  ChatFrame1.AddMessage with an AceHook prehook, FCF_OpenTemporaryWindow with
  a raw hook) put its own function in place after ours, but each calls ours
  through (Hyperlinks.lua:37, MessageRouter.lua:151, UIManager.lua:114).
- Its frame for a chat tab you aren't on can say shown: only the selected
  tab's counts (UI/Chat.lua ns.ChatWindowShown).
- Demo mode stands in for the real chat while on: a test that reads real lines
  must turn it off first (Modules/Demo.lua:79).
