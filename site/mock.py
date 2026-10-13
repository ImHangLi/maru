"""The code-drawn app components of the home page: the widget and the reminder, in HTML, no pictures.

The text of each language is in src/mock/<lang>.json. The facts that every language shares are below:
the five scheduled sample items of App/DebugLaunch.swift. The screenshots of the home page show the same items.
"""

import html
import json
from pathlib import Path

SITE = Path(__file__).resolve().parent
e = html.escape

# Part of the day (0 morning, 1 noon, 2 evening) and planned time of each item. The morning items are taken.
ITEMS = [{"part": 0, "at": (7, 0)}, {"part": 0, "at": (8, 0)}, {"part": 1, "at": (12, 30)},
         {"part": 2, "at": (21, 0)}, {"part": 2, "at": (21, 0)}]


def load(code):
    return json.loads((SITE / "src/mock" / f"{code}.json").read_text("utf-8"))


def clock(t, hour, minute):
    """A time in the region format of the language: 12-hour for English and Korean, 24-hour for the rest."""
    if t["time"] == "24h":
        return f"{hour}:{minute:02d}"
    h12 = f"{hour % 12 or 12}:{minute:02d}"
    mark = t["am"] if hour < 12 else t["pm"]
    # English puts a narrow no-break space before AM and PM, as iOS does. Korean puts the mark first.
    return f"{mark} {h12}" if t["time"] == "ko" else f"{h12} {mark}"


def widget(t):
    """The medium Today widget: the progress bar of the day, and each part of the day with its time and its capsules."""
    taken = {0, 1}
    cols = ""
    for p in range(3):
        mine = [i for i, it in enumerate(ITEMS) if it["part"] == p]
        caps = "".join(f'<i class="{"on" if i in taken else ""}"></i>' for i in mine)
        now = ' class="now"' if p == 1 else ""
        cols += (f'<div class="m-col"><b{now}>{e(t["parts"][p])}</b>'
                 f'<span class="m-time">{e(clock(t, *ITEMS[mine[0]]["at"]))}</span><span class="m-caps">{caps}</span></div>')
    # The bar has no text: its fill is the share of the doses that are taken (DayProgressBar).
    share = 100 * len(taken) / len(ITEMS)
    return (f'<div class="m-widget"><div class="m-widget-top"><b>{e(t["today"])}</b>'
            f'<span class="m-bar"><i style="width:{share:g}%"></i></span></div><div class="m-cols">{cols}</div></div>')


def reminder(t):
    """The Lock Screen reminder: the title and the body of a due reminder with the item name (MaruNotifications)."""
    return (f'<div class="m-notif"><span class="m-app-icon"></span><span class="m-notif-text"><span class="m-notif-top">'
            f'<b>{e(t["reminder_title"])}</b><span class="m-now">{e(t["now"])}</span></span>'
            f'<span class="m-body">{e(t["reminder_item"])}</span></span></div>')
