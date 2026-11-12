"""Local health, disk and verified-backup-age checks. No account or paid service."""

import argparse
import json
import shutil
import ssl
import urllib.request
from datetime import UTC, datetime
from pathlib import Path
from urllib.parse import urlsplit


def inspect(args):
    uri = urlsplit(args.url)
    if (
        uri.scheme != "https"
        or not uri.hostname
        or uri.username
        or uri.password
        or uri.query
        or uri.fragment
        or uri.path != "/health"
    ):
        raise ValueError("Provide a credential-free HTTPS /health URL")
    context = ssl.create_default_context(
        cafile=str(args.ca_file) if args.ca_file else None
    )
    problems = []
    try:
        with urllib.request.urlopen(args.url, context=context, timeout=10) as response:
            body = response.read(65537)
            if len(body) > 65536:
                raise ValueError("Oversized health response")
            health = json.loads(body)
            if not isinstance(health, dict):
                raise TypeError("Invalid health response")
            if health.get("status") != "ok" or health.get("database") != "ok":
                problems.append("database_health")
    except (OSError, ValueError, TypeError):
        health = {"status": "unavailable"}
        problems.append("https_health")
    disk = shutil.disk_usage(args.disk_root)
    if disk.free < args.min_free_gib * 1024**3:
        problems.append("disk_space")
    verified = []
    for path in args.backup_root.glob("*-verified.json"):
        try:
            receipt = json.loads(path.read_text("utf-8"))
            if (
                receipt.get("project") == args.project
                and receipt.get("restore_verified") is True
                and receipt.get("live_promoted") is False
            ):
                timestamp = datetime.fromisoformat(receipt["verified_at"])
                if timestamp.tzinfo is not None:
                    verified.append(timestamp.astimezone(UTC))
        except (OSError, KeyError, ValueError, TypeError):
            continue
    age = (
        (datetime.now(UTC) - max(verified)).total_seconds() / 3600 if verified else None
    )
    if age is None or age < 0 or age > args.max_backup_age_hours:
        problems.append("verified_backup_age")
    return {
        "checked_at": datetime.now(UTC).isoformat(),
        "healthy": not problems,
        "problems": problems,
        "database_health": health.get("database"),
        "free_bytes": disk.free,
        "backup_age_hours": age,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", required=True)
    parser.add_argument("--project", required=True)
    parser.add_argument("--disk-root", type=Path, required=True)
    parser.add_argument("--backup-root", type=Path, required=True)
    parser.add_argument("--ca-file", type=Path)
    parser.add_argument("--min-free-gib", type=int, default=10)
    parser.add_argument("--max-backup-age-hours", type=int, default=26)
    args = parser.parse_args()
    if args.min_free_gib < 1 or args.max_backup_age_hours < 1:
        parser.error("Use positive disk and age limits")
    report = inspect(args)
    print(json.dumps(report, indent=2))
    raise SystemExit(0 if report["healthy"] else 2)


if __name__ == "__main__":
    main()
