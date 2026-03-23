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


def hotspot_metric(path: Path, metric_name: str, patterns: dict[str, str]) -> dict[str, Any]:
    counts = {name: count_occurrences(path, pattern) for name, pattern in patterns.items()}
    return {
        "metric_name": metric_name,
        "metric": sum(counts.values()),
        "direction": "lower",
        "path": str(path.relative_to(ROOT)),
        "counts": counts,
    }


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


def verify_orch_qa_030() -> dict[str, Any]:
    path = ROOT / "Services" / "QuickAskService.swift"
    return hotspot_metric(
        path,
        "quickask_runtime_hotspots",
        {
            "shared_calls": r"\.shared\b",
            "mainactor_tasks": r"Task \{",
            "activation_policy_calls": r"NSApp\.setActivationPolicy",
            "window_activation_calls": r"NSApp\.activate\(",
            "recording_timers": r"Timer\.scheduledTimer",
        },
    )


def verify_orch_app_030() -> dict[str, Any]:
    path = ROOT / "App" / "AppDelegate.swift"
    return hotspot_metric(
        path,
        "appdelegate_settings_hotspots",
        {
            "shared_calls": r"\.shared\b",
            "mainactor_tasks": r"Task \{",
            "settings_window_mentions": r"showSettingsWindow\(",
            "activation_policy_calls": r"NSApp\.setActivationPolicy",
            "window_activation_calls": r"NSApp\.activate\(",
        },
    )


def verify_orch_rec_030() -> dict[str, Any]:
    path = ROOT / "Services" / "RecordingController.swift"
    return hotspot_metric(
        path,
        "recording_postprocess_hotspots",
        {
            "shared_calls": r"\.shared\b",
            "mainactor_tasks": r"Task \{",
            "recording_timers": r"Timer\.scheduledTimer",
            "process_transcription_mentions": r"processTranscription\(",
            "llm_refine_calls": r"llmPipeline\.refine\(",
        },
    )


def verify_orch_metric_010() -> dict[str, Any]:
    round3_csv = ROOT / "issues" / "2026-03-22_04-46-21-orchestrator-hotspots-round-3.csv"
    checks = {
        "round3_csv_exists": round3_csv.exists(),
        "handler_orch_qa_exists": "ORCH-QA-030" in HANDLERS,
        "handler_orch_app_exists": "ORCH-APP-030" in HANDLERS,
        "handler_orch_rec_exists": "ORCH-REC-030" in HANDLERS,
    }
    return bool_metric(checks, "missing_round3_hotspot_metrics")


def verify_orch_sa_080() -> dict[str, Any]:
    path = ROOT / "Services" / "SelectionActionService.swift"
    return hotspot_metric(
        path,
        "selection_action_round8_hotspots",
        {
            "panel_execution_calls": r"executePanelLLMAction\(",
            "toolbar_anchor_captures": r"hideToolbarAndCaptureAnchor\(",
            "template_prompt_calls": r"buildPromptFromTemplate\(",
            "split_finish_paths": r"completeAction\(|failAction\(",
        },
    )


def verify_orch_ss_080() -> dict[str, Any]:
    path = ROOT / "UI" / "Screenshot" / "ScreenshotView.swift"
    return hotspot_metric(
        path,
        "screenshot_round8_hotspots",
        {
            "context_menu_button_mentions": r"contextMenuButton\(",
            "inline_menu_state_fragments": r"pinMenuTitle|pinMenuImage|lockMenuTitle|lockMenuImage",
            "window_sync_action_mentions": r"performItemAction\(",
            "ocr_detached_tasks": r"Task\.detached",
        },
    )


def verify_orch_st_080() -> dict[str, Any]:
    path = ROOT / "Services" / "SelectionToolbarManager.swift"
    return hotspot_metric(
        path,
        "selection_toolbar_round8_hotspots",
        {
            "inline_timer_invalidations": r"\?\.invalidate\(\)",
            "inline_mouse_frame_checks": r"windowFrame\.contains\(mouseLocation\)",
            "hide_guard_fragments": r"Date\(\) < showProtectionEndTime|isExecutingAction|state\.phase == \.showingDictionary",
            "dictionary_hover_restart_mentions": r"restartDictionaryHoverMonitoring\(",
        },
    )


