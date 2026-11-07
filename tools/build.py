#!/usr/bin/env python3
"""Build dist/plugin.json from the metadata and the Lua source.

PBS Studio imports exactly one JSON document per plugin. This script embeds
src/plugin.lua into the reviewed manifest, checks the schema v5 size limits and
writes the installable artifact.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAX_SCRIPT_BYTES = 48 * 1024


def main() -> int:
    base = json.loads((ROOT / "manifest.base.json").read_text(encoding="utf-8"))
    source = (ROOT / "src" / "plugin.lua").read_text(encoding="utf-8")
    size = len(source.encode("utf-8"))
    if not 1 <= size <= MAX_SCRIPT_BYTES:
        print(f"src/plugin.lua is {size} bytes; schema v5 allows 1..{MAX_SCRIPT_BYTES}", file=sys.stderr)
        return 1
    if "\x00" in source:
        print("src/plugin.lua contains a NUL byte", file=sys.stderr)
        return 1
    base["runtime"] = {"language": "lua", "api": 2, "source": source}
    output = ROOT / "dist" / "plugin.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(base, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"wrote {output.relative_to(ROOT)} ({output.stat().st_size} bytes, script {size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
