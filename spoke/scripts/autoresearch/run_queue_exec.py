#!/usr/bin/env python3
import argparse
import json
import subprocess
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def resolve_path(base: Path, value: str) -> Path:
    path = Path(value).expanduser()
    if path.is_absolute():
        return path
    return (base / path).resolve()


def main() -> None:
    parser = argparse.ArgumentParser(description="Run autoresearch queue sequentially")
    parser.add_argument("--queue", default="autoresearch/queue/conditional-go-architecture.json")
    parser.add_argument("--launch", action="store_true")
    parser.add_argument("--unsafe-full-access", action="store_true")
    parser.add_argument("--model")
    parser.add_argument("--from-issue", help="Start from a specific issue id")
    parser.add_argument("--max-issues", type=int, help="Limit how many issues to process")
    parser.add_argument("--force", action="store_true", help="Run issues even if status says completed")
    args = parser.parse_args()

    queue_path = resolve_path(ROOT, args.queue)
    queue = load_json(queue_path)
    issues = queue["issues"]

    if args.from_issue:
        ids = [item["id"] for item in issues]
        if args.from_issue not in ids:
            raise SystemExit(f"issue not in queue: {args.from_issue}")
        start_index = ids.index(args.from_issue)
        issues = issues[start_index:]

    if args.max_issues is not None:
        issues = issues[: args.max_issues]

    results = []
    for item in issues:
        cmd = [
            "python3",
            str(ROOT / "scripts" / "autoresearch" / "run_issue_exec.py"),
            "--queue",
            str(queue_path),
            "--issue",
            item["id"],
        ]
        if args.launch:
            cmd.append("--launch")
        if args.unsafe_full_access:
            cmd.append("--unsafe-full-access")
        if args.model:
            cmd.extend(["--model", args.model])
        if args.force:
            cmd.append("--force")

        process = subprocess.run(
            cmd,
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        payload = {
            "issue": item["id"],
            "exit_code": process.returncode,
            "stdout": process.stdout.strip(),
            "stderr": process.stderr.strip(),
        }
        results.append(payload)

        if args.launch and process.returncode != 0:
            break

        try:
            parsed = json.loads(process.stdout)
        except json.JSONDecodeError:
            parsed = None
        if args.launch and parsed and parsed.get("blocked_by"):
            break

    print(json.dumps({"queue": queue["queue_id"], "launch": args.launch, "results": results}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
