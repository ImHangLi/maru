# Maru site

The landing site of Maru at `https://maru.day`. Static files, no framework, no tracking, and no cookies.

## Build

```sh
python3 site/build.py
```

The command needs Python 3 and nothing else. It writes the four pages of each language and `sitemap.xml`. Commit the generated pages with the source.

| Source | What it holds |
|---|---|
| `build.py` | The layout of every page, and the `STORE_URL` constant |
| `src/strings/<lang>.json` | The text of one language |
| `../PRIVACY.md` | The full privacy policy. It stays English on every language page |
| `style.css`, `site.js` | The style, the scroll entrances, and the language hint |

Do not edit `index.html`, `faq.html`, `privacy.html`, `support.html`, or a language folder by hand.

## Languages

English is at `/`. The other languages are at `/zh-hans/`, `/ja/`, `/es/`, `/de/`, and `/ko/`. They are the languages of the app (D051, D059). Use the words of `App/Localizable.xcstrings` for the names of screens and buttons.

A `|` in a headline marks a place where the line can break.

## App Store link

Set `STORE_URL` in `build.py` and build again. Every "Coming soon" button becomes Apple's "Download on the App Store" badge in the language of the page, and the Smart App Banner turns on. The badge files in `badges/` come from Apple's marketing tools. Follow Apple's badge rules when you change their size.

## Screenshots

```sh
python3 site/build.py --shots /path/to/screenshots
```

The command needs `sips` (macOS) and `cwebp`. It reads `today.png`, `reminder.png`, `history.png`, `widget.png`, and `detail.png`, and language files such as `today-ja.png`. It writes WebP files of 780 px width to `shots/`. A language page uses its own file, or the English file. A missing picture shows an empty frame with a label.

Use only real screenshots of the app. Do not draw app screens.

## Preview

```sh
python3 -m http.server 8931 --directory site
```
