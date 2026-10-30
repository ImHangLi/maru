# App icon notes

The icon is one pink capsule on white. It shows a daily dose with the fewest possible shapes, in the style of the built-in Apple apps.

- Round 1 was a pink circle with a white capsule cutout. At small sizes it looked like a "no entry" sign, and the owner asked for a simpler mark.
- Round 2 explored six simpler marks. The owner picked the single capsule.
- The final images are drawn from vector geometry with the same pink gradient as the generated candidate, so the edges are clean.
- Variants: light (white background), dark (#121212 background), and tinted (a gray-to-white capsule on black).

All images are 1024 x 1024 with no alpha channel.

## Alternate icons (D112)

Maru Pro adds five alternate icons: "Blue", "Purple", "Green", "Night", and "Mono". Each is the same capsule with the same geometry and the same gradient rule as the pink icon.

- `make_icons.py` is the source. Run `uv run docs/brand/make_icons.py`. It writes `App/AppIcons.xcassets`: the alternate icons and a preview of each choice for Settings.
- The script fits the geometry and the pink gradient to `AppIcon.png`. A new color gets its gradient from the same rule: the top is the color with 17 percent white, and the bottom is a little darker and more saturated.
- Each alternate icon uses the tinted image of the primary icon.

## Reminder sounds (D112, replaced by D120)

The eight reminder sounds of Maru Pro are CC0 files from other authors. No script makes them. `docs/third-party-licenses.md` lists the source, author, license, and edits of each sound.
