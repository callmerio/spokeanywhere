#!/usr/bin/env python3
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def contains_all(path: Path, patterns: list[str]) -> bool:
    if not path.exists():
        return False
    content = path.read_text(encoding="utf-8")
    return all(pattern in content for pattern in patterns)


def main() -> None:
    gate_doc = ROOT / "docs" / "roadmap" / "2026-03-conditional-go-architecture-roadmap.md"
    issue_csv = ROOT / "issues" / "2026-03-19_20-55-00-conditional-go-architecture.csv"
    current_audit = ROOT / "docs" / "architecture" / "current-state-audit.md"

    checks = {
        "roadmap_exists": gate_doc.exists(),
        "issues_csv_exists": issue_csv.exists(),
        "quality_commands_documented": contains_all(
            current_audit,
            ["swift test", "bash Tests/run-concurrency-check.sh"],
        ),
        "quality_gate_issue_present": contains_all(
            issue_csv,
            ["QG-010", "版本化质量门禁入口", "Tests/run-concurrency-check.sh"],
        ),
        "failure_categories_documented": contains_all(
            issue_csv,
            ["构建失败", "测试失败", "并发告警", "环境失败"],
        ),
    }

    missing = [name for name, ok in checks.items() if not ok]
    result = {
        "metric_name": "missing_quality_gate_contract_items",
        "metric": len(missing),
        "direction": "lower",
        "missing": missing,
        "checks": checks,
    }
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