def verify_orch_sm_090() -> dict[str, Any]:
    path = ROOT / "Services" / "SelectionMonitorService.swift"
    return hotspot_metric(
        path,
        "selection_monitor_round9_hotspots",
        {
            "shared_calls": r"\.shared\b",
            "mainactor_task_bridges": r"Task \{",
            "detached_ax_queries": r"Task\.detached",
            "inline_debounce_timers": r"Timer\.scheduledTimer",
            "toolbar_hit_testing": r"toolbarWindow\.frame\.contains\(",
        },
    )


def verify_orch_st_090() -> dict[str, Any]:
    path = ROOT / "Services" / "SelectionToolbarManager.swift"
    return hotspot_metric(
        path,
        "selection_toolbar_round9_hotspots",
        {
            "shared_calls": r"\.shared\b",
            "permission_polling_tasks": r"permissionPollingTask = Task \{",
            "selection_monitor_mentions": r"dependencies\.selectionMonitor\(\)",
            "open_settings_inline": r"dependencies\.openSystemSettings\(",
        },
    )


def verify_orch_wf_090() -> dict[str, Any]:
    path = ROOT / "Core" / "Workflow" / "WorkflowExecutor.swift"
    return hotspot_metric(
        path,
        "workflow_round9_hotspots",
        {
            "shared_calls": r"\.shared\b",
            "profile_lookup_mentions": r"profile\(matching: ",
            "preferred_profile_mentions": r"preferredProfileID\(",
            "copy_output_mentions": r"copyText\(",
        },
    )


def verify_orch_sa_100() -> dict[str, Any]:
    path = ROOT / "Services" / "SelectionActionLiveDependencies.swift"
    return hotspot_metric(
        path,
        "selection_action_live_dependency_file_hotspots",
        {
            "direct_service_shared_calls": (
                r"state: \.shared|ttsService: \.shared|screenOCR: \.shared|llmPipeline: \.shared|"
                r"dictionaryAPI: \.shared|answerPanelManager: \.shared|llmSettings: \.shared"
            ),
            "inline_async_after": r"DispatchQueue\.main\.asyncAfter",
            "inline_pasteboard_wiring": r"NSPasteboard\.general|pasteboard\.clearContents\(|pasteboard\.setString\(",
        },
    )


def verify_orch_sp_100() -> dict[str, Any]:
    path = ROOT / "Core" / "Transcription" / "Providers" / "SpeechAnalyzerProvider.swift"
    return hotspot_metric(
        path,
        "speech_analyzer_round10_hotspots",
        {
            "raw_task_calls": r"\bTask \{|\bTask\.detached",
            "mainactor_run_self_captures": r"MainActor\.run \{ \[weak self\]",
            "live_dependency_mentions": r"static let live = SpeechAnalyzerProviderDependencies",
        },
    )


def verify_orch_st_100() -> dict[str, Any]:
    path = ROOT / "Services" / "SelectionToolbarLiveDependencies.swift"
    return hotspot_metric(
        path,
        "selection_toolbar_live_dependency_file_hotspots",
        {
            "direct_service_shared_calls": r"state: \.shared|selectionMonitor: \{ \.shared \}|configService: \.shared",
            "workspace_open_inline": r"NSWorkspace\.shared\.open",
            "inline_workspace_capture": r"workspace: NSWorkspace = \.shared",
        },
    )


def verify_orch_sm_110() -> dict[str, Any]:
    path = ROOT / "Services" / "SelectionMonitorLiveDependencies.swift"
    return hotspot_metric(
        path,
        "selection_monitor_live_dependency_file_hotspots",
        {
            "direct_service_shared_calls": r"workspace: \.shared|selectionToolbarManager: \.shared",
            "toolbar_manager_inline_calls": r"SelectionToolbarManager\.shared",
        },
    )


def verify_orch_wf_110() -> dict[str, Any]:
    path = ROOT / "Core" / "Workflow" / "WorkflowExecutorLiveDependencies.swift"
    return hotspot_metric(
        path,
        "workflow_live_dependency_file_hotspots",
        {
            "direct_service_shared_calls": r"settings: \.shared|pipeline: \.shared|workflowConfigService: \.shared",
            "inline_general_pasteboard": r"pasteboard: \.general",
            "inline_current_locale": r"localeProvider: \{ \.current \}",
        },
    )


