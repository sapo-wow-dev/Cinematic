# Gating audit: findings (2026-11-25)

Read-only audit, nothing changed yet. Question: with a part unloaded, a part
switched off, or a page or tab switched off, does anything still show, still
cost something, or throw an error?

Base: HEAD 98f1035 plus the uncommitted tree. Eight read-only audits were run,
one per area: Visions, Cameras, Style, Atmosphere, Frames/HUD, Plates+UI,
QoL+Support+Profiles, and the gate machinery itself. The top ones were checked
again by hand (marked ✔).

Marks: **bug** = a plain bug by the rules ("page off = all off", "tab is a
container", unload = nothing runs). **call** = the right answer is yours.

## A. Errors with a part unloaded

| # | Where | What happens | Mark |
|---|---|---|---|
| A1 ✔ | Options.lua:9163, 11251 (painted by UI/GridRows.lua:1254) | With Style unloaded, the HUD Unit Frames parts rows and the Nameplates parts rows call `ns.StyleOverrideText`, which doesn't exist. Lua error when those pages are built or refreshed | bug |
| A2 | Atmosphere/Tint.lua:1134 | With Visions unloaded, `/cine tinttest` calls `ns.TestTimeChangeTitle` at each phase (inside a Step, so outside the slash command's catch-all) | bug, dev only |

Slash commands were checked: Slash.lua:2559 catches a missing part function and prints "isn't loaded".

## B. Game settings left changed, or data lost

| # | Where | What happens | Mark |
|---|---|---|---|
| B1 ✔ | Graphics.lua:177, 286; Modules.lua:331 | You untick Load Atmosphere and pick Later. Graphics+ is put back right away, but the part is still running, and it writes the boosted settings again after the next fight. After the reload no Atmosphere code runs, so they stay boosted for good | bug |
| B2 | Modules.lua:316 (only atmosphere has an ON_LEAVE) | You unload Cameras with Shoulder Cam on. The shoulder offset, Keep Character Centered, Reduce Unexpected Movement and the soft-target settings stay as Shoulder Cam set them (the game saves them). The next-login clean-ups also live inside Cameras, so they don't run either: ShoulderCalibrate.lua:342, ShoulderCam.lua:3878, SkyrideCam.lua:1037, CameraScripts.lua:3515, and the fishing volume (Camera.lua:561) | bug |
| B3 ✔ | UI/ChatCopy.lua:536 | Turning the QoL page off for one login wipes your saved chat history, although Keep chat history is still ticked | call (likely: wipe only when the tick itself is off) |

## C. Still showing with its switch off

**Tabs that do nothing**

| # | Where | What happens | Mark |
|---|---|---|---|
| C1 ✔ | Options.lua:11794; read in Effects.lua KeptHere/ShownInFights (~1083), Plates/PlateParts.lua | Nothing reads `tabOn:Nameplates:*`. The Parts, Enemy, Friendly, Instances, Target and every Names tab can be right-clicked off and the plates still hide and show by their rows. Chat had the same bug and was fixed with PEEK_TAB (UI/Chat.lua:105) | bug |
| C2 | Style/StylePages.lua:161-192 (`ns.StyleLook`) | The Style look proxy never checks a tab's switch. Bubble Style's Bubbles and Behind Bubbles tabs off: bubble and speech looks still apply. Affects every Style page read through StyleLook with tabs (CDM, Overrides and Combat Text Texts check by hand) | bug |
| C3 | Style/SelfTextStyle.lua:140-162 | Self Text Style's General, Look and Kinds tabs gate nothing: the game's text is still copied and held hidden, its setting held, events kept | bug |
| C4 | Style/CombatTextStyle.lua:99, 1460-1480; Core.lua:5492 | Combat Text Style's General tab off: our numbers still draw, the game's damage and heal numbers are kept off, the blank world font still loads at login | bug |
| C5 | Camera/Triggers.lua:52-110 | Built-in camera triggers ignore their own Starts / Ends / Timing / Scenes tabs (only your own triggers read them, CustomTriggers.lua:299) | bug |
| C6 | Frames.lua:13146 | Chat's Typing row is on the Conversations tab, but pressing Enter still brings the chat up with that tab off | bug |
| C7 | Frames.lua:8806, 773 | Gamepad: press reveal still works with the Settings tab off; the bars, legend and reticle still fade by their rows with the Show tab off | bug |
| C8 | Frames.lua:10907, 9768, 10317; UI/CooldownRing.lua:519; UI/CooldownStacks.lua:156 | Cooldown Manager: a bar's tab off still centers its icons ("Close the gaps"), keeps its keybind text and countdown numbers, and the Buffs tab off still draws rings and stack counts. With the whole page off, centering comes back on the next layout | bug |

**Pages and parts that keep going**

| # | Where | What happens | Mark |
|---|---|---|---|
| C9 ✔ | Atmosphere/Tint.lua:407; Visions/EmoteVision.lua:551; Core.lua PAGE_SWITCH | With Style unloaded or Enable Style off, your Tint Style (zone tints, presets, day phases) and Emote Vision Style still apply. Root cause: 10 Style page keys have no master in the switch tree (tintStyle, weatherStyle, letterboxStyle, questItemStyle, rollStyle, lowHealthStyle, emoteStyle, damageVisionLook, targetArrowStyle, questTalkStyle), so `ns.PageOn` and `ns.Setting` read them as on | bug |
| C10 | Plates/PlateThemes.lua:87 | Nameplate Style off live: plates keep the theme's ground and bar shape | bug |
| C11 | Plates/PlateGuild.lua ~199-689 | Name Style off, Enable Style off or Style unloaded: guild and title lines still take Name Style's size, color and shadow, and titles still turn into icons | bug |
| C12 ✔ | UI/Bubbles.lua:1004-1022 | Chat bubbles read `handleBubbles` raw: with the Chat Show tab or the whole HUD off, the bubble settings keep being written once a second and are never put back | bug |
| C13 ✔ | UI/TooltipParts.lua:43, 968, 1029 | Mouseover Show off: tooltips still fade in and out, and the After countdown still runs | bug |
| C14 | Camera/Camera.lua:2177; Camera/CameraScripts.lua:3092-3141; Core.lua:4829 | Enable Cameras off: a scene whose camera is your own script still plays it, and the camera keys and the wheel still play scripts (with the Scripts page off they play your edited copy, not the shipped one) | bug |
| C15 | Graphics.lua:316 | Weather page off: the bad-weather view distance still comes in, in rain in CineMode | bug |
| C16 | Atmosphere/WeatherFX.lua:226; Core.lua:4622 | After a safety stop or `/cine stop` mid-weather, frost, lens rain and lightning keep drawing and thundering, and weather density is held again | bug |
| C17 | Profiles/Profiles.lua:493; Options.lua:10141, 10272 | Switching to a profile with things off doesn't put back Graphics+, the XP "left" text, the inspect Talents buttons, or the dressing room by the AH. The QoL page switch doesn't clear the XP text or the drag strips; the Hunter page switch leaves the vendor fill buttons | bug |
| C18 | Dev/MouseTurn.lua:36-82 | Dev copy only: Mouse Turn sits outside the Cameras part and ignores its tab, so it still writes the turn speed with Cameras unloaded | bug, dev only |
| C19 ✔ | Visions/CombatVision.lua:1382 | The Boss event's Sounds tab off: the boss kill and wipe sounds still play (card sounds do check it, Cards.lua:640) | bug |
| C20 | Visions/Recap.lua:187; Core.lua:5728 | The login "Last time" line and the time-of-day title ignore their events' Settings tab, and the page-turn sound ignores the Sounds tab | bug (your call if the line counts as the card) |
| C21 | UI/WhyFeatures.lua:421 | With Visions unloaded, the Why window's Cards tab errors inside its pcall and shows empty | bug, low |

## D. Still costing something with its switch off

Biggest first. Nothing shows, but the work runs.

| # | Where | What runs | Mark |
|---|---|---|---|
| D1 ✔ | QoL/Campfire.lua:637-643 | The Campfire loop runs every frame for everyone, always (its gate reads `sceneOffCampfire`, which is nil by default), with checks 10 times a second; plus a hook on every world tooltip. Also with Cameras or Visions unloaded | bug |
| D2 | Style/RaidStyle.lua:298 | Raid frame hooks run the full restyle per member per update with Raid Style, Recolor or Enable Style off | bug |
| D3 | Camera/CameraScripts.lua:3322 → TriggerNow | With Enable Cameras off, scene picking still runs every frame | bug |
| D4 ✔ | QoL/Hunter.lua:121 | Every Classic Era hunter: a per-frame watcher, with the Hunter page off (it's off by default) | bug |
| D5 ✔ | Frames.lua:698 (`ns.AnyFramePageOn`) | HUD off still counts as "a page is on", so the frame scan keeps running | bug |
| D6 | Frames.lua:6049, 5749 | Buffs page or HUD off: every aura change on you still walks every buff icon | bug |
| D7 | Camera/CustomTriggers.lua:427-1025 | Your triggers keep ticking (0.1 s scans, events) with the Triggers, Scenes page or Enable Cameras off | bug |
| D8 ✔ | QoL/CenterPanels.lua:825 | Once a drag strip was ever made, every window open and close still rearranges panels with the page off. The strips also stay up | bug |
| D9 | Camera/ChatCam.lua:1642 | Every NPC say or yell: a bubble-scan ticker and a debug log line, with Chat Cam off | bug |
| D10 | Style/UnitStyle.lua:2606-2878; Style/ActionBarStyle.lua:917, 324 | Unit Style and Action Bar Style hooks and watchers install and run with their pages off | bug |
| D11 | Camera/Camera.lua:1229 | Fishing loop runs per frame with a pole equipped, Fishing page off | bug |
| D12 | Camera/QuestCam.lua:1218 | Quest Cam's loop runs through every NPC talk with it off | call (part of it feeds Quest Talk) |
| D13 | UI/CooldownStacks.lua:250; UI/CooldownRing.lua:700 | Stacks and rings keep their loop and events with the Cooldown Manager page off | call (stacks keeps counting on purpose) |
| D14 | Atmosphere/Focus.lua:91 | Haze loop runs every frame in CineMode where its Show in row says off | bug |
| D16 ✔ | Visions/QuestTalk.lua:2659 | Quest Vision off (or held to CineMode): Quest Talk's follower still runs every frame, kept alive by the raw `questTalk` tick | bug |
| D17 ✔ | Visions/EmoteVision.lua:2714, 2206, 2166, 2190 | Emote Vision off: every aura change on you is still read (can loop all plates and log), and each fight's end scans 40-80 auras | bug |
| D18 | Atmosphere/LowHealth.lua:2103 | Vitals or its Health tab off: every hit on you still runs a full Vitals update frame | bug |
| D19 | Visions/QuestMobs.lua:630 | Quest Vision off: every spell cast still reads tooltips and the quest log | bug |
| D20 | Visions/SleepingBag.lua:554 | Forever: every aura change reads the bag auras with Cards and the camp timer off | bug |
| D21 | Visions/CardMoments.lua:392 | Every login walks the whole achievement list with Cards, Discover and Explore off | bug |
| D22 | Visions/QuestItemButton.lua:627; QuestMobs.lua:1014; DamageVision.lua:1317; RollWindow.lua:1644 | Loops kept alive by raw ticks with Quest Vision off; Damage Vision and Roll Vision wake and log with their pages off | bug, low |
| D15 | small ones | ZoomGuard per-frame watch, Skyriding watcher, Reload's 0.5 s ticker, Conflicts' ticker, Graphics' 1 s ticker, Music's CVar hooks, Campfire aura scan per UNIT_AURA, Tooltip/Minimap style hooks after switching off, Self Text and Combat Text 2 s tickers, plate parts loop with the page off, FadeDetached's debugstack on every SetIgnoreParentAlpha, minimap tracking reads, gamepad watch | low, mostly calls |

## E. Your calls (the code says it's on purpose, or the rule isn't plain)

1. The letterbox key and Chat Cam's Ultra immersive bring the bars up with the Letterbox page or Visual Effects off (Atmosphere/Letterbox.lua:185-213).
2. The death song plays with the Audio page off when game music is on (Music.lua:486; the comment says on purpose).
3. Hover Groups page off: hovering stops, but the groups' event triggers (chat, roster, buff peek…) still bring members up (Frames.lua:13303).
4. A Keybinds tab off doesn't stop the secure wheel keys and the shoulder-swap key (they could, via `ApplyWheelSwitches`' `cineoff`).
5. With both hide-errors boxes off, each pass still sets the error frame's alpha to 1, which overrides another addon hiding it (Effects.lua:602).
6. Show Cine Mana Bar is a Personal Resources setting whose code is in Style: with Style unloaded the box shows and does nothing; with Style off the bar still shows.
7. The `nameplateStyle` setting is held by General, whatever the Nameplate Style page says (PlateHealthStyle.lua:29).
8. Enable Visions is a cascade (it writes each page's switch), not a master: a profile or one page ticked back on brings a Vision on while Enable Visions is off.
9. With Cameras unloaded, the Fishing page and QoL's "Reset the zoom on login" row still show but do nothing (the "hide unclickable" rule).
10. Shoulder Cam's Allow in flight / death and Name Style's service rows are read raw under their tabs: what "tab off" means for an "allow" box.
11. Death Vision has no Allow outside CineMode tick, unlike every other Vision.

## F. The gate machinery

1. The gate functions disagree. `ns.PageOn` reads a missing key as on; `ns.Setting` as off. `ns.MasterOff` doesn't check the key's own left-out mark. `ns.Setting` has no step cap (a loop in the tree would hang it). Only `ns.StyleOn` knows Enable Style. C9 is where it shows.
2. The tree changes shape with which parts are loaded: masters set inside a part's code (breath bar, camera triggers/scripts/shots under Enable Cameras, the Vitals, Emote and Cards tabs, CDM ring style) vanish when it's out.
3. Tab mappings exist from the first frame after load (eager pages) or from LazyPageDefaults (lazy ones). Gaps: reads during PLAYER_LOGIN handlers, and rows adopted only when a page opens.
4. What the tests prove: with a part out, its files make no frame, hook, event, timer or loop, and no error (modules.lua, loadparts). What they don't: work core code does for a left-out part or an off page, settings across the Later path and reloads, tab-off with raw reads, the tree's shape per part. The sweep turns each control on and back, but never a page or tab off while watching for effects.

**Proposed leak proof (offline)**, so this stays fixed:
1. For every page and tab switch: set it off, and check every gate function agrees for every key under it; with each part out, check its pages' keys are all left out.
2. Count the stub calls (SetCVar, event handlers, OnUpdate bodies, hooks) per pretend frame at defaults, then with each switch off: more than the defaults fails (with an allow-list).
3. A raw-read lint: `db.<key>` in game code for a key that has a master fails unless allow-listed.
4. Settings snapshots across "untick Load, Later, fight, reload" for each part.
5. The switch tree must be the same whichever parts load.
