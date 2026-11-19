#!/usr/bin/env python3
"""Copy the screenshots attached by the UI tests out of an .xcresult bundle, with readable names.

usage: export_screenshots.py <TestResults.xcresult> <output-dir>
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile


def main() -> int:
    bundle, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    raw = tempfile.mkdtemp()
    subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", bundle, "--output-path", raw], check=True)

    with open(os.path.join(raw, "manifest.json"), encoding="utf-8") as f:
        manifest = json.load(f)

    copied = 0

    def walk(node):
        nonlocal copied
        if isinstance(node, dict):
            exported = node.get("exportedFileName")
            if exported and os.path.splitext(exported)[1].lower() in (".png", ".jpg", ".jpeg", ".heic"):
                name = node.get("suggestedHumanReadableName") or exported
                # "en-07-writing_0_ABCD....png" -> "en-07-writing.png"
                base, ext = os.path.splitext(name)
                base = base.split("_")[0] or base
                # keep names safe for every file system (artifact uploads reject " : < > | * ?)
                base = "".join(ch if ch.isalnum() or ch in "-." else "-" for ch in base).strip("-") or "shot"
                ext = os.path.splitext(exported)[1].lower()
                target = os.path.join(out, base + (ext or ".png"))
                n = 2
                while os.path.exists(target):
                    target = os.path.join(out, f"{base}-{n}{ext or '.png'}")
                    n += 1
                shutil.copy(os.path.join(raw, exported), target)
                copied += 1
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)

    walk(manifest)
    print(f"exported {copied} screenshots to {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
