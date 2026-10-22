#!/usr/bin/env bash
# End to end for the Stop hook in hooks/hooks.json: real Claude Code, a copy of this plugin whose server is the local
# stand-in tests/stop_stub.py (it answers what the server's board_check answers). The copy is installed for one
# throwaway folder only (--scope local) and removed at the end, so no other session gets it. Spends three short haiku
# turns; needs `claude` signed in. CLAUDE_BIN picks another Claude Code build (the desktop app's own engine).
#   working: the session holds a card -> the turn goes on once, then stops with a line for the owner
#   none:    the session holds nothing -> it stops at once
#   down:    the server is not reachable (before sign-in) -> it stops at once, normally
set -u
CLAUDE=${CLAUDE_BIN:-claude}
cd "$(dirname "$0")/.." || exit 1
PLUGIN=$PWD
WORK=$(mktemp -d "${TMPDIR:-/tmp}/dipro-stop.XXXXXX")
STUB=
cleanup() {
  [ -n "$STUB" ] && kill "$STUB" 2>/dev/null
  (cd "$WORK/project" 2>/dev/null && "$CLAUDE" plugin uninstall dipro-board@brilliant-lab-test --scope local >/dev/null 2>&1
   "$CLAUDE" plugin marketplace remove brilliant-lab-test >/dev/null 2>&1)
  rm -rf "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/cache/brilliant-lab-test"
  if [ -n "${KEEP:-}" ]; then echo "kept $WORK"; else rm -rf "$WORK"; fi
}
trap cleanup EXIT
PORT=$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')

mkdir -p "$WORK/market/.claude-plugin" "$WORK/market/plugins" "$WORK/project"
rsync -a --exclude tests --exclude __pycache__ "$PLUGIN/" "$WORK/market/plugins/dipro-board/"
python3 - "$WORK/market" "$PORT" <<'PY'
import json, sys
market, port = sys.argv[1], sys.argv[2]
json.dump({'mcpServers': {'dipro-board': {'type': 'http', 'url': 'http://127.0.0.1:%s/mcp' % port}}},
          open(market + '/plugins/dipro-board/.mcp.json', 'w'))
json.dump({'name': 'brilliant-lab-test', 'owner': {'name': 'Zoaftware'},
           'plugins': [{'name': 'dipro-board', 'source': './plugins/dipro-board'}]},
          open(market + '/.claude-plugin/marketplace.json', 'w'))
PY
cd "$WORK/project" || exit 1
"$CLAUDE" plugin marketplace add "$WORK/market" --scope local >/dev/null || exit 1
"$CLAUDE" plugin install dipro-board@brilliant-lab-test --scope local >/dev/null || exit 1

turn() {  # mode: one haiku turn; the stream in $WORK/<mode>.jsonl, the stand-in's calls in $WORK/<mode>.log
  : >"$WORK/$1.log"
  if [ "$1" != down ]; then
    python3 "$PLUGIN/tests/stop_stub.py" "$PORT" "$WORK/$1.log" "$1" & STUB=$!
    sleep 1
  fi
  "$CLAUDE" -p "Reply with the single word OK." --model haiku --output-format stream-json --verbose --max-turns 5 \
    --setting-sources project,local >"$WORK/$1.jsonl" 2>"$WORK/$1.err"
  echo $? >"$WORK/$1.exit"
  [ -n "$STUB" ] && kill "$STUB" 2>/dev/null; wait "$STUB" 2>/dev/null; STUB=
}
turn working
turn none
turn down

python3 - "$WORK" <<'PY'
import json, sys
work = sys.argv[1]
fails, total = [], 0


def read(mode):
    events = [json.loads(l) for l in open('%s/%s.jsonl' % (work, mode)) if l.strip()]
    calls = [json.loads(l) for l in open('%s/%s.log' % (work, mode)) if l.strip()]
    init = next(e for e in events if e.get('type') == 'system' and e.get('subtype') == 'init')
    result = next(e for e in events if e.get('type') == 'result')
    turns = sum(1 for e in events if e.get('type') == 'assistant')
    return events, calls, init, result, turns, int(open('%s/%s.exit' % (work, mode)).read())


def check(ok, what):
    global total
    total += 1
    if not ok:
        fails.append(what)


events, calls, init, result, turns, code = read('working')
server = [s for s in init.get('mcp_servers', []) if s['name'] == 'plugin:dipro-board:dipro-board']
check(server and server[0]['status'] == 'connected', 'working: the plugin server connects: %s' % server)
check([c['tool'] for c in calls] == ['board_check', 'board_check'], 'working: the hook calls board_check twice: %s' % calls)
check(len(calls) == 2 and calls[0]['arguments'] == {'session_id': init['session_id'], 'stop_hook_active': 'false'},
      'working: first call carries this session id and stop_hook_active "false": %s' % calls[:1])
check(len(calls) == 2 and calls[1]['arguments'] == {'session_id': init['session_id'], 'stop_hook_active': 'true'},
      'working: second call carries stop_hook_active "true": %s' % calls[1:])
check(turns >= 2, 'working: the turn went on after the first stop (assistant messages: %d)' % turns)
check(code == 0 and result.get('subtype') == 'success', 'working: ends normally: exit %s, %s' % (code, result.get('subtype')))
print('working: %d assistant messages, last: %r' % (turns, (result.get('result') or '')[:200]))

events, calls, init, result, turns, code = read('none')
check([c['arguments'].get('stop_hook_active') for c in calls] == ['false'], 'none: one call, then it stops: %s' % calls)
check(turns == 1, 'none: one assistant message (got %d)' % turns)
check(code == 0 and result.get('subtype') == 'success', 'none: ends normally: exit %s, %s' % (code, result.get('subtype')))

events, calls, init, result, turns, code = read('down')
server = [s for s in init.get('mcp_servers', []) if s['name'] == 'plugin:dipro-board:dipro-board']
check(server and server[0]['status'] != 'connected', 'down: the server is not connected: %s' % server)
check(calls == [] and turns == 1, 'down: no call, one assistant message (got %d)' % turns)
check(code == 0 and result.get('subtype') == 'success', 'down: ends normally: exit %s, %s' % (code, result.get('subtype')))

for f in fails:
    print('FAIL ' + f)
print('%d/%d checks pass' % (total - len(fails), total))
sys.exit(1 if fails else 0)
PY
