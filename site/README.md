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
| `mock.py` | The app components of the home page, drawn in HTML and SVG |
| `src/mock/<lang>.json` | The app text and the item names of the components in one language |
| `../PRIVACY.md` | The full privacy policy. It stays English on every language page |
| `style.css`, `site.js` | The style, the scroll entrances, and the language hint |

Each page is the index file of its own folder: `/`, `/faq/`, `/privacy/`, `/support/`, and the same under each language folder. The address ends with a slash, so Cloudflare serves it with no redirect. The build also writes `404.html`, `_redirects`, and `llms.txt`. `_redirects` sends the old addresses (`/faq.html`, `/privacy.html`, `/support.html`, `/zh-hans/`, `/ja/`, `/ko/`, `/us/`) to the new ones. Do not edit a generated file by hand.

## Languages

English is at `/`. The other languages are at `/cn/` (Simplified Chinese), `/jp/`, `/es/`, `/de/`, and `/kr/`. A folder is a two-letter name, because ads and links carry it. The `lang` and `hreflang` values stay correct language tags (`zh-Hans`, `ja`, `ko`). `_redirects` sends `/us/` to `/` and the old folders (`/zh-hans/`, `/ja/`, `/ko/`) to the new ones. They are the languages of the app (D051, D059). Use the words of `App/Localizable.xcstrings` for the names of screens and buttons.

A `|` in a headline marks a place where the line can break.

The top bar has a language menu. It is a `details` element with plain links, so it works with no script. A link goes to the same page in the other language.

## Before and after the release

`RELEASED` in `build.py` says if Maru is in the App Store.

