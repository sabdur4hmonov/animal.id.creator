"""Run offline research using shared backend schemas without installing a package."""

import sys
from importlib import import_module
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))
sys.path.insert(0, str(ROOT / "research"))

if __name__ == "__main__":
    import_module("biolivestock_research.cli").main()
