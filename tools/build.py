#!/usr/bin/env python3
"""Package the shader pack as dist/GTNH-Gentle-Atmosphere-<VERSION>.zip.

The zip has `shaders/` at its root, which is the layout Angelica/OptiFine
expect inside the `shaderpacks` folder. Output is reproducible: fixed
timestamps and sorted entries.

Usage: python3 tools/build.py
"""
import pathlib
import zipfile

REPO = pathlib.Path(__file__).resolve().parent.parent


def main():
    version = (REPO / "VERSION").read_text(encoding="utf-8").strip()
    dist = REPO / "dist"
    dist.mkdir(exist_ok=True)
    target = dist / f"GTNH-Gentle-Atmosphere-{version}.zip"
    files = sorted(p for p in (REPO / "shaders").rglob("*") if p.is_file())
    files += [REPO / "LICENSE", REPO / "README.md", REPO / "CHANGELOG.md"]
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in files:
            info = zipfile.ZipInfo(path.relative_to(REPO).as_posix(), date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, path.read_bytes())
    print(f"{target.relative_to(REPO)} ({len(files)} files, {target.stat().st_size // 1024} KiB)")


if __name__ == "__main__":
    main()
