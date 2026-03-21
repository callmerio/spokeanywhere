#!/usr/bin/env python3
import argparse
import datetime as dt
import json
import shlex
import subprocess
from pathlib import Path
from typing import Any, Optional


ROOT = Path(__file__).resolve().parents[2]
UTC = dt.timezone.utc
GIT_ROOT = Path(
    subprocess.check_output(["git", "rev-parse", "--show-toplevel"], cwd=ROOT, text=True).strip()
)
PROJECT_PREFIX = subprocess.check_output(
    ["git", "rev-parse", "--show-prefix"], cwd=ROOT, text=True
).strip()


def repo_rel(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(ROOT.resolve()))
    except ValueError:
        return str(path)


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def dump_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def resolve_path(base: Path, value: str) -> Path:
    path = Path(value).expanduser()
    if path.is_absolute():
        return path
    return (base / path).resolve()


def project_dir_in_worktree(worktree_dir: Path) -> Path:
    if not PROJECT_PREFIX:
        return worktree_dir
    return (worktree_dir / PROJECT_PREFIX).resolve()


def slugify(text: str) -> str:
    lowered = text.lower()
    result = []
    for char in lowered:
        if char.isalnum():
            result.append(char)
        elif char in {" ", "-", "_"}:
            result.append("-")
    slug = "".join(result).strip("-")
    while "--" in slug:
        slug = slug.replace("--", "-")
    return slug or "issue"


def load_queue(path: Path) -> dict[str, Any]:
    queue = load_json(path)
    queue["__path"] = str(path)
    return queue