def verify_doc_arch_110() -> dict[str, Any]:
    current_state = ROOT / "docs" / "architecture" / "current-state-audit.md"
    overview = ROOT / "docs" / "architecture" / "overview.md"
    quick_reference = ROOT / "docs" / "architecture" / "quick-reference.md"
    risks = ROOT / "docs" / "architecture" / "risks-and-recommendations.md"
    checks = {
        "current_state_mentions_150_30": contains_all(current_state, ["150 tests / 30 suites"]),
        "overview_mentions_150_30": contains_all(overview, ["150 tests / 30 suites"]),
        "quick_reference_mentions_150_30": contains_all(quick_reference, ["150 tests / 30 suites"]),
        "risks_mentions_150_30": contains_all(risks, ["150 tests / 30 suites"]),
        "current_state_mentions_selection_monitor_round": contains_all(
            current_state, ["SelectionMonitorService", "SelectionMonitorRuntimeHelpers"]
        ),
        "overview_mentions_workflow_profile_resolver": contains_all(
            overview, ["WorkflowProfileResolver.swift"]
        ),
    }
    return bool_metric(checks, "architecture_doc_sync_gaps")


def verify_orch_sah_120() -> dict[str, Any]:
    path = ROOT / "Services" / "SelectionActionLiveHelpers.swift"
    return hotspot_metric(
        path,
        "selection_action_helper_sink_hotspots",
        {
            "direct_service_shared_calls": r"\.shared\b",
            "inline_async_after": r"DispatchQueue\.main\.asyncAfter",
            "inline_general_pasteboard": r"\.general\b",
        },
    )


def verify_orch_smh_120() -> dict[str, Any]:
    path = ROOT / "Services" / "SelectionMonitorLiveHelpers.swift"
    return hotspot_metric(
        path,
        "selection_monitor_helper_sink_hotspots",
        {
            "direct_service_shared_calls": r"\.shared\b",
            "toolbar_manager_singleton_calls": r"SelectionToolbarManager\.shared",
        },
    )


def verify_orch_wfh_120() -> dict[str, Any]:
    path = ROOT / "Core" / "Workflow" / "WorkflowExecutorLiveHelpers.swift"
    return hotspot_metric(
        path,
        "workflow_helper_sink_hotspots",
        {
            "direct_service_shared_calls": r"\.shared\b",
            "inline_general_pasteboard": r"\.general\b",
            "inline_current_locale": r"\.current\b",
        },
    )


def verify_orch_qal_130() -> dict[str, Any]:
    path = ROOT / "Services" / "QuickAskLiveDependencies.swift"
    return hotspot_metric(
        path,
        "quickask_live_factory_hotspots",
        {
            "direct_service_shared_calls": r"\.shared\b",
            "inline_send_action": r"NSApp\.sendAction",
            "inline_general_pasteboard": r"\.general\b",
        },
    )


def verify_orch_rcl_130() -> dict[str, Any]:
    path = ROOT / "Services" / "RecordingControllerLiveDependencies.swift"
    return hotspot_metric(
        path,
        "recording_live_factory_hotspots",
        {
            "direct_service_shared_calls": r"\.shared\b",
            "inline_send_action": r"NSApp\.sendAction",
            "inline_assertion_failure": r"assertionFailure\(",
            "inline_general_pasteboard": r"\.general\b",
        },
    )


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
    "ORCH-QA-030": verify_orch_qa_030,
    "ORCH-APP-030": verify_orch_app_030,
    "ORCH-REC-030": verify_orch_rec_030,
    "ORCH-METRIC-010": verify_orch_metric_010,
    "ORCH-SA-080": verify_orch_sa_080,
    "ORCH-SS-080": verify_orch_ss_080,
    "ORCH-ST-080": verify_orch_st_080,
    "ORCH-SM-090": verify_orch_sm_090,
    "ORCH-ST-090": verify_orch_st_090,
    "ORCH-WF-090": verify_orch_wf_090,
    "ORCH-SA-100": verify_orch_sa_100,
    "ORCH-SP-100": verify_orch_sp_100,
    "ORCH-ST-100": verify_orch_st_100,
    "ORCH-SM-110": verify_orch_sm_110,
    "ORCH-WF-110": verify_orch_wf_110,
    "DOC-ARCH-110": verify_doc_arch_110,
    "ORCH-SAH-120": verify_orch_sah_120,
    "ORCH-SMH-120": verify_orch_smh_120,
    "ORCH-WFH-120": verify_orch_wfh_120,
    "ORCH-QAL-130": verify_orch_qal_130,
    "ORCH-RCL-130": verify_orch_rcl_130,
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
