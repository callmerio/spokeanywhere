#!/usr/bin/env python3
import argparse
import csv
import json
from pathlib import Path
from typing import Any, Optional


def load_csv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def find_issue(rows: list[dict[str, str]], issue_id: str) -> dict[str, str]:
    for row in rows:
        if row.get("id") == issue_id:
            return row
    raise SystemExit(f"issue not found: {issue_id}")


def parse_refs(refs: str) -> list[str]:
    paths: list[str] = []
    for part in refs.split(";"):
        part = part.strip()
        if not part:
            continue
        if ":" in part:
            paths.append(part.split(":", 1)[0])
        else:
            paths.append(part)
    deduped: list[str] = []
    for path in paths:
        if path not in deduped:
            deduped.append(path)
    return deduped


def infer_scope(paths: list[str]) -> list[str]:
    if not paths:
        return []
    if len(paths) <= 4:
        return paths
    return paths[:4]


def infer_goal(issue: dict[str, str]) -> str:
    title = issue.get("title", "").strip()
    description = issue.get("description", "").strip()
    if description:
        return f"{title}：{description}"
    return title


def infer_guard(issue: dict[str, str]) -> list[str]:
    guard: list[str] = []
    text = " ".join(
        [
            issue.get("acceptance_criteria", ""),
            issue.get("test_steps", ""),
            issue.get("review_regression_requirements", ""),
        ]
    )
    if "swift test" in text:
        guard.append("swift test")
    if "run-concurrency-check.sh" in text:
        guard.append("bash Tests/run-concurrency-check.sh")
    return guard


def load_overrides(path: Optional[Path]) -> dict[str, Any]:
    if path is None:
        return {}
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def build_spec(issue: dict[str, str], overrides: dict[str, Any]) -> dict[str, Any]:
    refs = parse_refs(issue.get("refs", ""))
    inferred_guard = infer_guard(issue)
    spec: dict[str, Any] = {
        "issue_id": issue.get("id"),
        "title": issue.get("title"),
        "mode": "exec",
        "priority": issue.get("priority"),
        "phase": issue.get("phase"),
        "goal": infer_goal(issue),
        "scope": infer_scope(refs),
        "metric": None,
        "direction": None,
        "verify": None,
        "guard": inferred_guard,
        "iterations": 8,
        "run_tag": issue.get("id"),
        "stop_condition": "达到验收或连续 3 次 discard 后 pivot",
        "depends_on": [],
        "worktree_name": issue.get("id", "").lower(),
        "artifacts_dir": f"autoresearch/runs/{issue.get('id', '')}",
        "notes": issue.get("notes", ""),
        "source_csv_fields": {
            "description": issue.get("description", ""),
            "acceptance_criteria": issue.get("acceptance_criteria", ""),
            "test_plan": issue.get("test_plan", ""),
            "test_steps": issue.get("test_steps", ""),
            "test_dependencies": issue.get("test_dependencies", ""),
            "test_evidence": issue.get("test_evidence", ""),
            "review_initial_requirements": issue.get("review_initial_requirements", ""),
            "review_regression_requirements": issue.get("review_regression_requirements", ""),
            "refs": refs,
        },
        "autoresearch_ready": False,
        "readiness_gaps": [],
    }

    for key, value in overrides.items():
        spec[key] = value

    required = ["goal", "scope", "metric", "direction", "verify"]
    gaps: list[str] = []
    for key in required:
        value = spec.get(key)
        if value is None:
            gaps.append(key)
        elif isinstance(value, str) and not value.strip():
            gaps.append(key)
        elif isinstance(value, list) and not value:
            gaps.append(key)
    spec["readiness_gaps"] = gaps
    spec["autoresearch_ready"] = not gaps
    return spec


def render_markdown(spec: dict[str, Any]) -> str:
    lines: list[str] = []
    lines.append(f"# Autoresearch Spec - {spec['issue_id']}")
    lines.append("")
    lines.append(f"- Title: {spec['title']}")
    lines.append(f"- Ready: {'yes' if spec['autoresearch_ready'] else 'no'}")
    lines.append(f"- Mode: {spec.get('mode', 'exec')}")
    lines.append(f"- Priority: {spec['priority']}")
    lines.append(f"- Phase: {spec['phase']}")
    lines.append("")
    lines.append("## Goal")
    lines.append("")
    lines.append(spec["goal"])
    lines.append("")
    lines.append("## Scope")
    lines.append("")
    for item in spec.get("scope", []):
        lines.append(f"- `{item}`")
    if not spec.get("scope"):
        lines.append("- (missing)")
    lines.append("")
    lines.append("## Config")
    lines.append("")
    lines.append(f"- Metric: {spec.get('metric') or '(missing)'}")
    lines.append(f"- Direction: {spec.get('direction') or '(missing)'}")
    lines.append(f"- Verify: {spec.get('verify') or '(missing)'}")
    guard = spec.get("guard") or []
    lines.append(f"- Guard: {', '.join(guard) if guard else '(none)'}")
    lines.append(f"- Iterations: {spec.get('iterations')}")
    lines.append(f"- Run tag: {spec.get('run_tag')}")
    lines.append(f"- Stop condition: {spec.get('stop_condition')}")
    depends_on = spec.get("depends_on") or []
    lines.append(f"- Depends on: {', '.join(depends_on) if depends_on else '(none)'}")
    lines.append(f"- Worktree: {spec.get('worktree_name')}")
    lines.append(f"- Artifacts: {spec.get('artifacts_dir')}")
    lines.append("")
    if spec.get("readiness_gaps"):
        lines.append("## Readiness Gaps")
        lines.append("")
        for item in spec["readiness_gaps"]:
            lines.append(f"- {item}")
        lines.append("")
    lines.append("## Launch Block")
    lines.append("")
    lines.append("```text")
    lines.append("$codex-autoresearch")
    lines.append(f"Mode: {spec.get('mode', 'exec')}")
    lines.append(f"Goal: {spec['goal']}")
    lines.append("Scope:")
    for item in spec.get("scope", []):
        lines.append(f"- {item}")
    lines.append(f"Metric: {spec.get('metric') or ''}")
    lines.append(f"Direction: {spec.get('direction') or ''}")
    lines.append(f"Verify: {spec.get('verify') or ''}")
    if guard:
        lines.append(f"Guard: {' && '.join(guard)}")
    lines.append(f"Iterations: {spec.get('iterations')}")
    lines.append(f"Run tag: {spec.get('run_tag')}")
    lines.append(f"Stop condition: {spec.get('stop_condition')}")
    lines.append("```")
    lines.append("")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert issue CSV row to autoresearch spec")
    parser.add_argument("--csv", required=True, help="Issues CSV path")
    parser.add_argument("--issue", required=True, help="Issue ID")
    parser.add_argument("--overrides", help="JSON overrides path")
    parser.add_argument("--output", help="Output path, defaults to stdout")
    parser.add_argument("--format", choices=["json", "md"], default="json")
    args = parser.parse_args()

    rows = load_csv(Path(args.csv))
    issue = find_issue(rows, args.issue)
    overrides = load_overrides(Path(args.overrides)) if args.overrides else {}
    spec = build_spec(issue, overrides)

    if args.format == "json":
        rendered = json.dumps(spec, ensure_ascii=False, indent=2) + "\n"
    else:
        rendered = render_markdown(spec)

    if args.output:
        output = Path(args.output)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(rendered, encoding="utf-8")
    else:
        print(rendered, end="")


if __name__ == "__main__":
    main()
