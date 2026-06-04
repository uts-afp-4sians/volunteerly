"""Generate openapi.json from the FastAPI app.

FastAPI/Pydantic v2 emit OpenAPI 3.1, where an ``Optional[X]`` field becomes
``anyOf: [<X>, {"type": "null"}]``. Some downstream codegen tools (notably
swift-openapi-generator) don't support the bare ``{"type": "null"}`` schema and
silently *drop* those properties. To keep the contract faithful for every
consumer, we down-convert the document to OpenAPI 3.0.3, where nullability is
expressed as ``nullable: true`` — which those tools handle correctly.
"""

import json
from copy import deepcopy
from pathlib import Path
from typing import Any

from src.main import app

TARGET_VERSION = "3.0.3"


def _is_null_schema(node: Any) -> bool:
    return isinstance(node, dict) and node.get("type") == "null" and len(node) == 1


def _downgrade(node: Any) -> Any:
    """Recursively rewrite a 3.1 schema fragment to 3.0-compatible form."""
    if isinstance(node, list):
        return [_downgrade(item) for item in node]
    if not isinstance(node, dict):
        return node

    node = {key: _downgrade(value) for key, value in node.items()}

    # `type: ["string", "null"]`  ->  `type: "string", nullable: true`
    if isinstance(node.get("type"), list):
        types = [t for t in node["type"] if t != "null"]
        if len(node["type"]) != len(types):
            node["nullable"] = True
        node["type"] = types[0] if len(types) == 1 else types

    # `anyOf/oneOf: [<X>, {"type": "null"}]`  ->  collapse + nullable: true
    for combiner in ("anyOf", "oneOf"):
        members = node.get(combiner)
        if not isinstance(members, list):
            continue
        non_null = [m for m in members if not _is_null_schema(m)]
        if len(non_null) != len(members):
            node["nullable"] = True
            if len(non_null) == 1:
                only = non_null[0]
                del node[combiner]
                # A bare $ref can't carry sibling keywords in 3.0; wrap it.
                if set(only.keys()) == {"$ref"}:
                    node["allOf"] = [only]
                else:
                    node.update(only)
            else:
                node[combiner] = non_null

    # 3.0 has no `const`; express it as a single-value enum.
    if "const" in node:
        node["enum"] = [node.pop("const")]

    # 3.0 uses singular `example`, not the `examples` array.
    if isinstance(node.get("examples"), list) and node["examples"]:
        node.setdefault("example", node["examples"][0])
        del node["examples"]

    return node


def to_openapi_30(schema: dict) -> dict:
    schema = deepcopy(schema)
    schema["openapi"] = TARGET_VERSION
    schema = _downgrade(schema)
    return schema


def main() -> None:
    schema = to_openapi_30(app.openapi())
    out = Path(__file__).resolve().parent.parent / "openapi.json"
    out.write_text(json.dumps(schema, indent=2) + "\n")
    print(f"Wrote {out} (OpenAPI {schema['openapi']})")


if __name__ == "__main__":
    main()
