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
| `shots/` | The screenshots of the app in each language |
| `mock.py` | The widget and the reminder of the home page, drawn in HTML |
| `src/mock/<lang>.json` | The app text of the widget and the reminder in one language |
| `../PRIVACY.md` | The full privacy policy. It stays English on every language page |
| `style.css`, `site.js` | The style, the scroll entrances, the hero phone, and the language hint |
| `social.py` | The social preview cards: `og.png` and one card for each other language. Also the pictures of the repository README |

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

`DEVICES` in `build.py` is the list of devices that the row under the badge names: `"iphone"`, `"ipad"`, and `"watch"`. Each has one icon and its product name. **The list must match the devices that the released app supports.** It is `["iphone", "ipad"]` now: version 1.0 has no Apple Watch app. The FAQ answer about Apple Watch and the facts in `llms.txt` must agree with the list.

## Top bar

The top bar is a dark island that hangs from the top edge, in the middle of the page, as wide as its content. It is solid, so it stays readable over a picture, and it does not change when the page scrolls. Below 420 px it is the full width. It holds the logo, the language button, the GitHub button, and the "Download" button. The tokens that start with `--bar-` in `style.css` set its colors.

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
| Hero | The full Today list in a phone that scrolls: Morning recorded, Noon and Evening open, and As Needed at the end |
| Reminders | The medium Today widget and a Lock Screen reminder on a wallpaper, drawn in HTML |
| History | A screenshot of History: the graph and the last 7 days of each item |
| Item | A screenshot of one item: its plan and its last 7 days with the counts |
| Photos | Three supplement jars, cut out as item icons |

### Screenshots

```sh
python3 site/build.py --shots /path/to/captures
```

The command needs `sips` (macOS), `cwebp`, and `ffmpeg`. It reads `today-<lang>.png`, `today-end-<lang>.png`, `history-<lang>.png`, and `detail-<lang>.png`, for example `today-zh-Hans.png`. It writes WebP files of 780 px width to `shots/`. Each language page shows its own files in an iPhone frame.

The hero phone is live. `today-<lang>.png` is Today at the top of the list, and `today-end-<lang>.png` is the same screen with the list scrolled to its end. The command joins them into two files:

- `today-<lang>.webp`: the full list with no bars. It scrolls inside the screen.
- `today-bars-<lang>.webp`: the status bar, the toolbar buttons, and the tab bar. It stays in place over the list. Its top has the background of the app with a soft lower edge, so the title scrolls away under it and does not show beside the buttons. The rest is clear.

The list has some empty space after its last group, so the As Needed row comes to rest above the tab bar.

The list scrolls with the wheel, a touch, the keys, or a mouse drag, and the scroll passes to the page at each end. When the phone comes into view, the list moves to its end one time and comes back. This hint does not play with reduced motion.

- Capture an iPhone 17 Pro simulator (1206 x 2622) in light mode, with a debug build of the app.
- Launch with `-MaruSampleData YES -MaruSampleRecords YES`, and with `-AppleLanguages` and `-AppleLocale` of the language. The sample items follow the app language.
- Remove the app before each language, because the sample items load only into an empty store.
- Set the status bar: `xcrun simctl status_bar <device> override --time 9:41 --batteryLevel 100`.
- Use only real captures of the app.

### Jars

`shots/jar-*.webp` are three supplement jars with made-up brand labels: Driftholm, daywick, and Quietfield. The base photos are from Unsplash, under the [Unsplash License](https://unsplash.com/license), by Supliful:

- Omega-3: <https://unsplash.com/photos/7low5R-nSDU>
- Vitamin D3: <https://unsplash.com/photos/p3riFbawRgw>
- Magnesium: <https://unsplash.com/photos/W95UhZ1lwFQ>

The labels are new, and their numbers and barcodes are fake. Apple's Vision framework cut out each jar, as the app does.

### Widget and reminder

`mock.py` draws the widget and the reminder in HTML and CSS. `src/mock/<lang>.json` holds their words in one language (from the String Catalogs) and the time format.

- The components follow `Widget/` and `docs/design.md`: the system font, the sizes in points, and the default pink. The reminder is a Lock Screen banner of iOS 26, measured from a capture at 3x. It shows the title and the body of a due reminder from `MaruNotifications`, and the time, with no action. It has the width of the widget.
- A component scales with its block. `--base` is the width that it fills, in points, and `--pt-max` stops it at a little more than its real size. The colors are tokens that start with `--app-`, with a dark set.
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
