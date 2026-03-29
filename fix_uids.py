#!/usr/bin/env python3
"""
Fixes Godot UID mismatches by reading the current UIDs from .import files
and patching ext_resource entries in .tscn/.tres files to match.
"""
import os
import re
import glob

PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))

# Build ground-truth map: res:// path -> current UID from .import file
print("Reading current UIDs from .import files...")
import_uid_re = re.compile(r'^uid="(uid://[^"]+)"', re.MULTILINE)
import_path_map = {}  # res:// path -> uid

for import_file in glob.glob(os.path.join(PROJECT_ROOT, "**/*.import"), recursive=True):
    rel = os.path.relpath(import_file, PROJECT_ROOT).replace("\\", "/")
    res_path = "res://" + rel[:-len(".import")]
    with open(import_file, "r", encoding="utf-8") as fh:
        content = fh.read()
    m = import_uid_re.search(content)
    if m:
        import_path_map[res_path] = m.group(1)

print(f"  Found {len(import_path_map)} .import files with UIDs")

# Patch .tscn/.tres files: replace stale UIDs with the ones from .import files
ext_resource_re = re.compile(
    r'(\[ext_resource[^\]]*\buid=)"(uid://[^"]+)"([^\]]*\bpath="([^"]+)"[^\]]*\])',
)

def fix_line(m):
    before, old_uid, after, path = m.group(1), m.group(2), m.group(3), m.group(4)
    canonical_uid = import_path_map.get(path)
    if canonical_uid and canonical_uid != old_uid:
        return f'{before}"{canonical_uid}"{after}'
    return m.group(0)

fixed_files = 0
total_fixes = 0

source_files = glob.glob(os.path.join(PROJECT_ROOT, "**/*.tscn"), recursive=True)
source_files += glob.glob(os.path.join(PROJECT_ROOT, "**/*.tres"), recursive=True)

for src_file in source_files:
    with open(src_file, "r", encoding="utf-8") as fh:
        original = fh.read()

    patched = ext_resource_re.sub(fix_line, original)

    if patched != original:
        count = sum(
            1 for a, b in zip(original.splitlines(), patched.splitlines()) if a != b
        )
        rel = os.path.relpath(src_file, PROJECT_ROOT)
        print(f"  Fixed {count} UID(s) in {rel}")
        with open(src_file, "w", encoding="utf-8") as fh:
            fh.write(patched)
        fixed_files += 1
        total_fixes += count

print(f"\nDone: {total_fixes} UIDs fixed across {fixed_files} files.")
print("Restart Godot to verify.")
