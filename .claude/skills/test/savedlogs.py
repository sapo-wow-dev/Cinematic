"""Shared reading of the test logs the game saved (SavedVariables), for known.py and read_log.py.

Every test writes its lines into a CinematicDB.<name>Log list; the game saves the file on /reload and logout only,
and the next run of the same test clears its list, so a log not archived is lost.
"""
import glob
import hashlib
import os
import re
import time

WOW = r"C:\Program Files (x86)\World of Warcraft"
CLIENTS = {"_forever_": "forever", "_retail_": "retail", "_classic_era_": "classic_era"}
KEY = re.compile(r'^\["([A-Za-z0-9_]+)"\] = \{\s*$')
ITEM = re.compile(r'^"(.*)",(?:\s*-- \[\d+\])?\s*$')


def unescape(text):
    try:
        return text.encode("latin-1", "backslashreplace").decode("unicode_escape").encode("latin-1").decode("utf-8", "replace")
    except (UnicodeError, ValueError):
        return text.replace("\\n", "\n").replace('\\"', '"').replace("\\\\", "\\")


def saved_files():
    """(client, path) for each client's dev copy saved file, newest first."""
    found = []
    for folder, client in CLIENTS.items():
        for path in glob.glob(os.path.join(WOW, folder, "WTF", "Account", "*", "SavedVariables", "CinematicDev.lua")):
            found.append((client, path))
    return sorted(found, key=lambda f: -os.path.getmtime(f[1]))


def log_tables(path):
    """{key: [lines]} for every top-level CinematicDB key ending in Log (and "log" itself), lists of strings only."""
    out, key, lines = {}, None, None
    with open(path, encoding="utf-8", errors="replace") as f:
        for raw in f:
            raw = raw.rstrip("\r\n")
            if key is None:
                m = KEY.match(raw)
                if m and (m.group(1) == "log" or m.group(1).endswith("Log")):
                    key, lines = m.group(1), []
                continue
            if raw.startswith("}"):
                out[key] = lines
                key = None
                continue
            m = ITEM.match(raw)
            if m:
                lines.append(unescape(m.group(1)))
            elif raw.startswith("{") or raw.startswith("["):
                key = None  # not a plain list of lines: skip it
    return out


def archive_name(client, path, key, lines):
    """File name the archive keeps this log under: one per distinct content."""
    digest = hashlib.sha1("\n".join(lines).encode("utf-8", "replace")).hexdigest()[:8]
    day = time.strftime("%Y-%m-%d", time.localtime(os.path.getmtime(path)))
    return "%s-%s-%s-%s.txt" % (day, client, key, digest)
