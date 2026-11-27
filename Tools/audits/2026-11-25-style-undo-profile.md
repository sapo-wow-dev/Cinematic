# Style editor: a profile switch starts a new Undo history (fix card)
Fix: the style editor's Undo/Redo outlived a profile switch (no reload): Undo then wrote the profile left's value into the new one
Found by: audit 2026-11-25 (style editors from b53755f)
Code: Style/Studio/Editor.lua: Studio.ClearHistory (new); Profiles/Profiles.lua: SettingsChanged; Style/StyleDemos.lua: PutBack
Clients: both
Base: cc7e40d

## Before / after
- Before: change a setting on Nameplate Style, switch profile (or Reset profile, or load one), press Undo: the
  setting got the old profile's value, saved into the new profile. The same after a style demo (Welcome shelf)
  stopped: a step made while it ran wrote the demo's value over yours.
- After: other settings loaded (ns.SettingsChanged: profile switched, loaded, reset, a module/part applied, Show
  me, Follow HUD set up or taken off) or yours put back over a demo: Undo and Redo are empty, the setting stays as
  loaded.

## Who relies on the old behavior
(`python -I Tools/audit.py refs ClearHistory Studio.Undo SettingsChanged StyleDemo`, every hit read.)
- Players: anyone undoing across one of those: they lose steps that would have written the wrong profile's
  values. Undo after a Follow HUD setup or a Show me switch is also cleared (bulk changes made outside the editor;
  old steps over them were as wrong).
- Other features: every SettingsChanged caller (Profiles.lua SetProfile, Load paths, ResetProfile, ApplyPart,
  modules; FollowHud.lua; ShowMe.lua; Dev Sweep/Prerelease/GatingTest). StyleDemos.lua PutBack (stop, or after a
  fight). Studio.lua's OnChange listener redraws visible hosts on Notify(nil) (the footer's Undo/Redo words).
- Other addons: none.
- Tests that encode it: Tools/offline/gameplate.lua and Dev/StyleStudioTest.lua undo right after a change, no
  SettingsChanged between: unaffected.

## States (the matrix)
What happened after a change (nothing, a profile switch, Reset profile, a style demo stopped with the change made
while it ran), Undo or Redo pressed after it, the client.
Test: Tools/offline/styleundoprofilematrix.lua forever
Test: Tools/offline/styleundoprofilematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| style-undo-profile | after=switch | history=kept value=changed | history=cleared value=kept |
| style-undo-profile | after=reset | history=kept value=changed | history=cleared value=kept |
| style-undo-profile | after=demo | history=kept value=changed | history=cleared value=kept |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: Undo history is session memory only; nothing saved changes. A change made before a demo started is also
forgotten when it stops (it was valid: the demo put it back too). Not proven in game: the footer's Undo/Redo words
gone right after a switch on an open page.
