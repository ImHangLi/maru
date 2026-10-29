# Third-party licenses

Every third-party dependency of Maru is in this file, with its pinned version and its license text. Update the entry when you change a version. Add an entry when you add a dependency. The app must show these notices before a public release.

## GRDB.swift

- Use: SQLite access in the `MaruDatabase` target of `Packages/MaruKit`.
- Version: 7.11.1, pinned with `exact:` in `Packages/MaruKit/Package.swift`. Revision `b83108d10f42680d78f23fe4d4d80fc88dab3212`.
- Source: https://github.com/groue/GRDB.swift
- License: MIT. The text below is the `LICENSE` file of version 7.11.1.

```text
Copyright (C) 2015-2025 Gwendal Roué

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

## Hugeicons (landing site only)

- Use: four icons (GitHub, globe, check mark, close) as inline SVG in the pages of `site/`. The app does not use them, so the app does not show this license.
- Version: `@hugeicons/core-free-icons` 4.3.5, the free stroke set. The paths are copied into `site/build.py`.
- Source: https://hugeicons.com and https://www.npmjs.com/package/@hugeicons/core-free-icons
- License: MIT. The text below is the `LICENSE.md` file of version 4.3.5.

```text
Copyright (c) 2025 Hugeicons

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## App icons (not third-party)

- Use: the alternate app icons and their previews in `App/AppIcons.xcassets` (D112, D132).
- Source: `docs/brand/make_icons.py` draws the original color icons from vector geometry.
- D132 adds generated ceramic artwork owned by the project: Rose Ceramic, Blue Lotus, and Rose and Sage.
- The chosen round 2 concepts supply the light artwork. Image generation edits supply the dark artwork. Grayscale conversions supply the tinted artwork.
- The source prompts and generation records stay in the research folder. These icons use no third-party image, sample, or font.
- License: the same terms as the rest of this repository (`README.md`, "License"). The script uses Pillow on the Mac only. The app does not contain it, so it shows no notice for it.

## Reminder sounds (CC0)

- Use: the eight reminder sounds of Maru Pro in `App/Sounds` (D112, replaced by D120). Each file is 16-bit linear PCM in CAF at 44.1 kHz, 0.67 to 2.23 s long.
- License of each sound: CC0 1.0 Universal (public domain), https://creativecommons.org/publicdomain/zero/1.0/. The license needs no credit. The Freesound page of each sound and the Kenney page show the CC0 license. Maru does not show a notice in the app.
- Quality: the Freesound sounds come from the public high-quality preview (Ogg Vorbis, about 160 kbps), and the Glass sound comes from an Ogg Vorbis file. The sources are lossy. A later build can use the original files after a Freesound login.
- Edits for every sound: trim silence, a short fade-in and a fade-out, a gain to about -16 LUFS (peak limiting where the gain would clip), a conversion to 16-bit PCM CAF with `afconvert`. The highest true peak is -1.5 dBTP.

| Name in Maru | File | Author | Source | Origin | Edits |
|---|---|---|---|---|---|
| Rising Chime | `maru-rising-chime.caf` | Rob_Marion | https://freesound.org/people/Rob_Marion/sounds/541985/ | Freesound preview | Trimmed silence, 0.21 s fade-out, gain -2.3 dB to -16.0 LUFS. |
| Marimba | `maru-marimba-hello.caf` | Rob_Marion | https://freesound.org/people/Rob_Marion/sounds/542004/ | Freesound preview | Trimmed silence, 0.14 s fade-out, gain -2.4 dB to -16.0 LUFS. |
| Soft Bell | `maru-soft-bell.caf` | JustVic | https://freesound.org/people/JustVic/sounds/430800/ | Freesound preview | The source stops before the decay ends, so a 0.25 s fade-out removes the cut. Gain +1.0 dB to -16.0 LUFS. |
| Glass | `maru-glass-ting.caf` | Kenney (kenney.nl) | https://kenney.nl/assets/interface-sounds (file `Audio/glass_004.ogg`) | Kenney Interface Sounds, Ogg Vorbis | Trimmed silence, 0.14 s fade-out, gain +0.4 dB, 1.0 dB peak limiting, -16.8 LUFS. |
| Chime Bars | `maru-chime-bars.caf` | SamuelGremaud | https://freesound.org/people/SamuelGremaud/sounds/517660/ | Freesound preview | Removed 46 ms of handling noise before the strike. 0.25 s fade-out. Gain +5.6 dB with peak limiting, -18.8 LUFS (about 3 dB quieter than the others). |
| Hand Bell | `maru-hand-bell.caf` | IENBA | https://freesound.org/people/IENBA/sounds/648960/ | Freesound preview | Trimmed silence, 0.18 s fade-out, gain +0.2 dB to -16.0 LUFS. |
| Music Box | `maru-music-box.caf` | moodyfingers | https://freesound.org/people/moodyfingers/sounds/732943/ | Freesound preview | Trimmed silence, 0.25 s fade-out, gain +5.4 dB with 2.3 dB peak limiting, -16.2 LUFS. |
| Synth Bell | `maru-synth-bell.caf` | plasterbrain | https://freesound.org/people/plasterbrain/sounds/419493/ | Freesound preview | Trimmed silence, 0.13 s fade-out, gain +8.1 dB to -16.0 LUFS. |

## Paywall picture (generated, not third-party)

- Use: `ProHero` in `App/Assets.xcassets`, the picture of the second paywall (D116).
- Source: the image generation of Codex (OpenAI) made it from a text prompt that asks for an abstract gradient in the palette of the app color. It copies no third-party image, font, or logo. The prompt and the other candidates are in the maintainer's research folder, not in this repository.
- License: the same terms as the rest of this repository (`README.md`, "License"). The app shows no notice for it.
