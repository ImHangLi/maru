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

## App icons and reminder sounds (not third-party)

- Use: the alternate app icons and their previews in `App/AppIcons.xcassets`, and the reminder sounds in `App/Sounds` (D112).
- Source: Maru made them. `docs/brand/make_icons.py` draws the icons from vector geometry. `docs/brand/make_sounds.py` synthesizes the sounds from sine waves. They use no third-party image, sound, sample, or font.
- License: the same terms as the rest of this repository (`README.md`, "License"). The scripts use numpy and Pillow on the Mac only. The app does not contain them, so it shows no notice for them.

## Paywall picture (generated, not third-party)

- Use: `ProHero` in `App/Assets.xcassets`, the picture of the second paywall (D116).
- Source: the image generation of Codex (OpenAI) made it from a text prompt that asks for an abstract gradient in the palette of the app color. It copies no third-party image, font, or logo. The prompt and the other candidates are in the maintainer's research folder, not in this repository.
- License: the same terms as the rest of this repository (`README.md`, "License"). The app shows no notice for it.
