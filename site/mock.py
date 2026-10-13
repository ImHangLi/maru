"""The code-drawn app components of the home page: HTML and inline SVG, no pictures.

The text of each language is in src/mock/<lang>.json. The facts that every language shares are below:
the five sample items of App/DebugLaunch.swift, their records, and the days of the History graph.
The App Store screenshots use the same components and the same data, so the site and the store agree.
"""

import html
import json
from pathlib import Path

SITE = Path(__file__).resolve().parent
e = html.escape

# Form, item color, part of the day (0 morning, 1 noon, 2 evening), planned time, record time, and the last 7 days.
# A day of the week: a = all taken, s = some taken, m = planned and none taken, n = nothing planned (D061).
ITEMS = [
    {"form": "tablet", "color": "#FF8D28", "part": 0, "at": (7, 0), "took": (7, 4), "week": "aaaaaaa"},
    {"form": "softgel", "color": "#FF2D55", "part": 0, "at": (8, 0), "took": (8, 4), "week": "aaaaaaa"},
    {"form": "softgel", "color": "#FFCC00", "part": 1, "at": (12, 30), "took": (12, 31), "week": "aaamaam"},
    {"form": "capsule", "color": "#34C759", "part": 2, "at": (21, 0), "week": "aaaaaan"},
    {"form": "tablet", "color": "#00C8B3", "part": 2, "at": (21, 0), "week": "maaaaan"},
]
# The form icons of App/Icons.xcassets, unchanged.
FORM_ICONS = {
    "tablet": '<path d="M3 11v2.6a9 4.6 0 0 0 18 0V11a9 4.6 0 0 1-18 0Z" opacity="0.4"/><path d="M11.3 5.42A9 4.6 0 0 0 11.3 14.58Z"/><path d="M12.7 5.42A9 4.6 0 0 1 12.7 14.58Z"/>',
    "softgel": '<g transform="rotate(-35 12 12)"><path fill-rule="evenodd" d="M2.8 12a9.2 5.6 0 1 0 18.4 0a9.2 5.6 0 1 0-18.4 0ZM7.6 9.1h4.2a0.9 0.9 0 0 1 0 1.8H7.6a0.9 0.9 0 0 1 0-1.8Z"/></g>',
    "capsule": '<g transform="rotate(-45 12 12)"><path d="M7.5 7.5H11.4V16.5H7.5A4.5 4.5 0 0 1 7.5 7.5Z"/><path d="M12.6 7.5H16.5A4.5 4.5 0 0 1 16.5 16.5H12.6Z" opacity="0.4"/></g>',
}
# The record circle of a Today row: "circle" and "checkmark.circle.fill" (RecordSymbol).
RING = '<svg class="m-ring" viewBox="0 0 22 22"><circle cx="11" cy="11" r="10.13"/></svg>'
CHECK = ('<svg class="m-check" viewBox="0 0 22 22"><circle cx="11" cy="11" r="11"/>'
         '<path d="M7.17 11.5l2.67 3.17L14.83 7.17"/></svg>')
CHEVRON = '<svg class="m-chev" viewBox="0 0 20 34"><path d="M3.5 3.5L16.5 17L3.5 30.5"/></svg>'
# The 80 days of the sample history, read from the English capture: one string for each row, Sunday first,
# and one letter for each week. A: all taken. M: most taken. S: some taken. N: none taken. F: a future day.
GRAPH_ROWS = ["MAAMAMAMAANA", "NMAMAAAMMAAA", "AAMAMAAMAMAS", "MAMNAMAMAAMF",
              "AMMAAAMAMAAF", "AAMAAANMAMAF", "AAMMAMMAAAMF"]


def load(code):
    return json.loads((SITE / "src/mock" / f"{code}.json").read_text("utf-8"))


def clock(t, hour, minute):
    """A time in the region format of the language: 12-hour for English and Korean, 24-hour for the rest."""
    if t["time"] == "24h":
        return f"{hour}:{minute:02d}"
    h12 = f"{hour % 12 or 12}:{minute:02d}"
    mark = t["am"] if hour < 12 else t["pm"]
    # English puts a narrow no-break space before AM and PM, as iOS does. Korean puts the mark first.
    return f"{mark} {h12}" if t["time"] == "ko" else f"{h12} {mark}"


def form_icon(item):
    return f'<svg class="m-ico" viewBox="0 0 24 24" fill="{item["color"]}">{FORM_ICONS[item["form"]]}</svg>'


def strip(item, week=None):
    week = week or item["week"]
    return f'<span class="m-strip" style="--c:{item["color"]}">' + "".join(f'<i class="w-{d}"></i>' for d in week) + "</span>"


def today_row(t, i, state):
    """One row of the Today list. "tap" draws the open row that fills when the hero enters (Motion.fill)."""
    item, (name, amount) = ITEMS[i], t["items"][i]
    planned = amount + t["sep"] + clock(t, *item["at"])
    taken = amount + t["sep"] + t["taken_at"].format(t=clock(t, *item.get("took", item["at"])))
    if state == "tap":
        detail = (f'<span class="m-swap"><span class="m-before">{e(planned)}</span>'
                  f'<span class="m-after">{e(taken)}</span></span>')
        circle = f'<span class="m-rec m-tap"><span class="m-touch"></span>{RING}{CHECK}</span>'
    else:
        detail = e(taken if state == "taken" else planned)
        circle = f'<span class="m-rec">{CHECK if state == "taken" else RING}</span>'
    return (f'<div class="m-row">{form_icon(item)}<span class="m-txt"><b>{e(name)}</b>'
            f'<span class="m-sub">{detail}</span></span>{circle}</div>')


