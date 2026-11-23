#!/usr/bin/env python3
"""Tells Discord about the /bug and /claude commands and the Claude right-click entries. Run once, and again after changing it.

    python Tools/discord-bug-bot/register_commands.py

It asks for the bot token (the Bot page's token in the Discord Developer
Portal) without showing it, or reads DISCORD_BOT_TOKEN. The token is only
used here, never put it in the Worker or the repo.
"""
import getpass
import json
import os
import sys
import urllib.error
import urllib.request

APP_ID = "1566584455219515482"  # Cinematic Bugs, not secret

COMMANDS = [
    {
        "name": "bug",
        "description": "Report a Cinematic bug (it becomes a public GitHub issue)",
        "contexts": [0],  # servers only, not DMs
        "options": [
            {
                "name": "client",
                "description": "Which WoW you play",
                "type": 3,  # string
                "required": True,
                "choices": [
                    {"name": "Retail", "value": "retail"},
                    {"name": "Classic Era", "value": "classic_era"},
                    {"name": "WoW Forever", "value": "forever"},
                    {"name": "Other / not sure", "value": "other"},
                ],
            }
        ],
    },
    {
        # Sends the thread it's typed in to Claude on the author's PC
        # (claude_desk.py). Hidden from everyone but admins; the Worker also
        # checks CLAUDE_USERS.
        "name": "claude",
        "description": "Open a Claude session on Sapo's PC for this thread",
        "contexts": [0],
        "default_member_permissions": "0",
        "options": [
            {
                "name": "skill",
                "description": "Default: support in the bug forum, feature in the request forum",
                "type": 3,
                "required": False,
                "choices": [
                    {"name": "support (a player's problem)", "value": "support"},
                    {"name": "feature (a player's wish)", "value": "feature"},
                ],
            },
            {
                "name": "note",
                "description": "Anything to tell Claude along with the thread",
                "type": 3,
                "required": False,
                "max_length": 500,
            },
        ],
    },
    # Right-click a message > Apps: sends that one message (with a few around
    # it) to Claude, in any channel. Message commands take no options, so
    # each skill is its own entry. Names must match MESSAGE_COMMANDS in worker.js.
    {"name": "Claude: support", "type": 3, "contexts": [0], "default_member_permissions": "0"},
    {"name": "Claude: feature", "type": 3, "contexts": [0], "default_member_permissions": "0"},
]


def main():
    app_id = os.environ.get("DISCORD_APP_ID", APP_ID)
    token = os.environ.get("DISCORD_BOT_TOKEN") or getpass.getpass("Bot token (hidden as you paste): ").strip()
    if not token:
        sys.exit("No bot token given.")
    req = urllib.request.Request(
        f"https://discord.com/api/v10/applications/{app_id}/commands",
        data=json.dumps(COMMANDS).encode(),
        method="PUT",
        headers={
            "Authorization": f"Bot {token}",
            "Content-Type": "application/json",
            "User-Agent": "cinematic-bug-bot (https://github.com/sapo-wow-dev/Cinematic, 1)",
        },
    )
    try:
        with urllib.request.urlopen(req) as res:
            names = [c["name"] for c in json.load(res)]
            print("Registered:", ", ".join(n if " " in n else "/" + n for n in names))
    except urllib.error.HTTPError as err:
        sys.exit(f"Discord said {err.code}: {err.read().decode()}")


if __name__ == "__main__":
    main()
