#!/bin/bash
# Compare startup benchmark report against baseline thresholds.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

REPORT_PATH="${1:-docs/perf-startup-report.json}"
BASELINE_PATH="${2:-perf/baseline-startup.json}"

if [[ ! -f "$REPORT_PATH" ]]; then
  echo "ERROR: report file not found: $REPORT_PATH"
  exit 2
fi

if [[ ! -f "$BASELINE_PATH" ]]; then
  echo "ERROR: baseline file not found: $BASELINE_PATH"
  exit 2
fi

swift - "$REPORT_PATH" "$BASELINE_PATH" <<'SWIFT'
import Foundation

struct MetricSummary: Decodable {
    let samples: Int
    let p50: Double
    let p95: Double
    let max: Double
    let mean: Double
}

struct CaseReport: Decodable {
    let itemCount: Int
    let runs: Int
    let restoreCountAllMatch: Bool
    let launchTotalMs: MetricSummary
    let restoreDecodeMs: MetricSummary
    let restoreUiMs: MetricSummary
}

struct BenchmarkReport: Decodable {
    let runErrors: Int
    let cases: [CaseReport]
}

struct ThresholdRule: Decodable {
    let itemCount: Int
    let launchP95MaxMs: Double
    let restoreDecodeP95MaxMs: Double
    let restoreUiP95MaxMs: Double
    let requireRestoreCountMatch: Bool
}

struct Baseline: Decodable {
    let thresholds: [ThresholdRule]
}

let reportPath = CommandLine.arguments[1]
let baselinePath = CommandLine.arguments[2]

let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase

let reportData = try Data(contentsOf: URL(fileURLWithPath: reportPath))
let baselineData = try Data(contentsOf: URL(fileURLWithPath: baselinePath))

let report = try decoder.decode(BenchmarkReport.self, from: reportData)
let baseline = try decoder.decode(Baseline.self, from: baselineData)

var failures: [String] = []

if report.runErrors > 0 {
    failures.append("run_errors=\(report.runErrors) (benchmark execution was incomplete)")
}

let baselineMap = Dictionary(uniqueKeysWithValues: baseline.thresholds.map { ($0.itemCount, $0) })

for benchCase in report.cases {
    guard let rule = baselineMap[benchCase.itemCount] else {
        failures.append("missing baseline threshold for item_count=\(benchCase.itemCount)")
        continue
    }

    if benchCase.launchTotalMs.p95 > rule.launchP95MaxMs {
        failures.append("item_count=\(benchCase.itemCount) launch_total_ms.p95=\(benchCase.launchTotalMs.p95) > max=\(rule.launchP95MaxMs)")
    }
    if benchCase.restoreDecodeMs.p95 > rule.restoreDecodeP95MaxMs {
        failures.append("item_count=\(benchCase.itemCount) restore_decode_ms.p95=\(benchCase.restoreDecodeMs.p95) > max=\(rule.restoreDecodeP95MaxMs)")
    }
    if benchCase.restoreUiMs.p95 > rule.restoreUiP95MaxMs {
        failures.append("item_count=\(benchCase.itemCount) restore_ui_ms.p95=\(benchCase.restoreUiMs.p95) > max=\(rule.restoreUiP95MaxMs)")
    }
    if rule.requireRestoreCountMatch && !benchCase.restoreCountAllMatch {
        failures.append("item_count=\(benchCase.itemCount) restore_count_all_match=false")
    }
}

if failures.isEmpty {
    print("PASS: startup regression gate satisfied")
    exit(0)
}

print("FAIL: startup regression gate failed")
for failure in failures {
    print(" - \(failure)")
}
exit(1)
SWIFT
