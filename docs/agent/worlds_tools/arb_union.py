"""Resolve a conflicted ARB file (path relative to repo root, run from repo root)
by the union of both sides' keys. --theirs: on a clash keep theirs; else fail."""
import json, subprocess, sys
from collections import OrderedDict
path = sys.argv[1]
def stage(n):
    out = subprocess.run(["git", "show", f":{n}:{path}"], capture_output=True, text=True, check=True).stdout
    return json.loads(out, object_pairs_hook=OrderedDict)
ours, theirs = stage(2), stage(3)
merged = OrderedDict(ours); clashes = []
for k, v in theirs.items():
    if k in merged:
        if merged[k] != v:
            if "--theirs" in sys.argv: merged[k] = v
            else: clashes.append(k)
    else:
        merged[k] = v
if clashes:
    print("CLASH", path, clashes); sys.exit(2)
with open(path, "w", encoding="utf-8") as f:
    json.dump(merged, f, ensure_ascii=False, indent=2); f.write("\n")
print("merged", path, len(ours), "+", len(merged) - len(ours))
