# Maru site

The landing site of Maru at `https://maru.day`. Static files, no framework, no tracking, and no cookies.

## Build

```sh
python3 site/build.py
```

The command needs Python 3 and nothing else. It writes the four pages of each language, the English comparison and topic pages, and `sitemap.xml`. Commit the generated pages with the source.

| Source | What it holds |
|---|---|
| `build.py` | The layout of every page, and the `STORE_URL` constant |
| `src/strings/<lang>.json` | The text of one language |
| `src/guides/en.json` | The text of the English comparison and topic pages |
| `shots/` | The screenshots of the app in each language |
| `mock.py` | The widget and the reminder of the home page, drawn in HTML |
| `src/mock/<lang>.json` | The app text of the widget and the reminder in one language |
| `../PRIVACY.md` | The full privacy policy. It stays English on every language page |
| `style.css`, `site.js` | The style, the scroll entrances, the screens of the hero phone, and the language hint |
| `social.py` | The social preview cards: `og.png` and one card for each other language. Also the pictures of the repository README |

Each page is the index file of its own folder: `/`, `/faq/`, `/privacy/`, `/support/`, and the same under each language folder. The address ends with a slash, so Cloudflare serves it with no redirect. The build also writes `404.html`, `_redirects`, and `llms.txt`. `_redirects` sends the old addresses (`/compare.html`, `/faq.html`, `/privacy.html`, `/support.html`, `/zh-hans/`, `/ja/`, `/ko/`, `/us/`) to the new ones. Do not edit a generated file by hand.

## Comparison and topic pages

The English site also has pages for search: `/compare/` lists them, and the English footer links to it. The research and the sources are in `~/Documents/Research/maru/seo-pages-research.md` (D149).

| Kind | Pages |
|---|---|
| Comparison | `/compare/medisafe/`, `/compare/mytherapy/`, `/compare/apple-health/`, `/compare/round-health/` |
| Topic | `/pill-reminder-app/`, `/vitamin-reminder-app/`, `/medication-alarm/`, `/apple-watch-pill-reminder/`, `/pill-reminder-no-account/` |

- The pages are English only. They have no `hreflang` alternates, and the language menu goes to the home page of each language.
- A fact about another app needs a source on that app's own store page, help pages, or support pages. Put the source in `sources`, and change `checked` to the date that you read it. If you cannot verify a fact, do not write it.
- Each comparison shows the App Store privacy label of Maru next to the label of the other app.
- Titles and headings have no "free", no price, and no discount. The body can say "free" when it is true.
- `sitemap.xml` and `llms.txt` list the pages.

## Languages

English is at `/`. The other languages are at `/cn/` (Simplified Chinese), `/jp/`, `/es/`, `/de/`, and `/kr/`. A folder is a two-letter name, because ads and links carry it. The `lang` and `hreflang` values stay correct language tags (`zh-Hans`, `ja`, `ko`). `_redirects` sends `/us/` to `/` and the old folders (`/zh-hans/`, `/ja/`, `/ko/`) to the new ones. They are the languages of the app (D051, D059). Use the words of `App/Localizable.xcstrings` for the names of screens and buttons.

A `|` in a headline marks a place where the line can break.

The top bar has a language menu. It is a `details` element with plain links, so it works with no script. A link goes to the same page in the other language.

## Before and after the release

`RELEASED` in `build.py` says if Maru is in the App Store.

