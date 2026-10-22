#!/usr/bin/env python3
"""No soul in the package (card #35): the instructions of DiPro, DiDe and DiDev live on the DiPro Board server.

tests/soul-hashes.txt holds salted hashes of every line, sentence and 12-word run of the original souls (written by the
server repo's tools/dipro-instructions-split.py --hashes); this file holds no phrase of them. Each file is cut into the
same units and every unit's hash is looked up.

  python3 tests/test_no_soul.py              every file of this repo's working tree (not .git, not the hash list)
  python3 tests/test_no_soul.py FILE...      only these files (a copy of an original soul must be found)
  python3 tests/test_no_soul.py --history [REV]   every blob reachable from REV (default HEAD), so a soul kept
                                                 only in an old commit is found too (card #37)

Exit 0 when nothing is found, 1 when a unit of a soul is in a file.
Accepted limit: text re-encoded before it is committed (base64, rot13, ...) is not caught.
"""
import hashlib
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIST = os.path.join(ROOT, 'tests', 'soul-hashes.txt')


def load():
    salt, rule, hashes = None, {}, set()
    for line in open(LIST, encoding='utf-8'):
        line = line.strip()
        if line.startswith('salt '):
            salt = line[5:]
        elif line.startswith('rule '):
            rule = {k: int(v) for k, v in (p.split('=') for p in line[5:].split())}
        elif line and not line.startswith('#'):
            hashes.add(line)
    return salt, rule, hashes


def norm(s):
    return ' '.join(re.sub(r'[^0-9a-z]+', ' ', s.lower()).split())


def units(text, rule):
    """(line number, unit): lines, sentences and runs of words, cut exactly as the server's split tool cuts them."""
    out, short = [], lambda n: len(n) < rule['min_chars'] or n.count(' ') + 1 < rule['min_words']
    for no, line in enumerate(text.splitlines(), 1):
        n = norm(line)
        if not short(n):
            out.append((no, n))
    no = 1
    for block in re.split(r'(\n\s*\n)', text):
        if not block.strip():
            no += block.count('\n')
            continue
        flat = ' '.join(block.split())
        for sentence in re.split(r'(?<=[.!?;:])\s+', flat):
            n = norm(sentence)
            if not short(n):
                out.append((no, n))
        words = norm(flat).split()
        for i in range(len(words) - rule['shingle'] + 1):
            out.append((no, ' '.join(words[i:i + rule['shingle']])))
        no += block.count('\n')
    return out


def files():
    for d, dirs, names in os.walk(ROOT):
        dirs[:] = [x for x in dirs if x != '.git']
        for name in names:
            p = os.path.join(d, name)
            if os.path.abspath(p) != LIST:
                yield p


def blobs(rev):
    """(label, text) of every blob reachable from rev, each blob once, under the first path git names it by."""
    git = ['git', '-C', ROOT]
    listed = subprocess.run(git + ['rev-list', '--objects', rev], capture_output=True, text=True, check=True).stdout
    seen, todo = set(), []
    for line in listed.splitlines():
        sha, _, path = line.partition(' ')
        if path and sha not in seen and path != 'tests/soul-hashes.txt':
            seen.add(sha)
            todo.append((sha, path))
    cat = subprocess.run(git + ['cat-file', '--batch'], input=''.join(f'{sha}\n' for sha, _ in todo).encode(),
                         capture_output=True, check=True).stdout
    at = 0
    for sha, path in todo:
        head_end = cat.index(b'\n', at)
        _, kind, size = cat[at:head_end].split()
        body = cat[head_end + 1:head_end + 1 + int(size)]
        at = head_end + 1 + int(size) + 1
        if kind == b'blob':
            yield f'{path} @{sha[:10]}', body


def main():
    salt, rule, hashes = load()
    args = sys.argv[1:]
    if args[:1] == ['--history']:
        found_in = list(blobs(args[1] if len(args) > 1 else 'HEAD'))
    else:
        paths = args or sorted(files())
        found_in = []
        for p in paths:
            try:
                found_in.append((os.path.relpath(p, ROOT), open(p, 'rb').read()))
            except OSError:
                continue
    found = 0
    for label, raw in found_in:
        try:
            text = raw.decode('utf-8')
        except UnicodeDecodeError:
            continue
        hits = sorted({no for no, u in units(text, rule) if hashlib.sha256((salt + u).encode()).hexdigest()[:20] in hashes})
        if hits:
            found += 1
            print(f'SOUL {label}: lines {", ".join(map(str, hits[:20]))}{" ..." if len(hits) > 20 else ""}')
    print(f'no-soul: {len(found_in)} files, {len(hashes)} soul units, {found} files with soul text')
    sys.exit(1 if found else 0)


if __name__ == '__main__':
    main()
