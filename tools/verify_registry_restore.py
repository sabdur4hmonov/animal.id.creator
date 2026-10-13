"""Compare registry state byte-for-byte semantically after an isolated database restore."""

import argparse
import hashlib
import json
from pathlib import Path

from verify_docker_upload import compose_output, require


def verify(args):
    require(args.target_database.startswith("biolivestock_restore_"), "Only isolated restore databases allowed")
    tables = ["animal_number_counters", "animal_profiles", "registry_receipts", "animals", "audit_events"]
    evidence = {}
    for table in tables:
        values = []
        for database in ["biolivestock", args.target_database]:
            raw = compose_output(args.project, "exec", "-T", "db", "psql", "-U", "biolivestock",
                                 "-d", database, "-Atc", f"SELECT row_to_json(t) FROM {table} t")
            rows = sorted(json.dumps(json.loads(line), sort_keys=True) for line in raw.splitlines())
            values.append(rows)
        require(values[0] == values[1], f"Restored {table} differs from source")
        evidence[table] = {"rows": len(values[0]), "sha256": hashlib.sha256("\n".join(values[0]).encode()).hexdigest()}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("x", encoding="utf-8") as stream:
        json.dump({"synthetic": True, "target_database": args.target_database, "equal_tables": evidence}, stream, indent=2)
    print(f"Verified complete registry/animal/audit state matches isolated restore: {args.output}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", default="biolivestock-reliability")
    parser.add_argument("--target-database", required=True)
    parser.add_argument("--output", type=Path, required=True)
    verify(parser.parse_args())
