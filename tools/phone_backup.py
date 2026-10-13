"""Verify a phone ZIP or extract it into a new directory; never modify live evidence."""

import argparse
import hashlib
import json
import re
import shutil
import stat
from pathlib import Path
from zipfile import ZipFile

NAME = re.compile(r"^queue/(?:[a-f0-9]{32}\.jpg|(?:entry|receipt|registry|registry-receipt)-[a-f0-9]{32}\.json)(?:\.next)?$")


def verify(bundle: Path) -> dict:
    with ZipFile(bundle) as archive:
        entries = archive.infolist()
        names = [entry.filename for entry in entries]
        if len(names) != len(set(names)) or "manifest.json" not in names:
            raise ValueError("Duplicate entries or missing manifest")
        if archive.getinfo("manifest.json").file_size > 8 * 1024 * 1024:
            raise ValueError("Manifest exceeds size limit")
        manifest = json.loads(archive.read("manifest.json"))
        if (not isinstance(manifest, dict) or manifest.get("version") != 1 or manifest.get("format") != "biolivestock-phone-queue"
                or not isinstance(manifest.get("files"), dict)):
            raise ValueError("Unsupported phone backup")
        files = manifest["files"]
        if set(names) != set(files) | {"manifest.json"}:
            raise ValueError("Backup inventory mismatch")
        for name, expected in files.items():
            if not NAME.fullmatch(name) or not isinstance(expected, dict):
                raise ValueError("Unsafe or unsupported backup entry")
            info = archive.getinfo(name)
            if stat.S_ISLNK(info.external_attr >> 16) or info.is_dir():
                raise ValueError("Backup links/directories are unsupported")
            size, checksum = expected.get("bytes"), expected.get("sha256")
            if (type(size) is not int or not 0 <= size <= 128 * 1024 * 1024
                    or info.file_size != size or not isinstance(checksum, str)
                    or not re.fullmatch(r"[a-f0-9]{64}", checksum)):
                raise ValueError(f"Invalid file manifest: {name}")
            with archive.open(name) as source:
                actual = hashlib.file_digest(source, "sha256").hexdigest()
            if actual != checksum:
                raise ValueError(f"Backup checksum mismatch: {name}")
        return manifest


def extract(bundle: Path, destination: Path) -> dict:
    manifest = verify(bundle)
    if destination.exists() or destination.is_symlink():
        raise ValueError("Use a new, absent destination; existing files are preserved")
    root = destination.resolve()
    root.mkdir(parents=True, exist_ok=False)
    with ZipFile(bundle) as archive:
        for name in ["manifest.json", *manifest["files"]]:
            target = (root / name).resolve()
            if not target.is_relative_to(root):
                raise ValueError("Path escapes recovery directory")
            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(name) as source, target.open("xb") as output:
                shutil.copyfileobj(source, output, length=65536)
            if name != "manifest.json":
                with target.open("rb") as recovered:
                    checksum = hashlib.file_digest(recovered, "sha256").hexdigest()
                if checksum != manifest["files"][name]["sha256"]:
                    raise ValueError("Recovered file differs; partial recovery retained for inspection")
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("verify", "extract"):
        command = commands.add_parser(name)
        command.add_argument("--bundle", type=Path, required=True)
        if name == "extract":
            command.add_argument("--destination", type=Path, required=True)
    args = parser.parse_args()
    manifest = verify(args.bundle) if args.command == "verify" else extract(args.bundle, args.destination)
    print(f"Verified {len(manifest['files'])} phone evidence files; no live queue/database changed")


if __name__ == "__main__":
    main()
