# Window warmup

Anchors the 5-hour Claude usage window at ~5:00 / 10:00 / 15:00 ET on weekdays. Only a real
`claude -p` session anchors the rolling window — a claude.ai cloud routine spends a token but
does not (confirmed 2026-06-24).

GitHub Actions **scheduled** cron proved structurally unreliable for this: `on: schedule:` runs
share one global queue with no reserved capacity, so they fire 2–3h late and are silently
dropped under load. A 5am anchor that lands at 7:48am anchors the wrong window. So this uses two
independent tiers covering independent failure modes.

## Tier 1 — macOS launchd (local redundancy, best-effort timing)

A LaunchAgent with `WakeSystem=true` is *meant* to wake the sleeping Mac and run `warmup.sh`
locally at the scheduled times. Free, no third party, no cloud token, no sudo. **Caveat (observed
2026-06-29):** macOS coalesces `WakeSystem` events and arms only **one** RTC wake at a time
(`pmset -g sched` shows a single repeating wake, not three/day), so anchors that fall while the
Mac is asleep are deferred to the next natural wake and fire late (e.g. 5:00→6:25, 10:00→10:29).
It also fails outright if the Mac is powered off / away from power. Tier 2 is the precise tier;
treat Tier 1 as best-effort redundancy.

```sh
bash window-warmup/install.sh
# test immediately:
launchctl kickstart -k gui/$(id -u)/com.dgilford.window-warmup && sleep 5 && tail -n 5 ~/.claude/window-warmup.log
# confirm wake events registered:
pmset -g sched
```

`WakeSystem` alone is occasionally unreliable on modern macOS, so guarantee the 5am
wake-from-sleep with an explicit RTC wake (needs sudo, one-time):

```sh
sudo pmset repeat wake MTWRF 04:58:00   # wakes the Mac at 4:58; launchd fires at 5:00
```

Files: `warmup.sh` (the ping; `unset ANTHROPIC_API_KEY` to guarantee subscription billing),
`com.dgilford.window-warmup.plist.template` (LaunchAgent; weekdays × 5/10/15:00), `install.sh`.
Deployed to `~/.claude/window-warmup/` and `~/Library/LaunchAgents/`; log at
`~/.claude/window-warmup.log`.

## Tier 2 — GitHub workflow via external cron (fallback)

Covers the Mac-off/traveling case. `.github/workflows/window-warmup.yml` accepts
`workflow_dispatch` (an immediate webhook, NOT subject to the schedule-queue delay) and keeps a
coarse `schedule:` backup. The precise trigger is an external scheduler:

1. Create a fine-grained PAT (repo `dgilford/ai-tools` only, **Actions: Read and write**).
2. On [cron-job.org](https://cron-job.org) (free), create 3 jobs at 5:00 / 10:00 / 15:00 ET, each:
   - **Method** `POST`
   - **URL** `https://api.github.com/repos/dgilford/ai-tools/actions/workflows/window-warmup.yml/dispatches`
   - **Headers** `Authorization: Bearer <PAT>`, `Accept: application/vnd.github+json`
   - **Body** `{"ref":"main"}`

A ping inside an already-open window is a harmless no-op, so running both tiers is safe.

## Tier 3 — Remote server cron (independent redundancy)

An always-on remote server runs the same warmup ping via cron at 05:05 / 10:05 / 15:05 ET
(offset by 5 mins to help identify which tier anchored). It covers the case where both the local
Mac and GitHub are down, and is intended to **supersede Tier 1** once validated.

The Tier 3 script (`tier3-remote-heartbeat.sh`), deployment steps, and server details live in the
**private `talim-server` repo** (they carry the server's address/auth, so they stay out of this
public repo). A ping inside an already-open window is a harmless no-op, so running all tiers is safe.

## Health record & monthly check

GitHub retains Actions run history only ~90 days, and Tier 2 is the tier that actually anchors
the window — so the workflow keeps its own durable record. The `Record Tier-2 heartbeat` step
(runs `if: always()`) appends one line per fire to `heartbeat.log` on the orphan
**`warmup-heartbeat`** branch (kept off `main` to avoid polluting history):

```
2026-06-29T10:01:02-0400 trig=workflow_dispatch run=28377672699 late=1m ping=success
```

`late` is minutes from the nearest ET anchor (05/10/15:00): negative=early, positive=late;
`trig` distinguishes the precise `workflow_dispatch` from the coarse `schedule` backup. Read it
raw at `https://raw.githubusercontent.com/dgilford/ai-tools/warmup-heartbeat/heartbeat.log`.

A monthly **cloud routine** (`warmup health check`) fires on the last day of each month, scans
this log + the month's run history, and alerts only on degradation (any anchor missed, or a
`workflow_dispatch` fire >5 min late). See `.ai/routines.md` for the routine ID.
