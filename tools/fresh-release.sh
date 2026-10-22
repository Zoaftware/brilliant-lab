#!/usr/bin/env bash
# Builds the public release of this repo from any ref as ONE orphan commit (card #37): the tree of <source-ref> minus
# the internal files below, with the public-safe fixes applied, plus this script. Nothing is pushed, nothing is tagged.
#   bash tools/fresh-release.sh <source-ref> [branch]   prints the new commit's sha; [branch] is created or moved to it
# Re-runnable: every fix is a no-op when the source already has it, and the run fails if a leak is left in the tree.
# Accepted limit: the leak gate reads plain text and names; compressed or re-encoded text (gzip, base64) is not read.
set -euo pipefail
SRC="${1:?usage: tools/fresh-release.sh <source-ref> [branch]}"; BRANCH="${2:-}"
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
SELFTEST="$(dirname "$SELF")/../tests/test_fresh_release.sh"
cd "$(git rev-parse --show-toplevel)"
SRC_SHA="$(git rev-parse --verify "$SRC^{commit}")"

# Internal material: it stays in the private history of main and on the owner's Mac, never in the public tree.
# test_no_soul_history.sh needs an old commit holding a soul, which a stranger cannot fetch once main is replaced.
DROP=(CLAUDE.md docs/probe-g.md docs/RELAY-NOTES.md docs/RELAY-NOTES.ledger.jsonl tests/test_no_soul_history.sh)

TREE="$(mktemp -d)"; INDEX="$(mktemp)"; trap 'rm -rf "$TREE" "$INDEX"' EXIT
git archive "$SRC_SHA" | tar -x -C "$TREE"
for f in "${DROP[@]}"; do rm -f "$TREE/$f"; done
rmdir "$TREE/docs" 2>/dev/null || true
mkdir -p "$TREE/tools"; [ "$SELF" -ef "$TREE/tools/fresh-release.sh" ] || cp "$SELF" "$TREE/tools/fresh-release.sh"
if [ -f "$SELFTEST" ]; then
  mkdir -p "$TREE/tests"; [ "$SELFTEST" -ef "$TREE/tests/test_fresh_release.sh" ] || cp "$SELFTEST" "$TREE/tests/"
fi

python3 - "$TREE" <<'PY'
import os, re, sys
root = sys.argv[1]

def fix(path, old, new):
    p = os.path.join(root, path)
    if not os.path.exists(p):
        return
    text = open(p, encoding='utf-8').read()
    out = re.sub(old, new, text) if isinstance(old, re.Pattern) else text.replace(old, new)
    if out != text:
        open(p, 'w', encoding='utf-8').write(out)

# The public contact address zoaftware.com publishes (zoaftware-page site/app/Config/Zoaftware.php:26), not a Gmail.
fix('.claude-plugin/marketplace.json', re.compile(r'"email": "[^"]*@gmai[l][.]com"'), '"email": "hola@zoaftware.com"')
# The guard matches the API path on any host, so the test needs no real site: example.com is reserved (RFC 2606).
fix('plugins/dipro-board/tests/test_guard.sh', re.compile(r'zoaftware[.]directory[u]p[.]com'), 'example.com')
# The stub's docstring named server classes and branches; the public copy describes only what it imitates.
fix('plugins/dipro-board/tests/stop_stub.py',
    re.compile(r"which answers exactly what the server's\n.*?Claude Code sent\.", re.S),
    "which answers what the DiPro Board server's\n"
    "board_check answers for card #1 «New headline» held in Working by the calling session. Every tools/call is logged\n"
    "as one JSON line, so the test can see what Claude Code sent.")
LIMIT = 'Accepted limit: text re-encoded before it is committed (base64, rot13, ...) is not caught.\n'
p = os.path.join(root, 'tests/test_no_soul.py')
if os.path.exists(p):
    t = open(p, encoding='utf-8').read()
    anchor = 'Exit 0 when nothing is found, 1 when a unit of a soul is in a file.\n'
    if LIMIT not in t and anchor in t:
        open(p, 'w', encoding='utf-8').write(t.replace(anchor, anchor + LIMIT, 1))
PY

# The leak gate reads every file's text and every path name. Allowed: mail at zoaftware.com and example.com/.org,
# the addresses 127.0.0.1 and 0.0.0.0. The patterns are written so that this file itself does not match them.
if ! python3 - "$TREE" <<'PY'
import os, re, sys
root = sys.argv[1]
INTERNAL = re.compile(r'/Use[r]s/|/hom[e]/|/privat[e]/tmp|stuard[d]uran|claude[3]|tablero[.]py|gmai[l][.]com|directory[u]p',
                      re.I)
SECRET = re.compile(r's[k]-ant|-----BEGI[N].*PRIVAT[E] KEY|gh[p]_|xo[x][bp]-|AKI[A][0-9A-Z]{16}')
EMAIL = re.compile(r'[A-Za-z0-9._%+-]+@([A-Za-z0-9-]+(?:[.][A-Za-z0-9-]+)+)')
IPV4 = re.compile(r'(?<![0-9.])([0-9]{1,3}(?:[.][0-9]{1,3}){3})(?![0-9]|[.][0-9])')
MAIL_OK, IP_OK = ('zoaftware.com', 'example.com', 'example.org'), ('127.0.0.1', '0.0.0.0')


def mail_ok(domain):
    return any(domain == d or domain.endswith('.' + d) for d in MAIL_OK)


def leaks(text):
    found = [m.group(0) for m in INTERNAL.finditer(text)] + [m.group(0) for m in SECRET.finditer(text)]
    found += [m.group(0) for m in EMAIL.finditer(text) if not mail_ok(m.group(1).lower())]
    found += [m.group(1) for m in IPV4.finditer(text)
              if m.group(1) not in IP_OK and all(int(o) <= 255 for o in m.group(1).split('.'))]
    return found


hits = []
for top, dirs, files in os.walk(root):
    for name in sorted(dirs + files):
        path = os.path.join(top, name)
        rel = os.path.relpath(path, root)
        hits += ['%r: name: %s' % (rel, leak) for leak in leaks(rel)]
        if os.path.islink(path):
            hits.append('%r: symlink to %s' % (rel, os.readlink(path)))
        elif name in files:
            text = open(path, 'rb').read().decode('utf-8', 'replace')
            for n, line in enumerate(text.split('\n'), 1):
                hits += ['%s:%d:%s' % (rel, n, leak) for leak in leaks(line)]
for h in hits:
    print(h, file=sys.stderr)
sys.exit(1 if hits else 0)
PY
then
  echo "fresh-release: internal text, a secret or a symlink left in the tree (listed above)" >&2; exit 1
fi

# A release tree must hold no soul either; refs older than card #35 have no checker and stop here only on leaks.
if [ -f "$TREE/tests/test_no_soul.py" ] && ! python3 "$TREE/tests/test_no_soul.py" >&2; then
  echo "fresh-release: soul text in the tree of $SRC" >&2; exit 1
fi

rm -f "$INDEX"; export GIT_INDEX_FILE="$INDEX"  # git refuses an empty file as an index
git --work-tree="$TREE" add -A -f .
TREE_SHA="$(git write-tree)"
SHA="$(printf 'DiPro Board plugin, release snapshot of %s\n\nBuilt by tools/fresh-release.sh from %s: one orphan commit, internal files dropped.\n\nCo-Authored-By: Claude <noreply@%s>\n' \
  "${SRC_SHA:0:7}" "$SRC_SHA" anthropic.com | git commit-tree "$TREE_SHA")"
[ -z "$BRANCH" ] || git branch -f "$BRANCH" "$SHA" >/dev/null
echo "$SHA"
