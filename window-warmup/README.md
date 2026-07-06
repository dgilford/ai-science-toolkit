# Window warmup

Anchors the 5-hour Claude usage window at ~5:00 / 10:00 / 15:00 ET on weekdays. Only a real
`claude -p` session anchors the rolling window — a claude.ai cloud routine spends tokens but
does not (single test, confirmed 2026-06-24; re-verify after major Claude Code or plan changes —
Anthropic can change session accounting without notice).

GitHub Actions **scheduled** cron proved too imprecise for this: observed `on: schedule:` fires
land 1.5–3h late (apparently a shared scheduling queue with no reserved capacity), and in an
earlier config with 4 staggered crons per anchor block, only 1 of 4 fired — consistent with
GitHub coalescing or dropping same-workflow crons. A 5am anchor that lands at 7:48am anchors the
wrong window. So this uses two independent tiers covering independent failure modes.

**Retired:** an earlier Tier 1 (macOS launchd, `WakeSystem=true`) waking the local Mac to run a
local ping was dropped 2026-07-06 — the always-on remote server tier below covers the same
"GitHub is down" failure mode without the sleep/wake unreliability (observed fires 25–90 min late
when the Mac was asleep at an anchor) or the "Mac off/away from power" gap. Tiers renumbered
accordingly (old Tier 2 → Tier 1, old Tier 3 → Tier 2).

## Tier 1 — GitHub workflow via external cron (the precise anchor)

`.github/workflows/window-warmup.yml` accepts `workflow_dispatch` (an immediate webhook, NOT
subject to the schedule-queue delay) and keeps a coarse `schedule:` backup. The precise trigger
is an external scheduler:

1. Create a fine-grained PAT (repo `dgilford/ai-tools` only, **Actions: Read and write**).
2. On [cron-job.org](https://cron-job.org) (free), create 3 jobs at 5:00 / 10:00 / 15:00 ET, each:
   - **Method** `POST`
   - **URL** `https://api.github.com/repos/dgilford/ai-tools/actions/workflows/window-warmup.yml/dispatches`
   - **Headers** `Authorization: Bearer <PAT>`, `Accept: application/vnd.github+json`
   - **Body** `{"ref":"main"}`

A ping inside an already-open window is a harmless no-op, so running both tiers is safe.

## Tier 2 — Remote server cron (independent redundancy)

An always-on remote server runs the same warmup ping via cron at 05:05 / 10:05 / 15:05 ET
(offset by 5 mins to distinguish Tier 2 from Tier 1, which fires at :00). It covers the case
where GitHub itself is down or the external scheduler (cron-job.org) fails to fire.

The Tier 2 script (`tier2-remote-heartbeat.sh`), deployment steps, and server details live in the
**private `talim-server` repo** (they carry the server's address/auth, so they stay out of this
public repo). A ping inside an already-open window is a harmless no-op, so running both tiers is safe.

## Health record & monthly check

GitHub retains Actions run history for ~90 days, and the monthly health check only ever needs
the current month — always well inside that window — so there's no separate durable log to
maintain. A monthly **cloud routine** (`warmup health check`) fires on the last day of each
month, reads the current month's `window-warmup.yml` runs straight from the GitHub Actions API
(`GET /repos/dgilford/ai-tools/actions/workflows/window-warmup.yml/runs`, unauthenticated —
the repo is public), and for each one checks `event` (`workflow_dispatch` vs the coarse
`schedule` backup), `created_at` (trigger time, compared to the nearest 05/10/15 ET anchor), and
`conclusion` (`success` covers both a real ping and an already-capped window; anything else is a
real failure). It alerts only on degradation: any weekday anchor missed, a `workflow_dispatch`
run >5 min from its anchor, or a non-success conclusion. See `.ai/routines.md` for the routine ID.
