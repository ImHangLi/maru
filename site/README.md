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

`STORE_URL` in `build.py` is the one link of the badge, of the "Download" button in the top bar, and of the text link at the end of the home page. It also sets the Smart App Banner. The link opens a store page only when the app is on sale. Do not deploy the site before that.

The badge is in the hero only, because Apple asks for one badge in a layout. It is a part of the download unit: the app icon and the name, the badge, and one line that says where the app runs (iPhone, iOS 17 or later, from `project.yml`). Name no other device there. The top bar has a plain "Download" button in its own style, with no Apple logo, and the end of the home page has a text link.

## Top bar

The top bar is a dark island that hangs from the top edge, in the middle of the page, as wide as its content. It is solid, so it stays readable over a picture, and it does not change when the page scrolls. Below 420 px it is the full width. It holds the logo, the language button, the GitHub button, and the "Download" button. The tokens that start with `--bar-` in `style.css` set its colors.

## Icons

Every icon is from [Hugeicons](https://hugeicons.com), the free stroke set, package `@hugeicons/core-free-icons` version 4.3.5, MIT license. The paths are in `ICONS` in `build.py`, and the pages have them as inline SVG. No icon font, no CDN, and no script loads them. `--icon-size` and `--icon-stroke` in `style.css` set the size and the stroke of all icons. To add an icon, copy its paths from the same package and the same set.

## Type

The site uses the system fonts of each language and loads no font file: San Francisco for the Latin languages, PingFang SC, Hiragino Sans, and Apple SD Gothic Neo, each with fallbacks, through `:lang()`. Chinese, Japanese, and Korean have no negative tracking and more line height. Chinese and Japanese trim the empty half of a full-width mark at the edge of a line. Japanese headlines use proportional kana. Korean headlines are a little tighter. A headline does not hyphenate.

## Style and motion

`style.css` starts with one block of tokens: color, radius, duration, easing, shadow, icon, type, and space. A rule below that block uses a token and no raw value.

- A transition or an animation uses one of the four easing tokens. Do not use `ease` or `ease-in-out`.
- The page has one entrance when it loads, about 660 ms long. The top bar falls in from above the top edge (480 ms), and its content fades in at the end. The headline lines, the sentence, and the download unit rise 14 px in order, 60 ms apart (420 ms each), and the phone rises 24 px and grows from 97% (520 ms). A text page has the same bar and a shorter entrance of its title and its body.
- The phone is in the first paint at 30% opacity, so the largest picture of the page does not wait for the entrance.
- A block enters one time when it scrolls into view, with the same rise, blur, and duration as the hero parts. The blur clears at 60% of the time, so text is sharp when it comes to rest.
- Content is visible with no script. `<html>` gets the class `motion` only when the visitor did not ask for reduced motion. `site.js` adds the class `is-in` to a block when it enters the view. A page from the back and forward cache shows at rest.
- The language menu opens in 200 ms from its button (fade, scale from 96%, a few pixels of movement) and closes faster, in 130 ms (fade and scale). `site.js` keeps the menu in the layout until the close animation ends. With reduced motion it only fades.
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
