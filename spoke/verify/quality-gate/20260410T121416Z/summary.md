# Architecture Quality Gate

- status: passed
- mode: provider-neutral
- log_dir: /Users/bigdan/Workspace/macos/spokeanywhere/spoke/verify/quality-gate/20260410T121416Z
- hard_fail_checks:
  - swift build
  - swift test
  - bash Tests/run-concurrency-check.sh
- report_only_scans:
  - shared matches: 37
  - notification matches: 6

## Files

- build.log
- test.log
- concurrency.log
- shared-scan.log
- notification-scan.log
