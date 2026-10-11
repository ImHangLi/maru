# Security

## Report a vulnerability

Report it privately through [GitHub private vulnerability reporting](https://github.com/ImHangLi/maru/security/advisories/new). Do not open a public issue. You get a reply within a few days.

A useful report says what the problem is, how to reproduce it, and which version or commit you used. Do not include your own health data.

## Scope

Maru stores health records on the device and makes no network requests. Problems that matter most:

- A way to read Maru's data from outside the app, or while the iPhone is locked.
- A way to lose, double, or change a record without the user's action.
- A reminder that shows private content that the user did not choose to show.