def today(t):
    """The Today list: Morning with two taken rows, and Noon with the row that one tap records."""
    rows = {0: [today_row(t, 0, "taken"), today_row(t, 1, "taken")], 1: [today_row(t, 2, "tap")]}
    return '<div class="m-app m-today">' + "".join(
        f'<p class="m-head">{e(t["parts"][p])}</p><div class="m-card">{"".join(r)}</div>' for p, r in rows.items()) + "</div>"


def graph(t):
    """The History graph: 12 weeks of squares in three steps of the tint, the months, and three weekday letters."""
    days = ["A"] + [GRAPH_ROWS[r][c] for c in range(12) for r in range(7)]
    # The first day is a Saturday: row 6 when the week starts on Sunday, row 5 when it starts on Monday.
    # A week that starts on Monday ends one day later, so its last column has one more future day.
    start = 5 if t["monday_first"] else 6
    if t["monday_first"]:
        days.append("F")
    cells = "".join(
        f'<i class="g-{d}" style="grid-area:{(start + n) % 7 + 2}/{(start + n) // 7 + 2}"></i>' for n, d in enumerate(days))
    months = "".join(f'<u style="grid-area:1/{c + 2}">{e(m)}</u>' for c, m in zip([1, 6, 10], t["months"]))
    rows = [0, 2, 4] if t["monday_first"] else [1, 3, 5]
    letters = "".join(f'<u class="g-wk" style="grid-area:{r + 2}/1">{e(w)}</u>' for r, w in zip(rows, t["weekdays"]))
    return f'<div class="m-card m-graph">{months}{letters}{cells}</div>'


def history(t):
    """The graph, and under it the last 7 days of three items, as on the History screen."""
    rows = "".join(
        f'<div class="m-row">{form_icon(ITEMS[i])}<span class="m-txt"><b>{e(t["items"][i][0])}</b>'
        f'<span class="m-sub">{e(t["parts"][ITEMS[i]["part"]])}</span></span>{strip(ITEMS[i])}{CHEVRON}</div>'
        for i in [1, 2, 4])
    return (f'<div class="m-app m-history">{graph(t)}'
            f'<p class="m-head m-gray">{e(t["last7"])}</p><div class="m-card">{rows}</div></div>')


def detail(t):
    """The item page of Omega-3: its plan, then its strip of the last 7 days and the counts under it (D061)."""
    i = 2
    item = ITEMS[i]
    week = item["week"]
    counts = [week.count("a"), week.count("s"), week.count("m")]
    plan = [(t["parts"][item["part"]], clock(t, *item["at"])), (t["days"], t["every_day"]), (t["amount"], t["items"][i][1])]
    plan_rows = "".join(f'<div class="m-row m-pair"><span>{e(k)}</span><span class="m-value">{e(v)}</span></div>' for k, v in plan)
    count_text = "".join(f"<span>{e(c.format(n=n))}</span>" for c, n in zip(t["counts"], counts))
    # The app puts the counts side by side, or one under the other when they do not fit in one line (ViewThatFits).
    # "counts_stack" in the language file says that they do not fit. The width is the same at every scale.
    stack = " m-stack" if t.get("counts_stack") else ""
    return (f'<div class="m-app m-detail"><p class="m-head m-gray">{e(t["plan"])}</p><div class="m-card">{plan_rows}</div>'
            f'<p class="m-head m-gray">{e(t["last7"])}</p><div class="m-card m-week"><div class="m-week-top">{form_icon(item)}'
            f'{strip(item)}</div><p class="m-counts{stack}">{count_text}</p></div></div>')


def widget(t):
    """The medium Today widget: the count, and each part of the day with its time and its capsules."""
    taken = {0, 1}
    cols = ""
    for p in range(3):
        mine = [i for i, it in enumerate(ITEMS) if it["part"] == p]
        caps = "".join(f'<i class="{"on" if i in taken else ""}"></i>' for i in mine)
        now = ' class="now"' if p == 1 else ""
        cols += (f'<div class="m-col"><b{now}>{e(t["parts"][p])}</b>'
                 f'<span class="m-time">{e(clock(t, *ITEMS[mine[0]]["at"]))}</span><span class="m-caps">{caps}</span></div>')
    count = t["of"].format(a=len(taken), b=len(ITEMS))
    return (f'<div class="m-widget"><div class="m-widget-top"><b>{e(t["today"])}</b><b>{e(count)}</b></div>'
            f'<div class="m-cols">{cols}</div></div>')


def reminder(t):
    """The Lock Screen reminder, opened, with its "Taken" action under it. The banner is a system view."""
    return (f'<div class="m-notif"><span class="m-app-icon"></span><span class="m-ts">{e(t["time_sensitive"])}</span>'
            f'<b>{e(t["reminder_title"])}</b><span class="m-body">{e(t["items"][1][0])}</span>'
            f'<span class="m-now">{e(t["now"])}</span></div><div class="m-action">{e(t["taken"])}</div>')