def queue_map(queue: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {item["id"]: item for item in queue["issues"]}


def ensure_worktree(base_ref: str, worktree_dir: Path, branch_name: str) -> dict[str, str]:
    if (worktree_dir / ".git").exists():
        return {"worktree": str(worktree_dir), "branch": branch_name, "created": "false"}

    branch_exists = subprocess.run(
        ["git", "rev-parse", "--verify", branch_name],
        cwd=GIT_ROOT,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    ).returncode == 0

    if branch_exists:
        cmd = ["git", "worktree", "add", str(worktree_dir), branch_name]
    else:
        cmd = ["git", "worktree", "add", "-b", branch_name, str(worktree_dir), base_ref]

    subprocess.run(cmd, cwd=GIT_ROOT, check=True)
    return {"worktree": str(worktree_dir), "branch": branch_name, "created": "true"}


def build_prompt(spec: dict[str, Any]) -> str:
    lines = [
        "$codex-autoresearch",
        f"Mode: {spec.get('mode', 'exec')}",
        f"Goal: {spec['goal']}",
        "Scope:",
    ]
    for item in spec.get("scope", []):
        lines.append(f"- {item}")
    lines.extend(
        [
            f"Metric: {spec['metric']}",
            f"Direction: {spec['direction']}",
            f"Verify: {spec['verify']}",
        ]
    )
    guard = spec.get("guard") or []
    if guard:
        lines.append(f"Guard: {' && '.join(guard)}")
    lines.extend(
        [
            f"Iterations: {spec.get('iterations', 8)}",
            f"Run tag: {spec.get('run_tag', spec['issue_id'])}",
            f"Stop condition: {spec.get('stop_condition', '')}",
        ]
    )
    notes = spec.get("notes")
    if notes:
        lines.append(f"Notes: {notes}")
    return "\n".join(lines) + "\n"


def parse_last_json_line(text: str) -> Optional[dict[str, Any]]:
    for line in reversed([line for line in text.splitlines() if line.strip()]):
        try:
            return json.loads(line)
        except json.JSONDecodeError:
            continue
    return None


def load_status(path: Path, queue: dict[str, Any]) -> dict[str, Any]:
    if path.exists():
        return load_json(path)
    issues = {}
    for item in queue["issues"]:
        issues[item["id"]] = {
            "state": "planned",
            "depends_on": item.get("depends_on", []),
            "spec": item["spec"],
            "last_run": None,
            "artifacts": None,
            "worktree": None,
            "exit_code": None,
            "summary": None,
        }
    return {
        "queue_id": queue["queue_id"],
        "csv_path": queue["csv_path"],
        "updated_at": dt.datetime.now(UTC).isoformat(),
        "issues": issues,
    }


def write_status(path: Path, status: dict[str, Any]) -> None:
    status["updated_at"] = dt.datetime.now(UTC).isoformat()
    dump_json(path, status)


def main() -> None:
    parser = argparse.ArgumentParser(description="Run a single issue via codex-autoresearch exec")
    parser.add_argument("--queue", default="autoresearch/queue/conditional-go-architecture.json")
    parser.add_argument("--issue", required=True)
    parser.add_argument("--launch", action="store_true")
    parser.add_argument("--unsafe-full-access", action="store_true")
    parser.add_argument("--model", help="Optional model override")
    parser.add_argument("--force", action="store_true", help="Run even if status is completed")
    args = parser.parse_args()

    queue_path = resolve_path(ROOT, args.queue)
    queue = load_queue(queue_path)
    issue_map = queue_map(queue)
    if args.issue not in issue_map:
        raise SystemExit(f"issue not in queue: {args.issue}")
    issue_entry = issue_map[args.issue]

    spec_path = resolve_path(ROOT, issue_entry["spec"])
    spec = load_json(spec_path)
    if not spec.get("autoresearch_ready", True) and not args.launch:
        print(json.dumps({"issue": args.issue, "ready": False, "reason": "spec marked not ready"}))
        return

    status_path = resolve_path(ROOT, queue["status_path"])
    status = load_status(status_path, queue)

    current_state = status["issues"].get(args.issue, {}).get("state")
    if current_state == "completed" and not args.force:
        print(
            json.dumps(
                {
                    "issue": args.issue,
                    "ready": False,
                    "skipped": True,
                    "message": "issue already completed in status file",
                },
                ensure_ascii=False,
            )
        )
        return

    unresolved = [
        dep
        for dep in issue_entry.get("depends_on", [])
        if status["issues"].get(dep, {}).get("state") != "completed"
    ]
    if unresolved:
        print(
            json.dumps(
                {
                    "issue": args.issue,
                    "ready": False,
                    "blocked_by": unresolved,
                    "current_state": current_state,
                    "message": "dependencies not completed",
                },
                ensure_ascii=False,
            )
        )
        return

    base_ref = queue.get("base_ref", "HEAD")
    worktree_root = resolve_path(ROOT, queue["worktree_root"])
    artifacts_root = resolve_path(ROOT, queue["artifacts_root"])
    worktree_name = spec.get("worktree_name") or f"{args.issue.lower()}-{slugify(spec.get('title', args.issue))}"
    worktree_dir = worktree_root / worktree_name
    project_workdir = project_dir_in_worktree(worktree_dir)
    branch_name = f"autoresearch/{worktree_name}"
    artifact_dir = artifacts_root / args.issue / dt.datetime.now(UTC).strftime("%Y-%m-%d_%H-%M-%S")

    prompt = build_prompt(spec)
    prompt_path = artifact_dir / "prompt.txt"
    launch_config_path = artifact_dir / "launch-config.json"

    dry_run_payload = {
        "issue": args.issue,
        "launch": args.launch,
        "worktree_dir": str(worktree_dir),
        "project_workdir": str(project_workdir),
        "branch_name": branch_name,
        "artifact_dir": repo_rel(artifact_dir),
        "prompt_path": repo_rel(prompt_path),
        "spec_path": repo_rel(spec_path),
        "current_state": current_state,
    }

    if not args.launch:
        print(json.dumps(dry_run_payload, ensure_ascii=False, indent=2))
        return

    artifact_dir.mkdir(parents=True, exist_ok=True)
    prompt_path.write_text(prompt, encoding="utf-8")
    dump_json(
        launch_config_path,
        {
            "issue": args.issue,
            "queue": repo_rel(queue_path),
            "spec": spec,
            "worktree_dir": str(worktree_dir),
            "project_workdir": str(project_workdir),
            "branch_name": branch_name,
            "base_ref": base_ref,
        },
    )

    ensure_worktree(base_ref, worktree_dir, branch_name)

    command = [
        "codex",
        "exec",
        "--json",
        "--color",
        "never",
        "-C",
        str(project_workdir),
        "-o",
        str(artifact_dir / "last-message.txt"),
    ]
    if args.model:
        command.extend(["-m", args.model])
    if args.unsafe_full_access:
        command.append("--dangerously-bypass-approvals-and-sandbox")
    else:
        command.append("--full-auto")

    status["issues"][args.issue]["state"] = "running"
    status["issues"][args.issue]["worktree"] = str(worktree_dir)
    status["issues"][args.issue]["artifacts"] = repo_rel(artifact_dir)
    write_status(status_path, status)

    process = subprocess.run(
        command,
        cwd=ROOT,
        input=prompt,
        text=True,
        capture_output=True,
        check=False,
    )

    stdout_path = artifact_dir / "events.jsonl"
    stderr_path = artifact_dir / "stderr.log"
    stdout_path.write_text(process.stdout, encoding="utf-8")
    stderr_path.write_text(process.stderr, encoding="utf-8")

    summary = parse_last_json_line(process.stdout)
    state = "completed" if process.returncode == 0 else "blocked"
    status["issues"][args.issue]["state"] = state
    status["issues"][args.issue]["last_run"] = dt.datetime.now(UTC).isoformat()
    status["issues"][args.issue]["exit_code"] = process.returncode
    status["issues"][args.issue]["summary"] = summary
    write_status(status_path, status)

    summary_md = artifact_dir / "summary.md"
    lines = [
        f"# Run Summary - {args.issue}",
        "",
        f"- State: {state}",
        f"- Exit code: {process.returncode}",
        f"- Worktree: `{worktree_dir}`",
        f"- Project workdir: `{project_workdir}`",
        f"- Branch: `{branch_name}`",
        f"- Prompt: `{repo_rel(prompt_path)}`",
        f"- Events: `{repo_rel(stdout_path)}`",
        f"- STDERR: `{repo_rel(stderr_path)}`",
        "",
        "## Parsed Summary",
        "",
        "```json",
        json.dumps(summary or {}, ensure_ascii=False, indent=2),
        "```",
        "",
    ]
    summary_md.write_text("\n".join(lines), encoding="utf-8")

    print(
        json.dumps(
            {
                "issue": args.issue,
                "state": state,
                "exit_code": process.returncode,
                "artifact_dir": repo_rel(artifact_dir),
                "worktree_dir": str(worktree_dir),
                "summary": summary,
            },
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
