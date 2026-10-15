# Contributing to Maru

Thanks for your interest. Maru is a small project with a fixed scope, so a short talk first saves your time.

## Start with an issue

- **A bug:** open a [bug report](https://github.com/ImHangLi/maru/issues/new?template=bug.yml).
- **An idea:** open a [feature request](https://github.com/ImHangLi/maru/issues/new?template=feature.yml).
- **A security problem:** report it privately. See [SECURITY.md](SECURITY.md).

Open an issue before you write code for a feature. [docs/spec.md](docs/spec.md) is the source of truth for scope. Some features are out of scope on purpose: inventory, accounts, cloud sync, AI chat, streaks, and ads.

## Build

You need Xcode 27 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
open Maru.xcodeproj
```

`Maru.xcodeproj` is generated. Change `project.yml`, then run `xcodegen generate` again.

Before you open a pull request, run the checks that CI runs:

```sh
swift test --package-path Packages/MaruKit
xcodebuild -project Maru.xcodeproj -scheme Maru -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## A good pull request

- Does one thing, and links its issue.
- Names the spec sections or acceptance IDs (`T01`–`T55`) that it covers.
- Says what changed, why, and how you checked it. Add screenshots for a UI change.
- Keeps tests few. Add a test only for a behavior that protects a record or an acceptance ID (D016 in [docs/decisions.md](docs/decisions.md)).
- Uses English in code, comments, commit messages, and docs. Product text goes in `App/Localizable.xcstrings`, with a translator comment and the five other languages (D059).

[AGENTS.md](AGENTS.md) has the code rules. They apply to people and coding agents alike. If you use an agent, read and test its work before you send it.

## License

Maru uses the [MIT license](LICENSE). Your contribution is under the same license.
