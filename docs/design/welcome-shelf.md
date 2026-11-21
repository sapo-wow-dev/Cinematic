# Welcome window: See all shelf and tour

Plan agreed in a design session, 2026-11-20. The clickable mock is
`welcome-shelf.html` next to this file: open it in a browser. Nothing in the
addon is built yet.

## Goal

New players expect Cinematic to do a few things. The welcome window should let
them see every feature with one click, without making the first look longer.

## Decisions

- **The See it first row stays short.** Fading UI is added as its first button
  (new demo), then Letterbox, Tint, Camera, Vitals, Shoulder Cam, Teleport as
  today. The last slot is a dashed gold **See all N ▾** button, with "M more"
  under it.
- **The shelf opens in place**, inside the row, under its buttons and above
  Start in CineMode. Groups down the left follow the settings hubs (Atmosphere,
  Cameras, Visions, Interface, Style), each in its hub's band color; a group
  with nothing to play is left out. The grid has a fixed height and scrolls.
  A search box filters every group at once.
- **Only things that play get a tile.** Features with nothing to show (wheels,
  Keyboard Map, Fishing, Hunter, talent links, XP left, Tooltips, Cursor Hide,
  Themes, the Style pages, Graphics Boost, Camera Scripts) are one line of
  links under the grid, "Also in Cinematic:", each opening its settings page
  over the welcome window with a Back to it.
- **Tiles are the row's button**: icon, name, the In CineMode / 4 scenes / Off
  tag for the level hovered (else picked), Stop while running, hover fills the
  description box.
- **Turn on.** A tile whose feature is off in the profile being tried gets a
  small Turn on button. It writes that feature's switch into the profile; the
  tag then reads "On: you turned it on". Not shown while hovering a level card,
  while it runs, or for Blank Slate.
- **In a fight**, one line at the top of the shelf ("You're in a fight. The
  demos come back when it ends.") and every tile greys out together, rather
  than a tooltip per tile.
- **Saved**: shelf open or closed, and the last group.
- **While a demo plays**, the notice shows its name, "n of N" during a tour,
  and one short sentence of what it does.

## The tour

**▶ Watch the tour · 1½ min** in the row's header, so it's there before the
shelf opens. Inside the shelf the same button plays the open group.

Order: Fading UI, Letterbox, Tint, AFK Cam, Shoulder Cam, Vitals, Emote
Vision, Card Vision, Teleport.

- Shoulder Cam only once the player has said yes to its experimental camera
  setting (picked its level, or its own demo). A tour must not agree to it for
  them: skip it otherwise.
- Emote Vision's test keeps its card up until it goes (up to 60 s): cap it at
  about 15 s in the tour.
- Quest Vision and Damage Vision are left out on purpose: few players use them.
  They stay on the shelf.
- Open questions: skip a step when the player moves (AFK Cam stops on input),
  and keep the welcome window faded through the whole tour. Both leaned yes.

One-line descriptions for the tour's notice:

| Feature | Line |
|---|---|
| Fading UI | Your UI fades away between fights and comes back when you need it. |
| Letterbox | Black bars at the top and bottom, as in a film. |
| Tint | A color wash that follows the time of day, the zone and the weather. |
| AFK Cam | Go AFK and the camera sweeps slowly around you. |
| Shoulder Cam | The camera sits over your shoulder, with you to one side. |
| Vitals | The screen's edges close in as your health drops. |
| Emote Vision | Other players' emotes show as film dialogue over their heads. |
| Card Vision | Title cards for the moments of your day: a new zone, a level, a fight. |
| Teleport | A portal opens as you hearth or teleport, and the world fades out. |

## Where the demos come from

- **Test exists, needs a `DEMOS` entry** in `Profiles/ShowMe.lua`: the camera
  Tests in `Camera/CameraTests.lua` (AFK, Quest, Flight, Cozy, Vista, Fish,
  Death, RP Walk, Auto-run), `ns.TestShot`, Damage/Emote/Roll (already in
  `DEMOS`, not in the row), `ns.TestDamageRecap`, `ns.TestDeathVision`, the
  Duel Vision page's Test, the Quest Vision preview, `ns.CardTest`,
  `ns.TestCooldownFlash`, `ns.TestSpeechBehind`, `ns.TestVitalsSound`,
  `ns.TestTimeChangeTitle`, Weather (the Tint demo). `Dev/DemoHub.lua` already
  calls most of these and shows how.
- **New demos needed**: Fading UI, Mouseover, Heal Vision, Nameplates, Chat
  Bubbles, Combat Text, Skyriding Cam. Until each is done it sits in the link
  line.

## Build order

1. **Fading UI demo**, and its place first in the row.
2. **The shelf** in `Profiles/Welcome.lua` (`BuildDemoRow`), with the tiles
   that already have a Test, Turn on, the fight line and the saved state.
   Check the window's height in game at the smallest UI scale here; if the
   shelf doesn't fit, it becomes its own page of the window, as Customize is.
3. **The tour** and the "Also in Cinematic" page links (one helper that opens a
   page by name from the welcome window and returns to it).
4. **The other new demos**, one commit each.

Tips stay one sentence each: they're translated into eight languages.
