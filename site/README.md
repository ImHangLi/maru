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

English is at `/`. The other languages are at `/cn/` (Simplified Chinese), `/jp/`, `/es/`, `/de/`, and `/kr/`. A folder is a two-letter name, because ads and links carry it. The `lang` and `hreflang` values stay correct language tags (`zh-Hans`, `ja`, `ko`). `_redirects` sends `/us/` to `/` and the old folders (`/zh-hans/`, `/ja/`, `/ko/`) to the new ones. They are the languages of the app (D051, D059). Use the words of `App/Localizable.xcstrings` for the names of screens and buttons.

A `|` in a headline marks a place where the line can break.

The top bar has a language menu. It is a `details` element with plain links, so it works with no script. A link goes to the same page in the other language.

## App Store button

Set `STORE_URL` in `build.py` and build again. This one constant changes the top bar, the hero, and the end of the home page, and it turns on the Smart App Banner.

- After the release, the button is Apple's "Download on the App Store" badge in the language of the page. The files in `badges/` come from Apple's marketing tools. Do not change them. Apple asks for a height of 40 px or more on a screen and a clear space of one quarter of the height.
- Before the release, the button is a plain black pill in the same format, with the line "Coming soon on the" and with no Apple logo. Apple keeps its badge and its logo for an app that is in the store. The pill is not Apple's badge.

The rules are in Apple's [marketing guidelines](https://developer.apple.com/app-store/marketing/guidelines/).

## Pictures

```sh
python3 site/build.py --shots /path/to/captures
python3 site/concept.py /path/to/captures
```

Both commands need `sips` (macOS) and `cwebp`.

- `build.py --shots` reads `today.png`, `history.png`, and `detail.png`, and language files such as `today-ja.png`. It writes WebP files of 780 px width to `shots/`. The page shows them in an iPhone frame. A language page uses its own file, or the English file.
- `concept.py` cuts two product pictures with a transparent background. `shots/widget.webp` is the widget from `widget.png`. `shots/reminder.webp` is the notification and its "Taken" action from `reminder-expanded.png`. The page shows them with no phone, on a stage. They are English on every page.

Use only real captures of the app. Do not draw app screens.

## Preview

```sh
python3 -m http.server 8931 --directory site
```
