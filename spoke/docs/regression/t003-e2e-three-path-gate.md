# T003 E2E Three-Path Gate

This gate validates the three critical paths in one pass:

- Recording: start + stop completion logs
- Live Caption: show + hide state logs
- Screenshot: trigger + created/complete logs

The gate wraps `r2-3-debug-automation-suite.sh` and enforces T003 thresholds.

## Command

```bash
cd spoke
RUNS=10 ./scripts/regression/t003-e2e-three-path-gate.sh
```

Optional flags:

- `AUTO_START_APP=1` to auto-launch `.build/bundler/SpokenAnyWhere.app`
- `SUCCESS_RATE_THRESHOLD` (default `90`)
- `MAX_AVG_DURATION_S` (default `300`)
- `OUTPUT_DIR` (default `/tmp/spoke-t003-e2e-gate`)

## Output

The script prints and writes `SUMMARY.txt` under:

- `/tmp/spoke-t003-e2e-gate/<timestamp>/SUMMARY.txt`

Key fields:

- `window_start/window_end`
- `pid`
- `git_head`
- `path_status`
- `final_status`
- `success_rate` and threshold
- `avg_duration_s` and threshold

## Pass Criteria

- `final_status=PASS`
- `success_gate=PASS` (`success_rate >= 90`)
- `duration_gate=PASS` (`avg_duration_s <= 300`)
- `coverage_gate=PASS` (three paths all have PASS evidence)

