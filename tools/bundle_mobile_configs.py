"""Copy authoritative YAML bytes into offline Flutter assets; never rewrite values."""

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def bundle():
    output = ROOT / "mobile/assets/configs"
    output.mkdir(parents=True, exist_ok=True)
    manifest = {}
    for folder in ("species_configs", "business_configs"):
        for source in sorted((ROOT / folder).glob("*.yaml")):
            name = f"{folder}-{source.name}"
            content = source.read_bytes()
            (output / name).write_bytes(content)
            manifest[name] = {
                "source": f"{folder}/{source.name}",
                "sha256": hashlib.sha256(content).hexdigest(),
            }
    (output / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    bundle()
