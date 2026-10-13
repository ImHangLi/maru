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

## App Store badge

The hero has Apple's "Download on the App Store" badge in the language of the page. The files in `badges/` come from Apple's marketing tools. Do not change them. Apple asks for a height of 40 px or more on a screen and a clear space of one quarter of the height. The rules are in Apple's [marketing guidelines](https://developer.apple.com/app-store/marketing/guidelines/).

`STORE_URL` in `build.py` is the one link of the badge, of the "Download" button in the top bar, and of the text link at the end of the home page. It is a placeholder until Maru is on the App Store, and the build prints a warning while it is the placeholder. **Do not deploy the site with the placeholder.** Set the real link, build again, and check that the warning is gone. The real link also turns on the Smart App Banner.

The badge is in the hero only, because Apple asks for one badge in a layout. The top bar has a plain "Download" button in its own style, with no Apple logo, and the end of the home page has a text link.

## Top bar

The top bar is a dark island that hangs from the top edge, in the middle of the page, as wide as its content. It is solid, so it stays readable over a picture, and it does not change when the page scrolls. Below 420 px it is the full width. It holds the logo, the language button, the GitHub button, and the "Download" button. The tokens that start with `--bar-` in `style.css` set its colors.

## Icons

Every icon is from [Hugeicons](https://hugeicons.com), the free stroke set, package `@hugeicons/core-free-icons` version 4.3.5, MIT license. The paths are in `ICONS` in `build.py`, and the pages have them as inline SVG. No icon font, no CDN, and no script loads them. `--icon-size` and `--icon-stroke` in `style.css` set the size and the stroke of all icons. To add an icon, copy its paths from the same package and the same set.

## Style and motion

`style.css` starts with one block of tokens: color, radius, duration, easing, shadow, icon, type, and space. A rule below that block uses a token and no raw value.

- A transition or an animation uses one of the four easing tokens. Do not use `ease` or `ease-in-out`.
- An entrance moves 6 px, clears a blur of 2 px, and fades in, in 300 ms. A part of a block starts 70 ms after the part before it.
- Content is visible with no script. `site.js` adds the class `is-in` to a block when it enters the view, and the entrance plays one time. `<html>` gets the class `motion` only when the visitor did not ask for reduced motion.
- A press scales a control to 0.98. The link of the App Store badge changes only its opacity, because the badge must not move.

## Pictures

```sh
python3 site/build.py --shots /path/to/captures
python3 site/concept.py /path/to/captures
```

Both commands need `sips` (macOS) and `cwebp`.

- `build.py --shots` reads `today.png`, `history.png`, and `detail.png`, and language files such as `today-ja.png`. It writes WebP files of 780 px width to `shots/`. The page shows them in an iPhone frame. A language page uses its own file, or the English file.
- `concept.py` cuts two pictures with a transparent background, at one scale. `shots/widget.webp` is the widget from `widget.png`. `shots/notification.webp` is the notification from `reminder-expanded.png`. One block of the home page shows the two together with no phone. They are English on every page.

Use only real captures of the app. Do not draw app screens.

## Preview

```sh
python3 -m http.server 8931 --directory site
```
