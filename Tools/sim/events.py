"""Writes Dev/SimEvents.lua: every name in Cinematic's code that looks like a
game event, for the simulation probe's way B (Dev/SimProbeTest.lua: when
RegisterAllEvents can't be used, each of these is registered on its own under
pcall; a name the game doesn't know is skipped and counted).

    python -I Tools/sim/events.py          write it
    python -I Tools/sim/events.py --check  exit 1 when the file is out of date
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "Dev", "SimEvents.lua")
SKIP_DIRS = {"Tools", "Dev", "Locales", ".git", "Textures", "Media", "Fonts", "docs"}
# Event names start with one of these (the game's own families).
PREFIXES = (
    "ACTIONBAR_", "ACTIVE_", "ADDON_", "AREA_", "AUCTION_", "AUTOFOLLOW_", "BAG_", "BANKFRAME_", "BARBER_",
    "CHAT_MSG_", "CINEMATIC_", "CLIENT_", "COMBAT_", "COMPANION_", "CONSOLE_", "CURRENT_SPELL_", "CURSOR_",
    "CVAR_", "DISPLAY_", "DUEL_", "ENCOUNTER_", "EQUIPMENT_", "GLOBAL_MOUSE_", "GOSSIP_", "GROUP_", "GUILD_",
    "INSTANCE_", "ITEM_", "LEARNED_", "LOADING_SCREEN_", "LOOT_", "LOSS_OF_CONTROL_", "MAIL_", "MERCHANT_",
    "MINIMAP_", "MIRROR_TIMER_", "MODIFIER_", "MOUNT_", "NAME_PLATE_", "NEW_", "PARTY_", "PET_", "PLAYER_",
    "PLAY_MOVIE", "QUEST_", "RAID_", "READY_CHECK", "SCREENSHOT_", "SKILL_", "SOUNDKIT_", "SPELL_", "SPELLS_",
    "STOP_MOVIE", "TAXIMAP_", "TIME_PLAYED_", "TRADE_", "TRAINER_", "UI_", "UNIT_", "UPDATE_", "VARIABLES_",
    "VEHICLE_", "WORLD_", "ZONE_", "BOSS_", "BN_", "FRIENDLIST_", "LFG_", "EDIT_MODE_", "COOLDOWN_VIEWER_",
    "TALKINGHEAD_", "SOFT_", "TOOLTIP_", "HIDE_", "SHOW_", "START_", "STOP_", "GAME_", "SCENARIO_",
)
NAME = re.compile(r'"([A-Z][A-Z0-9_]{4,})"')


def names():
    found = set()
    for base, dirs, files in os.walk(ROOT):
        rel = os.path.relpath(base, ROOT)
        top = rel.split(os.sep)[0]
        if top in SKIP_DIRS:
            dirs[:] = []
            continue
        for name in files:
            if name.endswith(".lua"):
                with open(os.path.join(base, name), encoding="utf-8", errors="replace") as handle:
                    for match in NAME.finditer(handle.read()):
                        word = match.group(1)
                        if word.startswith(PREFIXES):
                            found.add(word)
    return sorted(found)


def render(events):
    lines = [
        "-- Made by Tools/sim/events.py: don't edit. Every name in Cinematic's code",
        "-- that looks like a game event, for the simulation probe's way B",
        "-- (Dev/SimProbeTest.lua). Dev copy only.",
        "local _, ns = ...",
        "ns.SIM_EVENTS = {",
    ]
    lines += ['\t"%s",' % event for event in events]
    lines.append("}")
    return "\n".join(lines) + "\n"


def main():
    text = render(names())
    if "--check" in sys.argv:
        with open(OUT, encoding="utf-8") as handle:
            same = handle.read() == text
        print("SimEvents.lua " + ("up to date" if same else "OUT OF DATE: python -I Tools/sim/events.py"))
        sys.exit(0 if same else 1)
    with open(OUT, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)
    print("wrote %s (%d events)" % (os.path.relpath(OUT, ROOT), text.count('\t"')))


if __name__ == "__main__":
    main()
