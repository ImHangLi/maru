# Market scan, October 2026

Date: 2026-10-10. Sources: Xiaohongshu posts, recent US App Store reviews (about 150 per app), Reddit, and X search results. The samples are small. Treat each point as an anecdote, not a general claim.

## Competitors

| App | Model | Users like | Users complain |
|---|---|---|---|
| [Medisafe](https://apps.apple.com/us/app/medisafe-medication-management/id573916946) | Subscription required from 2026-01-01 | Simple reminders, logged intake time | Paywall, bloat, a "For You" screen replaced the pillbox, 30-day history limit, re-reminds after "taken", time-zone bugs ([reviews](https://itunes.apple.com/us/rss/customerreviews/page=1/id=573916946/sortby=mostrecent/json)) |
| [MyTherapy](https://apps.apple.com/us/app/pill-reminder-mytherapy/id662170995) | Free, no ads | Logs the actual intake time | Wide feature set; no complaints in the sample |
| Apple Health Medications | Built in | Used for supplements ([XHS](https://www.xiaohongshu.com/explore/695abd92000000001e0145d5)) | Needs a recent iOS, confusing cycle settings, no widget ([r/iphone](https://www.reddit.com/r/iphone/comments/1u6dy5z/medication_reminders/)) |
| [Pillo](https://apps.apple.com/us/app/pillo-pill-reminder-tracker/id6736664288) | Free with ads | Reminds again until the dose is marked | Too many ads |

Supplement-specific apps are new and have few ratings. The "Stack" name is crowded: Stack, StackDay, StackLog, SupStack, NutriStack, VitaStack, Stackly.

## Pain points

1. Paywalls and forced accounts ([r/Epilepsy](https://www.reddit.com/r/Epilepsy/comments/1pepkpu/medisafe_requiring_subscription_a_now_alternatives/), [r/Supplements](https://www.reddit.com/r/Supplements/comments/1ryt7qg/built_a_free_ios_app_to_track_your_supplement/)).
2. Logging takes more effort than the habit itself ([XHS](https://www.xiaohongshu.com/explore/6ab799370000000002029feb)).
3. "Did I already take it?" ([r/Supplements](https://www.reddit.com/r/Supplements/comments/1to8ttk/how_are_you_tracking_what_you_actually_took_today/)). This thread may be promotional.
4. Reminders that do not arrive, or that do not stop.
5. No field for "with food" or "empty stomach". One user types it into the item name ([XHS](https://www.xiaohongshu.com/search_result/68663ceb0000000011002ca1)).
6. Complex schedules such as 21 days on and 7 days off.

## Effect on the spec

- Supported: free core, no account, local-only, simple flows.
- Candidate additions: a user-entered "with food / empty stomach" note, and a passive history heatmap with no streaks ([XHS](https://www.xiaohongshu.com/explore/69d25d10000000001a0290e8)).
- Open decision: an optional single follow-up reminder before confirmation. The spec default stays at one notification per time slot.
- No change: inventory has weak demand. Complex cycles stay out of V1.
