"""Create local-only credentials once; never print or commit tokens."""

import argparse
import hashlib
import json
import secrets
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--operator-id", default="operator-1")
    parser.add_argument("--admin-id", default="admin-1")
    args = parser.parse_args()
    import re

    if (
        any(
            not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,99}", label)
            for label in (args.operator_id, args.admin_id)
        )
        or args.operator_id == args.admin_id
    ):
        parser.error("Provide distinct, safe operator/admin IDs")
    root = Path(__file__).resolve().parents[1] / "backend" / ".secrets"
    root.mkdir(parents=True, exist_ok=True)
    paths = [root / "api_keys.json", root / "tokens.json"]
    if any(path.exists() for path in paths):
        parser.error(
            "Existing credentials preserved; edit/rotate explicitly rather than overwrite"
        )
    tokens, principals = {}, []
    for label, role in ((args.operator_id, "operator"), (args.admin_id, "admin")):
        token = secrets.token_urlsafe(32)
        tokens[role] = {"operator_id": label, "token": token}
        principals.append(
            {
                "operator_id": label,
                "role": role,
                "token_sha256": hashlib.sha256(token.encode()).hexdigest(),
            }
        )
    for path, value in zip(paths, (principals, tokens), strict=True):
        with path.open("x", encoding="utf-8") as stream:
            json.dump(value, stream, indent=2)
            stream.write("\n")
    print("Local API credentials created in backend/.secrets; tokens were not printed.")


if __name__ == "__main__":
    main()
