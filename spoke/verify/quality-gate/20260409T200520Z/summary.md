# Architecture Quality Gate

- status: passed
- mode: provider-neutral
- log_dir: /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere-ar-v3-20260410-030315/spoke/verify/quality-gate/20260409T200520Z
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
