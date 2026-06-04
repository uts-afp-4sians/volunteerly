"""Generate openapi.json from the FastAPI app."""

import json
from pathlib import Path

from src.main import app


def main() -> None:
    schema = app.openapi()
    out = Path(__file__).resolve().parent.parent / "openapi.json"
    out.write_text(json.dumps(schema, indent=2) + "\n")
    print(f"Wrote {out}")


if __name__ == "__main__":
    main()