- While it is `False`, the hero has one plain line, "Coming soon to the App Store", in the language of the page. The page has no Apple badge, no "Download" button, no link to the App Store, and no Smart App Banner. Apple's badge is a call to get an app that is in the store, and the pre-order badge is only for an app on pre-order. See Apple's [marketing guidelines](https://developer.apple.com/app-store/marketing/guidelines/).
- When it is `True`, the hero has Apple's "Download on the App Store" badge in the language of the page, the top bar has a "Download" button, the end of the home page has a text link, and the Smart App Banner is on. `STORE_URL` is the link of all of them.
- The files in `badges/` come from Apple's marketing tools. Do not change them. Apple asks for a height of 40 px or more on a screen and a clear space of one quarter of the height. The badge is in the hero only, because Apple asks for one badge in a layout.

Before the submission: build with `RELEASED = False` and deploy, because App Review reads the FAQ and the privacy pages. On the day of the release: set `RELEASED = True`, check `DEVICES`, build, and deploy.

`DEVICES` in `build.py` is the list of devices that the row under the badge names: `"iphone"`, `"ipad"`, and `"watch"`. Each has one icon and its product name. **The list must match the devices that the released app supports.** It is `["iphone", "ipad", "watch"]` now: version 1.1.0 embeds the Apple Watch app as a Maru Pro feature. The FAQ answer about Apple Watch and the facts in `llms.txt` must agree with the list.

## Top bar

The top bar is a dark island that hangs from the top edge, in the middle of the page, as wide as its content. It is solid, so it stays readable over a picture, and it does not change when the page scrolls. Below 420 px it is the full width. It holds the logo, the language button, and the "Download" button. The tokens that start with `--bar-` in `style.css` set its colors.

## Icons

Every icon is from [Hugeicons](https://hugeicons.com), the free stroke set, package `@hugeicons/core-free-icons` version 4.3.5, MIT license. The paths are in `ICONS` in `build.py`, and the pages have them as inline SVG. No icon font, no CDN, and no script loads them. `--icon-size` and `--icon-stroke` in `style.css` set the size and the stroke of all icons. To add an icon, copy its paths from the same package and the same set.

## Type

The site uses the system fonts of each language and loads no font file: San Francisco for the Latin languages, PingFang SC, Hiragino Sans, and Apple SD Gothic Neo, each with fallbacks, through `:lang()`. Chinese, Japanese, and Korean have no negative tracking and more line height. Chinese and Japanese trim the empty half of a full-width mark at the edge of a line. Japanese headlines use proportional kana. Korean headlines are a little tighter. A headline does not hyphenate.

## Style and motion

`style.css` starts with one block of tokens: color, radius, duration, easing, shadow, icon, type, and space. A rule below that block uses a token and no raw value.

- A transition or an animation uses one of the four easing tokens. Do not use `ease` or `ease-in-out`.
- The page has one entrance when it loads, about 660 ms long. The top bar falls in from above the top edge (480 ms), and its content fades in at the end. The headline lines, the sentence, and the download unit rise 14 px in order, 60 ms apart (420 ms each), and the hero phone rises 24 px and grows from 97% (520 ms). A text page has the same bar and a shorter entrance of its title and its body.
- The hero phone is in the first paint at 30% opacity, so the largest picture of the page does not wait for the entrance.
- A block enters one time when it scrolls into view, with the same rise, blur, and duration as the hero parts. The blur clears at 60% of the time, so text is sharp when it comes to rest.
- Content is visible with no script. `<html>` gets the class `motion` only when the visitor did not ask for reduced motion. `site.js` adds the class `is-in` to a block when it enters the view. A page from the back and forward cache shows at rest.
- The language menu opens in 200 ms from its button (fade, scale from 96%, a few pixels of movement) and closes faster, in 130 ms (fade and scale). `site.js` keeps the menu in the layout until the close animation ends. With reduced motion it only fades.
- A press scales a control to 0.98. The link of the App Store badge changes only its opacity, because the badge must not move.

## Pictures

| Block | Picture |
|---|---|
| Hero | A phone with three real screens: Today, My Items, and History. Nothing in it works |
| Alarm (iOS 26+) | A screenshot of the edit screen with the Alarm switch on |
| Reminders | A Lock Screen reminder with its actions, and the medium Today widget, on a wallpaper, drawn in HTML |
| Lock Screen (PRO) | A picture of the Lock Screen with the card of "Next Dose on Lock Screen" |
| Family (PRO) | A screenshot of the Family page |
| History | A screenshot of History: the graph and the last 7 days of each item |
| Apple Watch (PRO) | A screenshot of the Watch app in a drawn frame |
| Photos | Three supplement jars, cut out as item icons |

The order of the blocks follows the store page. The closing panel has "No account" and "No ads". A block with `mark` in `src/strings/<lang>.json` has a small mark after its heading: `PRO`, or the system that it needs.

### Screenshots

```sh
python3 site/build.py --shots /path/to/captures
```

The command needs `cwebp` and `ffmpeg`. It reads the store captures of 2412 x 5244 in `<captures>/<lang>/`, for example `<captures>/zh-Hans/today.png`: `today.png`, `items.png`, `history-all.png`, `alarm.png`, `family.png`, `lock-clock.png`, `lock-date.png`, `la.png`, and `watch.png`. A language with no folder keeps its files. It writes WebP files of 780 px width to `shots/`, and the Watch capture keeps its own width. Each language page shows its own files in an iPhone frame.

- Use the same captures as the store screenshots, so the site and the store show the same sample family: Me, Mom, Dad, Mochi the cat, and Biscuit the dog.
- `lock-<lang>.webp` joins three captures, as the store frame does. The date comes from `lock-date.png`, the clock and the wallpaper come from `lock-clock.png`, and the card comes from `la.png`, where it is on black. The card covers the reminder of the Lock Screen captures.

### The screens of the hero phone

With no script, the phone is the Today picture. `site.js` adds two screens. Their pictures load when the page is idle, or at the first use of the phone, so the first paint does not wait for them.

| Screen | How it opens, as in the app | Picture |
|---|---|---|
| My Items | The tab bar. No movement | `items-<lang>.webp` |
| History | The calendar button. It slides in from the right, and the tab bar stays in place | `history-<lang>.webp`, the picture of the History block |

- The phone shows the top of each list and does not scroll, because the store captures have one position of each list.
- Settings and Add Item are not in the phone, because the store captures have no pictures of them.
- A `button` lies over each control of a capture that moves between screens: the calendar, the two tabs, and the back button. Each button has a label in the language of the page (`phone` in `src/strings/<lang>.json`), and it is 44 pt of the app or more in each direction. Escape goes back. No other control of a capture does anything.
- For assistive technology, the phone is one group with a short description, and each added picture is hidden.
- With reduced motion, History fades in and out and does not move.

### Jars

`shots/jar-*.webp` are three supplement jars with made-up brand labels: Driftholm, daywick, and Quietfield. The base photos are from Unsplash, under the [Unsplash License](https://unsplash.com/license), by Supliful:

- Omega-3: <https://unsplash.com/photos/7low5R-nSDU>
- Vitamin D3: <https://unsplash.com/photos/p3riFbawRgw>
- Magnesium: <https://unsplash.com/photos/W95UhZ1lwFQ>

The labels are new, and their numbers and barcodes are fake. Apple's Vision framework cut out each jar, as the app does.

### Widget and reminder

`mock.py` draws the widget and the reminder in HTML and CSS. `src/mock/<lang>.json` holds their words in one language (from the String Catalogs) and the time format.

- The components follow `Widget/` and `docs/design.md`: the system font, the sizes in points, and the default pink. The reminder is a Lock Screen banner of iOS 26, measured from a capture at 3x. It shows the title and the body of a due reminder from `MaruNotifications`, and the time. Under it are the actions that a touch and hold shows. It has the width of the widget.
- A component scales with its block. `--base` is the width that it fills, in points, and `--pt-max` stops it at a little more than its real size. The colors are tokens that start with `--app-`. The site is light only, because the app pictures are light captures. The dark colors for the README pictures are in `social.py`.
- Each component is one picture for assistive technology: it has `role="img"` and the alt text of `shots` in `src/strings/<lang>.json`.

## Social preview cards

```sh
python3 site/social.py
```

The command needs Google Chrome on macOS. It draws each card as an HTML page with the system fonts, and Chrome takes the picture. Run it when the headline, the icon, or the Today screenshots change, and commit the pictures.

- `og.png` and `og-cn.png`, `og-jp.png`, `og-es.png`, `og-de.png`, `og-kr.png`: 1200 x 630 px, for Open Graph and X. Every page of a language names the card of that language in `og:image` and `twitter:image`, with `twitter:card` set to `summary_large_image`.
- `og-github.png`: 1280 x 640 px, the same design in English, for the social preview of the GitHub repository. Upload it by hand in the settings of the repository. The site does not serve it.
- The files are PNG, because X, Facebook, LinkedIn, Slack, and iMessage all read PNG, and each file is under 300 KB.
- A card has the icon, the name, the headline of the home page, and the top of the Today screen. It has no App Store badge and no "Download", so it stays true before and after the release.
- The command also writes the pictures of the repository README to `docs/images/`: `hero.png`, `reminders.png`, and `history.png`, and a `-dark` file of each for the dark theme of GitHub. The feature pictures are the blocks of the home page on a card. The dark hero shows `shots/today-dark-en.webp`, and the dark History card shows `shots/history-dark-en.webp`. They are captures of the app in dark mode at 780 px width, made from a 1206 x 2622 capture with `sips --resampleWidth 780` and `cwebp -q 90 -sharp_yuv`. The site does not serve the dark captures.
- Platforms keep a card for days. After a change, ask for a new read in the X Card Validator, the Facebook Sharing Debugger, and the LinkedIn Post Inspector.

## Deploy

The site is a Cloudflare Worker with static assets. `wrangler.toml` is in `site/`, and `.assetsignore` keeps the sources out of the upload.

`BingSiteAuth.xml` verifies the site in Bing Webmaster Tools. Keep it in the upload.

```sh
python3 site/build.py
cd site && npx wrangler deploy
```

After a deploy, check these addresses. Each must answer 200, or the redirect that the list names.

```sh
for p in / /faq/ /privacy/ /support/ /cn/ /jp/ /kr/ /es/ /de/ /sitemap.xml /robots.txt /llms.txt /BingSiteAuth.xml; do curl -s -o /dev/null -w "%{http_code} $p\n" https://maru.day$p; done
curl -sI https://maru.day/privacy.html | head -3      # 301 to /privacy/
curl -sI https://maru.day/zh-hans/ | head -3          # 301 to /cn/
curl -s -o /dev/null -w "%{http_code}\n" https://maru.day/no-such-page   # 404
```

The App Store record needs two addresses: the privacy policy `https://maru.day/privacy/` and the support page `https://maru.day/support/`. The app opens `https://maru.day/privacy.html` and `https://maru.day/support.html`, and `_redirects` sends them on.

## Preview

```sh
python3 -m http.server 8931 --directory site
```
