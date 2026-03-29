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


def hotspot_metric_paths(
    paths: list[Path], metric_name: str, patterns: dict[str, str]
) -> dict[str, Any]:
    counts = {
        name: sum(count_occurrences(path, pattern) for path in paths)
        for name, pattern in patterns.items()
    }
    return {
        "metric_name": metric_name,
        "metric": sum(counts.values()),
        "direction": "lower",
        "paths": [str(path.relative_to(ROOT)) for path in paths],
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


def verify_orch_sth_140() -> dict[str, Any]:
    path = ROOT / "Services" / "SelectionToolbarLiveHelpers.swift"
    return hotspot_metric(
        path,
        "selection_toolbar_helper_sink_hotspots",
        {
            "direct_service_shared_calls": r"\.shared\b",
            "inline_workspace_singletons": r"NSWorkspace\.shared|workspace: \.shared",
        },
    )


def verify_doc_state_140() -> dict[str, Any]:
    overview = ROOT / "docs" / "architecture" / "overview.md"
    current_state = ROOT / "docs" / "architecture" / "current-state-audit.md"
    risks = ROOT / "docs" / "architecture" / "risks-and-recommendations.md"
    checks = {
        "overview_mentions_live_factory_convergence": contains_all(
            overview, ["高风险 orchestrator 与 live factory 已完成多轮收敛"]
        ),
        "overview_mentions_quickask_recording_live_factories": contains_all(
            overview, ["QuickAskLiveDependencies.swift", "RecordingControllerLiveDependencies.swift"]
        ),
        "current_state_mentions_live_factory_convergence": contains_all(
            current_state, ["高频 orchestrator / live factory 已完成多轮收敛"]
        ),
        "risks_mentions_runtime_still_singleton_based": contains_all(
            risks, ["核心运行时仍建立在单例基础之上"]
        ),
    }
    return bool_metric(checks, "current_state_doc_gaps")


def verify_gov_sc_160() -> dict[str, Any]:
    path = ROOT / "Services" / "ServiceContainer.swift"
    return hotspot_metric(
        path,
        "service_container_file_hotspots",
        {
            "direct_service_shared_calls": r"AudioRecorderService\.shared|TranscriptionManager\.shared|LLMPipeline\.shared|AppSettings\.shared|HistoryManager\.shared|QuickAskService\.shared|SelectionToolbarManager\.shared",
            "inline_live_defaults_block": r"static let live = ServiceContainerDependencies\(",
        },
    )


def verify_doc_mod_160() -> dict[str, Any]:
    core_modules = ROOT / "docs" / "architecture" / "core-modules.md"
    ui_components = ROOT / "docs" / "architecture" / "ui-components.md"
    checks = {
        "core_modules_updated_date": contains_all(core_modules, ["**更新时间**: 2026-03-23"]),
        "ui_components_updated_date": contains_all(ui_components, ["**更新时间**: 2026-03-23"]),
        "core_modules_mentions_live_factory_convergence": contains_all(
            core_modules, ["高风险 orchestrator 与 live factory 已完成多轮收敛"]
        ),
        "ui_components_mentions_ui_direct_access_is_partial": contains_all(
            ui_components, ["仍保留若干直接访问 `*.shared` 的高频入口"]
        ),
    }
    return bool_metric(checks, "module_doc_sync_gaps")


def verify_gov_rb_170() -> dict[str, Any]:
    paths = [
        ROOT / "Services" / "QuickAskRuntimeHelpers.swift",
        ROOT / "Services" / "SelectionActionRuntimeHelpers.swift",
        ROOT / "Services" / "SelectionToolbarRuntimeHelpers.swift",
        ROOT / "Services" / "RecordingControllerRuntimeHelpers.swift",
        ROOT / "Services" / "SelectionMonitorRuntimeHelpers.swift",
    ]
    return hotspot_metric_paths(
        paths,
        "runtime_bridge_helper_duplication_hotspots",
        {
            "raw_task_calls": r"\bTask \{|\bTask\.detached",
            "raw_timer_calls": r"Timer\.scheduledTimer",
            "raw_mainactor_run_calls": r"MainActor\.run",
            "raw_sleep_calls": r"Task\.sleep",
        },
    )


def verify_doc_arch_170() -> dict[str, Any]:
    overview = ROOT / "docs" / "architecture" / "overview.md"
    current_state = ROOT / "docs" / "architecture" / "current-state-audit.md"
    quick_reference = ROOT / "docs" / "architecture" / "quick-reference.md"
    risks = ROOT / "docs" / "architecture" / "risks-and-recommendations.md"
    checks = {
        "overview_updated_date": contains_all(overview, ["**更新时间**: 2026-03-23"]),
        "current_state_updated_date": contains_all(current_state, ["**审计日期**: 2026-03-23"]),
        "quick_reference_updated_date": contains_all(
            quick_reference, ["**更新时间**: 2026-03-23"]
        ),
        "risks_updated_date": contains_all(risks, ["**更新时间**: 2026-03-23"]),
        "quick_reference_mentions_runtime_bridge_helpers": contains_all(
            quick_reference, ["RuntimeBridgeHelpers.swift"]
        ),
        "overview_mentions_service_container_live_defaults": contains_all(
            overview, ["ServiceContainerLiveDependencies.swift"]
        ),
        "current_state_mentions_memory_unavailable": contains_all(
            current_state, ["Memgraph 服务不可用"]
        ),
        "risks_mentions_runtime_bridge_helpers": contains_all(
            risks, ["RuntimeBridgeHelpers.swift"]
        ),
    }
    return bool_metric(checks, "architecture_round17_sync_gaps")


def verify_ui_preview_180() -> dict[str, Any]:
    paths = [
        ROOT / "UI" / "MessagePanel" / "MessagePanelView.swift",
        ROOT / "UI" / "LiveCaption" / "LiveCaptionView.swift",
        ROOT / "UI" / "HUD" / "QuickAskCapsuleView.swift",
    ]
    return hotspot_metric_paths(
        paths,
        "ui_preview_shared_hotspots",
        {
            "shared_calls": r"\.shared\b",
            "default_notification_center_calls": r"NotificationCenter\.default",
        },
    )


def verify_ui_livecaption_190() -> dict[str, Any]:
    path = ROOT / "UI" / "LiveCaption" / "LiveCaptionView.swift"
    checks = {
        "raw_async_after_removed": count_occurrences(path, r"DispatchQueue\.main\.asyncAfter") == 0,
        "inline_scroll_guard_removed": count_occurrences(
            path, r"if isAtBottom && !isUserSelecting"
        ) == 0,
        "runtime_helper_exists": (ROOT / "UI" / "LiveCaption" / "LiveCaptionRuntimeHelpers.swift").exists(),
    }
    return bool_metric(checks, "livecaption_runtime_tail_gaps")


def verify_messagepanel_200() -> dict[str, Any]:
    manager = ROOT / "Services" / "MessagePanelManager.swift"
    state = ROOT / "Core" / "MessagePanel" / "MessagePanelState.swift"
    checks = {
        "manager_raw_mainactor_tasks_removed": count_occurrences(
            manager, r"Task \{ @MainActor"
        ) == 0,
        "manager_summary_task_wrapped": count_occurrences(
            manager, r"Task \{ await summaryService"
        ) == 0,
        "state_summary_shared_removed": count_occurrences(
            state, r"SummaryService\.shared"
        ) == 0,
        "runtime_helper_exists": (ROOT / "Services" / "MessagePanelRuntimeHelpers.swift").exists(),
    }
    return bool_metric(checks, "messagepanel_cluster_gaps")


def verify_screenshot_210() -> dict[str, Any]:
    path = ROOT / "UI" / "Screenshot" / "ScreenshotContentView.swift"
    checks = {
        "raw_async_after_removed": count_occurrences(
            path, r"DispatchQueue\.main\.asyncAfter"
        ) == 0,
        "runtime_helper_exists": (
            ROOT / "UI" / "Screenshot" / "ScreenshotContentRuntimeHelpers.swift"
        ).exists(),
        "direct_runtime_task_count_reduced": count_occurrences(path, r"\bTask \{") <= 3,
    }
    return bool_metric(checks, "screenshot_runtime_tail_gaps")


def verify_attach_audio_220() -> dict[str, Any]:
    attachment = ROOT / "Core" / "Attachment" / "AttachmentManager.swift"
    checks = {
        "attachment_raw_task_reduced": count_occurrences(attachment, r"\bTask \{|\bTask\.detached") <= 2,
        "attachment_default_notification_removed": count_occurrences(
            attachment, r"NotificationCenter\.default"
        ) == 0,
        "attachment_runtime_helper_exists": (
            ROOT / "Core" / "Attachment" / "AttachmentRuntimeHelpers.swift"
        ).exists(),
    }
    return bool_metric(checks, "attachment_audio_cluster_gaps")


def verify_audio_230() -> dict[str, Any]:
    path = ROOT / "Core" / "Audio" / "AudioRecorderService.swift"
    checks = {
        "config_observer_raw_notification_removed": count_occurrences(
            path, r"NotificationCenter\.default\.addObserver"
        ) == 0,
        "config_debounce_raw_task_removed": count_occurrences(
            path, r"Task \{ @MainActor in\s*try\? await Task\.sleep\(for: \.milliseconds\(500\)\)"
        ) == 0,
        "provider_callback_raw_tasks_removed": count_occurrences(
            path, r"provider\.onResult = \{ \[weak self\] result in\s*Task \{ @MainActor in|provider\.onError = \{ \[weak self\] error in\s*Task \{ @MainActor in"
        ) == 0,
        "audio_runtime_helper_exists": (
            ROOT / "Core" / "Audio" / "AudioRecorderRuntimeHelpers.swift"
        ).exists(),
    }
    return bool_metric(checks, "audio_runtime_cluster_gaps")


def verify_livecaption_240() -> dict[str, Any]:
    path = ROOT / "Core" / "LiveCaption" / "LiveCaptionManager.swift"
    checks = {
        "app_picker_raw_mainactor_tasks_removed": count_occurrences(
            path, r"appCapture\.onSelectionComplete = \{ \[weak self\] success in\s+guard let self = self, success else \{ return \}\s+Task \{ @MainActor in|appCapture\.onSelectionCancelled = \{ \[weak self\] in\s+Task \{ @MainActor in|appCapture\.onRetryStateChanged = \{ \[weak self\] isRetrying, retryCount in\s+Task \{ @MainActor in|appCapture\.onError = \{ \[weak self\] error in\s+Task \{ @MainActor in"
        ) == 0,
        "legacy_capture_raw_mainactor_tasks_removed": count_occurrences(
            path, r"transcriber\.onTranscription = \{ \[weak self\] segment in\s+Task \{ @MainActor in|capture\.onError = \{ \[weak self\] error in\s+guard let self = self else \{ return \}\s+self\.logger\.error.*Task \{ @MainActor in"
        ) == 0,
        "volatile_translation_raw_task_removed": count_occurrences(
            path, r"volatileTranslationTask = Task \{"
        ) == 0,
        "runtime_helper_exists": (
            ROOT / "Core" / "LiveCaption" / "LiveCaptionManagerRuntimeHelpers.swift"
        ).exists(),
    }
    return bool_metric(checks, "livecaption_manager_cluster_gaps")


def verify_orch_qas_150() -> dict[str, Any]:
    path = ROOT / "Services" / "QuickAskService.swift"
    return hotspot_metric(
        path,
        "quickask_runtime_tail_hotspots",
        {
            "raw_task_calls": r"\bTask \{|\bTask\.detached",
            "raw_timer_calls": r"Timer\.scheduledTimer",
            "raw_async_after": r"DispatchQueue\.main\.asyncAfter",
        },
    )


def verify_orch_sas_150() -> dict[str, Any]:
    path = ROOT / "Services" / "SelectionActionService.swift"
    return hotspot_metric(
        path,
        "selection_action_runtime_tail_hotspots",
        {
            "raw_task_calls": r"\bTask \{|\bTask\.detached",
            "raw_timer_calls": r"Timer\.scheduledTimer",
            "raw_async_after": r"DispatchQueue\.main\.asyncAfter",
        },
    )


def verify_shothelp_1600() -> dict[str, Any]:
    path = ROOT / "UI" / "Screenshot" / "ScreenshotContentRuntimeHelpers.swift"
    return hotspot_metric(
        path,
        "screenshot_runtime_helper_hotspots",
        {
            "raw_task_calls": r"\bTask \{|\bTask\.detached",
        },
    )


def verify_screenocr_1600() -> dict[str, Any]:
    path = ROOT / "Services" / "ScreenOCRServiceRuntimeHelpers.swift"
    return hotspot_metric(
        path,
        "screenocr_runtime_helper_hotspots",
        {
            "raw_task_calls": r"\bTask \{|\bTask\.detached",
        },
    )


def verify_spanhelp_1600() -> dict[str, Any]:
    path = ROOT / "Core" / "Transcription" / "Providers" / "SpeechAnalyzerProviderRuntimeHelpers.swift"
    return hotspot_metric(
        path,
        "speech_analyzer_runtime_helper_hotspots",
        {
            "raw_task_calls": r"\bTask \{|\bTask\.detached",
        },
    )


def verify_dicthelp_1700() -> dict[str, Any]:
    path = ROOT / "UI" / "Dictionary" / "DictionaryPanelRuntimeHelpers.swift"
    return hotspot_metric(
        path,
        "dictionary_panel_runtime_helper_hotspots",
        {
            "raw_task_calls": r"\bTask \{|\bTask\.detached",
        },
    )


def verify_ttshelp_1700() -> dict[str, Any]:
    path = ROOT / "Services" / "TTSServiceRuntimeHelpers.swift"
    return hotspot_metric(
        path,
        "tts_runtime_helper_hotspots",
        {
            "raw_task_calls": r"\bTask \{|\bTask\.detached",
        },
    )


def verify_inputhelp_1700() -> dict[str, Any]:
    path = ROOT / "Services" / "InputServiceRuntimeHelpers.swift"
    return hotspot_metric(
        path,
        "input_runtime_helper_hotspots",
        {
            "raw_task_calls": r"\bTask \{|\bTask\.detached",
        },
    )


def verify_toolbarhelp_1700() -> dict[str, Any]:
    path = ROOT / "Services" / "ToolbarConfigServiceRuntimeHelpers.swift"
    return hotspot_metric(
        path,
        "toolbar_config_runtime_helper_hotspots",
        {
            "raw_task_calls": r"\bTask \{|\bTask\.detached",
        },
    )


def verify_qacapsule_1800() -> dict[str, Any]:
    path = ROOT / "UI" / "HUD" / "QuickAskCapsuleView.swift"
    return hotspot_metric(
        path,
        "quickask_capsule_runtime_tail_hotspots",
        {
            "raw_task_calls": r"\bTask \{|\bTask\.detached",
            "raw_async_after": r"DispatchQueue\.main\.asyncAfter",
        },
    )


def verify_attachthumb_1800() -> dict[str, Any]:
    path = ROOT / "UI" / "Components" / "AttachmentThumbnailView.swift"
    return hotspot_metric(
        path,
        "attachment_thumbnail_view_hotspots",
        {
            "raw_task_calls": r"\bTask \{|\bTask\.detached",
            "direct_shared_calls": r"\.shared\b",
        },
    )


def verify_livetoolbar_1800() -> dict[str, Any]:
    path = ROOT / "UI" / "LiveCaption" / "LiveCaptionToolbar.swift"
    return hotspot_metric(
        path,
        "live_caption_toolbar_hotspots",
        {
            "raw_task_calls": r"\bTask \{|\bTask\.detached",
        },
    )


def verify_hotkeyreg_1800() -> dict[str, Any]:
    path = ROOT / "Services" / "HotKey" / "HotKeyRegistry.swift"
    return hotspot_metric(
        path,
        "hotkey_registry_hotspots",
        {
            "raw_task_calls": r"\bTask \{|\bTask\.detached",
        },
    )


def verify_msgbubble_1800() -> dict[str, Any]:
    path = ROOT / "UI" / "QuickAsk" / "MessageBubbleView.swift"
    return hotspot_metric(
        path,
        "message_bubble_view_hotspots",
        {
            "raw_async_after": r"DispatchQueue\.main\.asyncAfter",
            "direct_shared_calls": r"\.shared\b",
        },
    )


def verify_livecaphelp_1900() -> dict[str, Any]:
    path = ROOT / "UI" / "LiveCaption" / "LiveCaptionRuntimeHelpers.swift"
    return hotspot_metric(
        path,
        "live_caption_runtime_helper_hotspots",
        {
            "raw_task_calls": r"\bTask \{|\bTask\.detached",
        },
    )


def verify_histhelp_1900() -> dict[str, Any]:
    path = ROOT / "Services" / "HistoryManagerRuntimeHelpers.swift"
    return hotspot_metric(
        path,
        "history_runtime_helper_hotspots",
        {
            "raw_task_calls": r"\bTask \{|\bTask\.detached",
        },
    )


def verify_shotmgrhelp_1900() -> dict[str, Any]:
    path = ROOT / "Core" / "Screenshot" / "ScreenshotManagerRuntimeHelpers.swift"
    return hotspot_metric(
        path,
        "screenshot_manager_runtime_helper_hotspots",
        {
            "raw_task_calls": r"\bTask \{|\bTask\.detached",
        },
    )


def verify_aisethelp_1900() -> dict[str, Any]:
    path = ROOT / "UI" / "Settings" / "AISettingsContentRuntimeHelpers.swift"
    return hotspot_metric(
        path,
        "ai_settings_content_runtime_helper_hotspots",
        {
            "raw_task_calls": r"\bTask \{|\bTask\.detached",
        },
    )


def verify_aicomphelp_1900() -> dict[str, Any]:
    path = ROOT / "UI" / "Settings" / "AISettingsComponentsRuntimeHelpers.swift"
    return hotspot_metric(
        path,
        "ai_settings_components_runtime_helper_hotspots",
        {
            "raw_task_calls": r"\bTask \{|\bTask\.detached",
        },
    )


def verify_ansinput_2000() -> dict[str, Any]:
    path = ROOT / "UI" / "QuickAsk" / "AnswerPanelView+Input.swift"
    return hotspot_metric(
        path,
        "answer_panel_input_hotspots",
        {
            "shared_calls": r"\.shared\b",
        },
    )


def verify_workflowstate_2000() -> dict[str, Any]:
    path = ROOT / "Core" / "Workflow" / "WorkflowState.swift"
    return hotspot_metric(
        path,
        "workflow_state_hotspots",
        {
            "shared_calls": r"\.shared\b",
        },
    )


def verify_tagbubble_2000() -> dict[str, Any]:
    path = ROOT / "UI" / "Components" / "TagBubbleView.swift"
    return hotspot_metric(
        path,
        "tag_bubble_hotspots",
        {
            "shared_calls": r"\.shared\b",
        },
    )


def verify_postproc_2000() -> dict[str, Any]:
    path = ROOT / "Core" / "Transcription" / "TranscriptionPostProcessor.swift"
    return hotspot_metric(
        path,
        "transcription_post_processor_hotspots",
        {
            "shared_calls": r"\.shared\b",
        },
    )


def verify_ansmgr_2100() -> dict[str, Any]:
    path = ROOT / "UI" / "QuickAsk" / "AnswerPanelManager.swift"
    return hotspot_metric(
        path,
        "answer_panel_manager_hotspots",
        {
            "shared_calls": r"\.shared\b",
            "default_notifications": r"NotificationCenter\.default",
        },
    )


def verify_selstate_2100() -> dict[str, Any]:
    path = ROOT / "Core" / "SelectionToolbar" / "SelectionToolbarState.swift"
    return hotspot_metric(
        path,
        "selection_toolbar_state_hotspots",
        {
            "shared_calls": r"\.shared\b",
        },
    )


def verify_msgsrc_2100() -> dict[str, Any]:
    path = ROOT / "Core" / "MessagePanel" / "MessagePanelSourceAppHelpers.swift"
    return hotspot_metric(
        path,
        "message_panel_source_app_hotspots",
        {
            "workspace_shared_calls": r"NSWorkspace\.shared",
        },
    )


def verify_context_2100() -> dict[str, Any]:
    path = ROOT / "Services" / "ContextService.swift"
    return hotspot_metric(
        path,
        "context_service_hotspots",
        {
            "workspace_shared_calls": r"NSWorkspace\.shared",
            "default_shared_calls": r"\.shared\b",
        },
    )


def verify_dicttext_2200() -> dict[str, Any]:
    path = ROOT / "UI" / "Components" / "DictionarySelectableText.swift"
    return hotspot_metric(
        path,
        "dictionary_selectable_text_hotspots",
        {
            "default_notifications": r"NotificationCenter\.default",
        },
    )


def verify_tmodel_2200() -> dict[str, Any]:
    path = ROOT / "Core" / "Transcription" / "Models" / "TranscriptionModelManager.swift"
    return hotspot_metric(
        path,
        "transcription_model_manager_hotspots",
        {
            "default_notifications": r"NotificationCenter\.default",
        },
    )


def verify_qasvc_2200() -> dict[str, Any]:
    path = ROOT / "Services" / "QuickAskService.swift"
    return hotspot_metric(
        path,
        "quickask_service_tail_hotspots",
        {
            "shared_calls": r"\.shared\b",
            "raw_task": r"\bTask\s*\{",
        },
    )


def verify_screencap_2300() -> dict[str, Any]:
    path = ROOT / "Core" / "Attachment" / "ScreenCaptureService.swift"
    return hotspot_metric(
        path,
        "screen_capture_service_hotspots",
        {
            "workspace_shared_calls": r"NSWorkspace\.shared",
            "shared_calls": r"\.shared\b",
        },
    )


def verify_appaudio_2300() -> dict[str, Any]:
    path = ROOT / "Core" / "LiveCaption" / "AppAudioCaptureService.swift"
    return hotspot_metric(
        path,
        "app_audio_capture_service_hotspots",
        {
            "shared_calls": r"\.shared\b",
        },
    )


def verify_mdparser_2300() -> dict[str, Any]:
    path = ROOT / "UI" / "Components" / "SimpleMarkdownParser.swift"
    return hotspot_metric(
        path,
        "simple_markdown_parser_hotspots",
        {
            "font_manager_shared_calls": r"NSFontManager\.shared",
            "shared_calls": r"\.shared\b",
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
    "ORCH-STH-140": verify_orch_sth_140,
    "DOC-STATE-140": verify_doc_state_140,
    "ORCH-QAS-150": verify_orch_qas_150,
    "ORCH-SAS-150": verify_orch_sas_150,
    "SHOTHELP-1600": verify_shothelp_1600,
    "SCREENOCR-1600": verify_screenocr_1600,
    "SPANHELP-1600": verify_spanhelp_1600,
    "DICTHELP-1700": verify_dicthelp_1700,
    "TTSHELP-1700": verify_ttshelp_1700,
    "INPUTHELP-1700": verify_inputhelp_1700,
    "TOOLBARHELP-1700": verify_toolbarhelp_1700,
    "QACAPSULE-1800": verify_qacapsule_1800,
    "ATTACHTHUMB-1800": verify_attachthumb_1800,
    "LIVETOOLBAR-1800": verify_livetoolbar_1800,
    "HOTKEYREG-1800": verify_hotkeyreg_1800,
    "MSGBUBBLE-1800": verify_msgbubble_1800,
    "LIVECAPHELP-1900": verify_livecaphelp_1900,
    "HISTHELP-1900": verify_histhelp_1900,
    "SHOTMGRHELP-1900": verify_shotmgrhelp_1900,
    "AISETHELP-1900": verify_aisethelp_1900,
    "AICOMPHELP-1900": verify_aicomphelp_1900,
    "ANSINPUT-2000": verify_ansinput_2000,
    "WORKFLOWSTATE-2000": verify_workflowstate_2000,
    "TAGBUBBLE-2000": verify_tagbubble_2000,
    "POSTPROC-2000": verify_postproc_2000,
    "ANSMGR-2100": verify_ansmgr_2100,
    "SELSTATE-2100": verify_selstate_2100,
    "MSGSRC-2100": verify_msgsrc_2100,
    "CONTEXT-2100": verify_context_2100,
    "DICTTEXT-2200": verify_dicttext_2200,
    "TMODEL-2200": verify_tmodel_2200,
    "QASVC-2200": verify_qasvc_2200,
    "SCREENCAP-2300": verify_screencap_2300,
    "APPAUDIO-2300": verify_appaudio_2300,
    "MDPARSER-2300": verify_mdparser_2300,
    "GOV-SC-160": verify_gov_sc_160,
    "DOC-MOD-160": verify_doc_mod_160,
    "GOV-RB-170": verify_gov_rb_170,
    "DOC-ARCH-170": verify_doc_arch_170,
    "UI-PREVIEW-180": verify_ui_preview_180,
    "UI-LIVECAP-190": verify_ui_livecaption_190,
    "MSGPANEL-200": verify_messagepanel_200,
    "SCREENSHOT-210": verify_screenshot_210,
    "ATTACH-AUDIO-220": verify_attach_audio_220,
    "AUDIO-230": verify_audio_230,
    "LIVECAP-240": verify_livecaption_240,
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