- While it is `False`, the hero has one plain line, "Coming soon to the App Store", in the language of the page. The page has no Apple badge, no "Download" button, no link to the App Store, and no Smart App Banner. Apple's badge is a call to get an app that is in the store, and the pre-order badge is only for an app on pre-order. See Apple's [marketing guidelines](https://developer.apple.com/app-store/marketing/guidelines/).
- When it is `True`, the hero has Apple's "Download on the App Store" badge in the language of the page, the top bar has a "Download" button, the end of the home page has a text link, and the Smart App Banner is on. `STORE_URL` is the link of all of them.
- The files in `badges/` come from Apple's marketing tools. Do not change them. Apple asks for a height of 40 px or more on a screen and a clear space of one quarter of the height. The badge is in the hero only, because Apple asks for one badge in a layout.

On the day of the release: set `RELEASED = True`, check `DEVICES`, build, and deploy.

`DEVICES` in `build.py` is the list of devices that the row under the badge names: `"iphone"`, `"ipad"`, and `"watch"`. Each has one icon and its product name. **The list must match the devices that the released app supports.** It is `["iphone"]` now. The FAQ answer about Apple Watch and the facts in `llms.txt` must agree with the list.

## Top bar

The top bar is a dark island that hangs from the top edge, in the middle of the page, as wide as its content. It is solid, so it stays readable over a picture, and it does not change when the page scrolls. Below 420 px it is the full width. It holds the logo, the language button, the GitHub button, and the "Download" button. The tokens that start with `--bar-` in `style.css` set its colors.

## Icons

Every icon is from [Hugeicons](https://hugeicons.com), the free stroke set, package `@hugeicons/core-free-icons` version 4.3.5, MIT license. The paths are in `ICONS` in `build.py`, and the pages have them as inline SVG. No icon font, no CDN, and no script loads them. `--icon-size` and `--icon-stroke` in `style.css` set the size and the stroke of all icons. To add an icon, copy its paths from the same package and the same set.

## Type

The site uses the system fonts of each language and loads no font file: San Francisco for the Latin languages, PingFang SC, Hiragino Sans, and Apple SD Gothic Neo, each with fallbacks, through `:lang()`. Chinese, Japanese, and Korean have no negative tracking and more line height. Chinese and Japanese trim the empty half of a full-width mark at the edge of a line. Japanese headlines use proportional kana. Korean headlines are a little tighter. A headline does not hyphenate.

## Style and motion

`style.css` starts with one block of tokens: color, radius, duration, easing, shadow, icon, type, and space. A rule below that block uses a token and no raw value.

- A transition or an animation uses one of the four easing tokens. Do not use `ease` or `ease-in-out`.
- The page has one entrance when it loads, about 660 ms long. The top bar falls in from above the top edge (480 ms), and its content fades in at the end. The headline lines, the sentence, and the download unit rise 14 px in order, 60 ms apart (420 ms each), and the hero component rises 24 px and grows from 97% (520 ms). A text page has the same bar and a shorter entrance of its title and its body.
- The hero component is in the first paint at 30% opacity, so the largest picture of the page does not wait for the entrance.
- After the entrance, one tap records the noon row of the hero: a touch, then the circle fills with a spring, as in the app. Without motion the row shows the recorded state at once.
- A block enters one time when it scrolls into view, with the same rise, blur, and duration as the hero parts. The blur clears at 60% of the time, so text is sharp when it comes to rest.
- Content is visible with no script. `<html>` gets the class `motion` only when the visitor did not ask for reduced motion. `site.js` adds the class `is-in` to a block when it enters the view. A page from the back and forward cache shows at rest.
- The language menu opens in 200 ms from its button (fade, scale from 96%, a few pixels of movement) and closes faster, in 130 ms (fade and scale). `site.js` keeps the menu in the layout until the close animation ends. With reduced motion it only fades.
- A press scales a control to 0.98. The link of the App Store badge changes only its opacity, because the badge must not move.

## Pictures

The site has no screenshots. Each block shows one app component, drawn in HTML, CSS, and inline SVG by `mock.py`:

| Block | Component |
|---|---|
| Hero | The Today list: Morning with two recorded rows, and Noon with the row that one tap records |
| Reminders | The medium Today widget, and the Lock Screen reminder with its "Taken" action, on a wallpaper |
| History | The History graph, and the last 7 days of three items |
| Item | The plan of one item, and its strip of the last 7 days with the counts |

- The components follow the SwiftUI code in `App/` and `Widget/` and `docs/design.md`: the system font, the sizes in points, the default pink, the item colors, and the form icons of `App/Icons.xcassets`. The App Store screenshots use the same components and the same sample items.
- `src/mock/<lang>.json` holds the words of the app in one language (from the String Catalogs), the time format, and local names for the sample items. Change one file, build, and every block of that language follows. The facts that every language shares (forms, colors, times, and records) are at the top of `mock.py`.
- A component scales with its block. `--base` is the width that it fills, in points, and `--pt-max` stops it at a little more than its real size. The colors are tokens that start with `--app-`, with a dark set.
- Each component is one picture for assistive technology: it has `role="img"` and the alt text of `shots` in `src/strings/<lang>.json`.
- When the app changes, change the component in the same way, and compare it with a capture of the app at 3x (1 pt is 3 px). The site does not keep the captures.

## Deploy

The site is a Cloudflare Worker with static assets. `wrangler.toml` is in `site/`, and `.assetsignore` keeps the sources out of the upload.

```sh
python3 site/build.py
cd site && npx wrangler deploy
```

After a deploy, check these addresses. Each must answer 200, or the redirect that the list names.

```sh
for p in / /faq/ /privacy/ /support/ /cn/ /jp/ /kr/ /es/ /de/ /sitemap.xml /robots.txt /llms.txt; do curl -s -o /dev/null -w "%{http_code} $p\n" https://maru.day$p; done
curl -sI https://maru.day/privacy.html | head -3      # 301 to /privacy/
curl -sI https://maru.day/zh-hans/ | head -3          # 301 to /cn/
curl -s -o /dev/null -w "%{http_code}\n" https://maru.day/no-such-page   # 404
```

The App Store record needs two addresses: the privacy policy `https://maru.day/privacy/` and the support page `https://maru.day/support/`. The app opens `https://maru.day/privacy.html` and `https://maru.day/support.html`, and `_redirects` sends them on.

## Preview

```sh
python3 -m http.server 8931 --directory site
```
