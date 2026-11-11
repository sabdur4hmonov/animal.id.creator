"""Read-only publication audit. Reports locations, never matched secret values."""

import io
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def git(*args: str) -> bytes:
    return subprocess.check_output(["git", *args], cwd=ROOT)


def read_blobs(objects):
    """One Git process avoids hundreds of Windows process launches per audit."""
    output = subprocess.check_output(
        ["git", "cat-file", "--batch"],
        cwd=ROOT,
        input=("\n".join(objects) + "\n").encode(),
    )
    stream = io.BytesIO(output)
    for expected in objects:
        header = stream.readline().decode("ascii").strip().split()
        if len(header) != 3 or header[0] != expected:
            raise RuntimeError("Unexpected Git object response; stop publication")
        raw = stream.read(int(header[2]))
        if stream.read(1) != b"\n":
            raise RuntimeError("Truncated Git object response; stop publication")
        if header[1] == "blob":
            yield expected, raw


def audit() -> dict:
    tracked = git("ls-files", "-z").decode().split("\0")[:-1]
    outgoing = git("rev-list", "--objects", "origin/main..HEAD").decode().splitlines()
    objects = dict(line.split(" ", 1) for line in outgoing if " " in line)
    for line in git("ls-tree", "-r", "HEAD").decode().splitlines():
        metadata, path = line.split("\t", 1)
        if " blob " in metadata:
            objects[metadata.split()[2]] = path
    findings = []
    personal = []
    suspects = []
    media = []
    forbidden = re.compile(
        r"(^data/|(^|/)(\.secrets|tokens\.json)(/|$)|(^|/)\.env($|\.(?!example$))"
        r"|\.(?:apk|aab|jks|keystore|pt|pth|onnx|dump|sqlite|db)$)",
        re.IGNORECASE,
    )
    signatures = {
        "private_key": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
        "github_token": re.compile(
            r"\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})\b"
        ),
        "aws_key": re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
        "openai_key": re.compile(r"\bsk-(?:proj-)?[A-Za-z0-9_-]{40,}\b"),
    }
    for path in tracked:
        if forbidden.search(path):
            findings.append({"kind": "forbidden_tracked_path", "path": path})
    for oid, raw in read_blobs(objects):
        path = objects[oid]
        if forbidden.search(path):
            findings.append({"kind": "forbidden_path", "path": path, "blob": oid})
        if b"\0" in raw:
            if path.lower().endswith((".png", ".jpg", ".jpeg", ".pdf", ".zip")):
                media.append(path)
            continue
        for number, line in enumerate(
            raw.decode("utf-8", errors="replace").splitlines(), 1
        ):
            location = {"path": path, "line": number, "blob": oid}
            for kind, pattern in signatures.items():
                if pattern.search(line):
                    findings.append({"kind": kind, **location})
            if re.search(
                r"(?i)(api[_-]?token|api[_-]?key|password|secret)\s*[=:]\s*['\"][^'\"]{12,}['\"]",
                line,
            ):
                suspects.append(location)
            if path.endswith(".md") and re.search(r"\+998[ -]*(?:\d[ -]*){9}", line):
                personal.append({"kind": "phone", **location})
    ignored = [
        "data/artifacts/probe.apk",
        "data/cattle/real.jpg",
        "backend/.secrets/tokens.json",
        "backend/.env",
        "mobile/android/app/private.jks",
        "models/cattle/model.pt",
    ]
    return {
        "head": git("rev-parse", "HEAD").decode().strip(),
        "base": git("rev-parse", "origin/main").decode().strip(),
        "outgoing_commits": int(git("rev-list", "--count", "origin/main..HEAD")),
        "tracked_count": len(tracked),
        "unique_objects_reviewed": len(objects),
        "findings": findings,
        "credential_assignment_review": suspects,
        "docs_phone_review": personal,
        "binary_media_review": sorted(set(media)),
        "ignore_checks": {
            path: subprocess.run(
                ["git", "check-ignore", "-q", path], cwd=ROOT, check=False
            ).returncode
            == 0
            for path in ignored
        },
    }


if __name__ == "__main__":
    result = audit()
    folder = ROOT / "data" / "dev"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "publication-audit-20261110.json").write_text(
        json.dumps(result, indent=2), encoding="utf-8"
    )
    print(json.dumps(result, indent=2))
