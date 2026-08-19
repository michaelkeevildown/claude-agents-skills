#!/usr/bin/env bash
# Repo self-audit. Every check here exists because it once found a real defect; each is mechanical,
# offline, and fails loudly rather than warning quietly.
#
# Run it after touching skills, agents, hooks, or shell. Exit 0 = clean, 1 = findings.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
note() { printf '  %s\n' "$1"; }
bad()  { printf '  FAIL: %s\n' "$1"; fail=1; }

echo "==> 1. shell syntax"
n=0
for f in $(git ls-files '*.sh'); do
  bash -n "$f" 2>/dev/null || bad "syntax error in $f"
  n=$((n + 1))
done
note "$n shell files parsed"

echo "==> 2. frontmatter (agents need name/description/tools/model; skills need name/description)"
python3 - <<'PY' || fail=1
import glob, os, re, sys
def fm(p):
    m = re.search(r"^---\n(.*?)\n---", open(p).read(), re.S)
    return m.group(1) if m else ""
bad = 0
for a in glob.glob("agents/*/*.md"):
    if os.path.basename(a) == "CLAUDE.md":
        continue
    miss = [k for k in ("name", "description", "tools", "model")
            if not re.search(rf"(?m)^{k}:", fm(a))]
    if miss:
        print(f"  FAIL: {a} missing {miss}"); bad = 1
for s in glob.glob("skills/*/*/SKILL.md"):
    miss = [k for k in ("name", "description") if not re.search(rf"(?m)^{k}:", fm(s))]
    if miss:
        print(f"  FAIL: {s} missing {miss}"); bad = 1
print("  all agent + skill frontmatter complete" if not bad else "")
sys.exit(bad)
PY

echo "==> 3. cited repo paths resolve (relative to the citing file OR the repo root)"
python3 - <<'PY' || fail=1
import re, glob, os, sys
# Paths that live in a CONSUMER repo, not this one. Not defects.
CONSUMER = (".claude/", "scripts/", "feature-docs/", "src/", "lib/", "tests/", "web/", "tools/",
            "path/", "ready/", "testing/", "building/", "review/", "docs/", ".circleci/",
            ".github/", "agent_logs/")
files = (glob.glob("skills/*/*/SKILL.md") + glob.glob("agents/*/*.md") + glob.glob("*.md")
         + glob.glob("*/CLAUDE.md") + glob.glob("templates/**/*.md", recursive=True))
pat = re.compile(r"`([A-Za-z0-9_.\-]+/[A-Za-z0-9_./\-]+\.(?:md|sh|json|tsv|yml|yaml|py|ts|tsx))`")
bad = 0
for f in files:
    d = os.path.dirname(f) or "."
    for m in pat.finditer(open(f, errors="ignore").read()):
        p = m.group(1)
        if p.startswith(CONSUMER):
            continue
        if os.path.exists(os.path.join(d, p)) or os.path.exists(p):
            continue
        print(f"  FAIL: {f} cites missing {p}"); bad = 1
print("  every repo-relative path cited resolves" if not bad else "")
sys.exit(bad)
PY

echo "==> 4. bash blocks in skills/templates are runnable (no pseudocode)"
python3 - <<'PY' || fail=1
import re, glob, subprocess, sys
bad = tot = 0
for f in glob.glob("skills/*/*/SKILL.md") + glob.glob("templates/**/*.md", recursive=True):
    for m in re.finditer(r"```bash\n(.*?)```", open(f).read(), re.S):
        code = m.group(1); tot += 1
        if "<" in code and ">" in code:
            continue  # carries placeholders; not literally runnable by design
        if subprocess.run(["bash", "-n"], input=code, text=True, capture_output=True).returncode:
            print(f"  FAIL: unparseable bash block in {f}"); bad = 1
print(f"  {tot} bash blocks scanned" if not bad else "")
sys.exit(bad)
PY

echo "==> 5. no unguarded command-substitution pipelines under pipefail"
python3 - <<'PY' || fail=1
import re, subprocess, sys
risky = re.compile(r'\$\((?=[^)]*\|)[^)]*\b(grep|head|tail|awk|lsof|find)\b[^)]*\)')
bad = 0
for f in subprocess.run(["git","ls-files","*.sh"],capture_output=True,text=True).stdout.split():
    src = open(f).read()
    if "pipefail" not in src:
        continue
    for i, line in enumerate(src.split("\n"), 1):
        s = line.strip()
        if s.startswith("#") or not risky.search(s) or "|| true" in s:
            continue
        print(f"  FAIL: {f}:{i} unguarded substitution under pipefail"); bad = 1
print("  all piped substitutions guarded" if not bad else "")
sys.exit(bad)
PY

echo "==> 6. stubs declare themselves"
python3 - <<'PY' || fail=1
import glob, sys
bad = 0
for s in glob.glob("skills/*/*/SKILL.md"):
    n = sum(1 for _ in open(s))
    if n > 40:
        continue
    body = open(s).read().lower()
    if not any(w in body for w in ("stub", "todo", "placeholder", "not yet")):
        print(f"  FAIL: silent stub {s} ({n} lines, no stub marker)"); bad = 1
print("  every stub is labelled as one" if not bad else "")
sys.exit(bad)
PY

echo "==> 7. hooks JSON valid + referenced scripts exist"
python3 - <<'PY' || fail=1
import glob, json, os, re, sys
bad = 0
for f in glob.glob("hooks/*.json"):
    try:
        txt = json.dumps(json.load(open(f)))
    except Exception as e:
        print(f"  FAIL: {f} invalid JSON ({e})"); bad = 1; continue
    for m in set(re.findall(r'[\w./-]*scripts/([\w.-]+\.sh)', txt)):
        if not os.path.exists(f"verify-scripts/{m}"):
            print(f"  FAIL: {f} references verify-scripts/{m}, which is missing"); bad = 1
print("  hooks valid, every referenced script present" if not bad else "")
sys.exit(bad)
PY

echo "==> 8. inventory is current"
tmp="$(mktemp)"; cp CLAUDE.md "$tmp"
bash verify-scripts/regenerate-inventory.sh >/dev/null || bad "inventory regen failed (an agent is missing model:?)"
if ! diff -q "$tmp" CLAUDE.md >/dev/null; then
  bad "CLAUDE.md inventory was stale - regenerated; commit the change"
else
  note "inventory matches disk"
fi
rm -f "$tmp"

echo ""
if [ "$fail" = "0" ]; then echo "AUDIT CLEAN"; else echo "AUDIT FOUND ISSUES (exit 1)"; fi
exit "$fail"
