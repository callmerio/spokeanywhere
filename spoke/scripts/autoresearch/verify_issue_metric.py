#!/usr/bin/env python3
import argparse
import json
import re
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]


def read_text(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8")


def contains_all(path: Path, patterns: list[str]) -> bool:
    content = read_text(path)
    return bool(content) and all(pattern in content for pattern in patterns)


def count_shared_calls(paths: list[Path]) -> int:
    total = 0
    for path in paths:
        total += len(re.findall(r"\.shared\b", read_text(path)))
    return total


def count_occurrences(path: Path, pattern: str) -> int:
    return len(re.findall(pattern, read_text(path)))


def load_status() -> dict[str, Any]:
    path = ROOT / "autoresearch" / "status" / "conditional-go-architecture.json"
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def bool_metric(checks: dict[str, bool], metric_name: str) -> dict[str, Any]:
    missing = [name for name, ok in checks.items() if not ok]
    return {
        "metric_name": metric_name,
        "metric": len(missing),
        "direction": "lower",
        "missing": missing,
        "checks": checks,
    }


def verify_ag010() -> dict[str, Any]:
    overview = ROOT / "docs" / "architecture" / "overview.md"
    quick_reference = ROOT / "docs" / "architecture" / "quick-reference.md"
    risks = ROOT / "docs" / "architecture" / "risks-and-recommendations.md"
    checklist = ROOT / "docs" / "architecture" / "maintenance-sync-checklist.md"
    boundaries = ROOT / "docs" / "architecture" / "history-boundaries.md"
    checks = {
        "current_state_linked_from_overview": contains_all(overview, ["./current-state-audit.md"]),
        "current_state_linked_from_quick_reference": contains_all(
            quick_reference, ["./current-state-audit.md"]
        ),
        "current_state_linked_from_risks": contains_all(risks, ["./current-state-audit.md"]),
        "maintenance_sync_checklist_exists": checklist.exists(),
        "history_boundaries_doc_exists": boundaries.exists(),
    }
    return bool_metric(checks, "remaining_fact_boundary_gaps")


def verify_qg010() -> dict[str, Any]:
    gate_doc = ROOT / "docs" / "roadmap" / "2026-03-conditional-go-architecture-roadmap.md"
    issue_csv = ROOT / "issues" / "2026-03-19_20-55-00-conditional-go-architecture.csv"
    current_audit = ROOT / "docs" / "architecture" / "current-state-audit.md"
    checks = {
        "roadmap_exists": gate_doc.exists(),
        "issues_csv_exists": issue_csv.exists(),
        "quality_commands_documented": contains_all(
            current_audit, ["swift test", "bash Tests/run-concurrency-check.sh"]
        ),
        "quality_gate_issue_present": contains_all(
            issue_csv, ["QG-010", "版本化质量门禁入口", "Tests/run-concurrency-check.sh"]
        ),
        "failure_categories_documented": contains_all(
            issue_csv, ["构建失败", "测试失败", "并发告警", "环境失败"]
        ),
    }
    return bool_metric(checks, "missing_quality_gate_contract_items")


def verify_app010() -> dict[str, Any]:
    contract = ROOT / "docs" / "architecture" / "service-lifecycle-contract.md"
    checks = {
        "service_lifecycle_contract_exists": contract.exists(),
        "contract_mentions_appdelegate": contains_all(contract, ["AppDelegate"]),
        "contract_mentions_recordingcontroller": contains_all(contract, ["RecordingController"]),
        "contract_mentions_selectiontoolbarmanager": contains_all(
            contract, ["SelectionToolbarManager"]
        ),
        "contract_mentions_resourcemonitor": contains_all(contract, ["ResourceMonitor"]),
        "contract_mentions_trackpadswipeservice": contains_all(
            contract, ["TrackpadSwipeService"]
        ),
    }
    return bool_metric(checks, "missing_lifecycle_contract_items")


def verify_app020() -> dict[str, Any]:
    inventory = ROOT / "docs" / "architecture" / "callback-cleanup-inventory.md"
    app_delegate = ROOT / "App" / "AppDelegate.swift"
    recording = ROOT / "Services" / "RecordingController.swift"
    add_count = count_occurrences(app_delegate, r"NotificationCenter\.default\.addObserver")
    remove_count = count_occurrences(app_delegate, r"NotificationCenter\.default\.removeObserver")
    checks = {
        "callback_cleanup_inventory_exists": inventory.exists(),
        "inventory_mentions_recordingcontroller": contains_all(
            inventory, ["RecordingController"]
        ),
        "inventory_mentions_appdelegate": contains_all(inventory, ["AppDelegate"]),
        "recordingcontroller_has_deinit_cleanup": "deinit" in read_text(recording),
        "appdelegate_observer_cleanup_balanced": remove_count >= add_count,
    }
    result = bool_metric(checks, "unmanaged_callback_hotspots")
    result["observer_add_count"] = add_count
    result["observer_remove_count"] = remove_count
    return result


def verify_arch010() -> dict[str, Any]:
    paths = [
        ROOT / "UI" / "Screenshot" / "ActionBarView.swift",
        ROOT / "UI" / "Screenshot" / "ScreenshotContentView+Actions.swift",
    ]
    metric = count_shared_calls(paths)
    return {
        "metric_name": "screenshot_ui_shared_calls",
        "metric": metric,
        "direction": "lower",
        "paths": [str(path.relative_to(ROOT)) for path in paths],
    }


def verify_arch020() -> dict[str, Any]:
    path = ROOT / "UI" / "MessagePanel" / "MessagePanelView.swift"
    metric = count_shared_calls([path])
    return {
        "metric_name": "message_panel_shared_calls",
        "metric": metric,
        "direction": "lower",
        "paths": [str(path.relative_to(ROOT))],
    }


def verify_arch030() -> dict[str, Any]:
    path = ROOT / "UI" / "HUD" / "QuickAskCapsuleView.swift"
    metric = count_shared_calls([path])
    return {
        "metric_name": "quickask_capsule_shared_calls",
        "metric": metric,
        "direction": "lower",
        "paths": [str(path.relative_to(ROOT))],
    }


def verify_gov010() -> dict[str, Any]:
    matrix = ROOT / "docs" / "architecture" / "dependency-channel-decision-matrix.md"
    quick_reference = ROOT / "docs" / "architecture" / "quick-reference.md"
    freeze_script = ROOT / "scripts" / "autoresearch" / "check_ui_shared_freeze.py"
    checks = {
        "decision_matrix_exists": matrix.exists(),
        "decision_matrix_mentions_all_channels": contains_all(
            matrix, ["direct call", "NotificationCenter", "ServiceContainer"]
        ),
        "ui_shared_freeze_checker_exists": freeze_script.exists(),
        "quick_reference_links_matrix": contains_all(
            quick_reference, ["dependency-channel-decision-matrix.md"]
        ),
    }
    return bool_metric(checks, "missing_governance_artifacts")


def verify_test010() -> dict[str, Any]:
    status = load_status()
    issues = status.get("issues", {})
    unresolved = []
    for issue_id, data in issues.items():
        if issue_id == "TEST-010":
            continue
        if data.get("state") != "completed":
            unresolved.append(issue_id)
    checks = {
        "all_previous_issues_completed": not unresolved,
        "final_review_doc_exists": (ROOT / "docs" / "roadmap" / "conditional-go-final-review.md").exists(),
    }
    result = bool_metric(checks, "remaining_conditional_go_blockers")
    result["unresolved_issues"] = unresolved
    return result


HANDLERS = {
    "AG-010": verify_ag010,
    "QG-010": verify_qg010,
    "APP-010": verify_app010,
    "APP-020": verify_app020,
    "ARCH-010": verify_arch010,
    "ARCH-020": verify_arch020,
    "ARCH-030": verify_arch030,
    "GOV-010": verify_gov010,
    "TEST-010": verify_test010,
}


def main() -> None:
    parser = argparse.ArgumentParser(description="Verify issue contract metric")
    parser.add_argument("--issue", required=True, help="Issue id")
    args = parser.parse_args()

    if args.issue not in HANDLERS:
        raise SystemExit(f"unsupported issue: {args.issue}")
    result = HANDLERS[args.issue]()
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
