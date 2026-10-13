#!/usr/bin/env python3
"""Compile every shader entry point with glslangValidator.

Resolves Iris/Angelica-style absolute #include paths, applies each profile
from shaders.properties (plus "all options off" and "everything on" sets)
the same way the in-game option menu rewrites `#define NAME value` lines,
and checks that every program compiles. Requires glslangValidator
(Ubuntu/Debian: `apt install glslang-tools`).

Usage: python3 tools/validate.py [--quick]
"""
import pathlib
import re
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent / "shaders"
INCLUDE = re.compile(r'^\s*#include\s+"([^"]+)"\s*$')
DEFINE = re.compile(r'^(\s*#define\s+(\w+)\s+)(\S+)(.*)$')


def resolve(path, seen=None):
    seen = seen or []
    lines = []
    for line in path.read_text(encoding="utf-8").splitlines():
        match = INCLUDE.match(line)
        if match:
            target = match.group(1)
            target = ROOT / target.lstrip("/") if target.startswith("/") else path.parent / target
            if target in seen:
                raise RuntimeError(f"include cycle: {target}")
            lines.extend(resolve(target, seen + [target]))
        else:
            lines.append(line)
    return lines


def options():
    values = {}
    for line in (ROOT / "lib/settings.glsl").read_text(encoding="utf-8").splitlines():
        match = DEFINE.match(line)
        if match and "[" in match.group(4):
            allowed = re.search(r"\[([^\]]*)\]", match.group(4)).group(1).split()
            values[match.group(2)] = (match.group(3), allowed)
    return values


def profiles(opts):
    text = (ROOT / "shaders.properties").read_text(encoding="utf-8")
    result = {"Defaults": {}}
    for name, body in re.findall(r"^profile\.(\w+)=(.*)$", text, re.M):
        result[name] = dict(item.split(":") for item in body.split())
    result["AllLowest"] = {k: v[1][0] for k, v in opts.items()}
    result["AllHighest"] = {k: v[1][-1] for k, v in opts.items()}
    for name, profile in result.items():
        for key, value in profile.items():
            if key not in opts:
                raise RuntimeError(f"profile {name}: unknown option {key}")
            if value not in opts[key][1]:
                raise RuntimeError(f"profile {name}: {key}={value} not in {opts[key][1]}")
    return result


def apply(lines, profile):
    out = []
    for line in lines:
        match = DEFINE.match(line)
        if match and match.group(2) in profile:
            line = match.group(1) + profile[match.group(2)] + match.group(4)
        out.append(line)
    return "\n".join(out) + "\n"


def main():
    opts = options()
    sets = profiles(opts)
    if "--quick" in sys.argv:
        sets = {k: sets[k] for k in ("Defaults",)}
    entries = sorted(p for d in ("", "world-1", "world1") for p in (ROOT / d).glob("*.[fv]sh"))
    failures = 0
    with tempfile.TemporaryDirectory() as tmp:
        for entry in entries:
            source = resolve(entry)
            stage = "frag" if entry.suffix == ".fsh" else "vert"
            for name, profile in sets.items():
                file = pathlib.Path(tmp) / f"shader.{stage}"
                file.write_text(apply(source, profile), encoding="utf-8")
                run = subprocess.run(["glslangValidator", str(file)], capture_output=True, text=True)
                errors = [l for l in run.stdout.splitlines() if "ERROR" in l]
                if run.returncode != 0 or errors:
                    failures += 1
                    print(f"FAIL {entry.relative_to(ROOT)} [{name}]")
                    for line in errors[:8]:
                        print("    " + line)
    total = len(entries) * len(sets)
    print(f"{total - failures}/{total} compilations passed ({len(entries)} entry points, {len(sets)} option sets)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
