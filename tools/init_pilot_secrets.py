"""Create a new private pilot secret directory; never overwrite or print credentials."""

import argparse
import hashlib
import json
import os
import re
import secrets
from pathlib import Path


def initialize(destination: Path, prefix: str, operator_id=None, admin_id=None):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,70}", prefix):
        raise ValueError("Use a safe actor prefix")
    identities = {
        "operator": operator_id or f"{prefix}-OPERATOR",
        "admin": admin_id or f"{prefix}-ADMIN",
    }
    if len(set(identities.values())) != 2 or any(
        not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,99}", value)
        for value in identities.values()
    ):
        raise ValueError(
            "Use distinct, safe operator/admin IDs; preserve the original capture operator"
        )
    old_umask = os.umask(0o077)
    try:
        destination.mkdir(parents=True, exist_ok=False)
        password = secrets.token_urlsafe(32)
        values = {
            "postgres_password": password,
            "database_url": f"postgresql+psycopg://biolivestock:{password}@db:5432/biolivestock",
        }
        tokens, principals = {}, []
        for role in ("operator", "admin"):
            token = secrets.token_urlsafe(32)
            identity = identities[role]
            tokens[role] = {"operator_id": identity, "token": token}
            principals.append(
                {
                    "operator_id": identity,
                    "role": role,
                    "token_sha256": hashlib.sha256(token.encode()).hexdigest(),
                }
            )
        values["api_keys.json"] = json.dumps(principals, indent=2)
        values["tokens.json"] = json.dumps(tokens, indent=2)
        for name, value in values.items():
            with (destination / name).open("x", encoding="utf-8") as stream:
                stream.write(value + "\n")
    finally:
        os.umask(old_umask)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--prefix", default="PILOT")
    parser.add_argument(
        "--operator-id",
        help="Exact original offline operator ID, if captures already exist",
    )
    parser.add_argument("--admin-id")
    args = parser.parse_args()
    initialize(
        args.output, args.prefix, operator_id=args.operator_id, admin_id=args.admin_id
    )
    print(
        "New private pilot secrets created. Nothing overwritten; no credential printed."
    )


if __name__ == "__main__":
    main()
