#!/usr/bin/env bash
# Tests tools/fresh-release.sh (card #37) on a copy of this checkout in a temp git repo: each leak rule refuses (rc=1,
# naming the file), the allowed values, a name with a space and a dirty checkout pass, and two runs give one tree.
#   bash tests/test_fresh_release.sh
# Every leaking fixture is assembled at run time, so this file itself passes the gate it tests.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
D="$(mktemp -d)"; trap 'rm -rf "$D"' EXIT
git init -q "$D/r"
git -C "$ROOT" ls-files -z | tar -C "$ROOT" --null -T - -cf - | tar -C "$D/r" -xf -
cd "$D/r"
git config user.email t@example.com; git config user.name t; git config commit.gpgsign false
git add -A; git commit -qm base; BASE="$(git rev-parse HEAD)"
pass=0; total=0

ok() { pass=$((pass + 1)); total=$((total + 1)); echo "ok   $1"; }
bad() { total=$((total + 1)); echo "FAIL $1"; }

# case LABEL WANT-RC [TEXT-THE-REFUSAL-MUST-NAME]: commits what the caller staged, runs the script, resets.
case_() {
  local label="$1" want="$2" names="${3:-}" out rc
  git add -A; git commit -q --allow-empty -m "$label"
  out="$(bash tools/fresh-release.sh HEAD 2>&1)"; rc=$?
  if [ "$rc" != "$want" ]; then bad "$label: rc=$rc, want $want | $(echo "$out" | tail -2 | tr '\n' ' ')"
  elif [ -n "$names" ] && ! grep -qF -- "$names" <<<"$out"; then bad "$label: refusal does not name $names"
  else ok "$label (rc=$rc)"; fi
  git reset -q --hard "$BASE"; git clean -qfdx
}

case_ "clean baseline" 0
printf 'mail hola@zoaftware.com or x@example.org, bind 127.0.0.1 or 0.0.0.0\n' > allowed.md
case_ "allowed mail and addresses" 0
echo x > "a b.md"; case_ "file name with a space" 0
echo "write to foo@q""crew.co" > m1.md; case_ "mail at another domain" 1 "m1.md:1:"
echo "write to x@brilliant""directories.com" > m2.md; case_ "mail at a second domain" 1 "m2.md:1:"
echo "key sk-""ant-api03-$(printf 'A%.0s' {1..20})" > s1.md; case_ "Anthropic key" 1 "s1.md:1:"
echo "-----BEGIN RSA PRIV""ATE KEY-----" > s2.md; case_ "private key" 1 "s2.md:1:"
echo "token gh""p_$(printf 'a%.0s' {1..36})" > s3.md; case_ "GitHub token" 1 "s3.md:1:"
echo "token xo""xb-123-456" > s4.md; case_ "Slack bot token" 1 "s4.md:1:"
echo "token xo""xp-123-456" > s5.md; case_ "Slack user token" 1 "s5.md:1:"
echo "id AKI""A$(printf 'B%.0s' {1..16})" > s6.md; case_ "AWS key id" 1 "s6.md:1:"
echo "server 10.1"".2.3" > ip.md; case_ "IPv4 address" 1 "ip.md:1:"
echo "see /Use""rs/someone/x" > p1.md; case_ "Mac home path" 1 "p1.md:1:"
echo "see /ho""me/someone/x" > p2.md; case_ "Linux home path" 1 "p2.md:1:"
echo "see /private""/tmp/x" > p3.md; case_ "private tmp path" 1 "p3.md:1:"
echo "by stuard""duran" > o1.md; case_ "owner user name" 1 "o1.md:1:"
echo "account claude""3" > o2.md; case_ "internal account" 1 "o2.md:1:"
echo "run tablero"".py" > o3.md; case_ "internal board script" 1 "o3.md:1:"
echo "someone@gmail"".com" > o4.md; case_ "personal mail" 1 "o4.md:1:"
echo "host directory""up" > o5.md; case_ "internal host" 1 "o5.md:1:"
mkdir -p notes; echo y > "notes/stuard""duran-notes.md"; case_ "leak in a file name only" 1 "notes/stuard"
ln -s README.md link-out; case_ "symlink (to a clean file)" 1 "'link-out': symlink"

echo "#!/usr/bin/env bash" > tests/test_no_soul_history.sh
git add -A; git commit -qm history-test; out="$(bash tools/fresh-release.sh HEAD 2>/dev/null)"
if [ -n "$out" ] && ! git ls-tree -r --name-only "$out" | grep -q test_no_soul_history; then ok "history test dropped"
else bad "history test dropped"; fi
git reset -q --hard "$BASE"; git clean -qfdx

echo dirty > dirty.txt; echo mod >> README.md; git add dirty.txt; before="$(git status --porcelain; git diff; git diff --cached)"
bash tools/fresh-release.sh HEAD >/dev/null 2>&1; rc=$?
[ "$rc" = 0 ] && [ "$before" = "$(git status --porcelain; git diff; git diff --cached)" ] && ok "dirty checkout untouched (rc=$rc)" \
  || bad "dirty checkout untouched (rc=$rc)"
git reset -q --hard "$BASE"; git clean -qfdx

a="$(bash tools/fresh-release.sh "$BASE" 2>/dev/null)"; b="$(bash tools/fresh-release.sh "$a" 2>/dev/null)"
if [ -n "$a" ] && [ "$(git rev-parse "$a^{tree}")" = "$(git rev-parse "$b^{tree}" 2>/dev/null)" ]; then ok "two runs, one tree"
else bad "two runs, one tree"; fi

echo "fresh-release: $pass/$total cases pass"
[ "$pass" = "$total" ]
